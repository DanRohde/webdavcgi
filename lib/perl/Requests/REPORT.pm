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
package Requests::REPORT;

use strict;
use warnings;

our $VERSION = '2.0';

use base qw( Requests::WebDAVRequest );

use English qw ( -no_match_vars );

use FileUtils qw( read_dir_by_suffix );
use HTTPHelper qw( read_request_body print_header_and_content );
use WebDAV::XMLHelper qw( create_xml simple_xml_parser handle_prop_element );

sub handle {
    my ($self) = @_;

    my $cgi     = $self->{cgi};
    my $backend = $self->{backend};
    my $fn      = $main::PATH_TRANSLATED;
    my $ru      = $main::REQUEST_URI;
    my $depth   = $cgi->http('Depth') // 0;
    if ( $depth =~ /infinity/xmsi ) { $depth = -1; }

    $self->debug("_REPORT($fn,$ru)");

    if (  !$backend->exists($fn)
        && $ru !~
/^(?:\Q$main::CURRENT_USER_PRINCIPAL\E|\Q$main::PRINCIPAL_COLLECTION_SET\E)/xms
      )
    {
        return print_header_and_content('404 Not Found');
    }

    my $xml     = read_request_body();
    my $xmldata = q{};

    if ( !eval { $xmldata = simple_xml_parser( $xml, 1 ); } ) {
        $self->debug("_REPORT: invalid XML request: ${EVAL_ERROR}");
        $self->debug("_REPORT: xml-request=$xml");
        return print_header_and_content('400 Bad Request');
    }

    if ( defined ${$xmldata}{'{DAV:}acl-principal-prop-set'} ) {
        return $self->_handle_acl_principal_prop_set( $fn, $ru, $xmldata );
    }
    if ( defined ${$xmldata}{'{DAV:}principal-match'} ) {
        return $self->_handle_principal_match( $fn, $ru, $xmldata, $depth );
    }
    if ( defined ${$xmldata}{'{DAV:}principal-property-search'} ) {
        return $self->_handle_principal_property_search( $fn, $ru, $xmldata,
            $depth );
    }
    if ( defined ${$xmldata}{'{DAV:}principal-search-property-set'} ) {
        return $self->_handle_principal_search_property_set();
    }
    if ( defined ${$xmldata}{'{urn:ietf:params:xml:ns:caldav}free-busy-query'} )
    {
        return $self->_handle_free_busy_query();
    }
    if ( defined ${$xmldata}{'{urn:ietf:params:xml:ns:caldav}calendar-query'} )
    {
        return $self->_handle_calendar_query( $fn, $ru, $xmldata, $depth );
    }
    if (
        defined ${$xmldata}{'{urn:ietf:params:xml:ns:caldav}calendar-multiget'}
      )
    {
        return $self->_handle_calendar_multiget($xmldata);
    }
    if (
        defined ${$xmldata}{'{urn:ietf:params:xml:ns:carddav}addressbook-query'}
      )
    {
        return $self->_handle_addressbook_query( $fn, $ru, $xmldata, $depth );
    }
    if (
        defined ${$xmldata}
        {'{urn:ietf:params:xml:ns:carddav}addressbook-multiget'} )
    {
        return $self->_handle_addressbook_multiget($xmldata);
    }

    return print_header_and_content('400 Bad Request');
}

