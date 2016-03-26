#!/usr/bin/perl
##!/usr/bin/speedy  -- -r50 -M7 -t3600
##!/usr/bin/perl -d:NYTProf
#########################################################################
# (C) ZE CMS, Humboldt-Universitaet zu Berlin
# Written 2010-2015 by Daniel Rohde <d.rohde@cms.hu-berlin.de>
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
# REQUIREMENTS:
#    - see http://webdavcgi.sf.net/doc.html#requirements
# INSTALLATION:
#    - see http://webdavcgi.sf.net/doc.html#installation
# CHANGES:
#    - see CHANGELOG
# KNOWN PROBLEMS:
#    - see http://webdavcgi.sf.net/
#########################################################################
package main;
use strict;
use warnings;

use vars
  qw($VIRTUAL_BASE $DOCUMENT_ROOT $UMASK %MIMETYPES $FANCYINDEXING %ICONS @FORBIDDEN_UID
  @HIDDEN $ALLOW_POST_UPLOADS $BUFSIZE $MAXFILENAMESIZE $DEBUG
  $DBI_SRC $DBI_USER $DBI_PASS $DBI_INIT $DBI_TIMEZONE $DEFAULT_LOCK_OWNER $ALLOW_FILE_MANAGEMENT
  $ALLOW_INFINITE_PROPFIND
  $CHARSET $LOGFILE %CACHE $SHOW_QUOTA $SIGNATURE $POST_MAX_SIZE
  $ENABLE_ACL $ENABLE_CALDAV $ENABLE_LOCK
  $ENABLE_CALDAV_SCHEDULE
  $ENABLE_CARDDAV $CURRENT_USER_PRINCIPAL
  %ADDRESSBOOK_HOME_SET %CALENDAR_HOME_SET $PRINCIPAL_COLLECTION_SET
  $ENABLE_TRASH $TRASH_FOLDER $SHOW_STAT $HEADER $CONFIGFILE
  $ENABLE_SEARCH $ENABLE_GROUPDAV
  @DB_SCHEMA $CREATE_DB %TRANSLATION $LANG $MAXNAVPATHSIZE
  $THUMBNAIL_WIDTH $ENABLE_THUMBNAIL $ENABLE_THUMBNAIL_CACHE $THUMBNAIL_CACHEDIR $ICON_WIDTH
  $ENABLE_BIND $LANGSWITCH
  $DBI_PERSISTENT
  $FILECOUNTLIMIT %FILECOUNTPERDIRLIMIT %FILEFILTERPERDIR
  $MIMEFILE $CSS $ENABLE_THUMBNAIL_PDFPS
  $ENABLE_FLOCK  $AFSQUOTA $CSSURI $HTMLHEAD $ENABLE_CLIPBOARD
  $LIMIT_FOLDER_DEPTH @PROHIBIT_AFS_ACL_CHANGES_FOR
  $AFS_PTSCMD
  $ENABLE_BOOKMARKS $ORDER $ENABLE_NAMEFILTER
  $VIEW $SHOW_CURRENT_FOLDER $SHOW_CURRENT_FOLDER_ROOTONLY $SHOW_PARENT_FOLDER $SHOW_LOCKS
  $SHOW_FILE_ACTIONS $REDIRECT_TO $INSTALL_BASE $ENABLE_DAVMOUNT $VHTDOCS $ENABLE_COMPRESSION
  @UNSELECTABLE_FOLDERS $TITLEPREFIX $FILE_ACTIONS_TYPE $BACKEND %BACKEND_CONFIG $ALLOW_SYMLINK
  @VISIBLE_TABLE_COLUMNS @ALLOWED_TABLE_COLUMNS %QUOTA_LIMITS @EXTENSIONS %EXTENSION_CONFIG @SUPPORTED_VIEWS %ERROR_DOCS %AUTOREFRESH
  %SUPPORTED_LANGUAGES $DEFAULT_LOCK_TIMEOUT
  @EVENTLISTENER $SHOWDOTFILES $SHOWDOTFOLDERS $FILETYPES $RELEASE @DEFAULT_EXTENSIONS @AFS_EXTENSIONS @EXTRA_EXTENSIONS @PUB_EXTENSIONS @DEV_EXTENSIONS
  $METHODS_RX %REQUEST_HANDLERS
);
$RELEASE = '1.1.1BETA20160326.08';
our $VERSION = '1.1.1BETA20160326.08';
#########################################################################
############  S E T U P #################################################

## -- ENV{PATH}
##  search PATH for binaries
local $ENV{PATH} = '/bin:/usr/bin:/sbin/:/usr/local/bin:/usr/sbin';

## -- INSTALL_BASE
## folder path to the webdav.conf, .css, .js, and. msg files for the Web interface
## (don't forget the trailing slash)
## DEFAULT: $INSTALL_BASE=q{} # use webdav.pl script path
$INSTALL_BASE = $ENV{INSTALL_BASE} || q{};

## -- CONFIGFILE
## you can overwrite all variables from this setup section with a config file
## (simply copy the complete setup section (without 'use vars ...') or single options to your config file)
## EXAMPLE: CONFIGFILE = './webdav.conf';
$CONFIGFILE = $ENV{REDIRECT_WEBDAVCONF} || $ENV{WEBDAVCONF} || 'webdav.conf';

## -- VIRTUAL_BASE
## only neccassary if you use redirects or rewrites from a VIRTUAL_BASE to the DOCUMENT_ROOT;
## regular expressions are allowed
## EXAMPLE: $VIRTUAL_BASE = qr{/}xms
$VIRTUAL_BASE = qr{/}xms;

