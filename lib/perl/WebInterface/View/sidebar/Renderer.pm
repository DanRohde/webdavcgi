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

package WebInterface::View::sidebar::Renderer;

use strict;

use WebInterface::View::classic::Renderer;
our @ISA = ( 'WebInterface::View::classic::Renderer' );

sub render {
	my ($self,$fn,$ru) = @_;
        my $content = "";
        my $head = "";
        $self->setLocale();
        $head .= $self->replaceVars($main::LANGSWITCH) if defined $main::LANGSWITCH;
        $head .= $self->replaceVars($main::HEADER) if defined $main::HEADER;
        $content.=$$self{cgi}->start_multipart_form(-method=>'post', -action=>$ru, -onsubmit=>'return pleaseWait()' ) if $main::ALLOW_FILE_MANAGEMENT;
        if ($main::ALLOW_SEARCH && $$self{backend}->isReadable($fn)) {
                my $search = $$self{cgi}->param('search');
                $head .= $$self{cgi}->div({-class=>'search'}, $self->tl('search'). ' '. $$self{cgi}->input({-title=>$self->tl('searchtooltip'),-onkeypress=>'javascript:handleSearch(this,event);', -onkeyup=>'javascript:if (this.size<this.value.length || (this.value.length<this.size && this.value.length>10)) this.size=this.value.length;', -name=>'search',-size=>$search?(length($search)>10?length($search):10):10, -value=>defined $search?$search:''}));
        }
        $head.=$self->renderMessage();
        if ($$self{cgi}->param('search')) {
                $content.=$self->getSearchResult($$self{cgi}->param('search'),$fn,$ru);
        } else {
                my $showall = $$self{cgi}->param('showpage') ? 0 : $$self{cgi}->param('showall') || $$self{cgi}->cookie('showall') || 0;
                ##$head .= $$self{cgi}->div({-id=>'notwriteable',-onclick=>'fadeOut("notwriteable");', -class=>'notwriteable msg'}, $self->tl('foldernotwriteable')) if !$$self{backend}->isWriteable($fn);
                ##$head .= $$self{cgi}->div({-id=>'notreadable', -onclick=>'fadeOut("notreadable");',-class=>'notreadable msg'},  $self->tl('foldernotreadable')) if !$$self{backend}->isReadable($fn);
                $head .= $$self{cgi}->div({-id=>'filtered', -onclick=>'fadeOut("filtered");', -class=>'filtered msg', -title=>$main::FILEFILTERPERDIR{$fn}}, $self->tl('folderisfiltered', $main::FILEFILTERPERDIR{$fn} || ($main::ENABLE_NAMEFILTER ? $$self{cgi}->param('namefilter') : undef) )) if $main::FILEFILTERPERDIR{$fn} || ($main::ENABLE_NAMEFILTER && $$self{cgi}->param('namefilter'));
                $head .= $$self{cgi}->div( { -class=>'foldername'},
                        $$self{cgi}->a({-href=>$ru},
                                        $$self{cgi}->img({-src=>$self->getIcon('<folder>'),-title=>$ru, -alt=>'folder'})
                                )
                        .($main::ENABLE_DAVMOUNT ? '&nbsp;'.$$self{cgi}->a({-href=>'?action=davmount',-class=>'davmount',-title=>$self->tl('mounttooltip')},$self->tl('mount')) : '')
                        .' '
                        .$self->getQuickNavPath($fn,$ru)
                );
                $head.= $$self{cgi}->div( { -class=>'viewtools' },
                                ($ru=~/^$main::VIRTUAL_BASE\/?$/ ? '' :$$self{cgi}->a({-class=>'up', -href=>main::getParentURI($ru).(main::getParentURI($ru) ne '/'?'/':''), -title=>$self->tl('uptitle')}, $self->tl('up')))
                                .' '.$$self{cgi}->a({-class=>'refresh',-href=>$ru.'?t='.time(), -title=>$self->tl('refreshtitle')},$self->tl('refresh')));
                if ($main::SHOW_QUOTA) {
                        my($ql, $qu) = main::getQuota($fn);
                        if (defined $ql && defined $qu) {
                                my ($ql_v, $ql_t ) = $self->renderByteValue($ql,2,2);
                                my ($qu_v, $qu_t ) = $self->renderByteValue($qu,2,2);
                                my ($qa_v, $qa_t ) = $self->renderByteValue($ql-$qu,2,2);
				my $style = '';
				my $exceeded;
				if ($ql>0 && ($ql-$qu)  / $ql <= $main::QUOTA_LIMITS{critical}{limit}) {
					$exceeded = 'critical';
				} elsif ($ql>0 && ($ql-$qu) / $ql <= $main::QUOTA_LIMITS{warn}{limit}) {
					$exceeded = 'warn';
				}
				if ($exceeded) {
					$style='color: '.$main::QUOTA_LIMITS{$exceeded}{color} 
						if exists $main::QUOTA_LIMITS{$exceeded}{color};
					$style.=';background-color: '.$main::QUOTA_LIMITS{$exceeded}{background} 
							if exists $main::QUOTA_LIMITS{$exceeded}{background};
				}
                                $head.= $$self{cgi}->div({-class=>'quota', style=>$style},
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
		$content.=$self->renderSideBar();
		$folderview.=$self->renderToolbar() if $main::ALLOW_FILE_MANAGEMENT;
                if ($main::ALLOW_FILE_MANAGEMENT && $$self{backend}->isWriteable($fn)) {
                        my $m = "";
                        $m .= $self->renderFieldSet('files', $self->renderCreateNewFolderView().$self->renderCreateNewFileView().($main::ALLOW_SYMLINK ? $self->renderCreateSymLinkView():'').$self->renderMoveView() .$self->renderDeleteView());
                        $m .= $self->renderFieldSet('zip', $self->renderZipView()) if ($main::ALLOW_ZIP_UPLOAD || $main::ALLOW_ZIP_DOWNLOAD);
                        $m .= $self->renderToggleFieldSet('mode', $self->renderChangePermissionsView()) if $main::ALLOW_CHANGEPERM;
                        $m .= $self->renderToggleFieldSet('afs', $self->renderAFSACLManager()) if ($main::ENABLE_AFSACLMANAGER);
                        $manageview .= $self->renderToggleFieldSet('management', $m);
                }
                my $showsidebar = $$self{cgi}->cookie('sidebar') ? $$self{cgi}->cookie('sidebar') eq 'true' : 1;
                $content .= $$self{cgi}->div({-id=>'folderview', -class=>'sidebarfolderview'.($showsidebar?'':' full')}, $folderview);
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
        $content.= $$self{cgi}->div({-class=>'signature sidebarsignature'}, $self->replaceVars($main::SIGNATURE)) if defined $main::SIGNATURE;
        ###$content =~ s/(<\/\w+[^>]*>)/$1\n/g;
        $content = $self->start_html("$main::TITLEPREFIX $ru").$content.$$self{cgi}->end_html();

        main::printCompressedHeaderAndContent('200 OK','text/html',$content,'Cache-Control: no-cache, no-store', $self->getCookies());
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
                $content .= $self->renderSideBarMenuItem('creatensymlinkview', $self->tl('createsymlinkdescr'), 'toggleActionView("createsymlinkview","linkdstname");', $$self{cgi}->button({-value=>$self->tl('createsymlinkbutton'),-name=>'createsymlink',-disabled=>'disabled'})) if $main::ALLOW_SYMLINK;
                $content .= $self->renderSideBarMenuItem('movefilesview', $self->tl('movefilesbutton'), undef, $$self{cgi}->button({-disabled=>'disabled',-onclick=>'toggleActionView("movefilesview","newname");',-name=>'rename',-value=>$self->tl('movefilesbutton')}));
                $content .= $self->renderSideBarMenuItem('permissionsview', $self->tl('mode'), undef, $$self{cgi}->button({-disabled=>'disabled', -onclick=>'toggleActionView("permissionsview");', -value=>$self->tl('mode'),-name=>'changeperm',-disabled=>'disabled'})) if $main::ALLOW_CHANGEPERM;
                $content .= $self->renderSideBarMenuItem('afsaclmanagerview', $self->tl('afs'), 'toggleActionView("afsaclmanagerview");', $$self{cgi}->button({-value=>$self->tl('afs'),-name=>'saveafsacl'})) if $main::ENABLE_AFSACLMANAGER;
                $content .= $$self{cgi}->hr().$self->renderSideBarMenuItem('afsgroupmanagerview', $self->tl('afsgroup'), 'toggleActionView("afsgroupmanagerview");', $$self{cgi}->button({-value=>$self->tl('afsgroup')})).$$self{cgi}->hr() if $main::ENABLE_AFSGROUPMANAGER;
                $av.= $self->renderActionView('fileuploadview', 'upload', $self->renderFileUploadView($main::PATH_TRANSLATED,'filesubmit'), 'filesubmit',0,0);
                $av.= $self->renderActionView('zipfileuploadview', 'zipfileupload', $self->renderZipUploadView(), 'zipfile_upload',0,0) if $main::ALLOW_ZIP_UPLOAD;
                $av.= $self->renderActionView('createfolderview', 'createfolderbutton', $self->renderCreateNewFolderView("colname-sidebar"),'colname-sidebar');
                $av.= $self->renderActionView('createnewfileview', 'createnewfilebutton', $self->renderCreateNewFileView(),'cnfname');
                $av.= $self->renderActionView('createsymlinkview', 'createsymlinkbutton', $self->renderCreateSymLinkView(),'linkdstname') if $main::ALLOW_SYMLINK;
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

        my $showsidebar =  (! defined $$self{cgi}->cookie('sidebar') || $$self{cgi}->cookie('sidebar') eq 'true');
        my $sidebartogglebutton = $showsidebar ? '&lt;' : '&gt;';

        return $$self{cgi}->div({-id=>'sidebar', -class=>'sidebar'}, $$self{cgi}->start_table({-id=>'sidebartable',-class=>'sidebartable'.($showsidebar ?'':' collapsed')}).$$self{cgi}->Tr($$self{cgi}->td({-id=>'sidebarcontent', -class=>'sidebarcontent'.($showsidebar?'':' collapsed')},$content).$$self{cgi}->td({-id=>'sidebartogglebutton', -title=>$self->tl('togglesidebar'), -class=>'sidebartogglebutton', -onclick=>'toggleSideBar()'},$sidebartogglebutton)).$$self{cgi}->end_table()). $av ;
}


1;
