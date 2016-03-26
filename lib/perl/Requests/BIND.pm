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
# RFC 5842 ( https://tools.ietf.org/html/rfc5842 )
# EXAMPLE:
# BIND request:
# <?xml version="1.0" encoding="utf-8" ?>
# <D:bind xmlns:D="DAV:">
#     <D:segment>bar.html</D:segment>
#     <D:href>http://localhost/foo.html</D:href>
# </D:bind>

package Requests::BIND;

use strict;
use warnings;

our $VERSION = '2.0';

use base qw( Requests::Request );

use English qw ( -no_match_vars );
use URI::Escape;

use HTTPHelper qw( read_request_body print_header_and_content );
use WebDAV::XMLHelper qw( simple_xml_parser );

sub handle {
    my ($self) = @_;

    my $cgi     = $self->{cgi};
    my $backend = $self->{backend};

    my $overwrite =
      defined $cgi->http('Overwrite') ? $cgi->http('Overwrite') : 'T';
    my $xml     = read_request_body();
    my $xmldata = q{};
    my $host    = $cgi->http('Host');

    $self->debug( __PACKAGE__ . "::handle: xml=$xml" );

    if ( !eval { $xmldata = simple_xml_parser( $xml, 0 ); } ) {
        $self->debug($EVAL_ERROR);
        return print_header_and_content('400 Bad Request');
    }

    my $segment = ${$xmldata}{'{DAV:}segment'};
    my $href    = ${$xmldata}{'{DAV:}href'};
    $href =~ s{^https?://\Q$host\E(:\d+)?$main::VIRTUAL_BASE}{}xms;
    $href = uri_unescape( uri_unescape($href) );
    my $src = $main::DOCUMENT_ROOT . $href;
    my $dst = $main::PATH_TRANSLATED . $segment;

    my $ndst = $dst;
    $ndst =~ s /\/$//xms;

    if ( !$backend->exists($src) ) {
        return print_header_and_content('404 Not Found');
    }
    if ( $backend->exists($dst) && !$backend->isLink($ndst) ) {
        return print_header_and_content('403 Forbidden');
    }
    if (   $backend->exists($dst)
        && $backend->isLink($ndst)
        && $overwrite eq 'F' )
    {
        return print_header_and_content('403 Forbidden');
    }
    main::broadcast( 'BIND', { file => $src, destination => $dst } );
    my $status = $backend->isLink($ndst) ? '204 No Content' : '201 Created';
    if ( $backend->isLink($ndst) && !$backend->unlinkFile($ndst) ) {
        return print_header_and_content('403 Forbidden');
    }
    if ( !$backend->createSymLink( $src, $dst ) ) {
        return print_header_and_content('403 Forbidden');
    }

    main::broadcast( 'BOUND', { file => $src, destination => $dst } );
    return print_header_and_content($status);
}
1;
