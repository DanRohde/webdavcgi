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

use DefaultConfig qw( %SESSION $REMOTE_USER $REQUEST_URI);

sub new {
   my ($class, $cgi) = @_;
   my $self  = {};
   bless $self, $class;
   $self->{cgi} = $cgi;
   return $self;
}
# 0 : unauthenticated -> login screen
# 1 : authenticated
# 2 : fresh authenticated -> redirect -> exit 
sub authenticate {
    my ($self) = @_;
    require CGI::Session;
    my $session = CGI::Session->new('driver:File', $self->{cgi},{Directory => $SESSION{temp} // '/tmp'});
    if (! defined $session) {
        carp("${self}: $CGI::Session::errstr");
        return 0;
    }
    if ($REMOTE_USER = $session->param('login')) {
        if ($self->{cgi}->param('logout')) {
            $session->delete();
            $session->flush();
            return 0;
        }
        return 1;
    }
    my ($domain, $login, $password ) = (scalar $self->{cgi}->param('domain'), scalar $self->{cgi}->param('login'), scalar $self->{cgi}->param('password'));
    if ( !$domain || !$login || !$password || $domain!~/^\w+$/xms || !$SESSION{domains}{$domain}) {
        $session->delete();
        $session->flush();
        return 0;
    }
    my $handler = ref $SESSION{domains}{$domain} eq 'HASH' ? [ $SESSION{domains}{$domain} ] : $SESSION{domains}{$domain};
    require Module::Load;
    foreach my $auth ( @{$handler} ) {
        Module::Load::load($auth->{authhandler});
        if ($auth->{authhandler}->check_login($auth->{config} // {}, $login, $password)) {
            # throw old session away
            $session->delete();
            $session->flush();
            # create a new one:
            $CGI::Session::IP_MATCH = 1;
            $session = CGI::Session->new('driver:File',undef, {Directory => $SESSION{temp} // '/tmp'});
            $session->param('login', $login);
            $session->expire($auth->{expire} // $SESSION{expire} // '+10m');
            $session->flush();
            # redirect because we are in a login procedure:
            print $self->{cgi}->redirect(-uri=>"${REQUEST_URI}?lang=".$self->{cgi}->escape(scalar $self->{cgi}->param("lang")), -cookie => $self->{cgi}->cookie($session->name(), $session->id()) );
            return 2;
        }
    }
    $session->delete();
    $session->flush();
    print $self->{cgi}->redirect("${REQUEST_URI}?logon=failure&login=".$self->{cgi}->escape($login).'&lang='.$self->{cgi}->escape(scalar $self->{cgi}->param("lang")));
    return 2;
}
1;