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
$(document).ready(function(){
	new PosixAclManager();
});
function PosixAclManager() {
	this.init();
}
PosixAclManager.prototype = {
	dialog: null,
	files: null,
	init: function() {
		var self = this;
		function handleFileListChanges() {
			var flt = $("#fileListTable");
			$("#apps .action.pacl").toggleClass("disabled", flt.hasClass("unselectable-yes") || flt.hasClass("isreadable-no"));
		}
		$("#flt").on("fileListChanged", handleFileListChanges);
		handleFileListChanges();
		$("body").on("fileActionEvent", function(event,data) {
			if (data.obj.hasClass("disabled")) return;
			if (data.obj.hasClass("pacl")) {
				var selrows = $("#fileList tr.selected:visible");
				self.files = selrows.length>0 ? $.map(selrows, function(val,i) { return $(val).attr("data-file")}) : new Array(!data.file ? '' : data.file);
				self.show();
			}
		});
	},
	show: function() {
		var self = this;
		$.post($("#fileList").data("uri"), {ajax: 'getPosixAclManager', files: self.files}, function(response) {
			self.dialog = $(response);
			self.initFormHandler();
			self.dialog.dialog({modal: true, width: "auto", height: "auto", resizable: true, close: function() { self.dialog.dialog("destroy"); $(".action.refresh:first").trigger("click");}});	
		});
		
	},
	initFormHandler: function() {
		var self = this;
		$("form",self.dialog).on("submit", function(event) { return self.handleSubmit(event); } );
		$('input.permissions',self.dialog).change(function(event) {
			if ($(this).is(":checked")) 
				$('input.permissions[name="'+$(this).attr("name")+'"][value'+($(this).val() == '---' ? '!=' : '=') + '"---"]:checked', self.dialog).attr("checked", false);				
		});
		$('input.pacl.newacl', self.dialog).autocomplete({
				minLength: 8,
				source: function(request,response) {
					$.post($("#fileList").data('uri'), {ajax: 'searchUserOrGroupEntry', term: request.term}, function(resp) {
						response(resp.result ? resp.result : new Array());
					});
				},
		});
	},
	handleSubmit: function(event) {
		var self = this;
		var form = $(".pacl.form",self.dialog);
		// check new ACL entry:
		var na = $("input.pacl.newacl");
		if (na.val() != "") {
			na.removeClass("error");
			$(".pacl.newaclpermissions").removeClass("error");
			if(!na.val().match(/^(user|u|group|g|default|d):/)) {
				na.addClass("error");
				window.alert($("#pacl_msg_err_usergroup").html());
				na.focus().select();
				return false;
			}
			var nap = $('input.permissions[name="newaclpermissions"]:checked');
			if (nap.length==0) {
				$(".pacl.newaclpermissions").addClass("error");
				window.alert($("#pacl_msg_err_perm").html());
				return false;
			}
		}
		// submit changes:
		var block = self.blockPage();
		var xhr = $.post(form.attr("action"), form.serialize(), function(response) {
			var output = $(response);
			if (noty) {
				if (response.error) noty({text: response.error.replace(/\r?\n/,'<br/>'), type: 'error', layout: 'topCenter', timeout: 30000 });
				else if (response.msg) noty({text: response.msg, type: 'info', layout: 'topCenter', timeout: 30000 });
			} 
			block.remove();
			$.post($("#fileList").data("uri"), {ajax: 'getPosixAclManager', files: self.files}, function(response){
				self.dialog.html( $(response).unwrap());
				self.initFormHandler();
			});
		});
		return false;
	},
	blockPage: function() {
		return $("<div></div>").prependTo("body").addClass("overlay");
	},
};