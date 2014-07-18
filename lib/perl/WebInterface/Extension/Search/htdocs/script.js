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
	$("#flt").on("fileListChanged", function() {
		var flt = $("#fileListTable");
		$("#apps .action.search").toggleClass("disabled", flt.hasClass("unselectable-yes") || flt.hasClass("isreadable-no"));
	});
	var flt = $("#fileListTable");
	$("#apps .action.search").toggleClass("disabled", flt.hasClass("unselectable-yes") || flt.hasClass("isreadable-no"));
	
	$(".action.search").click(function(event) {
		ToolBox.preventDefault(event);
		if ($(this).hasClass("disabled")) return;
		$(".action.search").addClass("disabled");
		$.get(window.location.pathname, { ajax: "getSearchForm", files: ToolBox.getSelectedFiles(this) }, function(response) {
			var dialog = $(response);
			initSearchDialog(dialog);
			dialog.dialog({ width: "auto", height: "auto", minWidth: 620, beforeClose: function() { doFinalActions(dialog);}});
			$(".action.search").removeClass("disabled");
		});
		
	});
	function doFinalActions(dialog) {
		dialog.data('completed',1);
		if (dialog.data("resultpuller")) {
			window.clearInterval(dialog.data("resultpuller"));
			dialog.removeData("resultpuller");
		}
		if (dialog.data("postXHR")) { 
			dialog.data("postXHR").abort();
			dialog.removeData("postXHR");
		}
		$("input.search.cancel",dialog).attr("disabled","disabled");
		$("input.search.start,input.search.query", dialog).removeAttr("disabled");
		dialog.removeClass("searchinprogress");
	}
	function initSearchDialog(dialog) {
		
		$("input.search.cancel",dialog).attr("disabled", "disabled").click(function() {
			$(".search.statusbar",dialog).html($(".msg.search.aborted").html());
			dialog.data("postXHR").abort();
		});
		$(".search.moreoptionscollapser",dialog).click(function() {
			$(".search.moreoptions",dialog).toggle();
			$(this).toggleClass("uncollapsed", $(".search.moreoptions",dialog).is(":visible"));
		});
		$("form",dialog).submit(function() {
			var self = $(this);
			dialog.data('completed',0);
			var formdata = self.serialize();
			$("input.search.cancel", dialog).removeAttr("disabled");
			$("input.search.start,input.search.query", dialog).attr("disabled","disabled");
			$(".search.statusbar", dialog).html($(".msg.search.inprogress").html());
			$(".search.resultcontentpane",dialog).html("");
			dialog.addClass("searchinprogress")
			startResultPulling(dialog);
			dialog.data("postXHR", $.ajax( {
					type: "POST",
					url: window.location.pathname, 
					data: formdata, 
					success : function(response) { handleResultResponse(response, dialog); },
					error: function(jqXHR, textStatus, errorThrown) { handleResultResponse({ error: textStatus }, dialog); },
					complete: function() { doFinalActions(dialog); },
			}));
			return false;
		});
		
	} 
	function startResultPulling(dialog) {
		dialog.data("resultpuller",window.setInterval(function() {
			$.get(window.location.pathname, { ajax: "getSearchResult", searchid : $('input.search.id', dialog).val()}, function(response) { if (!dialog.data('completed')) handleResultResponse(response,dialog); });
		}, 2000));
	}
	function handleResultResponse(response,dialog) {
		if (response.error) return;
		if (response.data) {
			var data = $(response.data);
			$(".search.resultcontentpane",dialog).html(data);
			initResult(data);
		}
		if (response.status) $(".search.statusbar", dialog).html($("<div/>").text(response.status).html());
	}
	function initResult(result) {
		/*$('a', result).click(function(event) {
			ToolBox.preventDefault(event);
			return false;
		});*/
		$('a.search.result.entry.folder',result).click(function(event) {
			ToolBox.preventDefault(event);
			ToolBox.changeUri($(this).attr("href"));
			return false;
		});
	}
	
});