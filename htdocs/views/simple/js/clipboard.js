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

initClipboard();

function initClipboard() {
	handleClipboard();
	$("#flt").on("fileListChanged", handleClipboard);
}
function handleClipboard() {
	var action = $.MyCookie("clpaction");
	var datauri = $.MyStringHelper.concatUri(getURI(), "/");
	var srcuri = $.MyCookie("clpuri");
	var files = $.MyCookie("clpfiles");
	var disabled = (!files || files === "" || (srcuri == datauri && action!="copy") || $("#fileListTable").hasClass("iswriteable-no"));
	toggleButton($(".action.paste"), disabled);
	if (srcuri == datauri && action == "cut") 
		$.each(files.split("@/@"), function(i,val) { 
			$("[data-file='"+val+"']").addClass("cutted").fadeTo("fast",0.5);
		}) ;
}
