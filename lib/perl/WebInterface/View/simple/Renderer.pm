#!/usr/bin/perl
#########################################################################
# (C) ZE CMS, Humboldt-Universitaet zu Berlin
# Written 2010-2013 by Daniel Rohde <d.rohde@cms.hu-berlin.de>
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

package WebInterface::View::simple::Renderer;

use strict;
no strict "refs";
use warnings;

use POSIX qw(strftime ceil);
use JSON;
use URI::Escape;
use DateTime;
use DateTime::Format::Human::Duration;

use WebInterface::Common;
our @ISA = ( 'WebInterface::Common' );

use vars qw(%CACHE @ERRORS %BYTEUNITS);
%BYTEUNITS = (B=>1, KB=>1024, MB => 1048576, GB => 1073741824, TB => 1099511627776, PB =>1125899906842624 );

sub render {
	my($self,$fn,$ru) = @_;
	my $content ='';
	my $contenttype= 'text/html';
	$self->setLocale();
	unless ('selector' ~~ @main::ALLOWED_TABLE_COLUMNS) {
		unshift @main::ALLOWED_TABLE_COLUMNS, 'selector';
		unshift @main::VISIBLE_TABLE_COLUMNS, 'selector';
	}

	if ($$self{cgi}->param('ajax')) {
		my $ajax = $$self{cgi}->param('ajax');
		if ($ajax eq 'getFileListTable') { 
			$content = $self->renderFileListTable($fn,$ru, $$self{cgi}->param('template')); 
			$contenttype='application/json';
		} elsif ($ajax eq 'getViewFilterDialog') {
			$content = $self->renderViewFilterDialog($fn, $ru, $$self{cgi}->param('template'));
		} elsif ($ajax eq 'getSearchDialog') {
			$content = $self->renderTemplate($fn,$ru,$self->readTemplate($$self{cgi}->param('template')));
		} elsif ($ajax eq 'getTableConfigDialog') {
			$content = $self->renderTemplate($fn,$ru,$self->readTemplate($$self{cgi}->param('template')));
		} elsif ($ajax eq 'getFileListEntry') {
			my $entrytemplate=$self->renderExtensionFunction($self->readTemplate($$self{cgi}->param('template')));
			my $columns = $self->renderVisibleTableColumns($entrytemplate).$self->renderInvisibleAllowedTableColumns($entrytemplate);
			$entrytemplate=~s/\$filelistentrycolumns/$columns/esg;
			$content = $self->renderFileListEntry($fn, $ru, $$self{cgi}->param('file'), $entrytemplate);
		}
	} elsif ($$self{cgi}->param('msg') || $$self{cgi}->param('errmsg') 
			|| $$self{cgi}->param('aclmsg') || $$self{cgi}->param('aclerrmsg')
			|| $$self{cgi}->param('afsmsg') || $$self{cgi}->param('afserrmsg')) {
		my $msg = $$self{cgi}->param('msg') || $$self{cgi}->param('aclmsg') || $$self{cgi}->param('afsmsg');
		my $errmsg = $$self{cgi}->param('errmsg') || $$self{cgi}->param('aclerrmsg') || $$self{cgi}->param('afserrmsg');
		my %jsondata = ();
		my $p = 1;
		my @params = ();
		push(@params,$$self{cgi}->escapeHTML($_)) while ($_=$$self{cgi}->param('p'.($p++))); 
		$jsondata{message} = sprintf($self->tl('msg_'.$msg),@params)  if $msg;
		$jsondata{error} = sprintf($self->tl('msg_'.$errmsg),@params) if $errmsg;
		my $json = new JSON();
		$content = $json->encode(\%jsondata);
		$contenttype='application/json';
	} else {
		$content = $self->minifyHTML($self->renderTemplate($fn,$ru,$self->readTemplate('page')));
	}
	delete $CACHE{$self}{$fn};
	
	main::printCompressedHeaderAndContent('200 OK',$contenttype,$content,'Cache-Control: no-cache, no-store', $self->getCookies());
}
sub minifyHTML {
	my ($self, $content) = @_;
	$content=~s/<!--.*?-->//sg;
	$content=~s/[\r\n]/ /sg;
	$content=~s/\s{2,}/ /sg;
	return $content;
}
sub getQuotaData {
	my ($self, $fn) = @_;
	return $CACHE{$self}{$fn}{quotaData} if exists $CACHE{$self}{$fn}{quotaData};
	my @quota = $main::SHOW_QUOTA ? main::getQuota($fn) : (0,0);
	my $quotastyle ="";
	my $level = 'info';
	if ($main::SHOW_QUOTA && $quota[0] > 0) {
		my $qusage = ($quota[0] - $quota[1]) / $quota[0];
		my $lowestlimit = 1;
		foreach my $l (keys(%main::QUOTA_LIMITS)) {
			if ($main::QUOTA_LIMITS{$l}{limit} && $main::QUOTA_LIMITS{$l}{limit} <= $lowestlimit && $qusage <= $main::QUOTA_LIMITS{$l}{limit}) {
				$level = $l;
				$lowestlimit = $main::QUOTA_LIMITS{$l}{limit};
			}
		}
		if ($main::QUOTA_LIMITS{$level}) {
			$quotastyle.=';color:'.$main::QUOTA_LIMITS{$level}{color} if $main::QUOTA_LIMITS{$level}{color};
			$quotastyle.=';background-color:'.$main::QUOTA_LIMITS{$level}{background} if $main::QUOTA_LIMITS{$level}{background};
		}
	}

	my $ret = { quotalimit=> $quota[0], quotaused => $quota[1], quotaavailable => $quota[0] - $quota[1], quotalevel=>$level, quotastyle=>$quotastyle };
	
	$$ret{quotausedperc} = $$ret{quotalimit}!=0 ? round(100 * $$ret{quotaused} / $$ret{quotalimit}) : 0;
	$$ret{quotaavailableperc} = $$ret{quotalimit}!=0 ? round(100 * $$ret{quotaavailable} / $$ret{quotalimit}) : 0;
	
	$CACHE{$self}{$fn}{quotaData}=$ret;

	return $ret;
}
sub renderTemplate {
	my ($self,$fn,$ru,$content) = @_;
	my $vbase = $ru=~/^($main::VIRTUAL_BASE)/ ? $1 : $ru;
	my %quota =  %{$self->getQuotaData($fn)};
	
	# replace standard variables:
	my %stdvars = ( uri => $ru, 
			baseuri=>$$self{cgi}->escapeHTML($vbase),
			quicknavpath=>$self->renderQuickNavPath($fn,$ru),
			maxuploadsize=>$main::POST_MAX_SIZE,
			maxuploadsizehr=>($self->renderByteValue($main::POST_MAX_SIZE,2,2))[0],
			quotalimit => ($self->renderByteValue($quota{quotalimit},2,))[0],
			quotalimitbytes => $quota{quotalimit},
			quotalimittitle => ($self->renderByteValue($quota{quotalimit},2,))[1],
			quotaused => ($self->renderByteValue($quota{quotaused},2,2))[0],
			quotausedtitle => ($self->renderByteValue($quota{quotaused},2,2))[1],
			quotaavailable => ($self->renderByteValue($quota{quotaavailable},2,2))[0],
			quotaavailabletitle => ($self->renderByteValue($quota{quotaavailable},2,2))[1],
			quotastyle=> $quota{quotastyle},
			quotalevel=> $quota{quotalevel},
			quotausedperc => $quota{quotausedperc},
			quotaavailableperc => $quota{quotaavailableperc},
			view => $main::VIEW,
			viewname => $self->tl("${main::VIEW}view"),
			USER=>$main::REMOTE_USER,
			CLOCK=>$$self{cgi}->span({id=>'clock', 'data-format'=>$self->tl('vartimeformat')},strftime($self->tl('vartimeformat'),localtime())),
			NOW=>strftime($self->tl('varnowformat'), localtime()),
			REQUEST_URI=>$main::REQUEST_URI,
			PATH_TRANSLATED=>$main::PATH_TRANSLATED,
			LANG=>$main::LANG,
			VBASE=>$$self{cgi}->escapeHTML($vbase),
			VHTDOCS=>$vbase.$main::VHTDOCS,
	);
	return $self->SUPER::renderTemplate($fn,$ru,$content, \%stdvars);
}
sub execTemplateFunction {
	my ($self, $fn, $ru, $func, $param) = @_;
	my $content; 
	
	$content = $self->renderFileList($fn,$ru,$param) if $func eq 'filelist';
	$content = $self->isViewFiltered() if $func eq 'isviewfiltered';
	$content = $self->renderFilterInfo() if $func eq 'filterInfo';
	$content = $self->renderLanguageList($fn,$ru,$param) if $func eq 'langList';
	$content = $self->renderExtension($fn,$ru,$param) if $func eq 'extension';
	
	$content = $self->SUPER::execTemplateFunction($fn,$ru,$func,$param) unless defined $content;
	
	return $content;
}
sub renderExtensionElement {
	my($self,$fn,$ru,$a) = @_;
	my $content = "";
	if (ref($a) eq 'HASH') {
		if ($$a{subpopupmenu}) {
			return $$self{cgi}->li({-title=>$$a{title} || $$a{label} || '', -class=>'subpopupmenu extension '. ($$a{classes} || '')},($$a{title} || '').$$self{cgi}->ul({-class=>'subpopupmenu extension'},$self->renderExtensionElement($fn,$ru,$$a{subpopupmenu}))) ;
		}
		my %params = (-class=>'');
		$params{-class}.=' action '.$$a{action} if $$a{action};
		$params{-class}.=' listaction '.$$a{listaction} if $$a{listaction};
		$params{-class}.= ' '.$$a{classes} if $$a{classes};
		$params{-class}.=' hidden' if $$a{disabled};
		$params{-accesskey}=$$a{accesskey} if $$a{accesskey};
		$params{-title}=$self->tl($$a{title} || $$a{label}) if $$a{title} || $$a{label};
		$params{-data_template} = $$a{template} if $$a{template};
		$content.=$$a{prehtml} if $$a{prehtml};
		if ($$a{data}) {
			foreach my $data ( keys %{$$a{data}}) {
				$params{"-data-$data"} = $$a{data}{$data};
			}
		}
		if ($$a{attr}) {
			foreach my $attr ( keys %{$$a{attr}}) {
				$params{"-$attr"} = $$a{attr}{$attr};
			}
		}
		if ($$a{type} && $$a{type} eq 'li') {	
			$content.=$$self{cgi}->li(\%params, $$self{cgi}->span({-class=>'label'},$self->tl($$a{label})));
		} else {
			$params{-href}='#';
			$params{-data_action} = $$a{action} || $$a{listaction}; 
			$content.=$$self{cgi}->a(\%params, $$self{cgi}->span({-class=>'label'},$self->tl($$a{label})));
			$content=$$self{cgi}->li({-class=>$$a{liclasses} || ''},$content) if $$a{type} && $$a{type} eq 'li-a'; 
		}
		$content.=$$a{posthtml} if $$a{posthtml};
	} elsif (ref($a) eq 'ARRAY') {
		$content=join("", map { $self->renderExtensionElement($fn,$ru,$_)} @$a);
	} else {
		$content.=$a;
	}
	return $content;
}
sub renderExtension {
	my ($self,$fn,$ru,$hook) = @_;
	
	if ($hook eq 'javascript') {
		if (main::getWebInterface()->optimizer_isOptimized()) {
			my $vbase = $self->getVBase();
			return q@<script>$(document).ready(function() { $(document.createElement("script")).attr("src","@."${vbase}${main::VHTDOCS}_OPTIMIZED(js)_".q@").appendTo($("body")); });</script>@;
		} else {
			return q@<script>$(document).ready(function() {var l=new Array(@.join(',',map { "'".$$self{cgi}->escape($_)."'"} @{$$self{config}{extensions}->handle($hook, { path=>$fn })} ).q@);$("<div/>").html($.map(l,function(v,i){return decodeURIComponent(v);}).join("")).appendTo($("body"));});</script>@;
		}	
	} elsif ($hook eq 'css') {
		if (main::getWebInterface()->optimizer_isOptimized()) {
			my $vbase = $self->getVBase();
			return qq@<link rel="stylesheet" href="${vbase}${main::VHTDOCS}_OPTIMIZED(css)_"/>@;
		}
	}
	
	return join('',map { $self->renderExtensionElement($fn,$ru,$_) } @{$$self{config}{extensions}->handle($hook, { path=>$fn }) || []} );
}
sub renderExtensionFunction {
	my ($self, $content) = @_;
	$content=~s/\$extension\((.*?)\)/$self->renderExtension($main::PATH_TRANSLATED,$main::REQUEST_URI,$1)/egs;
	return $content;
}
sub renderLanguageList {
	my($self, $fn, $ru, $tmplfile) = @_;
	my $tmpl = $tmplfile=~/^'(.*)'$/ ? $1 : $self->readTemplate($tmplfile);
	my $content ="";
	foreach my $lang (sort { $main::SUPPORTED_LANGUAGES{$a} cmp $main::SUPPORTED_LANGUAGES{$b} } keys %main::SUPPORTED_LANGUAGES) {
		my $l = $tmpl;
		$l=~s/\$langname/$main::SUPPORTED_LANGUAGES{$lang}/sg;
		$l=~s/\$lang/$lang/sg;
		$content.=$l;
	}
	return $content;
}
sub isViewFiltered {
	my($self) = @_;
	return 1 if $$self{cgi}->param('search.name') || $$self{cgi}->param('search.types') || $$self{cgi}->param('search.size');
	return $$self{cgi}->cookie('filter.name') || $$self{cgi}->cookie('filter.types') || $$self{cgi}->cookie('filter.size') ? 1 : 0;
}
sub isUnselectable {
	my ($self,$fn) = @_;
	my $unselregex = @main::UNSELECTABLE_FOLDERS ? '('.join('|',@main::UNSELECTABLE_FOLDERS).')' : '___cannot match___' ;
	return $$self{backend}->basename($fn) eq '..' || $fn =~ /^$unselregex$/;	
}
sub renderFileListTable {
	my ($self, $fn, $ru, $template) = @_;
	my $filelisttabletemplate = $self->renderExtensionFunction($self->readTemplate($template));
	my $columns = $self->renderVisibleTableColumns($filelisttabletemplate).$self->renderInvisibleAllowedTableColumns($filelisttabletemplate);
	my %stdvars = 
		( 
			filelistheadcolumns => $columns,
			visiblecolumncount => scalar($self->getVisibleTableColumns()),
			isreadable => $$self{backend}->isReadable($fn) ? 'yes' : 'no',
			iswriteable=>$$self{backend}->isWriteable($fn) ? 'yes' : 'no',
			unselectable => $self->isUnselectable($fn) ? 'yes' : 'no'
		);
	$filelisttabletemplate=~s/\$\{?(\w+)\}?/exists $stdvars{$1} && defined $stdvars{$1}?$stdvars{$1}:"\$$1"/egs;
	my %jsondata = ( content => $self->minifyHTML($self->renderTemplate($fn,$ru,$filelisttabletemplate) ) );
	if (!$$self{backend}->isReadable($fn)) {
		$jsondata{error} = $self->tl('foldernotreadable');
	} 
	$jsondata{warn}=sprintf($self->tl('folderisfiltered'),$main::FILEFILTERPERDIR{$fn} || ($main::ENABLE_NAMEFILTER ? $$self{cgi}->param('namefilter') : undef)) 
		if $main::FILEFILTERPERDIR{$fn} || ($main::ENABLE_NAMEFILTER && $$self{cgi}->param('namefilter'));	
	$jsondata{quicknav}=$self->minifyHTML($self->renderQuickNavPath($fn, $ru));
	my $json = new JSON();
	return $json->encode(\%jsondata);

}
sub renderFileListEntry {
	my ($self, $fn, $ru, $file, $entrytemplate) = @_;
	$ru .= ($ru=~/\//?'':'/');
	
	my $hdr = $CACHE{renderFileListEntry}{hdr} ? $CACHE{renderFileListEntry}{hdr} : $CACHE{renderFileListEntry}{hdr} = DateTime::Format::Human::Duration->new();
	my $lang = $main::LANG eq 'default' ? 'en' : $main::LANG;
	
	my $full = "$fn$file";
	my $fulle = $ru.$$self{cgi}->escape($file);
	$fulle=~s/\%2f/\//gi; ## fix for search
	$file.='/' if $file !~ /^\.\.?$/ && $$self{backend}->isDir($full);
	my $e = $entrytemplate;
	my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size, $atime,$mtime,$ctime,$blksize,$blocks) = $$self{backend}->stat($full);
	$mtime = 0 unless defined $mtime;
	$ctime = 0 unless defined $ctime;
	$mode = 0 unless defined $mode;
	my ($sizetxt,$sizetitle) = $self->renderByteValue($size,2,2);
	my $mime = $file eq '..' ? '< .. >' : $$self{backend}->isDir($full)?'<folder>':main::getMIMEType($full);
	my $isLocked = $main::SHOW_LOCKS && main::isLocked($full);
	my %stdvars = ( 
				'name' => $$self{cgi}->escapeHTML($file), 
				'displayname' => $$self{cgi}->escapeHTML($$self{backend}->getDisplayName($full)),
				'size' => $$self{backend}->isReadable($full) ? $sizetxt : '-', 
				'sizetitle'=>$sizetitle,
				'lastmodified' =>  $$self{backend}->isReadable($full) ? strftime($self->tl('lastmodifiedformat'), localtime($mtime)) : '-',
				'lastmodifiedtime' => $mtime,
				'lastmodifiedhr' => $$self{backend}->isReadable($full) && $mtime ? $hdr->format_duration_between(DateTime->from_epoch(epoch=>$mtime,locale=>$lang), DateTime->now(locale=>$lang), precision=>'seconds', significant_units=>2 ) : '-',
			 	'created'=> $$self{backend}->isReadable($full) ? strftime($self->tl('lastmodifiedformat'), localtime($ctime)) : '-',
			 	'createdhr'=>$$self{backend}->isReadable($full) && $ctime ? $hdr->format_duration_between(DateTime->from_epoch(epoch=>$ctime,locale=>$lang), DateTime->now(locale=>$lang), precision=>'seconds', significant_units=>2 ) : '-',
			 	'createdtime' => $ctime,
				'iconurl'=> $$self{backend}->isDir($full) ? $self->getIcon($mime) : $self->canCreateThumbnail($full)? $fulle.'?action=thumb' : $self->getIcon($mime),
				'iconclass'=>$self->canCreateThumbnail($full) ? 'icon thumbnail' : 'icon',
				'mime'=>$$self{cgi}->escapeHTML($mime),
				'realsize'=>$size ? $size : 0,
				'isreadable'=>$file eq '..' || $$self{backend}->isReadable($full)?'yes':'no',
				'iswriteable'=>$$self{backend}->isWriteable($full) || $$self{"backend"}->isLink($full)?'yes':'no',
				'isviewable'=>$$self{backend}->isReadable($full) && $self->canCreateThumbnail($full) ? 'yes' : 'no',
				'islocked'=> $isLocked ? 'yes' : 'no',
				'islink' => $$self{backend}->isLink($full) ? 'yes' : 'no',
				'type'=>$file =~ /^\.\.?$/ || $$self{backend}->isDir($full)?'dir':($$self{backend}->isLink($full)?'link':'file'),
				'fileuri'=>$fulle,
				'unselectable'=> $file eq '..' || $self->isUnselectable($full) ? 'yes' : 'no',
				'linkinfo'=> $$self{backend}->isLink($full) ? ' &rarr; '.$$self{cgi}->escapeHTML($$self{backend}->getLinkSrc($full)) : "",
				'mode' => sprintf('%04o', $mode & 07777),
				'modestr' => $self->mode2str($full, $mode),
				'uidNumber' => $uid || 0,'uid'=> scalar getpwuid($uid || 0) || $uid,
				'gidNumber'=> $gid || 0, 'gid'=> scalar getgrgid($gid || 0) || $gid,
				'ext_classes'=> '',
				'ext_attributes'=>'',
				'ext_styles' =>'',
				);
	# fileattr hook: collect and concatenate attribute values 
	my $fileattrExtensions = $$self{config}{extensions}->handle('fileattr', { path=>$full});
	if ($fileattrExtensions ) {
		foreach my $attrHashRef (@{$fileattrExtensions}) {
			foreach my $supportedFileAttr ( ('ext_classes', 'ext_attributes','ext_styles')) {
				$stdvars{$supportedFileAttr}.=' '.$$attrHashRef{$supportedFileAttr} if $$attrHashRef{$supportedFileAttr};	
			}
		}
	}
	# fileprop hook by Harald Strack <hstrack@ssystems.de>
	# overwrites all stdvars including ext_...
	my $filepropExtensions = $$self{config}{extensions}->handle('fileprop', { path=>$full});
	if (defined ($filepropExtensions)) {
		foreach my $ret (@{$filepropExtensions}) {
			@stdvars{keys %$ret} = values %$ret;
		}
	}
	$e=~s/\$\{?(\w+)\}?/exists $stdvars{$1} && defined $stdvars{$1}?$stdvars{$1}:"\$$1"/egs;
	return $self->renderTemplate($fn,$ru,$e);
}
sub renderVisibleTableColumns {
	# my ($self, $template) = @_;
	my @columns = $_[0]->getVisibleTableColumns();
	my $columns = "";
	for my $column (@columns) {
		if ($_[1]=~s/<!--TEMPLATE\($column\)\[(.*?)\]-->//sg) {
			my $c = $1;
			$c=~s/-hidden//sg;
			$columns.=$c;
		}
	}
	return $columns;
}
sub renderInvisibleAllowedTableColumns {
	# my ($self, $template) = @_;
	my $columns = "";
	for my $column (@main::ALLOWED_TABLE_COLUMNS) {
		if ($_[1]=~s/<!--TEMPLATE\($column\)\[(.*?)\]-->//sg) {
			my $c = $1;
			$c =~ s/-hidden/hidden/sg;
			$columns.=$c;
		}
	}
	$_[1]=~s/<!--TEMPLATE\([^\)]+\)\[.*?\]-->//sg;
	return $columns;
}
sub renderFileList {
	my ($self, $fn, $ru, $template) = @_;
	my $entrytemplate=$self->renderExtensionFunction($self->readTemplate($template));
	my $fl="";	

	my @files = $$self{backend}->isReadable($fn) ? sort { $self->cmp_files($a,$b) } @{$$self{backend}->readDir($fn,main::getFileLimit($fn),$self)} : ();

	unshift @files, '..' if $main::SHOW_PARENT_FOLDER && $main::DOCUMENT_ROOT ne $fn;
	unshift @files, '.'  if $main::SHOW_CURRENT_FOLDER || ($main::SHOW_CURRENT_FOLDER_ROOTONLY && $ru=~/^$main::VIRTUAL_BASE$/);
	
	my $columns = $self->renderVisibleTableColumns($entrytemplate).$self->renderInvisibleAllowedTableColumns($entrytemplate);
	$entrytemplate=~s/\$filelistentrycolumns/$columns/esg;
	
	foreach my $file (@files) {
		$fl.=$self->renderFileListEntry($fn,$ru,$file,$entrytemplate);	
	}

	return $fl;	
}
sub renderFilterInfo {
		my($self) = @_;
		my @filter;
		my $filtername = $$self{cgi}->param('search.name') || $$self{cgi}->cookie('filter.name'); 
		my $filtertypes =  $$self{cgi}->param('search.types') || $$self{cgi}->cookie('filter.types');
		my $filtersize = $$self{cgi}->param('search.size') || $$self{cgi}->cookie('filter.size');
		
		if ($filtername) {
			my %filterops = (
				'=~' => $self->tl('filter.name.regexmatch'),'^' => $self->tl('filter.name.startswith'),
				'$' => $self->tl('filter.name.endswith'),'eq' => $self->tl('filter.name.equal'),
				'ne' => $self->tl('filter.name.notequal'),'lt' => $self->tl('filter.name.lessthan'),
				'gt' => $self->tl('filter.name.greaterthan'),'ge' => $self->tl('filter.name.greaterorequal'),
				'le' => $self->tl('filter.name.lessorequal'),
			);
			my ($fo,$fn) = split(/\s/,$filtername);
			push @filter, $self->tl('filter.name.showonly').' '.$filterops{$fo}.' "'.$$self{cgi}->escapeHTML($fn).'"';
		}
		if ($filtertypes) {
			
			my @ft;
			foreach my $ftype (split(//,$filtertypes)) {
				push @ft, $self->tl('filter.types.files') if $ftype eq 'f';
				push @ft, $self->tl('filter.types.folder') if $ftype eq 'd';
				push @ft, $self->tl('filter.types.links') if $ftype eq 'l';
			}
			push @filter, $self->tl('filter.types.showonly').join(", ", @ft);
		}
		if ($filtersize) {
			push @filter, $self->tl('filter.size.showonly'). $filtersize;
			
		}
	
		return $#filter > -1 ? join(", ",@filter) : "";
	
}
sub readTemplate {
	my ($self,$filename) = @_;
	return $self->SUPER::readTemplate($filename, "$main::INSTALL_BASE/templates/simple/");
}
sub renderQuickNavPath {
        my ($self, $fn,$ru, $query) = @_;
        $ru = main::uri_unescape($ru);
        my $content = "";
        my $path = "";
        my $navpath = $ru;
        my $base = '';
        $navpath=~s/^($main::VIRTUAL_BASE)//;
        $base = $1;
        if ($base ne '/' ) {
                $navpath = main::getBaseURIFrag($base)."/$navpath";
                $base = main::getParentURI($base);
                $base .= '/' if $base ne '/';
                $content.=$base;
        } else {
                $base = '';
                $navpath = "/$navpath";
        }
        my @fna = split(/\//,substr($fn,length($main::DOCUMENT_ROOT)));
        my $fnc = $main::DOCUMENT_ROOT;
        my @pea = split(/\//, $navpath); ## path element array
        my $navpathlength = length($navpath);
        my $ignorepe = 0;
        my $lastignorepe = 0;
        my $ignoredpes = '';
        my $lastignoredpath = '';
        for (my $i=0; $i<=$#pea; $i++) {
                my $pe = $pea[$i];
                $path .= uri_escape($pe) . '/';
                $path = '/' if $path eq '//';
                my $dn =  "$pe/";
                $dn = $fnc eq $main::DOCUMENT_ROOT ? "$pe/" : $$self{backend}->getDisplayName($fnc);
                $lastignorepe = $ignorepe; 
                $ignorepe = 0;
                if (defined $main::MAXNAVPATHSIZE && $main::MAXNAVPATHSIZE>0 && $navpathlength>$main::MAXNAVPATHSIZE) {
                        if ($i==0) { 
                                if (length($dn)>$main::MAXFILENAMESIZE) {
                                        $dn=substr($dn,0,$main::MAXFILENAMESIZE-6).'[...]/';
                                        $navpathlength-=$main::MAXFILENAMESIZE-8;
                                }
                        } elsif ($i==$#pea) {
                                $dn=substr($dn,0,$main::MAXNAVPATHSIZE-7).'[...]/';
                                $navpathlength-=length($dn)-8;
                        } else {
                                $navpathlength-= length($dn);
                                $ignorepe=1;
                                $lastignoredpath="$base$path";
                        }
                }
                $ignoredpes.="$pe/" if $ignorepe;
                if (!$ignorepe && $lastignorepe) {
                        $content.=$$self{cgi}->a({-href=>$lastignoredpath,-title=>$ignoredpes}, " [...]/ ");
                        $ignoredpes='';
                }
                $content.=$$self{cgi}->a({-href=>"$base$path".(defined $query?"?$query":""),-title=>$$self{cgi}->escapeHTML(uri_unescape("$base$path"))}, $$self{cgi}->escapeHTML(" $dn ")) unless $ignorepe;
                $fnc.=shift(@fna).'/' if $#fna>-1;
        }
        $content .= $$self{cgi}->a({-href=>'/', -title=>'/'}, '/') if $content eq '';

        return $content;
}


sub renderViewFilterDialog {
	my ($self, $fn, $ru, $tmplfile) = @_;
	my $content = $self->readTemplate($tmplfile);
	my @filtername = $$self{cgi}->cookie('filter.name') ? split(/\s/, $$self{cgi}->cookie('filter.name')) : ( "", "");
	my @filtersize = ("","","");
	if ($$self{cgi}->cookie('filter.size') && $$self{cgi}->cookie('filter.size')=~/^([<>=]{1,2})(\d+)([KMGTP]?[B])$/) {
		@filtersize = ($1, $2, $3);
	} 
	my %params = (
		'filter.name.val' => $filtername[1],
		'filter.name.op' => $filtername[0],
		'filter.size.op' => $filtersize[0],
		'filter.size.val' => $filtersize[1],
		'filter.size.unit' =>$filtersize[2],
		'filter.types' => $$self{cgi}->cookie('filter.types') ? $$self{cgi}->cookie('filter.types') : "",
	);
	sub isIn  {	return $_[0] =~ m/\Q$_[1]\E/; };
	$content=~s/\$(selected|checked)\(([^:\)]+):([^\)]+)\)/$params{$2} eq $3 || isIn($params{$2},$3) ? "$1=\"$1\"" : ""/egs;
	
	$content=~s/\$([\w\.]+)/exists $params{$1} ? $$self{cgi}->escapeHTML($params{$1}) : "\$$1"/egs; 
	return $self->renderTemplate($fn,$ru,$content);
}
sub round {
	my ($float, $precision) = @_;
	$precision = 1 unless defined $precision;
	my $ret = sprintf("%.${precision}f", $float);
	$ret=~s/\,(\d{0,$precision})$/\.$1/; # fix locale specific notation
	return $ret;
}

sub filter {
        my ($self,$path, $file) = @_;
        return 1 if $$self{utils}->filter($path,$file);
        my $ret = 0;
        my $filter = $$self{cgi}->param('search.types') || $$self{cgi}->cookie('filter.types');
        if ( defined $filter ) {
                $ret|=1 if $filter!~/d/ && $main::backend->isDir("$path$file");
                $ret|=1 if $filter!~/f/ && $main::backend->isFile("$path$file");
                $ret|=1 if $filter!~/l/ && $main::backend->isLink("$path$file");
        }
        return 1 if $ret;
        $filter = $$self{cgi}->param('search.size') ||  $$self{cgi}->cookie('filter.size');
        if ( defined $filter && $main::backend->isFile("$path$file") &&  $filter=~/^([\<\>\=]{1,2})(\d+)(\w*)$/ ) {
                my ($op, $val,$unit) = ($1,$2,$3);
                $val = $val * $BYTEUNITS{$unit} if exists $BYTEUNITS{$unit};
                my $size = ($main::backend->stat("$path$file"))[7];
                $ret=!eval("$size $op $val");
        }
        return 1 if $ret;
        $filter = $$self{cgi}->param('search.name') || $$self{cgi}->cookie('filter.name');
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
        return $ret;
}
sub parseByteSize {
	my ($v) = @_;
	my %sf = ('b' => 1, 'kb' => 1024, 'mb' => 1048576, 'gb' => 1073741824, 'tb' => 1099511627776, 'pb' => 1125899906842624 );
	$v=~/(\d+([\.\,]\d+)?)([kmgtp]b)?/i;
	return $1 * ($3 ? ($sf{lc($3)} || 1) : 1);
}
1;