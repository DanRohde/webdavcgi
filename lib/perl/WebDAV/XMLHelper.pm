#!/usr/bin/perl
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

package WebDAV::XMLHelper;

use strict;
use warnings;

use base qw( Exporter );

our @EXPORT_OK =
  qw( create_xml get_namespace get_namespace_uri nonamespace simple_xml_parser handle_prop_element handle_propfind_element %NAMESPACES %NAMESPACEELEMENTS );

use XML::Simple;
use List::MoreUtils qw( any );

use DefaultConfig qw( $CHARSET );
use WebDAV::WebDAVProps qw( @KNOWN_COLL_PROPS @KNOWN_FILE_PROPS %KNOWN_FILECOLL_PROPS_HASH );

our $VERSION = '1.0';

use vars
  qw( %NAMESPACES %NAMESPACEABBR %NAMESPACEELEMENTS %DATATYPES %ELEMENTORDER %ELEMENTS @ALLPROP_PROPS @IGNORE_PROPS);

BEGIN {
    %NAMESPACES = (
        'DAV:'                                    => 'D',
        'http://apache.org/dav/props/'            => 'lp2',
        'urn:schemas-microsoft-com:'              => 'Z',
        'urn:schemas-microsoft-com:datatypes'     => 'M',
        'urn:schemas-microsoft-com:office:office' => 'Office',
        'http://schemas.microsoft.com/repl/'      => 'Repl',
        'urn:ietf:params:xml:ns:caldav'           => 'C',
        'http://calendarserver.org/ns/'           => 'CS',
        'http://www.apple.com/webdav_fs/props/'   => 'Apple',
        'http://www.w3.org/2000/xmlns/'           => 'x',
        'urn:ietf:params:xml:ns:carddav'          => 'A',
        'http://www.w3.org/2001/XMLSchema'        => 'xs',
        'http://groupdav.org/'                    => 'G',
    );

    %NAMESPACEABBR = (
        'D'      => 'DAV:',
        'lp2'    => 'http://apache.org/dav/props/',
        'Z'      => 'urn:schemas-microsoft-com:',
        'Office' => 'urn:schemas-microsoft-com:office:office',
        'Repl'   => 'http://schemas.microsoft.com/repl/',
        'M'      => 'urn:schemas-microsoft-com:datatypes',
        'C'      => 'urn:ietf:params:xml:ns:caldav',
        'CS'     => 'http://calendarserver.org/ns/',
        'Apple'  => 'http://www.apple.com/webdav_fs/props/',
        'A'      => 'urn:ietf:params:xml:ns:carddav',
        'xs'     => 'http://www.w3.org/2001/XMLSchema',
        'G'      => 'http://groupdav.org/',
    );

    %NAMESPACEELEMENTS = (
        'multistatus'                   => 1,
        'prop'                          => 1,
        'error'                         => 1,
        'principal-search-property-set' => 1,
    );

    %DATATYPES = (
        isfolder              => 'M:dt="boolean"',
        ishidden              => 'M:dt="boolean"',
        isstructureddocument  => 'M:dt="boolean"',
        hassubs               => 'M:dt="boolean"',
        nosubs                => 'M:dt="boolean"',
        reserved              => 'M:dt="boolean"',
        iscollection          => 'M:dt="boolean"',
        isFolder              => 'M:dt="boolean"',
        isreadonly            => 'M:dt="boolean"',
        isroot                => 'M:dt="boolean"',
        lastaccessed          => 'M:dt="dateTime"',
        Win32CreationTime     => 'M:dt="dateTime"',
        Win32LastAccessTime   => 'M:dt="dateTime"',
        Win32LastModifiedTime => 'M:dt="dateTime"',
        description           => 'xml:lang="en"',
    );

    %ELEMENTORDER = (
        multistatus           => 1,
        responsedescription   => 4,
        allprop               => 1,
        include               => 2,
        prop                  => 1,
        propstat              => 2,
        status                => 3,
        error                 => 4,
        href                  => 1,
        responsedescription   => 5,
        location              => 6,
        locktype              => 1,
        lockscope             => 2,
        depth                 => 3,
        owner                 => 4,
        timeout               => 5,
        locktoken             => 6,
        lockroot              => 7,
        getcontentlength      => 1001,
        getlastmodified       => 1002,
        resourcetype          => 0,
        getcontenttype        => 1,
        supportedlock         => 1010,
        lockdiscovery         => 1011,
        src                   => 1,
        dst                   => 2,
        principal             => 1,
        grant                 => 2,
        privilege             => 1,
        abstract              => 2,
        description           => 3,
        'supported-privilege' => 4,
        collection            => 1,
        calendar              => 2,
        'schedule-inbox'      => 3,
        'schedule-outbox'     => 4,
        'calendar-data'       => 101,
        getetag               => 100,
        properties            => 1,
        operators             => 2,
        default               => 1000,
    );

    %ELEMENTS = (
        'calendar'                         => 'C',
        'calendar-description'             => 'C',
        'calendar-timezone'                => 'C',
        'supported-calendar-component-set' => 'C',
        'supported-calendar-data'          => 'C',
        'max-resource-size'                => 'C',
        'min-date-time'                    => 'C',
        'max-date-time'                    => 'C',
        'max-instances'                    => 'C',
        'max-attendees-per-instance'       => 'C',
        'read-free-busy'                   => 'C',
        'calendar-home-set'                => 'C',
        'supported-collation-set'          => 'C',
        'schedule-tag'                     => 'C',
        'calendar-data'                    => 'C',
        'mkcalendar-response'              => 'C',
        getctag                            => 'CS',
        'calendar-user-address-set'        => 'C',
        'schedule-inbox-URL'               => 'C',
        'schedule-outbox-URL'              => 'C',
        'calendar-user-type'               => 'C',
        'schedule-calendar-transp'         => 'C',
        'schedule-default-calendar-URL'    => 'C',
        'schedule-inbox'                   => 'C',
        'schedule-outbox'                  => 'C',
        'transparent'                      => 'C',
        'calendar-multiget'                => 'C',
        'calendar-query'                   => 'C',
        'free-busy-query'                  => 'C',
        'addressbook'                      => 'A',
        'addressbook-description'          => 'A',
        'supported-address-data'           => 'A',
        'addressbook-home-set'             => 'A',
        'principal-address'                => 'A',
        'address-data'                     => 'A',
        'addressbook-query'                => 'A',
        'addressbook-multiget'             => 'A',
        'string'                           => 'xs',
        'anyURI'                           => 'xs',
        'nonNegativeInteger'               => 'xs',
        'dateTime'                         => 'xs',
        'vevent-collection'                => 'G',
        'vtodo-collection'                 => 'G',
        'vcard-collection'                 => 'G',
        'component-set'                    => 'G',
        'executable'                       => 'lp2',
        'Win32CreationTime'                => 'Z',
        'Win32LastModifiedTime'            => 'Z',
        'Win32LastAccessTime'              => 'Z',
        'authoritative-directory'          => 'Repl',
        'resourcetag'                      => 'Repl',
        'repl-uid'                         => 'Repl',
        'modifiedby'                       => 'Office',
        'specialFolderType'                => 'Office',
        'Win32CreationTime'                => 'Z',
        'Win32FileAttributes'              => 'Z',
        'Win32LastAccessTime'              => 'Z',
        'Win32LastModifiedTime'            => 'Z',
        default                            => 'D',
        'appledoubleheader'                => 'Apple',
        'directory-gateway'                => 'D',
        'calendar-free-busy-set'           => 'C',
    );

    @ALLPROP_PROPS = qw(
      creationdate       displayname
      getcontentlanguage getlastmodified
      lockdiscovery      resourcetype
      supportedlock      getetag
      getcontenttype     getcontentlength
      executable
    );

    @IGNORE_PROPS = qw( xmlns CS );

}

