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

package WebDAV::Properties;

use strict;
use warnings;

our $VERSION = '2.0';

use base 'WebDAV::Common';

use POSIX qw(strftime);
use Date::Parse;
use List::MoreUtils qw(any);
use English qw ( -no_match_vars );
use CGI;
use CGI::Carp;

use FileUtils qw( get_dir_info );
use HTTPHelper qw( get_etag get_supported_methods );
use WebDAV::XMLHelper qw( create_xml %NAMESPACES );
use WebDAV::WebDAVProps qw( @PROTECTED_PROPS );

sub remove_property {
    my ( $self, $propname, $element_parent_ref, $resp_200, $resp_403 ) = @_;
    ${$self}{db}->db_removeProperty( $self->resolve($main::PATH_TRANSLATED),
        $propname );
    ${$resp_200}{href}                      = $main::REQUEST_URI;
    ${$resp_200}{propstat}{status}          = 'HTTP/1.1 200 OK';
    ${$resp_200}{propstat}{prop}{$propname} = undef;
    return 1;
}

sub _set_exec_mode {
    my ( $self, $fn, %params ) = @_;
    my $resp_200           = $params{resp_200};
    my $propname           = $params{propname};
    my $ru                 = $params{ru};
    my $element_parent_ref = $params{element_parent_ref};
    my $executable         = ${$element_parent_ref}{$propname}{'content'};
    if ( defined $executable ) {
        my ($dev,   $ino,     $mode, $nlink, $uid,
            $gid,   $rdev,    $size, $atime, $mtime,
            $ctime, $blksize, $blocks
        ) = ${$self}{backend}->stat($fn);
        if (!chmod $executable =~ /F/xms
            ? $mode & oct(666)
            : $mode | oct(111),
            $fn
            )
        {
            croak("Chmod($mode,$fn) failed.");
        }
        ${$resp_200}{href}                       = $ru;
        ${$resp_200}{propstat}{prop}{executable} = $executable;
        ${$resp_200}{propstat}{status}           = 'HTTP/1.1 200 OK';
    }
    return;
}

sub _set_lastmodified {
    my ( $self, $fn, %params ) = @_;
    my $resp_200           = $params{resp_200};
    my $element_parent_ref = $params{element_parent_ref};
    my $ru                 = $params{ru};

    my $getlastmodified = ${$element_parent_ref}{'{DAV:}getlastmodified'}
        // ${$element_parent_ref}
        {'{urn:schemas-microsoft-com:}Win32LastModifiedTime'};
    my $lastaccesstime = ${$element_parent_ref}
        {'{urn:schemas-microsoft-com:}Win32LastAccessTime'};
    if ( defined $getlastmodified ) {
        my $mtime = str2time($getlastmodified);
        my $atime
            = defined $lastaccesstime
            ? str2time($lastaccesstime)
            : $mtime;
        utime $atime, $mtime, $fn
            or croak("Cannot set utime($atime,$mtime,$fn).");
        ${$resp_200}{href} = $ru;
        if ( defined ${$element_parent_ref}{'{DAV:}getlastmodified'} ) {
            ${$resp_200}{propstat}{prop}{getlastmodified} = $getlastmodified;
        }
        if ( ${$element_parent_ref}
            {'{urn:schemas-microsoft-com:}Win32LastModifiedTime'} )
        {
            ${$resp_200}{propstat}{prop}{Win32LastModifiedTime}
                = $getlastmodified;
        }
        if ( ${$element_parent_ref}
            {'{urn:schemas-microsoft-com:}Win32LastAccessTime'} )
        {
            ${$resp_200}{propstat}{prop}{Win32LastAccessTime}
                = $lastaccesstime;
        }
        if (defined ${$element_parent_ref}
            {'{urn:schemas-microsoft-com:}Win32CreationTime'} )
        {
            ${$resp_200}{propstat}{prop}{Win32CreationTime}
                = ${$element_parent_ref}
                {'{urn:schemas-microsoft-com:}Win32CreationTime'};
        }
        ${$resp_200}{propstat}{status} = 'HTTP/1.1 200 OK';
    }
    return;
}

