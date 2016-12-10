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
		if (self.data("quiet")) { self.data("quiet",false); return; }
		$("td,a.changeuri",ToolBox.getSelectedRows(self)).css(self.data("style"), ui.color.toString());
		window.clearTimeout(self.data("timeout"));
		self.data("timeout", window.setTimeout(function() {
			setHighlighterData(ToolBox.getSelectedRows(self), self.data("style"), ui.color.toString());
			saveHighlight(ToolBox.getSelectedFiles(self), self.data("style"), ui.color.toString());
		}, 2000));
	}});
	$("body").on("fileActionEvent", function(event,data) {
		var self = $(data.obj);
		if (data.obj.hasClass("mark")) {
			var files = ToolBox.getSelectedFiles(data.obj);
			var rows = ToolBox.getSelectedRows(data.obj);
			$("td,a.changeuri",rows).css(self.data("style"), self.data("value"));
			ToolBox.hidePopupMenu();
			setHighlighterData(rows, self.data("style"), self.data("value"));
			saveHighlight(files, self.data("style"), self.data("value"));
		} else if (data.obj.hasClass("removemarks")) {
			var files = ToolBox.getSelectedFiles(data.obj);
			var rows = ToolBox.getSelectedRows(data.obj);
			var styles = self.data("styles").split(",");
			for (var i=0; i<styles.length; i++) {
				$("td,a.changeuri",rows).css(styles[i],"");
				removeHighlighterData(rows, styles[i]);
			}
			ToolBox.hidePopupMenu();
			$.post(window.location.pathname, { action: 'removemarks', styles: self.data("styles"), files:files}, myResponseHandler);
		} else if (data.obj.hasClass("markcolorpicker")) {
			data.obj.iris('toggle');
		} else if (data.obj.hasClass("transfermarks")) {
			var files = ToolBox.getSelectedFiles(data.obj);
			var rows = ToolBox.getSelectedRows(data.obj);
			var data  = $(window).data("highlighter.transfer");
			ToolBox.hidePopupMenu();
			if (data) {
				$(".action.transfermarks").removeClass("active");
				var styles = self.data("styles").split(",");
				for (var i = 0; i<styles.length; i++) {
					$("td,a.changeuri",rows).css(styles[i],"");
					removeHighlighterData(rows, styles[i]);
				}
				for (var a in data) {
					setHighlighterData(rows, a, data[a]);
					$("td,a.changeuri",rows).css(a,data[a]);
				}
				$.post(window.location.pathname, { action: 'transfermarks', files: files, style: JSON.stringify(data)}, myResponseHandler);
				$(window).removeData("highlighter.transfer");
			} else {
				$(".action.transfermarks").addClass("active");
				$(window).data("highlighter.transfer", getMarks(rows));
			}
		} else if (data.obj.hasClass("savemarksaspreset")) {
			var rows = ToolBox.getSelectedRows(data.obj);
			var name = window.prompt(self.data("name"));
			if (name && name.trim() != "") {
				$.post(window.location.pathname, { action: "savemarksaspreset", name: name, data: JSON.stringify(getMarks(rows))}, function(response) { 
					myResponseHandler(response);
					window.location.reload(true);
				});
			}
		} else if (data.obj.hasClass("markwithpreset")) {
			var rows = ToolBox.getSelectedRows(data.obj);
			var styles = self.data("style");
			for (var style in styles) {
				setHighlighterData(rows, style, styles[style]);
				$("td,a.changeuri",rows).css(style,styles[style]);
			}
			$.post(window.location.pathname, { action: "transfermarks", style: JSON.stringify(self.data("style")), files: ToolBox.getSelectedFiles(data.obj)}, myResponseHandler);
		} else if (data.obj.hasClass("managepresets")) {
			var dialog = $(self.data("template"));
			var entrytmpl = $("#highlighter-preset-manager-preset-template",dialog).html();
			var presets = self.data("presets");
			var sortedPresetKeys = Object.keys(presets).sort();
			for (var i = 0; i < sortedPresetKeys.length; i++) { 
				var preset = sortedPresetKeys[i];
				var styles = presets[preset];
				var entry = $(entrytmpl);
				$(".highlighter-preset-entry-name", entry).text(preset).attr("title",preset+": "+styles).css(JSON.parse(styles));
				$(".highlighter-preset-entry-delete", entry).attr("data-preset",preset).on("click", function(ev) {
					ToolBox.preventDefault(ev);
					var self = $(this);
					var preset = self.data("preset");
					ToolBox.confirmDialog(self.data("confirm").replace('%s',preset), {
						confirm: function() {
							self.parent(".highlighter-preset-entry").remove();
							$.post(window.location.href, { action: "deletepreset", preset: preset}, function(response) {
								myResponseHandler(response);
								if (response.error) window.location.reload(true);
								else dialog.data("changes",true);
							});
						}
					});
				});
				$("#highlighter-preset-manager-entries",dialog).append(entry);
			}
			dialog.dialog({modal:true, width: 'auto', dialogClass: "highlighter-preset-manager-dialog", 
				closeText: $("#close").html(), dialogClass: "managepresets",
				close: function() { if (dialog.data("changes")) window.location.reload(true); }});
			dialog.MyTooltip(500);
		}
	});
	$("#flt").on("fileListChanged", highlightRows);
	highlightRows();
	$("#flt").on("popupmenu", function(e,row) {
		if ($(row).hasClass('highlighter-highlighted')) {
			$(".action.markcolorpicker").each(function(i,v) {
				color = $($(row).data("highlighter")).attr($(v).data("style"));
				if (color) { 
					$(v).data("quiet",true);
					$(v).iris("option","color", color);
				}
			});
		}
	});
	function getMarks(rows) {
		var data = Object();
		rows.filter(".highlighter-highlighted").each(function(i,v) {
			var s = $(v);
			var d = s.data('highlighter');
			for (var a in d) {
				data[a]= d[a];
			}
		});
		return data;
	}
	function highlightRows() {
		$(".highlighter-highlighted").each(function(i,v) {
			var self = $(v);
			var data = self.data('highlighter');
			for (var attr in data) {
				$("td,a.changeuri", self).css(attr, data[attr]);
			}
		});
	}
	function myResponseHandler(response) {
		ToolBox.handleJSONResponse(response);
		if (response.error) ToolBox.updateFileList();
	}
	function removeHighlighterData(rows, style) {
		var jsondata = rows.data("highlighter"); 
		if (!jsondata) return false;
		delete jsondata[style];
		rows.data("highlighter",jsondata);
		return true;
	}
	function setHighlighterData(rows, style, color) {
		var jsondata = rows.data("highlighter");
		if (!jsondata) jsondata=new Object();
		jsondata[style] = color;
		rows.data("highlighter", jsondata).addClass("highlighter-highlighted");
	}
	function saveHighlight(files,style,value) {
		$.post(window.location.pathname, { action : 'mark',  style: style, value: value, files : files}, myResponseHandler);
	}
	
	
});