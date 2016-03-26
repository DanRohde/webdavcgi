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
# disable_fileaction - disables fileaction entry
# disable_fileactionpopup - disables fileaction entry in popup menu
# enable_apps - enables sidebar menu entry
# disable_binarydownload - sets the right MIME type
#

package WebInterface::Extension::Download;

use strict;
use warnings;

our $VERSION = '2.0';

use base qw( WebInterface::Extension  );

use FileUtils qw( is_hidden );
use HTTPHelper qw( print_file_header );

sub init {
    my ( $self, $hookreg ) = @_;

    $self->setExtension('Download');

    my @hooks = qw( css locales javascript );
    if ( !$main::EXTENSION_CONFIG{Download}{disable_fileaction} ) {
        push @hooks, 'fileaction';
    }
    if ( !$main::EXTENSION_CONFIG{Download}{disable_fileactionpopup} ) {
        push @hooks, 'fileactionpopup';
    }
    if ( $main::EXTENSION_CONFIG{Download}{enable_apps} ) {
        push @hooks, 'apps';
    }
    if ( !$main::EXTENSION_CONFIG{Download}{disable_binarydownload} ) {
        push @hooks, 'gethandler';
    }
    $hookreg->register( \@hooks, $self );
    return $self;
}

sub handle {
    my ( $self, $hook, $config, $params ) = @_;
    my $ret = $self->SUPER::handle( $hook, $config, $params );
    return $ret if $ret;

    my $add_classes =
      $main::EXTENSION_CONFIG{Download}{disable_binarydownload}
      ? 'disablebinarydownload'
      : q{};
    if ( $hook eq 'fileaction' ) {
        return {
            action  => 'dwnload',
            label   => 'dwnload',
            path    => $params->{path},
            classes => 'access-readable is-file ' . $add_classes
        };
    }
    if ( $hook eq 'fileactionpopup' ) {
        return {
            accesskey => 's',
            action    => 'dwnload',
            label     => 'dwnload',
            path      => $params->{path},
            type      => 'li',
            classes   => $add_classes
        };
    }
    if ( $hook eq 'apps' ) {
        return $self->handleAppsHook( $self->{cgi},
            'listaction dwnload sel-one sel-file disabled ' . $add_classes,
            'dwnload', 'dwnload' );
    }
    if ( $hook eq 'gethandler' && $self->{cgi}->param('action') && $self->{cgi}->param('action') eq 'dwnload' ) {
        my $fn   = $self->{cgi}->param('file');
        my $file = $main::PATH_TRANSLATED . $fn;
        if ( $self->{backend}->exists($file) && !is_hidden($file) ) {
            if ( !$self->{backend}->isReadable($file) ) {
                main::print_header_and_content(
                    main::get_error_document(
                        '403 Forbidden',
                        'text/plain',
                        '403 Forbidden'
                    )
                );
            }
            else {
                my $qfn = $fn;
                $qfn =~ s/"/\\"/xmsg;
                print_file_header(
                    $file,
                    {
                        -Content_Disposition => 'attachment; filename="'
                          . $qfn . q{"},
                        -type => 'application/octet-stream'
                    }
                );
                $self->{backend}->printFile( $file, \*STDOUT );
            }
        }
        else {
            main::print_header_and_content(
                main::get_error_document(
                    '404 Not Found',
                    'text/plain', '404 - FILE NOT FOUND'
                )
            );
        }
        return 1;
    }
    return 0;
}

1;
