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
	/*$("#flt").on("fileListSelChanged", function() {
		var sel = ToolBox.getSelectedRows($(this));
		$(".action.scv").toggle(sel.length == 1 && sel.hasClass('svc-source') );
	});*/
	$("body").on("fileActionEvent", function(event,data) {
		if (data.obj.hasClass('scv')) {
			var files = ToolBox.getSelectedFiles(data.obj);
			var block = ToolBox.blockPage();
			var xhr = $.post(window.location.href, { action : "scv", files : files }, function(response) {
				block.remove();
				ToolBox.handleJSONResponse(response);
				if (!response.error) {
					var dialog = $(response);
					var wh = $(window).height();
					var ww = $(window).width();
					$(".prettyprint",dialog).data("src", $(".prettyprint",dialog).text());
					$(".prettyprint",dialog).css({ "max-width" : (ww-120)+'px', "max-height" : (wh-300)+'px' });
					$(".scv-linenum",dialog).button().click(function(e) {
							ToolBox.preventDefault(e);
							$(".prettyprint",dialog).toggleClass("linenums")
								.removeClass("prettyprinted")
								.text($(".prettyprint",dialog).data("src")); 
							prettyPrint();
							return false;
					});
					
					dialog.dialog({width: "auto", height: "auto", maxWidth: ww-50, maxHeight: wh-50, closeText: $("#close").html(), open: function() { if (prettyPrint) prettyPrint(); }});
			
				}
			});
			ToolBox.renderAbortDialog(xhr);
		}
	});
});