sub get_namespace {
    my ($el) = @_;
    return $ELEMENTS{$el} || $ELEMENTS{default};
}

sub get_namespace_uri {
    my ($prop) = @_;
    return $NAMESPACEABBR{ get_namespace($prop) };
}

sub nonamespace {
    my ($prop) = @_;
    $prop =~ s/^{[^}]*}//xms;
    return $prop;
}

sub simple_xml_parser {
    my ( $text, $keep_root ) = @_;
    my %param;
    $param{NSExpand} = 1;
    if ($keep_root) { $param{KeepRoot} = 1; }
    return XMLin( $text, %param );
}

sub _cmp_elements {
    my $aa = $ELEMENTORDER{$a} || $ELEMENTORDER{default};
    my $bb = $ELEMENTORDER{$b} || $ELEMENTORDER{default};
    return $aa <=> $bb || $a cmp $b;
}

sub _create_xml_data_hash {
    my ( $w, $d, $xmlns ) = @_;
    foreach my $e ( sort _cmp_elements keys %{$d} ) {
        my $el   = $e;
        my $euns = q{};
        my $uns;
        my $ns   = get_namespace($e);
        my $attr = q{};
        if ( defined $DATATYPES{$e} ) {
            $attr .= q{ } . $DATATYPES{$e};
            if ( $DATATYPES{$e} =~ /(\w+):dt/xms ) {
                if ( defined $NAMESPACEABBR{$1} ) { ${$xmlns}{$1} = 1; }
            }
        }
        if ( $e =~ /{([^}]*)}/xms ) {
            $ns = $1;
            if ( defined $NAMESPACES{$ns} ) {
                $el =~ s/{[^}]*}//xms;
                $ns = $NAMESPACES{$ns};
            }
            else {
                $uns  = $ns;
                $euns = $e;
                $euns =~ s/{[^}]*}//xms;
            }
        }
        my $el_end = $el;
        $el_end =~ s/[ ].*$//xms;
        my $euns_end = $euns;
        $euns_end =~ s/[ ].*$//xms;
        if ( !defined $uns ) { ${$xmlns}{$ns} = 1; }
        my $nsd = q{};
        if ( $e eq 'xmlns' ) {    # ignore namespace defs
            next;
        }

        if ( $e eq 'content' ) {    #
            ${$w} .= ${$d}{$e};
        }
        elsif ( !defined ${$d}{$e} ) {
            if ( defined $uns ) {
                ${$w} .= qq@<${euns} xmlns=\"$uns\"/>@;
            }
            else {
                ${$w} .= qq@<${ns}:${el}${nsd}${attr}/>@;
            }
        }
        elsif ( ref( ${$d}{$e} ) eq 'ARRAY' ) {
            foreach my $e1 ( @{ ${$d}{$e} } ) {
                my $tmpw = q{};
                _create_xml_data( \$tmpw, $e1, $xmlns );
                if ( $NAMESPACEELEMENTS{$el} ) {
                    foreach my $abbr ( keys %{$xmlns} ) {
                        $nsd .= qq@ xmlns:$abbr="$NAMESPACEABBR{$abbr}"@;
                        delete ${$xmlns}{$abbr};
                    }
                }
                ${$w} .= qq@<${ns}:${el}${nsd}${attr}>$tmpw</${ns}:${el_end}>@;
            }
        }
        else {
            if ( defined $uns ) {
                ${$w} .= qq@<${euns} xmlns="$uns">@;
                _create_xml_data( $w, ${$d}{$e}, $xmlns );
                ${$w} .= qq@</${euns_end}>@;
            }
            else {
                my $tmpw = q{};
                _create_xml_data( \$tmpw, ${$d}{$e}, $xmlns );
                if ( $NAMESPACEELEMENTS{$el} ) {
                    foreach my $abbr ( keys %{$xmlns} ) {
                        $nsd .= qq@ xmlns:$abbr="$NAMESPACEABBR{$abbr}"@;
                        delete ${$xmlns}{$abbr};
                    }
                }
                ${$w} .= qq@<${ns}:${el}${nsd}${attr}>$tmpw</${ns}:${el_end}>@;
            }
        }
    }
    return;
}

