/*********************************************************************
(C) ZE CMS, Humboldt-Universitaet zu Berlin
Written by Daniel Rohde <d.rohde@cms.hu-berlin.de>
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

initSelect();
initNav();
initFileListSettings();
updateFileList();

function initFileListSettings() {
	initShowSuffixesSetting();
	$("body").on("settingchanged", initShowSuffixesSetting);
}
function initShowSuffixesSetting() {
	$("#flt").toggleClass("hide-suffixes", $.MyCookie("settings.show.suffixes") == "no")
}
function getURI() {
	return $("#fileList").data("uri");
}
function getBaseURI() {
	return $("#flt").data("uri");
}
function initFileList() {
	$("#fileList.selectable-false tr").removeClass("unselectable-no").addClass("unselectable-yes");
	
	$("#fileList tr.unselectable-yes .selectbutton").attr("disabled","disabled");
	
	// mouse events on a file row:
	$("#fileList tr")
		.off("click.initFileList").on("click.initFileList",handleRowClickEvent)
		.off("dblclick.initFileList").on("dblclick.initFileList",function() { 
			changeUri($.MyStringHelper.concatUri(getURI(), encodeURIComponent($.MyStringHelper.stripSlash($(this).attr("data-file")))),
					$(this).attr("data-type") == "file");
		});
	
	// single click to change folder, open/download files or not:
	$("#fileList td.filename .changeuri").toggleClass("action",$.MyCookie("settings.dblclick.action")=="no");
	$("body").off("settingchanged.initFileList").on("settingchanged.initFileList", function(e, data) {
		if (data.setting != "settings.dblclick.action") return;
		window.setTimeout(function() {
			$("#fileList td.filename .changeuri").off("click.changeuri").toggleClass("action", !data.value);
			$("#flt").trigger("fileListChanged");
		}, 100);
	});
	
	// fix selections after tablesorter:
	$("#fileList tr.selected td .selectbutton:not(:checked)").prop("checked",true);

	// fix annyoing text selection for shift+click:
	$("#flt").disableSelection();
	
	// init drag & drop:
	$("#fileList:not(.dnd-false) tr.iswriteable-yes.is-dir.is-current-dir-no")
			.droppable({ scope: "fileList", tolerance: "pointer", drop: handleFileListDrop, hoverClass: "draghover" });
	$("#fileList:not(.dnd-false) tr.isreadable-yes.unselectable-no div.filename")
			.multiDraggable({getGroup: getVisibleAndSelectedFiles, zIndex: 200, scope: "fileList", revert: true });
	
	// init tabbing:
	$("#fileListTable th").MyKeyboardEventHandler();

	// init column drag and dblclick resize:
	$("#fileListTable").MyTableManager();

	// fix annyoing text selection after a double click on text in the file
	// list:
	$.MyRemoveTextSelections();
	
	$("#fileList tr:focusable:visible:first").focus();
	
	$("#flt").MyTooltip();
	$("#flt").trigger("fileListChanged");
}
function updateFileList(targetparam, dataparam) {
	var newtarget = targetparam;
	var data = dataparam;
	if (!newtarget) newtarget = getURI();
	if (!newtarget) newtarget = window.location.href;
	if (!data) {
		data={ajax: "getFileListTable", template: $("#flt").attr("data-template")};
	}
	$(".ajax-loader").show();
	$("#flt").hide();
	var timestamp = $.now();
	$("#flt").data("timestamp", timestamp);
	$.MyPost(newtarget, data, function(response) {
		var flt = $("#flt");
		if (flt.data("timestamp") != timestamp) return;
		flt.data("foldertree", response.foldertree);
		flt
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
function refreshFileListEntry(filename, oldname) {
	var fl = $("#fileList");
	return $.MyPost($.MyStringHelper.addMissingSlash(fl.data("uri")), { ajax: "getFileListEntry", template: fl.data("entrytemplate"), file: filename}, function(r) {
		try {
			var newrow = $(r);
			var row = $("tr[data-file='"+$.MyStringHelper.escapeSel(oldname !=undefined ? oldname : filename)+"']", fl);
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

function uncheckSelectedRows() {
	$("#fileList tr.selected:visible .selectbutton").prop("checked",false);
	$("#fileList tr.selected:visible").removeClass("selected");
	$("#fileList tr:visible").first().focus();
	$("#flt").trigger("fileListSelChanged");
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
	return $.map(getSelectedRows(el), function (v) { return $(v).data("file"); });
}
function getVisibleAndSelectedFiles() {
	return $("#fileList tr.isreadable-yes.unselectable-no.selected:visible div.filename");
}
function initSelect() {
	$("#flt").on("fileListChanged", function() {
		$(".toggleselection").off("click.select").on("click.select",function() {
			$("#fileList tr:not(:hidden).unselectable-no").each(function() {
				$(this).toggleClass("selected");
				$(".selectbutton", $(this)).prop("checked", $(this).hasClass("selected"));
			});
			$("#flt").trigger("fileListSelChanged");
		}).MyKeyboardEventHandler({namespace:"select"});
		$(".selectnone").off("click.select").on("click.select",function() {
			$("#fileList tr.selected:not(:hidden)").removeClass("selected");
			$("#fileList tr:not(:hidden) .selectbutton:checked").prop("checked", false);
			$("#flt").trigger("fileListSelChanged");
		}).MyKeyboardEventHandler({namespace:"select"});
		$(".selectall").off("click.select").on("click.select",function() {
			$("#fileList tr:not(.selected):not(:hidden).unselectable-no").addClass("selected");
			$("#fileList tr:not(:hidden).unselectable-no .selectbutton:not(:checked)").prop("checked", true);
			$("#flt").trigger("fileListSelChanged");
		}).MyKeyboardEventHandler({namespace:"select"});
	});
}
function isSelectableRow(row) {
	return row.attr("data-file") != ".." && !row.hasClass("unselectable-yes");
}
function getRowIndexFilter(r) {
	return function() {
		return this.rowIndex == r;
	};
}
function handleRowClickEvent(event) {
	var flt = $("#fileListTable");
	if (isSelectableRow($(this))) {
		var start = this.rowIndex;
		var end = start;
		if ((event.shiftKey || event.metaKey || event.altKey) && flt.data("lastSelectedRowIndex")) {
			end = flt.data("lastSelectedRowIndex");
			if (end < start ) {
				var c = end;
				end = start;
				start = c;
			}
			for (var r = start + 1 ; r < end ; r++ ) {
				var row = $("#fileList tr:visible").filter(getRowIndexFilter(r));
				if (row.length === 0) continue;
				toggleRowSelection(row);
				row = row.next();
			}
		}
		toggleRowSelection($(this));
		flt.data("lastSelectedRowIndex", this.rowIndex);
		$("#flt").trigger("fileListSelChanged");
	}
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
function initNav() {
	$(window).off("popstate.changeuri").on("popstate.changeuri", function() {
		var loc = history.location || document.location;
		updateFileList(loc.pathname);
	});
}
function removeFileListRow(row) {
	$("#flt").trigger("beforeFileListChange");
	row.remove();
	$("#flt").trigger("fileListChanged");
}
function doFileListDrop(srcinfo,dsturi) {
	var xhr = $.MyPost(dsturi, { srcuri: srcinfo.srcuri, action: srcinfo.action, files: srcinfo.files.join("@/@") }, function (response) {
		if (response.message && srcinfo.action=="cut") { 
			$("#flt").trigger("filesRemoved", { base: srcinfo.srcuri, files: srcinfo.files });
		}
		$("#flt").trigger("filesCreated", { base: dsturi, files: srcinfo.files } );
		if (response.error) updateFileList();
		handleJSONResponse(response);
	});
	renderAbortDialog(xhr);
}
function doFileListDropWithConfirm(srcinfo, dsturi) {
	var msg = $("#paste"+srcinfo.action+"confirm").html();
	msg = msg.replace(/%files%/g, $.MyStringHelper.quoteWhiteSpaces($.MyStringHelper.uri2html(srcinfo.files.join(", "))))
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
	var dragfilerow = ui.draggable.closest("tr");
	var srcuri = $.MyStringHelper.concatUri(getURI(), "/");
	return {
		action: event.shiftKey || event.altKey || event.ctrlKey || event.metaKey ? "copy" : "cut",
		srcuri: srcuri,
		files: dragfilerow.hasClass("selected")
				? $.map($("#fileList tr.selected:visible"), function(val, i) { return $(val).attr("data-file"); }) 
				: [ dragfilerow.attr("data-file") ]
	};
}
function handleFileListDrop(event, ui) {
	var dragfilerow = ui.draggable.closest("tr");
	var dsturi = $.MyStringHelper.concatUri(getURI(), encodeURIComponent($.MyStringHelper.stripSlash($(this).attr("data-file")))+"/");
	var srcinfo = getFileListDropSrcInfo(event, ui);
	if (dsturi == $.MyStringHelper.concatUri(srcinfo.srcuri,encodeURIComponent($.MyStringHelper.stripSlash(dragfilerow.attr("data-file"))))+"/") return;
	return doFileListDropWithConfirm(srcinfo,dsturi);
}
function toggleRowSelection(row,on) {
	if (!row) return;
	row.toggleClass("selected", on);
	row.find(".selectbutton").prop("checked", row.hasClass("selected"));
	row.attr("aria-checked", row.hasClass("selected"));
}