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
package DefaultConfig;

use strict;
use warnings;

our $VERSION = '2.0';

use base qw{ Exporter };
our %EXPORT_TAGS = ();
our @EXPORT_OK   = qw(
    init_defaults read_config
    $CGI $PATH_TRANSLATED $REQUEST_URI $REMOTE_USER $REQUEST_METHOD $HTTP_HOST
    $RELEASE $VERSION $VIRTUAL_BASE $DOCUMENT_ROOT $UMASK %MIMETYPES $FANCYINDEXING %ICONS @FORBIDDEN_UID
    @HIDDEN $ALLOW_POST_UPLOADS $BUFSIZE $MAXFILENAMESIZE $DEBUG
    $DBI_SRC $DBI_USER $DBI_PASS $DBI_INIT $DBI_TIMEZONE $DEFAULT_LOCK_OWNER $ALLOW_FILE_MANAGEMENT
    $ALLOW_INFINITE_PROPFIND
    $CHARSET $LOGFILE $SHOW_QUOTA $SIGNATURE $POST_MAX_SIZE
    $ENABLE_ACL $ENABLE_CALDAV $ENABLE_LOCK
    $ENABLE_CALDAV_SCHEDULE
    $ENABLE_CARDDAV $CURRENT_USER_PRINCIPAL
    %ADDRESSBOOK_HOME_SET %CALENDAR_HOME_SET $PRINCIPAL_COLLECTION_SET
    $ENABLE_TRASH $TRASH_FOLDER $SHOW_STAT $HEADER $CONFIGFILE
    $ENABLE_SEARCH $ENABLE_GROUPDAV
    @DB_SCHEMA $CREATE_DB %TRANSLATION $LANG
    $THUMBNAIL_WIDTH $ENABLE_THUMBNAIL $ENABLE_THUMBNAIL_CACHE $THUMBNAIL_CACHEDIR $ICON_WIDTH
    $ENABLE_BIND $LANGSWITCH
    $DBI_PERSISTENT $DB $CM $CONFIG $D $L
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
    @EVENTLISTENER $SHOWDOTFILES $SHOWDOTFOLDERS $FILETYPES @DEFAULT_EXTENSIONS @AFS_EXTENSIONS @EXTRA_EXTENSIONS @PUB_EXTENSIONS @DEV_EXTENSIONS
    $OPTIMIZERTMP $READBUFSIZE $BACKEND_INSTANCE $EVENT_CHANNEL $ALLOW_PATHINPUT $MAXQUICKNAVELEMENTS
    %SESSION @ALL_EXTENSIONS
);

#{
#
#    foreach my $sym (@EXPORT_OK) {
#        push @{ $EXPORT_TAGS{all} }, $sym;
#    }
#}

use vars qw(
    $CGI $PATH_TRANSLATED $REQUEST_URI $REMOTE_USER $REQUEST_METHOD
    $RELEASE $VERSION $VIRTUAL_BASE $DOCUMENT_ROOT $UMASK %MIMETYPES $FANCYINDEXING %ICONS @FORBIDDEN_UID
    @HIDDEN $ALLOW_POST_UPLOADS $BUFSIZE $MAXFILENAMESIZE $DEBUG
    $DBI_SRC $DBI_USER $DBI_PASS $DBI_INIT $DBI_TIMEZONE $DEFAULT_LOCK_OWNER $ALLOW_FILE_MANAGEMENT
    $ALLOW_INFINITE_PROPFIND
    $CHARSET $LOGFILE $SHOW_QUOTA $SIGNATURE $POST_MAX_SIZE
    $ENABLE_ACL $ENABLE_CALDAV $ENABLE_LOCK
    $ENABLE_CALDAV_SCHEDULE
    $ENABLE_CARDDAV $CURRENT_USER_PRINCIPAL
    %ADDRESSBOOK_HOME_SET %CALENDAR_HOME_SET $PRINCIPAL_COLLECTION_SET
    $ENABLE_TRASH $TRASH_FOLDER $SHOW_STAT $HEADER $CONFIGFILE
    $ENABLE_SEARCH $ENABLE_GROUPDAV
    @DB_SCHEMA $CREATE_DB %TRANSLATION $LANG
    $THUMBNAIL_WIDTH $ENABLE_THUMBNAIL $ENABLE_THUMBNAIL_CACHE $THUMBNAIL_CACHEDIR $ICON_WIDTH
    $ENABLE_BIND $LANGSWITCH
    $DBI_PERSISTENT $DB $CM $CONFIG
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
    @EVENTLISTENER $SHOWDOTFILES $SHOWDOTFOLDERS $FILETYPES @DEFAULT_EXTENSIONS @AFS_EXTENSIONS @EXTRA_EXTENSIONS @PUB_EXTENSIONS @DEV_EXTENSIONS
    $OPTIMIZERTMP $READBUFSIZE $BACKEND_INSTANCE $EVENT_CHANNEL $ALLOW_PATHINPUT $MAXQUICKNAVELEMENTS
    $ALLOW_FOLDERUPLOAD
    %SESSION @ALL_EXTENSIONS
);

