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

use base qw( Requests::WebDAVRequest );

use CGI::Carp;

use HTTPHelper qw( print_header_and_content get_if_header_components get_etag );
use FileUtils qw( stat2h );

sub handle {
    my ($self) = @_;

    my $cgi     = $self->{cgi};
    my $backend = $self->{backend};
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
    if (
        $self->_pre_condition_failed( $cgi, $backend, $main::PATH_TRANSLATED ) )
    {
        return print_header_and_content('412 Precondition Failed');
    }
    if ( !$self->is_allowed($main::PATH_TRANSLATED) ) {
        carp("PUT: 423 Locked: not owner or missing lock token");
        return print_header_and_content('423 Locked','text/plain','434 Locked: not owner or missing lock token');

      #} if (defined $ENV{HTTP_EXPECT} && $ENV{HTTP_EXPECT} =~ /100-continue/) {
      #	return print_header_and_content('417 Expectation Failed');
    }
    if (   $backend->isDir( $backend->getParent( ($main::PATH_TRANSLATED) ) )
        && $self->is_insufficient_storage( $cgi, $backend ) )
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
        $self->get_lock_module()->inherit_lock();
        $self->logger("PUT($main::PATH_TRANSLATED)");
        main::broadcast(
            'PUT',
            {
                file => $main::PATH_TRANSLATED,
                size =>
                  stat2h( \$backend->stat($main::PATH_TRANSLATED) )->{size}
            }
        );
    }
    else {
        $status =
          $self->is_insufficient_storage( $cgi, $backend )
          ? '507 Insufficient Storage'
          : '403 Forbidden';
        $content = q{};
        $type    = 'text/plain';
    }
    return print_header_and_content( $status, $type, $content );
}

sub _pre_condition_failed {
    my ( $self, $cgi, $backend, $fn ) = @_;
    if ( !$backend->exists($fn) ) { $fn = $backend->getParent($fn) . q{/}; }
    my $ifheader = get_if_header_components( $cgi->http('If') );
    my $t        = 0;                                              # token found
    my $nnl  = 0;               # not no-lock found
    my $nl   = 0;               # no-lock found
    my $e    = 0;               # wrong etag found
    my $etag = get_etag($fn);
    foreach my $ie ( @{ $ifheader->{list} } ) {
        $self->debug( ' - ie{token}=' . $ie->{token} );
        if ( $ie->{token} =~ /Not\s+<DAV:no-lock>/xmsi ) {
            $nnl = 1;
        }
        elsif ( $ie->{token} =~ /<DAV:no-lock>/xmsi ) {
            $nl = 1;
        }
        elsif ( $ie->{token} =~ /opaquelocktoken/xmsi ) {
            $t = 1;
        }
        if ( defined $ie->{etag} ) {
            $e = ( $ie->{etag} ne $etag ) ? 1 : 0;
        }
    }
    $self->debug("checkPreCondition: t=$t, nnl=$nnl, e=$e, nl=$nl");
    return ( $t & $nnl & $e ) | $nl;

}

1;