## -- DOCUMENT_ROOT
## by default the server document root
## (don't forget a trailing slash q{/}):
$DOCUMENT_ROOT = $ENV{DOCUMENT_ROOT} . q{/};

## -- UMASK
## mask for file/folder creation
## (it does not change permission of existing files/folders):
## DEFAULT: $UMASK = oct 2; # read/write/execute for users and groups, others get read/execute permissions
$UMASK = oct 22;

## -- MIMEFILE
## path to your MIME types file
## EXAMPLE: $MIMEFILE = '/etc/mime.types';
$MIMEFILE = $INSTALL_BASE . '/etc/mime.types';

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
## EXAMPLE: $VHTDOCS="/_webdavcgi_/$RELEASE/";
$VHTDOCS = "_webdavcgi_/$RELEASE/";

## -- MAXFILENAMESIZE
## Web interface: width of filename column
$MAXFILENAMESIZE = 40;

## -- MAXNAVPATHSIZE
## Web interface: maximum length of the navigation path
$MAXNAVPATHSIZE = 50;

## -- ICONS
## MIME icons for fancy indexing
## ("$VHTDOCS" will be replaced by "$VIRTUAL_HOST$VHTDOCS")
%ICONS = ( default => '${VHTDOCS}views/simple/icons/blank.png' );

## -- FILETYPES
$FILETYPES = <<'EOF'
unknown unknown
folder  folder
folderup folderup
text    1 2 3 4 5 6 7 8 9 asc eml ldif list log ics info out pub text txt vcard vcs
audio   aac aif aiff aifc atrac au flac m3u mid midi mp2 mp3 m4a oga ogg opus spx snd wav wma
video   3gp avi mkv mov mpeg mp4 mpg mpe mpv mts ogv qt webm wmv
image   arw bmp cr2 crw dcr dia fff gif hdr icn ico j2k jpg jpe jpeg jps jpx k25 kdc mac mng nef nrw odg odi omf pcx png ppf psp raw rwl sr2 srf tga thm tif tiff vsd xcf yuf
source  ada am as asp asm awk b bas c cc ccs cpp cs css cxx diff el erl f77 f90 for fs h has hpp hrl hs in inl jav java js json l lol lua m m4 mak make makefile p p6 pas patch php phps pl pm pod pov py pyw r rb sed src sql t tcl tk xql yml
oofficew odt ott odm stw sxw
officew doc docb docm docx dot dotx dotm rtf
officep pot potm potx ppam pps ppsx ppsm ppt pptm pptx odp otp sldm sldx sxi sti
offices 123 bks csv dex fm fp fods ods ots sdc sxc stc wki wks wku xl xla xlam xlr xll xls xlsb xlshtml xlsm xlsmhtml xlsx xlt xlthtml xltm xltx xlw  
adobe   ai eps flv ind indt pdf prn ps psd swf
markup  dtd htm html opml rdf rss sgml xml xsl xslt
archive ??_ ?q? ?z? 7z apk arc arj bz2 cpio deb egg f gz jar kgb lbr lz lzma lzo mar par par2 pea pim rar rpm rz s7z sda sfx shar sit sitx sqx sz tar tgz tlz war xpi xz z zz zip 
binary  a bin class cmd com ds_store dump exe img iso la lai lib lo o obj so vmdk 
shell   alias bat bash bash_history bashrc bash_login logout bsh bshrc csh cshrc env history jsh ksh kshrc lesshst login mysql_history netrwhist profile ps1 selected_editor sqlite_history sh tcsh tcshrc 
tex     aux bbl bib brf blg bst cls ctx def dtx dvi fd fmt ins lof lot ltx nav snm sty tex toc vrb
font    afm fnt fon mf otf tfm ttc ttf 
ebook   azw azw3 azw4 cbr cbz cb7 cbt cba ceb chm djvu epub fb2 kf8 lit lrf lrx ibooks opf oxps mobi pdb pdg prc  tpz tr2 tr3 xeb xps
db      accdb accde accdr accdt accdw adn cdb db db2 db3 dbc dbf dbs dbt dbv dbx fm5 fmp fmp12 fmpsl fp3 fp4 fp5 fp7 fpt frm kdb maf mav maw mdb mdbhtml mdn mrg myd mdtsqlite nsf s3db sq2 sq3 sqlite sqlite3 tmd usr wmdb xld
config	cf cnf conf exrc gvimrc gxt inf ini manifest muttrc pif pinerc pref preferences props properties rhosts set viminfo vimrc vmc vmx wfc xauthority
gis	axt eta fit gmap gml gpx kml kmz loc osb osc osm ov2 poi rgn tfw trk 
crypt	cer cert crl crt csr der gpg p12 p7b p7m p7r pem pfx pgr pgp pkr rnd skr spc sst stl
EOF
  ;

## -- UI_ICONS -- obsolete, use stylesheets instead
## user interface icons

## -- ALLOW_EDIT -- obsolete, use or not use TextEditor extension
## allow changing text files (@EDITABLEFILES) with the Web interface
#$ALLOW_EDIT = 1;

## -- EDITABLEFILES -- obsolete, configure TextEditor extension: $EXTENSION_CONFIG{TextEditor}{editablefiles} =\@EDITABLEFIELS;
## text file names (regex; case insensitive)
#@EDITABLEFILES = ( '\.(txt|php|s?html?|tex|inc|cc?|java|hh?|ini|pl|pm|py|css|js|inc|csh|sh|tcl|tk|tex|ltx|sty|cls|vcs|vcf|ics|csv|mml|asc|text|pot|brf|asp|p|pas|diff|patch|log|conf|cfg|sgml|xml|xslt|bat|cmd|wsf|cgi|sql)$',
#                   '^(\.ht|readme|changelog|todo|license|gpl|install|manifest\.mf)' );