$VERSION = '2.0';

use CGI::Carp;
use English qw( -no_match_vars );

sub init_defaults {
    $ENV{PATH} = '/bin:/usr/bin:/sbin/:/usr/local/bin:/usr/sbin';
    $INSTALL_BASE = $ENV{INSTALL_BASE}        // q{/etc/webdavcgi/};
    $CONFIGFILE   = $ENV{REDIRECT_WEBDAVCONF} // $ENV{WEBDAVCONF}
        // 'webdav.conf';
    $VIRTUAL_BASE       = qr{/}xms;
    $DOCUMENT_ROOT      //= $ENV{DOCUMENT_ROOT} . q{/};
    $UMASK              = oct 22;
    $MIMEFILE           = $INSTALL_BASE . '/etc/mime.types';
    $FANCYINDEXING      = 1;
    $ENABLE_COMPRESSION = 1;
    $VHTDOCS            = "_webdavcgi_/$RELEASE/";
    $MAXFILENAMESIZE    = 10;
    $MAXQUICKNAVELEMENTS = 3;
    $ALLOW_PATHINPUT    = 0;
    %ICONS     = ( default => '${VHTDOCS}views/simple/icons/blank.png' );
    $FILETYPES = <<'EOF'
unknown  unknown
folder          folder
folderaudio     my+music music audio $TL{foldertypes.audio}
folderconfig    .gnome .gnome2 .ssh .ssh2 etc system windows
foldercurrent   .
folderdocs      documents $TL{foldertypes.documents}
folderhome      $USER home
folderpictures  my+pictures pictures dcim $TL{foldertypes.pictures} 
foldertemp      temp tmp
foldertrash     $recycle.bin trash $TL{foldertypes.trash}
folderup        .. folderup
foldervideo     my+videos videos video movie movies mymovies my+movies mp4 $TL{foldertypes.videos}
folderweb       public_html .public_html www html
text      1 2 3 4 5 6 7 8 9 asc eml htpasswd ldif list log ics info out pub text txt vcard vcs md markdown
audio     aac aif aiff aifc atrac au flac m3u mid midi mp2 mp3 m4a oga ogg opus spx snd wav wma
video     3gp avi mkv mov mpeg mp4 mpg mpe mpv mts ogv qt webm wmv
image     arw bmp cr2 crw dcr dia fff gif hdr icn ico j2k jpg jpe jpeg jps jpx k25 kdc mac mng nef nrw odg odi omf pcx png ppf psp raw rwl sr2 srf tga thm tif tiff vsd xcf yuf
source    ada am as asp asm awk b bas c cc ccs cpp cs css cxx diff el erl f77 f90 for fs h has hpp hrl hs in inl jav java js json l lol lua m m4 mak make makefile p p6 pas patch php phps pl pm pod pov py pyw r rb sed src sql t tcl tk xql yml
oofficew  odt ott odm stw sxw
officew   doc docb docm docx dot dotx dotm rtf
officep   pot potm potx ppam pps ppsx ppsm ppt pptm pptx odp otp sldm sldx sxi sti
offices   123 bks csv dex fm fp fods ods ots sdc sxc stc wki wks wku xl xla xlam xlr xll xls xlsb xlshtml xlsm xlsmhtml xlsx xlt xlthtml xltm xltx xlw  
adobe     ai eps flv ind indt pdf prn ps psd swf
markup    dtd htm html opml rdf rss sgml xml xsl xslt
archive   ??_ ?q? ?z? 7z apk arc arj bz2 cpio deb egg f gz jar kgb lbr lz lzma lzo mar par par2 pea pim rar rpm rz s7z sda sfx shar sit sitx sqx sz tar tgz tlz war xpi xz z zz zip 
binary    a bin class cmd com ds_store dump exe img iso la lai lib lo o obj so vmdk 
shell     alias bat bash bash_history bashrc bash_login bash_profile bash_logout logout bsh bshrc csh cshrc env history jsh ksh kshrc lesshst login mysql_history netrwhist profile ps1 psql_history selected_editor sqlite_history sh tcsh tcshrc 
tex       aux bbl bib brf blg bst cls ctx def dtx dvi fd fmt ins lof lot ltx nav snm sty tex toc vrb
font      afm fnt fon mf otf tfm ttc ttf 
ebook     azw azw3 azw4 cbr cbz cb7 cbt cba ceb chm djvu epub fb2 kf8 lit lrf lrx ibooks opf oxps mobi pdb pdg prc  tpz tr2 tr3 xeb xps
db        accdb accde accdr accdt accdw adn cdb db db2 db3 dbc dbf dbs dbt dbv dbx fm5 fmp fmp12 fmpsl fp3 fp4 fp5 fp7 fpt frm kdb maf mav maw mdb mdbhtml mdn mrg myd mdtsqlite nsf s3db sq2 sq3 sqlite sqlite3 sqlite-journal tmd usr wmdb xld
config    cf cfg cnf conf exrc gitconfig gvimrc gxt htaccess inf ini manifest muttrc perltidyrc pif pinerc pref preferences props properties rhosts set viminfo vimrc vmc vmx wfc xauthority
gis       axt eta fit gmap gml gpx kml kmz loc osb osc osm ov2 poi rgn tfw trk 
crypt     cer cert crl crt csr dss_key der eslock gpg id_dsa id_rsa p12 p7b p7m p7r pem pfx pgr pgp pkr random_seed rnd skr spc sst stl
temp      ### $$$ $a $db $ed §§§ asd buf cache db$ download file moz swn swo temp tmp tmt
backup    000 001 002 ab abk arm arz backup backupdb bak bak1 bak2 bak3 bck bckp bk! bk0 bka1 bk2 bk3 bk4 bk5 vbk6 bk7 bk8 bk9 deleted ezc ezp mobilebackups moz-backup old old1 old2 old3 ori orig qic qmd 
EOF
        ;
    $ICON_WIDTH              = 18;
    $TITLEPREFIX             = 'WebDAV CGI:';
    $CSS                     = q{};
    @FORBIDDEN_UID           = (0);
    @HIDDEN                  = ();
    $SHOWDOTFILES            = 1;
    $SHOWDOTFOLDERS          = 1;
    @UNSELECTABLE_FOLDERS    = ();
    $ALLOW_INFINITE_PROPFIND = 1;
    $ALLOW_FILE_MANAGEMENT   = 1;
    $ALLOW_FOLDERUPLOAD      = 1;
    $ALLOW_SYMLINK           = 1;
    $ENABLE_CLIPBOARD        = 1;
    $ENABLE_NAMEFILTER       = 1;
    $ENABLE_DAVMOUNT         = 0;
    $SHOW_STAT               = 1;
    $SHOW_LOCKS              = 1;
    $ENABLE_BOOKMARKS        = 1;
    $VIEW                    = 'simple';
    @SUPPORTED_VIEWS         = qw( simple );
    $ALLOW_POST_UPLOADS      = 1;
    $POST_MAX_SIZE           = 1_073_741_824;
    $SHOW_QUOTA              = 1;
    %QUOTA_LIMITS            = (
        'warn' => { limit => 0.02, background => 'yellow', },
        'critical' =>
            { limit => 0.01, color => 'yellow', background => 'red', }
    );
    @ALLOWED_TABLE_COLUMNS
        = qw( selector name size lastmodified created mode mime uid gid );

    if ($ALLOW_FILE_MANAGEMENT) {
        push @ALLOWED_TABLE_COLUMNS, 'fileactions';
    }
    @VISIBLE_TABLE_COLUMNS = qw( selector name size lastmodified );
    if ($ALLOW_FILE_MANAGEMENT) {
        push @VISIBLE_TABLE_COLUMNS, 'fileactions';
    }
    $SHOW_FILE_ACTIONS                                        = 1;
    $FILE_ACTIONS_TYPE                                        = 'icons';
    $SHOW_CURRENT_FOLDER                                      = 0;
    $SHOW_CURRENT_FOLDER_ROOTONLY                             = 0;
    $SHOW_PARENT_FOLDER                                       = 1;
    $EXTENSION_CONFIG{Permissions} = {
        allow_changepermrecursive => 1,
        user    => [qw(r w x s)],
        group   => [qw(r w x s)],
        others  => [qw(r w x t)], };
    $LANGSWITCH
        = q{<div id="langswitch"><a href="?lang=en">EN</a> | <a href="?lang=de">DE</a> | <a href="?lang=fr">FR</a> | <a href="?lang=hu">HU</a> | <a href="?lang=it">IT</a>&nbsp;&nbsp;$CLOCK</div>};
    $HEADER
        = q{<div class="header">WebDAV CGI - Web interface: You are logged in as ${USER}.<div id="now">$NOW</div></div>};
    $SIGNATURE
        = q{&copy; ZE CMS, Humboldt-Universit&auml;t zu Berlin | Written 2010-2016 by <a href="https://DanRohde.github.io/webdavcgi/">Daniel Rohde</a>};
    $LANG                = 'en';
    %SUPPORTED_LANGUAGES = (
        'en'      => 'English',
        'de'      => 'Deutsch',
        'fr'      => 'Français',
        'hu'      => 'Magyar',
        'it'      => 'Italiano',
    );
    $ORDER   = 'name';
    $DBI_SRC = 'dbi:SQLite:dbname=/tmp/webdav.'
        . ( $ENV{REDIRECT_REMOTE_USER} // $ENV{REMOTE_USER} // 'unknown' ) . '.db';
    $DBI_USER       = q{};
    $DBI_PASS       = q{};
    $DBI_PERSISTENT = 1;
    $CREATE_DB      = 1;
    @DB_SCHEMA      = (
        'CREATE TABLE IF NOT EXISTS webdav_locks (basefn VARCHAR(5000) NOT NULL, fn VARCHAR(5000) NOT NULL, type VARCHAR(255), scope VARCHAR(255), token VARCHAR(255) NOT NULL, depth VARCHAR(255) NOT NULL, timeout VARCHAR(255) NULL, owner TEXT NULL, timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP)',
        'CREATE TABLE IF NOT EXISTS webdav_props (fn VARCHAR(5000) NOT NULL, propname VARCHAR(255) NOT NULL, value TEXT)',
        'CREATE INDEX IF NOT EXISTS webdav_locks_idx1 ON webdav_locks (fn)',
        'CREATE INDEX IF NOT EXISTS webdav_locks_idx2 ON webdav_locks (basefn)',
        'CREATE INDEX IF NOT EXISTS webdav_locks_idx3 ON webdav_locks (fn,basefn)',
        'CREATE INDEX IF NOT EXISTS webdav_locks_idx4 ON webdav_locks (fn,basefn,token)',
        'CREATE INDEX IF NOT EXISTS webdav_props_idx1 ON webdav_props (fn)',
        'CREATE INDEX IF NOT EXISTS webdav_props_idx2 ON webdav_props (fn,propname)',
    );
    $DEFAULT_LOCK_OWNER
        = { href => ( $ENV{REDIRECT_REMOTE_USER} // $ENV{REMOTE_USER} // 'unknown' ) . q{@}
            . $ENV{REMOTE_ADDR} };
    $DEFAULT_LOCK_TIMEOUT                       = 3600;
    $CHARSET                                    = 'utf-8';
    $BUFSIZE                                    = 1_048_576;
    $READBUFSIZE                                = 65_536;
    $BACKEND_CONFIG{AFS}{quota}                 = '/usr/bin/fs listquota';
    $BACKEND_CONFIG{AFS}{allowdottedprincipals} = 0;
    $BACKEND_CONFIG{AFS}{fscmd}                 = '/usr/bin/fs';
    $EXTENSION_CONFIG{AFSACLManager}{prohibit_afs_acl_changes_for} = [
        'system:backup',   'system:administrators',
        $ENV{REMOTE_USER}, $ENV{REDIRECT_REMOTE_USER}
    ];
    $EXTENSION_CONFIG{AFSACLManager}{ptscmd}   = '/usr/bin/pts';
    $EXTENSION_CONFIG{AFSGroupManager}{ptscmd} = '/usr/bin/pts';
    $ENABLE_LOCK                               = 1;
    $ENABLE_ACL                                = 0;
    $CURRENT_USER_PRINCIPAL                    = q{/principals/}
        . ( $ENV{REDIRECT_REMOTE_USER} // $ENV{REMOTE_USER} // 'unknown' ) . q{/};
    $PRINCIPAL_COLLECTION_SET = q{/directory/};
    $ENABLE_CALDAV            = 0;
    %CALENDAR_HOME_SET        = ( default => q{/}, );
    $ENABLE_CALDAV_SCHEDULE   = 0;
    $ENABLE_CARDDAV           = 0;
    %ADDRESSBOOK_HOME_SET     = ( default => q{/}, 1_000 => q{/carddav/} );
    $ENABLE_TRASH             = 0;
    $TRASH_FOLDER             = '/tmp/trash';
    $ENABLE_GROUPDAV          = 0;
    $ENABLE_SEARCH            = 0;
    $ENABLE_THUMBNAIL         = 1;
    $ENABLE_THUMBNAIL_PDFPS   = 1;
    $ENABLE_THUMBNAIL_CACHE   = 1;
    $THUMBNAIL_WIDTH          = 110;
    $THUMBNAIL_CACHEDIR       = '/tmp';
    $ENABLE_BIND              = 0;
    $FILECOUNTLIMIT           = 5000;
    %FILECOUNTPERDIRLIMIT     = (
        '/afs/.cms.hu-berlin.de/user/'         => -1,
        '/usr/local/www/htdocs/rohdedan/test/' => 2
    );
    my $_ru = ( split /\@/xms,
        ( $ENV{REMOTE_USER} // $ENV{REDIRECT_REMOTE_USER} // 'unknown' ) )[0];
    %FILEFILTERPERDIR = (
        '/afs/.cms.hu-berlin.de/user/'          => "^$_ru\$",
        '/usr/local/www/htdocs/rohdedan/links/' => '^loop[1-4]$'
    );
    %AUTOREFRESH = (
        30   => '30s',
        60   => '1m',
        300  => '5m',
        600  => '10m',
        900  => '15m',
        1800 => '30m',
    );
    $ENABLE_FLOCK       = 1;
    $LIMIT_FOLDER_DEPTH = 20;
    $BACKEND            //= 'FS';
    $DEBUG              //= 0;
    @DEFAULT_EXTENSIONS = qw(
        History     VideoJS   ViewerJS     TextEditor
        Highlighter Download  Zip          Search
        Diff        DiskUsage ODFConverter ImageInfo
        QuickToggle SaveSettings           Feedback
        MotD
    );
    @AFS_EXTENSIONS   = qw( AFSACLManager AFSGroupManager );
    @EXTRA_EXTENSIONS = qw( GPXViewer SourceCodeViewer HexDump SendByMail );
    @PUB_EXTENSIONS   = qw( PublicUri Redirect );
    @DEV_EXTENSIONS   = qw( SysInfo PropertiesViewer Localizer );
    @EXTENSIONS       = @DEFAULT_EXTENSIONS;
    @ALL_EXTENSIONS   = ( @DEFAULT_EXTENSIONS, @EXTRA_EXTENSIONS, @AFS_EXTENSIONS, @PUB_EXTENSIONS, @DEV_EXTENSIONS );
    @EVENTLISTENER    = ();
    $OPTIMIZERTMP     = $THUMBNAIL_CACHEDIR;
    %MIMETYPES        = (
        css     => 'text/css',
        js      => 'application/javascript',
        gif     => 'image/gif',
        png     => 'image/png',
        default => 'application/octet-stream',
    );
    $EXTENSION_CONFIG{Feedback}{contact} = 'd.rohde@cms.hu-berlin.de';
    undef %SESSION;
    return 1;
}

sub read_config {
    my ( $config, $configfile ) = @_;
    if ( defined $configfile ) {

        # for compatibilty:
        our $cgi    = $CGI;
        our $CONFIG = $config;
        my $ret;
        if ( !( $ret = do($configfile) ) ) {
            if ($EVAL_ERROR) {
                carp "couldn't parse $configfile: ${EVAL_ERROR}";
            }
            if ( !defined $ret ) { carp "couldn't do $configfile: ${ERRNO}" }
            return 0;
        }
        return 1;
    }
    return 0;
}
sub free {
    undef $DEFAULT_LOCK_OWNER;
    undef @ALLOWED_TABLE_COLUMNS;
    undef @DB_SCHEMA;
    undef @EVENTLISTENER;
    undef @EXTENSIONS;
    undef @FORBIDDEN_UID;
    undef @HIDDEN;
    undef @PROHIBIT_AFS_ACL_CHANGES_FOR;
    undef @SUPPORTED_VIEWS;
    undef @UNSELECTABLE_FOLDERS;
    undef @VISIBLE_TABLE_COLUMNS;
    undef %ADDRESSBOOK_HOME_SET;
    undef %AUTOREFRESH;
    undef %BACKEND_CONFIG;
    undef %CALENDAR_HOME_SET;
    undef %ERROR_DOCS;
    undef %EXTENSION_CONFIG;
    undef %FILEFILTERPERDIR;
    undef %ICONS;
    #undef %MIMETYPES;
    undef %QUOTA_LIMITS;
    undef %SUPPORTED_LANGUAGES;
    #undef %TRANSLATION;
    return;
}
1;
