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
use warnings;

our $VERSION = '2.0';

use base qw( Backend::FS::Driver );

use CGI::Carp;
use English qw( -no_match_vars );

use DefaultConfig qw( %BACKEND_CONFIG $BACKEND );

sub isFile {
    return $_[0]->_check_caller_access( $_[1], 'l', 'r' )
      ? $_[0]->SUPER::isFile( $_[1] )
      : 1;
}
sub isLink {
    return $_[0]->_check_caller_access( $_[1], 'l', 'r' )
      ? $_[0]->SUPER::isLink( $_[1] )
      : 0;
}

sub isReadable {
    return $_[0]->_check_caller_access( $_[1], 'l', 'r' );
}

sub isWriteable {
    return $_[0]->_check_caller_access( $_[1], 'w' );
}

sub isExecutable {
    return $_[0]->_check_caller_access( $_[1], 'l', 'r' )
      ? $_[0]->SUPER::isExecutable( $_[1] )
      : 1;
}

sub hasSetUidBit {
    return $_[0]->_check_caller_access( $_[1], 'l', 'r' )
      ? $_[0]->SUPER::hasSetUidBit( $_[1] )
      : 0;
}

sub hasSetGidBit {
    return $_[0]->_check_caller_access( $_[1], 'l', 'r' )
      ? $_[0]->SUPER::hasSetGidBit( $_[1] )
      : 0;
}

sub hasStickyBit {
    return $_[0]->_check_caller_access( $_[1], 'l', 'r' )
      ? $_[0]->SUPER::hasStickyBit( $_[1] )
      : 0;
}

sub isBlockDevice {
    return $_[0]->_check_caller_access( $_[1], 'l', 'r' )
      ? $_[0]->SUPER::isBlockDevice( $_[1] )
      : 0;
}

sub isCharDevice {
    return $_[0]->_check_caller_access( $_[1], 'l', 'r' )
      ? $_[0]->SUPER::isCharDevice( $_[1] )
      : 0;
}

sub exists {
    return $_[0]->_check_caller_access( $_[1], 'l', 'r' )
      ? $_[0]->SUPER::exists( $_[1] )
      : 1;
}

sub isEmpty {
    return $_[0]->_check_caller_access( $_[1], 'l', 'r' )
      ? $_[0]->SUPER::isEmpty( $_[1] )
      : 1;
}

sub stat {
    return $_[0]->_check_caller_access( $_[1], 'l', 'r' )
      ? $_[0]->SUPER::stat( $_[1] )
      : ( 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 );
}

sub getQuota {
    my ( $self, $fn ) = @_;
    $fn =~ s/(["\$\\])/\\$1/xmsg;
    if ( !defined $BACKEND_CONFIG{$BACKEND}{quota} ) {
        return ( 0, 0 );
    }
    my $cmd = sprintf '%s "%s"', $BACKEND_CONFIG{$BACKEND}{quota},
      $self->resolveVirt($fn);
    if ( open my $cmdfh, q{-|}, $cmd ) {
        my @lines = <$cmdfh>;
        close($cmdfh) || carp("Cannot close cmd $cmd\n");
        my @vals = $#lines >=1 ? split /\s+/xms, $lines[1] : (0,0,0);
        return ( $vals[1] * 1024, $vals[2] * 1024 );
    }
    return ( 0, 0 );
}

sub _get_caller_access {
    my ( $self, $fn ) = @_;
    $fn = $self->resolveVirt($fn);
    $fn =~ s{/$}{}xms;                # remove trailing slash
    $fn =~ s{/[^/]+/[.]{2}$}{}xms;    # eliminate ../
    $fn =~ s/(["\$\\])/\\$1/xmsg;     # quote special characters
    if ( exists $self->{cache}{$fn}{_get_caller_access} ) {
        return $self->{cache}{$fn}{_get_caller_access};
    }
###  checks on files working too
#    if ( !$self->isDir($fn) ) {
#        return $self->_get_caller_access( $self->dirname($fn) );
#    }
    my $access = q{};

    my $cmd = sprintf '%s getcalleraccess "%s" 2>/dev/null',
      $BACKEND_CONFIG{$BACKEND}{fscmd}, $fn;
    if ( open my $cmdfh, q{-|}, $cmd ) {
        local $RS = undef;
        my $lines = <$cmdfh>;
        close $cmdfh;
        if ( $lines && $lines =~ / ([rlidwka]{1,7})$/xms ) { $access = $1; }
    }
    return $self->{cache}{$fn}{_get_caller_access} = $access;
}

sub _check_caller_access {
    my ( $self, $fn, $dright, $fright ) = @_;
    $fright //= $dright;
    my $aright =
      $dright eq $fright || $self->SUPER::isDir($fn) ? $dright : $fright;
    return $self->_get_caller_access($fn) =~ /\Q$aright\E/xms;
}

1;
