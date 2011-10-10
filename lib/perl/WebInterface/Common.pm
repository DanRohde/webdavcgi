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

package WebInterface::Common;

use strict;

use POSIX qw( strftime ceil locale_h );

use vars qw( %CACHE %BYTEUNITS @BYTEUNITORDER ) ;

%BYTEUNITS = (B=>1, KB=>1024, MB => 1048576, GB => 1073741824, TB => 1099511627776, PB =>1125899906842624 );
@BYTEUNITORDER = ( 'B', 'KB', 'MB', 'GB', 'TB', 'PB' );


sub new {
	my $this = shift;
	my $class = ref($this) || $this;
	my $self = { };
	bless $self, $class;
	$$self{config}=shift;
	$$self{db}=shift;
	$self->initialize();
	return $self;
}

sub initialize() {
	my $self = shift;
	$$self{cgi} = $$self{config}->getProperty('cgi');
	$$self{backend} = $$self{config}->getProperty('backend');
	$$self{utils} = $$self{config}->getProperty('utils');

	$$self{BYTEUNITS}=\%BYTEUNITS;
	$$self{BYTEUNITORDER}=\@BYTEUNITORDER;
	$$self{WEB_ID}=0;

	$main::LANG = $$self{cgi}->param('lang') || $$self{cgi}->cookie('lang') || $main::LANG || 'default';
	$main::ORDER = $$self{cgi}->param('order') || $$self{cgi}->cookie('order') || $main::ORDER || 'name';
	$main::PAGE_LIMIT = $$self{cgi}->param('pagelimit') || $$self{cgi}->cookie('pagelimit') || $main::PAGE_LIMIT;
	$main::PAGE_LIMIT = ceil($main::PAGE_LIMIT) if defined $main::PAGE_LIMIT;
	@main::PAGE_LIMITS = ( 5, 10, 15, 20, 25, 30, 50, 100, -1 ) unless defined @main::PAGE_LIMITS;
	unshift @main::PAGE_LIMITS, $main::PAGE_LIMIT if defined $main::PAGE_LIMIT && $main::PAGE_LIMIT > 0 && grep(/\Q$main::PAGE_LIMIT\E/, @main::PAGE_LIMITS) <= 0 ;

	$main::VIEW = $$self{cgi}->param('view') || $$self{cgi}->cookie('view') || $main::VIEW || $main::SUPPORTED_VIEWS[0];

}

