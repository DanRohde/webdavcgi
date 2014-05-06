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

package WebInterface::Extension::DiskUsage;

use strict;

use WebInterface::Extension;
our @ISA = qw( WebInterface::Extension );

sub new {
        my $this = shift;
        my $class = ref($this) || $this;
        my $self = { };
        bless $self, $class;
        $self->init(shift);
        return $self;
}

sub init { 
	my($self, $hookreg) = @_; 
	$hookreg->register('fileaction', $self);
	$hookreg->register('fileactionpopup', $self);
	$hookreg->register('css', $self);
	$hookreg->register('javascript', $self);
	$hookreg->register('locales', $self);
}

sub handle { 
	my ($self, $hook, $config, $params) = @_;
	$$self{backend} = $$config{backend};
	if ($hook eq 'fileaction') {
		return { action=>'diskusage', disabled=>!$$self{backend}->isDir($$params{path})||!$$self{backend}->isReadable($$params{path}), label=>'diskusage', path=>$$params{path} };
	} elsif( $hook eq 'fileactionpopup') {
		return { action=>'diskusage', disabled=>!$$self{backend}->isDir($$params{path})||!$$self{backend}->isReadable($$params{path}), label=>'diskusage', path=>$$params{path}, type=>'li' };
	} elsif ( $hook eq 'css' ) {
		return q@<link rel="stylesheet" type="text/css" href="@.$self->getExtensionUri('DiskUsage','htdocs/style.css').q@">@;
	} elsif ( $hook eq 'javascript' ) {
		return q@<script src="@.$self->getExtensionUri('DiskUsage','htdocs/script.js').q@"></script>@;
	} elsif ( $hook eq 'locales') {
		return $self->getExtensionLocation('DiskUsage','locale/locale');
	}
	return 0; 
}

1;