## -- ICON_WIDTH
## specifies the icon width for the folder listings of the Web interface
## DEFAULT: $ICON_WIDTH = 18;
$ICON_WIDTH = 18;

## -- TITLEPREFIX
## defines a prefix for the page title of the Web interface
## EXAMPLE: $TITLEPREFIX='WebDAV CGI:';
$TITLEPREFIX = 'WebDAV CGI:';

## -- CSS
## defines a stylesheet added to the header of the Web interface
$CSS = q{};

## -- CSSURI
## additional CSS file to include in the Web interface after $CSS
# $CSSURI='/mystyle.css';

## -- HTMLHEAD
## additional data included in the HTML <head> tag after $CSS/$CSSURI of the Web interface
#$HTMLHEAD = q{};

## -- FORBIDDEN_UID
## a comman separated list of UIDs to block
## (process id of this CGI will be checked against this list)
## common "forbidden" UIDs: root, Apache process owner UID
## DEFAULT: @FORBIDDEN_UID = ( 0 );
@FORBIDDEN_UID = (0);

## -- HIDDEN
## hide some special files/folders (GET/PROPFIND)
## EXAMPLES: @HIDDEN = ( '\.DAV/?$', '~$', '\.bak$', '/\.ht' );
@HIDDEN = ();

## -- SHOWDOTFILES
## show dot files
$SHOWDOTFILES = 1;

## -- SHOWDOTFOLDERS
## show dot folders (AFS backend users should leave it enabled)
$SHOWDOTFOLDERS = 1;

## -- @UNSELECTABLE_FOLDERS
## listed files/folders are unselectable in the Web interface to
## avoid archive downloads, deletes, ... of large folders.
## It's a list of regular expressions and a expression must match a full path.
## EXAMPLE: @UNSELECTABLE_FOLDERS = ('/afs/[^/]+(/[^/]+)?/?');
##    # disallow selection of a AFS cell and all subfolders but subsubfolders are selectable for file/folder actions
@UNSELECTABLE_FOLDERS = ();

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

## -- ALLOW_SEARCH -- obsolete; add 'Search' extension to your @EXTENSIONS list
## enable file/folder search in the Web interface
##$ALLOW_SEARCH = 1;

### -- ALLOW_SYMLINK
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

## -- SHOW_LOCKS
## shows file locks created by a WebDAV client
$SHOW_LOCKS = 1;

## -- ENABLE_BOOKMARKS
## enables bookmark support in the Web interface (cookie/javascript based)
## EXAMPLE: $ENABLE_BOOKMARKS = 1;
$ENABLE_BOOKMARKS = 1;

## -- VIEW
## defines the default view
$VIEW = 'simple';

## -- SUPPORTED_VIEWS
## define supported views
@SUPPORTED_VIEWS = ('simple');

## -- ALLOW_POST_UPLOADS
## enables a upload form in a fancy index of a folder (browser access)
## ATTENTATION: locks will be ignored
## Apache configuration:
## DEFAULT: $ALLOW_POST_UPLOADS = 1;
$ALLOW_POST_UPLOADS = 1;

## -- POST_MAX_SIZE
## maximum post size (only POST requests)
## EXAMPLE: $POST_MAX_SIZE = 1_073_741_824; # 1GB
$POST_MAX_SIZE = 1_073_741_824;

## -- SHOW_QUOTA
## enables/disables quota information for fancy indexing
## DEFAULT: $SHOW_QUOTA = 0;
$SHOW_QUOTA = 1;

## -- QUOTA_LIMITS
## defines warn limit and critical limit with colors
%QUOTA_LIMITS = (
    'warn'     => { limit => 0.02, background => 'yellow', },
    'critical' => { limit => 0.01, color      => 'yellow', background => 'red' }
);

## -- @ALLOWED_TABLE_COLUMNS
## defines the allowed columns for the file list in the Web interface
## supported values: name, lastmodified, created, size, mode, mime, fileaction, uid, gid
@ALLOWED_TABLE_COLUMNS = qw( name size lastmodified created mode mime uid gid );
push @ALLOWED_TABLE_COLUMNS, 'fileactions' if $ALLOW_FILE_MANAGEMENT;

## -- @VISIBLE_TABLE_COLUMNS
## defines the visible columns for the file list in the Web interface
## supported values (see @ALLOWED_TABLE_COLUMNS)
@VISIBLE_TABLE_COLUMNS = ( 'name', 'size', 'lastmodified', );
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

## -- ALLOW_CHANGEPERM -- obsolete; add 'Permissions' to your @EXTENSIONS list
## allow users to change file permissions
## DEFAULT: ALLOW_CHANGEPERM = 0;
##$ALLOW_CHANGEPERM = 1;

## -- ALLOW_CHANGEPERMRECURSIVE -- obsolete; use '$EXTENSION_CONFIG{Permissions}{allow_changepermrecursive}
## allow users to change file/folder permissions recursively
##$ALLOW_CHANGEPERMRECURSIVE = 1;
$EXTENSION_CONFIG{Permissions}{allow_changepermrecursive} = 1;

## -- PERM_USER -- obsolete; use '$EXTENSION_CONFIG{Permissions}{user}'
# if ALLOW_CHANGEPERM is set to 1 the PERM_USER variable
# defines the file/folder permissions for user/owner allowed to change
# EXAMPLE: $PERM_USER = [ 'r','w','x','s' ];
## $PERM_USER = [ 'r','w','x','s' ];
$EXTENSION_CONFIG{Permissions}{user} = [ 'r', 'w', 'x', 's' ];

