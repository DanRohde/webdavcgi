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
use warnings;

our $VERSION = '2.0';

use CGI::Carp;
use Fcntl qw(:flock);
use MIME::Base64;
use Env::C;

use base qw(Events::EventListener);

sub new {
    my ($class) = @_;
    my $self = {};
    bless $self, $class;
    $self->init();
    return $self;
}

sub init {
    my $self = shift;
    if ( !$ENV{AUTHHEADER} ) { return 0; }
    my $ret             = 1;
    my $REMOTE_USER     = $ENV{REMOTE_USER} || $ENV{REDIRECT_REMOTE_USER};
    my $TICKET_LIFETIME = $ENV{TICKET_LIFETIME} || 300;

    if ( $ENV{KRB5CCNAME} ) {
        Env::C::setenv( 'KRB5CCNAMEORIG', $ENV{KRB5CCNAME} );
    }
    $self->register( main::getEventChannel() );

    my $ticketfn = "/tmp/krb5cc_webdavcgi_$REMOTE_USER";
    $ENV{KRB5CCNAME} = "FILE:$ticketfn";
    Env::C::setenv( 'KRB5CCNAME', $ENV{KRB5CCNAME} );
    if ( $ENV{KRB5_CONFIG} ) {
        Env::C::setenv( 'KRB5_CONFIG', $ENV{KRB5_CONFIG} );
    }

    $ENV{WEBDAVISWRAPPED} = 1;

    my $agefile = "$ticketfn.age";

    if (
        -e $ticketfn
        && ( time - ( stat $agefile )[9] >= $TICKET_LIFETIME
            || !-s $ticketfn )
      )
    {
        unlink $ticketfn;
    }

    if ( !-f $ticketfn ) {
        if ( open my $lfh, '>', $agefile ) {
            if ( flock $lfh, LOCK_EX ) {
                print {$lfh} time || carp "Cannot write time to $agefile.";
                open( my $kinit, q{|-},
                    "kinit '$REMOTE_USER' 1>/dev/null 2>&1" )
                  || croak "Cannot execute kinit $REMOTE_USER";
                print {$kinit} (
                    split /:/xms,
                    decode_base64( ( split /\s+/xms, $ENV{AUTHHEADER} )[1] )
                )[1] || carp 'Cannot write login:passwort to kinit.';
                close $kinit || carp 'Cannot close kinit call.';

                flock $lfh, LOCK_UN;
                close $lfh || carp "Cannot close $agefile.";
            }
            else {
                carp "flock($agefile) failed!";
                $ret = 0;
            }
        }
        else {
            carp "open('>$agefile') failed!";
            $ret = 0;
        }
    }
    return $ret;
}

sub register {
    my ( $self, $channel ) = @_;
    $channel->add( ['FINALIZE'], $self );
    return 1;
}

sub receive {
    my ( $self, $event, $data ) = @_;
    if (defined Env::C::getenv('KRB5CCNAMEORIG') ) { 
        Env::C::setenv( 'KRB5CCNAME', Env::C::getenv('KRB5CCNAMEORIG') ); 
    } else {
        Env::C::unsetenv('KRB5CCNAME');
    }
    return 1;
}
1;
