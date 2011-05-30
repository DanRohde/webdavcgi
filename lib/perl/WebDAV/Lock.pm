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

sub isLockedRecurse {
        my ($self,$fn) = @_;
        $fn = $main::PATH_TRANSLATED unless defined $fn;
        my $rows = $$self{db}->db_getLike("$fn\%");
        return $#{$rows} >-1;
}
sub isLocked {
        my ($self,$fn) = @_;
        $fn.='/' if $$self{backend}->isDir($fn) && $fn !~/\/$/;
        my $rows = $$self{db}->db_get($fn);
        return ($#{$rows}>-1)?1:0;
}
sub isLockable  { # check lock and exclusive
        my ($self, $fn,$xmldata) = @_;
        my @lockscopes = keys %{$$xmldata{'{DAV:}lockscope'}};
        my $lockscope = @lockscopes && $#lockscopes >-1 ? $lockscopes[0] : 'exclusive';

        my $rowsRef;
        if (! $$self{backend}->exists($fn)) {
                $rowsRef = $$self{db}->db_get($$self{backend}->getParent($fn).'/');
        } elsif ($$self{backend}->isDir($fn)) {
                $rowsRef = $$self{db}->db_getLike("$fn\%");
        } else {
                $rowsRef = $$self{db}->db_get($fn);
        }
        my $ret = 0;
        if ($#{$rowsRef}>-1) {
                my $row = $$rowsRef[0];
                $ret =  lc($$row[3]) ne 'exclusive' && $lockscope ne '{DAV:}exclusive'?1:0;
        } else {
                $ret = 1;
        }
        return $ret;
}

1;
