########################################################################
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

package WebInterface::Extension::SendByMail::LdapAddressbook;

use strict;
use warnings;

our $VERSION = '2.0';

use base qw( WebInterface::Extension::SendByMail::Addressbook );

use Net::LDAP;
use CGI::Carp;

sub get_mail_addresses {
    my ( $self, $extension, $pattern ) = @_;

    my %c = (
        server     => $extension->config( 'ldap.server',     'localhost' ),
        debug      => $extension->config( 'ldap.debug',      0 ),
        starttls   => $extension->config( 'ldap.starttls',   0 ),
        verify     => $extension->config( 'ldap.verify',     'required' ),
        sslversion => $extension->config( 'ldap.sslversion', 'tlsv1_2' ),
        binddn     => $extension->config( 'ldap.binddn',     0 ),
        password   => $extension->config('ldap.password'),
        basedn     => $extension->config('ldap.basedn'),
        filter =>
          $extension->config( 'ldap.filter', '(|(mail=*%s*)(cn=*%s*))' ),
        scope     => $extension->config( 'ldap.scope',     'sub' ),
        timelimit => $extension->config( 'ldap.timelimit', 5 ),
        sizelimit => $extension->config( 'ldap.sizelimit', 5 ),
        cn        => $extension->config( 'ldap.cn',        'cn' ),
        mail      => $extension->config( 'ldap.mail',      'mail' ),
    );

    my @paa    = split /\s*,\s*/xms, $pattern;
    my $query  = pop @paa;
    my $pa     = join ', ', @paa;
    my @result = ();

    if ( $query !~ /^\s*$/xms ) {

        my $ldap = Net::LDAP->new( $c{server}, debug => $c{debug} );

        $c{starttls}
          and
          ldap->start_tls( verify => $c{verify}, sslversion => $c{sslversion} );

        my $msg =
            $c{binddn}
          ? $ldap->bind( $c{binddn}, password => $c{password} )
          : $ldap->bind();

        $msg->code && carp $msg->error;

        $query =~ s/([()&|=!><~*])/sprintf('\\%x',ord($1))/exmsg;
        $c{filter} =~ s/\%s/$query/xmsg;

        $msg = $ldap->search(
            base      => $c{basedn},
            scope     => $c{scope},
            sizelimit => $c{sizelimit},
            timelimit => $c{timelimit},
            filter    => $c{filter},
            attrs     => [ $c{cn}, $c{mail} ],
            raw       => qr/(?i:$c{cn})/xms
        );
        $msg->code && carp $msg->error;
        my %dupcheck = ();

        foreach my $entry ( $msg->entries ) {
            my $mail = $entry->get_value( $c{mail} );
            my $cn   = $entry->get_value( $c{cn} );
            my $re   = "$cn <$mail>";
            if ( $pa ne q{} ) {
                $re = "$pa, $re";
            }
            if ( !$dupcheck{$re} ) {
                push @result, { label => $re, value => "$re, " };
                $dupcheck{$re} = 1;
            }
        }
        $ldap->unbind();
    }

    return \@result;
}
1;
