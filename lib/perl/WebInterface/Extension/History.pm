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

package WebInterface::Extension::History;

use strict;
use warnings;
our $VERSION = '2.0';

use base qw( WebInterface::Extension  );

sub init {
    my ( $self, $hookreg ) = @_;
    my @hooks = qw(css locales javascript fileactionpopup appsmenu);
    $hookreg->register( \@hooks, $self );
    return $self;
}

sub handle_hook_fileactionpopup {
    my ( $self, $config, $params ) = @_;
    return {
        title      => $self->tl('history'),
        popup      => [ { action => 'history-clear', label=>$self->tl('history.clear'), classes=>'sep' } ],
        classes    => 'history-popup',
        type       => 'li',
        subclasses => 'history-popup-history',
    };
}
sub handle_hook_appsmenu {
    my ( $self, $config, $params ) = @_;
    return $self->handle_hook_fileactionpopup($config, $params);
}

1;
