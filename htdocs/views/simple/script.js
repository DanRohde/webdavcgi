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
var ToolBox = new Object();
$(document).ready(function() {
	initPlugins();
	
	initUIEffects();
	
	initPopupMenu();
	
	initBookmarks();
	
	initFileListActions();

	initClipboard();

	initFolderStatistics();

	initNewActions();

	initChangeDir();

	initFilterBox();

	initFileUpload();

	initSelectionStatistics();

	initDialogActions()

	initViewFilterDialog();

	initClock();
	
	initSelect();
	
	initChangeUriAction();

	initWindowResize();
	
	initSettingsDialog();
	
	initAutoRefresh();
	
	initCollapsible();
	
	initTableConfigDialog();
	
	initKeyboardSupport();
	
	initToolBox();
	
	initDotFilter();
	
	initThumbnailSwitch();
	
	initTooltips();
	
	initNav();
	
	initStatusbar();
	
	$.ajaxSetup({ traditional: true });
	
	$(document).ajaxError(function(event, jqxhr, settings, exception) { 
		console.log(event);
		console.log(jqxhr); 
		console.log(settings);
		console.log(exception);
		if (jqxhr && jqxhr.statusText && jqxhr.statusText != 'abort') notifyError(jqxhr.statusText);
		$("div.overlay").remove();
		//if (jqxhr.status = 404) window.history.back();
	});
	// allow script caching:
	$.ajaxPrefilter('script',function( options, originalOptions, jqXHR ) { options.cache = true; });
	
	updateFileList($("#flt").attr("data-uri"));
	
function initStatusbar() {
	if (!cookie("settings.show.statusbar")) {
		cookie("settings.show.statusbar","no");
		cookie("settings.show.statusbar.keep","yes");
	}
	$("#statusbar").toggleClass("enabled", cookie("settings.show.statusbar") == "yes");
	$("#statusbar .unselectable").off("change").on("change", function(e) {$(this).prop("checked",true); preventDefault(e); });
	function renderStatusbarTemplate(){ 
		var flt = $("#fileListTable");
		var sb = $("#statusbar");
		$(".filecount",sb).html(flt.attr("data-filecounter"));
		$(".dircount",sb).html(flt.attr("data-dircounter"));
		$(".sum",sb).html(flt.attr("data-sumcounter"));
		$(".foldersize",sb).attr("title",renderByteSizes(flt.data("foldersize"))).html(renderByteSize(flt.data("foldersize")));
		$(".selfilecount",sb).html(flt.attr("data-fileselcounter"));
		$(".seldircount",sb).html(flt.attr("data-dirselcounter"));
		$(".selsum",sb).html(flt.attr("data-sumselcounter"));
		$(".selfoldersize",sb).attr("title", renderByteSizes(flt.attr("data-folderselsize"))).html(renderByteSize(flt.attr("data-folderselsize")));
		$(".selected-files-stats",sb).toggle(flt.attr("data-fileselcounter") != 0 || flt.attr("data-dirselcounter") != 0);
	}
	renderStatusbarTemplate();
	$("#flt").on("counterUpdated", renderStatusbarTemplate).on("fileListChanged", renderStatusbarTemplate).on("selectionCounterUpdated", renderStatusbarTemplate);
	$("body").on("notify",function(ev,data) {
		$("#statusbar .notify").attr("title",simpleEscape(data.msg)).removeClass("error message warning").addClass(data.type).html(simpleEscape(data.msg)).MyTooltip();
	});
	$("body").on("settingchanged",function(ev,data) {
		if (data.setting == "settings.show.statusbar") {
			$("#statusbar").toggleClass("enabled", data.value);
		}
	});
	$("#statusbar").MyTooltip(500);
	
}
function initTooltips() {
	$("#flt").on("fileListChanged", function() {
		$("#flt,#bookmarks,#filelistactions").MyTooltip(500);
	}).on("bookmarksChanged",function() {
		$("#bookmarks").MyTooltip(500);
	});
	$("#nav,#controls,#autorefreshtimer,#popupmenu").MyTooltip(500);
}
function initKeyboardSupport() {
	$("#flt").on("fileListChanged", function() { 
		// keyboard events for filename links
		$("#fileList .filename a").off("keydown.flca").on("keydown.flca",function(event) {
			if (event.keyCode == 32) { preventDefault(event); handleRowClickEvent.call($(this).closest("tr"), event); }
		});
		fixTabIndex();
		$("#fileList tr").off("keydown.flctr").on("keydown.flctr",function(event) {
			var tabindex = this.tabIndex || 1;
			var self = $(this);
			// console.log(event.keyCode);
			if (self.is(":focus")) {
				if (event.keyCode ==32) handleRowClickEvent.call(this,event);
				else if (event.keyCode==13) 
					changeUri(concatUri($("#fileList").attr('data-uri'), encodeURIComponent(stripSlash(self.attr('data-file')))),self.attr("data-type") == 'file')
				else if (event.keyCode==46) {
					if ($("#fileList tr.selected:visible").length==0) { 
						if (isSelectableRow(self)) handleFileDelete(self);
					} else handleFileListActionEventDelete();
				} else if (event.keyCode==36) 
					$("#fileList tr:visible").first().focus();
				else if (event.keyCode==35) 
					$("#fileList tr:visible").last().focus();
				else if (event.keyCode==45) 
					$(".paste").trigger("click");
			}
			if (event.keyCode==38 && tabindex > 1 ) {
				preventDefault(event);
				if (isSelectableRow(self) && (event.shiftKey || event.altKey || event.ctrlKey || event.metaKey)) {
					toggleRowSelection(self, true);
					$("#flt").trigger("fileListSelChanged");
				}
				$("#fileList tr[tabindex='"+(tabindex-1)+"']").focus();
				removeTextSelections();
			} else if (event.keyCode==40) {
				preventDefault(event);
				if (isSelectableRow(self) && (event.shiftKey || event.altKey || event.ctrlKey || event.metaKey)) {
					toggleRowSelection(self, true);
					$("#flt").trigger("fileListSelChanged");
				}
				$("#fileList tr[tabindex='"+(tabindex+1)+"']").focus();
				removeTextSelections();
			} 
		});
		$("#fileList tr[tabindex='1']").focus();
	}).on("fileListViewChanged", fixTabIndex);
	
	$('<a accesskey="0" title="Access key details"></a>')
		.on("click", renderAccessKeyDetails)
		.appendTo("body");
	$('<a href="#" title="go to file list" accesskey="l" class="gotofilelist"></a>')
		.on("focusin", function(event) {
			$("#fileList tr:visible").first().focus();
		})
		.appendTo("body");
}
function fixTabIndex() {
	$("#fileList tr:visible").each(function(i,v) {
		$(v).attr("tabindex",i+1);
	});
}
function initTableConfigDialog() {
	$("#flt").on("fileListChanged", function() {
		$(".tableconfigbutton").click(function(event) {
			preventDefault(event);
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
				$.get($("#fileList").attr("data-uri"),{ ajax : 'getTableConfigDialog', template : $(this).attr("data-template")}, function(response) {
					if (response.error) handleJSONResponse(response);
					$("#flt").data("TableConfigDialog", response);
					setupTableConfigDialog($(response));
				});
			}
		});
	});
}
function setupTableConfigDialog(dialog) {
	// init dialog:
	var visiblecolumns = $.map($("#fileListTable thead th[data-name]:not(.hidden)"), function(val,i) { return $(val).attr("data-name");});
	$.each(visiblecolumns, function(i,val) {
		dialog.find("input[name='visiblecolumn'][value='"+val+"']").prop("checked",true);	
	});
	dialog.find("input[name='visiblecolumn'][value='name']").attr("readonly","readonly").prop("checked",true).click(function(e) { preventDefault(e);}).closest("li").addClass("disabled");
	$("#fileListTable thead th.sorter-false").each(function(i,val) {
		dialog.find("input[name='sortingcolumn'][value='"+$(val).attr("data-name")+"']").prop("disabled",true).click(function(e){preventDefault(e)}).closest("li").addClass("disabled");
	});
	
	var so = cookie("order") ? cookie("order").split("_") : "name_asc".split("_");
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
		// cookie("visibletablecolumns,vtc.join(","));
		// but preserves table column order:
		// remove unselected elements:
		var removedEls = new Array();
		for (var i=vc.length-1; i>=0; i--) {
			if ($.inArray(vc[i], vtc)==-1) {
				removedEls.push(vc[i]);
				vc.splice(i,1);
			}
		}
		// add missing selected elements:
		var addedEls = new Array();
		$.each(vtc, function(i,val) {
			if ($.inArray(val, vc)==-1) {
				addedEls.push(val);
				vc.push(val);
			}
		});
		cookie("visibletablecolumns", vc.join(","), 1);
		
		var c = dialog.find("input[name='sortingcolumn']:checked").attr("value");
		var o = dialog.find("input[name='sortingorder']:checked").attr("value");
		cookie("order", c + (o=="desc" ? "_desc" :""), 1);
						
		if (vtc.sort().join(",") != visiblecolumns.sort().join(",")) {
			$.each(addedEls, function(i,val) {
				var cidx = $("#fileListTable th[data-name='"+val+"']").removeClass("hidden").prop("cellIndex");
				$("#fileList tr").each(function(j,v) { $("td",$(v)).eq(cidx).show(); });
			});
			$.each(removedEls, function(i,val) {
				var cidx = $("#fileListTable th[data-name='"+val+"']").addClass("hidden").prop("cellIndex");
				$("#fileList tr").each(function(j,v) { $("td",$(v)).eq(cidx).hide(); });
			});
		} else if (c != column || o != order) {
			var ch = $("#fileListTable th[data-name='"+c+"']");
			var sortorder = o == 'desc' ? -1 : 1;
			setupFileListSort(ch.prop("cellIndex"), sortorder);
			if (ch.length>0) sortFileList(ch.attr("data-sorttype") || "string", ch.attr("data-sort"), sortorder, ch.prop("cellIndex"), "data-file");	
		}
						
		dialog.dialog("close");
	});
	dialog.find("input[name='cancel']").button().click(function(event) {
		preventDefault(event);
		dialog.dialog("close");
		return false;
	});
	
	dialog.find("#tableconfigform").submit(function(event) { return false; });
	
	dialog.dialog({ modal: true, width: "auto", title: dialog.attr("data-title") || dialog.attr("title"), dialogClass: "tableconfigdialog", height: "auto", close: function() { $(".tableconfigbutton").removeClass("disabled"); dialog.dialog("destroy");}});
	
}
function handleSidebarCollapsible(event) {
	if (event) preventDefault(event);
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
	
	if (!iconsonly&&!collapsed) rmcookies("sidebar");
	else cookie("sidebar", iconsonly?"iconsonly":collapsed?"false":"true");
	
	handleWindowResize();
}
function initCollapsible() {
	$(".action.collapse-sidebar").click(handleSidebarCollapsible).MyTooltip(500);
	if (cookie("sidebar") && cookie("sidebar") != "true") {
		$(".collapse-sidebar-listener").toggleClass("sidebar-collapsed", cookie("sidebar") == "false").toggleClass("sidebar-iconsonly", cookie("sidebar") == "iconsonly");
		$(".action.collapse-sidebar").toggleClass("collapsed", cookie("sidebar") == "false").toggleClass("iconsonly", cookie("sidebar") == "iconsonly");
		handleWindowResize();
	}
	
	$(".action.collapse-head").click(function(event) {
		preventDefault(event);
		$(".action.collapse-head").toggleClass("collapsed");
		var collapsed = $(this).hasClass("collapsed");
		$(".collapse-head-collapsible").toggle(!collapsed);
		$(".collapse-head-listener").toggleClass("head-collapsed", collapsed);
		togglecookie("head","false",collapsed, 1);
		handleWindowResize();
	}).MyTooltip(500);
	if (cookie("head") == "false") $(".action.collapse-head").first().trigger("click");
}

