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

sub new {
        my $this = shift;
        my $class = ref($this) || $this;
        my $self = { };
        bless $self, $class;
        $self->init(shift);
        return $self;
}
sub init {
	my ($self, $hookreg) = @_;
}
sub setExtension {
	my ($self, $extension) = @_;
	$$self{EXTENSION} = $extension;
}
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
	my($self, $cgi, $action, $label, $title, $href) = @_;
	return $cgi->li({-title=>$self->tl($title || $label)},$cgi->a({-class=>"action $action", -href=> $href ? $href : '#'},$self->tl($label)));
}
sub handle { 
	my ($self, $hook, $config, $params) = @_;
	$$self{cgi} = $$config{cgi};
	$$self{backend}=$$config{backend};
	$$self{config}=$config;
	$$self{db} = $$config{db};
	$self->initialize(); ## Common::initialize to set correct LANG, ...
	$self->setLocale(); ## Common:setLocale to set right locale
	if ( $hook eq 'css' ) {
		return $self->handleCssHook($$self{EXTENSION});
	} elsif ( $hook eq 'javascript' ) {
		return $self->handleJavascriptHook($$self{EXTENSION});
	} elsif ( $hook eq 'locales') {
		return $self->handleLocalesHook($$self{EXTENSION});
	}
	return 0;
}
sub config {
	my ($self, $var, $default) = @_;
	return exists $main::EXTENSION_CONFIG{$$self{EXTENSION}}{$var} ? $main::EXTENSION_CONFIG{$$self{EXTENSION}}{$var} : $default;
}
sub readTemplate {
	my ($self,$filename) = @_;
	return $self->SUPER::readTemplate($filename, $self->getExtensionLocation($$self{EXTENSION},'templates/'));
}
1;