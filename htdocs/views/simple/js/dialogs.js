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
function confirmDialog(text, data) {
	var oldsetting;
	if (data.setting) {
		text+='<div class="confirmdialogsetting"><input type="checkbox" name="'+data.setting+'"/> '+$("#confirmdialogsetting").html()+"</div>";
		oldsetting = $.MyCookie(data.setting);
	}
	$("#confirmdialog").html(text).dialog({  
		modal: true,
		width: 500,
		height: "auto",
		title: $("#confirmdialog").attr("data-title"),
		closeText: $("#close").html(),
		dialogClass: "confirmdialog",
		buttons: [ 
			{ 
				text: $("#cancel").html(), 
				click: function() {
					if (data.setting) {
						$.MyCookie.toggleCookie(data.setting, oldsetting, oldsetting && oldsetting!=="",1);
					}
					$("#confirmdialog").dialog("close");  
					if (data.cancel) data.cancel();
				} 
			}, 
			{ 	
				text: "OK", 
				click: function() { 
					$("#confirmdialog").dialog("close");
					if (data.confirm) data.confirm();
				} 
			},
		],
		open: function() {
			if (data.setting) {
				$("input[name='"+data.setting+"']",$(this)).click(function() {
					$.MyCookie.toggleCookie(data.setting, "no", !$(this).is(":checked"), 1);
				}).prop("checked", $.MyCookie(data.setting)!="no");
			}
		},
		close: function() {
			if (data.cancel) data.cancel();
		}
	}).show();
}

function renderAbortDialog(xhr, timeout, handler) {
	$("#abortdialog").remove();
	var dialog = $("<div/>").html($("#abortdialogtemplate").html()).attr("id","abortdialog");
	$(".action.cancel",dialog).button().click(function(){
		if (xhr.readyState !=4) xhr.abort();
		dialog.hide().remove();
		if (handler) handler.call(this);
	});
	$("body").data("abortdialogtimeout",window.setTimeout(function() {
		if (xhr.readyState > 2) return;
		dialog.appendTo($("body")).show();
		var interval = window.setInterval(function() {
			if (xhr.readyState == 4) {
				dialog.hide().remove();
				window.clearInterval(interval);
			}
		}, 200);
		$("body").data("abortdialoginterval",interval);
		
	}, timeout || 2500));
	return dialog;
}
function removeAbortDialog() {
	window.clearTimeout($("body").data("abortdialogtimeout"));
	window.clearInterval($("body").data("abortdialoginterval"));
	$("#abortdialog").hide().remove();
}
