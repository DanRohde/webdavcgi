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
	function du_calculateColorStops(steps,brightness) {
		var colorStops = new Array();
		if (!brightness) brightness = 160;
		var f  = 1 / steps;
		var p = 2*Math.PI / steps;
		for (var i=0; i<=steps; i++) {
			var r = Math.abs(Math.round(Math.sin(p * i + Math.PI/2 ) * brightness ));
			var g = Math.abs(Math.round(Math.sin(p * i + Math.PI) * brightness ));
			var b = Math.abs(Math.round(Math.sin(p * i ) * brightness ));
			
			var rgb = b  | (g << 8) | (r << 16);
			var rgbs = rgb.toString(16);
			while(rgbs.length <6 ) rgbs+="0";
			if (rgbs.length>6) rgbs=rgbs.substr(0,6);
			colorStops.push( {"val": i*f, "color": "#"+rgbs });
		}
		return colorStops;
	}
	function du_initTreemap(dialog) {
		var colorStops = du_calculateColorStops(50);
		console.log( [ {"a":1,"b":2},{"a":2,"b":3} ]);
		console.log(colorStops);
		$(".treemappanel",dialog).each(function(i,v) {
			console.log($(v).data("mapdata"));
			var myLocation = ToolBox.stripSlash(window.location.pathname);
			var cache = new Array();
			$(v).treemap({ "dimensions": [800,600], "nodeData": $(v).data("mapdata"), 
				"colorStops" : colorStops	})
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
				$(v).treemap("option","colorOption",0);
			});
			$(".treemap.byfilecount", $(v).parent()).button().on("click", function() {
				$(v).treemap("option","sizeOption",1);
				$(v).treemap("option","colorOption",1);
			});
			
		});
	}
	function du_blockPage() {
		return $("<div></div>").prependTo("body").addClass("overlay");
	}
});