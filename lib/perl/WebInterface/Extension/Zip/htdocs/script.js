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
	ToolBox.initUpload($("#zipfile-up-form"), $("#zipupconfirm").html(),$("#progress").attr('data-title'), false);
	$(".action.zipup").click(function(event) {
		if ($(this).hasClass('disabled')) return;
		$("#zipfile-up-form input[type=file]").trigger("click");
	});
	$(".action.zipcompress").click(function(event) {
		if ($(this).hasClass('disabled')) return;
		var xhr = $.MyPost(window.location.pathname, {action: 'zipcompress', files: ToolBox.getSelectedFiles(this)}, function (response) {
			ToolBox.handleJSONResponse(response);
			ToolBox.updateFileList();
		});	
		ToolBox.renderAbortDialog(xhr, false, function() { ToolBox.updateFileList(); });
	});
	$(".action.zipuncompress").click(function(event) {
		var self = this;
		if ($(this).hasClass('disabled')) return;
		ToolBox.confirmDialog($("#zipuncompressconfirm").html(), { confirm: function() {
				var block = ToolBox.blockPage();
				var xhr = $.MyPost(window.location.pathname, { action: 'zipuncompress', files: ToolBox.getSelectedFiles(self)}, function(response) {
					block.remove();
					ToolBox.handleJSONResponse(response);
					ToolBox.updateFileList();
				});
				ToolBox.renderAbortDialog(xhr, false, function() { ToolBox.updateFileList(); });
			}
		});
	});
	$("body").on('fileActionEvent', function(event, data) {
		if (data.obj.hasClass('zipdwnload')) {
			ToolBox.postAction({'action' : 'zipdwnload', 'files' : data.selected });
		} else if (data.obj.hasClass('zipup')) {
			$("#zipfile-up-form input[type=file]").trigger("click");
		}
	});
});