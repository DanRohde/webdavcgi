#!/usr/bin/perl
###!/usr/bin/speedy --  -r20 -M5
#########################################################################
# (C) ZE CMS, Humboldt-Universitaet zu Berlin
# Written 2010 by Daniel Rohde <d.rohde@cms.hu-berlin.de>
#########################################################################
# This is a very pure WebDAV server implementation that
# uses the CGI interface of a Apache webserver.
# Use this script in conjunction with a UID/GID wrapper to
# get and preserve file permissions.
# IT WORKs ONLY WITH UNIX/Linux.
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
# VERSION 0.6.2 BETA
# REQUIREMENTS:
#    - see http://webdavcgi.sf.net/doc.html
# INSTALLATION:
#    - see http://webdavcgi.sf.net/doc.html
#       
# CHANGES:
#   0.6.2: BETA
#        - Web interface:
#            - added properties viewer switch (GET)
#            - added sidebar view (GET)
#            - improved page navigation (GET)
#            - changed message box behavior (GET)
#            - added file/folder name filtering feature (GET)
#            - added $ORDER config parameter (GET)
#            - improved folder list sort with cookies (GET)
#            - fixed sort bug in search results (GET)
#            - fixed selection not higlighted after back button pressed bug using Chrom(e/ium) browser (GET)
#            - fixed annoying whitespace wraps (GET)
#            - fixed wrong message display for change location/bookmark usage (GET)
#        - fixed file/folder search performance bug in a AFS (GET)
#   0.6.1: 2011/25/02
#        - fixed missing HTTP status of inaccessible files (GET)
#        - changed CONFIGFILE default
#        - fixed major AFS performance bug related to AFS ACL rights: list without read right on a folder with unreadable files (GET/PROPFIND)
#        - Web interface:
#            - fixed MIME sorting bug (GET)
#            - added ascending/descending order character to the column name (GET)
#            - fixed POST upload permission denied error message (POST)
#            - fixed rename of file/folder to a existing file/folder error message (POST)
#            - added change location feature (GET)
#            - added bookmark feature (GET)
#            - fixed major AFS quota and ACL command call bug  (special characters in folder names; GET)
#            - moved file upload up (GET)
#            - improved 'view by page'/'show all' (cookie based now, GET)
#            - added go up and refresh buttons (GET)
#            - changed THUMBNAIL_CACHEDIR default to /tmp (GET)
#   0.6.0: 2010/19/12
#        - fixed default DOCUMENT_ROOT and VIRTUAL_BASE (Apache's DOCUMENT_ROOT is without a trailing slash by default)
#        - added mime.types file support requested by Hanz Makmur <makmur@cs.rutgers.edu>
#        - added a per folder filter for files/folders listed by PROPFIND and the Web interface (GET/PROPFIND)
#        - added a per folder limit for file/folders listed by PROPFIND and the Web interface (GET/PROPFIND)
#        - fixed hidden file/folder handling (performance issue on MacOS-X) (PROPFIND)
#        - added a switch to ignore file permissions for full AFS support (GET/PUT/PROPFIND/COPY/MKCOL/MOVE/DELETE)
#        - added AFS quota support (GET/PROPFIND)
#        - fixed move/copy with a port in destination URI bug reported by lasse.karstensen@gmail.com (MOVE/COPY)
#        - fixed documenation bug related to MySQL schema reported by lasse.karstensen@gmail.com (MOVE/COPY)
#        - added file locking support (flock) requested by lasse.karstensen@gmail.com (PUT/POST)
#        - improved Web interface (GET/POST)
#            - used HTML table instead of preformatted text for file/folder listing
#            - added a clipboard (GET/POST)
#            - added stylesheet support ($CSS, $CSSURI)
#            - added row and column highlighting for file/folder listing 
#            - added selection on (shift) click and get on double click feature
#            - added tooltips to the last modified and size column
#            - changed thumbnail format (only GIFs are used for thumbnails)
#            - added PDF/PostScript/plain text thumbnail support
#            - fixed minor DVI file icon bug (GET)
#            - fixed minor page navigation bug (GET)
#            - added a switch to hide mime types requested by Hanz Makmur <makmur@cs.rutgers.edu>
#            - added OpenSearch.org support (GET)
#            - added media RSS feed for Cooliris.com support (GET)
#            - added the AFS ACL Manager (GET/POST)
#            - added the AFS Group Manager (GET/POST)
#        - fixed minor documentation bugs
#   0.5.3: 2010/10/11
#        - fixed minor link loop bug (depth != infinity => read until depth was reached) (PROPFIND)
#        - improved Web interface (GET/POST):
#            - added missing MIME types and icons (video, source code) (GET)
#            - fixed root folder navigation bug in the Web interface reported by Andre Schaaf (GET)
#            - added file permissions column to the Web interface (GET)
#            - added change file permission feature to the Web interface (GET/POST)
#            - added simple language switch to the Web interface (GET/POST)
#            - fixed German translations (GET)
#            - fixed minor sorting and properties view bug in the Web interface (GET)
#        - improved performance (direct method call instead of eval)
#        - replaced Image::Magick by Graphics::Magick for thumbnail support (GET)
#        - added Speedy support requested by Hanz Makmur (mod_perl and pperl should also work)
#   0.5.2: 2010/23/09
#        - added BIND/UNBIND/REBIND methods (RFC5842)
#        - fixed major link loop bug (PROPFIND/GET/SEARCH/LOCK)
#        - fixed major move/copy/delete symbolic link bug (MOVE/COPY/POST)
#        - fixed minor long URL after file upload bug (POST)
#   0.5.1: 2010/07/09
#        - fixed minor file not readable bug (GET)
#        - improved Web interface (GET/POST):
#            - fixed property view HTML conformance bug (GET)
#            - fixed major illegal regex bug in file/folder name search (GET)
#            - added image thumbnail support (GET)
#            - fixed minor readable/writeable folder bug (GET)
#            - added (error/acknowledgement) messages for file/folder actions (GET/POST)
#            - changed HTML conformance from XHTML to HTML5 (GET/POST)
#            - added multiple file upload support within a single file field supported by Firefox 3.6, Chrome4, ??? (GET/POST)
#   0.5.0: 2010/20/08
#        - improved database performance (indexes)
#        - added WebDAV SEARCH/DASL (RFC5323, SEARCH)
#        - added GroupDAV support (http://groupdav.org/draft-hess-groupdav-01.txt)
#        - improved Web interface (GET/POST):
#            - added localization support (GET)
#            - added paging (GET)
#            - added confirmation dialogs (GET)
#            - added 'Toggle All' button (GET)
#            - added zip upload (GET/POST)
#            - added zip download (GET/POST)
#            - added sorting feature (GET)
#            - added quick folder navigation (GET)
#            - added search feature (GET)
#            - added file/folder statistics (GET)
#        - fixed PUT trouble (empty files) with some Apache configurations reported by Cyril Elkaim
#        - added configuration file feature requested by Cyril Elkaim
#        - fixed SQL bugs to work with MySQL reported by Cyril Elkaim
#        - added missing MIME types (GET,PROPFIND,REPORT)
#        - fixed XML namespace for transparent element (PROPFIND)
#   0.4.1: 2010/05/07
#        - added a server-side trash can (DELETE/POST)
#        - added a property view to the web interface (GET)
#        - fixed missing bind/unbind privileges for ACL properties (PROPFIND)
#        - fixed missing data types for some Windows properties (PROPFIND)
#   0.4.0: 2010/24/06
#        - added CardDAV support (incomplete: no preconditions, no filter in REPORT queries; PROPFIND/REPORT)
#        - fixed missing current user privileges bug (PROPFIND)
#        - fixed supported-report-set property bug (PROPFIND)
#        - fixed depth greater than one bug in calendar-query REPORT query  (REPORT)
#        - fixed unknown report bug (REPORT)
#   0.3.7: 2010/14/06
#        - added current-user-principal property (RFC5397; PROPFIND)
#        - added incomplete CalDAV schedule support (http://tools.ietf.org/html/draft-desruisseaux-caldav-sched-08; REPORT/PROPFIND)
#        - added incomplete CalDAV support (RFC4791; PROPFIND/REPORT)
#        - added incomplete ACL support (RFC3744; PROPFIND/ACL/REPORT)
#        - added extendend MKCOL support (RFC5689; MKCOL)
#        - added mixed content support for user defined properties (PROPPATCH/PROPFIND)
#        - added switches to enable/disable features (LOCK, CalDAV, CalDAV-Schedule, ACL; OPTIONS/ACL/LOCK/UNLOCK/REPORT)
#        - improved performance with caching (PROPFIND/REPORT)
#        - improved XML generation: define only used namespaces (PROPFIND/REPORT/PROPATCH/DELETE/LOCK)
#        - fixed missing property protection bug (PROPPATCH)
#        - fixed OPTIONS bug
#        - fixed lock owner bug (LOCK)
#        - fixed bug: hidden files should not be counted (PROPFIND:childcount,visiblecount,hassubs,objectcount)
#        - fixed isroot bug (PROPFIND)
#   0.3.6: 2010/03/06
#        - improved security (POST)
#        - small but safe performance improvements (MOVE)
#        - fixed quota bug (quota-available-bytes; PROPFIND)
#        - added GFS/GFS2 quota support (GET, PROPFIND)
#        - fixed bug: missing '/' in href property of a folder (Dreamweaver works now; PROPFIND)
#        - improved performance with caching (PROPFIND)
#        - added missing source property (PROPFIND)
#   0.3.5: 2010/31/05
#        - added logging
#        - fixed redirect bugs reported by Paulo Estrela (POST,MKCOL,...)
#        - added user property support (PROPPATCH/PROPFIND)
#        - fixed datatype bug (PROPFIND)
#        - improved allprop request performance (PROPFIND)
#        - fixed include handling (PROPFIND)
#        - passed all litmus tests (http://www.webdav.org/neon/litmus/)
#        - fixed lock token generation bug (LOCK)
#        - fixed database schema bug (LOCK)
#        - fixed LOCK/UNLOCK shared/exclusive bugs (litmus locks)
#        - fixed PROPFIND bugs (litmus props)
#        - fixed PROPPATCH bugs (litmus props)
#        - fixed COPY bugs (litmus copymove/props)
#        - fixed MOVE bugs (litmus copymove/props)
#        - fixed MCOL bugs (litmus basic)
#        - fixed DELETE bugs (litmus basic)
#   0.3.4: 2010/25/05
#        - added WebDAV mount feature (RFC4709 - GET)
#        - added quota properties (RFC4331 - PROPFIND)
#        - added M$ name spaces (PROPFIND/PROPPATCH)
#        - added M$-WDVME support
#        - added M$-WDVSE support
#        - fixed depth handling (PROPFIND)
#   0.3.3: 2010/11/05
#        - improved file upload (POST)
#        - fixed Windows file upload bug (POST)
#        - fixed fency indexing header formatting bug (GET)
#        - fixed fency indexing URI encoding bug (GET)
#        - fixed redirect bug (CGI and POST)
#   0.3.2: 2010/10/05
#        - added simple file management (mkdir, rename/move, delete)
#        - fixed missing (REDIRECT_)PATH_TRANSLATED environment bug
#        - fixed double URL encoding problem (COPY/MOVE)
#   0.3.1: 2010/10/05
#        - fixed Vista/Windows7 problems (PROPFIND)
#   0.3.0: 2010/07/05
#        - added LOCK/UNLOCK
#        - added ETag support
#        - fixed account in destination URI bug (COPY/MOVE)
#        - fixed delete none existing resource bug (DELETE)
#        - fixed element order in XML responses bug (PROPFIND/PROPPATCH/DELETE/LOCK)
#        - fixed direct call bug (MKCOL/PUT/LOCK)
#        - fixed MIME type detection bug (GET/PROPFIND)
#   0.2.4: 2010/29/04
#        - added fancy indexing setup switch
#        - added additional properties for files/folders
#        - fixed PROPFIND request handling
#   0.2.3: 2010/28/04
#        - improved debugging
#        - fixed URI encoded characters in 'Destination' request header bug (MOVE/COPY)
#   0.2.2: 2010/27/04
#        - added Apache namespace (executable)
#        - fixed namespace bugs (PROPFIND/PROPPATCH)
#        - added hide feature: hide special files/folders 
#        - fixed PROPPATCH bug (Multi-Status)
#   0.2.1: 2010/27/04
#        - added PROPPATCH support for getlastmodified updates
#        - fixed MIME types (jpg)
#        - fixed error handling (Method Not Allowed, Not Implemented)
#        - added table header for fancy indexing
#        - code cleanup
#        - added setup documentation
#   0.2: 2010/26/04
#        - added umask configuration parameter
#        - fixed invalid HTML encoding for '<folder>' 
#          in GET requests on collections
#   0.1: 2010/26/04 
#        - initial implementation
# TODO:
#    - add a property editor to the Web interface
#    - handle LOCK timeouts 
#    - RFC5689 (extended MKCOL) is incomplete (error handling/precondition check)
#    - RFC3744 (ACL's) (incomplete)
#    - RFC4791 (CalDAV) incomplete
#    - Collection Synchronization for WebDAV (http://tools.ietf.org/html/draft-daboo-webdav-sync-03)
#    - RFC5842 (Binding Extensions to Web Distributed Authoring and Versioning (WebDAV))
#    - RFC5785 (Defining Well-Known Uniform Resource Identifiers (URIs))
#    - improve/fix precondition checks (If header)
# KNOWN PROBLEMS:
#    - see http://webdavcgi.sf.net/
#########################################################################
use vars qw($VIRTUAL_BASE $DOCUMENT_ROOT $UMASK %MIMETYPES $FANCYINDEXING %ICONS @FORBIDDEN_UID
            @HIDDEN $ALLOW_POST_UPLOADS $BUFSIZE $MAXFILENAMESIZE $DEBUG %ELEMENTORDER
            $DBI_SRC $DBI_USER $DBI_PASS $DBI_INIT $DEFAULT_LOCK_OWNER $ALLOW_FILE_MANAGEMENT
            $ALLOW_INFINITE_PROPFIND %NAMESPACES %NAMESPACEELEMENTS %ELEMENTS %NAMESPACEABBR %DATATYPES
            $CHARSET $LOGFILE %CACHE $GFSQUOTA $SHOW_QUOTA $SIGNATURE $POST_MAX_SIZE @PROTECTED_PROPS
            @UNSUPPORTED_PROPS $ENABLE_ACL $ENABLE_CALDAV @ALLPROP_PROPS $ENABLE_LOCK
            @KNOWN_COLL_PROPS @KNOWN_FILE_PROPS @IGNORE_PROPS @KNOWN_CALDAV_COLL_PROPS
            @KNOWN_COLL_LIVE_PROPS @KNOWN_FILE_LIVE_PROPS
            @KNOWN_CALDAV_COLL_LIVE_PROPS @KNOWN_CALDAV_FILE_LIVE_PROPS
            @KNOWN_CARDDAV_COLL_LIVE_PROPS @KNOWN_CARDDAV_FILE_LIVE_PROPS
            @KNOWN_ACL_PROPS @KNOWN_CALDAV_FILE_PROPS 
            $ENABLE_CALDAV_SCHEDULE
            $ENABLE_CARDDAV @KNOWN_CARDDAV_COLL_PROPS @KNOWN_CARDDAV_FILE_PROPS $CURRENT_USER_PRINCIPAL
            %ADDRESSBOOK_HOME_SET %CALENDAR_HOME_SET $PRINCIPAL_COLLECTION_SET 
            $ENABLE_TRASH $TRASH_FOLDER $ALLOW_SEARCH $SHOW_STAT $HEADER $CONFIGFILE $ALLOW_ZIP_UPLOAD $ALLOW_ZIP_DOWNLOAD
            $PAGE_LIMIT $ENABLE_SEARCH $ENABLE_GROUPDAV %SEARCH_PROPTYPES %SEARCH_SPECIALCONV %SEARCH_SPECIALOPS
            @DB_SCHEMA $CREATE_DB %TRANSLATION $LANG $MAXLASTMODIFIEDSIZE $MAXSIZESIZE
            $THUMBNAIL_WIDTH $ENABLE_THUMBNAIL $ENABLE_THUMBNAIL_CACHE $THUMBNAIL_CACHEDIR $ICON_WIDTH
            $ENABLE_BIND $SHOW_PERM $ALLOW_CHANGEPERM $ALLOW_CHANGEPERMRECURSIVE $LANGSWITCH
            $PERM_USER $PERM_GROUP $PERM_OTHERS
            $DBI_PERSISTENT
            $FILECOUNTLIMIT %FILECOUNTPERDIRLIMIT %FILEFILTERPERDIR $IGNOREFILEPERMISSIONS
            $MIMEFILE $CSS $ENABLE_THUMBNAIL_PDFPS
	    $ENABLE_FLOCK $SHOW_MIME $AFSQUOTA $CSSURI $HTMLHEAD $ENABLE_CLIPBOARD
	    $LIMIT_FOLDER_DEPTH $AFS_FSCMD $ENABLE_AFSACLMANAGER $ALLOW_AFSACLCHANGES @PROHIBIT_AFS_ACL_CHANGES_FOR
            $AFS_PTSCMD $ENABLE_AFSGROUPMANAGER $ALLOW_AFSGROUPCHANGES 
            $WEB_ID $ENABLE_BOOKMARKS $ENABLE_AFS $ORDER $ENABLE_NAMEFILTER @PAGE_LIMITS
            $ENABLE_SIDEBAR $VIEW $ENABLE_PROPERTIES_VIEWER
); 
#########################################################################
############  S E T U P #################################################

## -- ENV{PATH} 
##  search PATH for binaries 
$ENV{PATH}="/bin:/usr/bin:/sbin/:/usr/local/bin:/usr/sbin";

## -- CONFIGFILE
## you can overwrite all variables from this setup section with a config file
## (simply copy the complete setup section (without 'use vars ...') or single options to your config file)
## EXAMPLE: CONFIGFILE = './webdav.conf';
$CONFIGFILE = $ENV{WEBDAVCONF} || '/usr/local/www/cgi-bin/webdav.conf';

## -- VIRTUAL_BASE
## only neccassary if you use redirects or rewrites 
## from a VIRTUAL_BASE to the DOCUMENT_ROOT
## regular expressions are allowed
## DEFAULT: $VIRTUAL_BASE = "";
$VIRTUAL_BASE = '(/webdav/|)';

## -- DOCUMENT_ROOT
## by default the server document root
## (don't forget a trailing slash '/'):
$DOCUMENT_ROOT = $ENV{DOCUMENT_ROOT}.'/';

## -- UMASK
## mask for file/folder creation 
## (it does not change permission of existing files/folders):
## DEFAULT: $UMASK = 0002; # read/write/execute for users and groups, others get read/execute permissions
$UMASK = 0022;

## -- MIMETYPES
## some MIME types for Web browser access and GET access
## you can add some missing types ('extension list' => 'mime-type'):
%MIMETYPES = (
	'html htm shtm shtml' => 'text/html',
	'css' => 'text/css', 'xml xsl'=>'text/xml',
	'js' => 'application/x-javascript',
	'asc txt text pot brf' => 'text/plain',
	'c'=> 'text/x-csrc', 'h'=>'text/x-chdr',
	'gif'=>'image/gif', 'jpeg jpg jpe'=>'image/jpeg', 
	'png'=>'image/png', 'bmp'=>'image/bmp', 'tiff'=>'image/tiff',
	'pdf'=>'application/pdf', 'ps'=>'application/ps',
	'dvi'=>'application/x-dvi','tex'=>'application/x-tex',
	'zip'=>'application/zip', 'tar'=>'application/x-tar','gz'=>'application/x-gzip',
	'doc dot' => 'application/msword',
	'xls xlm xla xlc xlt xlw' => 'application/vnd.ms-excel',
	'ppt pps pot'=>'application/vnd.ms-powerpoint',
	'pptx'=>'application/vnd.openxmlformats-officedocument.presentationml.presentation',
	'ics' => 'text/calendar',
	'avi' => 'video/x-msvideo', 'wmv' => 'video/x-ms-wmv', 'ogv'=>'video/ogg',
	'mpeg mpg mpe' => 'video/mpeg', 'qt mov'=>'video/quicktime',
	default => 'application/octet-stream',
	); 

## -- MIMEFILE
## optionally you can use a mime.types file instead of %MIMETYPES
## EXAMPLE: $MIMEFILE = '/etc/mime.types';
$MIMEFILE = '/etc/mime.types';

## -- FANCYINDEXING
## enables/disables fancy indexing for GET requests on folders
## if disabled you get a 404 error for a GET request on a folder
## DEFAULT: $FANCYINDEXING = 1;
$FANCYINDEXING = 1;

## -- MAXFILENAMESIZE 
## Web interface: width of filename column
$MAXFILENAMESIZE = 30;

## -- MAXLASTMODIFIEDSIZE
## Web interface: width of last modified column
$MAXLASTMODIFIEDSIZE = 20;

## -- MAXSIZESIZE
## Web interface: width of size column
$MAXSIZESIZE = 12;

## -- ICONS
## for fancy indexing (you need a server alias /icons to your Apache icons directory):
%ICONS = (
	'< .. >' => '/icons/back.gif',
	'<folder>' => '/icons/folder.gif',
	'text/plain' => '/icons/text.gif', 'text/html' => '/icons/text.gif',
	'application/zip'=> '/icons/compressed.gif', 'application/x-gzip'=>'/icons/compressed.gif',
	'image/gif'=>'/icons/image2.gif', 'image/jpg'=>'/icons/image2.gif',
	'image/png'=>'/icons/image2.gif', 
	'application/pdf'=>'/icons/pdf.gif', 'application/ps' =>'/icons/ps.gif',
	'application/msword' => '/icons/text.gif',
	'application/vnd.ms-powerpoint' => '/icons/world2.gif',
	'application/vnd.ms-excel' => '/icons/quill.gif',
	'application/x-dvi'=>'/icons/dvi.gif', 'text/x-chdr' =>'/icons/c.gif', 'text/x-csrc'=>'/icons/c.gif',
	'video/x-msvideo'=>'/icons/movie.gif', 'video/x-ms-wmv'=>'/icons/movie.gif', 'video/ogg'=>'/icons/movie.gif',
	'video/mpeg'=>'/icons/movie.gif', 'video/quicktime'=>'/icons/movie.gif',
	default => '/icons/unknown.gif',
);

## -- ICON_WIDTH
## specifies the icon width for the folder listings of the Web interface
## DEFAULT: $ICON_WIDTH = 18;
$ICON_WIDTH = 18;

## -- CSS
## defines a stylesheet added to the header of the Web interface
$CSS = <<EOS
input,select { text-shadow: 1px 1px white;  }
.header, .signature { border: 2px outset black; padding-left:3px;background-color:#eeeeee; margin: 2px 0px 2px 0px; }
.signature a { color: black; text-decoration: none; }
.search { text-align:right;font-size:0.8em;padding:2px 0 0 0;border:0;margin: 0px 0px 4px 0px; }
.search input { font-size: 0.8em; }


.errormsg, .notwriteable, .notreadable { background-color:#ffeeee; border: 1px solid #ff0000; padding: 0px 4px 0px 4px; }
.infomsg { background-color:#eeeeff; padding: 0px 4px 0px 4px; border: 1px solid #0000ff;}
#msg, .msg { left: 50%; padding: 15px; margin-left: -300px; top: 10px; position: fixed; text-align:center; width: 600px; z-index: 10; }
.msg { z-index: 8; }
.filtered_old { background-color: yellow; padding: 0px 4px 0px 4px; border: 1px solid black; }
.filtered { background-color: yellow; padding: 0px 4px 0px 4px; border: 1px solid black; }

.thumb { border:0px; vertical-align:top;padding: 1px 0px 1px 0px; }
.icon { border:0px; }

.foldername { font-weight: bold; font-size: 1.2em; border:0; padding:0; margin:0; display: inline; }
#quicknavpath { white-space: nowrap; }
.foldername img { border: 0; }
.foldername a { text-decoration: none; }
.davmount { font-size:0.8em;color:black; }
.hidden { display: none; }
.changedirform { display: inline; }
.bookmark { width: 15em; text-shadow: none; font-family: monospace;}
.bookmark .title { background-color: #aaaaaa; font-weight: bold; }
.bookmark .func { background-color: #cccccc; font-weight: bold; text-shadow: 1px 1px white;}
#addbookmark, #rmbookmark { font-size: 0.8em; border: 1px outset black; padding: 0px; margin: 0px; font-family: monospace; background-color: #dddddd; text-shadow: 1px 1px white; color: black; font-weight: bold; text-decoration: none;}

.masterhead { background-color: white; position: fixed; top: 0px; width: 99%; }
.folderview { padding-top: 110px; }

.sidebar { position: fixed; top: 120px; padding: 2px; background-color: white; z-index: 5;}
.sidebartable { width: 200px; }
.sidebartable.collapsed { width: 5px; }
.sidebarcontent { overflow: hidden; border: 1px solid #aaaaaa;}
.sidebaractionview { z-index: 8; position: fixed; height: auto; min-height: 100px; left: 220px; top: 120px; width: auto; min-width: 300px; max-width: 800px; visibility: hidden; background-color: #dddddd; padding: 2px; border: 1px solid #aaaaaa; overflow: auto;}
.sidebaractionview.collapsed { min-height: 0px; overflow: hidden; }
.sidebaractionview.move { cursor: move; opacity: 0.8; filter: Alpha(opacity=80); }
.sidebarfolderview { padding-top: 110px; padding-bottom: 50px; margin-left: 220px; }
.sidebarfolderview.full { margin-left: 30px; }
.sidebarheader { background-color: #aaaaaa; text-shadow: 1px 1px #eeeeee; padding: 2px; font-size: 0.9em;}
.sidebaractionviewheader { background-color: #bbbbbb; text-shadow: 1px 1px white; padding: 2px; font-size: 0.9em;}
.sidebaraction { border: none; padding: 1px; }
.sidebaraction input { border: none; background-color: white; margin: 0px; width: 98%; text-align: left;}
.sidebaraction.highlight, .sidebaraction.highlight input { background-color: #eeeeee; }
.sidebaraction.active, .sidebaraction.active input { background-color: #dddddd; }
.sidebaraction.active.highlight, .sidebaraction.active.highlight, .sidebaraction.highlight.active, .sidebaraction.highlight.active input { background-color: #cccccc; }
.sidebaractionviewaction { padding: 5px 2px 2px 2px; }
.sidebaractionviewaction.collapsed {visibility: hidden; height: 0px; }
.sidebartogglebutton { font-size: 0.8em; margin: 0px; padding:0px; border: 1px solid #aaaaaa; background-color:#eeeeee; width: 5px; height: 100px;}

.sidebarsignature { position: fixed; bottom:0px; left: 0px; width: 100%;  z-index: 1;}

.viewtools { display: inline; float:right; margin-top: 4px;  }
.up, .refresh { font-size: 0.8em; border: 1px outset black; padding: 2px; font-weight: bold; text-decoration: none; color: black; background-color: #dddddd; text-shadow: 1px 1px white;}

.quota { padding-left:30px;font-size:0.8em; }

.pagenav, .showall { font-weight: bold; font-size:0.9em;padding: 2px 0px 2px 0px; text-align: center; background-color: #efefef;}
.pagenav a, .showall a { text-decoration: none;}

.filelist a { text-decoration: none; }
.filelist { width:100%;font-family:monospace;border:0; border-spacing:0; padding:2px; font-size: 0.9em; clear: both;}
.filelist .tr_odd { background-color: white; }
.filelist .tr_even { background-color: #eeeeee; }
.filelist .tr_up, .filelist .tr_even, .filelist .tr_odd {  cursor: pointer; }
.filelist .tr_selected { background-color: #ffeedd; }
.filelist .tr_highlight { background-color: #aaaaaa; }
.filelist .tr_even.tr_selected { background-color: #eeddcc; }
.filelist .tr_even.tr_selected.tr_highlight { background-color: #aa9988; }
.filelist .tr_odd.tr_selected.tr_highlight { background-color: #aa9988; }
.filelist .tr_odd.tr_cut, .filelist .tr_odd.tr_cut a { color: #8899aa; }
.filelist .tr_even.tr_cut, .filelist .tr_even.tr_cut a { color: #aabbcc;}
.filelist .tr_odd.tr_copy, .filelist .tr_odd.tr_copy a { color: #224466; }
.filelist .tr_even.tr_copy, .filelist .tr_even.tr_copy a { color: #113355; }
.filelist td { border-right: 1px dotted #aaaaaa; border-bottom: 1px solid #aaaaaa; padding: 1px 4px 1px 4px; }
.filelist .tc_lm  { white-space: nowrap;}
.th { cursor: pointer; font-weight: bold; background-color: #dddddd; }
.th_sel { width:1em; }
.th_fn a, .th_lm a, .th_size a, .th_perm a, .th_mime a { white-space: nowrap; color: black; text-decoration: none; text-shadow: 1px 1px white; }
.th_highlight { background-color: #bcbcbc; border: 1px inset black; }
.th_size, .th_perm, .tc_size, .tc_perm { text-align:right; }
.tr_up { background-color: white; }
.groupwriteable { color: darkred; }
.otherwriteable { color: red; }


.folderstats, .resultcount, .results { font-size:0.8em; }
.clipboard { float:left; margin-right: 30px; }
.copybutton,.cutbutton,.pastebutton { margin: 0px 5px 0px 5px; }
.namefilter { display: inline; }
.namefiltermatches { display: inline; font-size: 0.9em; font-weight: normal; border: none; background-color: #efefef; white-space: nowrap;}
.functions { float: right; padding: 0px 5px 0px 20px;}
fieldset { clear: both; }

.rmuploadfield { text-decoration: none; margin: 4px; font-family: monospace; padding: 1px; border: 1px outset black; text-shadow: 1px 1px white; background-color: #dddddd; color: black;}

.toggle { cursor:pointer; border: 1px outset black; font-family: monospace; padding: 0px 4px 1px 3px; margin: 0px 2px 0px 2px; }
legend {  font-size: 0.8em; font-weight: bold; margin: 5px 0px 2px 0px; padding: 0px; }

.props { width:100%;table-layout:fixed; }
.props .trhead { background-color:#dddddd;text-align:left; }
.props .thname { width:25%; }
.props .thvalue { width:75%; }
.props tr { text-align: left; }
.props .tr_odd { background-color: white; }
.props .tr_even { background-color: #eeeeee; }
.props .tdname { font-weight: bold; vertical-align: top; }
.props .tdvalue { vertical-align: bottom; }
.props .tdvalue pre { margin:0px; overflow:auto; }

.afsacltable th, .afsacltable td { border-bottom: 1px solid black; border-right: 1px dotted black; margin: 0px; padding: 1px;}
.afssavebutton { text-align: right; }

.afsgroupmanager td { vertical-align: top; padding: 5px; border-right: 1px solid black; border-bottom: 1px solid black; }
EOS
;

## -- CSSURI
## additional CSS file to include in the Web interface after $CSS
# $CSSURI='/mystyle.css';

## -- HTMLHEAD
## additional data included in the HTML <head> tag after $CSS/$CSSURI of the Web interface
#$HTMLHEAD = "";


## -- FORBIDDEN_UID
## a comman separated list of UIDs to block 
## (process id of this CGI will be checked against this list)
## common "forbidden" UIDs: root, Apache process owner UID
## DEFAULT: @FORBIDDEN_UID = ( 0 );
@FORBIDDEN_UID = ( 0 );

## -- HIDDEN 
## hide some special files/folders (GET/PROPFIND) 
## EXAMPLES: @HIDDEN = ( '\.DAV/?$', '~$', '\.bak$' );
@HIDDEN = ('/\.ht','/\.DAV');

## -- ALLOW_INFINITE_PROPFIND
## enables/disables infinite PROPFIND requests
## if disabled the default depth is set to 0
$ALLOW_INFINITE_PROPFIND = 1;

## -- ALLOW_FILE_MANAGEMENT
## enables file management with a web browser
## ATTENTATION: locks will be ignored
$ALLOW_FILE_MANAGEMENT = 1;

## -- ALLOW_SEARCH
## enable file/folder search in the Web interface
$ALLOW_SEARCH = 1;

## -- ALLOW_ZIP_UPLOAD
## enable zip file upload (incl. extraction)
$ALLOW_ZIP_UPLOAD = 1;

## -- ALLOW_ZIP_DOWNLOAD
## enable zip file download 
$ALLOW_ZIP_DOWNLOAD = 1;

## -- ENABLE_CLIPBOARD
## enables cut/copy/paste buttons and actions in the Web interface
$ENABLE_CLIPBOARD = 1;

## -- ENABLE_NAMEFILTER
## enables file/folder name filtering on the current folder in the Web interface
$ENABLE_NAMEFILTER = 1;

## -- SHOW_STAT
## shows file statistics after file/folder list in the Web interface
$SHOW_STAT = 1;

## -- PAGE_LIMIT
## limits number of files/folders shown in the Web interface
## EXAMPLE: $PAGE_LIMIT = 20;
$PAGE_LIMIT=15;

## -- PAGE_LIMITS
## allowed selectable limits (-1 = show all)
## EXAMPLE: @PAGE_LIMISTS = ( 5, 10, 15, 20, 30, 50, -1);
@PAGE_LIMITS = ( 5, 10, 15, 20, 30, 50, -1);

## -- ENABLE_BOOKMARKS
## enables bookmark support in the Web interface (cookie/javascript based)
## EXAMPLE: $ENABLE_BOOKMARKS = 1;
$ENABLE_BOOKMARKS = 1;

## -- ENABLE_PROPERTIES_VIEWER
## EXAMPLE: $ENABLE_PROPERTIES_VIEWER
$ENABLE_PROPERTIES_VIEWER = 0;

## -- ENABLE_SIDEBAR
## enables the sidebar view; you get the classic view only if you disable this:
## EXAMPLE: $ENABLE_SIDEBAR = 1;
$ENABLE_SIDEBAR = 1;

## -- VIEW
## defines the default view (sidebar or classic)
$VIEW = 'sidebar';

## -- ALLOW_POST_UPLOADS
## enables a upload form in a fancy index of a folder (browser access)
## ATTENTATION: locks will be ignored
## Apache configuration:
## DEFAULT: $ALLOW_POST_UPLOADS = 1;
$ALLOW_POST_UPLOADS = 1;

## -- POST_MAX_SIZE
## maximum post size (only POST requests)
## EXAMPLE: $POST_MAX_SIZE = 1073741824; # 1GB
$POST_MAX_SIZE = 1073741824;
#$POST_MAX_SIZE = 10240000;

## -- SHOW_QUOTA
## enables/disables quota information for fancy indexing
## DEFAULT: $SHOW_QUOTA = 0;
$SHOW_QUOTA = 1;

## -- SHOW_PERM
## show file permissions
## DEFAULT: $SHOW_PERM = 0;
$SHOW_PERM = 1;

## -- SHOW_MIME
## show mime type
## DEFAULT: $SHOW_MIME= 0;
$SHOW_MIME= 1;

## -- ALLOW_CHANGEPERM
## allow users to change file permissions
## DEFAULT: ALLOW_CHANGEPERM = 0;
$ALLOW_CHANGEPERM = 1;

## -- ALLOW_CHANGEPERMRECURSIVE
## allow users to change file/folder permissions recursively
$ALLOW_CHANGEPERMRECURSIVE = 1;

## -- PERM_USER
# if ALLOW_CHANGEPERM is set to 1 the PERM_USER variable 
# defines the file/folder permissions for user/owner allowed to change
# EXAMPLE: $PERM_USER = [ 'r','w','x','s' ];
$PERM_USER = [ 'r','w','x','s' ];

## -- PERM_GROUP
# if ALLOW_CHANGEPERM is set to 1 the PERM_GROUP variable 
# defines the file/folder permissions for group allowed to change
# EXMAMPLE: $PERM_GROUP = [ 'r','w','x','s' ];
$PERM_GROUP = [ 'r','w','x','s' ];

## -- PERM_OTHERS
# if ALLOW_CHANGEPERM is set to 1 the PERM_OTHERS variable 
# defines the file/folder permissions for other users allowed to change
# EXAMPLE: $PERM_OTHERS = [ 'r','w','x','t' ];
$PERM_OTHERS = [ 'r','w','x','t' ];

## -- LANGSWITCH
## a simple language switch
$LANGSWITCH = '<div style="font-size:0.6em;text-align:right;border:0px;padding:0px;"><a href="?lang=default">[EN]</a> <a href="?lang=de">[DE]</a></div>';

## -- HEADER
## content after body tag in the Web interface
$HEADER = '<div class="header">WebDAV CGI - Web interface: You are logged in as <span title="'.`id -a`.'">'.($ENV{REDIRECT_REMOTE_USER}||$ENV{REMOTE_USER}).'</span>.</div>';

## -- SIGNATURE
## for fancy indexing
## EXAMPLE: $SIGNATURE=$ENV{SERVER_SIGNATURE};
$SIGNATURE = '&copy; ZE CMS, Humboldt-Universit&auml;t zu Berlin | Written 2010 by <a href="http://webdavcgi.sf.net/">Daniel Rohde</a>';

## -- LANG
## defines the default language for the Web interface
## see %TRANSLATION option for supported languages
## DEFAULT: $LANG='default';
$LANG = 'default';
#$LANG = 'de';

## -- TRANSLATION
## defines text and tooltips for the Web interface
## if you add your own translation you don't need to translate all text keys
## (there is a fallback to the default)
## Don't use entities like &auml; for buttons and table header (names, lastmodified, size, mimetype).
%TRANSLATION = ( 'default' => 
			{
				search => 'Search for file/folder name:', searchtooltip => 'allowed are: file/folder name, regular expression',
				searchnothingfound => 'Nothing found for ', searchgoback =>' in ',
				searchresultsfor => ' search results for ', searchresultfor => ' search result for ',
				searchresults => ' results in', searchresult => ' result in',
				mount => '[M]', mounttooltip => 'View this collection in your WebDAV client (WebDAV mount).',
				quotalimit => 'Quota limit: ', quotaused => ' used: ', quotaavailable => ' available: ',
				navpage => 'Page ', navfirst=>' |&lt; ', navprev=>' &lt;&lt; ', navnext=>' &gt;&gt; ', navlast=>' &gt;| ', 
				navall=>'All', navpageview=>'View by page',
				navfirstblind=>' |&lt; ', navprevblind=>' &lt;&lt; ', navnextblind=>' &gt;&gt; ', navlastblind=>' &gt;| ', 
				navfirsttooltip=>'First Page', navprevtooltip=>'Previous Page', 
				navnexttooltip=>'Next Page', navlasttooltip=>'Last Page', navalltooltip=>'Show All',
				togglealltooltip=>'Toggle All', showproperties=>'Show Properties',
				properties=>' properties', propertyname=>'Name', propertyvalue=>'Value',
				names => 'Files/Folders', lastmodified => 'Last Modified', size => 'Size', mimetype => 'MIME Type',
				lastmodifiedformat => '%m/%d/%y %r',
				statfiles => 'files:', statfolders=> 'folders:', statsum => 'sum:', statsize => 'size:',
				createfoldertext => 'Create new folder: ', createfolderbutton => 'Create Folder',
				movefilestext => 'Rename/Move selected files/folders to: ', movefilesbutton => 'Rename/Move',
				movefilesconfirm => 'Do you really want to rename/move selected files/folders to the new file name or folder?',
				deletefilesbutton => 'Delete', deletefilestext => ' selected files/folders',
				deletefilesconfirm => 'Do you really want to delete selected files/folders?',
				zipdownloadbutton => 'Download', zipdownloadtext => ' selected files/folders (zip archive)',
				zipuploadtext => 'Upload zip archive: ', zipuploadbutton => 'Upload & Extract',
				zipuploadconfirm => 'Do you really want to upload zip, extract it and replace existing files?',
				fileuploadtext => 'File: ', fileuploadbutton=> 'Upload', fileuploadmore =>'more files',
				fileuploadconfirm =>'Do you really want to upload file(s) and replace existing file(s)?',
				confirm => 'Please confirm.',
				foldernotwriteable => 'This folder is not writeable (no write permission).',
				foldernotreadable=> 'This folder is not readable (no read permission).',
				msg_deletedsingle => '%s file/folder was deleted.',
				msg_deletedmulti => '%s files/folders were deleted.',
				msg_deleteerr => 'Could not delete selected files/folders.',
				msg_deletenothingerr => 'Please select file(s)/folder(s) to delete.',
				msg_foldercreated=>'Folder \'%s\' was created successfully.',
				msg_foldererr=>'Could not create folder \'%s\' (%s).',
				msg_foldernothingerr=>'Please specify a folder to create.',
				msg_rename=>'Moved files/folders \'%s\' to \'%s\'.',
				msg_renameerr=>'Could not move files/folders \'%s\' to \'%s\'.',
				msg_renamenothingerr=>'Please select files/folders to rename/move.',
				msg_renamenotargeterr=>'Please specify a target folder/name for move/rename.',
				msg_uploadsingle=>'%s file (%s) uploaded successfully.',
				msg_uploadmulti=>'%s files (%s) uploaded successfully.',
				msg_uploadnothingerr=>'Please select a local file (Browse ...) for upload.',
				msg_zipuploadsingle=>'%s zip archive (%s) uploaded successfully.',
				msg_zipuploadmulti=>'%s zip archives (%s) uploaded successfully.',
				msg_zipuploadnothingerr=>'Please select a local zip archive (Browse...) for upload.',
				clickforfullsize=>'Click for full size',
				permissions=>'Permissions', user=>'user:', group=>'group:', others=>'others:',
				recursive=>'recursive', changefilepermissions=>'Change file permissions: ', changepermissions=>'Change',
				readable=>'r', writeable=>'w', executable=>'x', sticky=>'t', setuid=>'s', setgid=>'s',
				add=>'add (+)', set=>'set (=)', remove=>'remove (-)',
				changepermconfirm=>'Do you really want to change file/folder permissions for selected files/folders?',
				msg_changeperm=>'Changed file/folder permissions successfully.',
				msg_chpermnothingerr=>'Please select files/folders to change permissions.',
				changepermlegend=>'r - read, w - write, x - execute, s - setuid/setgid, t - sticky bit',
				created=>'created',
				folderisfiltered=>'This folder is filtered (regex: %s).',
				webdavfolderisfiltered=>'',
				copy=>'Copy', cut=>'Cut', paste=>'Paste',
				msg_copysuccess => 'File(s)/Folder(s) %s copied.', msg_cutsuccess=>'File(s)/Folder(s) %s moved.',
				msg_copyfailed=>'File(s)/Folder(s) %s not copied.', msg_cutfailed=>'File(s)/Folder(s) %s not moved.',
				management=>'File/Folder Management', files=>'Files/Folders', zip=>'ZIP File Upload/Download', upload=>'File Upload',
				afs=>'AFS ACL Manager', afsnormalrights=>'Normal Rights', afsnegativerights=>'Negative Rights', afssaveacl=>'Save Permissions',
				afslookup=>'lookup', afsread=>'read', afswrite=>'write', afsinsert=>'insert', afsdelete=>'delete', afslock=>'lock', afsadmin=>'admin',
				msg_afsaclchanged=>'AFS ACLs changed.', msg_afsaclnotchanged=>'AFS ACLs not changed: %s',
				afsgroup=>'AFS Group Manager', afsgroups=>'Groups owned by %s', afsgrpusers=>'Members of group \'%s\'',
				afschangegroup=>'Manage Members', afscreatenewgroup=>'Create Group', afsrenamegroup=>'Rename Selected Group',
				afsdeletegroup=>'Delete Selected Group', afsadduser=>'Add Member(s)', afsremoveuser=>'Remove Selected Member(s)',
				msg_afsgrpnothingsel => 'You should select a group.', msg_afsgrpdeleted => 'Selected group \'%s\' deleted.',
				msg_afsgrpcreated =>  'Group \'%s\' created.',
				msg_afsgrpnogroupnamegiven => 'Please give me a group name.', msg_afsnonewgroupnamegiven=>'Please give me the new group name for \'%s\'.',
				msg_afsusrnothingsel=>'Please select users.', msg_afsuserremoved=>'Selected user(s) \'%s\' removed from \'%s\'.',
				msg_afsuseradded=>'New user(s) \'%s\' added to \'%s\'.', msg_afsnousersgiven=>'Please give me a space separated list of users to add to \'%s\'.',
				msg_afsusrremovefailed=>'Could not remove member(s) \'%s\' from \'%s\': \'%s\'', msg_afsadduserfailed =>'Could not add member(s) \'%s\' to \'%s\': \'%s\'',
				msg_afsgrpdeletefailed => 'Could not remove selected group \'%s\': \'%s\'', msg_afsgrpcreatefailed => 'Could not create group \'%s\': \'%s\'',
				msg_afsgrprenamed => 'Group \'%s\' renamed to \'%s\'.', msg_afsgrprenamefailed => 'Could not rename group \'%s\' to \'%s\': \'%s\'',
				afsconfirmdeletegrp => 'Do you really want to delete selected group?', afsconfirmcreategrp=>'Do you really want to create a new group?',
				afsconfirmrenamegrp => 'Do you really want to rename selected group?', afsconfirmremoveuser=>'Do you really want to remove selected users from group?',
				afsconfirmadduser=>'Do you really want to add new user(s) to group?',
				afsaclscurrentfolder=>'ACLs of the current folder <code>%s</code> <br/> (<code>%s</code>):',
				afsaclhelp => '  ', afsgrouphelp=>'  ',
				clickchangessort=>'Click here to change sort.',
				msg_uploadforbidden=>'Sorry, it\'s not possible to upload file(s) "%s" (wrong permissions?)',
				changedir=>'Change Location', go=>'Go', cancel=>'Cancel',
				bookmarks=>'-- Bookmarks --',
				addbookmark=>'Add', addbookmarktitle=>'Add current folder to bookmarks',
				rmbookmark=>'Remove', rmbookmarktitle=>'Remove current folder from bookmarks', 
				rmallbookmarks=>'-- Remove All --', rmallbookmarkstitle=>'Remove all bookmarks',
				sortbookmarkbypath=>'Sort By Path', sortbookmarkbytime=>'Sort By Date',
				up=>'Go Up &uarr;', uptitle=>'Go up one folder level', refresh=>'Refresh', refreshtitle=>'Refresh page view',
				rmuploadfield=>'-', rmuploadfieldtitle=>'Remove upload field',
				namefilter=>'Filter: ', namefiltertooltip=>'filter current folder', namefiltermatches=>'Match(es): ',
				copytooltip=>'Add files/folders to clipboard for copy operation', cuttooltip=>'Add files/folders to clipboard for move operation',
				pagelimit=>'Show: ', pagelimittooltip=>'Show per page ...',
				togglesidebar=>'Toggle Sidebar',
				viewoptions=>'View Options', classicview =>'Classic View', sidebarview=>'Sidebar View',
			},
		'de' => 
			{
				search => 'Suche nach Datei-/Ordnernamen:', searchtooltip => 'Namen und reguläre Ausdrücke',
				searchnothingfound => 'Es wurde nichts gefunden für ', searchgoback =>' in ',
				searchresultsfor => ' Suchergebnisse für ', searchresultfor => ' Suchergebniss für ',
				searchresults => ' Suchergebnisse in', searchresult => ' Suchergebniss in',
				mount => '[M]', mounttooltip => 'Klicken Sie hier, um diesen Ordner in Ihrem lokalen WebDAV-Clienten anzuzeigen.',
				quotalimit => 'Quota-Limit: ', quotaused => ' verwendet: ', quotaavailable => ' verf&uuml;gbar: ',
				navpage => 'Seite ', navall=>'Alles', navpageview=>'Seitenweise anzeigen',
				navfirsttooltip=>'Erste Seite', navprevtooltip=>'Vorherige Seite',
				navnexttooltip=>'Nächste Seite', navlasttooltip=>'Letzte Seite', navalltooltip=>'Zeige alles auf einer Seite',
				togglealltooltip=>'Auswahl umkehren', showproperties=>'Datei/Ordner-Attribute anzeigen',
				properties=>' Attribute', propertyname=>'Name', propertyvalue=>'Wert',
				names => 'Dateien/Ordner', lastmodified => 'Letzte Änderung', size => 'Größe', mimetype => 'MIME Typ',
				lastmodifiedformat => '%d.%m.%Y %H:%M:%S Uhr',
				statfiles => 'Dateien:', statfolders=> 'Ordner:', statsum => 'Gesamt:', statsize => 'Größe:',
				createfoldertext => 'Ordnername: ', createfolderbutton => 'Ordner anlegen',
				movefilestext => 'Ausgewählte Dateien nach: ', movefilesbutton => 'Umbenennen/Verschieben',
				movefilesconfirm => 'Wollen Sie wirklich die ausgewählte(n) Datei(en)/Ordner umbenennen/verschieben?',
				deletefilesbutton => 'Löschen', deletefilestext => 'aller ausgewählten Dateien/Ordner',
				deletefilesconfirm => 'Wollen Sie wirklich alle ausgewählten Dateien/Ordner löschen?',
				zipdownloadbutton => 'Herunterladen', zipdownloadtext => ' aller ausgewählten Dateien und Ordner als ZIP-Archiv.',
				zipuploadtext => 'Ein ZIP-Archiv: ', zipuploadbutton => 'hochladen & auspacken.',
				zipuploadconfirm => 'Wollen Sie das ZIP-Archiv wirklich hochladen, auspacken und damit alle existierenden Dateien ersetzen?',
				fileuploadtext => 'Datei: ', fileuploadbutton=> 'Hochladen', fileuploadmore =>'mehrere Dateien hochladen',
				fileuploadconfirm =>'Wollen Sie wirklich die Datei(en) hochladen und existierenende Dateien ggf. ersetzen?',
				confirm => 'Bitte bestätigen Sie.',
				foldernotwriteable => 'In diesem Ordner darf nicht geschrieben werden (fehlende Zugriffsrechte).',
				foldernotreadable=> 'Dieser Ordner ist nicht lesbar (fehlende Zugriffsrechte).',
				msg_deletedsingle => '%s Datei/Ordner gelöscht.',
				msg_deletedmulti => '%s Dateien/Ordner gelöscht.',
				msg_deleteerr => 'Konnte die ausgewählten Dateien/Ordner nicht löschen.',
				msg_deletenothingerr => 'Bitte wählen Sie die zu löschenden Dateien/Ordner aus.',
				msg_foldercreated=>'Der Ordner "%s" wurde erfolgreich angelegt.',
				msg_foldererr=>'Konnte den Ordner "%s" nicht anlegen (%s).',
				msg_foldernothingerr=>'Bitte geben Sie einen Ordner an, der angelegt werden soll.',
				msg_rename=>'Die Dateien/Ordner "%s" wurden nach "%s" verschoben.',
				msg_renameerr=>'Konnte die gewählten Dateien/Ordner "%s" nicht nach "%s" verschieben.',
				msg_renamenothingerr=>'Bitte wählen Sie Dateien/Ordner aus, die ubenannt bzw. verschoben werden sollen.',
				msg_renamenotargeterr=>'Bitte geben Sie einen Ziel-Order/-Dateinamen an:',
				msg_uploadsingle=>'%s Datei (%s) wurde erfolgreich hochgeladen.',
				msg_uploadmulti=>'%s Dateien (%s) wurden erfolgreich hochgeladen.',
				msg_uploadnothingerr=>'Bitte wählen Sie lokale Dateien zum Hochladen aus.',
				msg_zipuploadsingle=>'%s zip-Archiv (%s) wurde erfolgreich hochgeladen.',
				msg_zipuploadmulti=>'%s zip-Archive (%s) wurden erfolgreich hochgeladen.',
				msg_zipuploadnothingerr=>'Bitte wählen Sie ein lokales Zip-Archiv zum Hochladen aus.',
				clickforfullsize=>'Für volle Grösse anklicken',
				permissions=>'Rechte', user=>'Benutzer:', group=>'Gruppe:', others=>'Andere:',
				recursive=>'rekursiv', changefilepermissions=>'Datei-Rechte ändern: ', changepermissions=>'ändern',
				readable=>'r', writeable=>'w', executable=>'x', sticky=>'t', setuid=>'s', setgid=>'s', 
				add=>'hinzufügen (+)', set=>'setzen (=)', remove=>'entfernen (-)',
				changepermconfirm=>'Wolle Sie wirklich die Datei/Ordner-Rechte für die gewählten Dateien/Ordner ändern?',
				msg_changeperm=>'Datei/Ordner-Rechte erfolgreich geändert.',
				msg_chpermnothingerr=>'Sie haben keine Dateien/Ordner ausgewählt, für die die Rechte geändert werden sollen.',
				changepermlegend=>'r - lesen, w - schreiben, x - ausführen, s - setuid/setgid, t - sticky bit',
				created=>'erzeugt am',
				folderisfiltered=>'Dieser Ordner-Inhalt wird gefiltert (Regex-Filter: %s).',
				copy=>'Kopieren', cut=>'Ausschneiden', paste=>'Einfügen',
				msg_copysuccess => 'Dateien/Ordner %s kopiert.', msg_cutsuccess=>'Datei(en)/Ordner %s verschoben.',
				msg_copyfailed=>'Dateien/Ordner %s nicht kopiert.', msg_cutfailed=>'Dateien/Ordner %s nicht verschoben.',
				management=>'Dateien/Ordner-Verwaltung', files=>'Dateien/Ordner', zip=>'ZIP File Upload/Download', upload=>'Datei(en) Hochladen',
				afs=>'AFS ACL Manager', afsnormalrights=>'Normale Rechte', afsnegativerights=>'Negative Rechte', afssaveacl=>'Rechte Speichern',
				msg_afsaclchanged=>'AFS ACLs geändert.', msg_afsaclnotchanged=>'AFS ACLs nicht geändert: %s',
				afsgroup=>'AFS Group Manager', afsgroups=>'Gruppen von %s', afsgrpusers=>'Mitglieder der Gruppe \'%s\'',
				afschangegroup=>'Mitglieder verwalten', afscreatenewgroup=>'Gruppe erzeugen', afsrenamegroup=>'Gruppe umbenennen',
				afsdeletegroup=>'Gruppe löschen', afsadduser=>'Mitglied(er) hinzufügen', afsremoveuser=>'Mitglied(er) entfernen',
				msg_afsgrpnothingsel => 'Bitte wählen Sie eine Gruppe.', msg_afsgrpdeleted => 'Gruppe \'%s\' gelöscht.',
				msg_afsgrpcreated =>  'Gruppe \'%s\' erzeugt.',
				msg_afsgrpnogroupnamegiven => 'Bitte geben Sie einen Gruppennamen ein.', msg_afsnonewgroupnamegiven=>'Bitte geben Sie den neuen Gruppennamen für \'%s\' ein.',
				msg_afsusrnothingsel=>'Bitte wählen Sie mindestens ein Mitglied.', msg_afsuserremoved=>'Ausgewählte(n) Benutzer \'%s\' aus der Gruppe \'%s\' entfernt.',
				msg_afsuseradded=>'Neue(n) Benutzer \'%s\' zur Gruppe \'%s\' hinzugefügt.', msg_afsnousersgiven=>'Bitte geben Sie eine mit Leerzeichen getrennte Liste von Benutzernamen ein, die zur Gruppe \'%s\' hinzugefügt werden sollen.',
				msg_afsusrremovefailed=>'Konnte das/die Mitglied(er) \'%s\' aus der Gruppe \'%s\' nicht entfernen: \'%s\'', msg_afsadduserfailed =>'Konnte das/die Mitglied(er) \'%s\' nicht zur Gruppe \'%s\' hinzufügen: \'%s\'',
				msg_afsgrpdeletefailed => 'Konnte die gewählte Gruppe \'%s\' nicht löschen: \'%s\'', msg_afsgrpcreatefailed => 'Konnte die Gruppe \'%s\' nicht erzeugen: \'%s\'',
				msg_afsgrprenamed => 'Gruppe \'%s\' nach \'%s\' umbenannt.', msg_afsgrprenamefailed => 'Konnte die Gruppe \'%s\' nicht nach \'%s\' umbenennen: \'%s\'',
				afsconfirmdeletegrp => 'Wollen Sie wirklich die ausgewählte Gruppe löschen?', afsconfirmcreategrp=>'Wollen Sie wirklich eine neue Gruppe erzeugen?',
				afsconfirmrenamegrp => 'Wollen Sie wirklich die ausgewählte Gruppe umbenennen?', afsconfirmremoveuser=>'Wollen Sie wirklich die ausgewählten Benutzer aus der Gruppe entfernen?',
				afsconfirmadduser=>'Wollen Sie wirklich neue Benutzer zur Gruppe hinzufügen?',
				afsaclscurrentfolder=>'ACLs für den aktuellen Ordner <code>%s</code><br/> (<code>%s</code>):',
				afsaclhelp => '  ', afsgrouphelp=>'  ',
				clickchangessort=>'Klicken, um Sortierung zu ändern.',
				msg_uploadforbidden=>'Sorry, die Datei(en) "%s" kann/können nicht hochgeladen werden (fehlende Rechte?)',
				changedir=>'Verzeichnis wechseln', go=>'Wechseln', cancel=>'Abbrechen',
				bookmarks=>'-- Lesezeichen --',
				addbookmark=>'Hinzufügen', addbookmarktitle=>'Aktuellen Ordner zu Lesezeichen hinzufügen',
				rmbookmark=>'Entfernen', rmbookmarktitle=>'Aktuellen Ordner aus Lesezeichen entfernen', 
				rmallbookmarks=>'-- Alle Entfernen --', rmallbookmarkstitle=>'Alle Lesenzeichen entfernen',
				sortbookmarkbypath=>'Nach Pfad ordnen', sortbookmarkbytime=>'Nach Datum ordnen',
				up=>'Eine Ebene höher &uarr;', uptitle=>'Eine Ordnerebene höher gehen', refresh=>'Aktualisieren', refreshtitle=>'Ordneransicht aktualisieren',
				rmuploadfield=>'-', rmuploadfieldtitle=>'Datei-Feld entfernen',
				namefilter=>'Filter: ', namefiltertooltip=>'aktuelle Datei/Ordner-Liste filtern', namefiltermatches=>'Treffer: ',
				copytooltip=>'Dateien/Ordner zum Kopieren in die Zwischenablage ablegen', cuttooltip=>'Dateien/Ordner zum Verschieben in die Zwischenablage ablegen',
				pagelimit=>'Zeige: ', pagelimittooltip=>'Zeige pro Seite ...',
				togglesidebar=>'Sidebar anzeigen/verstecken',
				viewoptions=>'Ansicht', classicview =>'Klassische Ansicht', sidebarview=>'Sidebar Ansicht',
			},

		);
$TRANSLATION{'de_DE'} = $TRANSLATION{de};
$TRANSLATION{'de_DE.UTF8'} = $TRANSLATION{de};

## -- ORDER
##  sort order for a folder list (allowed values: name, lastmodified, size, mode, mime, and this values with a _desc suffix)
## DEFAULT: $ORDER = 'name';
$ORDER = 'name';

## -- DBI_(SRC/USER/PASS)
## database setup for LOCK/UNLOCK/PROPPATCH/PROPFIND data
## EXAMPLE: $DBI_SRC='dbi:SQLite:dbname=/tmp/webdav.'.($ENV{REDIRECT_REMOTE_USER}||$ENV{REMOTE_USER}).'.db';
## ATTENTION: if users share the same folder they should use the same database. The example works only for users with unshared folders and $CREATE_DB should be enabled.
$DBI_SRC='dbi:SQLite:dbname=/tmp/webdav.'.($ENV{REDIRECT_REMOTE_USER}||$ENV{REMOTE_USER}).'.db';
$DBI_USER="";
$DBI_PASS="";

## enables persitent database connection (only usefull in conjunction with mod_perl, Speedy/PersistenPerl)
$DBI_PERSISTENT = 0;

## -- CREATE_DB
## if set to 1 this script creates the database schema ($DB_SCHEMA)
## performance hint: if the database schema exists set CREATE_DB to 0
## DEFAULT: $CREATE_DB = 1;
$CREATE_DB = 1;

## -- DB_SCHEMA
## database schema (works with SQlite3)
## for MySQL 5.x: remove 'IF NOT EXISTS' for all 'CREATE INDEX' statements and if the schema exists set $CREATE_DB to 0
## WARNING!!! do not use a unique index 
@DB_SCHEMA = (
	'CREATE TABLE IF NOT EXISTS webdav_locks (basefn VARCHAR(255) NOT NULL, fn VARCHAR(255) NOT NULL, type VARCHAR(255) NOT NULL, scope VARCHAR(255), token VARCHAR(255) NOT NULL, depth VARCHAR(255) NOT NULL, timeout VARCHAR(255) NULL, owner TEXT NULL, timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP)',
	'CREATE TABLE IF NOT EXISTS webdav_props (fn VARCHAR(255) NOT NULL, propname VARCHAR(255) NOT NULL, value TEXT)',
	'CREATE INDEX IF NOT EXISTS webdav_locks_idx1 ON webdav_locks (fn)',
	'CREATE INDEX IF NOT EXISTS webdav_locks_idx2 ON webdav_locks (basefn)',
	'CREATE INDEX IF NOT EXISTS webdav_locks_idx3 ON webdav_locks (fn,basefn)',
	'CREATE INDEX IF NOT EXISTS webdav_locks_idx4 ON webdav_locks (fn,basefn,token)',
	'CREATE INDEX IF NOT EXISTS webdav_props_idx1 ON webdav_props (fn)',
	'CREATE INDEX IF NOT EXISTS webdav_props_idx2 ON webdav_props (fn,propname)',
	);

## -- DEFAULT_LOCK_OWNER
## lock owner if not given by client
## EXAMPLE: $DEFAULT_LOCK_OWNER=$ENV{REMOTE_USER}.'@'.$ENV{REMOTE_ADDR}; ## loggin user @ ip
$DEFAULT_LOCK_OWNER= { href=> ($ENV{REDIRECT_REMOTE_USER}||$ENV{REMOTE_USER}).'@'.$ENV{REMOTE_ADDR} };

## -- CHARSET
## change it if you get trouble with special characters
## DEFAULT: $CHARSET='utf-8';
$CHARSET='utf-8';
# and Perl's UTF-8 pragma for the right string length:
# use utf8;
# no utf8;

## -- BUFSIZE
## buffer size for read and write operations
# EXAMPLE: $BUFSIZE = 1073741824;
$BUFSIZE = 1048576;

## -- LOGFILE
## simple log for file/folder modifications (PUT/MKCOL/DELETE/COPY/MOVE)
## EXAMPLE: $LOGFILE='/tmp/webdavcgi.log';
# $LOGFILE='/tmp/webdavcgi.log';

## -- GFSQUOTA
## if you use a GFS/GFS2 filesystem and if you want quota property support set this variable
## EXAMPLE: $GFSQUOTA='/usr/sbin/gfs2_quota -f';
#$GFSQUOTA='/usr/sbin/gfs_quota -f';

## -- ENABLE_AFS
## enables AFS support
# $ENABLE_AFS = 1;

## -- AFSQUOTA
## if you use a AFS filesystem and if you want quota property support set this variable
## EXAMPLE: $GFSQUOTA='/usr/sbin/gfs2_quota -f';
#$AFSQUOTA='/usr/bin/fs listquota';

## -- AFS_FSCMD
## file path for the fs command to change acls
## EXAMPLE: $AFS_FSCMD='/usr/bin/fs';
$AFS_FSCMD='/usr/bin/fs';

## -- ENABLE_AFSACLMANAGER
## enables AFS ACL Manager for the Web interface
## EXAMPLE: $ENABLE_AFSACLMANAGER = 1;
$ENABLE_AFSACLMANAGER = $ENABLE_AFS;

## -- ALLOW_AFSACLCHANGES
## allows AFS ACL changes. if disabled the AFS ACL Manager shows only the ACLs of a folder.
## EXAMLE: $ALLOW_AFSACLCHANGES = 1;
$ALLOW_AFSACLCHANGES = $ENABLE_AFS;

## -- PROHIBIT_AFS_ACL_CHANGES_FOR
## prohibits AFS ACL changes for listed users/groups
## EXAMPLE: @PROHIBIT_AFS_ACL_CHANGES_FOR = ( 'system:backup', 'system:administrators' );
@PROHIBIT_AFS_ACL_CHANGES_FOR = ( 'system:backup', 'system:administrators', $ENV{REMOTE_USER}, $ENV{REDIRECT_REMOTE_USER} );

## -- ENABLE_AFSGROUPMANAGER 
## enables the AFS Group Manager
## EXAMPLE: $ENABLE_AFSGROUPMANAGER = 1;
$ENABLE_AFSGROUPMANAGER = $ENABLE_AFS;

## -- ALLOW_AFSGROUPCHANGES
## enables AFS group change support
## EXAMPLE: $ALLOW_AFSGROUPCHANGES = 1;
$ALLOW_AFSGROUPCHANGES = $ENABLE_AFS;

## -- AFS_PTSCMD
## file path to the AFS pts command
## EXAMPLE: $AFS_PTSCMD = '/usr/bin/pts';
$AFS_PTSCMD = '/usr/bin/pts';

## -- ENABLE_LOCK
## enable/disable lock/unlock support (WebDAV compiance class 2) 
## if disabled it's unsafe for shared collections/files but improves performance 
$ENABLE_LOCK = 1;

## -- ENABLE_ACL
## enable ACL support: only Unix like read/write access changes for user/group/other are supported
$ENABLE_ACL = 1;

## --- CURRENT_USER_PRINCIPAL
## a virtual URI for ACL principals
## for Apple's iCal &  Addressbook
$CURRENT_USER_PRINCIPAL = "/principals/".($ENV{REDIRECT_REMOTE_USER} || $ENV{REMOTE_USER}) .'/';

## -- PRINCIPAL_COLLECTION_SET 
## don't change it for MacOS X Addressbook support
## DEFAULT: $PRINCIPAL_COLLECTION_SET = '/directory/';
$PRINCIPAL_COLLECTION_SET = '/directory/';

## -- ENABLE_CALDAV
## enable CalDAV support for Lightning/Sunbird/iCal/iPhone calender/task support
$ENABLE_CALDAV = 1;

## -- CALENDAR_HOME_SET
## maps UID numbers or remote users (accounts) to calendar folders
%CALENDAR_HOME_SET = ( default=> '/', 1000 =>  '/caldav'  );

## -- ENABLE_CALDAV_SCHEDULE
## really incomplete (ALPHA) - properties exist but POST requests are not supported yet
$ENABLE_CALDAV_SCHEDULE = 0;

## -- ENABLE_CARDDAV
## enable CardDAV support for Apple's Addressbook
$ENABLE_CARDDAV = 1;

## -- ADDRESSBOOK_HOME_SET
## maps UID numbers or remote users to addressbook folders 
%ADDRESSBOOK_HOME_SET = ( default=> '/',  1000 => '/carddav/'  );

## -- ENABLE_TRASH
## enables the server-side trash can (don't forget to setup $TRASH_FOLDER)
$ENABLE_TRASH = 0;

## -- TRASH_FOLDER
## neccessary if you enable trash 
## it should be writable by your users (chmod a+rwxt <trash folder>)
## EXAMPLE: $TRASH_FOLDER = '/tmp/trash';
$TRASH_FOLDER = '/usr/local/www/var/trash';

## -- ENABLE_GROUPDAV
## enables GroupDAV (http://groupdav.org/draft-hess-groupdav-01.txt)
## EXAMPLE: $ENABLE_GROUPDAV = 0;
$ENABLE_GROUPDAV = 1;

## -- ENABLE_SEARCH
##  enables server-side search (WebDAV SEARCH/DASL, RFC5323)
## EXAMPLE: $ENABLE_SEARCH = 1;
$ENABLE_SEARCH = 1;

## -- ENABLE_THUMBNAIL
## enables image thumbnail support and media rss feed for folder listings of the Web interface.
## If enabled the default icons for images will be replaced by thumbnails
## and if the mouse is over a icon the icon will be zoomed to the size of $THUMBNAIL_WIDTH.
## DEFAULT: $ENABLE_THUMBNAIL = 0;
$ENABLE_THUMBNAIL = 1;

## -- ENABLE_THUMBNAIL_PDFPS
## enables image thumbnail support for PDF and PostScript files
## (ghostscript required: 'gs' binary is used by GraphicsMagick)
$ENABLE_THUMBNAIL_PDFPS = 1;

## -- ENABLE_THUMBNAIL_CACHE
## enable image thumbnail caching (improves performance - 2x faster)
## DEFAULT: $ENABLE_THUMBNAIL_CACHE = 0;
$ENABLE_THUMBNAIL_CACHE = 1;

## -- THUMBNAIL_WIDTH
## defines the width of a image thumbnail
$THUMBNAIL_WIDTH=110;

## -- THUMBNAIL_CACHEDIR
## defines the path to a cache directory for image thumbnails
## this is neccessary if you enable the thumbnail cache ($ENABLE_THUMBNAIL_CACHE)
## EXAMPLE: $THUMBNAIL_CACHEDIR=".thumbs";
$THUMBNAIL_CACHEDIR="/tmp";

## -- ENABLE_BIND
## enables BIND/UNBIND/REBIND methods defined in http://tools.ietf.org/html/draft-ietf-webdav-bind-27
## EXAMPLE: $ENABLE_BIND = 1;
$ENABLE_BIND = 1;

## -- FILECOUNTLIMIT
## limits the number of files/folders listed per folder by PROPFIND requests or Web interface browsing  
## (this will be overwritten by FILECOUNTPERDIRLIMIT)
## EXAMPLE: $FILECOUNTLIMIT = 5000;
$FILECOUNTLIMIT = 5000;

## -- FILECOUNTPERDIRLIMIT
## limits the number of files/folders listed by PROPFIND requests or the Web interface
## a value less than 1 prevents a 'opendir'
## (don't forget the trailing slash '/')
## EXAMPLE: %FILECOUNTPERDIRLIMIT = ( '/afs/.cms.hu-berlin.de/user/' => 5, '/usr/local/www/htdocs/rohdedan/test/' => 4 );
%FILECOUNTPERDIRLIMIT = ( '/afs/.cms.hu-berlin.de/user/' => -1, '/usr/local/www/htdocs/rohdedan/test/' => 2 );

## -- FILEFILTERPERDIR
## filter the visible files/folders per directory listed by PROPFIND or the Web interface
## you can use full Perl's regular expressions for the filter value
## SYNTAX: <my absolute path with trailing slash> => <my filter regex for visible files>;
## EXAMPLE: 
##   ## show only the user home in the AFS home dir 'user' of the cell '.cms.hu-berlin.de'
##   my $_ru = (split(/\@/, ($ENV{REMOTE_USER}||$ENV{REDIRECT_REMOTE_USER})))[0];
##   %FILEFILTERPERDIR = ( '/afs/.cms.hu-berlin.de/user/' => "^$_ru\$");
my $_ru = (split(/\@/, ($ENV{REMOTE_USER}||$ENV{REDIRECT_REMOTE_USER})))[0];
%FILEFILTERPERDIR = ( '/afs/.cms.hu-berlin.de/user/' => "^$_ru\$", '/usr/local/www/htdocs/rohdedan/links/'=>'^loop[1-4]$');

## -- IGNOREFILEPERMISSIONS
## if enabled all unreadable files and folders are clickable for full AFS support
## it's not a security risk because process rights and file permissions will work
## EXAMPLE: $IGNOREFILEPERMISSIONS = 0;
$IGNOREFILEPERMISSIONS = $ENABLE_AFS;

## -- ENABLE_FLOCK
## enables file locking support (flock) for PUT/POST uploads to respect existing locks and to set locks for files to change
$ENABLE_FLOCK = 1;

## -- LIMIT_FOLDER_DEPTH
## limits the depth a folder is visited for copy/move operations
$LIMIT_FOLDER_DEPTH = 20;

## -- DEBUG
## enables/disables debug output
## you can find the debug output in your web server error log
$DEBUG = 0;

############  S E T U P - END ###########################################
#########################################################################

use strict;
#use warnings;

use Fcntl qw(:flock);

use CGI;

use File::Basename;

use File::Spec::Link;

use XML::Simple;
use Date::Parse;
use POSIX qw(strftime ceil);

use URI::Escape;
use OSSP::uuid;
use Digest::MD5;

use DBI;

use Quota;

use Archive::Zip;

use Graphics::Magick;


## flush immediately:
$|=1;

## before 'new CGI' to read POST requests:
$ENV{REQUEST_METHOD}=$ENV{REDIRECT_REQUEST_METHOD} if (defined $ENV{REDIRECT_REQUEST_METHOD}) ;

$CGI::POST_MAX = $POST_MAX_SIZE;
$CGI::DISABLE_UPLOADS = $ALLOW_POST_UPLOADS?0:1;

## create CGI instance
our $cgi = $ENV{REQUEST_METHOD} eq 'PUT' ? new CGI({}) : new CGI;

my $method = $cgi->request_method();
if (defined $CONFIGFILE) {
	unless (my $ret = do($CONFIGFILE)) {
		warn "couldn't parse $CONFIGFILE: $@" if $@;
		warn "couldn't do $CONFIGFILE: $!" unless defined $ret;
		warn "couldn't run $CONFIGFILE" unless $ret;
	}
}

 
umask $UMASK;

## read mime.types file once:
readMIMETypes($MIMEFILE) if defined $MIMEFILE;
$MIMEFILE=undef;

## supported DAV compliant classes:
our $DAV='1';
$DAV.=', 2' if $ENABLE_LOCK;
$DAV.=', 3, <http://apache.org/dav/propset/fs/1>, extended-mkcol';
$DAV.=', access-control' if $ENABLE_ACL || $ENABLE_CALDAV || $ENABLE_CARDDAV;
$DAV.=', calendar-access, calendarserver-private-comments' if $ENABLE_CALDAV || $ENABLE_CALDAV_SCHEDULE; 
$DAV.=', calendar-auto-schedule' if  $ENABLE_CALDAV || $ENABLE_CALDAV_SCHEDULE;
$DAV.=', addressbook' if $ENABLE_CARDDAV;
$DAV.=', bind' if $ENABLE_BIND;

our $PATH_TRANSLATED = $ENV{PATH_TRANSLATED};
our $REQUEST_URI = $ENV{REQUEST_URI};

$LANG = $cgi->param('lang') || $cgi->cookie('lang') || $LANG || 'default';
$ORDER = $cgi->param('order') || $cgi->cookie('order') || $ORDER || 'name';
study $ORDER;
$PAGE_LIMIT = $cgi->param('pagelimit') || $cgi->cookie('pagelimit') || $PAGE_LIMIT;
$PAGE_LIMIT = ceil($PAGE_LIMIT) if defined $PAGE_LIMIT;
@PAGE_LIMITS = ( 5, 10, 15, 20, 25, 30, 50, 100, -1 ) unless defined @PAGE_LIMITS;
unshift @PAGE_LIMITS, $PAGE_LIMIT if defined $PAGE_LIMIT && $PAGE_LIMIT > 0 && grep(/\Q$PAGE_LIMIT\E/, @PAGE_LIMITS) <= 0 ;

$VIEW = $cgi->param('view') || $cgi->cookie('view') || $VIEW || ($ENABLE_SIDEBAR ? 'sidebar' : 'classic');
$VIEW = 'classic' unless $ENABLE_SIDEBAR;

debug("$0 called with UID='$<' EUID='$>' GID='$(' EGID='$)' method=$method");
debug("User-Agent: $ENV{HTTP_USER_AGENT}");
debug("CGI-Version: $CGI::VERSION");

debug("$0: X-Litmus: ".$cgi->http("X-Litmus")) if defined $cgi->http("X-Litmus");
debug("$0: X-Litmus-Second: ".$cgi->http("X-Litmus-Second")) if defined $cgi->http("X-Litmus-Second");

# 404/rewrite/redirect handling:
if (!defined $PATH_TRANSLATED) {
	$PATH_TRANSLATED = $ENV{REDIRECT_PATH_TRANSLATED};

	if (!defined $PATH_TRANSLATED && (defined $ENV{SCRIPT_URL} || defined $ENV{REDIRECT_URL})) {
		my $su = $ENV{SCRIPT_URL} || $ENV{REDIRECT_URL};
		$su=~s/^$VIRTUAL_BASE//;
		$PATH_TRANSLATED = $DOCUMENT_ROOT.$su;
	}
}


# protect against direct CGI script call:
if (!defined $PATH_TRANSLATED || $PATH_TRANSLATED eq "") {
	debug('FORBIDDEN DIRECT CALL!');
	printHeaderAndContent('404 Not Found');
	exit();
}

$PATH_TRANSLATED.='/' if -d $PATH_TRANSLATED && $PATH_TRANSLATED !~ /\/$/; 
$REQUEST_URI=~s/\?.*$//; ## remove query strings
$REQUEST_URI.='/' if -d $PATH_TRANSLATED && $REQUEST_URI !~ /\/$/;

$TRASH_FOLDER.='/' if $TRASH_FOLDER !~ /\/$/;

if (grep(/^\Q$<\E$/, @FORBIDDEN_UID)>0) {
	debug("Forbidden UID");
	printHeaderAndContent('403 Forbidden');
	exit(0);
}

$WEB_ID = 0;


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


@KNOWN_COLL_PROPS = ( 
			'creationdate', 'displayname','getcontentlanguage', 
			'getlastmodified', 'lockdiscovery', 'resourcetype', 
			'getetag', 'getcontenttype',
			'supportedlock', 'source',
			'quota-available-bytes', 'quota-used-bytes', 'quota', 'quotaused',
			'childcount', 'id', 'isfolder', 'ishidden', 'isstructureddocument',
			'hassubs', 'nosubs', 'objectcount', 'reserved', 'visiblecount',
			'iscollection', 'isFolder', 
			'authoritative-directory', 'resourcetag', 'repl-uid',
			'modifiedby', 
			'Win32CreationTime', 'Win32FileAttributes', 'Win32LastAccessTime', 'Win32LastModifiedTime', 
			'name','href', 'parentname', 'isreadonly', 'isroot', 'getcontentclass', 'lastaccessed', 'contentclass',
			'supported-report-set', 'supported-method-set',
			);
@KNOWN_ACL_PROPS = (
			'owner','group','supported-privilege-set', 'current-user-privilege-set', 'acl', 'acl-restrictions',
			'inherited-acl-set', 'principal-collection-set', 'current-user-principal'
		      );
@KNOWN_CALDAV_COLL_PROPS = (
			'calendar-description', 'calendar-timezone', 'supported-calendar-component-set',
			'supported-calendar-data', 'max-resource-size', 'min-date-time',
			'max-date-time', 'max-instances', 'max-attendees-per-instance',
			'getctag',
		        'principal-URL', 'calendar-home-set', 'schedule-inbox-URL', 'schedule-outbox-URL',
			'calendar-user-type', 'schedule-calendar-transp', 'schedule-default-calendar-URL',
			'schedule-tag', 'calendar-user-address-set',
			);
@KNOWN_CALDAV_FILE_PROPS = ( 'calendar-data' );

@KNOWN_CARDDAV_COLL_PROPS = ('addressbook-description', 'supported-address-data', 'addressbook-home-set', 'principal-address');
@KNOWN_CARDDAV_FILE_PROPS = ('address-data');

@KNOWN_COLL_LIVE_PROPS = ( );
@KNOWN_FILE_LIVE_PROPS = ( );
@KNOWN_CALDAV_COLL_LIVE_PROPS = ( 'resourcetype', 'displayname', 'calendar-description', 'calendar-timezone', 'calendar-user-address-set');
@KNOWN_CALDAV_FILE_LIVE_PROPS = ( );
@KNOWN_CARDDAV_COLL_LIVE_PROPS = ( 'addressbook-description');
@KNOWN_CARDDAV_FILE_LIVE_PROPS = ( );

push @KNOWN_COLL_LIVE_PROPS, @KNOWN_CALDAV_COLL_LIVE_PROPS if $ENABLE_CALDAV || $ENABLE_CALDAV_SCHEDULE || $ENABLE_CARDDAV;
push @KNOWN_FILE_LIVE_PROPS, @KNOWN_CALDAV_FILE_LIVE_PROPS if $ENABLE_CALDAV || $ENABLE_CALDAV_SCHEDULE || $ENABLE_CARDDAV;
push @KNOWN_COLL_LIVE_PROPS, @KNOWN_CARDDAV_COLL_LIVE_PROPS if $ENABLE_CARDDAV;
push @KNOWN_COLL_PROPS, @KNOWN_ACL_PROPS if $ENABLE_ACL || $ENABLE_CALDAV || $ENABLE_CALDAV_SCHEDULE || $ENABLE_CARDDAV;
push @KNOWN_COLL_PROPS, @KNOWN_CALDAV_COLL_PROPS if $ENABLE_CALDAV || $ENABLE_CALDAV_SCHEDULE;
push @KNOWN_COLL_PROPS, @KNOWN_CARDDAV_COLL_PROPS if $ENABLE_CARDDAV;
push @KNOWN_COLL_PROPS, 'resource-id' if $ENABLE_BIND;


@KNOWN_FILE_PROPS = ( @KNOWN_COLL_PROPS, 'getcontentlength', 'executable' );
push @KNOWN_FILE_PROPS, @KNOWN_CALDAV_FILE_PROPS if $ENABLE_CALDAV || $ENABLE_CALDAV_SCHEDULE;
push @KNOWN_FILE_PROPS, @KNOWN_CARDDAV_FILE_PROPS if $ENABLE_CARDDAV;

push @KNOWN_COLL_PROPS, 'component-set' if $ENABLE_GROUPDAV;

@UNSUPPORTED_PROPS = ( 'checked-in', 'checked-out', 'xmpp-uri', 'dropbox-home-URL' ,'parent-set', 'appledoubleheader' ); 

@PROTECTED_PROPS = ( @UNSUPPORTED_PROPS, 
			'getcontentlength', 'getcontenttype', 'getetag', 'lockdiscovery', 
			'source', 'supportedlock',
			'supported-report-set',
			'quota-available-bytes, quota-used-bytes', 'quota', 'quotaused',
			'childcount', 'id', 'isfolder', 'ishidden', 'isstructureddocument', 
			'hassubs', 'nosubs', 'objectcount', 'reserved', 'visiblecount',
			'iscollection', 'isFolder',
			'authoritative-directory', 'resourcetag', 'repl-uid',
			'modifiedby', 
			'name', 'href', 'parentname', 'isreadonly', 'isroot', 'getcontentclass', 'contentclass',
			'owner', 'group', 'supported-privilege-set', 'current-user-privilege-set', 
			'acl', 'acl-restrictions', 'inherited-acl-set', 'principal-collection-set',
			'supported-calendar-component-set','supported-calendar-data', 'max-resource-size',
			'min-date-time','max-date-time','max-instances','max-attendees-per-instance', 'getctag',
			'current-user-principal', 
			'calendar-user-address-set', 'schedule-inbox-URL', 'schedule-outbox-URL', 'schedule-calendar-transp',
			'schedule-default-calendar-URL', 'schedule-tag', 'supported-address-data', 
			'supported-collation-set', 'supported-method-set', 'supported-method',
			'supported-query-grammar'
		);

@ALLPROP_PROPS = ( 'creationdate', 'displayname', 'getcontentlanguage', 'getlastmodified', 
			'lockdiscovery', 'resourcetype','supportedlock', 'getetag', 'getcontenttype', 
			'getcontentlength', 'executable' );


### XML
%NAMESPACES = ( 'DAV:'=>'D', 'http://apache.org/dav/props/'=>'lp2', 'urn:schemas-microsoft-com:' => 'Z', 'urn:schemas-microsoft-com:datatypes'=>'M', 'urn:schemas-microsoft-com:office:office' => 'Office', 'http://schemas.microsoft.com/repl/' => 'Repl', 'urn:ietf:params:xml:ns:caldav'=>'C', 'http://calendarserver.org/ns/'=>'CS', 'http://www.apple.com/webdav_fs/props/'=>'Apple', 'http://www.w3.org/2000/xmlns/'=>'x', 'urn:ietf:params:xml:ns:carddav' => 'A', 'http://www.w3.org/2001/XMLSchema'=>'xs', 'http://groupdav.org/'=>'G');

%ELEMENTS = ( 	'calendar'=>'C','calendar-description'=>'C', 'calendar-timezone'=>'C', 'supported-calendar-component-set'=>'C',
		'supported-calendar-data'=>'C', 'max-resource-size'=>'C', 'min-date-time'=>'C',
		'max-date-time'=>'C','max-instances'=>'C', 'max-attendees-per-instance'=>'C',
		'read-free-busy'=>'C', 'calendar-home-set'=>'C', 'supported-collation-set'=>'C', 'schedule-tag'=>'C',
		'calendar-data'=>'C', 'mkcalendar-response'=>'C', getctag=>'CS',
		'calendar-user-address-set'=>'C', 'schedule-inbox-URL'=>'C', 'schedule-outbox-URL'=>'C',
		'calendar-user-type'=>'C', 'schedule-calendar-transp'=>'C', 'schedule-default-calendar-URL'=>'C',
		'schedule-inbox'=>'C', 'schedule-outbox'=>'C', 'transparent'=>'C',
		'calendar-multiget'=>'C', 'calendar-query'=>'C', 'free-busy-query'=>'C',
		'addressbook'=>'A', 'addressbook-description'=>'A', 'supported-address-data'=>'A', 'addressbook-home-set'=>'A', 'principal-address'=>'A',
		'address-data'=>'A',
		'addressbook-query'=>'A', 'addressbook-multiget'=>'A',
		'string'=>'xs', 'anyURI'=>'xs', 'nonNegativeInteger'=>'xs', 'dateTime'=>'xs',
		'vevent-collection'=>'G', 'vtodo-collection'=>'G', 'vcard-collection'=>'G', 'component-set'=>'G',
		'executable'=>'lp2','Win32CreationTime'=>'Z', 'Win32LastModifiedTime'=>'Z', 'Win32LastAccessTime'=>'Z', 
		'authoritative-directory'=>'Repl', 'resourcetag'=>'Repl', 'repl-uid'=>'Repl', 'modifiedby'=>'Office', 'specialFolderType'=>'Office',
		'Win32CreationTime'=>'Z', 'Win32FileAttributes'=>'Z', 'Win32LastAccessTime'=>'Z', 'Win32LastModifiedTime'=>'Z',default=>'D',
		'appledoubleheader'=>'Apple',
);

%NAMESPACEABBR = ( 'D'=>'DAV:', 'lp2'=>'http://apache.org/dav/props/', 'Z'=>'urn:schemas-microsoft-com:', 'Office'=>'urn:schemas-microsoft-com:office:office','Repl'=>'http://schemas.microsoft.com/repl/', 'M'=>'urn:schemas-microsoft-com:datatypes', 'C'=>'urn:ietf:params:xml:ns:caldav', 'CS'=>'http://calendarserver.org/ns/', 'Apple'=>'http://www.apple.com/webdav_fs/props/', 'A'=> 'urn:ietf:params:xml:ns:carddav', 'xs'=>'http://www.w3.org/2001/XMLSchema', 'G'=>'http://groupdav.org/');

%DATATYPES = ( isfolder=>'M:dt="boolean"', ishidden=>'M:dt="boolean"', isstructureddocument=>'M:dt="boolean"', hassubs=>'M:dt="boolean"', nosubs=>'M:dt="boolean"', reserved=>'M:dt="boolean"', iscollection =>'M:dt="boolean"', isFolder=>'M:dt="boolean"', isreadonly=>'M:dt="boolean"', isroot=>'M:dt="boolean"', lastaccessed=>'M:dt="dateTime"', Win32CreationTime=>'M:dt="dateTime"',Win32LastAccessTime=>'M:dt="dateTime"',Win32LastModifiedTime=>'M:dt="dateTime"', description=>'xml:lang="en"');

%NAMESPACEELEMENTS = ( 'multistatus'=>1, 'prop'=>1 , 'error'=>1, 'principal-search-property-set'=>1);

%ELEMENTORDER = ( multistatus=>1, responsedescription=>4, 
			allprop=>1, include=>2,
			prop=>1, propstat=>2,status=>3, error=>4,
			href=>1, responsedescription=>5, location=>6,
			locktype=>1, lockscope=>2, depth=>3, owner=>4, timeout=>5, locktoken=>6, lockroot=>7, 
			getcontentlength=>1001, getlastmodified=>1002, 
			resourcetype=>0,
			getcontenttype=>1, 
			supportedlock=>1010, lockdiscovery=>1011, 
			src=>1,dst=>2,
			principal => 1, grant => 2,
			privilege => 1, abstract=> 2, description => 3, 'supported-privilege' => 4,
			collection=>1, calendar=>2, 'schedule-inbox'=>3, 'schedule-outbox'=>4,
			'calendar-data'=>101, getetag=>100,
			properties => 1, operators=>2,
			default=>1000);
%SEARCH_PROPTYPES = ( default=>'string',
			  '{DAV:}getlastmodified'=> 'dateTime', '{DAV:}lastaccessed'=>'dateTime', '{DAV:}getcontentlength' => 'int', 
			  '{DAV:}creationdate' => 'dateTime','{urn:schemas-microsoft-com:}Win32CreationTime' =>'dateTime', 
			  '{urn:schemas-microsoft-com:}Win32LastAccessTime'=>'dateTime',  '{urn:schemas-microsoft-com:}Win32LastModifiedTime'=>'dateTime',
			  '{DAV:}childcount'=>'int', '{DAV:}objectcount'=>'int','{DAV:}visiblecount'=>'int',
			  '{DAV:}acl'=>'xml', '{DAV:}acl-restrictions'=>'xml','{urn:ietf:params:xml:ns:carddav}addressbook-home-set'=>'xml',
			  '{urn:ietf:params:xml:ns:caldav}calendar-home-set'=>'xml', '{DAV:}current-user-principal}'=>'xml',
			  '{DAV:}current-user-privilege-set'=>'xml', '{DAV:}group'=>'xml',
			  '{DAV:}owner'=>'xml', '{urn:ietf:params:xml:ns:carddav}principal-address'=>'xml',
			  '{DAV:}principal-collection-set'=>'xml', '{DAV:}principal-URL'=>'xml',
			  '{DAV:}resourcetype'=>'xml', '{urn:ietf:params:xml:ns:caldav}schedule-calendar-transp'=>'xml',
			  '{urn:ietf:params:xml:ns:caldav}schedule-inbox-URL'=>'xml', '{urn:ietf:params:xml:ns:caldav}schedule-outbox-URL'=>'xml',
			  '{DAV:}source'=>'xml', '{urn:ietf:params:xml:ns:carddav}supported-address-data'=>'xml',
			  '{urn:ietf:params:xml:ns:caldav}supported-calendar-component-set'=>'xml','{urn:ietf:params:xml:ns:caldav}supported-calendar-data'=>'xml',
			  '{DAV:}supported-method-set'=>'xml','{DAV:}supported-privilege-set'=>'xml','{DAV:}supported-report-set'=>'xml',
			  '{DAV:}supportedlock'=>'xml'
			);
%SEARCH_SPECIALCONV = ( dateTime => 'str2time', xml=>'convXML2Str' );
%SEARCH_SPECIALOPS = ( int => { eq => '==', gt => '>', lt =>'<', gte=>'>=', lte=>'<=', cmp=>'<=>' }, 
                           dateTime => { eq => '==', gt => '>', lt =>'<', gte=>'>=', lte=>'<=', cmp=>'<=>' }, 
                           string => { lte=>'le', gte=>'ge' } );

@IGNORE_PROPS = ( 'xmlns', 'CS');

# method handling:
if ($method=~/^(GET|HEAD|POST|OPTIONS|PROPFIND|PROPPATCH|MKCOL|PUT|COPY|MOVE|DELETE|LOCK|UNLOCK|GETLIB|ACL|REPORT|MKCALENDAR|SEARCH|BIND|UNBIND|REBIND)$/) { 

	### performance is bad:
#	eval "_${method}();" ;
#	if ($@) {
#		print STDERR "$0: Missing method handler for '$method'\n$@";
#		printHeaderAndContent('501 Not Implemented');
#	}
	### performance is much better than eval:
	gotomethod($method);
	if (!$DBI_PERSISTENT && $DBI_INIT) {
		$DBI_INIT->disconnect();
		$DBI_INIT=undef;
	}
} else {
	printHeaderAndContent('405 Method Not Allowed');
}
sub gotomethod {
	my ($method) = @_;
	$method="_$method";
	goto &$method; ## I use 'goto' so I don't need 'no strict "refs"' and 'goto' works only in a subroutine
}

sub _GET {
	my $fn = $PATH_TRANSLATED;
	debug("_GET: $fn");

	if (is_hidden($fn)) {
		printHeaderAndContent('404 Not Found','text/plain','404 - NOT FOUND');
	} elsif ($ENABLE_AFS && !checkAFSAccess($fn)) {
		printHeaderAndContent('403 Forbidden','text/plain', '403 Forbidden');
	} elsif (!$FANCYINDEXING && -d $fn) {
		printHeaderAndContent('404 Not Found','text/plain','404 - NOT FOUND');
	} elsif ($cgi->param('action') eq 'davmount' && -e $fn) {
		my $su = $ENV{REDIRECT_SCRIPT_URI} || $ENV{SCRIPT_URI};
		my $bn = basename($fn);
		$su =~ s/\Q$bn\E\/?//;
		$bn.='/' if -d $fn && $bn!~/\/$/;
		printHeaderAndContent('200 OK','application/davmount+xml',
		       qq@<dm:mount xmlns:dm="http://purl.org/NET/webdav/mount"><dm:url>$su</dm:url><dm:open>$bn</dm:open></dm:mount>@);
	} elsif ($ENABLE_THUMBNAIL &&  $cgi->param('action') eq 'mediarss' && -d $fn && ($IGNOREFILEPERMISSIONS || -r $fn)) {
		my $content = qq@<?xml version="1.0" encoding="utf-8" standalone="yes"?><rss version="2.0" xmlns:media="http://search.yahoo.com/mrss/" xmlns:atom="http://www.w3.org/2005/Atom"><channel><title>$ENV{SCRIPT_URI} media data</title><description>$ENV{SCRIPT_URI} media data</description><link>$ENV{SCRIPT_URI}</link>@;
		foreach my $file (sort cmp_files @{readDir($fn)}) {
			my $mime = getMIMEType($file);
			$mime='image/gif' if hasThumbSupport($mime) && $mime !~ /^image/i;
			$content.=qq@<item><title>$file</title><link>$REQUEST_URI$file</link><media:thumbnail type="image/gif" url="$ENV{SCRIPT_URI}$file?action=thumb"/><media:content type="$mime" url="$ENV{SCRIPT_URI}$file?action=image"/></item>@ if hasThumbSupport($mime) && ($IGNOREFILEPERMISSIONS || -r "$fn$file");
		}
		$content.=qq@</channel></rss>@;
		printHeaderAndContent("200 OK", 'appplication/rss+xml', $content);
	} elsif ($ENABLE_THUMBNAIL && $cgi->param('action') eq 'image' && hasThumbSupport(getMIMEType($fn)) && -f $fn) {
		my $image = Graphics::Magick->new;
		my $x = $image->Read($fn); warn "$x" if "$x";
		$image->Set(delay=>200);
		binmode STDOUT;
		print $cgi->header(-status=>'200 OK',-type=>'image/gif', -ETag=>getETag($fn));
		$x = $image->Write('gif:-'); warn "$x" if "$x";
	} elsif ($cgi->param('action') eq 'opensearch' && -d $fn) {
		my $content = qq@<?xml version="1.0" encoding="utf-8" ?><OpenSearchDescription xmlns="http://a9.com/-/spec/opensearch/1.1/"><ShortName>WebDAV CGI filename</ShortName><Description>WebDAV CGI filename search in $ENV{SCRIPT_URI}</Description><InputEncoding>utf-8</InputEncoding><Url type="text/html" template="$ENV{SCRIPT_URI}?search={searchTerms}" /></OpenSearchDescription>@;
		printHeaderAndContent("200 OK", 'text/xml', $content);
	} elsif ($ENABLE_THUMBNAIL && $cgi->param('action') eq 'thumb' && ($IGNOREFILEPERMISSIONS || -r $fn) && -f $fn) {
		my $image = Graphics::Magick->new;
		my $width = $THUMBNAIL_WIDTH || $ICON_WIDTH || 18;
		if ($ENABLE_THUMBNAIL_CACHE) {
			my $uniqname = $fn;
			$uniqname=~s/\//_/g;
			my $cachefile = "$THUMBNAIL_CACHEDIR/$uniqname.thumb.gif";
			mkdir($THUMBNAIL_CACHEDIR) if ! -e $THUMBNAIL_CACHEDIR;
			if (! -e $cachefile || (stat($fn))[9] > (stat($cachefile))[9]) {
				my $x;
				my ($w, $h,$s,$f) = $image->Ping($fn);
				
				$x = $image->Read($fn); warn "$x" if "$x";
				$image->Set(delay=>200);
				$image->Crop(height=>$h / ${width} ) if ($h > $width && $w < $width); 
				$image->Resize(geometry=>$width,filter=>'Gaussian') if ($w > $width);
				$image->Frame(width=>2,height=>2,outer=>0,inner=>2, fill=>'black');
				$x = $image->Write($cachefile); warn "$x" if "$x";
		
			}
			if (open(my $cf, "<$cachefile")) {
				print $cgi->header(-status=>'200 OK',-type=>getMIMEType($cachefile), -ETag=>getETag($cachefile), -Content-length=>(stat($cachefile))[7]);
				binmode $cf;
				binmode STDOUT;
				print while(<$cf>);
				close($cf);
			}
		} else {
			print $cgi->header(-status=>'200 OK',-type=>'image/gif', -ETag=>getETag($fn));
			my ($w, $h,$s,$f) = $image->Ping($fn);
			my $x;
			$x = $image->Read($fn); warn "$x" if "$x";
			$image->Set(delay=>200);
			$image->Crop(height=>$h / ${width} ) if ($h > $width && $w < $width); 
			$image->Resize(geometry=>$width,filter=>'Gaussian') if ($w > $width);
			$image->Frame(width=>2,height=>2,outer=>0,inner=>2, fill=>'black');
			binmode STDOUT;
			$x = $image->Write('gif:-'); warn "$x" if "$x";
		}
	} elsif ($ENABLE_PROPERTIES_VIEWER && $cgi->param('action') eq 'props' && -e $fn) {
		my $content = "";
		$content .= start_html("$REQUEST_URI properties");
		$content .= $LANGSWITCH if defined $LANGSWITCH;
		$content .= $HEADER if defined $HEADER;
		my $fullparent = dirname($REQUEST_URI) .'/';
		$fullparent = '/' if $fullparent eq '//' || $fullparent eq '';
		$content .=$cgi->h2( { -class=>'foldername' }, (-d $fn ? getQuickNavPath($REQUEST_URI,getQueryParams()) 
					     : getQuickNavPath($fullparent,getQueryParams())
					       .' '.$cgi->a({-href=>$REQUEST_URI}, basename($REQUEST_URI))
				      ). _tl('properties'));
		$content .= $cgi->br().$cgi->a({href=>$REQUEST_URI,title=>_tl('clickforfullsize')},$cgi->img({-src=>$REQUEST_URI.($ENABLE_THUMBNAIL?'?action=thumb':''), -alt=>'image', -class=>'thumb', -style=>'width:'.($ENABLE_THUMBNAIL?$THUMBNAIL_WIDTH:200)})) if hasThumbSupport(getMIMEType($fn));
		$content .= $cgi->start_table({-class=>'props'});
		local(%NAMESPACEELEMENTS);
		my $dbprops = db_getProperties($fn);
		my @bgstyleclasses = ( 'tr_odd', 'tr_even');
		my (%visited);
		$content.=$cgi->Tr({-class=>'trhead'}, $cgi->th({-class=>'thname'},_tl('propertyname')), $cgi->th({-class=>'thvalue'},_tl('propertyvalue')));
		foreach my $prop (sort {nonamespace(lc($a)) cmp nonamespace(lc($b)) } keys %{$dbprops},-d $fn ? @KNOWN_COLL_PROPS : @KNOWN_FILE_PROPS ) {
			my (%r200);
			next if exists $visited{$prop} || exists $visited{'{'.getNameSpaceUri($prop).'}'.$prop};
			if (exists $$dbprops{$prop}) {
				$r200{prop}{$prop}=$$dbprops{$prop};
			} else {
				getProperty($fn, $REQUEST_URI, $prop, undef, \%r200, \my %r404);
			}
			$visited{$prop}=1;
			$NAMESPACEELEMENTS{nonamespace($prop)}=1;
			my $title = createXML($r200{prop},1);
			my $value = createXML($r200{prop}{$prop},1);
			my $namespace = getNameSpaceUri($prop);
			if ($prop =~ /^\{([^\}]*)\}/) {
				$namespace = $1;
			}
			push @bgstyleclasses,  shift @bgstyleclasses;
			$content.= $cgi->Tr( {-class=>$bgstyleclasses[0] },
				 $cgi->td({-title=>$namespace, -class=>'tdname'},nonamespace($prop))
				.$cgi->td({-title=>$title, -class=>'tdvalue' }, $cgi->pre($cgi->escapeHTML($value)))
				);
		}
		$content.=$cgi->end_table();
		$content.=$cgi->hr().$cgi->div({-class=>'signature'},$SIGNATURE) if defined $SIGNATURE;
		$content.=$cgi->end_html();
		printHeaderAndContent('200 OK', 'text/html', $content, 'Cache-Control: no-cache, no-store');
	} elsif (-d $fn) {
		my $ru = $REQUEST_URI;
		my $content = "";
		my $head = "";
		debug("_GET: directory listing of $fn");
		$head .= $LANGSWITCH if defined $LANGSWITCH;
		$head .= $HEADER if defined $HEADER;
		$content.=$cgi->start_multipart_form(-method=>'post', -action=>$ru, -onsubmit=>'return window.confirm("'._tl('confirm').'");') if $ALLOW_FILE_MANAGEMENT;
		if ($ALLOW_SEARCH && ($IGNOREFILEPERMISSIONS || -r $fn)) {
			my $search = $cgi->param('search');
			$head .= # $cgi->start_form(-method=>'GET')
				# . 
				$cgi->div({-class=>'search'}, _tl('search'). ' '. $cgi->input({-title=>_tl('searchtooltip'),-onkeyup=>'javascript:if (this.size<this.value.length || (this.value.length<this.size && this.value.length>10)) this.size=this.value.length;', -name=>'search',-size=>$search?(length($search)>10?length($search):10):10, -value=>defined $search?$search:''}))
				#.$cgi->end_form();
				;
		}
		$head.=renderMessage();
		if ($cgi->param('search')) {
			$content.=getSearchResult($cgi->param('search'),$fn,$ru);
		} else {
			$head .= $cgi->div({-id=>'notwriteable',-onclick=>'fadeOut("notwriteable");', -class=>'notwriteable msg'}, _tl('foldernotwriteable')) if (!$IGNOREFILEPERMISSIONS && !-w $fn) ;
			$head .= $cgi->div({-id=>'notreadable', -onclick=>'fadeOut("notreadable");',-class=>'notreadable msg'},  _tl('foldernotreadable')) if (!$IGNOREFILEPERMISSIONS && !-r $fn) ;
			$head .= $cgi->div({-id=>'filtered', -onclick=>'fadeOut("filtered");', -class=>'filtered msg', -title=>$FILEFILTERPERDIR{$fn}}, sprintf(_tl('folderisfiltered'), $FILEFILTERPERDIR{$fn} || ($ENABLE_NAMEFILTER ? $cgi->param('namefilter') : undef) )) if $FILEFILTERPERDIR{$fn} || ($ENABLE_NAMEFILTER && $cgi->param('namefilter'));
			$head .= $cgi->div( { -class=>'foldername'},
				$cgi->a({-href=>$ru.($ENABLE_PROPERTIES_VIEWER ? '?action=props' : '')}, 
						$cgi->img({-src=>$ICONS{'<folder>'} || $ICONS{default},-title=>_tl('showproperties'), -alt=>'folder'})
					)
				.'&nbsp;'.$cgi->a({-href=>'?action=davmount',-class=>'davmount',-title=>_tl('mounttooltip')},_tl('mount'))
				.' '
				.getQuickNavPath($ru)
			);
			$head.= $cgi->div( { -class=>'viewtools' }, 
					$cgi->a({-class=>'up', -href=>dirname($ru).(dirname($ru) ne '/'?'/':''), -title=>_tl('uptitle')}, _tl('up'))
					.' '.$cgi->a({-class=>'refresh',-href=>$ru.'?t='.time(), -title=>_tl('refreshtitle')},_tl('refresh')));
			if ($SHOW_QUOTA) {
				my ($ql, $qu) = getQuota($fn);
				if (defined $ql && defined $qu) {
					$ql=$ql/1048576; $qu=$qu/1048576;
					$head.= $cgi->div({-class=>'quota'},
									_tl('quotalimit').$cgi->span({-title=>sprintf("= %.2f GB",$ql/1024)},sprintf("%.2f MB, ",$ql))
									._tl('quotaused').$cgi->span({-title=>sprintf("= %.2f GB",$qu/1024)}, sprintf("%.2f MB, ",$qu))
									._tl('quotaavailable').$cgi->span({-title=>sprintf("= %.2f GB",($ql-$qu)/1024)},sprintf("%.2f MB",($ql-$qu))));
				}
			}
			$content.=$cgi->div({-class=>'masterhead'}, $head);
			my $folderview = "";
			my $manageview = "";
			my ($list, $count) = getFolderList($fn,$ru, $ENABLE_NAMEFILTER ? $cgi->param('namefilter') : undef);
			$folderview.=$list;
			$manageview.= renderToolbar() if ($ALLOW_FILE_MANAGEMENT && ($IGNOREFILEPERMISSIONS || -w $fn)) ;
			$manageview.= renderFieldSet('upload',renderFileUploadView($fn)) if $ALLOW_POST_UPLOADS && ($IGNOREFILEPERMISSIONS || -w $fn);
			$content.=renderSideBar() if $VIEW eq 'sidebar';
			if ($ALLOW_FILE_MANAGEMENT && ($IGNOREFILEPERMISSIONS || -w $fn)) {
				my $m = "";
				$m .= renderFieldSet('files', renderCreateNewFolderView() .renderMoveView() .renderDeleteView());
				$m .= renderFieldSet('permissions', renderChangePermissionsView()) if $ALLOW_CHANGEPERM;
				$m .= renderFieldSet('zip', renderZipView()) if ($ALLOW_ZIP_UPLOAD || $ALLOW_ZIP_DOWNLOAD);
				$m .= renderToggleFieldSet('afs', renderAFSACLManager()) if ($ENABLE_AFSACLMANAGER);
				$manageview .= renderToggleFieldSet('management', $m);
			}
			$folderview .= $manageview unless $VIEW eq 'sidebar';
			$folderview .= renderToggleFieldSet('afsgroup',renderAFSGroupManager()) if ($ENABLE_AFSGROUPMANAGER && $VIEW ne 'sidebar');
			my $showsidebar = $cgi->cookie('sidebar') ? $cgi->cookie('sidebar') eq 'true' : 1;
			$content .= $cgi->div({-id=>'folderview', -class=>($VIEW eq 'sidebar'? 'sidebarfolderview'.($showsidebar?'':' full') : 'folderview')}, $folderview);
			my $showall = $cgi->param('showpage') ? 0 : $cgi->param('showall') || $cgi->cookie('showall') || 0;
			$content .= $VIEW ne 'sidebar' && $ENABLE_SIDEBAR ? renderFieldSet('viewoptions', 
					 ( $showall ? '&bull; '.$cgi->a({-href=>'?showpage=1'},_tl('navpageview')) : '' )
					.(!$showall ? '&bull; '.$cgi->a({-href=>'?showall=1'},_tl('navall')) : '' )
					. $cgi->br().'&bull; '.$cgi->a({-href=>'?view=sidebar'},_tl('sidebarview'))) : '';
			$content .= $cgi->end_form() if $ALLOW_FILE_MANAGEMENT;
			$content .= $cgi->start_form(-method=>'post', -id=>'clpform')
					.$cgi->hidden(-name=>'action', -value=>'') .$cgi->hidden(-name=>'srcuri', -value>'')
					.$cgi->hidden(-name=>'files', -value=>'') .$cgi->end_form() if ($ALLOW_FILE_MANAGEMENT && $ENABLE_CLIPBOARD);
		}
		$content.= $cgi->div({-class=>$VIEW eq 'classic' ? 'signature' : 'signature sidebarsignature'}, $SIGNATURE) if defined $SIGNATURE;
		###$content =~ s/(<\/\w+[^>]*>)/$1\n/g;
		$content = start_html($ru).$content.$cgi->end_html();
		printHeaderAndContent('200 OK','text/html',$content,'Cache-Control: no-cache, no-store' );
	} elsif (-e $fn && (!$IGNOREFILEPERMISSIONS && !-r $fn)) {
		printHeaderAndContent('403 Forbidden','text/plain', '403 Forbidden');
	} elsif (-e $fn) {
		debug("_GET: DOWNLOAD");
		printFileHeader($fn);
		if (open(F,"<$fn")) {
			binmode(STDOUT);
			while (read(F,my $buffer, $BUFSIZE || 1048576 )>0) {
				print $buffer;
			}
			close(F);
		} else {
			printHeaderAndContent('403 Forbidden','text/plain','403 Forbidden (cannot open file)');
		}
	} else {
		debug("GET: $fn NOT FOUND!");
		printHeaderAndContent('404 Not Found','text/plain','404 - FILE NOT FOUND');
	}
	
}
sub _HEAD {
	if (-d $PATH_TRANSLATED) {
		debug("_HEAD: $PATH_TRANSLATED is a folder!");
		printHeaderAndContent('200 OK','httpd/unix-directory');
	} elsif (-e $PATH_TRANSLATED) {
		debug("_HEAD: $PATH_TRANSLATED exists!");
		printFileHeader($PATH_TRANSLATED);
	} else {
		debug("_HEAD: $PATH_TRANSLATED does not exists!");
		printHeaderAndContent('404 Not Found');
	}
}
sub _POST {
	debug("_POST: $PATH_TRANSLATED");

	if (!$cgi->param('file_upload') && $cgi->cgi_error) {
		printHeaderAndContent($cgi->cgi_error,undef,$cgi->cgi_error);	
		exit 0;
	}

	my($msg,$msgparam,$errmsg);
	my $redirtarget = $REQUEST_URI;
	$redirtarget =~s/\?.*$//; # remove query
	
	if ($ALLOW_FILE_MANAGEMENT && ($cgi->param('delete')||$cgi->param('rename')||$cgi->param('mkcol')||$cgi->param('changeperm'))) {
		debug("_POST: file management ".join(",",$cgi->param('file')));
		if ($cgi->param('delete')) {
			if ($cgi->param('file')) {
				my $count = 0;
				foreach my $file ($cgi->param('file')) {
					debug("_POST: delete $PATH_TRANSLATED.$file");
					if ($ENABLE_TRASH) {
						moveToTrash($PATH_TRANSLATED.$file);
					} else {
						$count += deltree($PATH_TRANSLATED.$file, \my @err);
					}
					logger("DELETE($PATH_TRANSLATED) via POST");
				}
				if ($count>0) {
					$msg= ($count>1)?'deletedmulti':'deletedsingle';
					$msgparam="p1=$count";
				} else {
					$errmsg='deleteerr'; 
				}
			} else {
				$errmsg='deletenothingerr';
			}
		} elsif ($cgi->param('rename')) {
			if ($cgi->param('file')) {
				if ($cgi->param('newname')) {
					my @files = $cgi->param('file');
					if (($#files > 0)&&(! -d $PATH_TRANSLATED.$cgi->param('newname'))) {
						$errmsg='renameerr';
					} else {
						$msg='rename';
						$msgparam = 'p1='.$cgi->escape(join(', ',@files))
						          . ';p2='.$cgi->escape($cgi->param('newname'));
						foreach my $file (@files) {
							if (rmove($PATH_TRANSLATED.$file, $PATH_TRANSLATED.$cgi->param('newname'))) {
								logger("MOVE($PATH_TRANSLATED,$PATH_TRANSLATED".$cgi->param('newname').") via POST");
							} else {
								$errmsg='renameerr';
							}
						}
					}
				} else {
					$errmsg='renamenotargeterr';
				}
			} else {
				$errmsg='renamenothingerr';
			}
		} elsif ($cgi->param('mkcol'))  {
			my $colname = $cgi->param('colname') || $cgi->param('colname1');
			if ($colname ne "") {
				$msgparam="p1=".$cgi->escape($colname);
				if (mkdir($PATH_TRANSLATED.$colname)) {
					logger("MKCOL($PATH_TRANSLATED$colname via POST");
					$msg='foldercreated';
				} else {
					$errmsg='foldererr'; 
					$msgparam.=';p2='.$cgi->escape(_tl($!));
				}
			} else {
				$errmsg='foldernothingerr';
			}
		} elsif ($cgi->param('changeperm')) {
			if ($cgi->param('file')) {
				my $mode = 0000;
				foreach my $userperm ($cgi->param('fp_user')) {
					$mode = $mode | 0400 if $userperm eq 'r' && grep(/^r$/,@{$PERM_USER}) == 1;
					$mode = $mode | 0200 if $userperm eq 'w' && grep(/^w$/,@{$PERM_USER}) == 1;
					$mode = $mode | 0100 if $userperm eq 'x' && grep(/^x$/,@{$PERM_USER}) == 1;
					$mode = $mode | 04000 if $userperm eq 's' && grep(/^s$/,@{$PERM_USER}) == 1;
				}
				foreach my $grpperm ($cgi->param('fp_group')) {
					$mode = $mode | 0040 if $grpperm eq 'r' && grep(/^r$/,@{$PERM_GROUP}) == 1;
					$mode = $mode | 0020 if $grpperm eq 'w' && grep(/^w$/,@{$PERM_GROUP}) == 1;
					$mode = $mode | 0010 if $grpperm eq 'x' && grep(/^x$/,@{$PERM_GROUP}) == 1;
					$mode = $mode | 02000 if $grpperm eq 's' && grep(/^s$/,@{$PERM_GROUP}) == 1;
				}
				foreach my $operm ($cgi->param('fp_others')) {
					$mode = $mode | 0004 if $operm eq 'r' && grep(/^r$/,@{$PERM_OTHERS}) == 1;
					$mode = $mode | 0002 if $operm eq 'w' && grep(/^w$/,@{$PERM_OTHERS}) == 1;
					$mode = $mode | 0001 if $operm eq 'x' && grep(/^x$/,@{$PERM_OTHERS}) == 1;
					$mode = $mode | 01000 if $operm eq 't' && grep(/^t$/,@{$PERM_OTHERS}) == 1;
				}

				$msg='changeperm';
				$msgparam=sprintf("p1=%04o",$mode);
				foreach my $file ($cgi->param('file')) {
					changeFilePermissions($PATH_TRANSLATED.$file, $mode, $cgi->param('fp_type'), $ALLOW_CHANGEPERMRECURSIVE && $cgi->param('fp_recursive'));
				}
			} else {
				$errmsg='chpermnothingerr';
			}
		}
		print $cgi->redirect($redirtarget.createMsgQuery($msg,$msgparam, $errmsg, $msgparam));
	} elsif ($ALLOW_POST_UPLOADS && -d $PATH_TRANSLATED && defined $cgi->param('filesubmit')) {
		my @filelist;
		$errmsg=undef;
		$msgparam='';
		foreach my $filename ($cgi->param('file_upload')) {
			next if $filename eq "";
			next unless $cgi->uploadInfo($filename);
			my $rfn= $filename;
			$rfn=~s/\\/\//g; # fix M$ Windows backslashes
			my $destination = $PATH_TRANSLATED.basename($rfn);
			debug("_POST: save $filename to $destination.");
			push(@filelist, basename($rfn));
			if (open(O,">$destination")) {
				if ($ENABLE_FLOCK && !flock(O, LOCK_EX | LOCK_NB)) {
					close(O);
					printHeaderAndContent('403 Forbidden','text/plain','403 Forbidden (flock failed)');
					last;
				}
				while (read($filename,my $buffer,$BUFSIZE || 1048576)>0) {
					print O $buffer;
				}
				flock(O, LOCK_UN) if $ENABLE_FLOCK;
				close(O);
			} else {
				$errmsg='uploadforbidden';
				if ($msgparam eq '') { $msgparam='p1='.$rfn; } else { $msgparam.=', '.$rfn; }
				next;
			}
		}
		if (!defined $errmsg) {
			if ($#filelist>-1) {
				$msg=($#filelist>0)?'uploadmulti':'uploadsingle';
				$msgparam='p1='.($#filelist+1).';p2='.$cgi->escape(substr(join(', ',@filelist), 0, 150));
			} else {
				$errmsg='uploadnothingerr';
			}
		}
		print $cgi->redirect($redirtarget.createMsgQuery($msg,$msgparam,$errmsg,$msgparam));
	} elsif ($ALLOW_ZIP_DOWNLOAD && defined $cgi->param('zip')) {
		my $zip =  Archive::Zip->new();		
		foreach my $file ($cgi->param('file')) {
			if (-d $PATH_TRANSLATED.$file) {
				$zip->addTree($PATH_TRANSLATED.$file, $file);
			} else {
				$zip->addFile($PATH_TRANSLATED.$file, $file);
			}
		}
		my $zfn = basename($PATH_TRANSLATED).'.zip';
		$zfn=~s/ /_/;
		print $cgi->header(-status=>'200 OK', -type=>'application/zip',-Content_disposition=>'attachment; filename='.$zfn);
		$zip->writeToFileHandle(\*STDOUT,0);
	} elsif ($ALLOW_ZIP_UPLOAD && defined $cgi->param('uncompress')) {
		my @zipfiles;
		foreach my $fh ($cgi->param('zipfile_upload')) {
			my $rfn= $fh;
			$rfn=~s/\\/\//g; # fix M$ Windows backslashes
			$rfn=basename($rfn);
			if (open(F,">$PATH_TRANSLATED$rfn")) {
				push @zipfiles, $rfn;
				print F $_ while (<$fh>);
				close(F);
				my $zip = Archive::Zip->new();
				my $status = $zip->read($PATH_TRANSLATED.$rfn);
				if ($status eq $zip->AZ_OK) {
					$zip->extractTree(undef, $PATH_TRANSLATED);
					unlink($PATH_TRANSLATED.$rfn);
				}
			}
		}
		if ($#zipfiles>-1) {
			$msg=($#zipfiles>0)?'zipuploadmulti':'zipuploadsingle';
			$msgparam='p1='.($#zipfiles+1).';p2='.$cgi->escape(substr(join(', ',@zipfiles), 0, 150));
		} else {
			$errmsg='zipuploadnothingerr';
		}
		print $cgi->redirect($redirtarget.createMsgQuery($msg,$msgparam,$errmsg,$msgparam));
		
	} elsif ($ALLOW_FILE_MANAGEMENT && $ALLOW_AFSACLCHANGES && $cgi->param('saveafsacl')) {
		doAFSSaveACL($redirtarget);
	} elsif ($ALLOW_FILE_MANAGEMENT && ($cgi->param('afschgrp')|| $cgi->param('afscreatenewgrp') || $cgi->param('afsdeletegrp') || $cgi->param('afsrenamegrp') || $cgi->param('afsaddusr') || $cgi->param('afsremoveusr'))) {
		doAFSGroupActions($redirtarget);
	} elsif ($ALLOW_FILE_MANAGEMENT && $ENABLE_CLIPBOARD && $cgi->param('action')) {
		my ($msg,$msgparam, $errmsg) ;
		my $srcuri = $cgi->param('srcuri');
		$srcuri=~s/\%([a-f0-9]{2})/chr(hex($1))/eig;
		$srcuri=~s/^$VIRTUAL_BASE//;
		my $srcdir = $DOCUMENT_ROOT.$srcuri;
		my (@success,@failed);
		foreach my $file (split(/\@\/\@/, $cgi->param('files'))) {
			debug("clipboard: $srcdir$file -> $PATH_TRANSLATED$file\n");
			if (rcopy("$srcdir$file", "$PATH_TRANSLATED$file", $cgi->param('action') eq 'cut')) {
				$msg=$cgi->param("action").'success';
				push @success,$file;
			} else {
				$errmsg=$cgi->param("action").'failed';
				push @failed,$file;
			}
		}
		$msg= undef if defined $errmsg;
		$msgparam='p1='.$cgi->escape(substr(join(', ', defined $msg ? @success : @failed),0,150));
		print $cgi->redirect($redirtarget.createMsgQuery($msg,$msgparam,$errmsg,$msgparam));
	} elsif ($ENABLE_CALDAV_SCHEDULE && -d $PATH_TRANSLATED) {
		## NOT IMPLEMENTED YET
	} else {
		debug("_POST: forbidden POST to $PATH_TRANSLATED");
		printHeaderAndContent('403 Forbidden','text/plain','403 Forbidden (unknown request, params:'.join(', ',$cgi->param()).')');
	}
}
sub _OPTIONS {
	debug("_OPTIONS: $PATH_TRANSLATED");
	my $methods;
	my $status = '200 OK';
	my $type;
	if (-e $PATH_TRANSLATED) {
		$type = -d $PATH_TRANSLATED ? 'httpd/unix-directory' : getMIMEType($PATH_TRANSLATED);
		$methods = join(', ', @{getSupportedMethods($PATH_TRANSLATED)});
	} else {
		$status = '404 Not Found';
		$type = 'text/plain';
	}
		
	my $header =$cgi->header(-status=>$status ,-type=>$type, -Content_length=>0);
	$header="DASL: <DAV:basicsearch>\r\n$header" if $ENABLE_SEARCH;
	$header="MS-Author-Via: DAV\r\nDAV: $DAV\r\nAllow: $methods\r\nPublic: $methods\r\nDocumentManagementServer: Properties Schema\r\n$header" if (defined $methods); 

	print $header;
}
sub _TRACE {
	my $status = '200 OK';
	my $content = join("",<>);
	my $type = 'message/http';
	my $via = $cgi->http('Via') ;
	my $addheader = "Via: $ENV{SERVER_NAME}:$ENV{SERVER_PORT}".(defined $via?", $via":"");

	printHeaderAndContent($status, $type, $content, $addheader);
}
sub _GETLIB {
	my $fn = $PATH_TRANSLATED;
	my $status='200 OK';
	my $type=undef;
	my $content="";
	my $addheader="";
	if (!-e $fn) {
		$status='404 Not Found';
		$type='text/plain';
	} else {
		my $su = $ENV{SCRIPT_URI};
		$su=~s/\/[^\/]+$/\// if !-d $fn;
		$addheader="MS-Doclib: $su";
	}
	printHeaderAndContent($status,$type,$content,$addheader);
}

sub _PROPFIND {
	my $fn = $PATH_TRANSLATED;
	my $status='207 Multi-Status';
	my $type ='text/xml';
	my $noroot = 0;
	my $depth = defined $cgi->http('Depth')? $cgi->http('Depth') : -1;
	$noroot=1 if $depth =~ s/,noroot//;
	$depth=-1 if $depth =~ /infinity/i;
	$depth = 0 if $depth == -1 && !$ALLOW_INFINITE_PROPFIND;


	my $xml = join("",<>);
	$xml=qq@<?xml version="1.0" encoding="$CHARSET" ?>\n<D:propfind xmlns:D="DAV:"><D:allprop/></D:propfind>@ 
		if !defined $xml || $xml=~/^\s*$/;

	my $xmldata = "";
	eval { $xmldata = simpleXMLParser($xml); };
	if ($@) {
		debug("_PROPFIND: invalid XML request: $@");
		printHeaderAndContent('400 Bad Request');
		return;
	}

	my $ru = $REQUEST_URI;
	$ru=~s/ /%20/g;
	debug("_PROPFIND: depth=$depth, fn=$fn, ru=$ru");

	my @resps = ();

	## ACL, CalDAV, CardDAV, ...:
	if ( defined $PRINCIPAL_COLLECTION_SET && length($PRINCIPAL_COLLECTION_SET)>1 && $ru =~ /\Q$PRINCIPAL_COLLECTION_SET\E$/) { 
		$fn =~ s/\Q$PRINCIPAL_COLLECTION_SET\E$//;
		$depth=0;
	} elsif (defined $CURRENT_USER_PRINCIPAL && length($CURRENT_USER_PRINCIPAL)>1 && $ru =~ /\Q$CURRENT_USER_PRINCIPAL\E\/?$/) {
		$fn=~s/\Q$CURRENT_USER_PRINCIPAL\E\/?$//;
		$depth=0;
	}

	if (!is_hidden($fn) && -e $fn) {
		my ($props, $all, $noval) =  handlePropFindElement($xmldata);
		if (defined $props) {
			readDirRecursive($fn, $ru, \@resps, $props, $all, $noval, $depth, $noroot);
		} else {
			$status='400 Bad Request';
			$type='text/plain';
		}
	} else {
		$status='404 Not Found';
		$type='text/plain';
	}
	my $content = ($#resps>-1) ? createXML({ 'multistatus' => { 'response'=>\@resps} }) : "" ;
	
	debug("_PROPFIND: status=$status, type=$type");
	debug("_PROPFIND: REQUEST:\n$xml\nEND-REQUEST");
	debug("_PROPFIND: RESPONSE:\n$content\nEND-RESPONSE");
	printHeaderAndContent($status,$type,$content);
	
}
sub _PROPPATCH {
	debug("_PROPPATCH: $PATH_TRANSLATED");
	my $fn = $PATH_TRANSLATED;
	my $status = '403 Forbidden';
	my $type = 'text/plain';
	my $content = "";
	if (-e $fn && !isAllowed($fn)) {
		$status = '423 Locked';
	} elsif (-e $fn) {
		my $xml = join("",<>);


		debug("_PROPPATCH: REQUEST: $xml");
		my $dataRef;
		eval { $dataRef = simpleXMLParser($xml) };	
		if ($@) {
			debug("_PROPPATCH: invalid XML request: $@");
			printHeaderAndContent('400 Bad Request');
			return;
		}
		my @resps = ();
		my %resp_200 = ();
		my %resp_403 = ();

		handlePropertyRequest($xml, $dataRef, \%resp_200, \%resp_403);
		
		push @resps, \%resp_200 if defined $resp_200{href};
		push @resps, \%resp_403 if defined $resp_403{href};
		$status='207 Multi-Status';
		$type='text/xml';
		$content = createXML( { multistatus => { response => \@resps} });
	} else {
		$status='404 Not Found';
	}
	debug("_PROPPATCH: RESPONSE: $content");
	printHeaderAndContent($status, $type, $content);
}

sub _PUT {
	my $status='204 No Content';
	my $type = 'text/plain';
	my $content = "";
	my $buffer;

	debug("_PUT $PATH_TRANSLATED; dirname=".dirname($PATH_TRANSLATED));

	if (defined $cgi->http('Content-Range'))  {
		$status='501 Not Implemented';
	} elsif (-d dirname($PATH_TRANSLATED) && (!$IGNOREFILEPERMISSIONS  && !-w dirname($PATH_TRANSLATED))) {
		$status='403 Forbidden';
	} elsif (preConditionFailed($PATH_TRANSLATED)) {
		$status='412 Precondition Failed';
	} elsif (!isAllowed($PATH_TRANSLATED)) {
		$status='423 Locked';
	#} elsif (defined $ENV{HTTP_EXPECT} && $ENV{HTTP_EXPECT} =~ /100-continue/) {
	#	$status='417 Expectation Failed';
	} elsif (-d dirname($PATH_TRANSLATED)) {
		if (! -e $PATH_TRANSLATED) {
			debug("_PUT: created...");
			$status='201 Created';
			$type='text/html';
			$content = qq@<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">\n<html><head><title>201 Created</title></head>@
				 . qq@<<body><h1>Created</h1><p>Resource $ENV{'QUERY_STRING'} has been created.</p></body></html>\n@;
		}
		if (open(my $f,">$PATH_TRANSLATED")) {
			if ($ENABLE_FLOCK && !flock($f, LOCK_EX | LOCK_NB)) {
				$status = '423 Locked';
				$content=""; 
				$type='text/plain';
			} else {
				binmode STDIN;
				binmode $f;
				my $maxread = 0;
				while (my $read = read(STDIN, $buffer, $BUFSIZE || 1048576)>0) {
					print $f $buffer;
					$maxread+=$read;
				}
				flock($f, LOCK_UN) if $ENABLE_FLOCK;
				close($f);
				inheritLock();
				if (exists $ENV{CONTENT_LENGTH} && $maxread != $ENV{CONTENT_LENGTH}) {
					debug("_PUT: ERROR: maxread=$maxread, content-length: $ENV{CONTENT_LENGTH}");
					#$status='400';
				}
				logger("PUT($PATH_TRANSLATED)");
			}
		} else {
			$status='403 Forbidden';
			$content="";
			$type='text/plain';
		}
	} else {
		$status='409 Conflict';
	}
	printHeaderAndContent($status,$type,$content);
}
sub _COPY {
	my $status = '201 Created';
	my $depth = $cgi->http('Depth');
	my $host = $cgi->http('Host');
	my $destination = $cgi->http('Destination');
	my $overwrite = defined $cgi->http('Overwrite')?$cgi->http('Overwrite') : "T";
	$destination=~s@^https?://([^\@]+\@)?\Q$host\E(:\d+)?$VIRTUAL_BASE@@;
	$destination=uri_unescape($destination);
	$destination=uri_unescape($destination);
	$destination=$DOCUMENT_ROOT.$destination;

	debug("_COPY: $PATH_TRANSLATED => $destination");

	if ( (!defined $destination) || ($destination eq "") || ($PATH_TRANSLATED eq $destination) ) {
		$status = '403 Forbidden';
	} elsif ( -e $destination && $overwrite eq "F") {
		$status = '412 Precondition Failed';
	} elsif ( ! -d dirname($destination)) {
		$status = "409 Conflict - $destination";
	} elsif ( !isAllowed($destination,-d $PATH_TRANSLATED) ) {
		$status = '423 Locked';
	} elsif ( -d $PATH_TRANSLATED && $depth == 0 ) {
		if (-e $destination) {
			$status = '204 No Content' ;
		} else {
			if (mkdir $destination) {
				inheritLock($destination);
			} else {
				$status = '403 Forbidden';
			}
		}
	} else {
		$status = '204 No Content' if -e $destination;
		if (rcopy($PATH_TRANSLATED, $destination)) {
			inheritLock($destination,1);
			logger("COPY($PATH_TRANSLATED, $destination)");
		} else {
			$status = '403 Forbidden - copy failed';
		}
	}

	printHeaderAndContent($status);
}
sub _MOVE {
	my $status = '201 Created';
	my $host = $cgi->http('Host');
	my $destination = $cgi->http('Destination');
	my $overwrite = defined $cgi->http('Overwrite')?$cgi->http('Overwrite') : "T";
	debug("_MOVE: $PATH_TRANSLATED => $destination");
	$destination=~s@^https?://([^\@]+\@)?\Q$host\E(:\d+)?$VIRTUAL_BASE@@;
	$destination=uri_unescape($destination);
	$destination=uri_unescape($destination);
	$destination=$DOCUMENT_ROOT.$destination;

	if ( (!defined $destination) || ($destination eq "") || ($PATH_TRANSLATED eq $destination) ) {
		$status = '403 Forbidden';
	} elsif ( -e $destination && $overwrite eq "F") {
		$status = '412 Precondition Failed';
	} elsif ( ! -d dirname($destination)) {
		$status = "409 Conflict - ".dirname($destination);
	} elsif (!isAllowed($PATH_TRANSLATED,-d $PATH_TRANSLATED) || !isAllowed($destination, -d $destination)) {
		$status = '423 Locked';
	} else {
		unlink($destination) if -f $destination;
		$status = '204 No Content' if -e $destination;
		if (rmove($PATH_TRANSLATED, $destination)) {
			db_moveProperties($PATH_TRANSLATED, $destination);
			db_delete($PATH_TRANSLATED);
			inheritLock($destination,1);
			logger("MOVE($PATH_TRANSLATED, $destination)");
		} else {
			$status = '403 Forbidden';
		}
	}
	debug("_MOVE: status=$status");
	printHeaderAndContent($status);
}
sub _DELETE {
	my $status = '204 No Content';
	# check all files are writeable and than remove it

	debug("_DELETE: $PATH_TRANSLATED");

	my @resps = ();
	if (!-e $PATH_TRANSLATED) {
		$status='404 Not Found';
	} elsif (($REQUEST_URI=~/\#/ && $PATH_TRANSLATED!~/\#/) || (defined $ENV{QUERY_STRING} && $ENV{QUERY_STRING} ne "")) {
		$status='400 Bad Request';
	} elsif (!isAllowed($PATH_TRANSLATED)) {
		$status='423 Locked';
	} else {
		if ($ENABLE_TRASH) {
			$status='404 Forbidden' unless moveToTrash($PATH_TRANSLATED);
		} else {
			deltree($PATH_TRANSLATED, \my @err);
			logger("DELETE($PATH_TRANSLATED)");
			for my $diag (@err) {
				my ($file, $message) = each %$diag;
				push @resps, { href=>$file, status=>"403 Forbidden - $message" };
			}
			$status = '207 Multi-Status' if $#resps>-1;
		}
	}
		
	my $content = $#resps>-1 ? createXML({ 'multistatus' => { 'response'=>\@resps} }) : "";
	printHeaderAndContent($status, $#resps>-1 ? 'text/xml' : undef, $content);
	debug("_DELETE RESPONSE (status=$status): $content");
}
sub _MKCALENDAR {
	_MKCOL(1);
}
sub _MKCOL {
	my ($cal) = @_;
	my $status='201 Created';
	my ($type,$content);
	debug("_MKCOL: $PATH_TRANSLATED");
	my $body = join("",<>);
	my $dataRef;
	if ($body ne "") {
		debug("_MKCOL: yepp #1".$cgi->content_type());
		# maybe extended mkcol (RFC5689)
		if ($cgi->content_type() =~/\/xml/) {
			eval { $dataRef = simpleXMLParser($body) };	
			if ($@) {
				debug("_MKCOL: invalid XML request: $@");
				printHeaderAndContent('400 Bad Request');
				return;
			}
			if (ref($$dataRef{'{DAV:}set'}) !~ /(ARRAY|HASH)/) {
				printHeaderAndContent('400 Bad Request');
				return;
			}
		} else {
			$status = '415 Unsupported Media Type';
			printHeaderAndContent($status, $type, $content);
			return;
		}
	} 
	if (-e $PATH_TRANSLATED) {
		$status = '405 Method Not Allowed';
	} elsif (!-e dirname($PATH_TRANSLATED)) {
		$status = '409 Conflict';
	} elsif (!$IGNOREFILEPERMISSIONS && !-w dirname($PATH_TRANSLATED)) {
		$status = '403 Forbidden';
	} elsif (!isAllowed($PATH_TRANSLATED)) {
		debug("_MKCOL: not allowed!");
		$status = '423 Locked';
	} elsif (-e $PATH_TRANSLATED) {
		$status = '409 Conflict';
	} elsif (-d dirname($PATH_TRANSLATED)) {
		debug("_MKCOL: create $PATH_TRANSLATED");


		if (mkdir($PATH_TRANSLATED)) {
			my (%resp_200, %resp_403);
			handlePropertyRequest($body, $dataRef, \%resp_200, \%resp_403);
			## ignore errors from property request
			inheritLock();
			logger("MKCOL($PATH_TRANSLATED)");
		} else {
			$status = '403 Forbidden'; 
		}
	} else {	
		debug("_MKCOL: parent direcory does not exists");
		$status = '409 Conflict';
	}
	printHeaderAndContent($status, $type, $content);
}
sub _LOCK {
	debug("_LOCK: $PATH_TRANSLATED");
	
	my $fn = $PATH_TRANSLATED;
	my $ru = $REQUEST_URI;
	my $depth = defined $cgi->http('Depth')?$cgi->http('Depth'):'infinity';
	my $timeout = $cgi->http('Timeout');
	my $status = '200 OK';
	my $type = 'application/xml';
	my $content = "";
	my $addheader = undef;

	my $xml = join('',<>);
	my $xmldata = $xml ne "" ? simpleXMLParser($xml) : { };

	my $token ="opaquelocktoken:".getuuid($fn);

	if (!-e $fn && !-e dirname($fn)) {
		$status='409 Conflict';
		$type='text/plain';
	} elsif (!isLockable($fn, $xmldata)) {
		debug("_LOCK: not lockable ... but...");
		if (isAllowed($fn)) {
			$status='200 OK';
			lockResource($fn, $ru, $xmldata, $depth, $timeout, $token);
			$content = createXML({prop=>{lockdiscovery => getLockDiscovery($fn)}});	
		} else {
			$status='423 Locked';
			$type='text/plain';
		}
	} elsif (!-e $fn) {
		if (open(F,">$fn")) {
			print F '';
			close(F);
			my $resp = lockResource($fn, $ru, $xmldata, $depth, $timeout,$token);
			if (defined $$resp{multistatus}) {
				$status = '207 Multi-Status'; 
			} else {
				$addheader="Lock-Token: $token";
				$status='201 Created';
			}
			$content=createXML($resp);
		} else {
			$status='403 Forbidden';
			$type='text/plain';
		}
	} else {
		my $resp = lockResource($fn, $ru, $xmldata, $depth, $timeout, $token);
		$addheader="Lock-Token: $token";
		$content=createXML($resp);
		$status = '207 Multi-Status' if defined $$resp{multistatus};
	}
	debug("_LOCK: REQUEST: $xml");
	debug("_LOCK: RESPONSE: $content");
	debug("_LOCK: status: $status, type=$type");
	printHeaderAndContent($status,$type,$content,$addheader);	
}
sub _UNLOCK {
	my $status = '403 Forbidden';
	my $token = $cgi->http('Lock-Token');

	$token=~s/[\<\>]//g;
	debug("_UNLOCK: $PATH_TRANSLATED (token=$token)");
	
	if (!defined $token) {
		$status = '400 Bad Request';
	} elsif (isLocked($PATH_TRANSLATED)) {
		if (unlockResource($PATH_TRANSLATED, $token)) {
			$status = '204 No Content';
		} else {
			$status = '423 Locked';
		}
	} else {
		$status = '409 Conflict';
	}
	printHeaderAndContent($status);
}
sub _ACL {
	my $fn = $PATH_TRANSLATED;
	my $status = '200 OK';
	my $content = "";
	my $type;
	my %error;
	debug("_ACL($fn)");
	my $xml = join("",<>);
	my $xmldata = "";
	eval { $xmldata = simpleXMLParser($xml,1); };
	if ($@) {
		debug("_ACL: invalid XML request: $@");
		$status='400 Bad Request';
		$type='text/plain';
		$content='400 Bad Request';
	} elsif (!-e $fn) {
		$status = '404 Not Found';
		$type = 'text/plain';
		$content='404 Not Found';
	} elsif (!isAllowed($fn)) {
		$status = '423 Locked';
		$type = 'text/plain';
		$content='423 Locked';
	} elsif (!exists $$xmldata{'{DAV:}acl'}) {
		$status='400 Bad Request';
		$type='text/plain';
		$content='400 Bad Request';
	} else {
		my @ace;
		if (ref($$xmldata{'{DAV:}acl'}{'{DAV:}ace'}) eq 'HASH') {
			push @ace, $$xmldata{'{DAV:}acl'}{'{DAV:}ace'};
		} elsif (ref($$xmldata{'{DAV:}acl'}{'{DAV:}ace'}) eq 'ARRAY') {
			push @ace, @{$$xmldata{'{DAV:}acl'}{'{DAV:}ace'}};
		} else {
			printHeaderAndContent('400 Bad Request');
			return;
		}
		foreach my $ace (@ace) {
			my $p;
			my ($user,$group,$other) = (0,0,0);
			if (defined ($p = $$ace{'{DAV:}principal'})) {
				if (exists $$p{'{DAV:}property'}{'{DAV:}owner'}) { 
					$user=1;
				} elsif (exists $$p{'{DAV:}property'}{'{DAV:}group'}) {
					$group=1;
				} elsif (exists $$p{'{DAV:}all'}) {
					$other=1;
				} else {
					printHeaderAndContent('400 Bad Request');
					return;
				}
			} else {
				printHeaderAndContent('400 Bad Request');
				return;
			}
			my ($read,$write) = (0,0);
			if (exists $$ace{'{DAV:}grant'}) {
				$read=1 if exists $$ace{'{DAV:}grant'}{'{DAV:}privilege'}{'{DAV:}read'};
				$write=1 if exists $$ace{'{DAV:}grant'}{'{DAV:}privilege'}{'{DAV:}write'};
			} elsif (exists $$ace{'{DAV:}deny'}) {
				$read=-1 if exists $$ace{'{DAV:}deny'}{'{DAV:}privilege'}{'{DAV:}read'};
				$write=-1 if exists $$ace{'{DAV:}deny'}{'{DAV:}privilege'}{'{DAV:}write'};
			} else {
				printHeaderAndContent('400 Bad Request');
				return;
				
			}
			if ($read==0 && $write==0) {
				printHeaderAndContent('400 Bad Request');
				return;
			}
			my @stat = stat($fn);
			my $mode = $stat[2];
			$mode = $mode & 07777;
			
			my $newperm = $mode;
			if ($read!=0) {
				my $mask = $user? 0400 : $group ? 0040 : 0004;
				$newperm = ($read>0) ? $newperm | $mask : $newperm & ~$mask
			} 
			if ($write!=0) {
				my $mask = $user? 0200 : $group ? 0020 : 0002;
				$newperm = ($write>0) ? $newperm | $mask : $newperm & ~$mask;
			}
			debug("_ACL: old perm=".sprintf('%4o',$mode).", new perm=".sprintf('%4o',$newperm));
			if (!chmod($newperm, $fn)) {
				$status='403 Forbidden';
				$type='text/plain';
				$content='403 Forbidden';
			}

		}
		
	}
	printHeaderAndContent($status, $type, $content);
}
sub _REPORT {
	my $fn = $PATH_TRANSLATED;
	my $ru = $REQUEST_URI;
	my $depth = defined $cgi->http('Depth')? $cgi->http('Depth') : 0;
	$depth=-1 if $depth =~ /infinity/i;
	debug("_REPORT($fn,$ru)");
	my $status = '200 OK';
	my $content = "";
	my $type;
	my %error;
	my $xml = join("",<>);
	my $xmldata = "";
	eval { $xmldata = simpleXMLParser($xml,1); };
	if ($@) {
		debug("_REPORT: invalid XML request: $@");
		debug("_REPORT: xml-request=$xml");
		$status='400 Bad Request';
		$type='text/plain';
		$content='400 Bad Request';
	} elsif (!-e $fn) {
		$status = '404 Not Found';
		$type = 'text/plain';
		$content='404 Not Found';
	} else {
		# MUST CalDAV: DAV:expand-property
		$status='207 Multi-Status';
		$type='application/xml';
		my @resps;
		my @hrefs;
		my $rn;
		my @reports = keys %{$xmldata};
		debug("_REPORT: report=".$reports[0]) if $#reports >-1;
		if (defined $$xmldata{'{DAV:}acl-principal-prop-set'}) {
			my @props;
			handlePropElement($$xmldata{'{DAV:}acl-principal-prop-set'}{'{DAV:}prop'}, \@props);
			push @resps, { href=>$ru, propstat=> getPropStat($fn,$ru,\@props) };
		} elsif (defined $$xmldata{'{DAV:}principal-match'}) {
			if ($depth!=0) {
				printHeaderAndStatus('400 Bad Request');
				return;
			}
			# response, href
			my @props;
			handlePropElement($$xmldata{'{DAV:}principal-match'}{'{DAV:}prop'}, \@props) if (exists $$xmldata{'{DAV:}principal-match'}{'{DAV:}prop'});
			readDirRecursive($fn, $ru, \@resps, \@props, 0, 0, 1, 1);
		} elsif (defined $$xmldata{'{DAV:}principal-property-search'}) {
			if ($depth!=0) {
				printHeaderAndStatus('400 Bad Request');
				return;
			}

			my @props;
			handlePropElement($$xmldata{'{DAV:}principal-property-search'}{'{DAV:}prop'}, \@props) if exists $$xmldata{'{DAV:}principal-property-search'}{'{DAV:}prop'};
			readDirRecursive($fn, $ru, \@resps, \@props, 0, 0, 1, 1);
			### XXX filter data
			my @propertysearch;
			if (ref($$xmldata{'{DAV:}principal-property-search'}{'{DAV:}property-search'}) eq 'HASH') {
				push @propertysearch, $$xmldata{'{DAV:}principal-property-search'}{'{DAV:}property-search'};
			} elsif (ref($$xmldata{'{DAV:}principal-property-search'}{'{DAV:}property-search'}) eq 'ARRAY') {
				push @propertysearch, @{$$xmldata{'{DAV:}principal-property-search'}{'{DAV:}property-search'}};
			}
		} elsif (defined $$xmldata{'{DAV:}principal-search-property-set'}) {
			my %resp;
			$resp{'principal-search-property-set'} = { 
				'principal-search-property' =>
					[
						{ prop => { displayname=>undef }, description => 'Full name' },
					] 
			};
			$content = createXML(\%resp);
			$status = '200 OK';
			$type = 'text/xml';
		} elsif (defined $$xmldata{'{urn:ietf:params:xml:ns:caldav}free-busy-query'}) {
			($status,$type) = ('200 OK', 'text/calendar');
			$content="BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//Example Corp.//CalDAV Server//EN\r\nBEGIN:VFREEBUSY\r\nEND:VFREEBUSY\r\nEND:VCALENDAR";
		} elsif (defined $$xmldata{'{urn:ietf:params:xml:ns:caldav}calendar-query'}) { ## missing filter
			$rn = '{urn:ietf:params:xml:ns:caldav}calendar-query';
			readDirBySuffix($fn, $ru, \@hrefs, 'ics', $depth);
		} elsif (defined $$xmldata{'{urn:ietf:params:xml:ns:caldav}calendar-multiget'}) { ## OK - complete
			$rn = '{urn:ietf:params:xml:ns:caldav}calendar-multiget';
			if (!defined $$xmldata{$rn}{'{DAV:}href'} || !defined $$xmldata{$rn}{'{DAV:}prop'}) {
				printHeaderAndContent('404 Bad Request');
				return;
			}
			if (ref($$xmldata{$rn}{'{DAV:}href'}) eq 'ARRAY') {
				@hrefs = @{$$xmldata{$rn}{'{DAV:}href'}};
			} else {
				push @hrefs,  $$xmldata{$rn}{'{DAV:}href'};
			}
						
		} elsif (defined $$xmldata{'{urn:ietf:params:xml:ns:carddav}addressbook-query'}) {
			$rn = '{urn:ietf:params:xml:ns:carddav}addressbook-query';
			readDirBySuffix($fn, $ru, \@hrefs, 'vcf', $depth);
		} elsif (defined $$xmldata{'{urn:ietf:params:xml:ns:carddav}addressbook-multiget'}) {
			$rn = '{urn:ietf:params:xml:ns:carddav}addressbook-multiget';
			if (!defined $$xmldata{$rn}{'{DAV:}href'} || !defined $$xmldata{$rn}{'{DAV:}prop'}) {
				printHeaderAndContent('404 Bad Request');
				return;
			}
			if (ref($$xmldata{$rn}{'{DAV:}href'}) eq 'ARRAY') {
				@hrefs = @{$$xmldata{$rn}{'{DAV:}href'}};
			} else {
				push @hrefs,  $$xmldata{$rn}{'{DAV:}href'};
			}
		} else {
			$status ='400 Bad Request';
			$type = 'text/plain';
			$content = '400 Bad Request';
		}
		if ($rn) {
			foreach my $href (@hrefs) {
				my(%resp_200, %resp_404);
				$resp_200{status}='HTTP/1.1 200 OK';
				$resp_404{status}='HTTP/1.1 404 Not Found';
				my $nhref = $href;
				$nhref=~s/$VIRTUAL_BASE//;
				my $nfn.=$DOCUMENT_ROOT.$nhref;
				debug("_REPORT: nfn=$nfn, href=$href");
				if (!-e $nfn) {
					push @resps, { href=>$href, status=>'HTTP/1.1 404 Not Found' };
					next;
				} elsif (-d $nfn) {
					push @resps, { href=>$href, status=>'HTTP/1.1 403 Forbidden' };
					next;
				}
				my @props;
				handlePropElement($$xmldata{$rn}{'{DAV:}prop'}, \@props) if exists $$xmldata{$rn}{'{DAV:}prop'};
				push @resps, { href=>$href, propstat=> getPropStat($nfn,$nhref,\@props) };
			}
			### push @resps, { } if ($#hrefs==-1);  ## empty multistatus response not supported
		}
		$content=createXML({multistatus => $#resps>-1 ? { response => \@resps } : undef }) if $#resps>-1;

	}
	debug("_REPORT: REQUEST: $xml");
	debug("_REPORT: RESPONSE: $content");
	printHeaderAndContent($status, $type, $content);
}
sub _SEARCH {
	my @resps;
	my $status = 'HTTP/1.1 207 Multistatus';
	my $content = "";
	my $type='application/xml';
	my @errors;

	my $xml = join("",<>);
	my $xmldata = "";
	eval { $xmldata = simpleXMLParser($xml,1); };
	if ($@) {
		debug("_SEARCH: invalid XML request: $@");
		debug("_SEARCH: xml-request=$xml");
		$status='400 Bad Request';
		$type='text/plain';
		$content='400 Bad Request';
	} elsif (exists $$xmldata{'{DAV:}query-schema-discovery'}) {
		debug("_SEARCH: found query-schema-discovery");
		push @resps, { href=>$REQUEST_URI, status=>$status, 
				'query-schema'=> { basicsearchschema=> { properties => { 
					propdesc => [
						{ 'any-other-property'=>undef, searchable=>undef, selectable=>undef, caseless=>undef, sortable=>undef }
					]
				}, operators => { 'opdesc allow-pcdata="yes"' => 
								[ 
									{ like => undef, 'operand-property'=>undef, 'operand-literal'=>undef },
									{ contains => undef }
								] 
				}}}};
	} elsif (exists $$xmldata{'{DAV:}searchrequest'}) {
		foreach my $s (keys %{$$xmldata{'{DAV:}searchrequest'}}) {
			if ($s =~ /{DAV:}basicsearch/) {
				handleBasicSearch($$xmldata{'{DAV:}searchrequest'}{$s}, \@resps,\@errors);
			}
		}
	}
	if ($#errors>-1) {
		$content = createXML({error=>\@errors});
		$status='409 Conflict';
	} elsif ($#resps > -1) {
		$content = createXML({multistatus=>{ response=>\@resps }});
	} else {
		$content = createXML({multistatus=>{ response=> { href=>$REQUEST_URI, status=>'404 Not Found' }}});
	}
	printHeaderAndContent($status, $type, $content);
}
sub _BIND {
	my ($status,$type,$content) = ('200 OK', undef, undef);
	my $overwrite = defined $cgi->http('Overwrite')?$cgi->http('Overwrite') : "T";
	my $xml = join("",<>);
	my $xmldata = "";
	my $host = $cgi->http('Host');
	eval { $xmldata = simpleXMLParser($xml,0); };
	if ($@) {
		$status='400 Bad Request';
		$type='text/plain';
		$content='400 Bad Request';
	} else {
		my $segment = $$xmldata{'{DAV:}segment'};
		my $href = $$xmldata{'{DAV:}href'};
		$href=~s/^https?:\/\/\Q$host\E+$VIRTUAL_BASE//;
		$href=uri_unescape(uri_unescape($href));
		my $src = $DOCUMENT_ROOT.$href;
		my $dst = $PATH_TRANSLATED.$segment;

		my $ndst = $dst;
		$ndst=~s /\/$//;

		if (!-e $src) { 
			$status ='404 Not Found';
		} elsif ( -e $dst && ! -l $ndst) {
			$status = '403 Forbidden';
		} elsif (-e $dst && -l $ndst && $overwrite eq "F") {
			$status = '403 Forbidden';
		} else {
			$status = -l $ndst ? '204 No Content' : '201 Created';
			unlink($ndst) if -l $ndst;
			$status = '403 Forbidden' if (!symlink($src, $dst));
		}
	}
	printHeaderAndContent($status, $type, $content);
}
sub _UNBIND {
	my ($status,$type,$content) = ('204 No Content', undef, undef);
	my $xml = join("",<>);
	my $xmldata = "";
	eval { $xmldata = simpleXMLParser($xml,0); };
	if ($@) {
		$status='400 Bad Request';
		$type='text/plain';
		$content='400 Bad Request';
	} else {
		my $segment = $$xmldata{'{DAV:}segment'};
		my $dst = $PATH_TRANSLATED.$segment;
		if (!-e $dst ) {
			$status = '404 Not Found';
		} elsif (!-l $dst) {
			$status = '403 Forbidden';
		} elsif (!unlink($dst)) {
			$status = '403 Forbidden';
		}
	}
	printHeaderAndContent($status, $type, $content);
}
sub _REBIND {
	my ($status,$type,$content) = ('200 OK', undef, undef);
	my $overwrite = defined $cgi->http('Overwrite')?$cgi->http('Overwrite') : "T";
	my $xml = join("",<>);
	my $xmldata = "";
	my $host = $cgi->http('Host');
	eval { $xmldata = simpleXMLParser($xml,0); };
	if ($@) {
		$status='400 Bad Request';
		$type='text/plain';
		$content='400 Bad Request';
	} else {
		my $segment = $$xmldata{'{DAV:}segment'};
		my $href = $$xmldata{'{DAV:}href'};
		$href=~s/^https?:\/\/\Q$host\E+$VIRTUAL_BASE//;
		$href=uri_unescape(uri_unescape($href));
		my $src = $DOCUMENT_ROOT.$href;
		my $dst = $PATH_TRANSLATED.$segment;

		my $nsrc = $src; $nsrc =~ s/\/$//;
		my $ndst = $dst; $ndst =~ s/\/$//;

		if (!-e $src) {
			$status = '404 Not Found';
		} elsif (!-l $nsrc) { 
			$status = '403 Forbidden';
		} elsif (-e $dst && $overwrite ne 'T') {
			$status = '403 Forbidden';
		} elsif (-e $dst && !-l $ndst) {
			$status = '403 Forbidden';
		} else {
			$status = -l $ndst ? '204 No Content' : '201 Created';
			unlink($ndst) if -l $ndst;
			if (!rename($nsrc, $ndst)) {
				my $orig = readlink($nsrc);
				$status = '403 Forbidden' unless symlink($orig, $dst) && unlink($nsrc);
			}
		}
	}
	printHeaderAndContent($status, $type, $content);
}
sub changeFilePermissions {
	my ($fn, $mode, $type, $recurse, $visited) = @_;
	if ($type eq 's') {
		chmod($mode, $fn);
	} else {
		my @stat = stat($fn);
		my $newmode;
		$newmode = $stat[2] | $mode if $type eq 'a';
		$newmode = $stat[2] ^ ($stat[2] & $mode ) if $type eq 'r';
		chmod($newmode, $fn);
	}
	my $nfn = File::Spec::Link->full_resolve($fn);
	return if exists $$visited{$nfn};
	$$visited{$nfn}=1;

	if ($recurse && -d $fn) {
		if (opendir(my $dir, $fn)) {
			foreach my $f ( grep { !/^\.{1,2}$/ } readdir($dir)) {
				$f.='/' if -d "$fn$f" && $f!~/\/$/;
				changeFilePermissions($fn.$f, $mode, $type, $recurse, $visited);
			}
			closedir($dir);
		}
	}
}
sub buildExprFromBasicSearchWhereClause {
	my ($op, $xmlref, $superop) = @_;
	my ($expr,$type) = ( '', '', undef);
	my $ns = '{DAV:}';
	if (!defined $op) {
		my @ops = keys %{$xmlref};
		return buildExprFromBasicSearchWhereClause($ops[0], $$xmlref{$ops[0]}); 
	}

	$op=~s/\Q$ns\E//;
	$type='bool';

	if (ref($xmlref) eq 'ARRAY') {	
		foreach my $oo (@{$xmlref}) {
			my ($ne,$nt) = buildExprFromBasicSearchWhereClause($op, $oo, $superop);
			my ($nes,$nts) = buildExprFromBasicSearchWhereClause($superop, undef, $superop);
			$expr.= $nes if $expr ne "";
			$expr.= "($ne)";
		}
		return $expr;
	}

	study $op;
	if ($op =~ /^(and|or)$/) {
		if (ref($xmlref) eq 'HASH') {
			foreach my $o (keys %{$xmlref}) {
				$expr .= $op eq 'and' ? ' && ' : ' || ' if $expr ne "";
				my ($ne, $nt) =  buildExprFromBasicSearchWhereClause($o, $$xmlref{$o}, $op);
				$expr .= "($ne)";
			}
		} else {
			return $op eq 'and' ? ' && ' : ' || ';
		}
	} elsif ($op eq 'not') {
		my @k = keys %{$xmlref};
		my ($ne,$nt) = buildExprFromBasicSearchWhereClause($k[0], $$xmlref{$k[0]});
		$expr="!($ne)";
	} elsif ($op eq 'is-collection') {
		$expr="getPropValue('{DAV:}iscollection',\$filename,\$request_uri)==1";
	} elsif ($op eq 'is-defined') {
		my ($ne,$nt)=buildExprFromBasicSearchWhereClause('{DAV:}prop',$$xmlref{'{DAV:}prop'});
		$expr="$ne ne '__undef__'";
	} elsif ($op =~ /^(language-defined|language-matches)$/) {
		$expr='0!=0';
	} elsif ($op =~ /^(eq|lt|gt|lte|gte)$/) {
		my $o = $op;
		my ($ne1,$nt1) = buildExprFromBasicSearchWhereClause('{DAV:}prop',$$xmlref{'{DAV:}prop'});
		my ($ne2,$nt2) = buildExprFromBasicSearchWhereClause('{DAV:}literal', $$xmlref{'{DAV:}literal'});
		$ne2 =~ s/'/\\'/sg;
		$ne2 = $SEARCH_SPECIALCONV{$nt1} ? $SEARCH_SPECIALCONV{$nt1}."('$ne2')" : "'$ne2'";
		my $cl= $$xmlref{'caseless'} || $$xmlref{'{DAV:}caseless'} || 'yes';
		$expr = (($nt1 =~ /(string|xml)/ && $cl ne 'no')?"lc($ne1)":$ne1)
                      . ' '.($SEARCH_SPECIALOPS{$nt1}{$o} || $o).' '
		      . (($nt1 =~ /(string|xml)/ && $cl ne 'no')?"lc($ne2)":$ne2);
	} elsif ($op eq 'like') {
		my ($ne1,$nt1) = buildExprFromBasicSearchWhereClause('{DAV:}prop',$$xmlref{'{DAV:}prop'});
		my ($ne2,$nt2) = buildExprFromBasicSearchWhereClause('{DAV:}literal', $$xmlref{'{DAV:}literal'});
		$ne2=~s/\//\\\//gs;     ## quote slashes 
		$ne2=~s/(?<!\\)_/./gs;  ## handle unescaped wildcard _ -> .
		$ne2=~s/(?<!\\)%/.*/gs; ## handle unescaped wildcard % -> .*
		my $cl= $$xmlref{'caseless'} || $$xmlref{'{DAV:}caseless'} || 'yes';
		$expr = "$ne1 =~ /$ne2/s" . ($cl eq 'no'?'':'i');
	} elsif ($op eq 'contains') {
		my $content = ref($xmlref) eq "" ? $xmlref : $$xmlref{content};
		my $cl = ref($xmlref) eq "" ? 'yes' : ($$xmlref{caseless} || $$xmlref{'{DAV:}caseless'} || 'yes');
		$content=~s/\//\\\//g;
		$expr="getFileContent(\$filename) =~ /\\Q$content\\E/s".($cl eq 'no'?'':'i');
	} elsif ($op eq 'prop') {
		my @props = keys %{$xmlref};
		$props[0] =~ s/'/\\'/sg;
		$expr = "getPropValue('$props[0]',\$filename,\$request_uri)";
		$type = $SEARCH_PROPTYPES{$props[0]} || $SEARCH_PROPTYPES{default};
		$expr = $SEARCH_SPECIALCONV{$type}."($expr)" if exists $SEARCH_SPECIALCONV{$type};
	} elsif ($op eq 'literal') {
		$expr = ref($xmlref) ne "" ? convXML2Str($xmlref) : $xmlref;
		$type = $op;
	} else {
		$expr= $xmlref;
		$type= $op;
	}

	return ($expr, $type);
}
sub convXML2Str {
	my ($xml) = @_;
	return defined $xml ? lc(createXML($xml,1)) : $xml;
}
sub getPropValue {
	my ($prop, $fn, $uri) = @_;
	my (%stat,%r200,%r404);

	return $CACHE{getPropValue}{$fn}{$prop} if exists $CACHE{getPropValue}{$fn}{$prop};

	my $propname = $prop;
	$propname=~s/^{[^}]*}//;

	my $propval = grep(/^\Q$propname\E$/,@PROTECTED_PROPS)==0 ? db_getProperty($fn, $prop) : undef;

	if (! defined $propval) {
		getProperty($fn, $uri, $propname, undef, \%r200, \%r404) ;
		$propval = $r200{prop}{$propname};
	}

	$propval = defined $propval ? $propval : '__undef__';

	$CACHE{getPropValue}{$fn}{$prop} = $propval;

	debug("getPropValue: $prop = $propval");

	return $propval;
}
sub doBasicSearch {
	my ($expr, $base, $href, $depth, $limit, $matches, $visited) = @_;
	return if defined $limit && $limit > 0 && $#$matches + 1 >= $limit;

	return if defined $depth && $depth ne 'infinity' && $depth < 0 ;

	$base.='/' if -d $base && $base !~ /\/$/;
	$href.='/' if -d $base && $href !~ /\/$/;

	my $filename = $base;
	my $request_uri = $href;

	my $res = eval  $expr ;
	if ($@) {
		debug("doBasicSearch: problem in $expr: $@");
	} elsif ($res) {
		debug("doBasicSearch: $base MATCHED");
		push @{$matches}, { fn=> $base, href=> $href };
	}
	my $nbase = File::Spec::Link->full_resolve($base);
	return if exists $$visited{$nbase} && ($depth eq 'infinity' || $depth < 0);
	$$visited{$nbase}=1;

	if ((-d $base)&&(opendir(my $d, $base))) {
		foreach my $sf (grep { !/^\.{1,2}$/ } readdir($d)) {
			my $nbase = $base.$sf;
			my $nhref = $href.$sf;
			doBasicSearch($expr, $base.$sf, $href.$sf, defined $depth  && $depth ne 'infinity' ? $depth - 1 : $depth, $limit, $matches, $visited);
		}
		closedir($d);
	}
}
sub handleBasicSearch {
	my ($xmldata, $resps, $error) = @_;
	# select > (allprop | prop)  
	my ($propsref,  $all, $noval) = handlePropFindElement($$xmldata{'{DAV:}select'});
	# where > op > (prop,literal) 
	my ($expr,$type) =  buildExprFromBasicSearchWhereClause(undef, $$xmldata{'{DAV:}where'});
	debug("_SEARCH: call buildExpr: expr=$expr");
	# from > scope+ > (href, depth, include-versions?)
	my @scopes;
	if (ref($$xmldata{'{DAV:}from'}{'{DAV:}scope'}) eq 'HASH') {
		push @scopes, $$xmldata{'{DAV:}from'}{'{DAV:}scope'}; 
	} elsif (ref($$xmldata{'{DAV:}from'}{'{DAV:}scope'}) eq 'ARRAY') {
		push @scopes, @{$$xmldata{'{DAV:}from'}{'{DAV:}scope'}};
	} else { 
		push @scopes, { '{DAV:}href'=>$REQUEST_URI, '{DAV:}depth'=>'infinity'};
	}
	# limit > nresults 
	my $limit = $$xmldata{'{DAV:}limit'}{'{DAV:}nresults'};

	my $host = $cgi->http('Host');
	my @matches;
	foreach my $scope (@scopes) {
		my $depth = $$scope{'{DAV:}depth'};
		my $href = $$scope{'{DAV:}href'};
		my $base = $href;
		$base =~ s@^(https?://([^\@]+\@)?\Q$host\E)?$VIRTUAL_BASE@@;
		$base = $DOCUMENT_ROOT.uri_unescape(uri_unescape($base));
		
		debug("handleBasicSearch: base=$base (href=$href), depth=$depth, limit=$limit\n");

		if (!-e $base) {
			push @{$error}, { 'search-scope-valid'=> { response=> { href=>$href, status=>'HTTP/1.1 404 Not Found' } } };
			return;
		}
		doBasicSearch($expr, $base, $href, $depth, $limit, \@matches);
	}
	# orderby > order+ (caseless=(yes|no))> (prop|score), (ascending|descending)? 
	my $sortfunc="";
	if (exists $$xmldata{'{DAV:}orderby'} && $#matches>0) {
		my @orders;
		if (ref($$xmldata{'{DAV:}orderby'}{'{DAV:}order'}) eq 'ARRAY') {
			push @orders, @{$$xmldata{'{DAV:}orderby'}{'{DAV:}order'}};
		} elsif (ref($$xmldata{'{DAV:}orderby'}{'{DAV:}order'}) eq 'HASH') {
			push @orders, $$xmldata{'{DAV:}orderby'}{'{DAV:}order'};
		}
		foreach my $order (@orders) {
			my @props = keys %{$$order{'{DAV:}prop'}};
			my $prop = $props[0] || '{DAV:}displayname';
			my $proptype = $SEARCH_PROPTYPES{$prop} || $SEARCH_PROPTYPES{default};
			my $type = $$order{'{DAV:}descending'} ?  'descending' : 'ascending';
			debug("orderby: prop=$prop, proptype=$proptype, type=$type");
			my($ta,$tb,$cmp);
			$ta = qq@getPropValue('$prop',\$\$a{fn},\$\$a{href})@;
			$tb = qq@getPropValue('$prop',\$\$b{fn},\$\$b{href})@;
			if ($SEARCH_SPECIALCONV{$proptype}) {
				$ta = $SEARCH_SPECIALCONV{$proptype}."($ta)";
				$tb = $SEARCH_SPECIALCONV{$proptype}."($tb)";
			}
			$cmp = $SEARCH_SPECIALOPS{$proptype}{cmp} || 'cmp';
			$sortfunc.=" || " if $sortfunc ne "";
			$sortfunc.="$ta $cmp $tb" if $type eq 'ascending';
			$sortfunc.="$tb $cmp $ta" if $type eq 'descending';
		}

		debug("orderby: sortfunc=$sortfunc");
	}

	debug("handleBasicSearch: matches=$#matches");
	foreach my $match ( sort { eval($sortfunc) } @matches ) {
		push @{$resps}, { href=> $$match{href}, propstat=>getPropStat($$match{fn},$$match{href},$propsref,$all,$noval) };
	}

}
sub removeProperty {
	my ($propname, $elementParentRef, $resp_200, $resp_403) = @_;
	debug("removeProperty: $PATH_TRANSLATED: $propname");
	db_removeProperty($PATH_TRANSLATED, $propname);
	$$resp_200{href}=$REQUEST_URI;
	$$resp_200{propstat}{status}='HTTP/1.1 200 OK';
	$$resp_200{propstat}{prop}{$propname} = undef;
}
sub readDirBySuffix {
	my ($fn, $base, $hrefs, $suffix, $depth, $visited) = @_;
	debug("readDirBySuffix($fn, ..., $suffix, $depth)");

	my $nfn = File::Spec::Link->full_resolve($fn);
	return if exists $$visited{$nfn} && ($depth eq 'infinity' || $depth < 0);
	$$visited{$nfn}=1;

	if (opendir(DIR,$fn)) {
		foreach my $sf (grep { !/^\.{1,2}$/ } readdir(DIR)) {
			$sf.='/' if -d $fn.$sf;
			my $nbase=$base.$sf;
			push @{$hrefs}, $nbase if -f $fn.$sf && $sf =~ /\.\Q$suffix\E/;
			readDirBySuffix($fn.$sf, $nbase, $hrefs, $suffix, $depth - 1, $visited) if $depth!=0 && -d $fn.$sf;
			## XXX add only files with requested components 
			## XXX filter (comp-filter > comp-filter >)
		}
		closedir(DIR);
	}
}
sub handlePropFindElement {
	my ($xmldata) = @_;
	my @props;
	my $all;
	my $noval;
	foreach my $propfind (keys %{$xmldata} ) {
		my $nons = $propfind;
		my $ns ="";
		if ($nons=~s/{([^}]*)}//) {
			$ns = $1;
		}
		if (($nons =~ /(allprop|propname)/)&&($all)) {
			printHeaderAndContent('400 Bad Request');
			return;
		} elsif ($nons =~ /^(allprop|propname)$/) {
			$all = 1;
			$noval = $1 eq 'propname';
			push @props, @KNOWN_COLL_PROPS, @KNOWN_FILE_PROPS if $noval;
			push @props, @ALLPROP_PROPS unless $noval;
		} elsif ($nons =~ /^(prop|include)$/) {
			handlePropElement($$xmldata{$propfind},\@props);
		} elsif (grep (/\Q$nons\E/,@IGNORE_PROPS)) {
			next;
		} elsif (defined $NAMESPACES{$$xmldata{$propfind}} || defined $NAMESPACES{$ns} )  { # sometimes the namespace: ignore
		} else {	
			debug("Unknown element $propfind ($nons) in PROPFIND request");
			debug($NAMESPACES{$$xmldata{$propfind}});
			printHeaderAndContent('400 Bad Request');
			exit;
		}
	}
	return (\@props, $all, $noval);
}
sub handlePropElement {
	my ($xmldata, $props) = @_;
	foreach my $prop (keys %{$xmldata}) {
		my $nons = $prop;
		my $ns= "";
		if ($nons=~s/{([^}]*)}//) {
			$ns = $1;
		}
		if (ref($$xmldata{$prop}) !~/^(HASH|ARRAY)$/) { # ignore namespaces
		} elsif ($ns eq "" && ! defined $$xmldata{$prop}{xmlns}) {
			printHeaderAndContent('400 Bad Request');
			exit;
		} elsif (grep(/\Q$nons\E/, @KNOWN_FILE_PROPS, @KNOWN_COLL_PROPS)>0)  {
			push @{$props}, $nons;
		} elsif ($ns eq "") {
			push @{$props}, '{}'.$prop;
		} else {
			push @{$props}, $prop;
		}
	}

}
sub getPropStat {
	my ($fn,$uri,$props,$all,$noval) = @_;
	my @propstat= ();

	debug("getPropStat($fn,$uri,...)");

	### +++ AFS fix
	my $isReadable = $ENABLE_AFS ? checkAFSAccess($fn) : 1;
	### --- AFS fix

	my $nfn = $isReadable ? File::Spec::Link->full_resolve($fn) : $fn;

	my @stat = $isReadable ? stat($fn) : ();
	my %resp_200 = (status=>'HTTP/1.1 200 OK');
	my %resp_404 = (status=>'HTTP/1.1 404 Not Found');

	### +++ AFS fix
	my $isDir = $ENABLE_AFS ? checkAFSAccess($nfn) && -d $nfn : -d $fn;
	### --- AFS fix

	foreach my $prop (@{$props}) {
		my ($xmlnsuri,$propname) = ('DAV:',$prop);
		if ($prop=~/^{([^}]*)}(.*)$/) {
			($xmlnsuri, $propname) = ($1,$2);
		} 
		if (grep(/^\Q$propname\E$/,@UNSUPPORTED_PROPS) >0) {
			debug("getPropStat: UNSUPPORTED: $propname");
			$resp_404{prop}{$prop}=undef;
			next;
		} elsif (( !defined $NAMESPACES{$xmlnsuri} || grep(/^\Q$propname\E$/,$isDir?@KNOWN_COLL_LIVE_PROPS:@KNOWN_FILE_LIVE_PROPS)>0 ) && grep(/^\Q$propname\E$/,@PROTECTED_PROPS)==0) { 
			my $dbval = db_getProperty($fn, $prop=~/{[^}]*}/?$prop:'{'.getNameSpaceUri($prop)."}$prop");
			if (defined $dbval) {
				$resp_200{prop}{$prop}=$noval?undef:$dbval;
				next;
			} elsif (grep(/^\Q$propname\E$/,$isDir?@KNOWN_COLL_LIVE_PROPS:@KNOWN_FILE_LIVE_PROPS)==0) {
				debug("getPropStat: #1 NOT FOUND: $prop ($propname, $xmlnsuri)");
				$resp_404{prop}{$prop}=undef;
			}
		} 
		if (grep(/^\Q$propname\E$/, $isDir ? @KNOWN_COLL_PROPS : @KNOWN_FILE_PROPS)>0) {
			if ($noval) { 
				$resp_200{prop}{$prop}=undef;
			} else {
				getProperty($fn, $uri, $prop, \@stat, \%resp_200,\%resp_404);
			}
		} elsif (!$all) {
			debug("getPropStat: #2 NOT FOUND: $prop ($propname, $xmlnsuri)");
			$resp_404{prop}{$prop} = undef;
		}
	} # foreach

	push @propstat, \%resp_200 if exists $resp_200{prop};
	push @propstat, \%resp_404 if exists $resp_404{prop};
	return \@propstat;
}
sub getProperty {
	my ($fn, $uri, $prop, $statRef, $resp_200, $resp_404) = @_;
	debug("getProperty: fn=$fn, uri=$uri, prop=$prop");

	### +++ AFS fix
	my $isReadable = $ENABLE_AFS ? checkAFSAccess($fn) : 1;
	my $isDir = $isReadable && -d $fn;
	### --- AFS fix

	my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size, $atime,$mtime,$ctime,$blksize,$blocks) = defined $statRef ? @{$statRef} : ($isReadable ? stat($fn) : ());

	$$resp_200{prop}{creationdate}=strftime('%Y-%m-%dT%H:%M:%SZ' ,gmtime($ctime)) if $prop eq 'creationdate';
	$$resp_200{prop}{displayname}=$cgi->escape(basename($uri)) if $prop eq 'displayname' && !defined $$resp_200{prop}{displayname};
	$$resp_200{prop}{getcontentlanguage}='en' if $prop eq 'getcontentlanguage';
	$$resp_200{prop}{getcontentlength}= $size if $prop eq 'getcontentlength';
	$$resp_200{prop}{getcontenttype}=($isDir?'httpd/unix-directory':getMIMEType($fn)) if $prop eq 'getcontenttype';
	$$resp_200{prop}{getetag}=getETag($fn) if $prop eq 'getetag';
	$$resp_200{prop}{getlastmodified}=strftime('%a, %d %b %Y %T GMT' ,gmtime($mtime)) if $prop eq 'getlastmodified';
	$$resp_200{prop}{lockdiscovery}=getLockDiscovery($fn) if $prop eq 'lockdiscovery';
	$$resp_200{prop}{resourcetype}=($isDir?{collection=>undef}:undef) if $prop eq 'resourcetype';
	$$resp_200{prop}{resourcetype}{calendar}=undef if $prop eq 'resourcetype' && $ENABLE_CALDAV && $isDir;
	$$resp_200{prop}{resourcetype}{'schedule-inbox'}=undef if $prop eq 'resourcetype' && $ENABLE_CALDAV_SCHEDULE && $isDir;
	$$resp_200{prop}{resourcetype}{'schedule-outbox'}=undef if $prop eq 'resourcetype' && $ENABLE_CALDAV_SCHEDULE && $isDir;
	$$resp_200{prop}{resourcetype}{addressbook}=undef if $prop eq 'resourcetype' && $ENABLE_CARDDAV && $isDir;
	$$resp_200{prop}{resourcetype}{'vevent-collection'}=undef if $prop eq 'resourcetype' && $ENABLE_GROUPDAV && $isDir;
	$$resp_200{prop}{resourcetype}{'vtodo-collection'}=undef if $prop eq 'resourcetype' && $ENABLE_GROUPDAV && $isDir;
	$$resp_200{prop}{resourcetype}{'vcard-collection'}=undef if $prop eq 'resourcetype' && $ENABLE_GROUPDAV && $isDir;
	$$resp_200{prop}{'component-set'}='VEVENT,VTODO,VCARD' if $prop eq 'component-set';
	if ($prop eq 'supportedlock') {
		$$resp_200{prop}{supportedlock}{lockentry}[0]{lockscope}{exclusive}=undef;
		$$resp_200{prop}{supportedlock}{lockentry}[0]{locktype}{write}=undef;
		$$resp_200{prop}{supportedlock}{lockentry}[1]{lockscope}{shared}=undef;
		$$resp_200{prop}{supportedlock}{lockentry}[1]{locktype}{write}=undef;
	}
	$$resp_200{prop}{executable}=($isReadable && -x $fn )?'T':'F' if $prop eq 'executable';

	$$resp_200{prop}{source}={ 'link'=> { 'src'=>$uri, 'dst'=>$uri }} if $prop eq 'source';

	if ($prop eq 'quota-available-bytes' || $prop eq 'quota-used-bytes' || $prop eq 'quota' || $prop eq 'quotaused') {
		my ($ql,$qu) = getQuota();
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
	$$resp_200{prop}{childcount}=($isDir?getDirInfo($fn,$prop,\%FILEFILTERPERDIR,\%FILECOUNTPERDIRLIMIT,$FILECOUNTLIMIT):0) if $prop eq 'childcount';
	$$resp_200{prop}{id}=$uri if $prop eq 'id';
	$$resp_200{prop}{isfolder}=($isDir?1:0) if $prop eq 'isfolder';
	$$resp_200{prop}{ishidden}=(basename($fn)=~/^\./?1:0) if $prop eq 'ishidden';
	$$resp_200{prop}{isstructureddocument}=0 if $prop eq 'isstructureddocument';
	$$resp_200{prop}{hassubs}=($isDir?getDirInfo($fn,$prop,\%FILEFILTERPERDIR,\%FILECOUNTPERDIRLIMIT,$FILECOUNTLIMIT):0) if $prop eq 'hassubs';
	$$resp_200{prop}{nosubs}=($isDir?(-w $fn?1:0):1) if $prop eq 'nosubs';
	$$resp_200{prop}{objectcount}=($isDir?getDirInfo($fn,$prop,\%FILEFILTERPERDIR,\%FILECOUNTPERDIRLIMIT,$FILECOUNTLIMIT):0) if $prop eq 'objectcount';
	$$resp_200{prop}{reserved}=0 if $prop eq 'reserved';
	$$resp_200{prop}{visiblecount}=($isDir?getDirInfo($fn,$prop,\%FILEFILTERPERDIR,\%FILECOUNTPERDIRLIMIT,$FILECOUNTLIMIT):0) if $prop eq 'visiblecount';

	$$resp_200{prop}{iscollection}=($isDir?1:0) if $prop eq 'iscollection';
	$$resp_200{prop}{isFolder}=($isDir?1:0) if $prop eq 'isFolder';
	$$resp_200{prop}{'authoritative-directory'}=($isDir?'t':'f') if $prop eq 'authoritative-directory';
	$$resp_200{prop}{resourcetag}=$REQUEST_URI if $prop eq 'resourcetag';
	$$resp_200{prop}{'repl-uid'}=getuuid($fn) if $prop eq 'repl-uid';
	$$resp_200{prop}{modifiedby}=$ENV{REDIRECT_REMOTE_USER}||$ENV{REMOTE_USER} if $prop eq 'modifiedby';
	$$resp_200{prop}{Win32CreationTime}=strftime('%a, %d %b %Y %T GMT' ,gmtime($ctime)) if $prop eq 'Win32CreationTime';
	if ($prop eq 'Win32FileAttributes') {
		my $fileattr = 128 + 32; # 128 - Normal, 32 - Archive, 4 - System, 2 - Hidden, 1 - Read-Only
		$fileattr+=1 unless !$IGNOREFILEPERMISSIONS && -w $fn;
		$fileattr+=2 if basename($fn)=~/^\./;
		$$resp_200{prop}{Win32FileAttributes}=sprintf("%08x",$fileattr);
	}
	$$resp_200{prop}{Win32LastAccessTime}=strftime('%a, %d %b %Y %T GMT' ,gmtime($atime)) if $prop eq 'Win32LastAccessTime';
	$$resp_200{prop}{Win32LastModifiedTime}=strftime('%a, %d %b %Y %T GMT' ,gmtime($mtime)) if $prop eq 'Win32LastModifiedTime';
	$$resp_200{prop}{name}=$cgi->escape(basename($fn)) if $prop eq 'name';
	$$resp_200{prop}{href}=$uri if $prop eq 'href';
	$$resp_200{prop}{parentname}=$cgi->escape(basename(dirname($uri))) if $prop eq 'parentname';
	$$resp_200{prop}{isreadonly}=(!$IGNOREFILEPERMISSIONS && !-w $fn?1:0) if $prop eq 'isreadonly';
	$$resp_200{prop}{isroot}=($fn eq $DOCUMENT_ROOT?1:0) if $prop eq 'isroot';
	$$resp_200{prop}{getcontentclass}=($isDir?'urn:content-classes:folder':'urn:content-classes:document') if $prop eq 'getcontentclass';
	$$resp_200{prop}{contentclass}=($isDir?'urn:content-classes:folder':'urn:content-classes:document') if $prop eq 'contentclass';
	$$resp_200{prop}{lastaccessed}=strftime('%m/%d/%Y %I:%M:%S %p' ,gmtime($atime)) if $prop eq 'lastaccessed';

	$$resp_200{prop}{owner} = { href=>$uri } if $prop eq 'owner';
	$$resp_200{prop}{group} = { href=>$uri } if $prop eq 'group';
	$$resp_200{prop}{'supported-privilege-set'}= getACLSupportedPrivilegeSet($fn) if $prop eq 'supported-privilege-set';
	$$resp_200{prop}{'current-user-privilege-set'} = getACLCurrentUserPrivilegeSet($fn) if $prop eq 'current-user-privilege-set';
	$$resp_200{prop}{acl} = getACLProp($mode) if $prop eq 'acl';
	$$resp_200{prop}{'acl-restrictions'} = {'no-invert'=>undef,'required-principal'=>{all=>undef,property=>[{owner=>undef},{group=>undef}]}} if $prop eq 'acl-restrictions';
	$$resp_200{prop}{'inherited-acl-set'} = undef if $prop eq 'inherited-acl-set';
	$$resp_200{prop}{'principal-collection-set'} = { href=> $PRINCIPAL_COLLECTION_SET }, if $prop eq 'principal-collection-set';

	$$resp_200{prop}{'calendar-description'} = undef if $prop eq 'calendar-description';
	$$resp_200{prop}{'calendar-timezone'} = undef if $prop eq 'calendar-timezone';
	$$resp_200{prop}{'supported-calendar-component-set'} = '<C:comp name="VEVENT"/><C:comp name="VTODO"/><C:comp name="VJOURNAL"/><C:comp name="VTIMEZONE"/>' if $prop eq 'supported-calendar-component-set';
	$$resp_200{prop}{'supported-calendar-data'}='<C:calendar-data content-type="text/calendar" version="2.0"/>' if $prop eq 'supported-calendar-data';
	$$resp_200{prop}{'max-resource-size'}=20000000 if $prop eq 'max-resource-size';
	$$resp_200{prop}{'min-date-time'}='19000101T000000Z' if $prop eq 'min-date-time';
	$$resp_200{prop}{'max-date-time'}='20491231T235959Z' if $prop eq 'max-date-time';
	$$resp_200{prop}{'max-instances'}=100 if $prop eq 'max-instances';
	$$resp_200{prop}{'max-attendees-per-instance'}=100 if $prop eq 'max-attendees-per-instance';
	##$$resp_200{prop}{'calendar-data'}='<![CDATA['.getFileContent($fn).']]>' if $prop eq 'calendar-data';
	if ($prop eq 'calendar-data') {
		if ($fn=~/\.ics$/i) {
			$$resp_200{prop}{'calendar-data'}=$cgi->escapeHTML(getFileContent($fn));
		} else {
			$$resp_404{prop}{'calendar-data'}=undef;
		}
	}
	$$resp_200{prop}{'getctag'}=getETag($fn)  if $prop eq 'getctag';
	$$resp_200{prop}{'current-user-principal'}{href}=$CURRENT_USER_PRINCIPAL if $prop eq 'current-user-principal';
	$$resp_200{prop}{'principal-URL'}{href}=$CURRENT_USER_PRINCIPAL if $prop eq 'principal-URL';
	$$resp_200{prop}{'calendar-home-set'}{href}=getCalendarHomeSet($uri) if $prop eq 'calendar-home-set';
	$$resp_200{prop}{'calendar-user-address-set'}{href}= $CURRENT_USER_PRINCIPAL if $prop eq 'calendar-user-address-set';
	$$resp_200{prop}{'schedule-inbox-URL'}{href} = getCalendarHomeSet($uri) if $prop eq 'schedule-inbox-URL';
	$$resp_200{prop}{'schedule-outbox-URL'}{href} = getCalendarHomeSet($uri) if $prop eq 'schedule-outbox-URL';
	$$resp_200{prop}{'calendar-user-type'}='INDIVIDUAL' if $prop eq 'calendar-user-type';
	$$resp_200{prop}{'schedule-calendar-transp'}{transparent} = undef if $prop eq 'schedule-calendar-transp';
	$$resp_200{prop}{'schedule-default-calendar-URL'}=getCalendarHomeSet($uri) if $prop eq 'schedule-default-calendar-URL';
	$$resp_200{prop}{'schedule-tag'}=getETag($fn) if $prop eq 'schedule-tag';

	if ($prop eq 'address-data') {
		if ($fn =~ /\.vcf$/i) {
			$$resp_200{prop}{'address-data'}=$cgi->escapeHTML(getFileContent($fn));
		} else {
			$$resp_404{prop}{'address-data'}=undef;
		}
	}
	$$resp_200{prop}{'addressbook-description'} = $cgi->escape(basename($fn)) if $prop eq 'addressbook-description';
	$$resp_200{prop}{'supported-address-data'}='<A:address-data-type content-type="text/vcard" version="3.0"/>' if $prop eq 'supported-address-data';
	$$resp_200{prop}{'{urn:ietf:params:xml:ns:carddav}max-resource-size'}=20000000 if $prop eq 'max-resource-size' && $ENABLE_CARDDAV;
	$$resp_200{prop}{'addressbook-home-set'}{href}=getAddressbookHomeSet($uri) if $prop eq 'addressbook-home-set';
	$$resp_200{prop}{'principal-address'}{href}=$uri if $prop eq 'principal-address';
	
	
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
					]
				} if $prop eq 'supported-report-set';

	if ($prop eq 'supported-method-set') {
		$$resp_200{prop}{'supported-method-set'} = '';
		foreach my $method (@{getSupportedMethods($fn)}) {
			$$resp_200{prop}{'supported-method-set'} .= '<D:supported-method name="'.$method.'"/>';
		}
	}

	if ($prop eq 'resource-id') {
		my $e = getETag(File::Spec::Link->full_resolve($fn));
		$e=~s/"//g;
		$$resp_200{prop}{'resource-id'} = 'urn:uuid:'.$e;
	}

}

sub cmp_elements {
	my $aa = defined $ELEMENTORDER{$a} ? $ELEMENTORDER{$a} : $ELEMENTORDER{default};
	my $bb = defined $ELEMENTORDER{$b} ? $ELEMENTORDER{$b} : $ELEMENTORDER{default};
	if (defined $ELEMENTORDER{$a} || defined $ELEMENTORDER{$b} ) {
		return $aa <=> $bb;
	} 
	return $a cmp $b;
}
sub createXMLData {
        my ($w,$d,$xmlns) =@_;
        if (ref($d) eq 'HASH') {
                foreach my $e (sort cmp_elements keys %{$d}) {
			my $el = $e;
                        my $euns = "";
                        my $uns;
                        my $ns = getNameSpace($e);
			my $attr = "";
			if (defined $DATATYPES{$e}) {
				$attr.=" ".$DATATYPES{$e};
				if ($DATATYPES{$e}=~/(\w+):dt/) {
					$$xmlns{$1}=1 if defined $NAMESPACEABBR{$1};
				}
			}
                        if ($e=~/{([^}]*)}/) {
                                $ns = $1;
                                if (defined $NAMESPACES{$ns})  {
                                        $el=~s/{[^}]*}//;
                                        $ns = $NAMESPACES{$ns};
                                } else {
                                        $uns = $ns;
                                        $euns = $e;
                                        $euns=~s/{[^}]*}//;
                                }
                        }
			my $el_end = $el;
			$el_end=~s/ .*$//;
			my $euns_end = $euns;
			$euns_end=~s/ .*$//;
			$$xmlns{$ns}=1 unless defined $uns;
			my $nsd="";
			if ($e eq 'xmlns') { # ignore namespace defs
			} elsif ($e eq 'content') { #
					$$w.=$$d{$e};	
                        } elsif ( ! defined $$d{$e} ) {
                                if (defined $uns) {
                                        $$w.="<${euns} xmlns=\"$uns\"/>";
                                } else {
                                        $$w.="<${ns}:${el}${nsd}${attr}/>";
                                }
                        } elsif (ref($$d{$e}) eq 'ARRAY') {
                                foreach my $e1 (@{$$d{$e}}) {
					my $tmpw="";
                                        createXMLData(\$tmpw,$e1,$xmlns);
					if ($NAMESPACEELEMENTS{$el}) {
						foreach my $abbr (keys %{$xmlns}) {
							$nsd.=qq@ xmlns:$abbr="$NAMESPACEABBR{$abbr}"@;
							delete $$xmlns{$abbr};
						}
					}
                                        $$w.=qq@<${ns}:${el}${nsd}${attr}>@;
					$$w.=$tmpw;
                                        $$w.="</${ns}:${el_end}>";
                                }
                        } else {
                                if (defined $uns) {
                                        $$w.=qq@<${euns} xmlns="$uns">@;
                                        createXMLData($w, $$d{$e}, $xmlns);
                                        $$w.=qq@</${euns_end}>@;
                                } else {
					my $tmpw="";
                                        createXMLData(\$tmpw, $$d{$e}, $xmlns);
					if ($NAMESPACEELEMENTS{$el}) {
						foreach my $abbr (keys %{$xmlns}) {
							$nsd.=qq@ xmlns:$abbr="$NAMESPACEABBR{$abbr}"@;
							delete $$xmlns{$abbr};
						}
					}
                                        $$w.=qq@<${ns}:${el}${nsd}${attr}>@;
					$$w.=$tmpw;
                                        $$w.="</${ns}:${el_end}>";
                                }
                        }
                }
        } elsif (ref($d) eq 'ARRAY') {
                foreach my $e (@{$d}) {
                        createXMLData($w, $e, $xmlns);
                }
        } elsif (ref($d) eq 'SCALAR') {
                $$w.=qq@$d@;
        } elsif (ref($d) eq 'REF') {
                createXMLData($w, $$d, $xmlns);
        } else {
                $$w.=qq@$d@;
        }
}

sub createXML {
        my ($dataRef, $withoutp) = @_;

        my $data = "";
	$data=q@<?xml version="1.0" encoding="@.$CHARSET.q@"?>@ unless defined $withoutp;
	createXMLData(\$data,$dataRef);
        return $data;
}

sub getMIMEType {
	my ($filename) = @_;
	my $extension= "default";
	if ($filename=~/\.([^\.]+)$/) {
		$extension=$1;
	}
	my @t = grep /\b\Q$extension\E\b/i, keys %MIMETYPES;
	return $#t>-1 ? $MIMETYPES{$t[0]} : $MIMETYPES{default};
}
sub cmp_files {
	my $fp_a = $PATH_TRANSLATED.$a;
	my $fp_b = $PATH_TRANSLATED.$b;
	my $factor = ($ORDER =~/_desc$/) ? -1 : 1;
	## +++ AFS fix
	return $factor * ( $a cmp $b ) if $ENABLE_AFS && !checkAFSAccess($fp_a) && !checkAFSAccess($fp_b);
	return $factor if $ENABLE_AFS && !checkAFSAccess($fp_a);
	return $factor if $ENABLE_AFS && !checkAFSAccess($fp_b);
	## --- AFS fix
	return -1 if -d $fp_a && !-d $fp_b;
	return 1 if !-d $fp_a && -d $fp_b;
	if ($ORDER =~ /^(lastmodified|size|mode)/) {
		my $idx = $ORDER=~/lastmodified/? 9 : $ORDER=~/mode/? 2 : 7;
		return $factor * ( (stat($fp_a))[$idx] <=> (stat($fp_b))[$idx] || lc($a) cmp lc($b) );
	} elsif ($ORDER =~ /mime/) {
		return $factor * ( getMIMEType($a) cmp getMIMEType($b) || lc($a) cmp lc($b));
	}
	return $factor * (lc($a) cmp lc($b));
}
sub getfancyfilename {
	my ($full,$s,$m,$fn,$isUnReadable) = @_;
	my $ret = $s;
	my $q = getQueryParams();

	$full = '/' if $full eq '//'; # fixes root folder navigation bug

	$full.="?$q" if defined $q && defined $fn && !$isUnReadable && -d $fn;
	my $fntext = length($s)>$MAXFILENAMESIZE ? substr($s,0,$MAXFILENAMESIZE-3) : $s;

	$ret = $IGNOREFILEPERMISSIONS || (!-d $fn && -r $fn) || -x $fn  ? $cgi->a({href=>$full,title=>$s},$cgi->escapeHTML($fntext)) : $cgi->escapeHTML($fntext);
	$ret .=  length($s)>$MAXFILENAMESIZE ? '...' : (' 'x($MAXFILENAMESIZE-length($s)));

	$full=~/([^\.]+)$/;
	my $suffix = $1 || $m;
	my $icon = defined $ICONS{$m}?$ICONS{$m}:$ICONS{default};
	my $width = $ICON_WIDTH || 18;
	my $onmouseover="";
	my $onmouseout="";
	my $align="";
	my $id='i'.time().$WEB_ID;
	$id=~s/\"//g;
	
	my $cssclass='icon';
	if ($ENABLE_THUMBNAIL && !$isUnReadable && -r $fn && hasThumbSupport(getMIMEType($fn)))  {
		$icon=$full.($full=~/\?.*/?';':'?').'action=thumb';
		if ($THUMBNAIL_WIDTH && $ICON_WIDTH < $THUMBNAIL_WIDTH) {
			$cssclass='thumb';
			$onmouseover = qq@javascript:this.intervalFunc=function() { if (this.width<$THUMBNAIL_WIDTH) this.width+=@.(($THUMBNAIL_WIDTH-$ICON_WIDTH)/15).qq@; else window.clearInterval(this.intervalObj);}; this.intervalObj = window.setInterval("document.getElementById('$id').intervalFunc();", 10);@;
			$onmouseout = qq@javascript:window.clearInterval(this.intervalObj);this.width=$ICON_WIDTH;@;
		}
	}
	$full.= ($full=~/\?/ ? ';' : '?').'action=props' if $ENABLE_PROPERTIES_VIEWER;
	$ret = $cgi->a(  {href=>$full,title=>_tl('showproperties')},
			 $cgi->img({id=>$id, src=>$icon,alt=>'['.$suffix.']', -class=>$cssclass, -width=>$width, -onmouseover=>$onmouseover,-onmouseout=>$onmouseout})
			).' '.$ret;
	return $ret;
}
sub deltree {
	my ($f,$errRef) = @_;
	$errRef=[] unless defined $errRef;
	my $count = 0;
	my $nf = $f; $nf=~s/\/$//;
	if (!isAllowed($f,1)) {
		debug("Cannot delete $f: not allowed");
		push(@$errRef, { $f => "Cannot delete $f" });
	} elsif (-l $nf) {
		if (unlink($nf)) {
			$count++;
			db_deleteProperties($f);
			db_delete($f);
		} else {
			push(@$errRef, { $f => "Cannot delete '$f': $!" });
		}
	} elsif (-d $f) {
		if (opendir(DIR,$f)) {
			foreach my $sf (grep { !/^\.{1,2}$/ } readdir(DIR)) {
				my $full = $f.$sf;
				$full.='/' if -d $full && $full!~/\/$/;
				$count+=deltree($full,$errRef);
			}
			closedir(DIR);
			if (rmdir $f) {
				$count++;
				$f.='/' if $f!~/\/$/;
				db_deleteProperties($f);
				db_delete($f);
			} else {
				push(@$errRef, { $f => "Cannot delete '$f': $!" });
			}
		} else {
			push(@$errRef, { $f => "Cannot open '$f': $!" });
		}
	} elsif (-e $f) {
		if (unlink($f)) {	
			$count++;
			db_deleteProperties($f);
			db_delete($f);
		} else {
			push(@$errRef, { $f  => "Cannot delete '$f' : $!" }) ;
		}
	} else {
		push(@$errRef, { $f => "File/Folder '$f' not found" });
	}
	return $count;
}
sub getETag {
	my ($file) = @_;
	$file = $PATH_TRANSLATED unless defined $file;
	my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size, $atime,$mtime,$ctime,$blksize,$blocks) = stat($file);
	my $digest = new Digest::MD5;
	$digest->add($file);
	$digest->add($size);
	$digest->add($mtime);
	return '"'.$digest->hexdigest().'"';
}
sub printHeaderAndContent {
	my ($status, $type, $content, $addHeader) = @_;

	$status='403 Forbidden' unless defined $status;
	$type='text/plain' unless defined $type;
	$content="" unless defined $content;

	my @cookies = ( 
		$cgi->cookie(-name=>'lang',-value=>$LANG,-expires=>'+10y'),
		$cgi->cookie(-name=>'showall',-value=>$cgi->param('showpage') ? 0 : ($cgi->param('showall') || $cgi->cookie('showall') || 0), -expires=>'+10y'),
		$cgi->cookie(-name=>'order',-value=>$ORDER, -expires=>'+10y'),
		$cgi->cookie(-name=>'pagelimit',-value=>$PAGE_LIMIT, -expires=>'+10y'),
		$cgi->cookie(-name=>'view',-value=>$VIEW, -expires=>'+10y'),
	);

	my $header = $cgi->header(-status=>$status, -type=>$type, -Content_length=>length($content), -ETag=>getETag(), -charset=>$CHARSET, -cookie=>\@cookies );

	$header = "MS-Author-Via: DAV\r\n$header";
	$header = "DAV: $DAV\r\n$header";
	$header="$addHeader\r\n$header" if defined $addHeader;
	$header="Translate: f\r\n$header" if defined $cgi->http('Translate');

	print $header;
	binmode(STDOUT);
	print $content;
}
sub printFileHeader {
	my ($fn) = @_;
	my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size, $atime,$mtime,$ctime,$blksize,$blocks) = stat($fn);
	my $header = $cgi->header(-status=>'200 OK',-type=>getMIMEType($fn),
				-Content_Length=>$size,	
				-ETag=>getETag($fn),
				-Last_Modified=>strftime("%a, %d %b %Y %T GMT" ,gmtime($mtime)),
				-charset=>$CHARSET);

	$header = "MS-Author-Via: DAV\r\n$header";
	$header = "DAV: $DAV\r\n$header";
	$header = "Translate: f\r\n$header" if defined $cgi->http('Translate');
	print $header;

}
sub is_hidden {
	my ($fn) = @_;
	if (defined @HIDDEN && $#HIDDEN>-1) {
		my $regex = '('.join('|',@HIDDEN).')';
		return $fn=~/$regex/?1:0;
	} else {
		return 0;
	}
}
sub simpleXMLParser {
	my ($text,$keepRoot) = @_;
	my %param;
	$param{NSExpand}=1;
	$param{KeepRoot}=1 if $keepRoot;
	return XMLin($text,%param);
}
sub isLockedRecurse {
	my ($fn) = @_;
	$fn = $PATH_TRANSLATED unless defined $fn;

	my $rows = db_getLike("$fn\%");

	return $#{$rows} >-1;

}
sub isLocked {
	my ($fn) = @_;
	$fn.='/' if -d $fn && $fn !~/\/$/;
	my $rows = db_get($fn);
	return ($#{$rows}>-1)?1:0;
}
sub isLockable  { # check lock and exclusive
	my ($fn,$xmldata) = @_;
	my @lockscopes = keys %{$$xmldata{'{DAV:}lockscope'}};
	my $lockscope = @lockscopes && $#lockscopes >-1 ? $lockscopes[0] : 'exclusive';

	my $rowsRef;
	if (! -e $fn) {
		$rowsRef = db_get(dirname($fn).'/');
	} elsif (-d $fn) {
		$rowsRef = db_getLike("$fn\%");
	} else {
		$rowsRef = db_get($fn);
	}
	my $ret = 0;
	debug("isLockable: $#{$rowsRef}, lockscope=$lockscope");
	if ($#{$rowsRef}>-1) {
		my $row = $$rowsRef[0];
		$ret =  lc($$row[3]) ne 'exclusive' && $lockscope ne '{DAV:}exclusive'?1:0;
	} else {
		$ret = 1;
	}
	return $ret;
}
sub getLockDiscovery {
	my ($fn) = @_;

	my $rowsRef = db_get($fn);
	my @resp = ();
	if ($#$rowsRef > -1) {
		debug("getLockDiscovery: rowcount=".$#{$rowsRef});
		foreach my $row (@{$rowsRef}) { # basefn,fn,type,scope,token,depth,timeout,owner
			my %lock;
			$lock{locktype}{$$row[2]}=undef;
			$lock{lockscope}{$$row[3]}=undef;
			$lock{locktoken}{href}=$$row[4];
			$lock{depth}=$$row[5];
			$lock{timeout}= defined $$row[6] ? $$row[6] : 'Infinite';
			$lock{owner}=$$row[7] if defined $$row[7];

			push @resp, {activelock=>\%lock};
		}

	}
	debug("getLockDiscovery: resp count=".$#resp);
	
	return $#resp >-1 ? \@resp : undef;
}
sub lockResource {
	my ($fn, $ru, $xmldata, $depth, $timeout, $token, $base, $visited) =@_;
	my %resp = ();
	my @prop= ();

	debug("lockResource(fn=$fn,ru=$ru,depth=$depth,timeout=$timeout,token=$token,base=$base)");

	my %activelock = ();
	my @locktypes = keys %{$$xmldata{'{DAV:}locktype'}};
	my @lockscopes = keys %{$$xmldata{'{DAV:}lockscope'}};
	my $locktype= $#locktypes>-1 ? $locktypes[0] : undef;
	my $lockscope = $#lockscopes>-1 ? $lockscopes[0] : undef;
	my $owner = createXML(defined $$xmldata{'{DAV:}owner'} ?  $$xmldata{'{DAV:}owner'} : $DEFAULT_LOCK_OWNER, 0, 1);
	$locktype=~s/{[^}]+}//;
	$lockscope=~s/{[^}]+}//;

	$activelock{locktype}{$locktype}=undef;
	$activelock{lockscope}{$lockscope}=undef;
	$activelock{locktoken}{href}=$token;
	$activelock{depth}=$depth;
	$activelock{lockroot}=$ru;

	# save lock to database (structure: basefn, fn, type, scope, token, timeout(null), owner(null)):
	if (db_insert(defined $base?$base:$fn,$fn,$locktype,$lockscope,$token,$depth,$timeout, $owner))  {
		push @prop, { activelock=> \%activelock };
	} elsif (db_update(defined $base?$base:$fn,$fn,$timeout)) {
		push @prop, { activelock=> \%activelock };
	} else {
		my $n = $#{$resp{multistatus}{response}} +1;
		$resp{multistatus}{response}[$n]{href}=$ru;
		$resp{multistatus}{response}[$n]{status}='HTTP/1.1 403 Forbidden';
	}
	my $nfn = File::Spec::Link->full_resolve($fn);
	return \%resp if exists $$visited{$nfn};
	$$visited{$nfn}=1;

	if (-d $fn && (lc($depth) eq 'infinity' || $depth>0)) {
		debug("lockResource: depth=$depth");
		if (opendir(DIR,$fn)) {

			foreach my $f ( grep { !/^(\.|\.\.)$/ } readdir(DIR)) {
				my $nru = $ru.$f;
				my $nfn = $fn.$f;
				$nru.='/' if -d $nfn;
				$nfn.='/' if -d $nfn;
				debug("lockResource: $nfn, $nru");
				my $subreqresp = lockResource($nfn, $nru, $xmldata, lc($depth) eq 'infinity'?$depth:$depth-1, $timeout, $token, defined $base?$base:$fn, $visited);
				if (defined $$subreqresp{multistatus}) {
					push @{$resp{multistatus}{response}}, @{$$subreqresp{multistatus}{response}};
				} else {
					push @prop, @{$$subreqresp{prop}{lockdiscovery}} if exists $$subreqresp{prop};
				}
			}
			closedir(DIR);
		} else {
			my $n = $#{$resp{multistatus}{response}} +1;
			$resp{multistatus}{response}[$n]{href}=$ru;
			$resp{multistatus}{response}[$n]{status}='HTTP/1.1 403 Forbidden';
		}
	}
	$resp{multistatus}{response}[$#{$resp{multistatus}{response}} +1]{propstat}{prop}{lockdiscovery}=\@prop if defined $resp{multistatus} && $#prop>-1;
	$resp{prop}{lockdiscovery}=\@prop unless defined $resp{multistatus};
	
	return \%resp;
}
sub unlockResource {
	my ($fn, $token) = @_;
	return db_isRootFolder($fn, $token) && db_delete($fn,$token);
}
sub preConditionFailed {
	my ($fn) = @_;
	$fn = dirname($fn).'/' if ! -e $fn;
	my $ifheader = getIfHeaderComponents($cgi->http('If'));
	my $rowsRef = db_get( $fn );
	my $t =0; # token found
	my $nnl = 0; # not no-lock found
	my $nl = 0; # no-lock found
	my $e = 0; # wrong etag found
	my $etag = getETag($fn);
	foreach my $ie (@{$$ifheader{list}}) {
		debug(" - ie{token}=".$$ie{token});
		if ($$ie{token} =~ /Not\s+<DAV:no-lock>/i) {
			$nnl = 1;
		}elsif ($$ie{token} =~ /<DAV:no-lock>/i) {
			$nl = 1;
		}elsif ($$ie{token} =~ /opaquelocktoken/i) {
			$t = 1;
		}
		if (defined $$ie{etag}) { 
			$e= ($$ie{etag} ne $etag)?1:0;
		}
	}
	debug("checkPreCondition: t=$t, nnl=$nnl, e=$e, nl=$nl");
	return  ($t & $nnl & $e) | $nl;

}
sub isAllowed {
	my ($fn, $recurse) = @_;
	
	$fn = dirname($fn).'/' if ! -e $fn;
	debug("isAllowed($fn,$recurse) called.");

	return 1 unless $ENABLE_LOCK;
	
	my $ifheader = getIfHeaderComponents($cgi->http('If'));
	my $rowsRef = $recurse ? db_getLike("$fn%") : db_get( $fn );

	return 0 if -e $fn && (!$IGNOREFILEPERMISSIONS && !-w $fn); # not writeable
	return 1 if $#{$rowsRef}==-1; # no lock
	return 0 unless defined $ifheader;
	my $ret = 0;
	for (my $i=0; $i<=$#{$rowsRef}; $i++) {
		for (my $j=0; $j<=$#{$$ifheader{list}}; $j++) {
			my $iftoken = $$ifheader{list}[$j]{token};
			$iftoken="" unless defined $iftoken;
			$iftoken=~s/[\<\>\s]+//g; 
			debug("isAllowed: $iftoken send, needed for $$rowsRef[$i][4]: ". ($iftoken eq $$rowsRef[$i][4]?"OK":"FAILED") );
			if ($$rowsRef[$i][4] eq $iftoken) {
				$ret = 1;
				last;
			}
		}
	}
	return $ret;
}
sub inheritLock {
	my ($fn,$checkContent, $visited) = @_;
	$fn =  $PATH_TRANSLATED unless defined $fn;

	my $nfn = File::Spec::Link->full_resolve($fn);
	return if exists $$visited{$nfn};
	$$visited{$nfn}=1;

	my $bfn = dirname($fn).'/';

	debug("inheritLock: check lock for $bfn ($fn)");
	my $rows = db_get($bfn);
	return if $#{$rows} == -1 and !$checkContent;
	debug("inheritLock: $bfn is locked") if $#{$rows}>-1;
	if ($checkContent) {
		$rows = db_get($fn);
		return if $#{$rows} == -1;
		debug("inheritLock: $fn is locked");
	}
	my $row = $$rows[0];
	if (-d $fn) {
		debug("inheritLock: $fn is a collection");
		db_insert($$row[0],$fn,$$row[2],$$row[3],$$row[4],$$row[5],$$row[6],$$row[7]);
		if (opendir(DIR,$fn)) {
			foreach my $f (grep { !/^(\.|\.\.)$/ } readdir(DIR)) {
				my $full = $fn.$f;
				$full .='/' if -d $full && $full !~/\/$/;
				db_insert($$row[0],$full,$$row[2],$$row[3],$$row[4],$$row[5],$$row[6],$$row[7]);
				inheritLock($full,undef,$visited);
			}
			closedir(DIR);
		}
	} else {
		db_insert($$row[0],$fn,$$row[2],$$row[3],$$row[4],$$row[5],$$row[6],$$row[7]);
	}
}
sub getIfHeaderComponents {
        my($if) = @_;
        my($rtag,@tokens);
	if (defined $if) {
		if ($if =~ s/^<([^>]+)>\s*//) {
			$rtag=$1;
		}
		while ($if =~ s/^\((Not\s*)?([^\[\)]+\s*)?\s*(\[([^\]\)]+)\])?\)\s*//i) {
			push @tokens, { token=>"$1$2", etag=>$4 };
		}
		return {rtag=>$rtag, list=>\@tokens};
	}
	return undef;
}
sub readDirRecursive {
	my ($fn, $ru, $respsRef, $props, $all, $noval, $depth, $noroot, $visited) = @_;
	return if is_hidden($fn);
	### +++ AFS fix
	my $isReadable = $ENABLE_AFS ? checkAFSAccess($fn) : 1;
	### --- AFS fix
	my $nfn = $isReadable ?  File::Spec::Link->full_resolve($fn) : $fn;
	unless ($noroot) {
		my %response = ( href=>$ru );
		$response{href}=$ru;
		$response{propstat}=getPropStat($nfn,$ru,$props,$all,$noval);
		if ($#{$response{propstat}}==-1) {
			$response{status} = 'HTTP/1.1 200 OK';
			delete $response{propstat};
		} else {
			$response{propstat}[0]{status} = 'HTTP/1.1 208 Already Reported' if $ENABLE_BIND && $depth<0 && exists $$visited{$nfn};
		}
		push @{$respsRef}, \%response;
	}
	return if exists $$visited{$nfn} && !$noroot && ($depth eq 'infinity' || $depth<0);
	$$visited{$nfn} = 1;
	if ($depth!=0 &&  $isReadable && -d $nfn ) {
		if (!defined $FILECOUNTPERDIRLIMIT{$fn} || $FILECOUNTPERDIRLIMIT{$fn}>0) {
			if (defined $FILEFILTERPERDIR{$fn} && _tl('webdavfolderisfiltered') ne 'webdavfolderisfiltered') {
				my $fru = $ru.$cgi->escape(_tl('webdavfolderisfiltered'));
				push @{$respsRef}, {
					href => $fru,
					status=>'HTTP/1.1 200 OK',
					propstat=> getPropStat($nfn,$fru,$props,$all,$noval),
				};
			}
			foreach my $f ( sort cmp_files @{readDir($fn)}) {
				my $fru=$ru.$cgi->escape($f);
				###$fru.='/' if -d "$nfn/$f" && $fru!~/\/$/;
				$isReadable = $ENABLE_AFS ? checkAFSAccess("$nfn/$f") : 1;
				my $nnfn = $isReadable ? File::Spec::Link->full_resolve("$nfn/$f") : "$nfn/$f";
				$fru.='/' if $isReadable && -d $nnfn && $fru!~/\/$/;
				readDirRecursive($nnfn, $fru, $respsRef, $props, $all, $noval, $depth>0?$depth-1:$depth, 0, $visited);
			}
		}
	}
}
sub db_isRootFolder {
	my ($fn, $token) = @_;
	my $rows =  [];
	my $dbh = db_init();
	my $sth = $dbh->prepare('SELECT basefn,fn,type,scope,token,depth,timeout,owner FROM webdav_locks WHERE fn = ? AND basefn = ? AND token = ?');
	if (defined $sth) {
		$sth->execute($fn, $fn, $token);
		$rows = $sth->fetchall_arrayref();
	}
	return $#{$rows}>-1;
}
sub db_getLike {
	my ($fn) = @_;
	my $rows;
	my $dbh = db_init();
	my $sth = $dbh->prepare('SELECT basefn,fn,type,scope,token,depth,timeout,owner FROM webdav_locks WHERE fn like ?');
	if (defined $sth) {
		$sth->execute($fn);
		$rows = $sth->fetchall_arrayref();
	}
	return $rows;
}
sub db_get {
	my ($fn,$token) = @_;
	my $rows;
	my $dbh = db_init();
	my $sel = 'SELECT basefn,fn,type,scope,token,depth,timeout,owner FROM webdav_locks WHERE fn = ?';
	my @params;
	push @params, $fn;
	if (defined $token) {
		$sel .= ' AND token = ?';
		push @params, $token;
	}
	
	my $sth = $dbh->prepare($sel);
	if (defined $sth) {
		$sth->execute(@params);
		$rows = $sth->fetchall_arrayref();
	}
	return $rows;
}
sub db_insertProperty {
	my ($fn, $propname, $value) = @_;
	my $ret = 0;
	debug("db_insertProperty($fn, $propname, $value)");
	my $dbh = db_init();
	my $sth = $dbh->prepare('INSERT INTO webdav_props (fn, propname, value) VALUES ( ?,?,?)');
	if (defined  $sth) {
		$sth->execute($fn, $propname, $value);
		$ret = ($sth->rows >0)?1:0;
		$dbh->commit();
		$CACHE{Properties}{$fn}{$propname}=$value;
	}
	return $ret;
}
sub db_updateProperty {
	my ($fn, $propname, $value) = @_;
	my $ret = 0;
	debug("db_updateProperty($fn, $propname, $value)");
	my $dbh = db_init();
	my $sth = $dbh->prepare('UPDATE webdav_props SET value = ? WHERE fn = ? AND propname = ?');
	if (defined  $sth) {
		$sth->execute($value, $fn, $propname);
		$ret=($sth->rows>0)?1:0;
		$dbh->commit();
		$CACHE{Properties}{$fn}{$propname}=$value;
	}
	return $ret;
}
sub db_moveProperties {
	my($src,$dst) = @_;
	my $dbh = db_init();
	my $sth = $dbh->prepare('UPDATE webdav_props SET fn = ? WHERE fn = ?');
	my $ret = 0;
	if (defined $sth) {
		$sth->execute($dst,$src);
		$ret = ($sth->rows>0)?1:0;
		$dbh->commit();
		delete $CACHE{Properties}{$src};
	}
	return $ret;
}
sub db_copyProperties {
	my($src,$dst) = @_;
	my $dbh = db_init();
	my $sth = $dbh->prepare('INSERT INTO webdav_props (fn,propname,value) SELECT ?, propname, value FROM webdav_props WHERE fn = ?');
	my $ret = 0;
	if (defined $sth) {
		$sth->execute($dst,$src);
		$ret = ($sth->rows>0)?1:0;
		$dbh->commit();
	}
	return $ret;
}
sub db_deleteProperties {
	my($fn) = @_;
	my $dbh = db_init();
	my $sth = $dbh->prepare('DELETE FROM webdav_props WHERE fn = ?');
	my $ret = 0;
	if (defined $sth) {
		$sth->execute($fn);
		$ret = ($sth->rows>0)?1:0;
		$dbh->commit();
		delete $CACHE{Properties}{$fn};
	}
	return $ret;
	
}
sub db_getProperties {
	my ($fn) = @_;
	return $CACHE{Properties}{$fn} if exists $CACHE{Properties}{$fn} || $CACHE{Properties_flag}{$fn}; 
	my $dbh = db_init();
	my $sth = $dbh->prepare('SELECT fn, propname, value FROM webdav_props WHERE fn like ?');
	if (defined $sth) {
		$sth->execute("$fn\%");
		if (!$sth->err) {
			my $rows = $sth->fetchall_arrayref();
			foreach my $row (@{$rows}) {
				$CACHE{Properties}{$$row[0]}{$$row[1]}=$$row[2];
			}
			$CACHE{Properties_flag}{$fn}=1;
		}
	}
	return $CACHE{Properties}{$fn};
}
sub db_getProperty {
	my ($fn,$propname) = @_;
	debug("db_getProperty($fn, $propname)");
	my $props = db_getProperties($fn);
	return $$props{$propname};
}
sub db_removeProperty {
	my ($fn, $propname) = @_;
	debug("db_removeProperty($fn,$propname)");
	my $dbh = db_init();
	my $sth = $dbh->prepare('DELETE FROM webdav_props WHERE fn = ? AND propname = ?');
	my $ret = 0;
	if (defined $sth) {
		$sth->execute($fn, $propname);
		$ret = ($sth->rows >0)?1:0;
		$dbh->commit();
		delete $CACHE{Properties}{$fn}{$propname};
	}
	return $ret;
}
sub db_insert {
	my ($basefn, $fn, $type, $scope, $token, $depth, $timeout, $owner) = @_;
	debug("db_insert($basefn,$fn,$type,$scope,$token,$depth,$timeout,$owner)");
	my $ret = 0;
	my $dbh = db_init();
	my $sth = $dbh->prepare('INSERT INTO webdav_locks (basefn, fn, type, scope, token, depth, timeout, owner) VALUES ( ?,?,?,?,?,?,?,?)');
	if (defined $sth) {
		$sth->execute($basefn,$fn,$type,$scope,$token,$depth,$timeout,$owner);
		$ret=($sth->rows>0)?1:0;
		$dbh->commit();
	}
	return $ret;
}
sub db_update {
	my ($basefn, $fn, $timeout) = @_;
	debug("db_update($basefn,$fn,$timeout)");
	my $ret = 0;
	my $dbh = db_init();
	my $sth = $dbh->prepare('UPDATE webdav_locks SET timeout=? WHERE basefn = ? AND fn = ?' );
	if (defined $sth) {
		$sth->execute($timeout, $basefn, $fn);
		$ret = ($sth->rows>0)?1:0;
		$dbh->commit();
	}
	return $ret;
}
sub db_delete {
	my ($fn,$token) = @_;
	my $ret = 0;
	my $dbh = db_init();
	debug("db_delete($fn,$token)");
	my $sel = 'DELETE FROM webdav_locks WHERE ( basefn = ? OR fn = ? )';
	my @params = ($fn, $fn);
	if (defined $token) {
		$sel.=' AND token = ?';
		push @params, $token;
	}
	my $sth = $dbh->prepare($sel);
	if (defined $sth) {
		$sth->execute(@params);
		debug("db_delete: rows=".$sth->rows);
		$ret = $sth->rows>0?1:0;
		$dbh->commit();
	}
	
	return $ret;
}
sub db_init {
	return $DBI_INIT if defined $DBI_INIT;

	my $dbh = DBI->connect($DBI_SRC, $DBI_USER, $DBI_PASS, { RaiseError=>0, PrintError=>0, AutoCommit=>0 }) || die("You need a database (see \$DBI_SRC configuration)");
	if (defined $dbh && $CREATE_DB) {
		debug("db_init: CREATE TABLE/INDEX...");

		foreach my $query (@DB_SCHEMA) {
			my $sth = $dbh->prepare($query);
			if (defined $sth) {
				$sth->execute();
				if ($sth->err) {
					debug("db_init: '$query' execution failed!");
					$dbh=undef;
				} else {
					$dbh->commit();
					debug("db_init: '$query' done.");
				}	
			} else {
				debug("db_init: '$query' preparation failed!");
			}
		}
	}
	$DBI_INIT = $dbh;
	return $dbh;
}
sub db_rollback($) {
	my ($dbh) = @_;
	$dbh->rollback();
}
sub db_commit($) {
	my ($dbh) = @_;
	$dbh->commit();
}
sub handlePropertyRequest {
	my ($xml, $dataRef, $resp_200, $resp_403) = @_;

	if (ref($$dataRef{'{DAV:}remove'}) eq 'ARRAY') {
		foreach my $remove (@{$$dataRef{'{DAV:}remove'}}) {
			foreach my $propname (keys %{$$remove{'{DAV:}prop'}}) {
				removeProperty($propname, $$remove{'{DAV:}prop'}, $resp_200, $resp_403);
			}
		}
	} elsif (ref($$dataRef{'{DAV:}remove'}) eq 'HASH') {
		foreach my $propname (keys %{$$dataRef{'{DAV:}remove'}{'{DAV:}prop'}}) {
			removeProperty($propname, $$dataRef{'{DAV:}remove'}{'{DAV:}prop'}, $resp_200, $resp_403);
		}
	}
	if ( ref($$dataRef{'{DAV:}set'}) eq 'ARRAY' )  {
		foreach my $set (@{$$dataRef{'{DAV:}set'}}) {
			foreach my $propname (keys %{$$set{'{DAV:}prop'}}) {
				setProperty($propname, $$set{'{DAV:}prop'}, $resp_200, $resp_403);
			}
		}
	} elsif (ref($$dataRef{'{DAV:}set'}) eq 'HASH') {
		my $lastmodifiedprocessed = 0;
		foreach my $propname (keys %{$$dataRef{'{DAV:}set'}{'{DAV:}prop'}}) {
			if ($propname eq '{DAV:}getlastmodified' || $propname eq '{urn:schemas-microsoft-com:}Win32LastModifiedTime' ) {
				next if $lastmodifiedprocessed;
				$lastmodifiedprocessed = 1;
			}
			setProperty($propname, $$dataRef{'{DAV:}set'}{'{DAV:}prop'},$resp_200, $resp_403);
		}
	} 
	if ($xml =~ /<([^:]+:)?set[\s>]+.*<([^:]+:)?remove[\s>]+/s) { ## fix parser bug: set/remove|remove/set of the same prop
		if (ref($$dataRef{'{DAV:}remove'}) eq 'ARRAY') {
			foreach my $remove (@{$$dataRef{'{DAV:}remove'}}) {
				foreach my $propname (keys %{$$remove{'{DAV:}prop'}}) {
					removeProperty($propname, $$remove{'{DAV:}prop'}, $resp_200, $resp_403);
				}
			}
		} elsif (ref($$dataRef{'{DAV:}remove'}) eq 'HASH') {
			foreach my $propname (keys %{$$dataRef{'{DAV:}remove'}{'{DAV:}prop'}}) {
				removeProperty($propname, $$dataRef{'{DAV:}remove'}{'{DAV:}prop'}, $resp_200, $resp_403);
			}
		}
	}
}
sub setProperty {
	my ($propname, $elementParentRef, $resp_200, $resp_403) = @_;
	my $fn = $PATH_TRANSLATED;
	my $ru = $REQUEST_URI;
	$propname=~/^{([^}]+)}(.*)$/;
	my ($ns,$pn) = ($1,$2);
	debug("setProperty: $propname (ns=$ns, pn=$pn)");
	
	if ($propname eq '{http://apache.org/dav/props/}executable') {
		my $executable = $$elementParentRef{$propname}{'content'};
		if (defined $executable) {
			my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size, $atime,$mtime,$ctime,$blksize,$blocks) = stat($fn);
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
	} elsif (defined $NAMESPACES{$ns} && grep(/^\Q$pn\E$/,@PROTECTED_PROPS)>0) {
		$$resp_403{href}=$ru;
		$$resp_403{propstat}{prop}{$propname}=undef;
		$$resp_403{propstat}{status}='HTTP/1.1 403 Forbidden';
	} else {
		my $n = $propname;
		$n='{}'.$n if (ref($$elementParentRef{$propname}) eq 'HASH' && $$elementParentRef{$propname}{xmlns} eq "" && $n!~/^{[^}]*}/);
		my $dbval = db_getProperty($fn, $n);
		my $value = createXML($$elementParentRef{$propname},0);
		my $ret = defined $dbval ? db_updateProperty($fn, $n, $value) : db_insertProperty($fn, $n, $value);
		if ($ret) {
			$$resp_200{href}=$ru;
			$$resp_200{propstat}{prop}{$propname}=undef;
			$$resp_200{propstat}{status}='HTTP/1.1 200 OK';
		} else {
			debug("Cannot set property '$propname'");
			$$resp_403{href}=$ru;
			$$resp_403{propstat}{prop}{$propname}=undef;
			$$resp_403{propstat}{status}='HTTP/1.1 403 Forbidden';
			
		}
	}
}
sub rcopy {
	my ($src,$dst,$move,$depth) = @_;
	
	$depth=0 unless defined $depth;

	return 0 if defined $LIMIT_FOLDER_DEPTH && $LIMIT_FOLDER_DEPTH > 0 && $depth > $LIMIT_FOLDER_DEPTH;

	# src == dst ?
	return 0 if $src eq $dst;

	# src in dst?
	return 0 if -d $src && $dst =~ /^\Q$src\E/;

	# src exists and readable?
	return 0 if ! -e $src || (!$IGNOREFILEPERMISSIONS && !-r $src);

	# dst writeable?
	return 0 if -e $dst && (!$IGNOREFILEPERMISSIONS && !-w $dst);

	my $nsrc = $src;
	$nsrc =~ s/\/$//; ## remove trailing slash for link test (-l)
	
	if ( -l $nsrc) { # link
		if (!$move || !rename($nsrc, $dst)) {
			my $orig = readlink($nsrc);
			return 0 if ( !$move || unlink($nsrc) ) && !symlink($orig,$dst); 
		}
	} elsif ( -f $src ) { # file
		if (-d $dst) {
			$dst.='/' if $dst !~/\/$/;
			$dst.=basename($src);
		}
		if (!$move || !rename($src,$dst)) {
			return 0 unless open(SRC,"<$src");
			return 0 unless open(DST,">$dst");
			my $buffer;
			while (read(SRC,$buffer,$BUFSIZE || 1048576)>0) {
				print DST $buffer;
			}

			close(SRC);
			close(DST);
			if ($move) {
				return 0 if !$IGNOREFILEPERMISSIONS && !-w $src;
				return 0 unless unlink($src);
			}
		}
	} elsif ( -d $src ) {
		# cannot write folders to files:
		return 0 if -f $dst;

		$dst.='/' if $dst !~ /\/$/;
		$src.='/' if $src !~ /\/$/;

		if (!$move || getDirInfo($src,'realchildcount')>0 || !rename($src,$dst)) {
			mkdir $dst unless -e $dst;

			return 0 unless opendir(SRC,$src);
			my $rret = 1;
			foreach my $filename (grep { !/^\.{1,2}$/ } readdir(SRC)) {
				$rret = $rret && rcopy($src.$filename, $dst.$filename, $move, $depth+1);
			}
			closedir(SRC);
			if ($move) {
				return 0 if !$IGNOREFILEPERMISSIONS && !-w $src;
				return 0 unless $rret && rmdir($src);
			}
		}
	} else {
		return 0;
	}
	db_deleteProperties($dst);
	db_copyProperties($src,$dst);
	db_deleteProperties($src) if $move;
	
	return 1;
}
sub rmove {
	my ($src, $dst) = @_;
	return rcopy($src, $dst, 1);
}
sub getQuota {
	my ($fn) = @_;
	$fn = $PATH_TRANSLATED unless defined $fn;
	return ($CACHE{getQuota}{$fn}{block_hard}, $CACHE{getQuota}{$fn}{block_curr}) if defined $CACHE{getQuota}{$fn}{block_hard};

	my ($block_curr, $block_soft, $block_hard, $block_timelimit,
            $inode_curr, $inode_soft, $inode_hard, $inode_timelimit);
	$fn=~s/(["\$\\])/\\$1/g; 
	if (defined $GFSQUOTA && open(QCMD,"$GFSQUOTA \"$fn\"|")) {
		my @lines = <QCMD>;
		close(QCMD);
		my @vals = split(/\s+/,$lines[0]);
		($block_hard,$block_curr) = ($vals[3] * 1048576, $vals[7] * 1048576);
	} elsif (defined $AFSQUOTA && open(QCMD, "$AFSQUOTA \"$fn\"|")) {
		my @lines = <QCMD>;
		close(QCMD);
		my @vals = split(/\s+/, $lines[1]);
		($block_hard,$block_curr) = ($vals[1] * 1024, $vals[2] * 1024);
	} else {
		($block_curr, $block_soft, $block_hard, $block_timelimit,
		    $inode_curr, $inode_soft, $inode_hard, $inode_timelimit) = Quota::query(Quota::getqcarg($fn));
	}
	$CACHE{getQuota}{$fn}{block_hard}=$block_hard;
	$CACHE{getQuota}{$fn}{block_curr}=$block_curr;
	return ($block_hard,$block_curr);
}
sub getuuid {
	my ($fn) = @_;
	my $uuid = new OSSP::uuid;
	my $uuid_ns = new OSSP::uuid;
	$uuid_ns->load("opaquelocktoken:$fn");
	$uuid->make("v3", $uuid_ns, "$fn".time());
	return $uuid->export("str");
}
sub getDirInfo {
	my ($fn, $prop, $filter, $limit, $max) = @_;
	return $CACHE{getDirInfo}{$fn}{$prop} if defined $CACHE{getDirInfo}{$fn}{$prop};
	my %counter = ( childcount=>0, visiblecount=>0, objectcount=>0, hassubs=>0 );
	if (opendir(DIR,$fn)) {
		foreach my $f ( grep { !/^\.{1,2}$/ } readdir(DIR)) {
			$counter{realchildcount}++;
			if (!is_hidden("$fn/$f")) {
				next if defined $filter && defined $$filter{$fn} && $f !~ $$filter{$fn};
				$counter{childcount}++;
				last if (defined $limit && defined $$limit{$fn} && $counter{childcount} >= $$limit{$fn}) || (!defined $$limit{$fn} && defined $max && $counter{childcount} >= $max);
				$counter{visiblecount}++ if !-d "$fn/$f" && $f !~/^\./;
				$counter{objectcount}++ if !-d "$fn/$f";
			}
		}
		closedir(DIR);
	}
	$counter{hassubs} = ($counter{childcount}-$counter{objectcount} > 0 )? 1:0;

	foreach my $k (keys %counter) {
		$CACHE{getDirInfo}{$fn}{$k}=$counter{$k};
	}
	return $counter{$prop};
}
sub getACLSupportedPrivilegeSet {
	return { 'supported-privilege' =>
			{ 
				privilege => { all => undef }, 
				abstract => undef,
				description=>'Any operation',
				'supported-privilege' => [ 
					{
						privilege => { read =>  undef },
						description => 'Read any object',
						'supported-privilege' => [
							{
								privilege => { 'read-acl' => undef },
								absract => undef,
								description => 'Read ACL',
							},
							{
								privilege => { 'read-current-user-privilege-set' => undef },
								absract => undef,
								description => 'Read current user privilege set property',
							},
							{	privilege => { 'read-free-busy' },
								abstract => undef,
								description => 'Read busy time information'
							},
						],
					},
					{
						privilege => { write => undef },
						description => 'Write any object',
						'supported-privilege' => [
							{
								privilege => { 'write-acl' => undef },
								abstract => undef,
								description => 'Write ACL',
							},
							{
								privilege => { 'write-properties' => undef },
								abstract => undef,
								description => 'Write properties',
							},
							{
								privilege => { 'write-content' => undef },
								abstract => undef,
								description => 'Write resource content',
							},
						],

					},
					{
						privilege => {unlock => undef},
						abstract => undef,
						description => 'Unlock resource',
					},
					{
						privilege => {bind => undef},
						abstract => undef,
						description => 'Add new files/folders',
					},
					{
						privilege => {unbind => undef},
						abstract => undef,
						description => 'Delete or move files/folders',
					},
				],
			}
	};
}
sub getACLCurrentUserPrivilegeSet {
	my ($fn) = @_;

	my $usergrant;
	if ($IGNOREFILEPERMISSIONS || -r $fn) {
		push @{$$usergrant{privilege}},{read  => undef };
		push @{$$usergrant{privilege}},{'read-acl'  => undef };
		push @{$$usergrant{privilege}},{'read-current-user-privilege-set'  => undef };
		if ($IGNOREFILEPERMISSIONS || -w $fn) {
			push @{$$usergrant{privilege}},{write => undef };
			push @{$$usergrant{privilege}},{'write-acl' => undef };
			push @{$$usergrant{privilege}},{'write-content'  => undef };
			push @{$$usergrant{privilege}},{'write-properties'  => undef };
			push @{$$usergrant{privilege}},{bind=> undef };
			push @{$$usergrant{privilege}},{unbind=> undef };
		}
	}

	return $usergrant;
}
sub getACLProp {
	my ($mode) = @_;
	my @ace;

	my $ownergrant;
	my $groupgrant;
	my $othergrant;

	$mode = $mode & 07777;

	push @{$$ownergrant{privilege}},{read  => undef } if ($mode & 0400) == 0400;
	push @{$$ownergrant{privilege}},{write => undef } if ($mode & 0200) == 0200;
	push @{$$ownergrant{privilege}},{bind => undef } if ($mode & 0200) == 0200;
	push @{$$ownergrant{privilege}},{unbind => undef } if ($mode & 0200) == 0200;
	push @{$$groupgrant{privilege}},{read  => undef } if ($mode & 0040) == 0040;
	push @{$$groupgrant{privilege}},{write => undef } if ($mode & 0020) == 0020;
	push @{$$groupgrant{privilege}},{bind => undef } if ($mode & 0020) == 0020;
	push @{$$groupgrant{privilege}},{unbind => undef } if ($mode & 0020) == 0020;
	push @{$$othergrant{privilege}},{read  => undef } if ($mode & 0004) == 0004;
	push @{$$othergrant{privilege}},{write => undef } if ($mode & 0002) == 0002;
	push @{$$othergrant{privilege}},{bind => undef } if ($mode & 0002) == 0002;
	push @{$$othergrant{privilege}},{unbind => undef } if ($mode & 0002) == 0002;
	
	push @ace, { principal => { property => { owner => undef } },
		     grant => $ownergrant
                   };
	push @ace, { principal => { property => { owner => undef } },
	             deny => { privilege => { all => undef } }
	           };

	push @ace, { principal => { property => { group => undef } },
		     grant => $groupgrant
                   };
	push @ace, { principal => { property => { group => undef } },
	             deny => { privilege => { all => undef } }
	           };

	push @ace, { principal => { all => undef },
		     grant => $othergrant
                   };

	return { ace => \@ace };
}
sub getCalendarHomeSet {
	my ($uri) = @_;
	return $uri unless defined %CALENDAR_HOME_SET;
	my $rmuser = $ENV{REDIRECT_REMOTE_USER} || $ENV{REMOTE_USER};
	$rmuser = $< unless exists $CALENDAR_HOME_SET{$rmuser};
	return  ( exists $CALENDAR_HOME_SET{$rmuser} ? $CALENDAR_HOME_SET{$rmuser} : $CALENDAR_HOME_SET{default} );
}
sub getAddressbookHomeSet {
	my ($uri) = @_;
	return $uri unless defined %ADDRESSBOOK_HOME_SET;
	my $rmuser = $ENV{REDIRECT_REMOTE_USER} || $ENV{REMOTE_USER};
	$rmuser = $< unless exists $ADDRESSBOOK_HOME_SET{$rmuser};
	return ( exists $ADDRESSBOOK_HOME_SET{$rmuser} ? $ADDRESSBOOK_HOME_SET{$rmuser} : $ADDRESSBOOK_HOME_SET{default} );
}
sub getNameSpace {
	my ($prop) = @_;
	return defined $ELEMENTS{$prop}?$ELEMENTS{$prop}:$ELEMENTS{default};
}
sub getNameSpaceUri {
	my  ($prop) = @_;
	return $NAMESPACEABBR{getNameSpace($prop)};
}
sub getFileContent {
	my ($fn) = @_;
	debug("getFileContent($fn)");
	my $content="";
	if (-e $fn && !-d $fn && open(F,"<$fn")) {
		$content = join("",<F>);
		close(F);
	}
	return $content;
}
sub moveToTrash  {
	my ($fn) = @_;

	my $ret = 0;
	my $etag = getETag($fn); ## get a unique name for trash folder
	$etag=~s/\"//g;
	my $trash = "$TRASH_FOLDER$etag/";

	if ($fn =~ /^\Q$TRASH_FOLDER\E/) { ## delete within trash
		my @err;
		deltree($fn, \@err);
		$ret = 1 if $#err == -1;
		debug("moveToTrash($fn)->/dev/null = $ret");
	} elsif (-e $TRASH_FOLDER || mkdir($TRASH_FOLDER)) {
		if (-e $trash) {
			my $i=0;
			while (-e $trash) { ## find unused trash folder
				$trash="$TRASH_FOLDER$etag".($i++).'/';
			}
		}
		$ret = 1 if mkdir($trash) && rmove($fn, $trash.basename($fn));
		debug("moveToTrash($fn)->$trash = $ret");
	}
	return $ret;
}
sub getChangeDirForm {
	my ($ru) = @_;
	return 
		$cgi->span({-id=>'changedir', -class=>'hidden'},
		    $cgi->input({-id=>'changedirpath', -onkeypress=>'return catchEnter(event,"changedirgobutton");', -name=>'changedirpath', -value=>$ru, -size=>50 })
		   . ' '
		   . $cgi->button(-id=>'changedirgobutton',  -name=>_tl('go'), onclick=>'javascript:changeDir(document.getElementById("changedirpath").value)')
		   . ' '
		   . $cgi->button(-id=>'changedircancelbutton',  -name=>_tl('cancel'), onclick=>'javascript:showChangeDir(false)')
		)
		. $cgi->button(-id=>'changedirbutton', -name=>_tl('changedir'), -onclick=>'javascript:showChangeDir(true)')
		. ( $ENABLE_BOOKMARKS ?  buildBookmarkList() : '' )
		;
	
}
sub buildBookmarkList {
	my(@bookmarks, %labels, %attributes);
	my $isBookmarked = 0;
	my $i=0;
	while (my $b = $cgi->cookie('bookmark'.$i)) { 
		$i++;
		next if $b eq '-';
		push @bookmarks, $b;
		$labels{$b} = $cgi->escapeHTML(length($b) <=25 ? $b : substr($b,0,5).'...'.substr($b,length($b)-17));
		$attributes{$b}{title}=$cgi->escapeHTML($b);
		$attributes{$b}{disabled}='disabled' if $b eq $REQUEST_URI;
		$isBookmarked = 1 if $b eq $REQUEST_URI;
	}
	sub getBookmarkTime {
		my $i = 0;
		$i++ while ($cgi->cookie('bookmark'.$i) && $cgi->cookie('bookmark'.$i) ne $_[0]);
		return $cgi->cookie('bookmark'.$i.'time') || 0;
	}
	sub cmpBookmarks{
		my $s = $cgi->cookie('bookmarksort') || 'time-desc';
		my $f = $s=~/desc$/ ? -1 : 1;
		
		if ($s =~ /^time/) {
			my $at = getBookmarkTime($a);
			my $bt = getBookmarkTime($b);
			return $f * ($at == $bt ? $a cmp $b : $at < $bt ? -1 : 1);
		}
		return $f * ( $a cmp $b );
	};
	@bookmarks = sort cmpBookmarks @bookmarks;
	
	$attributes{""}{disabled}='disabled';
	if ($isBookmarked) {
		push @bookmarks, ""; 
		push @bookmarks, '-'; $labels{'-'}=_tl('rmbookmark'); $attributes{'-'}= { -title=>_tl('rmbookmarktitle'), -class=>'func' };
	} else {
		unshift @bookmarks, '+'; $labels{'+'}=_tl('addbookmark'); $attributes{'+'}={-title=>_tl('addbookmarktitle'), -class=>'func'};
	}
	if ($#bookmarks > 1) {
		my $bms = $cgi->cookie('bookmarksort') || 'time-desc';
		my ($sbpadd, $sbparr, $sbtadd, $sbtarr) = ('','','','');
		if ($bms=~/^path/) {
			$sbpadd = ($bms=~/desc$/)? '' : '-desc';
			$sbparr = ($bms=~/desc$/)? ' &darr;' : ' &uarr;';
		} else {
			$sbtadd = ($bms=~/desc$/)? '' : '-desc';
			$sbtarr = ($bms=~/desc$/)? ' &darr;' : ' &uarr;';
		}
		push @bookmarks, 'path'.$sbpadd;  $labels{'path'.$sbpadd}=_tl('sortbookmarkbypath').$sbparr; $attributes{'path'.$sbpadd}{class}='func';
		push @bookmarks, 'time'.$sbtadd;  $labels{'time'.$sbtadd}=_tl('sortbookmarkbytime').$sbtarr; $attributes{'time'.$sbtadd}{class}='func';
	}
	push @bookmarks,"";
	push @bookmarks,'--'; $labels{'--'}=_tl('rmallbookmarks'); $attributes{'--'}={ title=>_tl('rmallbookmarkstitle'), -class=>'func' };

	unshift @bookmarks, '#'; $labels{'#'}=_tl('bookmarks'); $attributes{'#'}{class}='title'; 
	my $e = $cgi->autoEscape(0);
	my $content = $cgi->popup_menu( -class=>'bookmark', -name=>'bookmark', -onchange=>'return bookmarkChanged(this.options[this.selectedIndex].value);', -values=>\@bookmarks, -labels=>\%labels, -attributes=>\%attributes);
	$cgi->autoEscape($e);
	return ' ' . $cgi->span({-id=>'bookmarks'}, $content) 
		. ' '. $cgi->a({-id=>'addbookmark',-class=>($isBookmarked ? 'hidden' : undef),-onclick=>'return addBookmark()', -href=>'#', -title=>_tl('addbookmarktitle')}, _tl('addbookmark'))
		. ' '. $cgi->a({-id=>'rmbookmark',-class=>($isBookmarked ? undef : 'hidden'),-onclick=>'return rmBookmark()', -href=>'#', -title=>_tl('rmbookmarktitle')}, _tl('rmbookmark')) ;
}
sub getQuickNavPath {
	my ($ru, $query) = @_;
	$ru = uri_unescape($ru);
	my $content = "";
	my $path = "";
	foreach my $pe (split(/\//, $ru)) {
		$path .= uri_escape($pe) . '/';
		$path = '/' if $path eq '//';
		$content .= $cgi->a({-href=>$path.(defined $query?"?$query":""), -title=>$path}," $pe/");
	}
	$content .= $cgi->a({-href=>'/', -title=>'/'}, '/') if $content eq '';

	$content = $cgi->span({-id=>'quicknavpath'}, $content);
	$content .= ' '.getChangeDirForm($ru,$query) unless defined $cgi->param('search') || defined $cgi->param('action');

	return $content;
}
sub renderToggleFieldSet {
	my($name,$content,$notoggle) = @_;

	my $display = $cgi->cookie('toggle'.$name) || 'none';
	return qq@<fieldset><legend>@
		.($notoggle ? '' : $cgi->span({-id=>"togglebutton$name",-onclick=>"toggle('$name');", -class=>'toggle'},$display eq 'none' ? '+' : '-'))
		.$cgi->escapeHTML(_tl($name))
		.qq@</legend>@
		.$cgi->div({-id=>"toggle$name",-style=>($notoggle ? 'display:block;' : 'display:'.$display.';')}, $content)
		.qq@</fieldset>@;
}
sub renderFieldSet { return renderToggleFieldSet($_[0],$_[1],1); }
sub renderDeleteFilesButton { return $cgi->submit(-title=>_tl('deletefilestext'),-name=>'delete',-disabled=>'disabled',-value=>_tl('deletefilesbutton'),-onclick=>'return window.confirm("'._tl('deletefilesconfirm').'");'); }
sub renderCopyButton { return $cgi->button({-onclick=>'clpaction("copy")', -disabled=>'disabled', -name=>'copy', -class=>'copybutton', -value=> _tl('copy'), -title=>_tl('copytooltip')}); }
sub renderCutButton { return $cgi->button({-onclick=>'clpaction("cut")', -disabled=>'disabled', -name=>'cut', -class=>'cutbutton', -value=>_tl('cut'), -title=>_tl('cuttooltip')}); }
sub renderPasteButton { return $cgi->button({-onclick=>'clpaction("paste")', -disabled=>'disabled', -id=>'paste', -class=>'pastebutton',-value=>_tl('paste')}); }
sub renderToolbar {
	my $clpboard = "";
	$clpboard = $cgi->div({-class=>'clipboard'}, renderCopyButton().renderCutButton().renderPasteButton()) if ($ENABLE_CLIPBOARD); 
	return $cgi->div({-class=>'toolbar'}, 
			$clpboard
			.$cgi->div({-class=>'functions'}, 
				(!$ALLOW_ZIP_DOWNLOAD ? '' : $cgi->span({-title=>_tl('zipdownloadtext')}, $cgi->submit(-name=>'zip', -disabled=>'disabled', -value=>_tl('zipdownloadbutton'))))
				.'&nbsp;&nbsp;'
				.$cgi->input({-name=>'colname1', -size=>10, -onkeypress=>'return catchEnter(event, "createfolder1")'}).$cgi->submit(-id=>'createfolder1', -name=>'mkcol',-value=>_tl('createfolderbutton'))
				.'&nbsp;&nbsp;'
				.renderDeleteFilesButton()
			)
		);
}
sub renderFileUploadView {
	my ($fn) = @_;
	return $cgi->hidden(-name=>'upload',-value=>1)
		.$cgi->span({-id=>'file_upload'},_tl('fileuploadtext').$cgi->filefield(-name=>'file_upload', -class=>'fileuploadfield', -multiple=>'multiple', -onchange=>'return addUploadField()' ))
		.$cgi->span({-id=>'moreuploads'},"")
		.' '.$cgi->submit(-name=>'filesubmit',-value=>_tl('fileuploadbutton'),-onclick=>'return window.confirm("'._tl('fileuploadconfirm').'");')
		.' '
		.$cgi->a({-onclick=>'javascript:return addUploadField(1);',-href=>'#'},_tl('fileuploadmore'))
		.' ('.($CGI::POST_MAX / 1048576).' MB max)';
}
sub renderCreateNewFolderView {
	return $cgi->div({-class=>'createfolder'},'&bull; '._tl('createfoldertext').$cgi->input({-name=>'colname', -size=>30, -onkeypress=>'return catchEnter(event,"createfolder");'}).$cgi->submit(-id=>'createfolder', -name=>'mkcol',-value=>_tl('createfolderbutton')))
}
sub renderMoveView {
	return $cgi->div({-class=>'movefiles', -id=>'movefiles'},
		'&bull; '._tl('movefilestext')
		.$cgi->input({-name=>'newname',-disabled=>'disabled',-size=>30,-onkeypress=>'return catchEnter(event,"rename");'}).$cgi->submit(-id=>'rename',-disabled=>'disabled', -name=>'rename',-value=>_tl('movefilesbutton'),-onclick=>'return window.confirm("'._tl('movefilesconfirm').'");')
	);
}
sub renderDeleteView {
	return $cgi->div({-class=>'delete', -id=>'delete'},'&bull; '.$cgi->submit(-disabled=>'disabled', -name=>'delete', -value=>_tl('deletefilesbutton'), -onclick=>'return window.confirm("'._tl('deletefilesconfirm').'");') 
		.' '._tl('deletefilestext'));
}
sub renderChangePermissionsView() {
	return	$cgi->start_table()
			. $cgi->Tr($cgi->td({-colspan=>2},_tl('changefilepermissions'))
				)
			.		
						(defined $PERM_USER 
							? $cgi->Tr($cgi->td( _tl('user') )
								. $cgi->td($cgi->checkbox_group(-name=>'fp_user', -values=>$PERM_USER,
									-labels=>{'r'=>_tl('readable'), 'w'=>_tl('writeable'), 'x'=>_tl('executable'), 's'=>_tl('setuid')}))
								)
							: ''
						)
						.(defined $PERM_GROUP
							? $cgi->Tr($cgi->td(_tl('group') )
								. $cgi->td($cgi->checkbox_group(-name=>'fp_group', -values=>$PERM_GROUP,
									-labels=>{'r'=>_tl('readable'), 'w'=>_tl('writeable'), 'x'=>_tl('executable'), 's'=>_tl('setgid')}))
								)
							: ''
						 )
						.(defined $PERM_OTHERS
							? $cgi->Tr($cgi->td(_tl('others'))
								.$cgi->td($cgi->checkbox_group(-name=>'fp_others', -values=>$PERM_OTHERS,
									-labels=>{'r'=>_tl('readable'), 'w'=>_tl('writeable'), 'x'=>_tl('executable'), 't'=>_tl('sticky')}))
								)
							: ''
						 )
			. $cgi->Tr( $cgi->td( {-colspan=>2},
						$cgi->popup_menu(-name=>'fp_type',-values=>['a','s','r'], -labels=>{ 'a'=>_tl('add'), 's'=>_tl('set'), 'r'=>_tl('remove')})
						.($ALLOW_CHANGEPERMRECURSIVE ? ' '.$cgi->checkbox_group(-name=>'fp_recursive', -value=>['recursive'], 
								-labels=>{'recursive'=>_tl('recursive')}) : '')
						. ' '. $cgi->submit(-disabled=>'disabled', -name=>'changeperm',-value=>_tl('changepermissions'), -onclick=>'return window.confirm("'._tl('changepermconfirm').'");')
			))
		. $cgi->Tr($cgi->td({-colspan=>2},_tl('changepermlegend')))
		. $cgi->end_table();
}
sub renderZipDownloadButton { return $cgi->submit(-disabled=>'disabled',-name=>'zip',-value=>_tl('zipdownloadbutton'),-title=>_tl('zipdownloadtext')) }
sub renderZipUploadView {
	return _tl('zipuploadtext').$cgi->filefield(-name=>'zipfile_upload', -multiple=>'multiple').$cgi->submit(-name=>'uncompress', -value=>_tl('zipuploadbutton'),-onclick=>'return window.confirm("'._tl('zipuploadconfirm').'");');
}
sub renderZipView {
	my $content = "";
	$content .= '&bull; '.renderZipDownloadButton()._tl('zipdownloadtext').$cgi->br() if $ALLOW_ZIP_DOWNLOAD; 
	$content .= '&bull; '.renderZipUploadView() if $ALLOW_ZIP_UPLOAD;
	return $content;
}
sub getActionViewInfos {
	my ($action) = @_;
	return $cgi->cookie($action) ? split(/\//, $cgi->cookie($action)) : ( 'false', undef, undef, undef, 'false');
}
sub renderActionView {
	my ($action, $name, $view) = @_;
	my $style = '';
	my ($visible, $x, $y, $z,$collapsed) = getActionViewInfos($action);
	$style .= $visible eq 'true' ? 'visibility: visible;' :'';
	$style .= $x ? 'left: '.$x.';' : '';
	$style .= $y ? 'top: '.$y.';' : '';
	$style .= $z ? 'z-index: '.$z.';' : '';
	return $cgi->div({-class=>'sidebaractionview'.($collapsed eq 'true'?' collapsed':''),-id=>$action, -onclick=>'this.style.zIndex = getDragZIndex(this.style.zIndex);', -style=>$style},
		$cgi->div({-class=>'sidebaractionviewheader',
				-ondblclick=>"toggleCollapseAction('$action',event)", 
				-onmousedown=>"handleWindowMove(event,'$action', 1)", 
				-onmouseup=>"handleWindowMove(event,'$action',0)"}, 
			_tl($name) . $cgi->span({-onclick=>"hideActionView('$action');",-style=>'cursor:pointer;float:right;'},' [X] '))
		.$cgi->div({-class=>'sidebaractionviewaction'.($collapsed eq 'true'?' collapsed':''),-id=>"v_$action"},$view)
		);
}
sub renderSideBarMenuItem {
	my ($action, $title, $onclick, $content) = @_;
	my $isactive = (getActionViewInfos($action))[0] eq 'true';
	return $cgi->div({
				-id=>$action.'menu', -class=>'sidebaraction'.($isactive?' active':''), 
				-onmouseover=>'javascript:addClassName(this, "highlight");', -onmouseout=>'javascript:removeClassName(this, "highlight");',
				-onclick=>$onclick, -title=>$title}, 
			$content);
}
sub renderSideBar {
	my $content = "";

	$content .= $cgi->div({-class=>'sidebarheader'}, _tl('management'));

	$content .= renderSideBarMenuItem('fileuploadview',_tl('upload'), 'toggleActionView("fileuploadview")',$cgi->button({-value=>_tl('upload')}));
	$content .= renderSideBarMenuItem('download', _tl('download'), undef, renderZipDownloadButton());
	$content .= renderSideBarMenuItem('copy',_tl('copytooltip'), undef, renderCopyButton());
	$content .= renderSideBarMenuItem('cut', _tl('cuttooltip'), undef, renderCutButton());
	$content .= renderSideBarMenuItem('paste', undef, undef, renderPasteButton());
	$content .= renderSideBarMenuItem('deleteview', undef, undef, renderDeleteFilesButton());
	$content .= renderSideBarMenuItem('createfolderview', _tl('createfolderbutton'), 'toggleActionView("createfolderview");', $cgi->button({-value=> _tl('createfolderbutton')}));
	$content .= renderSideBarMenuItem('movefilesview', _tl('movefilesbutton'), undef, $cgi->button({-disabled=>'disabled',-onclick=>'toggleActionView("movefilesview");',-name=>'rename',-value=>_tl('movefilesbutton')}));
	$content .= renderSideBarMenuItem('permissionsview', _tl('permissions'), undef, $cgi->button({-disabled=>'disabled', -onclick=>'toggleActionView("permissionsview");', -value=>_tl('permissions'),-name=>'changeperm',-disabled=>'disabled'})) if $ALLOW_CHANGEPERM;
	$content .= renderSideBarMenuItem('afsaclmanagerview', _tl('afs'), 'toggleActionView("afsaclmanagerview");', $cgi->button({-value=>_tl('afs')})) if $ENABLE_AFSACLMANAGER;
	$content .= $cgi->hr().renderSideBarMenuItem('afsgroupmanagerview', _tl('afsgroup'), 'toggleActionView("afsgroupmanagerview");', $cgi->button({-value=>_tl('afsgroup')})).$cgi->hr() if $ENABLE_AFSGROUPMANAGER;

	$content .= $cgi->div({-class=>'sidebarheader'},_tl('viewoptions'));
	my $showall = $cgi->param('showpage') ? 0 : $cgi->param('showall') || $cgi->cookie('showall') || 0;
	$content .= renderSideBarMenuItem('navpageview', _tl('navpageview'), 'window.location.href="?showpage=1";',$cgi->button(-value=>_tl('navpageview'))) if $showall;
	$content .= renderSideBarMenuItem('navall', _tl('navalltooltip'),'window.location.href="?showall=1";', $cgi->button(-value=>_tl('navall'))) unless $showall;
	$content .= $cgi->div({}, renderNameFilterForm().$cgi->div('&nbsp;')) if $showall;
	$content .= renderSideBarMenuItem('changeview', _tl('classicview'), 'javascript:window.location.href="?view=classic";', $cgi->button({-value=>_tl('classicview')})); 

	my $av = "";
	$av.= renderActionView('fileuploadview', 'upload', renderFileUploadView($PATH_TRANSLATED).$cgi->br().'&nbsp;'.$cgi->br().$cgi->div(renderZipUploadView()));
	$av.= renderActionView('createfolderview', 'createfolderbutton', renderCreateNewFolderView());
	$av.= renderActionView('movefilesview', 'movefilesbutton', renderMoveView());
	$av.= renderActionView('permissionsview', 'permissions', renderChangePermissionsView()) if $ALLOW_CHANGEPERM;
	$av.= renderActionView('afsaclmanagerview', 'afs', renderAFSACLManager()) if $ENABLE_AFSACLMANAGER;
	$av.= renderActionView('afsgroupmanagerview', 'afsgroup', renderAFSGroupManager()) if $ENABLE_AFSGROUPMANAGER;

	my $showsidebar = ! defined $cgi->cookie('sidebar') || $cgi->cookie('sidebar') eq 'true';
	my $sidebartogglebutton = $showsidebar ? '&lt;' : '&gt';

	return $cgi->div({-id=>'sidebar', -class=>'sidebar'}, $cgi->start_table({-id=>'sidebartable',-class=>'sidebartable'.($showsidebar?'':' collapsed')}).$cgi->Tr($cgi->td({-id=>'sidebarcontent', -style=>$showsidebar?'':'display:none'},$content).$cgi->td({-id=>'sidebartogglebutton', -title=>_tl('togglesidebar'), -class=>'sidebartogglebutton', -onclick=>'toggleSideBar()'},$sidebartogglebutton)).$cgi->end_table()). $av;
}
sub renderPageNavBar {
	my ($ru, $count, $files) = @_;
	my $limit = $PAGE_LIMIT || -1;
	my $showall = $cgi->param('showpage') ? 0 : $cgi->param('showall') || $cgi->cookie('showall') || 0;
	my $page = $cgi->param('page') || 1;

	my $content = "";
	return $content if $limit <1 || $count <= $limit;

	my $maxpages = ceil($count / $limit);
	return $content if $maxpages == 0;

	return $cgi->div({-class=>'showall'}, $cgi->a({href=>$ru."?showpage=1"}, _tl('navpageview')). ', '.renderNameFilterForm()) if ($showall);

	$content .= ($page > 1 ) 
			? $cgi->a({-href=>sprintf('%s?page=%d;pagelimit=%d',$ru,1,$limit), -title=>_tl('navfirsttooltip')}, _tl('navfirst')) 
			: _tl('navfirstblind');
	$content .= ($page > 1 ) 
			? $cgi->a({-href=>sprintf('%s?page=%d;pagelimit=%d',$ru,$page-1,$limit), -title=>_tl('navprevtooltip')}, _tl('navprev')) 
			: _tl('navprevblind');
	#$content .= _tl('navpage')."$page/$maxpages: ";
	$content .= _tl('navpage');
	my %attributes;
	if ($maxpages > 1 && $maxpages <= 50) {
		foreach my $i ( 1 .. $maxpages ) {
			$attributes{$i}{title}=$cgi->escapeHTML(sprintf('%s,...,%s',substr($$files[($i-1)*$limit],0,8),substr(($i*$limit -1 > $#$files ? $$files[$#$files] : $$files[$i*$limit -1]),0,8)));
		}
	}

	$content .= $maxpages < 2 || $maxpages > 50 ? $page : $cgi->popup_menu(-default=>$page, -name=>'page', -values=> [ 1 .. $maxpages ], -attributes=>\%attributes, -onchange=>'javascript:window.location.href=window.location.pathname+"?page="+this.value;' );
	$content .= " / $maxpages: ";

	$content .= sprintf("%02d-%02d/%d",(($limit * ($page - 1)) + 1) , ( $page < $maxpages || $count % $limit == 0 ? $limit * $page : ($limit*($page-1)) + $count % $limit), $count);
	
	$content .= ($page < $maxpages) 
			? $cgi->a({-href=>sprintf('%s?page=%d;pagelimit=%d', $ru, $page+1, $limit), -title=>_tl('navnexttooltip')},_tl('navnext')) 
			: _tl('navnextblind');

	$content .= ($page < $maxpages) 
			? $cgi->a({-href=>sprintf('%s?page=%d;pagelimit=%d', $ru, $maxpages, $limit), -title=>_tl('navlasttooltip')},_tl('navlast')) 
			: _tl('navlastblind');

	$content .= ' '.$cgi->span({-title=>_tl('pagelimittooltip')}, _tl('pagelimit').' '.$cgi->popup_menu(-name=>'pagelimit', -onchange=>'javascript: window.location.href=window.location.pathname + (this.value==-1 ? "?showall=1" : "?page=1;pagelimit="+this.value);', -values=>\@PAGE_LIMITS, -default=>$limit, -labels=>{-1=>_tl('navall')}, -attributes=>{-1=>{title=>_tl('navalltooltip')}}));

	##$content .= ' '. $cgi->a({-href=>$ru."?showall=1", -title=>_tl('navalltooltip')}, _tl('navall'));


	return $cgi->div({-class=>'pagenav'},$content);
}
sub getQueryParams {
	# preserve query parameters
	my @query;
	foreach my $param (()) {
		push @query, $param.'='.$cgi->param($param) if defined $cgi->param($param);
	}
	return $#query>-1 ? join(';',@query) : undef;
}
sub readDir {
	my ($dirname) = @_;
	my @files;
	if ((!defined $FILECOUNTPERDIRLIMIT{$dirname} || $FILECOUNTPERDIRLIMIT{$dirname} >0 ) && opendir(my $dir,$dirname)) {
		while (my $file = readdir($dir)) {
			next if $file =~ /^(\.|\.\.)$/;
			next if is_hidden("$dirname/$file");
			next if defined $FILEFILTERPERDIR{$dirname} && $file !~ $FILEFILTERPERDIR{$dirname};
			last if (defined $FILECOUNTPERDIRLIMIT{$dirname} && $#files+1 >= $FILECOUNTPERDIRLIMIT{$dirname}) 
				|| (!defined $FILECOUNTPERDIRLIMIT{$dirname} && defined $FILECOUNTLIMIT && $#files+1 > $FILECOUNTLIMIT);
			push @files, $file;
		}
		closedir(DIR);
	}
	return \@files;
}
sub getFolderList {
	my ($fn,$ru,$filter) = @_;
	my ($content,$list,$count,$filecount,$foldercount,$filesizes) = ("",0,0,0,0);

	my $row = "";
	$list="";
	
	$row.=$cgi->td({-class=>'th_sel'},$cgi->checkbox(-onclick=>'javascript:toggleAllFiles(this);', -name=>'selectall',-value=>"",-label=>"", -title=>_tl('togglealltooltip'))) if $ALLOW_FILE_MANAGEMENT;

	my $dir = $ORDER=~/_desc$/ ? '' : '_desc';
	my $query = $filter ? 'search=' . $cgi->param('search'):'';
	my $ochar = ' <span class="orderchar">'.($dir eq '' ? '&darr;' :'&uarr;').'</span>';
	$row.= $cgi->td({-class=>'th_fn'.($ORDER=~/^name/?' th_highlight':''), style=>'min-width:'.$MAXFILENAMESIZE.'em;',-onclick=>"window.location.href='$ru?order=name$dir;$query'"}, $cgi->a({-href=>"$ru?order=name$dir;$query"},_tl('names').($ORDER=~/^name/?$ochar:'')))
		.$cgi->td({-class=>'th_lm'.($ORDER=~/^lastmodified/?' th_highlight':''),-onclick=>"window.location.href='$ru?order=lastmodified$dir;$query'"}, $cgi->a({-href=>"$ru?order=lastmodified$dir;$query"},_tl('lastmodified').($ORDER=~/^lastmodified/?$ochar:'')))
		.$cgi->td({-class=>'th_size'.($ORDER=~/^size/i?' th_highlight':''),-onclick=>"window.location.href='$ru?order=size$dir;$query'"},$cgi->a({-href=>"$ru?order=size$dir;$query"},_tl('size').($ORDER=~/^size/?$ochar:'')))
		.($SHOW_PERM? $cgi->td({-class=>'th_perm'.($ORDER=~/^mode/?' th_highlight':''),-onclick=>"window.location.href='$ru?order=mode$dir;$query'"}, $cgi->a({-href=>"$ru?order=mode$dir;$query"},sprintf("%-11s",_tl('permissions').($ORDER=~/^mode/?$ochar:'')))):'')
		.($SHOW_MIME? $cgi->td({-class=>'th_mime'.($ORDER=~/^mime/?' th_highlight':''),-onclick=>"window.location.href='$ru?order=mime$dir;$query'"},'&nbsp;'.$cgi->a({-href=>"$ru?order=mime$dir;$query"},_tl('mimetype').($ORDER=~/^mime/?$ochar:''))):'');
	$list .= $cgi->Tr({-class=>'th', -title=>_tl('clickchangessort')}, $row);
			

	$list.=$cgi->Tr({-class=>'tr_up',-onmouseover=>'addClassName(this,"tr_highlight");',-onmouseout=>'removeClassName(this,"tr_highlight");', -ondblclick=>qq@window.location.href="..";@},
				$cgi->td({-class=>'tc_checkbox'},$cgi->checkbox(-name=>'hidden',-value=>"",-label=>"", -disabled=>'disabled', -style=>'visibility:hidden')) 
			      . $cgi->td({-class=>'tc_fn', -ondblclick=>'return false;', -onmousedown=>'return false'},getfancyfilename(dirname($ru).'/','..','< .. >',dirname($fn)))
			      . $cgi->td('').$cgi->td('').($SHOW_PERM?$cgi->td(''):'').$cgi->td('')
		) unless $fn eq $DOCUMENT_ROOT || $ru eq '/' || $filter;

	my @files = sort cmp_files @{readDir($fn)};

	my $page = $cgi->param('page') ? $cgi->param('page') - 1 : 0;
	my $fullcount = $#files + 1;
	my $showall = $cgi->param('showpage') ? 0 : $cgi->param('showall') || $cgi->cookie('showall') || 0;

	my $pagenav = $filter ? '' : renderPageNavBar($ru, $fullcount, \@files);

	if (!defined $filter && defined $PAGE_LIMIT && !$showall) {
		splice(@files, $PAGE_LIMIT * ($page+1) );
		splice(@files, 0, $PAGE_LIMIT * $page) if $page>0;
	}

	eval qq@/$filter/;@;
	$filter="\Q$filter\E" if ($@);

	my @rowclass = ( 'tr_odd', 'tr_even' );
	my $odd = 0;
	foreach my $filename (@files) {
		$WEB_ID++;
		my $fid = "f$WEB_ID";
		my $full = $fn.$filename;
		my $nru = $ru.uri_escape($filename);
		### +++ AFS fix
		my $isReadable = 1;	
		my $isUnReadable = 0;
		if (!$ENABLE_AFS || checkAFSAccess($full)) {
			$isReadable = $IGNOREFILEPERMISSIONS  || (-d $full && -x $full) || (-f $full && -r $full);
		} else {
			$isReadable = 0;
			$isUnReadable = 1;
		}
		### --- AFS fix

		my $mimetype = '?';
		$mimetype = -d $full ? '<folder>' : getMIMEType($filename) unless $isUnReadable;
		$filename.="/" if !$isUnReadable && -d $full;
		$nru.="/" if !$isUnReadable && -d $full;

		next if $filter && $filename !~/$filter/i;

		my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size, $atime,$mtime,$ctime,$blksize,$blocks) = !$isUnReadable ? stat($full) : (0,0,0,0,0,0,0,0,0,0,0,0,0,0);
		
		push @rowclass,shift @rowclass;

		my $row = "";
		
		my $focus = $filter ? '': qq@addClassNameById("tr_$fid","tr_highlight");@;
		my $blur =  $filter ? '': qq@removeClassNameById("tr_$fid","tr_highlight");@;
		my $onclick= $filter ? '' : qq@return handleRowClick("$fid", event);@;
		my $ignev= qq@return false;@;

		$row.= $cgi->td({-class=>'tc_checkbox'},$cgi->checkbox(-id=>$fid, -onfocus=>$focus,-onblur=>$blur, -onclick=>qq@return handleCheckboxClick(this, "$fid", event);@, -name=>'file', -value=>$filename, -label=>'')) if $ALLOW_FILE_MANAGEMENT;

		my $lmf = strftime(_tl('lastmodifiedformat'), localtime($mtime));
		my $ctf = strftime(_tl('lastmodifiedformat'), localtime($ctime));
		$row.= $cgi->td({-class=>'tc_fn', -onclick=>$onclick, -onmousedown=>$ignev, -ondblclick=>$ignev}, getfancyfilename($nru,$filename,$mimetype, $full, $isUnReadable));
		$row.= $cgi->td({-class=>'tc_lm', -title=>_tl('created').' '.$ctf, -onclick=>$onclick, -onmousedown=>$ignev}, $lmf);
		$row.= $cgi->td({-class=>'tc_size', -title=>sprintf("= %.2fKB = %.2fMB = %.2fGB",$size/1024, $size/1048576, $size/1073741824), -onclick=>$onclick, -onmousedown=>$ignev}, $size);
		$row.= $cgi->td({-class=>'tc_perm', -onclick=>$onclick, -onmousedown=>$ignev}, $cgi->span({-class=>getmodeclass($full,$mode),-title=>sprintf("mode: %04o, uid: %s (%s), gid: %s (%s)",$mode & 07777,"".getpwuid($uid), $uid, "".getgrgid($gid), $gid)},sprintf("%-11s",mode2str($full,$mode)))) if $SHOW_PERM;
		$row.= $cgi->td({-class=>'tc_mime', -onclick=>$onclick, -onmousedown=>$ignev},'&nbsp;'. $cgi->escapeHTML($mimetype)) if $SHOW_MIME;
		$list.=$cgi->Tr({-class=>$rowclass[0],-id=>"tr_$fid", -title=>"$filename", -onmouseover=>$focus,-onmouseout=>$blur, -ondblclick=>$isReadable?qq@window.location.href="$nru";@ : ''}, $row);
		$odd = ! $odd;

		$count++;
		$foldercount++ if !$isUnReadable && -d $full;
		$filecount++ if $isUnReadable || -f $full;
		$filesizes+=$size if $isUnReadable || -f $full;

	}
	###$content.=$cgi->start_multipart_form(-method=>'post', -action=>$ru, -onsubmit=>'return window.confirm("'._tl('confirm').'");') if $ALLOW_FILE_MANAGEMENT;
	$content .= $pagenav;
	$content .= $cgi->start_table({-class=>'filelist'}).$list.$cgi->end_table();
	$content .= $cgi->div({-class=>'folderstats'},sprintf("%s %d, %s %d, %s %d, %s %d Bytes (= %.2f KB = %.2f MB = %.2f GB)", _tl('statfiles'), $filecount, _tl('statfolders'), $foldercount, _tl('statsum'), $count, _tl('statsize'), $filesizes, $filesizes/1024, $filesizes/1048576, $filesizes/1073741824)) if ($SHOW_STAT); 

	$content .= $pagenav;
	return ($content, $count);
}
sub getmodeclass {
	my ($fn, $m) = @_;
	my $class= "";
	$class='groupwriteable' if ($m & 0020) == 0020;
	$class='otherwriteable' if ($m & 0002) == 0002 && !-k $fn;

	return $class;
}
sub mode2str {
	my ($fn,$m) = @_;

	$m = (lstat($fn))[2] if -l $fn;
	my @ret = split(//,'-' x 10);

	$ret[0] = 'd' if -d $fn;
	$ret[0] = 'b' if -b $fn;
	$ret[0] = 'c' if -c $fn;
	$ret[0] = 'l' if -l $fn;

	$ret[1] = 'r' if ($m & 0400) == 0400;
	$ret[2] = 'w' if ($m & 0200) == 0200;
	$ret[3] = 'x' if ($m & 0100) == 0100;
	$ret[3] = 's' if -u $fn;
	
	$ret[4] = 'r' if ($m & 0040) == 0040;
	$ret[5] = 'w' if ($m & 0020) == 0020;
	$ret[6] = 'x' if ($m & 0010) == 0010;
	$ret[6] = 's' if -g $fn;

	$ret[7] = 'r' if ($m & 0004) == 0004;
	$ret[8] = 'w' if ($m & 0002) == 0002;
	$ret[9] = 'x' if ($m & 0001) == 0001;
	$ret[9] = 't' if -k $fn;
	

	return join('',@ret);
}
sub getSearchResult {
	my ($search,$fn,$ru,$isRecursive, $fullcount, $visited) = @_;
	my $content = "";
	$ALLOW_FILE_MANAGEMENT=0;

	## link loop detection:
	my $nfn = File::Spec::Link->full_resolve($fn);
	return $content if $$visited{$nfn};
	$$visited{$nfn}=1;

	my ($list,$count)=getFolderList($fn,$ru,$search);
	$content.=$cgi->hr().$cgi->div({-class=>'resultcount'},$count._tl($count>1?'searchresults':'searchresult')).getQuickNavPath($ru).$list if $count>0 && $isRecursive;
	$$fullcount+=$count;
	if (opendir(my $fh,$fn)) {
		foreach my $filename (sort cmp_files grep {  !/^\.{1,2}$/ } readdir($fh)) {
			local($PATH_TRANSLATED);
			my $full = $fn.$filename;
			next if is_hidden($full);
			my $nru = $ru.uri_escape($filename);
			my $isDir = $ENABLE_AFS ? checkAFSAccess($full) && -d $full : -d $full;
			$full.="/" if $isDir;
			$nru.="/" if $isDir;
			$PATH_TRANSLATED = $full;
			$content.=getSearchResult($search,$full,$nru,1,$fullcount,$visited) if $isDir;
		}
		closedir($fh);
	}
	if (!$isRecursive) {
		if ($$fullcount==0) {
			$content.=$cgi->h2(_tl('searchnothingfound') . "'" .$cgi->escapeHTML($search)."'"._tl('searchgoback').getQuickNavPath($ru));
		} else {
			$content=$cgi->h2("$$fullcount "._tl($$fullcount>1?'searchresultsfor':'searchresultfor')."'".$cgi->escapeHTML($search)."'"._tl('searchgoback').getQuickNavPath($ru)) 
				. ($count>0 ?  $cgi->hr().$cgi->div({-class=>'results'},$count._tl($count>1?'searchresults':'searchresult')).getQuickNavPath($ru).$list : '' )
				. $content;
		}
	}
	return $content;
}
sub getSupportedMethods {
	my ($path) = @_;
	my @methods;
	my @rmethods = ('OPTIONS', 'TRACE', 'GET', 'HEAD', 'PROPFIND', 'PROPPATCH', 'COPY', 'GETLIB');
	my @wmethods = ('POST', 'PUT', 'MKCOL', 'MOVE', 'DELETE');
	push @rmethods, ('LOCK', 'UNLOCK') if $ENABLE_LOCK;
	push @rmethods, 'REPORT' if $ENABLE_ACL || $ENABLE_CALDAV || $ENABLE_CALDAV_SCHEDULE || $ENABLE_CARDDAV;
	push @rmethods, 'SEARCH' if $ENABLE_SEARCH;
	push @wmethods, 'ACL' if $ENABLE_ACL || $ENABLE_CALDAV || $ENABLE_CARDDAV;
	push @wmethods, 'MKCALENDAR' if $ENABLE_CALDAV || $ENABLE_CALDAV_SCHEDULE;
	push @wmethods, 'BIND', 'UNBIND', 'REBIND' if $ENABLE_BIND;
	@methods = @rmethods;
	push @methods, @wmethods if !defined $path || ($IGNOREFILEPERMISSIONS || -w $path);
	return \@methods;
}
sub nonamespace {
	my ($prop) = @_;
	$prop=~s/^{[^}]*}//;
	return $prop;
}
sub logger {
	if (defined $LOGFILE && open(LOG,">>$LOGFILE")) {
		my $ru = $ENV{REDIRECT_REMOTE_USER} || $ENV{REMOET_USR};
		print LOG localtime()." - $<($ru)\@$ENV{REMOTE_ADDR}: @_\n";
		close(LOG);
	} else {
		print STDERR "$0: @_\n";
	}
}
sub _tl {
	return $TRANSLATION{$LANG}{$_[0]} || $TRANSLATION{default}{$_[0]} || $_[0];
}
sub createMsgQuery {
	my ($msg,$msgparam,$errmsg,$errmsgparam,$prefix) = @_;
	$prefix='' unless defined $prefix;
	my $query ="";
	$query.=";${prefix}msg=$msg" if defined $msg;
	$query.=";$msgparam" if defined $msg && $msgparam;
	$query.=";${prefix}errmsg=$errmsg" if defined $errmsg;
	$query.=";$errmsgparam" if defined $errmsg && $errmsgparam;
	return "?t=".time().$query;
}
sub start_html {
	my ($title) = @_;
	my $content ="";
	my $confirmmsg = _tl('confirm');
	$content.="<!DOCTYPE html>\n";
	$content.='<head><title>'.$cgi->escapeHTML($title).'</title>';
	$content.=qq@<meta http-equiv="Content-Type" content="text/html; charset=$CHARSET"/>@;
	$content.=qq@<meta name="author" content="Daniel Rohde"/>@;

	my %tl;
	foreach my $usedtext (('bookmarks','addbookmark','rmbookmark','addbookmarktitle','rmbookmarktitle','rmallbookmarks','sortbookmarkbypath','sortbookmarkbytime','rmuploadfield','rmuploadfieldtitle')) {
		$tl{$usedtext} = _tl($usedtext);
	}
	my $jscript = <<EOS
		<script type="text/javascript">
		var dragElID = null;
		var dragOffset = new Object();
		var dragZIndex = 10;
		var dragOrigHandler = new Object();
		function getEventPos(e) {
			var p = new Object();
			p.x = e.pageX ? e.pageX : e.clientX ? e.clientX : e.offsetX;
			p.y = e.pageY ? e.pageY : e.clientY ? e.clientY : e.offsetY;
			return p;
		}
		function getViewport() {
			var v = new Object();
			v.w = window.innerWidth || (document.documentElement && document.documentElement.clientWidth ? document.documentElement.clientWidth : 0) || document.getElementsByTagName('body')[0].clientWidth;
			v.h = window.innerHeight || (document.documentElement && document.documentElement.clientHeight ? document.documentElement.clientHeight : 0) || document.getElementsByTagName('body')[0].clientHeight;
			return v;
		}
		function getDragZIndex(z) {
			dragZIndex = getCookie('dragZIndex')!="" ? parseInt(getCookie('dragZIndex')) : dragZIndex;
			if (z && z>dragZIndex) dragZIndex = z + 10;
			setCookie('dragZIndex', ++dragZIndex);
			return dragZIndex;
		}
		function handleMouseDrag(event) {
			if (!event) event = window.event;	
			if (dragElID!=null) {
				var el = document.getElementById(dragElID);	
				if (el) {
					var p = getEventPos(event);
					var v = getViewport();
					if (p.x+dragOffset.x < 0 || p.y+dragOffset.y <0 || p.x > v.w ||  p.y > v.h ) return false;
					el.style.left = (p.x+dragOffset.x)+'px';
					el.style.top = (p.y+dragOffset.y)+'px';
					return false;
				}
			}
			return true;
		}
		function handleWindowMove(event, id, down) {
			if (!event) event=window.event;
			var e = document.getElementById(id);
			if (down) {
				if (e && event) {
					dragElID = id;
					var p = getEventPos(event);
					dragOffset.x = ( e.style.left ? parseInt(e.style.left) : 220 ) - p.x;
					dragOffset.y = ( e.style.top ? parseInt(e.style.top) : 120 ) - p.y;
					dragOrigHandler.onmousemove = document.onmousemove;
					document.onmousemove = handleMouseDrag;
					dragOrigHandler.onselectstart = document.onselectstart;
					document.onselectstart = function () { return false; };
					document.body.focus();
					event.ondragstart = function() { return false; };
					if (event.preventDefault) event.preventDefault(); else event.returnValue = false;
					e.style.zIndex = getDragZIndex(e.style.zIndex);
					addClassName(e,'move');
					return false;
				}
			} else {
				dragElID = null;
				document.onmousemove = dragOrigHandler.onmousemove;
				document.onselectstart = dragOrigHandler.onselectstart;
				if (e) { 
					removeClassName(e,'move');
					setCookie(id, 'true/'+e.style.left+'/'+e.style.top+'/'+e.style.zIndex+'/'+ e.collapsed );
				}
			}
			return true;
		}
		function toggleSideBar() {
			var e = document.getElementById('sidebarcontent');
			var ison = 1;
			if (e) {
				ison = !(e.style.display=='none');
				e.style.display = ison ? 'none' : 'block';
				toggleClassNameById('sidebartable','collapsed', ison);
				toggleClassNameById('folderview','full', ison);
				document.getElementById('sidebartogglebutton').innerHTML = ison ? '&gt;' : '&lt;'
			}
			setCookie('sidebar', !ison);
		}
		function showActionView(action) {
			var e = document.getElementById(action);
			if (e) { 
				var v = getViewport();
				var x = e.style.left ? e.style.left : '';
				var y = e.style.top ? e.style.top : '';
				if (x!="") if (parseInt(x) < v.w) e.style.left = x; else e.style.left = (v.w-100)+'px';
				if (y!="") if (parseInt(y) < v.h) e.style.top = y; else e.style.top = (v.h-100)+'px';
				e.style.visibility='visible';
				e.style.zIndex = getDragZIndex(e.style.zIndex);
				addClassNameById(action+'menu', 'active');
				setCookie(action, 'true/'+e.style.left+'/'+e.style.top+'/'+e.style.zIndex+'/'+e.collapsed);
			}
			return false;
		}
		function hideActionView(action) {
			var e = document.getElementById(action);
			if (e) e.style.visibility='hidden';
			removeClassNameById(action+'menu', 'active');
			setCookie(action, 'false/'+e.style.left+'/'+e.style.top+'/'+e.style.zIndex+'/'+e.collapsed);
		}
		function toggleActionView(action) {
			var e = document.getElementById(action);
			if (e && e.style.visibility=='visible') hideActionView(action); else showActionView(action);
		}
		function addUploadField(force) {
			var e = document.getElementById('moreuploads');
			var fu = document.getElementsByName('file_upload');
			if (!force) for (var i = 0; i<fu.length; i++) if (fu[i].value == "") return false;
			e.id = 'moreuploads'+(new Date()).getTime();
			var rmid='fileuploadfield'+(new Date()).getTime();
			e.innerHTML = '<span id="'+rmid+'"><br/>'
					+ document.getElementById("file_upload").innerHTML 
				      + '<a class="rmuploadfield" title="$tl{rmuploadfieldtitle}" href="#" onclick="document.getElementById(\\''+rmid+'\\').innerHTML=\\'\\'; return false;">$tl{rmuploadfield}</a></span>'
					+ '<span id="moreuploads"></span>';
			return false;
		}
		function getBookmarkLocation() {
			return decodeURIComponent(window.location.pathname);
		}
		function addBookmark() {
			var loc = getBookmarkLocation();
			var i = 0;
			while (getCookie('bookmark'+i)!= "-" && getCookie('bookmark'+i) != "" && getCookie('bookmark'+i)!=loc) i++;
			if (getCookie('bookmark'+i) != loc) {
				setCookie('bookmark'+i, loc, 1);
				setCookie('bookmark'+i+'time', (new Date()).getTime(), 1);
				bookmarkcheck();
			}
			return false;
		}
		function rmBookmark() {
			var loc = getBookmarkLocation();
			var i = 0;
			while (getCookie('bookmark'+i) != "" && getCookie('bookmark'+i)!=loc) i++;
			if (getCookie('bookmark'+i) == loc) {
				setCookie('bookmark'+i, "-", 1);
				bookmarkcheck();
			}
		}
		function rmAllBookmarks() {
			var i = 0;
			while (getCookie('bookmark'+i) != "") {
				delCookie('bookmark'+i);
				delCookie('bookmark'+i+'time');
				i++;
			}
			bookmarkcheck();
		}
		function isBookmarked() {
			var loc = getBookmarkLocation();
			var i = 0;
			while (getCookie('bookmark'+i)!="") { 
				if (getCookie('bookmark'+i) == loc) return true; 
				i++; 
			}
			return false;
		}
		function toggleBookmarkButtons() {
			var ib = isBookmarked();
			if (document.getElementById('addbookmark')) {
				document.getElementById('addbookmark').style.display = ib ? 'none' : 'inline';
				document.getElementById('rmbookmark').style.display = ib ? 'inline' : 'none';
			}
		}
		function encodeSpecChars(uri) {
			uri = uri.replace(/%/g,"%25");
			uri = uri.replace(/#/g,"%23");
			uri = uri.replace(/&/g,"%26");
			uri = uri.replace(/;/g,"%3B");
			uri = uri.replace(/ /g,"%20");
			uri = uri.replace(/\\+/g,"%2B");
			uri = uri.replace(/\\?/g,"%3F");
			uri = uri.replace(/\\"/g,"%22");
			return uri;
		}
		function bookmarkChanged(bm) {
			if (bm == '+') addBookmark();
			else if (bm == '-') rmBookmark();
			else if (bm == '--') rmAllBookmarks();
			else if (bm.match(/^time/) || bm.match(/^path/)) { setCookie('bookmarksort',bm); bookmarkcheck(); }
			else changeDir(bm);
			return true;
		}
		function getBookmarkTime(bm) {
			var i=0;
			while (getCookie('bookmark'+i) != "" && getCookie('bookmark'+i) != bm) i++;
			return getCookie('bookmark'+i+'time');
		}
		function bookmarkSort(a,b) {
			var s = getCookie('bookmarksort');
			if (s == "") s='time-desc';
			var f = s.match(/desc/) ? -1 : 1;

			if (s.match(/time/)) {
				a = getBookmarkTime(a);
				b = getBookmarkTime(b);
			}
			return f * (a == b ? 0 : a < b ? -1 : 1);
		}
		function buildBookmarkList() {
			var e = document.getElementById('bookmarks');
			if (!e) return;
			var loc = getBookmarkLocation();
			var b = new Array();
			var content = "";
			var i = 0;
			while (getCookie('bookmark'+i)!="") {
				var c = getCookie('bookmark'+i);
				i++;
				if (c=="-") continue;
				b.push(c);
			}
			b.sort(bookmarkSort);
			var isBookmarked = false;
			for (i=0; i<b.length; i++) {
				var c = b[i];
				var d = (c == loc) ? ' disabled="disabled"' : '';
				if (c == loc) isBookmarked = true;
				var v = c.length <= 25 ? c : c.substr(0,5)+'...'+c.substr(c.length-17);
				content = content + '<option value="'+encodeSpecChars(c)+'" title="'+c+'"'+d+'>' + v + '</option>';
			}
			var bms = getCookie('bookmarksort');
			if (bms == "") bms='time-desc';
			var sbparr,sbpadd,sbtarr,sbtadd;
			sbpadd = ''; sbparr = '';
			sbtadd = ''; sbtarr = ''; 
			if (bms.match(/^path/)) {
				sbpadd = bms.match(/desc/) ? '' : '-desc';
				sbparr = bms.match(/desc/) ? '&darr;' : '&uarr;';
			} else if (bms.match(/^time/)) {
				sbtadd = bms.match(/desc/) ? '' : '-desc';
				sbtarr = bms.match(/desc/) ? '&darr;' : '&uarr;';
			}
			e.innerHTML = '<select class="bookmark" name="bookmark" onchange="return bookmarkChanged(this.options[this.selectedIndex].value);">'
					+'<option class="title" value="">$tl{bookmarks}</option>'
					+(!isBookmarked?'<option class="func" title="$tl{addbookmarktitle}" value="+">$tl{addbookmark}</option>' : '')
					+ (content != "" ?  content : '')
					+(isBookmarked?'<option disabled="disabled"></option><option class="func" title="$tl{rmbookmarktitle}" value="-">$tl{rmbookmark}</option>' : '')
					+ (b.length<=1 ? '' : '<option class="func" value="path'+sbpadd+'">$tl{sortbookmarkbypath} '+sbparr+'</option><option class="func" value="time'+sbtadd+'">$tl{sortbookmarkbytime} '+sbtarr+'</option>')
					+ '<option disabled="disabled"></option><option class="func" title="$tl{rmallbookmarkstitle}" value="--">$tl{rmallbookmarks}</option>' 
					+ '</select>' ;
		}
		function bookmarkcheck() {
			toggleBookmarkButtons();
			buildBookmarkList();
		}
		function changeDir(href) {
			window.location.href=href; 
			return true;
		}
		function showChangeDir(show) {
			document.getElementById('changedir').style.display = show ? 'inline' : 'none';
			document.getElementById('changedirbutton').style.display = show ? 'none' : 'inline';
			document.getElementById('quicknavpath').style.display = show ? 'none' : 'inline';
		}
		function catchEnter(e, id) {
			if (!e) e = window.event;
			if (e.keyCode == 13) {
				var el = document.getElementById(id);
				if (el) el.click();
				return false;
			}
			return true;
		}
		function handleRowClick(id,e) {
			if (!e) e = window.event;
			var el=document.getElementById(id); 
			if (el) { 
				shiftsel.shifted=e.shiftKey; 
				el.click(); 
			}; 
			return true;
		}
		function encodeRegExp(v) { return v.replace(/([\\*\\?\\+\\\$\\^\\{\\}\\[\\]\\(\\)\\\\])/g,'\\\\\$1'); }
		function handleNameFilter(el,ev) {
			if (!ev) ev=window.event;
			if (ev && el && ev.keyCode != 13) {
				if (el.size>5 && el.value.length<el.size) el.size = 5;
				if (el.size<el.value.length) el.size = el.value.length;
				var regex;
				try { 
					regex = new RegExp(el.value, 'gi');
				} catch (exc) {
					regex = new RegExp(encodeRegExp(el.value), 'gi');
				}
				var matchcount = 0;
				var i = 1;
				var e;
				while ((e = document.getElementById('f'+i))) {
					var m = e.value.match(regex);
					if (m)  matchcount++;
					toggleClassNameById('tr_f'+i, 'hidden', !m);
					i++;
				}
				var me = document.getElementsByName('namefiltermatches');
				for (i=0; i<me.length; i++) me[i].value=matchcount;
				me = document.getElementsByName('namefilter');
				for (i=0; i<me.length; i++) {
					if (el!=me[i]) {
						me[i].value=el.value;
						if (me[i].size>5 && el.value.length<me[i].size) me[i].size = 5;
						if (me[i].size<el.value.length) me[i].size = el.value.length;
					}
				}
				return ev.keyCode!=13;
			}
			return false;
		}
		var shiftsel = new Object();
		function handleCheckboxClick(o,id,e) {
			if (!e) e = window.event;
			var nid = parseInt(id.substr(1));
			var nlid = shiftsel && shiftsel.lastId ? parseInt(shiftsel.lastId.substr(1)) : nid;
			if ((e.shiftKey||shiftsel.shifted) && shiftsel.lastId && nid != nlid ) {
				var start = nid > nlid ? nlid : nid;
				var end = nid > nlid ? nid : nlid;
				shiftsel.shifted=false;
				for (var i = start + 1; i < end ; i++) {
					var el = document.getElementById('f'+i);
					if (el) { 	
						if (document.getElementById('tr_f'+i).className.match('hidden')) continue;
						el.checked=!el.checked; 
						toggleClassNameById("tr_f"+i, "tr_selected", el.checked); 
					}
				}
			}
			shiftsel.lastId = id;
			if (document.getElementById('tr_'+id).className.match('hidden')) return false;
			toggleFileFolderActions(); 
			toggleClassNameById("tr_"+id, "tr_selected", o.checked); 
			return true;
		}
		function addClassName(e, cn) {
			if (e && e.className) {
				if (e.className.indexOf(" "+cn)>-1) return;
				e.className = e.className + " " + cn;
			}
		}
		function addClassNameById(id, cn) { addClassName(document.getElementById(id), cn); }
		function removeClassName(e,cn) {
			if (e && e.className) {
				var a = e.className.split(' ');
				for (var i=0; i<a.length; i++) {
					if (a[i] == cn) a.splice(i,1);
				}
				e.className = a.join(' ');
			}
		}
		function removeClassNameById(id, cn) { removeClassName(document.getElementById(id),cn); }
		function toggleClassName(e, cn, s) { if (s) addClassName(e, cn); else removeClassName(e,cn); }
		function toggleClassNameById(id, cn, s) { toggleClassName(document.getElementById(id), cn, s); }
		function toggleFileFolderActions() {
			var disabled = true;
			var ea = document.getElementsByName("file"); 
			for (var i=0; i<ea.length; i++) {
				if (ea[i].checked) { disabled=false; break; }
			}
			var names = new Array('copy','cut','delete','newname','rename','zip','changeperm');
			for (var i=0; i<names.length; i++) {
				ea = document.getElementsByName(names[i]);
				if (ea) for (var j=0; j<ea.length; j++) ea[j].disabled = disabled;
			}
		}

		function toggleAllFiles(tb) {
			tb.checked=false; 
			var ea = document.getElementsByName("file"); 
			for (var i=0; i<ea.length; i++) ea[i].click();
		}
		function setCookie(name,value,e) { 
			var expires;
			var date = new Date();
			date.setTime(date.getTime() + 315360000000);
			expires = date.toGMTString();
			document.cookie = name + '=' + escape(value) + ';'+ (e?'expires='+expires+'; ':'') +' path=/; secure;'; 
		}
		function delCookie(name) {
			var date = new Date();
			date.setTime(date.getTime() - 1000000);
			document.cookie = name + '=' + escape('-') + '; expires='+date.toGMTString()+'; path=/; secure;';
		}
		function getCookie(name) {
			if (document.cookie.length>0) {
				var c_start=document.cookie.indexOf(name + "=");
				if (c_start!=-1) {
					c_start=c_start + name.length+1;
					var c_end=document.cookie.indexOf(";",c_start);
					if (c_end==-1) c_end=document.cookie.length;
					return unescape(document.cookie.substring(c_start,c_end));
				}
			}
			return "";
		}
		function clpcheck() { 
			if (document.getElementById('paste')) {
				document.getElementById('paste').disabled=(getCookie('clpfiles') == '' || '$REQUEST_URI' == getCookie('clpuri')); 
				if (getCookie('clpfiles')!='') 
					document.getElementById('paste').title=getCookie('clpaction')+' '
							+getCookie('clpuri')+': '+getCookie('clpfiles').split("\@/\@").join(", ");
			}
		}
		function clpaction(action) {
			var sel = new Array();
			var files = document.getElementsByName('file');
			for (var i=0; i<files.length; i++) { 
				removeClassNameById("tr_"+files[i].id, "tr_cut");
				removeClassNameById("tr_"+files[i].id, "tr_copy");
				if (files[i].checked === true) { 
					files[i].click(); 
					sel.push(files[i].value); 
					addClassNameById("tr_"+files[i].id, "tr_"+action);
				}
			}
			if (action == 'paste') {
				var clpform = document.getElementById('clpform');
				clpform.action.value=getCookie('clpaction');
				clpform.srcuri.value=getCookie('clpuri');
				clpform.files.value=getCookie('clpfiles');
				if (clpform.files.value!='' && window.confirm('$confirmmsg')) {
					document.getElementById('paste').disabled=true;
					if (clpform.action.value != "copy") {
						setCookie('clpuri','');
						setCookie('clpaction','');
						setCookie('clpfiles','');
					}
					clpform.submit();
				}
			} else {
				setCookie( 'clpuri','$REQUEST_URI');
				setCookie( 'clpaction', action);
				setCookie( 'clpfiles', sel.join('\@/\@'));
				if (document.getElementById('paste') && sel.length>0) 
					document.getElementById('paste').title=action+' $REQUEST_URI: '+sel.join(', ');
				clpcheck();
			}
		}
		function toggle(name,cshow,chide) {
			var button = document.getElementById('togglebutton'+name);
			var div = document.getElementById('toggle'+name);
			if (!cshow) cshow = '+';
			if (!chide) chide = '-';
			div.style.display=div.style.display=='none'?'block':'none';
			button.innerHTML = div.style.display=='none'?cshow:chide; 
			setCookie('toggle'+name, div.style.display);
		}
		function selcheck() {
			var i = 1;
			var el;
			while ((el = document.getElementById('f'+i))) {
				if (el.checked) toggleClassNameById("tr_f"+i, "tr_selected", el.checked); 
				i++;
			}
		}
		function check() {
			selcheck();
			clpcheck();
			bookmarkcheck();
			hideMsg();
		}
		function fadeOut(id) {
			var obj = document.getElementById(id);
			if (!obj.fadeOutInterval) {
				obj.fadeOutInterval = window.setInterval('fadeOut("'+id+'");', 50);
				obj.fadeOutOpacity = 0.95;
				obj.style.opacity = obj.fadeOutOpacity;
				obj.style.filter = "Alpha(opacity="+(obj.fadeOutOpacity*100)+")";
				obj.fadeOutTop = 10;
				obj.style.top = obj.fadeOutTop + "px";
			}
			if (obj.fadeOutOpacity <= 0) {
				window.clearInterval(obj.fadeOutInterval);
				obj.style.display="none";
			} else  {
				if (obj.fadeOutOpacity > 0) obj.fadeOutOpacity -= 0.1;
				if (obj.fadeOutOpacity < 0) obj.fadeOutOpacity = 0;
				obj.style.opacity = obj.fadeOutOpacity; 
				obj.style.filter = "Alpha(opacity="+(obj.fadeOutOpacity*100)+")"; 
				obj.fadeOutTop -= 6;
				obj.style.top =  obj.fadeOutTop + "px";
			}
		}
		function hideMsg() { if (document.getElementById("msg")) setTimeout("fadeOut('msg');", 60000); }
		function toggleCollapseAction(action, event) {
			if (!event) event=window.event;
			var e = document.getElementById('v_'+action);
			if (!e) return true;
			var shown = !e.className.match(/collapsed/);
			e.collapsed = shown;
			toggleClassName(e,'collapsed', shown);
			toggleClassNameById(action, 'collapsed', shown);
			e = document.getElementById(action);
			e.collapsed = shown;
			setCookie(action, 'true/'+e.style.left+'/'+e.style.top+'/'+e.style.zIndex+'/'+e.collapsed);
			if (event.preventDefault) event.preventDefault(); else event.returnValue = false;
			return false;
		}
		</script>
EOS
;
	minify($jscript);
	$content.=$jscript;
	$content.=qq@<link rel="search" type="application/opensearchdescription+xml" title="WebDAV CGI filename search" href="$REQUEST_URI?action=opensearch"/>@ if $ALLOW_SEARCH;
	$content.=qq@<link rel="alternate" href="$REQUEST_URI?action=mediarss" type="application/rss+xml" title="" id="gallery"/>@ if $ENABLE_THUMBNAIL;
	minify($CSS);
	$content.=qq@<style>$CSS</style>@ if defined $CSS;
	$content.=qq@<link href="$CSSURI" rel="stylesheet" type="text/css"/>@ if defined $CSSURI;
	$content.=$HTMLHEAD if defined $HTMLHEAD;
	$content.=qq@</head><body onload="check()">@;
	return $content;
}
sub minify {
	return $_[0] unless defined $_[0];
	$_[0]=~s/\/{2,}.*$//g;
	$_[0]=~s/\/\*.*?\*\///sg;
	$_[0]=~s/[\r\n]/ /g;
	$_[0]=~s/\s{2,}/ /g;
	return $_[0];
}
sub renderNameFilterForm() {
		return $ENABLE_NAMEFILTER && !$cgi->param('search') ? 
			$cgi->div({-class=>'namefilter', -title=>_tl('namefiltertooltip')}, _tl('namefilter').
				$cgi->input({-size=>5, -value=>$cgi->param('namefilter')||'',-name=>'namefilter', 
						-onkeypress=>'javascript:return catchEnter(event,"undef")', 
						-onkeyup=>'javascript:return handleNameFilter(this,event);'})
				.' '
				.$cgi->span({-class=>'namefiltermatches'}, _tl('namefiltermatches').$cgi->input({-size=>2,-value=>'-',-readonly=>'readonly',-name=>'namefiltermatches',-class=>'namefiltermatches'}))
			) 
			: '';
}
sub renderAFSACLManager {
	my @entries;
	my $pt = $PATH_TRANSLATED;
	$pt=~s/(["\$\\])/\\$1/g; 
	open(my $afs, "$AFS_FSCMD listacl \"$pt\" |") or die("cannot execute $AFS_FSCMD list \"$PATH_TRANSLATED\"");
	my $line;
	$line = <$afs>; # skip first line
	my $ispositive = 1;
	while ($line = <$afs>) {
		chomp($line);
		$line=~s/^\s+//;
		next if $line =~ /^\s*$/; # skip empty lines
		if ($line=~/^(Normal|Negative) rights:/) {
			$ispositive = 0 if $line=~/^Negative/;
		} else {
			my ($user, $right) = split(/\s+/,$line);
			push @entries, { user=>$user, right=>$right, ispositive=>$ispositive };
		}
		
	}
	close($afs);
	sub _renderACLData {
		my ($entries, $mustpositive) = @_;
		my $s = $mustpositive ? 'p' : 'n';
		my $content="";
		$content.=$cgi->Tr(
			$cgi->th(_tl( $mustpositive?'afsnormalrights':'afsnegativerights'))
			.$cgi->th(_tl('afslookup')).$cgi->th(_tl('afsread')).$cgi->th(_tl('afswrite')).$cgi->th(_tl('afsinsert'))
			.$cgi->th(_tl('afsdelete')).$cgi->th(_tl('afslock')).$cgi->th(_tl('afsadmin'))
		);
		foreach my $entry (sort { $$a{user} cmp $$b{user} || $$b{right} cmp $$a{right} } @{$entries}) {
				my ($user, $right, $ispositive) = ( $$entry{user}, $$entry{right}, $$entry{ispositive} );
				next if $mustpositive != $ispositive;
				my $prohibit = !$ALLOW_AFSACLCHANGES || grep(/^\Q$user\E$/, @PROHIBIT_AFS_ACL_CHANGES_FOR) >0;
				my $row = $cgi->td({-title=>"$user $right"}, $user . ($prohibit ? $cgi->hidden({ -name=>"u$s\[$user\]", -value=>$right}):'') );
				foreach my $r (split(//,'lrwidka')) {
					my %param = ( name=>"u$s\[$user\]", label=>'', value=>$r);
					$param{checked} = 'checked' if $right=~/$r/;
					$param{disabled} = 'disabled' if $prohibit;
					$row .= $cgi->td({-class=>'afsaclcell'},$cgi->checkbox(\%param));
				};
				$content.=$cgi->Tr($row);
		}
		if ($ALLOW_AFSACLCHANGES) {
			my $row = $cgi->td($cgi->input({-type=>'text', -size=>15, -name=>"u${s}_add"}));
			foreach my $r ( split(//, 'lrwidka')) {
				$row .= $cgi->td({-class=>'afsaclcell'}, $cgi->checkbox({-name=>"u${s}", -value=>$r, -label=>''}));
			}
			$content.=$cgi->Tr($row);
		}
		return $content;
	}
	my $content = $cgi->a({-id=>'afsaclmanagerpos'},"").renderMessage('acl')
			.$cgi->div(sprintf(_tl('afsaclscurrentfolder'),$PATH_TRANSLATED, $REQUEST_URI))
			.$cgi->start_table({-class=>'afsacltable'});
	$content .= _renderACLData(\@entries, 1);
	$content .= _renderACLData(\@entries, 0);
	$content .= $cgi->Tr($cgi->td({-class=>'afssavebutton',-colspan=>8}, $cgi->submit({-name=>'saveafsacl', -value=>_tl('afssaveacl')}))) if $ALLOW_AFSACLCHANGES;
	$content .= $cgi->end_table();
	$content .= $cgi->div({-class=>'afsaclhelp'}, _tl('afsaclhelp'));
	return $content;
}
sub isValidAFSGroupName { return $_[0] =~ /^[a-z0-9\_\@\:]+$/i; }
sub isValidAFSUserName { return $_[0] =~ /^[a-z0-9\_\@]+$/i; }
sub isValidAFSACL { return $_[0] =~ /^[rlidwka]+$/; }
sub doAFSSaveACL() {
	my ($redirtarget) = @_;
	my ($pacls, $nacls) = ( "","");
	my ($msg,$errmsg,$msgparam);
	foreach my $param ($cgi->param()) {
		my $value = join("", $cgi->param($param));
		if ($param eq "up") {
			$pacls .= sprintf("\"%s\" \"%s\" ", $cgi->param("up_add"), $value) 
				if (isValidAFSUserName($cgi->param("up_add")) || isValidAFSGroupName($cgi->param("up_add"))) && isValidAFSACL($value);
		} elsif ($param eq "un") {
			$nacls .= sprintf("\"%s\" \"%s\" ", $cgi->param("un_add"), $value) 
				if (isValidAFSUserName($cgi->param("un_add")) || isValidAFSGroupName($cgi->param("un_add"))) && isValidAFSACL($value);
		} elsif ($param =~ /^up\[([^\]]+)\]$/) {
			$pacls .= sprintf("\"%s\" \"%s\" ", $1, $value)
				if (isValidAFSUserName($1) || isValidAFSGroupName($1)) && isValidAFSACL($value);
		} elsif ($param =~ /^un\[([^\]]+)\]$/) {
			$nacls .= sprintf("\"%s\" \"%s\" ", $1, $value)
				if (isValidAFSUserName($1) || isValidAFSGroupName($1)) && isValidAFSACL($value);
		}
	}
	my $output = "";
	if ($pacls ne "") {
		my $cmd;
		my $fn = $PATH_TRANSLATED;
		$fn=~s/(["\$\\])/\\$1/g; 
		$cmd= qq@$AFS_FSCMD setacl -dir \"$fn\" -acl $pacls -clear 2>&1@;
		debug($cmd);
		$output = qx@$cmd@;
		if ($nacls ne "") {
			$cmd = qq@$AFS_FSCMD setacl -dir \"$fn\" -acl $nacls -negative 2>&1@;
			debug($cmd);
			$output .= qx@$cmd@;
		} 
		debug("output of $AFS_FSCMD = $output");
	} else { $output = _tl('empty normal rights'); }
	if ($output eq "") {
		$msg='afsaclchanged';
		$msgparam='p1='.$cgi->escape($pacls).';p2='.$cgi->escape($nacls);
	} else {
		$errmsg='afsaclnotchanged';
		$msgparam='p1='.$cgi->escape($output);
	}
	print $cgi->redirect($redirtarget.createMsgQuery($msg, $msgparam, $errmsg, $msgparam,'acl').'#afsaclmanagerpos');
}
sub checkAFSAccess {
	my ($f) =@_;
	my $ret = 0;

	return $CACHE{checkAFSAccess}{$f} if exists $CACHE{checkAFSAccess}{$f};

	$ret = lstat($f) ? 1 : 0;

	#$f=~s/([\'\\])/\\$1/g;
	#system("$AFS_FSCMD getcalleraccess '$f'>/dev/null 2>&1");
	#$ret = $?>>8 == 0 ? 1 : 0;

	$CACHE{checkAFSAccess}{$f} = $ret;

	return $ret;
}
sub renderAFSGroupManager {
	my $ru = $ENV{REDIRECT_REMOTE_USER} || $ENV{REMOTE_USER};
	my $grp =  $cgi->param('afsgrp') || "";
	my @usrs = $cgi->param('afsusrs') || ( );

	my @groups = split(/\r?\n\s*?/, qx@$AFS_PTSCMD listowned $ru@);
	shift @groups; # remove comment
	s/^\s+//g foreach (@groups);
	s/[\s\r\n]+$//g foreach (@groups);
	@groups = sort @groups;

	my $hgc = "";
	$hgc .= sprintf(_tl('afsgroups'), $ru);
	my $gc = "";
	$gc.= $cgi->scrolling_list(-name=>'afsgrp', -values=>\@groups, -size=>5, -default=>[ $grp ], -ondblclick=>'document.getElementById("afschgrp").click();' ) if $#groups>-1;

	my $huc ="";
	my $uc = "";
	my $nusr = "";
	my $dusr = "";
	if ($grp ne "") {
		my @users = split(/\r?\n/, qx@$AFS_PTSCMD members $grp@);
		shift @users; # remove comment
		s/^\s+//g foreach (@users);
		@users = sort @users;
		chomp @users;

		$huc .= sprintf(_tl('afsgrpusers'), $grp) . $cgi->hidden({-name=>'afsselgrp', -value=>$grp});

		$uc.= $cgi->scrolling_list(-name=>'afsusr', -values=>\@users, -size=>5, -multiple=>'multiple', -defaults=>\@usrs) if $#users>-1;

		$nusr = $cgi->input({-name=>'afsaddusers', size=>20, -onkeypress=>'return catchEnter(event,"afsaddusr");'}).$cgi->submit({-id=>'afsaddusr', -name=>'afsaddusr', -value=>_tl('afsadduser'),-onclick=>'return window.confirm("'._tl('afsconfirmadduser').'");'}) if $ALLOW_AFSGROUPCHANGES;

		$dusr = $cgi->submit({-name=>'afsremoveusr', -value=>_tl('afsremoveuser'), -onclick=>'return window.confirm("'._tl('afsconfirmremoveuser').'");'}) if $ALLOW_AFSGROUPCHANGES && $#users > -1;

	}

	my $cb = "";
	$cb .= $cgi->submit({-id=>'afschgrp',-name=>'afschgrp',-value=>_tl('afschangegroup')}) if $#groups>-1;

	my $dgrp ="";
	$dgrp .= $cgi->submit({-name=>'afsdeletegrp', -value=>_tl('afsdeletegroup'),-onclick=>'return window.confirm("'._tl('afsconfirmdeletegrp').'");'}) if $ALLOW_AFSGROUPCHANGES && $#groups>-1;

	my $ngrp ="";
	$ngrp .= $cgi->input({-name=>'afsnewgrp', -size=>20, -onfocus=>'if (this.value == "") { this.value="'.$ru.':"; this.select();}', -onblur=>'if (this.value == "'.$ru.':") this.value="";', -onkeypress=>'return catchEnter(event,"afscreatenewgrp");'}).$cgi->submit({-id=>'afscreatenewgrp', -name=>'afscreatenewgrp', -value=>_tl('afscreatenewgroup'), -onclick=>'return window.confirm("'._tl('afsconfirmcreategrp').'");'}) if $ALLOW_AFSGROUPCHANGES;

	my $rgrp = "";
	$rgrp .= $cgi->input({-name=>'afsnewgrpname',-size=>20, -value=>$cgi->param('afsnewgrpname')||'',-onfocus=>'if (this.value == "") { this.value="'.$ru.':"; this.select();}', -onblur=>'if (this.value == "'.$ru.':") this.value="";', -onkeypress=>'return catchEnter(event,"afsrenamegrp");'}).$cgi->submit({-id=>'afsrenamegrp', -name=>'afsrenamegrp', -value=>_tl('afsrenamegroup'), -onclick=>'return window.confirm("'._tl('afsconfirmrenamegrp').'");'}) if $ALLOW_AFSGROUPCHANGES && $#groups > -1;

	return $cgi->a({-id=>'afsgroupmanagerpos'},"").renderMessage('afs')
		##.$cgi->start_form({-name=>'afsgroupmanagerform', -method=>'post'})
		.$cgi->start_table({-class=>'afsgroupmanager'})
		.$cgi->Tr($cgi->th($hgc).$cgi->th($huc))
		.$cgi->Tr($cgi->td($gc.$cgi->br().$cb.$cgi->br().$dgrp.$cgi->br().$ngrp.$cgi->br().$rgrp)
				.$cgi->td($uc.$cgi->br().$dusr.$cgi->br().$nusr))
		.$cgi->end_table()
		.$cgi->div({-class=>'afsgrouphelp'}, _tl('afsgrouphelp'))
		##.$cgi->end_form();
		;
}
sub doAFSGroupActions {
	my ($redirtarget ) = @_;
	my ($msg, $errmsg, $msgparam);
	my $grp = $cgi->param('afsgrp') || '';
	my $output;
	if ($cgi->param('afschgrp')) {
		if ($cgi->param('afsgrp')) { 
			$msg = '';
			$msgparam='afsgrp='.$cgi->escape($cgi->param('afsgrp')) if isValidAFSGroupName($cgi->param('afsgrp'));
		} else {
			$errmsg = 'afsgrpnothingsel';
		}
	} elsif (!$ALLOW_AFSGROUPCHANGES)  {
		## do nothing
	} elsif ($cgi->param('afsdeletegrp')) {
		if (isValidAFSGroupName($grp)) {
			$output = qx@$AFS_PTSCMD delete "$grp" 2>&1@;
			if ($output eq "") {
				$msg = 'afsgrpdeleted';
				$msgparam='p1='.$cgi->escape($grp);
			} else {
				$errmsg = 'afsgrpdeletefailed';
				$msgparam='afsgroup='.$cgi->escape($grp).';p1='.$cgi->escape($grp).';p2='.$cgi->escape($output);
			}
		} else {
			$errmsg = 'afsgrpnothingsel';
		}
	} elsif ($cgi->param('afscreatenewgrp')) {
		$grp = $cgi->param('afsnewgrp');
		$grp=~s/^\s+//; $grp=~s/\s+$//;
		if (isValidAFSGroupName($grp)) {
			$output = qx@$AFS_PTSCMD creategroup $grp 2>&1@;
			if ($output eq "" || $output =~ /^group \Q$grp\E has id/i) {
				$msg = 'afsgrpcreated';
				$msgparam='afsgrp='.$cgi->escape($grp).';p1='.$cgi->escape($grp);
			} else {
				$errmsg = 'afsgrpcreatefailed';
				$msgparam='p1='.$cgi->escape($grp).';p2='.$cgi->escape($output);
			}
		} else {
			$errmsg = 'afsgrpnogroupnamegiven';
		}
	} elsif ($cgi->param('afsrenamegrp')) {
		my $ngrp = $cgi->param('afsnewgrpname') || '';
		if (isValidAFSGroupName($grp)) {
			if (isValidAFSGroupName($ngrp)) {
				$output = qx@$AFS_PTSCMD rename -oldname \"$grp\" -newname \"$ngrp\" 2>&1@;
				if ($output eq "") {
					$msg = 'afsgrprenamed';
					$msgparam = 'afsgrp='.$cgi->escape($ngrp).';p1='.$cgi->escape($grp).';p2='.$cgi->escape($ngrp);
				} else {
					$errmsg = 'afsgrprenamefailed';
					$msgparam = 'afsgrp='.$cgi->escape($grp).';afsnewgrpname='.$cgi->escape($ngrp).';p1='.$cgi->escape($grp).';p2='.$cgi->escape($ngrp).';p3='.$cgi->escape($output);
				}
			} else {
				$errmsg = 'afsnonewgroupnamegiven';
				$msgparam='afsgrp='.$cgi->escape($grp).';p1='.$cgi->escape($grp);
			}
		} else {
			$errmsg = 'afsgrpnothingsel';
			$msgparam=';afsnewgrpname='.$cgi->escape($ngrp);
		}
	} elsif ($cgi->param('afsremoveusr')) {
		$grp = $cgi->param('afsselgrp') || '';
		if (isValidAFSGroupName($grp)) {
			my @users;
			foreach ($cgi->param('afsusr')) { push @users,$_ if isValidAFSUserName($_)||isValidAFSGroupName($_); }
			if ($#users >-1) {
				my $userstxt = '"'.join('" "', @users).'"';
				$output = qx@$AFS_PTSCMD removeuser -user $userstxt -group \"$grp\" 2>&1@;
				if ($output eq "") {
					$msg = 'afsuserremoved';
					$msgparam = 'afsgrp='.$cgi->escape($grp).';p1='.$cgi->escape(join(', ',@users)).';p2='.$cgi->escape($grp);
				} else {
					$errmsg = 'afsusrremovefailed';
					$msgparam = 'afsgrp='.$cgi->escape($grp).';p1='.$cgi->escape(join(', ',@users)).';p2='.$cgi->escape($grp).';p3='.$cgi->escape($output);
				}
			} else {
				$errmsg = 'afsusrnothingsel';
				$msgparam='afsgrp='.$cgi->escape($grp);
			}
		} else {
			$errmsg = 'afsgrpnothingsel';
		}
	} elsif ($cgi->param('afsaddusr')) {
		$grp = $cgi->param('afsselgrp') || '';
		if (isValidAFSGroupName($grp)) {
			my @users;
			foreach (split(/\s+/, $cgi->param('afsaddusers'))) { push @users,$_ if isValidAFSUserName($_)||isValidAFSGroupName($_); }
			if ($#users > -1) {
				my $userstxt = '"'.join('" "', @users).'"';
				$output = qx@$AFS_PTSCMD adduser -user $userstxt -group "$grp" 2>&1@;
				if ($output eq "") {
					$msg = 'afsuseradded';
					$msgparam = 'afsgrp='.$cgi->escape($grp).';p1='.$cgi->escape(join(', ',@users)).';p2='.$cgi->escape($grp);
				} else {
					$errmsg = 'afsadduserfailed';
					$msgparam = 'afsgrp='.$cgi->escape($grp).';afsaddusers='.$cgi->escape($cgi->param('afsaddusers')).';p1='.$cgi->escape($cgi->param('afsaddusers')).';p2='.$cgi->escape($grp).';p3='.$cgi->escape($output);
				}

			} else {
				$errmsg = 'afsnousersgiven';
				$msgparam='afsgrp='.$cgi->escape($grp).';p1='.$cgi->escape($grp);
			}
		} else {
			$errmsg = 'afsgrpnothingsel';
		}
	}

	print $cgi->redirect($redirtarget.createMsgQuery($msg, $msgparam, $errmsg, $msgparam, 'afs').'#afsgroupmanagerpos');
}
sub renderMessage {
	my ($prefix) = @_;
	$prefix='' unless defined $prefix;
	my $content = "";
	if ( my $msg = $cgi->param($prefix.'errmsg') || $cgi->param($prefix.'msg')) {
		my @params = ();
		my $p=1;
		while (defined $cgi->param("p$p")) {
			push @params, $cgi->escapeHTML($cgi->param("p$p"));
			$p++;
		}
		$content .= $cgi->div({-id=>'msg',-onclick=>'javascript:fadeOut("msg");', -class=>$cgi->param($prefix.'errmsg')?'errormsg':'infomsg'}, sprintf(_tl('msg_'.$msg),@params));
	}
	return $content;
}
sub hasThumbSupport {
	my ($mime) = @_;
	return 1 if $mime =~ /^image\// || $mime =~ /^text\/plain/ || ($ENABLE_THUMBNAIL_PDFPS && $mime =~ /^application\/(pdf|ps)$/);
	return 0;
}
sub readMIMETypes {
	my ($mimefile) = @_;
	if (open(my $f, "<$mimefile")) {
		while (my $e = <$f>) {
			next if $e =~ /^\s*(\#.*)?$/;
			my ($type,$suffixes) = split(/\s+/, $e, 2);
			$MIMETYPES{$suffixes}=$type;
		}
		close($f);
	} else {
		warn "Cannot open $mimefile";
	}
	$MIMETYPES{default}='application/octet-stream';
}
sub debug {
	print STDERR "$0: @_\n" if $DEBUG;
}
