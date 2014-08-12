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

package WebInterface::Extension::PublicUri::Common;

use strict;

use WebInterface::Extension;
our @ISA = qw( WebInterface::Extension  );

use Digest::MD5 qw(md5_hex);

sub initDefaults {
	my ($self) = @_;
	
	$$self{namespace} = $self->config('namespace', '{http://webdavcgi.sf.net/extension/PublicUri/}');
	$$self{propname} = $self->config('propname', 'public_prop');
	$$self{seed} = $self->config('seed', 'seed');
	$$self{orig} = $self->config('orig', 'orig');
	$$self{prefix} = $self->config('prefix','');
		
	$$self{uribase} = $self->config('uribase', 'https://'.$ENV{HTTP_HOST}.'/public/');

	$$self{virtualbase} = $self->config('basepath', '/public/');
	$$self{allowedpostactions} = $self->config('allowedpostactions','^(zipdwnload|diskusage|search|diff)$')
	  
}

sub getPropertyName {
	my ($self) = @_;
	return $$self{namespace}.$$self{propname};
}
sub getSeedName {
	my ($self) = @_;
	return $$self{namespace}.$$self{seed};
}
sub getOrigName {
	my ($self) = @_;
	return $$self{namespace}.$$self{orig};
}
sub getFileFromCode {
	my ( $self, $digest ) = @_;
	my $fna = $$self{db}->db_getPropertyFnByValue($self->getPropertyName(), $digest);
	return $fna ? $$fna[0] : undef;
}
sub getSeed {
	my ( $self, $fn) = @_;
	return $$self{db}->db_getProperty($fn, $self->getSeedName());
}
sub getOrig {
	my ( $self, $fn) = @_;
	return $$self{db}->db_getProperty($fn, $self->getOrigName());
}
sub getDigest {
	my ($self, $fn, $seed) = @_;
	return $$self{prefix}.substr(md5_hex($fn.$seed), 0, 16);
}
sub genUrlHash {
	my ($self, $fn) = @_;
	my $seed   = time().int(rand(time())) . md5_hex($main::REMOTE_USER) . $fn;
	my $digest = $self->getDigest($fn, $seed);
	return $digest, $seed;
}
sub isPublicUri {
	my ($self, $fn, $code, $seed) = @_;
	return $code eq $self->getDigest($self->getOrig($fn), $seed);
}

1;