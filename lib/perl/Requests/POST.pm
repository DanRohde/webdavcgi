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

package Requests::POST;

use strict;
use warnings;

our $VERSION = '2.0';

use base qw( Requests::Request );

use HTTPHelper qw( print_header_and_content );
use FileUtils qw( get_error_document );

sub handle {
    my ($self)  = @_;
    my $cgi     = $self->{cgi};
    my $backend = $self->{backend};
    $self->debug("_POST: $main::PATH_TRANSLATED");
    if ( !$cgi->param('file_upload') && $cgi->cgi_error ) {
        return print_header_and_content( $cgi->cgi_error, undef,
            $cgi->cgi_error );
    }
    if ( $main::ALLOW_FILE_MANAGEMENT
        && $self->get_webinterface()->handle_post_request() )
    {
        $self->debug('_POST: WebInterface called');
        return;
    }
    if (   $main::ENABLE_CALDAV_SCHEDULE
        && $backend->isDir($main::PATH_TRANSLATED) )
    {
        ## TODO: NOT IMPLEMENTED YET
        return print_header_and_content('501 Not Implemented');
    }
    $self->debug("_POST: forbidden POST to $main::PATH_TRANSLATED");
    return print_header_and_content(
        get_error_document(
            '403 Forbidden',
            'text/plain',
            '403 Forbidden (unknown request, params:'
              . join( ', ', $cgi->param() ) . ')'
        )
    );
}

1;