sub set_property {
    my ( $self, $propname, $element_parent_ref, $resp_200, $resp_403 ) = @_;
    my $fn  = $main::PATH_TRANSLATED;
    my $rfn = $self->resolve($fn);
    my $ru  = $main::REQUEST_URI;
    my ( $ns, $pn );
    if ( $propname =~ /^{([^}]+)}(.*)$/xms ) {
        ( $ns, $pn ) = ( $1, $2 );
    }

    if ( $propname eq '{http://apache.org/dav/props/}executable' ) {
        return $self->_set_exec_mode(
            $fn,
            (   resp_200           => $resp_200,
                propname           => $propname,
                ru                 => $ru,
                element_parent_ref => $element_parent_ref,
            )
        );
    }
    if ( ( $propname eq '{DAV:}getlastmodified' )
        || ($propname eq '{urn:schemas-microsoft-com:}Win32LastModifiedTime' )
        || ( $propname eq '{urn:schemas-microsoft-com:}Win32LastAccessTime' )
        || ( $propname eq '{urn:schemas-microsoft-com:}Win32CreationTime' ) )
    {
        return $self->_set_lastmodified(
            $fn,
            (   resp_200           => $resp_200,
                ru                 => $ru,
                element_parent_ref => $element_parent_ref,
            )
        );
    }
    if ( $propname eq '{urn:schemas-microsoft-com:}Win32FileAttributes' ) {
        ${$resp_200}{href}                                = $ru;
        ${$resp_200}{propstat}{prop}{Win32FileAttributes} = undef;
        ${$resp_200}{propstat}{status}                    = 'HTTP/1.1 200 OK';
    }
    elsif ( defined $NAMESPACES{ $ns // q{} }
        && any {/^\Q$pn\E$/xms} @PROTECTED_PROPS )
    {
        ${$resp_403}{href}                      = $ru;
        ${$resp_403}{propstat}{prop}{$propname} = undef;
        ${$resp_403}{propstat}{status}          = 'HTTP/1.1 403 Forbidden';
    }
    else {
        my $n      = $propname;
        my $parref = ${$element_parent_ref}{$propname};
        if (   $parref
            && ref($parref) eq 'HASH'
            && ( !${$parref}{xmlns} || ${$parref}{xmlns} eq q{} )
            && $n !~ /^{[^}]*}/xms )
        {
            $n = '{}' . $n;
        }

        my $dbval = ${$self}{db}->db_getProperty( $rfn, $n );
        my $value = create_xml( ${$element_parent_ref}{$propname}, 0 );
        my $ret
            = defined $dbval
            ? ${$self}{db}->db_updateProperty( $rfn, $n, $value )
            : ${$self}{db}->db_insertProperty( $rfn, $n, $value );
        if ($ret) {
            ${$resp_200}{href}                      = $ru;
            ${$resp_200}{propstat}{prop}{$propname} = undef;
            ${$resp_200}{propstat}{status}          = 'HTTP/1.1 200 OK';
        }
        else {
            carp("Cannot set property '$propname'");
            ${$resp_403}{href} = $ru;
            ${$resp_403}{propstat}{prop}{$propname} = undef;
            ${$resp_403}{propstat}{status} = 'HTTP/1.1 403 Forbidden';

        }
    }
    return;
}

sub get_property {
    my ( $self, $fn, $uri, $prop, @refs ) = @_;
    my ( $statref, $resp_200, $resp_404 ) = @refs;

    my $is_readable = ${$self}{backend}->isReadable($fn);
    my $is_dir      = ${$self}{backend}->isDir($fn);

    my ($dev,  $ino,   $mode,  $nlink, $uid,     $gid, $rdev,
        $size, $atime, $mtime, $ctime, $blksize, $blocks
        )
        = defined $statref
        ? @{$statref}
        : ( $is_readable ? ${$self}{backend}->stat($fn) : () );

    my %params = (
        resp_200    => $resp_200,
        resp_404    => $resp_404,
        fn          => $fn,
        uri         => $uri,
        is_dir      => $is_dir,
        size        => $size,
        mode        => $mode,
        ctime       => $ctime,
        atime       => $atime,
        mtime       => $mtime,
        is_readable => $is_readable,
        prop        => $prop,
    );

           $self->_get_webdav_props( $prop, %params )
        || $self->_get_lock_props( $prop, %params )
        || $self->_get_os_props( $prop, %params )
        || $self->_get_re_props( $prop, %params )
        || $self->_get_quota_props( $prop, %params )
        || $self->_get_coll_props( $prop, %params )
        || $self->_get_acl_caldav_cardav_props( $prop, %params )
        || $self->_get_groupdav_props( $prop, %params )
        || $self->_get_cup_props( $prop, %params )
        || $self->_get_deltav_props( $prop, %params )
        || $self->_get_bind_props( $prop, %params );

    return 1;
}

