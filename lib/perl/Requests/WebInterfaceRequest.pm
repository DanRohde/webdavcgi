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

package Requests::WebInterfaceRequest;

use strict;
use warnings;

our $VERSION = '1.0';

use base qw( Requests::Request );

use CacheManager;

sub get_webinterface {
    my ($self) = @_;
    my $cache = CacheManager::getinstance();
    my $wi = $cache->get_entry('webinterface', undef, $cache->get_app_context());
    if (!$wi) {
        require WebInterface;
        $wi = WebInterface->new();
        $cache->set_entry('webinterface', $wi, $cache->get_app_context());
    }
    return $wi->init($self->{config});
}

1;