function initAutoRefresh() {
	$(".action.autorefreshmenu").button().click(function(event) {
		preventDefault(event);
		$("#autorefresh ul").toggle();
	}).dblclick(function(event) {
		preventDefault(event);
		updateFileList();
	});
	$("body").click(function(){ $("#autorefresh ul:visible").hide()});
	$(".action.autorefreshrunning").addClass("disabled");
	$(".autorefreshtimer").addClass("disabled");
	$("#autorefresh").on("started", function() {
		$(".autorefreshtimer").removeClass("disabled");
		$(".action.autorefreshrunning").removeClass("disabled");
		$("#autorefreshtimer").show();
		$(".action.autorefreshtoggle").addClass("running");
	}).on("stopped", function() {
		$(".autorefreshtimer").addClass("disabled");
		$(".action.autorefreshrunning").addClass("disabled");
		$("#autorefreshtimer").hide();
		$(".action.autorefreshtoggle").removeClass("running");
	});
	
	$("#flt").on("fileListChanged", function() {
		if (cookie("autorefresh") != "" && parseInt(cookie("autorefresh"))>0) startAutoRefreshTimer(parseInt(cookie("autorefresh")));
	});
	$(".action.setautorefresh").click(function(event){
		preventDefault(event);
		$("#autorefresh ul").addClass("hidden");
		if ($(this).attr("data-value") == "now") {
			updateFileList();
			return;
		}
		cookie("autorefresh", $(this).attr("data-value"));
		startAutoRefreshTimer(parseInt($(this).attr("data-value")));
	});
	$(".action.autorefreshclear").click(function(event) {
		preventDefault(event);
		if ($(this).hasClass("disabled")) return;
		window.clearInterval($("#autorefresh").data("timer"));
		rmcookies("autorefresh");
		$("#autorefresh").trigger("stopped");
		$("#autorefresh ul").addClass("hidden");
	});
	$(".action.autorefreshtoggle").click(function(event) {
		preventDefault(event);
		if ($(this).hasClass("disabled")) return;
		var af = $("#autorefresh");
		if (af.data("timer")!=null) {
			window.clearInterval(af.data("timer"));
			af.data("timer",null);
			$(".action.autorefreshtoggle").removeClass("running");
		} else {
			startAutoRefreshTimer(af.data("timeout"));
			$(".action.autorefreshtoggle").addClass("running");
		}
		$("#autorefresh ul").addClass("hidden");
	});
	
	$("#autorefreshtimer").draggable({ stop: function(e,ui) { cookie("autorefreshtimerpos", JSON.stringify(fixElementPosition("#autorefreshtimer",ui.offset))); }});	
	if (cookie("autorefreshtimerpos")) fixElementPosition("#autorefreshtimer",$.parseJSON(cookie("autorefreshtimerpos")));
}
function fixElementPosition(id, position) {
	var e = $(id);
	var w = $(window);
	var newposition = { 
			left: Math.min(Math.max(position.left, 0), w.width() - e.outerWidth() + w.scrollLeft() ), 
			 top: Math.min(Math.max(position.top, 0), w.height() - e.outerHeight() + w.scrollTop() ) };
	e.offset(newposition);
	return newposition;
}
function renderAutoRefreshTimer(aftimeout) {
	var t = $(".autorefreshtimer");
	var f = t.attr("data-template") || "%sm %ss";
	var minutes = Math.floor(aftimeout / 60);
	var seconds = aftimeout % 60;
	if (seconds < 10) seconds='0'+seconds;
	t.html(f.replace("%s", minutes).replace("%s", seconds));
}
function startAutoRefreshTimer(timeout) {
	var af = $("#autorefresh");
	if (af.data("timer")!=null) window.clearInterval(af.data("timer"));
	af.data("timeout", timeout);
	renderAutoRefreshTimer(timeout);
	af.data("timer", window.setInterval(function() {
		var aftimeout = af.data("timeout") -1;
		renderAutoRefreshTimer(aftimeout);
		af.data("timeout", aftimeout);
		if (aftimeout < 0) {
			window.clearInterval(af.data("timer"));
			af.data("timer",null);
			renderAutoRefreshTimer(0);
			af.trigger("stopped");
			updateFileList();
		}
	}, 1000));
	af.trigger("started");
}
function initSettingsDialog() {
	var settings = $("#settings");
	settings.data("initHandler", { init: function() {
		$("input[type=checkbox][name^='settings.']", settings).each(function(i,v) {
			$(v).prop("checked", cookie($(v).prop("name")) != "no").click(function(event) {
				if (cookie($(this).prop("name")+".keep")) 
					cookie($(this).prop("name"),$(this).is(":checked")?'yes':'no',1);
				else 
					togglecookie($(this).prop("name"),"no",!$(this).is(":checked"), 1);
				$("body").trigger("settingchanged", { setting: $(this).prop("name"), value: $(this).is(":checked") });
			});
		});
		$("select[name^='settings.']", settings)
			.change(function(){
				cookie($(this).prop("name").replace(/^settings./,""),$("option:selected",$(this)).val(),1);
				window.location.href = window.location.pathname; // reload bug fixed (if query view=...)
			})
			.each(function(i,v) {
				$("option[value='"+cookie($(v).prop("name").replace(/^settings\./,""))+"']",$(v)).prop("selected",true);	
			});
	}});
}
function initUIEffects() {
	$(".accordion").accordion({ collapsible: true, active: false });
	
	$("#flt").on("fileListChanged", function() {
		$(".dropdown-hover").off("hover").hover(
			function() {
				$(".dropdown-menu",$(this)).show();
			},
			function() {
				$(".dropdown-menu",$(this)).hide();
			}
		)
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
	$(".action.changeuri").on("click.changeuri",handleChangeUriAction);
	$(".action.refresh").on("click.refresh",function(event) {
		preventDefault(event);
		updateFileList();
		return false;
	});
	$("#flt").on("fileListChanged", function() {
		$("#fileList tr.is-dir .action.changeuri").click(handleChangeUriAction);
	});
}
function handleChangeUriAction(event) {
	preventDefault(event);
	if (!$(this).closest("div.filename").is(".ui-draggable-dragging")) {
		changeUri($(this).attr("href"));
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
		});	
		$(".selectnone").off("click.select").on("click.select",function(event) {
			$("#fileList tr.selected:not(:hidden)").removeClass("selected");
			$("#fileList tr:not(:hidden) .selectbutton:checked").prop("checked", false);
			$("#flt").trigger("fileListSelChanged");
		});
		$(".selectall").off("click.select").on("click.select",function(event) {
			$("#fileList tr:not(.selected):not(:hidden).unselectable-no").addClass("selected");
			$("#fileList tr:not(:hidden).unselectable-no .selectbutton:not(:checked)").prop("checked", true);
			$("#flt").trigger("fileListSelChanged");
		});
	});
}
function initClock() {
	var clock = $("#clock");
	if (clock.length==0) return;
	var fmt = clock.attr("data-format");
    if (!fmt) fmt="%I:%M:%S";
    window.setInterval(function() {
    	function addzero(v) { return v<10 ? "0"+v : v; }
        var d = new Date();
        var s = fmt;
        // %H = 00-23; %I = 01-12; %k = 0-23; %l = 1-12
        // %M = 00-59; %S = 0-60
        s = s.replace(/\%(H|k)/, addzero(d.getHours()))
             .replace(/\%(I|l)/, addzero(d.getHours() % 12 == 0 ? 12 : d.getHours() % 12) )
             .replace(/\%M/, addzero(d.getMinutes()))
             .replace(/\%S/, addzero(d.getSeconds()));
        clock.html(s);	
    }, fmt.match(/%S/) ? 1000 : 60000);
}
function initBookmarks() {
	var bookmarks = $("#bookmarks");
	$(".action.addbookmark", bookmarks).button();
	$("#flt").on("bookmarksChanged", buildBookmarkList)
	.on("bookmarksChanged",toggleBookmarkButtons)
	.on("fileListChanged", function() {
		buildBookmarkList();
		toggleBookmarkButtons();	
	});
	
	// register bookmark actions:
	$(".action.addbookmark,.action.rmbookmark,.action.rmallbookmarks,.action.bookmarksortpath,.action.bookmarksorttime,.action.gotobookmark",bookmarks)
		.click(handleBookmarkActions);
	// enable bookmark menu button:
	$(".action.bookmarkmenu", bookmarks).click(
		function(event) {
			preventDefault(event);
			$("#bookmarksmenu ul").toggle();
		}
	).button();
	$("body").click(function() { $("#bookmarksmenu ul:visible").hide();});
	

}
function toggleButton(button, disabled) {
	$.each(button, function(i,v) { 
		var self = $(v);
		if (self.hasClass("hideit")) self.toggle(!disabled);
		if (self.hasClass("button")) self.button("option","disabled",disabled);
		if (!self.hasClass("notab")) self.attr("tabindex",disabled ? -1 : 0);
		self.toggleClass("disabled", disabled);
	});
}
function toggleBookmarkButtons() {
	var currentPath = concatUri($("#flt").attr("data-uri"),"/");	
	var isCurrentPathBookmarked = false;
	var count = 0;
	var i = 0;
	while (cookie("bookmark"+i)!=null) {
		if (cookie("bookmark"+i) == currentPath) isCurrentPathBookmarked=true;
		if (cookie("bookmark"+i) != "-") count++;
		i++;
	}
	toggleButton($(".action.addbookmark"), isCurrentPathBookmarked);
	toggleButton($(".action.rmbookmark"), !isCurrentPathBookmarked);
	toggleButton($(".action.bookmarksortpath"), count<2);
	toggleButton($(".action.bookmarksorttime"), count<2);
	toggleButton($(".action.rmallbookmarks"), count==0);

	var sort= cookie("bookmarksort")==null ? "time-desc" : cookie("bookmarksort");
	$(".action.bookmarksortpath .path").hide();
	$(".action.bookmarksortpath .path-desc").hide();
	$(".action.bookmarksorttime .time").hide();
	$(".action.bookmarksorttime .time-desc").hide();
	if (sort == "path" || sort=="path-desc" || sort=="time" || sort=="time-desc") {
		$("#bookmarks .action.bookmarksort"+sort.replace(/-desc/,"")+" ."+sort).show();
	}
}
function buildBookmarkList() {
	var currentPath = concatUri($("#flt").attr("data-uri"),"/");
	// remove all bookmark list entries:
	$(".dyn-bookmark").each(function(i,val) {
		$(val).remove();
	});
	// read existing bookmarks:
	var bookmarks = new Array();
	var i=0;
	while (cookie("bookmark"+i)!=null) {
		if (cookie("bookmark"+i)!="-") bookmarks.push({ path : cookie("bookmark"+i), time: parseInt(cookie("bookmark"+i+"time"))});
		i++;
	}
	// sort bookmarks:
	var s = cookie("bookmarksort") ? cookie("bookmarksort") : "time-desc";
	var sortorder = 1;
	if (s.indexOf("-desc")>0) { sortorder = -1; s= s.replace(/-desc/,"") } ;
	bookmarks.sort(function(b1,b2) {
		if (s == "path") return sortorder * b1[s].localeCompare(b2[s]);
		else return sortorder * ( b2[s] - b1[s]);
	});
	// build bookmark list:
	var tmpl = $("#bookmarktemplate").html();
	$.each(bookmarks, function(i,val) {
		var epath = unescape(val["path"]);
		$("<li>" + tmpl.replace(/\$bookmarkpath/g,val["path"]).replace(/\$bookmarktext/,quoteWhiteSpaces(simpleEscape(trimString(epath,20)))) + "</li>")
			.insertAfter($("#bookmarktemplate"))
			.click(handleBookmarkActions)
			.addClass("link dyn-bookmark")
			.attr('data-action','gotobookmark')
			.attr('data-bookmark',val["path"])
			.attr("title",simpleEscape(epath)+" ("+(new Date(parseInt(val["time"])))+")")
			.toggleClass("disabled", val["path"] == currentPath)
			.find(".action.rmsinglebookmark").click(handleBookmarkActions);
	});
}
function removeBookmark(path) {
	var i = 0;
	while (cookie('bookmark'+i) != null && cookie('bookmark'+i)!=path) i++;
	if (cookie('bookmark'+i) == path) cookie('bookmark'+i, "-", 1);
	$('#flt').trigger("bookmarksChanged");
}
function handleBookmarkActions(event) {
	preventDefault(event);
	if ($(this).hasClass("disabled")) return;
	var action = $(this).attr('data-action');
	var uri = $("#fileList").attr('data-uri');
	if (action == 'addbookmark') {
		var i = 0;
	        while (cookie('bookmark'+i)!=null && cookie('bookmark'+i)!= "-" && cookie('bookmark'+i) != "" && cookie('bookmark'+i)!=uri) i++;
		cookie('bookmark'+i, uri, 1);
		cookie('bookmark'+i+'time', (new Date()).getTime(), 1);
		$("#flt").trigger("bookmarksChanged");
	} else if (action == 'gotobookmark') {
		changeUri($(this).attr('data-bookmark'));	
		$("#bookmarksmenu ul").toggleClass("hidden");
	} else if (action == 'rmbookmark') {
		removeBookmark(uri);
	} else if (action == 'rmallbookmarks') {
		var i = 0;
		while (cookie('bookmark'+i)!=null) {
			rmcookies('bookmark'+i, 'bookmark'+i+'time');
			i++;
		}
		$('#flt').trigger("bookmarksChanged");
	} else if (action == 'rmsinglebookmark') {
		removeBookmark($(this).attr("data-bookmark"));
	} else if (action == 'bookmarksortpath') {
		cookie("bookmarksort", cookie("bookmarksort")=="path" || cookie("bookmarksort") == null ? "path-desc" : "path");
		$("#flt").trigger("bookmarksChanged");
	} else if (action == 'bookmarksorttime') {
		cookie("bookmarksort", cookie("bookmarksort")=="time" ? "time-desc" : "time");
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
	$("#fileListTable").attr('data-fileselcounter',s["fileselcounter"]).attr('data-dirselcounter',s["dirselcounter"]).attr('data-folderselsize',s["folderselsize"]).attr("data-sumselcounter", s["sumselcounter"]);
	$("#flt").trigger("selectionCounterUpdated");
	selstats.html(tmpl.replace(/\$filecount/,s["fileselcounter"]).replace(/\$dircount/,s["dirselcounter"]).replace(/\$sum/,s["sumselcounter"])).attr('title',renderByteSizes(s["folderselsize"]));
}

function initChangeDir() {
	$("#pathinputform").submit(function(event) { return false; });
	$("#pathinputform input[name='uri']").keydown(function(event){
		if (event.keyCode==27) {
			$('#pathinput').hide();
			$('#quicknav').show();
			$('.filterbox').show();
		} else if (event.keyCode==13) {
			preventDefault(event);
			$('#pathinput').hide();
			$('#quicknav').show();
			$('.filterbox').show();
			changeUri($(this).val());
		}
	});
	$(".action.changedir").button().click(function(event) {
		preventDefault(event);
		$('#pathinput').toggle();
		$('#quicknav').toggle();
		$('#pathinput input[name=uri]').focus().select();
		$('.filterbox').toggle();
	});
	$("#path [data-action='chdir']").button().click(function(event){
		preventDefault(event);
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
	$("form#filterbox .action.clearfilter").toggleClass("invisible",$("form#filterbox input").val() == "");
	$("form#filterbox input").keyup(function() {
		$("form#filterbox .action.clearfilter").toggleClass("invisible",$(this).val() == "");
	});
	$("form#filterbox .action.clearfilter").click(function(event) {
		preventDefault(event);
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
							response($.grep(files, function(item){ return matcher.test(item)}));
						} catch (e) {
							response($.grep(files, function(item){ return item.indexOf(request.term)>-1 }));
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
			if (filter == "" || $(this).attr('data-file').match(r)) $(this).show(); else $(this).hide();	
		} catch (error) {
			if (filter == "" || $(this).attr('data-file').toLowerCase().indexOf(filter.toLowerCase()) >-1) $(this).show(); else $(this).hide();
		}
	});

	$("#flt").trigger("fileListViewChanged");
	return true;
}
function renderUploadProgressAll(uploadState, data) {
	if (!data) data=uploadState;
	var perc =  data.loaded / data.total * 100;
	$('#progress .bar').css('width', perc.toFixed(2) + '%')
		.html(parseInt(perc)+'% ('+renderByteSize(data.loaded)+'/'+renderByteSize(data.total)+')' 
				+"; "+uploadState.done+"/"+uploadState.uploads
				);	
}
function initUpload(form,confirmmsg,dialogtitle, dropZone) {
	$("#flt").on("fileListChanged",function() {
		form.fileupload("option","url",$("#fileList").attr("data-uri"));
	});
	var uploadState = {
		aborted: false,
		transports: new Array(),
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
				var filename = data.files[0]["name"];
				uploadState.transports.push(transport);
				var up =$("<div></div>").appendTo("#progress .info").attr("id","fpb"+filename).addClass("fileprogress");
				$("<div></div>").click(function(event) {
					preventDefault(event);
					$(this).data("transport").abort($("#uploadaborted").html()+": "+$(this).data("filename"));
				}).appendTo(up).attr("title",$("#cancel").html()).MyTooltip().addClass("cancel").html("&nbsp;").data({ filename: filename, transport: transport });
				$("<div></div>").appendTo(up).addClass("fileprogressbar running").html(data.files[0]["name"]+" ("+renderByteSize(data.files[0]["size"])+"): 0%");;
				// $("#progress .info").scrollTop($("#progress
				// .info")[0].scrollHeight);
				uploadState.uploads++;
				return true;
			}
			return false;
		},
		done:  function(e,data) {
			$("#progress [id='fpb"+data.files[0]["name"]+"'] .cancel").remove();
			$("div[id='fpb"+data.files[0]["name"]+"'] .fileprogressbar", "#progress .info")
				.removeClass("running")
				.addClass(data.result.message ? "done" : "failed")
				.css("width","100%")
				.html(data.result && data.result.error ? data.result.error : data.result.message ? data.result.message : data.files[0]["name"]);
			if (data.result.message) uploadState.done++; else uploadState.failed++;
			renderUploadProgressAll(uploadState);
		},
		fail: function(e,data) {
			$("#progress [id='fpb"+data.files[0]["name"]+"'] .cancel").remove();
			$("div[id='fpb"+data.files[0]["name"]+"'] .fileprogressbar", "#progress .info")
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
			uploadState.transports = new Array();
			uploadState.aborted = false;
			uploadState.files = new Array();
			uploadState.uploads = 0;
			uploadState.failed = 0;
			uploadState.done = 0;
			return true;
		},
		start: function(e,data) {
			
			var buttons = new Array();
			buttons.push({ text:$("#close").html(), disabled: true});
			buttons.push({text:$("#cancel").html(), click: function() {
				if (uploadState.aborted) return;
				uploadState.aborted=true;
				$.each(uploadState.transports, function(i,jqXHR) {
					if (jqXHR && jqXHR.abort) jqXHR.abort($("#uploadaborted").html());
				});
				uploadState.transports = [];
			}});
			$('#progress').dialog({ modal:true, title: dialogtitle, height: 370 , width: 500, buttons: buttons, beforeClose: function() { return false;} });
			$('#progress').show().each(function() {
				$(this).find('.bar').css('width','0%').html('0%');
				$(this).find('.info').html('');
			});
		},
		progress: function(e,data) {
			var perc = parseInt(data.loaded/data.total * 100)+"%";
			$("div[id='fpb"+data.files[0]["name"]+"'] .fileprogressbar", "#progress .info").css("width", perc).html(data.files[0]["name"]+" ("+renderByteSize(data.files[0]["size"])+"): "+perc);
			
		},
		progressall: function(e,data) {
			uploadState.total = data.total;
			uploadState.loaded = data.loaded;
			renderUploadProgressAll(uploadState, data);
		},
		submit: function(e,data) {
			if (!$(this).data('ask.confirm')) $(this).data('ask.confirm', cookie("settings.confirm.upload") == "no" || !checkUploadedFilesExist(data) || window.confirm(confirmmsg));
			return $(this).data('ask.confirm');
		}
	});	
}
function checkUploadedFilesExist(data) {
	for (var i=0; i<data.files.length; i++) {
		if ($("#fileList tr[data-file='"+simpleEscape(data.files[i].name)+"']").length>0) return true;
	}
	return false;
}
function initFileUpload() {
	initUpload($("#file-upload-form"),$('#fileuploadconfirm').html(), $("#progress").attr('data-title'), $(document));
	
	$(".action.upload.uibutton").button();
	$(".action.upload").click(function(event) { 
		preventDefault(event); 
		if ($(this).hasClass("disabled")) return;
		$("#file-upload-form input[type=file]").trigger('click'); 
	});
	
	$(document).bind('dragenter', function (e) {
		$("#fileList").addClass('draghover');
	}).bind('dragleave', function(e) {
		$("#fileList").removeClass('draghover');
	}).bind('drop', function(e) {
		$("#fileList").removeClass('hover');
	});

}

