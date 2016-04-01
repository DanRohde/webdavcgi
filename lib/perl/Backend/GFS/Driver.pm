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
use warnings;

our $VERSION = '2.0';

use base qw( Backend::FS::Driver );

use CGI::Carp;

use DefaultConfig qw( $BACKEND %BACKEND_CONFIG );

sub getQuota {
    my ( $self, $fn ) = @_;
    $fn =~ s/(["\$\\])/\\$1/xmsg;
    my $cmdline = sprintf '%s "%s"',
      $BACKEND_CONFIG{$BACKEND}{quota}, $self->resolveVirt($fn);
    if ( open my $cmd, q{-|}, $cmdline ) {

        #my @lines = <$cmd>;
        my $firstline = <$cmd>;
        close($cmd) || carp( 'Cannot close GFS quota command: ' . $cmdline );

        #my @vals = split( /\s+/, $lines[0] );
        my @vals = split /\s+/xms, $firstline;
        return ( $vals[3] * 1_048_576, $vals[7] * 1_048_576 );
    }
    return ( 0, 0 );
}

1;
