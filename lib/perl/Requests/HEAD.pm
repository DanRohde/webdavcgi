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

use base qw( Requests::Request );

use HTTPHelper
  qw( fix_mod_perl_response print_header_and_content print_file_header );

sub handle {
    my ($self)  = @_;
    my $backend = main::getBackend();
    my $fn      = $main::PATH_TRANSLATED;
    if ( $main::FANCYINDEXING
        && main::getWebInterface()->handle_head_request() )
    {
        main::debug('HEAD: WebInterface called');
        return;
    }
    if ( !$backend->exists($fn) ) {
        main::debug("HEAD: $fn does not exists!");
        print_header_and_content('404 Not Found');

    }
    main::debug("HEAD: $fn exists!");
    return fix_mod_perl_response( print_file_header($fn) );
}
1;
