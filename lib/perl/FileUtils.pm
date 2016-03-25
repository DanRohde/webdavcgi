#########################################################################
# (C) ZE CMS, Humboldt-Universitaet zu Berlin
# Written 2010-2016 by Daniel Rohde <d.rohde@cms.hu-berlin.de>
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

package FileUtils;

use strict;
use warnings;

our $VERSION = '1.0';

use base qw( Exporter );
our @EXPORT_OK =
  qw( get_dir_info get_local_file_content_and_type move2trash rcopy read_dir_by_suffix
  rmove is_hidden filter get_error_document stat2h )
  ;

use CGI;
use CGI::Carp;

use English qw( -no_match_vars );

use HTTPHelper qw( get_etag );
use CacheManager;

use vars qw( $_INSTANCE );

sub rcopy {
    my ( $src, $dst, $move, $depth ) = @_;

    my $backend = main::getBackend();

    $depth //= 0;

    return 0
      if defined $main::LIMIT_FOLDER_DEPTH
      && $main::LIMIT_FOLDER_DEPTH > 0
      && $depth > $main::LIMIT_FOLDER_DEPTH;

    # src == dst ?
    return 0 if $src eq $dst;

# src == dst ?
#   return 0 if $backend->getLinkSrc($src) eq $backend->getLinkSrc($dst); # litmus fails (why?)

    # src in dst?
    return 0 if $backend->isDir($src) && $dst =~ /^\Q$src\E/xms;

    # src exists and can copy?
    return 0
      if !$backend->exists($src)
      || ( !$move && !$backend->isReadable($src) );

    # src moveable because writeable?
    return 0 if $move && !$backend->isWriteable($src);

    # dst writeable?
    return 0 if $backend->exists($dst) && !$backend->isWriteable($dst);

    my $nsrc = $src;
    $nsrc =~ s/\/$//xms;    ## remove trailing slash for link test (-l)

    if ( $backend->isLink($nsrc) ) {    # link
        if ( !$move || !$backend->rename( $nsrc, $dst ) ) {
            my $orig = $backend->getLinkSrc($nsrc);
            $dst =~ s/\/$//xms;
            my $ret = $backend->createSymLink( $orig, $dst );
            if ( $ret && $move ) { $ret = $backend->unlinkFile($nsrc); }
            return $ret;
        }
    }
    elsif ( $backend->isFile($src) ) {    # file
        if ( $backend->isDir($dst) ) {
            $dst .= $dst !~ /\/$/xms ? q{/} : q{};
            $dst .= $backend->basename($src);
        }
        if ( !$move || !$backend->rename( $src, $dst ) ) {
            if ( !$backend->copy( $src, $dst ) ) { return 0; }
            if ($move) {
                if (  !$backend->isWriteable($src)
                    || $backend->unlinkFile($src) )
                {
                    return 0;
                }
            }
        }
    }
    elsif ( $backend->isDir($src) ) {

        # cannot write folders to files:
        return 0 if $backend->isFile($dst);

        $dst .= $dst !~ /\/$/xms ? q{/} : q{};
        $src .= $src !~ /\/$/xms ? q{/} : q{};

#if (!$move || get_dir_info($src,'realchildcount')>0 || !$backend->rename($src,$dst)) {  ## doesn't work with GIT backend; why did I do this shit?
        if ( !$move || !$backend->rename( $src, $dst ) ) {
            if ( !$backend->exists($dst) )     { $backend->mkcol($dst); }
            if ( !$backend->isReadable($src) ) { return 0; }
            my $rret = 1;
            foreach my $filename ( @{ $backend->readDir($src) } ) {
                $rret = $rret
                  && rcopy( $src . $filename, $dst . $filename,
                    $move, $depth + 1 );
            }
            if ($move) {
                if (   !$rret
                    || !$backend->isWriteable($src)
                    || !$backend->deltree($src) )
                {
                    return 0;
                }
            }
        }
    }
    else {
        return 0;
    }

    #BUGFIX: properties have no trailing slash
    $src =~ s{/$}{}xms;
    $dst =~ s{/$}{}xms;
    main::broadcast(
        $move ? 'FILEMOVED' : 'FILECOPIED',
        {
            file        => $src,
            destination => $dst,
            depth       => $depth,
            overwrite   => 'T',
            size        => ( $backend->stat($src) )[7] // 0,
        },
    );
    return 1;
}

sub rmove {
    my ( $src, $dst ) = @_;
    return rcopy( $src, $dst, 1 );
}


sub get_local_file_content_and_type {
    my ( $fn, $default, $defaulttype ) = @_;
    my $content = q{};
    if ( -e $fn && !-d $fn && open my $F, '<', $fn ) {
        {
            local $RS = undef;
            $content = <$F>;
        };
        close($F) || croak("Cannot close filehandle for '$fn'.");
        $defaulttype = main::get_mime_type($fn);
    }
    else {
        $content = $default;
    }
    return ( $defaulttype, $content );
}

