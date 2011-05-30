#!/usr/bin/perl
#########################################################################
# (C) ZE CMS, Humboldt-Universitaet zu Berlin
# Written 2010-2011 by Daniel Rohde <d.rohde@cms.hu-berlin.de>
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

package WebDAV::Lock;

use strict;

sub new {
       my $this = shift;
       my $class = ref($this) || $this;
       my $self = { };
       bless $self, $class;
       $$self{cgi}=shift;
       $$self{backend}=shift;
       $$self{db}=shift;
       return $self;
}

sub lockResource {
        my ($self, $fn, $ru, $xmldata, $depth, $timeout, $token, $base, $visited) =@_;
        my %resp = ();
        my @prop= ();

        my %activelock = ();
        my @locktypes = keys %{$$xmldata{'{DAV:}locktype'}};
        my @lockscopes = keys %{$$xmldata{'{DAV:}lockscope'}};
        my $locktype= $#locktypes>-1 ? $locktypes[0] : undef;
        my $lockscope = $#lockscopes>-1 ? $lockscopes[0] : undef;
        my $owner = main::createXML(defined $$xmldata{'{DAV:}owner'} ?  $$xmldata{'{DAV:}owner'} : $main::DEFAULT_LOCK_OWNER, 0, 1);
        $locktype=~s/{[^}]+}//;
        $lockscope=~s/{[^}]+}//;

        $activelock{locktype}{$locktype}=undef;
        $activelock{lockscope}{$lockscope}=undef;
        $activelock{locktoken}{href}=$token;
        $activelock{depth}=$depth;
        $activelock{lockroot}=$ru;

        # save lock to database (structure: basefn, fn, type, scope, token, timeout(null), owner(null)):
        if ($$self{db}->db_insert(defined $base?$base:$fn,$fn,$locktype,$lockscope,$token,$depth,$timeout, $owner))  {
                push @prop, { activelock=> \%activelock };
        } elsif ($$self{db}->db_update(defined $base?$base:$fn,$fn,$timeout)) {
                push @prop, { activelock=> \%activelock };
        } else {
                push @{$resp{multistatus}{response}},{href=>$ru, status=>'HTTP/1.1 403 Forbidden (db update failed)'};
        }
        my $nfn = $$self{backend}->resolve($fn);
        return \%resp if exists $$visited{$nfn};
        $$visited{$nfn}=1;

        if ($$self{backend}->isDir($fn) && (lc($depth) eq 'infinity' || $depth>0)) {
                if ($$self{backend}->isReadable($fn)) {
                        foreach my $f (@{$$self{backend}->readDir($fn,main::getFileLimit($fn),\&main::filterCallback)}) {
                                my $nru = $ru.$f;
                                my $nfn = $fn.$f;
                                $nru.='/' if $$self{backend}->isDir($nfn);
                                $nfn.='/' if $$self{backend}->isDir($nfn);
                                my $subreqresp = $self->lockResource($nfn, $nru, $xmldata, lc($depth) eq 'infinity'?$depth:$depth-1, $timeout, $token, defined $base?$base:$fn, $visited);
                                if (defined $$subreqresp{multistatus}) {
                                        push @{$resp{multistatus}{response}}, @{$$subreqresp{multistatus}{response}};
                                } else {
                                        push @prop, @{$$subreqresp{prop}{lockdiscovery}} if exists $$subreqresp{prop};
                                }
                        }
                } else {
                        push @{$resp{multistatus}{response}}, { href=>$ru, status=>'HTTP/1.1 403 Forbidden' };
                }
        }
        push @{$resp{multistatus}{response}}, {propstat=>{prop =>{lockdiscovery=>\@prop }}} if exists $resp{multistatus} && $#prop>-1;
        $resp{prop}{lockdiscovery}=\@prop unless defined $resp{multistatus};

        return \%resp;
}
sub unlockResource {
        my ($self, $fn, $token) = @_;
        return $$self{db}->db_isRootFolder($fn, $token) && $$self{db}->db_delete($fn,$token);
}

1;
