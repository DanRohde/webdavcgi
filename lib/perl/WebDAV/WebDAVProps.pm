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
#### PROPERTIES:
# from RFC2518:
#    creationdate, displayname, getcontentlanguage, getcontentlength,
#    getcontenttype, getetag, getlastmodified, lockdiscovery, resourcetype,
#    source, supportedlock
# from RFC4918:
#    -source
# from RFC4331:
#    quota-available-bytes, quota-used-bytes
# from draft-hopmann-collection-props-00.txt:
#    childcount, defaultdocument (live), id, isfolder, ishidden, isstructureddocument,
#    hassubs, nosubs, objectcount, reserved, visiblecount
# from MS-WDVME:
#    iscollection, isFolder, ishidden (=draft),
#    Repl:authoritative-directory, Repl:resourcetag, Repl:repl-uid,
#    Office:modifiedby, Office:specialFolderType (dead),
#    Z:Win32CreationTime, Z:Win32FileAttributes, Z:Win32LastAccessTime, Z:Win32LastModifiedTime
# from reverse engineering:
#    name, href, parentname, isreadonly, isroot, getcontentclass, lastaccessed, contentclass
#    executable
# from RFC3744 (ACL):
#    owner, group, supported-privilege-set, current-user-privilege-set, acl, acl-restrictions
# from RFC4791 (CalDAV):
#    calendar-description, calendar-timezone, supported-calendar-component-set, supported-calendar-data,
#    max-resource-size, min-date-time, max-date-time, max-instances, max-attendees-per-instance,
#    calendar-home-set,
# from http://svn.calendarserver.org/repository/calendarserver/CalendarServer/trunk/doc/Extensions/caldav-ctag.txt
#    getctag
# from RFC5397 (WebDAV Current User Principal)
#    current-user-principal
# from http://tools.ietf.org/html/draft-desruisseaux-caldav-sched-08
#    principal: schedule-inbox-URL, schedule-outbox-URL, calendar-user-type, calendar-user-address-set,
#    collection: schedule-calendar-transp,schedule-default-calendar-URL,schedule-tag
# from http://svn.calendarserver.org/repository/calendarserver/CalendarServer/trunk/doc/Extensions/caldav-pubsubdiscovery.txt
# from RFC3253 (DeltaV)
#    supported-report-set
#    supported-method-set for RFC5323 (DASL/SEARCH):
# from http://datatracker.ietf.org/doc/draft-ietf-vcarddav-carddav/
#    collection: addressbook-description, supported-address-data
#    principal: addressbook-home-set, principal-address
#    report: address-data
# from RFC5842 (bind)
#    resource-id, parent-set (unsupported yet)
# from http://tools.ietf.org/html/draft-daboo-carddav-directory-gateway-02
#    directory-gateway (unsupported yet)
# from ?
#    calendar-free-busy-set

package WebDAV::WebDAVProps;

use strict;
use warnings;

our $VERSION = '2.0';

use base qw( Exporter );
our @EXPORT = qw(
  init_webdav_props
  @UNSUPPORTED_PROPS @PROTECTED_PROPS @KNOWN_COLL_PROPS @KNOWN_ACL_PROPS
  @KNOWN_CALDAV_COLL_PROPS @KNOWN_CALDAV_FILE_PROPS @KNOWN_CARDDAV_COLL_PROPS
  @KNOWN_CARDDAV_FILE_PROPS @KNOWN_COLL_LIVE_PROPS @KNOWN_FILE_LIVE_PROPS
  @KNOWN_CALDAV_COLL_LIVE_PROPS @KNOWN_CALDAV_FILE_LIVE_PROPS
  @KNOWN_CARDDAV_COLL_LIVE_PROPS @KNOWN_CARDDAV_FILE_LIVE_PROPS
  @KNOWN_FILE_PROPS 
  %KNOWN_FILECOLL_PROPS_HASH %KNOWN_COLL_PROPS_HASH %KNOWN_FILE_PROPS_HASH
  %UNSUPPORTED_PROPS_HASH
);