## -- PERM_GROUP -- obsolete; use '$EXTENSION_CONFIG{Permissions}{group}'
# if ALLOW_CHANGEPERM is set to 1 the PERM_GROUP variable
# defines the file/folder permissions for group allowed to change
# EXMAMPLE: $PERM_GROUP = [ 'r','w','x','s' ];
# $PERM_GROUP = [ 'r','w','x','s' ];
$EXTENSION_CONFIG{Permissions}{group} = [ 'r', 'w', 'x', 's' ];

## -- PERM_OTHERS -- obsolete; use '$EXTENSION_CONFIG{Permissions}{others}'
# if ALLOW_CHANGEPERM is set to 1 the PERM_OTHERS variable
# defines the file/folder permissions for other users allowed to change
# EXAMPLE: $PERM_OTHERS = [ 'r','w','x','t' ];
# $PERM_OTHERS = [ 'r','w','x','t' ];
$EXTENSION_CONFIG{Permissions}{others} = [ 'r', 'w', 'x', 't' ];

## -- LANGSWITCH
## a simple language switch
$LANGSWITCH =
q{<div style="font-size:0.6em;text-align:right;border:0px;padding:0px;"><a href="?lang=default">[EN]</a> <a href="?lang=de">[DE]</a> <a href="?lang=fr">[FR]</a> <a href="?lang=hu">[HU]</a> <a href="?lang=it">[IT]</a> $CLOCK</div>};

## -- HEADER
## content after body tag in the Web interface
$HEADER =
q{<div class="header">WebDAV CGI - Web interface: You are logged in as ${USER}.<div style="float:right;font-size:0.8em;">$NOW</div></div>};

## -- SIGNATURE
## for fancy indexing
## EXAMPLE: $SIGNATURE=$ENV{SERVER_SIGNATURE};
$SIGNATURE =
q{&copy; ZE CMS, Humboldt-Universit&auml;t zu Berlin | Written 2010-2013 by <a href="http://webdavcgi.sf.net/">Daniel Rohde</a>};

## -- LANG
## defines the default language for the Web interface
## DEFAULT: $LANG='default';
$LANG = 'default';

#$LANG = 'de';

## -- SUPPORTED_LANGUAGES
## defines a list of languages for settings dialog
%SUPPORTED_LANGUAGES = (
    'default' => 'English',
    'de'      => 'Deutsch',
    'fr'      => 'Français',
    'hu'      => 'Magyar',
    'it'      => 'Italiano',
);

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
$DBI_SRC = 'dbi:SQLite:dbname=/tmp/webdav.'
  . ( $ENV{REDIRECT_REMOTE_USER} || $ENV{REMOTE_USER} ) . '.db';
$DBI_USER = q{};
$DBI_PASS = q{};

## -- DBI_TIMEZONE
## used to fix timestamp data delivered by the database:
## SQLite: $DBI_TIMEZONE = 'GMT';
## PostgreSQL: $DBI_TIMEZONE = 'localtime';
## MySQL: $DBI_TIMEZONE = q{};
#$DBI_TIMEZONE = 'GMT';

## enables persitent database connection (only usefull in conjunction with mod_perl, Speedy/PersistenPerl)
$DBI_PERSISTENT = 1;

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
'CREATE TABLE IF NOT EXISTS webdav_locks (basefn VARCHAR(5000) NOT NULL, fn VARCHAR(5000) NOT NULL, type VARCHAR(255), scope VARCHAR(255), token VARCHAR(255) NOT NULL, depth VARCHAR(255) NOT NULL, timeout VARCHAR(255) NULL, owner TEXT NULL, timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP)',
'CREATE TABLE IF NOT EXISTS webdav_props (fn VARCHAR(5000) NOT NULL, propname VARCHAR(255) NOT NULL, value TEXT)',
    'CREATE INDEX IF NOT EXISTS webdav_locks_idx1 ON webdav_locks (fn)',
    'CREATE INDEX IF NOT EXISTS webdav_locks_idx2 ON webdav_locks (basefn)',
    'CREATE INDEX IF NOT EXISTS webdav_locks_idx3 ON webdav_locks (fn,basefn)',
'CREATE INDEX IF NOT EXISTS webdav_locks_idx4 ON webdav_locks (fn,basefn,token)',
    'CREATE INDEX IF NOT EXISTS webdav_props_idx1 ON webdav_props (fn)',
'CREATE INDEX IF NOT EXISTS webdav_props_idx2 ON webdav_props (fn,propname)',
);

## -- DEFAULT_LOCK_OWNER
## lock owner if not given by client
## EXAMPLE: $DEFAULT_LOCK_OWNER=$ENV{REMOTE_USER}.q{@}.$ENV{REMOTE_ADDR}; ## loggin user @ ip
$DEFAULT_LOCK_OWNER =
  { href => ( $ENV{REDIRECT_REMOTE_USER} || $ENV{REMOTE_USER} ) . q{@}
      . $ENV{REMOTE_ADDR} };

## -- DEFAULT_LOCK_TIMEOUT
## sets a default lock timout in seconds if a WebDAV client forget to set one
$DEFAULT_LOCK_TIMEOUT = 3600;

## -- CHARSET
## change it if you get trouble with special characters
## DEFAULT: $CHARSET='utf-8';
$CHARSET = 'utf-8';

# and Perl's UTF-8 pragma for the right string length:
# use utf8;
# no utf8;

## -- BUFSIZE
## buffer size for read and write operations
# EXAMPLE: $BUFSIZE = 1_073_741_824;
$BUFSIZE = 1_048_576;

