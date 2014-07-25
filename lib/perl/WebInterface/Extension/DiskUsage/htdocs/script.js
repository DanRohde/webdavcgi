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
	// handle file actions:
	$("body").on("fileActionEvent", function(event,data) {
		if (data.obj.hasClass("disabled")) return;
		if (data.obj.hasClass("diskusage") && data.obj.hasClass("listaction")) {
			var selrows = $("#fileList tr.selected.is-dir:visible");
			var files = selrows.length>0 ? $.map(selrows, function(val,i) { return $(val).attr("data-file")}) : new Array(!data.file ? '' : data.file);
			du_dialog(files);
		} else if (data.obj.hasClass("diskusage")) {
			du_dialog(new Array(data.file));
		}
	});
	$("#flt").on("fileListChanged", function() {
		var flt = $("#fileListTable");
		$("#apps .listaction.diskusage").toggleClass("disabled", flt.hasClass("unselectable-yes") || flt.hasClass("isreadable-no"));
	});
	function du_dialog(files) {
		$(".action.diskusage").addClass("disabled");
		var block=du_blockPage();
		var xhr = $.post($("#fileList").attr("data-uri"),{action: "diskusage", file: files}, function (response) {
			var dialog = $(response);
			block.remove();
			var ch = function(event) {
				window.location.href = $("a",$(this)).attr("href");
			};
			$("tr.diskusage.entry", dialog).dblclick(ch).click(ch);
			dialog.dialog({modal: true, width: "auto", height: "auto", maxWidth: $(window).width()-100, resizable: true, 
					open: function() { du_initAccordion(dialog); du_initTreemap(dialog);}, 
					close: function() { dialog.dialog("destroy")}});			
			$(".action.diskusage").removeClass("disabled");
		});
		ToolBox.renderAbortDialog(xhr);
	}
	function du_initAccordion(dialog) {
		$(".accordion",dialog).accordion({collapsible: true, active: false, heightStyle:"content"});
	}
	function du_initTreemap(dialog) {
		$(".treemappanel",dialog).each(function(i,v) {
			console.log($(v).data("mapdata"));
			var myLocation = ToolBox.stripSlash(window.location.pathname);
			var cache = new Array();
			$(v).treemap({ "dimensions": [800,600], "nodeData": $(v).data("mapdata"), 
				"colorStops" :[ { "val":0, "color":"#aa0000" }, {"val":0.1,"color":"#aa1a00"}, { "val":0.2, "color":"#aaaa00" }, { "val":0.4, "color":"#00aa00" },
				                { "val":0.6, "color":"#0000aa" }, { "val":0.8, "color":"#4b0082" }, {  "val":0.9, "color":"#4b0082"}, { "val":1, "color":"#8b00ff" },]	})
				.on("treemapclick", function(event, data) { ToolBox.changeUri(myLocation+'/'+data.nodes[0].uri)})
				.on("treemapmousemove", function(event,data) {
					var el;
				
					if (cache["el"]) { 
						el = cache["el"];
					} else { 
						el = $('<div/>').appendTo(dialog).addClass("diskusage treemap tooltip");
						cache["el"] = el;
					}
					if (data.nodes[0].title) {
						window.clearTimeout(cache["timeout"]);
						el.html(data.nodes[0].id+": "+ data.nodes[0].val+"<br/>"+data.nodes[0].title.split(", ").join("<br/>"));
						var offset = dialog.offset();
						var elWidth = el.width(); 
						var elHeight = el.height();
						var left = event.pageX-offset.left + 4;
						var top = event.pageY -offset.top + 4;
						var treemapWidth = $(v).width();
						var treemapHeight = $(v).height();
						var treemapOffset = $(v).offset();
						if (event.pageX + elWidth + 4> treemapOffset.left + treemapWidth) left-=elWidth+8;
						if (event.pageY + elHeight + 4> treemapOffset.top + treemapHeight) top-=elHeight+8;
						el.css({"position" : "absolute", "top" : top+"px","left":left+"px"}).show();
					}
					
				})
				.on("mouseout", function(){
					window.clearTimeout(cache["timeout"]);
					cache["timeout"] = window.setTimeout(function() {cache["el"].hide(500)}, 5000)
				});
			$(".treemap.bysize",$(v).parent()).button().on("click", function() {
				$(v).treemap("option","sizeOption",0);
			});
			$(".treemap.byfilecount", $(v).parent()).button().on("click", function() {
				$(v).treemap("option","sizeOption",1);
			});
			
		});
	}
	function du_blockPage() {
		return $("<div></div>").prependTo("body").addClass("overlay");
	}
});