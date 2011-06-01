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

package Utils;

use strict;

sub new {
	my $this = shift;
	my $class = ref($this) || $this;
	my $self = { };
	bless $self, $class;
	return $self;
}

sub getHiddenFilter {
        return @main::HIDDEN ? '('.join('|',@main::HIDDEN).')' : undef;
}

sub filter {
        my ($self, $path, $file) = @_;
        my $hidden = $self->getHiddenFilter();
        my $filter = defined $path ? $main::FILEFILTERPERDIR{$path} : undef;
        return 1 if defined $file && $file =~ /^\.{1,2}$/;
        return 1 if defined $filter && defined $file && $file !~ $filter;
        return 1 if defined $hidden && defined $file && defined $path && "$path$file" =~ /$hidden/;
        return 0;
}

1;
