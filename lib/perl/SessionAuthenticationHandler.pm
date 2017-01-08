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
#      tokenmaxage => 36000, # 10h
#      expire => '+10m', # can be overwritten by domain
#      temp => '/tmp',
#      domains => {
#          DOMAIN1 => [ # multiple handler
#              {
#                  authhandler => qw( SessionAuthenticationHandler::AuthenticationHandler ),
#                  expire => '+10m', # default
#                  config => {  whatever => 'here comes'  },
#                  _order => 1, # sort order for login screen
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
use CGI::Session;
use WWW::CSRF qw(generate_csrf_token check_csrf_token CSRF_OK );
use Bytes::Random::Secure;

use DefaultConfig qw( %SESSION $REMOTE_USER $REQUEST_URI $REQUEST_METHOD $LANG $VIRTUAL_BASE $DOCUMENT_ROOT );
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
            $self->_logout($session);
            return $self->_handle_logout_redir($session) || $self->_handle_goto_login($session);
        }
        if ($self->_check_token($REMOTE_USER) && $self->_check_session($session)) {
            $ENV{REMOTE_USER} = $REMOTE_USER;
            $self->_create_token($REMOTE_USER);
            $self->set_domain_defaults($self->_get_auth($session));
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

    if (my $auth = $self->check_credentials(\%SESSION, $domain, $login, $password)) {
        # throw old (expired) session away:
        $self->_remove_session($session);
        # create a new one:
        $CGI::Session::IP_MATCH = 1;
        $session = CGI::Session->new('driver:File', undef, {Directory => $SESSION{temp} // '/tmp'});
        $session->param('login', $login);
        $session->param('domain', $domain);
        $session->param('handleridx', $auth->{_handleridx});
        $session->expire($auth->{expire} // $SESSION{expire});
        $session->flush();
        # redirect because I have to set a new session cookie:
        return $self->_handle_redirect(undef, -cookie=> $self->{cgi}->cookie(-name=>$session->name(), -value=>$session->id(),-secure=>1,-path=> $REQUEST_URI=~/^($VIRTUAL_BASE)/xms ? $1 : $REQUEST_URI ));
    }
    return $self->_handle_redirect($session, logon=>'failure', login=>$login);
}
sub _get_auth {
    my ($self, $session) = @_;
    return $self->_get_handler_arrref(\%SESSION, $session->param('domain'))->[$session->param('handleridx')];
}
sub set_domain_defaults {
    my ($self, $auth) = @_;
    if ($auth->{defaults}) {
        foreach my $k (keys %{$auth->{defaults}}) {
            my $dref = $DefaultConfig::{$k};
            my $val = $auth->{defaults}->{$k};
            if (!defined $dref) {
                carp("set_domain_defaults: unknown default $k");
                next;
            }
            if (${$dref}) {
                ${$dref} = $val;
            } elsif ( @{$dref} ) {
                @{$dref} = @{$val};
            } elsif (%{$dref}) {
                %{$dref} = %{$val};
            } else {
                carp("set_domain_defaults: unknown default $k (ref=".ref($dref).q{)});
            }
        }
    }
    if ($auth->{callback}) {
        require Module::Load;
        Module::Load::load($auth->{callback});
        $auth->{callback}->init($auth->{callback_param});
    }
    return;
}
sub _get_handler_arrref {
    my ($self, $sessionconfig, $domain) = @_;
    return ref $sessionconfig->{domains}{$domain} eq 'HASH' ? [ $sessionconfig->{domains}{$domain} ] : $sessionconfig->{domains}{$domain};
}
sub check_credentials {
    my ($self, $sessionconfig, $domain, $login, $password) = @_;
    my $handler = $self->_get_handler_arrref($sessionconfig, $domain);
    require Module::Load;
    for my $h ( 0 .. $#{$handler} ) {
        my $auth = $handler->[$h];
        Module::Load::load($auth->{authhandler});
        if ($auth->{authhandler}->login($auth->{config} // {}, $login, $password)) {
            $auth->{_handleridx} = $h;
            return $auth;
        }
    }
    return 0;
}
sub _check_session {
    my ($self, $session ) = @_;
    my $auth = $self->_get_auth($session);
    require Module::Load;
    Module::Load::load($auth->{authhandler});
    return $auth->{authhandler}->check_session($auth->{config} // {}, $session->param('login'));
}
sub _logout {
    my ($self, $session ) = @_;
    my $auth = $self->_get_auth($session);
    require Module::Load;
    Module::Load::load($auth->{authhandler});
    return $auth->{authhandler}->logout($auth->{config} // {}, $session->param('login'));
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
sub _handle_logout_redir {
    my ($self, $session) = @_;
    if ($SESSION{logout_redir}) {
        $self->_remove_session($session);
        print_compressed_header_and_content('302 Redirect','text/html', q{}, {-location=>$SESSION{logout_redir}});
        return 2;
    }
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
    $SESSION{tokenmaxage} //= 36000;
    $SESSION{expire} //= '+10m';
    return;
}
sub _create_token {
    my ($self, $login, $force) = @_;
    my $token = $SESSION{TOKEN} = generate_csrf_token($login, $SESSION{secret}, {  Random => $self->{random}->bytes(20) });
  #  carp("Token $token for $login generated.");
    return $token;
}
sub _check_token {
    my ($self, $login) = @_;
    my $cgitoken = $self->{cgi}->param($SESSION{tokenname});
    if ($REQUEST_METHOD ne 'POST' && !$cgitoken) {
        return 1;
    }
    if (!$cgitoken || !$login) {
        my %cgivars = $self->{cgi}->Vars();
        carp("UGLY POST TO $REQUEST_URI WITHOUT TOKEN:" . join q{, }, map { $_.q{=}.$cgivars{$_} } sort keys %cgivars );
        return 0;
    }
    my %warnings = ( 0 => "CSRF token $cgitoken for $login checked successfully.",
                     1 => "CSRF token $cgitoken for $login is expired.",
                     2 => "CSRF token $cgitoken for $login has an invalid signature.",
                     3 => "CSRF token $cgitoken for $login is malformed.",
    );
    my $check = check_csrf_token($login, $SESSION{secret}, $cgitoken, { MaxAge => $SESSION{tokenmaxage} });
    if ( $check != CSRF_OK ) {
        carp($warnings{$check});
    }
    return $check == CSRF_OK;
}
1;
