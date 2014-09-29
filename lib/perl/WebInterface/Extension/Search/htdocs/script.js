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
	function handleFileListChanges() {
		var flt = $("#fileListTable");
		$("#apps .action.search").toggleClass("disabled", flt.hasClass("unselectable-yes") || flt.hasClass("isreadable-no"));
	}
	$("#flt").on("fileListChanged", handleFileListChanges);
	handleFileListChanges();
	var flt = $("#fileListTable");
	$("#apps .action.search").toggleClass("disabled", flt.hasClass("unselectable-yes") || flt.hasClass("isreadable-no"));
	
	$(".action.search").click(function(event) {
		ToolBox.preventDefault(event);
		if ($(this).hasClass("disabled")) return;
		openSearchDialog();
	});

	if ($.QueryString["action"] == 'search') {
		openSearchDialog();
	}
	
	function openSearchDialog() {
		$(".action.search").addClass("disabled");
		$.get(window.location.pathname, { action: "getSearchForm", files: ToolBox.getSelectedFiles(this) }, function(response) {
			var dialog = $(response);
			initSearchDialog(dialog);
			dialog.dialog({ width: "auto", height: "auto", maxWidth: $(window).width()-100, closeText: $("#close").html(), 
				beforeClose: function() { $("#flt").off('fileListChanged', null, dialog.fileListChangedHandler); doFinalActions(dialog);}});
			$(".action.search").removeClass("disabled");
			dialog.MyTooltip(500);
		});
	}
	function toggleSearch(dialog, on) {
		if (on) {
			$("input.search.start,input.search.query", dialog).removeAttr("disabled");	
		} else {
			$("input.search.start,input.search.query", dialog).attr("disabled","disabled");
		}
	}
	function doFinalActions(dialog) {
		dialog.data('completed',1);
		if (dialog.data("resultpoll")) {
			window.clearTimeout(dialog.data("resultpoll"));
			dialog.removeData("resultpoll");
		}
		if (dialog.data("postXHR")) { 
			dialog.data("postXHR").abort();
			dialog.removeData("postXHR");
		}
		$("input.search.cancel",dialog).attr("disabled","disabled");
		toggleSearch(dialog,true);
		dialog.removeClass("searchinprogress");
	}
	function initSearchDialog(dialog) {
		dialog.fileListChangedHandler = function() {
			var flt = $("#fileListTable");
			toggleSearch(dialog,  !flt.hasClass("unselectable-yes") && !flt.hasClass("isreadable-no"));
		};
		$(".search.resultcontentpane", dialog).css("max-height", ($(window).height()-310 > 310 ? $(window).height()-310 : 350)+'px');
		$("#flt").on("fileListChanged", dialog.fileListChangedHandler);
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
			toggleSearch(dialog, false);
			$(".search.statusbar", dialog).html($(".msg.search.inprogress").html());
			$(".search.resultcontentpane",dialog).html("");
			dialog.addClass("searchinprogress")
			startResultPoll(dialog);
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
		
		if ($.QueryString["action"] == "search") {
			dialog.find("input[name=query]").val($.QueryString["query"]);
			var searchin = $.QueryString["searchin"] == "content" ? "content" : "filename";
			dialog.find("input[name=searchin][value="+searchin+"]:enabled").attr("checked","checked");
			dialog.find("form").submit();
		}
		
	} 
	function startResultPoll(dialog) {
		dialog.data("resultpoll", window.setTimeout(function() {
			$.get(window.location.pathname, { action: "getSearchResult", searchid : $('input.search.id', dialog).val()}, 
					function(response) { 
						if (!dialog.data('completed')) {
							handleResultResponse(response,dialog);
							startResultPoll(dialog);
						}
					}
			);
		}, 2000));
	}
	function handleResultResponse(response,dialog) {
		if (response.error) return;
		ToolBox.handleJSONResponse(response);
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
		$('a.search.result.entry',result).hover(function() {
			var self = $(this);
			if (self.data("timeout")) window.clearTimeout(self.data("timeout"));
			$(".search.result.fileuri",self.parent()).show();
		}, function() {
			var self = $(this);
			window.clearTimeout(self.data("timeout"));
			self.data("timeout",window.setTimeout(function() {
				$(".search.result.fileuri",self.parent()).hide(5000);
			},5000));
			
		});
		result.MyTooltip();
	}
	
});