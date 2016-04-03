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
use warnings;
our $VERSION = '2.0';

use Net::LDAP;
use Authen::SASL qw(Perl);
use Net::DNS;
use Cache::Memcached;
use CGI::Carp;
use English qw( -no_match_vars );

use vars qw( $REGEX_DRIVE $REGEX_DOMAIN );

{
    $REGEX_DRIVE  = '(?:[[:alpha:]]:)';
    $REGEX_DOMAIN = '(?:(?:[[:alnum:]\-]+?)(?:[.][[:alnum:]\-]+?)*?)';
}

sub new {
    my ( $class, %config ) = @_;
    my $self = {};
    bless $self, $class;
    return $self->_init(%config);
}

sub _init {
    my ( $self, %config ) = @_;

    $self->{memcached} = $config{memcached};    ###  127.0.0.1:11211
    $self->{memcachedexpire} = $config{memcachedexpire} // 600;
    $self->{debug}           = $config{debug};
    $self->{separator}       = $config{separator} // q{~};
    $self->{defaultdomain} =
      $config{defaultdomain}
      ? uc( $config{defaultdomain} )
      : 'CMS.HU-BERLIN.DE';
    $self->{nameservers} = $config{nameservers};
    $self->{allowflag}   = $config{allowflag};
    $self->{ldapattr}    = $config{ldapattr} // 'info';
    $self->{retries}     = $config{retries} // 3;
    return $self;
}

sub getSmbConfig {
    my ($self) = @_;
    my $smb;
    if ( $self->{memcached} ) {
        my $cache = Cache::Memcached->new(
            {
                servers => [ $self->{memcached} ],
                debug   => $self->{debug}
            }
        );
        my $key = $ENV{REMOTE_USER} // $ENV{REDIRECT_REMOTE_USER};
        $smb = $cache->get($key);
        if ( !$smb ) {
            $smb = $self->_get_smb_config();
            if ( defined $smb->{defaultdomain} ) {
                $cache->set( $key, $smb, $self->{memcachedexpire} );
            }
        }
    }
    else {
        $smb = $self->_get_smb_config();
    }
    return $smb;
}

sub debug {
    my ( $self, @args ) = @_;
    if ( !$self->{debug} ) { return; }
    print( {*STDERR} join( ', ', @args ) . "\n" )
      || carp('Cannot print to STDERR.');
    return $self;
}

