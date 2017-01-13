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

package SessionAuthenticationHandler::AuthenticationHandler;
use strict;
use warnings;

our $VERSION = '1.0';

use CGI::Carp;

sub login {
    my ($self, $config, $login, $password) = @_;
    return 0;
}
sub check_session {
    my ($self, $config, $login) = @_;
    $self->log($config, "check_session($login) called.", 8);
    return 1;
}
sub logout {
    my ($self, $config, $login) = @_;
    $self->log($config, "$login logged out.", 4);
    return 1;
}

sub log {
    my ($self, $config, $message, $severity) = @_;
    $severity //= 4;
    if ($config->{log} && ( $config->{log} & $severity) == $severity ) {
        my %severites = ( 1 => 'ERROR', 2=> 'WARN', 4=> 'INFO', 8=> 'DEBUG' );
        carp(sprintf '%s: %s', $severites{$severity}, $message);
    }
}
1;