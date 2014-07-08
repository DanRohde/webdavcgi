$(document).ready(function() {
	function checkInputField(field,dialog) {
		if ($("input[name="+field+"]",dialog).val().trim() == "") {
			$("input[name="+field+"]",dialog).addClass("error").focus();
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
	$("body").on("fileActionEvent", function(event,data) {
		if (data.obj.hasClass("disabled")) return;
		if (!data.obj.hasClass("sendbymail")) return;
		
		$.post(window.location.pathname, { action: 'sendbymail', ajax: 'preparemail', files: data.selected}, function(response) {
			var dialog = $(response);
			
			
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
				
				$.post(window.location.pathname, $(this).serialize(), function(resp) {
					var type = "info", msg=resp.msg;
					if (resp.error) { type="error"; msg=resp.error; }
					noty({text: msg, type: type, layout: 'topCenter', timeout: 30000 });
					dialog.dialog("close");
				});
				return false;
			});
			
			dialog.dialog({modal: true, width: "auto", height: "auto"});
			
		});
		
	});
});