## -- LOGFILE
## simple log for file/folder modifications (PUT/MKCOL/DELETE/COPY/MOVE)
## EXAMPLE: $LOGFILE='/tmp/webdavcgi.log';
# $LOGFILE='/tmp/webdavcgi.log';

## -- GFSQUOTA -- obsolete, use $BACKEND_CONFIG{GFS}{quota}='...' instead
## if you use a GFS/GFS2 filesystem and if you want quota property support set this variable
## EXAMPLE: $GFSQUOTA='/usr/sbin/gfs2_quota -f';
#$GFSQUOTA='/usr/sbin/gfs_quota -f';

## -- ENABLE_AFS -- obsolete, use $BACKEND = 'AFS' instead
## to enable AFS support set: $BACKEND = 'AFS';
## $ENABLE_AFS is only used to enable AFS ACL manager and AFS group manager
# $ENABLE_AFS = 1;

## -- AFSQUOTA -- obsolete, use $BACKEND_CONFIG{AFS}{quota}='/usr/bin/fs listquota'; instead
## if you use a AFS filesystem and if you want quota property support set this variable
## EXAMPLE: $AFSQUOTA='/usr/bin/fs listquota';
#$AFSQUOTA='/usr/bin/fs listquota';
$BACKEND_CONFIG{AFS}{quota} = '/usr/bin/fs listquota';

## allows AFS dotted principals (/usr/lib/openafs/fileserver -allow-dotted-principals ...)
## EXAMLE: $BACKEND_CONFIG{AFS}{allowdottedprincipals} = 1;
$BACKEND_CONFIG{AFS}{allowdottedprincipals} = 0;

## -- AFS_FSCMD -- obsolete, use $BACKEND_CONFIG{AFS}{fscmd}='/usr/bin/fs'; instead
## file path for the fs command to change acls
## EXAMPLE: $AFS_FSCMD='/usr/bin/fs';
#$AFS_FSCMD='/usr/bin/fs';
$BACKEND_CONFIG{AFS}{fscmd} = '/usr/bin/fs';

## -- ENABLE_AFSACLMANAGER -- obsolete, add 'AFSACLManager' to your @EXTENSIONS list
## enables AFS ACL Manager for the Web interface
## EXAMPLE: $ENABLE_AFSACLMANAGER = 1;
#$ENABLE_AFSACLMANAGER = 0;

## -- ALLOW_AFSACLCHANGES -- obsolete, use $EXTENSION_CONFIG{AFSACLManager}{allow_afsaclchanges} instead
## allows AFS ACL changes. if disabled the AFS ACL Manager shows only the ACLs of a folder.
# EXAMLE: $ALLOW_AFSACLCHANGES = 1;
#$ALLOW_AFSACLCHANGES = 0;

## -- PROHIBIT_AFS_ACL_CHANGES_FOR -- obsolete, use EXTENSION_CONFIG{AFSACLManager}{prohibit_afs_acl_changes_for} instead
## prohibits AFS ACL changes for listed users/groups
## EXAMPLE: @PROHIBIT_AFS_ACL_CHANGES_FOR = ( 'system:backup', 'system:administrators' );
##@PROHIBIT_AFS_ACL_CHANGES_FOR = ( 'system:backup', 'system:administrators', $ENV{REMOTE_USER}, $ENV{REDIRECT_REMOTE_USER} );
$EXTENSION_CONFIG{AFSACLManager}{prohibit_afs_acl_changes_for} = [
    'system:backup',   'system:administrators',
    $ENV{REMOTE_USER}, $ENV{REDIRECT_REMOTE_USER}
];

## -- ENABLE_AFSGROUPMANAGER -- obsolete, use AFSGroupManager extension instead
## enables the AFS Group Manager
## EXAMPLE: $ENABLE_AFSGROUPMANAGER = 1;
#$ENABLE_AFSGROUPMANAGER = 0;

## -- ALLOW_AFSGROUPCHANGES - obsolete, use $EXTENSION_CONFIG{AFSGroupManager}{disallow_afsgroupchanges} = 0; instead
## enables AFS group change support
## EXAMPLE: $ALLOW_AFSGROUPCHANGES = 1;
#$ALLOW_AFSGROUPCHANGES = 0;

## -- AFS_PTSCMD -- obsolete, use  $EXTENSION_CONFIG{AFS(ACL|Group)Manager}{ptscmd} instead
## file path to the AFS pts command
## EXAMPLE: $AFS_PTSCMD = '/usr/bin/pts';
## $AFS_PTSCMD = '/usr/bin/pts';
$EXTENSION_CONFIG{AFSACLManager}{ptscmd}   = '/usr/bin/pts';
$EXTENSION_CONFIG{AFSGroupManager}{ptscmd} = '/usr/bin/pts';

## -- ENABLE_LOCK
## enable/disable lock/unlock support (WebDAV compliance class 2)
## if disabled it's unsafe for shared collections/files but improves performance
$ENABLE_LOCK = 1;

## -- ENABLE_ACL
## enable ACL support: only Unix like read/write access changes for user/group/other are supported
$ENABLE_ACL = 0;

## --- CURRENT_USER_PRINCIPAL
## a virtual URI for ACL principals
## for Apple's iCal &  Addressbook
$CURRENT_USER_PRINCIPAL =
  q{/principals/} . ( $ENV{REDIRECT_REMOTE_USER} || $ENV{REMOTE_USER} ) . q{/};

## -- PRINCIPAL_COLLECTION_SET
## don't change it for MacOS X Addressbook support
## DEFAULT: $PRINCIPAL_COLLECTION_SET = q{/directory/};
$PRINCIPAL_COLLECTION_SET = q{/directory/};

## -- ENABLE_CALDAV
## enable CalDAV support for Lightning/Sunbird/iCal/iPhone calender/task support
$ENABLE_CALDAV = 0;

