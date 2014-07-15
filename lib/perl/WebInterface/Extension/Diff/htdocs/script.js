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
					function initButtons() {
						$('.diff.raw',dialog).click(function(){
							$(dialog).html($(response.raw));
							initButtons();
						});	
						$('.diff.formatted',dialog).click(function() {
							$(dialog).html($(response.content));
							initButtons();
						});
						$('.diff.formatted,.diff.raw').mousedown(function() { $(this).addClass('clicked'); }).mouseup(function(){ $(this).removeClass("clicked")}).mouseout(function() { $(this).removeClass("clicked")});
					}
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
					initButtons();
				}
		});

	});
	$(".action.diff,.listaction.diff").addClass('disabled');
	$("#flt").on("fileListSelChanged",function() {
		$(".action.diff,.listaction.diff").toggleClass('disabled', $("#fileList tr.selected").length!=2);
	});
});