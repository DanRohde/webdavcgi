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
package Requests::ACL;

use strict;
use warnings;

our $VERSION = '2.0';

use base qw( Requests::Request );

use English qw ( -no_match_vars );

use FileUtils qw( get_error_document );
use HTTPHelper qw( read_request_body print_header_and_content );
use WebDAV::XMLHelper qw( create_xml simple_xml_parser );

sub handle {
    my ($self) = @_;

    my $backend = main::getBackend();
    my $fn      = $main::PATH_TRANSLATED;

    main::debug("_ACL($fn)");

    if ( !$backend->exists($fn) ) {
        return print_header_and_content( get_error_document('404 Not Found') );
    }
    if ( !main::isAllowed($fn) ) {
        return print_header_and_content( get_error_document('432 Locked') );
    }

    my $xml     = read_request_body();
    my $xmldata = q{};
    if ( !eval { $xmldata = simple_xml_parser( $xml, 1 ); } ) {
        main::debug("_ACL: invalid XML request: ${EVAL_ERROR}");
        return print_header_and_content(
            get_error_document('400 Bad Request') );
    }
    if ( !exists ${$xmldata}{'{DAV:}acl'} ) {
        return print_header_and_content(
            get_error_document('400 Bad Request') );
    }

    my @ace = ();
    if ( ref( ${$xmldata}{'{DAV:}acl'}{'{DAV:}ace'} ) eq 'HASH' ) {
        push @ace, ${$xmldata}{'{DAV:}acl'}{'{DAV:}ace'};
    }
    elsif ( ref( ${$xmldata}{'{DAV:}acl'}{'{DAV:}ace'} ) eq 'ARRAY' ) {
        push @ace, @{ ${$xmldata}{'{DAV:}acl'}{'{DAV:}ace'} };
    }
    else {
        return print_header_and_content('400 Bad Request');
    }
    foreach my $ace (@ace) {
        my $who = $self->_get_who($ace);
        if ( !defined $who ) {
            return print_header_and_content(
                get_error_document('400 Bad Request') );
        }
        my ( $read, $write ) = $self->_get_read_write($ace);
        if ( !defined $read || !defined $write ) {
            return print_header_and_content(
                get_error_document('400 Bad Request') );
        }
        if ( $read == 0 && $write == 0 ) {
            return print_header_and_content(
                get_error_document('400 Bad Request') );
        }

        if (
            !$backend->changeMod(
                $fn, $self->_get_new_perm( $fn, $who, $read, $write )
            )
          )
        {
            return print_header_and_content(
                get_error_document('403 Forbidden') );
        }

    }
    return print_header_and_content('200 OK');
}

sub _get_read_write {
    my ( $self, $ace ) = @_;
    my ( $read, $write ) = ( 0, 0 );
    if ( exists ${$ace}{'{DAV:}grant'} ) {
        $read =
          exists ${$ace}{'{DAV:}grant'}{'{DAV:}privilege'}{'{DAV:}read'}
          ? 1
          : 0;
        $write =
          exists ${$ace}{'{DAV:}grant'}{'{DAV:}privilege'}{'{DAV:}write'}
          ? 1
          : 0;
        return ( $read, $write );
    }
    if ( exists ${$ace}{'{DAV:}deny'} ) {
        $read =
          exists ${$ace}{'{DAV:}deny'}{'{DAV:}privilege'}{'{DAV:}read'}
          ? -1
          : 0;
        $write =
          exists ${$ace}{'{DAV:}deny'}{'{DAV:}privilege'}{'{DAV:}write'}
          ? -1
          : 0;
        return ( $read, $write );
    }
    return;
}

sub _get_who {
    my ( $self, $ace ) = @_;
    if ( defined( my $p = ${$ace}{'{DAV:}principal'} ) ) {
        if ( exists ${$p}{'{DAV:}property'}{'{DAV:}owner'} ) {
            return 0;
        }
        if ( exists ${$p}{'{DAV:}property'}{'{DAV:}group'} ) {
            return 1;
        }
        if ( exists ${$p}{'{DAV:}all'} ) {
            return 2;
        }
    }
    return;
}

sub _get_new_perm {
    my ( $self, $fn, $who, $read, $write ) = @_;
    my $mode = ( main::getBackend()->stat($fn) )[2];
    $mode = $mode & oct 7777;
    my $newperm = $mode;
    if ( $read != 0 ) {
        my $mask = $who == 0 ? oct(400) : $who == 1 ? oct(40) : oct 4;
        $newperm = ( $read > 0 ) ? $newperm | $mask : $newperm & ~$mask;
    }
    if ( $write != 0 ) {
        my $mask = $who == 0 ? oct(200) : $who == 1 ? oct(20) : oct 2;
        $newperm = ( $write > 0 ) ? $newperm | $mask : $newperm & ~$mask;
    }
    main::debug(
        '_ACL: old perm='
          . sprintf( '%4o', $mode )
          . ', new perm='
          . sprintf '%4o',
        $newperm
    );
    return $newperm;
}
1;
