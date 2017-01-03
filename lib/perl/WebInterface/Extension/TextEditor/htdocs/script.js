/*********************************************************************
(C) ZE CMS, Humboldt-Universitaet zu Berlin
Written 2014 by Daniel Rohde <d.rohde@cms.hu-berlin.de>
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
	$("body").on("fileActionEvent", function(event,data) {
		if (data.obj.hasClass('edit')) handleFileEdit(data.row);
	});
	function doSaveTextData(datauri, filename, text, size) {
		text.trigger("editsubmit");
		var xhr = $.MyPost(ToolBox.addMissingSlash(datauri), { action: 'savetextdata', filename: filename, textdata: text.val() }, function(response) {
			if (!response.error && response.message) {
				text.data("response", text.val());
				if ($("#fileList").attr("data-uri") == datauri) {
					ToolBox.refreshFileListEntry(filename);
					if (ToolBox.cookie("settings.texteditor.backup") != 'no' && size != 0) ToolBox.refreshFileListEntry(filename+".backup");
				}
			} else {
				updateFileList();
			}
			ToolBox.handleJSONResponse(response);
		});
		ToolBox.renderAbortDialog(xhr);
	}
	function handleFileEdit(row) {
		var datauri = $("#fileList").attr("data-uri");
		var filename = row.attr("data-file");
		var size = row.data("size");
		var xhr = $.MyPost(datauri, { action: 'edit', filename: filename }, function(response) {
			if (response.message || response.error) {
				ToolBox.handleJSONResponse(response);
			} else {
				var dialog = $(response);
				var text = $(".textdata", dialog);
				text.data("response", text.val());
				dialog.find('.action.savetextdata').button().off('click').click(function(event) {
					$.MyPreventDefault(event);
					if (ToolBox.cookie("settings.confirm.save") != "no") 
						ToolBox.confirmDialog($('#confirmsavetextdata').html().replace(/%s/,ToolBox.quoteWhiteSpaces(row.attr('data-file'))), { 
								confirm: function() { doSaveTextData(datauri,filename,text,size);}, 
								setting: "settings.confirm.save" });
					else
						doSaveTextData(datauri, filename, text, size);
				});
				dialog.find('.action.cancel-edit').button().off('click').click(function(event) {
					$.MyPreventDefault(event);
					text.trigger("editsubmit");
					dialog.dialog('close');
				});
				$(window).on("unload.handleFileEdit beforeunload.handleFileEdit",function(e){
						text.trigger("editsubmit");
						if (text.data("response") == text.val()) return;
						return $("#beforeunload").html().replace(/%s/,ToolBox.quoteWhiteSpaces(row.attr("data-file")));
					});
				
				dialog.dialog({ 
					modal: true, width: "auto", height: "auto", dialogClass: "edittextdata", 
					title: row.attr('data-file'), closeText: $("#close").html(),
					open: function() { text.trigger("editstart"); },
					close: function(event) { text.trigger("editdone"); dialog.dialog("destroy"); },
                    resize: function(event) { text.trigger("editresize"); },
					beforeClose: function(event,ui) { $(window).off("unload.handleFileEdit beforeunload.handleFileEdit"); return text.val() == text.data("response") || window.confirm($('#canceledit').html());}
				});
			}
		});
		ToolBox.renderAbortDialog(xhr);
	}
});
