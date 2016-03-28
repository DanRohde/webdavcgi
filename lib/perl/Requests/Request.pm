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
package Requests::Request;

use strict;
use warnings;

our $VERSION = '2.0';

use CGI::Carp;

use DefaultConfig qw( $ENABLE_LOCK );
use HTTPHelper qw( get_if_header_components );
use WebDAV::Lock;
use CacheManager;

sub new {
    my ($this) = @_;
    my $class = ref($this) || $this;
    my $self = {};
    bless $self, $class;
    return $self;
}

sub init {
    my ( $self, $config ) = @_;
    foreach my $k ( keys %{$config} ) {
        $self->{$k} = $config->{$k};
    }
    return $self;
}

sub handle {
    croak('Implement me!');
}

sub logger {
    my ( $self, @args ) = @_;
    return $self->{logger}->(@args);
}

sub debug {
    my ( $self, @args ) = @_;
    return $self->{debug}->(@args);
}

sub is_insufficient_storage {
    my ( $self, $cgi, $backend ) = @_;
    my $ret = 0;
    my ( $block_hard, $block_curr ) = $backend->getQuota();
    if ( $block_hard > 0 ) {
        if ( $block_curr >= $block_hard ) {
            $ret = 1;
        }
        elsif ( defined $cgi->http('Content-Length') ) {
            my $filesize = $cgi->http('Content-Length');
            $ret = $filesize + $block_curr > $block_hard;
        }
    }
    return $ret;
}

sub is_locked_cached {
    my ( $self, $fn ) = @_;
    if ( !$ENABLE_LOCK ) { return 0; }
    return $self->get_lock_module()->is_locked_cached($fn);
}

sub is_locked {
    my ( $self, $fn, $r ) = @_;
    if ( !$ENABLE_LOCK ) { return 0; }
    return $r
      ? $self->get_lock_module()->is_locked_recurse($fn)
      : $self->get_lock_module()->is_locked($fn);
}

sub get_lock_module {
    my ($self) = @_;
    my $cache  = CacheManager::getinstance();
    my $lm     = $cache->get_entry('lockmodule');
    if ( !$lm ) {
        $lm = WebDAV::Lock->new( $self->{config} );
        $cache->set_entry( 'lockmodule', $lm );
    }
    return $lm;
}

sub is_allowed {
    my ( $self, $fn, $recurse ) = @_;

    my $cgi     = $self->{cgi};
    my $backend = $self->{backend};

    if ( !$ENABLE_LOCK ) {
        return 1;
    }

    if ( !$backend->exists($fn) ) {
        $fn = $backend->getParent($fn) . q{/};
    }

    if ( $backend->exists($fn) && !$backend->isWriteable($fn) )
    {    # not writeable
        return 0;
    }
    if ( !$self->is_locked($fn) ) {
        return 1;
    }

    my $ifheader = get_if_header_components( $cgi->http('If') );

    if ( !defined $ifheader ) {
        return 0;
    }
    my $ret = 0;

    foreach
      my $token ( @{ $self->get_lock_module()->get_tokens( $fn, $recurse ) } )
    {
        for my $j ( 0 .. $#{ ${$ifheader}{list} } ) {
            my $iftoken = $ifheader->{list}[$j]{token};
            $iftoken //= q{};
            $iftoken =~ s/[<>\s]+//xmsg;
            $self->debug( "is_allowed: $iftoken send, needed for $token: "
                  . ( $iftoken eq $token ? 'OK' : 'FAILED' ) );
            if ( $token eq $iftoken ) {
                $ret = 1;
                last;
            }
        }
    }
    return $ret;
}
1;
