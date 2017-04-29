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
		if ($(this).hasClass("disabled")) return;
		openSearchDialog(ToolBox.getSelectedFiles(this));
	});
	
	if ($.QueryString.action == 'search' && !$("#fileListTable").hasClass("unselectable-yes")) {
		openSearchDialog();
	}
	
	function openSearchDialog(files) {
		$(".action.search").addClass("disabled");
		$.MyPost(window.location.pathname, { action: "getSearchForm", files: files }, function(response) {
			var dialog = $(response);
			initSearchDialog(dialog);
			var w = $(window);
			$(".search.resultcontentpane",dialog).css("max-height",(w.height()*0.85)+"px");
			dialog.dialog({ width: w.width()*0.8, height: "auto", closeText: $("#close").html(), dialogClass: "search",
				beforeClose: function() { $("#flt").off('fileListChanged', null, dialog.fileListChangedHandler); doFinalActions(dialog);}});
			$(".action.search").removeClass("disabled");
			dialog.MyTooltip();
			$(".contexthelp").MyContextHelp();
		});
	}
	function toggleSearch(dialog, on) {
		if (on) {
			$("input.search.start,input.search.query", dialog).removeAttr("disabled");	
		} else {
			$("input.search.start,input.search.query", dialog).attr("disabled","disabled");
		}
		$("input.search.start", dialog).button("option","disabled", !on);
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
		$("input.search.cancel",dialog).attr("disabled","disabled").button("option","disabled",true);
		toggleSearch(dialog,true);
		dialog.removeClass("searchinprogress");
	}
	function initSearchDialog(dialog) {
		$("input[type=submit], input[type=button]",dialog).button();
		dialog.fileListChangedHandler = function() {
			var flt = $("#fileListTable");
			toggleSearch(dialog,  !flt.hasClass("unselectable-yes") && !flt.hasClass("isreadable-no"));
		};
		//$(".search.resultcontentpane", dialog).css("max-height", ($(window).height()-310 > 310 ? $(window).height()-310 : 350)+'px');
		$("#flt").on("fileListChanged", dialog.fileListChangedHandler);
		$("input.search.cancel",dialog).attr("disabled", "disabled").button("option","disabled",true).click(function() {
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
			$("input.search.cancel", dialog).removeAttr("disabled").button("option","disabled",false);
			toggleSearch(dialog, false);
			$(".search.statusbar", dialog).html($(".msg.search.inprogress").html());
			$(".search.resultcontentpane",dialog).html("");
			dialog.addClass("searchinprogress");
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
		
		if ($.QueryString.action == "search" && !$("#fileListTable").hasClass("unselectable-yes")) {
			dialog.find("input[name=query]").val($.QueryString.query);
			var searchin = $.QueryString.searchin == "content" ? "content" : "filename";
			dialog.find("input[name=searchin][value="+searchin+"]:enabled").attr("checked","checked");
			dialog.find("form").submit();
		}
		$(".search-result-thumb-view-toggle-button", dialog).on("click", function() {
			$(".search.resultpanel").toggleClass("search-result-thumb-view");
			$(this).toggleClass("ai-flt-view-thumbs").toggleClass("ai-flt-view-list")
		});
	} 
	function startResultPoll(dialog) {
		dialog.data("resultpoll", window.setTimeout(function() {
			$.MyPost(window.location.pathname, { action: "getSearchResult", searchid : $('input.search.id', dialog).val()}, 
					function(response) { 
						if (!dialog.data('completed')) {
							handleResultResponse(response,dialog);
							startResultPoll(dialog);
						}
					}, true
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
		$('.entry-info.folder,.parent.folder',result).click(function() {
			ToolBox.changeUri($(this).attr("data-href"));
		});
		$('.entry-info.file',result).click(function(event) {
			if (event.target != this && $(event.target).hasClass("thumbnail")) return;
			window.open($(this).attr("data-href"),"_blank");
		})
		$('img', result).off("error.search").on("error.search", function() {
			var self = $(this);
			self.removeClass("thumbnail").attr("src",$("#emptyimage").attr("src"));
		});
		result.MyTooltip({showtimeout:-1,hidetimeout:-1});
		result.find(".icon.thumbnail")
		.attr({"data-fancybox":"searchresultgallery"})
		.each(function(i,item) {
			var $item = $(item);
			$item.data({
				caption: $item.siblings(".label").html(),
				src: $item.attr("src").replace(/\?action=thumb$/,"")
			});
		})
		.fancybox();
	}
	
});
