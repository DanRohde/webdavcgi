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
use warnings;
our $VERSION = '2.0';

use base qw( WebInterface::Extension  );

use DefaultConfig qw( $PATH_TRANSLATED );

sub init {
    my ( $self, $hookreg ) = @_;

    $self->{redirect} = $self->config( 'redirect', undef );

    my @hooks = qw( css javascript fileprop );
    if ( $self->config( 'enable_directredirect', 0 ) ) {
        push @hooks, 'gethandler';
    }
    if ( defined $self->{redirect} ) { $hookreg->register( \@hooks, $self ); }
    return $self;
}

sub _strip_slash {
    my ( $self, $path ) = @_;
    return $path =~ m{^(.*?)/+$}xms ? $1 : $path;
}

sub handle_hook_fileprop {
    my ( $self, $config, $params ) = @_;
    my $c = $self->{redirect};
    my $p = $self->_strip_slash( $params->{path} );
    return exists $c->{$p}
      ? {
        fileuri        => $c->{$p},
        uri            => $c->{$p},
        title          => $c->{$p},
        read           => 'yes',
        ext_classes    => 'redirect isreadable-yes iswriteable-no unselectable-yes ',
        ext_attributes => q{},
        ext_styles     => q{},
        isreadable     => 'yes',
        unselectable   => 'yes',
        iseditable     => 'no',
        isviewable     => 'no',
        writeable      => 'no'
      }
      : 0;
}

sub handle_hook_gethandler {
    my ( $self, $config, $params ) = @_;
    my $c = $self->{redirect};
    my $p = $self->_strip_slash($PATH_TRANSLATED);
    if ( $c && exists $c->{$p} ) {
        print $config->{cgi}->redirect( $c->{$p} );
        return 1;
    }
    return 0;
}

1;
