#!/usr/bin/perl
#########################################################################
# (C) ZE CMS, Humboldt-Universitaet zu Berlin
# Written 2010-2014 by Daniel Rohde <d.rohde@cms.hu-berlin.de>
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

package WebInterface::Extension;

use strict;
use warnings;

our $VERSION = '2.0';

use base qw( WebInterface::Common );

use DefaultConfig qw( $INSTALL_BASE $VHTDOCS %EXTENSION_CONFIG );

sub new {
    my ( $class, $hookreg, $extensionname, $config ) = @_;
    my $self = {};
    bless $self, $class;
    $self->{EXTENSION} = $extensionname;
    $self->{config}    = $config;
    $self->{backend}   = $config->{backend};
    $self->{db}        = $config->{db};
    $self->{cgi}       = $config->{cgi};
    return $self->init($hookreg);
}

sub init {
    my ( $self, $hookreg ) = @_;
    return $self;
}

sub setExtension {
    my ( $self, $extension ) = @_;
    ${$self}{EXTENSION} = $extension;
    return;
}

sub getExtensionLocation {
    my ( $self, $extension, $file ) = @_;
    return
        $INSTALL_BASE
      . 'lib/perl/WebInterface/Extension/'
      . $extension . q{/}
      . $file;
}

sub getExtensionUri {
    my ( $self, $extension, $file ) = @_;
    my $vbase = $self->get_vbase();
    $vbase .= $vbase !~ /\/$/xms ? q{/} : q{};
    return $vbase . $VHTDOCS . '_EXTENSION(' . $extension . ')_/' . $file;
}

sub handleJavascriptHook {
    my ( $self, $extension, $file ) = @_;
    return
        q@<script src="@
      . $self->getExtensionUri( $extension, $file || 'htdocs/script.min.js' )
      . q@"></script>@;
}

sub handleCssHook {
    my ( $self, $extension, $file ) = @_;
    return
        q@<link rel="stylesheet" type="text/css" href="@
      . $self->getExtensionUri( $extension, $file || 'htdocs/style.min.css' )
      . q@">@;
}

sub handleLocalesHook {
    my ( $self, $extension, $file ) = @_;
    return $self->getExtensionLocation( $extension, $file || 'locale/locale' );
}

sub handleAppsHook {
    my ( $self, @args ) = @_;
    my ( $cgi, $action, $label, $title, $href ) = @args;
    return $cgi->li(
        { -title => $self->tl( $title // $label ) },
        $cgi->a(
            { -class => "action $action", -href => $href ? $href : q{#} },
            $cgi->span( { -class => 'label' }, $self->tl($label) )
        )
    );
}

sub handleSettingsHook {
    my ( $self, $settings ) = @_;
    my $ret = q{};
    if ( ref($settings) eq 'ARRAY' ) {
        foreach my $setting ( @{$settings} ) {
            $ret .= $self->handleSettingsHook($setting);
        }
    }
    else {
        $ret .= ${$self}{cgi}->Tr(
            ${$self}{cgi}->td( $self->tl("settings.$settings") )
              . ${$self}{cgi}->td(
                ${$self}{cgi}->checkbox(
                    -name  => "settings.$settings",
                    -label => q{}
                )
              )
        );
    }
    return $ret;
}

sub handle {
    my ( $self, $hook, $config, $params ) = @_;
    ${$self}{cgi}     = ${$config}{cgi};
    ${$self}{backend} = ${$config}{backend};
    ${$self}{config}  = $config;
    ${$self}{db}      = ${$config}{db};
    $self->initialize();    ## Common::initialize to set correct LANG, ...
    $self->set_locale();    ## Common:set_locale to set right locale
    if ( $hook eq 'css' ) {
        return $self->handleCssHook( ${$self}{EXTENSION} );
    }
    elsif ( $hook eq 'javascript' ) {
        return $self->handleJavascriptHook( ${$self}{EXTENSION} );
    }
    elsif ( $hook eq 'locales' ) {
        return $self->handleLocalesHook( ${$self}{EXTENSION} );
    }
    return 0;
}

sub config {
    my ( $self, $var, $default ) = @_;
    return $EXTENSION_CONFIG{ ${$self}{EXTENSION} }{$var} // $default;
}

sub read_template {
    my ( $self, $filename ) = @_;
    return $self->SUPER::read_template( $filename,
        $self->getExtensionLocation( ${$self}{EXTENSION}, 'templates/' ) );
}

sub exec_template_function {
    my ( $self, $fn, $ru, $func, $param ) = @_;
    my $content;
    if ( $func eq 'extconfig' ) {
        $content = $self->config( $param, 0 ) // q{};
    }
    $content //=
      $self->SUPER::exec_template_function( $fn, $ru, $func, $param );
    return $content;
}
1;
