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

use Fcntl qw(:flock O_WRONLY O_TRUNC O_CREAT);
use Env::C;

use Events::EventListener;
our @ISA = qw ( Events::EventListener );

sub new {
	my ($class) = @_;
	my $self = {};
	bless $self, $class;
	$self->init();
	return $self;
}
sub init {
	my $self = shift;
	my $REMOTE_USER = $ENV{REMOTE_USER} || $ENV{REDIRECT_REMOTE_USER};
	my $TICKET_LIFETIME = $ENV{TICKET_LIFETIME} || 300;
	
	my $ticketfn = "/tmp/krb5cc_webdavcgi_$REMOTE_USER";
	my $agefile = $ticketfn.'.age';
	Env::C::setenv('KRB5CCNAMEORIG',$ENV{KRB5CCNAME}) if $ENV{KRB5CCNAME};
	$self->registerChannel(main::getEventChannel());
	if ($ENV{KRB5CCNAME} && $ENV{KRB5CCNAME} ne $ticketfn) {

		unlink $ticketfn if -e $ticketfn && ( time() - ( stat($agefile) )[9] >= $TICKET_LIFETIME || !-s $ticketfn );
		
		if ($ENV{KRB5CCNAME}=~/^FILE:(.*)$/ && !-e $ticketfn) {
			my $oldfilename = $1;
			
			
			my ($in, $out, $age);
			if (open($in, '<', $oldfilename) && sysopen($out, $ticketfn, O_WRONLY | O_TRUNC | O_CREAT, 0600) && open($age, '>', $agefile)) {
				if (flock($age, LOCK_EX | LOCK_NB) ) {
					binmode $in;
					binmode $out;
					while (read($in, my $buffer, $main::BUFSIZE || 1048576)) {
						print $out $buffer;
					}
					close($in);
					close($out);
					flock($age, LOCK_UN);
					close($age);
				} else {
					warn("flock($agefile) failed!");
				}
				
				
			} else {
				warn("Cannot read ticket file (don't use a setuid/setgid wrapper):" . (-r $oldfilename));
			}
		}
	}
	$ENV{KRB5CCNAME} = "FILE:$ticketfn";
	Env::C::setenv( 'KRB5CCNAME', $ENV{KRB5CCNAME} );
	Env::C::setenv( 'KRB5_CONFIG', $ENV{KRB5_CONFIG}) if $ENV{KRB5_CONFIG};
}
sub registerChannel {
	my ($self, $channel) = @_;
	$channel->addEventListener(['FINALIZE'], $self);
}
sub receiveEvent {
	my ( $self, $event, $data ) = @_;
	Env::C::setenv('KRB5CCNAME', Env::C::getenv('KRB5CCNAMEORIG'));
}
1;