sub _create_xml_data {
    my ( $w, $d, $xmlns ) = @_;
    if ( ref($d) eq 'HASH' ) {
        return _create_xml_data_hash( $w, $d, $xmlns );
    }
    if ( ref($d) eq 'ARRAY' ) {
        foreach my $e ( @{$d} ) {
            _create_xml_data( $w, $e, $xmlns );
        }
        return;
    }
    if ( ref($d) eq 'SCALAR' ) {
        ${$w} .= qq@$d@;
        return;
    }
    if ( ref($d) eq 'REF' ) {
        return _create_xml_data( $w, ${$d}, $xmlns );
    }
    ${$w} .= $d // q{};
    return;
}

sub create_xml {
    my ( $data_ref, $withoutp ) = @_;
    my $data =
      !defined $withoutp
      ? q@<?xml version="1.0" encoding="@ . $CHARSET . q@"?>@
      : q{};
    _create_xml_data( \$data, $data_ref );
    return $data;
}

sub handle_prop_element {
    my ( $xmldata, $props ) = @_;
    foreach my $prop ( keys %{$xmldata} ) {
        my $nons = $prop;
        my $ns   = q{};
        if ( $nons =~ s/{([^}]*)}//xms ) {
            $ns = $1;
        }
        if ( ref( $xmldata->{$prop} ) !~ /^(?:HASH|ARRAY)$/xms )
        {    # ignore namespaces
            next;
        }

        if ( $ns eq q{} && !defined $xmldata->{$prop}{xmlns} ) {
            return 0;
        }
        elsif ( exists $KNOWN_FILECOLL_PROPS_HASH{$nons} ) {
            push @{$props}, $nons;
        }
        elsif ( $ns eq q{} ) {
            push @{$props}, '{}' . $prop;
        }
        else {
            push @{$props}, $prop;
        }
    }
    return 1;
}

sub handle_propfind_element {
    my ($xmldata) = @_;
    my @props;
    my $all;
    my $noval;
    foreach my $propfind ( keys %{$xmldata} ) {
        my $nons = $propfind;
        my $ns   = q{};
        if ( $nons =~ s/{([^}]*)}//xms ) {
            $ns = $1;
        }
        if ( ( $nons =~ /(?:allprop|propname)/xms ) && ($all) ) {
            return; # error !
        }
        if ( $nons =~ /^(allprop|propname)$/xms ) {
            $noval = $1 eq 'propname';
            $all   = 1;
            if ($noval) {
                push @props, @KNOWN_COLL_PROPS, @KNOWN_FILE_PROPS;
            }
            else {
                push @props, @ALLPROP_PROPS;
            }
            next;
        }
        if ( $nons =~ /^(?:prop|include)$/xms ) {
            if ( !handle_prop_element( $xmldata->{$propfind}, \@props ) ) {
                return; # error!
            }
            next;
        }
        if ( any { /\Q$nons\E/xms } @IGNORE_PROPS ) {
            next;
        }
        if (   defined $NAMESPACES{ $xmldata->{$propfind} }
            || defined $NAMESPACES{$ns} )
        {    # sometimes the namespace: ignore
            next;
        }
        return; # error!
    }
    return ( \@props, $all, $noval );
}

1;
