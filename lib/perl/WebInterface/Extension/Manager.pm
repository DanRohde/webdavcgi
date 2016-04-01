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

package WebInterface::Extension::Manager;

use strict;
use warnings;

our $VERSION = '2.0';

use Module::Load;
use CGI::Carp;
use English qw( -no_match_vars );

use DefaultConfig qw( @EXTENSIONS );

use vars qw( %HOOKS );

sub new {
    my ( $this, $config ) = @_;
    my $class = ref($this) || $this;
    my $self = {};
    bless $self, $class;
    return $self->init($config);
}

sub init {
    my ( $self, $config ) = @_;
    $self->{config} = $config;
    foreach my $extname (@EXTENSIONS) {
        eval {
            load "WebInterface::Extension::$extname";
            my $extension =
              "WebInterface::Extension::$extname"
              ->new( $self, $extname, $self->{config} );
        } || carp("Can't load extension $extname: $EVAL_ERROR");
    }
    return $self;
}

sub register {
    my ( $self, $hook, $handler ) = @_;
    my $ref = ref $hook;
    if ( $ref eq 'ARRAY' ) {
        foreach my $h ( @{$hook} ) {
            $self->register( $h, $handler );
        }
    }
    elsif ( $ref eq 'HASH' ) {
        foreach my $h ( keys %{$hook} ) {
            $self->register( $h, $hook->{$h} // $handler );
        }
    }
    else {
        $HOOKS{$self}{$hook} //= [];
        push @{ $HOOKS{$self}{$hook} }, $handler;
    }
    return 1;
}

sub handle {
    my ( $self, $hook, $params ) = @_;
    if ( !exists $HOOKS{$self}{$hook} ) {
        ;
        return;
    }
    my @ret;
    foreach my $handler ( @{ $HOOKS{$self}{$hook} } ) {
        push @ret, $handler->handle( $hook, $self->{config}, $params );
    }
    return \@ret;
}

1;
