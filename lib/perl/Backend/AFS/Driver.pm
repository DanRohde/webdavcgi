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

package Backend::AFS::Driver;

use strict;
#use warnings;

use Backend::FS::Driver;

our @ISA = qw( Backend::FS::Driver );

our $VERSION = 0.1;

sub isReadable { 
	return $_[0]->_checkCallerAccess($_[1],"l","r");
}
sub isWriteable { 
	return $_[0]->_checkCallerAccess($_[1],"w");
}
sub isExecutable {
	return 1;
}
sub hasSetUidBit { 
	return 0;
}
sub hasSetGidBit { 
	return 0;
}
sub hasStickyBit { 
	return 0;
}
sub isBlockDevice { 
	return 0;
}
sub isCharDevice { 
	return 0;
}
sub exists { 
	return $_[0]->_checkAFSAccess($_[1]);
}
sub isEmpty {
	return $_[0]->_checkAFSAccess($_[1]) && -z $_[1];
}
sub stat {
	return $_[0]->_checkAFSAccess($_[1]) ? $_[0]->SUPER::stat($_[1]) : (0,0,0,0,0,0,0,0,0,0,0,0,0);
}

sub getQuota {
	my ($self, $fn) = @_;
	$fn=~s/(["\$\\])/\\$1/g;
	if (defined $main::AFSQUOTA && open(my $cmd, sprintf("%s '%s'|", $main::AFSQUOTA, $self->resolveVirt($fn)))) {
		my @lines = <$cmd>;
		close($cmd);
		my @vals = split(/\s+/, $lines[1]);
		return ($vals[1] * 1024, $vals[2] * 1024);
	}
	return (0,0);
}
sub _getCallerAccess {
	my ($self, $fn) = @_;
	$fn = $self->resolveVirt($fn);
	$fn=~s/\/$//;
	$fn=~s/\/[^\/]+\/\.\.$//;
	return $$self{cache}{$fn}{_getCallerAccess} if exists $$self{cache}{$fn}{_getCallerAccess};
	return $self->_getCallerAccess($self->dirname($fn)) unless $self->isDir($fn);
	my $access = "";

	if (open(my $cmd, sprintf("%s getcalleraccess '%s' 2>/dev/null|", $main::AFS_FSCMD, $fn))) {
		my @lines = <$cmd>;
		close($cmd);
		chomp @lines;
		my @sl=split(/\s+/,$lines[$#lines]);
		$access = $sl[$#sl] if $sl[$#sl]=~/^[rlidwka]{1,7}$/;
	}
	return $$self{cache}{$fn}{_getCallerAccess} = $access;
}
sub _checkCallerAccess {
	my ($self, $fn, $dright,$fright) = @_;	
	$fright = $dright unless defined $fright;
	my $right = $self->isDir($fn) ? $dright : $fright; 
	return $$self{cache}{$fn}{_checkCallerAccess} if exists $$self{cache}{$fn}{_checkCallerAccess};   
	return $$self{cache}{$fn}{_checkCallerAccess} = $self->_getCallerAccess($fn) =~ /\Q$right\E/;
}
sub _checkAFSAccess {
	my $CACHE = $_[0] && $$_[0]{cache}? $$_[0]{cache} : {};
	return exists $$CACHE{$_[0]}{$_[1]}{_checkAFSAccess} 
			? $$CACHE{$_[0]}{$_[1]}{_checkAFSAccess} 
			: ( $$CACHE{$_[0]}{$_[1]}{_checkAFSAccess} = ($_[0]->SUPER::lstat($_[1]) ? 1 : 0) );
}

1;