sub move2trash {
    my ($fn)    = @_;
    my $backend = main::getBackend();
    my $ret     = 0;
    my $etag    = get_etag($fn);        ## get a unique name for trash folder
    $etag =~ s/\"//xmsg;
    my $trash = "$main::TRASH_FOLDER$etag/";

    if ( $fn =~ /^\Q$main::TRASH_FOLDER\E/xms ) {    ## delete within trash
        my @err;
        $ret += $backend->deltree( $fn, \@err );
        if ( $#err >= 0 ) { $ret = 0; }
        main::debug("move2trash($fn)->/dev/null = $ret");
    }
    elsif ($backend->exists($main::TRASH_FOLDER)
        || $backend->mkcol($main::TRASH_FOLDER) )
    {
        if ( $backend->exists($trash) ) {
            my $i = 0;
            while ( $backend->exists($trash) ) {     ## find unused trash folder
                $trash = "$main::TRASH_FOLDER$etag" . ( $i++ ) . q{/};
            }
        }
        $ret = $backend->mkcol($trash)
          && rmove( $fn, $trash . $backend->basename($fn) ) ? 1 : 0;
        main::debug("move2trash($fn)->$trash = $ret");
    }
    return $ret;
}

sub read_dir_by_suffix {
    my ( $fn, $base, $hrefs, $suffix, $depth, $visited ) = @_;
    debug("read_dir_by_suffix($fn, ..., $suffix, $depth)");
    my $backend = main::getBackend();

    my $nfn = $backend->resolve($fn);
    return
      if exists ${$visited}{$nfn} && ( $depth eq 'infinity' || $depth < 0 );
    ${$visited}{$nfn} = 1;

    if ( $backend->isReadable($fn) ) {
        foreach my $sf (
            @{ $backend->readDir( $fn, main::getFileLimit($fn), \&filter ) } )
        {
            $sf .= $backend->isDir( $fn . $sf ) ? q{/} : q{};
            my $nbase = $base . $sf;
            if ( $backend->isFile( $fn . $sf ) && $sf =~ /[.]\Q$suffix\E/xms ) {
                push @{$hrefs}, $nbase;
            }
            if ( $depth != 0 && $backend->isDir( $fn . $sf ) ) {
                read_dir_by_suffix(
                    $fn . $sf, $nbase,     $hrefs,
                    $suffix,   $depth - 1, $visited
                );
            }
            ## XXX add only files with requested components
            ## XXX filter (comp-filter > comp-filter >)
        }
    }
    return;
}

sub get_dir_info {
    my ( $fn, $prop, $filter, $limit, $max ) = @_;
    my $cm = CacheManager::getinstance();
    if ( $cm->exists_entry( [ 'get_dir_info', $fn, $prop ] ) ) {
        return $cm->get_entry( [ 'get_dir_info', $fn, $prop ] );
    }

    my $backend = main::getBackend();

    my %counter = (
        childcount   => 0,
        visiblecount => 0,
        objectcount  => 0,
        hassubs      => 0,
    );
    if ( $backend->isReadable($fn) ) {
        foreach my $f (
            @{ $backend->readDir( $fn, ${$limit}{$fn} || $max, \&filter ) } )
        {
            $counter{realchildcount}++;
            $counter{childcount}++;
            if ( !$backend->isDir("$fn$f") && $f !~ /^[.]/xms ) {
                $counter{visiblecount}++;
            }
            if ( !$backend->isDir("$fn$f") ) {
                $counter{objectcount}++;
            }
        }
    }
    $counter{hassubs} =
      ( $counter{childcount} - $counter{objectcount} > 0 ) ? 1 : 0;

    foreach my $k ( keys %counter ) {
        $cm->set_entry( [ 'get_dir_info', $fn, $k ], $counter{$k} );
    }
    return $counter{$prop} // 0;
}

sub _get_hidden_filter {
    return @main::HIDDEN ? '(' . join( q{|}, @main::HIDDEN ) . ')' : undef;
}

sub is_hidden {
    my ($fn) = @_;
    my $filter = _get_hidden_filter();
    return $filter && $fn =~ /$filter/xms;
}

sub filter {
    my ( $path, $file ) = @_;
    my $hidden = _get_hidden_filter();
    my $filter = defined $path ? $main::FILEFILTERPERDIR{$path} : undef;

    return
         ( defined $file && $file =~ /^[.]{1,2}$/xms )
      || ( defined $filter && defined $file && $file !~ $filter )
      || ( defined $hidden
        && defined $file
        && defined $path
        && "$path$file" =~ /$hidden/xms );
}

sub get_error_document {
    my ( $status, $defaulttype, $default ) = @_;
    $defaulttype //= 'text/plain';
    $default //= $status;
    return exists $main::ERROR_DOCS{$status}
      ? (
        $status,
        get_local_file_content_and_type(
            $main::ERROR_DOCS{$status},
            $default, $defaulttype
        )
      )
      : ( $status, $defaulttype, $default );
}

sub stat2h {
    my (@stat) = @_;

    # map is slower than unpacking arrays to vars !
    my (
        $dev,  $ino,   $mode,  $nlink, $uid,     $gid, $rdev,
        $size, $atime, $mtime, $ctime, $blksize, $blocks
    ) = $#stat == 0 && ref $stat[0] eq 'ARRAY' ? @{ $stat[0] } : @stat;
    return {
        dev     => $dev,
        ino     => $ino,
        mode    => $mode,
        nlink   => $nlink,
        uid     => $uid,
        gid     => $gid,
        rdev    => $dev,
        size    => $size,
        atime   => $atime,
        mtime   => $mtime,
        ctime   => $ctime,
        blksize => $blksize,
        blocks  => $blocks,
    };
}

1;
