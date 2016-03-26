#########################################################################
# (C) ZE CMS, Humboldt-Universitaet zu Berlin
# Written 2014 by Daniel Rohde <d.rohde@cms.hu-berlin.de>
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
# SETUP:
#
# virtualbase - virtual base URI for the public link (default: /public/)
# uribase - base URI for the public link (default: https://$ENV{HTTP_HOST}/public/)
# propname - property name for the share digest (default: public_prop)
# seed - property name for digest seed (default: seed)
# namespace - XML namespace for propname and seed (default: {http://webdavcgi.sf.net/extension/PublicUri/})
# prefix - a prefix for URI digest (default: empty string)
# allowedpostactions - allowed actions regex, default: ^(zipdwnload|diskusage|search|diff)$
# mode - public or private (default: "public" if $BACKEND is 'RO' else "private" )

package WebInterface::Extension::PublicUri;

use strict;
use warnings;

our $VERSION = '2.0';
use base qw( WebInterface::Extension  );

use Module::Load;

sub init {
    my ( $self, $hookreg ) = @_;

    my $mode = $self->config( 'mode',
        $main::BACKEND eq 'RO' ? 'public' : 'private' );

    my $handler
        = $mode eq 'private'
        ? 'WebInterface::Extension::PublicUri::Private'
        : 'WebInterface::Extension::PublicUri::Public';

    load $handler;
    $handler->new($hookreg,'PublicUri',$self->{config});
    return $self;
}

1;