use vars
  qw( @UNSUPPORTED_PROPS @PROTECTED_PROPS @KNOWN_COLL_PROPS @KNOWN_ACL_PROPS
  @KNOWN_CALDAV_COLL_PROPS @KNOWN_CALDAV_FILE_PROPS @KNOWN_CARDDAV_COLL_PROPS
  @KNOWN_CARDDAV_FILE_PROPS @KNOWN_COLL_LIVE_PROPS @KNOWN_FILE_LIVE_PROPS
  @KNOWN_CALDAV_COLL_LIVE_PROPS @KNOWN_CALDAV_FILE_LIVE_PROPS
  @KNOWN_CARDDAV_COLL_LIVE_PROPS @KNOWN_CARDDAV_FILE_LIVE_PROPS
  @KNOWN_FILE_PROPS 
  %KNOWN_FILECOLL_PROPS_HASH %KNOWN_COLL_PROPS_HASH %KNOWN_FILE_PROPS_HASH
  %UNSUPPORTED_PROPS_HASH
);

BEGIN {

    @UNSUPPORTED_PROPS = qw(
      checked-in checked-out xmpp-uri dropbox-home-URL
      parent-set directory-gateway
    );

    @PROTECTED_PROPS = (
        @UNSUPPORTED_PROPS,
        'appledoubleheader',
        'getcontentlength',
        'getcontenttype',
        'getetag',
        'lockdiscovery',
        'source',
        'supportedlock',
        'supported-report-set',
        'quota-available-bytes, quota-used-bytes',
        'quota',
        'quotaused',
        'childcount',
        'id',
        'isfolder',
        'ishidden',
        'isstructureddocument',
        'hassubs',
        'nosubs',
        'objectcount',
        'reserved',
        'visiblecount',
        'iscollection',
        'isFolder',
        'authoritative-directory',
        'resourcetag',
        'repl-uid',
        'modifiedby',
        'name',
        'href',
        'parentname',
        'isreadonly',
        'isroot',
        'getcontentclass',
        'contentclass',
        'owner',
        'group',
        'supported-privilege-set',
        'current-user-privilege-set',
        'acl',
        'acl-restrictions',
        'inherited-acl-set',
        'principal-collection-set',
        'supported-calendar-component-set',
        'supported-calendar-data',
        'max-resource-size',
        'min-date-time',
        'max-date-time',
        'max-instances',
        'max-attendees-per-instance',
        'getctag',
        'current-user-principal',
        'calendar-user-address-set',
        'schedule-inbox-URL',
        'schedule-outbox-URL',
        'schedule-calendar-transp',
        'schedule-default-calendar-URL',
        'schedule-tag',
        'supported-address-data',
        'supported-collation-set',
        'supported-method-set',
        'supported-method',
        'supported-query-grammar',
        'directory-gateway',
        'caldav-free-busy-set',
    );
    @KNOWN_COLL_PROPS = qw(
      creationdate            displayname
      getcontentlanguage      getlastmodified
      lockdiscovery           resourcetype
      getetag                 getcontenttype
      supportedlock           source
      quota-available-bytes   quota-used-bytes
      quota                   quotaused
      childcount              id
      isfolder                ishidden
      isstructureddocument    hassubs
      nosubs                  objectcount
      reserved                visiblecount
      iscollection            isFolder
      authoritative-directory resourcetag
      repl-uid                modifiedby
      Win32CreationTime       Win32FileAttributes
      Win32LastAccessTime     Win32LastModifiedTime
      name                    href
      parentname              isreadonly
      isroot                  getcontentclass
      lastaccessed            contentclass
      supported-report-set    supported-method-set
    );
    @KNOWN_ACL_PROPS = qw(
      owner                   group
      supported-privilege-set current-user-privilege-set
      acl                     acl-restrictions
      inherited-acl-set       principal-collection-set
      current-user-principal
    );
    @KNOWN_CALDAV_COLL_PROPS = qw(
      calendar-description             calendar-timezone
      supported-calendar-component-set supported-calendar-data
      max-resource-size                min-date-time
      max-date-time                    max-instances
      max-attendees-per-instance       getctag
      principal-URL                    calendar-home-set
      schedule-inbox-URL               schedule-outbox-URL
      calendar-user-type               schedule-calendar-transp
      schedule-default-calendar-URL    schedule-tag
      calendar-user-address-set        calendar-free-busy-set
    );
    @KNOWN_CALDAV_FILE_PROPS = qw( calendar-data );

    @KNOWN_CARDDAV_COLL_PROPS = qw(
      addressbook-description supported-address-data
      addressbook-home-set    principal-address
    );
    @KNOWN_CARDDAV_FILE_PROPS = qw( address-data );

    @KNOWN_COLL_LIVE_PROPS        = ();
    @KNOWN_FILE_LIVE_PROPS        = ();
    @KNOWN_CALDAV_COLL_LIVE_PROPS = qw(
      resourcetype         displayname
      calendar-description calendar-timezone
      calendar-user-address-set
    );
    @KNOWN_CALDAV_FILE_LIVE_PROPS  = ();
    @KNOWN_CARDDAV_COLL_LIVE_PROPS = qw( addressbook-description );
    @KNOWN_CARDDAV_FILE_LIVE_PROPS = ();

    @KNOWN_FILE_PROPS = ( @KNOWN_COLL_PROPS, 'getcontentlength', 'executable' );

}

