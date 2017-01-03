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
	function loadPlayer(file) {
		var xhr = $.MyPost($("#flt").data("uri"), { action : 'videojs', file: file}, function (response) {
			var div = $(response);
			$("#videojs-closebutton",div).click(function() {
				$("body").trigger("videojs-close");
				div.remove();
			});
			div.MyTooltip(500);
			$("body").append(div);
		});
		ToolBox.renderAbortDialog(xhr, false, function() { });
	}
	$("#flt").on("fileListChanged", function() {
		$("#fileList .suffix-mp4.isempty-no.isreadable-yes.is-file .filename a, #fileList .suffix-ogv.isempty-no.isreadable-yes.is-file .filename a, #fileList .suffix-webm.isempty-no.isreadable-yes.is-file .filename a")
			.off("click").click(function() {
			var self = $(this);
			if (self.hasClass("disabled")) return;
			if (self.closest("div.filename").is(".ui-draggable-dragging")) return;
			loadPlayer(self.closest("tr").data("file"));
		});	
	});
	
	$("body").on("fileActionEvent", function(event,data) {
		if (data.obj.hasClass("videojs")) {
			loadPlayer(data.file);
		}
	});
});