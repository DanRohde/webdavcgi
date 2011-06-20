#########################################################################
# (C) ZE CMS, Humboldt-Universitaet zu Berlin
# Written 2010-2011 by Daniel Rohde <d.rohde@cms.hu-berlin.de>
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

package WebInterface::Extension::Manager;

use strict;

use Module::Load;

##our @SUPPORTED_HOOKS = ( 'gethandler', 'posthandler', 'header', 'search', 'viewtools', 'quota', 'sidebar', 'getFolderList', 'toolbar' );
our @SUPPORTED_HOOKS = ( 'gethandler', 'fileaction' );

##  HOOKS:
##     gethandler - return: 1 (handled) | 0 (not handled)
##     fileaction - return: { action=>'actionname', label=>'keyfromlocaledb', disabled=>0 }

our %HOOKS;

sub new {
        my $this = shift;
	my $class = ref($this) || $this;
	my $self = { };
	bless $self, $class;
	$$self{config}=shift;
	$$self{config}{db} = shift;
	$self->init($self);
	return $self;
}

sub init {
	my ($self) = @_;
	foreach my $extname (@main::EXTENSIONS) {
		eval { 
			load "WebInterface::Extension::$extname";
			my $extension = "WebInterface::Extension::$extname"->new($self);
		};
		warn("Can't load extensions $extname: $@") if $@;
	}
}

sub register {
	my($self, $hook, $handler) = @_;
	$HOOKS{$self}{$hook} = [ ] unless exists $HOOKS{$self}{$hook};
	push @{$HOOKS{$self}{$hook}}, $handler;
	return 1;
}

sub handle {
	my ($self, $hook, $params) = @_;
	return undef unless exists $HOOKS{$self}{$hook};
	my @ret;
	foreach my $handler (@{$HOOKS{$self}{$hook}}) {
		push @ret, $handler->handle($hook,$$self{config},$params);
	}
	return \@ret;
}

1;
