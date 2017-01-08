#!/usr/bin/perl
########################################################################
# (C) ZE CMS, Humboldt-Universitaet zu Berlin
# Written by Daniel Rohde <d.rohde@cms.hu-berlin.de>
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

use strict;
use warnings;

our $VERSION = '1.0';


use CGI;
use CGI::Carp;

use MIME::Base64;

use SessionAuthenticationHandler;
use DefaultConfig;
use WebDAVCGI;

use vars qw( $W %SESSION $REALM );


sub send_auth_required_response() {
    print CGI::header(-status=>'401 Unauthorized', -WWW_Authenticate=>sprintf 'Basic realm="%s"', $REALM);
    return;
}

sub get_login_password {
    my ($authheader) = @_;
    if ($authheader =~ /^ Basic \s+ (\S+) $/xmsi) {
        my $cred = decode_base64($1);
        return split /:/xms, $cred, 2;
    }
    return ( 'unknown', 'unknown' );
}

sub letsplay {

    my $conf = $ENV{SESSIONCONF} // '/etc/webdav-session.conf';
    my $authheader = $ENV{AUTHHEADER};

    require $conf;

    $REALM //= $ENV{REALM} // $ENV{DOMAIN} // 'default';

    if (!$authheader) {
        send_auth_required_response();
        return;
    }
    my $handler = SessionAuthenticationHandler->new();
    my ($login, $password) = get_login_password($authheader);

    my @domains = $ENV{DOMAIN}
                    ? ( $ENV{DOMAIN} )
                    : sort {
                             ref $SESSION{domains}{$a} eq 'HASH'
                                 ? ( $SESSION{domains}{$a}{_order} // 0) <=> ( $SESSION{domains}{$b}{_order} // 1 ) || $a cmp $b
                                 : $a cmp $b
                           }
                           keys %{$SESSION{domains}};
    foreach my $domain ( @domains ) {
        if (my $auth=$handler->check_credentials(\%SESSION, $domain, $login, $password)) {
            $ENV{REMOTE_USER} = $login;
            DefaultConfig::init_defaults();
            $handler->set_domain_defaults($auth);
            $W //= WebDAVCGI->new();
            $W->run();
            return;
        }
    }
    send_auth_required_response();
    return;
}

letsplay();

1;