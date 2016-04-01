#########################################################################
# (C) ZE CMS, Humboldt-Universitaet zu Berlin
# Written 2015 by Daniel Rohde <d.rohde@cms.hu-berlin.de>
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

package Backend::S3B::Driver;

use strict;
use warnings;

our $VERSION = '1.0';

use base qw( Backend::Helper );

use CGI::Carp;
use Amazon::S3;
use Digest::SHA qw( sha512_base64 );
use File::Temp qw( tempfile tempdir );
use Date::Parse;

use Data::Dumper;

use DefaultConfig
  qw( $READBUFSIZE $DOCUMENT_ROOT $UMASK $BACKEND %BACKEND_CONFIG );
use HTTPHelper qw( get_mime_type );

use vars qw( $S3 %CACHE );

sub finalize {
    $S3    = undef;
    %CACHE = ();
    return;
}

sub initialize {
    my ($self) = @_;
    $S3 //= Amazon::S3->new(
        {
            aws_access_key_id     => $BACKEND_CONFIG{$BACKEND}{access_id},
            aws_secret_access_key => $BACKEND_CONFIG{$BACKEND}{secret_key},
            host                  => $BACKEND_CONFIG{$BACKEND}{host},
            secure                => defined $BACKEND_CONFIG{$BACKEND}{secure}
            ? $BACKEND_CONFIG{S3B}{secure}
            : 1,
            retry   => $BACKEND_CONFIG{$BACKEND}{retry},
            timeout => $BACKEND_CONFIG{$BACKEND}{timeout} // 60
        }
    );
    $self->{bucketprefix} = $BACKEND_CONFIG{$BACKEND}{bucketprefix};
    return;
}

sub readDir {
    my ( $self, $fn, $limit, $filter ) = @_;
    $self->initialize();
    my @list;
    if ( $self->_is_root($fn) ) {
        my $buckets = $S3->buckets();
        foreach my $b ( @{ $buckets->{buckets} } ) {
            my $bn = $b->{bucket};
            if ( $self->{bucketprefix} ) {
                $bn =~ s/^\Q$self->{bucketprefix}//xms;
            }
            $self->_fill_stat_cache( $fn . $bn, $b );
            push @list, $bn;
        }
    }
    elsif ( $self->_is_bucket($fn) && !$self->SUPER::isDir($fn) ) {
        my $l =
          $S3->list_bucket_all( { bucket => $self->_get_bucket_name($fn) } );
        foreach my $key ( @{ $l->{keys} } ) {
            my $file = $key->{key};
            my $full = $fn . $file;
            $self->_fill_stat_cache( $full, $key );
            push @list, $key->{key};
        }
    }
    return \@list;
}

sub unlinkFile {
    my ( $self, $fn ) = @_;
    my $ret = 0;
    $self->initialize();
    $fn = $self->resolve($fn);
    if ( $self->_is_root($fn) ) {
        $ret = 0;
    }
    elsif ( $self->_is_bucket($fn) ) {
        $ret = $S3->delete_bucket( { bucket => $self->_get_bucket_name($fn) } );
    }
    else {
        my $bucket = $S3->bucket( $self->_get_bucket_name($fn) );
        $ret = $bucket && $bucket->delete_key( $self->basename($fn) );
    }
    return $ret;
}

sub deltree {
    my ( $self, $fn ) = @_;
    my $ret = 1;
    $self->initialize();
    $fn = $self->resolve($fn);
    if ( $self->_is_root($fn) || $self->_is_bucket($fn) ) {
        my $list = $self->readDir($fn);
        foreach my $f ( @{$list} ) {
            $ret &= $self->deltree( $fn . q{/} . $f );
        }
    }
    $ret &= $self->unlinkFile($fn);
    return $ret;
}

sub isLink {
    return 0;
}

sub isDir {
    return $_[0]->_is_root( $_[1] ) || $_[0]->_is_bucket( $_[1] );
}

sub isFile {
    return !$_[0]->isDir( $_[1] );
}