## -- CALENDAR_HOME_SET
## maps UID numbers or remote users (accounts) to calendar folders
## Note: all listed folders are not CalDAV enabled;
##       you must create and use subfolders for calendars
%CALENDAR_HOME_SET = ( default => q{/}, );

## -- ENABLE_CALDAV_SCHEDULE
## really incomplete (ALPHA) - properties exist but POST requests are not supported yet
$ENABLE_CALDAV_SCHEDULE = 0;

## -- ENABLE_CARDDAV
## enable CardDAV support for Apple's Addressbook
$ENABLE_CARDDAV = 0;

## -- ADDRESSBOOK_HOME_SET
## maps UID numbers or remote users to addressbook folders
%ADDRESSBOOK_HOME_SET = ( default => q{/}, 1_000 => q{/carddav/} );

## -- ENABLE_TRASH
## enables the server-side trash can (don't forget to setup $TRASH_FOLDER)
$ENABLE_TRASH = 0;

## -- TRASH_FOLDER
## neccessary if you enable trash
## it should be writable by your users (chmod a+rwxt <trash folder>)
## EXAMPLE: $TRASH_FOLDER = '/tmp/trash';
$TRASH_FOLDER = '/tmp/trash';

## -- ENABLE_GROUPDAV
## enables GroupDAV (http://groupdav.org/draft-hess-groupdav-01.txt)
## EXAMPLE: $ENABLE_GROUPDAV = 0;
$ENABLE_GROUPDAV = 0;

## -- ENABLE_SEARCH
##  enables server-side search (WebDAV SEARCH/DASL, RFC5323)
## EXAMPLE: $ENABLE_SEARCH = 0;
$ENABLE_SEARCH = 0;

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
$THUMBNAIL_WIDTH = 110;

## -- THUMBNAIL_CACHEDIR
## defines the path to a cache directory for image thumbnails
## this is neccessary if you enable the thumbnail cache ($ENABLE_THUMBNAIL_CACHE)
## EXAMPLE: $THUMBNAIL_CACHEDIR=".thumbs";
$THUMBNAIL_CACHEDIR = '/tmp';

## -- ENABLE_BIND
## enables BIND/UNBIND/REBIND methods defined in http://tools.ietf.org/html/draft-ietf-webdav-bind-27
## EXAMPLE: $ENABLE_BIND = 1;
$ENABLE_BIND = 0;

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
%FILECOUNTPERDIRLIMIT = (
    '/afs/.cms.hu-berlin.de/user/'         => -1,
    '/usr/local/www/htdocs/rohdedan/test/' => 2
);

## -- FILEFILTERPERDIR
## filter the visible files/folders per directory listed by PROPFIND or the Web interface
## you can use full Perl's regular expressions for the filter value
## SYNTAX: <my absolute path with trailing slash> => <my filter regex for visible files>;
## EXAMPLE:
##   ## show only the user home in the AFS home dir 'user' of the cell '.cms.hu-berlin.de'
##   my $_ru = (split(/\@/, ($ENV{REMOTE_USER}||$ENV{REDIRECT_REMOTE_USER})))[0];
##   %FILEFILTERPERDIR = ( '/afs/.cms.hu-berlin.de/user/' => "^$_ru\$");
my $_ru =
  ( split /\@/xms, ( $ENV{REMOTE_USER} || $ENV{REDIRECT_REMOTE_USER} ) )[0];
%FILEFILTERPERDIR = (
    '/afs/.cms.hu-berlin.de/user/'          => "^$_ru\$",
    '/usr/local/www/htdocs/rohdedan/links/' => '^loop[1-4]$'
);

## -- AUTOREFRESH
## values for auto-refresh feature:
%AUTOREFRESH = (
    30   => '30s',
    60   => '1m',
    300  => '5m',
    600  => '10m',
    900  => '15m',
    1800 => '30m',
);

## -- ENABLE_FLOCK
## enables file locking support (flock) for PUT/POST uploads to respect existing locks and to set locks for files to change
$ENABLE_FLOCK = 1;

## -- LIMIT_FOLDER_DEPTH
## limits the depth a folder is visited for copy/move operations
$LIMIT_FOLDER_DEPTH = 20;

## -- BACKEND
## defines the WebDAV/Web interface backend (see $INSTALL_BASE/lib/perl/Backend/<BACKEND> for supported backends)
$BACKEND = 'FS';

## -- BACKEND_CONFIG
## allowes backend specific configurations (see doc/doc.html)
## EXAMPLE: $BACKEND_CONFIG{FS}={ fsvlink=> { '/home/testuser/' => {'testlink' => '/home/testuser/testlinkdest' } }}

## -- SMB -- obsolte, use $BACKEND_CONFIG{SMB} = { } instead
## SMB backend configuration (see doc/doc.html):
#%SMB = ();

## -- RCS -- obsolete, use $BACKEND_CONFIG{RCS} = { } instead
## RCS backend configuration (see doc/doc.html):
#%RCS = ();

## -- FSVLINK -- obsolete, use $BACKEND_CONFIG{FS} = { fsvlink=> { ... }} instead;
## FSVLINK provides virtual file system links
## FORMAT:
##         <directory> => { <linkname> => <linkdest>,  <linkname2> = > <linkdest2>, ...},
##         <directory2> => ...
## NOTES:
##         <directory> entries require a trailing slash
##         <linkname> entries must not contain slashes
##         <linnkdest> entries have to be absolute folder names
## EXAMPLE: %FSVLINK = ( '/home/testuser/' => { 'testlink' => '/home/testuser/testlinkdest' } );
#%FSVLINK = ();

