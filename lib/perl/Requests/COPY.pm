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

package Requests::COPY;

use strict;
use warnings;

our $VERSION = '2.0';

use base qw( Requests::WebDAVRequest );

use URI::Escape;

use FileUtils qw( rcopy );
use HTTPHelper qw( print_header_and_content );

sub handle {
    my ( $self ) = @_;
    my $cgi         = $self->{cgi};
    my $backend     = $self->{backend};
    my $depth       = $cgi->http('Depth');
    my $host        = $cgi->http('Host');
    my $destination = $cgi->http('Destination');
    my $overwrite =
      defined $cgi->http('Overwrite') ? $cgi->http('Overwrite') : 'T';
    $destination =~
      s{^https?://([^\@]+\@)?\Q$host\E(:\d+)?$main::VIRTUAL_BASE}{}xms;
    $destination = uri_unescape($destination);
    $destination = uri_unescape($destination);
    $destination = $main::DOCUMENT_ROOT . $destination;

    $self->debug("_COPY: $main::PATH_TRANSLATED => $destination");

    if (   ( !defined $destination )
        || ( $destination eq q{} )
        || ( $main::PATH_TRANSLATED eq $destination ) )
    {
        return print_header_and_content('403 Forbidden');
    }
    if ( $backend->exists($destination) && $overwrite eq 'F' ) {
        return print_header_and_content('412 Precondition Failed');
    }
    if ( !$backend->isDir( $backend->getParent( ($destination) ) ) ) {
        return print_header_and_content("409 Conflict - $destination");
    }
    if (
        !$self->is_allowed(
            $destination, $backend->isDir($main::PATH_TRANSLATED)
        )
      )
    {
        return print_header_and_content('423 Locked');
    }
    main::broadcast(
        'COPY',
        {
            file        => $main::PATH_TRANSLATED,
            destination => $destination,
            depth       => $depth,
            overwrite   => $overwrite
        }
    );
    my $status =
      $backend->exists($destination) ? '204 No Content' : '201 Created';

    if ( $backend->isDir($main::PATH_TRANSLATED) && $depth == 0 ) {
        if ( !$backend->exists($destination) && !$backend->mkcol($destination) )
        {
            return print_header_and_content(
                "403 Forbidden (mkcol($destination) failed)");
        }
        $self->get_lock_module()->inherit_lock($destination);
        main::broadcast(
            'FILECOPIED',
            {
                file        => $main::PATH_TRANSLATED,
                destination => $destination,
                depth       => $depth,
                overwrite   => $overwrite
            }
        );
    }
    else {
        if ( !rcopy( $main::PATH_TRANSLATED, $destination ) ) {
            return print_header_and_content(
"403 Forbidden - copy failed (rcopy($main::PATH_TRANSLATED,$destination))"
            );
        }
        $self->get_lock_module()->inherit_lock( $destination, 1 );
        main::broadcast(
            'COPIED',
            {
                file        => $main::PATH_TRANSLATED,
                destination => $destination,
                depth       => $depth,
                overwrite   => $overwrite
            }
        );
    }
    $self->logger("COPY($main::PATH_TRANSLATED, $destination)");
    return print_header_and_content($status);
}

1;
