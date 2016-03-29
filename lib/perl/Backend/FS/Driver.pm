#########################################################################
# (C) ZE CMS, Humboldt-Universitaet zu Berlin
# Written 2010-2011 by Daniel Rohde <d.rohde@cms.hu-berlin.de>
#########################################################################
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#########################################################################
# Some performance notes:
# - unpacking and shifting of subroutine parameters are slower than $_[..]
# - caching is really neccessary
#
package Backend::FS::Driver;

use strict;
use warnings;

our $VERSION = '2.0';

use base qw( Backend::Driver );

# fixed ACL bug  reported by Thomas Klose <thomas.klose@gmx.com>:
use filetest 'access';

use File::Spec::Link;
use Fcntl qw(:flock);
use CGI::Carp;
use English qw ( -no_match_vars );

use DefaultConfig qw( $READBUFSIZE );
use HTTPHelper qw( get_parent_uri get_base_uri_frag );

use vars qw( %CACHE );


sub finalize {
    my ($self) = @_;
    %CACHE = ();
    ${$self}{cache} = \%CACHE;
    return;
}

sub __basename {
    my $bn = get_base_uri_frag( $_[1] );
    if ( $_[2] ) { $bn =~ s/\Q$_[2]\E//xms; }
    return $bn;
}

sub basename {
    return $CACHE{ $_[0] }{ $_[1] }{basename} //=
      $_[0]->__basename( $_[1], $_[2] );
}

sub dirname {
    return $CACHE{ $_[0] }{ $_[1] // q{} }{dirname} //= get_parent_uri( $_[1] );
}

sub exists {
    return $CACHE{ $_[0] }{ $_[1] // q{} }{exists} //= defined $_[1] && -e $_[0]->resolveVirt( $_[1] );
}

sub isDir {
    return $CACHE{ $_[0] }{ $_[1] // q{} }{isDir} //= defined $_[1] && -d $_[0]->resolveVirt( $_[1] );
}

sub isFile {
    return $CACHE{ $_[0] }{ $_[1] }{isFile} //= -f $_[0]->resolveVirt( $_[1] );
}

sub isLink {
    my ( $self, $fn ) = @_;
    $self->remove_slash($fn);
    return $CACHE{$self}{$fn}{isLink} //=
      $self->isVirtualLink($fn) || -l $self->resolveVirt( $fn, 1 );
}

sub isBlockDevice {
    return $CACHE{ $_[0] }{ $_[1] }{isBlockDevice} //=
      -b $_[0]->resolveVirt( $_[1] );
}

sub isCharDevice {
    return $CACHE{ $_[0] }{ $_[1] }{isCharDevice} //=
      -c $_[0]->resolveVirt( $_[1] );
}

sub isEmpty {
    return $CACHE{ $_[0] }{ $_[1] }{isEmpty} //= -z $_[0]->resolveVirt( $_[1] );
}

sub isReadable {
    return $CACHE{ $_[0] }{ $_[1] }{isReadable} //=
      -r $_[0]->resolveVirt( $_[1] );
}

sub isWriteable {
    return $CACHE{ $_[0] }{ $_[1] }{isWriteable} //=
      -w $_[0]->resolveVirt( $_[1] );
}

sub isExecutable {
    return $CACHE{ $_[0] }{ $_[1] }{isExecutable} //=
      -x $_[0]->resolveVirt( $_[1] );
}

sub getParent {
    return $_[0]->dirname( $_[1] );
}

sub mkcol {
    delete $CACHE{ $_[0] }{ $_[1] };
    return CORE::mkdir( $_[0]->resolveVirt( $_[1] ) );
}

sub unlinkFile {
    my ( $self, $f ) = @_;
    return 0 if $self->isVirtualLink($f);
    delete $CACHE{$self}{$f};
    $self->remove_slash($f);
    delete $CACHE{$self}{$f};
    return CORE::unlink( $self->resolveVirt($f) );
}

sub unlinkDir {
    delete $CACHE{ $_[0] }{ $_[1] };
    return 0 if $_[0]->isVirtualLink( $_[1] );
    return CORE::rmdir( $_[0]->resolveVirt( $_[1] ) );
}

sub readDir {
    my ( $self, $dirname, $limit, $filter ) = @_;
    my @files;
    if ( opendir my $dir, $self->resolveVirt($dirname) ) {
        while ( my $file = readdir $dir ) {
            last if defined $limit && $#files >= $limit;
            next if $self->filter( $filter, $dirname, $file );
            push @files, $file;
        }
        closedir($dir) || carp("Cannot close $dirname.");
        if ( exists $main::BACKEND_CONFIG{$main::BACKEND}{fsvlink}{$dirname}
            && ( !defined $limit || $#files < $limit ) )
        {
            foreach my $file (
                keys
                %{ $main::BACKEND_CONFIG{$main::BACKEND}{fsvlink}{$dirname} } )
            {
                last if defined $limit && $#files >= $limit;
                next if $self->filter( $filter, $dirname, $file );
                push @files, $file;
            }
        }
    }
    return \@files;
}

sub filter {
    my ( $self, $filter, $dirname, $file ) = @_;
    return 1 if defined $file && $file =~ /^[.]{1,2}$/xms;
    return defined $filter
      && ( ( ref($filter) eq 'CODE' && $filter->( $dirname, $file ) )
        || ( ref($filter) ne 'CODE' && $filter->filter( $dirname, $file ) ) );
}

sub stat {
    return CORE::stat( $_[0]->resolveVirt( $_[1] ) );
}

sub lstat {
    return CORE::lstat( $_[0]->resolveVirt( $_[1] ) );
}

sub deltree {
    my ( $self, $f, $err_ref ) = @_;
    $err_ref //= [];
    my $count = 0;
    if ( !$self->{config}->{method}->is_allowed( $f, 1 ) ) {
        push @{$err_ref}, { $f => "Cannot delete $f" };
        return 0;
    }
    if ( $self->isLink($f) ) {
        if ( $self->unlinkFile($f) ) {
            $count++;
        }
        else {
            push @{$err_ref}, { $f => "Cannot delete '$f': $ERRNO" };
        }
    }
    elsif ( $self->isDir($f) ) {
        if ( opendir my $dirh, $self->resolveVirt($f) ) {
            foreach my $sf ( grep { !/^[.]{1,2}$/xms } readdir $dirh ) {
                my $full = $f . $sf;
                $self->add_slash( $full, $self->isDir($full) );
                $count += $self->deltree( $full, $err_ref );
            }
            closedir($dirh) || carp("Cannot close directory $f.");
            if ( $self->unlinkDir($f) ) {
                $count++;
                $f .= $f !~ /\/$/xms ? q{/} : q{};
            }
            else {
                push @{$err_ref}, { $f => "Cannot delete '$f': $ERRNO" };
            }
        }
        else {
            push @{$err_ref}, { $f => "Cannot open '$f': $ERRNO" };
        }
    }
    elsif ( $self->exists($f) ) {
        if ( $self->unlinkFile($f) ) {
            $count++;
        }
        else {
            push @{$err_ref}, { $f => "Cannot delete '$f' : $ERRNO" };
        }
    }
    else {
        push @{$err_ref}, { $f => "File/Folder '$f' not found" };
    }
    return $count;
}

sub changeFilePermissions {
    my ( $self, $fn, $mode, $type, $recurse, $visited ) = @_;
    if ( $type eq 's' ) {
        chmod $mode, $fn;
    }
    else {
        my @stat = $self->stat($fn);
        chmod $type eq 'a' ? $stat[2] | $mode
          : $type eq 'r' ? $stat[2] ^ ( $stat[2] & $mode )
          :                $stat[2], $fn;
    }
    my $nfn = $self->resolve( $self->resolveVirt($fn) );
    return if exists ${$visited}{$nfn};
    ${$visited}{$nfn} = 1;

    if ( $recurse && $self->isDir($fn) ) {
        if ( opendir my $dir, $self->resolveVirt($fn) ) {
            foreach my $f ( grep { !/^[.]{1,2}$/xms } readdir $dir ) {
                $self->add_slash( $f, $self->isDir("$fn$f") );

                #$f .= '/' if $self->isDir("$fn$f") && $f !~ /\/$/xms;
                changeFilePermissions( $self, $fn . $f, $mode, $type,
                    $recurse, $visited );
            }
            closedir($dir) || carp("Cannot close directory $fn.");
        }
    }
    return;
}

sub saveData {
    my ( $self, $file, $data, $append ) = @_;
    my $ret = 1;

    delete $CACHE{$self}{$file};

    my ( $block_hard, $block_curr ) =
      $self->getQuota( $self->dirname($file) );
    return 0 if $block_hard > 0 && bytes::length($data) + $block_curr > $block_hard;

    my $mode = $append ? '>>' : '>';

    if ( ( $ret = open my $f, ${mode}, $self->resolveVirt($file) ) ) {
        if ( $main::ENABLE_FLOCK && !flock $f, LOCK_EX | LOCK_NB ) {
            $ret = 0;
        }
        else {
            print( {$f} $data ) || carp("Cannot write data to $file.");
            if ($main::ENABLE_FLOCK) { flock $f, LOCK_UN; }
        }
        close($f) || carp("Cannot close $file");
    }
    return $ret;
}

sub saveStream {
    my ( $self, $destination, $filehandle ) = @_;
    my $ret = 1;

    delete $CACHE{$self}{$destination};

    my ( $block_hard, $block_curr ) =
      $self->getQuota( $self->dirname($destination) );

    if ( ( $ret = open my $f, '>', $self->resolveVirt($destination) ) ) {
        if ( $main::ENABLE_FLOCK && !flock $f, LOCK_EX | LOCK_NB ) {
            close($f) || carp("Cannot close $destination.");
            $ret = 0;
        }
        else {
            binmode $f;
            binmode $filehandle;
            my ($consumed) = 0;
            while (
                read( $filehandle, my $buffer, $READBUFSIZE ) >
                0 )
            {
                last
                  if $block_hard > 0
                  && $consumed + $block_curr >= $block_hard;
                print( {$f} $buffer ) || carp("Cannot write to $destination.");
                $consumed += bytes::length( $buffer );
            }
            if ($main::ENABLE_FLOCK) { flock $f, LOCK_UN; }
            close($f) || carp("Cannot close $destination.");
            $ret =
              !( $block_hard > 0 && $consumed + $block_curr >= $block_hard );
        }
    }
    else {
        $ret = 0;
    }
    return $ret;
}

sub uncompress_archive {
    my ( $self, $zipfile, $destination ) = @_;
    my $ret = 1;
    require Archive::Zip;
    my $zip    = Archive::Zip->new();
    my $status = $zip->read( $self->resolveVirt($zipfile) );
    if ( $ret = $status eq $zip->AZ_OK ) {
        $zip->extractTree( undef, $self->resolveVirt($destination) );
    }
    return $ret;
}

sub compress_files {
    my ( $self, $desthandle, $basepath, @files ) = @_;

    require Archive::Zip;
    my $zip = Archive::Zip->new();
    foreach my $file (@files) {
        if ( $self->isDir( $basepath . $file ) ) {
            $zip->addTree( $self->resolveVirt( $basepath . $file ), $file );
        }
        elsif ($self->isReadable( $basepath . $file )
            && $self->exists( $basepath . $file ) )
        {
            $zip->addFile( $self->resolveVirt( $basepath . $file ), $file );
        }
    }
    return $zip->writeToFileHandle( $desthandle, 0 );
}

sub changeMod {
    delete $CACHE{ $_[1] }{ $_[2] };
    return chmod $_[1], $_[0]->resolveVirt( $_[2] );
}

sub createSymLink {
    delete $CACHE{ $_[1] }{ $_[2] };
    return
      CORE::symlink( $_[0]->resolveVirt( $_[1] ), $_[0]->resolveVirt( $_[2] ) );
}

sub getLinkSrc {
    return $_[0]->resolveVirt( $_[1] ) if $_[0]->isVirtualLink( $_[1] );
    return CORE::readlink( $_[0]->resolveVirt( $_[1] ) );
}

sub resolveVirt {
    return $CACHE{ $_[0] }{ $_[1] // q{} }{resolveVirt} //=
      $_[0]->getVirtualLinkTarget( $_[1] );
}

sub resolve {
    return $CACHE{ $_[0] }{ $_[1] }{resolve} //=
      File::Spec::Link->full_resolve( $_[1] );
}

sub getFileContent {
    my ( $self, $fn, $limit ) = @_;
    my $content = q{};
    if ( $self->exists($fn) && !$self->isDir($fn) && open my $fh,
        '<', $self->resolveVirt($fn) )
    {
        binmode $fh;
        read $fh, $content, $limit || ( $self->stat($fn) )[7];
        close($fh) || carp("Cannot close $fn.");
    }
    return $content;
}

sub hasSetUidBit {
    return $CACHE{ $_[0] }{ $_[1] }{hasSetUidBit} //=
      -u $_[0]->resolveVirt( $_[1] );
}

sub hasSetGidBit {
    return $CACHE{ $_[0] }{ $_[1] }{hasSetGidBit} //=
      -g $_[0]->resolveVirt( $_[1] );
}

sub hasStickyBit {
    return $CACHE{ $_[0] }{ $_[1] }{hasStickyBit} //=
      -k $_[0]->resolveVirt( $_[1] );
}

sub getLocalFilename {
    return $_[0]->resolveVirt( $_[1] );
}

sub printFile {
    my ( $self, $file, $to, $pos, $count ) = @_;
    $to //= \*STDOUT;
    my $bufsize = $main::BUFSIZE || 1_048_576;
    if ( defined $count && $count < $bufsize ) { $bufsize = $count; }
    if ( open my $fh, '<', $self->resolveVirt($file) ) {
        binmode $fh;
        binmode $to;
        if ($pos) { seek $fh, $pos, 0; }
        my $bytecount = 0;
        while ( my $bytesread = read $fh, my $buffer, $bufsize ) {
            print( {$to} $buffer ) || carp("Cannot write data to $to");
            $bytecount += $bytesread;
            if ( defined $count && $bytecount >= $count ) { last; }
            if ( defined $count && ( $bytecount + $bufsize > $count ) ) {
                $bufsize = $count - $bytecount;
            }
        }
        close($fh) || carp("Cannot close $file.");
    }
    return;
}

sub getDisplayName {
    return $CACHE{ $_[0] }{ $_[1] }{getDisplayName} //=
      $_[0]->basename( $_[1] )
      . ( $_[0]->isDir( $_[1] ) && $_[1] ne q{/} ? q{/} : q{} );
}

sub rename {
    delete $CACHE{ $_[0] }{ $_[1] };
    delete $CACHE{ $_[0] }{ $_[2] };
    return 0
      if $_[0]->isVirtualLink( $_[1] ) || $_[0]->isVirtualLink( $_[2] );
    return $_[0]->{config}->{method}->is_allowed( $_[0]->resolveVirt( $_[1] ), 1 )
      ? CORE::rename( $_[0]->resolveVirt( $_[1] ), $_[0]->resolveVirt( $_[2] ) )
      : 0;
}

sub getQuota {
    my ( $self, $fn ) = @_;
    require Quota;
    my @quota = Quota::query(
        Quota::getqcarg(
            $self->resolveVirt(
                $self->isDir($fn) ? $fn : $self->getParent($fn)
            )
        )
    );
    return @quota ? ( $quota[2] * 1024, $quota[0] * 1024 ) : ( 0, 0 );
}

sub copy {
    my ( $self, $src, $dst ) = @_;
    delete $CACHE{$self}{$dst};

    if (
        open( my $srcfh, '<', $self->resolveVirt( $src, 1 ) ) && open my $dstfh,
        '>',
        $self->resolveVirt( $dst, 1 )
      )
    {
        while ( read $srcfh, my $buffer, $main::BUFSIZE || 1_048_576 ) {
            syswrite $dstfh, $buffer;
        }
        close($srcfh) || carp("Cannot close $src.");
        close($dstfh) || carp("Cannot close $dst.");
        return 1;
    }
    return 0;
}

sub isVirtualLink {
    my ( $self, $fn ) = @_;
    return
      exists $main::BACKEND_CONFIG{$main::BACKEND}{fsvlink}
      { $self->dirname($fn) . q{/} }
      && exists $main::BACKEND_CONFIG{$main::BACKEND}{fsvlink}
      { $self->dirname($fn) . q{/} }{ $self->basename($fn) };
}

sub getVirtualLinkTarget {
    my ( $self, $src ) = @_;
    my $target = $src;
    if (!defined $src) {
        return $target;
    }
    if ( !exists $CACHE{$self}{$src}{getVirtualLinkTarget}{sortedkeys} ) {
        my @fslinkkeys = reverse sort { $a cmp $b }
          keys %{ $main::BACKEND_CONFIG{$main::BACKEND}{fsvlink} };
        $CACHE{$self}{$src}{getVirtualLinkTarget}{sortedkeys} = \@fslinkkeys;
    }

    foreach
      my $linkdir ( @{ $CACHE{$self}{$src}{getVirtualLinkTarget}{sortedkeys} } )
    {
        if ( !exists $CACHE{$self}{$src}{getVirtualLinkTarget}{$linkdir} ) {
            my @linkdirkeys =
              keys %{ $main::BACKEND_CONFIG{$main::BACKEND}{fsvlink}{$linkdir}
              };
            $CACHE{$self}{$src}{getVirtualLinkTarget}{$linkdir} =
              \@linkdirkeys;
        }
        foreach
          my $link ( @{ $CACHE{$self}{$src}{getVirtualLinkTarget}{$linkdir} } )
        {
            $target =~
s/^\Q$linkdir$link\E(\/?|\/.+)?$/$main::BACKEND_CONFIG{$main::BACKEND}{fsvlink}{$linkdir}{$link}$1/xms
              && last;
        }
    }
    return $target;
}

sub add_slash {
    # my ($self, $filename, $cond) = @_;
    return $_[1] .=
      ( !defined $_[2] || $_[2] ) && $_[1] !~ m{/$}xms ? q{/} : q{};
}

sub remove_slash {
    # my ($self, $filename ) = @_;
    return $_[1] =~ s{/$}{}xms;
}
1;
