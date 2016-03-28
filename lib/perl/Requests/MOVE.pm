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

package Requests::MOVE;

use strict;
use warnings;

our $VERSION = '2.0';

use base qw( Requests::WebDAVRequest );

use URI::Escape;

use DefaultConfig qw( $PATH_TRANSLATED $DOCUMENT_ROOT $VIRTUAL_BASE );
use FileUtils qw( rmove );
use HTTPHelper qw( print_header_and_content );

sub handle {
    my ($self)      = @_;
    my $cgi         = $self->{cgi};
    my $backend     = $self->{backend};
    my $host        = $cgi->http('Host');
    my $destination = $cgi->http('Destination');
    my $overwrite =
      defined $cgi->http('Overwrite') ? $cgi->http('Overwrite') : 'T';
    $self->debug("_MOVE: $PATH_TRANSLATED => $destination");
    $destination =~
      s{^https?://([^\@]+\@)?\Q$host\E(:\d+)?$VIRTUAL_BASE}{}xms;
    $destination = uri_unescape($destination);
    $destination = uri_unescape($destination);
    $destination = $DOCUMENT_ROOT . $destination;

    if (   ( !defined $destination )
        || ( $destination eq q{} )
        || ( $PATH_TRANSLATED eq $destination ) )
    {
        return print_header_and_content('403 Forbidden');
    }
    if ( $backend->exists($destination) && $overwrite eq 'F' ) {
        return print_header_and_content('412 Precondition Failed');
    }
    if ( !$backend->isDir( $backend->getParent($destination) ) ) {
        return print_header_and_content('409 Conflict');
    }
    if (
        !$self->is_allowed( $PATH_TRANSLATED,
            $backend->isDir($PATH_TRANSLATED) )
        || !$self->is_allowed( $destination, $backend->isDir($destination) )
      )
    {
        return print_header_and_content('423 Locked');
    }
    $self->{event}->broadcast(
        'MOVE',
        {
            file        => $PATH_TRANSLATED,
            destination => $destination,
            overwrite   => $overwrite
        }
    );
    if ( $backend->exists($destination) && $backend->isFile($destination) ) {
        $backend->unlinkFile($destination);
    }
    my $status =
      $backend->exists($destination) ? '204 No Content' : '201 Created';
    if ( !rmove( $self->{config}, $PATH_TRANSLATED, $destination ) ) {
        return print_header_and_content(
            "403 Forbidden (rmove($PATH_TRANSLATED, $destination) failed)"
        );
    }
    $self->get_lock_module()->inherit_lock( $destination, 1 );
    $self->logger("MOVE($PATH_TRANSLATED, $destination)");
    $self->{event}->broadcast(
        'MOVED',
        {
            file        => $PATH_TRANSLATED,
            destination => $destination,
            overwrite   => $overwrite
        }
    );
    $self->debug("_MOVE: status=$status");
    return print_header_and_content($status);
}

1;
