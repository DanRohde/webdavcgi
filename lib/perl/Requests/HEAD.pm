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

package Requests::HEAD;

use strict;
use warnings;

our $VERSION = '2.0';

use base qw( Requests::WebInterfaceRequest );

use DefaultConfig qw( $PATH_TRANSLATED $FANCYINDEXING );
use HTTPHelper
  qw( fix_mod_perl_response print_header_and_content print_file_header );

sub handle {
    my ($self) = @_;
    my $backend = $self->{backend};
    if ( $FANCYINDEXING && $self->get_webinterface()->handle_head_request() )
    {
        $self->debug('HEAD: WebInterface called');
        return;
    }
    if ( !$backend->exists($PATH_TRANSLATED) ) {
        $self->debug("HEAD: $PATH_TRANSLATED does not exists!");
        print_header_and_content('404 Not Found');

    }
    $self->debug("HEAD: $PATH_TRANSLATED exists!");
    return fix_mod_perl_response( print_file_header($PATH_TRANSLATED) );
}
1;
