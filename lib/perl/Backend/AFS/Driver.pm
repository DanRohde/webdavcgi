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
	return _checkAFSAccess($_[1]) && -r $_[1];
}
sub isWriteable { 
	return _checkAFSAccess($_[1]) && -w $_[1]; 
}

sub isDir {
	return _checkAFSAccess($_[1]) && -d $_[1];
}
sub isFile {
	return !_checkAFSAccess($_[1]) || -f $_[1];
}
sub isExecutable {
	return _checkAFSAccess($_[1]) && -x $_[1];
}

sub exists { 
	return _checkAFSAccess($_[1]) && -e $_[1];
}
sub isEmpty {
	return !_checkAFSAccess($_[1]) || -z $_[1];
}
sub stat {
	return _checkAFSAccess($_[1]) ? CORE::stat($_[1]) : CORE::lstat($_[1]);
}

sub _checkAFSAccess {
        my ($f) =@_;
        return $CACHE{_checkAFSAccess}{$f} if exists $CACHE{_checkAFSAccess}{$f};
        return $CACHE{_checkAFSAccess}{$f} = (lstat($f) ? 1 : 0);
}

1;
