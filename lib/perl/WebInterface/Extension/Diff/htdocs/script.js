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