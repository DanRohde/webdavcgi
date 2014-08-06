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
#  see WebInterface::Extension::PublicUri::(Private|Publi)
package WebInterface::Extension::PublicUri;

use strict;

use WebInterface::Extension;
our @ISA = qw( WebInterface::Extension  );

use Module::Load;

sub init { 
	my($self, $hookreg) = @_; 


	my $mode = $self->config('mode', $main::BACKEND eq 'RO' ? 'public' : 'private');
	
	my $handler = $mode eq 'private' ? 'WebInterface::Extension::PublicUri::Private' : 'WebInterface::Extension::PublicUri::Public';
	
	load $handler;
	my $h = $handler->new($hookreg)->setExtension('PublicUri');
	
}

1;