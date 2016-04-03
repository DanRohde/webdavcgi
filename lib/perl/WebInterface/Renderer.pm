#########################################################################
# (C) ZE CMS, Humboldt-Universitaet zu Berlin
# Written 2010-2016 by Daniel Rohde <d.rohde@cms.hu-berlin.de>
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

package WebInterface::Renderer;

use strict;
use warnings;

our $VERSION = '2.0';

use Module::Load;
use CGI::Carp;

use DefaultConfig qw( $INSTALL_BASE $VIEW @SUPPORTED_VIEWS );
use vars qw( %_RENDERER );

sub new {
    my $class = shift;
    my $self = {};
    bless $self, $class;
    $self->{config} = shift;
    return $self;
}

sub _get_renderer {
    my ($self) = @_;
    my $view = "WebInterface::View::\u${VIEW}::Renderer";
    $view =~ s/[.\/]+//xmsg;
    if ( !-f "${INSTALL_BASE}lib/perl/WebInterface/View/\u${VIEW}/Renderer.pm" )
    {
        $view = "WebInterface::View::\u$SUPPORTED_VIEWS[0]::Renderer";
    }
    if ( exists $_RENDERER{$self}{$view} ) {
        return $_RENDERER{$self}{$view};
    }
    load $view;
    $_RENDERER{$self}{$view} = $view->new( ${$self}{config} );
    return $_RENDERER{$self}{$view};
}

sub render_web_interface {
    my ( $self ) = @_;
    my $_RENDERER = $self->_get_renderer();
    return $_RENDERER->render();
}

1;
