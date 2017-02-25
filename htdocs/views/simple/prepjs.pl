#!/usr/bin/perl
########################################################################
# (C) ZE CMS, Humboldt-Universitaet zu Berlin
# Written by Daniel Rohde <d.rohde@cms.hu-berlin.de>
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

use strict;
use warnings;
our $VERSION = '1.0';

use Carp;
use English qw( -no_match_vars );

local $RS = undef;
print replace_include(scalar <>);

sub replace_include {
    my ($js) = @_;
    ### replace /**INCLUDE(<filename>)**/
    $js =~ s{/[*][*]INCLUDE[(] ([^)]+) [)][*][*]/}{get_js($1)}xmseg;
    return $js;
}
sub get_js {
    my ($fn) = @_;
    my $text = q{};
    if ($fn=~/,/xms) {
        foreach ( split /\s*,\s*/xms, $fn ) {
            $text .= get_js($_);
        }
    } elsif (open my $fh, '<', $fn) {
        local $RS = undef;
        $text = replace_include(scalar <$fh>);
        close $fh;
    } else {
        carp("Cannot read $fn.");
    }
    return $text;
}