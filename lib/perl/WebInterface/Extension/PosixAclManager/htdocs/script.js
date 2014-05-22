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
		$("#flt").on("fileListChanged", function() {
			var flt = $("#fileListTable");
			$("#apps .action.pacl").toggleClass("disabled", flt.hasClass("unselectable-yes") || flt.hasClass("isreadable-no"));
		});
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
			self.dialog.dialog({modal: true, width: "auto", height: "auto", resizable: true, close: function() { self.dialog.dialog("destroy")}});	
		});
		
	},
	initFormHandler: function() {
		var self = this;
		$("form",self.dialog).on("submit", function(event) { return self.handleSubmit(event); } );
		$('input.permissions',self.dialog).change(function(event) {
			if ($(this).is(":checked")) {
				if ($(this).val() == '---') {
					$('input.permissions[name="'+$(this).attr("name")+'"]', self.dialog).each(function(i,v) {
						if ($(v).val() != '---') $(v).attr("checked", false);
					});
				} else {
					$('input.permissions[name="'+$(this).attr("name")+'"][value="---"]').attr("checked",false);
				}
				
			}	
		});
		$('input.pacl.newacl', self.dialog).autocomplete({
				minLength: 8,
				source: function(request,response) {
					$.post($("#fileList").data('uri'), {ajax: 'searchUserOrGroupEntry', term: request.term}, function(resp) {
						response(resp.result ? resp.result[0] : new Array());
					});
				},
		});
	},
	handleSubmit: function(event) {
		var self = this;
		self.preventDefault(event);
		var block = self.blockPage();
		var form = $(".pacl.form",self.dialog);
		var xhr = $.post(form.attr("action"), form.serialize(), function(response) {
			var output = $(response);
			if (noty) {
				if (response.error) noty({text: response.error.replace("/\r?\n/",'<br/>'), type: 'error', layout: 'topCenter', timeout: 30000 });
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
	preventDefault: function(event) {
		if (event.preventDefault) event.preventDefault(); else event.returnValue = false;
		if (event.stopPropagation) event.stopPropagation();
	},
	blockPage: function() {
		return $("<div></div>").prependTo("body").addClass("overlay");
	},
};