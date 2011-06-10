#!/usr/bin/perl -d:NYTProf
###!/usr/bin/perl 
###!/usr/bin/speedy  -- -r20 -M5
###!/usr/bin/perl -d:NYTProf
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
# VERSION 0.7.1-BETA
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
use strict;
#use warnings;
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
            $ENABLE_BIND $ALLOW_CHANGEPERM $ALLOW_CHANGEPERMRECURSIVE $LANGSWITCH
            $PERM_USER $PERM_GROUP $PERM_OTHERS
            $DBI_PERSISTENT
            $FILECOUNTLIMIT %FILECOUNTPERDIRLIMIT %FILEFILTERPERDIR 
            $MIMEFILE $CSS $ENABLE_THUMBNAIL_PDFPS
	    $ENABLE_FLOCK  $AFSQUOTA $CSSURI $HTMLHEAD $ENABLE_CLIPBOARD
	    $LIMIT_FOLDER_DEPTH $AFS_FSCMD $ENABLE_AFSACLMANAGER $ALLOW_AFSACLCHANGES @PROHIBIT_AFS_ACL_CHANGES_FOR
            $AFS_PTSCMD $ENABLE_AFSGROUPMANAGER $ALLOW_AFSGROUPCHANGES 
            $WEB_ID $ENABLE_BOOKMARKS $ENABLE_AFS $ORDER $ENABLE_NAMEFILTER @PAGE_LIMITS
            $ENABLE_SIDEBAR $VIEW $ENABLE_PROPERTIES_VIEWER $SHOW_CURRENT_FOLDER $SHOW_CURRENT_FOLDER_ROOTONLY $SHOW_PARENT_FOLDER
            $SHOW_FILE_ACTIONS $REDIRECT_TO $INSTALL_BASE $ENABLE_DAVMOUNT @EDITABLEFILES $ALLOW_EDIT $ENABLE_SYSINFO $VHTDOCS $ENABLE_COMPRESSION
	    @UNSELECTABLE_FOLDERS $TITLEPREFIX @AUTOREFRESHVALUES %UI_ICONS $FILE_ACTIONS_TYPE $BACKEND %SMB %DBB $ALLOW_SYMLINK
	    @VISIBLE_TABLE_COLUMNS @ALLOWED_TABLE_COLUMNS 
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

## -- MIMEFILE
## path to your MIME types file
## EXAMPLE: $MIMEFILE = '/etc/mime.types';
$MIMEFILE = $INSTALL_BASE.'/etc/mime.types';

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
## MIME icons for fancy indexing 
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

## -- UI_ICONS
## user interface icons
## ("$VHTDOCS" will be replaced by "$VIRTUAL_HOST$VHTDOCS")
%UI_ICONS = (
	rename => '${VHTDOCS}actions/Actions-edit-rename-icon.png',
	##edit => '${VHTDOCS}actions/txt-icon.png',
	edit => '${VHTDOCS}actions/desktop-icon.png',
	zip => '${VHTDOCS}actions/tgz-icon.png',
	delete => '${VHTDOCS}actions/trashcan-full-icon.png',
	props => '${VHTDOCS}actions/readme-icon.png',
);

## -- ALLOW_EDIT
## allow changing text files (@EDITABLEFILES) with the Web interface
$ALLOW_EDIT = 1;

## -- EDITABLEFILES
## text file names (regex; case insensitive)
@EDITABLEFILES = ( '\.(txt|php|s?html?|tex|inc|cc?|java|hh?|ini|pl|pm|py|css|js|inc|csh|sh|tcl|tk|tex|ltx|sty|cls|vcs|vcf|ics|csv|mml|asc|text|pot|brf|asp|p|pas|diff|patch|log|conf|cfg|sgml|xml|xslt|bat|cmd|wsf|cgi|sql)$', 
		'^(\.ht|readme|changelog|todo|license|gpl|install|manifest\.mf)' );

## -- ICON_WIDTH
## specifies the icon width for the folder listings of the Web interface
## DEFAULT: $ICON_WIDTH = 18;
$ICON_WIDTH = 18;


## -- TITLEPREFIX
## defines a prefix for the page title of the Web interface
## EXAMPLE: $TITLEPREFIX='WebDAV CGI:';
$TITLEPREFIX='WebDAV CGI:';

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

## -- ALLOW_SYMLINK
## enable symbolic link support
$ALLOW_SYMLINK = 1;

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

## -- @ALLOWED_TABLE_COLUMNS
## defines the allowed columns for the file list in the Web interface
## supported values: name, lastmodified, created, size, mode, mime, fileaction
@ALLOWED_TABLE_COLUMNS = ('name','lastmodified','created','size','mode','mime');
push @ALLOWED_TABLE_COLUMNS, 'fileactions' if $ALLOW_FILE_MANAGEMENT;

## -- @VISIBLE_TABLE_COLUMNS
## defines the visible columns for the file list in the Web interface
## supported values (see @ALLOWED_TABLE_COLUMNS)
@VISIBLE_TABLE_COLUMNS = ('name','lastmodified','size','mode' );
push @VISIBLE_TABLE_COLUMNS, 'fileactions' if $ALLOW_FILE_MANAGEMENT;

## -- SHOW_FILE_ACTIONS
## show file actions column
$SHOW_FILE_ACTIONS = 1;