sub _get_acl_caldav_cardav_props {
    my ( $self, $prop, %params ) = @_;
    if (   $main::ENABLE_ACL
        || $main::ENABLE_CALDAV
        || $main::ENABLE_CALDAV_SCHEDULE
        || $main::ENABLE_CARDDAV )
    {
        if ( $self->_get_acl_props( $prop, %params ) ) {
            return 1;
        }
        if ( $main::ENABLE_CALDAV || $main::ENABLE_CALDAV_SCHEDULE ) {
            if ( $self->_get_caldav_props( $prop, %params ) ) {
                return 1;
            }
            if (   $main::ENABLE_CALDAV_SCHEDULE
                && $self->_get_caldavschedule_props( $prop, %params ) )
            {
                return 1;
            }
        }
        if (   $main::ENABLE_CARDDAV
            && $self->_get_carddav_props( $prop, %params ) )
        {
            return 1;
        }

    }
    return 0;
}

sub _get_cup_props {
    my ( $self, $prop, %params ) = @_;
    my $resp_200 = $params{resp_200};
    if ( $prop eq 'current-user-principal' ) {
        ${$resp_200}{prop}{$prop}{href}
            = $main::CURRENT_USER_PRINCIPAL;
        return 1;
    }
    return 0;
}

sub _get_coll_props {
    my ( $self, $prop, %params ) = @_;
    my $resp_200 = $params{resp_200};
    my $fn       = $params{fn};
    my $uri      = $params{uri};
    my $is_dir   = $params{is_dir};

    if ( $prop eq 'childcount' ) {
        ${$resp_200}{prop}{$prop} = (
            $is_dir
            ? get_dir_info(
                $fn,                      $prop,
                \%main::FILEFILTERPERDIR, \%main::FILECOUNTPERDIRLIMIT,
                $main::FILECOUNTLIMIT
                )
            : 0
        );
        return 1;
    }
    if ( $prop eq 'id' ) { return ${$resp_200}{prop}{$prop} = $uri; }
    if ( $prop eq 'objectcount' ) {
        ${$resp_200}{prop}{$prop} = (
            $is_dir
            ? get_dir_info(
                $fn,                      $prop,
                \%main::FILEFILTERPERDIR, \%main::FILECOUNTPERDIRLIMIT,
                $main::FILECOUNTLIMIT
                )
            : 0
        );
        return 1;
    }
    if ( $prop eq 'reserved' ) {
        ${$resp_200}{prop}{$prop} = 0;
        return 1;
    }
    if ( $prop eq 'visiblecount' ) {

        ${$resp_200}{prop}{$prop} = (
            $is_dir
            ? get_dir_info(
                $fn,                      $prop,
                \%main::FILEFILTERPERDIR, \%main::FILECOUNTPERDIRLIMIT,
                $main::FILECOUNTLIMIT
                )
            : 0
        );
        return 1;
    }
    return 0;
}