sub rename {
    my ( $self, $on, $nn ) = @_;
    $on = $self->resolve($on);
    $nn = $self->resolve($nn);
    return $self->copy( $on, $nn ) && $self->deltree($on);
}

sub copy {
    my ( $self, $src, $dst ) = @_;
    my $ret = 1;
    $src = $self->resolve($src);
    $dst = $self->resolve($dst);
    if ( $self->_is_root($src) ) {
        $ret = 0;
    }
    elsif ( $self->_is_bucket($src) ) {
        if ( $self->_is_root( $self->dirname($dst) ) ) {
            $self->mkcol($dst) || return 0;
        }
        my @list = $self->readDir($src);
        foreach my $f (@list) {
            $ret &= $self->copy( $src . q{/} . $f, $dst );
        }
    }
    elsif ( $self->_is_bucket( $self->dirname($src) ) ) {
        $ret =
          !$self->_is_root($dst)
          && ( $self->_is_bucket($dst)
            || $self->_is_bucket( $self->dirname($dst) ) )
          ? $self->saveData( $dst, $self->getFileContent($src) )
          : 0;
    }
    return $ret;
}

sub mkcol {
    my ( $self, $fn ) = @_;
    $self->initialize();
    my $ret = 0;
    if ( $self->_is_root( $self->dirname($fn) ) ) {
        $ret = $S3->add_bucket( { bucket => $self->_get_bucket_name($fn) } );
        if ( !$ret ) { carp( $S3->err . ': ' . $S3->errstr ); }
    }
    return $ret;
}
sub isReadable   { return 1; }
sub isWriteable  { return 1; }
sub isExecutable { return $_[0]->isDir( $_[1] ); }

sub hasSetUidBit  { return 0; }
sub hasSetGidBit  { return 0; }
sub changeMod     { return 0; }
sub isBlockDevice { return 0; }
sub isCharDevice  { return 0; }
sub getLinkSrc    { return; }
sub createSymLink { return 0; }
sub hasStickyBit  { return 0; }

sub exists {
    my ( $self, $fn ) = @_;
    return 1 if $self->_is_root($fn) || $self->_is_bucket($fn);
    $fn = $self->resolve($fn);
    $self->initialize();
    my $bucket = $S3->bucket( $self->_get_bucket_name($fn) );
    return $bucket->head_key( $self->basename($fn) );
}

sub stat {
    my ( $self, $fn ) = @_;
    return ( 0, 0, $UMASK, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 )
      if $self->_is_root($fn);
    if ( !exists $CACHE{stat}{$fn} && !$self->_is_bucket($fn) ) {
        my $bucketdir = $self->_get_bucket_dirname($fn);
        return $self->SUPER::stat($fn) if !$self->_is_bucket($bucketdir);
        my $bucket = $S3->bucket( $self->_get_bucket_name($fn) );
        $self->_fill_stat_cache( $fn,
            $bucket->head_key( $self->basename($fn) ) );
    }
    $fn = $self->resolve($fn);
    my $lm =
      $CACHE{stat}{$fn}{last_modified} || $CACHE{stat}{$fn}{creation_date} || 0;
    my $size = $CACHE{stat}{$fn}{size} || 0;
    return ( 0, 0, $UMASK, 0, 0, 0, 0, $size, $lm, $lm, $lm, 0, 0 );
}

sub _is_root {
    return $_[1] eq $DOCUMENT_ROOT;
}

sub _is_bucket {
    my ( $self, $bucketdirname ) = @_;
    if ( !exists $CACHE{buckets} ) { $_[0]->_read_buckets( $_[1] ); }
    my $bn = $self->basename($bucketdirname);
    if ( $self->{bucketprefix} && $bn !~ /^\Q$self->{bucketprefix}\E/xms ) {
        $bn = $self->{bucketprefix} . $bn;
    }
    return $CACHE{buckets}{$bn}
      && $self->_is_root( $self->dirname($bucketdirname) );
}

