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
#use warnings;

use Date::Parse;

use WebDAV::Common;
our @ISA = ( 'WebDAV::Common' );

sub new {
       my $this = shift;
       my $class = ref($this) || $this;
       my $self = { };
       bless $self, $class;
       $$self{config}=shift;
       $$self{db}=shift;
       $self->initialize();
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
        $locktype=~s/{[^}]+}// if $locktype;
        $lockscope=~s/{[^}]+}// if $lockscope;

        $activelock{locktype}{$locktype}=undef if $locktype;
        $activelock{lockscope}{$lockscope}=undef if $lockscope;
        $activelock{locktoken}{href}=$token;
        $activelock{depth}=$depth;
        $activelock{lockroot}=$ru;

	my $rfn = $self->resolve($fn);
	my $rbase = $self->resolve($base?$base:$fn);

        # save lock to database (structure: basefn, fn, type, scope, token, timeout(null), owner(null)):
        if ($$self{db}->db_insert($rbase,$rfn,$locktype,$lockscope,$token,$depth,$timeout, $owner))  {
                push @prop, { activelock=> \%activelock };
        } elsif ($$self{db}->db_update($rbase,$rfn,$timeout)) {
                push @prop, { activelock=> \%activelock };
        } else {
                push @{$resp{multistatus}{response}},{href=>$ru, status=>'HTTP/1.1 403 Forbidden (db update failed)'};
        }
        my $nfn = $$self{backend}->resolve($fn);
        return \%resp if exists $$visited{$nfn};
        $$visited{$nfn}=1;

        if ($$self{backend}->isDir($fn) && (lc($depth) eq 'infinity' || $depth>0)) {
                if ($$self{backend}->isReadable($fn)) {
                        foreach my $f (@{$$self{backend}->readDir($fn,main::getFileLimit($fn),$$self{utils})}) {
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
        my $rfn = $self->resolve($fn);
        return $$self{db}->db_isRootFolder($rfn, $token) && $$self{db}->db_delete($rfn,$token);
}
sub _checkTimedOut {
	my ($self, $fn, $rows) = @_;
	my $ret = 0;
	my $now = time();
	$main::DBI_TIMEZONE = $main::DBI_SRC =~ /dbi:SQLite/i ? 'GMT' : 'localtime' unless $main::DBI_TIMEZONE;
	$main::DEFAULT_LOCK_TIMEOUT = 3600 unless $main::DEFAULT_LOCK_TIMEOUT;
	while (my $row = shift @{$rows}) {
		my ($token, $timeout, $timestamp) = ($$row[4], $$row[6], int(str2time($$row[8], $main::DBI_TIMEZONE)));
		$timeout="Second-$main::DEFAULT_LOCK_TIMEOUT" if !defined $timeout || $timeout =~ /^\s*$/;
		main::debug("_checkTimedOut($fn): token=$token, timeout=$timeout, timestamp=$timestamp");
		if ($timeout =~ /(\d+)$/) {
			my $val = $1;
			my $mult = 1;
			my %m = ( 'second' => 1, 'minute' => 60, 'hour' => 3600, 'day' => 86400, 'week' => 604800);
			if ($timeout =~ /^([^\-]+)/) {
				$mult = $m{lc($1)} || 1;
			}
			$ret = $now - $timestamp - ($mult * $val) >= 0 ? 1 : 0;
			main::debug("_checkTimedOut($fn): now=$now, mult=$mult, val=$val (now-timestamp)=".($now-$timestamp).": ret=$ret");
			$$self{db}->db_delete($fn,$token) if $ret;
		}
	}
	return $ret;
}
sub isLockedRecurse {
        my ($self,$fn) = @_;
        $fn = $main::PATH_TRANSLATED unless defined $fn;
        my $rfn = $self->resolve($fn);
        my $rows = $$self{db}->db_getLike("$rfn\%");
        return $#{$rows} >-1 && !$self->_checkTimedOut($rfn, $rows);
}
sub isLocked {
        my ($self,$fn) = @_;
        my $rfn = $self->resolve($fn);
        $rfn.='/' if $$self{backend}->isDir($fn) && $rfn !~/\/$/;
        my $rows = $$self{db}->db_get($rfn);
        return (($#{$rows}>-1) && !$self->_checkTimedOut($rfn, $rows)) ? 1 : 0;
}
sub isLockedCached {
	my ($self, $fn) = @_;
	my $rfn = $self->resolve($fn);
        $rfn.='/' if $$self{backend}->isDir($fn) && $rfn !~/\/$/;
        my $rows = $$self{db}->db_getCached($rfn);
        return (($#{$rows}>-1) && !$self->_checkTimedOut($rfn, $rows)) ? 1 : 0;
}
sub isLockable  { # check lock and exclusive
        my ($self, $fn,$xmldata) = @_;
        my $rfn = $self->resolve($fn);
        my @lockscopes = keys %{$$xmldata{'{DAV:}lockscope'}};
        my $lockscope = @lockscopes && $#lockscopes >-1 ? $lockscopes[0] : 'exclusive';

        my $rowsRef;
        if (! $$self{backend}->exists($fn)) {
                $rowsRef = $$self{db}->db_get($self->resolve($$self{backend}->getParent($fn)).'/');
        } elsif ($$self{backend}->isDir($fn)) {
                $rowsRef = $$self{db}->db_getLike("$rfn\%");
        } else {
                $rowsRef = $$self{db}->db_get($rfn);
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
sub getLockDiscovery {
	my ($self, $fn) = @_;
	my $rfn = $self->resolve($fn);
	main::debug("getLockDiscovery($fn) (rfn=$rfn)");
	my $rowsRef = $$self{db}->db_get($rfn);
	
	my @resp = ();
	main::debug("getLockDiscovery: rowcount=".$#{$rowsRef});
	if ($#$rowsRef > -1) {
		foreach my $row (@{$rowsRef}) { # basefn,fn,type,scope,token,depth,timeout,owner
			my %lock;
			$lock{locktype}{$$row[2]}=undef if defined $$row[2];
			$lock{lockscope}{$$row[3]}=undef if defined $$row[3];
			$lock{locktoken}{href}=$$row[4];
			$lock{depth}=$$row[5];
			$lock{timeout}= defined $$row[6] ? $$row[6] : 'Infinite';
			$lock{owner}=$$row[7] if defined $$row[7];

			push @resp, {activelock=>\%lock};
		}

	}
	main::debug("getLockDiscovery: resp count=".$#resp);
	
	return $#resp >-1 ? \@resp : undef;
}
sub getTokens {
	my ($self, $fn, $recurse) = @_;
	my $rfn = $self->resolve($fn);
	my $rowsRef = $recurse ? $$self{db}->db_getLike("$rfn%") : $$self{db}->db_get( $rfn );
	my @tokens = map { $$_[4]} @{$rowsRef};
	return \@tokens;
}
sub inheritLock {
	my ($self, $fn,$checkContent, $visited) = @_;
	$fn =  $main::PATH_TRANSLATED unless defined $fn;
	my $backend = $$self{backend};

	my $rfn = $self->resolve($fn);
	
	my $nfn = $backend->resolveVirt($backend->resolve($fn));
	return if exists $$visited{$nfn};
	$$visited{$nfn}=1;

	my $bfn = $backend->getParent($fn).'/';

	main::debug("inheritLock: check lock for $bfn ($fn)");
	my $db = $$self{db};
	my $rows = $db->db_get($self->resolve($bfn));
	return if $#{$rows} == -1 and !$checkContent;
	main::debug("inheritLock: $bfn is locked") if $#{$rows}>-1;
	if ($checkContent) {
		$rows = $db->db_get($rfn);
		return if $#{$rows} == -1;
		main::debug("inheritLock: $fn is locked");
	}
	my $row = $$rows[0];
	if ($backend->isDir($fn)) {
		main::debug("inheritLock: $fn is a collection");
		$db->db_insert($$row[0],$rfn,$$row[2],$$row[3],$$row[4],$$row[5],$$row[6],$$row[7]);
		if ($backend->isReadable($fn)) {
			foreach my $f (@{$backend->readDir($fn,main::getFileLimit($fn),$main::utils)}) {
				my $full = $fn.$f;
				$full .='/' if $backend->isDir($full) && $full !~/\/$/;
				$db->db_insert($self->resolve($$row[0]),$$self->resolve($full),$$row[2],$$row[3],$$row[4],$$row[5],$$row[6],$$row[7]);
				$self->inheritLock($full,undef,$visited);
			}
		}
	} else {
		$db->db_insert($self->resolve($$row[0]),$rfn,$$row[2],$$row[3],$$row[4],$$row[5],$$row[6],$$row[7]);
	}
}
1;