########################################################################
# (C) ZE CMS, Humboldt-Universitaet zu Berlin
# Written by Daniel Rohde
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
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.
#########################################################################
# ticketfilename: '/tmp/krb5cc_webdavcgi_%s'
# kinit_argv: [ 'kinit' ]
# kdestroy_argv: [ 'kdestroy' ]
# login: '%s'
# ticketlifetime: 300
# krb5_config: set it to '/etc/krb5.conf' or whatever
# log: 1 - error, 2 - warn, 4 - info, 8 - debug; combine: add, all: 15
#
# 19 Apr 2026: command injection in login username field via shell-built 
# kinit invocation; fixed by strict username validation plus argv-based 
# exec and suppressed child output.

package SessionAuthenticationHandler::KerberosAuthHandler;
use strict;
use warnings;
our $VERSION = '1.0';

use base qw( SessionAuthenticationHandler::AuthenticationHandler );
use Env::C;
use English qw( -no_match_vars );
use CGI::Carp;

sub login {
  my ($self, $config, $login, $password) = @_;
  $self->log($config, "login($login, ...) called.", 8);

  if (!$self->_valid_login($login)) {
    $self->log($config, 'Rejected invalid login syntax.', 2);
    return 0;
  }

  my $ticketfn = $self->_get_ticketfilename($config, $login);
  my $agefn    = $self->_get_agefilename($config, $login);

  if (-r $ticketfn && $self->check_session($config, $login)) {
    return 1;
  }

  $self->_setenv($config, $login);

  my @kinit = $self->_kinit_argv($config, $login);
  my $pid = open my $kinit, q{|-};

  if (!defined $pid) {
    $self->log($config, "Cannot fork kinit for supplied login: $ERRNO", 1);
    return 0;
  }

  if ($pid == 0) {
    open STDOUT, '>', '/dev/null' or croak "Cannot redirect STDOUT: $ERRNO";
    open STDERR, '>', '/dev/null' or croak "Cannot redirect STDERR: $ERRNO";
    exec @kinit or croak "Cannot exec kinit: $ERRNO";
  }

  print({$kinit} $password)
    || $self->log($config, 'Cannot write password to kinit.', 1);

  close $kinit;

  if ($CHILD_ERROR >> 8 != 0) {
    $self->log($config, "Kerberos login failed for $login: $CHILD_ERROR", 2);
    return 0;
  }

  if (open my $age, q{>}, $agefn) {
    print({$age} time)
      || $self->log($config, "Cannot write to $agefn.", 1);
    close($age)
      || $self->log($config, "Cannot close $agefn: $ERRNO", 2);
  } else {
    $self->log($config, "Cannot write $agefn: $ERRNO", 1);
  }

  $self->log($config, "Kerberos login for $login successfull.", 4);
  return 1;
}

sub check_session {
  my ($self, $config, $login) = @_;
  $self->log($config, "check_session($login) called.", 8);

  if (!$self->_valid_login($login)) {
    $self->log($config, 'Rejected invalid login syntax during session check.', 2);
    return 0;
  }

  $self->_setenv($config, $login);

  my $agefn = $self->_get_agefilename($config, $login);
  my $ticketlifetime = $config->{ticketlifetime} // 600;

  if ( time - (stat $agefn)[9] >= $ticketlifetime ) {
    $self->log($config, "ticketlifetime $ticketlifetime for $login elapsed.", 4);
    $self->logout($config, $login);
    return 0;
  }

  return 1;
}

sub logout {
  my ($self, $config, $login) = @_;
  $self->log($config, "logout($login) called.", 8);

  if (!$self->_valid_login($login)) {
    $self->log($config, 'Refusing logout for invalid login syntax.', 2);
    return 0;
  }

  $self->_setenv($config, $login);

  my @kdestroy = $self->_kdestroy_argv($config);
  system @kdestroy;

  if ($CHILD_ERROR >> 8 != 0 ) {
    $self->log($config, "kdestroy failed: $CHILD_ERROR, $ERRNO", 1);
  }

  unlink($self->_get_agefilename($config, $login))
    || $self->log($config, "Cannot remove age file for $login", 1);

  return 1;
}

sub _get_ticketfilename {
  my ( $self, $config, $login) = @_;
  return sprintf $config->{ticketfilename} // '/tmp/krb5cc_webdavcgi_%s', $login;
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

sub _valid_login {
  my ($self, $login) = @_;
  return 0 if !defined $login;
  return 0 if $login eq q{};
  return 0 if length($login) > 128;
  return 0 if $login =~ /[\x00-\x1f\x7f]/xms;
  return 0 if $login !~ /\A[\w.@-]+\z/xms;
  return 1;
}

sub _kinit_argv {
  my ($self, $config, $login) = @_;

  if (ref($config->{kinit_argv}) eq 'ARRAY' && @{$config->{kinit_argv}}) {
    return (@{$config->{kinit_argv}}, $login);
  }

  return ('kinit', $login);
}

sub _kdestroy_argv {
  my ($self, $config) = @_;

  if (ref($config->{kdestroy_argv}) eq 'ARRAY' && @{$config->{kdestroy_argv}}) {
    return @{$config->{kdestroy_argv}};
  }

  return ('kdestroy');
}

1;
