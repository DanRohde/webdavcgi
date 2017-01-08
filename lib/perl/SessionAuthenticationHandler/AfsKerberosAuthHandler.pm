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

package SessionAuthenticationHandler::AfsKerberosAuthHandler;
use strict;
use warnings;

our $VERSION = '1.0';

use base qw{ SessionAuthenticationHandler::KerberosAuthHandler };

use CGI::Carp;
use English qw( -no_match_vars );
use AFS::PAG qw( setpag unlog haspag );

sub login {
    my ($self, $config, $login, $password) = @_;
    return $self->SUPER::login($config, $login, $password) && $self->_aklog($config, $login);
}
sub _aklog {
    my ($self, $config, $login) = @_;
    system $config->{aklog} // 'aklog';
    if ($CHILD_ERROR >> 8 != 0) {
        carp("AFS login failed for $login: $CHILD_ERROR, $ERRNO");
        return 0;
    }
    carp("AFS login successful ($CHILD_ERROR).");
    return 1;
}
sub check_session {
    my ($self, $config, $login) = @_;
    if ($self->SUPER::check_session($config, $login)) {
        if (haspag()) {
            unlog();
        } else {
            if (!setpag()) {
                carp("setpag failed for $login.");
                return 0;
            }
        }
        return $self->_aklog($config, $login);
    }
    return 0;
}
sub logout {
    my ($self, $config, $login ) = @_;
    $self->SUPER::logout($config, $login);
    system $config->{unlog} // 'unlog';
    return 1;
}

1;