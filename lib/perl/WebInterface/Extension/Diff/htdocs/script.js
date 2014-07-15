$(document).ready(function() {
	$("body").on("fileActionEvent", function(event,data) {
		if (data.obj.hasClass("disabled")) return;
		if (!data.obj.hasClass("diff")) return;
		var block = ToolBox.blockPage();
		$.post(window.location.pathname, {action:'diff', files: data.selected}, function(response) {
				block.remove();
				if (response.error) {
					noty({text: response.error, type: 'error', layout: 'topCenter', timeout: 30000 });
				} else {
					var dialog = $(response.content);		
					$('.diff.raw',dialog).click(function(){
						$(dialog).html($('<pre class="diff pre"></pre>').html($("<div/>").text(response.raw).html()));
					});
					var maxWidth = $(window).width() - 200;
					var maxHeight = $(window).height() - 200;
					dialog.css({ "max-width":maxWidth+"px", "max-height" : maxHeight+"px", "overflow":"auto"});
					dialog.dialog({modal: true, width: "auto", height: "auto", maxWidth: maxWidth , maxHeight: maxHeight, resizeStart : function() {  
						var maxWidth = $(window).width() - 200;
						var maxHeight = $(window).height() - 200;
						dialog.css({ "max-width":maxWidth+"px", "max-height" : maxHeight+"px", "overflow":"auto"});
						dialog.dialog("option", "maxWidth", maxWidth);
						dialog.dialog("option", "maxHeight", maxHeight)
					}});
				}
		});

	});
	$(".action.diff,.listaction.diff").addClass('disabled');
	$("#flt").on("fileListSelChanged",function() {
		$(".action.diff,.listaction.diff").toggleClass('disabled', $("#fileList tr.selected").length!=2);
	});
});