sub _get_re_props {
    my ( $self, $prop, %params ) = @_;
    my $resp_200    = $params{resp_200};
    my $fn          = $params{fn};
    my $uri         = $params{uri};
    my $is_dir      = $params{is_dir};
    my $is_readable = $params{is_readable};
    my $atime       = $params{atime};
    if ( $prop eq 'executable' ) {
        return ${$resp_200}{prop}{$prop}
            = ( $is_readable && ${$self}{backend}->isExecutable($fn) )
            ? 'T'
            : 'F';
    }
    if ( $prop eq 'name' ) {
        return ${$resp_200}{prop}{$prop}
            = ${$self}{cgi}->escape( ${$self}{backend}->basename($fn) );
    }
    if ( $prop eq 'href' ) { return ${$resp_200}{prop}{$prop} = $uri; }
    if ( $prop eq 'parentname' ) {
        return ${$resp_200}{prop}{$prop} = ${$self}{cgi}
            ->escape( main::getBaseURIFrag( main::getParentURI($uri) ) );
    }
    if ( $prop eq 'isreadonly' ) {
        ${$resp_200}{prop}{$prop}
            = ( !${$self}{backend}->isWriteable($fn) ? 1 : 0 );
        return 1;
    }
    if ( $prop eq 'isroot' ) {
        ${$resp_200}{prop}{$prop} = ( $fn eq $main::DOCUMENT_ROOT ? 1 : 0 );
        return 1;
    }
    if ( $prop =~ /^(?:getcontentclass|contentclass)$/xms ) {
        return ${$resp_200}{prop}{$prop} = (
            $is_dir
            ? 'urn:content-classes:folder'
            : 'urn:content-classes:document'
        );
    }
    if ( $prop eq 'lastaccessed' ) {
        return ${$resp_200}{prop}{$prop}
            = strftime( '%m/%d/%Y %I:%M:%S %p', gmtime $atime );
    }
    return 0;
}

sub _get_webdav_props {
    my ( $self, $prop, %params ) = @_;
    my $resp_200 = $params{resp_200};
    my $fn       = $params{fn};
    my $uri      = $params{uri};
    my $is_dir   = $params{is_dir};
    my $size     = $params{size};
    my $ctime    = $params{ctime};
    my $mtime    = $params{mtime};

    if ( $prop eq 'creationdate' ) {
        return ${$resp_200}{prop}{$prop}
            = strftime( '%Y-%m-%dT%H:%M:%SZ', gmtime $ctime );
    }
    if ( $prop eq 'displayname' && !defined ${$resp_200}{prop}{displayname} )
    {
        return ${$resp_200}{prop}{$prop}
            = ${$self}{cgi}->escape( main::getBaseURIFrag($uri) );
    }
    if ( $prop eq 'getcontentlanguage' ) {
        return ${$resp_200}{prop}{$prop} = 'en';
    }
    if ( $prop eq 'getcontentlength' ) {
        ${$resp_200}{prop}{$prop} = $size;
        return 0;
    }
    if ( $prop eq 'getcontenttype' ) {
        return ${$resp_200}{prop}{$prop}
            = ( $is_dir ? 'httpd/unix-directory' : main::get_mime_type($fn) );
    }
    if ( $prop eq 'getetag' ) {
        return ${$resp_200}{prop}{$prop} = get_etag($fn);
    }
    if ( $prop eq 'getlastmodified' ) {
        return ${$resp_200}{prop}{$prop}
            = strftime( '%a, %d %b %Y %T GMT', gmtime $mtime );
    }
    if ( $prop eq 'resourcetype' ) {
        ${$resp_200}{prop}{$prop}
            = ( $is_dir ? { collection => undef } : undef );
        return 1;
    }
    if ( $prop eq 'source' ) {
        return ${$resp_200}{prop}{$prop}
            = { 'link' => { 'src' => $uri, 'dst' => $uri } };
    }
    return 0;
}

sub _get_bind_props {
    my ( $self, $prop, %params ) = @_;
    my $resp_200 = $params{resp_200};
    my $fn       = $params{fn};
    if ( $prop eq 'resource-id' ) {
        my $e = get_etag( ${$self}{backend}->resolve($fn) );
        $e =~ s/"//xmsg;
        return ${$resp_200}{prop}{$prop} = 'urn:uuid:' . $e;
    }
    return 0;
}

sub _get_deltav_props {
    my ( $self, $prop, %params ) = @_;
    my $resp_200 = $params{resp_200};
    my $fn       = $params{fn};

    if ( $prop eq 'supported-report-set' ) {
        return ${$resp_200}{prop}{$prop} = {
            'supported-report' => [
                { report => { 'acl-principal-prop-set'    => undef } },
                { report => { 'principal-match'           => undef } },
                { report => { 'principal-property-search' => undef } },
                { report => { 'calendar-multiget'         => undef } },
                { report => { 'calendar-query'            => undef } },
                { report => { 'free-busy-query'           => undef } },
                { report => { 'addressbook-query'         => undef } },
                { report => { 'addressbook-multiget'      => undef } },
                ## { report=>{ 'expand-property'=>undef} },
            ]
        };
    }
    if ( $prop eq 'supported-method-set' ) {
        ${$resp_200}{prop}{$prop} = q{};
        foreach my $method ( @{ get_supported_methods($self->{config}->{backend}, $fn) } ) {
            ${$resp_200}{prop}{$prop}
                .= q{<D:supported-method name="} . $method . q{"/>};
        }
        return 1;
    }

    return 0;
}