## -- DEBUG
## enables/disables debug output
## you can find the debug output in your web server error log
$DEBUG = 0;

## -- DEFAULT_EXTENSIONS
## don't change it - use @EXTENSIONS instead
@DEFAULT_EXTENSIONS = qw(
  History     VideoJS   ViewerJS     TextEditor
  Highlighter Download  Zip          Search
  Diff        DiskUsage ODFConverter ImageInfo
  QuickToggle
);
## -- AFS_EXTENSIONS
## don't change it - use @EXTENSIONS instead
@AFS_EXTENSIONS = qw( AFSACLManager AFSGroupManager );
## -- EXTRA_EXTENSIONS
## don't change it - use @EXTENSIONS instead
@EXTRA_EXTENSIONS = qw( GPXViewer SourceCodeViewer HexDump SendByMail );
## -- PUB_EXTENSIONS
@PUB_EXTENSIONS = qw( PublicUri Redirect );
## -- DEV_EXTENSIONS
## don't change it - use @EXTENSIONS intead
@DEV_EXTENSIONS = qw( SysInfo PropertiesViewer );

## -- EXTENSIONS
## a list of Web interface extensions:
## supported: 'AFSACLManager', 'AFSGroupManager','Diff', 'DiskUsage', 'Download', 'HexDump',
##            'Highlighter', 'History', 'ODFConverter', 'Permissions','PosixAclManager', 'PropertiesViewer', 'PublicUri',
##            'Redirect', 'Search','SendByMail', 'SourceCodeViewer', 'SysInfo', 'TextEditor', 'ViewerJS', 'Zip'
## EXAMPLE: @EXTENSIONS = ( 'History', 'ViewJS', 'TextEditor', 'Highlighter', 'Download', 'Zip', 'Search', 'Diff', 'DiskUsage', 'ODFConverter' , 'ImageInfo');
@EXTENSIONS = @DEFAULT_EXTENSIONS;

## -- EXTENSION_CONFIG
## allowes extension configurations supported by a activated extension (see @EXTENSIONS)
## EXAMPLE: %EXTENSION_CONFIG = ( 'SysInfo' => { showall=>1 });
#%EXTENSION_CONFIG = ( 'SysInfo' => { showall=>1 });

## -- EVENTLISTENER
## a list of event listener (module names)
@EVENTLISTENER = ();

############  S E T U P - END ###########################################
#########################################################################
use vars
  qw( $CGI %CONFIG $PATH_TRANSLATED $REQUEST_URI $REMOTE_USER $REQUEST_METHOD );

use List::MoreUtils qw( any );
use CGI;
use CGI::Carp;
use English qw ( -no_match_vars );
use IO::Handle;
use Module::Load;
use POSIX qw( setlocale LC_TIME);

use DB::Driver;
use DatabaseEventAdapter;
use Backend::Manager;
use HTTPHelper
  qw( print_header_and_content print_compressed_header_and_content print_file_header print_header_and_content print_local_file_header get_mime_type );
use FileUtils qw( get_local_file_content_and_type rcopy );
use WebDAV::WebDAVProps qw( init_webdav_props );

init();
handle_request();

sub init {
    ## flush immediately:
    *STDERR->autoflush(1);
    *STDOUT->autoflush(1);

    ## before 'new CGI' to read POST requests:
    $REQUEST_METHOD = $ENV{REDIRECT_REQUEST_METHOD} // $ENV{REQUEST_METHOD}
      // 'GET';

    ## create CGI instance:
    $CGI = $REQUEST_METHOD eq 'PUT' ? CGI->new( {} ) : CGI->new();

    ## some config independent objects for convinience:
    $CONFIG{event} = get_event_channel();
    $CONFIG{cache} = CacheManager::getinstance();
    ## read config file:
    if ( defined $CONFIGFILE ) {
        my $ret;
        if ( !( $ret = do($CONFIGFILE) ) ) {
            if ($EVAL_ERROR) {
                carp "couldn't parse $CONFIGFILE: ${EVAL_ERROR}";
            }
            if ( !defined $ret ) { carp "couldn't do $CONFIGFILE: ${ERRNO}" }
        }
    }

    ## for security reasons:
    $CGI::POST_MAX = $POST_MAX_SIZE;
    $CGI::DISABLE_UPLOADS = $ALLOW_POST_UPLOADS ? 0 : 1;

    ## some config objects for the convinience:
    $CONFIG{config} = \%CONFIG;
    $CONFIG{cgi}    = $CGI;
    $CONFIG{db}     = $CACHE{ $ENV{REMOTE_USER} }{dbdriver} //=
      DB::Driver->new( \%CONFIG );

    setlocale( LC_TIME, 'en_US.' . $CHARSET )
      ; ## fixed Speedy/mod_perl related bug: strftime in PROPFIND delivers localized getlastmodified

    DatabaseEventAdapter->new( \%CONFIG )->register( $CONFIG{event} );

    broadcast('INIT');

    my $backend =
      Backend::Manager::getinstance()->get_backend( $BACKEND, \%CONFIG );
    $CONFIG{backend} = $backend;

    umask $UMASK || croak("Cannot set umask $UMASK.");

    $PATH_TRANSLATED = $ENV{PATH_TRANSLATED};
    $REQUEST_URI     = $ENV{REQUEST_URI};
    $REMOTE_USER     = $ENV{REDIRECT_REMOTE_USER} || $ENV{REMOTE_USER};

    # 404/rewrite/redirect handling:
    if ( !defined $PATH_TRANSLATED ) {
        $PATH_TRANSLATED = $ENV{REDIRECT_PATH_TRANSLATED};

        if ( !defined $PATH_TRANSLATED
            && ( defined $ENV{SCRIPT_URL} || defined $ENV{REDIRECT_URL} ) )
        {
            my $su = $ENV{SCRIPT_URL} || $ENV{REDIRECT_URL};
            $su =~ s/^$VIRTUAL_BASE//xms;
            $PATH_TRANSLATED = $DOCUMENT_ROOT . $su;
            $PATH_TRANSLATED .=
                 $backend->isDir($PATH_TRANSLATED)
              && $PATH_TRANSLATED !~ m{/$}xms
              && $PATH_TRANSLATED ne q{} ? q{/} : q{};
        }
    }

    $REQUEST_URI =~ s/[?].*$//xms;    ## remove query strings
    $REQUEST_URI .= $backend->isDir($PATH_TRANSLATED)
      && $REQUEST_URI !~ /\/$/xms ? q{/} : q{};
    $REQUEST_URI =~ s/\&/%26/xmsg;    ## bug fix (Mac Finder and &)

    $TRASH_FOLDER .= $TRASH_FOLDER !~ /\/$/xms ? q{/} : q{};

    init_webdav_props();
    return;
}

