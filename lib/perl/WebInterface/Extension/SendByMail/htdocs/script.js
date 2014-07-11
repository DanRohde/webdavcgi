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
	function addErrorToField(field,dialog) {
		showInputFailure(dialog);
		$("input[name="+field+"]",dialog).addClass("error").focus();
	}
	function showInputFailure(dialog) {
		$("#inputfailure",dialog).show(1000);
		window.setTimeout(function() {  $("#inputfailure",dialog).hide(800); }, 5000);
	}
	function checkInputField(field,dialog) {
		if ($("input[name="+field+"]",dialog).val().trim() == "") {
			addErrorToField(field,dialog);
			return false;
		}
		return true;
	}
	function checkInputFields(fields,dialog) {
		var i;
		for (i=0; i<fields.length; i++) {
			if (!checkInputField(fields[i],dialog)) return false;
		}
		return true;
	}
	function blockPage() {
		return $("<div></div>").prependTo("body").addClass("overlay");
	}
	$("body").on("fileActionEvent", function(event,data) {
		if (data.obj.hasClass("disabled")) return;
		if (!data.obj.hasClass("sendbymail")) return;
		var loc = window.location.pathname;
		$.post(loc, { action: 'sendbymail', ajax: 'preparemail', files: data.selected}, function(response) {
			var dialog = $(response);
			
			$("input[name=download]",dialog).click(function(event) {
				event.preventDefault();
				dialog.dialog("close");
				$('form',dialog).off("submit").append('<input type="hidden" name="download" value="yes"/>').submit();
				return false;
			});
			
			$("input",dialog).on("keydown", function(event) {
				$(this).next("input").focus();
				return event.which !==13;
			});
			
			$("input[name=zipfilename]",dialog).prop("disabled", true);
			$("input[name=zip]", dialog).change(function(){
				if ($(".sendbymail.files.dir",dialog).length>0) $(this).prop("checked", true);
				$("input[name=zipfilename]",dialog).prop("disabled", !$(this).is(":checked"));
			});

			if ($(".sendbymail.files.dir",dialog).length>0) $("input[name=zip]",dialog).prop("checked", true).trigger("change");

			
			if ($(".sendbymail.remove", dialog).length==1)	$(".sendbymail.remove",dialog).remove();
			$(".sendbymail.remove", dialog).click(function() {
				$(".sendbymail.sumfilesizes").remove();
				$(this).parent().remove();
				if ($(".sendbymail.remove",dialog).length==1) $(".sendbymail.remove",dialog).remove();
			});
			
			$("form.sendbymail", dialog).submit(function() {
			
				$("input.error",dialog).removeClass("error");
				if (!checkInputFields(new Array("from","to","subject"),dialog)) return false;
				
				$("input[type=submit]",dialog).prop("disabled",true);
				var block = blockPage();
				$.post(loc, $(this).serialize(), function(resp) {
					block.remove();
					var type = "info", msg=resp.msg;
					if (resp.error) { 
						type="error"; msg=resp.error;
						if (resp.field)  addErrorToField(resp.field, dialog);
					}
					noty({text: msg, type: type, layout: 'topCenter', timeout: 30000 });
					if (!resp.error) dialog.dialog("close");
					else $("input[type=submit]",dialog).prop("disabled",false);
				});
				return false;
			});
			
			dialog.dialog({modal: true, width: "auto", height: "auto"});
			
		});
		
	});
});