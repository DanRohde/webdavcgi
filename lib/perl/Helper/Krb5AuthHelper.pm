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
package Helper::Krb5AuthHelper;

use strict;

use Fcntl qw(:flock);
use MIME::Base64;
use Env::C;

sub new {
	my ($class) = @_;
	my $self = {};
	bless $self, $class;
	$self->init();
	return $self;
}
sub init {
	return 0 unless $ENV{AUTHHEADER};
	my $ret = 1;
	my $REMOTE_USER = $ENV{REMOTE_USER} || $ENV{REDIRECT_REMOTE_USER};
	my $TICKET_LIFETIME = $ENV{TICKET_LIFETIME} || 300;

	my $ticketfn = $ENV{KRB5CCNAME} =~ /^FILE:(.*)$/ ? $1 : "/tmp/krb5cc_webdavcgi_$REMOTE_USER";
	$ENV{KRB5CCNAME} = "FILE:$ticketfn";
	Env::C::setenv( 'KRB5CCNAME', $ENV{KRB5CCNAME} );
	Env::C::setenv( 'KRB5_CONFIG', $ENV{KRB5_CONFIG}) if $ENV{KRB5_CONFIG};

	$ENV{WEBDAVISWRAPPED} = 1;

	my $agefile = "$ticketfn.age";

	if ( -e $ticketfn ) {
		unlink $ticketfn if time() - ( stat($agefile) )[9] >= $TICKET_LIFETIME || !-s $ticketfn;
	}

	if ( !-f $ticketfn ) {
		if ( open( my $lfh, '>', $agefile ) ) {
			if ( flock( $lfh, LOCK_EX ) ) {
				open(my $kinit,	'|-', "kinit '$REMOTE_USER' 1>/dev/null 2>&1") || die("Cannot execute kinit $REMOTE_USER");
				print $kinit (split(/:/, decode_base64((split(/\s+/,$ENV{AUTHHEADER}))[1])))[1];
				close($kinit);
				print $lfh time();
				flock( $lfh, LOCK_UN );
			} else {
				warn("flock($agefile) failed!");
				$ret = 0;
			}
			close($lfh);
		} else {
			warn("open('>$agefile') failed!");
			$ret = 0;
		}
	}
	return $ret;
}
1;