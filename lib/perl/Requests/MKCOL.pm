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

package Requests::MKCOL;

use strict;
use warnings;

our $VERSION = '2.0';

use base qw( Requests::WebDAVRequest );

use English qw ( -no_match_vars );

use DefaultConfig qw( $PATH_TRANSLATED );
use HTTPHelper qw( read_request_body print_header_and_content );
use WebDAV::XMLHelper qw( simple_xml_parser );

sub handle {
    my ($self)  = @_;
    my $cgi     = $self->{cgi};
    my $backend = $self->{backend};
    my $pt      = $PATH_TRANSLATED;

    $self->debug("MKCOL: $pt");
    my $body = read_request_body();
    my $dataref;
    if ( $body ne q{} ) {

        # maybe extended mkcol (RFC5689)
        if ( $cgi->content_type() =~ /\/xml/xms ) {
            if ( !eval { $dataref = simple_xml_parser($body) } ) {
                $self->debug("MKCOL: invalid XML request: ${EVAL_ERROR}");
                return print_header_and_content('400 Bad Request');
            }
            if ( ref( ${$dataref}{'{DAV:}set'} ) !~ /(?:ARRAY|HASH)/xms ) {
                return print_header_and_content('400 Bad Request');
            }
        }
        else {
            return print_header_and_content('415 Unsupported Media Type');
        }
    }
    if ( $backend->exists($pt) ) {
        $self->debug('MKCOL: folder exists (405 Method Not Allowed)!');
        return print_header_and_content(
            '405 Method Not Allowed (folder exists)');
    }
    if ( !$backend->exists( $backend->getParent($pt) ) ) {
        $self->debug('MKCOL: parent does not exists (409 Conflict)!');
        return print_header_and_content('409 Conflict');
    }
    if ( !$backend->isWriteable( $backend->getParent($pt) ) ) {
        $self->debug('MKCOL: parent is not writeable (403 Forbidden)!');
        return print_header_and_content('403 Forbidden');
    }
    if ( !$self->is_allowed($pt) ) {
        $self->debug('MKCOL: not allowed!');
        return print_header_and_content('423 Locked');
    }
    if (   $backend->isDir( $backend->getParent($pt) )
        && $self->is_insufficient_storage( $cgi, $backend ) )
    {
        $self->debug('MKCOL: insufficient storage!');
        return print_header_and_content('507 Insufficient Storage');
    }

    if ( !$backend->isDir( $backend->getParent($pt) ) ) {
        $self->debug('MKCOL: parent direcory does not exists');
        return print_header_and_content('409 Conflict');
    }

    $self->debug("MKCOL: create $pt");
    $self->{event}->broadcast( 'MKCOL', { file => $pt } );

    if ( !$backend->mkcol($pt) ) {
        return print_header_and_content('403 Forbidden');
    }

    my ( %resp_200, %resp_403 );
    $self->handle_property_request( $body, $dataref, \%resp_200, \%resp_403 );
    ## ignore errors from property request
    $self->get_lock_module()->inherit_lock();
    $self->logger("MKCOL($pt)");
    $self->{event}->broadcast( 'MDCOL', { file => $pt } );
    return print_header_and_content('201 Created');
}

1;
