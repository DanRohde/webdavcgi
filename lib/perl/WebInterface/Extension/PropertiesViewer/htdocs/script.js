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
		if (data.obj.hasClass("props")) {
			pv_dialog(new Array(data.file));
		}
	});
	function pv_dialog(files) {
		$.post($("#fileList").attr("data-uri"),{action: "props", file: files}, function (response) {
			var dialog = $(response);
			dialog.dialog({modal: false,width: "auto", height: "auto", resizable: true, closeOnEscape: true,
					close: function() { dialog.dialog("destroy")}});			
			$(".action.diskusage").removeClass("disabled");
		});
	}
});