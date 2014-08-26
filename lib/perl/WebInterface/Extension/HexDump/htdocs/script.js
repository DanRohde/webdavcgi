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
		
		if (data.obj.hasClass('hexdump')) {
			var block = ToolBox.blockPage();
			var xhr = $.get(window.location.pathname, { action: 'hexdump', file: data.file }, function(response) {
				block.remove();
				var dialog = $(response);
				
				$(".hexdump",dialog).css( { "max-height" : Math.max(Math.floor($(window).height()*0.8),200)+"px", "overflow": "auto", "padding-right":"2em" });
				
				dialog.dialog({width:"auto", height:"auto", closeText: $("#close").html() });
			} );
			ToolBox.renderAbortDialog(xhr);
		}
	});
});