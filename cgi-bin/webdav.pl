#!/usr/bin/perl
###!/usr/bin/speedy --  -r20 -M5
#########################################################################
# (C) ZE CMS, Humboldt-Universitaet zu Berlin
# Written 2010-2011 by Daniel Rohde <d.rohde@cms.hu-berlin.de>
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
# VERSION 0.7.0 RC2
# REQUIREMENTS:
#    - see http://webdavcgi.sf.net/doc.html#requirements
# INSTALLATION:
#    - see http://webdavcgi.sf.net/doc.html#installation
# CHANGES:
#    - see CHANGELOG
# TODO:
#    - see TODO
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
            @DB_SCHEMA $CREATE_DB %TRANSLATION $LANG $MAXLASTMODIFIEDSIZE 
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
            $ENABLE_SIDEBAR $VIEW $ENABLE_PROPERTIES_VIEWER $SHOW_CURRENT_FOLDER $SHOW_CURRENT_FOLDER_ROOTONLY $SHOW_PARENT_FOLDER
            $SHOW_FILE_ACTIONS $REDIRECT_TO $INSTALL_BASE $ENABLE_DAVMOUNT @EDITABLEFILES $ALLOW_EDIT $ENABLE_SYSINFO $VHTDOCS $ENABLE_COMPRESSION
	    @UNSELECTABLE_FOLDERS
); 
#########################################################################
############  S E T U P #################################################

## -- ENV{PATH} 
##  search PATH for binaries 
$ENV{PATH}="/bin:/usr/bin:/sbin/:/usr/local/bin:/usr/sbin";

## -- INSTALL_BASE
## folder path to the webdav.conf, .css, .js, and. msg files for the Web interface
## (don't forget the trailing slash)
## DEFAULT: $INSTALL_BASE='' # use webdav.pl script path
$INSTALL_BASE=$ENV{INSTALL_BASE} || '';

## -- CONFIGFILE
## you can overwrite all variables from this setup section with a config file
## (simply copy the complete setup section (without 'use vars ...') or single options to your config file)
## EXAMPLE: CONFIGFILE = './webdav.conf';
$CONFIGFILE = $ENV{REDIRECT_WEBDAVCONF} || $ENV{WEBDAVCONF} || 'webdav.conf';

## -- VIRTUAL_BASE
## only neccassary if you use redirects or rewrites from a VIRTUAL_BASE to the DOCUMENT_ROOT;
## regular expressions are allowed
## EXAMPLE: $VIRTUAL_BASE = '/';
$VIRTUAL_BASE = '/';

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
## enables/disables Web interface
## if disabled you get a 404 error for a GET request on a folder
## DEFAULT: $FANCYINDEXING = 1;
$FANCYINDEXING = 1;

## -- ENABLE_COMPRESSION
## enables/disables gzip content encoding for the Web interface
## EXAMPLE: $ENABLE_COMPRESSION = 1;
$ENABLE_COMPRESSION = 1;

## -- VHTDOCS
## virtual path name to "${INSTALL_BASE}htdocs",
## e.g. access to ${VHTDOCS}icons/test.png delivers ${INSTALL_BASE}htdocs${VHTDOCS}icons/test.png
## note: all delivered data from htdocs expires in one week
## (don't forget the trailing slash)
## EXAMPLE: $VHTDOCS='/_webdavcgi_/';
$VHTDOCS='_webdavcgi_/';

## -- MAXFILENAMESIZE 
## Web interface: width of filename column
$MAXFILENAMESIZE = 40;

## -- MAXLASTMODIFIEDSIZE
## Web interface: width of last modified column
$MAXLASTMODIFIEDSIZE = 20;

## -- ICONS
## for fancy indexing 
## ("$VHTDOCS" will be replaced by "$VIRTUAL_HOST$VHTDOCS")
%ICONS = (
	'< .. >' => '${VHTDOCS}icons/back.gif',
	'<folder>' => '${VHTDOCS}icons/folder.gif',
	'text/plain' => '${VHTDOCS}icons/text.gif', 'text/html' => '${VHTDOCS}icons/text.gif',
	'application/zip'=> '${VHTDOCS}icons/compressed.gif', 'application/x-gzip'=>'${VHTDOCS}icons/compressed.gif',
	'image/gif'=>'${VHTDOCS}icons/image2.gif', 'image/jpg'=>'${VHTDOCS}icons/image2.gif',
	'image/png'=>'${VHTDOCS}icons/image2.gif', 
	'application/pdf'=>'${VHTDOCS}icons/pdf.gif', 'application/ps' =>'${VHTDOCS}icons/ps.gif',
	'application/msword' => '${VHTDOCS}icons/text.gif',
	'application/vnd.ms-powerpoint' => '${VHTDOCS}icons/world2.gif',
	'application/vnd.ms-excel' => '${VHTDOCS}icons/quill.gif',
	'application/x-dvi'=>'${VHTDOCS}icons/dvi.gif', 'text/x-chdr' =>'${VHTDOCS}icons/c.gif', 'text/x-csrc'=>'${VHTDOCS}icons/c.gif',
	'video/x-msvideo'=>'${VHTDOCS}icons/movie.gif', 'video/x-ms-wmv'=>'${VHTDOCS}icons/movie.gif', 'video/ogg'=>'${VHTDOCS}icons/movie.gif',
	'video/mpeg'=>'${VHTDOCS}icons/movie.gif', 'video/quicktime'=>'${VHTDOCS}icons/movie.gif',
	'audio/mpeg'=>'${VHTDOCS}icons/sound2.gif',
	default => '${VHTDOCS}icons/unknown.gif',
);


## -- ALLOW_EDIT
## allow changing text files (@EDITABLEFILES) with the Web interface
$ALLOW_EDIT = 1;

## -- EDITABLEFILES
## text file names (regex; case insensitive)
@EDITABLEFILES = ( '\.(txt|php|s?html?|tex|inc|cc?|java|hh?|ini|pl|pm|py|css|js|inc|csh|sh|tcl|tk|tex|ltx|sty|cls|vcs|vcf|ics|csv|mml|asc|text|pot|brf|asp|p|pas|diff|patch|log|conf|cfg|sgml|xml|xslt)$', 
		'^(\.ht|readme|changelog|todo|license|gpl|install|manifest\.mf)' );

## -- ICON_WIDTH
## specifies the icon width for the folder listings of the Web interface
## DEFAULT: $ICON_WIDTH = 18;
$ICON_WIDTH = 18;

## -- CSS
## defines a stylesheet added to the header of the Web interface
$CSS = '';

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
## EXAMPLES: @HIDDEN = ( '\.DAV/?$', '~$', '\.bak$', '/\.ht' );
@HIDDEN = ();

## -- @UNSELECTABLE_FOLDERS
## listed files/folders are unselectable in the Web interface to
## avoid archive downloads, deletes, ... of large folders.
## It's a list of regular expressions and a expression must match a full path.
## EXAMPLE: @UNSELECTABLE_FOLDERS = ('/afs/[^/]+(/[^/]+)?/?'); 
##    # disallow selection of a AFS cell and all subfolders but subsubfolders are selectable for file/folder actions
@UNSELECTABLE_FOLDERS = ('/afs/[^/]+(/[^/]+)?/?');

## -- ALLOW_INFINITE_PROPFIND
## enables/disables infinite PROPFIND requests
## if disabled the default depth is set to 0
$ALLOW_INFINITE_PROPFIND = 1;

## -- ALLOW_FILE_MANAGEMENT
## enables file management with a Web browser
## ATTENTATION: locks will be ignored
$ALLOW_FILE_MANAGEMENT = 1;

## -- REDIRECT_TO
## redirect all directory/folder requests to the given URL if FANCYINDEXING is disabled 
## EXAMPLE: $REDIRECT_TO='http:/';
#$REDIRECT_TO='http:/';

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

## -- ENABLE_DAVMOUNT
## enables DAV mount button in the folder navigation of the Web interface
## DEFAULT: $ENABLE_DAVMOUNT = 0;
$ENABLE_DAVMOUNT = 0;

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
## enables the WebDAV properties viewer in the Web interface
## DEFAULT: $ENABLE_PROPERTIES_VIEWER = 0;
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
$SHOW_MIME= 0;

## -- SHOW_FILE_ACTIONS
## show file actions column
$SHOW_FILE_ACTIONS = 0;

## -- SHOW_CURRENT_FOLDER
## shows the current folder '.' to allow permission changes,...
$SHOW_CURRENT_FOLDER = 0;

## -- SHOW_CURRENT_FOLDER_ROOTONLY 
## shows the current folder '.' only in the document root ($DOCUMENT_ROOT)
$SHOW_CURRENT_FOLDER_ROOTONLY = 0;

## -- SHOW_PARENT_FOLDER
## shows the parent folder '..' for navigation
$SHOW_PARENT_FOLDER = 1;

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
$LANGSWITCH = '<div style="font-size:0.6em;text-align:right;border:0px;padding:0px;"><a href="?lang=default">[EN]</a> <a href="?lang=de">[DE]</a> <a href="?lang=fr">[FR]</a> $CLOCK</div>';

