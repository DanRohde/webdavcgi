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
initCopyUrl();
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
			$("[data-file='"+$.MyStringHelper.escapeSel(val)+"']").addClass("cutted").fadeTo("fast",0.5);
		}) ;
}
function initCopyUrl() {
	$("body").on("fileActionEvent", function(event,data) {
		if (!data.obj.hasClass("copyurl")) return;
		var url = window.location.href.split(/\?|#/)[0];
		if (!url.match(/\/$/)) url += "/";
		url = data.file == ".."
								? $.MyStringHelper.getParentURI(url)
								: data.file == "."
													? url
													: url + encodeURIComponent($.MyStringHelper.stripSlash(data.file));
		var te = $("<textarea/>")
					.css({position:"fixed",top:0,left:0,width:"2em",height:"2em", padding:0,border:"none",outline:"none",boxShadow:"none"})
					.val(url);
		$("body").append(te);
		te.select();
		try {
			if (! document.execCommand("copy") ) {
				window.prompt(data.obj.data("tooltip"),url);
			};
		} catch (e) {
			window.prompt(data.obj.data("tooltip"),url);
		}
		te.remove();
	});
}