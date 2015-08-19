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
		$(".action.permissions").click(function(event){
			ToolBox.preventDefault(event);
			if ($(this).hasClass("disabled")) return;
			var self = this;
			var selectedFiles = ToolBox.getSelectedFiles(self);
			$(".action.permissions").addClass("disabled");
			var target = $("#fileList").attr("data-uri");
			var template = $(this).attr("data-template");
			$.get(target, {ajax: "getPermissionsDialog", template: template},function(response){
				var permissions = $(response);
				$("form",permissions).submit(function(){
					var permissionsform = $(this);
					ToolBox.confirmDialog($("#changepermconfirm").html(), {
						confirm: function() {
							permissions.dialog("close");
							var block = ToolBox.blockPage();
							var xhr = $.post(target, permissionsform.serialize()+"&"+$.param({ files: selectedFiles}), function(resp){
								ToolBox.handleJSONResponse(resp);
								block.remove();
								ToolBox.updateFileList();
							});
							ToolBox.renderAbortDialog(xhr);
						}
					});
					return false;
				});
				$("input[name=changeperm]", permissions).button();
				permissions.dialog({modal:true, width: "auto", height: "auto", dialogClass: "permissions", closeText: $("#close").html(), close: function() {$(".action.permissions").removeClass("disabled"); permissions.remove();}}).show();
				
			});
		});

});