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
	function loadGPXViewerDialog(file) {
		var block = ToolBox.blockPage();
		var xhr = $.post(window.location.href, { action: 'gpxviewer', file: file }, function(response) {
			var dialog = $(response);
			block.remove();
			dialog.dialog({ width: "auto", height: "auto", modal: true, dialogClass: dialog.attr("class"), closeText: $("#close").html(), open: function() { initGPXViewer(); }, resize: function() { 
				$("#gpxviewermap").css({width:dialog.width(),height:dialog.height()-$("#gpxviewerstats",dialog).height()});
				triggerGPXViewerResize();
			}, close: function() { finalizeGPXViewer(); dialog.dialog("destroy"); }});
		});
		ToolBox.renderAbortDialog(xhr);
	}
	$("body").on("fileActionEvent", function(event,data) {
		if (data.obj.hasClass("gpxviewer")) {
			loadGPXViewerDialog(data.file);
		}
	});
	$("#flt").on("fileListChanged",function() {
		$("#fileList .suffix-gpx.isempty-no.isreadable-yes.is-file .filename a").off("click").on("click", function(ev) {
			var self = $(this);
			ToolBox.preventDefault(ev);
			if (self.closest("div.filename").is(".ui-draggable-dragging")) return;
			loadGPXViewerDialog(self.closest("tr").data("file"));
		} );
		
	})
});