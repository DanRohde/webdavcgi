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
	function HSVtoRGB(h, s, v) {
	    var r, g, b, i, f, p, q, t;
	    i = Math.floor(h * 6);
	    f = h * 6 - i;
	    p = v * (1 - s);
	    q = v * (1 - f * s);
	    t = v * (1 - (1 - f) * s);
	    switch (i % 6) {
	        case 0: r = v, g = t, b = p; break;
	        case 1: r = q, g = v, b = p; break;
	        case 2: r = p, g = v, b = t; break;
	        case 3: r = p, g = q, b = v; break;
	        case 4: r = t, g = p, b = v; break;
	        case 5: r = v, g = p, b = q; break;
	    }
	    return { r: Math.floor(r * 255), g: Math.floor(g * 255), b: Math.floor(b * 255)};
	}
	function du_calculateColorStops(steps) {
		var colorStops = new Array();
		var f  = 1 / steps;
		var starth = 300; // purple: 300,  blue= 240, green=120, red = 0/360
		var speed = starth / steps;
		var x = starth / Math.log(speed*steps+1);
		for (var i=0; i<=steps; i++) {
			var c = HSVtoRGB(Math.abs( (starth - x*Math.log(speed*i+1))/360 ),1,0.60);
			var rgb = c.b | c.g << 8 | c.r << 16;
			var rgbs = rgb.toString(16);
			while(rgbs.length <6 ) rgbs="0"+rgbs;
			if (rgbs.length>6) rgbs=rgbs.substr(0,6);
			colorStops.push( {"val": i*f, "color": "#"+rgbs });
		}
		return colorStops;
	}
	function du_drawColorSpectrum(colorStops) {
		var canvasWidth = 700;
		var canvasHeight = 16;
		var steps = colorStops.length;
		var rectWidth = Math.round(canvasWidth / steps);
		var canvas = $("<canvas/>").attr({"width":canvasWidth,"height":canvasHeight});
		var ctx = canvas[0].getContext("2d");
		$.each(colorStops.sort(function(a,b){ return a.val-b.val }), function(i,v) {
			var grd = ctx.createLinearGradient(0,0,rectWidth,0);
			if (v.val < 1) {
				grd.addColorStop(0, v.color);
				grd.addColorStop(1, colorStops[i+1].color);
			} else {
				grd.addColorStop(0, colorStops[i-1].color);
				grd.addColorStop(1, v.color);
			}
			ctx.fillStyle = grd;
			ctx.fillRect(i*rectWidth, 2, rectWidth, canvasHeight-2);
		});
		ctx.fillStyle = "#ffffff";
		ctx.font = "bold 10px sans-serif";
		ctx.textBaseline = 'bottom';
		ctx.fillText("0%",2,15);
		var m = ctx.measureText("100%");
		ctx.fillText("100%",canvasWidth-m.width-2,15);
		
		return $("<div/>").css({"margin-left":"auto", "margin-right":"auto", "width":canvasWidth+"px"}).append(canvas);
	}
	function du_initTreemap(dialog) {
		var colorStops = du_calculateColorStops(50);
		$(".treemappanel",dialog).each(function(i,v) {
			var myLocation = ToolBox.stripSlash(window.location.pathname);
			var cache = new Array();
			$(v).treemap({ "dimensions": [800,600], "nodeData": $(v).data("mapdata"), 
				"colorStops" : colorStops, "leafNodeBodyGradient":function(ctx,rect,rgb){
                    var r1 = Math.min(rect[2],rect[3])*0.1;
                    var r2 = Math.max(rect[2],rect[3]);
                    var x = rect[0];
                    var y = rect[1];
                    var gradient = ctx.createRadialGradient(x,y,r1,x,y,r2);
                    gradient.addColorStop(0,TreemapUtils.darkerColor(TreemapUtils.rgb2hex(rgb),0.1));
                    gradient.addColorStop(1,TreemapUtils.lighterColor(TreemapUtils.rgb2hex(rgb),0.1));
                    return gradient;
                }})
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
			$(v).parent().prepend(du_drawColorSpectrum(colorStops));
		});
	}
	function du_blockPage() {
		return $("<div></div>").prependTo("body").addClass("overlay");
	}
});