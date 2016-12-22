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
# IDEAS: Tröte als Icon, Admin-User kann anlegen und löschen, sonstige nur Anzeigen
#        Admin kann dauerhafte Anzeige erzwingen, Anzeige- und Ablaufdatum festlegen
#        und festlegen, ob einmalig oder in jeder Session
#        oder Text-Datei ins richtige Verzeichnis abwerfen (default: /etc/motd ;-)
#        Über Web wird motd in DB geschrieben (Property für alle lesbar)
#        Anzeige des Motd im Statusbar, im Apps/Prefs/Popup-Menü abrufbar
#        Nachrichten lokalisierbar machen (Sprachversionen unterstützen)
#          (mit default und Sprachdateien)
#        evtl. austauschbares Audio abspielen
#        Farbliche Gestaltung der Dialog-Box, z.B. mit HTML/CSS (evtl. HTML-Editor einbinden)
#
# ok  1. Version: Text-Datei einlesen, Nutzer pollt nach (geänderten) Nachrichten 
#                 und merkt sich in der Session, was er schon angezeigt bekommen hat
# ok  2. Version: Lokalisierbar machen anhand der Sprache des Nutzers
#     3. Version: Web-GUI zum Anzeigen, Anlegen, Löschen von motds inder DB
#       
# SETUP:
# motd - message file (HTML is allowed) and it can handle filenames with
#        '_$LANG' suffixes (e.g /etc/motd_de)
# motdmessage - motd as text; if exists motd parameter will be ignored
# motdtitle - motd dialog title (default: from locale files: motd.title)
# session - 1: (default) show MOTD every session, 0: otherwise
package WebInterface::Extension::MotD;

use strict;
use warnings;

our $VERSION = '2.0';
use base qw( WebInterface::Extension );

use DefaultConfig qw( $PATH_TRANSLATED $REQUEST_URI $LANG );
use HTTPHelper qw( print_compressed_header_and_content );

use JSON;

use FileUtils qw( stat2h get_local_file_content_and_type );

use vars qw( $ACTION );

$ACTION = 'motd';

sub init {
    my ( $self, $hookreg ) = @_;
    my @hooks = qw( css locales javascript gethandler statusbar pref );
    $hookreg->register( \@hooks, $self );

    $self->{json} = JSON->new();

    $self->{motd} = $self->config('motd', '/etc/motd');
    $self->{session} = $self->config('session', 1);
    $self->{motdmessage} = $self->config('motdmessage');

    return;
}

sub _get_motd_filename {
    my ($self) = @_;
    my $lfn = "$self->{motd}_$LANG";
    return -e $lfn ? $lfn : -e $self->{motd} ? $self->{motd} : undef;
}
sub _get_motd_and_timestamp {
    my ($self) = @_;
    if (defined $self->{motdmessage}) {
        require Digest::MD5;
        return ( $self->{motdmessage}, Digest::MD5::md5_hex($self->{motdmessage}) );
    }
    my $motdfn = $self->_get_motd_filename();
    my $stat = stat2h(stat $motdfn);
    return ( (get_local_file_content_and_type($motdfn))[1], $stat->{mtime});
}
sub handle_hook_gethandler {
    my ( $self, $config, $params ) = @_;
    my $action = $self->{cgi}->param('action') // q{};
    if ( $action eq $ACTION ) {
        my ( $motd, $timestamp ) = $self->_get_motd_and_timestamp();
        my $json = {
            message    => $motd,
            timestamp  => $timestamp,
            title      => $self->config('motdtitle', $self->tl('motd.title', 'Message Of The Day [MOTD]')),
            session    => $self->{session},
        };
        print_compressed_header_and_content( '200 OK', 'application/json', $self->{json}->encode($json) );
        return 1;
    }
    return 0;
}
sub _is_admin {
    my ( $self ) = @_;
    # TODO: 
    return 0;
}
sub handle_hook_pref {
    my ( $self, $config, $params ) = @_;
    return {
            action => 'showmotd',
            label  => $self->tl('motd.showmotd'),
            type   => 'li',
            attr   => { tabindex=> 0 },
        };
}
sub handle_hook_fileactionpopup {
    my ( $self, $config, $params ) = @_;
    if (!$self->_is_admin()) {
        return {
            action => 'showmotd',
            label  => $self->tl('motd.showmotd'),
            type   => 'li',
        };
    }
    return {
        label        => $self->tl('motd.motd'),
        popup => [
            {
                action => 'showmotd',
                label  => $self->tl('motd.showmotd'),
                type   => 'li',
            },
            {
                action => 'writemotd',
                label  => $self->tl('motd.write'),
                type   => 'li',
            },
            {
                action => 'editmotd',
                label  => $self->tl('motd.edit'),
                type   => 'li',
            },
            {
                action => 'deletemotd',
                label  => $self->tl('motd.delete'),
                type   => 'li',
            },
        ],
    };
}

sub handle_hook_statusbar {
    my ( $self, $config, $params ) = @_;
    return $self->{cgi}->div({-class=>'motd motd-statusbar', -tabindex=>0},q{});
}
1;