function confirmDialog(text, data) {
	var oldsetting;
	if (data.setting) {
		text+='<div class="confirmdialogsetting"><input type="checkbox" name="'+data.setting+'"/> '+$("#confirmdialogsetting").html()+'</div>';
		oldsetting = cookie(data.setting);
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
						togglecookie(data.setting, oldsetting, oldsetting && oldsetting!="",1);
					}
					$("#confirmdialog").dialog("close");  
					if (data.cancel) data.cancel();
				} 
			}, 
			{ 	
				text: "OK", 
				click: function() { 
					$("#confirmdialog").dialog("close");
					if (data.confirm) data.confirm() 
				} 
			},
		],
		open: function() {
			if (data.setting) {
				$("input[name='"+data.setting+"']",$(this)).click(function(event) {
					togglecookie(data.setting, "no", !$(this).is(":checked"), 1);
				}).prop("checked", cookie(data.setting)!="no");
			}
		},
		close: function() {
			if (data.cancel) data.cancel();
		}
	}).show();
}
function getVisibleAndSelectedFiles() {
	return $("#fileList tr.isreadable-yes.unselectable-no").filter(function() {return $(this).hasClass("selected") && $(this).is(":visible"); }).find("div.filename");
}
function getSelectedRows(el) {
	var selrows = $("#fileList tr.selected:visible");
	if (selrows.length==0) selrows = $(el).closest("tr[data-file]");
	if (selrows.length==0) selrows = $("#fileList tr:visible:focus");
	return selrows;
}
function getSelectedFiles(el) {
	return $.map(getSelectedRows(el), function (v,i) { return $(v).attr("data-file")});
	/*
	var selfiles = $.map($("#fileList tr.selected:visible"), function (v,i) { return $(v).attr("data-file")});
	if (selfiles.length==0) selfiles = new Array($(el).closest("tr").attr("data-file"));
	if (selfiles.length==0) selfiles =  $.map($("#fileList tr:visible:focus"), function(v,i){ return $(v).attr("data-file")});
	return selfiles;
	*/
}
function handleFileActionEvent(event) {
	preventDefault(event);
	var self = $(this);
	if (self.hasClass('disabled')) return;
	var row = self.closest("tr");
	if (self.hasClass("rename")) {
		handleFileRename(row);
	} else if (self.hasClass("delete")) {
		handleFileDelete(row);
	} else { // extension support:
		$("body").trigger("fileActionEvent",{ obj: self, event: event, file: row.attr('data-file'), selected: getSelectedFiles(this), row: row });
	}
}
function handleFileListRowFocusIn(event) {
	if (cookie("settings.show.fileactions")=="no") return;
	// if (event.type == 'mouseenter') $(this).focus();
	$("#fileactions").toggleClass("hidelabels", cookie("settings.show.fileactionlabels") =="no").MyTooltip();
	if ($("#fileactions").length==1) $("#flt").data("#fileactions",$("#fileactions").html());
	else $(".template").append('<div id="fileactions">'+$("#flt").data("#fileactions")+'</div>').MyTooltip();
	if ($("#fileactions",$(this)).length==0) {
		$("div.filename",$(this)).after($("#fileactions"));
		$("#fileactions .action").click(handleFileActionEvent);
	}	
}
function handleFileListRowFocusOut(event) {
	$("#fileactions").appendTo($(".template")).find(".action").off("click");	
}
function initFileList() {
	var flt = $("#fileListTable");
	var fl = $("#fileList");
	
	initTableSorter();
	
	$("#fileList.selectable-false tr").removeClass("unselectable-no").addClass("unselectable-yes");
	
	$("#fileList tr.unselectable-yes .selectbutton").attr("disabled","disabled");
	
	// init single file actions:
	$("#fileList tr.unselectable-no")
		.off("mouseenter.initFileList").off("mouseleave.initFileList").on("mouseenter.initFileList",handleFileListRowFocusIn).on("mouseleave.initFileList", handleFileListRowFocusOut)
		.off("focusin.initFileList").on("focusin.initFileList",handleFileListRowFocusIn)
		.each(function(i,v) {
			var self = $(this);
			self.find(".filename a").off("focusin.initFileList").on("focusin.initFileList",function(event) {
				handleFileListRowFocusIn.call(self,event);
			});
		});
	
	// mouse events on a file row:
	$("#fileList tr")
		.off("click.initFileList").on("click.initFileList",handleRowClickEvent)
		.off("dblclick.initFileList").on("dblclick.initFileList",function(event) { 
			changeUri(concatUri($("#fileList").attr('data-uri'), encodeURIComponent(stripSlash($(this).attr('data-file')))),
					$(this).attr("data-type") == 'file');
		});
	
	// fix selections after tablesorter:
	$("#fileList tr.selected td .selectbutton:not(:checked)").prop("checked",true);

	// fix annyoing text selection for shift+click:
	$('#flt').disableSelection();
	
	// init fancybox:
	$("#fileList tr.isviewable-yes[data-mime^='image/'][data-size!='0']:visible td.filename a")
		.attr("data-fancybox-group","imggallery")
		.fancybox({
			padding: 0,
			afterShow: function() { $(".fancybox-close").focus();},
			beforeLoad: function() { this.title = $(this.element).html(); }, 
			helpers: { buttons: {}, thumbs: { width: 60, height: 60, source: function(current) { return (current.element).attr('href')+'?action=thumb'; } } } 
		});
	$("#fileList tr.isviewable-no[data-mime^='image/'][data-size!='0']:visible td.filename a")
		.attr("data-fancybox-group","wtimggallery")
		.fancybox({ 
			padding: 0,
			afterShow: function() { $(".fancybox-close").focus();},
			beforeLoad: function() { this.title = $(".nametext", this.element).html(); },
			helpers: { buttons: {} }
		});
	// init drag & drop:
	$("#fileList:not(.dnd-false) tr.iswriteable-yes[data-type='dir']")
			.droppable({ scope: "fileList", tolerance: "pointer", drop: handleFileListDrop, hoverClass: 'draghover' });
	$("#fileList:not(.dnd-false) tr.isreadable-yes.unselectable-no div.filename")
			.multiDraggable({getGroup: getVisibleAndSelectedFiles, zIndex: 200, scope: "fileList", revert: true, axis: "y" });
	
	// init column drag & drop:
	$("#fileListTable th.dragaccept")
		.draggable({ zIndex: 200, scope: "fileListTable",  axis: "x" , helper: function(event) {
			var th = $(event.currentTarget);
			return $(event.currentTarget).clone().width(th.width()).addClass("dragged");
		}});
	$("#fileListTable th.dragaccept,#fileListTable th.dropaccept")
		.droppable({ scope: "fileListTable", tolerance: "pointer", drop: handleFileListColumnDrop, hoverClass: "draghover"});
	
	// init column drag and dblclick resize
	$("#fileListTable th:not(.resizable-false)")
		.off("click.initFileList").off("click.tablesorter")
		.each(function(i,v) {
			var col = $(v);
			$("<div/>").prependTo(col).html("&nbsp;").addClass("columnResizeHandle left");
			$("<div/>").prependTo(col).html("&nbsp;").addClass("columnResizeHandle right");
			col.data("origWidth", col.width());
			var wcookie = cookie(col.prop("id")+".width");
			if (wcookie) col.width(parseFloat(wcookie));
			
			// handle click and dblclick at the same time:
			var clicks = 0;
			$(v).on("click.initFileList",function(event) {
				var self = $(this);
				clicks++;
				if (clicks == 1) {
					window.setTimeout(function() {
						if (clicks == 1) {
							if (! self.hasClass("sorter-false")) handleTableColumnClick.call(self,event);
						} else {
							var width = self.width() == self.data("origWidth") ? 1 : self.data("origWidth");
							self.width(width);
							togglecookie(self.prop("id")+".width", width, width != self.data("origWidth"),1);		
						}	
						clicks = 0;
					}, 300);
				}
			});
		});	
	$("#fileListTable .columnResizeHandle").draggable({
		scope: "columnResize",
		axis: "x",
		start: function(event,ui) {
			startPos = parseInt(ui.offset.left);
			column = $(this).closest("th");
			startWidth = column.width(); 
			// origStyle = $(this).attr("style");
			handlePos = $(this).hasClass("left")? "left" : "right";
		},
		stop: function(event,ui) {
			// $(this).attr("style", origStyle);
			$(this).removeAttr("style");
			cookie(column.attr("id")+".width", column.width(),1);
		},
		drag: function(event,ui) {
			if (handlePos=="right") column.width( startWidth +  ui.offset.left - startPos );
			else column.width(startWidth + startPos - ui.offset.left);
		}
 	});
	
	// fix annyoing text selection after a double click on text in the file
	// list:
	removeTextSelections();
	$("#flt").trigger("fileListChanged");
}
function removeTextSelections() {
	if (document.selection && document.selection.empty) document.selection.empty();
	else if (window.getSelection) {
		var sel = window.getSelection();
		if (sel && sel.removeAllRanges) sel.removeAllRanges();
	}
}
function handleFileListColumnDrop(event, ui) {
	var didx = ui.draggable.prop("cellIndex");
	var tidx = $(this).prop("cellIndex");
	if (didx + 1 == tidx) return false;
	
	var cols = $("#fileListTable thead th");
	cols.eq(didx).detach().insertBefore(cols.eq(tidx));
	
	$.each($("#fileList tr"), function() {
		var cols = $(this).children("td");
		cols.eq(didx).detach().insertBefore(cols.eq(tidx));
	});
	
	cookie("visibletablecolumns", $.map($("#fileListTable thead th[data-name]:not(.hidden):not(:last)"), function(v) { return $(v).attr("data-name")} ).join(","), 1);
	
	return true;
}
function initTableSorter() {
	if (cookie('order')) {
		var so = cookie('order').split("_");
		var sname = so[0];
		var sortorder = so[1] && so[1] == 'desc' ? -1 : 1;
		var col = $("#fileListTable thead th[data-name='"+sname+"']:not(.sorter-false)");
		if (col.length>0) {
			var sattr = col.attr('data-sort');
			var stype = col.attr('data-sorttype') || 'string';
			var cidx = col.prop("cellIndex");
			setupFileListSort(cidx, sortorder);
			sortFileList(stype, sattr, sortorder, cidx, "data-file");
		}
	}
	
	$("#fileListTable thead th:not(.sorter-false)")
		.addClass('tablesorter-head')
		.off("click.tablesorter")
		.on("click.tablesorter", handleTableColumnClick);
}
function handleTableColumnClick(event) {
	var flt = $("#fileListTable");
	var lcc = flt.data("tablesorter-lastclickedcolumn");
	var sortorder = flt.data("tablesorter-sortorder");
	var stype = $(this).attr("data-sorttype")|| "string";
	var sattr = $(this).attr("data-sort");
	var cidx = $(this).prop("cellIndex");
	if (!sortorder) sortorder = -1;
	if (lcc == cidx) sortorder = -sortorder;
	cookie("order",$(this).attr('data-name') + (sortorder==-1?'_desc':''),1);
	setupFileListSort(cidx, sortorder);
	sortFileList(stype,sattr,sortorder,cidx,"data-file");
}
function setupFileListSort(cidx, sortorder) {
	var flt = $("#fileListTable");
	flt.data("tablesorter-lastclickedcolumn",cidx)
	flt.data("tablesorter-sortorder", sortorder);
	$("#fileListTable thead th")
		.removeClass('tablesorter-down')
		.removeClass('tablesorter-up')
		.eq(cidx).addClass(sortorder == 1 ? 'tablesorter-up' : 'tablesorter-down');
}
function sortFileList(stype,sattr,sortorder,cidx,ssattr) {
	$("#fileListTable tbody").each(function(i,val){
		var rows = $(val).children("tr").get();
		rows.sort(function(a,b){
			var ret = 0;
			var jqa = $(a);
			var jqb = $(b);
			var vala = jqa.attr(sattr) ? (stype=='number' ? parseInt(jqa.attr(sattr)) : jqa.attr(sattr)) : a.cells.item(cidx).innerHTML.toLowerCase();
			var valb = jqb.attr(sattr) ? (stype=='number' ? parseInt(jqb.attr(sattr)) : jqb.attr(sattr)) : b.cells.item(cidx).innerHTML.toLowerCase();
	
			if (jqa.attr('data-file').match(/^\.\.?$/)) return -1;
			if (jqb.attr('data-file').match(/^\.\.?$/)) return 1;
			if (jqa.attr('data-type') == 'dir' && jqb.attr('data-type') != 'dir') return -1;
			if (jqa.attr('data-type') != 'dir' && jqb.attr('data-type') == 'dir') return 1;
			
		
			if (stype == "number") {
				ret = vala - valb;
			} else {
				if (vala.localeCompare) {
					ret = vala.localeCompare(valb);
				} else {
					ret = (vala < valb ? -1 : (vala==valb ? 0 : 1));
				}
			}
			if (ret == 0 && sattr!=ssattr) {
				if (vala.localeCompare) {
					ret = jqa.attr(ssattr).localeCompare(jqb.attr(ssattr));
				} else {
					ret = jqa.attr(ssattr) < jqb.attr(ssattr) 
							? -1 : jqa.attr(ssattr) > jqb.attr(ssattr)	? 1 : 0;
				}
			}
			return sortorder * ret;
		});
		for (var r=0; r<rows.length; r++) {
			$(val).append(rows[r]);
			rows[r].tabIndex=r+1;
		}
		
	});
}

