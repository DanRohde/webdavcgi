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
# redirect - sets folder/files for a redirect
#             format: { '/full/file/path' => 'url' , ... }
# enable_directredirect - enables redirects of direct calls to redirected pathes (default: off)

package WebInterface::Extension::Redirect;

use strict;

use WebInterface::Extension;
our @ISA = qw( WebInterface::Extension  );


sub init { 
	my($self, $hookreg) = @_; 
	
	$$self{redirect} = $self->config('redirect', undef); 
	
	my @hooks = ('css','javascript', 'fileprop');
	push @hooks, 'gethandler' if $self->config('enable_directredirect', 0); 
	$hookreg->register(\@hooks, $self) if defined $$self{redirect};
}
sub stripSlash {
	my ($self, $path) = @_;
	return $path=~/^(.*?)\/+$/ ? $1 : $path;
}
sub handle { 
	my ($self, $hook, $config, $params) = @_;
	my $ret = 0;
	if ($hook eq 'fileprop') {
		my $c = $$self{redirect};
		my $p = $self->stripSlash($$params{path});
		$ret = { 'fileuri'=>$$c{$p}, ext_classes=>'redirect ', ext_attributes=>'', ext_styles=>'', isreadable=>'yes', unselectable=>'yes', iseditable=>'no', isviewable=>'no', writeable=>'no' } 
			if $c && exists $$c{$p};
	} elsif ($hook eq 'gethandler') {
		my $c = $$self{redirect};
		my $p = $self->stripSlash($main::PATH_TRANSLATED);
		if ($c && exists $$c{$p}) {
			print $$config{cgi}->redirect($$c{$p});
			$ret = 1;
		}
	} else {
		$ret = $self->SUPER::handle($hook, $config, $params);	
	}
	return $ret;
}

1;