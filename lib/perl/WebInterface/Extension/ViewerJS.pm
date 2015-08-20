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
#
# SETUP:
# disable_fileactionpopup - disables file action entry in popup menu
# disable_fileaction - disables file action 

package WebInterface::Extension::ViewerJS;

use strict;

use WebInterface::Extension;
our @ISA = qw( WebInterface::Extension  );


sub init { 
	my($self, $hookreg) = @_; 
	my @hooks = ('css','locales','javascript', 'fileattr', 'gethandler');
	push @hooks,'fileactionpopup' unless $self->config('disable_fileactionpopup',0);
	push @hooks,'fileaction' unless $self->config('disable_fileaction',0);
	$hookreg->register(\@hooks, $self);
}
sub handle { 
	my ($self, $hook, $config, $params) = @_;
	if ($hook eq 'fileattr') {
		return { ext_classes=>'viewerjs-'.($$params{path}=~/\.(odt|odp|ods|pdf)$/i ? 'yes' : 'no')  };
	} 
	my $ret = $self->SUPER::handle($hook, $config, $params);
	return $ret if $ret;
	
	if ($hook eq 'fileactionpopup') {
		$ret =   { action=>'viewerjs', label=>'viewerjs.view', type=>'li'};
	} elsif ($hook eq 'fileaction') {
		$ret =   { action=>'viewerjs', label=>'viewerjs.view'};
	} elsif ($hook eq 'gethandler') {
		$ret = $self->handleGetRequest('view') if $$self{cgi}->param('action') eq 'viewerjs';
	}
	 
	return $ret;
}
sub handleGetRequest {
	my ($self,$template) = @_;
	my ($self) = @_;
	my $file = $$self{cgi}->param('file');
	my $fileuri = $main::REQUEST_URI.$$self{cgi}->escape($file);
	my $tmpl = $self->renderTemplate($main::PATH_TRANSLATED, $main::REQUEST_URI, $self->readTemplate($template), { fileuri=>$fileuri, file=>$$self{cgi}->escapeHTML($file) });
	main::printCompressedHeaderAndContent('200 OK', 'text/html', $tmpl, 'Cache-Control: no-cache, no-store');
	return 1;
}
1;