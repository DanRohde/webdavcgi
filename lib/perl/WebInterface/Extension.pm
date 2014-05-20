#!/usr/bin/perl
#########################################################################
# (C) ZE CMS, Humboldt-Universitaet zu Berlin
# Written 2010-2014 by Daniel Rohde <d.rohde@cms.hu-berlin.de>
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

package WebInterface::Extension;

use WebInterface::Renderer;
our @ISA = ( 'WebInterface::Renderer');

sub getExtensionLocation {
	my ($self, $extension, $file) = @_;
	return $main::INSTALL_BASE.'lib/perl/WebInterface/Extension/'.$extension.'/'.$file;
}
sub getExtensionUri {
	my ($self, $extension, $file) = @_;	
	return $main::VHTDOCS.'_EXTENSION('.$extension.')_/'.$file;
}

sub handleJavascriptHook {
	my($self, $extension, $file) = @_;
	return q@<script src="@.$self->getExtensionUri($extension,$file || 'htdocs/script.min.js').q@"></script>@;
}
sub handleCssHook {
	my($self, $extension, $file) = @_;
	return q@<link rel="stylesheet" type="text/css" href="@.$self->getExtensionUri($extension,$file || 'htdocs/style.min.css').q@">@;
}
sub handleLocalesHook {
	my($self, $extension, $file) = @_;
	return $self->getExtensionLocation($extension, $file || 'locale/locale');
}
sub handleAppsHook {
	my($self, $cgi, $action, $label, $title) = @_;
	return $cgi->li({-title=>$self->tl($title || $label)},$cgi->a({-class=>"action $action", -href=>'#'},$self->tl($label)));
}

1;