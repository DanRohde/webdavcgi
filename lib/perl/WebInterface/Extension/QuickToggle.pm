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
# toggles - template file
# disable_filterbox - disables filterbox entry
# enable_apps - enables sidebar menu entry 
# enable_pref - enables sidebar menu entry (after preferences)



package WebInterface::Extension::QuickToggle;

use strict;

use WebInterface::Extension;
our @ISA = qw( WebInterface::Extension  );

use vars qw( $ACTION );

sub init { 
	my($self, $hookreg) = @_; 
	my @hooks = ('css','locales','javascript');
	push @hooks,'filterbox' unless $self->config('disable_filterbox',0);
	push @hooks,'apps' if $self->config('enable_apps', 0);
	push @hooks,'pref' if $self->config('enable_pref', 0);
	$hookreg->register(\@hooks, $self);
}
sub handle { 
	my ($self, $hook, $config, $params) = @_;
	my $ret = $self->SUPER::handle($hook, $config, $params);
	return $ret if $ret;
	
	if ($hook eq 'filterbox' || $hook eq 'apps' || $hook eq 'pref') {
		$ret = $self->renderTemplate($main::PATH_TRANSLATED, $main::REQUEST_URI, $self->readTemplate($self->config('toggles','toggles')));
		$ret = $$self{cgi}->li($$self{cgi}->a({-href=>'#'}, $ret)) unless $hook eq 'filterbox';
	
	} 
	return $ret;
}

1;