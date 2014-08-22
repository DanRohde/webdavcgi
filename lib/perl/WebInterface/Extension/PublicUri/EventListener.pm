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
use WebInterface::Extension::PublicUri::Common;
our @ISA = qw( Events::EventListener WebInterface::Extension::PublicUri::Common);

sub registerChannel {
	my ($self, $channel) = @_;
	
	$self->initDefaults();
		
	$channel->addEventListener(['FILECOPIED','PROPFIND','OPTIONS'], $self);
}

sub receiveEvent {
	my ( $self, $event, $data ) = @_;
	if ($event eq 'FILECOPIED') {
		$self->handleFileCopiedEvent($data);
	} elsif ($event eq 'OPTIONS') {
		$self->handleWebDAVRequest($data);
	}
	
}
sub handleWebDAVRequest {
	my ($self, $data) = @_;
	if ($$data{file} =~ /^$main::DOCUMENT_ROOT([^\/]+)(.*)?$/) {
		my ($code, $path) = ($1,$2);
		my $fn = $self->getFileFromCode($code);
		return if (!$fn || !$self->isPublicUri($fn, $code, $self->getSeed($fn)));
		
		$main::DOCUMENT_ROOT = $fn;
		$main::DOCUMENT_ROOT.='/' if $main::DOCUMENT_ROOT !~ /\/$/;
		$main::PATH_TRANSLATED = $fn . $path;		
		$main::VIRTUAL_BASE = $$self{virtualbase}.$code.'/?';
		
		if ($main::backend->isDir($main::PATH_TRANSLATED)) {
			$main::PATH_TRANSLATED .= '/' if $main::PATH_TRANSLATED !~ /\/$/;
			$main::REQUEST_URI .= '/' if $main::REQUEST_URI !~ /\/$/;	
		} 
	}
		
}
sub handleFileCopiedEvent {
	my ($self, $data) = @_;
	my $dst = $$data{destination};
	my $db  = $$self{db};
	$dst=~s/\/$//;
	$db->db_deletePropertiesRecursiveByName($dst, $$self{namespace}.$$self{propname});
	$db->db_deletePropertiesRecursiveByName($dst, $$self{namespace}.$$self{seed});
	$db->db_deletePropertiesRecursiveByName($dst, $$self{namespace}.$$self{orig});
}
1;