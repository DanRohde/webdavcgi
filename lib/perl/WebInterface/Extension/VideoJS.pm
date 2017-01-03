#########################################################################
# (C) ZE CMS, Humboldt-Universitaet zu Berlin
# Written 2015 by Daniel Rohde <d.rohde@cms.hu-berlin.de>
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
# template - viewerjs template filename

package WebInterface::Extension::VideoJS;

use strict;
use warnings;
our $VERSION = '2.0';

use base qw( WebInterface::Extension  );

use DefaultConfig qw( $LANG $PATH_TRANSLATED $REQUEST_URI %EXTENSION_CONFIG );
use HTTPHelper qw( get_mime_type print_compressed_header_and_content );

use vars qw( $ACTION );

$ACTION = 'videojs';

sub init {
    my ( $self, $hookreg ) = @_;
    my @hooks = qw(css locales javascript posthandler appsmenu);
    if ( !$EXTENSION_CONFIG{VideoJS}{disable_fileactionpopup} ) {
        push @hooks, 'fileactionpopup';
    }
    if ( !$EXTENSION_CONFIG{VideoJS}{disable_fileaction} ) {
        push @hooks, 'fileaction';
    }
    $hookreg->register( \@hooks, $self );
    return $self;
}

sub handle_hook_fileactionpopup {
    my ( $self, $config, $params ) = @_;
    return {
        action => $ACTION,
        label  => $ACTION,
        path   => $params->{path},
        type   => 'li'
    };
}

sub handle_hook_fileaction {
    my ( $self, $config, $params ) = @_;
    return {
        action  => $ACTION,
        label   => $ACTION,
        path    => $params->{path},
        classes => 'access-readable'
    };
}
sub handle_hook_appsmenu {
    my ( $self ) = @_;
    return {
        action => $ACTION,
        label  => $ACTION,
        classes => 'access-readable sel-one-suffix hideit',
        data => { suffix => q{(?:mp4|ogv|webm)}, },
    };
}
sub handle_hook_posthandler {
    my ($self) = @_;
    if (   $self->{cgi}->param('action')
        && $self->{cgi}->param('action') eq 'videojs' )
    {
        return $self->_render_viewerjs( scalar $self->{cgi}->param('file') );
    }
    return 0;
}
sub _render_viewerjs {
    my ( $self, $filename ) = @_;
    my $vars = {
        filename => $REQUEST_URI . $filename,
        mime     => get_mime_type($filename),
        lang     => $LANG eq 'default' ? 'en' : $LANG
    };
    my $content =
      $self->render_template( $PATH_TRANSLATED, $REQUEST_URI,
        $self->read_template( $self->config( 'template', 'videojs' ) ), $vars );
    print_compressed_header_and_content( '200 OK', 'text/html', $content );
    return 1;
}
1;
