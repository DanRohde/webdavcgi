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
# %SESSION = (
#      tokenname => 'TOKEN',
#      secret => 'uP:oh2oo',
#      expire => '+10m', # can be overwritten by domain
#      temp => '/tmp',
#      domains => {
#          DOMAIN1 => [ # multiple handler
#              {
#                  authhandler => qw( SessionAuthenticationHandler::AuthenticationHandler ),
#                  expire => '+10m', # default
#                  config => {  whatever => 'here comes'  },
#              }, ...
#          ],
#          DOMAIN2 => { ... }, # single handler
#      ...
#      }
# );
package SessionAuthenticationHandler;
use strict;
use warnings;

our $VERSION = '1.0';

use CGI::Carp;
use WWW::CSRF qw(generate_csrf_token check_csrf_token CSRF_OK );
use Bytes::Random::Secure;

use DefaultConfig qw( %SESSION $REMOTE_USER $REQUEST_URI $REQUEST_METHOD $LANG);
use HTTPHelper qw( print_compressed_header_and_content );
sub new {
   my ($class, $cgi) = @_;
   my $self  = {};
   bless $self, $class;
   $self->{cgi} = $cgi;
   $self->{random} = Bytes::Random::Secure->new(Bits => 512, NonBlocking => 1); ## by default CSRF uses /dev/random but /dev/urandom has more random bytes
   return $self;
}
# 0 : unauthenticated -> login screen
# 1 : authenticated
# 2 : fresh authenticated -> redirect -> exit 
sub authenticate {
    my ($self) = @_;
    require CGI::Session;
    my $session = CGI::Session->load('driver:File', $self->{cgi}, {Directory => $SESSION{temp} // '/tmp'});
    if (! defined $session) {
        carp("${self}: ".CGI::Session->errstr());
        if ($self->{cgi}->param('error')) { # prevent redirect loop
            return $self->_handle_goto_login();
        }
        return $self->_handle_redirect($session, error=>CGI::Session->errstr());
    }
    $self->_set_defaults();
    if ($session->is_expired) {
        if ($self->{cgi}->param('logon')) { # prevent redirect loop
            return $self->_handle_goto_login($session);
        }
        return $self->_handle_redirect($session, logon=>'session', from=>1);
    }
    if ($REMOTE_USER = $session->param('login')) { ## login exists
        if ($self->{cgi}->param('logout')) { ## logout requested
            return $self->_handle_goto_login($session);
        }
        if ($self->_check_token($REMOTE_USER)) {
            $self->_create_token($REMOTE_USER);
            return 1;
        }
        return $self->_handle_redirect($session, logon=>'session', login=>$REMOTE_USER, from=>2 );
    }
    my ($domain, $login, $password ) = (scalar $self->{cgi}->param('domain'), scalar $self->{cgi}->param('login'), scalar $self->{cgi}->param('password'));
    if ( $REQUEST_METHOD ne 'POST' || !$domain || !$login || !$password || $domain!~/^\w+$/xms || !$SESSION{domains}{$domain}) {
        return $self->_handle_goto_login($session);
    }

    if (!$self->_check_token('LOGIN'))  {
        return $self->_handle_redirect($session, login=>$login, logon=>'session', from=>3);
    }

    my $handler = ref $SESSION{domains}{$domain} eq 'HASH' ? [ $SESSION{domains}{$domain} ] : $SESSION{domains}{$domain};
    require Module::Load;
    foreach my $auth ( @{$handler} ) {
        Module::Load::load($auth->{authhandler});
        if ($auth->{authhandler}->check_login($auth->{config} // {}, $login, $password)) {
            # throw old (expired) session away:
            $self->_remove_session($session);
            # create a new one:
            $CGI::Session::IP_MATCH = 1;
            $session = CGI::Session->new('driver:File', undef, {Directory => $SESSION{temp} // '/tmp'});
            $session->param('login', $login);
            $session->expire($auth->{expire} // $SESSION{expire} // '+10m');
            $session->flush();
            # redirect because I have to set a new session cookie:
            return $self->_handle_redirect(undef, -cookie=> $self->{cgi}->cookie($session->name(), $session->id()));
        }
    }
    return $self->_handle_redirect($session, logon=>'failure', login=>$login);
}
sub _remove_session {
    my ($self, $session) = @_;
    if (!$session) { return 0; }
    $session->delete();
    $session->flush();
    return 1;
}
sub _handle_goto_login {
    my ($self, $session) = @_;
    $self->_remove_session($session);
    $self->_create_token('LOGIN', 1);
    return 0;
}
sub _handle_redirect {
    my ($self, $session, %query) = @_;
    $self->_remove_session($session);
    $query{lang} //= $self->{cgi}->param('lang') // $LANG;
    my $cookie = $query{-cookie};
    if ($cookie) { delete $query{-cookie} };
    my $query_string = join q{&}, map { "${_}=".$self->{cgi}->escape($query{$_}) } keys %query;
    my $uri = ${REQUEST_URI}.q{?}.${query_string};
    my %redirparams = ( -location => $uri, -X_Login_Required => $uri );
    print_compressed_header_and_content('302 Redirect', 'text/html', q{}, \%redirparams, $cookie);
    return 2;
}
sub _set_defaults {
    $SESSION{tokenname} //= 'TOKEN';
    $SESSION{secret} //= 'uP:oh2oo';
    return;
}
sub _create_token {
    my ($self, $login, $force) = @_;
    my $token = $SESSION{TOKEN} = WWW::CSRF::generate_csrf_token($login, $SESSION{secret}, {  Random => $self->{random}->bytes(20) });
  #  carp("Token $token for $login generated.");
    return $token;
}
sub _check_token {
    my ($self, $login) = @_;
    my $cgitoken = $self->{cgi}->param($SESSION{tokenname});

    if ($REQUEST_METHOD ne 'POST') {
        return 1;
    }
    if (!$cgitoken || !$login) {
        #return 0; ## TODO: later
        return 1;
    }
    $SESSION{secret} //= 'uP:oh2oo';
    my %warnings = ( 0 => "CSRF token $cgitoken of $login checked successfully.",
                     1 => "CSRF token $cgitoken of $login is expired.",
                     2 => "CSRF token $cgitoken of $login has an invalid signature.",
                     3 => "CSRF token $cgitoken of $login is malformed.",
    );
    my $check = check_csrf_token($login, $SESSION{secret}, $cgitoken);
    if ( $check != CSRF_OK ) {
        carp($warnings{$check});
    }
    return $check == CSRF_OK ? 1 : 0;
}
1;