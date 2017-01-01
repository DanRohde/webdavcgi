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
		function resizeIframe(dialog) {
			$("iframe",dialog).attr("width", $(window).width()-40).attr("height", $(window).height()-Math.max($(".close.button",dialog).outerHeight(),50));
		}
		function removeDialog(dialog) {
			$("#main").show();
			$(window).off("popstate.viewerjs unload.viewerjs beforeunload.viewerjs resize.viewerjs"); 
			if (dialog && dialog.remove) dialog.remove();
			
		}
		if (data.obj.hasClass('viewerjs')) {
			var xhr = $.MyPost(window.location.pathname, { action:"viewerjs", file:data.file}, function(response) {
				$("#main").hide();
				var dialog = $(response);
				$(".close.button",dialog).button().click(function() { removeDialog(dialog); });
				$(window)
					.off("popstate.viewerjs unload.viewerjs beforeunload.viewerjs")
					.on("popstate.viewerjs unload.viewerjs beforeunload.viewerjs", function(){ removeDialog(dialog); })			
					.off("resize.viewerjs").on("resize.viewerjs", function() { resizeIframe(dialog); });
				resizeIframe(dialog);
				dialog.appendTo($("body"));
			});
			ToolBox.renderAbortDialog(xhr);
		}
	});
});