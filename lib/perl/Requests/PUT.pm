########################################################################
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

package Requests::PUT;

use strict;
use warnings;

our $VERSION = '2.0';

use base qw( Requests::Request );

use HTTPHelper qw( print_header_and_content );
use FileUtils qw( stat2h );

sub handle {
    my ( $self, $cgi, $backend ) = @_;
    my $status  = '204 No Content';
    my $type    = 'text/plain';
    my $content = q{};

    if ( defined $cgi->http('Content-Range') ) {
        $status = '501 Not Implemented';
    }
    if (
        $backend->isDir( $backend->getParent( ($main::PATH_TRANSLATED) ) )
        && !$backend->isWriteable(
            $backend->getParent( ($main::PATH_TRANSLATED) )
        )
      )
    {
        return print_header_and_content('403 Forbidden');
    }
    if ( main::preConditionFailed($main::PATH_TRANSLATED) ) {
        return print_header_and_content('412 Precondition Failed');
    }
    if ( !main::isAllowed($main::PATH_TRANSLATED) ) {
        return print_header_and_content('423 Locked');

      #} if (defined $ENV{HTTP_EXPECT} && $ENV{HTTP_EXPECT} =~ /100-continue/) {
      #	return print_header_and_content('417 Expectation Failed');
    }
    if ( $backend->isDir( $backend->getParent( ($main::PATH_TRANSLATED) ) )
        && main::is_insufficient_storage() )
    {
        return print_header_and_content('507 Insufficient Storage');
    }
    if ( !$backend->isDir( $backend->getParent( ($main::PATH_TRANSLATED) ) ) ) {
        return print_header_and_content('409 Conflict');
    }
    if ( !$backend->exists($main::PATH_TRANSLATED) ) {
        $self->debug('_PUT: created...');
        $status = '201 Created';
        $type   = 'text/html';
        $content =
            qq@<!DOCTYPE html>\n<html><head><title>201 Created</title></head>@
          . qq@<body><h1>Created</h1><p>Resource $ENV{REQUEST_URI} has been created.</p></body></html>\n@;
    }
    if ( $backend->saveStream( $main::PATH_TRANSLATED, \*STDIN ) ) {
        main::getLockModule()->inherit_lock();
        $self->logger("PUT($main::PATH_TRANSLATED)");
        main::broadcast(
            'PUT',
            {
                file => $main::PATH_TRANSLATED,
                size => stat2h(\$backend->stat($main::PATH_TRANSLATED))->{size}
            }
        );
    }
    else {
        $status =
          is_insufficient_storage()
          ? '507 Insufficient Storage'
          : '403 Forbidden';
        $content = q{};
        $type    = 'text/plain';
    }
    return print_header_and_content( $status, $type, $content );
}

1;
