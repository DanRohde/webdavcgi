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

package WebInterface::Renderer;

use strict;

use WebInterface::Common;
our @ISA = ( 'WebInterface::Common' );

use POSIX qw(strftime ceil locale_h);
use File::Basename;
use IO::Compress::Gzip qw(gzip);
use IO::Compress::Deflate qw(deflate);
use URI::Escape;
use Graphics::Magick;

use vars qw (%TRANSLATIONS  $WEB_ID %BYTEUNITS @BYTEUNITORDER);

%BYTEUNITS = (B=>1, KB=>1024, MB => 1048576, GB => 1073741824, TB => 1099511627776, PB =>1125899906842624 );
@BYTEUNITORDER = ( 'B', 'KB', 'MB', 'GB', 'TB', 'PB' );




sub new {
       my $this = shift;
       my $class = ref($this) || $this;
       my $self = { };
       bless $self, $class;

       $$self{cgi}=shift;
       $$self{backend}=shift;
       return $self;
}

sub renderPropertiesViewer {
        my ($self, $fn, $ru) = @_;
        $self->setLocale();
        my $content = "";
        $content .= $self->start_html("$main::TITLEPREFIX $ru properties");
        $content .= $self->replaceVars($main::LANGSWITCH) if defined $main::LANGSWITCH;
        $content .= $self->replaceVars($main::HEADER) if defined $main::HEADER;
        my $fullparent = dirname($ru) .'/';
        $fullparent = '/' if $fullparent eq '//' || $fullparent eq '';
        $content .=$$self{cgi}->h2( { -class=>'foldername' }, ($$self{backend}->isDir($fn) ? $self->getQuickNavPath($fn,$ru,$self->getQueryParams())
                                    : $self->getQuickNavPath($$self{backend}->getParent($fn), $fullparent,$self->getQueryParams())
                                       .' '.$$self{cgi}->a({-href=>$ru}, basename($ru))
                              ). $self->tl('properties'));
        $content .= $$self{cgi}->br().$$self{cgi}->a({href=>$ru,title=>$self->tl('clickforfullsize')},$$self{cgi}->img({-src=>$ru.($main::ENABLE_THUMBNAIL?'?action=thumb':''), -alt=>'image', -class=>'thumb', -style=>'width:'.($main::ENABLE_THUMBNAIL?$main::THUMBNAIL_WIDTH:200)})) if $self->hasThumbSupport(main::getMIMEType($fn));
        $content .= $$self{cgi}->start_table({-class=>'props'});
        local(%main::NAMESPACEELEMENTS);
        my $dbprops = main::db_getProperties($fn);
        my @bgstyleclasses = ( 'tr_odd', 'tr_even');
        my (%visited);
        $content.=$$self{cgi}->Tr({-class=>'trhead'}, $$self{cgi}->th({-class=>'thname'},$self->tl('propertyname')), $$self{cgi}->th({-class=>'thvalue'},$self->tl('propertyvalue')));
        foreach my $prop (sort {main::nonamespace(lc($a)) cmp main::nonamespace(lc($b)) } keys %{$dbprops},$$self{backend}->isDir($fn) ? @main::KNOWN_COLL_PROPS : @main::KNOWN_FILE_PROPS ) {
                my (%r200);
                next if exists $visited{$prop} || exists $visited{'{'.main::getNameSpaceUri($prop).'}'.$prop};
                if (exists $$dbprops{$prop}) {
                        $r200{prop}{$prop}=$$dbprops{$prop};
                } else {
                        main::getProperty($fn, $ru, $prop, undef, \%r200, \my %r404);
                }
                $visited{$prop}=1;
                $main::NAMESPACEELEMENTS{main::nonamespace($prop)}=1;
                my $title = main::createXML($r200{prop},1);
                my $value = main::createXML($r200{prop}{$prop},1);
                my $namespace = main::getNameSpaceUri($prop);
                if ($prop =~ /^\{([^\}]*)\}/) {
                        $namespace = $1;
                }
                push @bgstyleclasses,  shift @bgstyleclasses;
                $content.= $$self{cgi}->Tr( {-class=>$bgstyleclasses[0] },
                         $$self{cgi}->td({-title=>$namespace, -class=>'tdname'},main::nonamespace($prop))
                        .$$self{cgi}->td({-title=>$title, -class=>'tdvalue' }, $$self{cgi}->pre($$self{cgi}->escapeHTML($value)))
                        );
        }
        $content.=$$self{cgi}->end_table();
        $content.=$$self{cgi}->hr().$$self{cgi}->div({-class=>'signature'},$self->replaceVars($main::SIGNATURE)) if defined $main::SIGNATURE;
        $content.=$$self{cgi}->end_html();
        main::printCompressedHeaderAndContent('200 OK', 'text/html', $content, 'Cache-Control: no-cache, no-store');
}

sub hasThumbSupport {
        my ($self,$mime) = @_;
        return 1 if $mime =~ /^image\// || $mime =~ /^text\/plain/ || ($main::ENABLE_THUMBNAIL_PDFPS && $mime =~ /^application\/(pdf|ps)$/);
        return 0;
}
sub getQuickNavPath {
        my ($self, $fn,$ru, $query) = @_;
        $ru = main::uri_unescape($ru);
        my $content = "";
        my $path = "";
        my $navpath = $ru;
        my $base = '';
        $navpath=~s/^($main::VIRTUAL_BASE)//;
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
        my @fna = split(/\//,substr($fn,length($main::DOCUMENT_ROOT)));
        my $fnc = $main::DOCUMENT_ROOT;
        foreach my $pe (split(/\//, $navpath)) {
                $path .= uri_escape($pe) . '/';
                $path = '/' if $path eq '//';
                my $dn =  "$pe/";
                $dn = $fnc eq $main::DOCUMENT_ROOT ? "$pe/" : $$self{backend}->getDisplayName($fnc);
                $content .= $$self{cgi}->a({-href=>"$base$path".(defined $query?"?$query":""), -title=>$path}," $dn ");
                $fnc.=shift(@fna).'/';
        }
        $content .= $$self{cgi}->a({-href=>'/', -title=>'/'}, '/') if $content eq '';

        $content = $$self{cgi}->span({-id=>'quicknavpath'}, $content);
        $content .= ' '.$self->getChangeDirForm($ru,$query) unless defined $$self{cgi}->param('search') || defined $$self{cgi}->param('action');

        return $content;
}
sub setLocale {
        my $locale;
        if ($main::LANG eq 'default') {
                $locale = "en_US.\U$main::CHARSET\E"
        } else {
                $main::LANG =~ /^(\w{2})(_(\w{2})(\.(\S+))?)?$/;
                my ($c1,$c,$c3,$c4,$c5) = ($1, $2, $3, $4, $5);
                $c3 = uc($c1) unless $c3;
                $c5 = uc($main::CHARSET) unless $c5 && uc($c5) eq uc($main::CHARSET);
                $locale = "${c1}_${c3}.${c5}";
        }
        setlocale(LC_COLLATE, $locale);
        setlocale(LC_TIME, $locale);
        setlocale(LC_CTYPE, $locale);
        setlocale(LC_NUMERIC, $locale);
}
sub start_html {
        my ($self,$title) = @_;
        my $content ="";
        $content.="<!DOCTYPE html>\n";
        $content.='<head><title>'.$$self{cgi}->escapeHTML($title).'</title>';
        $content.=qq@<meta http-equiv="Content-Type" content="text/html; charset=$main::CHARSET"/>@;
        $content.=qq@<meta name="author" content="Daniel Rohde"/>@;

        my $js='function tl(k) { var tl = new Array();';
        foreach my $usedtext (('bookmarks','addbookmark','rmbookmark','addbookmarktitle','rmbookmarktitle','rmallbookmarks','rmallbookmarkstitle','sortbookmarkbypath','sortbookmarkbytime','rmuploadfield','rmuploadfieldtitle','deletefileconfirm', 'movefileconfirm', 'cancel', 'confirm','pastecopyconfirm','pastecutconfirm','msgtimeouttooltip')) {
                $js.= qq@tl['$usedtext']='@.$self->tl($usedtext).qq@';@;
        }
        $js.=' return tl[k] ? tl[k] : k; }';
        $js.=qq@var REQUEST_URI = '$main::REQUEST_URI';@;
        $js.=qq@var MAXFILENAMESIZE= '$main::MAXFILENAMESIZE';@;

        $main::REQUEST_URI=~/^($main::VIRTUAL_BASE)/;
        my $base = $1;
        $base.='/' unless $base=~/\/$/;
        $content.=qq@<link rel="search" type="application/opensearchdescription+xml" title="WebDAV CGI filename search" href="$main::REQUEST_URI?action=opensearch"/>@ if $main::ALLOW_SEARCH;
        $content.=qq@<link rel="alternate" href="$main::REQUEST_URI?action=mediarss" type="application/rss+xml" title="" id="gallery"/>@ if $main::ENABLE_THUMBNAIL;
        $content.=qq@<script type="text/javascript">$js</script>@;
        $content.=qq@<link href="${base}webdav-ui.css" rel="stylesheet" type="text/css"/>@;
        $content.=qq@<link href="${base}webdav-ui-custom.css" rel="stylesheet" type="text/css"/>@ if -e "${main::INSTALL_BASE}lib/webdav-ui-custom.css" || ($main::ENABLE_COMPRESSION && -e "${main::INSTALL_BASE}lib/webdav-ui-custom.css.gz");
        $content.=qq@<style type="text/css">$main::CSS</style>@ if defined $main::CSS;
        $content.=qq@<link href="$main::CSSURI" rel="stylesheet" type="text/css"/>@ if defined $main::CSSURI;
        $content.=qq@<script src="${base}webdav-ui.js" type="text/javascript"></script>@;
        $content.=qq@<link href="${base}webdav-ui-custom.js" rel="stylesheet" type="text/css"/>@ if -e "${main::INSTALL_BASE}lib/webdav-ui-custom.js";
        $content.=$main::HTMLHEAD if defined $main::HTMLHEAD;
        $content.=qq@</head><body onload="check()">@;
        return $content;
}

sub replaceVars {
        my ($self,$t) = @_;
        $t=~s/\${?NOW}?/strftime($self->tl('varnowformat'), localtime())/eg;
        $t=~s/\${?TIME}?/strftime($self->tl('vartimeformat'), localtime())/eg;
        $t=~s/\${?USER}?/$main::REMOTE_USER/g;
        $t=~s/\${?REQUEST_URI}?/$main::REQUEST_URI/g;
        $t=~s/\${?PATH_TRANSLATED}?/$main::PATH_TRANSLATED/g;
        $t=~s/\${?ENV{([^}]+?)}}?/$ENV{$1}/eg;
        my $clockfmt = $self->tl('vartimeformat');
        $t=~s@\${?CLOCK}?@<span id="clock"></span><script>startClock('clock','$clockfmt');</script>@;
        $t=~s/\${?LANG}?/$main::LANG/g;
        $t=~s/\${?TL{([^}]+)}}?/$self->tl($1)/eg;

        $main::REQUEST_URI =~ /^($main::VIRTUAL_BASE)/;
        my $vbase= $1;
        $t=~s/\${?VBASE}?/$vbase/g;
        $t=~s/\${?VHTDOCS}?/$vbase$main::VHTDOCS/g;

        return $t;
}

sub getQueryParams {
	my ($self) = @_;
        # preserve query parameters
        my @query;
        foreach my $param (()) {
                push @query, $param.'='.$$self{cgi}->param($param) if defined $$self{cgi}->param($param);
        }
        return $#query>-1 ? join(';',@query) : undef;
}

sub printThumbnail {
	my ($self,$fn) = @_;
	my $image = Graphics::Magick->new;
	my $width = $main::THUMBNAIL_WIDTH || $main::ICON_WIDTH || 18;
	if ($main::ENABLE_THUMBNAIL_CACHE) {
		my $uniqname = $fn;
		$uniqname=~s/\//_/g;
		my $cachefile = "$main::THUMBNAIL_CACHEDIR/$uniqname.thumb.gif";
		mkdir($main::THUMBNAIL_CACHEDIR) if ! -e $main::THUMBNAIL_CACHEDIR;
		if (! -e $cachefile || ($$self{backend}->stat($fn))[9] > (stat($cachefile))[9]) {
			my $lfn = $$self{backend}->getLocalFilename($fn);
			my $x;
			my ($w, $h,$s,$f) = $image->Ping($lfn);

			$x = $image->Read($lfn); warn "$x" if "$x";
			$image->Set(delay=>200);
			$image->Crop(height=>$h / ${width} ) if ($h > $width && $w < $width);
			$image->Resize(geometry=>$width,filter=>'Gaussian') if ($w > $width);
			$image->Frame(width=>2,height=>2,outer=>0,inner=>2, fill=>'black');
			$x = $image->Write($cachefile); warn "$x" if "$x";

		}
		if (open(my $cf, "<$cachefile")) {
			print $$self{cgi}->header(-status=>'200 OK',-type=>main::getMIMEType($cachefile), -ETag=>main::getETag($cachefile), -Content-length=>(stat($cachefile))[7]);
			binmode $cf;
			binmode STDOUT;
			print while(<$cf>);
			close($cf);
		}
	} else {
		my $lfn = $$self{backend}->getLocalFilename($fn);
		print $$self{cgi}->header(-status=>'200 OK',-type=>'image/gif', -ETag=>main::getETag($fn));
		my ($w, $h,$s,$f) = $image->Ping($lfn);
		my $x;
		$x = $image->Read($lfn); warn "$x" if "$x";
		$image->Set(delay=>200);
		$image->Crop(height=>$h / ${width} ) if ($h > $width && $w < $width);
		$image->Resize(geometry=>$width,filter=>'Gaussian') if ($w > $width);
		$image->Frame(width=>2,height=>2,outer=>0,inner=>2, fill=>'black');
		binmode STDOUT;
		$x = $image->Write('gif:-'); warn "$x" if "$x";
	}
}
sub printImage {
	my ($self, $fn) = @_;
	$fn = $$self{backend}->getLocalFilename($fn);
	my $image = Graphics::Magick->new;
	my $x = $image->Read($fn); warn "$x" if "$x";
	$image->Set(delay=>200);
	binmode STDOUT;
	print $$self{cgi}->header(-status=>'200 OK',-type=>'image/gif', -ETag=>main::getETag($fn));
	$x = $image->Write('gif:-'); warn "$x" if "$x";
}
sub printMediaRSS {
	my ($self,$fn,$ru) = @_;
	my $content = qq@<?xml version="1.0" encoding="utf-8" standalone="yes"?><rss version="2.0" xmlns:media="http://search.yahoo.com/mrss/" xmlns:atom="http://www.w3.org/2005/Atom"><channel><title>$ENV{SCRIPT_URI} media data</title><description>$ENV{SCRIPT_URI} media data</description><link>$ENV{SCRIPT_URI}</link>@;
	foreach my $file (sort { $self->cmp_files } @{$$self{backend}->readDir($fn, main::getFileLimit($fn), \&frontendFilterCallback)}) {
		my $mime = main::getMIMEType($file);
		$mime='image/gif' if $self->hasThumbSupport($mime) && $mime !~ /^image/i;
		$content.=qq@<item><title>$file</title><link>$ru$file</link><media:thumbnail type="image/gif" url="$ENV{SCRIPT_URI}$file?action=thumb"/><media:content type="$mime" url="$ENV{SCRIPT_URI}$file?action=image"/></item>@ if $self->hasThumbSupport($mime) && $$self{backend}->isReadable("$fn$file");
	}
	$content.=qq@</channel></rss>@;
	main::printHeaderAndContent("200 OK", 'appplication/rss+xml', $content);

}

