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
	function doSaveTextData(row,text) {
		text.trigger("editsubmit");
		var block = ToolBox.blockPage();
		var filename = row.data("file");
		var xhr = $.post(ToolBox.addMissingSlash($('#fileList').attr('data-uri')), { action: 'savetextdata', filename: filename, textdata: text.val() }, function(response) {
			if (!response.error && response.message) {
				text.data("response", text.val());
				block.remove();
				ToolBox.refreshFileListEntry(filename);
				if (ToolBox.cookie("settings.texteditor.backup") != 'no') ToolBox.refreshFileListEntry(filename+".backup");
			} else {
				updateFileList();
			}
			ToolBox.handleJSONResponse(response);
		}).always(function() { block.remove(); });	
		ToolBox.renderAbortDialog(xhr);
	}
	function handleFileEdit(row) {
		var block = ToolBox.blockPage();
		var xhr = $.get($('#fileList').attr('data-uri'), { action:'edit', filename:row.attr('data-file') }, function(response) {
			block.remove();
			if (response.message || response.error) {
				ToolBox.handleJSONResponse(response);
			} else {
				var dialog = $(response);
				var text = $(".textdata", dialog);
				text.data("response", text.val());
				dialog.find('.action.savetextdata').button().off('click').click(function(event) {
					ToolBox.preventDefault(event);
					if (ToolBox.cookie("settings.confirm.save") != "no") 
						ToolBox.confirmDialog($('#confirmsavetextdata').html().replace(/%s/,row.attr('data-file')), { confirm: function() { doSaveTextData(row,text);}, setting: "settings.confirm.save" });
					else
						doSaveTextData(row,text);
				});
				dialog.find('.action.cancel-edit').button().off('click').click(function(event) {
					ToolBox.preventDefault(event);
					text.trigger("editsubmit");
					dialog.dialog('close');
				});
				$(window).on("unload.handleFileEdit beforeunload.handleFileEdit",function(e){
						text.trigger("editsubmit");
						if (text.data("response") == text.val()) return;
						return $("#beforeunload").html().replace(/%s/,row.attr("data-file"));
					});
				
				dialog.dialog({ 
					modal: true, width: "auto", height: "auto",
					title: row.attr('data-file'), closeText: $("#close").html(),
					open: function() { text.trigger("editstart");},
					close: function(event) { text.trigger("editdone");},
					beforeClose: function(event,ui) { $(window).off("unload.handleFileEdit beforeunload.handleFileEdit"); return text.val() == text.data("response") || window.confirm($('#canceledit').html());}
				});
			}
		});
		ToolBox.renderAbortDialog(xhr);
	}
});