sub _get_osflag_props {
    my ( $self, $prop, %params ) = @_;
    my $resp_200 = $params{resp_200};
    my $fn       = $params{fn};
    my $is_dir   = $params{is_dir};
    if ( $prop eq 'isfolder' ) {
        ${$resp_200}{prop}{$prop} = ( $is_dir ? 1 : 0 );
        return 1;
    }
    if ( $prop eq 'ishidden' ) {
        ${$resp_200}{prop}{$prop}
            = ( ${$self}{backend}->basename($fn) =~ /^[.]/xms ? 1 : 0 );
        return 1;
    }
    if ( $prop eq 'isstructureddocument' ) {
        ${$resp_200}{prop}{$prop} = 0;
        return 1;
    }
    if ( $prop eq 'hassubs' ) {
        ${$resp_200}{prop}{$prop} = (
            $is_dir
            ? get_dir_info(
                $fn,                      $prop,
                \%main::FILEFILTERPERDIR, \%main::FILECOUNTPERDIRLIMIT,
                $main::FILECOUNTLIMIT
                )
            : 0
        );
        return 1;
    }
    if ( $prop eq 'nosubs' ) {
        ${$resp_200}{prop}{$prop} = (
            $is_dir ? ( ${$self}{backend}->isWriteable($fn) ? 1 : 0 ) : 1 );
        return 1;
    }
    if ( $prop eq 'iscollection' ) {
        ${$resp_200}{prop}{$prop} = ( $is_dir ? 1 : 0 );
        return 1;
    }
    if ( $prop eq 'isFolder' ) {
        ${$resp_200}{prop}{$prop} = ( $is_dir ? 1 : 0 );
        return 1;
    }
    return 0;
}

sub _get_os_props {
    my ( $self, $prop, %params ) = @_;
    my $resp_200 = $params{resp_200};
    my $fn       = $params{fn};
    my $is_dir   = $params{is_dir};
    my $atime    = $params{atime};
    my $ctime    = $params{ctime};
    my $mtime    = $params{mtime};

    if ( $self->_get_osflag_props( $prop, %params ) ) {
        return 1;
    }

    if ( $prop eq 'Win32CreationTime' ) {
        return ${$resp_200}{prop}{$prop}
            = strftime( '%a, %d %b %Y %T GMT', gmtime $ctime );

    }
    if ( $prop eq 'Win32FileAttributes' ) {
        my $fileattr = 128 + 32
            ; # 128 - Normal, 32 - Archive, 4 - System, 2 - Hidden, 1 - Read-Only
        $fileattr += !${$self}{backend}->isWriteable($fn)          ? 1 : 0;
        $fileattr += ${$self}{backend}->basename($fn) =~ /^[.]/xms ? 2 : 0;
        return ${$resp_200}{prop}{$prop} = sprintf '%08x', $fileattr;
    }
    if ( $prop eq 'Win32LastAccessTime' ) {
        return ${$resp_200}{prop}{$prop}
            = strftime( '%a, %d %b %Y %T GMT', gmtime $atime );
    }
    if ( $prop eq 'Win32LastModifiedTime' ) {
        return ${$resp_200}{prop}{$prop}
            = strftime( '%a, %d %b %Y %T GMT', gmtime $mtime );

    }
    if ( $prop eq 'authoritative-directory' ) {
        return ${$resp_200}{prop}{$prop} = ( $is_dir ? 't' : 'f' );
    }
    if ( $prop eq 'resourcetag' ) {
        return ${$resp_200}{prop}{$prop} = $main::REQUEST_URI;
    }
    if ( $prop eq 'repl-uid' ) {
        return ${$resp_200}{prop}{$prop}
            = main::getLockModule()->getuuid($fn);
    }
    if ( $prop eq 'modifiedby' ) {
        return ${$resp_200}{prop}{$prop} = $main::REMOTE_USER;
    }

## appledoubleheader: Magic(4) Version(4) Filler(16) EntryCout(2)  EntryDescriptor(id:4(2:resource fork),offset:4,length:4) EntryDescriptor(id:9 finder)... Finder Info(16+16)
## namespace: http://www.apple.com/webdav_fs/props/
## content: MIME::Base64(pack('H*', '00051607'. '00020000' . ( '00' x 16 ) . '0002'. '00000002'. '00000026' . '0000002C'.'00000009'. '00000032' . '00000020' . ('00' x 32) ))
    if ( $prop eq 'appledoubleheader' ) {
        return ${$resp_200}{prop}
            {'{http://www.apple.com/webdav_fs/props/}appledoubleheader'}
            = 'AAUWBwACAAAAAAAAAAAAAAAAAAAAAAAAAAIAAAACAAAAJgAAACwAAAAJAAAAMgAAACAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA==';
    }
    return 0;
}