sub printDAVMount {
	my ($self,$fn) = @_;
	my $su = $ENV{REDIRECT_SCRIPT_URI} || $ENV{SCRIPT_URI};
	my $bn = basename($fn);
	$su =~ s/\Q$bn\E\/?//;
	$bn.='/' if $$self{backend}->isDir($fn) && $bn!~/\/$/;
	main::printHeaderAndContent('200 OK','application/davmount+xml',
	       qq@<dm:mount xmlns:dm="http://purl.org/NET/webdav/mount"><dm:url>$su</dm:url><dm:open>$bn</dm:open></dm:mount>@);
}

sub printOpenSearch {
	my ($self) = @_;
	my $content = qq@<?xml version="1.0" encoding="utf-8" ?><OpenSearchDescription xmlns="http://a9.com/-/spec/opensearch/1.1/"><ShortName>WebDAV CGI filename</ShortName><Description>WebDAV CGI filename search in $ENV{SCRIPT_URI}</Description><InputEncoding>utf-8</InputEncoding><Url type="text/html" template="$ENV{SCRIPT_URI}?search={searchTerms}" /></OpenSearchDescription>@;
	main::printHeaderAndContent("200 OK", 'text/xml', $content);
}

sub printStylesAndVHTOCSFiles {
	my ($self,$fn) = @_;
	my $file = $fn =~ /\Q$main::VHTDOCS\E(.*)/ ? $main::INSTALL_BASE.'htdocs/'.$1 : $main::INSTALL_BASE.'lib/'.basename($fn);
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
		main::printLocalFileHeader($nfile, $header);
		binmode(STDOUT);
		while (read(F,my $buffer, $main::BUFSIZE || 1048576 )>0) {
			print $buffer;
		}
		close(F);
	} else {
		main::printHeaderAndContent('404 Not Found','text/plain','404 - NOT FOUND');
	}

}
sub renderWebInterface {
	my ($self,$fn,$ru) = @_;
        my $content = "";
        my $head = "";
        $self->setLocale();
        $head .= $self->replaceVars($main::LANGSWITCH) if defined $main::LANGSWITCH;
        $head .= $self->replaceVars($main::HEADER) if defined $main::HEADER;
        ##$content.=$$self{cgi}->start_multipart_form(-method=>'post', -action=>$ru, -onsubmit=>'return window.confirm("'.$self->tl('confirm').'");') if $main::ALLOW_FILE_MANAGEMENT;
        $content.=$$self{cgi}->start_multipart_form(-method=>'post', -action=>$ru ) if $main::ALLOW_FILE_MANAGEMENT;
        if ($main::ALLOW_SEARCH && $$self{backend}->isReadable($fn)) {
                my $search = $$self{cgi}->param('search');
                $head .= $$self{cgi}->div({-class=>'search'}, $self->tl('search'). ' '. $$self{cgi}->input({-title=>$self->tl('searchtooltip'),-onkeypress=>'javascript:handleSearch(this,event);', -onkeyup=>'javascript:if (this.size<this.value.length || (this.value.length<this.size && this.value.length>10)) this.size=this.value.length;', -name=>'search',-size=>$search?(length($search)>10?length($search):10):10, -value=>defined $search?$search:''}));
        }
        $head.=$self->renderMessage();
        if ($$self{cgi}->param('search')) {
                $content.=$self->getSearchResult($$self{cgi}->param('search'),$fn,$ru);
        } else {
                my $showall = $$self{cgi}->param('showpage') ? 0 : $$self{cgi}->param('showall') || $$self{cgi}->cookie('showall') || 0;
                $head .= $$self{cgi}->div({-id=>'notwriteable',-onclick=>'fadeOut("notwriteable");', -class=>'notwriteable msg'}, $self->tl('foldernotwriteable')) if !$$self{backend}->isWriteable($fn);
                $head .= $$self{cgi}->div({-id=>'notreadable', -onclick=>'fadeOut("notreadable");',-class=>'notreadable msg'},  $self->tl('foldernotreadable')) if !$$self{backend}->isReadable($fn);
                $head .= $$self{cgi}->div({-id=>'filtered', -onclick=>'fadeOut("filtered");', -class=>'filtered msg', -title=>$main::FILEFILTERPERDIR{$fn}}, $self->tl('folderisfiltered', $main::FILEFILTERPERDIR{$fn} || ($main::ENABLE_NAMEFILTER ? $$self{cgi}->param('namefilter') : undef) )) if $main::FILEFILTERPERDIR{$fn} || ($main::ENABLE_NAMEFILTER && $$self{cgi}->param('namefilter'));
                $head .= $$self{cgi}->div( { -class=>'foldername'},
                        $$self{cgi}->a({-href=>$ru.($main::ENABLE_PROPERTIES_VIEWER ? '?action=props' : '')},
                                        $$self{cgi}->img({-src=>$self->getIcon('<folder>'),-title=>$main::ENABLE_PROPERTIES_VIEWER?$self->tl('showproperties'):$ru, -alt=>'folder'})
                                )
                        .($main::ENABLE_DAVMOUNT ? '&nbsp;'.$$self{cgi}->a({-href=>'?action=davmount',-class=>'davmount',-title=>$self->tl('mounttooltip')},$self->tl('mount')) : '')
                        .' '
                        .$self->getQuickNavPath($fn,$ru)
                );
                $head.= $$self{cgi}->div( { -class=>'viewtools' },
                                ($ru=~/^$main::VIRTUAL_BASE\/?$/ ? '' :$$self{cgi}->a({-class=>'up', -href=>dirname($ru).(dirname($ru) ne '/'?'/':''), -title=>$self->tl('uptitle')}, $self->tl('up')))
                                .' '.$$self{cgi}->a({-class=>'refresh',-href=>$ru.'?t='.time(), -title=>$self->tl('refreshtitle')},$self->tl('refresh')));
                if ($main::SHOW_QUOTA) {
                        my($ql, $qu) = main::getQuota($fn);
                        if (defined $ql && defined $qu) {
                                my ($ql_v, $ql_t ) = renderByteValue($ql,2,2);
                                my ($qu_v, $qu_t ) = renderByteValue($qu,2,2);
                                my ($qa_v, $qa_t ) = renderByteValue($ql-$qu,2,2);

                                $head.= $$self{cgi}->div({-class=>'quota'},
                                                                $self->tl('quotalimit').$$self{cgi}->span({-title=>$ql_t}, $ql_v)
                                                                .$self->tl('quotaused').$$self{cgi}->span({-title=>$qu_t}, $qu_v)
                                                                .$self->tl('quotaavailable').$$self{cgi}->span({-title=>$qa_t},$qa_v));
                        }
                }
                $content.=$$self{cgi}->div({-class=>'masterhead'}, $head);
                my $folderview = "";
                my $manageview = "";
                my ($list, $count) = $self->getFolderList($fn,$ru, $main::ENABLE_NAMEFILTER ? $$self{cgi}->param('namefilter') : undef);
                $folderview.=$list;
                $manageview.= $self->renderToolbar() if ($main::ALLOW_FILE_MANAGEMENT && $$self{backend}->isWriteable($fn)) ;
                $manageview.= $self->renderFieldSet('editbutton',$$self{cgi}->a({-id=>'editpos'},"").$self->renderEditTextView()) if $main::ALLOW_EDIT && $$self{cgi}->param('edit');
                $manageview.= $self->renderFieldSet('upload',$self->renderFileUploadView($fn)) if $main::ALLOW_FILE_MANAGEMENT && $main::ALLOW_POST_UPLOADS && $$self{backend}->isWriteable($fn);
                if ($main::VIEW eq 'sidebar') {
                        $content.=$self->renderSideBar() if $main::VIEW eq 'sidebar';
                        $folderview.=$self->renderToolbar() if $main::ALLOW_FILE_MANAGEMENT;
                }
                if ($main::ALLOW_FILE_MANAGEMENT && $$self{backend}->isWriteable($fn)) {
                        my $m = "";
                        $m .= $self->renderFieldSet('files', $self->renderCreateNewFolderView().$self->renderCreateNewFileView().($main::ALLOW_SYMLINK ? $self->renderCreateSymLinkView():'').$self->renderMoveView() .$self->renderDeleteView());
                        $m .= $self->renderFieldSet('zip', $self->renderZipView()) if ($main::ALLOW_ZIP_UPLOAD || $main::ALLOW_ZIP_DOWNLOAD);
                        $m .= $self->renderToggleFieldSet('mode', $self->renderChangePermissionsView()) if $main::ALLOW_CHANGEPERM;
                        $m .= $self->renderToggleFieldSet('afs', $self->renderAFSACLManager()) if ($main::ENABLE_AFSACLMANAGER);
                        $manageview .= $self->renderToggleFieldSet('management', $m);
                }
                $folderview .= $manageview unless $main::VIEW eq 'sidebar';
                $folderview .= $self->renderToggleFieldSet('afsgroup',$self->renderAFSGroupManager()) if ($main::ENABLE_AFSGROUPMANAGER && $main::VIEW ne 'sidebar');
                my $showsidebar = $$self{cgi}->cookie('sidebar') ? $$self{cgi}->cookie('sidebar') eq 'true' : 1;
                $content .= $$self{cgi}->div({-id=>'folderview', -class=>($main::VIEW eq 'sidebar'? 'sidebarfolderview'.($showsidebar?'':' full') : 'folderview')}, $folderview);
                $content .= $main::VIEW ne 'sidebar' && $main::ENABLE_SIDEBAR ? $self->renderFieldSet('viewoptions',
                                 ( $showall ? '&bull; '.$$self{cgi}->a({-href=>'?showpage=1'},$self->tl('navpageview')) : '' )
                                .(!$showall ? '&bull; '.$$self{cgi}->a({-href=>'?showall=1'},$self->tl('navall')) : '' )
                                . $$self{cgi}->br().'&bull; '.$$self{cgi}->a({-href=>'?view=sidebar'},$self->tl('sidebarview'))
                                .$self->renderToggleFieldSet('filter.title',$self->renderViewFilterView())
                                ) : '';
                $content .= $$self{cgi}->end_form() if $main::ALLOW_FILE_MANAGEMENT;
                $content .= $$self{cgi}->start_form(-method=>'post', -id=>'clpform')
                                .$$self{cgi}->hidden(-name=>'action', -value=>'') .$$self{cgi}->hidden(-name=>'srcuri', -value>'')
                                .$$self{cgi}->hidden(-name=>'files', -value=>'') .$$self{cgi}->end_form() if ($main::ALLOW_FILE_MANAGEMENT && $main::ENABLE_CLIPBOARD);
                $content .= $$self{cgi}->start_form(-method=>'post', -id=>'faform')
                                .$$self{cgi}->hidden(-id=>'faction', -name=>'dummy', -value=>'unused')
                                .$$self{cgi}->hidden(-id=>'fdst', -name=>'newname',-value=>'')
                                .$$self{cgi}->hidden(-id=>'fsrc', -name=>'file', -value=>'')
                                .$$self{cgi}->hidden(-id=>'fid', -name=>'fid', -value=>'')
                                .$$self{cgi}->div({-id=>'forigcontent', -class=>'hidden'},"")
                                .$$self{cgi}->end_form() if $main::ALLOW_FILE_MANAGEMENT && $main::SHOW_FILE_ACTIONS;
        }
        $content.= $$self{cgi}->div({-class=>$main::VIEW eq 'classic' ? 'signature' : 'signature sidebarsignature'}, $self->replaceVars($main::SIGNATURE)) if defined $main::SIGNATURE;
        ###$content =~ s/(<\/\w+[^>]*>)/$1\n/g;
        $content = $self->start_html("$main::TITLEPREFIX $ru").$content.$$self{cgi}->end_html();

        main::printCompressedHeaderAndContent('200 OK','text/html',$content,'Cache-Control: no-cache, no-store' );
}
sub renderByteValue {
        my ($v, $f, $ft) = @_;
        $f = 2 unless defined $f;
        $ft = $f unless defined $ft;
        my $showunit = 'B';
        my %rv;
        my $title = '';
        my $lowerlimitf = 10**(-$f);
        my $lowerlimitft = 10**(-$ft);
        my $upperlimit = 10**10;
        foreach my $unit (@BYTEUNITORDER) {
                $rv{$unit} = $v / $BYTEUNITS{$unit};
                last if $rv{$unit} < $lowerlimitf;
                $showunit=$unit if $rv{$unit} >= 1;
                $title.= ($unit eq 'B' ? sprintf(' = %.0f B ',$rv{$unit}) : sprintf('= %.'.$ft.'f %s ', $rv{$unit}, $unit)) if $rv{$unit} >= $lowerlimitft && $rv{$unit} < $upperlimit;
        }
        return ( ($showunit eq 'B' ? $rv{$showunit} : sprintf('%.'.$f.'f %s',$rv{$showunit},$showunit)), $title);
}
sub renderMessage {
        my ($self,$prefix) = @_;
        $prefix='' unless defined $prefix;
        my $content = "";
        if ( my $msg = $$self{cgi}->param($prefix.'errmsg') || $$self{cgi}->param($prefix.'msg')) {
                my @params = ();
                my $p=1;
                while (defined $$self{cgi}->param("p$p")) {
                        push @params, $$self{cgi}->escapeHTML($$self{cgi}->param("p$p"));
                        $p++;
                }
                $content .= $$self{cgi}->div({-id=>'msg',-onclick=>'javascript:fadeOut("msg");', -class=>$$self{cgi}->param($prefix.'errmsg')?'errormsg':'infomsg'}, sprintf($self->tl('msg_'.$msg),@params));
        }
        return $content;
}
sub getIcon {
        my ($self,$type) = @_;
        return $self->replaceVars(exists $main::ICONS{$type} ? $main::ICONS{$type} : $main::ICONS{default});
}
sub getUIIcon {
        my ($self,$action) = @_;
        return $self->replaceVars(exists $main::UI_ICONS{$action} ? $main::UI_ICONS{$action} : $main::UI_ICONS{default});
}
sub getChangeDirForm {
        my ($self,$ru,$query) = @_;
        return
                $$self{cgi}->span({-id=>'changedir', -class=>'hidden'},
                    $$self{cgi}->input({-id=>'changedirpath', -onkeypress=>'return catchEnter(event,"changedirgobutton");', -name=>'changedirpath', -value=>$ru, -size=>50 })
                   . ' '
                   . $$self{cgi}->button(-id=>'changedirgobutton',  -name=>$self->tl('go'), onclick=>'javascript:changeDir(document.getElementById("changedirpath").value)')
                   . ' '
                   . $$self{cgi}->button(-id=>'changedircancelbutton',  -name=>$self->tl('cancel'), onclick=>'javascript:showChangeDir(false)')
                )
                . $$self{cgi}->button(-id=>'changedirbutton', -name=>$self->tl('changedir'), -onclick=>'javascript:showChangeDir(true)')
                . ( $main::ENABLE_BOOKMARKS ?  $self->buildBookmarkList() : '' )
                ;

}
sub buildBookmarkList {
	my ($self) = @_;
        my(@bookmarks, %labels, %attributes);
        my $isBookmarked = 0;
        my $i=0;
        while (my $b = $$self{cgi}->cookie('bookmark'.$i)) {
                $i++;
                next if $b eq '-';
                push @bookmarks, $b;
                $labels{$b} = $$self{cgi}->escapeHTML(length($b) <=25 ? $b : substr($b,0,5).'...'.substr($b,length($b)-17));
                $attributes{$b}{title}=$$self{cgi}->escapeHTML($b);
                $attributes{$b}{disabled}='disabled' if $b eq $main::REQUEST_URI;
                $isBookmarked = 1 if $b eq $main::REQUEST_URI;
        }
        sub getBookmarkTime {
                my $i = 0;
                $i++ while ($$self{cgi}->cookie('bookmark'.$i) && $$self{cgi}->cookie('bookmark'.$i) ne $_[0]);
                return $$self{cgi}->cookie('bookmark'.$i.'time') || 0;
        }
        sub cmpBookmarks{
                my $s = $$self{cgi}->cookie('bookmarksort') || 'time-desc';
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
                push @bookmarks, '-'; $labels{'-'}=$self->tl('rmbookmark'); $attributes{'-'}= { -title=>$self->tl('rmbookmarktitle'), -class=>'func' };
        } else {
                unshift @bookmarks, '+'; $labels{'+'}=$self->tl('addbookmark'); $attributes{'+'}={-title=>$self->tl('addbookmarktitle'), -class=>'func'};
        }
        if ($#bookmarks > 1) {
                my $bms = $$self{cgi}->cookie('bookmarksort') || 'time-desc';
                my ($sbpadd, $sbparr, $sbtadd, $sbtarr) = ('','','','');
                if ($bms=~/^path/) {
                        $sbpadd = ($bms=~/desc$/)? '' : '-desc';
                        $sbparr = ($bms=~/desc$/)? ' &darr;' : ' &uarr;';
                } else {
                        $sbtadd = ($bms=~/desc$/)? '' : '-desc';
                        $sbtarr = ($bms=~/desc$/)? ' &darr;' : ' &uarr;';
                }
                push @bookmarks, 'path'.$sbpadd;  $labels{'path'.$sbpadd}=$self->tl('sortbookmarkbypath').$sbparr; $attributes{'path'.$sbpadd}{class}='func';
                push @bookmarks, 'time'.$sbtadd;  $labels{'time'.$sbtadd}=$self->tl('sortbookmarkbytime').$sbtarr; $attributes{'time'.$sbtadd}{class}='func';
        }
        push @bookmarks,"";
        push @bookmarks,'--'; $labels{'--'}=$self->tl('rmallbookmarks'); $attributes{'--'}={ title=>$self->tl('rmallbookmarkstitle'), -class=>'func' };

        unshift @bookmarks, '#'; $labels{'#'}=$self->tl('bookmarks'); $attributes{'#'}{class}='title';
        my $e = $$self{cgi}->autoEscape(0);
        my $content = $$self{cgi}->popup_menu( -class=>'bookmark', -name=>'bookmark', -onchange=>'return bookmarkChanged(this.options[this.selectedIndex].value);', -values=>\@bookmarks, -labels=>\%labels, -attributes=>\%attributes);
        $$self{cgi}->autoEscape($e);
        return ' ' . $$self{cgi}->span({-id=>'bookmarks'}, $content)
                . ' '. $$self{cgi}->a({-id=>'addbookmark',-class=>($isBookmarked ? 'hidden' : undef),-onclick=>'return addBookmark()', -href=>'#', -title=>$self->tl('addbookmarktitle')}, $self->tl('addbookmark'))
                . ' '. $$self{cgi}->a({-id=>'rmbookmark',-class=>($isBookmarked ? undef : 'hidden'),-onclick=>'return rmBookmark()', -href=>'#', -title=>$self->tl('rmbookmarktitle')}, $self->tl('rmbookmark')) ;
}
sub getFolderList {
        my ($self,$fn,$ru,$filter) = @_;
        my ($content,$list,$count,$filecount,$foldercount,$filesizes) = ("",0,0,0,0);

        $list="";
        my $tablehead ="";

        $tablehead.=$$self{cgi}->td({-class=>'th_sel'},$$self{cgi}->checkbox(-onclick=>'javascript:toggleAllFiles(this);', -name=>'selectall',-value=>"",-label=>"", -title=>$self->tl('togglealltooltip'))) if $main::ALLOW_FILE_MANAGEMENT;

        my $dir = $main::ORDER=~/_desc$/ ? '' : '_desc';
        my $query = $filter ? 'search=' . $$self{cgi}->param('search'):'';
        my $ochar = ' <span class="orderchar">'.($dir eq '' ? '&darr;' :'&uarr;').'</span>';

        my @tablecolumns = $self->getVisibleTableColumns();
        my %usedcols;

        my $rowpattern = '';
        foreach my $column (@tablecolumns) {
                $tablehead .= $$self{cgi}->td({
                                                -class=>"th_$column".($main::ORDER=~/^\Q$column\E/?' th_highlight':''),
                                                -style=> $column eq 'name' ? "min-width: ${main::MAXFILENAMESIZE}ex;" : '',
                                                -title=> $column ne 'fileactions' ? $self->tl('clickchangessort') : $self->tl($column),
                                                -onclick=> $column ne 'fileactions' ? "window.location.href='$ru?order=${column}${dir};$query';" : '',
                                        }, $column ne 'fileactions' ?  $$self{cgi}->a({-href=>"$ru?order=${column}${dir};$query"}, $self->tl($column).($main::ORDER=~/^\Q$column\E/?$ochar:''))
                                                                : $self->tl($column)
                );
                $usedcols{$column}=1;
                $rowpattern .= q@$row.=$$self{cgi}->td({
                                                -class=>"tc_@.$column.q@",
                                                -id=>"tc_@.${column}.q@_${fid}",
                                                -title=>$rowdata{@.$column.q@}{title},
                                                -onclick=>$onclick,
                                                -onmousedown=>$ignev,
                                                -ondblclick=>$ignev,
                                        }, $rowdata{@.$column.q@}{value});
                                @;
        }

        $tablehead = $$self{cgi}->Tr({-class=>'th', -title=>$self->tl('clickchangessort')}, $tablehead);
        $list .= $tablehead;


        my @files = $$self{backend}->isReadable($fn) ? sort { $self->cmp_files } @{$$self{backend}->readDir($fn,main::getFileLimit($fn),\&frontendFilterCallback)} : ();
        unshift @files, '.' if  $main::SHOW_CURRENT_FOLDER || ($main::SHOW_CURRENT_FOLDER_ROOTONLY && $main::DOCUMENT_ROOT eq $fn);
        unshift @files, '..' if $main::SHOW_PARENT_FOLDER && $main::DOCUMENT_ROOT ne $fn;

        my $page = $$self{cgi}->param('page') ? $$self{cgi}->param('page') - 1 : 0;
        my $fullcount = $#files + 1;
        my $showall = $$self{cgi}->param('showpage') ? 0 : $$self{cgi}->param('showall') || $$self{cgi}->cookie('showall') || 0;

        my $pagenav = $filter ? '' : $self->renderPageNavBar($ru, $fullcount, \@files);

        if (!defined $filter && defined $main::PAGE_LIMIT && !$showall) {
                splice(@files, $main::PAGE_LIMIT * ($page+1) );
                splice(@files, 0, $main::PAGE_LIMIT * $page) if $page>0;
        }

        eval qq@/$filter/;@;
        $filter="\Q$filter\E" if ($@);

        my $unselregex = @main::UNSELECTABLE_FOLDERS ? '('.join('|',@main::UNSELECTABLE_FOLDERS).')' : '___cannot match___' ;

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

                my $isReadable = ($$self{backend}->isDir($full) && $$self{backend}->isExecutable($full)) || ($$self{backend}->isFile($full) && $$self{backend}->isReadable($full));
                my $isUnReadable = !$isReadable;

                my $mimetype = '?';
                $mimetype = $$self{backend}->isDir($full) ? ( $filename eq '..' ? '< .. >' : '<folder>' ) : main::getMIMEType($filename) unless $isUnReadable;
                $filename.="/" if !$isUnReadable && $filename !~ /^\.{1,2}$/ && $$self{backend}->isDir($full);
                $nru.="/" if !$isUnReadable && $filename !~ /^\.{1,2}$/ && $$self{backend}->isDir($full);

                next if $filter && $filename !~/$filter/i;

                my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size, $atime,$mtime,$ctime,$blksize,$blocks) = !$isUnReadable ? $$self{backend}->stat($full) : (0,0,0,0,0,0,0,0,0,0,0,0,0,0);

                push @rowclass,shift @rowclass;

                my $row = "";

                my $focus = $filter ? '': qq@addClassNameById("tr_$fid","tr_highlight");@;
                my $blur =  $filter ? '': qq@removeClassNameById("tr_$fid","tr_highlight");@;
                my $onclick= $filter ? '' : qq@return handleRowClick("$fid", event);@;
                my $ignev= qq@return false;@;

                my $unsel = $full =~ /^$unselregex$/;

                if ($main::ALLOW_FILE_MANAGEMENT) {
                        my %checkboxattr = (-id=>$fid, -onfocus=>$focus, -onblur=>$blur, -name=>'file', -value=>$filename, -label=>'');
                        if ($filename eq '..' || $unsel) {
                                $checkboxattr{-disabled}='disabled';
                                $checkboxattr{-style}='visibility: hidden;display:none';
                                $checkboxattr{-value}='__not_allowed__';
                        } else {
                                $checkboxattr{-onclick}=qq@return handleCheckboxClick(this, "$fid", event);@;
                        }
                        $row.= $$self{cgi}->td({-class=>'tc_checkbox'},$$self{cgi}->checkbox(\%checkboxattr));
                }

                my $lmf = strftime($self->tl('lastmodifiedformat'), localtime($mtime));
                my $ctf = strftime($self->tl('lastmodifiedformat'), localtime($ctime));
                my ($size_v, $size_t) = renderByteValue($size,0,2);
                my %rowdata = (
                        'name'=> $usedcols{name} ? { value=>$self->getfancyfilename($nru, $filename, $mimetype, $full, $isUnReadable), title=>$filename} : '',
                        'lastmodified'=> $usedcols{lastmodified} ? { value=>$lmf, title=>$self->tl('created').' '.$ctf} : '',
                        'created'=> $usedcols{created} ? { value=>$ctf, title=>$self->tl('lastmodified').' '.$lmf} : '',
                        'size'=> $usedcols{size} ? { value=>$size_v, title=>$size_t} : '',
                        'mode'=> $usedcols{mode} ? { value=>sprintf("%-11s",$self->mode2str($full,$mode)), title=>sprintf("mode: %04o, uid: %s (%s), gid: %s (%s)",$mode & 07777,"".getpwuid($uid), $uid, "".getgrgid($gid), $gid)} : '',
                        'fileactions'=> $usedcols{fileactions} ? {value=>$filename=~/^\.{1,2}$/ || $unsel ? '' : $self->renderFileActions($fid, $filename, $full), title=>$filename } : '',
                        'mime'=> $usedcols{mime} ? { value=>$$self{cgi}->escapeHTML($mimetype), title=>$filename} : '',
                );
                eval $rowpattern;
