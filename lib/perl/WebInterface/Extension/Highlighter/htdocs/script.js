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
(function ( $ ) {
$(document).ready(function() {
	$(".action.markcolorpicker").iris({hide:true, palettes:true, color: "#ff0000", change: function(e,ui) {
		var self = $(this);
		if (self.data("quiet")) { self.data("quiet",false); return; }
		setCss(ToolBox.getSelectedRows(self), self.data("style"), ui.color.toString());
		window.clearTimeout(self.data("timeout"));
		self.data("timeout", window.setTimeout(function() {
			setHighlighterData(ToolBox.getSelectedRows(self), self.data("style"), ui.color.toString());
			saveHighlight(ToolBox.getSelectedFiles(self), self.data("style"), ui.color.toString());
		}, 2000));
	}});
	$(".action.mark").on("click", function(event) {
		$.MyPreventDefault(event);
		var self = $(this);
		var files = ToolBox.getSelectedFiles(this);
		var rows  = ToolBox.getSelectedRows(this);
		var style = self.data("style");
		var value = self.data("value");
		setCss(rows, style, value);
		setHighlighterData(rows, style, value);
		saveHighlight(files, style, value);
	});
	$(".action.removemarks").on("click", function(event) {
		$.MyPreventDefault(event);
		var self = $(this);
		var files = ToolBox.getSelectedFiles(this);
		var rows = ToolBox.getSelectedRows(this);
		var styles = self.data("styles").split(",");
		for (var i=0; i<styles.length; i++) {
			setCss(rows, styles[i],"");
			removeHighlighterData(rows, styles[i]);
		}
		$.MyPost(window.location.pathname, { action: "removemarks", styles: self.data("styles"), files:files}, myResponseHandler, true);

	});
	$(".action.markcolorpicker").on("click", function(event) {
		$.MyPreventDefault(event);
		$(this).iris("toggle");
	});
	$(".action.replacemarks").on("click", function(event) {
		$.MyPreventDefault(event);
		var self = $(this);
		var files = ToolBox.getSelectedFiles(this);
		var rows = ToolBox.getSelectedRows(this);
		var data  = $(window).data("highlighter.transfer");
		if (data) {
			$(".action.replacemarks").removeClass("active");
			var styles = self.data("styles").split(",");
			for (var i = 0; i<styles.length; i++) {
				setCss(rows, styles[i],"");
				removeHighlighterData(rows, styles[i]);
			}
			for (var a in data) {
				setHighlighterData(rows, a, data[a]);
				setCss(rows,a,data[a]);
			}
			$.MyPost(window.location.pathname, { action: "replacemarks", files: files, style: JSON.stringify(data)}, myResponseHandler, true);
			$(window).removeData("highlighter.transfer");
		} else {
			$(".action.replacemarks").addClass("active");
			$(window).data("highlighter.transfer", getMarks(rows));
		}
	});
	$(".action.savemarksaspreset").on("click", function(event) {
		$.MyPreventDefault(event);
		var self = $(this);
		var rows = ToolBox.getSelectedRows(this);
		var name = window.prompt(self.data("name"));
		if (name && name.trim() != "") {
			$.MyPost(window.location.pathname, { action: "savemarksaspreset", name: name, data: JSON.stringify(getMarks(rows))}, function(response) { 
				myResponseHandler(response);
				handlePresetChanges();
			}, true);
		}
	});
	initPresetActions();
	$("#flt").on("fileListChanged", highlightRows);
	$("#foldertree").on("foldertreeChanged", highlightRows);
	highlightRows();
	$("#flt").on("popupmenu", function(e,row) {
		if ($(row).hasClass("highlighter-highlighted")) {
			$(".action.markcolorpicker").each(function(i,v) {
				var color = $($(row).data("highlighter")).attr($(v).data("style"));
				if (color) { 
					$(v).data("quiet",true);
					$(v).iris("option","color", color);
				}
			});
		}
	});
	function initPresetActions() {
		$(".action.markwithpreset").off("click.highlighter").on("click.highlighter", function(event) {
			$.MyPreventDefault(event);
			var self = $(this);
			var rows = ToolBox.getSelectedRows(this);
			var styles = $(".highlighter-popup .removemarks").last().data("styles").split(",");
			for (var i = 0; i<styles.length; i++) {
				setCss(rows, styles[i],"");
				removeHighlighterData(rows, styles[i]);
			}
			styles = self.data("style");
			for (var style in styles) {
				setHighlighterData(rows, style, styles[style]);
				setCss(rows,style,styles[style]);
			}
			$.MyPost(window.location.pathname, { action: "replacemarks", style: JSON.stringify(self.data("style")), files: ToolBox.getSelectedFiles(this)}, myResponseHandler, true);
		});
		$(".action.managepresets").off("click.highlighter").on("click.highlighter", function(event) {
			$.MyPreventDefault(event);
			var self = $(this);
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
					$.MyPreventDefault(ev);
					var self = $(this);
					var preset = self.data("preset");
					ToolBox.confirmDialog(self.data("confirm").replace("%s",preset), {
						confirm: function() {
							self.parent(".highlighter-preset-entry").remove();
							$.MyPost(window.location.href, { action: "deletepreset", preset: preset}, function(response) {
								myResponseHandler(response);
								if (response.error) window.location.reload(true);
								else dialog.data("changes",true);
							});
						}
					});
				});
				$("#highlighter-preset-manager-entries",dialog).append(entry);
			}
			dialog.dialog({modal:true, width: "auto", dialogClass: "managepresets", 
				closeText: $("#close").html(), 
				close: function() { if (dialog.data("changes")) handlePresetChanges(); }});
			dialog.MyTooltip(500);
		});
	}
	function handlePresetChanges() {
		$.MyPost(window.location.pathname, {}, function(resp) {
			$(".toolbar .highlighter.subpreset").html($(".toolbar .highlighter.subpreset", resp).html());
			$("#popupmenu .highlighter.subpreset").html($("#popupmenu .highlighter.subpreset", resp).html());
			initPresetActions();
		}, true);
	}
	function getMarks(rows) {
		var data = {};
		rows.filter(".highlighter-highlighted").each(function(i,v) {
			var s = $(v);
			var d = s.data("highlighter");
			for (var a in d) {
				data[a]= d[a];
			}
		});
		return data;
	}
	function setCss(row, style, data) {
		var nodes = WebDAVCGI.foldertree.getFolderTreeNodesForRows(row);
		_setCss(row, style, data);
		_setCss(nodes, style, data);
	}
	function _setCss(row, style, data) {
		if (row.hasClass("mft-node")) {
			row.find(".mft-node-label:first").css(style, data);
			return row;
		}
		if (style == "background" || style.match(/^border/)!=null ) {
			row.css(style,data);
		} else if ( style == "transform" ) {
			$("td", row).css(style,data);
		} else {
			$("td", row.css(style,data)).css(style,data);
		}
		return row;
	}
	function highlightRows() {
		$(".highlighter-highlighted").each(function(i,v) {
			var self = $(v);
			var data = self.data("highlighter");
			for (var attr in data) {
				_setCss(self,attr, data[attr]);
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
		var nodes = WebDAVCGI.foldertree.getFolderTreeNodesForRows(rows);
		rows.data("highlighter",jsondata);
		nodes.data("highlighter",jsondata);
		return true;
	}
	function setHighlighterData(rows, style, color) {
		var jsondata = rows.data("highlighter");
		if (!jsondata) jsondata={};
		jsondata[style] = color;
		var nodes = WebDAVCGI.foldertree.getFolderTreeNodesForRows(rows);
		rows.data("highlighter", jsondata).addClass("highlighter-highlighted");
		nodes.data("highlighter", jsondata).addClass("highlighter-highlighted");
	}
	function saveHighlight(files,style,value) {
		$.MyPost(window.location.pathname, { action : "mark", style: style, value: value, files : files}, myResponseHandler, true);
	}
});
}( jQuery ));