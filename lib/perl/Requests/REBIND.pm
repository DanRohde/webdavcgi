#########################################################################
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
# RFC 5842 ( https://tools.ietf.org/html/rfc5842 )
#
# EXAMPLE:
# REBIND request:
# <?xml version="1.0" encoding="utf-8" ?>
# <D:rebind xmlns:D="DAV:">
#     <D:segment>foo.html</D:segment>
#     <D:href>http://localhost/bar.html</D:href>
# </D:rebind>

package Requests::REBIND;

use strict;
use warnings;

our $VERSION = '2.0';

use base qw( Requests::Request );

use URI::Escape;

use FileUtils qw( rmove get_error_document );
use HTTPHelper qw( read_request_body print_header_and_content );
use WebDAV::XMLHelper qw( simple_xml_parser );

sub handle {
    my ($self) = @_;

    my $cgi     = main::getCGI();
    my $backend = main::getBackend();
    my $host    = $cgi->http('Host');
    my $overwrite =
      defined $cgi->http('Overwrite') ? $cgi->http('Overwrite') : 'T';

    my $xml     = read_request_body();
    my $xmldata = q{};

    if ( !eval { $xmldata = simple_xml_parser( $xml, 0 ); } ) {
        return print_header_and_content(
            get_error_document(
                '400 Bad Request',
                'text/plain',
                '400 Bad Request'
            )
        );
    }

    my $segment = ${$xmldata}{'{DAV:}segment'};
    my $href    = ${$xmldata}{'{DAV:}href'};
    $href =~ s{^https?://\Q$host\E(:\d+)?$main::VIRTUAL_BASE}{}xms;
    $href = uri_unescape( uri_unescape($href) );
    my $src = $main::DOCUMENT_ROOT . $href;
    my $dst = $main::PATH_TRANSLATED . $segment;

    my $nsrc = $src;
    $nsrc =~ s/\/$//xms;
    my $ndst = $dst;
    $ndst =~ s/\/$//xms;

    if ( !$backend->exists($src) ) {
        return print_header_and_content(
            get_error_document('404 Not Found') );
    }
    if ( !$backend->isLink($nsrc) ) {
        return print_header_and_content(
            get_error_document('403 Forbidden') );
    }
    if ( $backend->exists($dst) && $overwrite ne 'T' ) {
        return print_header_and_content(
            get_error_document('403 Forbidden') );
    }
    if ( $backend->exists($dst) && !$backend->isLink($ndst) ) {
        return print_header_and_content(
            get_error_document('403 Forbidden') );
    }
    if ( main::is_insufficient_storage() ) {
        return print_header_and_content(
            get_error_document('507 Insufficient Storage') );
    }
    my ( $status, $type, $content );

    main::broadcast( 'REBIND', { file => $nsrc, destination => $ndst } );

    $status = $backend->isLink($ndst) ? '204 No Content' : '201 Created';

    if ( $backend->isLink($ndst) ) { $backend->unlinkFile($ndst); }

    if ( !rmove( $nsrc, $ndst ) ) {    ### check rename->rmove OK?
        my $orig = $backend->getLinkSrc($nsrc);
        if (   $backend->createSymLink( $orig, $dst )
            && $backend->unlinkFile($nsrc) )
        {
            main::broadcast( 'REBOUND',
                { file => $orig, destination => $dst } );
        }
        else {
            $status = '403 Forbidden';
        }
    }

    return print_header_and_content( $status, $type, $content );
}

1;
