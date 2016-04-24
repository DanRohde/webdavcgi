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
# SETUP:
# settings.savesettings - default behavior
#     (one of savesettings.dontsave, savesettings.saveall, 
#      savesettings.savesettingsonly, savesettings.savebookmarksonly)

package WebInterface::Extension::SaveSettings;

use strict;
use warnings;

our $VERSION = '2.0';
use base qw( WebInterface::Extension );

use DefaultConfig qw( $REMOTE_USER $DOCUMENT_ROOT );
use HTTPHelper qw( print_header_and_content );

sub init {
    my ( $self, $hookreg ) = @_;
    my @hooks = qw( javascript locales gethandler settings cookies );
    $hookreg->register( \@hooks, $self );
    $self->{settingsproperty} =
      '{http://webdavcgi.sf.net/[REMOTE_USER]}settings';
    $self->{settingspath} = $self->{backend}->resolveVirt($DOCUMENT_ROOT);
    return $self;
}

sub handle_hook_settings {
    my ( $self, $config, $params ) = @_;
    return $self->handle_settings_hook(
        {
            savesettings => [
                qw( savesettings.dontsave savesettings.saveall savesettings.savesettingsonly savesettings.savebookmarksonly )
            ]
        }
    );
}

sub handle_hook_gethandler {
    my ( $self, $config, $params ) = @_;
    my $action = $self->{cgi}->param('action') // q{};
    if ( $action eq 'savesettings' ) {
        my $pn      = $self->_get_property_name();
        my $cookies = $self->_get_cookies_json();
        $self->{db}->db_removeProperty( $self->{settingspath}, $pn );
        my %message = ();
        if ( $self->{db}
            ->db_insertProperty( $self->{settingspath}, $pn, $cookies ) )
        {
        #    $message{message} = $self->tl('savesettings.success');
        }
        else {
            $message{error} = $self->tl('savesettings.failed');
        }
        require JSON;
        print_header_and_content( '200 OK', 'application/json',
            JSON->new()->encode( \%message ) );
        return 1;
    }
    if ( $action eq 'deletesettings' ) {
        $self->{db}->db_removeProperty($self->{settingspath}, $self->_get_property_name());
        require JSON;
        print_header_and_content( '200 OK', 'application/json', JSON->new()->encode( {} ) );
        return 1;
    }
    return 0;
}

sub handle_hook_cookies {
    my ( $self, $config, $params ) = @_;
    my @setup = $self->_get_setup();
    my ( $ss, $allowsettings, $allowbookmarks ) = @setup;
    require JSON;
    my $settings = $self->{db}
      ->db_getProperty( $self->{settingspath}, $self->_get_property_name() );
    if ( !$settings || $settings eq q{} ) { return 1; }
    my $cookies = JSON->new()->decode($settings);
    my $path    = $self->get_vbase();

    foreach my $cookie ( @{$cookies} ) {
        my ( $key, $val ) = %{$cookie};
        if ( !$self->_is_allowed_setting( @setup, $key ) ) { next; }
        push @{ $params->{cookies} },
          $self->{cgi}->cookie(
            -name    => $key,
            -value   => $val,
            -expires => '+10y',
            -secure  => 1,
            -path    => $path
          );
    }
    return 1;
}

sub _get_setup {
    my ($self) = @_;
    my $ss = $self->{cgi}->cookie('settings.savesettings')
      // $self->config( 'settings.savesettings', 'savesettings.dontsave' );
    my $allowsettings =
      $ss =~ /^savesettings[.](?:saveall|savesettingsonly)$/xms;
    my $allowbookmarks =
      $ss =~ /^savesettings[.](?:saveall|savebookmarksonly)$/xms;
    return ( $ss, $allowsettings, $allowbookmarks );
}

sub _is_allowed_setting {
    my ( $self, $ss, $allowsettings, $allowbookmarks, $cookie ) = @_;
    if ( $ss eq 'savesettings.dontsave' ) { return 0; }
    return ( $allowbookmarks && $cookie =~ /^bookmark/xms )
      || ( $allowsettings && $cookie !~ /^bookmark/xms );
}

sub _get_cookies_json {
    my ($self)  = @_;
    my @setup   = $self->_get_setup();
    my @data    = ();
    my @cookies = $self->{cgi}->cookie();
    foreach my $cookie (@cookies) {
        if ( !$self->_is_allowed_setting( @setup, $cookie ) ) { next; }
        push @data, { $cookie => $self->{cgi}->cookie($cookie) };
    }
    require JSON;
    return JSON->new()->encode( \@data );
}

sub _get_property_name {
    my ($self) = @_;
    my $pn = $self->{settingsproperty};
    $pn =~
s{(?:\[([^\]]+)\])}{$DefaultConfig::{$1} ? ${$DefaultConfig::{$1}} : q{}  }exmsg;
    return $pn;
}

1;
