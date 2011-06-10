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

package WebDAV::Properties;

use strict;
#use warnings;

use WebDAV::Common;
our @ISA = ( 'WebDAV::Common' );

use POSIX qw(strftime);

sub new {
        my $this = shift;
        my $class = ref($this) || $this;
        my $self = { };
        bless $self, $class;
        $$self{config}=shift;
	$$self{db} = shift;
	$self->initialize();
        return $self;
}

sub removeProperty {
        my ($self,$propname, $elementParentRef, $resp_200, $resp_403) = @_;
        $$self{db}->db_removeProperty($main::PATH_TRANSLATED, $propname);
        $$resp_200{href}=$main::REQUEST_URI;
        $$resp_200{propstat}{status}='HTTP/1.1 200 OK';
        $$resp_200{propstat}{prop}{$propname} = undef;
}
sub setProperty {
        my ($self,$propname, $elementParentRef, $resp_200, $resp_403) = @_;
        my $fn = $main::PATH_TRANSLATED;
        my $ru = $main::REQUEST_URI;
        $propname=~/^{([^}]+)}(.*)$/;
        my ($ns,$pn) = ($1,$2);

        if ($propname eq '{http://apache.org/dav/props/}executable') {
                my $executable = $$elementParentRef{$propname}{'content'};
                if (defined $executable) {
                        my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size, $atime,$mtime,$ctime,$blksize,$blocks) = $$self{backend}->stat($fn);
                        chmod( ($executable=~/F/) ? $mode & 0666 : $mode | 0111, $fn);
                        $$resp_200{href}=$ru;
                        $$resp_200{propstat}{prop}{executable}=$executable;
                        $$resp_200{propstat}{status}='HTTP/1.1 200 OK';
                }
        } elsif (($propname eq '{DAV:}getlastmodified')||($propname eq '{urn:schemas-microsoft-com:}Win32LastModifiedTime')
                        ||($propname eq '{urn:schemas-microsoft-com:}Win32LastAccessTime')
                        ||($propname eq '{urn:schemas-microsoft-com:}Win32CreationTime')) {
                my $getlastmodified = $$elementParentRef{'{DAV:}getlastmodified'};
                $getlastmodified = $$elementParentRef{'{urn:schemas-microsoft-com:}Win32LastModifiedTime'} if !defined $getlastmodified;
                my $lastaccesstime =$$elementParentRef{'{urn:schemas-microsoft-com:}Win32LastAccessTime'};
                if (defined $getlastmodified) {
                        my $mtime = str2time($getlastmodified);
                        my $atime = defined $lastaccesstime ? str2time($lastaccesstime) : $mtime;
                        utime($atime,$mtime,$fn);
                        $$resp_200{href}=$ru;
                        $$resp_200{propstat}{prop}{getlastmodified}=$getlastmodified if defined  $$elementParentRef{'{DAV:}getlastmodified'};
                        $$resp_200{propstat}{prop}{Win32LastModifiedTime}=$getlastmodified if $$elementParentRef{'{urn:schemas-microsoft-com:}Win32LastModifiedTime'};
                        $$resp_200{propstat}{prop}{Win32LastAccessTime}=$lastaccesstime if $$elementParentRef{'{urn:schemas-microsoft-com:}Win32LastAccessTime'};
                        $$resp_200{propstat}{prop}{Win32CreationTime}=$$elementParentRef{'{urn:schemas-microsoft-com:}Win32CreationTime'} if defined $$elementParentRef{'{urn:schemas-microsoft-com:}Win32CreationTime'};
                        $$resp_200{propstat}{status}='HTTP/1.1 200 OK';
                }
        } elsif ($propname eq '{urn:schemas-microsoft-com:}Win32FileAttributes') {
                $$resp_200{href}=$ru;
                $$resp_200{propstat}{prop}{Win32FileAttributes}=undef;
                $$resp_200{propstat}{status}='HTTP/1.1 200 OK';
        } elsif (defined $main::NAMESPACES{$ns} && grep(/^\Q$pn\E$/,@main::PROTECTED_PROPS)>0) {
                $$resp_403{href}=$ru;
                $$resp_403{propstat}{prop}{$propname}=undef;
                $$resp_403{propstat}{status}='HTTP/1.1 403 Forbidden';
        } else {
                my $n = $propname;
		my $parRef = $$elementParentRef{$propname};
                $n='{}'.$n if ($parRef && ref($parRef) eq 'HASH' && (!$$parRef{xmlns} || $$parRef{xmlns} eq "") && $n!~/^{[^}]*}/);
                my $dbval = $$self{db}->db_getProperty($fn, $n);
                my $value = main::createXML($$elementParentRef{$propname},0);
                my $ret = defined $dbval ? $$self{db}->db_updateProperty($fn, $n, $value) : $$self{db}->db_insertProperty($fn, $n, $value);
                if ($ret) {
                        $$resp_200{href}=$ru;
                        $$resp_200{propstat}{prop}{$propname}=undef;
                        $$resp_200{propstat}{status}='HTTP/1.1 200 OK';
                } else {
                        warn("Cannot set property '$propname'");
                        $$resp_403{href}=$ru;
                        $$resp_403{propstat}{prop}{$propname}=undef;
                        $$resp_403{propstat}{status}='HTTP/1.1 403 Forbidden';

                }
        }
}

