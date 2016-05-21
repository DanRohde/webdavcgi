/*********************************************************************
(C) ZE CMS, Humboldt-Universitaet zu Berlin
Written 2016 by Daniel Rohde <d.rohde@cms.hu-berlin.de>
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
	$(".action.feedback").on("click", function(ev) {
		ToolBox.preventDefault(ev);
		if ($(this).hasClass("disabled")) return false;
		$(".action.feedback").addClass("disabled");
		

		ToolBox.getDialog({action: "feedback"}, function(resp) {
			var dialog = $(resp);
			$("#feedback_screenshot_reset",dialog).button().hide().on("click",function() {
				$("#feedback_screenshot_reset",dialog).hide();
				$("#feedback_screenshot_img",dialog).val("");
				var p = $("#feedback_screenshot_preview",dialog);
				p.attr("src", p.data("src"));
				$("#feedback_screenshot_preview_link",dialog).attr({href: "#", tabindex:-1});
				$("#feedback_take_screenshot",dialog).show().focus();
			});
			$("#feedback_take_screenshot",dialog).button().on("click", function() {
				var self = $(this);
				self.attr("disabled", true);
				$(".feedbackdialog").hide();
				$("body").append($("<div/>").addClass("feedback-wait"));
				$(".feedback-shutter").prop("currentTime",0).trigger("play");
				html2canvas(document.body, {
					onrendered: function(canvas) {
						$(".feedbackdialog").show();
						var data = canvas.toDataURL();
						$("#feedback_screenshot_preview", dialog).attr("src", data);
						$("#feedback_screenshot_preview_link", dialog).attr({href: data, tabindex: 0});
						$("#feedback_screenshot_img", dialog).val(data);
						$("#feedback_screenshot_reset",dialog).show().focus();
						$("#feedback_take_screenshot",dialog).hide();
						self.attr("disabled", false);
						$(".feedback-wait").addClass("flash");
						window.setTimeout(function() { $(".feedback-wait").remove(); }, 250);
					}
				});
				
			});
			$("#feedback_cancel",dialog).button().on("click", function() {
				dialog.dialog("close");
				$(".action.feedback").removeClass("disabled");
			});
			$("#feedback_submit",dialog).button().on("click", function() {
				if ($("#feedbackmsg",dialog).val().match(/^\s*$/)) {
					ToolBox.notifyError($("#feedback_missing_message").html());
					$("#feedbackmsg", dialog).addClass("missing").focus();
					return;
				}
				$.post(window.location.pathname, $("#feedbackform").serialize(), function(resp) {
					ToolBox.handleJSONResponse(resp);
					if (!resp.error && !resp.message) {
						ToolBox.notifyError($("#feedback_error").html());
					} else if (!resp.error) dialog.dialog("close");
					if (resp.required) $("#feedbackmsg", dialog).addClass("missing").focus();
				});
			});
			dialog.dialog({width:"auto",height:"auto", dialogClass:"feedbackdialog", closeText: $("#close").html(),
				beforeClose: function() {
					$(".action.feedback").removeClass("disabled");
				},
				open: function() { dialog.MyTooltip(500); },
				close: function() { dialog.dialog("destroy"); }
			});
			
		});
		return false;
	});
});