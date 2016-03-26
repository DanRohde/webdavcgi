#########################################################################
# (C) ZE CMS, Humboldt-Universitaet zu Berlin
# Written 2013 by Daniel Rohde <d.rohde@cms.hu-berlin.de>
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

package DatabaseEventAdapter;

use strict;
use warnings;

our $VERSION = '2.1';

use base qw(Events::EventListener );

use vars qw( $_INSTANCE );

sub new {
    my $this  = shift;
    my $class = ref($this) || $this;
    my $self  = {};
    if ( !$_INSTANCE ) {
        bless $self, $class;
        $_INSTANCE = $self;
    }
    $self->{config} = shift;
    return $_INSTANCE;
}

sub getinstance {
    return __PACKAGE__->new();
}

sub _strip_slash {
    my ( $self, $file ) = @_;
    $file =~ s/\/$//xms;
    return $file;
}

sub _normalize {
    my ( $self, $file ) = @_;
    return $self->_strip_slash( main::getPropertyModule()->resolve($file) );
}

sub register {
    my ( $self, $channel ) = @_;
    $channel->add(
        [ 'FINALIZE', 'FILEMOVED', 'FILECOPIED', 'DELETED', 'WEB-DELETED' ],
        $self );
    return 1;
}

sub _handle_file_moved {
    my ( $self, $event, $data, $db ) = @_;
    if ( $event ne 'FILEMOVED' ) {
        return 0;
    }
    my ( $src, $dst ) = (
        $self->_normalize( ${$data}{file} ),
        $self->_normalize( ${$data}{destination} )
    );
    $db->db_deleteProperties($dst);
    $db->db_movePropertiesRecursive( $src, $dst );
    $db->db_delete($src);
    return 1;
}

sub _handle_file_copied {
    my ( $self, $event, $data, $db ) = @_;
    if ( $event ne 'FILECOPIED' ) {
        return 0;
    }
    my ( $src, $dst ) = (
        $self->_normalize( ${$data}{file} ),
        $self->_normalize( ${$data}{destination} )
    );
    $db->db_deleteProperties($dst);
    $db->db_copyProperties( $src, $dst );
    return 1;
}

sub _handle_deleted {
    my ( $self, $event, $data, $db ) = @_;
    if ( $event ne 'DELETED' && $event ne 'WEB-DELETED' ) {
        return 0;
    }
    my ($dst) = ( $self->_normalize( ${$data}{file} ) );
    $db->db_deletePropertiesRecursive($dst);
    $db->db_delete($dst);
    return 1;
}

sub receive {
    my ( $self, $event, $data ) = @_;
    my $db = $self->{config}->{db};
    if ( $event eq 'FINALIZE' ) {
        $db->finalize();
    }
    else {
        $self->_handle_file_moved( $event, $data, $db )
            || $self->_handle_deleted( $event, $data, $db )
            || $self->_handle_file_copied( $event, $data, $db );
    }
    return 1;
}
1;
