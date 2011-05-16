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

package Backend::GFS::Driver;

use strict;

use Backend::FS::Driver;

our @ISA = qw( Backend::FS::Driver );

our $VERSION = 0.1;

sub getQuota {
	my ($self, $fn) = @_;
	$fn=~s/(["\$\\])/\\$1/g;
	if (defined $GFSQUOTA && open(my $cmd,"$GFSQUOTA \"$fn\"|")) {
		my @lines = <$cmd>;
		close($cmd);
		my @vals = split(/\s+/,$lines[0]);
		return ($vals[3] * 1048576, $vals[7] * 1048576);
	}
	return (0,0);
}

1;
