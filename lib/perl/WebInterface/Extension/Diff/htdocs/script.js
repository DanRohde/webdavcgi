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
(function ( $ ) {

$(document).ready(function() {
	$("body").on("fileActionEvent", function(event,data) {
		if (!data.obj.hasClass("diff")) return;
		function handleResponse(response) {
			//if (response.error) {
			//	noty({text: response.error, type: "error", layout: "topCenter", timeout: 30000 });
			//} else {
			if (!response.error) {
				var dialog = $(response.content);		
				var maxWidth = $(window).width() - 200;
				var maxHeight = $(window).height() - 200;
				$(".diff.tabs",dialog).tabs({heightStyle: "auto"});
				dialog.dialog({modal: true, width: maxWidth, height: maxHeight, dialogClass: "diff", closeText: $("#close").html(), 
					resizeStop: function() {
						$("#showdifftab,#showrawtab",dialog).css({"height" : dialog.height()-$(".buttonbar",dialog).height()-120});
					},
					open: function() {
						$("#showdifftab,#showrawtab",dialog).css({"height" : dialog.height()-$(".buttonbar",dialog).height()-120});
					}
				});
				$(".diff.swapfiles", dialog).button().click(function() {
					dialog.dialog("close");
					ToolBox.getDialogByPost({action:"diff", files:[$(this).data("file2"), $(this).data("file1")]}, handleResponse);
				});
				$(".diff.close", dialog).button().click(function() {
					dialog.dialog("destroy");
				});
				dialog.MyTooltip(500);
			}
		}
		ToolBox.getDialogByPost({action:"diff", files: data.selected}, handleResponse);
	});
	$(".action.diff").hide();
	$("#flt").on("fileListSelChanged",function() {
		$(".action.diff").toggle($("#fileList tr.selected:visible").length==2);
	});
});
}( jQuery ));