sub _get_lock_props {
    my ( $self, $prop, %params ) = @_;
    if ( !$main::ENABLE_LOCK ) {
        return 0;
    }
    my $resp_200 = $params{resp_200};
    my $fn       = $params{fn};
    if ( $prop eq 'supportedlock' ) {
        return ${$resp_200}{prop}{$prop} = {
            lockentry => [
                {   lockscope => { exclusive => undef },
                    locktype  => { q{write}  => undef },
                },
                {   lockscope => { shared   => undef },
                    locktype  => { q{write} => undef },
                },
            ],
        };
    }
    if ( $prop eq 'lockdiscovery' ) {
        return ${$resp_200}{prop}{$prop}
            = main::getLockModule()->get_lock_discovery($fn);
    }
    return 0;
}

sub _get_quota_props {
    my ( $self, $prop, %params ) = @_;
    my $resp_200 = $params{resp_200};
    my $resp_404 = $params{resp_404};
    my $fn       = $params{fn};
    if ( $prop =~
        /^(?:quota-available-bytes|quota-used-bytes|quota|quotaused)$/xms )
    {
        my ( $ql, $qu ) = ${$self}{backend}->getQuota($fn);
        if ( defined $ql && defined $qu ) {
            ${$resp_200}{prop}{$prop}
                = $prop eq 'quota-available-bytes' ? $ql - $qu
                : $prop eq 'quota-used-bytes'      ? $qu
                : $prop eq 'quota'                 ? $ql
                : $prop eq 'quotaused'             ? $qu
                :                                    undef;
        }
        else {
            ${$resp_404}{prop}{$prop} = undef;
        }
        return 1;
    }
    return 0;
}

sub _get_acl_props {
    my ( $self, $prop, %params ) = @_;
    my $resp_200 = $params{resp_200};
    my $fn       = $params{fn};
    my $uri      = $params{uri};
    my $mode     = $params{mode};
    if ( $prop =~ /^(?:owner|group)$/xms ) {
        return ${$resp_200}{prop}{$prop}{href} = $uri;
    }
    if ( $prop eq 'supported-privilege-set' ) {
        return ${$resp_200}{prop}{$prop}
            = $self->_get_acl_module()->getACLSupportedPrivilegeSet($fn);
    }
    if ( $prop eq 'current-user-privilege-set' ) {
        return ${$resp_200}{prop}{$prop}
            = $self->_get_acl_module()->getACLCurrentUserPrivilegeSet($fn);
    }
    if ( $prop eq 'acl' ) {
        return ${$resp_200}{prop}{$prop}
            = $self->_get_acl_module()->getACLProp($mode);
    }
    if ( $prop eq 'acl-restrictions' ) {
        return ${$resp_200}{prop}{$prop} = {
            'no-invert'          => undef,
            'required-principal' => {
                all      => undef,
                property => [ { owner => undef }, { group => undef } ]
            }
        };
    }
    if ( $prop eq 'inherited-acl-set' ) {
        ${$resp_200}{prop}{$prop} = undef;
        return 1;
    }
    if ( $prop eq 'principal-collection-set' ) {
        return ${$resp_200}{prop}{$prop}{href}
            = $main::PRINCIPAL_COLLECTION_SET;
    }
    return 0;
}

