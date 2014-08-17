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
	function handleFileListChanges() {
		var flt = $("#fileListTable");
		$("#apps .listaction.diskusage").toggleClass("disabled", flt.hasClass("unselectable-yes") || flt.hasClass("isreadable-no"));
	}
	$("#flt").on("fileListChanged", handleFileListChanges);
	handleFileListChanges();
	function du_dialog(files) {
		$(".action.diskusage").addClass("disabled");
		var block=ToolBox.blockPage();
		var xhr = $.post($("#fileList").attr("data-uri"),{action: "diskusage", file: files}, function (response) {
			if (response.error) {
				block.remove();
				ToolBox.handleJSONResponse(response);
				return;
			}
			var dialog = $(response);
			block.remove();
			var ch = function(event) {
				window.location.href = $("a",$(this)).attr("href");
			};
			$("tr.diskusage.entry", dialog).dblclick(ch).click(ch);
			dialog.dialog({modal: true, width: "auto", height: "auto", maxWidth: $(window).width()-100, resizable: true, 
					open: function() { du_initTreemap(dialog); du_initFiletypeStatistics(dialog); du_initAccordion(dialog); }, 
					close: function() { dialog.dialog("destroy")}});	
			 
			
			$(".action.diskusage").removeClass("disabled");
			dialog.MyTooltip();
		});
		ToolBox.renderAbortDialog(xhr);
	}
	function du_initAccordion(dialog) {
		$(".accordion",dialog).accordion({collapsible: true, active: false, heightStyle:"content",
			activate: function(e,ui) { $(this).trigger("MyActivate", [e,ui]);  }});
		
	}
	function du_initTreemap(dialog) {
		var colorStops = new Array();
		
		colorStops["color1"] = [{ "val":0, "color":"#aa0000" },{ "val":0.2, "color":"#00aaaa" },{ "val":0.4, "color":"#aaaa00" },{ "val":0.6, "color":"#00aa00" },{ "val":0.8, "color":"#0000aa" },{ "val":1, "color":"#000000" }];
		colorStops["color2"] = [{ "val":0, "color":"#404040" },{ "val":0.2, "color":"#909090" },{ "val":0.4, "color":"#333333" },{ "val":0.6, "color":"#404040" },{ "val":0.8, "color":"#989898" },{ "val":1, "color":"#000000" }];
		colorStops["color3"] = [{ "val":0, "color":"#000040" },{ "val":0.2, "color":"#000090" },{ "val":0.4, "color":"#000033" },{ "val":0.6, "color":"#000040" },{ "val":0.8, "color":"#0000ff" },{ "val":1, "color":"#000000" }];
		
		$(".treemappanel",dialog).each(function(i,v) {
			var myLocation = ToolBox.stripSlash(window.location.pathname);
			var cache = new Array();
			$(v).treemap({ "dimensions": $(".treemap.dimensions.active",dialog).data("dimensions"), 
							"nodeData": $(v).data("mapdata"), 
							"nodeBorderWidth":1, 
							"colorStops" : colorStops[$(".treemap.color.active",dialog).data("color") ],
							"leafNodeBodyGradient":function(ctx,rect,rgb){
									var r1 = Math.min(rect[2],rect[3])*0.05;
									var r2 = Math.max(rect[2],rect[3]);
									var x = rect[0]+rect[2]*0.95;
									var y = rect[1]+rect[3]*Math.random();
									var gradient = ctx.createRadialGradient(x,y,r1,x,y,r2);
									gradient.addColorStop(0,TreemapUtils.lighterColor(TreemapUtils.rgb2hex(rgb),0.8));
									gradient.addColorStop(1,TreemapUtils.darkerColor(TreemapUtils.rgb2hex(rgb),0.1));
                    
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

					if (data.nodes && data.nodes[0].title) {
						window.clearTimeout(cache["timeout"]);
						var filename = data.nodes[0].id;
						if (filename.length>30) filename = filename.match(/.{30}/g).join("\\<br/>");
						el.html(filename+": "+ data.nodes[0].val+"<br/>"+data.nodes[0].title.split(", ").join("<br/>"));
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
						var c=data.nodes[0].computedColor;
						el.css({"position" : "absolute", "top" : top+"px","left":left+"px", "border-radius":"1px", "box-shadow" : "0px 0px 0px 4px rgba("+c[0]+","+c[1]+","+c[2]+",0.3)"}).show();
					}
					
			})
			.on("mouseout", function(){
				window.clearTimeout(cache["timeout"]);
				cache["timeout"] = window.setTimeout(function() {cache["el"].hide(200)}, 1000)
			});
			
			function toggleActive(button, group) {
				$("."+group+".active", dialog).removeClass("active");
				button.addClass("active");
			}
			$(".treemap.byfoldersize",$(v).parent()).button().on("click", function() {
				toggleActive($(this), "sort");
				$(v).treemap("option","sizeOption",0);
				$(v).treemap("option","colorOption",0);
			});
			$(".treemap.byfilecount", $(v).parent()).button().on("click", function() {
				toggleActive($(this), "sort");
				$(v).treemap("option","sizeOption",1);
				$(v).treemap("option","colorOption",1);
			});
			$(".treemap.byfilesize",$(v).parent()).button().on("click", function() {
				toggleActive($(this), "sort");
				$(v).treemap("option","sizeOption",2);
				$(v).treemap("option","colorOption",2);
			});
			$(".treemap.dimensions",$(v).parent()).button().on("click", function() {
				toggleActive($(this), "dimensions");
				$(this).addClass("active");
				$(v).treemap("option", "dimensions", $(this).data("dimensions"));
			});
			$(".treemap.color",$(v).parent()).button().on("click", function() {
				toggleActive($(this), "color");
				$(v).treemap("option", "colorStops", colorStops[$(this).data("color")]);
			});
		});
	}
	function du_initFiletypeStatistics(dialog) {
		$(".diskusage.filetype.accordion").on("MyActivate", function() {
			$(".diskusage.filetype.piechart",dialog).each(function(i,v) {
				var self = $(v);
				var id = self.attr("id");
				var chart=AmCharts.makeChart( id, {
					"type": "pie",
					"theme": "light",
					"legend": {
						"position": "right",
						"maxColumns": 6,
						"markerSize": 8,
						"markerLabelGap": 2,
						"spacing": 1,
						"verticalGap": 1,
						"fontSize": 9,
						"marginRight": 5,
						"autoMargins": false,
						"marginLeft" : 0,
						"valueText" : "",
						"valueWidth": 0
					},
					"dataProvider": self.data("json").data,
					"valueField": "y",
					"titleField": "x",
					"balloonText": "[[x]]:[[l]] ([[percents]]%)",
					"balloon": {
						"fillColor":"#ffffff",
						"fillAlpha":1
					},
					"hideLabelsPercent":5,
					"depth3D": 15,
					"angel": 30,
					"outlineAlpha":0.4,
					"creditsPosition":"bottom-right"
				});
				chart.write(id);		
			});
		});
	}
});