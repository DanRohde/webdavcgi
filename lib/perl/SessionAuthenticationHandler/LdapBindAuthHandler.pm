########################################################################
# (C) ZE CMS, Humboldt-Universitaet zu Berlin
# Written by Daniel Rohde <d.rohde@cms.hu-berlin.de>
#########################################################################
# This is a very pure WebDAV server implementation that
# uses the CGI interface of a Apache webserver.
# Use this script in conjunction with a UID/GID wrapper to
# get and preserve file permissions.
# IT WORKs ONLY WITH UNIX/Linux.
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
#  config => {
#    server => 'localhost',
#    starttls => 1,
#    sslversion => 'tlsv1_2',
#    verify => 'required',
#    basedn => 'dn=localhost',
#    filter => '(uid=%s)',
#    userdn => 'uid=%s,dn=localhost', ## faster than search, if dn is fix
#    timelimit => 5,
#    sizelimit => 5,
#    scope => 'sub',
#    debug => 0,
#    binddn => undef,
#    password => undef,
# }
package SessionAuthenticationHandler::LdapBindAuthHandler;
use strict;
use warnings;

our $VERSION = '1.0';

use base qw(SessionAuthenticationHandler::AuthenticationHandler);

use CGI::Carp;
use Net::LDAP;
use Authen::SASL qw(Perl);
use English qw ( -no_match_vars );

use vars qw ( %DEFAULT_CONFIG );

%DEFAULT_CONFIG = (
    server     => 'localhost',
    starttls   => 1,
    timeout    => 2,
    onerror    => 'warn',
    sslversion => 'tlsv1_2',
    verify     => 1,
    basedn     => 'dn=localhost',
    filter     => '(uid=%s)',
    scope      => 'sub',
    binddn     => undef,
    password   => undef,
    timelimit  => 5,
    sizelimit  => 5,
    userdn     => undef,
    debug      => 0,
);

sub check_login {
    my ( $self, $config, $login, $password ) = @_;
    my %settings = ( %DEFAULT_CONFIG, %{$config} );
    my $ldap = Net::LDAP->new( $settings{server}, timeout=>$settings{timeout}, onerror=>$settings{onerror}, debug => $settings{debug} );
    if (!$ldap) {
        carp("Cannot connect to ldap server $settings{server}.");
        return 0;
    }
    if ( $settings{starttls} ) {
        $ldap->start_tls(
            verify     => $settings{verify},
            sslversion => $settings{sslversion}
        );
    }

    my $msg;
    my $userdn;
    if ( $settings{userdn} ) {
        $userdn = sprintf $settings{dn}, $login;
    }
    else {
        $msg =
          !defined $settings{binddn}
          ? $ldap->bind()
          : $ldap->bind( $settings{binddn}, password => $settings{password} );
        if ( $msg->code ) {
            carp( $msg->error );
            return 0;
        }
        my $f = sprintf $settings{filter}, $login;
        $msg = $ldap->search(
            base      => $settings{basedn},
            scope     => $settings{scope},
            sizelimit => $settings{sizelimit},
            timelimit => $settings{timelimit},
            filter    => $f,
            attrs     => ['dn'],
            raw       => qr/dn/xmsi
        );
        if ( $msg->code ) {
            carp( $msg->error );
            return 0;
        }
        my @entries = $msg->entries;
        if ( @entries != 1 ) {
            return 0;
        }
        $userdn = $entries[0]->get_value('dn');
    }
    $msg = $ldap->bind( $userdn, password => $password );
    if ( $msg->code ) {
        return 0;
    }
    $ldap->unbind;
    $ldap->disconnect();
    return 1;
}

1;