sub _get_caldavschedule_props {
    my ( $self, $prop, %params ) = @_;
    my $resp_200 = $params{resp_200};
    my $fn       = $params{fn};
    my $uri      = $params{uri};
    my $is_dir   = $params{is_dir};
    if ( $is_dir && $prop eq 'resourcetype' ) {
        ${$resp_200}{prop}{$prop}{'schedule-inbox'}  = undef;
        ${$resp_200}{prop}{$prop}{'schedule-outbox'} = undef;
        return 1;
    }
    if ( $prop eq 'schedule-inbox-URL' ) {
        return ${$resp_200}{prop}{$prop}{href}
            = $self->_get_calendar_homeset( $uri, 'inbox' );
    }
    if ( $prop eq 'schedule-outbox-URL' ) {
        return ${$resp_200}{prop}{$prop}{href}
            = $self->_get_calendar_homeset( $uri, 'outbox' );
    }
    if ( $prop eq 'schedule-calendar-transp' ) {
        ${$resp_200}{prop}{$prop}{transparent} = undef;
        return 1;
    }
    if ( $prop eq 'schedule-default-calendar-URL' ) {
        return ${$resp_200}{prop}{$prop} = $self->_get_calendar_homeset($uri);
    }
    if ( $prop eq 'schedule-tag' ) {
        return ${$resp_200}{prop}{$prop} = get_etag($fn);
    }
    return 0;
}

sub _get_caldav_props {
    my ( $self, $prop, %params ) = @_;
    my $resp_200 = $params{resp_200};
    my $fn       = $params{fn};
    my $uri      = $params{uri};
    my $is_dir   = $params{is_dir};

    if ( $prop =~ /^(?:calendar-description|calendar-timezone)$/xms ) {
        return ${$resp_200}{prop}{$prop} = undef;
    }
    if ( $prop eq 'supported-calendar-component-set' ) {
        return ${$resp_200}{prop}{$prop}
            = q{<C:comp name="VEVENT"/><C:comp name="VTODO"/><C:comp name="VJOURNAL"/><C:comp name="VTIMEZONE"/>};
    }
    if ( $prop eq 'supported-calendar-data' ) {
        return ${$resp_200}{prop}{$prop}
            = q{<C:calendar-data content-type="text/calendar" version="2.0"/>};
    }
    if ( $prop eq 'max-resource-size' ) {
        return ${$resp_200}{prop}{$prop} = $CGI::POST_MAX // 20_000_000;
    }
    if ( $prop eq 'min-date-time' ) {
        return ${$resp_200}{prop}{$prop} = '19000101T000000Z';
    }
    if ( $prop eq 'max-date-time' ) {
        return ${$resp_200}{prop}{$prop} = '20491231T235959Z';
    }
    if ( $prop eq 'max-instances' ) {
        return ${$resp_200}{prop}{$prop} = 100;
    }    ## TODO: config
    if ( $prop eq 'max-attendees-per-instance' ) {
        return ${$resp_200}{prop}{$prop} = 100;
    }    ## TODO: config
    if ( $prop eq 'principal-URL' ) {
        return ${$resp_200}{prop}{$prop}{href}
            = $main::CURRENT_USER_PRINCIPAL;
    }
    if ( $prop eq 'getctag' ) {
        return ${$resp_200}{prop}{$prop} = get_etag($fn);
    }
    if (   $prop eq 'resourcetype'
        && $is_dir
        && $self->_get_calendar_homeset($uri) ne $uri )
    {
        return ${$resp_200}{prop}{$prop}{calendar} = undef;
    }
    if ( $prop eq 'calendar-home-set' ) {
        return ${$resp_200}{prop}{$prop} = $self->_get_calendar_homeset($uri);
    }
    if ( $prop eq 'calendar-user-address-set' ) {
        return ${$resp_200}{prop}{$prop}{href}
            = $main::CURRENT_USER_PRINCIPAL;
    }
    if ( $prop eq 'calendar-user-type' ) {
        return ${$resp_200}{prop}{$prop} = 'INDIVIDUAL';
    }
    if ( $prop eq 'calendar-data' ) {
        return ${$resp_200}{prop}{$prop}
            = $fn =~ /[.]ics$/xmsi
            ? ${$self}{cgi}
            ->escapeHTML( ${$self}{backend}->getFileContent($fn) )
            : undef;
    }
    if ( $prop eq 'calendar-free-busy-set' ) {
        return ${$resp_200}{prop}{$prop} = $self->_get_calendar_homeset($uri);
    }
    return 0;
}