## -- HEADER
## content after body tag in the Web interface
$HEADER = '<div class="header">WebDAV CGI - Web interface: You are logged in as <span title="'.`id -a`.'">$USER</span>.<div style="float:right;font-size:0.8em;">$NOW</div></div>';

## -- SIGNATURE
## for fancy indexing
## EXAMPLE: $SIGNATURE=$ENV{SERVER_SIGNATURE};
$SIGNATURE = '&copy; ZE CMS, Humboldt-Universit&auml;t zu Berlin | Written 2010-2011 by <a href="http://webdavcgi.sf.net/">Daniel Rohde</a>';

## -- LANG
## defines the default language for the Web interface
## DEFAULT: $LANG='default';
$LANG = 'default';
#$LANG = 'de';

## -- TRANSLATION
## DEPRECATED: use webdav-ui_${LANG}.msg files instead
## defines text and tooltips for the Web interface 
## if you add your own translation you don't need to translate all text keys
## (there is a fallback to the default)
## Don't use entities like &auml; for buttons and table header (names, lastmodified, size, mimetype).
## EXAMPLE: %TRANSLATION = ( de => { cancel => 'Abbrechen' } );
%TRANSLATION = ( mylangcode => { cancel => 'Cancel' } );

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
## enable/disable lock/unlock support (WebDAV compliance class 2) 
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

## -- ENABLE_SYSINFO
## enables sysinfo.html (only useful for debugging)
## just call /<my virtual path>/sysinfo.html to system information
$ENABLE_SYSINFO = $DEBUG;

############  S E T U P - END ###########################################
#########################################################################

use strict;
#use warnings;

use locale;

use Fcntl qw(:flock);

use CGI;

use File::Basename;
use File::Spec::Link;

use XML::Simple;
use Date::Parse;
use POSIX qw(strftime ceil locale_h);

use URI::Escape;
use OSSP::uuid;
use Digest::MD5;

use DBI;
use Quota;
use Archive::Zip;
use Graphics::Magick;

use IO::Compress::Gzip qw(gzip);
use IO::Compress::Deflate qw(deflate);

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
$DAV.=', calendar-schedule,calendar-availability,calendarserver-principal-property-search,calendarserver-private-events,calendarserver-private-comments,calendarserver-sharing,calendar-auto-schedule' if  $ENABLE_CALDAV || $ENABLE_CALDAV_SCHEDULE;
$DAV.=', addressbook' if $ENABLE_CARDDAV;
$DAV.=', bind' if $ENABLE_BIND;

our $PATH_TRANSLATED = $ENV{PATH_TRANSLATED};
our $REQUEST_URI = $ENV{REQUEST_URI};
our $REMOTE_USER = $ENV{REDIRECT_REMOTE_USER} || $ENV{REMOTE_USER};

$LANG = $cgi->param('lang') || $cgi->cookie('lang') || $LANG || 'default';
$ORDER = $cgi->param('order') || $cgi->cookie('order') || $ORDER || 'name';
$PAGE_LIMIT = $cgi->param('pagelimit') || $cgi->cookie('pagelimit') || $PAGE_LIMIT;
$PAGE_LIMIT = ceil($PAGE_LIMIT) if defined $PAGE_LIMIT;
@PAGE_LIMITS = ( 5, 10, 15, 20, 25, 30, 50, 100, -1 ) unless defined @PAGE_LIMITS;
unshift @PAGE_LIMITS, $PAGE_LIMIT if defined $PAGE_LIMIT && $PAGE_LIMIT > 0 && grep(/\Q$PAGE_LIMIT\E/, @PAGE_LIMITS) <= 0 ;

$VIEW = $cgi->param('view') || $cgi->cookie('view') || $VIEW || ($ENABLE_SIDEBAR ? 'sidebar' : 'classic');
$VIEW = 'classic' unless $ENABLE_SIDEBAR ;

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
# from http://tools.ietf.org/html/draft-daboo-carddav-directory-gateway-02
#    directory-gateway (unsupported yet)
# from ?
#    calendar-free-busy-set


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
			'schedule-tag', 'calendar-user-address-set', 'calendar-free-busy-set',
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

