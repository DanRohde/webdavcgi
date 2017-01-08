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
# ticketfilename: '/tmp/krb5cc_webdavcgi_%s'
# kinit: q{kinit '%s' 1>/dev/null 2>&1}
# kdestroy: q{kdestroy 1>/dev/null 2>&1}
# login: '%s'
# ticketlifetime: 300
# krb5_config: set it to '/etc/krb5.conf' or whatever

package SessionAuthenticationHandler::KerberosAuthHandler;
use strict;
use warnings;

our $VERSION = '1.0';

use base qw( SessionAuthenticationHandler::AuthenticationHandler );

use CGI::Carp;
use Env::C;
use Fcntl qw(:flock);
use English qw( -no_match_vars );

sub login {
    my ($self, $config, $login, $password) = @_;

    my $kinitcmd = sprintf $config->{kinit} // q{kinit '%s' 1>/dev/null 2>&1}, $login;
    my $ticketfn = $self->_get_ticketfilename($config, $login);
    my $agefn    = $self->_get_agefilename($config, $login);
    $self->_setenv($config, $login);

    if ( -r $ticketfn && $self->check_session($config, $login)) {
        return 1;
    }
    my $kinit;
    if (! open $kinit, q{|-}, $kinitcmd) {
        carp "Cannot execute $kinitcmd: $ERRNO";
    }
    print( {$kinit} $password ) || carp 'Cannot write passwort to kinit.';
    close $kinit;
    if ($CHILD_ERROR >> 8 != 0) {
        carp("Kerberos login failed for $login: $CHILD_ERROR");
        return 0;
    }
    if (open my $age, q{>}, $agefn) {
        print({$age} time) || carp "Cannot write to $agefn.";
        close($age) || carp "Cannot close $agefn: $ERRNO";
    } else {
        carp "Cannot write $agefn: $ERRNO";
    }
    #carp("Kerberos login for $login successfull.");
    return 1;
}
sub check_session {
    my ($self, $config, $login) = @_;
    $self->_setenv($config, $login);
    my $agefn = $self->_get_agefilename($config, $login);
    my $ticketlifetime = $config->{ticketlifetime} // 300;
    if ( time - (stat $agefn)[9] >= $ticketlifetime  ) {
        $self->logout($config, $login);
        return 0;
    }
    return 1;
}
sub logout {
    my ($self, $config, $login) = @_;
    $self->_setenv($config, $login);
    my $kdestroycmd = $config->{kdestroy} // q{kdestroy 1>/dev/null 2>&1};
    system $kdestroycmd;
    if ($CHILD_ERROR >> 8 != 0 ) {
        carp("Command $kdestroycmd failed: $CHILD_ERROR, $ERRNO");
    }
    unlink $self->_get_agefilename($config, $login);
    return 1;
}
sub _get_ticketfilename {
    my ( $self, $config, $login) = @_;
    return  sprintf $config->{ticketfilename} // '/tmp/krb5cc_webdavcgi_%s', $login;
}
sub _get_agefilename {
    my ( $self, $config, $login ) = @_;
    return $self->_get_ticketfilename($config,$login).'.age';
}
sub _setenv {
    my ($self, $config, $login) = @_;
    my $ticketfn = $self->_get_ticketfilename($config,$login);
    $ENV{KRB5CCNAME} = "FILE:$ticketfn";
    Env::C::setenv( 'KRB5CCNAME', $ENV{KRB5CCNAME} );
    if ( $config->{krb5_config} || $ENV{KRB5_CONFIG} ) {
        Env::C::setenv( 'KRB5_CONFIG', $config->{krb5_config} || $ENV{KRB5_CONFIG} );
    }
    return;
}


1;