## -- FILE_ACTIONS_TYPE
## select the file action type: 'icons' or form 'select'
## EXAMPLE: $FILE_ACTIONS_TYPE = 'select';
$FILE_ACTIONS_TYPE = 'icons';

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
$HEADER = '<div class="header">WebDAV CGI - Web interface: You are logged in as $USER.<div style="float:right;font-size:0.8em;">$NOW</div></div>';

## -- SIGNATURE
## for fancy indexing
## EXAMPLE: $SIGNATURE=$ENV{SERVER_SIGNATURE};
$SIGNATURE = '&copy; ZE CMS, Humboldt-Universit&auml;t zu Berlin | Written 2010-2011 by <a href="http://webdavcgi.sf.net/">Daniel Rohde</a>';


## -- AUTOREFRESHVALUES 
## values (seconds; 0 = off) for the autorefresh feature of the Web interface
## EXAMPLE: @AUTOREFRESHVALUES = (0, 10, 30, 60, 300, 600);
@AUTOREFRESHVALUES = ( 0, 10, 30, 60, 300, 600);

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

## -- ENABLE_AFS -- obsolete - use $BACKEND = 'AFS' instead
## to enable AFS support set: $BACKEND = 'AFS';
## $ENABLE_AFS is only used to enable AFS ACL manager and AFS group manager
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
## Note: all listed folders are not CalDAV enabled; 
##       you must create and use subfolders for calendars
%CALENDAR_HOME_SET = ( default=> '/', );

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

## -- ENABLE_FLOCK
## enables file locking support (flock) for PUT/POST uploads to respect existing locks and to set locks for files to change
$ENABLE_FLOCK = 1;

## -- LIMIT_FOLDER_DEPTH
## limits the depth a folder is visited for copy/move operations
$LIMIT_FOLDER_DEPTH = 20;


## -- BACKEND
## defines the WebDAV/Web interface backend (see $INSTALL_BASE/lib/perl/Backend/<BACKEND> for supported backends)
$BACKEND =  $ENABLE_AFS ? 'AFS' : 'FS';

## -- SMB
## SMB backend configuration (see docs/smb.html):
%SMB = ();

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
use vars qw( $cgi $method $backend $backendmanager $config $utils %known_coll_props %known_file_props %known_filecoll_props %unsupported_props);
use CGI;

## flush immediately:
$|=1;

## before 'new CGI' to read POST requests:
$ENV{REQUEST_METHOD}=$ENV{REDIRECT_REQUEST_METHOD} if (defined $ENV{REDIRECT_REQUEST_METHOD}) ;

$CGI::POST_MAX = $POST_MAX_SIZE;
$CGI::DISABLE_UPLOADS = $ALLOW_POST_UPLOADS?0:1;

## create CGI instance
$cgi = $ENV{REQUEST_METHOD} eq 'PUT' ? new CGI({}) : new CGI;

if (defined $CONFIGFILE) {
	unless (my $ret = do($CONFIGFILE)) {
		warn "couldn't parse $CONFIGFILE: $@" if $@;
		warn "couldn't do $CONFIGFILE: $!" unless defined $ret;
		warn "couldn't run $CONFIGFILE" unless $ret;
	}
}

use POSIX qw(strftime);

use XML::Simple;

use URI::Escape;
use UUID::Tiny;
use Digest::MD5;

use IO::Compress::Gzip qw(gzip);
use IO::Compress::Deflate qw(deflate);

$method = $cgi->request_method();

use RequestConfig;
$config = new RequestConfig($cgi);

use Backend::Manager;
$backendmanager = new Backend::Manager;
$backend = $backendmanager->getBackend($BACKEND);
$config->setProperty('backend',$backend);

use Utils;
$utils = new Utils();
$config->setProperty('utils',$utils);

 
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

$PATH_TRANSLATED.='/' if $backend->isDir($PATH_TRANSLATED) && $PATH_TRANSLATED !~ /\/$/; 
$REQUEST_URI=~s/\?.*$//; ## remove query strings
$REQUEST_URI.='/' if $backend->isDir($PATH_TRANSLATED) && $REQUEST_URI !~ /\/$/;

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


