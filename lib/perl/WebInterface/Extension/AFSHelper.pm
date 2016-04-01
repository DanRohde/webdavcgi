#########################################################################
# (C) ZE CMS, Humboldt-Universitaet zu Berlin
# Written 2016 by Daniel Rohde <d.rohde@cms.hu-berlin.de>
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

package WebInterface::Extension::AFSHelper;

use strict;
use warnings;

our $VERSION = '2.0';

use base qw( Exporter );
our @EXPORT_OK = qw( exec_ptscmd read_afs_group_list exec_cmd
  is_valid_afs_group_name is_valid_afs_username );

use English qw( -no_match_vars );
use CGI::Carp;

use vars qw( $_CACHE );

sub exec_cmd {
    my ($cmd) = @_;
    my $output = q{};
    if ( open my $pts, q{-|}, $cmd ) {
        local $RS = undef;
        $output = <$pts>;
        close($pts) || carp("Cannot close cmd '$cmd'.");
    }
    else {
        carp("Cannot open cmd '$cmd'.");
    }
    return $output;
}

sub exec_ptscmd {
    my ($cmd) = @_;
    my @output = map { /^\s*(.*)\s*$/xms ? $1 : $_ } split /\r?\n/xms,
      exec_cmd($cmd);
    shift @output;    # remove comment
    return \@output;
}

sub read_afs_group_list {
    my ( $ptscmd, $fn, $user ) = @_;
    return exec_ptscmd(qq{$ptscmd listowned $user});
}

sub is_valid_afs_group_name {
    my ( $gn, $dottedprincipals ) = @_;
    return 0 if $gn =~ /^-/xms;
    if ($dottedprincipals) {
        return $gn =~ /^[[:word:]\@:\-.]+$/xmsi;
    }
    return $gn =~ /^[[:word:]\@:\-]+$/xmsi;
}

sub is_valid_afs_username {
    my ( $un, $dottedprincipals ) = @_;
    return 0 if $un =~ /^-/xms;
    if ($dottedprincipals) {
        return $un =~ /^[[:word:]\@\-.]+$/xmsi;
    }
    return $un =~ /^[[:word:]\@\-]+$/xmsi;
}

1;
