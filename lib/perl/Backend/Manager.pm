#########################################################################
# (C) ZE CMS, Humboldt-Universitaet zu Berlin
# Written 2010-2011 by Daniel Rohde <d.rohde@cms.hu-berlin.de>
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

package Backend::Manager;

use strict;

use Module::Load;

our $VERSION = 0.1;

our %BACKENDS;

sub new {
	my $class = shift;
	my $self = { };
	return bless $self, $class;
}

sub getBackend {
	my $self = shift;
	my $backendname = shift;
	my $module = "Backend::${backendname}::Driver";
	return $BACKENDS{$backendname} if exists $BACKENDS{$backendname};
	load $module;
	return $BACKENDS{$backendname} = $module->new;
}

1;