sub _get_smb_config {
    my $self = shift;
    my %SMB;
    my $remote_user = $ENV{REMOTE_USER} || $ENV{REDIRECT_REMOTE_USER};
    #### Bentutzername und Domaine extrahieren
    my @rurd   = split /\@/xms, $remote_user;
    my $user   = $rurd[0];
    my $domain = $rurd[1] ? uc( $rurd[1] ) : $self->{defaultdomain};

    $self->debug("genConfig: user=$user, domain=$domain");

    #### Variablen
    my $separator = $self->{separator};
    %SMB = (
        defaultdomain => $domain // $self->{defaultdomain},
        sharesep      => $separator,
        secure        => 1,
        retries       => $self->{retries},
    );
    my $dc;
    my $home_directory;
    my $home_drive;
    my $other_directory;
    $SMB{allowed} = $self->{allowflag} ? 0 : 1;

    #### DC Benutzerdaten auslesen
    #### Domain Controller finden
    my $res = Net::DNS::Resolver->new();
    if ( $self->{nameservers} ) {
        $res->nameservers( @{ $self->{nameservers} } );
    }
    my $query = $res->search( "_ldap._tcp.\L$domain\E", 'SRV' );
    if ($query) {
        foreach my $rr ( $query->answer ) {
            next if $rr->type ne 'SRV';
            $dc = $rr->target;
            last;
        }
    }
    else { carp $res->errorstring; }

    $self->debug("genConfig: domain controller: $dc");

    #### homedirectory Eintrag auslesen
    my $ldap = Net::LDAP->new($dc) or confess $EVAL_ERROR;
    my $sasl =
         Authen::SASL->new( mechanism => 'GSSAPI', debug => $self->{debug} )
      or confess $EVAL_ERROR;
    my $result = $ldap->bind( sasl => $sasl );
    confess $result->error if $result->code;
    my $basename = 'dc=' . join ',dc=', split /[.]/xms, $domain;

    $result = $ldap->search(
        base   => $basename,
        filter => "(samaccountname=$user)"
    );
    foreach ( $result->entries ) {
        $home_directory  = $_->get_value('homeDirectory');
        $home_drive      = uc( $_->get_value('homeDrive') );
        $other_directory = $_->get_value( $self->{ldapattr} );
    }
    $ldap->unbind();

    $self->debug(
"genConfig: homeDirectory: $home_directory, homeDrive: $home_drive, other=$other_directory"
    );

    #### homedirectory als Share eintragen
    chomp $home_directory;
    $home_directory =~ s/\s+$//xms;     # Leerzeichen am Ende entfernen
    $home_directory =~ s/[*].*//xms;    # Kommentare entfernen
    if ( $home_directory =~ /^\\\\($REGEX_DOMAIN)\\([^\\]+)(\\.*)?$/xms )
    {                                   # wenn es ein korrekter Shareeintrag ist
        my ( $home_server, $home_share, $home_dir ) = ( $1, $2, $3 );
        if ($home_dir) {
            $home_dir =~ s{\\}{/}xmsg; # alle restlischen Rückstriche umwandeln
            $home_dir =~ s{/$}{}xmsg;
        }
        $SMB{domains}->{$domain}->{fileserver}->{$home_server}->{shares} =
          [$home_share];
        $SMB{domains}->{$domain}->{fileserver}->{$home_server}->{sharealiases}
          ->{$home_share} = "$home_drive \u$home_share/";
        if ($home_dir) {
            $SMB{domains}->{$domain}->{fileserver}->{$home_server}->{initdir}
              ->{$home_share} = $home_dir;
        }
    }

    $self->_handle_other_directory( \%SMB, $domain, $other_directory );

    if ( $self->{debug} ) {
        require Data::Dumper;
        $self->debug( Data::Dumper::Dumper( \%SMB ) );
    }
    return $SMB{allowed} ? \%SMB : {};
}

sub _handle_other_directory {
    my ( $self, $smbref, $domain, $other_directory ) = @_;
    #### [DRIVE:] \\ SERVER \ SHARE \ DIRECTORY
    foreach ( split /\r?\n/xms, $other_directory ) {
        chomp;
        s/[*].*//xms;    # Kommentare entfernen
        s/^\s+//xms;     # Leerzeichen am Anfang entfernen
        s/\s+$//xms;     # Leerzeichen am Ende entfernen
        s/.*;$//xms;
        if ( $self->{allowflag} && /^\Q$self->{allowflag}\E/xms ) {
            $smbref->{allowed} = 1;
        }
        if (/^($REGEX_DRIVE)?\\\\($REGEX_DOMAIN)\\([^\\]+)(\\.*)?$/xms) {
            my ( $drive, $server, $share, $directory ) =
              ( uc($1), $2, $3, $4 );
            $directory //= q{};
            $directory =~ s{\\}{/}xmsg;    # umwandeln von \ nach /
            $directory =~ s{/$}{/}xms;     # / am Ende entfernen
            my $alias = $directory;        # Alias auf Pfad ableiten
            $alias =~ s{.*/}{}xms;
            push @{ $smbref->{domains}->{$domain}->{fileserver}->{$server}
                  ->{shares} },
              $share . $directory;
            if ($alias) {
                $smbref->{domains}->{$domain}->{fileserver}->{$server}
                  ->{sharealiases}->{ $share . $directory } =
                  "$drive \u$share: $alias/";
            }
            else {
                $smbref->{domains}->{$domain}->{fileserver}->{$server}
                  ->{sharealiases}->{ $share . $directory } =
                  "$drive \u$share/";
            }
        }
    }
    return $smbref;
}
1;
