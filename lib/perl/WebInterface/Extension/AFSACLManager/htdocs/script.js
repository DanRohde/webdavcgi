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
	$("body").on("fileActionEvent", function(event,data) {
		if (data.obj.hasClass("afsaclmanager")) handleAFSACLManager.call(this,event);
	});
	$(".action.afsaclmanager").click(handleAFSACLManager);
	function handleAFSACLManager(){
		if ($(this).hasClass("disabled")) return false;
		$(".action.afsaclmanager").addClass("disabled");
		var target = $("#fileList").attr("data-uri");
		var seldir = $("#fileList tr.selected[data-type='dir']");
		var template = $(this).attr("data-template");
		if (seldir.length>0) target = ToolBox.concatUri(target,encodeURIComponent(ToolBox.stripSlash($(seldir[0]).attr("data-file")))+"/");
		var xhr = $.MyPost(target, { ajax : "getAFSACLManager", template : template }, function(response) {
			var aclmanager = $(response);
			initAFSACLManager(aclmanager);
			("#afasaclmanager",aclmanager).submit(function() {
				$("input[type='submit']",aclmanager).attr("disabled","disable");
				xhr = $.MyPost(target, $("#afsaclmanager",aclmanager).serialize(), function(resp) {
					ToolBox.handleJSONResponse(resp);
					$.MyPost(target, {ajax: "getAFSACLManager", template: template}, function(r) {
						aclmanager.html($(r).unwrap());
						initAFSACLManager(aclmanager);
					});
				});
				ToolBox.renderAbortDialog(xhr);
				return false;
			});
			aclmanager.dialog({modal: true, width: "auto", height: "auto", dialogClass: "afsaclmanager", closeText: $("#close").html(), close: function() { $(".action.afsaclmanager").removeClass("disabled"); aclmanager.remove(); }}).show();
		});
		ToolBox.renderAbortDialog(xhr);
		return true;5
	}
	function initAFSACLManager(aclmanager) {
		$("input[readonly='readonly']",aclmanager).click(function(e) {$.MyPreventDefault(e); });
		$("input.afsaclmanager.add",aclmanager).autocomplete( { minLength: 4, source: function(request,response) {
			$.MyPost($("#fileList").data("uri"), {ajax: "searchAFSUserOrGroupEntry", term: request.term}, function(resp) {
				response(resp.result ? resp.result : [] );
			}, true);
		}});
		$("input[name=saveafsacl]",aclmanager).button();
	}
}( jQuery ));