sub getProperty {
        my ($self,$fn, $uri, $prop, $statRef, $resp_200, $resp_404) = @_;

        my $isReadable = $$self{backend}->isReadable($fn);
        my $isDir = $$self{backend}->isDir($fn);

        my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size, $atime,$mtime,$ctime,$blksize,$blocks) = defined $statRef ? @{$statRef} : ($isReadable ? $$self{backend}->stat($fn) : ());

        $$resp_200{prop}{creationdate}=strftime('%Y-%m-%dT%H:%M:%SZ' ,gmtime($ctime)) if $prop eq 'creationdate';
        $$resp_200{prop}{displayname}=$$self{cgi}->escape(main::getBaseURIFrag($uri)) if $prop eq 'displayname' && !defined $$resp_200{prop}{displayname};
        $$resp_200{prop}{getcontentlanguage}='en' if $prop eq 'getcontentlanguage';
        $$resp_200{prop}{getcontentlength}= $size if $prop eq 'getcontentlength';
        $$resp_200{prop}{getcontenttype}=($isDir?'httpd/unix-directory':main::getMIMEType($fn)) if $prop eq 'getcontenttype';
        $$resp_200{prop}{getetag}=main::getETag($fn) if $prop eq 'getetag';
        $$resp_200{prop}{getlastmodified}=strftime('%a, %d %b %Y %T GMT' ,gmtime($mtime)) if $prop eq 'getlastmodified';
        $$resp_200{prop}{lockdiscovery}=main::getLockDiscovery($fn) if $prop eq 'lockdiscovery';
        $$resp_200{prop}{resourcetype}=($isDir?{collection=>undef}:undef) if $prop eq 'resourcetype';
        if ($main::ENABLE_LOCK) {
                if ($prop eq 'supportedlock') {
                        $$resp_200{prop}{supportedlock}{lockentry}[0]{lockscope}{exclusive}=undef;
                        $$resp_200{prop}{supportedlock}{lockentry}[0]{locktype}{write}=undef;
                        $$resp_200{prop}{supportedlock}{lockentry}[1]{lockscope}{shared}=undef;
                        $$resp_200{prop}{supportedlock}{lockentry}[1]{locktype}{write}=undef;
                }
        }

        $$resp_200{prop}{executable}=($isReadable && $$self{backend}->isExecutable($fn) )?'T':'F' if $prop eq 'executable';

        $$resp_200{prop}{source}={ 'link'=> { 'src'=>$uri, 'dst'=>$uri }} if $prop eq 'source';

        if ($prop eq 'quota-available-bytes' || $prop eq 'quota-used-bytes' || $prop eq 'quota' || $prop eq 'quotaused') {
                my ($ql,$qu) = $$self{backend}->getQuota();
                if (defined $ql && defined $qu) {
                        $$resp_200{prop}{'quota-available-bytes'} = $ql - $qu if $prop eq 'quota-available-bytes';
                        $$resp_200{prop}{'quota-used-bytes'} = $qu if $prop eq 'quota-used-bytes';
                        $$resp_200{prop}{'quota'} = $ql if $prop eq 'quota';
                        $$resp_200{prop}{'quotaused'}= $qu if $prop eq 'quotaused';
                } else {
                        $$resp_404{prop}{'quota-available-bytes'} = undef if $prop eq 'quota-available-bytes';
                        $$resp_404{prop}{'quota-used-bytes'} = undef if $prop eq 'quota-used-bytes';
                }
        }
        $$resp_200{prop}{childcount}=($isDir?main::getDirInfo($fn,$prop,\%main::FILEFILTERPERDIR,\%main::FILECOUNTPERDIRLIMIT,$main::FILECOUNTLIMIT):0) if $prop eq 'childcount';
        $$resp_200{prop}{id}=$uri if $prop eq 'id';
        $$resp_200{prop}{isfolder}=($isDir?1:0) if $prop eq 'isfolder';
        $$resp_200{prop}{ishidden}=($$self{backend}->basename($fn)=~/^\./?1:0) if $prop eq 'ishidden';
        $$resp_200{prop}{isstructureddocument}=0 if $prop eq 'isstructureddocument';
        $$resp_200{prop}{hassubs}=($isDir?main::getDirInfo($fn,$prop,\%main::FILEFILTERPERDIR,\%main::FILECOUNTPERDIRLIMIT,$main::FILECOUNTLIMIT):0) if $prop eq 'hassubs';
        $$resp_200{prop}{nosubs}=($isDir?($$self{backend}->isWriteable($fn)?1:0):1) if $prop eq 'nosubs';
        $$resp_200{prop}{objectcount}=($isDir?main::getDirInfo($fn,$prop,\%main::FILEFILTERPERDIR,\%main::FILECOUNTPERDIRLIMIT,$main::FILECOUNTLIMIT):0) if $prop eq 'objectcount';
        $$resp_200{prop}{reserved}=0 if $prop eq 'reserved';
        $$resp_200{prop}{visiblecount}=($isDir?main::getDirInfo($fn,$prop,\%main::FILEFILTERPERDIR,\%main::FILECOUNTPERDIRLIMIT,$main::FILECOUNTLIMIT):0) if $prop eq 'visiblecount';

        $$resp_200{prop}{iscollection}=($isDir?1:0) if $prop eq 'iscollection';
        $$resp_200{prop}{isFolder}=($isDir?1:0) if $prop eq 'isFolder';
        $$resp_200{prop}{'authoritative-directory'}=($isDir?'t':'f') if $prop eq 'authoritative-directory';
        $$resp_200{prop}{resourcetag}=$main::REQUEST_URI if $prop eq 'resourcetag';
        $$resp_200{prop}{'repl-uid'}=main::getuuid($fn) if $prop eq 'repl-uid';
        $$resp_200{prop}{modifiedby}=$main::REMOTE_USER if $prop eq 'modifiedby';
        $$resp_200{prop}{Win32CreationTime}=strftime('%a, %d %b %Y %T GMT' ,gmtime($ctime)) if $prop eq 'Win32CreationTime';
        if ($prop eq 'Win32FileAttributes') {
                my $fileattr = 128 + 32; # 128 - Normal, 32 - Archive, 4 - System, 2 - Hidden, 1 - Read-Only
                $fileattr+=1 unless $$self{backend}->isWriteable($fn);
                $fileattr+=2 if $$self{backend}->basename($fn)=~/^\./;
                $$resp_200{prop}{Win32FileAttributes}=sprintf("%08x",$fileattr);
        }
        $$resp_200{prop}{Win32LastAccessTime}=strftime('%a, %d %b %Y %T GMT' ,gmtime($atime)) if $prop eq 'Win32LastAccessTime';
        $$resp_200{prop}{Win32LastModifiedTime}=strftime('%a, %d %b %Y %T GMT' ,gmtime($mtime)) if $prop eq 'Win32LastModifiedTime';
        $$resp_200{prop}{name}=$$self{cgi}->escape($$self{backend}->basename($fn)) if $prop eq 'name';
        $$resp_200{prop}{href}=$uri if $prop eq 'href';
        $$resp_200{prop}{parentname}=$$self{cgi}->escape(main::getBaseURIFrag(main::getParentURI($uri))) if $prop eq 'parentname';
        $$resp_200{prop}{isreadonly}=(!$$self{backend}->isWriteable($fn)?1:0) if $prop eq 'isreadonly';
        $$resp_200{prop}{isroot}=($fn eq $main::DOCUMENT_ROOT?1:0) if $prop eq 'isroot';
        $$resp_200{prop}{getcontentclass}=($isDir?'urn:content-classes:folder':'urn:content-classes:document') if $prop eq 'getcontentclass';
        $$resp_200{prop}{contentclass}=($isDir?'urn:content-classes:folder':'urn:content-classes:document') if $prop eq 'contentclass';
        $$resp_200{prop}{lastaccessed}=strftime('%m/%d/%Y %I:%M:%S %p' ,gmtime($atime)) if $prop eq 'lastaccessed';

        $$resp_200{prop}{'current-user-principal'}{href}=$main::CURRENT_USER_PRINCIPAL if $prop eq 'current-user-principal';

        if ($main::ENABLE_ACL  || $main::ENABLE_CALDAV || $main::ENABLE_CALDAV_SCHEDULE || $main::ENABLE_CARDDAV) {
                $$resp_200{prop}{owner} = { href=>$uri } if $prop eq 'owner';
                $$resp_200{prop}{group} = { href=>$uri } if $prop eq 'group';
                $$resp_200{prop}{'supported-privilege-set'}= $self->getACLModule()->getACLSupportedPrivilegeSet($fn) if $prop eq 'supported-privilege-set';
                $$resp_200{prop}{'current-user-privilege-set'} = $self->getACLModule()->getACLCurrentUserPrivilegeSet($fn) if $prop eq 'current-user-privilege-set';
                $$resp_200{prop}{acl} = $self->getACLModule()->getACLProp($mode) if $prop eq 'acl';
                $$resp_200{prop}{'acl-restrictions'} = {'no-invert'=>undef,'required-principal'=>{all=>undef,property=>[{owner=>undef},{group=>undef}]}} if $prop eq 'acl-restrictions';
                $$resp_200{prop}{'inherited-acl-set'} = undef if $prop eq 'inherited-acl-set';
                $$resp_200{prop}{'principal-collection-set'} = { href=> $main::PRINCIPAL_COLLECTION_SET }, if $prop eq 'principal-collection-set';
        }

        if ($main::ENABLE_CALDAV || $main::ENABLE_CALDAV_SCHEDULE) {
                $$resp_200{prop}{'calendar-description'} = undef if $prop eq 'calendar-description';
                $$resp_200{prop}{'calendar-timezone'} = undef if $prop eq 'calendar-timezone';
                $$resp_200{prop}{'supported-calendar-component-set'} = '<C:comp name="VEVENT"/><C:comp name="VTODO"/><C:comp name="VJOURNAL"/><C:comp name="VTIMEZONE"/>' if $prop eq 'supported-calendar-component-set';
                $$resp_200{prop}{'supported-calendar-data'}='<C:calendar-data content-type="text/calendar" version="2.0"/>' if $prop eq 'supported-calendar-data';
                $$resp_200{prop}{'max-resource-size'}=20000000 if $prop eq 'max-resource-size';
                $$resp_200{prop}{'min-date-time'}='19000101T000000Z' if $prop eq 'min-date-time';
                $$resp_200{prop}{'max-date-time'}='20491231T235959Z' if $prop eq 'max-date-time';
                $$resp_200{prop}{'max-instances'}=100 if $prop eq 'max-instances';
                $$resp_200{prop}{'max-attendees-per-instance'}=100 if $prop eq 'max-attendees-per-instance';
                $$resp_200{prop}{'principal-URL'}{href}=$main::CURRENT_USER_PRINCIPAL if $prop eq 'principal-URL';
                $$resp_200{prop}{'getctag'}=main::getETag($fn)  if $prop eq 'getctag';
                $$resp_200{prop}{resourcetype}{calendar}=undef if $prop eq 'resourcetype' && $isDir && $self->getCalendarHomeSet($uri) ne $uri;

                $$resp_200{prop}{'calendar-home-set'}{href}=$self->getCalendarHomeSet($uri) if $prop eq 'calendar-home-set';
                $$resp_200{prop}{'calendar-user-address-set'}{href}= $main::CURRENT_USER_PRINCIPAL if $prop eq 'calendar-user-address-set';
                $$resp_200{prop}{'calendar-user-type'}='INDIVIDUAL' if $prop eq 'calendar-user-type';
                ##$$resp_200{prop}{'calendar-data'}='<![CDATA['.$$self{backend}->getFileContent($fn).']]>' if $prop eq 'calendar-data';
                if ($prop eq 'calendar-data') {
                        if ($fn=~/\.ics$/i) {
                                $$resp_200{prop}{'calendar-data'}=$$self{cgi}->escapeHTML($$self{backend}->getFileContent($fn));
                        } else {
                                $$resp_404{prop}{'calendar-data'}=undef;
                        }
                }
                $$resp_200{prop}{'calendar-free-busy-set'}{href}=$self->getCalendarHomeSet($uri) if $prop eq 'calendar-free-busy-set';
        }
        if ($main::ENABLE_CALDAV_SCHEDULE) {
                $$resp_200{prop}{resourcetype}{'schedule-inbox'}=undef if $prop eq 'resourcetype' && $main::ENABLE_CALDAV_SCHEDULE && $isDir;
                $$resp_200{prop}{resourcetype}{'schedule-outbox'}=undef if $prop eq 'resourcetype' && $main::ENABLE_CALDAV_SCHEDULE && $isDir;
                $$resp_200{prop}{'schedule-inbox-URL'}{href} = $self->getCalendarHomeSet($uri) if $prop eq 'schedule-inbox-URL';
                $$resp_200{prop}{'schedule-outbox-URL'}{href} = $self->getCalendarHomeSet($uri) if $prop eq 'schedule-outbox-URL';
                $$resp_200{prop}{'schedule-calendar-transp'}{transparent} = undef if $prop eq 'schedule-calendar-transp';
                $$resp_200{prop}{'schedule-default-calendar-URL'}=$self->getCalendarHomeSet($uri) if $prop eq 'schedule-default-calendar-URL';
                $$resp_200{prop}{'schedule-tag'}=main::getETag($fn) if $prop eq 'schedule-tag';
        }
        if ($main::ENABLE_CARDDAV) {
                if ($prop eq 'address-data') {
                        if ($fn =~ /\.vcf$/i) {
                                $$resp_200{prop}{'address-data'}=$$self{cgi}->escapeHTML($$self{backend}->getFileContent($fn));
                        } else {
                                $$resp_404{prop}{'address-data'}=undef;
                        }
                }
                $$resp_200{prop}{'addressbook-description'} = $$self{cgi}->escape($$self{backend}->basename($fn)) if $prop eq 'addressbook-description';
                $$resp_200{prop}{'supported-address-data'}='<A:address-data-type content-type="text/vcard" version="3.0"/>' if $prop eq 'supported-address-data';
                $$resp_200{prop}{'{urn:ietf:params:xml:ns:carddav}max-resource-size'}=20000000 if $prop eq 'max-resource-size' && $main::ENABLE_CARDDAV;
                $$resp_200{prop}{'addressbook-home-set'}{href}=$self->getAddressbookHomeSet($uri) if $prop eq 'addressbook-home-set';
                $$resp_200{prop}{'principal-address'}{href}=$uri if $prop eq 'principal-address';
                $$resp_200{prop}{resourcetype}{addressbook}=undef if $prop eq 'resourcetype' && $main::ENABLE_CARDDAV && $isDir;
        }
        if ($main::ENABLE_GROUPDAV) {
                $$resp_200{prop}{resourcetype}{'vevent-collection'}=undef if $prop eq 'resourcetype' && $isDir;
                $$resp_200{prop}{resourcetype}{'vtodo-collection'}=undef if $prop eq 'resourcetype' && $isDir;
                $$resp_200{prop}{resourcetype}{'vcard-collection'}=undef if $prop eq 'resourcetype' && $isDir;
                $$resp_200{prop}{'component-set'}='VEVENT,VTODO,VCARD' if $prop eq 'component-set'  && $isDir;
        }

        $$resp_200{prop}{'supported-report-set'} =
                                { 'supported-report' =>
                                        [
                                                { report=>{ 'acl-principal-prop-set'=>undef } },
                                                { report=>{ 'principal-match'=>undef } },
                                                { report=>{ 'principal-property-search'=>undef } },
                                                { report=>{ 'calendar-multiget'=>undef } },
                                                { report=>{ 'calendar-query'=>undef } },
                                                { report=>{ 'free-busy-query'=>undef } },
                                                { report=>{ 'addressbook-query'=>undef} },
                                                { report=>{ 'addressbook-multiget'=>undef} },
                                                ## { report=>{ 'expand-property'=>undef} },
                                        ]
                                } if $prop eq 'supported-report-set';

        if ($prop eq 'supported-method-set') {
                $$resp_200{prop}{'supported-method-set'} = '';
                foreach my $method (@{main::getSupportedMethods($fn)}) {
                        $$resp_200{prop}{'supported-method-set'} .= '<D:supported-method name="'.$method.'"/>';
                }
        }

        if ($prop eq 'resource-id') {
                my $e = main::getETag($$self{backend}->resolve($fn));
                $e=~s/"//g;
                $$resp_200{prop}{'resource-id'} = 'urn:uuid:'.$e;
        }

}
sub getACLModule {
	my ($self) = @_;
	require WebDAV::ACL;
	return new WebDAV::ACL($$self{cgi},$$self{backend});
}

sub getAddressbookHomeSet {
        my ($self, $uri) = @_;
        return $uri unless defined %main::ADDRESSBOOK_HOME_SET;
        my $rmuser = $main::REMOTE_USER;
        $rmuser = $< unless exists $main::ADDRESSBOOK_HOME_SET{$rmuser};
        return ( exists $main::ADDRESSBOOK_HOME_SET{$rmuser} ? $main::ADDRESSBOOK_HOME_SET{$rmuser} : $main::ADDRESSBOOK_HOME_SET{default} );
}
sub getCalendarHomeSet {
        my ($self,$uri) = @_;
        return $uri unless defined %main::CALENDAR_HOME_SET;
        my $rmuser = $main::REMOTE_USER;
        $rmuser = $< unless exists $main::CALENDAR_HOME_SET{$rmuser};
        return  ( exists $main::CALENDAR_HOME_SET{$rmuser} ? $main::CALENDAR_HOME_SET{$rmuser} : $main::CALENDAR_HOME_SET{default} );
}

1;
