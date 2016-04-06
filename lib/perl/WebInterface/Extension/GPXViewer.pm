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

package WebInterface::Extension::GPXViewer;

use strict;
use warnings;
our $VERSION = '2.0';

use base qw( WebInterface::Extension  );

use DefaultConfig qw( $PATH_TRANSLATED $REQUEST_URI );
use HTTPHelper qw( print_header_and_content );

sub init {
    my ( $self, $hookreg ) = @_;
    my @hooks = qw(css locales javascript fileactionpopup posthandler);
    $hookreg->register( \@hooks, $self );
    return $self;
}

sub handle {
    my ( $self, $hook, $config, $params ) = @_;
    if ( my $ret = $self->SUPER::handle( $hook, $config, $params ) ) {
        return $ret;
    }

    if ( $hook eq 'fileactionpopup' ) {
        return {
            action => 'gpxviewer',
            label  => 'gpxviewer',
            path   => $params->{path},
            type   => 'li'
        };
    }
    my $action = $self->{cgi}->param('action') // q{};
    if ( $hook eq 'posthandler' && $action eq 'gpxviewer' ) {
        print_header_and_content(
            '200 OK',
            'text/html',
            $self->render_template(
                $PATH_TRANSLATED,
                $REQUEST_URI,
                $self->read_template('gpxviewer'),
                {
                    file =>
                      $self->{cgi}->escapeHTML( scalar $self->{cgi}->param('file') )
                }
            ),
            'Cache-Control: no-cache, no-store'
        );
        return 1;
    }
    return 0;
}

1;
