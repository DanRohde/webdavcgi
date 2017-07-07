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
	var body = $("body");
	$("#flt").on("fileListChanged", function() {
		var history = restoreHistory() || [];
		var uri = $("#fileList").data("uri") || window.location.pathname;
		
		var idx=-1;
		if ((idx=history.indexOf(uri))>-1) history.splice(idx,1); 
		if (history.length>=10) history.shift();
		history.push(uri);
		
		body.trigger("history.changed", { history: history});
	});
	
	body.on("history.changed", function(e,d) {
		buildHistoryPopup(saveHistory(d.history));
		$(".action.history-clear").toggleClass("disabled", d.history && d.history.length == 0);
	});
	
	$(".action.history-clear").click(function() {
		if (!$(this).hasClass("disabled")) {
			body.trigger("history.changed", { history: [] });
		}
	});
	
	function saveHistory(history) {
		if (history.length > 0) $.MyCookie("history", JSON.stringify(history), 1);
		else $.MyCookie.rmCookies("history");
		return history;
	}
	function restoreHistory() {
		return $.MyCookie("history") ? JSON.parse($.MyCookie("history")) : [];
	}
	function buildHistoryPopup(history) {
		var p = $(".history-popup-history");
		p.find('li.action.changeUri').remove();
		var currentUri = $("#fileList").data("uri");
		for (var i=0; i<history.length; i++ ) {
			var dtext = decodeURIComponent(history[i]);
			var dhistory = dtext;
			if (dtext.length > 34) dtext = '/...'+dhistory.substr(-30);
			var he = $("<li/>").addClass("action changeUri history icon category-folder suffix-folder").attr({title : dhistory, tabindex : 0}).data("uri",history[i]).html(ToolBox.quoteWhiteSpaces(dtext));
			if (history[i] == currentUri) he.addClass("disabled");
			p.prepend(he);
		}
		p.find(".action.changeUri:not(.disabled)").click(function() { ToolBox.changeUri($(this).data("uri")); }).MyKeyboardEventHandler();
		p.MyTooltip(250);
		return history;
	}
});
