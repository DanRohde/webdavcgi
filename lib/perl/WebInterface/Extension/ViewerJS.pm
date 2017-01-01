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
use warnings;
our $VERSION = '2.0';

use base qw( WebInterface::Extension  );

use DefaultConfig qw( $PATH_TRANSLATED $REQUEST_URI );
use HTTPHelper qw( print_compressed_header_and_content );

sub init {
    my ( $self, $hookreg ) = @_;
    my @hooks = qw( css locales javascript fileattr posthandler );
    if ( !$self->config( 'disable_fileactionpopup', 0 ) ) {
        push @hooks, 'fileactionpopup';
    }
    if ( !$self->config( 'disable_fileaction', 0 ) ) {
        push @hooks, 'fileaction';
    }
    $hookreg->register( \@hooks, $self );
    return $self->SUPER::init($hookreg);
}

sub handle_hook_fileattr {
    my ( $self, $config, $params ) = @_;
    return { ext_classes => 'viewerjs-'
          . ( $params->{path} =~ /[.](?:odt|odp|ods|pdf)$/xmsi ? 'yes' : 'no' )
    };
}

sub handle_hook_fileactionpopup {
    return { action => 'viewerjs', label => 'viewerjs.view', type => 'li' };
}

sub handle_hook_fileaction {
    return { action => 'viewerjs', label => 'viewerjs.view' };
}

sub handle_hook_posthandler {
    my ( $self, $config, $params ) = @_;
    if ( defined $self->{cgi}->param('action')
        && $self->{cgi}->param('action') eq 'viewerjs' )
    {
        return $self->_handle_post_request('view');
    }
    return 0;
}

sub _handle_post_request {
    my ( $self, $template ) = @_;
    my $file    = $self->{cgi}->param('file');
    my $fileuri = $REQUEST_URI . $self->{cgi}->escape($file);
    my $tmpl    = $self->render_template(
        $PATH_TRANSLATED, $REQUEST_URI,
        $self->read_template($template),
        { fileuri => $fileuri, file => $self->{cgi}->escapeHTML($file) }
    );
    print_compressed_header_and_content( '200 OK', 'text/html', $tmpl,
        'Cache-Control: no-cache, no-store' );
    return 1;
}
1;
