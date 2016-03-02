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

our $VERSION = '2.0';

use base qw(Events::EventListener );

use vars qw( $_INSTANCE );

sub new {
    my $this  = shift;
    my $class = ref($this) || $this;
    my $self  = {};
    if ( !$_INSTANCE ) {
        bless $self, $class;
        $_INSTANCE = $self;
        $self->register(main::getEventChannel());
    }
    return $_INSTANCE;
}

sub getinstance {
    return __PACKAGE__->new();
}

sub strip_slash {
    my ( $self, $file ) = @_;
    $file =~ s/\/$//xms;
    return $file;
}

sub normalize {
    my ( $self, $file ) = @_;
    return $self->strip_slash( main::getPropertyModule()->resolve($file) );
}

sub register {
    my ( $self, $channel ) = @_;
    $channel->add(
        [ 'FINALIZE', 'FILEMOVED', 'FILECOPIED', 'DELETED', 'WEB-DELETED' ],
        $self );
    return 1;
}

sub receive {
    my ( $self, $event, $data ) = @_;
    my $db = main::getDBDriver();
    if ( $event eq 'FINALIZE' ) {
        $db->finalize();
    }
    elsif ( $event eq 'FILEMOVED' ) {
        my ( $src, $dst ) = (
            $self->normalize( ${$data}{file} ),
            $self->normalize( ${$data}{destination} )
        );
        $db->db_deleteProperties($dst);
        $db->db_movePropertiesRecursive( $src, $dst );
        $db->db_delete($src);
    }
    elsif ( $event eq 'FILECOPIED' ) {
        my ( $src, $dst ) = (
            $self->normalize( ${$data}{file} ),
            $self->normalize( ${$data}{destination} )
        );
        $db->db_deleteProperties($dst);
        $db->db_copyProperties( $src, $dst );
    }
    elsif ( $event eq 'DELETED' || $event eq 'WEB-DELETED' ) {
        my ($dst) = ( $self->normalize( ${$data}{file} ) );
        $db->db_deletePropertiesRecursive($dst);
        $db->db_delete($dst);
    }
    return 1;
}
1;
