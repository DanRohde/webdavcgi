#!/usr/bin/perl
#########################################################################
# (C) ZE CMS, Humboldt-Universitaet zu Berlin
# Written 2014 by Daniel Rohde <d.rohde@cms.hu-berlin.de>
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
package Helper::Krb5EnvHelper;

use strict;

use Env::C;

sub new {
	my ($class) = @_;
	my $self = {};
	bless $self, $class;
	$self->init();
	return $self;
}
sub init {
	my $REMOTE_USER = $ENV{REMOTE_USER} || $ENV{REDIRECT_REMOTE_USER};
	my $ticketfn = $ENV{KRB5CCNAME} =~ /^FILE:(.*)$/ ? $1 : "/tmp/krb5cc_webdavcgi_$REMOTE_USER";
	$ENV{KRB5CCNAME} = "FILE:$ticketfn";
	Env::C::setenv( 'KRB5CCNAME', $ENV{KRB5CCNAME} );
	Env::C::setenv( 'KRB5_CONFIG', $ENV{KRB5_CONFIG}) if $ENV{KRB5_CONFIG};
}
1;