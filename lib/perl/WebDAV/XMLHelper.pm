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

use XML::Simple;

our $VERSION = '1.0';

use vars
    qw( $_INSTANCE %NAMESPACES %NAMESPACEABBR %NAMESPACEELEMENTS %DATATYPES %ELEMENTORDER %ELEMENTS );

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

}

sub new {
    my $this  = shift;
    my $class = ref($this) || $this;
    my $self  = {};
    if ( !$_INSTANCE ) {
        bless $self, $class;
        $_INSTANCE = $self;
    }
    return $_INSTANCE;
}

sub getinstance {
    return __PACKAGE__->new();
}

sub get_namespace {
    my ( $self, $el ) = @_;
    return $ELEMENTS{$el} || $ELEMENTS{default};
}

sub get_namespace_uri {
    my ( $self, $prop ) = @_;
    return $NAMESPACEABBR{ $self->get_namespace($prop) };
}

sub nonamespace {
    my ( $self, $prop ) = @_;
    $prop =~ s/^{[^}]*}//xms;
    return $prop;
}

sub simple_xml_parser {
    my ( $self, $text, $keep_root ) = @_;
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
    my ( $self, $w, $d, $xmlns ) = @_;
    foreach my $e ( sort _cmp_elements keys %{$d} ) {
        my $el   = $e;
        my $euns = q{};
        my $uns;
        my $ns   = $self->get_namespace($e);
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
                $self->_create_xml_data( \$tmpw, $e1, $xmlns );
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
                $self->_create_xml_data( $w, ${$d}{$e}, $xmlns );
                ${$w} .= qq@</${euns_end}>@;
            }
            else {
                my $tmpw = q{};
                $self->_create_xml_data( \$tmpw, ${$d}{$e}, $xmlns );
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
    my ( $self, $w, $d, $xmlns ) = @_;
    if ( ref($d) eq 'HASH' ) {
        $self->_create_xml_data_hash( $w, $d, $xmlns);
    }
    elsif ( ref($d) eq 'ARRAY' ) {
        foreach my $e ( @{$d} ) {
            $self->_create_xml_data( $w, $e, $xmlns );
        }
    }
    elsif ( ref($d) eq 'SCALAR' ) {
        ${$w} .= qq@$d@;
    }
    elsif ( ref($d) eq 'REF' ) {
        $self->_create_xml_data( $w, ${$d}, $xmlns );
    }
    else {
        ${$w} .= $d // q{};
    }
    return;
}

sub create_xml {
    my ( $self, $data_ref, $withoutp ) = @_;
    my $data
        = !defined $withoutp
        ? q@<?xml version="1.0" encoding="@ . $main::CHARSET . q@"?>@
        : q{};
    $self->_create_xml_data( \$data, $data_ref );
    return $data;
}

1;
