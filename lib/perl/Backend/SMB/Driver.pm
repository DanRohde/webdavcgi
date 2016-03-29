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

package Backend::SMB::Driver;

use strict;
use warnings;

our $VERSION = '1.0';

use base qw( Backend::Helper);

use Filesys::SmbClient;
use File::Temp qw/ tempfile tempdir /;
use Fcntl qw(:flock);
use CGI::Carp;
use English qw( -no_match_vars );

use DefaultConfig
  qw( $DOCUMENT_ROOT $BACKEND %BACKEND_CONFIG $READBUFSIZE $UMASK $BUFSIZE );
use FileUtils qw( stat2h );

use vars qw( $_SHARESEP %_CACHE %_SMBCLIENT );

sub init {
    my ( $self, $config ) = @_;
    $self->SUPER::init($config);
    $_SHARESEP = $BACKEND_CONFIG{$BACKEND}{sharesep} // q{~};

    ## backup credential cache
    if ( $ENV{KRB5CCNAME} && !exists $ENV{WEBDAVISWRAPPED} ) {
        if ( $ENV{KRB5CCNAME} =~ /^FILE:(.*)$/xms ) {
            my $oldfilename = $1;
            my $newfilename = "/tmp/krb5cc_webdavcgi_$ENV{REMOTE_USER}";
            my ( $in, $out );
            if (
                   $oldfilename ne $newfilename
                && open( $in,  '<', $oldfilename )
                && open( $out, '>', $newfilename )
                && flock $out,
                LOCK_EX | LOCK_NB
              )
            {
                binmode $in;
                binmode $out;
                while ( read $in, my $buffer, $READBUFSIZE ) {
                    print( {$out} $buffer )
                      || carp("Cannot write to $newfilename");
                }
                close($in) || carp("Cannot close $oldfilename.");
                flock $out, LOCK_UN;
                close($out) || carp("Cannot close $newfilename");
            }
            else {
                if ( $oldfilename ne $newfilename ) {
                    carp(
q{Cannot read ticket file (don' t use a setuid / setgid wrapper:}
                          . ( -r $oldfilename ) );
                }

            }
        }
    }
    return $self;
}

sub getSmbClient {
    my ($self) = @_;
    my $rmuser = $ENV{REMOTE_USER} || $ENV{REDIRECT_REMOTE_USER};

    if ( -e "/tmp/krb5cc_webdavcgi_$rmuser" ) {
        $ENV{KRB5CCNAME} = "FILE:/tmp/krb5cc_webdavcgi_$rmuser";
    }

    if ( exists $_SMBCLIENT{$rmuser} ) { return $_SMBCLIENT{$rmuser}; }
    return $_SMBCLIENT{$rmuser} = Filesys::SmbClient->new(
        username  => $ENV{SMBUSER},
        password  => $ENV{SMBPASSWORD},
        workgroup => $ENV{SMBWORKGROUP}
      )
      if exists $ENV{SMBUSER}
      && exists $ENV{SMBPASSWORD}
      && exists $ENV{SMBWORKGROUP};
    return $_SMBCLIENT{$rmuser} = Filesys::SmbClient->new(
        username => _get_full_username(),
        flags    => Filesys::SmbClient::SMB_CTX_FLAG_USE_KERBEROS
    );
}

sub finalize {
    %_CACHE = ();
    return 1;
}

sub _read_dir_root {
    my ( $self, $base, $limit, $filter ) = @_;
    my @files;
    my $dom =
      $BACKEND_CONFIG{$BACKEND}{domains}{ _get_user_domain() };
    foreach my $fserver ( keys %{ $dom->{fileserver} } ) {
        if (   exists $dom->{fileserver}{$fserver}{usershares}
            && exists $dom->{fileserver}{$fserver}{usershares}
            { _get_username() } )
        {
            push @files,
              split /,\s/xms,
              $fserver . $_SHARESEP . join ", $fserver$_SHARESEP",
              @{ $dom->{fileserver}{$fserver}{usershares}{ _get_username() } };
            next;
        }
        if ( exists $dom->{fileserver}{$fserver}{shares} ) {
            my $scounter = -1;
            foreach my $share ( @{ $dom->{fileserver}{$fserver}{shares} } ) {
                $scounter++;
                my $shareidx = undef;
                my $path     = $fserver . $_SHARESEP . $share;
                if ( $path =~ s{:?(/.*)$}{}xms ) {
                    $shareidx = $scounter;
                    $path .= $_SHARESEP . $shareidx;
                }
                push @files, $path;
            }

#push @files, split(/, /, $fserver.$_SHARESEP.join(", $fserver$_SHARESEP",@{$dom->{fileserver}{$fserver}{shares}}) );
            next;
        }
        if ( $fserver eq q{} ) {
            ## ignore empty entries
            next;
        }
        my $smbclient = self->getSmbClient();
        if ( my $dir = $smbclient->opendir("smb://$fserver/") ) {
            my $sfilter = _get_share_filter(
                $dom->{fileserver}{$fserver},
                _get_share_filter(
                    $dom, _get_share_filter( $BACKEND_CONFIG{$BACKEND} )
                )
            );
            while ( my $f = $smbclient->readdir_struct($dir) ) {
                $self->_set_cache_entry(
                    'readDir',
                    "$DOCUMENT_ROOT$fserver$_SHARESEP$$f[1]",
                    { type => $f->[0], comment => $f->[2] }
                );
                if ( $f->[0] == $self->smbclient->SMBC_FILE_SHARE
                    && ( !defined $sfilter || $f->[1] !~ /$sfilter/xms ) )
                {
                    push @files, "$fserver$_SHARESEP$$f[1]";
                }

            }
            $smbclient->closedir($dir);
        }
        else {
            carp("Cannot open dir smb://$fserver/: $ERRNO");
        }
    }
    return \@files;
}

sub readDir {
    my ( $self, $base, $limit, $filter ) = @_;

    my $files = [];

    return $self->_get_cache_entry( 'readDir:list', $base )
      if $self->_exists_cache_entry( 'readDir:list', $base );

    $base .= $base !~ m{/$}xms ? q{/} : q{};
    if ( _is_root($base) ) {
        $files = $self->_read_dir_root( $base, $limit, $filter );
    }
    elsif ( ( my $url = $self->_get_smb_url($base) ) ne $base ) {
        my $maxretries = $BACKEND_CONFIG{$BACKEND}{retries} // 1;
        my $trycounter = 0;
        my $dir;
        while ( !$dir && ++$trycounter <= $maxretries ) {
            if ( $dir = $self->getSmbClient()->opendir($url) ) {
                while ( my $f = $self->getSmbClient()->readdir_struct($dir) ) {
                    last if defined $limit && $#{$files} >= $limit;
                    next if $self->filter( $filter, $base, $f->[1] );
                    $self->_set_cache_entry( 'readDir', "$base$$f[1]",
                        { type => $f->[0], comment => $f->[2] } );
                    push @{$files}, $f->[1];
                }
                $self->getSmbClient()->closedir($dir);
            }
            else {
                carp(
                    "Cannot open dir $url: $ERRNO\nKRB5CCNAME=$ENV{KRB5CCNAME}"
                );
            }
        }
    }
    $self->_set_cache_entry( 'readDir:list', $base, $files );
    return $files;
}

sub _get_share_filter {
    my ( $data, $filter ) = @_;
    my $fh = $data->{usersharefilter}{ _get_username() }
      // $data->{usersharefilter}{ _get_full_username() }
      // $data->{sharefilter};
    $filter = $fh ? q{(} . join( q{|}, @{$fh} ) . q{)} : $filter;
    return $filter;
}

sub isFile {
    my ( $self, $file ) = @_;
    return
         !_is_root($file)
      && !_is_share($file)
      && $self->_get_type($file) == $self->getSmbClient()->SMBC_FILE;
}

sub isDir {
    my ( $self, $file ) = @_;
    if ( !$self->_is_allowed($file) ) { return 0; }
    return $self->_exists_cache_entry( 'isDir', $file )
      ? $self->_get_cache_entry( 'isDir', $file )
      : $self->_set_cache_entry(
        'isDir',
        $file,
        _is_root($file)
          || _is_share($file)
          || $self->_get_type($file) == $self->getSmbClient()->SMBC_DIR
      );
}

sub _is_allowed {
    my ( $self, $file ) = @_;
    if ( $self->_exists_cache_entry( '_is_allowed', $file ) ) {
        return $self->_get_cache_entry( '_is_allowed', $file );
    }
    my ( $server, $share, $path, $shareidx ) = _get_path_info($file);
    my $userdomain = _get_user_domain();
    my $sregex =
         defined $server
      && defined $userdomain
      && ref(
        $BACKEND_CONFIG{$BACKEND}{domains}{$userdomain}{fileserver}{$server}
          {shares} ) eq 'ARRAY'
      ? '^(?:'
      . join(
        q{|},
        @{
            $BACKEND_CONFIG{$BACKEND}{domains}{$userdomain}{fileserver}
              {$server}{shares}
        }
      )
      . ')$'
      : q{^$};
    return $self->_set_cache_entry(
        '_is_allowed',
        $file,
        !$BACKEND_CONFIG{$BACKEND}{secure}
          || _is_root($file)
          || (
            exists $BACKEND_CONFIG{$BACKEND}
            {domains}{$userdomain}{fileserver}{$server}
            && !
            exists $BACKEND_CONFIG{$BACKEND}
            {domains}{$userdomain}{fileserver}{$server}{shares} )
          || (
            exists $BACKEND_CONFIG{$BACKEND}
            {domains}{$userdomain}{fileserver}{$server}
            && $shareidx
            && exists $BACKEND_CONFIG{$BACKEND}
            {domains}{$userdomain}{fileserver}{$server}{shares}[$shareidx] )
          || $share =~ /$sregex/i
    );
}

sub isLink {
    my ( $self, $file ) = @_;
    return $self->_exists_cache_entry( 'isLink', $file )
      ? $self->_get_cache_entry( 'isLink', $file )
      : $self->_set_cache_entry( 'isLink', $file,
        $self->_get_type($file) == $self->getSmbClient()->SMBC_LINK );
    return 0;
}

sub isEmpty {
    my ( $self, $file ) = @_;
    if ( my $stat = stat2h( $self->stat($file) ) ) {
        return $stat->{size} == 0;
    }
    return 1;
}

sub stat {
    my ( $self, $file ) = @_;

    return @{ $self->_get_cache_entry( 'stat', $file ) }
      if $self->_exists_cache_entry( 'stat', $file );

    my @stat;
    my $time = time;
    if ( _is_root($file) || _is_share($file) ) {
        @stat = ( 0, 0, oct(755), 0, 0, 0, 0, 0, $time, $time, $time, 0, 0 );
    }
    else {
        if ( $file =~
            /^\Q$DOCUMENT_ROOT\E[^\Q$_SHARESEP\E]+\Q$_SHARESEP\E.*$/xms )
        {
            @stat = $self->getSmbClient()->stat( $self->_get_smb_url($file) );
            if ( $#stat > 0 ) {
                my (@a) = splice @stat, 8, 2;
                push @stat, @a;

                #$stat[2]=0755;
            }
            else {
                @stat = CORE::lstat($file);
            }
        }
        else {
            @stat = CORE::lstat($file);
        }
    }
    if (@stat) { $self->_set_cache_entry( 'stat', $file, \@stat ); }
    return @stat;
}

sub lstat {
    my ( $self, $file ) = @_;
    return $self->stat($file);
}

sub copy {
    my ( $self, $src, $dst ) = @_;
    if (
        (
            my $srcfh =
            $self->getSmbClient()->open( '<' . $self->_get_smb_url($src) )
        )
        && ( my $dstfh =
            $self->getSmbClient()
            ->open( '>' . $self->_get_smb_url($dst), oct(7777) ^ $UMASK ) )
      )
    {
        while ( my $buffer = $self->getSmbClient()->read( $srcfh, $BUFSIZE ) ) {
            $self->getSmbClient()->write( $dstfh, $buffer );
        }
        $self->getSmbClient()->close($srcfh);
        $self->getSmbClient()->close($dstfh);
        $self->finalize();
        return 1;
    }
    return 0;
}

sub printFile {
    my ( $self, $file, $fh, $pos, $count ) = @_;
    my $bufsize = defined $count && $count < $BUFSIZE ? $count : $BUFSIZE;
    my $smbclient = $self->getSmbClient();
    $fh //= \*STDOUT;
    if ( my $rd = $smbclient->open( $self->_get_smb_url($file) ) ) {
        my $bytecount = 0;
        if ($pos) { $smbclient->seek( $rd, $pos ); }
        while ( my $buffer = $smbclient->read( $rd, $bufsize ) ) {
            print( {$fh} $buffer ) || carp("Cannot print file $file to $fh.");
            $bytecount += bytes::length($buffer);
            if ( defined $count && $bytecount >= $count ) { last; }
            if ( defined $count && ( $bytecount + $bufsize > $count ) ) {
                $bufsize = $count - $bytecount;
            }
        }
        $smbclient->close($rd);
        return 1;
    }
    return 0;
}

sub saveStream {
    my ( $self, $path, $fh ) = @_;
    if ( my $rd =
        $self->getSmbClient()->open( '>' . $self->_get_smb_url($path) ) )
    {
        while ( read( $fh, my $buffer, $BUFSIZE ) > 0 ) {
            $self->getSmbClient()->write( $rd, $buffer );
        }
        $self->getSmbClient()->close($rd);
        $self->finalize();
        return 1;
    }
    return 0;
}

sub saveData {

    #my ($self, $path, $data, $append) = @_;
    if ( my $rd =
        $_[0]->getSmbClient()
        ->open( '>' . ( $_[3] ? '>' : q{} ) . $_[0]->_get_smb_url( $_[1] ) ) )
    {
        $_[0]->getSmbClient()->write( $rd, $_[2] );
        $_[0]->getSmbClient()->close($rd);
        $_[0]->finalize();
        return 1;
    }
    return 0;
}

sub getLocalFilename {
    my ( $self, $file ) = @_;
    if ( $self->exists($file) ) {
        my $suffix = $file =~ m{([.][^./]+)$}xms ? $1 : undef;
        my ( $fh, $filename ) = tempfile(
            TEMPLATE => '/tmp/webdavcgiXXXXX',
            CLEANUP  => 1,
            SUFFIX   => $suffix
        );
        $self->printFile( $file, $fh );
        close($fh) || carp("Cannot close $file.");
        my $stat = stat2h( $self->stat($file) );
        utime $stat->{atime}, $stat->{mtime}, $filename;
        return $filename;
    }
    return $file;
}

sub getFileContent {
    my $content;
    if ( my $fh =
        $_[0]->getSmbClient()->open( q{<} . $_[0]->_get_smb_url( $_[1] ) ) )
    {
        $content = $_[0]->getSmbClient()
          ->read( $fh, $_[2] || stat2h( $_[0]->stat( $_[1] ) )->{size} );
        $_[0]->getSmbClient()->close($fh);
    }
    return $content;
}

sub _check_can_open_dir {
    my ( $self, $file ) = @_;
    if ( !$self->_is_allowed($file) || !$self->exists($file) ) {
        return 0;
    }
    if ( !$self->isDir($file) ) {
        return 1;
    }
    if ( my $dir =
        $self->getSmbClient()->opendir( $self->_get_smb_url($file) ) )
    {
        $self->getSmbClient()->closedir($dir);
        return 1;
    }
    return 0;
}

sub isReadable {
    my ( $self, $file ) = @_;
    return $self->_exists_cache_entry( 'isReadable', $file )
      ? $self->_get_cache_entry( 'isReadable', $file )
      : $self->_set_cache_entry(
        'isReadable',
        $file,
        _is_root($file) || _is_share($file) || $self->_check_can_open_dir($file)
      );
}

sub isWriteable {
    my ( $self, $file ) = @_;
    return !_is_root($file) && $self->exists($file);
}

sub isExecutable {
    my ( $self, $file ) = @_;
    return
         _is_root($file)
      || _is_share($file)
      || $self->isDir($file);
}

sub exists {
    my ( $self, $file ) = @_;
    if ( !$self->_is_allowed($file) ) {
        return 0;
    }
    return 1
      if _is_root($file)
      || _is_share($file)
      || $self->_exists_cache_entry( 'readDir', $file );
    my @stat = $self->stat($file);
    return $#stat > 0;
}

sub mkcol {
    my ( $self, $file ) = @_;
    return $self->getSmbClient()->mkdir( $self->_get_smb_url($file), $UMASK )
      && $self->finalize();
}

sub unlinkFile {
    my ( $self, $file ) = @_;
    my $ret =
        $self->isDir($file)
      ? $self->getSmbClient()->rmdir_recurse( $self->_get_smb_url($file) )
      : $self->getSmbClient()->unlink( $self->_get_smb_url($file) );
    if   ( !$ret ) { carp("Could not delete $file: $!"); }
    else           { $self->finalize(); }
    return $ret;
}

sub deltree {
    my ( $self, $path ) = @_;
    return $self->unlinkFile($path);
}

sub rename {
    my ( $self, $on, $nn ) = @_;
    return $self->getSmbClient()
      ->rename( $self->_get_smb_url($on), $self->_get_smb_url($nn) )
      && $self->finalize();
}

sub resolve {
    my ( $self, $fn ) = @_;
    $fn =~ s{([^/]*)/[.]{2}(/?.*)}{$1}xms;    # eliminate /../
    $fn =~ s{/$}{}xms;                        # remove trailing slash
    $fn =~ s{//}{/}xmsg;                      # replace // with /
    return $fn;
}

sub resolveVirt {
    my ( $self, $fn ) = @_;
    return $self->SUPER::resolveVirt( $self->_get_smb_url($fn) );
}

sub getParent {
    my ( $self, $file ) = @_;
    return $self->dirname($file);
}

sub getDisplayName {
    my ( $self, $file ) = @_;
    my $name;
    if ( _is_share($file) ) {
        my ( $server, $share, $path, $shareidx ) = _get_path_info($file);
        my $fs =
          $BACKEND_CONFIG{$BACKEND}{domains}
          { _get_user_domain() }{fileserver}{$server};
        my $initdir = undef;
        if ( defined $shareidx
            && $fs->{shares}[$shareidx] =~ m{:?(/.*)}xms )
        {
            $initdir = $1;
            $name //= $fs->{sharealiases}{"$share:$initdir"}
              // $fs->{sharealiases}{"$share$initdir"};
        }
        $name //= $fs->{sharealiases}{$share};
        if (  !defined $name
            && exists $fs->{sharealiases}{_USERNAME_}
            && $share eq _get_username() )
        {
            $name //= $fs->{sharealiases}{_USERNAME_};
        }
        if ( !defined $name ) {
            $name = $self->basename($file);
            my $cf = $self->_get_cache_entry( 'readDir', $file );
            my $comment = defined $cf ? $cf->{comment} : undef;
            $name .= defined $comment ? q{ ( } . $comment . q{ )/} : q{/};
        }
    }
    if ( !defined $name && $self->basename($file) ne q{/} ) {
        $name =
          $self->basename($file)
          . (   !$self->_exists_cache_entry( 'readDir', $file )
              || $self->isDir($file) ? q{/} : q{} );
    }
    return $name // $file;
}

sub _get_full_username {
    return $ENV{REMOTE_USER} =~ /\@/xms
      ? $ENV{REMOTE_USER}
      : $ENV{REMOTE_USER} . q{@} . _get_user_domain();
}

sub _get_username {
    if ( $ENV{REMOTE_USER} =~ /^([^\@]+)/xms ) {
        return $1;
    }
    return $ENV{REMOTE_USER};
}

sub _get_user_domain {
    my $domain;
    if ( $ENV{REMOTE_USER} =~ /\@(.*)$/xms ) {
        $domain = $1;
    }
    else {
        $domain = $BACKEND_CONFIG{$BACKEND}{defaultdomain};
    }
    return $domain;
}

sub _is_root {
    return $_[0] eq $DOCUMENT_ROOT;
}

sub _is_share {

    return $_[0] =~
      m{^\Q$DOCUMENT_ROOT\E[^\Q$_SHARESEP\E]+\Q$_SHARESEP\E[^/]+/?$}xms;
}
sub S_ISLNK  { return ( $_[0] & oct 120_000 ) == oct 120_000; }
sub S_ISDIR  { return ( $_[0] & oct 40_000 ) == oct 40_000; }
sub S_ISFILE { return ( $_[0] & oct 100_000 ) == oct 100_000; }

sub _get_type {
    my ( $self, $file ) = @_;
    if ( !$self->_exists_cache_entry( 'readDir', $file ) ) {
        my @stat = $self->stat($file);
        return 0 if scalar(@stat) == 0;
        $self->_set_cache_entry(
            'readDir',
            $file,
            {
                  type => S_ISLNK( $stat[2] ) ? $self->getSmbClient()->SMBC_LINK
                : S_ISDIR( $stat[2] ) ? $self->getSmbClient()->SMBC_DIR
                : $self->getSmbClient()->SMBC_FILE,
                comment => q{}
            }
        );
    }
    return ${ $self->_get_cache_entry( 'readDir', $file ) }{type}
      || 0;
}

sub _get_cache_entry {
    my ( $self, $id, $file ) = @_;
    $file =~ s{/$}{}xms;
    return $_CACHE{$self}{$file}{$id};
}

sub _set_cache_entry {
    my ( $self, $id, $file, $value ) = @_;
    $file =~ s{/$}{}xms;
    return $_CACHE{$self}{$file}{$id} = $value;
}

sub _exists_cache_entry {
    my ( $self, $id, $file ) = @_;
    $file =~ s{/$}{}xms;
    return
         exists $_CACHE{$self}{$file}
      && exists $_CACHE{$self}{$file}{$id}
      && defined $_CACHE{$self}{$file}{$id};
}

sub _get_path_info {
    my ($file) = @_;
    my ( $server, $share, $path, $shareidx ) = ( q{}, q{}, $file, undef );
    if ( $file =~
/^\Q$DOCUMENT_ROOT\E([^\Q$_SHARESEP\E]+)\Q$_SHARESEP\E([^\/\Q$_SHARESEP\E]+)(\Q$_SHARESEP\E(\d+))?(.*)$/xms
      )
    {
        ( $server, $share, $path, $shareidx ) = ( $1, $2, $5, $4 );
    }
    return ( $server, $share, $path, $shareidx );
}

sub _get_smb_url {
    my ( $self, $file ) = @_;
    my $url = $file;
    my $fs =
      $BACKEND_CONFIG{$BACKEND}{domains}{ _get_user_domain() }{fileserver};
    if ( $file =~
/^\Q$DOCUMENT_ROOT\E([^\Q$_SHARESEP\E]+)\Q$_SHARESEP\E([^\/\Q$_SHARESEP\E]*)(\Q$_SHARESEP\E(\d+))?(\/.*)?$/xms
      )
    {
        my ( $server, $share, $initdir, $path, $shareidx ) =
          ( $1, $2, $fs->{$1}{initdir}{$2}, $5, $4 );

        if ( defined $shareidx
            && $fs->{$server}{shares}[$shareidx] =~ m{:?(/.*)}xms )
        {
            $initdir = $1;
        }

        $url = "smb://$server/$share";
        $url .= defined $initdir ? $initdir : q{};
        if ( defined $path ) {
            $path =~ s/[*<>?|:"\\]/_/xmsg;
            $url .= $path;
        }
    }
    return $url;
}

sub changeFilePermissions {
    return 0;
}
sub hasSetUidBit  { return 0; }
sub hasSetGidBit  { return 0; }
sub changeMod     { return 0; }
sub isBlockDevice { return 0; }
sub isCharDevice  { return 0; }
sub createSymLink { return 0; }
sub getLinkSrc    { return; }
sub hasStickyBit  { return 0; }

sub _quote_single_quotes {
    my ( $self, $str ) = @_;
    if ( defined $str ) {
        $str =~ s/'/\\'/xmsg;
    }
    return $str;
}

sub getQuota {
    my ( $server, $share, $path, $shareidx ) =
      _get_path_info( $_[1] );
    $server = $_[0]->_quote_single_quotes($server);
    $share  = $_[0]->_quote_single_quotes($share);
    $path   = $_[0]->_quote_single_quotes($path);
    $path //= q{/};
    my $fs = $BACKEND_CONFIG{$BACKEND}{domains}
      { _get_user_domain() }{fileserver}{$server};
    my $initdir = $fs->{initdir}{$share};
    if ( defined $shareidx
        && $fs->{shares}[$shareidx] =~ m{:?(/.*)}xms )
    {
        $initdir = $1;
    }
    if ( defined $initdir ) { $path = "$initdir/$path"; }
    return ( 0, 0 )
      if !$share
      || $share eq q{}
      || ( defined $fs->{quota}{$share} && !$fs->{quota}{$share} )
      || (!defined $fs->{quota}{$share}
        && defined $BACKEND_CONFIG{$BACKEND}{quota}
        && !$BACKEND_CONFIG{$BACKEND}{quota} );
    my $smbclient =
         exists $ENV{SMBWORKGROUP}
      && exists $ENV{SMBUSER} && exists $ENV{SMBPASSWORD}
      ? "/usr/bin/smbclient '//$server/$share' '$ENV{SMBPASSWORD}' -U '$ENV{SMBUSER}' -W '$ENV{SMBWORKGROUP}' -D '$path' -c du"
      : "/usr/bin/smbclient -k '//$server/$share' -D '$path' -c du";
    if ( $server && open my $c, q{-|}, "$smbclient 2>/dev/null" ) {
        my @l = <$c>;
        close($c) || carp("Cannot close $smbclient handle.");
        if ( @l && $l[1] =~ /^\D+(\d+)\D+(\d+)\D+(\d+)/xms ) {
            my ( $b, $s, $a ) = ( $1, $2, $3 );
            return ( $b * $s, ( $b - $a ) * $s );
        }
    }
    return ( 0, 0 );
}
1;