sub readTLFile {
	my ($self, $fn, $dataRef) = @_;
        if (open(my $i, "<$fn")) {
                while (my $line = <$i>) {
                        chomp($line);
                        next if $line=~/^#/;
                        $$dataRef{$1}=$2 if $line=~/^(\S+)\s+"(.*)"\s*$/;
                }
                close($i);
        } else { warn("Cannot read $fn!"); }
}
sub readTL  {
        my ($self,$l) = @_;
        my $fn = -e "${main::INSTALL_BASE}locale/webdav-ui_${l}.msg" ? "${main::INSTALL_BASE}locale/webdav-ui_${l}.msg" : undef;
        return unless defined $fn;
	$self->readTLFile($fn, $main::TRANSLATION{$l});
        $main::TRANSLATION{$l}{x__READ__x}=1;
}
sub readViewTL  {
        my ($self,$l) = @_;
        my $fn = -e "${main::INSTALL_BASE}lib/perl/WebInterface/View/$main::VIEW/locale/locale_${l}.msg" ? "${main::INSTALL_BASE}lib/perl/WebInterface/View/$main::VIEW/locale/locale_${l}.msg" : undef;
        return unless defined $fn;
	$self->readTLFile($fn, $main::TRANSLATION{$l});
        $main::TRANSLATION{$l}{x__VIEWREAD__x}=1;
}
sub tl {
        my $self = shift;
        my $key = shift;
        $self->readTL('default') if !exists $main::TRANSLATION{default}{x__READ__x};
	$self->readViewTL('default') if !exists $main::TRANSLATION{default}{x__VIEWREAD__x};
        $self->readTL($main::LANG) if !exists $main::TRANSLATION{$main::LANG}{x__READ__x};
	$self->readViewTL($main::LANG) if !exists $main::TRANSLATION{$main::LANG}{x__VIEWREAD__x};

        my $val = $main::TRANSLATION{$main::LANG}{$key} || $main::TRANSLATION{default}{$key} || $key;
        return $#_>-1 ? sprintf( $val, @_) : $val;
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
sub getCookies {
        my ($self) = @_;
        return [
                 $$self{cgi}->cookie(-name=>'lang',-value=>$main::LANG,-expires=>'+10y'),
                 $$self{cgi}->cookie(-name=>'showall',-value=>$$self{cgi}->param('showpage') ? 0 : ($$self{cgi}->param('showall') || $$self{cgi}->cookie('showall') || 0), -expires=>'+10y'),
                 $$self{cgi}->cookie(-name=>'order',-value=>$main::ORDER, -expires=>'+10y'),
                 $$self{cgi}->cookie(-name=>'pagelimit',-value=>$main::PAGE_LIMIT, -expires=>'+10y'),
                 $$self{cgi}->cookie(-name=>'view',-value=>$main::VIEW, -expires=>'+10y'),
        ];
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
sub cmp_strings {
        $CACHE{$_[0]}{cmp_strings}{$_[1]} = substr($_[1],0,1) unless exists $CACHE{$_[0]}{cmp_strings}{$_[1]};
        $CACHE{$_[0]}{cmp_strings}{$_[2]} = substr($_[2],0,1) unless exists $CACHE{$_[0]}{cmp_strings}{$_[2]};
        return  $CACHE{$_[0]}{cmp_strings}{$_[1]} cmp $CACHE{$_[0]}{cmp_strings}{$_[2]} || $_[1] cmp $_[2];
}
sub cmp_files {
        my ($self,$a,$b) = @_;
        my $fp_a = $main::PATH_TRANSLATED.$a;
        my $fp_b = $main::PATH_TRANSLATED.$b;
        my $factor = exists $CACHE{$self}{cmp_files}{$main::ORDER} ? $CACHE{$self}{cmp_files}{$main::ORDER} : ( $CACHE{$self}{cmp_files}{$main::ORDER} =  ($main::ORDER =~/_desc$/) ? -1 : 1 );
        $CACHE{$self}{cmp_files}{$fp_a} = $$self{backend}->isDir($fp_a) unless exists $CACHE{$self}{cmp_files}{$fp_a};
        $CACHE{$self}{cmp_files}{$fp_b} = $$self{backend}->isDir($fp_b) unless exists $CACHE{$self}{cmp_files}{$fp_b};

        return -1 if $CACHE{$self}{cmp_files}{$fp_a} && !$CACHE{$self}{cmp_files}{$fp_b};
        return 1 if !$CACHE{$self}{cmp_files}{$fp_a} && $CACHE{$self}{cmp_files}{$fp_b};

        if ($main::ORDER =~ /^(lastmodified|created|size|mode)/) {
                my $idx = $main::ORDER=~/^lastmodified/? 9 : $main::ORDER=~/^created/ ? 10 : $main::ORDER=~/^mode/? 2 : 7;
                return $factor * ( ($$self{backend}->stat($fp_a))[$idx] <=> ($$self{backend}->stat($fp_b))[$idx] || $self->cmp_strings($$self{backend}->getDisplayName($fp_a),$$self{backend}->getDisplayName($fp_b)) );
        } elsif ($main::ORDER =~ /mime/) {
                return $factor * ( $self->cmp_strings(main::getMIMEType($a), main::getMIMEType($b)) || $self->cmp_strings($$self{backend}->getDisplayName($fp_a),$$self{backend}->getDisplayName($fp_b)));
        }
        return $factor * $self->cmp_strings($$self{backend}->getDisplayName($fp_a),$$self{backend}->getDisplayName($fp_b));
}

sub escapeQuotes {
        my ($self,$q) = @_;
        $q=~s/(["'])/\\$1/g;
        return $q;
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
sub renderByteValue {
        my ($self, $v, $f, $ft) = @_; # v-value, f-accuracy, ft-title accuracy
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
                $title.= ($unit eq 'B' ? sprintf(' = %.0fB ',$rv{$unit}) : sprintf('= %.'.$ft.'f%s ', $rv{$unit}, $unit)) if $rv{$unit} >= $lowerlimitft && $rv{$unit} < $upperlimit;
        }
        return ( ($showunit eq 'B' ? $rv{$showunit} : sprintf('%.'.$f.'f%s',$rv{$showunit},$showunit)), $title);
}
sub filter {
        my ($self,$path, $file) = @_;
        return 1 if $$self{utils}->filter($path,$file);
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

sub getfancyfilename {
        my ($self, $full,$s,$m,$fn,$isUnReadable) = @_;
        my $ret = $s;

        $full = '/' if $full eq '//'; # fixes root folder navigation bug

        my $fntext = $s =~ /^\.{1,2}$/ ? $s : $$self{backend}->getDisplayName($fn);
        $fntext =substr($fntext,0,$main::MAXFILENAMESIZE-5) if length($s)>$main::MAXFILENAMESIZE;
        my $linkit =  $fn=~/^\.{1,2}$/ || (!$$self{backend}->isDir($fn) && $$self{backend}->isReadable($fn)) || $$self{backend}->isExecutable($fn);

        $ret = $linkit ? $$self{cgi}->a({href=>$full},$$self{cgi}->escapeHTML($fntext)) : $$self{cgi}->escapeHTML($fntext);
        $ret .=  length($s)>$main::MAXFILENAMESIZE ? '[...]' : (' 'x($main::MAXFILENAMESIZE-length($s)));

        $full=~/([^\.]+)$/;
        my $suffix = $1 || $m;
        my $icon = $self->getIcon($m);
        my $width = $main::ICON_WIDTH || 18;
        my $onmouseover="";
        my $onmouseout="";
        my $align="";
        my $id='i'.time().$$self{WEB_ID};
        $id=~s/\"//g;

        my $cssclass='icon';
        if ($main::ENABLE_THUMBNAIL && $self->hasThumbSupport($m) && $$self{backend}->isReadable($fn) && !$$self{backend}->isEmpty($fn))  {
                $icon=$full.($full=~/\?.*/?';':'?').'action=thumb';
                if ($main::THUMBNAIL_WIDTH && $main::ICON_WIDTH < $main::THUMBNAIL_WIDTH) {
                        $cssclass='thumb';
                        $onmouseover = qq@javascript:this.intervalFunc=function() { if (this.width<$main::THUMBNAIL_WIDTH) this.width+=@.(($main::THUMBNAIL_WIDTH-$main::ICON_WIDTH)/15).qq@; else window.clearInterval(this.intervalObj);}; this.intervalObj = window.setInterval("document.getElementById('$id').intervalFunc();", 10);@;
                        $onmouseout = qq@javascript:window.clearInterval(this.intervalObj);this.width=$main::ICON_WIDTH;@;
                }
        }
        my $img =  $$self{cgi}->img({id=>$id, src=>$icon,alt=>'['.$suffix.']', -class=>$cssclass, -width=>$width, -onmouseover=>$onmouseover,-onmouseout=>$onmouseout});
        $ret = ($linkit ? $$self{cgi}->a(  {href=>$full}, $img):$img).' '.$ret;
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
sub getIcon {
        my ($self,$type) = @_;
        return $self->replaceVars(exists $main::ICONS{$type} ? $main::ICONS{$type} : $main::ICONS{default});
}
sub getUIIcon {
        my ($self,$action) = @_;
        return $self->replaceVars(exists $main::UI_ICONS{$action} ? $main::UI_ICONS{$action} : $main::UI_ICONS{default});
}
sub hasThumbSupport {
        my ($self,$mime) = @_;
	return 1 if $mime =~ /^image\// || $mime =~ /^text\/plain/ || ($main::ENABLE_THUMBNAIL_PDFPS && $mime =~ /^application\/(pdf|ps)$/);
	return 0;
}
sub renderFileActionsWithIcons {
        my ($self,$fid, $file, $full) = @_;
        my %attr= ();
        my %disabled = ();
        my @actions = ('edit','rename','zip','delete');
        my %labels = ( rename=>$self->tl('movefilesbutton'),edit=>$self->tl('editbutton'),delete=>$self->tl('deletefilesbutton'), zip=>$self->tl('zipdownloadbutton'));
        delete $actions[2] unless $main::ALLOW_ZIP_DOWNLOAD;
        my $extactions = $$self{config}{extensions}->handle('fileaction', { path=>$full });
        map { push @actions, $$_{action}; $labels{$$_{action}}=$self->tl($$_{label}); $disabled{$$_{action}}=$$_{disabled};  }  @{$extactions};
        if (! $$self{backend}->isWriteable($full)) {
                $disabled{rename}=1;
                $disabled{delete}=1;
        }
        if (! $$self{backend}->isReadable($full)) {
                $disabled{zip}=1;
        }
        if ($main::ALLOW_EDIT) {
                my $ef = '('.join('|',@main::EDITABLEFILES).')';
                $disabled{edit} = 1 unless $$self{backend}->basename($file) =~/$ef/i && $$self{backend}->isFile($full) && $$self{backend}->isWriteable($full);
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
        my %labels = ( '--'=> '', rename=>$self->tl('movefilesbutton'),edit=>$self->tl('editbutton'),delete=>$self->tl('deletefilesbutton'), zip=>$self->tl('zipdownloadbutton') );
        my %attr;

        my $extactions = $$self{config}{extensions}->handle('fileaction', { path=>$full });
        map { push @values, $$_{action}; $labels{$$_{action}}=$self->tl($$_{label}); $attr{$$_{action}}{disabled}='disabled' if $$_{disabled};  }  @{$extactions};

        if (! $$self{backend}->isWriteable($full)) {
                $attr{rename}{disabled}='disabled';
                $attr{delete}{disabled}='disabled';
        }
        if (! $$self{backend}->isReadable($full)) {
                $attr{zip}{disabled}='disabled';
        }

        if ($main::ALLOW_EDIT) {
                my $ef = '('.join('|',@main::EDITABLEFILES).')';
                $attr{edit}{disabled}='disabled' unless $$self{backend}->basename($file) =~/$ef/i && ($$self{backend}->isFile($full) && $$self{backend}->isWriteable($full));
        } else {
                @values = grep(!/^edit$/,@values);
        }

        return $$self{cgi}->popup_menu(-name=>'actions', -id=>'fileactions_'.$fid, -onchange=>"handleFileAction(this.value,'$fid',event,'select');", -values=>\@values, -labels=>\%labels, -attributes=>\%attr);
}
sub renderTableConfig {
        my ($self, $action) = @_;
	$action='window.location.reload()' unless $action;
        my $content = "";

        my $sortingcolumndefault ='name';
        my $sortingorderdefault = 'asc';
        if ($main::ORDER && $main::ORDER =~/^([^_]+)(_(.*))?$/) {
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
                $self->renderFieldSet('tableconfig.tablecolumns', $$self{cgi}->checkbox_group({-name=>'tablecolumns',-cols=>1,-values=>\@tablecolumns,-labels=>\%tablecolumnlabels,-defaults=>\@tablecolumndefaults, -attributes=>\%tablecolumnattributes}))
                .$self->renderFieldSet('tableconfig.sortingcolumns', $$self{cgi}->radio_group({-name=>'sortingcolumns',-cols=>1, -values=>\@sortingcolumns,-labels=>\%tablecolumnlabels,-default=>$sortingcolumndefault}))
                .$self->renderFieldSet('tableconfig.sortingorder', $$self{cgi}->radio_group({-name=>'sortingorder',-cols=>1, -values=>['asc','desc'], -labels=>{'asc'=>$self->tl('tableconfig.ascending'),'desc'=>$self->tl('tableconfig.descending')}, -default=>$sortingorderdefault}))
                .$$self{cgi}->div({-class=>'tableconfigactions'},
                        $$self{cgi}->button({-value=>$self->tl('cancel'),-onclick=>'toggleClassNameById("tableconfig","hidden",1)'})
                        .$$self{cgi}->button({-value=>$self->tl('savebutton'), -onclick=>'if (saveTableConfig()) '.$action})
                 )
        );

        return $$self{cgi}->div({-class=>'tableconfigcontainer'},$content);
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
                my ($v,$t) = $self->renderByteValue($val*($$self{BYTEUNITS}{$unit}||1),2,2);
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


1;