sub _read_buckets {
    my ($self) = @_;
    $self->initialize();
    my $b = $S3->buckets();
    foreach my $b ( @{ $b->{buckets} } ) {
        my $bn = $b->{bucket};
        $CACHE{buckets}{$bn} = 1;
        if ( $self->{bucketprefix} ) {
            $bn =~ s/^\Q$self->{bucketprefix}\E//xms;
        }
        $self->_fill_stat_cache( $DOCUMENT_ROOT . $bn, $b );
    }
    return;
}

sub _fill_stat_cache {
    my ( $self, $fn, $v ) = @_;
    $CACHE{stat}{$fn} = {
        content_type  => $v->{content_type},
        size          => $v->{size} // $v->{content_length},
        last_modified => str2time( $v->{last_modified} || $v->{creation_date} )
    };
    return;
}

sub _get_bucket_dirname {
    my ( $self, $fn ) = @_;
    if ( $self->_is_bucket($fn) ) {
        return
            $self->dirname($fn)
          . $self->{bucketprefix}
          . $self->basename($fn)
          if $self->{bucketprefix};
        return $fn;
    }
    elsif ( $self->_is_bucket( $self->dirname($fn) ) ) {
        return $self->_get_bucket_dirname( $self->dirname($fn) );
    }
    elsif ( $self->_is_root( $self->dirname($fn) ) ) {
        return
            $self->dirname($fn)
          . $self->{bucketprefix}
          . $self->basename($fn)
          if $self->{bucketprefix};
        return $fn;
    }
    return;
}

sub _get_bucket_name {
    my ( $self, $fn ) = @_;
    my $dn = $self->_get_bucket_dirname($fn);
    return $self->basename( $dn ? $dn : $fn );
}

sub resolve {
    my ( $self, $fn ) = @_;
    $fn =~ s{([^/]*)/[.]{2}(/?.*)}{$1}xms;
    $fn =~ s{/$}{}xms;
    $fn =~ s{//}{/}xmsg;
    return $fn;
}

sub isEmpty {
    return ( $_[0]->stat( $_[1] ) )[7] == 0;
}

sub saveData {

    #my ($self, $path, $data, $append) = @_;
    my $fn = $_[0]->resolve( $_[1] );
    $_[0]->initialize();
    my $bucket = $S3->bucket( $_[0]->_get_bucket_name($fn) );
    my $key    = $_[0]->basename($fn);
    my $mime   = get_mime_type($fn);
    my $ret    = $bucket->add_key( $key, $_[2], { content_type => $mime } );
    if ( !$ret ) { carp( $bucket->err . ': ' . $bucket->errstr ); }
    return $ret;

}

sub saveStream {
    my ( $self, $fn, $fh ) = @_;
    $fn = $self->resolve($fn);
    my $blob;
    while ( read $fh, my $buffer, $READBUFSIZE ) {
        $blob .= $buffer;
    }
    return $self->saveData( $fn, $blob );
}

sub printFile {
    my ( $self, $fn, $fh, $pos, $count ) = @_;
    $fn = $self->resolve($fn);

    if ($pos) {
        print( {$fh} substr $self->getFileContent($fn), $pos, $count )
          || carp("Cannot write to $fn.");
    }
    print( {$fh} $self->getFileContent($fn) ) || carp("Cannot write to $fn.");
    return;
}

sub getLocalFilename {
    my ( $self, $fn ) = @_;
    my $suffix = $fn =~ /([.][^.]+)$/xms ? $1 : undef;
    my ( $fh, $filename ) = tempfile(
        TEMPLATE => '/tmp/webdavcgiXXXXX',
        CLEANUP  => 1,
        SUFFIX   => $suffix
    );
    $self->printFile( $fn, $fh );
    return $filename;
}

sub getFileContent {
    my ( $self, $fn ) = @_;
    $self->initialize();
    $fn = $self->resolve($fn);
    my $bucket = $S3->bucket( $self->_get_bucket_name($fn) );
    my $v      = $bucket->get_key( $self->basename($fn) );
    return $v->{value};
}
1;
