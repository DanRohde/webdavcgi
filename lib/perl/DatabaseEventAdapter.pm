#########################################################################
# (C) ZE CMS, Humboldt-Universitaet zu Berlin
# Written 2013 by Daniel Rohde <d.rohde@cms.hu-berlin.de>
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

package DatabaseEventAdapter;

use Events::EventListener;
@ISA = ('Events::EventListener');
use vars qw( %CHACHE );

sub stripTrailingSlash {
	my ($self, $file) = @_;
	$file=~s/\/$//;
	return $file;
}
sub receiveEvent {
	my ( $self, $event, $data ) = @_;
	my $db = main::getDBDriver();
	if ( $event eq 'FINALIZE' ) {
		$db->finalize();
	}
	elsif ( $event eq 'FILEMOVED' ) {
		my ($src,$dst) = ($self->stripTrailingSlash($$data{file}), $self->stripTrailingSlash($$data{destination}));
		$db->db_deletePropertiesRecursive($dst);
		$db->db_movePropertiesRecursive($src,$dst);
		$db->db_delete($src);
	}
	elsif ( $event eq 'FILECOPIED' ) {
		my ($src,$dst) = ($self->stripTrailingSlash($$data{file}), $self->stripTrailingSlash($$data{destination}));
		$db->db_deletePropertiesRecursive($dst);
		$db->db_copyPropertiesRecursive($src, $dst);
	}
	elsif ( $event eq 'DELETED' ) {
		my ($dst) = ($self->stripTrailingSlash($$data{file}));
		$db->db_deletePropertiesRecursive($dst);
		$db->db_delete($dst);
	}
}
1;