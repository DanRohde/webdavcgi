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
		var history = body.data("history") || restoreHistory() || new Array();
		var uri = $("#fileList").data("uri") || window.location.pathname;
		
		var idx=-1;
		if ((idx=history.indexOf(uri))>-1) history.splice(idx,1); 
		if (history.length>=10) history.shift();
		history.push(uri);
		
		body.data("history", history);
		body.trigger("history.changed", { history: history});
	});
	
	body.on("history.changed", function(e,d) {
		saveHistory(d.history);
		buildHistoryPopup(d.history);
	});
	
	function saveHistory(history) {
		ToolBox.cookie("history", JSON.stringify(history), 1);
	}
	function restoreHistory() {
		return ToolBox.cookie("history") ? $.parseJSON(ToolBox.cookie("history")) : new Array();
	}
	function buildHistoryPopup(history) {
		var p = $(".history-popup .subpopupmenu");
		p.empty();
		var currentUri = $("#fileList").data("uri");
		for (var i=history.length; i--; i >= 0 ) {
			var text = history[i];
			if (text.length > 34) text = '/...'+history[i].substr(-30);
			var he = $("<li/>").addClass("action changeUri history icon category-folder suffix-folder").attr("title",decodeURIComponent(history[i])).data("uri",history[i]).html(decodeURIComponent(text));
			if (history[i] == currentUri) he.addClass("disabled");
			p.append(he);
		}
		p.find(".action.changeUri").click(function() { ToolBox.changeUri($(this).data("uri")) });
		p.MyTooltip(250);
	}
	
});