sub init_webdav_props {
    if (   $main::ENABLE_CALDAV
        || $main::ENABLE_CALDAV_SCHEDULE
        || $main::ENABLE_CARDDAV )
    {
        push @KNOWN_COLL_LIVE_PROPS, @KNOWN_CALDAV_COLL_LIVE_PROPS;
        push @KNOWN_FILE_LIVE_PROPS, @KNOWN_CALDAV_FILE_LIVE_PROPS;
    }
    if ($main::ENABLE_CARDDAV) {
        push @KNOWN_COLL_LIVE_PROPS, @KNOWN_CARDDAV_COLL_LIVE_PROPS;
    }
    if (   $main::ENABLE_ACL
        || $main::ENABLE_CALDAV
        || $main::ENABLE_CALDAV_SCHEDULE
        || $main::ENABLE_CARDDAV )
    {
        push @KNOWN_COLL_PROPS, @KNOWN_ACL_PROPS;
    }

    if ( $main::ENABLE_CALDAV || $main::ENABLE_CALDAV_SCHEDULE ) {
        push @KNOWN_COLL_PROPS, @KNOWN_CALDAV_COLL_PROPS;

        push @KNOWN_FILE_PROPS, @KNOWN_CALDAV_FILE_PROPS;
    }

    if ($main::ENABLE_CARDDAV) {
        push @KNOWN_COLL_PROPS, @KNOWN_CARDDAV_COLL_PROPS;
        push @KNOWN_FILE_PROPS, @KNOWN_CARDDAV_FILE_PROPS;
    }

    if ($main::ENABLE_BIND) {
        push @KNOWN_COLL_PROPS, 'resource-id';
    }

    if ($main::ENABLE_GROUPDAV) {
        push @KNOWN_COLL_PROPS, 'component-set';
    }

    foreach (@KNOWN_COLL_PROPS) {
        $KNOWN_COLL_PROPS_HASH{$_}     = 1;
        $KNOWN_FILECOLL_PROPS_HASH{$_} = 1;
    }
    foreach (@KNOWN_FILE_PROPS) {
        $KNOWN_FILE_PROPS_HASH{$_}     = 1;
        $KNOWN_FILECOLL_PROPS_HASH{$_} = 1;
    }
    foreach (@UNSUPPORTED_PROPS) { $UNSUPPORTED_PROPS_HASH{$_} = 1; }

    return;
}

1;
