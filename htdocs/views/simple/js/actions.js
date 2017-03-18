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

initChangeUriAction();
initFileActions();
initFileListActions();
initNavigationActions();


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
function handleFileActionEvent(event) {
	$.MyPreventDefault(event);
	var self = $(this);
	if (self.hasClass("disabled")) return;
	var row = self.closest("tr[data-file]");
	if (row.length === 0) row = getSelectedRows(this).shift();
	if (self.hasClass("rename")) {
		handleFileRename(row);
	} else if (self.hasClass("delete")) {
		handleFileDelete(row);
	} else { // extension support:
		$("body").trigger("fileActionEvent",{ obj: self, event: event, file: row.data("file"), selected: [ row.data("file") ] , row: row });
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
function initFileListActions() {
	updateFileListActions();
	$(".action.uibutton").button();
	$("#flt")
		.on("fileListSelChanged fileListViewChanged", updateFileListActions)
		.on("filesRemoved", function(e,data) {
			var uri = decodeURIComponent(getURI());
			for (var i = 0; i<data.files.length; i++) { // check for parent folder:
				if (uri.indexOf(data.base + data.files[i]) == 0) {
					changeUri(data.base);
					return;
				}
			}
			if (data.base != uri) return;
			uncheckSelectedRows();
			removeFileListRow($("#fileList tr[data-file='"+$.MyStringHelper.escapeSel(data.files).join("'],#fileList tr[data-file='")+"']"));
		})
		.on("filesCreated", function(e,data) {
			if (data.base != getURI()) return;
			if (data.files.length > 1) updateFileList();
			else refreshFileListEntry(data.files[0]);
		})
		.on("fileRenamed", function(e,data) {
			var uri = getURI();
			if (uri.indexOf(data.base + data.file) == 0 ) { // check for parent folder:
				changeUri(uri.replace(new RegExp("^"+data.base + data.file), data.base + data.newname +"/"));
				return;
			}
			if (data.base != getURI()) return;
			refreshFileListEntry(data.newname, data.file);
		})
	;
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

	toggleButton($(".sel-none.sel-file"+exclude), s.fileselcounter!== 0);
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
function handleFileActionsSettings() {
	$("#fileactions")
		.toggleClass("hidefileactions", $.MyCookie("settings.show.fileactions") == "no")
		.toggleClass("hidelabels", $.MyCookie("settings.show.fileactionlabels") == "no")
		.toggleClass("showalways", $.MyCookie("settings.show.fileactionalways") == "no");
}
function handleFileListRowFocusIn(event) {
	var self = $(this);
	if ($("#fileactions", self).length===0) {
		$(".changeuri.filename", self).after($("#fileactions"));
	}
	$("#fileList tr.focus").removeClass("focus");
	self.addClass("focus");
	updateFileListActions(event, { focus: true});
}
function handleFileListRowFocusOut() {
	$("#fileactions").appendTo($(".template"));
}
function handleFileDelete(row) {
	row.fadeTo("slow",0.5);
	confirmDialog($("#deletefileconfirm").html().replace(/%s/,$.MyStringHelper.quoteWhiteSpaces($.MyStringHelper.simpleEscape(row.attr("data-displayname")))),{
		confirm: function() {
			var file = row.data("file");
			var xhr = $.MyPost(getURI(), { "delete": "yes", file: file }, function(response) {
				$("#flt").trigger("filesRemoved", { base: getURI(), files: [ file ] });
				if (response.error) updateFileList();
				handleJSONResponse(response);
			});
			renderAbortDialog(xhr);
		},
		cancel: function() {
			row.fadeTo("fast",1);
		}
	});
}
function doRename(base, file, newname) {
	var xhr = $.MyPost(base, { rename: "yes", newname: newname, file: file }, function(response) {
		if (response.message) $("#flt").trigger("fileRenamed", { base: base, file: file, newname: newname });
		handleJSONResponse(response);
	});
	renderAbortDialog(xhr);
}
function handleFileRename(row) {
	var file = row.closest("tr[data-file]").data("file");
	var defaultValue = file.replace(/\/$/,"");
	$.MyInplaceEditor({	
		editorTarget: row.find("td.filename"),
		defaultValue: defaultValue,
		beforeEvent: function() { $("#flt").enableSelection(); },
		finalEvent: function() { $("#flt").disableSelection(); },
		changeEvent: function(data) {
			var newname = data.value.replace(/\//g,"");
			var base = getURI();
			if (newname == defaultValue ) return;
			if ($.MyCookie("settings.confirm.rename")!="no") {
				confirmDialog($("#movefileconfirm").html().replace(/\\n/g,"<br/>").replace(/%s/,$.MyStringHelper.quoteWhiteSpaces(file)).replace(/%s/,$.MyStringHelper.quoteWhiteSpaces(newname)), {
					confirm: function() { doRename(base, file, newname); },
					setting: "settings.confirm.rename"
				});
			} else {
				doRename(base, file, newname);
			}
		}
	});
}
function handleFileListActionEventDelete() {
	var self = $(this);
	var data;
	var selrows;
	var filename;
	var posturi;
	var files;
	if (self.parents(".mft-node").length > 0 ) {
		data = $("#foldertree").MyFolderTree("get-node-data", self);
		filename = decodeURIComponent($.MyStringHelper.getBasename(data.uri))+"/";
		posturi = $.MyStringHelper.getParentURI(data.uri);
		files = [ filename ];
		if (posturi == getURI()) selrows = $("#fileList tr[data-file='"+$.MyStringHelper.escapeSel(filename)+"/']");
	} else {
		selrows = getSelectedRows(this);
		if (selrows.length == 1) filename = selrows.first().data("file");
		posturi = getURI();
		files = $.map(selrows, function(v,i) { return $(v).data("file"); });
		selrows.fadeTo("slow", 0.5);
	}
	var confirm_msg = filename != undefined ?  $("#deletefileconfirm").html() : $("#deletefilesconfirm").html();
	confirm_msg = confirm_msg.replace(/%s/,$.MyStringHelper.quoteWhiteSpaces($.MyStringHelper.uri2html(filename)));
	confirmDialog( confirm_msg, {
		confirm: function() {
			var xhr = $.MyPost(posturi, { "delete" : "yes", "file" : files } , function(response) {
				$("#flt").trigger("filesRemoved", { base: posturi, files: files });
				if (response.error) updateFileList();
				handleJSONResponse(response);
			});
			renderAbortDialog(xhr);
		},
		cancel: function() {
			if (selrows) {
				selrows.fadeTo("fast",1);
				$("#fileList tr.selected:not(:visible) .selectbutton").prop("checked",true);
			}
		}
	});	
}
function doPasteAction(action,srcuri,dsturi,files) {
	var xhr = $.MyPost(dsturi, { action: action, files: files, srcuri: srcuri }, function(response) {
		if ($.MyCookie("clpaction") == "cut") $.MyCookie.rmCookies("clpfiles","clpaction","clpuri");
		$("#flt").trigger("filesCreated", { base: dsturi, files: response.files ? response.files : files.split("@/@") });
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
		var selfiles;
		var clpuri;
		if ( self.parents(".mft-node").length > 0) {
			var node = self.closest(".mft-node");
			var data = $("#foldertree").MyFolderTree("get-node-data",node);
			clpuri = $.MyStringHelper.getParentURI(data.uri);
			selfiles = [ decodeURIComponent($.MyStringHelper.getBasename(data.uri)) ];
			$("#foldertree .mft-node").removeClass("cutted").fadeTo("fast", 1);
			if (self.hasClass("cut")) node.addClass("cutted").fadeTo("slow", 0.5);
		} else {
			$("#fileList tr").removeClass("cutted").fadeTo("fast",1);
			selfiles = $.map(getSelectedRows(self), function(val,i) { return $(val).attr("data-file"); });
			clpuri = $.MyStringHelper.concatUri(getURI(), "/");
			if (self.hasClass("cut")) $("#fileList tr.selected:visible").addClass("cutted").fadeTo("slow",0.5);
			uncheckSelectedRows();
		}
		$.MyCookie("clpfiles", selfiles.join("@/@"));
		$.MyCookie("clpaction",self.hasClass("cut")?"cut":"copy");
		$.MyCookie("clpuri", clpuri);
		handleClipboard();
	} else if (self.hasClass("paste")) {
		var files = $.MyCookie("clpfiles");
		var action= $.MyCookie("clpaction");
		var srcuri= $.MyCookie("clpuri");
		var dsturi = $.MyStringHelper.concatUri(getURI(), "/");
		
		if ($.MyCookie("settings.confirm.paste") != "no") {
			var msg = $("#paste"+action+"confirm").html()
					.replace(/%srcuri%/g, $.MyStringHelper.uri2html(srcuri))
					.replace(/%dsturi%/g, $.MyStringHelper.uri2html(dsturi)).replace(/\\n/g,"<br/>")
					.replace(/%files%/g, $.MyStringHelper.uri2html(files.split("@/@").join(", ")));
			confirmDialog(msg, { confirm: function() { doPasteAction(action,srcuri,dsturi,files); }, setting: "settings.confirm.paste" });
		} else doPasteAction(action,srcuri,dsturi,files);
	} else if (self.hasClass("backupcopy")) {
		var uri = getURI();
		var files = getSelectedFiles(self);
		var filesparam = files.join("@/@");
		var msg = $("#backupcopyconfirm").html().replace(/%files%/g,  files.join(", "));
		if ($.MyCookie("settings.confirm.backupcopy") != "no") 
			confirmDialog(msg, { confirm: function() { doPasteAction("copy", uri, uri, filesparam); }, setting: "settings.confirm.backupcopy" });
		else doPasteAction("copy",uri, uri, filesparam);
	} else if (self.attr("href") !== undefined && self.attr("href") != "#") {
		window.open(self.attr("href"), self.attr("target") || "_self");
	} else {
		var row = getSelectedRows(self);
		$("body").trigger("fileActionEvent",{ obj: self, event: event, file: row.attr("data-file"), row: row, selected: getSelectedFiles(this) });
	}
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
	form.hide().prop("action", getURI()).prop("method","POST");
	form.append($("#token").clone().removeAttr("id"));
	renderHiddenInput(form,data);
	form.submit();
	form.remove();
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

function initNavigationActions() {
	$("#nav .action").click(handleFileListActionEvent).MyKeyboardEventHandler();
	$("#nav > ul > li.popup").addClass("popup-click");
	$("#nav li.popup").MyPopup();
	$("#flt").on("beforeFileListChange fileListSelChanged", function() { $("#nav li.popup").MyPopup("close"); });
}
