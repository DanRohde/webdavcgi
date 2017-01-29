/*********************************************************************
(C) ZE CMS, Humboldt-Universitaet zu Berlin
Written 2013 by Daniel Rohde <d.rohde@cms.hu-berlin.de>
**********************************************************************
This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.
You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
**********************************************************************/
var ToolBox = {};
/*$(document).ready(function() {*/
$(function() {
	
	initUIEffects();

	initPopupMenu();
	
	initBookmarks();
	
	initFileListActions();
	
	initFileActions();
	
	initClipboard();
	
	initFolderStatistics();
	
	initToolbarActions();
	
	initNavigationActions();
	
	initChangeDir();
	
	initFilterBox();
	
	initFileUpload();
	
	initSelectionStatistics();
	
	initDialogActions();
	
	initViewFilterDialog();
	
	initClock();
	
	initSelect();
	
	initChangeUriAction();
	
	initFancyBox();
	
	initWindowResize();
	
	initSettingsDialog();
	
	initAutoRefresh();
	
	initCollapsible();
	
	initTableConfigDialog();
	
	initKeyboardSupport();
	
	initDotFilter();
	
	initThumbnailSwitch();
	
	initFileListViewSwitches();
	
	initTooltips();
	
	initNav();
	
	initStatusbar();
	
	initTabs();
	
	initToolBox();
	
	initGuide();
	
	initFolderTree();

	$.ajaxSetup({ traditional: true });
	
	$(document).ajaxError(function(event, jqxhr, settings, exception) { 
		console.log(event);
		console.log(jqxhr); 
		console.log(settings);
		console.log(exception);
		if (jqxhr && jqxhr.statusText && jqxhr.statusText != 'abort') notifyError(jqxhr.statusText);
		$.MyPageBlocker("remove");
		//if (jqxhr.status = 404) window.history.back();
	}).ajaxSuccess(function(event,jqxhr,options,data) {
		if (jqxhr.getResponseHeader('X-Login-Required')) {
			window.alert($("#login-session").text());
			window.location.href = jqxhr.getResponseHeader('X-Login-Required');
		}
	});
	// allow script caching:
	$.ajaxPrefilter('script',function( options, originalOptions, jqXHR ) { options.cache = true; });
	
	updateFileList($("#flt").attr("data-uri"));

function handleFolderTreeDrop(event,ui) {
	var dsturi = $(this).closest(".mft-node").data("mftn").uri;
	var srcinfo = getFileListDropSrcInfo(event,ui);
	if (dsturi != srcinfo.srcuri) doFileListDropWithConfirm(srcinfo,dsturi);
	return false;
}
function initFolderTree() {
	var baseuri = $("#flt").data("baseuri");
	$(".action.toggle-foldertree").on("click", function() {
		
		$("#content").toggleClass("show-foldertree");
		$.MyCookie.toggleCookie("settings.show.foldertree","yes", $("#content").hasClass("show-foldertree"), true);
	});
	$("#foldertree").MyFolderTree({ 
		nodeClickHandler: function(data) {
			if (data.isreadable && data.uri) changeUri(data.uri);
		},
		initDom: function(el) {
			el.MyTooltip();
			el.find(".mft-node-label,.mft-node-expander").MyKeyboardEventHandler();
		},
		droppable : {
			selector: ".mft-node.iswriteable-yes .mft-node-label",
			params: { scope: "fileList", tolerance: "pointer", drop: handleFolderTreeDrop, hoverClass: 'foldertree-draghover' }
		},
		rootNodes : [ { name: baseuri, uri: baseuri, isreadable: true, iswriteable: true, classes: "isreadable-yes iswriteable-yes" } ],
		getFolderTree: function(node, callback) {
			$.MyPost(node.uri, { ajax:"getFolderTree" }, function(response) {
				handleJSONResponse(response);
				callback(response.children ? response.children: []);
			});
		},
	});
	$("#content").toggleClass("show-foldertree", $.MyCookie("settings.show.foldertree") == "yes");
}
function initFileListViewSwitches() {
	var v = $.MyCookie("settings.filelisttable.view");
	if (v) {
		$("#flt").addClass(v);
		$(".action.flt-view-change."+v).addClass("toggle-on");
	} else {
		$("#flt").addClass($(".action.flt-view-default").data("view"));
		$(".action.flt-view-default").addClass("toggle-on");
	}
	$(".action.flt-view-change").on("click",function() {
		var self = $(this);
		$.MyCookie("settings.filelisttable.view", self.data("view"));
		$("body").trigger("settingchanged", { setting: "settings.filelisttable.view", value: self.data("view") });
	});
	$("body").on("settingchanged", function(ev,data) {
		if (data.setting == "settings.filelisttable.view") {
			$(".action.flt-view-change").removeClass("toggle-on");
			$(".action.flt-view-change."+data.value).addClass("toggle-on");
			$(".action.flt-view-change").each(function() {
				$("#flt").removeClass($(this).data("view"));
			});
			$("#flt").addClass(data.value);
		}
	});
}
function initTabs(el) {
	if (!el) el=$(document);
	$('.tabsel',el).on("click keyup", function(ev) {
		if (ev.type == 'keyup' && ev.keyCode != 32 && ev.keyCode != 13) return;
		$.MyPreventDefault(ev);
		var self = $(this);
		$('.tabsel.activetabsel',el).removeClass('activetabsel');
		self.addClass('activetabsel');
		$('.tab.showtab',el).removeClass('showtab');
		var tab = $('.tab.'+self.data('group'),el).addClass('showtab');
		$(":focusable:visible:first", tab).focus();
	});
}
function initStatusbar() {
	if (!$.MyCookie("settings.show.statusbar")) {
		$.MyCookie("settings.show.statusbar","no");
		$.MyCookie("settings.show.statusbar.keep","yes");
	}
	$("#statusbar").toggleClass("enabled", $.MyCookie("settings.show.statusbar") == "yes");
	$("#statusbar .unselectable").off("change").on("change", function(e) {$(this).prop("checked",true); $.MyPreventDefault(e); });
	function renderStatusbarTemplate(){ 
		var flt = $("#fileListTable");
		var sb = $("#statusbar");
		$(".filecount",sb).html(flt.attr("data-filecounter"));
		$(".dircount",sb).html(flt.attr("data-dircounter"));
		$(".sum",sb).html(flt.attr("data-sumcounter"));
		$(".foldersize",sb).attr("title",$.MyStringHelper.renderByteSizes(flt.data("foldersize"))).html($.MyStringHelper.renderByteSize(flt.data("foldersize")));
		$(".selfilecount",sb).html(flt.attr("data-fileselcounter"));
		$(".seldircount",sb).html(flt.attr("data-dirselcounter"));
		$(".selsum",sb).html(flt.attr("data-sumselcounter"));
		$(".selfoldersize",sb).attr("title", $.MyStringHelper.renderByteSizes(flt.attr("data-folderselsize"))).html($.MyStringHelper.renderByteSize(flt.attr("data-folderselsize")));
		$(".selected-files-stats",sb).toggle(flt.attr("data-fileselcounter") !== 0 || flt.attr("data-dirselcounter") !== 0);
	}
	renderStatusbarTemplate();
	$("#flt").on("counterUpdated fileListChanged selectionCounterUpdated", renderStatusbarTemplate);
	$("body").on("notify",function(ev,data) {
		$("#statusbar .notify").attr("title",data.msg).removeClass("error message warning").addClass(data.type).html(data.msg).MyTooltip();
	});
	$("body").on("settingchanged",function(ev,data) {
		if (data.setting == "settings.show.statusbar") {
			$("#statusbar").toggleClass("enabled", data.value);
		}
	});
	$("#statusbar").MyTooltip();
	
}
function initTooltips() {
	$("#flt").on("fileListChanged", function() {
		$("#flt,#bookmarks").MyTooltip();
	}).on("bookmarksChanged",function() {
		$("#bookmarks").MyTooltip();
	});
	$("#nav,#controls,#autorefreshtimer,#popupmenu").MyTooltip();
}
function initKeyboardSupport() {
	$("#flt").on("fileListChanged", function() { 
		$("#fileList tr").off("keydown.flctr").on("keydown.flctr",function(event) {
			var tabindex = this.tabIndex || 1;
			var self = $(this);
			if (self.is(":focus")) {
				if (event.keyCode ==32) handleRowClickEvent.call(this,event);
				else if (event.keyCode==13) 
					changeUri($.MyStringHelper.concatUri($("#fileList").attr('data-uri'), encodeURIComponent($.MyStringHelper.stripSlash(self.attr('data-file')))),self.attr("data-type") == 'file');
				else if (event.keyCode==46) {
					if ($("#fileList tr.selected:visible").length === 0) { 
						if (isSelectableRow(self)) handleFileDelete(self);
					} else handleFileListActionEventDelete();
				} else if (event.keyCode==36) 
					$("#fileList tr:visible").first().focus();
				else if (event.keyCode==35) 
					$("#fileList tr:visible").last().focus();
				else if (event.keyCode==45) 
					$(".paste").trigger("click");
			}
			if (event.keyCode==38 && tabindex > -1 ) {
				$.MyPreventDefault(event);
				if (isSelectableRow(self) && (event.shiftKey || event.altKey || event.ctrlKey || event.metaKey)) {
					toggleRowSelection(self, true);
					$("#flt").trigger("fileListSelChanged");
				}
				self.prevAll(":focusable:first").focus();
				removeTextSelections();
			} else if (event.keyCode==40) {
				$.MyPreventDefault(event);
				if (isSelectableRow(self) && (event.shiftKey || event.altKey || event.ctrlKey || event.metaKey)) {
					toggleRowSelection(self, true);
					$("#flt").trigger("fileListSelChanged");
				}
				self.nextAll(":focusable:first").focus();
				removeTextSelections();
			} 
		});
		$("#fileList tr[tabindex='1']").focus();
	});
	$("#accesskeydetailseventcatcher").on("focus", renderAccessKeyDetails);
	$("#gotofilelisteventcatcher").on("focus", function() { $("#fileList tr:focusable:first").focus(); });
	$("#gotoappsmenueventcatcher").on("focus", function() { $("#apps :focusable:first").focus(); });
	$("#gototoolbareventcatcher").on("focus", function() { $(".toolbar :focusable:first").focus(); });
}
function initTableConfigDialog() {
	$("#flt").on("fileListChanged", function() {
		$(".tableconfigbutton").click(function(event) {
			$.MyPreventDefault(event);
			if ($(this).hasClass("disabled")) return;
			$(".tableconfigbutton").addClass("disabled");
			
			var dialog = $("#flt").data("TableConfigDialog");
			if (dialog) {
				setupTableConfigDialog($(dialog));
			} else if ($("#tableconfigdialogtemplate").length>0) {
				var tct = $("#tableconfigdialogtemplate").html();
				$("#flt").data("TableConfigDialog", tct);
				setupTableConfigDialog($(tct));
			} else {
				$.MyPost($("#fileList").attr("data-uri"),{ ajax : 'getTableConfigDialog', template : $(this).attr("data-template")}, function(response) {
					if (response.error) handleJSONResponse(response);
					$("#flt").data("TableConfigDialog", response);
					setupTableConfigDialog($(response));
				});
			}
		}).MyKeyboardEventHandler();
	});
}
function setupTableConfigDialog(dialog) {
	// init dialog:
	var visiblecolumns = $.map($("#fileListTable thead th[data-name]:not(.hidden)"), function(val,i) { return $(val).attr("data-name");});
	$.each(visiblecolumns, function(i,val) {
		dialog.find("input[name='visiblecolumn'][value='"+val+"']").prop("checked",true);	
	});
	dialog.find("input[name='visiblecolumn'][value='name']").attr("readonly","readonly").prop("checked",true).click(function(e) { $.MyPreventDefault(e);}).closest("li").addClass("disabled");
	$("#fileListTable thead th.sorter-false").each(function(i,val) {
		dialog.find("input[name='sortingcolumn'][value='"+$(val).attr("data-name")+"']").prop("disabled",true).click(function(e){$.MyPreventDefault(e);}).closest("li").addClass("disabled");
	});
	
	var so = $.MyCookie("order") ? $.MyCookie("order").split("_") : "name_asc".split("_");
	var column = so[0];
	var order = so[1] || 'asc';
	
	dialog.find("input[name='sortingcolumn'][value='"+column+"']").prop("checked",true);
	dialog.find("input[name='sortingorder'][value='"+order+"']").prop("checked", true);
	
	dialog.find("input[value='fileactions']").closest("li").hide();
	
	// register dialog actions:
	dialog.find("input[name='save']").button().click(function(event) {
		// preserve table column order:
		var vc = visiblecolumns.slice(0); // clone visiblecolumns
		var vtc = $.map($("input[name='visiblecolumn']:checked"), function (val,i) { return $(val).attr("value"); });
		
		// this is more inefficient than
		// $.MyCookie("visibletablecolumns,vtc.join(","));
		// but preserves table column order:
		// remove unselected elements:
		var removedEls = [];
		for (var i=vc.length-1; i>=0; i--) {
			if ($.inArray(vc[i], vtc)==-1) {
				removedEls.push(vc[i]);
				vc.splice(i,1);
			}
		}
		// add missing selected elements:
		var addedEls = [];
		$.each(vtc, function(i,val) {
			if ($.inArray(val, vc)==-1) {
				addedEls.push(val);
				vc.push(val);
			}
		});
		
		var c = dialog.find("input[name='sortingcolumn']:checked").attr("value");
		var o = dialog.find("input[name='sortingorder']:checked").attr("value");
		
		var table = $("#fileListTable");
		if (vtc.sort().join(",") != visiblecolumns.sort().join(",")) {
			$.each(addedEls, function(i,val) {
				$.MyTableManager.toggleTableColumn(table, val, true);
			});
			$.each(removedEls, function(i,val) {
				$.MyTableManager.toggleTableColumn(table, val, false);
			});
		}
		$.MyTableManager.sortTable(table, c, o == 'desc' ? -1 : 1);
		
		dialog.dialog("close");
	});
	dialog.find("input[name='cancel']").button().click(function(event) {
		$.MyPreventDefault(event);
		dialog.dialog("close");
		return false;
	});
	
	dialog.find("#tableconfigform").submit(function(event) { return false; });
	
	dialog.dialog({ modal: true, width: "auto", title: dialog.attr("data-title") || dialog.attr("title"), dialogClass: "tableconfigdialog", height: "auto", close: function() { $(".tableconfigbutton").removeClass("disabled"); dialog.dialog("destroy");}});
	
}
function handleSidebarCollapsible(event) {
	if (event) $.MyPreventDefault(event);
	var collapsed = $(this).hasClass("collapsed");
	var iconsonly = $(this).hasClass("iconsonly");
	if (!collapsed && !iconsonly) iconsonly = true;
	else if (iconsonly) {
		iconsonly=false;
		collapsed=true;
	}
	else collapsed = false;
	
	$(".collapse-sidebar-listener").toggleClass("sidebar-collapsed", collapsed).toggleClass("sidebar-iconsonly", iconsonly);
	$(".action.collapse-sidebar").toggleClass("collapsed",collapsed).toggleClass("iconsonly",iconsonly);
	
	if (!iconsonly&&!collapsed) $.MyCookie.rmCookies("sidebar");
	else $.MyCookie("sidebar", iconsonly?"iconsonly":collapsed?"false":"true");
	
	handleWindowResize();
}
function initCollapsible() {
	$(".action.collapse-sidebar").click(handleSidebarCollapsible).MyKeyboardEventHandler().MyTooltip();
	if ($.MyCookie("sidebar") && $.MyCookie("sidebar") != "true") {
		$(".collapse-sidebar-listener").toggleClass("sidebar-collapsed", $.MyCookie("sidebar") == "false").toggleClass("sidebar-iconsonly", $.MyCookie("sidebar") == "iconsonly");
		$(".action.collapse-sidebar").toggleClass("collapsed", $.MyCookie("sidebar") == "false").toggleClass("iconsonly", $.MyCookie("sidebar") == "iconsonly");
		handleWindowResize();
	}
	
	$(".action.collapse-head").click(function(event) {
		$.MyPreventDefault(event);
		$(".action.collapse-head").toggleClass("collapsed");
		var collapsed = $(this).hasClass("collapsed");
		$(".collapse-head-collapsible").toggle(!collapsed);
		$(".collapse-head-listener").toggleClass("head-collapsed", collapsed);
		$.MyCookie.toggleCookie("head","false",collapsed, 1);
		handleWindowResize();
	}).MyTooltip().MyKeyboardEventHandler();
	if ($.MyCookie("head") == "false") $(".action.collapse-head").first().trigger("click");
}

function initAutoRefresh() {
	$(".autorefreshmenu").on("dblclick", function() { updateFileList() } );
	toggleButton($(".action.autorefreshrunning, .autorefreshtimer"), true);
	$(document).on("mycountdowntimer-started", function(e, data) {
		toggleButton($(".action.autorefreshrunning, .autorefreshtimer"), false);
		$("#autorefreshtimer").show();
		$(".action.autorefreshtoggle").addClass("running");
		renderAutoRefreshTimer(data.timeout);
	}).on("mycountdowntimer-paused", function(e, data) {
		renderAutoRefreshTimer(data.timeout);
		$(".action.autorefreshtoggle").removeClass("running");
	}).on("mycountdowntimer-stopped", function() {
		toggleButton($(".action.autorefreshrunning, .autorefreshtimer"), true);
		$("#autorefreshtimer").hide();
		$(".action.autorefreshtoggle").removeClass("running");
	}).on("mycountdowntimer-elapsed", function(e,data) {
		renderAutoRefreshTimer(data.timeout);
	}).on("mycountdowntimer-lapsed", function() {
		renderAutoRefreshTimer(0);
		updateFileList();
	});
	
	$("#flt").on("fileListChanged", function() {
		if ($.MyCookie("autorefresh") !== "" && parseInt($.MyCookie("autorefresh"),10)>0) $(document).MyCountdownTimer("start", parseInt($.MyCookie("autorefresh"),10));
	});
	$(".action.setautorefresh").click(function(event){
		if ($(this).attr("data-value") === "now") {
			updateFileList();
			return;
		}
		$.MyCookie("autorefresh", $(this).attr("data-value"));
		$(document).MyCountdownTimer("start", parseInt($(this).data("value"),10));
	});
	$(".action.autorefreshclear").click(function(event) {
		if ($(this).hasClass("disabled")) return;
		$(document).MyCountdownTimer("stop");
		$.MyCookie.rmCookies("autorefresh");
	});
	$(".action.autorefreshtoggle").click(function(event) {
		if ($(this).hasClass("disabled")) return;
		$(document).MyCountdownTimer("toggle");
	});
	
	$("#autorefreshtimer").MyFixedElementDragger();
}

function renderAutoRefreshTimer(aftimeout) {
	var t = $(".autorefreshtimer");
	var f = t.attr("data-template") || "%sm %ss";
	var minutes = Math.floor(aftimeout / 60);
	var seconds = aftimeout % 60;
	if (seconds < 10) seconds="0"+seconds;
	t.html(f.replace("%s", minutes).replace("%s", seconds));
}

function initSettingsDialog() {
	var settings = $("#settings");
	settings.data("initHandler", { init: function() {
		$("input[type=checkbox][name^='settings.']", settings).each(function(i,v) {
			$(v).prop("checked", $.MyCookie($(v).prop("name")) != "no").click(function(event) {
				if ($.MyCookie($(this).prop("name")+".keep")) 
					$.MyCookie($(this).prop("name"),$(this).is(":checked")?'yes':'no',1);
				else 
					$.MyCookie.toggleCookie($(this).prop("name"),"no",!$(this).is(":checked"), 1);
				$("body").trigger("settingchanged", { setting: $(this).prop("name"), value: $(this).is(":checked") });
			});
		});
		$("select[name^='settings.']", settings)
			.change(function(){
				if ($(this).prop("name") == "settings.lang") {
					$.MyCookie($(this).prop("name").replace(/^settings./,""),$("option:selected",$(this)).val(),1);
					window.location.href = window.location.pathname; // reload bug fixed (if query view=...)
				} else {
					$.MyCookie($(this).prop("name"), $("option:selected",$(this)).val(),1);
					$("body").trigger("settingchanged", { setting: $(this).prop("name"), value: $("option:selected",$(this)).val()});
				}
			})
			.each(function(i,v) {
				var s = $(v);
				var name = s.prop("name");
				if (name == "settings.lang") name = name.replace(/^settings\./,"");
				$("option[value='"+$.MyCookie(name)+"']", s).prop("selected",true);
			});
	}});
}
function initUIEffects() {
	$(".accordion").accordion({ collapsible: true, active: false });
	
	$("#flt").on("fileListChanged", function() {
		$(".dropdown-hover")
			.off(".dropdown-hover")
			.on("mouseenter.dropdown-hover", function() { $(".dropdown-menu",$(this)).show(); })
			.on("mouseleave.dropdown-hover", function() { $(".dropdown-menu",$(this)).hide(); })
			.on("focus.dropdown-hover", function() { $(".dropdown-menu",$(this)).show(); } )
			.on("keyup.dropdown-hover", function(e) { if (e.keyCode==13 || e.keyCode == 32) $(".dropdown-menu" , $(this)).hide(); } );
		$(".dropdown-click")
			.off(".dropdown-click")
			.on("click.dropdown-click dblclick.dropdown-click", function(e) { $.MyPreventDefault(e); $(".dropdown-menu",$(this)).toggle(); })
			.MyKeyboardEventHandler({namespace:'dropdown-click'});
	});
}
function initWindowResize() {
	$("#flt").on("fileListChanged", handleWindowResize).on("fileListViewChanged", handleWindowResize);
	$(window).resize(handleWindowResize);
	handleWindowResize();
}
function handleWindowResize() {
	var width = $(window).width()-$("#nav").width();
	$("#content").width(width);
	$("#controls").width(width);
	$("body").trigger("windowResized");
}

function initChangeUriAction() {
	
	$(".home-button[data-href], .logout-button[data-href], .contact-button[data-href], .link-button[data-href], .help-button[data-href]")
		.off("click")
		.attr("tabindex",0 )
		.on("click", function() { window.open($(this).data("href"), $(this).data("target") || "_self"); });
	
	$(".action.changeuri").off(".changeuri").on("click.changeuri",handleChangeUriAction);
	$(".action.refresh").off(".refresh").on("click.refresh",function(event) {
		$.MyPreventDefault(event);
		updateFileList();
		return false;
	});
	$("#flt").on("fileListChanged", function() {
		$("#fileList .is-dir .action.changeuri").off(".changeuri").on("click.changeuri", handleChangeUriAction);
		$("#fileList .is-file .action.changeuri").off(".changeuri").on("click.changeuri",
				function() {
					var self=$(this);
					if (!self.closest("div.filename").is(".ui-draggable-dragging")) {
						window.location.href=self.data("href")? self.data("href") : self.attr("href");
					}
				});
	});
}
function handleChangeUriAction(event) {
	$.MyPreventDefault(event);
	if (!$(this).closest("div.filename").is(".ui-draggable-dragging")) {
		changeUri($(this).data("href") || $(this).attr("href") || $(this).data("uri"));
	}
	return false;
}
function initSelect() {
	$("#flt").on("fileListChanged", function() {
		$(".toggleselection").off("click.select").on("click.select",function(event) {
			$("#fileList tr:not(:hidden).unselectable-no").each(function(i,row) {
				$(this).toggleClass("selected");
				$(".selectbutton", $(this)).prop("checked", $(this).hasClass("selected"));
			});
			$("#flt").trigger("fileListSelChanged");
		}).MyKeyboardEventHandler({namespace:'select'});
		$(".selectnone").off("click.select").on("click.select",function(event) {
			$("#fileList tr.selected:not(:hidden)").removeClass("selected");
			$("#fileList tr:not(:hidden) .selectbutton:checked").prop("checked", false);
			$("#flt").trigger("fileListSelChanged");
		}).MyKeyboardEventHandler({namespace:'select'});
		$(".selectall").off("click.select").on("click.select",function(event) {
			$("#fileList tr:not(.selected):not(:hidden).unselectable-no").addClass("selected");
			$("#fileList tr:not(:hidden).unselectable-no .selectbutton:not(:checked)").prop("checked", true);
			$("#flt").trigger("fileListSelChanged");
		}).MyKeyboardEventHandler({namespace:'select'});
	});
}
function initClock() {
	$("#clock").MyClock();
}
function initBookmarks() {
	$("#flt").on("bookmarksChanged", buildBookmarkList)
	.on("bookmarksChanged fileListSelChanged",toggleBookmarkButtons)
	.on("fileListChanged", function() {
		buildBookmarkList();
		toggleBookmarkButtons();	
	});
	// register bookmark actions:
	$(".action.addbookmark,.action.rmbookmark,.action.rmallbookmarks,.action.bookmarksortpath,.action.bookmarksorttime,.action.gotobookmark")
		.click(handleBookmarkActions);
}
function toggleButton(button, disabled) {
	$.each(button, function(i,v) { 
		var self = $(v);
		if (self.hasClass("hideit")) self.toggle(!disabled); // self.css({"display" : disabled ? "none" : "", "visibility" : disabled ? "hidden" : ""});
		if (self.hasClass("button")) self.button("option","disabled",disabled);
		if (!self.hasClass("notab")) self.attr("tabindex",disabled ? -1 : 0);
		self.toggleClass("disabled", disabled);
	});
}
function toggleBookmarkButtons() {
	var currentPath = $.MyStringHelper.concatUri($("#flt").attr("data-uri"),"/");	
	var isCurrentPathBookmarked = false;
	var count = 0;
	var i = 0;
	while ($.MyCookie("bookmark"+i)!=null) {
		if ($.MyCookie("bookmark"+i) == currentPath) isCurrentPathBookmarked=true;
		if ($.MyCookie("bookmark"+i) != "-") count++;
		i++;
	}
	toggleButton($(".action.addbookmark"), isCurrentPathBookmarked);
	//toggleButton($(".action.rmbookmark"), !isCurrentPathBookmarked);
	toggleButton($(".action.bookmarksortpath"), count<2);
	toggleButton($(".action.bookmarksorttime"), count<2);
	toggleButton($(".action.rmallbookmarks"), count===0);

	var sort = $.MyCookie("bookmarksort")==null ? "time-desc" : $.MyCookie("bookmarksort");
	$(".action.bookmarksortpath .path").hide();
	$(".action.bookmarksortpath .path-desc").hide();
	$(".action.bookmarksorttime .time").hide();
	$(".action.bookmarksorttime .time-desc").hide();
	if (sort == "path" || sort=="path-desc" || sort=="time" || sort=="time-desc") {
		$(".action.bookmarksort"+sort.replace(/-desc/,"")+" ."+sort).show();
	}
}
function buildBookmarkList() {
	var currentPath = $.MyStringHelper.concatUri($("#flt").attr("data-uri"),"/");
	// remove all bookmark list entries:
	$(".dyn-bookmark").each(function(i,val) {
		$(val).remove();
	});
	// read existing bookmarks:
	var bookmarks = [];
	var i=0;
	while ($.MyCookie("bookmark"+i)!=null) {
		if ($.MyCookie("bookmark"+i)!="-") bookmarks.push({ path : $.MyCookie("bookmark"+i), time: parseInt($.MyCookie("bookmark"+i+"time"))});
		i++;
	}
	// sort bookmarks:
	var s = $.MyCookie("bookmarksort") ? $.MyCookie("bookmarksort") : "time-desc";
	var sortorder = 1;
	if (s.indexOf("-desc")>0) { sortorder = -1; s= s.replace(/-desc/,""); }
	bookmarks.sort(function(b1,b2) {
		if (s == "path") return sortorder * b1[s].localeCompare(b2[s]);
		else return sortorder * ( b2[s] - b1[s]);
	});
	// build bookmark list:
	var tmpl = $(".bookmarktemplate").first().html();
	$.each(bookmarks, function(i,val) {
		var epath = unescape(val.path);
		$("<li>" + tmpl.replace(/\$bookmarkpath/g,val.path).replace(/\$bookmarktext/,$.MyStringHelper.quoteWhiteSpaces($.MyStringHelper.simpleEscape($.MyStringHelper.trimString(epath,20)))) + "</li>")
			.clone(false).insertAfter($(".bookmarktemplate"))
			.click(handleBookmarkActions).MyKeyboardEventHandler()
			.addClass("action dyn-bookmark")
			.attr('data-bookmark',val.path)
			.attr("data-htmltooltip",$.MyStringHelper.simpleEscape(epath)+"%0D"+(new Date(parseInt(val.time))))
			.attr("tabindex", val.path == currentPath ? -1 : 0)
			.toggleClass("disabled", val.path == currentPath)
			.find(".action.rmsinglebookmark").click(handleBookmarkActions).MyKeyboardEventHandler();
	});
}
function removeBookmark(path) {
	var i = 0;
	while ($.MyCookie('bookmark'+i) != null && $.MyCookie('bookmark'+i)!=path) i++;
	if ($.MyCookie('bookmark'+i) == path) $.MyCookie('bookmark'+i, "-", 1);
	$('#flt').trigger("bookmarksChanged");
}
function handleBookmarkActions(event) {
	$.MyPreventDefault(event);
	if ($(this).hasClass("disabled")) return;
	var self = $(this);
	var uri = $("#fileList").attr('data-uri');
	if (self.hasClass('addbookmark')) {
		var i = 0;
	        while ($.MyCookie('bookmark'+i)!=null && $.MyCookie('bookmark'+i)!= "-" && $.MyCookie('bookmark'+i) != "" && $.MyCookie('bookmark'+i)!=uri) i++;
		$.MyCookie('bookmark'+i, uri, 1);
		$.MyCookie('bookmark'+i+'time', (new Date()).getTime(), 1);
		$("#flt").trigger("bookmarksChanged");
	} else if (self.hasClass('dyn-bookmark')) {
		changeUri(self.attr('data-bookmark'));	
		self.closest("ul").hide();
	} else if (self.hasClass('rmbookmark')) {
		removeBookmark(uri);
	} else if (self.hasClass('rmallbookmarks')) {
		var i = 0;
		while ($.MyCookie('bookmark'+i)!=null) {
			$.MyCookie.rmCookies('bookmark'+i, 'bookmark'+i+'time');
			i++;
		}
		$('#flt').trigger("bookmarksChanged");
	} else if (self.hasClass('rmsinglebookmark')) {
		removeBookmark($(this).attr("data-bookmark"));
	} else if (self.hasClass('bookmarksortpath')) {
		$.MyCookie("bookmarksort", $.MyCookie("bookmarksort")=="path" || $.MyCookie("bookmarksort") == null ? "path-desc" : "path");
		$("#flt").trigger("bookmarksChanged");
	} else if (self.hasClass('bookmarksorttime')) {
		$.MyCookie("bookmarksort", $.MyCookie("bookmarksort")=="time" ? "time-desc" : "time");
		$("#flt").trigger("bookmarksChanged");
	}
}
function initSelectionStatistics() {
	$('#selstats').data('selstats', $('#selstats').html());
	$("#flt").on("fileListSelChanged",handleSelectionStatistics).on("fileListViewChanged",handleSelectionStatistics);
}
function handleSelectionStatistics() {
	var selstats = $('#selstats');
	var tmpl = selstats.data('selstats');

	var s = getFolderStatistics();
	$("#fileListTable").attr('data-fileselcounter',s.fileselcounter).attr('data-dirselcounter',s.dirselcounter).attr('data-folderselsize',s.folderselsize).attr("data-sumselcounter", s.sumselcounter);
	$("#flt").trigger("selectionCounterUpdated");
	selstats.html(
			tmpl.replace(/\$filecount/g,s.fileselcounter)
				.replace(/\$dircount/g,s.dirselcounter)
				.replace(/\$sum/g,s.sumselcounter)
				.replace(/\$folderselsizes/g, $.MyStringHelper.renderByteSizes(s.folderselsize))
				.replace(/\$folderselsize/g,$.MyStringHelper.renderByteSize(s.folderselsize))
			).attr('title',$.MyStringHelper.renderByteSizes(s.folderselsize)).MyTooltip();
}

function initChangeDir() {
	$("#pathinputform").submit(function(event) { return false; });
	$("#pathinputform input[name='uri']").keydown(function(event){
		if (event.keyCode==27) {
			$('#pathinput').hide();
			$('#quicknav').show();
			$('.filterbox').show();
		} else if (event.keyCode==13) {
			$.MyPreventDefault(event);
			$('#pathinput').hide();
			$('#quicknav').show();
			$('.filterbox').show();
			changeUri($(this).val());
		}
	});
	$(".action.changedir").button().click(function(event) {
		$.MyPreventDefault(event);
		$('#pathinput').toggle();
		$('#quicknav').toggle();
		$('#pathinput input[name=uri]').focus().select();
		$('.filterbox').toggle();
	});
	$("#path [data-action='chdir']").button().click(function(event){
		$.MyPreventDefault(event);
		$('#pathinput').hide();
		$('#quicknav').show();
		changeUri($("#pathinput input[name='uri']").val());
	});
	$("#flt").on("fileListChanged", function() {
		$('#pathinput input[name=uri]').val(decodeURI($('#fileList').attr('data-uri')));
	});
	

}
function initFilterBox() {
	$("form#filterbox").submit(function(event) { return false;});
	$("form#filterbox input").keyup(applyFilter).change(applyFilter).autocomplete({minLength: 1, select: applyFilter, close: applyFilter});
	// clear button:
	$("form#filterbox .action.clearfilter").toggleClass("invisible",$("form#filterbox input").val()=== "");
	$("form#filterbox input").keyup(function() {
		$("form#filterbox .action.clearfilter").toggleClass("invisible",$(this).val()=== "");
	});
	$("form#filterbox .action.clearfilter").click(function(event) {
		$.MyPreventDefault(event);
		$("form#filterbox input").val("");
		applyFilter();
		$(this).addClass("invisible");
	});
	
	$("#flt")
		.on("fileListChanged", applyFilter)
		.on("fileListChanged", function() {
			var files = $.map($("#fileList tr"),function(val,i) { return $(val).attr("data-file");});
			$("form#filterbox input")
				.autocomplete({ 
					source: function(request, response) {
						try {
							var matcher = new RegExp(request.term);
							response($.grep(files, function(item){ return matcher.test(item); }));
						} catch (e) {
							response($.grep(files, function(item){ return item.indexOf(request.term)>-1; }));
						}
					}
				});
		});
}
function applyFilter() {
	var filter = $("form#filterbox input").val();
	$('#fileList tr').each(function() {
		try {
			var r = new RegExp(filter,"i");
			if (filter === "" || $(this).attr('data-file').match(r)) $(this).show(); else $(this).hide();	
		} catch (error) {
			if (filter === "" || $(this).attr('data-file').toLowerCase().indexOf(filter.toLowerCase()) >-1) $(this).show(); else $(this).hide();
		}
	});

	$("#flt").trigger("fileListViewChanged");
	return true;
}
function renderUploadProgressAll(uploadState, data) {
	if (!data) data=uploadState;
	var perc =  data.loaded / data.total * 100;
	$('#progress .bar').css('width', perc.toFixed(2) + '%')
		.html(parseInt(perc)+'% ('+$.MyStringHelper.renderByteSize(data.loaded)+'/'+$.MyStringHelper.renderByteSize(data.total)+')' + "; " + uploadState.done+"/"+uploadState.uploads
				);	
}
function initUpload(form,confirmmsg,dialogtitle, dropZone) {
	$("#flt").on("fileListChanged",function() {
		form.fileupload("option","url",$("#fileList").attr("data-uri"));
	});
	var uploadState = {
		aborted: false,
		transports: [],
		done: 0,
		failed: 0,
		uploads: 0
	};
	form.fileupload({ 
		url: $("#fileList").attr("data-uri"), 
		sequentialUploads: false,
		limitConcurrentUploads: 3,
		dropZone: dropZone,
		singleFileUploads: true,
		autoUpload: false,
		add: function(e,data) {
			if (!uploadState.aborted) {
				var transport = data.submit();
				var filename = data.files[0].name;
				uploadState.transports.push(transport);
				var up =$("<div></div>").appendTo("#progress .info").attr("id","fpb"+filename).addClass("fileprogress");
				$("<div></div>").click(function(event) {
					$.MyPreventDefault(event);
					$(this).data("transport").abort($("#uploadaborted").html()+": "+$(this).data("filename"));
				}).appendTo(up).attr("title",$("#cancel").html()).MyTooltip().addClass("cancel").html("&nbsp;").data({ filename: filename, transport: transport });
				$("<div></div>").appendTo(up).addClass("fileprogressbar running").html(data.files[0].name+" ("+$.MyStringHelper.renderByteSize(data.files[0].size)+"): 0%");
				// $("#progress .info").scrollTop($("#progress
				// .info")[0].scrollHeight);
				uploadState.uploads++;
				return true;
			}
			return false;
		},
		done:  function(e,data) {
			$("#progress [id='fpb"+data.files[0].name+"'] .cancel").remove();
			$("div[id='fpb"+data.files[0].name+"'] .fileprogressbar", "#progress .info")
				.removeClass("running")
				.addClass(data.result.message ? "done" : "failed")
				.css("width","100%")
				.html(data.result && data.result.error ? data.result.error : data.result.message ? data.result.message : data.files[0].name);
			if (data.result.message) uploadState.done++; else uploadState.failed++;
			renderUploadProgressAll(uploadState);
		},
		fail: function(e,data) {
			$("#progress [id='fpb"+data.files[0].name+"'] .cancel").remove();
			$("div[id='fpb"+data.files[0].name+"'] .fileprogressbar", "#progress .info")
				.removeClass("running")
				.addClass("failed")
				.css("width","100%")
				.html(data.textStatus+": "+$.map(data.files, function(v,i) { return v.name;}).join(", "));
			uploadState.failed++;
			renderUploadProgressAll(uploadState);
			console.log(data);
		},
		stop: function(e,data) {
			// $('#progress').dialog('close');
			renderUploadProgressAll(uploadState);
			$(this).data('ask.confirm',false);
			$("#progress").dialog("option","beforeClose",function() { return true; });
			$("#progress").dialog("option","close",function() { updateFileList(); });
			$("#progress").dialog("option","buttons",[ { text: $("#close").html(), click:  function() { $(this).dialog("close"); }}]);
		},
		change: function(e,data) {
			uploadState.transports = [];
			uploadState.aborted = false;
			uploadState.files = [];
			uploadState.uploads = 0;
			uploadState.failed = 0;
			uploadState.done = 0;
			return true;
		},
		start: function(e,data) {
			
			var buttons = [];
			buttons.push({ text:$("#close").html(), disabled: true});
			buttons.push({text:$("#cancel").html(), click: function() {
				if (uploadState.aborted) return;
				uploadState.aborted=true;
				$.each(uploadState.transports, function(i,jqXHR) {
					if (jqXHR && jqXHR.abort) jqXHR.abort($("#uploadaborted").html());
				});
				uploadState.transports = [];
			}});
			$('#progress').dialog({ modal:true, title: dialogtitle, height: 370 , width: 500, buttons: buttons, dialogClass: "uploaddialog", beforeClose: function() { return false;} });
			$('#progress').show().each(function() {
				$(this).find('.bar').css('width','0%').html('0%');
				$(this).find('.info').html('');
			});
		},
		progress: function(e,data) {
			var perc = parseInt(data.loaded/data.total * 100)+"%";
			$("div[id='fpb"+data.files[0].name+"'] .fileprogressbar", "#progress .info").css("width", perc).html(data.files[0].name+" ("+$.MyStringHelper.renderByteSize(data.files[0].size)+"): "+perc);
			
		},
		progressall: function(e,data) {
			uploadState.total = data.total;
			uploadState.loaded = data.loaded;
			renderUploadProgressAll(uploadState, data);
		},
		submit: function(e,data) {
			if (!$(this).data('ask.confirm')) $(this).data('ask.confirm', $.MyCookie("settings.confirm.upload") == "no" || !checkUploadedFilesExist(data) || window.confirm(confirmmsg));
			$("#file-upload-form-relapath").val(data.files[0].relativePath || (data.files[0].webkitRelativePath && data.files[0].webkitRelativePath.split(/[\\\/]/).slice(0,-1).join('/')+'/') || '');
			$("#file-upload-form-token").val($("#token").val());
			return $(this).data('ask.confirm');
		}
	});	
}
function checkUploadedFilesExist(data) {
	for (var i=0; i<data.files.length; i++) {
		var relaPath;
		if (data.files[i].relativePath && data.files[i].relativePath != "") {
			relaPath = data.files[i].relativePath.split(/[\\\/]/)[0] + '/';
		} else if (data.files[i].webkitRelativePath && data.files[i].webkitRelativePath != "") {
			relaPath = data.files[i].webkitRelativePath.split(/[\\\/]/).slice(0,-1).join('/') + '/';
		}
		if (relaPath && $("#fileList tr[data-file='"+$.MyStringHelper.simpleEscape(relaPath)+"']").length>0) return true;
		else if ($("#fileList tr[data-file='"+$.MyStringHelper.simpleEscape(data.files[i].name)+"']").length>0) return true;
	}
	return false;
}
function initFileUpload() {
	initUpload($("#file-upload-form"),$('#fileuploadconfirm').html(), $("#progress").attr('data-title'), $(document));
	$(".action.upload").off("click.upload").on("click.upload", function(event) {
		if ($(this).hasClass("disabled")) return;
		$("#file-upload-form input[type=file]").removeAttr("directory webkitdirectory mozdirectory").trigger('click'); 
	});
	$(".action.uploaddir.uibutton").button();
	$(".action.uploaddir").off("click.uploaddir").on("click.uploaddir", function(event) {
		if ($(this).hasClass("disabled")) return;
		$("#file-upload-form input[type=file]").attr({"directory":"directory","webkitdirectory":"webkitdirectory","mozdirectory":"mozdirectory"}).trigger('click');
	});
	$(document).on('dragenter', function (e) {
		$("#fileList").addClass('draghover');
	}).on('dragleave', function(e) {
		$("#fileList").removeClass('draghover');
	}).on('drop', function(e) {
		$("#fileList").removeClass('hover');
	});

}

function confirmDialog(text, data) {
	var oldsetting;
	if (data.setting) {
		text+='<div class="confirmdialogsetting"><input type="checkbox" name="'+data.setting+'"/> '+$("#confirmdialogsetting").html()+'</div>';
		oldsetting = $.MyCookie(data.setting);
	}
	$("#confirmdialog").html(text).dialog({  
		modal: true,
		width: 500,
		height: "auto",
		title: $("#confirmdialog").attr('data-title'),
		closeText: $("#close").html(),
		buttons: [ 
			{ 
				text: $("#cancel").html(), 
				click: function() {
					if (data.setting) {
						$.MyCookie.toggleCookie(data.setting, oldsetting, oldsetting && oldsetting!=="",1);
					}
					$("#confirmdialog").dialog("close");  
					if (data.cancel) data.cancel();
				} 
			}, 
			{ 	
				text: "OK", 
				click: function() { 
					$("#confirmdialog").dialog("close");
					if (data.confirm) data.confirm();
				} 
			},
		],
		open: function() {
			if (data.setting) {
				$("input[name='"+data.setting+"']",$(this)).click(function(event) {
					$.MyCookie.toggleCookie(data.setting, "no", !$(this).is(":checked"), 1);
				}).prop("checked", $.MyCookie(data.setting)!="no");
			}
		},
		close: function() {
			if (data.cancel) data.cancel();
		}
	}).show();
}
function getVisibleAndSelectedFiles() {
	return $("#fileList tr.isreadable-yes.unselectable-no.selected:visible div.filename");
}
function getSelectedRows(el) {
	var selrows = $("#fileList tr.selected:visible");
	if (selrows.length === 0) selrows = $(el).closest("tr[data-file]");
	if (selrows.length === 0) selrows = $("#fileList tr:visible:focus");
	if (selrows.length === 0) selrows = $("#fileList tr:visible #popupmenu").closest("tr[data-file]");
	if (selrows.length === 0) selrows = $("#fileList tr:visible #fileactions").closest("tr[data-file]");
	return selrows;
}
function getSelectedFiles(el) {
	return $.map(getSelectedRows(el), function (v) { return $(v).attr("data-file"); });
}
function handleFileActionEvent(event) {
	$.MyPreventDefault(event);
	var self = $(this);
	if (self.hasClass('disabled')) return;
	var row = self.closest("tr[data-file]");
	if (row.length === 0) row = getSelectedRows(this).shift();
	if (self.hasClass("rename")) {
		handleFileRename(row);
	} else if (self.hasClass("delete")) {
		handleFileDelete(row);
	} else { // extension support:
		$("body").trigger("fileActionEvent",{ obj: self, event: event, file: row.attr('data-file'), selected: [ row.data("file") ] , row: row });
	}
}
function initFileActions() {
	$("#fileactions")
		.on("click dblclick", function(ev) {
			$.MyPreventDefault(ev);
			$(".fileactions-popup").toggle();
		}).MyKeyboardEventHandler().MyTooltip();
	$("#fileactions .action").addClass("focus").on("click dblclick", handleFileActionEvent).MyKeyboardEventHandler();
	$("#fileactions li.popup").MyPopup();
	$("#flt").on("fileListChanged", function(){
		// init single file actions:
		$("#fileList tr.unselectable-no")
			.off(".fileAction")
			.on("mouseenter.fileAction focusin.fileAction",handleFileListRowFocusIn)
			.on("mouseleave.fileAction", handleFileListRowFocusOut);
	}).on("beforeFileListChange replaceRow", handleFileListRowFocusOut);
	handleFileActionsSettings();
	$("body").on("settingchanged", handleFileActionsSettings);
}
function handleFileActionsSettings(ev,data) {
	$("#fileactions")
		.toggleClass("hidefileactions", $.MyCookie("settings.show.fileactions") == "no")
		.toggleClass("hidelabels", $.MyCookie("settings.show.fileactionlabels") == "no")
		.toggleClass("showalways", $.MyCookie("settings.show.fileactionalways") == "no");
}
function handleFileListRowFocusIn(event) {
	var self = $(this);
	if ($("#fileactions", self).length===0) {
		$(".action.changeuri.filename", self).after($("#fileactions"));
	}
	$("#fileList tr.focus").removeClass("focus");
	self.addClass("focus");
	updateFileListActions(event, { focus: true});
}
function handleFileListRowFocusOut(event) {
	$("#fileactions").appendTo($(".template"));
}
function initFancyBox() {
	$("#flt").on("fileListChanged", function() {
		$("#fileList tr.isviewable-yes[data-mime^='image/'][data-size!='0']:visible .action.changeuri")
			.off("click")
			.attr("data-fancybox-group","imggallery")
			.each(function(i,v){ var self = $(v); if (!self.attr("href")) self.data("fancybox-href", self.data("href"));    })
			.fancybox({
				padding: 0,
				afterShow: function() { $(".fancybox-close").focus();},
				beforeLoad: function() { this.title = $(this.element).html(); }, 
				helpers: { buttons: {}, thumbs: { width: 60, height: 60, source: function(current) { return (current.element).attr('data-href')+'?action=thumb'; } } } 
			});
		$("#fileList tr.isviewable-no[data-mime^='image/'][data-size!='0']:visible .action.changeuri")
			.off("click")
			.attr("data-fancybox-group","wtimggallery")
			.each(function(i,v){ var self = $(v); if (!self.attr("href")) self.data("fancybox-href", self.data("href"));    })
			.fancybox({
				padding: 0,
				afterShow: function() { $(".fancybox-close").focus();},
				beforeLoad: function() { this.title = $(".nametext", this.element).html(); },
				helpers: { buttons: {} }
		});
	});
}
function initFileList() {
	var flt = $("#fileListTable");
	var fl = $("#fileList");
	
	$("#fileList.selectable-false tr").removeClass("unselectable-no").addClass("unselectable-yes");
	
	$("#fileList tr.unselectable-yes .selectbutton").attr("disabled","disabled");
	
	// mouse events on a file row:
	$("#fileList tr")
		.off("click.initFileList").on("click.initFileList",handleRowClickEvent)
		.off("dblclick.initFileList").on("dblclick.initFileList",function(event) { 
			changeUri($.MyStringHelper.concatUri($("#fileList").attr('data-uri'), encodeURIComponent($.MyStringHelper.stripSlash($(this).attr('data-file')))),
					$(this).attr("data-type") == 'file');
		});
	
	// fix selections after tablesorter:
	$("#fileList tr.selected td .selectbutton:not(:checked)").prop("checked",true);

	// fix annyoing text selection for shift+click:
	$('#flt').disableSelection();
	
	// init drag & drop:
	$("#fileList:not(.dnd-false) tr.iswriteable-yes[data-type='dir']")
			.droppable({ scope: "fileList", tolerance: "pointer", drop: handleFileListDrop, hoverClass: 'draghover' });
	$("#fileList:not(.dnd-false) tr.isreadable-yes.unselectable-no div.filename")
			.multiDraggable({getGroup: getVisibleAndSelectedFiles, zIndex: 200, scope: "fileList", revert: true });
	
	// init tabbing:
	$("#fileListTable th").MyKeyboardEventHandler();

	// init column drag and dblclick resize:
	$("#fileListTable").MyTableManager();

	// fix annyoing text selection after a double click on text in the file
	// list:
	removeTextSelections();
	
	$("#fileList tr:focusable:visible:first").focus();
	
	$("#flt").trigger("fileListChanged");
}
function removeTextSelections() {
	if (document.selection && document.selection.empty) document.selection.empty();
	else if (window.getSelection) {
		var sel = window.getSelection();
		if (sel && sel.removeAllRanges) sel.removeAllRanges();
	}
}
function handleFileDelete(row) {
	row.fadeTo('slow',0.5);
	confirmDialog($('#deletefileconfirm').html().replace(/%s/,$.MyStringHelper.quoteWhiteSpaces($.MyStringHelper.simpleEscape(row.attr('data-displayname')))),{
		confirm: function() {
			var file = row.attr('data-file');
			removeFileListRow(row);
			var xhr = $.MyPost($('#fileList').attr('data-uri'), { 'delete': 'yes', file: file }, function(response) {
				if (response.error) updateFileList();
				handleJSONResponse(response);
			});
			renderAbortDialog(xhr);
		},
		cancel: function() {
			row.fadeTo('fast',1);
		}
	});
}
function handleJSONResponse(response) {
	if (response.error)  notifyError(response.error);
	if (response.warn) notifyWarn(response.warn);
	if (response.message) notifyInfo(response.message);
	if (response.quicknav) {
		$("#quicknav").html(response.quicknav).MyTooltip();
		$("#quicknav a").click(function(event) {
			$.MyPreventDefault(event);
			changeUri($(this).attr("href"));
		});
	}
}
function doRename(row, file, newname) {
	var xhr = $.MyPost($('#fileList').attr('data-uri'), { rename: 'yes', newname: newname, file: file  }, function(response) {
		if (response.message) {
			$.MyPost($('#fileList').attr('data-uri'), { ajax:'getFileListEntry', file: newname, template: $("#fileList").attr("data-entrytemplate")}, function(r) {
				try {
					var newrow = $(r);
					var d = $("tr[data-file='"+newname+"']");
					if (d.length>0) d.remove();
					$("#flt").trigger("replaceRow",{ row: row,newrow:newrow });
					row.replaceWith(newrow);
					row = newrow;
					initFileList();
					newrow.focus();
				} catch (e) {
					updateFileList();
				}
			}, true);
		}
		handleJSONResponse(response);
	});
	renderAbortDialog(xhr);
}
function handleFileRename(row) {
	var file = row.closest("tr[data-file]").data("file");
	var defaultValue  = file.replace(/\/$/,"");
	$.MyInplaceEditor({	
		editorTarget: row.find("td.filename"),
		defaultValue: defaultValue,
		beforeEvent: function() { $("#flt").enableSelection(); },
		finalEvent: function() { $("#flt").disableSelection(); },
		changeEvent: function(data) {
			var newname = data.value.replace(/\//g,"");
			if (newname == defaultValue ) return;
			if ($.MyCookie("settings.confirm.rename")!="no") {
				confirmDialog($("#movefileconfirm").html().replace(/\\n/g,'<br/>').replace(/%s/,$.MyStringHelper.quoteWhiteSpaces(file)).replace(/%s/,$.MyStringHelper.quoteWhiteSpaces(newname)), {
					confirm: function() { doRename(row,file,newname); },
					setting: "settings.confirm.rename"
				});
			} else {
				doRename(row, file, newname);
			}
		}
	});
}
function notify(type,msg) {
	console.log("notify["+type+"]: "+msg);
	if ($.MyCookie("settings.messages."+type)=="no") return;
	noty({text: msg, type: type, layout: 'topCenter', timeout: 30000 });
	$("body").trigger("notify",{type:type,msg:msg});
// var notification = $("#notification");
// notification.removeClass().hide();
// notification.off('click').click(function() { $(this).hide().removeClass();
// }).addClass(type).html('<span>'+$.MyStringHelper.simpleEscape(msg)+'</span>').show();
	// .fadeOut(30000,function() { $(this).removeClass(type).html("");});
}
function notifyError(error) {
	notify('error',error);
}
function notifyInfo(info) {
	notify('message',info);
}
function notifyWarn(warn) {
	notify('warning',warn);
}
function toggleRowSelection(row,on) {
	if (!row) return;
	row.toggleClass("selected", on);
	row.find(".selectbutton").prop('checked', row.hasClass("selected"));
}
function isSelectableRow(row) {
	return row.attr("data-file") != '..' && !row.hasClass("unselectable-yes");
}
function handleRowClickEvent(event) {
	var flt = $('#fileListTable');
	if (isSelectableRow($(this))) {
		var start = this.rowIndex;
		var end = start;
		if ((event.shiftKey || event.metaKey || event.altKey) && flt.data('lastSelectedRowIndex')) {
			end = flt.data('lastSelectedRowIndex');
			if (end < start ) {
				var c = end;
				end = start;
				start = c;
			}
			for (var r = start + 1 ; r < end ; r++ ) {
				var row = $("#fileList tr:visible").filter(function(){ return this.rowIndex == r; });
				if (row.length === 0) continue;
				toggleRowSelection(row);
				row = row.next();
			}
		}
		toggleRowSelection($(this));
		flt.data('lastSelectedRowIndex', this.rowIndex);
		$("#flt").trigger("fileListSelChanged");
	}
}
function initDialogActions() {
	$('.dialog.action').click(handleDialogActionEvent);
}
function handleDialogActionEvent(event) {
	$.MyPreventDefault(event);
	if ($(this).hasClass("disabled")) return;
	var self = $(this);
	self.addClass("disabled");
	
	var action = $("#"+self.attr('data-action'));
	if (action.attr("title")) action.data("title", action.attr("title"));
	action.attr("title", action.data("title"));
	
	action.dialog({modal:true, width: 'auto', 
					open: function() { if (action.data("initHandler")) action.data("initHandler").init(); },
					close: function() { self.removeClass("disabled"); },
					dialogClass: self.attr("data-action")+"dialog",
					buttons : [ { text: $("#close").html(), click:  function() { $(this).dialog("close"); }}]}).show();
}
function initFileListActions() {
	updateFileListActions();
	$(".action.uibutton").button();
	$("#flt").on("fileListSelChanged", updateFileListActions).on("fileListViewChanged",updateFileListActions);
}
function updateFileListActions(event, data) {
	var s = getFolderStatistics(data && data.focus);
	
	var flt = $("#fileListTable");
	var f = data && data.focus ? ".focus" : ":not(.focus)";
	var exclude = f;
	exclude += flt.hasClass("iswriteable-no") ? ":not(.access-writeable)" : "";
	exclude += flt.hasClass("isreadable-no") ? ":not(.access-readable)" : "";
	exclude += flt.hasClass("unselectable-no") ? ":not(.access-selectable)" : "";
	
	
	
	toggleButton($(".access-writeable"+f), flt.hasClass("iswriteable-no"));
	toggleButton($(".access-readable"+f), flt.hasClass("isreadable-no"));
	toggleButton($(".access-selectable"+f), flt.hasClass("unselectable-yes"));
	
	toggleButton($(".sel-none"+exclude), s.sumselcounter!== 0);
	toggleButton($(".sel-one"+exclude), s.sumselcounter!=1);
	toggleButton($(".sel-multi"+exclude), s.sumselcounter===0);
	toggleButton($(".sel-noneorone"+exclude), s.sumselcounter>1);

	toggleButton($(".sel-none.sel-dir"+exclude), s.fileselcounter!== 0 );
	toggleButton($(".sel-one.sel-dir"+exclude), s.fileselcounter>0 || s.dirselcounter!=1);
	toggleButton($(".sel-multi.sel-dir"+exclude), s.fileselcounter>0 || s.dirselcounter===0);
	toggleButton($(".sel-noneorone.sel-dir"+exclude), s.fileselcounter>0 || s.dirselcounter>1);
	toggleButton($(".sel-noneormulti.sel-dir"+exclude), s.fileselcounter>0);

	toggleButton($(".sel-none.sel-file"+exclude),  s.fileselcounter!== 0);
	toggleButton($(".sel-one.sel-file"+exclude), s.dirselcounter>0 || s.fileselcounter!=1);
	toggleButton($(".sel-multi.sel-file"+exclude), s.dirselcounter>0 || s.fileselcounter===0);
	toggleButton($(".sel-noneorone.sel-file"+exclude), s.dirselcounter>0 || s.fileselcounter>1);
	toggleButton($(".sel-noneormulti.sel-file"+exclude), s.dirselcounter>0);
	
	toggleButton($(".sel-one-suffix"+exclude), true);
	toggleButton($(".sel-one-mime"+exclude), true);
	toggleButton($(".sel-one-filename"+exclude), true);
	if (s.sumselcounter === 1 && s.fileselcounter === 1) {
		if (s.selectedmimetypes != "") {
			$(".sel-one-mime"+exclude).each(function() {
				var self = $(this);
				toggleButton(self, self.data("mime") == undefined || s.selectedmimetypes.match(self.data("mime")) === null);
			});
		}
		if (s.selectedsuffixes != "") {
			$(".sel-one-suffix"+exclude).each(function() {
				var self = $(this);
				toggleButton(self, self.data("suffix") == undefined || s.selectedsuffixes.match(self.data("suffix")) === null);
			});
		}
		$(".sel-one-filename"+exclude).each(function() {
			var self = $(this);
			toggleButton(self, self.data("filename") == undefined || s.selectedfilenames.match(self.data("filename")) === null);
		});
	}
	
}
function initFolderStatistics() {
	$("#flt").on("fileListChanged", updateFolderStatistics).on("fileListViewChanged", updateFolderStatistics);
}
function resetFileListCounters(flt) {
	if (!flt) flt=$('#fileListTable');
	if (flt && flt.attr) 
		flt.attr('data-filecounter',0).attr('data-dircounter',0).attr('data-foldersize',0).attr('data-sumcounter',0)
			.attr('data-fileselcounter',0).attr('data-dirselcounter',0).attr('data-folderselsize',0).attr('data-sumselcounter',0);
}
function updateFileListCounters() {
	var flt = $("#fileListTable");
	// file list counters:
	resetFileListCounters(flt);

	var s = getFolderStatistics();

	flt.attr('data-dircounter', s.dircounter);
	flt.attr('data-filecounter', s.filecounter);
	flt.attr('data-foldersize', s.foldersize);
	flt.attr('data-sumcounter', s.sumcounter);
	
	$("#flt").trigger("counterUpdated");
}
function getFolderStatistics(focus) {
	var stats = [];
	var es = focus ? ".focus" : ".selected:visible";
	stats.focus = focus;
	
	stats.dircounter =  $("#fileList tr.is-subdir-yes:visible").length;
	stats.filecounter = $("#fileList tr.is-file:visible").length;
	stats.sumcounter = stats.dircounter+stats.filecounter;
	stats.dirselcounter = $("#fileList tr.is-subdir-yes"+es).length;
	stats.fileselcounter = $("#fileList tr.is-file"+es).length;
	stats.sumselcounter = stats.dirselcounter+stats.fileselcounter;

	var selfiles = $("#fileList tr.is-file"+es);
	stats.selectedmimetypes = selfiles.map(function() { return $(this).data("mime");  }).get().sort().join(",").replace(/([^,]+)(,\1)*/g,"$1");
	stats.selectedsuffixes  = selfiles.map(function() { return $(this).data("file").toLocaleLowerCase().match(/\.\w+$/)!=null ? $(this).data("file").split(".").pop() : "";  }).get().sort().join(",").replace(/([^,]+)(,\1)*/g,"$1");
	stats.selectedfilenames = selfiles.map(function() { return $(this).data("file").toLocaleLowerCase(); }).get().sort().join("/");
	
	var foldersize = 0;
	var folderselsize = 0;
	$("#fileList tr:visible").each(function(i,val) {  
		var size = parseInt($(this).attr('data-size'));
		if ($(this).is(es)) folderselsize +=size;
		foldersize += size;
	});

	stats.foldersize=foldersize;
	stats.folderselsize=folderselsize;

	return stats;
}
function updateFolderStatistics() {
	var hn = $('#headerName');
	var flt = $('#fileListTable');
	var hs = $('#headerSize');

	updateFileListCounters();

	if (hn.length>0 && !hn.attr('data-title')) hn.attr('data-title',hn.attr('title'));
	if (hs.length>0 && !hs.attr('data-title')) hs.attr('data-title',hs.attr('title'));
	if (hn.length>0) 
		hn.attr('title', 
			hn.attr('data-title')
				.replace(/\$filecount/, flt.attr('data-filecounter'))
				.replace(/\$dircount/,flt.attr('data-dircounter'))
				.replace(/\$sum/,parseInt(flt.attr('data-dircounter'))+parseInt(flt.attr('data-filecounter')))
		);
	var fs = parseInt(flt.attr('data-foldersize'));
	if (hs.length > 0) hs.attr('title', hs.attr('data-title').replace(/\$foldersize/, $.MyStringHelper.renderByteSizes(fs)));
}
function initNav() {
	$(window).off("popstate.changeuri").on("popstate.changeuri", function() {
		var loc = history.location || document.location;
		updateFileList(loc.pathname);
	});	
}
function changeUri(uri, leaveUnblocked) {
	// try browser history manipulations:
	try {
		if (!leaveUnblocked) {
			if (window.history.pushState) {
				window.history.pushState({path: uri},"",uri);
				updateFileList(uri);
			} else {
				updateFileList(uri);
			}
			return;
		}
	} catch (e) {
		console.log(e);
	}
	// fallback for errors and unblocked links:
	if (!leaveUnblocked) $.MyPageBlocker();
	window.location.href=uri;
	
}
function updateFileList(newtarget, data) {
	if (!newtarget) newtarget = $('#fileList').attr('data-uri');
	if (!newtarget) newtarget = window.location.href;
	if (!data) {
		data={ajax: "getFileListTable", template: $('#flt').attr('data-template')};
	}
	$(".ajax-loader").show();
	$("#flt").hide();
	var timestamp = $.now();
	$("#flt").data("timestamp", timestamp);
	$.MyPost(newtarget, data, function(response) {
		if ($("#flt").data("timestamp") != timestamp) return; 
		$("#flt")
			.trigger("beforeFileListChange")
			.show()
			.html(response.content)
			.attr("data-uri",newtarget);
		$(".ajax-loader").hide();
		$("title").html($("#titleprefix").html()+" "+newtarget.replace(/\/[^\/]+\/\.\.$/,"/"));
		initFileList();
		handleJSONResponse(response);
	}, true);
}
function removeFileListRow(row) {
	$("#flt").trigger("beforeFileListChange");
	row.remove();
	$("#flt").trigger("fileListChanged");
}
function doFileListDrop(srcinfo,dsturi) {
	var xhr = $.MyPost(dsturi, { srcuri: srcinfo.srcuri, action: srcinfo.action, files: srcinfo.files.join('@/@') }, function (response) {
		if (response.message && srcinfo.action=='cut') { 
			removeFileListRow($("#fileList tr[data-file='"+srcinfo.files.join("'],#fileList tr[data-file='")+"']"));
		}
		if (response.error) updateFileList();
		handleJSONResponse(response);
	});
	renderAbortDialog(xhr);
}
function doFileListDropWithConfirm(srcinfo, dsturi) {
	var msg = $("#paste"+srcinfo.action+"confirm").html();
	msg = msg.replace(/%files%/g, $.MyStringHelper.quoteWhiteSpaces($.MyStringHelper.uri2html(srcinfo.files.join(', '))))
			.replace(/%srcuri%/g, $.MyStringHelper.quoteWhiteSpaces($.MyStringHelper.uri2html(srcinfo.srcuri)))
			.replace(/%dsturi%/g, $.MyStringHelper.quoteWhiteSpaces($.MyStringHelper.uri2html(dsturi)))
			.replace(/\\n/g,"<br/>");
	if ($.MyCookie("settings.confirm.dnd")!="no") {
		confirmDialog(msg, { confirm: function() { doFileListDrop(srcinfo, dsturi); }, setting: "settings.confirm.dnd" });
	} else {
		doFileListDrop(srcinfo,dsturi);
	}
}
function getFileListDropSrcInfo(event,ui) {
	var dragfilerow = ui.draggable.closest('tr');
	var srcuri = $.MyStringHelper.concatUri($("#fileList").attr("data-uri"),'/');
	var dragfilerow = ui.draggable.closest('tr');
	return {
		action: event.shiftKey || event.altKey || event.ctrlKey || event.metaKey ? "copy" : "cut",
		srcuri: srcuri,
		files: dragfilerow.hasClass('selected') ?  
				$.map($("#fileList tr.selected:visible"), function(val, i) { return $(val).attr("data-file"); }) 
				: [ dragfilerow.attr('data-file') ]
	};
}
function handleFileListDrop(event, ui) {
	var dragfilerow = ui.draggable.closest('tr');
	var dsturi = $.MyStringHelper.concatUri($("#fileList").attr('data-uri'), encodeURIComponent($.MyStringHelper.stripSlash($(this).attr('data-file')))+"/");
	var srcinfo = getFileListDropSrcInfo(event, ui);
	if (dsturi == $.MyStringHelper.concatUri(srcinfo.srcuri,encodeURIComponent($.MyStringHelper.stripSlash(dragfilerow.attr('data-file'))))+"/") return;
	return doFileListDropWithConfirm(srcinfo,dsturi);
}
function renderHiddenInput(form, data, key) {
	for (var k in data) {
		var v = data[k];
		if (typeof v === "object") renderHiddenInput(form, v, k);
		else if (key) form.append($("<input/>").prop("name",key).prop("value",v).prop("type","hidden"));
		else form.append($("<input/>").prop("name", k).prop("value",v).prop("type","hidden"));
	}
	return form;
}
function postAction(data) {
	var form = $("<form/>").appendTo("body");
	form.hide().prop("action",$("#fileList").attr("data-uri")).prop("method","POST");
	form.append($("#token").clone().removeAttr("id"));
	renderHiddenInput(form,data);
	form.submit();
	form.remove();
}
function handleFileListActionEventDelete(event) {
	var self = $(this);
	var selrows = getSelectedRows(this);
	selrows.fadeTo("slow", 0.5);
	confirmDialog(selrows.length > 1 ? $('#deletefilesconfirm').html() : $('#deletefileconfirm').html().replace(/%s/,$.MyStringHelper.quoteWhiteSpaces($.MyStringHelper.simpleEscape(selrows.first().attr('data-file')))), {
		confirm: function() {
			if (selrows.length === 0) selrows = self.closest("tr");
			var xhr = $.MyPost($("#fileList").attr("data-uri"), { "delete" : "yes", "file" : $.map(selrows, function(v,i) { return $(v).attr("data-file"); })}, function(response) {
				removeFileListRow(selrows);
				uncheckSelectedRows();
				if (response.error) updateFileList();
				handleJSONResponse(response);
			});
			renderAbortDialog(xhr);
		},
		cancel: function() {
			selrows.fadeTo("fast",1);
			$("#fileList tr.selected:not(:visible) .selectbutton").prop('checked',true);
		}
	});	
}
function uncheckSelectedRows() {
	$("#fileList tr.selected:visible .selectbutton").prop('checked',false);
	$("#fileList tr.selected:visible").removeClass("selected");
	$("#fileList tr:visible").first().focus();
	$("#flt").trigger("fileListSelChanged");
}
function doPasteAction(action,srcuri,dsturi,files) {
	var xhr = $.MyPost(dsturi, { action: action, files: files, srcuri: srcuri }, function(response) {
		if ($.MyCookie("clpaction") == "cut") $.MyCookie.rmCookies("clpfiles","clpaction","clpuri");
		if (files.split("@/@").length == 1) {
			refreshFileListEntry(files);
		} else {
			updateFileList();
		}
		handleJSONResponse(response);
	});
	renderAbortDialog(xhr);
}
function handleFileListActionEvent(event) {
	$.MyPreventDefault(event);
	var self = $(this);
	if (self.hasClass("disabled")) return;
	if (self.hasClass("delete")) {
		handleFileListActionEventDelete.call(this,event);
	} else if (self.hasClass("rename")) {
		handleFileRename(self.closest("tr"));
	} else if (self.hasClass("cut")||self.hasClass("copy")) {
		$("#fileList tr").removeClass("cutted").fadeTo("fast",1);
		var selfiles = $.map(getSelectedRows(self), function(val,i) { return $(val).attr("data-file"); });
		$.MyCookie('clpfiles', selfiles.join('@/@'));
		$.MyCookie('clpaction',self.hasClass("cut")?"cut":"copy");
		$.MyCookie('clpuri',$.MyStringHelper.concatUri($("#fileList").attr('data-uri'),"/"));
		if (self.hasClass("cut")) $("#fileList tr.selected").addClass("cutted").fadeTo("slow",0.5);
		handleClipboard();
		uncheckSelectedRows();
	} else if (self.hasClass("paste")) {
		var files = $.MyCookie("clpfiles");
		var action= $.MyCookie("clpaction");
		var srcuri= $.MyCookie("clpuri");
		var dsturi = $.MyStringHelper.concatUri($("#fileList").attr("data-uri"),"/");
		
		if ($.MyCookie("settings.confirm.paste") != "no") {
			var msg = $("#paste"+action+"confirm").html()
					.replace(/%srcuri%/g, $.MyStringHelper.uri2html(srcuri))
					.replace(/%dsturi%/g, $.MyStringHelper.uri2html(dsturi)).replace(/\\n/g,"<br/>")
					.replace(/%files%/g, $.MyStringHelper.uri2html(files.split("@/@").join(", ")));
			confirmDialog(msg, { confirm: function() { doPasteAction(action,srcuri,dsturi,files); }, setting: "settings.confirm.paste" });
		} else doPasteAction(action,srcuri,dsturi,files);
	} else if (self.attr("href") !== undefined && self.attr("href") != "#") {
		window.open(self.attr("href"), self.attr("target") || "_self");
	} else {
		var row = getSelectedRows(self);
		$("body").trigger("fileActionEvent",{ obj: self, event: event, file: row.attr('data-file'), row: row, selected: getSelectedFiles(this) });
	}
}
function initClipboard() {
	handleClipboard();
	$('#flt').on('fileListChanged', handleClipboard);
}
function handleClipboard() {
	var action = $.MyCookie("clpaction");
	var datauri = $.MyStringHelper.concatUri($("#fileList").attr("data-uri"),"/");
	var srcuri = $.MyCookie("clpuri");
	var files = $.MyCookie("clpfiles");
	var disabled = (!files || files === "" || srcuri == datauri || $("#fileListTable").hasClass("iswriteable-no"));
	toggleButton($(".action.paste"), disabled);
	if (srcuri == datauri && action == "cut") 
		$.each(files.split("@/@"), function(i,val) { 
			$("[data-file='"+val+"']").addClass("cutted").fadeTo("fast",0.5);
		}) ;
}

function initNavigationActions() {
	$("#nav .action").click(handleFileListActionEvent).MyKeyboardEventHandler();
	$("#nav > ul > li.popup").addClass("popup-click");
	$("#nav li.popup").MyPopup();
	$("#flt").on("beforeFileListChange fileListSelChanged", function() { $("#nav li.popup").MyPopup("close"); });
}
function initToolbarActions() {
	$(".toolbar li.uibutton").button();
	$(".toolbar .action").click(handleFileListActionEvent).MyKeyboardEventHandler();
	$(".toolbar > li.popup").addClass("popup-click");
	$(".toolbar li.popup").MyPopup();
	$("#flt").on("beforeFileListChange fileListSelChanged", function() { $(".toolbar li.popup").MyPopup("close"); });
	
	var inplaceOptions = {
		actionInterceptor: function() {
			return $(this).hasClass("disabled");
		},
		beforeEvent: function() {
			$("#flt").enableSelection();
			$(this).closest("ul.popup:hidden").show();
		},
		cancelEvent: function() {
			$(this).next().focus();
		},
		finalEvent: function(success) {
			$("#flt").disableSelection();
			if (success) $(this).closest("ul").hide();
		}
	};
	
	$(".action.create-folder").MyInplaceEditor($.extend(inplaceOptions,  
		{ changeEvent: function(data) {
			var self = $(this);
			$.MyPost($('#fileList').attr('data-uri'), { mkcol : 'yes', colname : data.value }, function(response) {
				if (!response.error && response.message) refreshFileListEntry(data.value);
				handleJSONResponse(response);
			});
		}}));

	$(".action.create-file").MyInplaceEditor($.extend(inplaceOptions,
		{ changeEvent: function(data) {
			var self = $(this);
			$.MyPost($('#fileList').attr('data-uri'), { createnewfile : 'yes', cnfname : data.value }, function(response) {
				if (!response.error && response.message) refreshFileListEntry(data.value);
				handleJSONResponse(response);
			});
		}}));

	$(".action.create-symlink").MyInplaceEditor($.extend(inplaceOptions,
		{ changeEvent: function(data) {
			var row = getSelectedRows(this);
			$.MyPost($('#fileList').attr('data-uri'), { createsymlink: 'yes', lndst: data.value, file: row.attr('data-file') }, function(response) {
				if (!response.error && response.message) refreshFileListEntry(data.value);
				handleJSONResponse(response);
			});
		}}));
}
function initViewFilterDialog() {
	$(".action.viewfilter").click(function(event){
		$.MyPreventDefault(event);
		if ($(this).hasClass("disabled")) return;
		var self = $(this);
		$(".action.viewfilter").addClass("disabled");
		var target =$("#fileList").attr("data-uri");
		var template = self.attr("data-template");
		$.MyPost(target, {ajax: "getViewFilterDialog", template: template}, function(response){
			var vfd = $(response);
			$("input[name='filter.size.val']", vfd).spinner({min: 0, page: 10, numberFormat: "n", step: 1});
			$(".filter-apply", vfd).button().click(function(event){
				$.MyPreventDefault(event);
				$.MyCookie.toggleCookie("filter.name", 
						$("select[name='filter.name.op'] option:selected", vfd).val()+" "+$("input[name='filter.name.val']",vfd).val(),
						$("input[name='filter.name.val']", vfd).val() !== "");
				$.MyCookie.toggleCookie("filter.size",
						$("select[name='filter.size.op'] option:selected",vfd).val() + 
						$("input[name='filter.size.val']",vfd).val() + 
						$("select[name='filter.size.unit'] option:selected",vfd).val(),
						$("input[name='filter.size.val']", vfd).val() !== "");
				if ($("input[name='filter.types']:checked", vfd).length > 0) {
					var filtertypes = "";
					$("input[name='filter.types']:checked", vfd).each(function(i,val) {
						filtertypes += $(val).val();
					});
					$.MyCookie("filter.types", filtertypes);
				} else $.MyCookie.rmCookies("filter.types");
				vfd.dialog("close");
				updateFileList();
			});
			$(".filter-reset", vfd).button().click(function(event){
				$.MyPreventDefault(event);
				$.MyCookie.rmCookies("filter.name", "filter.size", "filter.types");
				vfd.dialog("close");
				updateFileList();
			});
			vfd.submit(function(){
				return false;
			});
			vfd.dialog({modal:true,width:"auto",height:"auto", dialogClass: "viewfilterdialog", title: self.attr("title") || self.data("title"), close: function(){$(".action.viewfilter").removeClass("disabled"); vfd.remove();}}).show();
		});
	});
}
function renderAbortDialog(xhr, timeout, handler) {
	$("#abortdialog").remove();
	var dialog = $("<div/>").html($("#abortdialogtemplate").html()).attr("id","abortdialog");
	$(".action.cancel",dialog).button().click(function(event){
		if (xhr.readyState !=4) xhr.abort();
		dialog.hide().remove();
		if (handler) handler.call(this);
	});
	$("body").data("abortdialogtimeout",window.setTimeout(function() {
		if (xhr.readyState > 2) return;
		dialog.appendTo($("body")).show();
		var interval = window.setInterval(function() {
			if (xhr.readyState == 4) {
				dialog.hide().remove();
				window.clearInterval(interval);
			}
		}, 200);
		$("body").data("abortdialoginterval",interval);
		
	}, timeout || 2500));
	return dialog;
}
function removeAbortDialog() {
	window.clearTimeout($("body").data("abortdialogtimeout"));
	window.clearInterval($("body").data("abortdialoginterval"));
	$("#abortdialog").hide().remove();
}
function renderAccessKeyDetails() {
	if ($("#accesskeydetails").length>0) {
		$("#accesskeydetails").dialog("destroy").remove();
		$("#fileList tr:focusable:first").focus();
		return;
	}
	var text = "";
	var refs = $("*[accesskey]").get().sort(function(a,b) {
		var aa = $(a).attr("accesskey");
		var bb = $(b).attr("accesskey");
		return aa < bb ? -1 : aa > bb ? 1 : 0; 
	});
	var dup = [];
	$.each(refs, function(i,v) {
		var qv = $(v);
		var ak = qv.attr("accesskey");
		if (!dup[ak]) {
			text += '<li tabindex="0" role="definition">'+ak+": "+( qv.attr("aria-label") || qv.attr("title") || qv.attr("data-tooltip") || qv.html() )+"</li>";
			dup[ak]=true;
		} else {
			console.log("found accesskey "+ak+" more than on time");
		}
	});
	$('<div id="accesskeydetails" tabindex="-1"/>')
		.html('<ul class="accesskeydetails">'+text+"</ul>")
		.dialog({title: $(this).attr("title"), width: "auto", height: "auto", dialogClass : "accesskeydialog",
				buttons : [ { text: $("#close").html(), click:  function() { $(this).dialog("destroy").remove(); }}],
				open: function() { $("#accesskeydetails li:focusable:first").focus(); } });
}
function hidePopupMenu() {
	$("#popupmenu li.popup").MyPopup("close");
	$("#tc_popupmenu li.popup").MyPopup("close");
}
function handleTableConfigActionEvent(event) {
	$.MyPreventDefault(event);
	var self = $(this);
	if (self.hasClass("disabled")) return;
	if (self.hasClass("table-sort")) {
		var lts = $.MyTableManager.getLastTableSort();
		$.MyTableManager.sortTable(self.closest("table"), self.data("name"), lts.name == self.data("name") ? -lts.sortorder : 1);
	} else if (self.hasClass("table-sort-this-asc")) {
		$.MyTableManager.sortTable(self.closest("table"), self.closest("th").data("name"), 1 );
	} else if (self.hasClass("table-sort-this-desc")) {
		$.MyTableManager.sortTable(self.closest("table"), self.closest("th").data("name"), -1 );
	} else if (self.hasClass("table-column-hide-this")) {
		$.MyTableManager.toggleTableColumn(self.closest("table"), self.closest("th:not(.table-column-not-hide)").data("name"), false);
	} else if (self.hasClass("table-column")) {
		$.MyTableManager.toggleTableColumn(self.closest("table"), self.data("name"));
	} else if (self.hasClass("table-column-width-default")) {
		$.MyTableManager.setTableColumnWidth(self.closest("th"), "default");
	} else if (self.hasClass("table-column-width-minimum")) {
		$.MyTableManager.setTableColumnWidth(self.closest("th"), "minimum");
	}
}
function initTableColumnPopupActions() {
	$("#tc_popupmenu .action")
	.off(".popupmenu")
	.on("click.popupmenu", handleTableConfigActionEvent)
	.on("dblclick.popupmenu", $.MyPreventDefault)
	.MyKeyboardEventHandler();
	
	$("#flt").on("fileListChanged", function() {
		
		$("#fileListTable th[data-name].sorter-false").each(function(i,v) {
			$(".action.table-sort."+$(v).data("name")).addClass("hidden").hide();
		});
		$(".action.table-sort.fileactions").hide();
		
	});
	setupContextActions();
	function setupContextActions() {
		var lts = $.MyTableManager.getLastTableSort();
		//$(".action.table-sort .symbol").html("&#8597;");
		//$(".action.table-sort."+lts.name+" .symbol").html( lts.sortorder == 1 ? "&#8600;" : "&#8599;");
		$(".action.table-sort .symbol").removeClass("descending ascending");
		$(".action.table-sort."+lts.name+" .symbol").addClass(lts.sortorder == 1 ? "descending" : "ascending");
		
		$(".action.table-column .symbol").removeClass("column-hidden");
		$(".action.table-column").addClass("hidden disabled");
		$("#fileListTable th[data-name]").each(function(i,v) {
			$(".action.table-column."+$(v).data("name")).removeClass("hidden").toggleClass("disabled", $(v).hasClass("table-column-not-hide"))
				.find(".symbol").toggleClass("column-hidden",$(v).is(":not(:visible)"))
		});
	}
	$("body").on("settingchanged", function(event,data) {
		if (data.setting == "order" || data.setting == "visibletablecolumns") setupContextActions();
	});
	
	// var visiblecolumns = $.map($("#fileListTable thead th[data-name]:not(.hidden)"), function(val,i) { return $(val).attr("data-name");});
}
function initPopupMenu() {
	$("#popupmenu .action")
		.off(".popupmenu")
		.on("click.popupmenu", handleFileListActionEvent)
		.on("dblclick.popupmenu", $.MyPreventDefault)
		.MyKeyboardEventHandler();

	initTableColumnPopupActions();
	$("#flt")
		.off(".popupmenu")
		.on("beforeFileListChange.popupmenu", function() {
			hidePopupMenu();
		})
		.on("fileListChanged.popupmenu", function(){
			$("#popupmenu li.popup").MyPopup({
				contextmenu: $("#popupmenu"), 
				contextmenuTarget: $("#fileList tr"), 
				contextmenuAnchor: "#content"
			});

			$("#tc_popupmenu li.popup").MyPopup({contextmenu: $("#tc_popupmenu"), contextmenuTarget: $("#fileListTable .fileListHead th"), contextmenuAnchor: "#content", contextmenuAnchorElement: true});
		});
	$("#filler").on("contextmenu", function(event) { if (event.which==3) { if (event.originalEvent.detail === 1 ) $.MyPreventDefault(event); hidePopupMenu(); } });
}
function refreshFileListEntry(filename) {
	var fl = $("#fileList");
	return $.MyPost($.MyStringHelper.addMissingSlash(fl.data("uri")), { ajax: "getFileListEntry", template: fl.data("entrytemplate"), file: filename}, function(r) {
		try {
			var newrow = $(r);
			row = $("tr[data-file='"+$.MyStringHelper.simpleEscape(filename)+"']", fl);
			if (row.length > 0) {
				$("#flt").trigger("replaceRow", {row:row,newrow:newrow });
				row.replaceWith(newrow);
			} else {
				newrow.appendTo(fl);
			}
			initFileList();
			newrow.focus();
		} catch (e) {
			updateFileList();
		}
	}, true);
}
function initDotFilter() {

	$("body").off("settingchanged.initDotFilter").on("settingchanged.initDotFilter",function(e,data) {
		if (data.setting == "settings.show.dotfiles") {
			$("body").toggleClass("hidedotfiles", !data.value);
			$("#flt").trigger("fileListViewChanged");
		} else if (data.setting == "settings.show.dotfolders") {
			$("body").toggleClass("hidedotfolders", !data.value);
			$("#flt").trigger("fileListViewChanged");
		}
	});
	$("body").toggleClass("hidedotfiles", $.MyCookie("settings.show.dotfiles") == "no");
	$("body").toggleClass("hidedotfolders", $.MyCookie("settings.show.dotfolders") == "no");
}
function updateThumbnails() {
	var enabled = $.MyCookie("settings.enable.thumbnails") != "no";
	$("#flt .icon").each(function(i,v) {
		var self = $(this);
		if (self.data("thumb")!=self.data("icon")) {
			var thumb = self.data("thumb");
			var icon = self.data("icon");
			var empty = $("#emptyimage").attr("src");
			self.attr("src", enabled ? ( thumb === "" ? empty : thumb ) : ( icon === "" ? empty : icon));
			self.toggleClass("thumbnail", enabled);
		}
	});
	
}
function initThumbnailSwitch() {
	$("body").off("settingchanged.initThumbnailSwitch").on("settingchanged.initThumbnailSwitch", function(e,data) {
		if (data.setting == "settings.enable.thumbnails") {
			updateThumbnails();
		}
	});
	$("#flt").on("fileListChanged", function() {
		// fix broken thumbnails bug
		$("#flt img.icon.thumbnail").on("error", function(){ 
			var self=$(this);
			var icon = self.data("icon");
			self.removeClass("thumbnail").attr("src", icon !== "" ? icon : $("#emptyimage").attr("src"));
		});
	});
}
function getDialog(data, initfunc) {
	var xhr = $.MyGet(window.location.pathname, data, function(response) {
		handleJSONResponse(response);
		initfunc(response);
	});
	renderAbortDialog(xhr);
}
function getDialogByPost(data, initfunc) {
	var xhr = $.MyPost(window.location.pathname, data, function(response) {
		handleJSONResponse(response);
		initfunc(response);
	});
	renderAbortDialog(xhr);
}
function initToolBox() {
	ToolBox = { 
			addMissingSlash: $.MyStringHelper.addMissingSlash,
			blockPage: $.MyPageBlocker,
			changeUri: changeUri,
			concatUri: $.MyStringHelper.concatUri,
			confirmDialog : confirmDialog,
			cookie : $.MyCookie,
			getDialog : getDialog,
			getDialogByPost: getDialogByPost,
			getSelectedFiles : getSelectedFiles,
			getSelectedRows : getSelectedRows,
			handleJSONResponse : handleJSONResponse,
			handleWindowResize : handleWindowResize,
			hidePopupMenu : hidePopupMenu,
			initFileList: initFileList,
			initPopupMenu : initPopupMenu,
			initTabs : initTabs,
			initUpload : initUpload,
			notify : notify,
			notifyError : notifyError,
			notifyInfo : notifyInfo,
			notifyWarn : notifyWarn,
			preventDefault : $.MyPreventDefault,
			preventDefaultImmediatly : $.MyPreventDefaultImmediatly,
			postAction: postAction,
			quoteWhiteSpaces: $.MyStringHelper.quoteWhiteSpaces,
			refreshFileListEntry : refreshFileListEntry,
			removeAbortDialog: removeAbortDialog,
			renderAbortDialog: renderAbortDialog,
			renderByteSize: $.MyStringHelper.renderByteSize,
			renderByteSizes: $.MyStringHelper.renderByteSizes,
			rmcookies: $.MyCookie.rmCookies,
			simpleEscape: $.MyStringHelper.simpleEscape,
			stripSlash : $.MyStringHelper.stripSlash,
			togglecookie : $.MyCookie.toggleCookie,
			toggleRowSelection : toggleRowSelection,
			uncheckSelectedRows : uncheckSelectedRows,
			updateFileList : updateFileList
	};
}
function initGuide() {
	$.fn.MyTooltip.defaults.helphandler = handleGuide;
	$(".contexthelp").MyContextHelp();
	$(".action.guide").click(function() {
		handleGuide.call(this, $(this).data("help"));
	});
}
function handleGuide(help) {
	var w = $(window);
	$("<div/>").append(
			$("<iframe/>").attr({ name: "guide", src: help, width: "99%", height: "99%"}).text(help)
	).dialog({ width: w.width()/2, height: w.height()/2, title:$(".action.guide").data("title"), dialogClass: "guidedialog" });
}
// ready ends:
});