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

use WebInterface::Common;
our @ISA = ( 'WebInterface::Common' );

use vars qw(%STATS %CACHE);
sub render {
	my($self,$fn,$ru) = @_;
	my $content ='';
	my $contenttype= 'text/html';
	
	$self->setLocale();
	
	if ($$self{cgi}->param('ajax')) {
		my $ajax = $$self{cgi}->param('ajax');
		if ($ajax eq 'getFileListTable') { 
			$content = $self->renderFileListTable($fn,$ru, $$self{cgi}->param('template')); 
			$contenttype='application/json';
		} elsif ($ajax eq 'getAFSACLManager') {
			$content = $self->renderAFSACLManager($fn,$ru, $$self{cgi}->param('template'));
		} elsif ($ajax eq 'getAFSGroupManager') {
			$content = $self->renderAFSGroupManager($fn,$ru, $$self{cgi}->param('template'));
		} elsif ($ajax eq 'getPermissionsDialog') {
			$content = $self->renderPermissionsDialog($fn,$ru, $$self{cgi}->param('template'));
		} elsif ($ajax eq 'getViewFilterDialog') {
			$content = $self->renderViewFilterDialog($fn, $ru, $$self{cgi}->param('template'));
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
	
	$$ret{quotausedperc} = $$ret{quotalimit}!=0 ? int(100 * $$ret{quotaused} / $$ret{quotalimit}) : 0;
	$$ret{quotaavailableperc} = $$ret{quotalimit}!=0 ? int(100 * $$ret{quotaavailable} / $$ret{quotalimit}) : 0;
	
	$CACHE{$self}{$fn}{quotaData}=$ret;

	return $ret;
}
sub renderTemplate {
	my ($self,$fn,$ru,$content) = @_;

	# replace eval:
	$content=~s/\$eval(.)(.*?)\1/eval($2)/egs;
	# replace functions:
	$content=~s/\$(\w+)\(([^\)]*)\)/$self->execTemplateFunction($fn,$ru,$1,$2)/esg;

	my $vbase = $ru=~/^($main::VIRTUAL_BASE)/ ? $1 : $ru;

	my %quota =  %{$self->getQuotaData($fn)};
	# replace standard variables:
	my %stdvars = ( uri => $ru, 
			baseuri=>$$self{cgi}->escapeHTML($vbase),
			quicknavpath=>$self->renderQuickNavPath($fn,$ru),
			maxuploadsize=>$main::POST_MAX_SIZE,
			maxuploadsizehr=>($self->renderByteValue($main::POST_MAX_SIZE,2,2))[0],
			quotalimit => ($self->renderByteValue($quota{quotalimit},2,))[0],
			quotalimittitle => ($self->renderByteValue($quota{quotalimit},2,))[1],
			quotaused => ($self->renderByteValue($quota{quotaused},2,2))[0],
			quotausedtitle => ($self->renderByteValue($quota{quotaused},2,2))[1],
			quotaavailable => ($self->renderByteValue($quota{quotaavailable},2,2))[0],
			quotaavailabletitle => ($self->renderByteValue($quota{quotaavailable},2,2))[1],
			quotastyle=> $quota{quotastyle},
			quotalevel=> $quota{quotalevel},
			quotausedperc => $quota{quotausedperc},
			quotaavailableperc => $quota{quotaavailableperc},
			USER=>$main::REMOTE_USER,
			CLOCK=>$$self{cgi}->span({id=>'clock', 'data-format'=>$self->tl('vartimeformat')},""),
			NOW=>strftime($self->tl('varnowformat'), localtime()),
			REQUEST_URI=>$main::REQUEST_URI,
			PATH_TRANSLATED=>$main::PATH_TRANSLATED,
			LANG=>$main::LANG,
			VBASE=>$$self{cgi}->escapeHTML($vbase),
			VHTDOCS=>$vbase.$main::VHTDOCS,
	);
	$content=~s/\${?ENV{([^}]+?)}}?/$ENV{$1}/egs;
	$content=~s/\${?TL{([^}]+)}}?/$self->tl($1)/egs;
	$content=~s/\$\[(\w+)\]/exists $stdvars{$1}?$stdvars{$1}:"\$$1"/egs;
	$content=~s/\$\{?(\w+)\}?/exists $stdvars{$1}?$stdvars{$1}:"\$$1"/egs;
	$content=~s/<!--IF\((.*?)\)-->(.*?)<!--ENDIF-->/eval($1)? $2 : ''/egs;
	$content=~s/<!--IF(\#\d+)\((.*?)\)-->(.*?)<!--ENDIF\1-->/eval($2)? $3 : ''/egs;
	return $content;
}
sub execTemplateFunction {
	my ($self, $fn, $ru, $func, $param) = @_;
	my $content = $self->tl('error');
	
	$content = ${"main::${param}"} || '' if $func eq 'config';
	$content = $ENV{$param} || '' if $func eq 'env';
	$content = $self->tl($param) if $func eq 'tl';
	$content = $self->renderFileList($fn,$ru,$param) if $func eq 'filelist';
	$content = $self->renderAFSACLList($fn,$ru,1,$param) if $func eq 'afsnormalacllist';
	$content = $self->renderAFSACLList($fn,$ru,0,$param) if $func eq 'afsnegativeacllist';
	$content = $self->renderAFSGroupList($fn,$ru,$param) if $func eq 'afsgrouplist';
	$content = $self->renderAFSMemberList($fn,$ru,$param) if $func eq 'afsmemberlist';
	$content = $self->isViewFiltered() if $func eq 'isviewfiltered';
	$content = $self->renderFilterInfo() if $func eq 'filterInfo';
	$content = $self->renderViewList($fn,$ru,$param) if $func eq 'viewList';
	$content = $$self{cgi}->param($param) ? $$self{cgi}->param($param) : "" if $func eq 'cgiparam';
	return $content;
}
sub renderViewList {
	my ($self, $fn,$ru,$tmplfile) = @_;
	my $tmpl = $self->readTemplate($tmplfile);
	my $content = "";
	foreach my $view (@main::SUPPORTED_VIEWS) {
		next if ($view eq $main::VIEW);
		my $t = $tmpl;
		$t=~s/\$viewlink/"$ru?view=$view"/egs;
		$t=~s/\$viewname/$self->tl("${view}view")/egs;
		$t=~s/\$view/$view/gs;
		$content.=$t;
	}
	return $self->renderTemplate($fn,$ru,$content);
}
sub isViewFiltered {
	my($self) = @_;
	return $$self{cgi}->cookie('filter.name') || $$self{cgi}->cookie('filter.types') || $$self{cgi}->cookie('filter.size') ? 1 : 0;
}
sub renderFileListTable {
	my ($self, $fn, $ru, $template) = @_;
	my %jsondata = ( content => $self->minifyHTML($self->renderTemplate($fn,$ru,$self->readTemplate($template)) ) );
	if (!$$self{backend}->isReadable($fn)) {
		$jsondata{error} = $self->tl('foldernotreadable');
	} 
	$jsondata{warn}=sprintf($self->tl('folderisfiltered'),$main::FILEFILTERPERDIR{$fn} || ($main::ENABLE_NAMEFILTER ? $$self{cgi}->param('namefilter') : undef)) 
		if $main::FILEFILTERPERDIR{$fn} || ($main::ENABLE_NAMEFILTER && $$self{cgi}->param('namefilter'));	
	$jsondata{quicknav}=$self->minifyHTML($self->renderQuickNavPath($fn, $ru));
	my $json = new JSON();
	return $json->encode(\%jsondata);

}
sub renderFileList {
	my ($self, $fn, $ru, $template) = @_;
	my $entrytemplate=$self->readTemplate($template);
	my $fl="";	

	my $unselregex = @main::UNSELECTABLE_FOLDERS ? '('.join('|',@main::UNSELECTABLE_FOLDERS).')' : '___cannot match___' ;

	my @files = $$self{backend}->isReadable($fn) ? sort { $self->cmp_files($a,$b) } @{$$self{backend}->readDir($fn,main::getFileLimit($fn),$self)} : ();

	$STATS{$self}{$fn}{foldersize} = 0;
	$STATS{$self}{$fn}{dircount}=0;
	$STATS{$self}{$fn}{filecount}=0;
	unshift @files, '..' if $main::SHOW_PARENT_FOLDER && $main::DOCUMENT_ROOT ne $fn;
	unshift @files, '.' if $main::SHOW_CURRENT_FOLDER || ($main::SHOW_CURRENT_FOLDER_ROOTONLY && $ru=~/^$main::VIRTUAL_BASE$/);
	my $fileid = 0;
	foreach my $file (@files) {
		$ru .= ($ru=~/\//?'':'/');
		my $full = "$fn$file";
		my $fulle = $ru.$$self{cgi}->escape($file);
		$file.='/' if $file !~ /^\.\.?$/ && $$self{backend}->isDir($full);

		my $e = $entrytemplate;
		my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size, $atime,$mtime,$ctime,$blksize,$blocks) = $$self{backend}->stat($full);
		my ($sizetxt,$sizetitle) = $self->renderByteValue($size,2,2);
		my $mimetype = $file eq '..' ? '< .. >' : $$self{backend}->isDir($full)?'<folder>':main::getMIMEType($full);
		my %stdvars = ( 
				'name' => $$self{cgi}->escapeHTML($file), 
				'size' => $$self{backend}->isReadable($full) ? $sizetxt : '-', 
				'sizetitle'=>$sizetitle,
				'lastmodified' =>  strftime($self->tl('lastmodifiedformat'), localtime($mtime)),
				'lastmodifiedtime' => $mtime,
			 	'created'=> strftime($self->tl('lastmodifiedformat'), localtime($ctime)),
				'iconurl'=> $$self{backend}->isDir($full) ? $self->getIcon($mimetype) : $self->canCreateThumbnail($full)? $fulle.'?action=thumb' : $self->getIcon($mimetype),
				'iconclass'=>$self->canCreateThumbnail($full) ? 'icon thumbnail' : 'icon',
				'mimetype'=>$mimetype,
				'realsize'=>$size ? $size : 0,
				'isreadable'=>$file eq '..' || $$self{backend}->isReadable($full)?'yes':'no',
				'iswriteable'=>$$self{backend}->isWriteable($full) || $$self{"backend"}->isLink($full)?'yes':'no',
				'iseditable'=>$self->isEditable($full) ? 'yes' : 'no',
				'isviewable'=>$$self{backend}->isReadable($full) && $self->canCreateThumbnail($full) ? 'yes' : 'no',
				'type'=>$file =~ /^\.\.?$/ || $$self{backend}->isDir($full)?'dir':($$self{backend}->isLink($full)?'link':'file'),
				'fileid'=>$fileid++,
				'fileuri'=>$fulle,
				'unselectable'=> $file eq '..' || $full =~ /^$unselregex$/ ? 'yes' : 'no',
				'linkinfo'=> $$self{backend}->isLink($full) ? ' &rarr; '.$$self{cgi}->escapeHTML($$self{backend}->getLinkSrc($full)) : "",
				);
		$e=~s/\$\{?(\w+)\}?/exists $stdvars{$1}?$stdvars{$1}:"\$$1"/egs;
		$fl.=$self->renderTemplate($fn,$ru,$e);
		$STATS{$self}{$fn}{foldersize}+=$size;
		$STATS{$self}{$fn}{dircount}++ if $stdvars{type} eq 'dir';
		$STATS{$self}{$fn}{filecount}++ if $stdvars{type} ne 'dir';
	}

	return $fl;	
}
sub renderFilterInfo {
		my($self) = @_;
		my @filter;
		my $filtername = $$self{cgi}->cookie('filter.name');
		my $filtertypes = $$self{cgi}->cookie('filter.types');
		my $filtersize = $$self{cgi}->cookie('filter.size');
		
		if ($filtername) {
			my %filterops = (
				'=~' => $self->tl('filter.name.regexmatch'),'^' => $self->tl('filter.name.startwith'),
				'$' => $self->tl('filter.name.endswith'),'eq' => $self->tl('filter.name.equal'),
				'ne' => $self->tl('filter.name.notequal'),'lt' => $self->tl('filter.name.lessthan'),
				'gt' => $self->tl('filter.name.greaterthan'),'ge' => $self->tl('filter.name.greaterorequal'),
				'le' => $self->tl('filter.name.lessorequal'),
			);
			my ($fo,$fn) = split(/\s/,$filtername);
			push @filter, $self->tl('filter.name.showonly').' '.$filterops{$fo}.' "'.$fn.'"';
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
	
		return $#filter > -1 ? $self->tl("filter").join(", ",@filter) : "";
	
}
sub canCreateThumbnail {
	my ($self,$fn) = @_;
	return $main::ENABLE_THUMBNAIL 
		&& $self->hasThumbSupport(main::getMIMEType($fn)) 
		&& $$self{backend}->isReadable($fn) 
		&& !$$self{backend}->isEmpty($fn);
}
sub isEditable {
	my ($self,$fn) = @_;
	my $ef = $CACHE{$self}{editablefilesregex} ? $CACHE{$self}{editablefilesregex} : $CACHE{$self}{editablefilesregex}='('.join('|',@main::EDITABLEFILES).')';
        return $main::ALLOW_EDIT && $$self{backend}->basename($fn) =~/$ef/i
         && $$self{backend}->isFile($fn) && $$self{backend}->isReadable($fn) && $$self{backend}->isWriteable($fn);
}
sub readTemplate {
	my ($self,$filename) = @_;
	
	my $text = "";
	$filename=~s/\//\./g;
	$filename .= '.custom' if -r "../templates/simple/${filename}.custom.tmpl";
	return $CACHE{template}{$filename} if exists $CACHE{template}{$filename};
	#print STDERR "readTemplate($filename)\n";
	if (open(IN, "../templates/simple/$filename.tmpl")) {
		my @tmpl = <IN>;
		close(IN);
		$text = join("",@tmpl);
		$text =~ s/\$INCLUDE\((.*?)\)/$self->readTemplate($1)/egs;	
	}
	return $CACHE{template}{$filename}=$text;
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
sub readAFSAcls {
	my ($self, $fn, $ru) = @_;
	return $CACHE{$self}{$fn}{afsacls} if exists $CACHE{$self}{$fn}{afsacls};

	$fn=~s/(["\$\\])/\\$1/g;
	open(my $afs, sprintf("%s listacl \"%s\"|", $main::AFS_FSCMD, $$self{backend}->resolveVirt($fn) )) or die("cannot execute $main::AFS_FSCMD list \"$fn\"");
	my @lines = <$afs>;
	close($afs);

	shift @lines; # skip first line

	my @entries;
	my $ispositive = 1;
	foreach my $line (@lines) {
		chomp($line);
		$line=~s/^\s+//;
		next if $line=~ /^\s*$/; # skip empty lines
		if ($line=~/^(Normal|Negative) rights:/) {
			$ispositive = 0 if $line=~/^Negative/;
		} else {
			my ($user, $right) = split(/\s+/, $line);
			push @entries, { user=> $user, right=> $right, ispositive=> $ispositive };
		}
	}

	$CACHE{$self}{$fn}{afsacls} = \@entries;
	return \@entries;
}
sub renderAFSAclEntries {
	my ($self, $entries, $positive, $tmpl) = @_;
	my $content = "";
	my $prohiregex = '^('.join('|',map { $_ ? $_ : '__undef__'} @main::PROHIBIT_AFS_ACL_CHANGES_FOR).')$';
	foreach my $entry (sort { $$a{user} cmp $$b{user} || $$b{right} cmp $$a{right} } @{$entries}) {
		next if $$entry{ispositive} != $positive;	
		my $t = $tmpl;
		$t=~s/\$entry/$$entry{user}/sg;
		$t=~s/\$checked\((\w)\)/$$entry{right}=~m@$1@?'checked="checked"':""/egs;
		$t=~s/\$readonly/$$entry{user}=~m@$prohiregex@ ? 'readonly="readonly"' : ""/egs;
		$t=~s/\$disabled/$main::ALLOW_AFSACLCHANGES ? '' : 'disabled="disabled"'/egs;
		$content.=$t;
	}
	return $content;
}
sub renderAFSACLList {
	my ($self, $fn, $ru, $positive, $tmplfile) = @_;
	return $self->renderTemplate($fn,$ru, $self->renderAFSAclEntries($self->readAFSAcls($fn,$ru), $positive, $self->readTemplate($tmplfile)));
}
sub uridecode {
	my ($txt) = @_;
	$txt=~s/\%([a-f0-9]{2})/chr(hex($1))/eigs;
	return $txt;
}
sub renderAFSACLManager {
	my ($self, $fn, $ru, $tmplfile) = @_;
	my $content = $self->renderTemplate($fn,$ru,$self->readTemplate($tmplfile));
	my $stdvars = {
		afsaclscurrentfolder => sprintf($self->tl('afsaclscurrentfolder'), 
										$$self{cgi}->escapeHTML(uridecode($$self{backend}->basename($ru))), 
										$$self{cgi}->escapeHTML(uridecode($ru))),
	};
	$content=~s/\$(\w+)/exists $$stdvars{$1} ? $$stdvars{$1} : ''/egs;
	return $content;
}
sub readAFSGroupList {
	my ($self, $fn, $ru) = @_;
	return $CACHE{$self}{$fn}{afsgrouplist} if exists $CACHE{$self}{$fn}{afsgrouplist};
	my @groups = split(/\r?\n\s*?/, qx@$main::AFS_PTSCMD listowned $main::REMOTE_USER@);
	shift @groups; # remove comment
	s/(^\s+|[\s\r\n]+$)//g foreach (@groups);
	@groups = sort @groups;
	$CACHE{$self}{$fn}{afsgrouplist} = \@groups;
	return \@groups;
}
sub renderAFSGroupListEntry {
	my ($self,$groups) = @_;
}
sub renderAFSGroupList {
	my ($self, $fn, $ru, $tmplfile) = @_;
	my $content ="";
	my $tmpl = $self->renderTemplate($fn,$ru,$self->readTemplate($tmplfile));
	foreach my $group (@{$self->readAFSGroupList($fn,$ru)}) {
		my $t = $tmpl;
		$t=~s/\$afsgroupname/$group/g;
		$content.=$t;
	}
	return $content;
}
sub readAFSMembers {
	my ($self, $grp) = @_;
	return [] unless $grp;
	my @users = split(/\r?\n/, qx@$main::AFS_PTSCMD members '$grp'@);
    shift @users; # remove comment
    s/^\s+//g foreach (@users);
    @users = sort @users;
    chomp @users;
	return \@users;
}
sub renderAFSMemberList {
	my ($self, $fn, $ru, $tmplfile) = @_;
	my $content = "";
	my $tmpl = $self->readTemplate($tmplfile);
	my $afsgrp = $$self{cgi}->param('afsgrp');
	foreach my $user (@{$self->readAFSMembers($afsgrp)}) {
		my $t = $tmpl;
		$t=~s/\$afsmember/$user/sg;
		$t=~s/\$afsgroupname/$afsgrp/sg;
		$content.=$t;
	}
	return $self->renderTemplate($fn,$ru,$content);
}
sub renderAFSGroupManager {
	my ($self, $fn, $ru, $tmplfile) = @_;
	my $content = $self->renderTemplate($fn,$ru,$self->readTemplate($tmplfile));
	my $stdvars = {
		afsgroupeditorhead => sprintf($self->tl('afsgroups'), $$self{cgi}->escapeHTML($main::REMOTE_USER)),
		afsmembereditorhead=> $$self{cgi}->param('afsgrp') ? sprintf($self->tl('afsgrpusers'), $$self{cgi}->escapeHTML($$self{cgi}->param('afsgrp'))): "",
		user => $main::REMOTE_USER,
	};
	$content=~s/\$(\w+)/exists $$stdvars{$1} ? $$stdvars{$1} : "\$${1}"/egs;
	return $content;
}
sub checkPermAllowed {
	my ($p,$r) = @_;
	my $perms;
	$perms = join("",@{$main::PERM_USER}) if $p eq 'u';
	$perms = join("",@{$main::PERM_GROUP}) if $p eq 'g';
	$perms = join("",@{$main::PERM_OTHERS}) if $p eq 'o';
	return $perms =~ m/\Q$r\E/;
}
sub renderPermissionsDialog {
	my ($self, $fn, $ru, $tmplfile) = @_;
	my $content = $self->readTemplate($tmplfile);
	
	$content =~ s/\$disabled\((\w)(\w)\)/&checkPermAllowed($1,$2) ? '' : 'disabled="disabled"'/egs;
	
	return $self->renderTemplate($fn, $ru, $content);
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
1;