sub _print_response_from_hrefs {
    my ( $self, $xmldata, $rn, $hrefsref ) = @_;
    my $backend = $self->{backend};
    my @resps   = ();
    foreach my $href ( @{$hrefsref} ) {
        my ( %resp_200, %resp_404 );
        $resp_200{status} = 'HTTP/1.1 200 OK';
        $resp_404{status} = 'HTTP/1.1 404 Not Found';
        my $nhref = $href;
        $nhref =~ s/^$main::VIRTUAL_BASE//xms;
        my $nfn = $main::DOCUMENT_ROOT . $nhref;
        $self->debug("_REPORT: nfn=$nfn, href=$href");
        if ( !$backend->exists($nfn) ) {
            push @resps, { href => $href, status => 'HTTP/1.1 404 Not Found' };
            next;
        }
        elsif ( $backend->isDir($nfn) ) {
            push @resps, { href => $href, status => 'HTTP/1.1 403 Forbidden' };
            next;
        }
        my @props;
        if ( exists ${$xmldata}{$rn}{'{DAV:}prop'}
            && !handle_prop_element( ${$xmldata}{$rn}{'{DAV:}prop'}, \@props ) )
        {
            return print_header_and_content('400 Bad Request');
        }

        push @resps,
          {
            href     => $href,
            propstat => $self->get_prop_stat( $nfn, $nhref, \@props )
          };
    }
    ### push @resps, { } if ($#hrefs==-1);  ## empty multistatus response not supported
    return $self->_print_response( \@resps );
}