map { $known_coll_props{$_} = 1; $known_filecoll_props{$_} = 1; } @KNOWN_COLL_PROPS;
map { $known_file_props{$_} = 1; $known_filecoll_props{$_} = 1; } @KNOWN_FILE_PROPS;
map { $unsupported_props{$_} = 1; } @UNSUPPORTED_PROPS;

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
	} elsif (!$FANCYINDEXING && $backend->isDir($fn)) {
		if (defined $REDIRECT_TO) {
			print $cgi->redirect($REDIRECT_TO);
		} else {
			printHeaderAndContent('404 Not Found','text/plain','404 - NOT FOUND');
		}
	} elsif ($FANCYINDEXING && getWebInterface()->handleGetRequest()) {
		debug("_GET: WebInterface called");
	} elsif ($backend->exists($fn) && !$backend->isReadable($fn)) {
		printHeaderAndContent('403 Forbidden','text/plain', '403 Forbidden');
	} elsif ($backend->exists($fn)) {
		debug("_GET: DOWNLOAD");
		binmode(STDOUT);
		my $enc = $cgi->http('Accept-Encoding');
		my $mime = getMIMEType($fn);
		my @stat = $backend->stat($fn);
		if ($ENABLE_COMPRESSION && $enc && $enc=~/(gzip|deflate)/ && $stat[7] > 1023 && $mime=~/^(text\/(css|html)|application\/(x-)?javascript)$/i && open(my $F, "<".$backend->getLocalFilename($fn))) {
				print $cgi->header( -status=>'200 OK',-type=>$mime, -ETag=>getETag($fn), -Last_Modified=>strftime("%a, %d %b %Y %T GMT" ,gmtime($stat[9])), -charset=>$CHARSET, -Content_Encoding=>$enc=~/gzip/?'gzip':'deflate');
				if ($enc =~ /gzip/i) {
					gzip $F => \*STDOUT;
				} elsif ($enc =~ /deflate/i) {
					deflate $F => \*STDOUT;
				}
				close($F);
		} else {
			printFileHeader($fn);
			$backend->printFile($fn, \*STDOUT);
		}
	} else {
		debug("GET: $fn NOT FOUND!");
		printHeaderAndContent('404 Not Found','text/plain','404 - FILE NOT FOUND');
	}
	
}
sub _HEAD {
	if ($FANCYINDEXING && getWebInterface()->handleHeadRequest()) {
		debug("_HEAD: WebInterface called");
	} elsif ($backend->exists($PATH_TRANSLATED)) {
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
	if ($ALLOW_FILE_MANAGEMENT && getWebInterface()->handlePostRequest()) {
		debug("_POST: WebInterface called");
	} elsif ($ENABLE_CALDAV_SCHEDULE && $backend->isDir($PATH_TRANSLATED)) {
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
	if ($backend->exists($PATH_TRANSLATED)) {
		$type = $backend->isDir($PATH_TRANSLATED) ? 'httpd/unix-directory' : getMIMEType($PATH_TRANSLATED);
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
	if (!$backend->exists($fn)) {
		$status='404 Not Found';
		$type='text/plain';
	} else {
		my $su = $ENV{SCRIPT_URI};
		$su=~s/\/[^\/]+$/\// if !$backend->isDir($fn);
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

	if (!is_hidden($fn) && $backend->exists($fn)) {
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
	if ($backend->exists($fn) && !isAllowed($fn)) {
		$status = '423 Locked';
	} elsif ($backend->exists($fn)) {
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

	if (defined $cgi->http('Content-Range'))  {
		$status='501 Not Implemented';
	} elsif ($backend->isDir($backend->getParent(($PATH_TRANSLATED))) && !$backend->isWriteable($backend->getParent(($PATH_TRANSLATED)))) {
		$status='403 Forbidden';
	} elsif (preConditionFailed($PATH_TRANSLATED)) {
		$status='412 Precondition Failed';
	} elsif (!isAllowed($PATH_TRANSLATED)) {
		$status='423 Locked';
	#} elsif (defined $ENV{HTTP_EXPECT} && $ENV{HTTP_EXPECT} =~ /100-continue/) {
	#	$status='417 Expectation Failed';
	} elsif ($backend->isDir($backend->getParent(($PATH_TRANSLATED)))) {
		if (! $backend->exists($PATH_TRANSLATED)) {
			debug("_PUT: created...");
			$status='201 Created';
			$type='text/html';
			$content = qq@<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">\n<html><head><title>201 Created</title></head>@
				 . qq@<<body><h1>Created</h1><p>Resource $ENV{'QUERY_STRING'} has been created.</p></body></html>\n@;
		}
		if ($backend->saveStream($PATH_TRANSLATED, \*STDIN)) {
			inheritLock();
			logger("PUT($PATH_TRANSLATED)");
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
	} elsif ( $backend->exists($destination) && $overwrite eq "F") {
		$status = '412 Precondition Failed';
	} elsif ( ! $backend->isDir($backend->getParent(($destination)))) {
		$status = "409 Conflict - $destination";
	} elsif ( !isAllowed($destination,$backend->isDir($PATH_TRANSLATED)) ) {
		$status = '423 Locked';
	} elsif ( $backend->isDir($PATH_TRANSLATED) && $depth == 0 ) {
		if ($backend->exists($destination)) {
			$status = '204 No Content' ;
		} else {
			if ($backend->mkcol($destination)) {
				inheritLock($destination);
			} else {
				$status = '403 Forbidden (mkcol($destination) failed)';
			}
		}
	} else {
		$status = '204 No Content' if $backend->exists($destination);
		if (rcopy($PATH_TRANSLATED, $destination)) {
			inheritLock($destination,1);
			logger("COPY($PATH_TRANSLATED, $destination)");
		} else {
			$status = "403 Forbidden - copy failed (rcopy($PATH_TRANSLATED,$destination))";
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
	} elsif ( $backend->exists($destination) && $overwrite eq "F") {
		$status = '412 Precondition Failed';
	} elsif ( ! $backend->isDir($backend->getParent($destination))) {
		$status = '409 Conflict';
	} elsif (!isAllowed($PATH_TRANSLATED,$backend->isDir($PATH_TRANSLATED)) || !isAllowed($destination, $backend->isDir($destination))) {
		$status = '423 Locked';
	} else {
		$backend->unlinkFile($destination) if $backend->exists($destination) && $backend->isFile($destination);
		$status = '204 No Content' if $backend->exists($destination);
		if (rmove($PATH_TRANSLATED, $destination)) {
			my $db = getDBDriver();
			$db->db_moveProperties($PATH_TRANSLATED, $destination);
			$db->db_delete($PATH_TRANSLATED);
			inheritLock($destination,1);
			logger("MOVE($PATH_TRANSLATED, $destination)");
		} else {
			$status = "403 Forbidden (rmove($PATH_TRANSLATED, $destination) failed)";
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
	if (!$backend->exists($PATH_TRANSLATED)) {
		$status='404 Not Found';
	} elsif (($REQUEST_URI=~/\#/ && $PATH_TRANSLATED!~/\#/) || (defined $ENV{QUERY_STRING} && $ENV{QUERY_STRING} ne "")) {
		$status='400 Bad Request';
	} elsif (!isAllowed($PATH_TRANSLATED)) {
		$status='423 Locked';
	} else {
		if ($ENABLE_TRASH) {
			$status='404 Forbidden' unless $backend->moveToTrash($PATH_TRANSLATED);
		} else {
			$backend->deltree($PATH_TRANSLATED, \my @err);
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
	if ($backend->exists($PATH_TRANSLATED)) {
		debug("_MKCOL: folder exists (405 Method Not Allowed)!");
		$status = '405 Method Not Allowed (folder exists)';
	} elsif (!$backend->exists($backend->getParent($PATH_TRANSLATED))) {
		debug("_MKCOL: parent does not exists (409 Conflict)!");
		$status = '409 Conflict';
	} elsif (!$backend->isWriteable($backend->getParent($PATH_TRANSLATED))) {
		debug("_MKCOL: parent is not writeable (403 Forbidden)!");
		$status = '403 Forbidden';
	} elsif (!isAllowed($PATH_TRANSLATED)) {
		debug("_MKCOL: not allowed!");
		$status = '423 Locked';
	} elsif ($backend->isDir($backend->getParent($PATH_TRANSLATED))) {
		debug("_MKCOL: create $PATH_TRANSLATED");

		if ($backend->mkcol($PATH_TRANSLATED)) {
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

	if (!$backend->exists($fn) && !$backend->exists($backend->getParent($fn))) {
		$status='409 Conflict';
		$type='text/plain';
	} elsif (!getLockModule()->isLockable($fn, $xmldata)) {
		debug("_LOCK: not lockable ... but...");
		if (isAllowed($fn)) {
			$status='200 OK';
			getLockModule()->lockResource($fn, $ru, $xmldata, $depth, $timeout, $token);
			$content = createXML({prop=>{lockdiscovery => getLockDiscovery($fn)}});	
		} else {
			$status='423 Locked';
			$type='text/plain';
		}
	} elsif (!$backend->exists($fn)) {
		if ($backend->saveData($fn,'')) {
			my $resp = getLockModule()->lockResource($fn, $ru, $xmldata, $depth, $timeout,$token);
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
		my $resp = getLockModule()->lockResource($fn, $ru, $xmldata, $depth, $timeout, $token);
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
	} elsif (getLockModule()->isLocked($PATH_TRANSLATED)) {
		if (getLockModule()->unlockResource($PATH_TRANSLATED, $token)) {
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
	} elsif (!$backend->exists($fn)) {
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
			my @stat = $backend->stat($fn);
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
			if (!$backend->changeMod($fn, $newperm)) {
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
	} elsif (!$backend->exists($fn) && $ru ne $CURRENT_USER_PRINCIPAL) {
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
				if (!$backend->exists($nfn)) {
					push @resps, { href=>$href, status=>'HTTP/1.1 404 Not Found' };
					next;
				} elsif ($backend->isDir($nfn)) {
					push @resps, { href=>$href, status=>'HTTP/1.1 403 Forbidden' };
					next;
				}
				my @props;
				handlePropElement($$xmldata{$rn}{'{DAV:}prop'}, \@props) if exists $$xmldata{$rn}{'{DAV:}prop'};
				push @resps, { href=>$href, propstat=> getPropStat($nfn,$nhref,\@props) };
			}
			### push @resps, { } if ($#hrefs==-1);  ## empty multistatus response not supported
		}
		$content= $#resps> -1 ? createXML({multistatus => $#resps>-1 ? { response => \@resps } : '' }) : '<?xml version="1.0" encoding="UTF-8"?><D:multistatus xmlns:D="DAV:"></D:multistatus>';
	}
	debug("_REPORT: REQUEST: $xml");
	debug("_REPORT: RESPONSE: $content");
	printHeaderAndContent($status, $type, $content);
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
		require WebDAV::Search;
		(new WebDAV::Search($config))->getSchemaDiscovery($REQUEST_URI, \@resps);
	} elsif (exists $$xmldata{'{DAV:}searchrequest'}) {
		require WebDAV::Search;
		foreach my $s (keys %{$$xmldata{'{DAV:}searchrequest'}}) {
			if ($s =~ /{DAV:}basicsearch/) {
				(new WebDAV::Search($config))->handleBasicSearch($$xmldata{'{DAV:}searchrequest'}{$s}, \@resps,\@errors);
			}
		}
	}
	if ($#errors>-1) {
		$content = createXML({error=>\@errors});
		$status='409 Conflict';
	} elsif ($#resps > -1) {
		$content = createXML({multistatus=>{ response=>\@resps }});
	} else {
		$content = createXML({multistatus=>{ }}); ## rfc5323 allows empty multistatus
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

		if (!$backend->exists($src)) { 
			$status ='404 Not Found';
		} elsif ($backend->exists($dst) && ! $backend->isLink($ndst)) {
			$status = '403 Forbidden';
		} elsif ($backend->exists($dst) && $backend->isLink($ndst) && $overwrite eq "F") {
			$status = '403 Forbidden';
		} else {
			$status = $backend->isLink($ndst) ? '204 No Content' : '201 Created';
			$backend->unlinkFile($ndst) if $backend->isLink($ndst);
			$status = '403 Forbidden' if (!$backend->createSymLink($src, $dst));
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
		if (!$backend->exists($dst) ) {
			$status = '404 Not Found';
		} elsif (!$backend->isLink($dst)) {
			$status = '403 Forbidden';
		} elsif (!$backend->unlinkFile($dst)) {
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

		if (!$backend->exists($src)) {
			$status = '404 Not Found';
		} elsif (!$backend->isLink($nsrc)) { 
			$status = '403 Forbidden';
		} elsif ($backend->exists($dst) && $overwrite ne 'T') {
			$status = '403 Forbidden';
		} elsif ($backend->exists($dst) && !$backend->isLink($ndst)) {
			$status = '403 Forbidden';
		} else {
			$status = $backend->isLink($ndst) ? '204 No Content' : '201 Created';
			$backend->unlinkFile($ndst) if $backend->isLink($ndst);
			if (!rmove($nsrc, $ndst)) { ### check rename->rmove OK?
				my $orig = $backend->getLinkSrc($nsrc);
				$status = '403 Forbidden' unless $backend->createSymLink($orig, $dst) && $backend->unlinkFile($nsrc);
			}
		}
	}
	printHeaderAndContent($status, $type, $content);
}

sub readDirBySuffix {
	my ($fn, $base, $hrefs, $suffix, $depth, $visited) = @_;
	debug("readDirBySuffix($fn, ..., $suffix, $depth)");

	my $nfn = $backend->resolve($fn);
	return if exists $$visited{$nfn} && ($depth eq 'infinity' || $depth < 0);
	$$visited{$nfn}=1;

	if ($backend->isReadable($fn)) {
		foreach my $sf (@{$backend->readDir($fn, getFileLimit($fn), $utils)}) {
			$sf.='/' if $backend->isDir($fn.$sf);
			my $nbase=$base.$sf;
			push @{$hrefs}, $nbase if $backend->isFile($fn.$sf) && $sf =~ /\.\Q$suffix\E/;
			readDirBySuffix($fn.$sf, $nbase, $hrefs, $suffix, $depth - 1, $visited) if $depth!=0 && $backend->isDir($fn.$sf);
			## XXX add only files with requested components 
			## XXX filter (comp-filter > comp-filter >)
		}
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
		##} elsif (grep(/\Q$nons\E/, @KNOWN_FILE_PROPS, @KNOWN_COLL_PROPS)>0)  {
		} elsif (exists $known_filecoll_props{$nons}) {
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

	my $isReadable = $backend->isReadable($fn);

	my $nfn = $isReadable ? $backend->resolve($fn) : $fn;

	my @stat = $isReadable ? $backend->stat($fn) : ();
	my %resp_200 = (status=>'HTTP/1.1 200 OK');
	my %resp_404 = (status=>'HTTP/1.1 404 Not Found');

	my $isDir = $backend->isDir($nfn);

	$fn .= '/' if $isDir && $fn!~/\/$/;
	foreach my $prop (@{$props}) {
		my ($xmlnsuri,$propname) = ('DAV:',$prop);
		if ($prop=~/^{([^}]*)}(.*)$/) {
			($xmlnsuri, $propname) = ($1,$2);
		} 
		#if (grep(/^\Q$propname\E$/,@UNSUPPORTED_PROPS) >0) {
		if (exists $unsupported_props{$propname}) {
			debug("getPropStat: UNSUPPORTED: $propname");
			$resp_404{prop}{$prop}=undef;
			next;
		} elsif (( !defined $NAMESPACES{$xmlnsuri} || grep(/^\Q$propname\E$/,$isDir?@KNOWN_COLL_LIVE_PROPS:@KNOWN_FILE_LIVE_PROPS)>0 ) && grep(/^\Q$propname\E$/,@PROTECTED_PROPS)==0) { 
			my $dbval = getDBDriver()->db_getProperty($fn, $prop=~/{[^}]*}/?$prop:'{'.getNameSpaceUri($prop)."}$prop");
			if (defined $dbval) {
				$resp_200{prop}{$prop}=$noval?undef:$dbval;
				next;
			} elsif (grep(/^\Q$propname\E$/,$isDir?@KNOWN_COLL_LIVE_PROPS:@KNOWN_FILE_LIVE_PROPS)==0) {
				debug("getPropStat: #1 NOT FOUND: $prop ($propname, $xmlnsuri)");
				$resp_404{prop}{$prop}=undef;
			}
		} 
		##if (grep(/^\Q$propname\E$/, $isDir ? @KNOWN_COLL_PROPS : @KNOWN_FILE_PROPS)>0) {
		if ( ( $isDir ? exists $known_coll_props{$propname} : exists $known_file_props{$propname}) ) {
			if ($noval) { 
				$resp_200{prop}{$prop}=undef;
			} else {
				getPropertyModule()->getProperty($fn, $uri, $prop, \@stat, \%resp_200,\%resp_404);
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
sub cmp_elements {
	my $aa = $ELEMENTORDER{$a} || $ELEMENTORDER{default};
	my $bb = $ELEMENTORDER{$b} || $ELEMENTORDER{default};
	return $aa <=> $bb || $a cmp $b;
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

sub getETag {
	my ($file) = @_;
	$file = $PATH_TRANSLATED unless defined $file;
	my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size, $atime,$mtime,$ctime,$blksize,$blocks) = $backend->stat($file);
	my $digest = new Digest::MD5;
	$digest->add($file);
	$digest->add($size || 0);
	$digest->add($mtime || 0);
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
sub printLocalFileHeader {
	my ($fn,$addheader) = @_;
	my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size, $atime,$mtime,$ctime,$blksize,$blocks) = stat($fn);
	my %ha = ( -status=>'200 OK',-type=>getMIMEType($fn),  -Content_Length=>$size, -ETag=>getETag($fn), -Last_Modified=>strftime("%a, %d %b %Y %T GMT" ,gmtime($mtime || 0)), -charset=>$CHARSET);
	%ha = (%ha, %{$addheader}) if $addheader;
	my $header = $cgi->header(\%ha);

	$header = "MS-Author-Via: DAV\r\n$header";
	$header = "DAV: $DAV\r\n$header";
	$header = "Translate: f\r\n$header" if defined $cgi->http('Translate');
	print $header;
}
sub printFileHeader {
	my ($fn,$addheader) = @_;
	my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size, $atime,$mtime,$ctime,$blksize,$blocks) = $backend->stat($fn);
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
	my $filter = getHiddenFilter();
	return $filter && $fn =~ /$filter/;
}
sub simpleXMLParser {
	my ($text,$keepRoot) = @_;
	my %param;
	$param{NSExpand}=1;
	$param{KeepRoot}=1 if $keepRoot;
	return XMLin($text,%param);
}
sub getLockDiscovery {
	my ($fn) = @_;

	my $rowsRef = getDBDriver()->db_get($fn);
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
sub preConditionFailed {
	my ($fn) = @_;
	$fn = $backend->getParent($fn).'/' if ! $backend->exists($fn);
	my $ifheader = getIfHeaderComponents($cgi->http('If'));
	my $rowsRef = getDBDriver()->db_get( $fn );
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
	
	$fn = $backend->getParent($fn).'/' if ! $backend->exists($fn);

	return 1 unless $ENABLE_LOCK;
	
	my $ifheader = getIfHeaderComponents($cgi->http('If'));
	my $rowsRef = $recurse ? getDBDriver()->db_getLike("$fn%") : getDBDriver()->db_get( $fn );

	return 0 if $backend->exists($fn) && !$backend->isWriteable($fn); # not writeable
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

	my $nfn = $backend->resolve($fn);
	return if exists $$visited{$nfn};
	$$visited{$nfn}=1;

	my $bfn = $backend->getParent($fn).'/';

	debug("inheritLock: check lock for $bfn ($fn)");
	my $db = getDBDriver();
	my $rows = $db->db_get($bfn);
	return if $#{$rows} == -1 and !$checkContent;
	debug("inheritLock: $bfn is locked") if $#{$rows}>-1;
	if ($checkContent) {
		$rows = $db->db_get($fn);
		return if $#{$rows} == -1;
		debug("inheritLock: $fn is locked");
	}
	my $row = $$rows[0];
	if ($backend->isDir($fn)) {
		debug("inheritLock: $fn is a collection");
		$db->db_insert($$row[0],$fn,$$row[2],$$row[3],$$row[4],$$row[5],$$row[6],$$row[7]);
		if ($backend->isReadable($fn)) {
			foreach my $f (@{$backend->readDir($fn,getFileLimit($fn),$utils)}) {
				my $full = $fn.$f;
				$full .='/' if $backend->isDir($full) && $full !~/\/$/;
				$db->db_insert($$row[0],$full,$$row[2],$$row[3],$$row[4],$$row[5],$$row[6],$$row[7]);
				inheritLock($full,undef,$visited);
			}
		}
	} else {
		$db->db_insert($$row[0],$fn,$$row[2],$$row[3],$$row[4],$$row[5],$$row[6],$$row[7]);
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
			push @tokens, { token=>($1 ? $1 : '').($2 ? $2 : ''), etag=>$4 };
		}
		return {rtag=>$rtag, list=>\@tokens};
	}
	return undef;
}
sub readDirRecursive {
	my ($fn, $ru, $respsRef, $props, $all, $noval, $depth, $noroot, $visited) = @_;
	return if is_hidden($fn);
	my $isReadable = $backend->isReadable($fn);
	my $nfn = $isReadable ?  $backend->resolve($fn) : $fn;
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
	if ($depth!=0 &&  $isReadable && $backend->isDir($nfn) ) {
		if (!defined $FILECOUNTPERDIRLIMIT{$fn} || $FILECOUNTPERDIRLIMIT{$fn}>0) {
			foreach my $f ( @{$backend->readDir($fn, getFileLimit($fn),$utils)}) {
				my $fru=$ru.$cgi->escape($f);
				$isReadable = $backend->isReadable("$nfn/$f");
				my $nnfn = $isReadable ? $backend->resolve("$nfn/$f") : "$nfn/$f";
				$fru.='/' if $isReadable && $backend->isDir($nnfn) && $fru!~/\/$/;
				readDirRecursive($nnfn, $fru, $respsRef, $props, $all, $noval, $depth>0?$depth-1:$depth, 0, $visited);
			}
		}
	}
}
sub handlePropertyRequest {
	my ($xml, $dataRef, $resp_200, $resp_403) = @_;

	if (ref($$dataRef{'{DAV:}remove'}) eq 'ARRAY') {
		foreach my $remove (@{$$dataRef{'{DAV:}remove'}}) {
			foreach my $propname (keys %{$$remove{'{DAV:}prop'}}) {
				getPropertyModule()->removeProperty($propname, $$remove{'{DAV:}prop'}, $resp_200, $resp_403);
			}
		}
	} elsif (ref($$dataRef{'{DAV:}remove'}) eq 'HASH') {
		foreach my $propname (keys %{$$dataRef{'{DAV:}remove'}{'{DAV:}prop'}}) {
			getPropertyModule()->removeProperty($propname, $$dataRef{'{DAV:}remove'}{'{DAV:}prop'}, $resp_200, $resp_403);
		}
	}
	if ( ref($$dataRef{'{DAV:}set'}) eq 'ARRAY' )  {
		foreach my $set (@{$$dataRef{'{DAV:}set'}}) {
			foreach my $propname (keys %{$$set{'{DAV:}prop'}}) {
				getPropertyModule()->setProperty($propname, $$set{'{DAV:}prop'}, $resp_200, $resp_403);
			}
		}
	} elsif (ref($$dataRef{'{DAV:}set'}) eq 'HASH') {
		my $lastmodifiedprocessed = 0;
		foreach my $propname (keys %{$$dataRef{'{DAV:}set'}{'{DAV:}prop'}}) {
			if ($propname eq '{DAV:}getlastmodified' || $propname eq '{urn:schemas-microsoft-com:}Win32LastModifiedTime' ) {
				next if $lastmodifiedprocessed;
				$lastmodifiedprocessed = 1;
			}
			getPropertyModule()->setProperty($propname, $$dataRef{'{DAV:}set'}{'{DAV:}prop'},$resp_200, $resp_403);
		}
	} 
	if ($xml =~ /<([^:]+:)?set[\s>]+.*<([^:]+:)?remove[\s>]+/s) { ## fix parser bug: set/remove|remove/set of the same prop
		if (ref($$dataRef{'{DAV:}remove'}) eq 'ARRAY') {
			foreach my $remove (@{$$dataRef{'{DAV:}remove'}}) {
				foreach my $propname (keys %{$$remove{'{DAV:}prop'}}) {
					getPropertyModule()->removeProperty($propname, $$remove{'{DAV:}prop'}, $resp_200, $resp_403);
				}
			}
		} elsif (ref($$dataRef{'{DAV:}remove'}) eq 'HASH') {
			foreach my $propname (keys %{$$dataRef{'{DAV:}remove'}{'{DAV:}prop'}}) {
				getPropertyModule()->removeProperty($propname, $$dataRef{'{DAV:}remove'}{'{DAV:}prop'}, $resp_200, $resp_403);
			}
		}
	}
}
sub getQuota {
	my ($fn) = @_;
	$fn = $PATH_TRANSLATED unless defined $fn;
	return ($CACHE{getQuota}{$fn}{block_hard}, $CACHE{getQuota}{$fn}{block_curr}) if defined $CACHE{getQuota}{$fn}{block_hard};
	my ($block_hard, $block_curr) = $backend->getQuota($fn);
	$CACHE{getQuota}{$fn}{block_hard}=$block_hard;
	$CACHE{getQuota}{$fn}{block_curr}=$block_curr;
	return ($block_hard,$block_curr);
}
sub getuuid {
        my ($fn) = @_;
	my $uuid_ns = create_UUID(UUID_V1, "opaquelocktoken:$fn");
	my $uuid = create_UUID(UUID_V3, $uuid_ns, "$fn".time());
	return UUID_to_string($uuid);
}
sub getDirInfo {
	my ($fn, $prop, $filter, $limit, $max) = @_;
	return $CACHE{getDirInfo}{$fn}{$prop} if defined $CACHE{getDirInfo}{$fn}{$prop};
	my %counter = ( childcount=>0, visiblecount=>0, objectcount=>0, hassubs=>0 );
	if ($backend->isReadable($fn)) {
		foreach my $f (@{$backend->readDir($fn, $$limit{$fn} || $max, $utils)}) {
			$counter{realchildcount}++;
			$counter{childcount}++;
			$counter{visiblecount}++ if !$backend->isDir("$fn$f") && $f !~/^\./;
			$counter{objectcount}++ if !$backend->isDir("$fn$f");
		}
	}
	$counter{hassubs} = ($counter{childcount}-$counter{objectcount} > 0 )? 1:0;

	foreach my $k (keys %counter) {
		$CACHE{getDirInfo}{$fn}{$k}=$counter{$k};
	}
	return $counter{$prop} || 0;
}
sub getNameSpace {
	return $ELEMENTS{$_[0]} || $ELEMENTS{default};
}
sub getNameSpaceUri {
	my  ($prop) = @_;
	return $NAMESPACEABBR{getNameSpace($prop)};
}
sub moveToTrash  {
        my ($fn) = @_;

        my $ret = 0;
        my $etag = getETag($fn); ## get a unique name for trash folder
        $etag=~s/\"//g;
        my $trash = "$TRASH_FOLDER$etag/";

        if ($fn =~ /^\Q$TRASH_FOLDER\E/) { ## delete within trash
                my @err;
                $backend->deltree($fn, \@err);
                $ret = 1 if $#err == -1;
                debug("moveToTrash($fn)->/dev/null = $ret");
        } elsif ($backend->exists($TRASH_FOLDER) || $backend->mkcol($TRASH_FOLDER)) {
                if ($backend->exists($trash)) {
                        my $i=0;
                        while ($backend->exists($trash)) { ## find unused trash folder
                                $trash="$TRASH_FOLDER$etag".($i++).'/';
                        }
                }
                $ret = 1 if $backend->mkcol($trash) && rmove($fn, $trash.$backend->basename($fn));
                debug("moveToTrash($fn)->$trash = $ret");
        }
        return $ret;
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
	push @methods, @wmethods if !defined $path || $backend->isWriteable($path);
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
			my ($type,@suffixes) = split(/\s+/, $e);
			map  { $MIMETYPES{$_} = $type }  @suffixes;
		}
		close($f);
	} else {
		warn "Cannot open $mimefile";
	}
	$MIMETYPES{default}='application/octet-stream';
}
sub getMIMEType {
	my ($filename) = @_;
	my $extension= 'default';
	if ($filename=~/\.([^\.]+)$/) {
		$extension=lc($1);
	}
	return $MIMETYPES{$extension} || $MIMETYPES{default};
}
sub rcopy {
        my ($src,$dst,$move,$depth) = @_;

        $depth=0 unless defined $depth;

        return 0 if defined $LIMIT_FOLDER_DEPTH && $LIMIT_FOLDER_DEPTH > 0 && $depth > $LIMIT_FOLDER_DEPTH;

        # src == dst ?
        return 0 if $src eq $dst;

        # src in dst?
        return 0 if $backend->isDir($src) && $dst =~ /^\Q$src\E/;

        # src exists and readable?
        return 0 if ! $backend->exists($src) || !$backend->isReadable($src);

        # dst writeable?
        return 0 if $backend->exists($dst) && !$backend->isWriteable($dst);

        my $nsrc = $src;
        $nsrc =~ s/\/$//; ## remove trailing slash for link test (-l)
        
        if ( $backend->isLink($nsrc)) { # link
                if (!$move || !$backend->rename($nsrc, $dst)) {
                        my $orig = $backend->getLinkSrc($nsrc);
			$dst=~s/\/$//;
                        return 0 if !$backend->createSymLink($orig,$dst) && ( !$move || $backend->unlinkFile($nsrc) );
                }
        } elsif ( $backend->isFile($src) ) { # file
                if ($backend->isDir($dst)) {
                        $dst.='/' if $dst !~/\/$/;
                        $dst.=$backend->basename($src);
                }
                if (!$move || !$backend->rename($src,$dst)) {
			return 0 unless $backend->copy($src,$dst);
			if ($move) {
				return 0 unless $backend->isWriteable($src) && $backend->unlinkFile($src);
			}
                }
        } elsif ( $backend->isDir($src) ) {
                # cannot write folders to files:
                return 0 if $backend->isFile($dst);

                $dst.='/' if $dst !~ /\/$/;
                $src.='/' if $src !~ /\/$/;

                if (!$move || getDirInfo($src,'realchildcount')>0 || !$backend->rename($src,$dst)) {
                        $backend->mkcol($dst) unless $backend->exists($dst);

			return 0 unless $backend->isReadable($src);
                        my $rret = 1;
                        foreach my $filename (@{$backend->readDir($src)}) {
                                $rret = $rret && rcopy($src.$filename, $dst.$filename, $move, $depth+1);
                        }
                        if ($move) {
                                return 0 unless $rret && $backend->isWriteable($src) && $backend->deltree($src);
                        }
                }
        } else {
                return 0;
        }
	my $db = getDBDriver();
        $db->db_deleteProperties($dst);
        $db->db_copyProperties($src,$dst);
        $db->db_deleteProperties($src) if $move;
        
        return 1;
}

sub rmove {
	my ($src, $dst) = @_;
	return rcopy($src,$dst,1);
}
sub getFileLimit {
	my ($path) = @_;
	return $FILECOUNTPERDIRLIMIT{$path} || $FILECOUNTLIMIT;
}
sub getHiddenFilter {
	my ($path) = @_,
	return @HIDDEN ? '('.join('|',@HIDDEN).')' : undef;
}
sub getWebInterface {
	require WebInterface;
	return new WebInterface($config, getDBDriver());
}
sub getDBDriver {
	require DB::Driver;
	return $CACHE{dbdriver} || ($CACHE{dbdriver} = new DB::Driver);
}
sub getPropertyModule {
	require WebDAV::Properties;
	return $CACHE{webdavproperties} || ($CACHE{webdavproperties} = new WebDAV::Properties($config,getDBDriver()));
}
sub getLockModule {
	require WebDAV::Lock;
	return $CACHE{webdavlock} || ($CACHE{webdavlock} = new WebDAV::Lock($config,getDBDriver()));
}
sub getBaseURIFrag {
        return $_[0]=~/([^\/]+)\/?$/ ? ( $1 || '/' ) : '/';
}
sub getParentURI {
	return $_[0]=~/^(.*?)\/[^\/]+\/?$/ ? ( $1 || '/' ) : '/';
}

sub debug {
	print STDERR "$0: @_\n" if $DEBUG;
}
