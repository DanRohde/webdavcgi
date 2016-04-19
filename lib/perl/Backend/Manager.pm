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
use warnings;

use Module::Load;

our $VERSION = '2.0';

use vars qw( %_BACKENDS $_MANAGER );

sub new {
    my $this  = shift;
    my $class = ref($this) || $this;
    my $self  = {};
    if ( !$_MANAGER ) {
        bless $self, $class;
        $_MANAGER = $self;
    }
    return $_MANAGER;
}
sub free {
    my ($self) = @_;
    foreach my $b ( keys %_BACKENDS ) {
        $_BACKENDS{$b}->free();
        delete $_BACKENDS{$b};
    }
    undef %_BACKENDS;
    return $self;
}
sub getinstance {
    return __PACKAGE__->new();
}

sub get_backend {
    my ( $self, $backendname, $config ) = @_;
    my $module = "Backend::${backendname}::Driver";
    if ( exists $_BACKENDS{$backendname} ) {
        return $_BACKENDS{$backendname}->init($config);
    }
    load $module;
    return $_BACKENDS{$backendname} = $module->new()->init($config);
}
1;
