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
# TODO: describe extension setup


package WebInterface::Extension::History;

use strict;

use WebInterface::Extension;
our @ISA = qw( WebInterface::Extension  );


sub init { 
	my($self, $hookreg) = @_; 
	my @hooks = ('css','locales','javascript','fileactionpopup');
	$hookreg->register(\@hooks, $self);
}
sub handle { 
	my ($self, $hook, $config, $params) = @_;
	my $ret = $self->SUPER::handle($hook, $config, $params);
	return $ret if $ret;
	
	if ($hook eq 'fileactionpopup') {
		$ret = { title=>$self->tl('history'), subpopupmenu=>[], classes=>'history-popup', type=>'li' };
	}
	 
	return $ret;
}

1;