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

use HTTPHelper
  qw( print_header_and_content get_byte_ranges get_etag print_file_header fix_mod_perl_response );
use FileUtils qw( get_error_document is_hidden stat2h );

use vars qw( $MIN_COMPRESSABLE_FILESIZE $MAX_COMPRESSABLE_FILESIZE $DEFAULT_BUFSIZE );

BEGIN {
    $MIN_COMPRESSABLE_FILESIZE = 1_024;
    $MAX_COMPRESSABLE_FILESIZE = 1_073_741_824;
    $DEFAULT_BUFSIZE           = 1_048_576;
}

sub handle {
    my ( $self ) = @_;
    $self->debug("_GET: $main::PATH_TRANSLATED");
    
    my $backend = $self->{backend};
    my $cgi     = $self->{cgi};
    
    if ( is_hidden($main::PATH_TRANSLATED) ) {
        return print_header_and_content( get_error_document('404 Not Found') );
    }
    if ( !$main::FANCYINDEXING && $backend->isDir($main::PATH_TRANSLATED) ) {
        if ( !defined $main::REDIRECT_TO ) {
            return print_header_and_content(
                get_error_document('404 Not Found') );
        }
        return print $cgi->redirect($main::REDIRECT_TO);
    }
    if (
        $main::FANCYINDEXING
        && (   $main::DOCUMENT_ROOT eq q{/}
            || $backend->isDir($main::PATH_TRANSLATED)
            || $ENV{QUERY_STRING} ne q{}
            || !$backend->exists($main::PATH_TRANSLATED) )
        && $self->get_webinterface()->handle_get_request()
      )
    {
        $self->debug('_GET: WebInterface called');
        return;
    }
    if ( !$backend->exists($main::PATH_TRANSLATED) ) {
        $self->debug("GET: $main::PATH_TRANSLATED NOT FOUND!");
        return print_header_and_content( get_error_document('404 Not Found') );
    }
    if ( !$backend->isReadable($main::PATH_TRANSLATED) ) {
        $self->debug("GET: $main::PATH_TRANSLATED not readable!");
        return print_header_and_content( get_error_document('403 Forbidden') );
    }

    $self->debug('_GET: DOWNLOAD');
    binmode(STDOUT) || croak('Cannot set binmode for STDOUT.');

    if ( !$self->_handle_compressed_file( $cgi, $backend ) ) {
        my ( $start, $end, $count ) = get_byte_ranges( $cgi, $backend );
        my $headerref = print_file_header($main::PATH_TRANSLATED);
        $backend->printFile( $main::PATH_TRANSLATED, \*STDOUT, $start, $count );
        fix_mod_perl_response($headerref);

        main::broadcast(
            'GET',
            {
                file => $main::PATH_TRANSLATED,
                size => $count
                  || stat2h( \$backend->stat($main::PATH_TRANSLATED))->{size}
            }
        );
    }

    return;
}

sub _compressable {
    my ( $self, $cgi, $backend ) = @_;
    my $enc  = $cgi->http('Accept-Encoding');
    my $mime = main::get_mime_type($main::PATH_TRANSLATED);
    my $stat = stat2h( \$backend->stat($main::PATH_TRANSLATED) );

    return
         $main::ENABLE_COMPRESSION
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
    my $mime = main::get_mime_type($main::PATH_TRANSLATED);
    my $stat = stat2h( \$backend->stat($main::PATH_TRANSLATED) );

    my ( $start, $end, $count ) = get_byte_ranges( $cgi, $backend );

    my %header = (
        -status => '200 OK',
        -type   => $mime,
        -ETag   => get_etag($main::PATH_TRANSLATED),
        -Last_Modified =>
          strftime( '%a, %d %b %Y %T GMT', gmtime $stat->{mtime} ),
        -charset          => $main::CHARSET,
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
    my $bufsize = $main::BUFSIZE || $DEFAULT_BUFSIZE;
    if ( defined $count && $count < $bufsize ) { $bufsize = $count; }
    my $bytecount = 0;
    if ( open my $F, '<', $backend->getLocalFilename($main::PATH_TRANSLATED) ) {
        if ( defined $start ) {
            seek( $F, $start, 0 )
              || croak(
                "Cannot seek filehandle for '$main::PATH_TRANSLATED' to $start."
              );
        }
        while ( my $bytesread = read $F, my $buffer, $bufsize ) {
            $c->write($buffer);
            $bytecount += $bytesread;
            if ( defined $count && $bytecount >= $count ) { last; }
            if ( defined $count && ( $bytecount + $bufsize > $count ) ) {
                $bufsize = $count - $bytecount;
            }
        }
        close($F) || croak('Cannot close filehandle.');
    }
    main::broadcast(
        'GET',
        {
            file => $main::PATH_TRANSLATED,
            size => $count || $stat->{size}
        }
    );
    return 1;
}

1;
