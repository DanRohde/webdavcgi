#!/usr/bin/perl
#########################################################################
# (C) ZE CMS, Humboldt-Universitaet zu Berlin
# Written by Aleksander Goudalo
# Modified 2014 by Daniel Rohde <d.rohde@cms.hu-berlin.de>
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
package Helper::AdsSmbConfigurator;

use strict;

use Net::LDAP;
use Authen::SASL qw(Perl);
use Net::DNS;
use Cache::Memcached;
use Carp;

sub new {
	my $class = shift;
	my $self  = {};
	bless $self, $class;
	$self->_init(@_);
	return $self;
}

sub _init {
	my $self   = shift;
	my %config = @_;

	$$self{memcached} = $config{memcached};    ###  127.0.0.1:11211
	$$self{memcachedexpire} = $config{memcachedexpire} || 600;
	$$self{debug}     = $config{debug};
	$$self{separator} = $config{separator} || '~';
	$$self{defaultdomain} = $config{defaultdomain} ? uc($config{defaultdomain}) : 'CMS.HU-BERLIN.DE';
	$$self{nameservers} = $config{nameservers};
	$$self{allowflag} = $config{allowflag};
	$$self{ldapattr} = $config{ldapattr} || 'info';
}

sub getSmbConfig {
	my $self = shift;
	my $smb;
	if ($$self{memcached}) {
		my $cache =  new Cache::Memcached { servers => [ $$self{memcached} ], debug => $$self{debug} };
		my $key = $ENV{REMOTE_USER} || $ENV{REDIRECT_REMOTE_USER};
		$smb = $cache->get( $key );
		if (!$smb) {
			$smb = $self->_getSmbConfig();
			$cache->set($key, $smb, $$self{memcachedexpire}) if defined $$smb{defaultdomain};
		}
	} else {
		$smb = $self->_getSmbConfig();	
	}
	return $smb;
}
sub debug {
	my $self = shift;
	print STDERR join(', ', @_)."\n" if $$self{debug};
}
sub _getSmbConfig {
	my $self = shift;
	my %SMB;
	my $remote_user = $ENV{REMOTE_USER} || $ENV{REDIRECT_REMOTE_USER};
	#### Bentutzername und Domaine extrahieren
	my @rurd = split(/\@/, $remote_user );
	my $user = $rurd[0];
	my $domain = $rurd[1] ? uc($rurd[1]) : $$self{defaultdomain};

	$self->debug("genConfig: user=$user, domain=$domain");

	#### Variablen
	my $separator = $$self{separator};
	%SMB = (
		defaultdomain => $domain || $$self{defaultdomain},
		sharesep      => $separator,
		secure        => 1
	);
	my $dc;
	my $homeDirectory;
	my $homeDrive;
	my $otherDirectory;
	$SMB{allowed} = $$self{allowflag} ? 0 : 1; 

	#### Variablen fuer Syntaxpruefung
	my $regex_drive  = "(?:[A-Za-z]:)";
	my $regex_domain =  "(?:(?:[a-zA-Z0-9-]+?)(?:\.[a-zA-Z0-9-]+?)*?)";
	#### DC Benutzerdaten auslesen
	#### Domain Controller finden
	my $res = Net::DNS::Resolver->new();
	$res->nameservers( @{$$self{nameservers}} ) if $$self{nameservers};
	my $query = $res->search( "_ldap._tcp.\L$domain\E", 'SRV' );
	if ($query) {
		foreach my $rr ( $query->answer ) {
			next unless $rr->type eq 'SRV';
			$dc = $rr->target;
			last;
		}
	} else { carp $res->errorstring ; }
	
	$self->debug("genConfig: domain controller: $dc");

	#### homedirectory Eintrag auslesen
	my $ldap = Net::LDAP->new($dc) or confess $@;
	my $sasl = Authen::SASL->new(mechanism => 'GSSAPI', debug=>$$self{debug}) or confess $@;
	my $result = $ldap->bind( sasl => $sasl );
	confess $result->error if $result->code;
	my $basename = 'dc=' . join( ',dc=', split(/\./, $domain) );

	$result = $ldap->search( base => $basename, filter => "(samaccountname=$user)" );
	foreach ( $result->entries ) {
		$homeDirectory  = $_->get_value('homeDirectory');
		$homeDrive      = uc( $_->get_value('homeDrive') );
		$otherDirectory = $_->get_value($$self{ldapattr});
	}
	$ldap->unbind();

	$self->debug("genConfig: homeDirectory: $homeDirectory, homeDrive: $homeDrive, other=$otherDirectory");

	#### homedirectory als Share eintragen
	chomp($homeDirectory);
	$homeDirectory =~ s/\s+$//;    # Leerzeichen am Ende entfernen
	$homeDirectory =~ s/\*.*//;    # Kommentare entfernen
	if ( $homeDirectory =~ /^\\\\($regex_domain)\\([^\\]+)(\\.*)?$/ ) {    # wenn es ein korrekter Shareeintrag ist
		my ($homeServer, $homeShare, $homeDir) = ($1,$2,$3);
		if ($homeDir) {
			$homeDir =~ s/\\/\//g;   # alle restlischen Rückstriche umwandeln
			$homeDir =~ s/\/$//g;
		} 
		$SMB{domains}->{$domain}->{fileserver}->{$homeServer}->{shares} = [$homeShare];
		$SMB{domains}->{$domain}->{fileserver}->{$homeServer}->{sharealiases}->{$homeShare} = "$homeDrive \u$homeShare/";
		$SMB{domains}->{$domain}->{fileserver}->{$homeServer}->{initdir}->{$homeShare} = $homeDir if $homeDir;
	}
	#### [DRIVE:] \\ SERVER \ SHARE \ DIRECTORY
	foreach ( split( /\r?\n/, $otherDirectory ) ) {
		chomp;
		s/\*.*//;          # Kommentare entfernen
		s/^\s+//;          # Leerzeichen am Anfang entfernen
		s/\s+$//;          # Leerzeichen am Ende entfernen
		s/.*;$//; 
		if ($$self{allowflag} && /^\Q$$self{allowflag}\E/) {
			$SMB{allowed} = 1;
		} 
		if (/^($regex_drive)?\\\\($regex_domain)\\([^\\]+)(\\.*)?$/) {
			my ($drive, $server, $share, $directory) = ( uc($1), $2, $3,$4 );    
			$directory = "" unless $directory;
			$directory =~ s/\\/\//g;           # umwandeln von \ nach /
			$directory =~ s/\/$//; # / am Ende entfernen
			my $alias = $directory;          # Alias auf Pfad ableiten
			$alias =~ s/.*\///;
			push(@{$SMB{domains}->{$domain}->{fileserver}->{$server}->{shares}}, $share . $directory );
			if ($alias) {
				$SMB{domains}->{$domain}->{fileserver}->{$server}->{sharealiases}->{ $share . $directory } = "$drive \u$share: $alias/";
			} else {
				$SMB{domains}->{$domain}->{fileserver}->{$server}->{sharealiases}->{ $share . $directory } = "$drive \u$share/";
			}
		}
	}
		
	return $SMB{allowed} ? \%SMB : {};
}

1;