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
		if (data.obj.hasClass("imageinfo")) {
			var block = ToolBox.blockPage();
			var xhr = $.post(window.location.href, { action : 'imageinfo', file : data.file}, function(response) {
				var dialog = $(response);
				block.remove();
				$(".iigroupsel a",dialog).on("click", function(e) {
					ToolBox.preventDefault(e);
					var self = $(this);
					var to = $(self.attr("href"), dialog);
					$(".iigroupsel a.active", dialog).removeClass("active");
					self.addClass("active");
					
					$(".iigroup:visible",dialog).hide();
					to.show();
					
					$(".iigroupcontent").scrollTop(0);
				});
				$(".iigroup", dialog).first().show();
				$(".iigroupsel a", dialog).first().addClass("active");
				
				dialog.dialog({width: "auto", height: "auto", resizable: false, dialogClass: "imageinfo", closeText: $("#close").html()});
				dialog.MyTooltip(500); 
				$(".iigroupcontent",dialog).resizable();
			});
			ToolBox.renderAbortDialog(xhr);
		}
	});
});