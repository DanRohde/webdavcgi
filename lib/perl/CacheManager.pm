#########################################################################
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

package CacheManager;

use strict;
use warnings;

our $VERSION = '2.0';

sub new {
    my $class = shift;
    my $self  = {};
    bless $self, $class;
    $self->{cache} = {};
    return $self;
}
sub free {
    my ($self) = @_;
    delete $self->{cache};
    return $self;
}

sub _exists_entry_arrayref {
    my ( $self, $cache, $key ) = @_;
    if ( $#{$key} > 0 ) {
        return $self->_exists_entry_arrayref( ${$cache}{ shift @{$key} },
            $key );
    }
    return exists ${$cache}{ shift @{$key} };
}

sub exists_entry {
    my ( $self, $key ) = @_;
    my ($package) = caller;
    if ( ref($key) eq 'ARRAY' ) {
        return $self->_exists_entry_arrayref( $self->{cache}{$package}, $key );
    }
    return exists $self->{cache}{$package}{$key};
}

sub _set_entry_arrayref {
    my ( $self, $cache, $key, $data ) = @_;
    if ( $#{$key} > 0 ) {
        $self->_set_entry_arrayref( ${$cache}{ shift @{$key} } //= {},
            $key, $data );
    }
    else {
        ${$cache}{ shift @{$key} } = $data;
    }
    return $data;
}

sub set_entry {
    my ( $self, $key, $data ) = @_;
    my ($package) = caller;
    if ( ref($key) eq 'ARRAY' ) {
        $self->_set_entry_arrayref( $self->{cache}{$package} //= {},
            $key, $data );
    }
    else {
        $self->{cache}{$package}{$key} = $data;
    }
    return $data;
}

sub _get_entry_arrayref {
    my ( $self, $cache, $key ) = @_;
    if ( $#{$key} > 0 ) {
        return $self->_get_entry_arrayref( ${$cache}{ shift @{$key} }, $key );
    }
    return ${$cache}{ shift @{$key} };
}

sub get_entry {
    my ( $self, $key, $default ) = @_;
    my ($package) = caller;
    if ( ref($key) eq 'ARRAY' ) {
        return $self->_get_entry_arrayref( $self->{cache}{$package}, $key )
          // $default;
    }
    return $self->{cache}{$package}{$key} // $default;
}

sub _remove_entry_arrayref {
    my ( $self, $cache, $key ) = @_;
    if ( $#{$key} > 0 ) {
        return $self->_remove_entry_arrayref( ${$cache}{ shift @{$key} },
            $key );
    }
    return delete ${$cache}{ shift @{$key} };
}

sub remove_entry {
    my ( $self, $key ) = @_;
    my ($package) = caller;
    if ( ref($key) eq 'ARRAY' ) {
        return $self->_remove_entry_arrayref( $self->{cache}{$package}, $key );
    }
    return $self->{cache}{$package}{$key};
}

1;
