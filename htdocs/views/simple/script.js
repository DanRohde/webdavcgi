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
$(document).ready(function() {
	
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

	initZipFileUpload();

	initSelectionStatistics();

	initDialogActions()

	initTooltips();
	
	initPermissionsDialog();
	
	initViewFilterDialog();

	initClock();
	
	initAFS(); 

	initSelect();
	
	initChangeUriAction();

	initWindowResize();
	
	initSearch();
	
	initSettingsDialog();
	
	initAutoRefresh();
	
	initCollapsible();
	
	initTableConfigDialog();
	
	initKeyboardSupport();
	
	$.ajaxSetup({ traditional: true });
	
	$(document).ajaxError(function(event, jqxhr, settings, exception) { 
		console.log(event);
		console.log(jqxhr); 
		console.log(settings);
		console.log(exception);
		if (jqxhr && jqxhr.statusText) notifyError(jqxhr.statusText);
		$("div.overlay").remove();
		if (jqxhr.status = 404) window.history.back();
	});
	
	updateFileList($("#flt").attr("data-uri"));

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
	
	dialog.dialog({ modal: true, width: "auto", height: "auto", close: function() { $(".tableconfigbutton").removeClass("disabled"); dialog.dialog("destroy");}});
	
}
function initCollapsible() {
	$(".action.collapse-sidebar").click(function(event) {
		preventDefault(event);
		$(".action.collapse-sidebar").toggleClass("collapsed");
		var collapsed = $(this).hasClass("collapsed");
		$(".collapse-sidebar-collapsible").toggle(!collapsed).toggleClass("collapsed", collapsed);
		$(".collapse-sidebar-listener").toggleClass("sidebar-collapsed", collapsed);
		handleWindowResize();
		togglecookie("sidebar", "false", collapsed,1);
	});
	
	if (cookie("sidebar") == "false") $(".action.collapse-sidebar").first().trigger("click");
	
	$(".action.collapse-head").click(function(event) {
		preventDefault(event);
		$(".action.collapse-head").toggleClass("collapsed");
		var collapsed = $(this).hasClass("collapsed");
		$(".collapse-head-collapsible").toggle(!collapsed);
		$(".collapse-head-listener").toggleClass("head-collapsed", collapsed);
		handleWindowResize();
		togglecookie("head","false",collapsed, 1);
	});
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
	$("a.autorefreshrunning").addClass("disabled");
	$(".action.autorefreshtimer").addClass("disabled");
	$("#autorefresh").on("started", function() {
		$(".action.autorefreshtimer").removeClass("disabled");
		$("a.autorefreshrunning").removeClass("disabled");
		$("#autorefreshtimer").show();
		$(".action.autorefreshtoggle").addClass("running");
	}).on("stopped", function() {
		$(".action.autorefreshtimer").addClass("disabled");
		$("a.autorefreshrunning").addClass("disabled");
		$("#autorefreshtimer").hide();
		$(".action.autorefreshtoggle").removeClass("running");
	});
	
	$("#flt").on("fileListChanged", function() {
		if (cookie("autorefresh") != "" && parseInt(cookie("autorefresh"))>0) startAutoRefreshTimer(parseInt(cookie("autorefresh")));
	});
	$("a[data-action='setautorefresh']").click(function(event){
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
}
function renderAutoRefreshTimer(aftimeout) {
	var t = $(".action.autorefreshtimer");
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
				togglecookie($(this).prop("name"),"no",!$(this).is(":checked"), 1);
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
function initSearch() {
	$(".action.search").click(function(event) {
		preventDefault(event)
		if ($(this).hasClass("disabled")) return;
		var self = this;
		$(this).addClass("disabled");
		var resulttemplate = $(this).attr("data-resulttemplate");
		$.get($("#fileList").attr("data-uri"),{ajax: "getSearchDialog", template: $(this).attr("data-dialogtemplate")}, function(response){
			var dialog = $(response);
			
			$("div[data-action='search.apply']", dialog).button().click(function(event){
				preventDefault(event);
				var f = $("form",dialog);
				// XXX check all form elements (only one must have values)
				
				
				var data = { ajax: "search", template: resulttemplate };
				
				if ($("input[name='search.size.val']",f).val() != "") {
					$.extend(data, {
						"search.size" : $("select[name='search.size.op'] option:selected",f).val() 
										+ $("input[name='search.size.val']",f).val() 
										+ $("select[name='search.size.unit'] option:selected",f).val()
					});
				}
				if ($("input[name='search.name.val']",f).val() != "") {
					$.extend(data, {
						"search.name" : $("select[name='search.name.op'] option:selected",f).val() 
										+ " "
										+ $("input[name='search.name.val']",f).val()
					});
				}	
				if ($("input[name='search.types']:checked", f).length > 0) {
					var filtertypes = "";
					$("input[name='search.types']:checked", f).each(function(i,val) {
						filtertypes += $(val).val();
					});
					$.extend(data, { "search.types" : filtertypes});
				}
				dialog.dialog("close");
				
				updateFileList($("#fileList").attr("data-uri"), data);
			
			});
			handleJSONResponse(response);
			dialog.dialog({modal: true, width: "auto", height: "auto", close: function(){ $(self).removeClass("disabled"); dialog.dialog("destroy");}}).show();
		});
	});
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
	var width = $(window).width()-$("#nav").width()
	$("#content").width(width);
	$("#controls").width(width);
}

function initChangeUriAction() {
	$(".action.changeuri").click(handleChangeUriAction);
	$(".action.refresh").click(function(event) {
		preventDefault(event);
		updateFileList();
	});
	$("#flt").on("fileListChanged", function() {
		$("#fileList tr.is-dir .action.changeuri").click(handleChangeUriAction);
	});
}
function handleChangeUriAction(event) {
	preventDefault(event);
	if ($(this).closest("div.filename").is(".ui-draggable-dragging")) {
		return;
	} else {
		changeUri($(this).attr("href"));
	}
}
function initSelect() {
	$("#flt").on("fileListChanged", function() {
		$("#fileListTable .toggleselection").off("click").click(function(event) {
			preventDefault(event);
			$("#fileList tr:not(:hidden).unselectable-no").each(function(i,row) {
				$(this).toggleClass("selected");
				$(".selectbutton", $(this)).prop("checked", $(this).hasClass("selected"));
			});
			$("#flt").trigger("fileListSelChanged");
		});	
		$("#fileListTable .selectnone").off("click").click(function(event) {
			preventDefault(event);
			$("#fileList tr.selected:not(:hidden)").removeClass("selected");
			$("#fileList tr:not(:hidden) .selectbutton:checked").prop("checked", false);
			$("#flt").trigger("fileListSelChanged");
		});
		$("#fileListTable .selectall").off("click").click(function(event) {
			preventDefault(event);
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
function initTooltips() {
/*
 * $("[title]").powerTip({smartPlacement: true}); $("#flt")
 * .on("fileListChanged", function() { $("#content
 * [title]").powerTip({smartPlacement: true}); }) .on("fileListViewChanged",
 * function() { $("#content [title]").powerTip({smartPlacement: true}); })
 * .on("fileListSelChanged", function() { $("#content
 * [title]").powerTip({smartPlacement: true}); }) .on("bookmarksChanged",
 * function() { $("#bookmarks [title]").powerTip({smartPlacement: true}); });
 */
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
		self.attr("tabindex",disabled ? -1 : 0);
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
		$("<li>" + tmpl.replace(/\$bookmarkpath/g,val["path"]).replace(/\$bookmarktext/,simpleEscape(trimString(epath,20))) + "</li>")
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
				.autocomplete("option", "source", function(request, response) {
					try {
						var matcher = new RegExp(request.term);
						response($.grep(files, function(item){ return matcher.test(item)}));
					} catch (e) {
						return files;
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
				}).appendTo(up).attr("title",$("#cancel").html()).addClass("cancel").html("&nbsp;").data({ filename: filename, transport: transport });
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
function initZipFileUpload() { 
	initUpload($("#zipfile-upload-form"), $("#zipuploadconfirm").html(),$("#progress").attr('data-title'), false);
	$(".action.uncompress").click(
			function (event) { 
				preventDefault(event);
				if ($(this).hasClass("disabled")) return;
				$(this).closest(".popup.hidden").hide();
				$("#zipfile-upload-form input[type=file]").trigger("click");
			}
	);
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
function handleFileActionEvent(event) {
	preventDefault(event);
	var self = $(this);
	var row = self.closest("tr");
	if (self.hasClass("download")) {
		postAction({"zip" : "yes", "file" : row.attr('data-file')});
	} else if (self.hasClass("rename")) {
		handleFileRename(row);
	} else if (self.hasClass("delete")) {
		handleFileDelete(row);
	} else if (self.hasClass("edit")) {
		handleFileEdit(row);
	} else if (self.hasClass("props")) {
		window.location.href = concatUri(window.location.pathname, row.attr('data-file') + '?action=props');
	} else { // extension support:
		$("body").trigger("fileActionEvent",{ obj: self, event: event, file: row.attr('data-file'), row: row });
	}
}
function handleFileListRowFocusIn(event) {
	if (cookie("settings.show.fileactions")=="no") return;
	// if (event.type == 'mouseenter') $(this).focus();
	if ($("#fileactions").length==1) $("#flt").data("#fileactions",$("#fileactions").html());
	else $(".template").append('<div id="fileactions">'+$("#flt").data("#fileactions")+'</div>');
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
		.hover(handleFileListRowFocusIn, handleFileListRowFocusOut)
		.focusin(handleFileListRowFocusIn)
		.each(function(i,v) {
			var self = $(this);
			self.find(".filename a").focusin(function(event) {
				handleFileListRowFocusIn.call(self,event);
			});
		});
	
	// mouse events on a file row:
	$("#fileList tr")
		.click(handleRowClickEvent)
		.dblclick(function(event) { 
			changeUri(concatUri($("#fileList").attr('data-uri'), encodeURIComponent(stripSlash($(this).attr('data-file')))),
					$(this).attr("data-type") == 'file');
		});
	
	// fix selections after tablesorter:
	$("#fileList tr.selected td .selectbutton:not(:checked)").prop("checked",true);

	// fix annyoing text selection for shift+click:
	$('#flt').disableSelection();
	
	// init fancybox:
	$("#fileList tr.isviewable-yes.iseditable-no:not([data-file$='.pdf'])[data-size!='0']:visible td.filename a")
		.attr("data-fancybox-group","imggallery")
		.fancybox({
			afterShow: function() { $(".fancybox-close").focus();},
			beforeLoad: function() { this.title = $(this.element).html(); }, 
			helpers: { thumbs: { width: 60, height: 60, source: function(current) { return (current.element).attr('href')+'?action=thumb'; } } } 
		});
/*	
	$("#fileList tr.isviewable-yes.iseditable-yes[data-size!='0']:visible td.filename a,#fileList tr.isviewable-yes[data-file$='.pdf'] td.filename a")
		.attr("data-fancybox-group","txtgallery")
		.fancybox({
			afterShow: function() { $(".fancybox-close").focus();},
			type: 'iframe', arrows: false, beforeLoad: function() { this.title = $(this.element).html(); }, 
			helpers: { thumbs: { width: 60, height: 60, source: function(current) { return (current.element).attr('href')+'?action=thumb'; } } } 
		});
*/
	$("#fileList tr.isviewable-no[data-mime^='image/'][data-size!='0']:visible td.filename a")
		.attr("data-fancybox-group","wtimggallery")
		.fancybox({ 
			afterShow: function() { $(".fancybox-close").focus();},
			beforeLoad: function() { this.title = $(".nametext", this.element).html(); }
		});
/*	
	$("#fileList tr.isviewable-no[data-mime^='text/']:visible td.filename a, #fileList tr.isviewable-no[data-type!='dir'][data-file$='.pdf'] td.filename a")
			.attr("data-fancybox-group","wttxtgallery")
			.fancybox({
				afterShow: function() { $(".fancybox-close").focus();},
				type: 'iframe', arrows: false, beforeLoad: function() { this.title = $(".nametext",$(this.element)).html();}
			});
*/	
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
		.off("click")
		.each(function(i,v) {
			var col = $(v);
			$("<div/>").prependTo(col).html("&nbsp;").addClass("columnResizeHandle left");
			$("<div/>").prependTo(col).html("&nbsp;").addClass("columnResizeHandle right");
			col.data("origWidth", col.width());
			var wcookie = cookie(col.prop("id")+".width");
			if (wcookie) col.width(parseFloat(wcookie));
			
			// handle click and dblclick at the same time:
			var clicks = 0;
			$(v).click(function(event) {
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
function handleFileEdit(row) {
	$.get(concatUri($('#fileList').attr('data-uri'), encodeURIComponent(row.attr('data-file'))), function(response) {
		if (response.message || response.error) {
			handleJSONResponse(response);
		} else {
			var dialog = $('#edittextdata');
			var text = $("textarea[name=textdata]", dialog);
			dialog.attr('title',row.attr('data-file'));
			text.attr("data-file",row.attr("data-file"));
			text.val(response);
			text.data("response", text.val());
			dialog.find('.action.savetextdata').button().unbind('click').click(function(event) {
				preventDefault(event);
				
				function doSaveTextData() {
					text.trigger("editsubmit");
					$.post(addMissingSlash($('#fileList').attr('data-uri')), { savetextdata: 'yes', filename: row.attr('data-file'), textdata: text.val() }, function(response) {
						if (!response.error && response.message) {
							text.data("response", text.val());
							//updateFileList();
							$.get(addMissingSlash($('#fileList').attr('data-uri')), { ajax: 'getFileListEntry', template: $('#fileList').attr("data-entrytemplate"), file: row.attr('data-file')}, function(r) {
								var newrow = $(r);
								row.replaceWith(newrow);
								row = newrow;
								initFileList();
							});
						}
						handleJSONResponse(response);
					});	
				}
				if (cookie("settings.confirm.save") != "no") 
					confirmDialog($('#confirmsavetextdata').html().replace(/%s/,row.attr('data-file')), { confirm: doSaveTextData, setting: "settings.confirm.save" });
				else
					doSaveTextData();
			});
			dialog.find('.action.cancel-edit').button().unbind('click').click(function(event) {
				preventDefault(event);
				text.trigger("editsubmit");
				dialog.dialog('close');
			});
			
			dialog.dialog({ 
				modal: true, width: "auto", height: "auto",
				title: row.attr('data-file'),
				open: function() { text.trigger("editstart");},
				close: function(event) { text.trigger("editdone");},
				beforeClose: function(event,ui) { return text.val() == text.data("response") || window.confirm($('#canceledit').html());}
			});

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
	confirmDialog($('#deletefileconfirm').html().replace(/%s/,simpleEscape(row.attr('data-file'))),{
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
		$("#quicknav").html(response.quicknav);
		$("#quicknav a").click(function(event) {
			preventDefault(event);
			changeUri($(this).attr("href"));
		});
	}
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
			function doRename() {
				var block = blockPage();
				$.post($('#fileList').attr('data-uri'), { rename: 'yes', newname: newname, file: file  }, function(response) {
					row.find('.renamefield').remove();
					row.find('td.filename div.hidden div.filename').unwrap();
					if (response.message) {
						$.get($('#fileList').attr('data-uri'), { ajax:'getFileListEntry', file: newname, template: $("#fileList").attr("data-entrytemplate")}, function(r) {
							var d = $("tr[data-file='"+newname+"']");
							if (d.length>0) d.remove();
							var newrow = $(r);
							row.replaceWith(newrow);
							row = newrow;
							initFileList();
							block.remove();
						});
					} else {
						block.remove();
					}
					handleJSONResponse(response);
				});
			}
			if (cookie("settings.confirm.rename")!="no") {
				confirmDialog($("#movefileconfirm").html().replace(/\\n/g,'<br/>').replace(/%s/,file).replace(/%s/,newname), {
					confirm: doRename,
					setting: "settings.confirm.rename"
				});
			} else {
				doRename();
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
		if ((event.ctrlKey || event.shiftKey || event.metaKey || event.altKey) && flt.data('lastSelectedRowIndex')) {
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
	if ($(this).hasClass("disabled")) return false;
	var self = this;
	$(this).addClass("disabled");
	var action = $("#"+$(this).attr('data-action'));
	action.dialog({modal:true, title: $(this).html(), width: 'auto', 
					open: function() { if (action.data("initHandler")) action.data("initHandler").init(); },
					close: function() { $(self).removeClass("disabled"); },
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
		flt.attr('data-filecounter',0).attr('data-dircounter',0).attr('data-foldersize',0)
			.attr('data-fileselcounter',0).attr('data-dirselcounter',0).attr('data-folderselsize',0);
}
function updateFileListCounters() {
	var flt = $("#fileListTable");
	// file list counters:
	resetFileListCounters(flt);

	var s = getFolderStatistics();

	flt.attr('data-dircounter', s["dircounter"]);
	flt.attr('data-filecounter', s["filecounter"]);
	flt.attr('data-foldersize', s["foldersize"]);
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
function changeUri(uri, leaveUnblocked) {
	// try browser history manipulations:
	try {
		if (!leaveUnblocked) {
			if (window.history.pushState) {
				window.history.pushState({path: uri},"",uri);
				updateFileList(uri);
				$(window).off("popstate.changeuri").on("popstate.changeuri", function() {
					var loc = history.location || document.location;
					updateFileList(loc.pathname);
				});
				return true;
			} else {
				updateFileList(uri);
				return true;
			}
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
function handleFileListDrop(event, ui) {
	var dragfilerow = ui.draggable.closest('tr');
	var dsturi = concatUri($("#fileList").attr('data-uri'), encodeURIComponent(stripSlash($(this).attr('data-file')))+"/");
	var srcuri = concatUri($("#fileList").attr("data-uri"),'/');
	if (dsturi == concatUri(srcuri,encodeURIComponent(stripSlash(dragfilerow.attr('data-file'))))+"/") return false;
	var action = event.shiftKey || event.altKey || event.ctrlKey || event.metaKey ? "copy" : "cut" ;
	var files = dragfilerow.hasClass('selected') 
				?  $.map($("#fileList tr.selected:visible"), function(val, i) { return $(val).attr("data-file"); }) 
				: new Array(dragfilerow.attr('data-file'));

	function doFileListDrop() {
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
	
	if (cookie("settings.confirm.dnd")!="no") {
		var msg = $("#paste"+action+"confirm").html();
		msg = msg.replace(/%files%/g, uri2html(files.join(', ')))
				.replace(/%srcuri%/g, uri2html(srcuri))
				.replace(/%dsturi%/g, uri2html(dsturi))
				.replace(/\\n/g,"<br/>");
		confirmDialog(msg, { confirm: doFileListDrop, setting: "settings.confirm.dnd" });
	} else {
		doFileListDrop();
	}
}
function blockPage() {
	return $("<div></div>").prependTo("body").addClass("overlay");
}
function stripSlash(uri) {
	return uri.replace(/\/$/,"");
}
function postAction(data) {
	var form = $("<form/>").appendTo("body");
	form.hide().prop("action",$("#fileList").attr("data-uri")).prop("method","POST");
	function renderHiddenInput(form, data, key) {
		for (var k in data) {
			var v = data[k];
			if (typeof v === "object") renderHiddenInput(form, v, k);
			else if (key) form.append($("<input/>").prop("name",key).prop("value",v).prop("type","hidden"));
			else form.append($("<input/>").prop("name", k).prop("value",v).prop("type","hidden"));
		}
		return form;
	}
	renderHiddenInput(form,data);
	form.submit();
	form.remove();
}
function handleFileListActionEventDelete(event) {
	$("#fileList tr.selected:visible").fadeTo("slow",0.5);
	var self = $(this);
	confirmDialog($('#deletefilesconfirm').html(), {
		confirm: function() {
			var block = blockPage();
			var selrows = $("#fileList tr.selected:visible");
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
function handleFileListActionEvent(event) {
	preventDefault(event);
	var self = $(this);
	if (self.hasClass("disabled")) return;
	if (self.hasClass("download")) {
		var selfiles = $.map($("#fileList tr.selected:visible"), function (v,i) { return $(v).attr("data-file")});
		if (selfiles.length==0) selfiles = new Array($(this).closest("tr").attr("data-file"));
		var data =  { "zip" : "yes", "file" : selfiles }; 
		postAction(data);
		uncheckSelectedRows();
	} else if (self.hasClass("delete")) {
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
		
		function doPasteAction() {
			var block = blockPage();
			var xhr = $.post(dsturi, { action: action, files: files, srcuri: srcuri }, function(response) {
				if (cookie("clpaction") == "cut") rmcookies("clpfiles","clpaction","clpuri");
				block.remove();
				updateFileList();
				handleJSONResponse(response);
			});
			renderAbortDialog(xhr);
		}
		if (cookie("settings.confirm.paste") != "no") {
			var msg = $("#paste"+action+"confirm").html()
					.replace(/%srcuri%/g, uri2html(srcuri))
					.replace(/%dsturi%/g, uri2html(dsturi)).replace(/\\n/g,"<br/>")
					.replace(/%files%/g, uri2html(files.split("@/@").join(", ")));
			confirmDialog(msg, { confirm: doPasteAction, setting: "settings.confirm.paste" });
		} else doPasteAction();
	} else {
		var row = $(this).closest("tr");
		$("body").trigger("fileActionEvent",{ obj: self, event: event, file: row.attr('data-file'), row: row });
	}
}
function uri2html(uri) {
	return simpleEscape(decodeURIComponent(uri));
}
function cookie(name,val,expires) {
	var date = new Date();
       	date.setTime(date.getTime() + 315360000000);
	if (val) return $.cookie(name, val, { path:$("#flt").attr("data-baseuri"), secure: true, expires: expires ? date : undefined});
	return $.cookie(name);
}
function rmcookies() {
	for (var i=0; i < arguments.length; i++) $.removeCookie(arguments[i], { path:$("#flt").attr("data-baseuri"), secure: true});
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
	$('#flt').on('fileListChanged', handleClipboard);
}
function handleClipboard() {
	var action = cookie("clpaction");
	var datauri = concatUri($("#fileList").attr("data-uri"),"/");
	var srcuri = cookie("clpuri");
	var files = cookie("clpfiles");
	var disabled = (!files || files=="" || srcuri  == datauri || $("#fileListTable").hasClass("iswriteable-no"));
	$(".listaction.paste").toggleClass("disabled",disabled).attr("tabindex",disabled?-1:0);
	$(".listaction.paste.uibutton").button().button("option","disabled",disabled);
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
		$(this).closest(".popup.hidden").hide();
		$.post($('#fileList').attr('data-uri'), { mkcol : 'yes', colname : $(this).data('value') }, function(response) {
			if (!response.error && response.message) updateFileList();
			handleJSONResponse(response);
		});
	});

	handleInplaceInput($('.action.create-file')).on('changed', function(event) {
		$(this).closest(".popup.hidden").hide();
		$.post($('#fileList').attr('data-uri'), { createnewfile : 'yes', cnfname : $(this).data('value') }, function(response) {
			if (!response.error && response.message) updateFileList();
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
function initAFS() {
	$(".action.afsaclmanager").click(handleAFSACLManager);
	$(".action.afsgroupmanager").click(handleAFSGroupManager);
}
function initGroupManager(groupmanager, template, target){
	var groupmanager, groupManagerResponseHandler;
	groupManagerResponseHandler = function(response) {
		groupmanager.html($(response).unwrap());
		initGroupManager(groupmanager, template, target);
	};
	
	var groupSelectionHandler = function(event) {
		preventDefault(event);
		$.get(target, { ajax:"getAFSGroupManager", template: template, afsgrp: $(this).closest("li").attr('data-group')}, groupManagerResponseHandler);
	};
	$("#afsgrouplist li[data-group='"+$("#afsmemberlist").attr("data-afsgrp")+"']").addClass("selected");
	$("#afsgrouplist a[data-action='afsgroupdelete']", groupmanager).hide();
	$("#afsgrouplist li", groupmanager)
		.click(groupSelectionHandler)
		.hover(function(){
			$("a[data-action='afsgroupdelete']",$(this)).show();
		},function(){
			$("a[data-action='afsgroupdelete']", $(this)).hide();
		});
	
	$("[data-action='afsgroupdelete']", groupmanager).click(function(event){
		preventDefault(event);
		var afsgrp = $(this).closest("li").attr('data-group');
		confirmDialog($("#afsconfirmdeletegrp").html(),{
			confirm: function() {
				$.post(target,{afsdeletegrp : 1, afsgrp: afsgrp} , function(response){
					handleJSONResponse(response);
					$.get(target,{ajax: "getAFSGroupManager", template: template},groupManagerResponseHandler);
				});
			}
		});
	});
	$("input[name='afsnewgrp']", groupmanager)
		.focus(function(event) { $(this).val($(this).attr('data-user')+":").select();})
		.keypress(function(event){
			if (event.keyCode == 13) {
				var afsgrp = $(this).val();
				$.post(target,{afscreatenewgrp: "1", afsnewgrp: afsgrp}, function(response){
					handleJSONResponse(response);
					$.get(target, { ajax: "getAFSGroupManager", template: template, afsgrp: afsgrp}, groupManagerResponseHandler);
				});		
			}
		});
	$("img[data-action='afscreatenewgrp']", groupmanager).click(function(event){
		preventDefault(event);
		var afsgrp = $("input[name='afsnewgrp']", groupmanager).val();
		$.post(target,{afscreatenewgrp: "1", afsnewgrp: afsgrp}, function(response){
			handleJSONResponse(response);
			$.get(target, { ajax: "getAFSGroupManager", template: template, afsgrp: afsgrp}, groupManagerResponseHandler);
		});		
	});
	$("input[name='afsaddusers']", groupmanager).keypress(function(event){
		if (event.keyCode == 13) {
			var user = $(this).val();
			var afsgrp = $(this).attr('data-afsgrp');
			$.post(target,{afsaddusr: 1, afsaddusers: user, afsselgrp: afsgrp}, function(response){
				handleJSONResponse(response);
				$.get(target,{ajax: "getAFSGroupManager", template: template, afsgrp: afsgrp}, groupManagerResponseHandler);
			});					
		}
	});
	$("img[data-action='afsaddusr']", groupmanager).click(function(event){
		var user =$("input[name='afsaddusers']", groupmanager).val();
		var afsgrp = $("input[name='afsaddusers']", groupmanager).attr("data-afsgrp");
		$.post(target,{afsaddusr: 1, afsaddusers: user, afsselgrp: afsgrp}, function(response){
			handleJSONResponse(response);
			$.get(target,{ajax: "getAFSGroupManager", template: template, afsgrp: afsgrp}, groupManagerResponseHandler);
		});
	});
	$("a[data-action='afsmemberdelete']").click(function(event){
		var afsgrp = $("#afsmemberlist").attr("data-afsgrp");
		var member = $(this).closest("li").attr("data-member");
		preventDefault(event);
		confirmDialog($("#afsconfirmremoveuser").html(),{
			confirm: function() {
				$.post(target,{afsremoveusr:1,afsselgrp:afsgrp,afsusr: member}, function(response){
					handleJSONResponse(response);
					$.get(target,{ajax: "getAFSGroupManager", template: template, afsgrp: afsgrp}, groupManagerResponseHandler);
				});		
			}
		});
	});
	$("a[data-action='afsremoveselectedmembers']")
	.toggleClass("disabled", $("#afsmemberlist li.selected").length==0)
	.click(function(event){
		preventDefault(event);
		if ($(this).hasClass("disabled")) return;
		var afsmembers = $.map($("#afsmemberlist li.selected"), function(val,i){ return $(val).attr("data-member");});
		var afsgrp = $("#afsmemberlist").attr("data-afsgrp");
		confirmDialog($("#afsconfirmremoveuser").html(),{
			confirm: function() {
				$.post(target, {afsremoveusr: 1, afsselgrp: afsgrp, afsusr: afsmembers }, function(response){
					handleJSONResponse(response);
					$.get(target,{ajax: "getAFSGroupManager", template: template, afsgrp: afsgrp},groupManagerResponseHandler);
				});
			}
		});
	});
	$("#afsmemberlist li a[data-action='afsmemberdelete']", groupmanager).hide();
	$("#afsmemberlist li", groupmanager).click(function(event){
		$(this).toggleClass("selected");
		$("a[data-action='afsremoveselectedmembers']").toggleClass("disabled", $("#afsmemberlist li.selected").length==0)
	}).hover(function() {
		$("a[data-action='afsmemberdelete']",$(this)).show();
	},function(){
		$("a[data-action='afsmemberdelete']",$(this)).hide();
	});
	$("#afsgroupmanager", groupmanager).submit(function(event){return false;});

}
function handleAFSGroupManager(event) {
	preventDefault(event);
	var template = $(this).attr('data-template');
	var target = $("#fileList").attr('data-uri');
	if ($(this).hasClass("disabled")) return false;
	var self = this;
	$(".action.afsgroupmanager").addClass("disabled");
	$.get(target, { ajax : "getAFSGroupManager", template: template }, function(response) {
		var groupmanager = $(response);
		initGroupManager(groupmanager, template, target);
		groupmanager.dialog({modal: false, width: "auto", height: "auto", close: function() { $(".action.afsgroupmanager").removeClass("disabled"); groupmanager.remove();}}).show();
	});	
}
function handleAFSACLManager(event){
	preventDefault(event);
	if ($(this).hasClass("disabled")) return false;
	var self = this;
	$(".action.afsaclmanager").addClass("disabled");
	var target = $("#fileList").attr('data-uri');
	var seldir = $("#fileList tr.selected[data-type='dir']");
	var template = $(this).attr('data-template');
	if (seldir.length>0) target = concatUri(target,encodeURIComponent(stripSlash($(seldir[0]).attr('data-file')))+"/");
	$.get(target, { ajax : "getAFSACLManager", template : template }, function(response) {
		var aclmanager = $(response);
		$("input[readonly='readonly']",aclmanager).click(function(e) { preventDefault(e); });
		("#afasaclmanager",aclmanager).submit(function() {
			$("input[type='submit']",aclmanager).attr("disabled","disable");
			var block = blockPage();
			var xhr = $.post(target, $("#afsaclmanager",aclmanager).serialize(), function(response) {
				handleJSONResponse(response);
				block.remove();
				// aclmanager.dialog("close");
				$.get(target, {ajax: "getAFSACLManager", template: template}, function(response) {
					aclmanager.html($(response).unwrap());
					$("input[readonly='readonly']",aclmanager).click(function(e) { preventDefault(e); });
				});
			});
			renderAbortDialog(xhr);
			return false;
		});
		aclmanager.dialog({modal: true, width: "auto", height: "auto", close: function() { $(".action.afsaclmanager").removeClass("disabled"); aclmanager.remove(); }}).show();
	});
}
function initPermissionsDialog() {
	$(".action.permissions").click(function(event){
		preventDefault(event);
		if ($(this).hasClass("disabled")) return;
		var self = this;
		$(".action.permissions").addClass("disabled");
		var target = $("#fileList").attr("data-uri");
		var template = $(this).attr("data-template");
		$.get(target, {ajax: "getPermissionsDialog", template: template},function(response){
			var permissions = $(response);
			$("form",permissions).submit(function(){
				var permissionsform = $(this);
				confirmDialog($("#changepermconfirm").html(), {
					confirm: function() {
						permissions.dialog("close");
						var block = blockPage();
						var xhr = $.post(target, permissionsform.serialize()+"&"+$.param({ file: $.map($("#fileList tr.selected:visible"),function(val,i) { return $(val).attr("data-file") })}), function(resp){
							handleJSONResponse(resp);
							block.remove();
							updateFileList();
						});
						renderAbortDialog(xhr);
					}
				});
				return false;
			});
			permissions.dialog({modal:true, width: "auto", height: "auto", close: function() {$(".action.permissions").removeClass("disabled"); permissions.remove();}}).show();
			
		});
	});
}
function initViewFilterDialog() {
	$(".action.viewfilter").click(function(event){
		preventDefault(event);
		if ($(this).hasClass("disabled")) return;
		var self = this;
		$(".action.viewfilter").addClass("disabled");
		var target =$("#fileList").attr("data-uri");
		var template = $(this).attr("data-template");
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
			vfd.dialog({modal:true,width:"auto",height:"auto", close: function(){$(".action.viewfilter").removeClass("disabled"); vfd.remove();}}).show();
		});
	});
}
function renderAbortDialog(xhr, timeout) {
	window.setTimeout(function() {
		if (xhr.readyState > 2) return;
		
		var dialog = $("<div/>").html($("#cancel").html()).button();
		dialog.css({ "z-index": 100000, "position":"fixed", 
				top:'50%',left:'50%',margin:'-'+(dialog.height() / 2)+'px 0 0 -'+(dialog.width() / 2)+'px' })
		dialog.click(function(event){
			if (xhr.readyState !=4) xhr.abort();
			dialog.hide().remove();
		}).appendTo("body").show();
		var interval = window.setInterval(function() {
			if (xhr.readyState == 4) {
				dialog.hide().remove();
				window.clearInterval(interval);
			}
		}, 200);
		
	}, timeout || 5000);
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
		text += "<li>"+$(v).attr("accesskey")+": "+($(v).attr("title")? $(v).attr("title") : $(v).html())+"</li>";
	});
	$('<div id="accesskeydetails"/>')
		.html('<ul class="accesskeydetails">'+text+"</ul>")
		.dialog({title: $(this).attr("title"), width: "auto", height: "auto",
				buttons : [ { text: $("#close").html(), click:  function() { $(this).dialog("destroy").remove(); }}]});
}
function initPopupMenu() {
	$("#popupmenu .action").click(function(event) {
		handleFileActionEvent.call(this,event);
		//handleFileListActionEvent.call(this,event);
	});
	$("#popupmenu .action, #popupmenu .listaction").dblclick(function(event) { preventDefault(event);});
	$("#popupmenu .subpopupmenu").click(function(event) { preventDefault(event); }).dblclick(function(event) { preventDefault(event);});
	$("#flt")
		.on("beforeFileListChange", function() {
			$("#popupmenu").appendTo("body").hide();
		})
		.on("fileListChanged", function(){
			$("#fileList tr").off("contextmenu").on("contextmenu", function(event) {
				if (event.which==3) {
					preventDefault(event);
					if ($("#popupmenu").is(":visible")) {
						$("#popupmenu").hide().appendTo("body");
						return;
					}  else {
						var offset = $("#content").position();
						$("#popupmenu")
							.appendTo($(this))
							.css({position: "absolute", left: (event.pageX-offset.left)+"px", top: (event.pageY-offset.top)+"px", opacity: 1})
							.show()
							.find(".action").first().focus();
						handleClipboard();
					}
				}
			});
		});
	$("body").click(function() { $("#popupmenu:visible").hide().appendTo("body"); });
}
// ready ends:
});
