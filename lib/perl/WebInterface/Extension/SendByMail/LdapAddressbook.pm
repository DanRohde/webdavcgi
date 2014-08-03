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

use Net::LDAP;

sub getMailAddresses {
	my ($self, $extension, $pattern) = @_;
	
	my %c = (
		server => $extension->config('ldap.server'),
		debug => $extension->config('ldap.debug',0),
		starttls => $extension->config('ldap.starttls',0),
		binddn => $extension->config('ldap.binddn',0),
		password => $extension->config('ldap.password'),
		basedn => $extension->config('ldap.basedn'),
		filter => $extension->config('ldap.filter','(|(mail=*%s*)(cn=*%s*))'),
		scope => $extension->config('ldap.scope','sub'),
		timelimit => $extension->config('ldap.timelimit',10),
		sizelimit => $extension->config('ldap.sizelimit',3),
		mail => $extension->config('ldap.mail','mail'),
	);
	
	my @paa = split(/\s*,\s*/, $pattern);
	my $query = pop(@paa);
	my $pa = join(', ',@paa);
	my @result = ();
	
	if ($query!~/^\s*$/) {
	
		my $ldap = Net::LDAP->new($c{server}, debug=>$c{debug});
	
		ldap->start_tls() if $c{starttls}; 
	
		my $msg = $c{binddn} ? $ldap->bind($c{binddn}, password=>$c{password}) : $ldap->bind();
	
		$msg->code && warn $msg->error;
	
		$query=~s/([\(\)\&\|\=\!\>\<\~\*])/sprintf('\\%x',ord($1))/eg; 
		$c{filter} =~ s/\%s/$query/g;
	
		$msg = $ldap->search(base=>$c{basedn}, scope=>$c{scope},sizelimit=>$c{sizelimit}, timelimit=>$c{timelimit}, filter=>$c{filter}, attrs=>[ $c{mail} ]);
		$msg->code && warn $msg->error;
		foreach my $entry ($msg->entries) {
			my $val = $entry->get_value( $c{mail} );
			push @result, $pa ne "" ? "$pa, $val" : $val;
		}
		$ldap->unbind();
	}
	
	return \@result;
}
1;