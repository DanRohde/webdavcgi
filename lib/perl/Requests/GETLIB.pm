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

package Requests::GETLIB;

use strict;
use warnings;

our $VERSION = '2.0';

use base qw( Requests::Request );

use HTTPHelper qw( print_header_and_content );

sub handle {
    my ( $self, $cgi, $backend ) = @_;
    my $fn = $main::PATH_TRANSLATED;
    if ( !$backend->exists($fn) ) {
        return print_header_and_content('404 Not Found');
    }
    my $su = $ENV{SCRIPT_URI};
    if ( !$backend->isDir($fn) ) { $su =~ s{/[^/]+$}{/}xms; }
    my $addheader = "MS-Doclib: $su";
    $self->debug("HTTP_GETLIB: $addheader\n");
    return print_header_and_content( '200 OK', 'text/plain', q{}, $addheader );
}
1;