sub handle_request {

    # protect against direct CGI script call:
    if ( !defined $PATH_TRANSLATED || $PATH_TRANSLATED eq q{} ) {
        carp('FORBIDDEN DIRECT CALL!');
        return print_header_and_content('404 Not Found');
    }

    my $method = $CGI->request_method();
    debug(
"${PROGRAM_NAME} called with UID='${UID}' EUID='${EUID}' GID='${GID}' EGID='${EGID}' method=$method"
    );
    debug("User-Agent: $ENV{HTTP_USER_AGENT}");
    debug("CGI-Version: $CGI::VERSION");
    if ( defined $CGI->http('X-Litmus') ) {
        debug( "${PROGRAM_NAME}: X-Litmus: " . $CGI->http('X-Litmus') );
    }
    if ( defined $CGI->http('X-Litmus-Second') ) {
        debug( "${PROGRAM_NAME}: X-Litmus-Second: "
              . $CGI->http('X-Litmus-Second') );
    }
    $METHODS_RX //= _get_methods_rx();
    debug("METHOD_RX: $METHODS_RX");

    if ( any { /^\Q${UID}\E$/xms } @FORBIDDEN_UID ) {
        carp("Forbidden UID ${UID}!");
        return print_header_and_content('403 Forbidden');
    }
    if ( $method !~ /$METHODS_RX/xms ) {
        carp("Method not allowed: $method");
        return print_header_and_content('405 Method Not Allowed');
    }
    if ( !$REQUEST_HANDLERS{$method} ) {
        my $module = "Requests::${method}";
        load($module);
        $REQUEST_HANDLERS{$method} = $module->new();
    }
    $CONFIG{method} = $REQUEST_HANDLERS{$method};
    $REQUEST_HANDLERS{$method}->init( \%CONFIG )->handle();
    if ( $CONFIG{backend} ) { $CONFIG{backend}->finalize(); }
    broadcast('FINALIZE');
    return;
}

sub _get_methods_rx {
    my @methods =
      qw( GET HEAD POST OPTIONS PUT PROPFIND PROPPATCH MKCOL COPY MOVE DELETE GETLIB );
    if ($ENABLE_LOCK)   { push @methods, qw( LOCK UNLOCK ); }
    if ($ENABLE_SEARCH) { push @methods, 'SEARCH'; }
    if ( $ENABLE_ACL || $ENABLE_CALDAV || $ENABLE_CARDDAV ) {
        push @methods, 'ACL';
    }
    if ($ENABLE_BIND) { push @methods, qw( BIND UNBIND REBIND ); }
    if (   $ENABLE_ACL
        || $ENABLE_CALDAV
        || $ENABLE_CALDAV_SCHEDULE
        || $ENABLE_CARDDAV
        || $ENABLE_GROUPDAV )
    {
        push @methods, 'REPORT';
    }
    if ( $ENABLE_CALDAV || $ENABLE_CALDAV_SCHEDULE ) {
        push @methods, 'MKCALENDAR';
    }
    return q{^(?:} . join( q{|}, @methods ) . q{)$};
}


sub logger {
    if ( defined $LOGFILE && open my $LOG, '>>', $LOGFILE ) {
        print {$LOG} localtime()
          . " - ${UID}($REMOTE_USER)\@$ENV{REMOTE_ADDR}: @_\n" || carp("Cannot write log entry to $LOGFILE: @_");
        close($LOG) || carp("Cannot close filehandle for '$LOGFILE'");
    }
    else {
        print {*STDERR} "${PROGRAM_NAME}: @_\n" || carp("Cannot print log entry to STDERR: @_");
    }
    return;
}

sub debug {
    my ($text) = @_;
    if ($DEBUG) {
        print {*STDERR} "${PROGRAM_NAME}: $text\n" || carp("Cannot print debug output to STDERR: $text");
    }
    return;
}

sub get_event_channel {
    my $cache = CacheManager::getinstance();
    my $ec    = $cache->get_entry('eventchannel');
    if ( !$ec ) {
        require Events::EventChannel;
        $ec = Events::EventChannel->new();
        $cache->set_entry( 'eventchannel', $ec );
        foreach my $listener (@EVENTLISTENER) {
            load $listener;
            $listener->new( \%CONFIG )->register($ec);
        }
    }
    return $ec;
}

sub broadcast {
    my ( $event, $data ) = @_;
    return get_event_channel()->broadcast( $event, $data );
}

sub get_cgi {
    return $CGI;
}

sub get_backend {
    return $CONFIG{backend};
}

1;