#               foreach my $column (@tablecolumns) {
#                       $row.=$$self{cgi}->td({
#                                               -class=>"tc_$column",
#                                               -id=>"tc_${column}_${fid}",
#                                               -title=>$rowdata{$column}{title},
#                                               -onclick=>$onclick,
#                                               -onmousedown=>$ignev,
#                                               -ondblclick=>$ignev,
#                                       }, $rowdata{$column}{value});
#               }
                $list.=$$self{cgi}->Tr({-class=>$rowclass[0],-id=>"tr_$fid", -title=>"$filename", -onmouseover=>$focus,-onmouseout=>$blur, -ondblclick=>($filename=~/^\.{1,2}$/ || $isReadable)?qq@window.location.href="$nru";@ : ''}, $row);
                $odd = ! $odd;

                if ($filename!~/^\.{1,2}$/) {
                        $count++;
                        $foldercount++ if !$isUnReadable && $$self{backend}->isDir($full);
                        $filecount++ if $isUnReadable || $$self{backend}->isFile($full);
                        $filesizes+=$size if $isUnReadable || $$self{backend}->isFile($full);
                }

                ##$list .= $tablehead if $count % 50 == 0;

        }
        $list .= $tablehead if $count > 20; ## && $count % 50 != 0 && $count % 50 > 20;
        $content .= $self->renderTableConfig(). $pagenav;
        $content .= $$self{cgi}->start_table({-class=>'filelist'}).$list.$$self{cgi}->end_table();
        my ($sizetext,$sizetitle) = renderByteValue($filesizes,2,2);
        $sizetext.=$sizetitle ne "" ? " ($sizetitle)" : $sizetitle;
        $content .= $$self{cgi}->div({-class=>'folderstats'},sprintf("%s %d, %s %d, %s %d, %s %s", $self->tl('statfiles'), $filecount, $self->tl('statfolders'), $foldercount, $self->tl('statsum'), $count, $self->tl('statsize'), $sizetext)) if ($main::SHOW_STAT);
        $content .= $self->renderFrontendFilter($fn);

        $content .= $pagenav;
        return ($content, $count);
}
sub getVisibleTableColumns {
	my ($self) = @_;
        my @vc;

        if (my $vcs = $$self{cgi}->cookie('visibletablecolumns')) {
                my @cvc = split(',', $vcs);
                my ($allowed) = 1;
                foreach my $c (@cvc) {
                        push @vc, $c if grep(/^\Q$c\E$/, @main::ALLOWED_TABLE_COLUMNS);
                }
        } else {
                @vc = @main::VISIBLE_TABLE_COLUMNS;
        }
        return @vc;
}
sub renderPageNavBar {
        my ($self, $ru, $count, $files) = @_;
        my $limit = $main::PAGE_LIMIT || -1;
        my $showall = $$self{cgi}->param('showpage') ? 0 : $$self{cgi}->param('showall') || $$self{cgi}->cookie('showall') || 0;
        my $page = $$self{cgi}->param('page') || 1;

        my $content = "";
        return $content if $limit <1; # || $count <= $limit;

        my $maxpages = ceil($count / $limit);
        return $content if $maxpages == 0;

        return $$self{cgi}->div({-class=>'showall'}, $$self{cgi}->a({href=>$ru."?showpage=1", -title=>$self->tl('navpageviewtooltip')}, $self->tl('navpageview')). ', '.$self->renderNameFilterForm()) if ($showall);
        if ($count >$limit) {

                $content .= ($page > 1 )
                                ? $$self{cgi}->a({-href=>sprintf('%s?page=%d;pagelimit=%d',$ru,1,$limit), -title=>$self->tl('navfirsttooltip')}, $self->tl('navfirst'))
                                : $self->tl('navfirstblind');
                $content .= ($page > 1 )
                                ? $$self{cgi}->a({-href=>sprintf('%s?page=%d;pagelimit=%d',$ru,$page-1,$limit), -title=>$self->tl('navprevtooltip')}, $self->tl('navprev'))
                                : $self->tl('navprevblind');
                #$content .= $self->tl('navpage')."$page/$maxpages: ";
                $content .= $self->tl('navpage');

                my %attributes;
                if ($maxpages > 1 && $maxpages <= 50) {
                        foreach my $i ( 1 .. $maxpages ) {
                                $attributes{$i}{title}=$$self{cgi}->escapeHTML(sprintf('%s,...,%s',substr($$files[($i-1)*$limit],0,8),substr(($i*$limit -1 > $#$files ? $$files[$#$files] : $$files[$i*$limit -1]),0,8)));
                        }
                }

                $content .= $maxpages < 2 || $maxpages > 50 ? $page : $$self{cgi}->popup_menu(-default=>$page, -name=>'page', -values=> [ 1 .. $maxpages ], -attributes=>\%attributes, -onchange=>'javascript:window.location.href=window.location.pathname+"?page="+this.value;' );
                $content .= " / $maxpages: ";

                $content .= sprintf("%02d-%02d/%d",(($limit * ($page - 1)) + 1) , ( $page < $maxpages || $count % $limit == 0 ? $limit * $page : ($limit*($page-1)) + $count % $limit), $count);

                $content .= ($page < $maxpages)
                                ? $$self{cgi}->a({-href=>sprintf('%s?page=%d;pagelimit=%d', $ru, $page+1, $limit), -title=>$self->tl('navnexttooltip')},$self->tl('navnext'))
                                : $self->tl('navnextblind');

                $content .= ($page < $maxpages)
                                ? $$self{cgi}->a({-href=>sprintf('%s?page=%d;pagelimit=%d', $ru, $maxpages, $limit), -title=>$self->tl('navlasttooltip')},$self->tl('navlast'))
                                : $self->tl('navlastblind');
        } else {
                $content .= '&nbsp;';
        }

        $content .= ' '.$$self{cgi}->span({-class=>'pagelimit',-title=>$self->tl('pagelimittooltip')}, $self->tl('pagelimit').' '.$$self{cgi}->popup_menu(-name=>'pagelimit', -onchange=>'javascript: window.location.href=window.location.pathname + (this.value==-1 ? "?showall=1" : "?page=1;pagelimit="+this.value);', -values=>\@main::PAGE_LIMITS, -default=>$limit, -labels=>{-1=>$self->tl('navall')}, -attributes=>{-1=>{title=>$self->tl('navalltooltip')}}));

        ##$content .= ' '. $$self{cgi}->a({-href=>$ru."?showall=1", -title=>$self->tl('navalltooltip')}, $self->tl('navall'));


        return $$self{cgi}->div({-class=>'pagenav'},$content);
}


sub renderTableConfig {
	my ($self) = @_;
        my $content = "";

        my $sortingcolumndefault ='name';
        my $sortingorderdefault = 'asc';
        if ($$self{cgi}->cookie('order') && $$self{cgi}->cookie('order') =~/^([^_]+)(_(.*))?$/) {
                ($sortingcolumndefault,$sortingorderdefault) = ($1, $3 || 'asc');
        }
        my @tablecolumns = @main::ALLOWED_TABLE_COLUMNS;
        my @sortingcolumns = grep(!/^fileactions$/,@main::ALLOWED_TABLE_COLUMNS);
        my @visiblecolumns = $self->getVisibleTableColumns();
        my %tablecolumnlabels;
        my @tablecolumndefaults;
        foreach my $col  (@tablecolumns) {
                $tablecolumnlabels{$col} = $self->tl($col);
                push @tablecolumndefaults, $col if grep(/^\Q$col\E$/,@visiblecolumns);
        }
        my %tablecolumnattributes = ( 'name'=>{ -disabled=>'disabled' } );

        $content.=$$self{cgi}->div({-class=>'tableconfigbutton', -title=>$self->tl('tableconfig.button.title'), -onclick=>'toggleClassNameById("tableconfig","hidden",!document.getElementById("tableconfig").className.match(/hidden/));'}, $self->tl('tableconfig.button'));

        $content.=$$self{cgi}->div({-id=>'tableconfig',-class=>'tableconfig hidden'},
                $self->renderFieldSet($self->tl('tableconfig.tablecolumns'), $$self{cgi}->checkbox_group({-name=>'tablecolumns',-cols=>1,-values=>\@tablecolumns,-labels=>\%tablecolumnlabels,-defaults=>\@tablecolumndefaults, -attributes=>\%tablecolumnattributes}))
                .$self->renderFieldSet($self->tl('tableconfig.sortingcolumns'), $$self{cgi}->radio_group({-name=>'sortingcolumns',-cols=>1, -values=>\@sortingcolumns,-labels=>\%tablecolumnlabels,-default=>$sortingcolumndefault}))
                .$self->renderFieldSet($self->tl('tableconfig.sortingorder'), $$self{cgi}->radio_group({-name=>'sortingorder',-cols=>1, -values=>['asc','desc'], -labels=>{'asc'=>$self->tl('tableconfig.ascending'),'desc'=>$self->tl('tableconfig.descending')}, -default=>$sortingorderdefault}))
                .$$self{cgi}->div({-class=>'tableconfigactions'},
                        $$self{cgi}->button({-value=>$self->tl('cancel'),-onclick=>'toggleClassNameById("tableconfig","hidden",1)'})
                        .$$self{cgi}->button({-value=>$self->tl('savebutton'), -onclick=>'saveTableConfig()'})
                 )
        );

        return $$self{cgi}->div({-class=>'tableconfigcontainer'},$content);
}
sub renderFrontendFilter {
	my ($self ) = @_;
        my $content  = "";
        if ($$self{cgi}->cookie('filter.name') && $$self{cgi}->cookie('filter.name')=~/^(\=\~|\^|\$|eq|ne|lt|le|gt|ge) (.*)$/) {
                my ($nameop, $nameval) = ($1,$2);
                my %nameops = ( '=~' => $self->tl('filter.name.regexmatch'), '^' => $self->tl('filter.name.startswith'), '$' => $self->tl('filter.name.endswith'), 'eq' => $self->tl('filter.name.equal'), 'ne' => $self->tl('filter.name.notequal'), 'lt' => $self->tl('filter.name.lessthan'), 'gt' => $self->tl('filter.name.greaterthan'), 'le' => $self->tl('filter.name.lessorequal'), 'ge' => $self->tl('filter.name.greaterorequal'));
                $content.=$self->tl('filter.name.showonly').$nameops{$nameop}.'&nbsp;"'.$$self{cgi}->span($nameval).'"';

        }
        if ($$self{cgi}->cookie('filter.types') && $$self{cgi}->cookie('filter.types')=~/^[dfl]+$/ && length($$self{cgi}->cookie('filter.types'))<3) {
                my $filter = $$self{cgi}->cookie('filter.types');
                my $t=$filter=~/d/ ? $self->tl('filter.types.folder') : '';
                if ($filter=~/f/) {
                        $t.=', ' if $t ne '';
                        $t.=$self->tl('filter.types.files');
                }
                if ($filter=~/l/) {
                        $t.=', ' if $t ne '';
                        $t.=$self->tl('filter.types.links');
                }
                $content.='; ' if $content ne '';
                $content.=$self->tl('filter.types.showonly').$t;
        }

        if ($$self{cgi}->cookie('filter.size') && $$self{cgi}->cookie('filter.size')  =~ /^([\<\>\=]{1,2})(\d+)(\w*)$/) {
                my ($op,$val,$unit) = ($1,$2,$3);
                my ($v,$t) = renderByteValue($val*($BYTEUNITS{$unit}||1),2,2);
                my %sizeops = ( '<'=>$self->tl('filter.size.lessthan'), '<='=>$self->tl('filter.size.lessorequal'), '=='=> $self->tl('filter.size.equal'), '>'=>$self->tl('filter.size.greaterthan'), '>='=>$self->tl('filter.size.greaterorequal'),);
                $content.='; ' if $content ne '';
                $content.=$self->tl('filter.size.showonly').$sizeops{$op}.$$self{cgi}->span({-title=>$t},$v);
        }
        if ($$self{cgi}->cookie('filter.time') && $$self{cgi}->cookie('filter.time') =~ /^([\<\>\=]{1,2})(\d+)$/) {
                my ($op,$val) = ($1,$2);
                $content.='; ' if $content ne '';
                $content.=$self->tl('filter.time.showonly').$op.localtime($val);
        }

        return $content ne "" ? $$self{cgi}->div({-class=>'filter'},$self->tl('filter').$content) : $content;
}
sub renderFileActionsWithIcons {
        my ($self,$fid, $file, $full) = @_;
        my %attr= ();
        my %disabled = ();
        my @actions = ('edit','rename','zip','delete');
        delete $actions[2] unless $main::ALLOW_ZIP_DOWNLOAD;
        push @actions, 'props' if $main::ENABLE_PROPERTIES_VIEWER;
        my %labels = ( rename=>$self->tl('movefilesbutton'),edit=>$self->tl('editbutton'),delete=>$self->tl('deletefilesbutton'), zip=>$self->tl('zipdownloadbutton'), props=>$self->tl('showproperties') );
        if (! $$self{backend}->isWriteable($full)) {
                $disabled{rename}=1;
                $disabled{delete}=1;
        }
        if (! $$self{backend}->isReadable($full)) {
                $disabled{zip}=1;
                $disabled{props}=1 if $main::ENABLE_PROPERTIES_VIEWER;
        }
        if ($main::ALLOW_EDIT) {
                my $ef = '('.join('|',@main::EDITABLEFILES).')';
                $disabled{edit} = 1 unless basename($file) =~/$ef/i && $$self{backend}->isFile($full) && $$self{backend}->isWriteable($full);
        }
        my $content="";
        foreach my $action (@actions) {
                $attr{$action}{-id}=qq@fileactions_${action}_${fid}@;
                ###$attr{$action}{-name}='actions';
                $attr{$action}{-class}='actionicon'.($disabled{$action}?' disabled':'');
                $attr{$action}{-onclick}=$disabled{$action}? 'return false;' : qq@handleFileAction('$action','${fid}',event,'select');@;
                $attr{$action}{-ondblclick}=$disabled{$action} ? 'return false;' : qq@handleFileAction('$action','${fid}',event,'select');@;
                $attr{$action}{-src}=$self->getUIIcon($action);
                $attr{$action}{-title}=$labels{$action};
                $content.= $$self{cgi}->img($attr{$action});
        }
        return $$self{cgi}->div({-class=>'actionicons'},$content);
}
sub renderFileActions {
	my $self = shift;
        return $main::FILE_ACTIONS_TYPE && $main::FILE_ACTIONS_TYPE eq 'select' ? $self->renderFileActionsWithSelect(@_) : $self->renderFileActionsWithIcons(@_);
}
sub renderFileActionsWithSelect {
        my ($self,$fid, $file, $full) = @_;
        my @values = ('--','rename','edit','zip','delete');
        delete $values[3] unless $main::ALLOW_ZIP_DOWNLOAD;

        my %labels = ( '--'=> '', rename=>$self->tl('movefilesbutton'),edit=>$self->tl('editbutton'),delete=>$self->tl('deletefilesbutton'), zip=>$self->tl('zipdownloadbutton'), props=>$self->tl('showproperties') );
        my %attr;
        push @values, 'props' if $main::ENABLE_PROPERTIES_VIEWER;
        if (! $$self{backend}->isWriteable($full)) {
                $attr{rename}{disabled}='disabled';
                $attr{delete}{disabled}='disabled';
        }
        if (! $$self{backend}->isReadable($full)) {
                $attr{zip}{disabled}='disabled';
                $attr{props}{disabled}='disabled' if $main::ENABLE_PROPERTIES_VIEWER;
        }

        if ($main::ALLOW_EDIT) {
                my $ef = '('.join('|',@main::EDITABLEFILES).')';
                $attr{edit}{disabled}='disabled' unless basename($file) =~/$ef/i && ($$self{backend}->isFile($full) && $$self{backend}->isWriteable($full));
        } else {
                @values = grep(!/^edit$/,@values);
        }

        return $$self{cgi}->popup_menu(-name=>'actions', -id=>'fileactions_'.$fid, -onchange=>"handleFileAction(this.value,'$fid',event,'select');", -values=>\@values, -labels=>\%labels, -attributes=>\%attr);
}

sub renderNameFilterForm {
	my ($self) = @_;
	return $main::ENABLE_NAMEFILTER && !$$self{cgi}->param('search') ?
		$$self{cgi}->div({-class=>'namefilter', -title=>$self->tl('namefiltertooltip')}, $self->tl('namefilter').
			$$self{cgi}->input({-size=>5, -value=>$$self{cgi}->param('namefilter')||'',-name=>'namefilter',
					-onkeypress=>'javascript:return catchEnter(event,"undef")',
					-onkeyup=>'javascript:return handleNameFilter(this,event);'})
			.' '
			.$$self{cgi}->span({-class=>'namefiltermatches'}, $self->tl('namefiltermatches').$$self{cgi}->input({-size=>2,-value=>'-',-readonly=>'readonly',-name=>'namefiltermatches',-class=>'namefiltermatches'}))
		)
		: '';
}
sub getfancyfilename {
        my ($self, $full,$s,$m,$fn,$isUnReadable) = @_;
        my $ret = $s;
        my $q = getQueryParams();

        $full = '/' if $full eq '//'; # fixes root folder navigation bug

        $full.="?$q" if defined $q && defined $fn && !$isUnReadable && $$self{backend}->isDir($fn);
        my $fntext = $s eq '.' ? $s : $$self{backend}->getDisplayName($fn);
        $fntext =substr($fntext,0,$main::MAXFILENAMESIZE-3) if length($s)>$main::MAXFILENAMESIZE;
        my $linkit =  $fn=~/^\.{1,2}$/ || (!$$self{backend}->isDir($fn) && $$self{backend}->isReadable($fn)) || $$self{backend}->isExecutable($fn);

        $ret = $linkit ? $$self{cgi}->a({href=>$full,title=>$s},$$self{cgi}->escapeHTML($fntext)) : $$self{cgi}->escapeHTML($fntext);
        $ret .=  length($s)>$main::MAXFILENAMESIZE ? '...' : (' 'x($main::MAXFILENAMESIZE-length($s)));

        $full=~/([^\.]+)$/;
        my $suffix = $1 || $m;
        my $icon = $self->getIcon($m);
        my $width = $main::ICON_WIDTH || 18;
        my $onmouseover="";
        my $onmouseout="";
        my $align="";
        my $id='i'.time().$WEB_ID;
        $id=~s/\"//g;

        my $cssclass='icon';
        if ($main::ENABLE_THUMBNAIL && $$self{backend}->isReadable($fn) && !$$self{backend}->isEmpty($fn) && $self->hasThumbSupport($m))  {
                $icon=$full.($full=~/\?.*/?';':'?').'action=thumb';
                if ($main::THUMBNAIL_WIDTH && $main::ICON_WIDTH < $main::THUMBNAIL_WIDTH) {
                        $cssclass='thumb';
                        $onmouseover = qq@javascript:this.intervalFunc=function() { if (this.width<$main::THUMBNAIL_WIDTH) this.width+=@.(($main::THUMBNAIL_WIDTH-$main::ICON_WIDTH)/15).qq@; else window.clearInterval(this.intervalObj);}; this.intervalObj = window.setInterval("document.getElementById('$id').intervalFunc();", 10);@;
                        $onmouseout = qq@javascript:window.clearInterval(this.intervalObj);this.width=$main::ICON_WIDTH;@;
                }
        }
        my $img =  $$self{cgi}->img({id=>$id, src=>$icon,alt=>'['.$suffix.']', -class=>$cssclass, -width=>$width, -onmouseover=>$onmouseover,-onmouseout=>$onmouseout});
        $ret = ($linkit ? $$self{cgi}->a(  {href=>$full,title=>$s}, $img):$img).' '.$ret;
        return $ret;
}
sub mode2str {
        my ($self,$fn,$m) = @_;

        $m = ($$self{backend}->lstat($fn))[2] if $$self{backend}->isLink($fn);
        my @ret = split(//,'-' x 10);

        $ret[0] = 'd' if $$self{backend}->isDir($fn);
        $ret[0] = 'b' if $$self{backend}->isBlockDevice($fn);
        $ret[0] = 'c' if $$self{backend}->isCharDevice($fn);
        $ret[0] = 'l' if $$self{backend}->isLink($fn);

        $ret[1] = 'r' if ($m & 0400) == 0400;
        $ret[2] = 'w' if ($m & 0200) == 0200;
        $ret[3] = 'x' if ($m & 0100) == 0100;
        $ret[3] = 's' if $$self{backend}->hasSetUidBit($fn);

        $ret[4] = 'r' if ($m & 0040) == 0040;
        $ret[5] = 'w' if ($m & 0020) == 0020;
        $ret[6] = 'x' if ($m & 0010) == 0010;
        $ret[6] = 's' if $$self{backend}->hasSetGidBit($fn);

        $ret[7] = 'r' if ($m & 0004) == 0004;
        $ret[8] = 'w' if ($m & 0002) == 0002;
        $ret[9] = 'x' if ($m & 0001) == 0001;
        $ret[9] = 't' if $$self{backend}->hasStickyBit($fn);


        return join('',@ret);
}
sub getSearchResult {
        my ($self,$search,$fn,$ru,$isRecursive, $fullcount, $visited) = @_;
        my $content = "";
        $main::ALLOW_FILE_MANAGEMENT=0;

        ## link loop detection:
        my $nfn = $$self{backend}->resolve($fn);
        return $content if $$visited{$nfn};
        $$visited{$nfn}=1;

        my ($list,$count)=getFolderList($fn,$ru,$search);
        $content.=$$self{cgi}->hr().$$self{cgi}->div({-class=>'resultcount'},$count.$self->tl($count>1?'searchresults':'searchresult')).getQuickNavPath($fn,$ru).$list if $count>0 && $isRecursive;
        $$fullcount+=$count;
        if ($$self{backend}->isReadable($fn)) {
                foreach my $filename (sort { $self->cmp_files } @{$$self{backend}->readDir($fn,getFileLimit($fn),\&main::filterCallback)}) {
                        local($main::PATH_TRANSLATED);
                        my $full = $fn.$filename;
                        next if is_hidden($full);
                        my $nru = $ru.uri_escape($filename);
                        my $isDir = $$self{backend}->isDir($full);
                        $full.="/" if $isDir;
                        $nru.="/" if $isDir;
                        $main::PATH_TRANSLATED = $full;
                        $content.=$self->getSearchResult($search,$full,$nru,1,$fullcount,$visited) if $isDir;
                }
        }
        if (!$isRecursive) {
                if ($$fullcount==0) {
                        $content.=$$self{cgi}->h2($self->tl('searchnothingfound') . "'" .$$self{cgi}->escapeHTML($search)."'".$self->tl('searchgoback').getQuickNavPath($fn,$ru));
                } else {
                        $content=$$self{cgi}->h2("$$fullcount ".$self->tl($$fullcount>1?'searchresultsfor':'searchresultfor')."'".$$self{cgi}->escapeHTML($search)."'".$self->tl('searchgoback').getQuickNavPath($fn,$ru))
                                . ($count>0 ?  $$self{cgi}->hr().$$self{cgi}->div({-class=>'results'},$count.$self->tl($count>1?'searchresults':'searchresult')).getQuickNavPath($fn,$ru).$list : '' )
                                . $content;
                }
        }
        return $content;
}
sub renderToggleFieldSet {
        my($self,$name,$content,$notoggle) = @_;

        my $display = $$self{cgi}->cookie('toggle'.$name) || 'none';
        return qq@<fieldset><legend>@
                .($notoggle ? '' : $$self{cgi}->span({-id=>"togglebutton$name",-onclick=>"toggle('$name');", -class=>'toggle'},$display eq 'none' ? '+' : '-'))
                .$$self{cgi}->escapeHTML($self->tl($name))
                .qq@</legend>@
                .$$self{cgi}->div({-id=>"toggle$name",-style=>($notoggle ? 'display:block;' : 'display:'.$display.';')}, $content)
                .qq@</fieldset>@;
}
sub renderFieldSet { my $self=shift; return $self->renderToggleFieldSet($_[0],$_[1],1); }
sub renderDeleteFilesButton { my $self=shift; return $$self{cgi}->submit(-title=>$self->tl('deletefilestext'),-name=>'delete',-disabled=>'disabled',-value=>$self->tl('deletefilesbutton'),-onclick=>'return window.confirm("'.$self->tl('deletefilesconfirm').'");'); }
sub renderCopyButton { 
	my ($self) = @_;
	return $$self{cgi}->button({-onclick=>'clpaction("copy")', -disabled=>'disabled', -name=>'copy', -class=>'copybutton', -value=> $self->tl('copy'), -title=>$self->tl('copytooltip')}); 
}
sub renderCutButton { my $self=shift; return $$self{cgi}->button({-onclick=>'clpaction("cut")', -disabled=>'disabled', -name=>'cut', -class=>'cutbutton', -value=>$self->tl('cut'), -title=>$self->tl('cuttooltip')}); }
sub renderPasteButton { my $self = shift; return $$self{cgi}->button({-onclick=>'clpaction("paste")', -disabled=>'disabled', -name=>'paste', -class=>'pastebutton',-value=>$self->tl('paste')}); }
sub renderToolbar {
	my ($self) = @_;
        my $clpboard = "";
        $clpboard = $$self{cgi}->div({-class=>'clipboard'}, $self->renderCopyButton().$self->renderCutButton().$self->renderPasteButton()) if ($main::ENABLE_CLIPBOARD);
        return $$self{cgi}->div({-class=>'toolbar'},
                        $clpboard
                        .$$self{cgi}->div({-class=>'functions'},
                                (!$main::ALLOW_ZIP_DOWNLOAD ? '' : $$self{cgi}->span({-title=>$self->tl('zipdownloadtext')}, $$self{cgi}->submit(-name=>'zip', -disabled=>'disabled', -value=>$self->tl('zipdownloadbutton'))))
                                .'&nbsp;&nbsp;'
                                .$$self{cgi}->input({-name=>'colname1', -size=>10, -onkeypress=>'return catchEnter(event, "createfolder1")'}).$$self{cgi}->submit(-id=>'createfolder1', -name=>'mkcol',-value=>$self->tl('createfolderbutton'))
                                .'&nbsp;&nbsp;'
                                .$self->renderDeleteFilesButton()
                        )
                );
}
sub renderFileUploadView {
        my ($self,$fn,$bid) = @_;
        return $$self{cgi}->hidden(-name=>'upload',-value=>1)
                .$$self{cgi}->span({-id=>'file_upload'},$self->tl('fileuploadtext').$$self{cgi}->filefield(-id=>$bid?$bid:'filesubmit'.(++$WEB_ID), -name=>'file_upload', -class=>'fileuploadfield', -multiple=>'multiple', -onchange=>'return addUploadField()' ))
                .$$self{cgi}->span({-id=>'moreuploads'},"")
                .' '.$$self{cgi}->a({-onclick=>'javascript:return addUploadField(1);',-href=>'#'},$self->tl('fileuploadmore'))
                .$$self{cgi}->div({-class=>'uploadfuncs'},
                        $$self{cgi}->submit(-name=>'filesubmit',-value=>$self->tl('fileuploadbutton'),-onclick=>'return window.confirm("'.$self->tl('fileuploadconfirm').'");')
                );
}
sub renderCreateNewFolderView {
	my $self=shift;
        return $$self{cgi}->div({-class=>'createfolder'},'&bull; '.$self->tl('createfoldertext').$$self{cgi}->input({-id=>$_[0]?$_[0]:'colname'.(++$WEB_ID), -name=>'colname', -size=>30, -onkeypress=>'return catchEnter(event,"createfolder");'}).$$self{cgi}->submit(-id=>'createfolder', -name=>'mkcol',-value=>$self->tl('createfolderbutton')))
}
sub renderMoveView {
	my $self =shift;
        return $$self{cgi}->div({-class=>'movefiles', -id=>'movefiles'},
                '&bull; '.$self->tl('movefilestext')
                .$$self{cgi}->input({-id=>$_[0]?$_[0]:'newname'.(++$WEB_ID), -name=>'newname',-disabled=>'disabled',-size=>30,-onkeypress=>'return catchEnter(event,"rename");'}).$$self{cgi}->submit(-id=>'rename',-disabled=>'disabled', -name=>'rename',-value=>$self->tl('movefilesbutton'),-onclick=>'return window.confirm("'.$self->tl('movefilesconfirm').'");')
        );
}
sub renderCreateSymLinkView {
	my $self = shift;
        return $$self{cgi}->div({-class=>'createsymlink', -title=>$self->tl('createsymlinkdescr')},
                '&bull; '.$self->tl('createsymlinktext')
                .$$self{cgi}->input({-id=>'linkdstname', -disabled=>'disabled', -name=>'lndst', -size=>30, -onkeypress=>'return catchEnter(event,"createsymlink");'})
                .$$self{cgi}->submit(-id=>'createsymlink', -disabled=>'disabled', -name=>'createsymlink',-value=>$self->tl('createsymlinkbutton'))
        );

}

sub renderViewFilterView {
	my $self = shift;
        my $content ="";

        my @typesdefault;
        my $filter = $$self{cgi}->cookie('filter.types');
        if (defined $filter && $filter =~ /^[fdl\-]+$/i) {
                push @typesdefault, 'l' if $filter=~/l/i;
                push @typesdefault, 'd' if $filter=~/d/i;
                push @typesdefault, 'f' if $filter=~/f/i;
        } else {
                @typesdefault = ( 'f','d','l' );
        }

        my($sizeopdefault,$sizevaldefault,$sizeunitdefault) = ('==','','B');
        $filter = $$self{cgi}->cookie('filter.size');
        if (defined $filter && $filter =~ /^([\<\>\=]+)(\d+)(\w+)$/) {
                ($sizeopdefault, $sizevaldefault, $sizeunitdefault) = ($1,$2,$3);
        }

        my($timeopdefault, $timevaldefault) = ('==','');
        $filter = $$self{cgi}->cookie('filter.time');
        if (defined $filter && $filter =~ /^([\<\>\=]+)(\d+)$/) {
                ($timeopdefault, $timevaldefault) = ($1,$2);
        }

        my ($nameop, $nameval) = ( '=~', '');
        $filter = $$self{cgi}->cookie('filter.name');
        if (defined $filter && $filter =~ /^(\=\~|\^|\$|eq|ne|lt|gt|le|ge) (.*)$/) {
                ($nameop, $nameval) = ($1,$2);
        }

        $content.=$$self{cgi}->div({},
                        $self->tl('filter.name.title')
                        .$self->tl('filter.name.showonly')
                        .$$self{cgi}->popup_menu(-name=>'filter.name.op', -default=>$nameop,
                                -values=>['=~','^','$','eq','ne','lt','gt','ge','le'],
                                -labels=>{ '=~' => $self->tl('filter.name.regexmatch'),
                                             '^' => $self->tl('filter.name.startswith'),
                                             '$' => $self->tl('filter.name.endswith'),
                                            'eq' => $self->tl('filter.name.equal'),
                                            'ne' => $self->tl('filter.name.notequal'),
                                            'lt' => $self->tl('filter.name.lessthan'),
                                            'gt' => $self->tl('filter.name.greaterthan'),
                                            'le' => $self->tl('filter.name.lessorequal'),
                                            'ge' => $self->tl('filter.name.greaterorequal')
                                         })
                        .$$self{cgi}->input({-name=>'filter.name.val', -size=>20, -value=>$nameval, -onkeypress=>'return catchEnter(event,"filter.apply")'})
        );

        $content.=$$self{cgi}->div({},
                        $self->tl('filter.types.title')
                        .$self->tl('filter.types.showonly')
                        .$$self{cgi}->checkbox_group(-values=>['f','d','l'],-name=>'filter.types', defaults=>\@typesdefault, labels=>{d=>$self->tl('filter.types.folder'), l=>$self->tl('filter.types.links'),f=>$self->tl('filter.types.files')})
                        );
        $content.=$$self{cgi}->div({},
                $self->tl('filter.size.title')
                .$self->tl('filter.size.showonly')
                . $$self{cgi}->popup_menu( -name=>'filter.size.op', -defaults=>$sizeopdefault, -values=>['<','<=','==','>=','>'],
                        -labels=>{
                                  '<'=>$self->tl('filter.size.lessthan'),
                                  '<='=>$self->tl('filter.size.lessorequal'),
                                   '=='=> $self->tl('filter.size.equal'),
                                  '>'=>$self->tl('filter.size.greaterthan'),
                                  '>='=>$self->tl('filter.size.greaterorequal'), ### '�', '�'
                                  })
                .$$self{cgi}->input({-size=>10, -name=>'filter.size.val', -value=>$sizevaldefault, -onkeypress=>'return catchEnter(event,"filter.apply")'})
                . $$self{cgi}->popup_menu(-name=>'filter.size.unit', -values=>['B','KB','MB','GB','TB','PB'], defaults=>$sizeunitdefault));
###     $content.=$$self{cgi}->div({},
###             $self->tl('filter.time.title')
###             .$self->tl('filter.time.showonly')
###             .$$self{cgi}->popup_menu( -name=>'filter.time.op', -defaults=>$timeopdefault, -value=>['<','<=','==','>=','>'], labels=>{'=='=>'=', '>='=>'�', '<='=>'�'})
###             .$$self{cgi}->input({-size=>20, -name=>'filter.time.val', -value=>$timevaldefault})
###             );


        $content.=$$self{cgi}->div({-style=>'clear:both'},
                $$self{cgi}->div({-style=>'float: right'},
                        ###$$self{cgi}->checkbox(-name=>'filter.pathonly', -value=>$main::REQUEST_URI, -label=>$self->tl('filter.pathonly'), -checked=>'checked').
                        $$self{cgi}->button(-name=>'filter.apply',-value=>$self->tl('filter.apply'), -onclick=>'return applyFilters();')
                )
                .$$self{cgi}->div({-style=>'float:left'},$$self{cgi}->button(-name=>'filter.reset',-value=>$self->tl('filter.reset'), -onclick=>'return resetFilters();'))
                );

        return $content;
}

sub renderDeleteView {
	my $self = shift;
        return $$self{cgi}->div({-class=>'delete', -id=>'delete'},'&bull; '.$$self{cgi}->submit(-disabled=>'disabled', -name=>'delete', -value=>$self->tl('deletefilesbutton'), -onclick=>'return window.confirm("'.$self->tl('deletefilesconfirm').'");')
                .' '.$self->tl('deletefilestext'));
}
sub renderCreateNewFileView {
	my $self = shift;
        return $$self{cgi}->div($self->tl('newfilename').$$self{cgi}->input({-id=>'cnfname',-size=>30,-type=>'text',-name=>'cnfname',-onkeypress=>'return catchEnter(event,"createnewfile")'}).$$self{cgi}->submit({-id=>'createnewfile',-name=>'createnewfile',-value=>$self->tl('createnewfilebutton')}));
}
sub renderEditTextResizer {
        my ($self,$text, $pid) = @_;
        return $text.$$self{cgi}->div({-class=>'textdataresizer', -onmousedown=>'handleTextAreaResize(event,"textdata","'.$pid.'",1);',-onmouseup=>'handleTextAreaResize(event,"textdata","'.$pid.'",0)'},'&nbsp;');
}
sub renderEditTextView {
	my $self = shift;
        my $file = $main::PATH_TRANSLATED. $$self{cgi}->param('edit');

        my ($cols,$rows,$ff) = $$self{cgi}->cookie('textdata') ? split(/\//,$$self{cgi}->cookie('textdata')) : (70,15,'mono');
        my $fftoggle = $ff eq 'mono' ? 'prop' : 'mono';

        my $cmsg = $self->tl('confirmsavetextdata',escapeQuotes($$self{cgi}->param('edit')));

        return $$self{cgi}->div($$self{cgi}->param('edit').':')
              .$$self{cgi}->div(
                 $$self{cgi}->hidden(-id=>'filename', -name=>'filename', -value=>$$self{cgi}->param('edit'))
                .$$self{cgi}->hidden(-id=>'mimetype',-name=>'mimetype', -value=>main::getMIMEType($file))
                .$$self{cgi}->div({-class=>'textdata'},
                        $$self{cgi}->textarea({-id=>'textdata',-class=>'textdata '.$ff,-name=>'textdata', -autofocus=>'autofocus',-default=>$$self{backend}->getFileContent($file), -rows=>$rows, -cols=>$cols})
                        )
                .$$self{cgi}->div({-class=>'textdatabuttons'},
                                $$self{cgi}->button(-value=>$self->tl('cancel'), -onclick=>'if (window.confirm("'.$self->tl('canceledit').'")) window.location.href="'.$main::REQUEST_URI.'";')
                                . $$self{cgi}->submit(-style=>'float:right',-name=>'savetextdata',-onclick=>"return window.confirm('$cmsg');", -value=>$self->tl('savebutton'))
                                . $$self{cgi}->submit(-style=>'float:right',-name=>'savetextdatacont',-onclick=>"return window.confirm('$cmsg');", -value=>$self->tl('savecontbutton'))
                )
              );
}

sub renderChangePermissionsView {
	my $self = shift;
        return $$self{cgi}->start_table()
                        . $$self{cgi}->Tr($$self{cgi}->td({-colspan=>2},$self->tl('changefilepermissions'))
                                )
                        .(defined $main::PERM_USER
                                ? $$self{cgi}->Tr($$self{cgi}->td( $self->tl('user') )
                                        . $$self{cgi}->td($$self{cgi}->checkbox_group(-name=>'fp_user', -values=>$main::PERM_USER,
                                                -labels=>{'r'=>$self->tl('readable'), 'w'=>$self->tl('writeable'), 'x'=>$self->tl('executable'), 's'=>$self->tl('setuid')}))
                                        )
                                : ''
                        )
                        .(defined $main::PERM_GROUP
                                ? $$self{cgi}->Tr($$self{cgi}->td($self->tl('group') )
                                        . $$self{cgi}->td($$self{cgi}->checkbox_group(-name=>'fp_group', -values=>$main::PERM_GROUP,
                                                -labels=>{'r'=>$self->tl('readable'), 'w'=>$self->tl('writeable'), 'x'=>$self->tl('executable'), 's'=>$self->tl('setgid')}))
                                        )
                                : ''
                         )
                        .(defined $main::PERM_OTHERS
                                ? $$self{cgi}->Tr($$self{cgi}->td($self->tl('others'))
                                        .$$self{cgi}->td($$self{cgi}->checkbox_group(-name=>'fp_others', -values=>$main::PERM_OTHERS,
                                                -labels=>{'r'=>$self->tl('readable'), 'w'=>$self->tl('writeable'), 'x'=>$self->tl('executable'), 't'=>$self->tl('sticky')}))
                                        )
                                : ''
                         )
                        . $$self{cgi}->Tr( $$self{cgi}->td( {-colspan=>2},
                                                $$self{cgi}->popup_menu(-name=>'fp_type',-values=>['a','s','r'], -labels=>{ 'a'=>$self->tl('add'), 's'=>$self->tl('set'), 'r'=>$self->tl('remove')})
                                                .($main::ALLOW_CHANGEPERMRECURSIVE ? ' '.$$self{cgi}->checkbox_group(-name=>'fp_recursive', -value=>['recursive'],
                                                                -labels=>{'recursive'=>$self->tl('recursive')}) : '')
                                                . ' '. $$self{cgi}->submit(-disabled=>'disabled', -name=>'changeperm',-value=>$self->tl('changepermissions'), -onclick=>'return window.confirm("'.$self->tl('changepermconfirm').'");')
                        ))
                . $$self{cgi}->Tr($$self{cgi}->td({-colspan=>2},$self->tl('changepermlegend')))
                . $$self{cgi}->end_table();
}
sub renderZipDownloadButton { my $self=shift; return $$self{cgi}->submit(-disabled=>'disabled',-name=>'zip',-value=>$self->tl('zipdownloadbutton'),-title=>$self->tl('zipdownloadtext')) }
sub renderZipUploadView {
	my $self=shift;
        return $self->tl('zipuploadtext').$$self{cgi}->filefield(-name=>'zipfile_upload', -id=>'zipfile_upload',-multiple=>'multiple').$$self{cgi}->submit(-name=>'uncompress', -value=>$self->tl('zipuploadbutton'),-onclick=>'return window.confirm("'.$self->tl('zipuploadconfirm').'");');
}
sub renderZipView {
	my $self=shift;
        my $content = "";
        $content .= '&bull; '.$self->renderZipDownloadButton().$self->tl('zipdownloadtext').$$self{cgi}->br() if $main::ALLOW_ZIP_DOWNLOAD;
        $content .= '&bull; '.$self->renderZipUploadView() if $main::ALLOW_ZIP_UPLOAD;
        return $content;
}
sub getActionViewInfos {
        my ($self,$action) = @_;
        return $$self{cgi}->cookie($action) ? split(/\//, $$self{cgi}->cookie($action)) : ( 'false', undef, undef, undef, 'null');
}
sub renderActionView {
        my ($self,$action, $name, $view, $focus, $forcevisible, $resizeable) = @_;
        my $style = '';
        my ($visible, $x, $y, $z,$collapsed) = $self->getActionViewInfos($action);
        my $dzi = $$self{cgi}->cookie('dragZIndex') ? $$self{cgi}->cookie('dragZIndex') : $z ? $z : 10;
        $style .= $forcevisible || $visible eq 'true' ? 'visibility: visible;' :'';
        $style .= $x ? 'left: '.$x.';' : '';
        $style .= $y ? 'top: '.$y.';' : '';
        $style .= 'z-index:'.($forcevisible ? $dzi : $z ? $z : $dzi).';';
        return $$self{cgi}->div({-class=>'sidebaractionview'.($collapsed eq 'collapsed'?' collapsed':''),-id=>$action,
                                -onclick=>"handleWindowClick(event,'$action'".($focus?",'$focus'":'').')', -style=>$style},
                $$self{cgi}->div({-class=>'sidebaractionviewheader',
                                -ondblclick=>$forcevisible ? undef : "toggleCollapseAction('$action',event)",
                                -onmousedown=>"handleWindowMove(event,'$action', 1)",
                                -onmouseup=>"handleWindowMove(event,'$action',0)"},
                                ($forcevisible ? '' : $$self{cgi}->span({-onclick=>"hideActionView('$action');",-class=>'sidebaractionviewclose'},' [X] '))
                                .
                                $self->tl($name)
                        )
                .$$self{cgi}->div({-class=>'sidebaractionviewaction'.($collapsed eq 'collapsed'?' collapsed':''),-id=>"v_$action"},$view)
                .($resizeable ? $$self{cgi}->div({-class=>'sidebaractionviewresizer'.($collapsed eq 'collapsed'?' collapsed':''), -onmousedown=>"handleWindowResize(event,'$action',1);", -onmouseup=>"handleWindowResize(event,'$action',0);"},'&nbsp') : '')


                );
}
sub renderSideBarMenuItem {
        my ($self,$action, $title, $onclick, $content) = @_;
        my $isactive = ($self->getActionViewInfos($action))[0] eq 'true';
        return $$self{cgi}->div({
                                -id=>$action.'menu', -class=>'sidebaraction'.($isactive?' active':''),
                                -onmouseover=>'javascript:addClassName(this, "highlight");', -onmouseout=>'javascript:removeClassName(this, "highlight");',
                                -onclick=>$onclick, -title=>$title},
                        $content);
}
sub renderAutoRefresh {
	my $self=shift;
        return $self->tl('autorefresh').$$self{cgi}->popup_menu(-onchange=>'setAutoRefresh(this.value)', -id=>'autorefresh',-name=>'autorefresh', -values=> \@main::AUTOREFRESHVALUES, -labels=> { 0=>$self->tl('off'), 10=>'10s', 30=>'30s', 60 => '1min', 300=>'5min',600=>'10min',1800=>'30min',3600=>'1h' }, -default=>[$$self{cgi}->cookie('autorefresh')]);
}
sub renderSideBar {
	my $self=shift;
        my $content = "";
        my $av = "";

        if ($main::ALLOW_FILE_MANAGEMENT) {
                $content .= $$self{cgi}->div({-class=>'sidebarheader'}, $self->tl('management'));
                $content .= $self->renderSideBarMenuItem('fileuploadview',$self->tl('upload'), 'toggleActionView("fileuploadview","filesubmit")',$$self{cgi}->button({-value=>$self->tl('upload'), -name=>'filesubmit'}));
                $content .= $self->renderSideBarMenuItem('zipfileuploadview',$self->tl('zipfileupload'), 'toggleActionView("zipfileuploadview","zipfile_upload")',$$self{cgi}->button({-value=>$self->tl('zipfileupload'), -name=>'uncompress'})) if $main::ALLOW_ZIP_UPLOAD;
                $content .= $self->renderSideBarMenuItem('download', $self->tl('download'), undef, $self->renderZipDownloadButton()) if $main::ALLOW_ZIP_DOWNLOAD;
                $content .= $self->renderSideBarMenuItem('copy',$self->tl('copytooltip'), undef, $self->renderCopyButton());
                $content .= $self->renderSideBarMenuItem('cut', $self->tl('cuttooltip'), undef, $self->renderCutButton());
                $content .= $self->renderSideBarMenuItem('paste', undef, undef, $self->renderPasteButton());
                $content .= $self->renderSideBarMenuItem('deleteview', undef, undef, $self->renderDeleteFilesButton());
                $content .= $self->renderSideBarMenuItem('createfolderview', $self->tl('createfolderbutton'), 'toggleActionView("createfolderview","colname-sidebar");', $$self{cgi}->button({-value=> $self->tl('createfolderbutton'),-name=>'mkcol'}));
                $content .= $self->renderSideBarMenuItem('createnewfileview', $self->tl('createnewfilebutton'), 'toggleActionView("createnewfileview","cnfname");', $$self{cgi}->button({-value=>$self->tl('createnewfilebutton'),-name=>'createnewfile'}));
                $content .= $self->renderSideBarMenuItem('creatensymlinkview', $self->tl('createsymlinkdescr'), 'toggleActionView("createsymlinkview","lndst");', $$self{cgi}->button({-value=>$self->tl('createsymlinkbutton'),-name=>'createsymlink',-disabled=>'disabled'})) if $main::ALLOW_SYMLINK;
                $content .= $self->renderSideBarMenuItem('movefilesview', $self->tl('movefilesbutton'), undef, $$self{cgi}->button({-disabled=>'disabled',-onclick=>'toggleActionView("movefilesview","newname");',-name=>'rename',-value=>$self->tl('movefilesbutton')}));
                $content .= $self->renderSideBarMenuItem('permissionsview', $self->tl('mode'), undef, $$self{cgi}->button({-disabled=>'disabled', -onclick=>'toggleActionView("permissionsview");', -value=>$self->tl('mode'),-name=>'changeperm',-disabled=>'disabled'})) if $main::ALLOW_CHANGEPERM;
                $content .= $self->renderSideBarMenuItem('afsaclmanagerview', $self->tl('afs'), 'toggleActionView("afsaclmanagerview");', $$self{cgi}->button({-value=>$self->tl('afs'),-name=>'saveafsacl'})) if $main::ENABLE_AFSACLMANAGER;
                $content .= $$self{cgi}->hr().$self->renderSideBarMenuItem('afsgroupmanagerview', $self->tl('afsgroup'), 'toggleActionView("afsgroupmanagerview");', $$self{cgi}->button({-value=>$self->tl('afsgroup')})).$$self{cgi}->hr() if $main::ENABLE_AFSGROUPMANAGER;
                $av.= $self->renderActionView('fileuploadview', 'upload', $self->renderFileUploadView($main::PATH_TRANSLATED,'filesubmit'), 'filesubmit',0,0);
                $av.= $self->renderActionView('zipfileuploadview', 'zipfileupload', $self->renderZipUploadView(), 'zipfile_upload',0,0) if $main::ALLOW_ZIP_UPLOAD;
                $av.= $self->renderActionView('createfolderview', 'createfolderbutton', $self->renderCreateNewFolderView("colname-sidebar"),'colname-sidebar');
                $av.= $self->renderActionView('createnewfileview', 'createnewfilebutton', $self->renderCreateNewFileView(),'cnfname');
                $av.= $self->renderActionView('createsymlinkview', 'createsymlinkbutton', $self->renderCreateSymLinkView(),'lndst') if $main::ALLOW_SYMLINK;
                $av.= $self->renderActionView('movefilesview', 'movefilesbutton', $self->renderMoveView("newname"),'newname');
                $av.= $self->renderActionView('permissionsview', 'mode', $self->renderChangePermissionsView()) if $main::ALLOW_CHANGEPERM;
                $av.= $self->renderActionView('afsaclmanagerview', 'afs', $self->renderAFSACLManager()) if $main::ENABLE_AFSACLMANAGER;
                $av.= $self->renderActionView('afsgroupmanagerview', 'afsgroup', $self->renderAFSGroupManager()) if $main::ENABLE_AFSGROUPMANAGER;

                $av.= $self->renderActionView('editview','editbutton',$self->renderEditTextResizer($self->renderEditTextView(),'editview'),'textdata',1) if $main::ALLOW_EDIT && $$self{cgi}->param('edit');
        }

        $content .= $$self{cgi}->div({-class=>'sidebarheader'},$self->tl('viewoptions'));
        my $showall = $$self{cgi}->param('showpage') ? 0 : $$self{cgi}->param('showall') || $$self{cgi}->cookie('showall') || 0;
        $content .= $self->renderSideBarMenuItem('navpageview', $self->tl('navpageviewtooltip'), 'window.location.href="?showpage=1";',$$self{cgi}->button(-value=>$self->tl('navpageview'))) if $showall;
        $content .= $self->renderSideBarMenuItem('navall', $self->tl('navalltooltip'),'window.location.href="?showall=1";', $$self{cgi}->button(-value=>$self->tl('navall'))) unless $showall;
        $content .= $self->renderSideBarMenuItem('changeview', $self->tl('classicview'), 'javascript:window.location.href="?view=classic";', $$self{cgi}->button(-value=>$self->tl('classicview')));
        $content .= $self->renderSideBarMenuItem('filterview',$self->tl('filter.title'), 'toggleActionView("filterview","filter.size.op");', $$self{cgi}->button(-value=>$self->tl('filter.title'), -name=>'filter'));
        $content .= $self->renderActionView('filterview', 'filter.title', $self->renderViewFilterView());
        #$content .= $self->renderSideBarMenuItem('autorefreshview',$self->tl('autorefresh'),'javascript:toggleActionView("autorefreshview","autorefresh")', $$self{cgi}->button(-value=>$self->tl('autorefreshbutton')));
        #$av.=$self->renderActionView('autorefreshview','autorefreshbutton',$self->renderAutoRefresh());


        my $showsidebar =  (! defined $$self{cgi}->cookie('sidebar') || $$self{cgi}->cookie('sidebar') eq 'true');
        my $sidebartogglebutton = $showsidebar ? '&lt;' : '&gt;';

        return $$self{cgi}->div({-id=>'sidebar', -class=>'sidebar'}, $$self{cgi}->start_table({-id=>'sidebartable',-class=>'sidebartable'.($showsidebar ?'':' collapsed')}).$$self{cgi}->Tr($$self{cgi}->td({-id=>'sidebarcontent', -class=>'sidebarcontent'.($showsidebar?'':' collapsed')},$content).$$self{cgi}->td({-id=>'sidebartogglebutton', -title=>$self->tl('togglesidebar'), -class=>'sidebartogglebutton', -onclick=>'toggleSideBar()'},$sidebartogglebutton)).$$self{cgi}->end_table()). $av ;
}


sub renderAFSACLManager {
	my $self=shift;
        my @entries;
        my $pt = $main::PATH_TRANSLATED;
        $pt=~s/(["\$\\])/\\$1/g;
        open(my $afs, "$main::AFS_FSCMD listacl \"$pt\" |") or die("cannot execute $main::AFS_FSCMD list \"$main::PATH_TRANSLATED\"");
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
                $content.=$$self{cgi}->Tr(
                        $$self{cgi}->th($self->tl( $mustpositive?'afsnormalrights':'afsnegativerights'))
                        .$$self{cgi}->th($self->tl('afslookup')).$$self{cgi}->th($self->tl('afsread')).$$self{cgi}->th($self->tl('afswrite')).$$self{cgi}->th($self->tl('afsinsert'))
                        .$$self{cgi}->th($self->tl('afsdelete')).$$self{cgi}->th($self->tl('afslock')).$$self{cgi}->th($self->tl('afsadmin'))
                );
                foreach my $entry (sort { $$a{user} cmp $$b{user} || $$b{right} cmp $$a{right} } @{$entries}) {
                                my ($user, $right, $ispositive) = ( $$entry{user}, $$entry{right}, $$entry{ispositive} );
                                next if $mustpositive != $ispositive;
                                my $prohibit = !$main::ALLOW_AFSACLCHANGES || grep(/^\Q$user\E$/, @main::PROHIBIT_AFS_ACL_CHANGES_FOR) >0;
                                my $row = $$self{cgi}->td({-title=>"$user $right"}, $user . ($prohibit ? $$self{cgi}->hidden({ -name=>"u$s\[$user\]", -value=>$right}):'') );
                                foreach my $r (split(//,'lrwidka')) {
                                        my %param = ( name=>"u$s\[$user\]", label=>'', value=>$r);
                                        $param{checked} = 'checked' if $right=~/$r/;
                                        $param{disabled} = 'disabled' if $prohibit;
                                        $row .= $$self{cgi}->td({-class=>'afsaclcell'},$$self{cgi}->checkbox(\%param));
                                };
                                $content.=$$self{cgi}->Tr($row);
                }
                if ($main::ALLOW_AFSACLCHANGES) {
                        my $row = $$self{cgi}->td($$self{cgi}->input({-type=>'text', -size=>15, -name=>"u${s}_add"}));
                        foreach my $r ( split(//, 'lrwidka')) {
                                $row .= $$self{cgi}->td({-class=>'afsaclcell'}, $$self{cgi}->checkbox({-name=>"u${s}", -value=>$r, -label=>''}));
                        }
                        $content.=$$self{cgi}->Tr($row);
                }
                return $content;
        }
        my $content = $$self{cgi}->a({-id=>'afsaclmanagerpos'},"").$self->renderMessage('acl')
                        .$$self{cgi}->div($self->tl('afsaclscurrentfolder',$main::PATH_TRANSLATED, $main::REQUEST_URI))
                        .$$self{cgi}->start_table({-class=>'afsacltable'});
        $content .= _renderACLData(\@entries, 1);
        $content .= _renderACLData(\@entries, 0);
        $content .= $$self{cgi}->Tr($$self{cgi}->td({-class=>'afssavebutton',-colspan=>8}, $$self{cgi}->submit({-name=>'saveafsacl', -value=>$self->tl('afssaveacl')}))) if $main::ALLOW_AFSACLCHANGES;
        $content .= $$self{cgi}->end_table();
        $content .= $$self{cgi}->div({-class=>'afsaclhelp'}, $self->tl('afsaclhelp'));
        return $content;
}


sub renderAFSGroupManager {
	my $self=shift;
        my $ru = $main::REMOTE_USER;
        my $grp =  $$self{cgi}->param('afsgrp') || "";
        my @usrs = $$self{cgi}->param('afsusrs') || ( );

        my @groups = split(/\r?\n\s*?/, qx@$main::AFS_PTSCMD listowned $ru@);
        shift @groups; # remove comment
        s/^\s+//g foreach (@groups);
        s/[\s\r\n]+$//g foreach (@groups);
        @groups = sort @groups;

        my $hgc = "";
        $hgc .= sprintf($self->tl('afsgroups'), $ru);
        my $gc = "";
        $gc.= $$self{cgi}->scrolling_list(-name=>'afsgrp', -values=>\@groups, -size=>5, -default=>[ $grp ], -ondblclick=>'document.getElementById("afschgrp").click();' ) if $#groups>-1;

        my $huc ="";
        my $uc = "";
        my $nusr = "";
        my $dusr = "";
        if ($grp ne "") {
                my @users = split(/\r?\n/, qx@$main::AFS_PTSCMD members $grp@);
                shift @users; # remove comment
                s/^\s+//g foreach (@users);
                @users = sort @users;
                chomp @users;

                $huc .= sprintf($self->tl('afsgrpusers'), $grp) . $$self{cgi}->hidden({-name=>'afsselgrp', -value=>$grp});

                $uc.= $$self{cgi}->scrolling_list(-name=>'afsusr', -values=>\@users, -size=>5, -multiple=>'multiple', -defaults=>\@usrs) if $#users>-1;

                $nusr = $$self{cgi}->input({-name=>'afsaddusers', size=>20, -onkeypress=>'return catchEnter(event,"afsaddusr");'}).$$self{cgi}->submit({-id=>'afsaddusr', -name=>'afsaddusr', -value=>$self->tl('afsadduser'),-onclick=>'return window.confirm("'.$self->tl('afsconfirmadduser').'");'}) if $main::ALLOW_AFSGROUPCHANGES;

                $dusr = $$self{cgi}->submit({-name=>'afsremoveusr', -value=>$self->tl('afsremoveuser'), -onclick=>'return window.confirm("'.$self->tl('afsconfirmremoveuser').'");'}) if $main::ALLOW_AFSGROUPCHANGES && $#users > -1;

        }

        my $cb = "";
        $cb .= $$self{cgi}->submit({-id=>'afschgrp',-name=>'afschgrp',-value=>$self->tl('afschangegroup')}) if $#groups>-1;

        my $dgrp ="";
        $dgrp .= $$self{cgi}->submit({-name=>'afsdeletegrp', -value=>$self->tl('afsdeletegroup'),-onclick=>'return window.confirm("'.$self->tl('afsconfirmdeletegrp').'");'}) if $main::ALLOW_AFSGROUPCHANGES && $#groups>-1;

        my $ngrp ="";
        $ngrp .= $$self{cgi}->input({-name=>'afsnewgrp', -size=>20, -onfocus=>'if (this.value == "") { this.value="'.$ru.':"; this.select();}', -onblur=>'if (this.value == "'.$ru.':") this.value="";', -onkeypress=>'return catchEnter(event,"afscreatenewgrp");'}).$$self{cgi}->submit({-id=>'afscreatenewgrp', -name=>'afscreatenewgrp', -value=>$self->tl('afscreatenewgroup'), -onclick=>'return window.confirm("'.$self->tl('afsconfirmcreategrp').'");'}) if $main::ALLOW_AFSGROUPCHANGES;

        my $rgrp = "";
        $rgrp .= $$self{cgi}->input({-name=>'afsnewgrpname',-size=>20, -value=>$$self{cgi}->param('afsnewgrpname')||'',-onfocus=>'if (this.value == "") { this.value="'.$ru.':"; this.select();}', -onblur=>'if (this.value == "'.$ru.':") this.value="";', -onkeypress=>'return catchEnter(event,"afsrenamegrp");'}).$$self{cgi}->submit({-id=>'afsrenamegrp', -name=>'afsrenamegrp', -value=>$self->tl('afsrenamegroup'), -onclick=>'return window.confirm("'.$self->tl('afsconfirmrenamegrp').'");'}) if $main::ALLOW_AFSGROUPCHANGES && $#groups > -1;

        return $$self{cgi}->a({-id=>'afsgroupmanagerpos'},"").$self->renderMessage('afs')
                ##.$$self{cgi}->start_form({-name=>'afsgroupmanagerform', -method=>'post'})
                .$$self{cgi}->start_table({-class=>'afsgroupmanager'})
                .$$self{cgi}->Tr($$self{cgi}->th($hgc).$$self{cgi}->th($huc))
                .$$self{cgi}->Tr($$self{cgi}->td($gc.$$self{cgi}->br().$cb.$$self{cgi}->br().$dgrp.$$self{cgi}->br().$ngrp.$$self{cgi}->br().$rgrp)
                                .$$self{cgi}->td($uc.$$self{cgi}->br().$dusr.$$self{cgi}->br().$nusr))
                .$$self{cgi}->end_table()
                .$$self{cgi}->div({-class=>'afsgrouphelp'}, $self->tl('afsgrouphelp'))
                ##.$$self{cgi}->end_form();
                ;
}

sub frontendFilterCallback {
        my ($path, $file) = @_;
        return 1 if main::filterCallback($path,$file);
        my $ret = 0;
        my $filter = $main::cgi->cookie('filter.types');
        if ( defined $filter ) {
                $ret|=1 if $filter!~/d/ && $main::backend->isDir("$path$file");
                $ret|=1 if $filter!~/f/ && $main::backend->isFile("$path$file");
                $ret|=1 if $filter!~/l/ && $main::backend->isLink("$path$file");
        }
        return 1 if $ret;
        $filter = $main::cgi->cookie('filter.size');
        if ( defined $filter && $main::backend->isFile("$path$file") &&  $filter=~/^([\<\>\=]{1,2})(\d+)(\w*)$/ ) {
                my ($op, $val,$unit) = ($1,$2,$3);
                $val = $val * $BYTEUNITS{$unit} if exists $BYTEUNITS{$unit};
                my $size = ($main::backend->stat("$path$file"))[7];
                $ret=!eval("$size $op $val");
        }
        return 1 if $ret;
        $filter = $main::cgi->cookie('filter.name');
        if (defined $filter && defined $file && $filter =~ /^(\=\~|\^|\$|eq|ne|lt|gt|le|ge) (.*)$/) {
                my ($nameop,$nameval) = ($1,$2);
                $nameval=~s/\//\/\//g;
                if ($nameop eq '^') {
                        $ret=!eval(qq@'$file' =~ /\^\Q$nameval\E/i@);
                } elsif ($nameop eq '$') {
                        $ret=!eval(qq@'$file' =~ /\Q$nameval\E\$/i@);
                } elsif ($nameop eq '=~') {
                        $ret=!eval("'$file' $nameop /$nameval/i");
                } else {
                        $ret=!eval("lc('$file') $nameop lc(q/$nameval/)");
                }
        }
        return 1 if $ret;

        $filter = $main::cgi->cookie('filter.time');
        if ( defined $filter && $filter=~/^([\<\>\=]{1,2})(\d+)$/) {
                my ($op, $val) = ($1, $2);
                my $mtime = ($main::backend->stat("$path$file"))[9];
                $ret=!eval("$val $op $mtime");
        }
        return $ret;
}
sub renderSysInfo {
	my $self = shift;
        my $i = "";
        $i.= $self->start_html("$main::TITLEPREFIX SysInfo");

        $i.= $$self{cgi}->h1('WebDAV CGI SysInfo');
        $i.= $$self{cgi}->h2('Process - '.$0);
        $i.= $$self{cgi}->start_table()
             .$$self{cgi}->Tr($$self{cgi}->td('BASETIME').$$self{cgi}->td(''.localtime($^T)))
             .$$self{cgi}->Tr($$self{cgi}->td('OSNAME').$$self{cgi}->td($^O))
             .$$self{cgi}->Tr($$self{cgi}->td('PID').$$self{cgi}->td($$))
             .$$self{cgi}->Tr($$self{cgi}->td('REAL UID').$$self{cgi}->td($<))
             .$$self{cgi}->Tr($$self{cgi}->td('EFFECTIVE UID').$$self{cgi}->td($>))
             .$$self{cgi}->Tr($$self{cgi}->td('REAL GID').$$self{cgi}->td($())
             .$$self{cgi}->Tr($$self{cgi}->td('EFFECTIVE GID').$$self{cgi}->td($)))

             .$$self{cgi}->end_table();
        $i.= $$self{cgi}->h2('Perl');
        $i.= $$self{cgi}->start_table()
                .$$self{cgi}->Tr($$self{cgi}->td('version').$$self{cgi}->td(sprintf('%vd',$^V)))
                .$$self{cgi}->Tr($$self{cgi}->td('debugging').$$self{cgi}->td($^D))
                .$$self{cgi}->Tr($$self{cgi}->td('taint mode').$$self{cgi}->td(${^TAINT}))
                .$$self{cgi}->Tr($$self{cgi}->td('unicode').$$self{cgi}->td(${^UNICODE}))
                .$$self{cgi}->Tr($$self{cgi}->td('warning').$$self{cgi}->td($^W))
                .$$self{cgi}->Tr($$self{cgi}->td('executable name').$$self{cgi}->td($^X))
                .$$self{cgi}->end_table();
        $i.= $$self{cgi}->h2('Perl Variables');
        $i.= $$self{cgi}->start_table()
                .$$self{cgi}->Tr($$self{cgi}->td('@INC').$$self{cgi}->td(join(" ",@INC)))
                .$$self{cgi}->end_table();

        $i.= $$self{cgi}->h2('Includes');
        $i.= $$self{cgi}->start_table();
        foreach my $e (sort keys %INC) {
                $i.=$$self{cgi}->Tr($$self{cgi}->td($e).$$self{cgi}->td($ENV{$e}));
        }
        $i.= $$self{cgi}->end_table();

        $i.= $$self{cgi}->h2('System Times');
        my ($user,$system,$cuser,$csystem) = times;
        $i.=  $$self{cgi}->start_table()
             .$$self{cgi}->Tr($$self{cgi}->td('user (s)').$$self{cgi}->td($user))
             .$$self{cgi}->Tr($$self{cgi}->td('system (s)').$$self{cgi}->td($system))
             .$$self{cgi}->Tr($$self{cgi}->td('cuser (s)').$$self{cgi}->td($cuser))
             .$$self{cgi}->Tr($$self{cgi}->td('csystem (s)').$$self{cgi}->td($csystem))
             .$$self{cgi}->end_table();
        $i.= $$self{cgi}->h2('Environment');
        $i.= $$self{cgi}->start_table();
        foreach my $e (sort keys %ENV) {
                $i.=$$self{cgi}->Tr($$self{cgi}->td($e).$$self{cgi}->td($ENV{$e}));
        }
        $i.= $$self{cgi}->end_table();

        $i.=$$self{cgi}->end_html();

	main::printHeaderAndContent('200 OK', 'text/html', $i);
}

sub cmp_strings {
        my ($_a,$_b) = @_;
        return substr($_a,0,1) cmp substr($_b,0,1) || $_a cmp $_b;
}
sub cmp_files {
	my $self = shift;
        my $fp_a = $main::PATH_TRANSLATED.$a;
        my $fp_b = $main::PATH_TRANSLATED.$b;
        my $factor = ($main::ORDER =~/_desc$/) ? -1 : 1;
        return -1 if $$self{backend}->isDir($fp_a) && !$$self{backend}->isDir($fp_b);
        return 1 if !$$self{backend}->isDir($fp_a) && $$self{backend}->isDir($fp_b);
        if ($main::ORDER =~ /^(lastmodified|created|size|mode)/) {
                my $idx = $main::ORDER=~/^lastmodified/? 9 : $main::ORDER=~/^created/ ? 10 : $main::ORDER=~/^mode/? 2 : 7;
                return $factor * ( ($$self{backend}->stat($fp_a))[$idx] <=> ($$self{backend}->stat($fp_b))[$idx] || cmp_strings($$self{backend}->getDisplayName($fp_a),$$self{backend}->getDisplayName($fp_b)) );
        } elsif ($main::ORDER =~ /mime/) {
                return $factor * ( cmp_strings(getMIMEType($a), getMIMEType($b)) || cmp_strings($$self{backend}->getDisplayName($fp_a),$$self{backend}->getDisplayName($fp_b)));
        }
        return $factor * cmp_strings($$self{backend}->getDisplayName($fp_a),$$self{backend}->getDisplayName($fp_b));
}

1;