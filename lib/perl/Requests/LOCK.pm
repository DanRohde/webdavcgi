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

package Requests::LOCK;

use strict;
use warnings;

our $VERSION = '2.0';

use base qw( Requests::WebDAVRequest );

use HTTPHelper qw( print_header_and_content read_request_body );
use WebDAV::XMLHelper qw( create_xml simple_xml_parser );

sub handle {
    my ($self) = @_;
    $self->debug("_LOCK: $main::PATH_TRANSLATED");

    my $backend = $self->{backend};
    my $cgi     = $self->{cgi};
    my $lm      = main::getLockModule();
    my $fn      = $main::PATH_TRANSLATED;
    my $ru      = $main::REQUEST_URI;
    my $depth = defined $cgi->http('Depth') ? $cgi->http('Depth') : 'infinity';
    my $timeout   = $cgi->http('Timeout');
    my $status    = '200 OK';
    my $type      = 'application/xml';
    my $content   = q{};
    my $addheader = undef;

    my $xml = read_request_body();
    my $xmldata = $xml ne q{} ? simple_xml_parser($xml) : {};

    my $token = 'opaquelocktoken:' . $lm->getuuid($fn);

    if (   !$backend->exists($fn)
        && !$backend->exists( $backend->getParent($fn) ) )
    {
        return print_header_and_content('409 Conflict');
    }
    if ( !$lm->is_lockable( $fn, $xmldata ) ) {
        $self->debug('_LOCK: not lockable ... but...');
        if ( !$self->is_allowed($fn) ) {
            return print_header_and_content('423 Locked');
        }
        $status = '200 OK';
        $lm->lock_resource( $fn, $ru, $xmldata, $depth, $timeout, $token );
        $content = create_xml(
            {
                prop => {
                    lockdiscovery => $lm->get_lock_discovery($fn)
                }
            }
        );
    }
    elsif ( !$backend->exists($fn) ) {
        if ( $self->is_insufficient_storage( $cgi, $backend ) ) {
            return print_header_and_content('507 Insufficient Storage');
        }
        if ( !$backend->saveData( $fn, q{} ) ) {
            return print_header_and_content('403 Forbidden');
        }
        my $resp =
          $lm->lock_resource( $fn, $ru, $xmldata, $depth, $timeout, $token );
        if ( defined ${$resp}{multistatus} ) {
            $status = '207 Multi-Status';
        }
        else {
            $addheader = "Lock-Token: $token";
            $status    = '201 Created';
        }
        $content = create_xml($resp);
    }
    else {
        my $resp =
          $lm->lock_resource( $fn, $ru, $xmldata, $depth, $timeout, $token );
        $addheader = "Lock-Token: $token";
        $content   = create_xml($resp);
        $status    = '207 Multi-Status' if defined ${$resp}{multistatus};
    }
    $self->debug("_LOCK: REQUEST: $xml");
    $self->debug("_LOCK: RESPONSE: $content");
    $self->debug("_LOCK: status: $status, type=$type");
    return print_header_and_content( $status, $type, $content, $addheader );
}

1;