@UNSUPPORTED_PROPS = ( 'checked-in', 'checked-out', 'xmpp-uri', 'dropbox-home-URL' ,'parent-set', 'appledoubleheader', 'directory-gateway' ); 

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
			'supported-query-grammar', 'directory-gateway', 'caldav-free-busy-set',
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
		'appledoubleheader'=>'Apple', 'directory-gateway'=>'D', 'calendar-free-busy-set'=>'C',
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
	} elsif ($ENABLE_SYSINFO && $fn =~/\/sysinfo.html$/) {
		printHeaderAndContent('200 OK', 'text/html', renderSysInfo());
	} elsif ($FANCYINDEXING && ($fn =~ /\/webdav-ui(-custom)?\.(js|css)$/ || $fn =~ /\Q$VHTDOCS\E(.*)$/) && ($ENABLE_AFS || !-e $fn)) {
		my $file = $fn =~ /\Q$VHTDOCS\E(.*)/ ? $INSTALL_BASE.'htdocs/'.$1 : $INSTALL_BASE.'lib/'.basename($fn);
		$file=~s/\/\.\.\///g;
		my $compression = !-e $file && -e "$file.gz";
		my $nfile = $file;
		$file = "$nfile.gz" if $compression;
		if (open(F,"<$file")) {
			my $header = { -Expires=>strftime("%a, %d %b %Y %T GMT" ,gmtime(time()+ 604800)), -Vary=>'Accept-Encoding' };
			if ($compression) {
				$$header{-Content_Encoding}='gzip';
				$$header{-Content_Length}=(stat($file))[7];
			}
			printFileHeader($nfile, $header);
			binmode(STDOUT);
			while (read(F,my $buffer, $BUFSIZE || 1048576 )>0) {
				print $buffer;
			}
			close(F);
		} else {
			printHeaderAndContent('404 Not Found','text/plain','404 - NOT FOUND');
		}
	} elsif ($ENABLE_AFS && !checkAFSAccess($fn)) {
		printHeaderAndContent('403 Forbidden','text/plain', '403 Forbidden');
	} elsif (!$FANCYINDEXING && -d $fn) {
		if (defined $REDIRECT_TO) {
			print $cgi->redirect($REDIRECT_TO);
		} else {
			printHeaderAndContent('404 Not Found','text/plain','404 - NOT FOUND');
		}
	} elsif ($ENABLE_DAVMOUNT && $cgi->param('action') eq 'davmount' && -e $fn) {
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
		renderPropertiesViewer();
	} elsif (-d $fn) {
		renderWebInterface();
	} elsif (-e $fn && (!$IGNOREFILEPERMISSIONS && !-r $fn)) {
		printHeaderAndContent('403 Forbidden','text/plain', '403 Forbidden');
	} elsif (-e $fn) {
		debug("_GET: DOWNLOAD");
		if (open(my $F,"<$fn")) {
			binmode(STDOUT);
			my $enc = $cgi->http('Accept-Encoding');
			my $mime = getMIMEType($fn);
			my @stat = lstat($fn);
			if ($ENABLE_COMPRESSION && $enc && $enc=~/(gzip|deflate)/ && $stat[7] > 1023 && $mime=~/^(text\/(css|html)|application\/(x-)?javascript)$/i) {
				print $cgi->header( -status=>'200 OK',-type=>$mime, -ETag=>getETag($fn), -Last_Modified=>strftime("%a, %d %b %Y %T GMT" ,gmtime($stat[9])), -charset=>$CHARSET, -Content_Encoding=>$enc=~/gzip/?'gzip':'deflate');
				if ($enc =~ /gzip/i) {
					gzip $F => \*STDOUT;
				} elsif ($enc =~ /deflate/i) {
					deflate $F => \*STDOUT;
				}
			} else {
				printFileHeader($fn);
				while (read($F,my $buffer, $BUFSIZE || 1048576 )>0) {
					print $buffer;
				}
			}
			close($F);
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
	} elsif ($PATH_TRANSLATED =~ /\/webdav-ui\.(js|css)$/ && !-e $PATH_TRANSLATED) {
		printFileHeader(-e $INSTALL_BASE.basename($PATH_TRANSLATED) ? $INSTALL_BASE.basename($PATH_TRANSLATED) : "${INSTALL_BASE}lib/".basename($PATH_TRANSLATED));
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
	
	if ($ALLOW_FILE_MANAGEMENT && ($cgi->param('delete')||$cgi->param('rename')||$cgi->param('mkcol')||$cgi->param('changeperm')||$cgi->param('edit')||$cgi->param('savetextdata')||$cgi->param('savetextdatacont')||$cgi->param('createnewfile'))) {
		debug("_POST: file management ".join(",",$cgi->param('file')));
		if ($cgi->param('delete')) {
			if ($cgi->param('file')) {
				my $count = 0;
				foreach my $file ($cgi->param('file')) {
					$file = "" if $file eq '.';
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
							my $target = $PATH_TRANSLATED.$cgi->param('newname');
							$target.='/'.$file if -d $target;
							if (rmove($PATH_TRANSLATED.$file, $target)) {
								logger("MOVE $PATH_TRANSLATED$file to $target via POST");
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
					$file="" if $file eq '.';
					changeFilePermissions($PATH_TRANSLATED.$file, $mode, $cgi->param('fp_type'), $ALLOW_CHANGEPERMRECURSIVE && $cgi->param('fp_recursive'));
				}
			} else {
				$errmsg='chpermnothingerr';
			}
		} elsif ($cgi->param('edit')) {
			my $file = $PATH_TRANSLATED. $cgi->param('file');
			if (-f $file && -w $file) {
				$msgparam='edit='.$cgi->escape($cgi->param('file')).'#editpos';
			} else {
				$errmsg='editerr';
				$msgparam='p1='.$cgi->escape($cgi->param('file'));
			}
		} elsif ($cgi->param('savetextdata') || $cgi->param('savetextdatacont')) {
			my $file = $PATH_TRANSLATED . $cgi->param('filename');
			if (-f $file && -w $file && open(F, ">$file")) {
				print F $cgi->param('textdata');
				close(F);
				$msg='textsaved';
			} else {
				$errmsg='savetexterr';
			}
			$msgparam='p1='.$cgi->escape(''.$cgi->param('filename'));
			$msgparam.=';edit='.$cgi->escape($cgi->param('filename')) if $cgi->param('savetextdatacont');
		} elsif ($cgi->param('createnewfile')) {
			my $fn = $cgi->param('cnfname');
			my $full = $PATH_TRANSLATED.$fn;
			if (($IGNOREFILEPERMISSIONS || -w $PATH_TRANSLATED) && ($IGNOREFILEPERMISSIONS || !-e $full) && ($fn !~ /\//) && open(F,">>$full")) {
				$msg='newfilecreated';
				print F "";
				close(F);
			} else {
				$errmsg='createnewfileerr';
			}
			$msgparam='p1='.$cgi->escape($fn);
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
	printCompressedHeaderAndContent($status,$type,$content);
	
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
	printCompressedHeaderAndContent($status, $type, $content);
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
			} elsif (ref($$xmldata{$rn}{'{DAV:}href'}) eq 'HASH') {
				@hrefs = grep(!/DAV:/, values %{$$xmldata{$rn}{'{DAV:}href'}});
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
			} elsif (ref($$xmldata{$rn}{'{DAV:}href'}) eq 'HASH') {
				@hrefs = grep(!/DAV:/,values %{$$xmldata{$rn}{'{DAV:}href'}});
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
				$nhref=~s/^$VIRTUAL_BASE//;
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
		$content= $#resps> -1 ? createXML({multistatus => $#resps>-1 ? { response => \@resps } : '' }) : '<?xml version="1.0" encoding="UTF-8"?><D:multistatus xmlns:D="DAV:"/>';
	}
	debug("_REPORT: REQUEST: $xml");
	debug("_REPORT: RESPONSE: $content");
	printCompressedHeaderAndContent($status, $type, $content);
}
sub _SEARCH {
	my @resps;
	my $status = '207 Multistatus';
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
	debug("_SEARCH: status=$status, type=$type, request:\n$xml\n\n response:\n $content\n\n");
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
		$href=~s/^https?:\/\/\Q$host\E(:\d+)?$VIRTUAL_BASE//;
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
		$href=~s/^https?:\/\/\Q$host\E(:\d+)?$VIRTUAL_BASE//;
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
		$base =~ s@^(https?://([^\@]+\@)?\Q$host\E(:\d+)?)?$VIRTUAL_BASE@@;
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
	$sortfunc = 'return $a cmp $b ' if $sortfunc eq '';

	debug("handleBasicSearch: matches=$#matches, sortfunc=$sortfunc");
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
	$$resp_200{prop}{modifiedby}=$REMOTE_USER if $prop eq 'modifiedby';
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
	$$resp_200{prop}{'calendar-free-busy-set'}{href}=getCalendarHomeSet($uri) if $prop eq 'calendar-free-busy-set';

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
		return $factor * ( (stat($fp_a))[$idx] <=> (stat($fp_b))[$idx] || $a cmp $b );
	} elsif ($ORDER =~ /mime/) {
		return $factor * ( getMIMEType($a) cmp getMIMEType($b) || $a cmp $b);
	}
	return $factor * ($a cmp $b);
}
sub getfancyfilename {
	my ($full,$s,$m,$fn,$isUnReadable) = @_;
	my $ret = $s;
	my $q = getQueryParams();

	$full = '/' if $full eq '//'; # fixes root folder navigation bug

	$full.="?$q" if defined $q && defined $fn && !$isUnReadable && -d $fn;
	my $fntext = $s;
	$fntext =substr($s,0,$MAXFILENAMESIZE-3) if length($s)>$MAXFILENAMESIZE;
	my $linkit =  $IGNOREFILEPERMISSIONS || $fn=~/^\.{1,2}$/ || (!-d $fn && -r $fn) || -x $fn ;

	$ret = $linkit ? $cgi->a({href=>$full,title=>$s},$cgi->escapeHTML($fntext)) : $cgi->escapeHTML($fntext);
	$ret .=  length($s)>$MAXFILENAMESIZE ? '...' : (' 'x($MAXFILENAMESIZE-length($s)));

	$full=~/([^\.]+)$/;
	my $suffix = $1 || $m;
	my $icon = getIcon($m);
	my $width = $ICON_WIDTH || 18;
	my $onmouseover="";
	my $onmouseout="";
	my $align="";
	my $id='i'.time().$WEB_ID;
	$id=~s/\"//g;
	
	my $cssclass='icon';
	if ($ENABLE_THUMBNAIL && !$isUnReadable && -r $fn && !-z $fn && hasThumbSupport($m))  {
		$icon=$full.($full=~/\?.*/?';':'?').'action=thumb';
		if ($THUMBNAIL_WIDTH && $ICON_WIDTH < $THUMBNAIL_WIDTH) {
			$cssclass='thumb';
			$onmouseover = qq@javascript:this.intervalFunc=function() { if (this.width<$THUMBNAIL_WIDTH) this.width+=@.(($THUMBNAIL_WIDTH-$ICON_WIDTH)/15).qq@; else window.clearInterval(this.intervalObj);}; this.intervalObj = window.setInterval("document.getElementById('$id').intervalFunc();", 10);@;
			$onmouseout = qq@javascript:window.clearInterval(this.intervalObj);this.width=$ICON_WIDTH;@;
		}
	}
	$full.= ($full=~/\?/ ? ';' : '?').'action=props' if $ENABLE_PROPERTIES_VIEWER;
	my $img =  $cgi->img({id=>$id, src=>$icon,alt=>'['.$suffix.']', -class=>$cssclass, -width=>$width, -onmouseover=>$onmouseover,-onmouseout=>$onmouseout});
	$ret = ($linkit ? $cgi->a(  {href=>$full,title=>$ENABLE_PROPERTIES_VIEWER ? _tl('showproperties') : $s}, $img):$img).' '.$ret;
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

	my @cookies;
	@cookies  = ( 
		$cgi->cookie(-name=>'lang',-value=>$LANG,-expires=>'+10y'),
		$cgi->cookie(-name=>'showall',-value=>$cgi->param('showpage') ? 0 : ($cgi->param('showall') || $cgi->cookie('showall') || 0), -expires=>'+10y'),
		$cgi->cookie(-name=>'order',-value=>$ORDER, -expires=>'+10y'),
		$cgi->cookie(-name=>'pagelimit',-value=>$PAGE_LIMIT, -expires=>'+10y'),
		$cgi->cookie(-name=>'view',-value=>$VIEW, -expires=>'+10y'),
	) if $cgi->request_method() =~ /^(GET|POST)$/;

	my $header = $cgi->header(-status=>$status, -type=>$type, -Content_length=>length($content), -ETag=>getETag(), -charset=>$CHARSET, -cookie=>\@cookies );

	$header = "MS-Author-Via: DAV\r\n$header";
	$header = "DAV: $DAV\r\n$header";
	$header="$addHeader\r\n$header" if defined $addHeader;
	$header="Translate: f\r\n$header" if defined $cgi->http('Translate');

	print $header;
	binmode(STDOUT);
	print $content;
}
sub printCompressedHeaderAndContent {
	my ($status, $type, $content, $addHeader) = @_;
	if ($ENABLE_COMPRESSION && (my $enc = $cgi->http('Accept-Encoding'))) {
		my $orig = $content;
		$addHeader ="" unless defined $addHeader;
		if ($enc =~ /gzip/i) {
			gzip \$orig => \$content;	
			$addHeader.="\r\nContent-Encoding: gzip";
		} elsif ($enc =~ /deflate/i) {
			deflate \$orig => \$content;
			$addHeader.="\r\nContent-Encoding: deflate";
		}
	}
	printHeaderAndContent($status, $type, $content, $addHeader);
}
sub printFileHeader {
	my ($fn,$addheader) = @_;
	my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size, $atime,$mtime,$ctime,$blksize,$blocks) = stat($fn);
	my %ha = ( -status=>'200 OK',-type=>getMIMEType($fn),  -Content_Length=>$size, -ETag=>getETag($fn), -Last_Modified=>strftime("%a, %d %b %Y %T GMT" ,gmtime($mtime)), -charset=>$CHARSET);
	%ha = (%ha, %{$addheader}) if $addheader;
	my $header = $cgi->header(\%ha);

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
		$block_curr *= 1024; $block_hard *= 1024;
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
		push @{$$usergrant{privilege}},{'read-free-busy'  => undef };
		push @{$$usergrant{privilege}},{'schedule-query-freebusy'  => undef };
		if ($IGNOREFILEPERMISSIONS || -w $fn) {
			push @{$$usergrant{privilege}},{write => undef };
			push @{$$usergrant{privilege}},{'write-acl' => undef };
			push @{$$usergrant{privilege}},{'write-content'  => undef };
			push @{$$usergrant{privilege}},{'write-properties'  => undef };
			push @{$$usergrant{privilege}},{'unlock'  => undef };
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
	my $rmuser = $REMOTE_USER;
	$rmuser = $< unless exists $CALENDAR_HOME_SET{$rmuser};
	return  ( exists $CALENDAR_HOME_SET{$rmuser} ? $CALENDAR_HOME_SET{$rmuser} : $CALENDAR_HOME_SET{default} );
}
sub getAddressbookHomeSet {
	my ($uri) = @_;
	return $uri unless defined %ADDRESSBOOK_HOME_SET;
	my $rmuser = $REMOTE_USER;
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
	my $navpath = $ru;
	my $base = '';
	$navpath=~s/^($VIRTUAL_BASE)//;
	$base = $1;
	if ($base ne '/' ) {
		$navpath = basename($base)."/$navpath";
		$base = dirname($base);
		$base .= '/' if $base ne '/';
		$content.=$base;
	} else {
		$base = '';
		$navpath = "/$navpath";
	}
	foreach my $pe (split(/\//, $navpath)) {
		$path .= uri_escape($pe) . '/';
		$path = '/' if $path eq '//';
		$content .= $cgi->a({-href=>"$base$path".(defined $query?"?$query":""), -title=>$path}," $pe/");
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
sub renderPasteButton { return $cgi->button({-onclick=>'clpaction("paste")', -disabled=>'disabled', -name=>'paste', -class=>'pastebutton',-value=>_tl('paste')}); }
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
	my ($fn,$bid) = @_;
	return $cgi->hidden(-name=>'upload',-value=>1)
		.$cgi->span({-id=>'file_upload'},_tl('fileuploadtext').$cgi->filefield(-id=>$bid?$bid:'filesubmit'.(++$WEB_ID), -name=>'file_upload', -class=>'fileuploadfield', -multiple=>'multiple', -onchange=>'return addUploadField()' ))
		.$cgi->span({-id=>'moreuploads'},"")
		.' '.$cgi->a({-onclick=>'javascript:return addUploadField(1);',-href=>'#'},_tl('fileuploadmore'))
		.$cgi->div({-class=>'uploadfuncs'},
			$cgi->submit(-name=>'filesubmit',-value=>_tl('fileuploadbutton'),-onclick=>'return window.confirm("'._tl('fileuploadconfirm').'");')
		);
}
sub renderCreateNewFolderView {
	return $cgi->div({-class=>'createfolder'},'&bull; '._tl('createfoldertext').$cgi->input({-id=>$_[0]?$_[0]:'colname'.(++$WEB_ID), -name=>'colname', -size=>30, -onkeypress=>'return catchEnter(event,"createfolder");'}).$cgi->submit(-id=>'createfolder', -name=>'mkcol',-value=>_tl('createfolderbutton')))
}
sub renderMoveView {
	return $cgi->div({-class=>'movefiles', -id=>'movefiles'},
		'&bull; '._tl('movefilestext')
		.$cgi->input({-id=>$_[0]?$_[0]:'newname'.(++$WEB_ID), -name=>'newname',-disabled=>'disabled',-size=>30,-onkeypress=>'return catchEnter(event,"rename");'}).$cgi->submit(-id=>'rename',-disabled=>'disabled', -name=>'rename',-value=>_tl('movefilesbutton'),-onclick=>'return window.confirm("'._tl('movefilesconfirm').'");')
	);
}
sub renderDeleteView {
	return $cgi->div({-class=>'delete', -id=>'delete'},'&bull; '.$cgi->submit(-disabled=>'disabled', -name=>'delete', -value=>_tl('deletefilesbutton'), -onclick=>'return window.confirm("'._tl('deletefilesconfirm').'");') 
		.' '._tl('deletefilestext'));
}
sub renderCreateNewFileView {
	return $cgi->div(_tl('newfilename').$cgi->input({-id=>'cnfname',-size=>30,-type=>'text',-name=>'cnfname',-onkeypress=>'return catchEnter(event,"createnewfile")'}).$cgi->submit({-id=>'createnewfile',-name=>'createnewfile',-value=>_tl('createnewfilebutton')}));
}
sub renderEditTextResizer {
	my ($text, $pid) = @_;
	return $text.$cgi->div({-class=>'textdataresizer', -onmousedown=>'handleTextAreaResize(event,"textdata","'.$pid.'",1);',-onmouseup=>'handleTextAreaResize(event,"textdata","'.$pid.'",0)'},'&nbsp;');
}
sub escapeQuotes {
	my ($q) = @_;
	$q=~s/(["'])/\\$1/g;
	return $q;
}
sub renderEditTextView {
	my $file = $PATH_TRANSLATED. $cgi->param('edit');

	my ($cols,$rows,$ff) = $cgi->cookie('textdata') ? split(/\//,$cgi->cookie('textdata')) : (70,15,'mono');
	my $fftoggle = $ff eq 'mono' ? 'prop' : 'mono';

	my $cmsg = _tl('confirmsavetextdata',escapeQuotes($cgi->param('edit')));

	return $cgi->div($cgi->param('edit').':')
	      .$cgi->div(
		 $cgi->hidden(-id=>'filename', -name=>'filename', -value=>$cgi->param('edit'))
		.$cgi->hidden(-id=>'mimetype',-name=>'mimetype', -value=>getMIMEType($file))
		.$cgi->div({-class=>'textdata'},
			$cgi->textarea({-id=>'textdata',-class=>'textdata '.$ff,-name=>'textdata', -autofocus=>'autofocus',-default=>getFileContent($file), -rows=>$rows, -cols=>$cols})
			)
		.$cgi->div({-class=>'textdatabuttons'},
				$cgi->button(-value=>_tl('cancel'), -onclick=>'if (window.confirm("'._tl('canceledit').'")) window.location.href="'.$REQUEST_URI.'";')
				. $cgi->submit(-style=>'float:right',-name=>'savetextdata',-onclick=>"return window.confirm('$cmsg');", -value=>_tl('savebutton'))
				. $cgi->submit(-style=>'float:right',-name=>'savetextdatacont',-onclick=>"return window.confirm('$cmsg');", -value=>_tl('savecontbutton'))
		)
	      );
}
sub renderChangePermissionsView {
	return $cgi->start_table()
			. $cgi->Tr($cgi->td({-colspan=>2},_tl('changefilepermissions'))
				)
			.(defined $PERM_USER 
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
	return _tl('zipuploadtext').$cgi->filefield(-name=>'zipfile_upload', -id=>'zipfile_upload',-multiple=>'multiple').$cgi->submit(-name=>'uncompress', -value=>_tl('zipuploadbutton'),-onclick=>'return window.confirm("'._tl('zipuploadconfirm').'");');
}
sub renderZipView {
	my $content = "";
	$content .= '&bull; '.renderZipDownloadButton()._tl('zipdownloadtext').$cgi->br() if $ALLOW_ZIP_DOWNLOAD; 
	$content .= '&bull; '.renderZipUploadView() if $ALLOW_ZIP_UPLOAD;
	return $content;
}
sub getActionViewInfos {
	my ($action) = @_;
	return $cgi->cookie($action) ? split(/\//, $cgi->cookie($action)) : ( 'false', undef, undef, undef, 'null');
}
sub renderActionView {
	my ($action, $name, $view, $focus, $forcevisible, $resizeable) = @_;
	my $style = '';
	my ($visible, $x, $y, $z,$collapsed) = getActionViewInfos($action);
	my $dzi = $cgi->cookie('dragZIndex') ? $cgi->cookie('dragZIndex') : $z ? $z : 10;
	$style .= $forcevisible || $visible eq 'true' ? 'visibility: visible;' :'';
	$style .= $x ? 'left: '.$x.';' : '';
	$style .= $y ? 'top: '.$y.';' : '';
	$style .= 'z-index:'.($forcevisible ? $dzi : $z ? $z : $dzi).';';
	return $cgi->div({-class=>'sidebaractionview'.($collapsed eq 'collapsed'?' collapsed':''),-id=>$action, 
				-onclick=>"handleWindowClick(event,'$action'".($focus?",'$focus'":'').')', -style=>$style},
		$cgi->div({-class=>'sidebaractionviewheader',
				-ondblclick=>$forcevisible ? undef : "toggleCollapseAction('$action',event)", 
				-onmousedown=>"handleWindowMove(event,'$action', 1)", 
				-onmouseup=>"handleWindowMove(event,'$action',0)"}, 
				($forcevisible ? '' : $cgi->span({-onclick=>"hideActionView('$action');",-class=>'sidebaractionviewclose'},' [X] '))
				.
				_tl($name)
			)
		.$cgi->div({-class=>'sidebaractionviewaction'.($collapsed eq 'collapsed'?' collapsed':''),-id=>"v_$action"},$view)
		.($resizeable ? $cgi->div({-class=>'sidebaractionviewresizer'.($collapsed eq 'collapsed'?' collapsed':''), -onmousedown=>"handleWindowResize(event,'$action',1);", -onmouseup=>"handleWindowResize(event,'$action',0);"},'&nbsp') : '')
					
				
		);
}
sub renderPropertiesViewer {
	my $fn = $PATH_TRANSLATED;
	setLocale();
	my $content = "";
	$content .= start_html("$REQUEST_URI properties");
	$content .= replaceVars($LANGSWITCH) if defined $LANGSWITCH;
	$content .= replaceVars($HEADER) if defined $HEADER;
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
	$content.=$cgi->hr().$cgi->div({-class=>'signature'},replaceVars($SIGNATURE)) if defined $SIGNATURE;
	$content.=$cgi->end_html();
	printCompressedHeaderAndContent('200 OK', 'text/html', $content, 'Cache-Control: no-cache, no-store');
}
sub renderWebInterface {
	my $ru = $REQUEST_URI;
	my $content = "";
	my $head = "";
	my $fn = $PATH_TRANSLATED;
	debug("_GET: directory listing of $fn");
	setLocale();
	$head .= replaceVars($LANGSWITCH) if defined $LANGSWITCH;
	$head .= replaceVars($HEADER) if defined $HEADER;
	##$content.=$cgi->start_multipart_form(-method=>'post', -action=>$ru, -onsubmit=>'return window.confirm("'._tl('confirm').'");') if $ALLOW_FILE_MANAGEMENT;
	$content.=$cgi->start_multipart_form(-method=>'post', -action=>$ru ) if $ALLOW_FILE_MANAGEMENT;
	if ($ALLOW_SEARCH && ($IGNOREFILEPERMISSIONS || -r $fn)) {
		my $search = $cgi->param('search');
		$head .= $cgi->div({-class=>'search'}, _tl('search'). ' '. $cgi->input({-title=>_tl('searchtooltip'),-onkeypress=>'javascript:handleSearch(this,event);', -onkeyup=>'javascript:if (this.size<this.value.length || (this.value.length<this.size && this.value.length>10)) this.size=this.value.length;', -name=>'search',-size=>$search?(length($search)>10?length($search):10):10, -value=>defined $search?$search:''}));
	}
	$head.=renderMessage();
	if ($cgi->param('search')) {
		$content.=getSearchResult($cgi->param('search'),$fn,$ru);
	} else {
		my $showall = $cgi->param('showpage') ? 0 : $cgi->param('showall') || $cgi->cookie('showall') || 0;
		$head .= $cgi->div({-id=>'notwriteable',-onclick=>'fadeOut("notwriteable");', -class=>'notwriteable msg'}, _tl('foldernotwriteable')) if (!$IGNOREFILEPERMISSIONS && !-w $fn) ;
		$head .= $cgi->div({-id=>'notreadable', -onclick=>'fadeOut("notreadable");',-class=>'notreadable msg'},  _tl('foldernotreadable')) if (!$IGNOREFILEPERMISSIONS && !-r $fn) ;
		$head .= $cgi->div({-id=>'filtered', -onclick=>'fadeOut("filtered");', -class=>'filtered msg', -title=>$FILEFILTERPERDIR{$fn}}, _tl('folderisfiltered', $FILEFILTERPERDIR{$fn} || ($ENABLE_NAMEFILTER ? $cgi->param('namefilter') : undef) )) if $FILEFILTERPERDIR{$fn} || ($ENABLE_NAMEFILTER && $cgi->param('namefilter'));
		$head .= $cgi->div( { -class=>'foldername'},
			$cgi->a({-href=>$ru.($ENABLE_PROPERTIES_VIEWER ? '?action=props' : '')}, 
					$cgi->img({-src=>getIcon('<folder>'),-title=>_tl('showproperties'), -alt=>'folder'})
				)
			.($ENABLE_DAVMOUNT ? '&nbsp;'.$cgi->a({-href=>'?action=davmount',-class=>'davmount',-title=>_tl('mounttooltip')},_tl('mount')) : '')
			.' '
			.getQuickNavPath($ru)
		);
		$head.= $cgi->div( { -class=>'viewtools' }, 
				($ru=~/^$VIRTUAL_BASE\/?$/ ? '' :$cgi->a({-class=>'up', -href=>dirname($ru).(dirname($ru) ne '/'?'/':''), -title=>_tl('uptitle')}, _tl('up')))
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
		$manageview.= renderFieldSet('editbutton',$cgi->a({-id=>'editpos'},"").renderEditTextView()) if $ALLOW_EDIT && $cgi->param('edit');
		$manageview.= renderFieldSet('upload',renderFileUploadView($fn)) if $ALLOW_FILE_MANAGEMENT && $ALLOW_POST_UPLOADS && ($IGNOREFILEPERMISSIONS || -w $fn);
		if ($VIEW eq 'sidebar') {
			$content.=renderSideBar() if $VIEW eq 'sidebar';
			$folderview.=renderToolbar() if $ALLOW_FILE_MANAGEMENT;
		}
		if ($ALLOW_FILE_MANAGEMENT && ($IGNOREFILEPERMISSIONS || -w $fn)) {
			my $m = "";
			$m .= renderFieldSet('files', renderCreateNewFolderView().renderCreateNewFileView() .renderMoveView() .renderDeleteView());
			$m .= renderFieldSet('zip', renderZipView()) if ($ALLOW_ZIP_UPLOAD || $ALLOW_ZIP_DOWNLOAD);
			$m .= renderToggleFieldSet('permissions', renderChangePermissionsView()) if $ALLOW_CHANGEPERM;
			$m .= renderToggleFieldSet('afs', renderAFSACLManager()) if ($ENABLE_AFSACLMANAGER);
			$manageview .= renderToggleFieldSet('management', $m);
		}
		$folderview .= $manageview unless $VIEW eq 'sidebar';
		$folderview .= renderToggleFieldSet('afsgroup',renderAFSGroupManager()) if ($ENABLE_AFSGROUPMANAGER && $VIEW ne 'sidebar');
		my $showsidebar = $cgi->cookie('sidebar') ? $cgi->cookie('sidebar') eq 'true' : 1;
		$content .= $cgi->div({-id=>'folderview', -class=>($VIEW eq 'sidebar'? 'sidebarfolderview'.($showsidebar?'':' full') : 'folderview')}, $folderview);
		$content .= $VIEW ne 'sidebar' && $ENABLE_SIDEBAR ? renderFieldSet('viewoptions', 
				 ( $showall ? '&bull; '.$cgi->a({-href=>'?showpage=1'},_tl('navpageview')) : '' )
				.(!$showall ? '&bull; '.$cgi->a({-href=>'?showall=1'},_tl('navall')) : '' )
				. $cgi->br().'&bull; '.$cgi->a({-href=>'?view=sidebar'},_tl('sidebarview'))) : '';
		$content .= $cgi->end_form() if $ALLOW_FILE_MANAGEMENT;
		$content .= $cgi->start_form(-method=>'post', -id=>'clpform')
				.$cgi->hidden(-name=>'action', -value=>'') .$cgi->hidden(-name=>'srcuri', -value>'')
				.$cgi->hidden(-name=>'files', -value=>'') .$cgi->end_form() if ($ALLOW_FILE_MANAGEMENT && $ENABLE_CLIPBOARD);
		$content .= $cgi->start_form(-method=>'post', -id=>'faform') 
				.$cgi->hidden(-id=>'faction', -name=>'dummy', -value=>'unused')
				.$cgi->hidden(-id=>'fdst', -name=>'newname',-value=>'')
				.$cgi->hidden(-id=>'fsrc', -name=>'file', -value=>'')
				.$cgi->hidden(-id=>'fid', -name=>'fid', -value=>'')
				.$cgi->div({-id=>'forigcontent', -class=>'hidden'},"")
				.$cgi->end_form() if $ALLOW_FILE_MANAGEMENT && $SHOW_FILE_ACTIONS;
	}
	$content.= $cgi->div({-class=>$VIEW eq 'classic' ? 'signature' : 'signature sidebarsignature'}, replaceVars($SIGNATURE)) if defined $SIGNATURE;
	###$content =~ s/(<\/\w+[^>]*>)/$1\n/g;
	$content = start_html($ru).$content.$cgi->end_html();

	printCompressedHeaderAndContent('200 OK','text/html',$content,'Cache-Control: no-cache, no-store' );
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
	my $av = "";

	if ($ALLOW_FILE_MANAGEMENT) {
		$content .= $cgi->div({-class=>'sidebarheader'}, _tl('management'));
		$content .= renderSideBarMenuItem('fileuploadview',_tl('upload'), 'toggleActionView("fileuploadview","filesubmit")',$cgi->button({-value=>_tl('upload'), -name=>'filesubmit'}));
		$content .= renderSideBarMenuItem('zipfileuploadview',_tl('zipfileupload'), 'toggleActionView("zipfileuploadview","zipfile_upload")',$cgi->button({-value=>_tl('zipfileupload'), -name=>'uncompress'}));
		$content .= renderSideBarMenuItem('download', _tl('download'), undef, renderZipDownloadButton());
		$content .= renderSideBarMenuItem('copy',_tl('copytooltip'), undef, renderCopyButton());
		$content .= renderSideBarMenuItem('cut', _tl('cuttooltip'), undef, renderCutButton());
		$content .= renderSideBarMenuItem('paste', undef, undef, renderPasteButton());
		$content .= renderSideBarMenuItem('deleteview', undef, undef, renderDeleteFilesButton());
		$content .= renderSideBarMenuItem('createfolderview', _tl('createfolderbutton'), 'toggleActionView("createfolderview","colname-sidebar");', $cgi->button({-value=> _tl('createfolderbutton'),-name=>'mkcol'}));
		$content .= renderSideBarMenuItem('createnewfileview', _tl('createnewfilebutton'), 'toggleActionView("createnewfileview","cnfname");', $cgi->button({-value=>_tl('createnewfilebutton'),-name=>'createnewfile'}));
		$content .= renderSideBarMenuItem('movefilesview', _tl('movefilesbutton'), undef, $cgi->button({-disabled=>'disabled',-onclick=>'toggleActionView("movefilesview","newname");',-name=>'rename',-value=>_tl('movefilesbutton')}));
		$content .= renderSideBarMenuItem('permissionsview', _tl('permissions'), undef, $cgi->button({-disabled=>'disabled', -onclick=>'toggleActionView("permissionsview");', -value=>_tl('permissions'),-name=>'changeperm',-disabled=>'disabled'})) if $ALLOW_CHANGEPERM;
		$content .= renderSideBarMenuItem('afsaclmanagerview', _tl('afs'), 'toggleActionView("afsaclmanagerview");', $cgi->button({-value=>_tl('afs'),-name=>'saveafsacl'})) if $ENABLE_AFSACLMANAGER;
		$content .= $cgi->hr().renderSideBarMenuItem('afsgroupmanagerview', _tl('afsgroup'), 'toggleActionView("afsgroupmanagerview");', $cgi->button({-value=>_tl('afsgroup')})).$cgi->hr() if $ENABLE_AFSGROUPMANAGER;
		$av.= renderActionView('fileuploadview', 'upload', renderFileUploadView($PATH_TRANSLATED,'filesubmit'), 'filesubmit',0,0);
		$av.= renderActionView('zipfileuploadview', 'zipfileupload', renderZipUploadView(), 'zipfile_upload',0,0);
		$av.= renderActionView('createfolderview', 'createfolderbutton', renderCreateNewFolderView("colname-sidebar"),'colname-sidebar');
		$av.= renderActionView('createnewfileview', 'createnewfilebutton', renderCreateNewFileView(),'cnfname');
		$av.= renderActionView('movefilesview', 'movefilesbutton', renderMoveView("newname"),'newname');
		$av.= renderActionView('permissionsview', 'permissions', renderChangePermissionsView()) if $ALLOW_CHANGEPERM;
		$av.= renderActionView('afsaclmanagerview', 'afs', renderAFSACLManager()) if $ENABLE_AFSACLMANAGER;
		$av.= renderActionView('afsgroupmanagerview', 'afsgroup', renderAFSGroupManager()) if $ENABLE_AFSGROUPMANAGER;
	
		$av.= renderActionView('editview','editbutton',renderEditTextResizer(renderEditTextView(),'editview'),'textdata',1) if $ALLOW_EDIT && $cgi->param('edit'); 
	}

	$content .= $cgi->div({-class=>'sidebarheader'},_tl('viewoptions'));
	my $showall = $cgi->param('showpage') ? 0 : $cgi->param('showall') || $cgi->cookie('showall') || 0;
	$content .= renderSideBarMenuItem('navpageview', _tl('navpageviewtooltip'), 'window.location.href="?showpage=1";',$cgi->button(-value=>_tl('navpageview'))) if $showall;
	$content .= renderSideBarMenuItem('navall', _tl('navalltooltip'),'window.location.href="?showall=1";', $cgi->button(-value=>_tl('navall'))) unless $showall;
	$content .= renderSideBarMenuItem('changeview', _tl('classicview'), 'javascript:window.location.href="?view=classic";', $cgi->button({-value=>_tl('classicview')})); 


	my $showsidebar =  (! defined $cgi->cookie('sidebar') || $cgi->cookie('sidebar') eq 'true');
	my $sidebartogglebutton = $showsidebar ? '&lt;' : '&gt;';

	return $cgi->div({-id=>'sidebar', -class=>'sidebar'}, $cgi->start_table({-id=>'sidebartable',-class=>'sidebartable'.($showsidebar ?'':' collapsed')}).$cgi->Tr($cgi->td({-id=>'sidebarcontent', -class=>'sidebarcontent'.($showsidebar?'':' collapsed')},$content).$cgi->td({-id=>'sidebartogglebutton', -title=>_tl('togglesidebar'), -class=>'sidebartogglebutton', -onclick=>'toggleSideBar()'},$sidebartogglebutton)).$cgi->end_table()). $av ;
}
sub renderPageNavBar {
	my ($ru, $count, $files) = @_;
	my $limit = $PAGE_LIMIT || -1;
	my $showall = $cgi->param('showpage') ? 0 : $cgi->param('showall') || $cgi->cookie('showall') || 0;
	my $page = $cgi->param('page') || 1;

	my $content = "";
	return $content if $limit <1; # || $count <= $limit;

	my $maxpages = ceil($count / $limit);
	return $content if $maxpages == 0;

	return $cgi->div({-class=>'showall'}, $cgi->a({href=>$ru."?showpage=1", -title=>_tl('navpageviewtooltip')}, _tl('navpageview')). ', '.renderNameFilterForm()) if ($showall);
	if ($count >$limit) {

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
	}

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
			next if $file =~ /^\.{1,2}$/;
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

	$list="";
	my $tablehead ="";
	
	$tablehead.=$cgi->td({-class=>'th_sel'},$cgi->checkbox(-onclick=>'javascript:toggleAllFiles(this);', -name=>'selectall',-value=>"",-label=>"", -title=>_tl('togglealltooltip'))) if $ALLOW_FILE_MANAGEMENT;

	my $dir = $ORDER=~/_desc$/ ? '' : '_desc';
	my $query = $filter ? 'search=' . $cgi->param('search'):'';
	my $ochar = ' <span class="orderchar">'.($dir eq '' ? '&darr;' :'&uarr;').'</span>';
	$tablehead .= $cgi->td({-class=>'th_fn'.($ORDER=~/^name/?' th_highlight':''), style=>'min-width:'.$MAXFILENAMESIZE.'ex;',-onclick=>"window.location.href='$ru?order=name$dir;$query'"}, $cgi->a({-href=>"$ru?order=name$dir;$query"},_tl('names').($ORDER=~/^name/?$ochar:'')))
		.$cgi->td({-class=>'th_lm'.($ORDER=~/^lastmodified/?' th_highlight':''),-onclick=>"window.location.href='$ru?order=lastmodified$dir;$query'"}, $cgi->a({-href=>"$ru?order=lastmodified$dir;$query"},_tl('lastmodified').($ORDER=~/^lastmodified/?$ochar:'')))
		.$cgi->td({-class=>'th_size'.($ORDER=~/^size/i?' th_highlight':''),-onclick=>"window.location.href='$ru?order=size$dir;$query'"},$cgi->a({-href=>"$ru?order=size$dir;$query"},_tl('size').($ORDER=~/^size/?$ochar:'')))
		.($SHOW_PERM? $cgi->td({-class=>'th_perm'.($ORDER=~/^mode/?' th_highlight':''),-onclick=>"window.location.href='$ru?order=mode$dir;$query'"}, $cgi->a({-href=>"$ru?order=mode$dir;$query"},sprintf("%-11s",_tl('permissions').($ORDER=~/^mode/?$ochar:'')))):'')
		.($SHOW_MIME? $cgi->td({-class=>'th_mime'.($ORDER=~/^mime/?' th_highlight':''),-onclick=>"window.location.href='$ru?order=mime$dir;$query'"},'&nbsp;'.$cgi->a({-href=>"$ru?order=mime$dir;$query"},_tl('mimetype').($ORDER=~/^mime/?$ochar:''))):'')
		.($ALLOW_FILE_MANAGEMENT && $SHOW_FILE_ACTIONS ? $cgi->td({-title=>_tl('fileactions'), -class=>'th_actions'}, _tl('fileactions')) : '')
	;
	$tablehead = $cgi->Tr({-class=>'th', -title=>_tl('clickchangessort')}, $tablehead);
	$list .= $tablehead;
			

	my @files = sort cmp_files @{readDir($fn)};
	unshift @files, '.' if  $SHOW_CURRENT_FOLDER || ($SHOW_CURRENT_FOLDER_ROOTONLY && $DOCUMENT_ROOT eq $fn);
	unshift @files, '..' if $SHOW_PARENT_FOLDER && $DOCUMENT_ROOT ne $fn;

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

	my $unselregex = @UNSELECTABLE_FOLDERS ? '('.join('|',@UNSELECTABLE_FOLDERS).')' : '___cannot match___' ;

	my @rowclass = ( 'tr_odd', 'tr_even' );
	my $odd = 0;
	foreach my $filename (@files) {
		$WEB_ID++;
		my $fid = "f$WEB_ID";
		my $full = $filename eq '.' ? $fn : $fn.$filename;
		my $nru = $ru.uri_escape($filename);

		$nru = dirname($ru).'/' if $filename eq '..';
		$nru = $ru if $filename eq '.';
		$nru = '/' if $nru eq '//';

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
		$mimetype = -d $full ? ( $filename eq '..' ? '< .. >' : '<folder>' ) : getMIMEType($filename) unless $isUnReadable;
		$filename.="/" if !$isUnReadable && $filename !~ /^\.{1,2}$/ && -d $full;
		$nru.="/" if !$isUnReadable && $filename !~ /^\.{1,2}$/ && -d $full;

		next if $filter && $filename !~/$filter/i;

		my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size, $atime,$mtime,$ctime,$blksize,$blocks) = !$isUnReadable ? stat($full) : (0,0,0,0,0,0,0,0,0,0,0,0,0,0);
		
		push @rowclass,shift @rowclass;

		my $row = "";
		
		my $focus = $filter ? '': qq@addClassNameById("tr_$fid","tr_highlight");@;
		my $blur =  $filter ? '': qq@removeClassNameById("tr_$fid","tr_highlight");@;
		my $onclick= $filter ? '' : qq@return handleRowClick("$fid", event);@;
		my $ignev= qq@return false;@;

		my $unsel = $full =~ /^$unselregex$/;

		if ($ALLOW_FILE_MANAGEMENT) {
			my %checkboxattr = (-id=>$fid, -onfocus=>$focus, -onblur=>$blur, -name=>'file', -value=>$filename, -label=>'');
			if ($filename eq '..' || $unsel) {
				$checkboxattr{-disabled}='disabled'; 
				$checkboxattr{-style}='visibility: hidden;display:none'; 
				$checkboxattr{-value}='__not_allowed__';
			} else {
				$checkboxattr{-onclick}=qq@return handleCheckboxClick(this, "$fid", event);@;
			}
			$row.= $cgi->td({-class=>'tc_checkbox'},$cgi->checkbox(\%checkboxattr));
		}

		my $lmf = strftime(_tl('lastmodifiedformat'), localtime($mtime));
		my $ctf = strftime(_tl('lastmodifiedformat'), localtime($ctime));
		$row.= $cgi->td({-class=>'tc_fn', -id=>"tc_fn_$fid", -onclick=>$onclick, -onmousedown=>$ignev, -ondblclick=>$ignev}, getfancyfilename($nru,$filename,$mimetype, $full, $isUnReadable));
		$row.= $cgi->td({-class=>'tc_lm', -title=>_tl('created').' '.$ctf, -onclick=>$onclick, -onmousedown=>$ignev}, $lmf);
		$row.= $cgi->td({-class=>'tc_size', -title=>sprintf("= %.2fKB = %.2fMB = %.2fGB",$size/1024, $size/1048576, $size/1073741824), -onclick=>$onclick, -onmousedown=>$ignev}, $size);
		$row.= $cgi->td({-class=>'tc_perm', -onclick=>$onclick, -onmousedown=>$ignev}, $cgi->span({-class=>getmodeclass($full,$mode),-title=>sprintf("mode: %04o, uid: %s (%s), gid: %s (%s)",$mode & 07777,"".getpwuid($uid), $uid, "".getgrgid($gid), $gid)},sprintf("%-11s",mode2str($full,$mode)))) if $SHOW_PERM;
		$row.= $cgi->td({-class=>'tc_mime', -onclick=>$onclick, -onmousedown=>$ignev},'&nbsp;'. $cgi->escapeHTML($mimetype)) if $SHOW_MIME;
		$row.= $cgi->td({-class=>'tc_actions' }, $filename=~/^\.{1,2}$/ || $unsel ? '' : renderFileActions($fid, $filename, $full)) if $ALLOW_FILE_MANAGEMENT && $SHOW_FILE_ACTIONS;
		$list.=$cgi->Tr({-class=>$rowclass[0],-id=>"tr_$fid", -title=>"$filename", -onmouseover=>$focus,-onmouseout=>$blur, -ondblclick=>($filename=~/^\.{1,2}$/ || $isReadable)?qq@window.location.href="$nru";@ : ''}, $row);
		$odd = ! $odd;

		$count++;
		$foldercount++ if !$isUnReadable && -d $full;
		$filecount++ if $isUnReadable || -f $full;
		$filesizes+=$size if $isUnReadable || -f $full;

		##$list .= $tablehead if $count % 50 == 0;

	}
	$list .= $tablehead if $count > 20; ## && $count % 50 != 0 && $count % 50 > 20;
	$content .= $pagenav;
	$content .= $cgi->start_table({-class=>'filelist'}).$list.$cgi->end_table();
	$content .= $cgi->div({-class=>'folderstats'},sprintf("%s %d, %s %d, %s %d, %s %d Bytes (= %.2f KB = %.2f MB = %.2f GB)", _tl('statfiles'), $filecount, _tl('statfolders'), $foldercount, _tl('statsum'), $count, _tl('statsize'), $filesizes, $filesizes/1024, $filesizes/1048576, $filesizes/1073741824)) if ($SHOW_STAT); 

	$content .= $pagenav;
	return ($content, $count);
}
sub renderFileActions {
	my ($fid, $file, $full) = @_;
	my @values = ('--','rename','edit','zip','delete');
	my %labels = ( '--'=> '', rename=>_tl('movefilesbutton'),edit=>_tl('editbutton'),delete=>_tl('deletefilesbutton'), zip=>_tl('zipdownloadbutton') );
	my %attr;
	if (!$IGNOREFILEPERMISSIONS && ! -w $full) {
		$attr{rename}{disabled}='disabled';
		$attr{delete}{disabled}='disabled';
	}
	if (!$IGNOREFILEPERMISSIONS && ! -r $full) {
		$attr{zip}{disabled}='disabled';
	}

	if ($ALLOW_EDIT) {
		my $ef = '('.join('|',@EDITABLEFILES).')';
		$attr{edit}{disabled}='disabled' unless basename($file) =~/$ef/i && ($IGNOREFILEPERMISSIONS || (-f $full && -w $full));
	} else {
		@values = grep(!/^edit$/,@values);
	}

	return $cgi->popup_menu(-name=>'actions', -id=>'fileactions_'.$fid, -onchange=>"handleFileAction(this.value,'$fid',event,'select');", -values=>\@values, -labels=>\%labels, -attributes=>\%attr);
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
		print LOG localtime()." - $<($REMOTE_USER)\@$ENV{REMOTE_ADDR}: @_\n";
		close(LOG);
	} else {
		print STDERR "$0: @_\n";
	}
}
sub readTL  {
	my ($l) = @_;
	my $fn = -e "${INSTALL_BASE}webdav-ui_${l}.msg" ? "${INSTALL_BASE}webdav-ui_${l}.msg" : -e "${INSTALL_BASE}locale/webdav-ui_${l}.msg" ? "${INSTALL_BASE}locale/webdav-ui_${l}.msg" : undef;
	return unless defined $fn;
	if (open(I, "<$fn")) { 
		while (<I>) {
			chomp;
			next if /^#/;
			$TRANSLATION{$l}{$1}=$2 if /^(\S+)\s+"(.*)"\s*$/;
		}
		close(I);
	} else { warn("Cannot read $fn!"); }
	$TRANSLATION{$l}{x__READ__x}=1;
}
sub _tl {
	readTL('default') if !exists $TRANSLATION{default}{x__READ__x};
	readTL($LANG) if !exists $TRANSLATION{$LANG}{x__READ__x};
	my $key = $_[0];
	my $val = $TRANSLATION{$LANG}{$key} || $TRANSLATION{default}{$key} || $key;
	shift @_;
	return $#_>-1 ? sprintf( $val, @_) : $val;
}
sub createMsgQuery {
	my ($msg,$msgparam,$errmsg,$errmsgparam,$prefix) = @_;
	$prefix='' unless defined $prefix;
	my $query ="";
	$query.=";${prefix}msg=$msg" if defined $msg;
	$query.=";$msgparam" if $msgparam;
	$query.=";${prefix}errmsg=$errmsg" if defined $errmsg;
	$query.=";$errmsgparam" if defined $errmsg && $errmsgparam;
	return "?t=".time().$query;
}
sub start_html {
	my ($title) = @_;
	my $content ="";
	$content.="<!DOCTYPE html>\n";
	$content.='<head><title>'.$cgi->escapeHTML($title).'</title>';
	$content.=qq@<meta http-equiv="Content-Type" content="text/html; charset=$CHARSET"/>@;
	$content.=qq@<meta name="author" content="Daniel Rohde"/>@;

	my $js='function tl(k) { var tl = new Array();';
	foreach my $usedtext (('bookmarks','addbookmark','rmbookmark','addbookmarktitle','rmbookmarktitle','rmallbookmarks','rmallbookmarkstitle','sortbookmarkbypath','sortbookmarkbytime','rmuploadfield','rmuploadfieldtitle','deletefileconfirm', 'movefileconfirm', 'cancel', 'confirm')) {
		$js.= qq@tl['$usedtext']='@._tl($usedtext).qq@';@;
	}
	$js.=' return tl[k] ? tl[k] : k; }';
	$js.=qq@var REQUEST_URI = '$REQUEST_URI';@;
	$js.=qq@var MAXFILENAMESIZE= '$MAXFILENAMESIZE';@;
	
	$REQUEST_URI=~/^($VIRTUAL_BASE)/;
	my $base = $1;
	$base.='/' unless $base=~/\/$/;
	$content.=qq@<link rel="search" type="application/opensearchdescription+xml" title="WebDAV CGI filename search" href="$REQUEST_URI?action=opensearch"/>@ if $ALLOW_SEARCH;
	$content.=qq@<link rel="alternate" href="$REQUEST_URI?action=mediarss" type="application/rss+xml" title="" id="gallery"/>@ if $ENABLE_THUMBNAIL;
	$content.=qq@<link href="${base}webdav-ui.css" rel="stylesheet" type="text/css"/>@;
	$content.=qq@<link href="${base}webdav-ui-custom.css" rel="stylesheet" type="text/css"/>@ if -e "${INSTALL_BASE}lib/webdav-ui-custom.css" || ($ENABLE_COMPRESSION && -e "${INSTALL_BASE}lib/webdav-ui-custom.css.gz");
	$content.=qq@<style type="text/css">$CSS</style>@ if defined $CSS;
	$content.=qq@<link href="$CSSURI" rel="stylesheet" type="text/css"/>@ if defined $CSSURI;
	$content.=qq@<script type="text/javascript">$js</script><script src="${base}webdav-ui.js" type="text/javascript"></script>@;
	$content.=qq@<link href="${base}webdav-ui-custom.js" rel="stylesheet" type="text/css"/>@ if -e "${INSTALL_BASE}lib/webdav-ui-custom.js";
	$content.=$HTMLHEAD if defined $HTMLHEAD;
	$content.=qq@</head><body onload="check()">@;
	return $content;
}
sub renderNameFilterForm {
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
			.$cgi->div(_tl('afsaclscurrentfolder',$PATH_TRANSLATED, $REQUEST_URI))
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
	my $ru = $REMOTE_USER;
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
sub replaceVars {
	my ($t) = @_;
	$t=~s/\${?NOW}?/strftime(_tl('varnowformat'), localtime())/eg;
	$t=~s/\${?TIME}?/strftime(_tl('vartimeformat'), localtime())/eg;
	$t=~s/\${?USER}?/$REMOTE_USER/g;
	$t=~s/\${?REQUEST_URI}?/$REQUEST_URI/g;
	$t=~s/\${?PATH_TRANSLATED}?/$PATH_TRANSLATED/g;
	$t=~s/\${?ENV{([^}]+?)}}?/$ENV{$1}/eg;
	my $clockfmt = _tl('vartimeformat');
	$t=~s@\${?CLOCK}?@<span id="clock"></span><script>startClock('clock','$clockfmt');</script>@;
	$t=~s/\${?LANG}?/$LANG/g;
	$t=~s/\${?TL{([^}]+)}}?/_tl($1)/eg;

	$REQUEST_URI =~ /^($VIRTUAL_BASE)/;
	my $vbase= $1;
	$t=~s/\${?VBASE}?/$vbase/g;
	$t=~s/\${?VHTDOCS}?/$vbase$VHTDOCS/g;

	return $t;
}
sub renderSysInfo {
	my $i = "";
	$i.= start_html();
	
	$i.= $cgi->h1('WebDAV CGI SysInfo');
	$i.= $cgi->h2('Process - '.$0);
	$i.= $cgi->start_table()
             .$cgi->Tr($cgi->td('BASETIME').$cgi->td(''.localtime($^T)))
             .$cgi->Tr($cgi->td('OSNAME').$cgi->td($^O))
             .$cgi->Tr($cgi->td('PID').$cgi->td($$))
	     .$cgi->Tr($cgi->td('REAL UID').$cgi->td($<))
             .$cgi->Tr($cgi->td('EFFECTIVE UID').$cgi->td($>))
             .$cgi->Tr($cgi->td('REAL GID').$cgi->td($())
	     .$cgi->Tr($cgi->td('EFFECTIVE GID').$cgi->td($)))
	     
	     .$cgi->end_table();
        $i.= $cgi->h2('Perl');
	$i.= $cgi->start_table()
		.$cgi->Tr($cgi->td('version').$cgi->td(sprintf('%vd',$^V)))
		.$cgi->Tr($cgi->td('debugging').$cgi->td($^D))
                .$cgi->Tr($cgi->td('taint mode').$cgi->td(${^TAINT}))
                .$cgi->Tr($cgi->td('unicode').$cgi->td(${^UNICODE}))
                .$cgi->Tr($cgi->td('warning').$cgi->td($^W))
                .$cgi->Tr($cgi->td('executable name').$cgi->td($^X))
		.$cgi->end_table();
	$i.= $cgi->h2('Includes');
	$i.= $cgi->start_table();
	foreach my $e (sort keys %INC) {
		$i.=$cgi->Tr($cgi->td($e).$cgi->td($ENV{$e}));
	}
	$i.= $cgi->end_table();

	$i.= $cgi->h2('System Times');
	my ($user,$system,$cuser,$csystem) = times;
	$i.=  $cgi->start_table()
	     .$cgi->Tr($cgi->td('user (s)').$cgi->td($user))
	     .$cgi->Tr($cgi->td('system (s)').$cgi->td($system))
             .$cgi->Tr($cgi->td('cuser (s)').$cgi->td($cuser))
	     .$cgi->Tr($cgi->td('csystem (s)').$cgi->td($csystem))
	     .$cgi->end_table();
	$i.= $cgi->h2('Environment');
	$i.= $cgi->start_table();
	foreach my $e (sort keys %ENV) {
		$i.=$cgi->Tr($cgi->td($e).$cgi->td($ENV{$e}));
	}
	$i.= $cgi->end_table();
	
	$i.=$cgi->end_html();

	return $i;
}
sub getIcon {
	my ($type) = @_;
	return replaceVars(exists $ICONS{$type} ? $ICONS{$type} : $ICONS{default});
}
sub setLocale {
	my $locale;
	if ($LANG eq 'default') {
        	$locale = "en_US.\U$CHARSET\E" 
	} else {
		$LANG =~ /^(\w{2})(_(\w{2})(\.(\S+))?)?$/;
		my ($c1,$c,$c3,$c4,$c5) = ($1, $2, $3, $4, $5);
		$c3 = uc($c1) unless $c3;
		$c5 = uc($CHARSET) unless $c5 && uc($c5) eq uc($CHARSET);
		$locale = "${c1}_${c3}.${c5}";
	}
	setlocale(LC_COLLATE, $locale); 
	setlocale(LC_TIME, $locale); 
	setlocale(LC_CTYPE, $locale); 
	setlocale(LC_NUMERIC, $locale);
}
sub debug {
	print STDERR "$0: @_\n" if $DEBUG;
}
