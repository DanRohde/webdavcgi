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
# disable_fileaction - disables fileaction entry
# disable_fileactionpopup - disables fileaction entry in popup menu
# enable_apps - disables sidebar menu entry
# 
# 

package WebInterface::Extension::Download;

use strict;

use WebInterface::Extension;
our @ISA = qw( WebInterface::Extension  );

sub init { 
	my($self, $hookreg) = @_; 
	
	$self->setExtension('Download');
	
	my @hooks = ('css','locales','javascript');
	push @hooks,'fileaction' unless $main::EXTENSION_CONFIG{Download}{disable_fileaction};
	push @hooks,'fileactionpopup' unless $main::EXTENSION_CONFIG{Download}{disable_fileactionpopup};
	push @hooks,'apps' if $main::EXTENSION_CONFIG{Download}{enable_apps};
	$hookreg->register(\@hooks, $self);
}

sub handle { 
	my ($self, $hook, $config, $params) = @_;
	my $ret = 0;
	$ret = $self->SUPER::handle($hook, $config, $params);
	return $ret if $ret;
	
	if ($hook eq 'fileaction') {
		$ret = { action=>'dwnload',label=>'dwnload', path=>$$params{path}, classes=>'access-readable is-file'};
	} elsif ($hook eq 'fileactionpopup') {
		$ret = { accesskey=>'s', action=>'dwnload', label=>'dwnload', path=>$$params{path}, type=>'li'};	
	} elsif ($hook eq 'apps') {
		$ret = $self->handleAppsHook($$self{cgi},'listaction dwnload sel-one sel-file disabled','dwnload','dwnload'); 		
	}
	return $ret;
}

1;