#########################################################################
# (C) ZE CMS, Humboldt-Universitaet zu Berlin
# Written 2016 by Daniel Rohde <d.rohde@cms.hu-berlin.de>
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

# TODO: change package name
package WebInterface::Extension::Skeleton;

use strict;
use warnings;

our $VERSION = '2.0';
use base qw( WebInterface::Extension );

use DefaultConfig qw( $PATH_TRANSLATED $REQUEST_URI );
use HTTPHelper qw( print_compressed_header_and_content );

#use FileUtils qw( );

use vars qw( $ACTION );

# TODO: define a ACTION name
$ACTION = '_REPLACE_ME_WITH_A_ACTION_NAME_';

sub init {
    my ( $self, $hookreg ) = @_;
    my @hooks = qw( css locales javascript fileactionpopup posthandler );
    $hookreg->register( \@hooks, $self );
    return;
}

# TODO: handle hooks

sub handle_hook_fileactionpopup {
    my ( $self, $config, $params ) = @_;
    return {
        action => $ACTION,
        label  => $ACTION,
        path   => ${$params}{path},
    };
}

sub handle_hook_posthandler {
    my ( $self, $config, $params ) = @_;
    my $action = $self->{cgi}->param('action') // q{};
    if ( $action eq $ACTION ) {
        return print_compressed_header_and_content( '200 OK', 'text/html',
            '<!DOCTYPE html><html><head></head><body></body></html>' );
    }
    return 0;
}

# template:
sub handle_hook_ {
    my ( $self, $config, $params ) = @_;
    return 0;
}
1;
