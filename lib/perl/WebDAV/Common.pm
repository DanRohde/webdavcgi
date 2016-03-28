#!/usr/bin/perl
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

package WebDAV::Common;

use strict;
use warnings;

our $VERSION = '2.0';

sub new {
    my ( $this, $config ) = @_;
    my $class = ref($this) || $this;
    my $self = {};
    bless $self, $class;
    $self->{config}  = $config;
    $self->{cgi}     = $config->{cgi};
    $self->{backend} = $config->{backend};
    $self->{db}      = $config->{db};
    $self->{debug}   = $config->{debug};

    $self->initialize();
    return $self;
}

sub initialize {
    my $self = shift;
    return $self;
}

sub resolve {
    my ( $self, $fn ) = @_;
    return $self->{backend}->resolveVirt($fn);
}

1;