function concatUri(base,file) {
	return (addMissingSlash(base) + file).replace(/\/\//g,"/").replace(/\/[^\/]+\/\.\.\//g,"/");
}
function addMissingSlash(base) {
	return (base+'/').replace(/\/\//g,"/");
}
function handleFileDelete(row) {
	row.fadeTo('slow',0.5);
	confirmDialog($('#deletefileconfirm').html().replace(/%s/,quoteWhiteSpaces(simpleEscape(row.attr('data-file')))),{
		confirm: function() {
			var file = row.attr('data-file');
			removeFileListRow(row);
			var block = blockPage();
			var xhr = $.post($('#fileList').attr('data-uri'), { 'delete': 'yes', file: file }, function(response) {
				block.remove();
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
		$("#quicknav").html(response.quicknav).MyTooltip(500);
		$("#quicknav a").click(function(event) {
			preventDefault(event);
			changeUri($(this).attr("href"));
		});
	}
}
function doRename(row, file, newname) {
	var block = blockPage();
	var xhr = $.post($('#fileList').attr('data-uri'), { rename: 'yes', newname: newname, file: file  }, function(response) {
		row.find('.renamefield').remove();
		row.find('td.filename div.hidden div.filename').unwrap();
		if (response.message) {
			var xhr = $.get($('#fileList').attr('data-uri'), { ajax:'getFileListEntry', file: newname, template: $("#fileList").attr("data-entrytemplate")}, function(r) {
				try {
					var newrow = $(r);
					var d = $("tr[data-file='"+newname+"']");
					if (d.length>0) d.remove();
					row.replaceWith(newrow);
					row = newrow;
					initFileList();
				} catch (e) {
					updateFileList();
				}
				block.remove();
			});
			renderAbortDialog(xhr);
		} else {
			block.remove();
		}
		handleJSONResponse(response);
	});
	renderAbortDialog(xhr);
}
function handleFileRename(row) {
	var tdfilename = row.find('td.filename');
	var filename = row.attr('data-file');
	// fixes accesskey bug: multiple calls with on shurtcut usage:
	if ($(".renamefield",tdfilename).length>0) return;
	
	renamefield = $('#renamefield').html();

	tdfilename.wrapInner('<div class="hidden"/>').prepend(renamefield);
	var inputfield = tdfilename.find('.renamefield input[type=text]');
	$("#flt").enableSelection();
	inputfield.attr('value',inputfield.attr('value').replace(/\$filename/,filename).replace(/\/$/,"")).focus().select();
	
	inputfield.off("click").on("click", function(event) { preventDefault(event); $(this).focus();})
		.off("dblclick").on("dblclick",function(event) { preventDefault(event);});
	inputfield.keydown(function(event) {
		var row = $(this).closest('tr');
		var file = $(this).closest('tr').attr('data-file');
		var newname = $(this).val();
		if (event.keyCode == 13 && file != newname) {
			preventDefault(event);
			if (cookie("settings.confirm.rename")!="no") {
				confirmDialog($("#movefileconfirm").html().replace(/\\n/g,'<br/>').replace(/%s/,quoteWhiteSpaces(file)).replace(/%s/,quoteWhiteSpaces(newname)), {
					confirm: function() { doRename(row,file,newname)},
					setting: "settings.confirm.rename"
				});
			} else {
				doRename(row,file,newname);
			}
		} else if (event.keyCode == 27 || (event.keyCode==13 && file == newname)) {
			preventDefault(event);
			row.find('.renamefield').remove();
			row.find('td.filename div.hidden div.filename').unwrap();
			$("#flt").disableSelection();
			row.focus();
		} 
	});
	inputfield.focusout(function(event) {
		row.find('.renamefield').remove();
		row.find('td.filename div.hidden div.filename').unwrap();
		$("#flt").disableSelection();
	});
}
function notify(type,msg) {
	console.log("notify["+type+"]: "+msg);
	if (cookie("settings.messages."+type)=="no") return;
	noty({text: msg, type: type, layout: 'topCenter', timeout: 30000 });
	$("body").trigger("notify",{type:type,msg:msg});
// var notification = $("#notification");
// notification.removeClass().hide();
// notification.unbind('click').click(function() { $(this).hide().removeClass();
// }).addClass(type).html('<span>'+simpleEscape(msg)+'</span>').show();
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
				var row = $("#fileList tr").filter(function(i){ return this.rowIndex == r});
				if (!row) continue;
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
	preventDefault(event);
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
	$(".listaction.uibutton").button();
	$(".listaction").click(handleFileListActionEvent);
	$("#flt").on("fileListSelChanged", updateFileListActions).on("fileListViewChanged",updateFileListActions);
}
function updateFileListActions() {
	var s = getFolderStatistics();
	// if (s["sumselcounter"] > 0 ) $('#filelistactions').show(); else
	// $('#filelistactions').hide();
	var flt = $("#fileListTable");
	var exclude = flt.hasClass("iswriteable-no") ? ":not(.access-writeable)" : "";
	exclude += flt.hasClass("isreadable-no") ? ":not(.access-readable)" : "";
	exclude += flt.hasClass("unselectable-no") ? ":not(.access-selectable)" : "";
	
	toggleButton($(".access-writeable"), flt.hasClass("iswriteable-no"));
	toggleButton($(".access-readable"), flt.hasClass("isreadable-no"));
	toggleButton($(".access-selectable"), flt.hasClass("unselectable-yes"));
	
	toggleButton($(".sel-none"+exclude), s["sumselcounter"]!=0);
	toggleButton($(".sel-one"+exclude), s["sumselcounter"]!=1);
	toggleButton($(".sel-multi"+exclude), s["sumselcounter"]==0);
	toggleButton($(".sel-noneorone"+exclude), s["sumselcounter"]>1);

	toggleButton($(".sel-none.sel-dir"+exclude), s["fileselcounter"]!=0 );
	toggleButton($(".sel-one.sel-dir"+exclude), s["fileselcounter"]>0 || s["dirselcounter"]!=1);
	toggleButton($(".sel-multi.sel-dir"+exclude), s["fileselcounter"]>0 || s["dirselcounter"]==0);
	toggleButton($(".sel-noneorone.sel-dir"+exclude), s["fileselcounter"]>0 || s["dirselcounter"]>1);
	toggleButton($(".sel-noneormulti.sel-dir"+exclude), s["fileselcounter"]>0);

	toggleButton($(".sel-none.sel-file"+exclude),  s["fileselcounter"]!=0)
	toggleButton($(".sel-one.sel-file"+exclude), s["dirselcounter"]>0 || s["fileselcounter"]!=1);
	toggleButton($(".sel-multi.sel-file"+exclude), s["dirselcounter"]>0 || s["fileselcounter"]==0);
	toggleButton($(".sel-noneorone.sel-file"+exclude), s["dirselcounter"]>0 || s["fileselcounter"]>1);
	toggleButton($(".sel-noneormulti.sel-file"+exclude), s["dirselcounter"]>0);
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

	flt.attr('data-dircounter', s["dircounter"]);
	flt.attr('data-filecounter', s["filecounter"]);
	flt.attr('data-foldersize', s["foldersize"]);
	flt.attr('data-sumcounter', s["sumcounter"]);
	
	$("#flt").trigger("counterUpdated");
}
function getFolderStatistics() {
	var stats = new Array();

	stats["dircounter"] =  $("#fileList tr[data-mime='<folder>']:visible").length;
	stats["filecounter"] = $("#fileList tr[data-type!='dir']:visible").length;
	stats["sumcounter"] = stats["dircounter"]+stats["filecounter"];
	stats["dirselcounter"] = $("#fileList tr.selected[data-mime='<folder>']:visible").length;
	stats["fileselcounter"] = $("#fileList tr.selected[data-type!='dir']:visible").length;
	stats["sumselcounter"] = stats["dirselcounter"]+stats["fileselcounter"];

	var foldersize = 0;
	var folderselsize = 0;
	$("#fileList tr:visible").each(function(i,val) {  
		var size = parseInt($(this).attr('data-size'));
		if ($(this).hasClass('selected')) folderselsize +=size;
		foldersize += size;
	});

	stats["foldersize"]=foldersize;
	stats["folderselsize"]=folderselsize;

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
	if (hs.length > 0) hs.attr('title', hs.attr('data-title').replace(/\$foldersize/, renderByteSizes(fs)));
}
function simpleEscape(text) {
	// return text.replace(/&/,'&amp;').replace(/</,'&lt;').replace(/>/,'&gt;');
	return $('<div/>').text(text).html();
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
	if (!leaveUnblocked) blockPage();
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
	$.get(newtarget, data, function(response) {
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
	});
}
function removeFileListRow(row) {
	$("#flt").trigger("beforeFileListChange");
	row.remove();
	$("#flt").trigger("fileListChanged");
}
function doFileListDrop(action,srcuri,dsturi,files) {
	var block = blockPage(); 
	var xhr = $.post(dsturi, { srcuri: srcuri, action: action , files: files.join('@/@')  }, function (response) {
		if (response.message && action=='cut') { 
			removeFileListRow($("#fileList tr[data-file='"+files.join("'],#fileList tr[data-file='")+"']"));
		}
		block.remove();
		if (response.error) updateFileList();
		handleJSONResponse(response);
	});
	renderAbortDialog(xhr);
}
function handleFileListDrop(event, ui) {
	var dragfilerow = ui.draggable.closest('tr');
	var dsturi = concatUri($("#fileList").attr('data-uri'), encodeURIComponent(stripSlash($(this).attr('data-file')))+"/");
	var srcuri = concatUri($("#fileList").attr("data-uri"),'/');
	if (dsturi == concatUri(srcuri,encodeURIComponent(stripSlash(dragfilerow.attr('data-file'))))+"/") return;
	var action = event.shiftKey || event.altKey || event.ctrlKey || event.metaKey ? "copy" : "cut" ;
	var files = dragfilerow.hasClass('selected') 
				?  $.map($("#fileList tr.selected:visible"), function(val, i) { return $(val).attr("data-file"); }) 
				: new Array(dragfilerow.attr('data-file'));	
	if (cookie("settings.confirm.dnd")!="no") {
		var msg = $("#paste"+action+"confirm").html();
		msg = msg.replace(/%files%/g, quoteWhiteSpaces(uri2html(files.join(', '))))
				.replace(/%srcuri%/g, quoteWhiteSpaces(uri2html(srcuri)))
				.replace(/%dsturi%/g, quoteWhiteSpaces(uri2html(dsturi)))
				.replace(/\\n/g,"<br/>");
		confirmDialog(msg, { confirm: function() { doFileListDrop(action,srcuri,dsturi,files)}, setting: "settings.confirm.dnd" });
	} else {
		doFileListDrop(action,srcuri,dsturi,files);
	}
}
function blockPage() {
	return $("<div></div>").prependTo("body").addClass("overlay");
}
function stripSlash(uri) {
	return uri.replace(/\/$/,"");
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
	renderHiddenInput(form,data);
	form.submit();
	form.remove();
}
function handleFileListActionEventDelete(event) {
	$("#fileList tr.selected:visible").fadeTo("slow",0.5);
	var self = $(this);
	var selrows = $("#fileList tr.selected:visible");
	if (selrows.length == 0 ) selrows = $(this).closest('tr');
	confirmDialog(selrows.length > 1 ? $('#deletefilesconfirm').html() : $('#deletefileconfirm').html().replace(/%s/,quoteWhiteSpaces(simpleEscape(selrows.first().attr('data-file')))), {
		confirm: function() {
			var block = blockPage();
			
			if (selrows.length == 0) selrows = self.closest("tr");
			var xhr = $.post($("#fileList").attr("data-uri"), { "delete" : "yes", "file" : $.map(selrows, function(v,i) { return $(v).attr("data-file") })}, function(response) {
				block.remove();
				removeFileListRow(selrows);
				uncheckSelectedRows();
				if (response.error) updateFileList();
				handleJSONResponse(response);
			});
			renderAbortDialog(xhr);
		},
		cancel: function() {
			$("#fileList tr.selected:visible").fadeTo("fast",1);
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
	var block = blockPage();
	var xhr = $.post(dsturi, { action: action, files: files, srcuri: srcuri }, function(response) {
		if (cookie("clpaction") == "cut") rmcookies("clpfiles","clpaction","clpuri");
		block.remove();
		updateFileList();
		handleJSONResponse(response);
	});
	renderAbortDialog(xhr);
}

function handleFileListActionEvent(event) {
	preventDefault(event);
	var self = $(this);
	if (self.hasClass("disabled")) return;
	if (self.hasClass("delete")) {
		handleFileListActionEventDelete.call(this,event);
	} else if (self.hasClass("cut")||self.hasClass("copy")) {
		$("#fileList tr").removeClass("cutted").fadeTo("fast",1);
		var selfiles = $.map($("#fileList tr.selected"), function(val,i) { return $(val).attr("data-file"); });
		cookie('clpfiles', selfiles.join('@/@'));
		cookie('clpaction',self.hasClass("cut")?"cut":"copy");
		cookie('clpuri',concatUri($("#fileList").attr('data-uri'),"/"));
		if (self.hasClass("cut")) $("#fileList tr.selected").addClass("cutted").fadeTo("slow",0.5);
		handleClipboard();
		uncheckSelectedRows();
	} else if (self.hasClass("paste")) {
		var files = cookie("clpfiles");
		var action= cookie("clpaction");
		var srcuri= cookie("clpuri");
		var dsturi = concatUri($("#fileList").attr("data-uri"),"/");
		
		if (cookie("settings.confirm.paste") != "no") {
			var msg = $("#paste"+action+"confirm").html()
					.replace(/%srcuri%/g, uri2html(srcuri))
					.replace(/%dsturi%/g, uri2html(dsturi)).replace(/\\n/g,"<br/>")
					.replace(/%files%/g, uri2html(files.split("@/@").join(", ")));
			confirmDialog(msg, { confirm: function() { doPasteAction(action,srcuri,dsturi,files); }, setting: "settings.confirm.paste" });
		} else doPasteAction(action,srcuri,dsturi,files);
	} else {
		var row = $(this).closest("tr");
		$("body").trigger("fileActionEvent",{ obj: self, event: event, file: row.attr('data-file'), row: row, selected: getSelectedFiles(this) });
	}
}
function uri2html(uri) {
	return simpleEscape(decodeURIComponent(uri));
}
function cookie(name,val,expires) {
	var date = new Date();
       	date.setTime(date.getTime() + 315360000000);
	if (val) return Cookies.set(name, val, { path:$("#flt").attr("data-baseuri"), secure: true, expires: expires ? date : undefined});
	return Cookies.get(name);
}
function rmcookies() {
	for (var i=0; i < arguments.length; i++) Cookies.remove(arguments[i], { path:$("#flt").attr("data-baseuri"), secure: true});
}
function togglecookie(name,val,toggle,expires) {
	if (toggle) cookie(name,val,expires);
	else rmcookies(name);
}
function renderByteSizes(size) {
	var text = "";
	text += size+" Byte(s)";
	var nfs = size / 1024;
	if (nfs.toFixed(2) > 0) text +=' = '+nfs.toFixed(2)+'KB';
	nfs = nfs / 1024;
	if (nfs.toFixed(2) > 0) text +=' = '+nfs.toFixed(2)+'MB';
	nfs = nfs / 1024;
	if (nfs.toFixed(2) > 0) text +=' = '+nfs.toFixed(2)+'GB';
	nfs = nfs / 1024;
	if (nfs.toFixed(2) > 0) text +=' = '+nfs.toFixed(2)+'TB';
	return text;
}
function renderByteSize(size) {
	var text = size+" Byte(s)";
	var nfs = size / 1024;
	if (nfs.toFixed(2) > 0 && nfs > 1) text = nfs.toFixed(2)+'KB';
	nfs = nfs / 1024;
	if (nfs.toFixed(2) > 0 && nfs > 1) text =nfs.toFixed(2)+'MB';
	nfs = nfs / 1024;
	if (nfs.toFixed(2) > 0 && nfs > 1) text =nfs.toFixed(2)+'GB';
	nfs = nfs / 1024;
	if (nfs.toFixed(2) > 0 && nfs > 1) text =nfs.toFixed(2)+'TB';
	return text;
}
function initClipboard() {
	handleClipboard();
	$('#flt').on('fileListChanged', handleClipboard).on('popupmenu', handleClipboard);
}
function handleClipboard() {
	var action = cookie("clpaction");
	var datauri = concatUri($("#fileList").attr("data-uri"),"/");
	var srcuri = cookie("clpuri");
	var files = cookie("clpfiles");
	var disabled = (!files || files=="" || srcuri  == datauri || $("#fileListTable").hasClass("iswriteable-no"));
	toggleButton($(".listaction.paste"), disabled);
	if (srcuri == datauri && action == "cut") 
		$.each(files.split("@/@"), function(i,val) { 
			$("[data-file='"+val+"']").addClass("cutted").fadeTo("fast",0.5);
		}) ;
}

function handleInplaceInput(target, defval) {
	target.click(function(event) {
		preventDefault(event);
		var self = $(this);
		self.closest(".popup.hidden").show();
		if (self.hasClass("disabled")) return;
		if (self.data('is-active')) return;
		self.data('is-active', true);
		self.data('orig-html', target.html());
		inplace=$('<div class="inplace"><form method="post" action="#"><input class="inplace input"/></form></div>');
		var input = inplace.find('input');
		inplace.off("click").on("click",function(e) { preventDefault(e); $(this).focus()} )
			.off("dblclick").on("dblclick",function(e) { preventDefeault(e);});
		if (defval) input.val(defval);
		$("#flt").enableSelection();
		input.keydown(function(event) {
			//console.log(event);
			if (event.keyCode == 13) {
				preventDefault(event);
				$("#flt").disableSelection();
				self.data('is-active', false);
				self.html(self.data('orig-html'));
				if ((defval && input.val() == defval)||(input.val() == "")) {
					self.data('value',input.val()).focus().trigger('unchanged');
				} else {
					self.data('value',input.val()).trigger('changed');
				}
			} else if (event.keyCode == 27) {
				preventDefault(event);
				self.data('is-active', false);
				$("#flt").disableSelection();
				self.html(self.data('orig-html')).focus();
				self.trigger('canceled');
			}
		}).focusout(function(event) {
			self.data('is-active',false);
			$("#flt").disableSelection();
			self.html(self.data('orig-html'));
			self.trigger('canceled');
		});
		self.html(inplace);
		input.focus();
	});
	return target;
}
function initNewActions() {
	$(".action.new").button().click(function(event) {
		preventDefault(event);
		$(".new.popup").toggle();
		if ($(".new.popup").is(":visible")) $(".new.popup .action").first().focus();
	});
	$("body").on("click", function() { $(".new.popup:visible").hide(); });
	$(".new.popup").keydown(function(event) {
		if (event.keyCode == 27) $(this).hide();
	});
	handleInplaceInput($('.action.create-folder')).on('changed', function(event) {
		var self = $(this);
		self.closest(".popup.hidden").hide();
		$.post($('#fileList').attr('data-uri'), { mkcol : 'yes', colname : self.data('value') }, function(response) {
			if (!response.error && response.message) {
				//updateFileList();
				refreshFileListEntry(self.data('value'));
			}
			handleJSONResponse(response);
		});
	});

	handleInplaceInput($('.action.create-file')).on('changed', function(event) {
		var self = $(this);
		self.closest(".popup.hidden").hide();
		$.post($('#fileList').attr('data-uri'), { createnewfile : 'yes', cnfname : self.data('value') }, function(response) {
			if (!response.error && response.message) {
				//updateFileList();
				refreshFileListEntry(self.data('value'));
			}
			handleJSONResponse(response);
		});
	});

	handleInplaceInput($('.action.create-symlink')).on('changed', function(event) {
		$(this).closest(".popup.hidden").hide();
		var row = $('#fileList tr.selected');
		$.post($('#fileList').attr('data-uri'), { createsymlink: 'yes', lndst: $(this).data('value'), file: row.attr('data-file') }, function(response) {
			if (!response.error && response.message) updateFileList();
			handleJSONResponse(response);
		});

	});
}
function preventDefault(event) {
	if (event.preventDefault) event.preventDefault(); else event.returnValue = false;
	if (event.stopPropagation) event.stopPropagation();
}

function trimString(str,charcount) {
	if (str.length > charcount)  str = str.substr(0,4)+'...'+str.substr(str.length-charcount+7,charcount-7);
	return str;
}

function initViewFilterDialog() {
	$(".action.viewfilter").click(function(event){
		preventDefault(event);
		if ($(this).hasClass("disabled")) return;
		var self = $(this);
		$(".action.viewfilter").addClass("disabled");
		var target =$("#fileList").attr("data-uri");
		var template = self.attr("data-template");
		$.get(target, {ajax: "getViewFilterDialog", template: template}, function(response){
			var vfd = $(response);
			$("input[name='filter.size.val']", vfd).spinner({min: 0, page: 10, numberFormat: "n", step: 1});
			$("[data-action='filter.apply']", vfd).button().click(function(event){
				preventDefault(event);
				togglecookie("filter.name", 
						$("select[name='filter.name.op'] option:selected", vfd).val()+" "+$("input[name='filter.name.val']",vfd).val(),
						$("input[name='filter.name.val']", vfd).val() != "");
				togglecookie("filter.size",
						$("select[name='filter.size.op'] option:selected",vfd).val() 
						+ $("input[name='filter.size.val']",vfd).val() 
						+ $("select[name='filter.size.unit'] option:selected",vfd).val(),
						$("input[name='filter.size.val']", vfd).val() != "");
				if ($("input[name='filter.types']:checked", vfd).length > 0) {
					var filtertypes = "";
					$("input[name='filter.types']:checked", vfd).each(function(i,val) {
						filtertypes += $(val).val();
					});
					cookie("filter.types", filtertypes);
				} else rmcookies("filter.types");
				vfd.dialog("close");
				updateFileList();
			});
			$("[data-action='filter.reset']", vfd).button().click(function(event){
				preventDefault(event);
				rmcookies("filter.name", "filter.size", "filter.types");
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
		return;
	}
	var text = "";
	var refs = $("*[accesskey]").get().sort(function(a,b) {
		var aa = $(a).attr("accesskey");
		var bb = $(b).attr("accesskey");
		return aa < bb ? -1 : aa > bb ? 1 : 0; 
	});
	$.each(refs, function(i,v) {
		text += "<li>"+$(v).attr("accesskey")+": "+( $(v).attr("title") || $(v).attr("data-tooltip") || $(v).html())+"</li>";
	});
	$('<div id="accesskeydetails"/>')
		.html('<ul class="accesskeydetails">'+text+"</ul>")
		.dialog({title: $(this).attr("title"), width: "auto", height: "auto",
				buttons : [ { text: $("#close").html(), click:  function() { $(this).dialog("destroy").remove(); }}]});
}
function hidePopupMenu() {
	$("#popupmenu ul:visible").hide();
	$("#popupmenu:visible").hide().appendTo("body");
}
function initPopupMenu() {
	$("#popupmenu .action").click(function(event) {
		handleFileActionEvent.call(this,event);
		//handleFileListActionEvent.call(this,event);
	});
	// CSS replacement for a delayed
	$("#popupmenu li ul").hoverIntent(function() { $(this).show(); });
	$("#popupmenu li").hoverIntent(function(){
		var self = $(this);
		self.siblings().find("ul:visible").hide();
		$("ul",self).first().show();
		window.clearTimeout(self.data("leavetimer"));
	}, function() {
		var self = $(this);
		window.clearTimeout(self.data("leavetimer"));
		self.data("leavetimer", window.setTimeout( function() { $("ul:visible", self).hide(); }, 2500));
	});
	/*
	$("#popupmenu li ul").on("mouseenter", function() {
		$(this).show();
	});
	
	
	$("#popupmenu li").on("mouseenter", function() {
		var self = $(this);
		self.siblings().find("ul:visible").hide();
		$("ul",self).first().show();
		window.clearTimeout(self.data("leavetimer"));
	}).on("mouseleave", function(){
		var self = $(this);
		window.clearTimeout(self.data("leavetimer"));
		self.data("leavetimer", window.setTimeout( function() { $("ul:visible", self).hide(); }, 2500));
	});
	*/
	$("#popupmenu .action, #popupmenu .listaction").dblclick(function(event) { preventDefault(event);});
	$("#popupmenu .subpopupmenu").click(function(event) { preventDefault(event); }).dblclick(function(event) { preventDefault(event);});	
	function adjustPopupPosition(pageX,pageY) {
		var popup = $("#popupmenu");
		var offset = $("#content").position();
		var left = (pageX-offset.left);
		var top = (pageY-offset.top);
		var win = $(window);
		var popupHeight = popup.height();
		var popupWidth = popup.width();
		if (popupHeight + top - win.scrollTop() + offset.top > win.height() && top-popupHeight>= $("#top").height()) top-=popupHeight;
		if (popupWidth + left - win.scrollLeft() + offset.left > win.width() && left-popupWidth>= 0) left-=popupWidth;
		popup.css({"top":top+"px","left":left+"px"});
	}
	$("#flt")
		.on("beforeFileListChange", function() {
			$("#popupmenu").appendTo("body").hide();
		})
		.on("fileListChanged", function(){
			$("#fileList tr").off("contextmenu").on("contextmenu", function(event) {
				if (event.which==3) {
					preventDefault(event);
					if ($("#popupmenu").is(":visible")) {
						hidePopupMenu();
					} else {
						$("#popupmenu").appendTo($(this)).css({position: "absolute", opacity: 1}).show();
						adjustPopupPosition(event.pageX,event.pageY);
						$("#flt").trigger('popupmenu',$(this).closest('tr'));
					}
				}
			});
		});
	$("body").click(function() { hidePopupMenu(); }).on("keydown", function(e) { if (e.which == 27) hidePopupMenu(); });
	$("#filler").on("contextmenu", function() { hidePopupMenu() });
}
function refreshFileListEntry(filename) {
	var fl = $("#fileList");
	return $.get(addMissingSlash(fl.data("uri")), { ajax: "getFileListEntry", template: fl.data("entrytemplate"), file: filename}, function(r) {
		try {
			var newrow = $(r);
			row = $("tr[data-file='"+simpleEscape(filename)+"']", fl);
			if (row.length > 0) {
				row.replaceWith(newrow);
			} else {
				newrow.appendTo(fl);
			}
			initFileList();
		} catch (e) {
			updateFileList();
		}
	});
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
	$("body").toggleClass("hidedotfiles", cookie("settings.show.dotfiles") == "no");
	$("body").toggleClass("hidedotfolders", cookie("settings.show.dotfolders") == "no");
}
function updateThumbnails() {
	var enabled = cookie("settings.enable.thumbnails") != "no";
	$("#flt .icon").each(function(i,v) {
		var self = $(this);
		if (self.data("thumb")!=self.data("icon")) {
			var thumb = self.data("thumb");
			var icon = self.data("icon");
			var empty = $("#emptyimage").attr("src");
			self.attr("src", enabled ? ( thumb == "" ? empty : thumb ) : ( icon == "" ? empty : icon));
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
		$("#flt img.icon.thumbnail").error(function(){ 
			var self=$(this);
			var icon = self.data("icon");
			self.removeClass("thumbnail").attr("src", icon !='' ? icon : $("#emptyimage").attr("src"));
		});
	});
}
function quoteWhiteSpaces(filename) {
	return filename.replace(/( {2,})/g, '<span class="ws">$1</span>');
}
function initPlugins() {
	(function($) {
	    $.QueryString = (function(a) {
	        if (a == "") return {};
	        var b = {};
	        for (var i = 0; i < a.length; ++i)
	        {
	            var p=a[i].split('=');
	            if (p.length != 2) continue;
	            b[p[0]] = decodeURIComponent(p[1].replace(/\+/g, " "));
	        }
	        return b;
	    })(window.location.search.substr(1).split('&'))
	})(jQuery);
	$.fn.MyTooltip = function(delay, hidetimeout, showtimeout) {
		var toel = $("body");
		var w = $(window);
		var tooltip;
		if (!toel.data("tooltip")) { 
				tooltip = $("<div/>").addClass("tooltip").appendTo($("body")).hide();
				toel.data("tooltip", tooltip);
		} else {
			tooltip = toel.data("tooltip");
		}
		toel.off("click.MyTooltip").on("click.MyTooltip", function() { 
			clearTimeout();
			tooltip.hide();
		});
		tooltip.off("mouseover.tooltip").on("mouseover.tooltip",function(e) { 
				preventDefault(e); 
				clearTimeout(); 
				tooltip.hide(); 
		});
		function clearTimeout() {
			if (toel.data("tttimeout")) window.clearTimeout(toel.data("tttimeout"));
		}
		function setDelayTimeout(e,el) {
			clearTimeout();
			tooltip.hide();
			toel.data("tttimeout", window.setTimeout(function(){
				setTooltipPosition(e,el);
			},delay));
		}
		function hideTooltip(t,el) {
			toel.data("tttimeout", window.setTimeout(function() {tooltip.hide()}, t));
		}
		function setTooltipPosition(e,el) {
			clearTimeout();
			var left = e.pageX - Math.floor(tooltip.outerWidth()/2); 
			var top = el.offset().top - tooltip.outerHeight()-4;
			var maxWidth = Math.max(Math.floor(w.width()/2),50);
			var maxHeight = Math.max(Math.floor(w.height()/2),10);
			if (left-w.scrollLeft()<0) left = 4;
			if (left + tooltip.outerWidth() > w.width()) left = w.width() - tooltip.outerWidth()-4;
			if (top-w.scrollTop()<0) top = Math.floor(el.offset().top + el.outerHeight() + 4);
			if (Math.abs(e.pageY-top) > 50) top = Math.max(e.pageY - tooltip.outerHeight() - 14, 0);
			tooltip.css({"left":left+"px", "top":top+"px", "max-height":maxHeight+"px", "max-width":maxWidth+"px"});
			tooltip.show();
			hideTooltip(showtimeout || 7000, el);
		}
		function handleMouseOver(e,u) {
			var el = $(this);
			handleTitleAttribute(el);
			if (el.is("[data-tooltip-block]")) return;
			el.parents("[data-tooltip], [title]").each(function(i,el) { $(el).attr("data-tooltip-block", "true"); } );
			
			tooltip.text(el.attr("data-tooltip"));
			
			if (delay) {
				setDelayTimeout(e,el);
			} else {
				setTooltipPosition(e,el);
			}
		}
		function handleMouseMove(e,u) {
			var el = $(this);
			handleTitleAttribute(el);
			if (el.is("[data-tooltip-block]")) return;
			if (tooltip.is(":visible") && !delay) setTooltipPosition(e,el);
			else setDelayTimeout(e,el);
		}
		function handleMouseOut(e,u) {
			clearTimeout();
			hideTooltip(hidetimeout || 500, u);
			$(this).parents("[data-tooltip-block]").removeAttr("data-tooltip-block");
		}
		function handleTitleAttribute(el) {
			if (el.attr("title")) {
				if (el.attr("title").trim()!="") el.attr("data-tooltip", el.attr("title"));
				else cleanupMouseHandler(el).removeAttr("data-tooltip");
				el.removeAttr("title");
			}
		}
		function cleanupMouseHandler(el) {
			return el.off("mouseover.tooltip").off("mouseout.tooltip").off("mousemove.tooltip");
		}
		function initElement(el) {
			if (el.attr("title").trim()!="") cleanupMouseHandler(el).on("mouseover.tooltip",handleMouseOver).on("mouseout.tooltip",handleMouseOut).on("mousemove.tooltip",handleMouseMove);
		}
		this.find("[title]").each(function(i,v) { initElement($(v)); });
		if (this.attr("title")) initElement(this);
		
		return this;	
	};
}
function toggleFullscreen(on) {
	var e = document.documentElement;
	if (on) {
		if (e.requestFullScreen) e.requestFullScreen();
		else if (e.mozRequestFullScreen) e.mozRequestFullScreen();
		else if (e.webkitRequestFullscreen) e.webkitRequestFullscreen();
		else if (e.webkitRequestFullScreen) e.webkitRequestFullScreen();
		else if (e.msRequestFullscreen) e.msRequestFullscreen();
	} else {
		if (document.cancelFullScreen) document.cancelFullScreen();
		else if (document.mozCancelFullScreen) document.mozCancelFullScreen();
		else if (document.webkitCancelFullScreen) document.webkitCancelFullScreen();
		else if (document.webkitCancelFullscreen) document.webkitCancelFullscreen();
		else if (document.msExitFullscreen) document.msExitFullscreen();
	}
}
function addFullscreenChangeListener(fn) {
	$(document).on("webkitfullscreenchange mozfullscreenchange fullscreenchange MSFullscreenChange", fn);
}
function isFullscreen() {
	return document.fullscreenElement || document.mozFullScreenElement || document.webkitFullscreenElement || document.msFullscreenElement ? true : false;
}
function getDialog(data, initfunc) {
	var block = blockPage();
	var xhr = $.get(window.location.pathname, data, function(response) {
		block.remove();
		handleJSONResponse(response);
		initfunc(response);
	});
	renderAbortDialog(xhr);
}
function getDialogByPost(data, initfunc) {
	var block = blockPage();
	var xhr = $.post(window.location.pathname, data, function(response) {
		block.remove();
		handleJSONResponse(response);
		initfunc(response);
	});
	renderAbortDialog(xhr);
}
function initToolBox() {
	ToolBox = { 
			addFullscreenChangeListener : addFullscreenChangeListener,
			addMissingSlash: addMissingSlash,
			blockPage: blockPage,
			changeUri: changeUri,
			concatUri: concatUri,
			confirmDialog : confirmDialog,
			cookie : cookie,
			fixElementPosition: fixElementPosition,
			getDialog : getDialog,
			getDialogByPost: getDialogByPost,
			getSelectedFiles : getSelectedFiles,
			getSelectedRows : getSelectedRows,
			handleJSONResponse : handleJSONResponse,
			handleWindowResize : handleWindowResize,
			hidePopupMenu : hidePopupMenu,
			initFileList: initFileList,
			initUpload : initUpload,
			isFullscreen : isFullscreen,
			notify : notify,
			notifyError : notifyError,
			notifyInfo : notifyInfo,
			notifyWarn : notifyWarn,
			preventDefault : preventDefault,
			postAction: postAction,
			quoteWhiteSpaces: quoteWhiteSpaces,
			refreshFileListEntry : refreshFileListEntry,
			removeAbortDialog: removeAbortDialog,
			renderAbortDialog: renderAbortDialog,
			renderByteSize: renderByteSize,
			renderByteSizes: renderByteSizes,
			rmcookies: rmcookies,
			simpleEscape: simpleEscape,
			stripSlash : stripSlash,
			togglecookie : togglecookie,
			toggleFullscreen : toggleFullscreen,
			toggleRowSelection : toggleRowSelection,
			uncheckSelectedRows : uncheckSelectedRows,
			updateFileList : updateFileList
	};
}
// ready ends:
});
