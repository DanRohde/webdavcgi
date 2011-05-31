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

use Backend::FS::Driver;

our @ISA = qw( Backend::FS::Driver );

our $VERSION = 0.1;

use vars qw ( %CACHE );


sub isReadable { 
	return _checkAFSAccess($_[1]);
}
sub isWriteable { 
	return _checkAFSAccess($_[1]) && -w $_[1];
}
sub isDir {
	return _checkAFSAccess($_[1]) && -d $_[1];
}
sub isFile {
	return _checkAFSAccess($_[1]) && -f $_[1];
}
sub isLink {
	return _checkAFSAccess($_[1]) && -l $_[1];
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
	return _checkAFSAccess($_[1]);
}
sub isEmpty {
	return _checkAFSAccess($_[1]) && -z $_[1];
}
sub stat {
	return _checkAFSAccess($_[1]) ? CORE::stat($_[1]) : CORE::lstat($_[1]);
}

sub getQuota {
	my ($self, $fn) = @_;
	$fn=~s/(["\$\\])/\\$1/g;
	if (defined $main::AFSQUOTA && open(my $cmd, "$main::AFSQUOTA \"$fn\"|")) {
		my @lines = <$cmd>;
		close($cmd);
		my @vals = split(/\s+/, $lines[1]);
		return ($vals[1] * 1024, $vals[2] * 1024);
	}
	return (0,0);
}

sub _checkAFSAccess {
        return $CACHE{_checkAFSAccess}{$_[0]} if exists $CACHE{_checkAFSAccess}{$_[0]};
        return $CACHE{_checkAFSAccess}{$_[0]} = (CORE::lstat($_[0]) ? 1 : 0);
}

1;
