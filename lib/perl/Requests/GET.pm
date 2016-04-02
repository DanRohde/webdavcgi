########################################################################
# (C) ZE CMS, Humboldt-Universitaet zu Berlin
# Written 2016 by Daniel Rohde <d.rohde@cms.hu-berlin.de>
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

package Requests::GET;

use strict;
use warnings;

our $VERSION = '2.0';

use base qw( Requests::WebInterfaceRequest );

use CGI::Carp;
use POSIX qw( strftime );

use DefaultConfig
  qw( $PATH_TRANSLATED $REQUEST_URI $VIRTUAL_BASE $VHTDOCS $DOCUMENT_ROOT $CHARSET
  $FANCYINDEXING $ENABLE_COMPRESSION $BUFSIZE $REDIRECT_TO );
use HTTPHelper
  qw( print_header_and_content get_byte_ranges get_etag print_file_header fix_mod_perl_response
  get_mime_type );
use FileUtils qw( get_error_document is_hidden stat2h );

use vars qw( $MIN_COMPRESSABLE_FILESIZE $MAX_COMPRESSABLE_FILESIZE );

{
    $MIN_COMPRESSABLE_FILESIZE = 1_024;
    $MAX_COMPRESSABLE_FILESIZE = 1_073_741_824;
}

sub handle {
    my ($self) = @_;
    $self->debug("GET: $REQUEST_URI => $PATH_TRANSLATED");

    my $backend = $self->{backend};
    my $cgi     = $self->{cgi};

    if ( is_hidden($PATH_TRANSLATED) ) {
        return print_header_and_content( get_error_document('404 Not Found') );
    }
    if ( !$FANCYINDEXING && $backend->isDir($PATH_TRANSLATED) ) {
        if ( !defined $REDIRECT_TO ) {
            return print_header_and_content(
                get_error_document('404 Not Found') );
        }
        return print $cgi->redirect($REDIRECT_TO);
    }
    if (
        $FANCYINDEXING
        && (   $DOCUMENT_ROOT eq q{/}
            || $REQUEST_URI =~ /^$VIRTUAL_BASE\Q$VHTDOCS\E/xms
            || $ENV{QUERY_STRING} ne q{}
            || $backend->isDir($PATH_TRANSLATED)
            || !$backend->exists($PATH_TRANSLATED) )
        && $self->get_webinterface()->handle_get_request()
      )
    {
        $self->debug('GET: WebInterface called');
        return;
    }
    if ( !$backend->exists($PATH_TRANSLATED) ) {
        $self->debug("GET: $PATH_TRANSLATED NOT FOUND!");
        return print_header_and_content( get_error_document('404 Not Found') );
    }
    if ( !$backend->isReadable($PATH_TRANSLATED) ) {
        $self->debug("GET: $PATH_TRANSLATED not readable!");
        return print_header_and_content( get_error_document('403 Forbidden') );
    }

    $self->debug('GET: DOWNLOAD');
    binmode(STDOUT) || carp('Cannot set binmode for STDOUT.');

    if ( !$self->_handle_compressed_file( $cgi, $backend ) ) {
        my ( $start, $end, $count ) = get_byte_ranges( $cgi, $backend );
        my $headerref = print_file_header($backend, $PATH_TRANSLATED);
        $backend->printFile( $PATH_TRANSLATED, \*STDOUT, $start, $count );
        fix_mod_perl_response($headerref);

        $self->{event}->broadcast(
            'GET',
            {
                file => $PATH_TRANSLATED,
                size => $count
                  || stat2h( $backend->stat($PATH_TRANSLATED) )->{size}
            }
        );
    }
    return;
}

sub _compressable {
    my ( $self, $cgi, $backend ) = @_;
    my $enc  = $cgi->http('Accept-Encoding');
    my $mime = get_mime_type($PATH_TRANSLATED);
    my $stat = stat2h( $backend->stat($PATH_TRANSLATED) );

    return
         $ENABLE_COMPRESSION
      && $enc
      && $enc =~ /(?:gzip|deflate)/xms
      && $stat->{size} >= $MIN_COMPRESSABLE_FILESIZE
      && $stat->{size} <= $MAX_COMPRESSABLE_FILESIZE
      && $mime !~ m{^(?:text/(?:css|html)|application/(?:x-)?javascript)$}xmsi;
}

sub _handle_compressed_file {
    my ( $self, $cgi, $backend ) = @_;
    if ( !$self->_compressable( $cgi, $backend ) ) {
        return 0;
    }

    my $enc  = $cgi->http('Accept-Encoding');
    my $mime = get_mime_type($PATH_TRANSLATED);
    my $stat = stat2h( $backend->stat($PATH_TRANSLATED) );

    my ( $start, $end, $count ) = get_byte_ranges( $cgi, $backend );

    my %header = (
        -status => '200 OK',
        -type   => $mime,
        -ETag   => get_etag($PATH_TRANSLATED),
        -Last_Modified =>
          strftime( '%a, %d %b %Y %T GMT', gmtime $stat->{mtime} ),
        -charset          => $CHARSET,
        -Content_Encoding => $enc =~ /gzip/xms ? 'gzip' : 'deflate',
        -Cache_Control    => 'no-cache',
    );
    if ( defined $start ) {
        $header{-status} = '206 Partial Content';
        $header{-Content_Range} = sprintf 'bytes %s-%s/%s', $start, $end,
          $stat->{size};
        $header{-Content_Length} = $count;
    }
    print( $cgi->header( \%header ) ) || carp('Cannot print HTTP header.');
    my $c;
    if ( $enc =~ /gzip/xmsi ) {
        require IO::Compress::Gzip;
        $c = IO::Compress::Gzip->new( \*STDOUT );
    }
    elsif ( $enc =~ /deflate/xmsi ) {
        require IO::Compress::Deflate;
        $c = IO::Compress::Deflate->new( \*STDOUT );
    }
    my $bufsize = $BUFSIZE;
    if ( defined $count && $count < $bufsize ) { $bufsize = $count; }
    my $bytecount = 0;
    if ( open my $F, '<', $backend->getLocalFilename($PATH_TRANSLATED) ) {
        if ( defined $start ) {
            seek( $F, $start, 0 )
              || carp(
                "Cannot seek filehandle for '$PATH_TRANSLATED' to $start.");
        }
        while ( my $bytesread = read $F, my $buffer, $bufsize ) {
            $c->write($buffer);
            $bytecount += $bytesread;
            if ( defined $count && $bytecount >= $count ) { last; }
            if ( defined $count && ( $bytecount + $bufsize > $count ) ) {
                $bufsize = $count - $bytecount;
            }
        }
        close($F) || carp('Cannot close filehandle.');
    }
    $self->{event}->broadcast(
        'GET',
        {
            file => $PATH_TRANSLATED,
            size => $count || $stat->{size}
        }
    );
    return 1;
}

1;