sub _get_carddav_props {
    my ( $self, $prop, %params ) = @_;
    my $resp_200 = $params{resp_200};
    my $resp_404 = $params{resp_404};
    my $fn       = $params{fn};
    my $uri      = $params{uri};
    my $is_dir   = $params{is_dir};
    if ( $prop eq 'address-data' ) {
        if ( $fn =~ /[.]vcf$/xmsi ) {
            ${$resp_200}{prop}{$prop} = ${$self}{cgi}
                ->escapeHTML( ${$self}{backend}->getFileContent($fn) );
        }
        else {
            ${$resp_404}{prop}{$prop} = undef;
        }
        return 1;
    }
    if ( $prop eq 'addressbook-description' ) {
        return ${$resp_200}{prop}{$prop}
            = ${$self}{cgi}->escape( ${$self}{backend}->basename($fn) );

    }
    if ( $prop eq 'supported-address-data' ) {
        return ${$resp_200}{prop}{$prop}
            = '<A:address-data-type content-type="text/vcard" version="3.0"/>';
    }
    if ( $prop eq 'max-resource-size' ) {
        return ${$resp_200}{prop}
            {'{urn:ietf:params:xml:ns:carddav}max-resource-size'}
            = 20_000_000;
    }
    if ( $prop eq 'addressbook-home-set' ) {
        return ${$resp_200}{prop}{$prop}{href}
            = $self->_get_addressbook_homeset($uri);

    }
    if ( $prop eq 'principal-address' ) {
        return ${$resp_200}{prop}{$prop}{href} = $uri;
    }
    if ( $prop eq 'resourcetype' && $is_dir ) {
        ${$resp_200}{prop}{$prop}{addressbook} = undef;
        return 1;
    }
    return 0;
}

sub _get_groupdav_props {
    my ( $self, $prop, %params ) = @_;
    if ( !$main::ENABLE_GROUPDAV ) {
        return 0;
    }
    my $resp_200 = $params{resp_200};
    if ( $prop eq 'resourcetype' && $params{is_dir} ) {
        ${$resp_200}{prop}{$prop}{'vevent-collection'} = undef;
        ${$resp_200}{prop}{$prop}{'vtodo-collection'}  = undef;
        ${$resp_200}{prop}{$prop}{'vcard-collection'}  = undef;
        return 1;
    }
    if ( $prop eq 'component-set' && $params{is_dir} ) {
        return ${$resp_200}{prop}{$prop} = 'VEVENT,VTODO,VCARD';
    }
    return 0;
}

sub _get_acl_module {
    my ($self) = @_;
    require WebDAV::ACL;
    return WebDAV::ACL->new( ${$self}{cgi}, ${$self}{backend} );
}

sub _get_addressbook_homeset {
    my ( $self, $uri ) = @_;
    if ( !%main::ADDRESSBOOK_HOME_SET ) {
        return $uri;
    }
    my $rmuser
        = exists $main::ADDRESSBOOK_HOME_SET{$main::REMOTE_USER}
        ? $main::REMOTE_USER
        : $UID;
    return $main::ADDRESSBOOK_HOME_SET{$rmuser}
        // $main::ADDRESSBOOK_HOME_SET{default};
}

sub _get_calendar_homeset {
    my ( $self, $uri, $subpath ) = @_;
    if ( !%main::CALENDAR_HOME_SET ) {
        return $uri;
    }
    my $rmuser
        = exists $main::CALENDAR_HOME_SET{$main::REMOTE_USER}
        ? $main::REMOTE_USER
        : $UID;
    return ( $main::CALENDAR_HOME_SET{$rmuser}
            // $main::CALENDAR_HOME_SET{default} )
        . ( defined $subpath ? $subpath : q{} );
}

1;
