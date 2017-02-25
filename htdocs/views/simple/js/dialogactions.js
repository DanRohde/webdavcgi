/*********************************************************************
(C) ZE CMS, Humboldt-Universitaet zu Berlin
Written by Daniel Rohde <d.rohde@cms.hu-berlin.de>
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

initDialogActions();

function initDialogActions() {
	$(".dialog.action").click(handleDialogActionEvent);
}
function handleDialogActionEvent(event) {
	$.MyPreventDefault(event);
	if ($(this).hasClass("disabled")) return;
	var self = $(this);
	self.addClass("disabled");
	
	var action = $("#"+self.attr("data-action"));
	if (action.attr("title")) action.data("title", action.attr("title"));
	action.attr("title", action.data("title"));
	
	action.dialog({
					modal:true,
					width: "auto", 
					open: function() { if (action.data("initHandler")) action.data("initHandler").init(); },
					close: function() { self.removeClass("disabled"); },
					dialogClass: self.attr("data-action")+"dialog",
					buttons : [{ text: $("#close").html(), click:  function() { $(this).dialog("close"); }}]}).show();
}