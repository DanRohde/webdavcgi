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
	$(".action.markcolorpicker").iris({hide:true, palettes:true, color: "#ff0000", change: function(e,ui) {
		var self = $(this);
		$("td,a.changeuri",ToolBox.getSelectedRows(self)).css(self.data("style"), ui.color.toString());
		window.clearTimeout(self.data("timeout"));
		self.data("timeout", window.setTimeout(function() {
			saveHighlight(ToolBox.getSelectedFiles(self), self.data("style"), ui.color.toString());
		}, 2000));
	}});
	$("body").on("fileActionEvent", function(event,data) {
		if (data.obj.hasClass("mark")) {
			var self = $(data.obj);
			var files = ToolBox.getSelectedFiles(data.obj);
			var rows = ToolBox.getSelectedRows(data.obj);
			$("td,a.changeuri",rows).css(self.data("style"), self.data("value"));
			ToolBox.hidePopupMenu();
			saveHighlight(files, self.data("style"), self.data("value"));
		} else if (data.obj.hasClass("removemark")) {
			var self = $(data.obj);
			var files = ToolBox.getSelectedFiles(data.obj);
			var rows = ToolBox.getSelectedRows(data.obj);
			$("td,a.changeuri",rows).css(self.data("style"), "");
			ToolBox.hidePopupMenu();
			$.post(window.location.pathname, { action: 'removemark', style: self.data("style"), files: files }, myResponseHandler);
		} else if (data.obj.hasClass("markcolorpicker")) {
			data.obj.iris('toggle');
		}
	});
	$("#flt").on("fileListChanged", function() {
		$(".highlighter-highlighted").each(function(i,v) {
			var self = $(v);
			var data = self.data('highlighter');
			for (var attr in data) {
				$("td,a.changeuri", self).css(attr, data[attr]);
			}
		});
	});
	function myResponseHandler(response) {
		ToolBox.handleJSONResponse(response);
		if (response.error) oolBox.updateFileList();
	}
	function saveHighlight(files,style,value) {
		$.post(window.location.pathname, { action : 'mark',  style: style, value: value, files : files}, myResponseHandler);
	}
	
});