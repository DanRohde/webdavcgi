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

package Requests::PROPFIND;

use strict;
use warnings;

our $VERSION = '2.0';

use base qw( Requests::WebDAVRequest );

use English qw ( -no_match_vars );
use CGI::Carp;

use DefaultConfig 
   qw( $PATH_TRANSLATED $REQUEST_URI $ALLOW_INFINITE_PROPFIND 
       $PRINCIPAL_COLLECTION_SET $CURRENT_USER_PRINCIPAL $CHARSET
   );
use HTTPHelper qw( print_header_and_content read_request_body );
use WebDAV::XMLHelper
  qw( create_xml simple_xml_parser handle_propfind_element );
use FileUtils qw( is_hidden );

use vars qw( $DEPTH_INFINITY );

BEGIN {
    $DEPTH_INFINITY = -1;
}

sub handle {
    my ($self)  = @_;
    my $cgi     = $self->{cgi};
    my $backend = $self->{backend};
    my $fn      = $PATH_TRANSLATED;
    my $ru      = $REQUEST_URI;
    my $status  = '207 Multi-Status';
    my $type    = 'text/xml';
    my $depth = $cgi->http('Depth') // $DEPTH_INFINITY;
    my $noroot = $depth =~ s/,noroot//xms ? 1 : 0;
    $depth = $depth =~ /infinity/xmsi ? $DEPTH_INFINITY : $depth;
    $self->debug("_PROPFIND: depth=$depth, fn=$fn, ru=$ru");
    if (   ( $depth == $DEPTH_INFINITY && !$ALLOW_INFINITE_PROPFIND )
        || ( $depth !~ /^(?:0|-?1)$/xms ) )
    {
        carp("PROPFIND: 400 Bad Request: illegal Depth header value: $depth");
        return print_header_and_content(
            '400 Bad Request (illegal Depth header value in PROPFIND request)');
    }

    my $xml = read_request_body();
    if ( !defined $xml || $xml =~ /^\s*$/xms ) {
        $xml =
qq{<?xml version="1.0" encoding="$CHARSET" ?>\n<D:propfind xmlns:D="DAV:"><D:allprop/></D:propfind>};
    }

    my $xmldata;
    if ( !eval { $xmldata = simple_xml_parser($xml); } ) {
        carp("PROPFIND: invalid XML request: ${EVAL_ERROR}\n$xml");
        return print_header_and_content(
            '400 Bad Request (invalid XML in PROPFIND request)');
    }

    $ru =~ s/\s/%20/xmsg;

    my @resps = ();

    ## ACL, CalDAV, CardDAV, ...:
    if (   defined $PRINCIPAL_COLLECTION_SET
        && length($PRINCIPAL_COLLECTION_SET) > 1
        && $ru =~ /\Q$PRINCIPAL_COLLECTION_SET\E$/xms )
    {
        $fn =~ s/\Q$PRINCIPAL_COLLECTION_SET\E$//xms;
        $depth = 0;
    }
    elsif (defined $CURRENT_USER_PRINCIPAL
        && length($CURRENT_USER_PRINCIPAL) > 1
        && $ru =~ /\Q$CURRENT_USER_PRINCIPAL\E\/?$/xms )
    {
        $fn =~ s/\Q$CURRENT_USER_PRINCIPAL\E\/?$//xms;
        $depth = 0;
    }
    elsif ( $ru =~ m{^/[.]well-known/(?:caldav|carddav)$}xms ) {    # RFC5785
        $fn =~ s{/[.]well-known/(?:caldav|carddav)$}{}xms;
        $depth = 0;
    }

    if ( is_hidden($fn) || !$backend->exists($fn) ) {
        return print_header_and_content('404 Not Found');
    }
    my ( $props, $all, $noval ) = handle_propfind_element($xmldata);
    if ( !defined $props ) {
        carp("PROPFIND: 400 Bad Request: no or unsupported properties found.");
        return print_header_and_content('400 Bad Request (no or unsupported properties found)');
    }
    $self->read_dir_recursive( $fn, $ru, \@resps, $props, $all, $noval, $depth,
        $noroot );

    my $content =
      ( $#resps >= 0 )
      ? create_xml( { 'multistatus' => { 'response' => \@resps } } )
      : q{};

    my $size = bytes::length($content);
    $self->{event}->broadcast( 'PROPFIND',
        { file => $PATH_TRANSLATED, size => $size } );
    $self->debug("_PROPFIND: status=$status, type=$type, size=$size");
    $self->debug("_PROPFIND: REQUEST:\n$xml\nEND-REQUEST");
    $self->debug("_PROPFIND: RESPONSE:\n$content\nEND-RESPONSE");

    return print_header_and_content( $status, $type, $content );
}

1;
