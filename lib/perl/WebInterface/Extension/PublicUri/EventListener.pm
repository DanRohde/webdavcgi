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

package WebInterface::Extension::PublicUri::EventListener;

use strict;

use Events::EventListener;
our @ISA = qw( Events::EventListener );

sub registerChannel {
	my ($self, $channel) = @_;
	
	$$self{namespace} = $main::EXTENSION{PublicUri}{namepsace} || '{http://webdavcgi.sf.net/extension/PublicUri/}';
	$$self{propname} =  $main::EXTENSION{PublicUri}{propname} || 'public_prop';
	$$self{seed} = $main::EXTENSION{PublicUri}{seed} || 'seed';
	$$self{orig} = $main::EXTENSION{PublicUri}{orig} || 'orig';
	
	$channel->addEventListener('FILECOPIED', $self);
}

sub receiveEvent {
	my ( $self, $event, $data ) = @_;
	my $dst = $$data{destination};
	my $db  = $$self{db} || main::getDBDriver();
	warn($event);
	$dst=~s/\/$//;
	$db->db_deletePropertiesRecursiveByName($dst, $$self{namespace}.$$self{propname});
	$db->db_deletePropertiesRecursiveByName($dst, $$self{namespace}.$$self{seed});
	$db->db_deletePropertiesRecursiveByName($dst, $$self{namespace}.$$self{orig});
}
1;