sub _print_response {
    my ( $self, $respsref ) = @_;
    my $content;
    if ( !defined $respsref || ref($respsref) ne 'ARRAY' || $#{$respsref} < 0 )
    {
        $content =
q{<?xml version="1.0" encoding="UTF-8"?><D:multistatus xmlns:D="DAV:"></D:multistatus>};
    }
    else {
        $content = create_xml( { multistatus => { response => $respsref } } );
    }
    $self->debug("_REPORT: RESPONSE: $content");
    return print_header_and_content( '207 Multi-Status',
        'application/xml', $content );
}

sub _handle_principal_match {
    my ( $self, $fn, $ru, $xmldata, $depth ) = @_;
    my @resps = ();
    if ( $depth != 0 ) {
        return print_header_and_content('400 Bad Request');
    }

    # response, href
    my @props;
    if (
        exists ${$xmldata}{'{DAV:}principal-match'}{'{DAV:}prop'}
        && !handle_prop_element(
            ${$xmldata}{'{DAV:}principal-match'}{'{DAV:}prop'}, \@props
        )
      )
    {
        return print_header_and_content('400 Bad Request');
    }
    $self->read_dir_recursive( $fn, $ru, \@resps, \@props, 0, 0, 1, 1 );
    return $self->_print_response( \@resps );
}

sub _handle_acl_principal_prop_set {
    my ( $self, $fn, $ru, $xmldata ) = @_;
    my @resps = ();
    my @props;
    if (
        !handle_prop_element(
            ${$xmldata}{'{DAV:}acl-principal-prop-set'}{'{DAV:}prop'}, \@props
        )
      )
    {
        return print_header_and_content('400 Bad Request');
    }
    push @resps,
      {
        href     => $ru,
        propstat => $self->get_prop_stat( $fn, $ru, \@props )
      };
    return $self->_print_response( \@resps );
}

sub _handle_principal_property_search {
    my ( $self, $fn, $ru, $xmldata, $depth ) = @_;
    if ( $depth != 0 ) {
        return print_header_and_content('400 Bad Request');
    }
    my @resps = ();
    my @props;
    if (
        exists ${$xmldata}{'{DAV:}principal-property-search'}{'{DAV:}prop'}
        && !handle_prop_element(
            ${$xmldata}{'{DAV:}principal-property-search'}{'{DAV:}prop'},
            \@props
        )
      )
    {
        return print_header_and_content('400 Bad Request');
    }
    $self->read_dir_recursive( $fn, $ru, \@resps, \@props, 0, 0, 1, 1 );
    ### TODO: filter data
    my @propertysearch;
    if (
        ref(
            ${$xmldata}{'{DAV:}principal-property-search'}
              {'{DAV:}property-search'}
        ) eq 'HASH'
      )
    {
        push @propertysearch,
          ${$xmldata}{'{DAV:}principal-property-search'}
          {'{DAV:}property-search'};
    }
    elsif (
        ref(
            ${$xmldata}{'{DAV:}principal-property-search'}
              {'{DAV:}property-search'}
        ) eq 'ARRAY'
      )
    {
        push @propertysearch,
          @{ ${$xmldata}{'{DAV:}principal-property-search'}
              {'{DAV:}property-search'} };
    }
    return $self->_print_response( \@resps );
}

sub _handle_principal_search_property_set {
    my ($self) = @_;
    my %resp;
    $resp{'principal-search-property-set'} = {
        'principal-search-property' => [
            {
                prop        => { displayname => undef },
                description => 'Full name'
            },
        ]
    };
    return print_header_and_content( '200 OK', 'text/xml',
        create_xml( \%resp ) );
}

sub _handle_free_busy_query {
    return print_header_and_content(
        '200 OK',
        'text/calendar',
"BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//Example Corp.//CalDAV Server//EN\r\nBEGIN:VFREEBUSY\r\nEND:VFREEBUSY\r\nEND:VCALENDAR"
    );
}

sub _handle_calendar_query {    ## missing filter
    my ( $self, $fn, $ru, $xmldata, $depth ) = @_;
    my @hrefs = ();
    read_dir_by_suffix( $fn, $ru, \@hrefs, 'ics', $depth );
    return $self->_print_response_from_hrefs( $xmldata,
        '{urn:ietf:params:xml:ns:caldav}calendar-query', \@hrefs );
}

sub _handle_calendar_multiget {    ## OK - complete
    my ( $self, $xmldata ) = @_;
    my @hrefs;
    my $rn = '{urn:ietf:params:xml:ns:caldav}calendar-multiget';
    if (   !defined ${$xmldata}{$rn}{'{DAV:}href'}
        || !defined ${$xmldata}{$rn}{'{DAV:}prop'} )
    {
        return print_header_and_content('400 Bad Request');
    }
    if ( ref( ${$xmldata}{$rn}{'{DAV:}href'} ) eq 'ARRAY' ) {
        @hrefs = @{ ${$xmldata}{$rn}{'{DAV:}href'} };
    }
    elsif ( ref( ${$xmldata}{$rn}{'{DAV:}href'} ) eq 'HASH' ) {
        @hrefs =
          grep { !/DAV:/xms } values %{ ${$xmldata}{$rn}{'{DAV:}href'} };
    }
    else {
        push @hrefs, ${$xmldata}{$rn}{'{DAV:}href'};
    }
    return $self->_print_response_from_hrefs( $xmldata, $rn, \@hrefs );
}

sub _handle_addressbook_query {
    my ( $self, $fn, $ru, $xmldata, $depth ) = @_;
    my @hrefs = ();
    read_dir_by_suffix( $fn, $ru, \@hrefs, 'vcf', $depth );
    return $self->_print_response_from_hrefs( $xmldata,
        '{urn:ietf:params:xml:ns:carddav}addressbook-query', \@hrefs );
}

sub _handle_addressbook_multiget {
    my ( $self, $xmldata ) = @_;
    my @hrefs;
    my $rn = '{urn:ietf:params:xml:ns:carddav}addressbook-multiget';

    if (   !defined ${$xmldata}{$rn}{'{DAV:}href'}
        || !defined ${$xmldata}{$rn}{'{DAV:}prop'} )
    {
        return print_header_and_content('400 Bad Request');
    }
    if ( ref( ${$xmldata}{$rn}{'{DAV:}href'} ) eq 'ARRAY' ) {
        @hrefs = @{ ${$xmldata}{$rn}{'{DAV:}href'} };
    }
    elsif ( ref( ${$xmldata}{$rn}{'{DAV:}href'} ) eq 'HASH' ) {
        @hrefs = grep { !/DAV:/xms } values %{ ${$xmldata}{$rn}{'{DAV:}href'} };
    }
    else {
        push @hrefs, ${$xmldata}{$rn}{'{DAV:}href'};
    }
    return $self->_print_response_from_hrefs( $xmldata, $rn, \@hrefs );
}

1;
