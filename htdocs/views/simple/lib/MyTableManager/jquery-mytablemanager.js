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

/* Cookies: order, visibletablecolumns
 * Events: settingchanged: order, visibletablecolumns
 * Dependency: $.MyCookie
 */
(function ( $ ) {

	$.fn.MyTableManager = function() {
		var table = this;
		// init column drag & drop:
		table.find("th.dragaccept").draggable({ 
			zIndex: 200, 
			scope: "fileListTable",  
			axis: "x" , 
			helper: function(event) {
				var th = $(event.currentTarget);
				return $(event.currentTarget).clone().width(th.width()).addClass("dragged");
			}
		});
		table.find("th.dragaccept, th.dropaccept").droppable({ scope: "fileListTable", tolerance: "pointer", drop: handleColumnDrop, hoverClass: "draghover"});
		
		var ls = $.MyTableManager.getLastTableSort();
		if (ls) $.MyTableManager.sortTable(table, ls.name, ls.sortorder);
		
		table.find("th:not(.sorter-false)")
			.addClass('tablesorter-head')
			.off("click.tablecolumnmanager")
			.on("click.tablecolumnmanager", function(event) {
				if (event.target != this) return;
				var self = this;
				if (self.MyClickCounter === undefined) {
					self.MyClickCounter = 1;
					window.setTimeout( function() {
						if (self.MyClickCounter == 1) {
							var lts = $.MyTableManager.getLastTableSort();
							$.MyTableManager.sortTable(table, $(self).data("name"), lts.name == $(self).data("name")? -lts.sortorder : 1);
						}
						delete self.MyClickCounter;
					}, 250);
				} else {
					self.MyClickCounter+=1;
				}
			});
		// init dblclick resize and drag resize:
		var rhleft = $("<div/>").addClass("columnResizeHandle left");
		var rhright = $("<div/>").addClass("columnResizeHandle right");		
		table.find("th:not(.resizable-false)")
			.each(function() {
				var col = $(this);
				col.prepend(rhleft.clone(), rhright.clone());
				$.MyTableManager.setTableColumnWidth(col, $.MyCookie(col.prop("id")+".width"));
			})
			.off("dblclick.tablecolumnmanager")
			.on("dblclick.tablecolumnmanager", function(event){
				if (event.target != this) return;
				var self = $(this);
				$.MyTableManager.setTableColumnWidth(self, self.width() == self.data("origWidth") ? "minimum" : "default");
			});
		table.find(".columnResizeHandle").draggable({
			scope: "columnResize",
			axis: "x",
			start: function(event,ui) {
				var self = $(this);
				var col = self.closest("th");
				this.MTCMColumnResize= {
					startPos   : parseInt(ui.offset.left,10),
					column     : col,
					startWidth : col.width(),
					handlePos  : self.hasClass("left")? "left" : "right" 
				};
			},
			stop: function() {
				var self = $(this);
				var data = this.MTCMColumnResize;
				self.removeAttr("style");
				$.MyTableManager.setTableColumnWidth(data.column, data.column.width());
			},
			drag: function(event,ui) {
				var data = this.MTCMColumnResize;
				if (data.handlePos=="right") data.column.width( data.startWidth + ui.offset.left - data.startPos );
				else data.column.width(data.startWidth + data.startPos - ui.offset.left);
			}
		});
		function handleColumnDrop(event, ui) {
			var didx = ui.draggable.prop("cellIndex");
			var tidx = $(this).prop("cellIndex");
			if (didx + 1 == tidx) return false;
			
			var cols = table.find("thead th");
			cols.eq(didx).detach().insertBefore(cols.eq(tidx));
			
			$("#fileList tr").each(function() {
				var cs = $(this).children("td");
				cs.eq(didx).detach().insertBefore(cs.eq(tidx));
			});
			setVisibleTableColumnsCookie(table);
			return true;
		}
		return this;
	};
	$.MyTableManager = {
		setTableColumnWidth: function(col, pWidth) {
			var name = col.prop("id")+".width";
			var width = pWidth;
			var origWidth = col.data("origWidth");
			if (origWidth === undefined) col.data("origWidth", col.width());
			if (width === undefined) { 
				col.addClass("column-width-default"); return col; 
			} else if (width === "default") width = origWidth;
			else if (width === "minimum") width = 1;
			col.width(width);
			col.toggleClass("column-width-default", width == origWidth).toggleClass("column-width-minimum", width == 1);
			$.MyCookie.toggleCookie(name, width, width != origWidth);
			return col;
		},
		toggleTableColumn: function(table, name, toggle) {
			var th = table.find("th[data-name="+name+"]");
			var on = toggle === undefined ? !th.is(":visible") : toggle;
			var cidx = th.toggleClass("hidden",!on).toggle(on).prop("cellIndex");
			table.find("td:nth-child("+(cidx+1)+")").toggleClass("hidden",!on).toggle(on);
			setVisibleTableColumnsCookie(table);
		},
		getLastTableSort: function() {
			var so = $.MyCookie("order").split("_");
			if (!so) return { name : "data-file", sortorder : 1 };
			return { name : so[0], sortorder: so[1] && so[1] == "desc" ? -1 : 1 };
		},
		sortTable: function(table, name, sortorder) {
			var col = table.find("th[data-name='"+name+"']:not(.sorter-false)");
			if (col.length==0) return;
			table.find("th").removeClass("tablesorter-down tablesorter-up");
			col.addClass(sortorder == 1 ? "tablesorter-up" : "tablesorter-down");
			sortTableRows(table, col.data("sorttype") || "string", col.data("sort"), sortorder, col.prop("cellIndex"), "data-file");
			$.MyCookie("order", name + (sortorder==1?"_asc":"_desc"),1);
			$("body").trigger("settingchanged",{ setting: "order", value : $.MyCookie("order")});
		}
	};
	/* some private functions */
	function sortTableRows(table,stype,sattr,sortorder,cidx,ssattr) {
		var rows = table.find("tbody tr").get();
		rows.sort(function(a,b){
			var ret = 0;
			var jqa = $(a);
			var jqb = $(b);
			var vala = jqa.attr(sattr) ? (stype=="number" ? parseInt(jqa.attr(sattr),10) : jqa.attr(sattr)) : a.cells.item(cidx).innerHTML.toLowerCase();
			var valb = jqb.attr(sattr) ? (stype=="number" ? parseInt(jqb.attr(sattr),10) : jqb.attr(sattr)) : b.cells.item(cidx).innerHTML.toLowerCase();
	
			if (jqa.attr("data-file").match(/^\.\.?$/)) return -1;
			if (jqb.attr("data-file").match(/^\.\.?$/)) return 1;
			if (jqa.attr("data-type") == "dir" && jqb.attr("data-type") != "dir") return -1;
			if (jqa.attr("data-type") != "dir" && jqb.attr("data-type") == "dir") return 1;
			
			if (stype == "number") {
				ret = vala - valb;
			} else {
				if (vala.localeCompare) {
					ret = vala.localeCompare(valb);
				} else {
					ret = (vala < valb ? -1 : (vala==valb ? 0 : 1));
				}
			}
			if (ret === 0 && sattr!=ssattr) {
				if (vala.localeCompare) {
					ret = jqa.attr(ssattr).localeCompare(jqb.attr(ssattr));
				} else {
					ret = jqa.attr(ssattr) < jqb.attr(ssattr) ? -1 : jqa.attr(ssattr) > jqb.attr(ssattr) ? 1 : 0;
				}
			}
			return sortorder * ret;
		});
		for (var r=0; r<rows.length; r++) {
			table.append(rows[r]);
		}
		return table;
	}
	function setVisibleTableColumnsCookie(table) {
		$.MyCookie("visibletablecolumns", table.find("th[data-name]:visible").map(function() { return $(this).data("name"); }).get().join(","), 1);
		$("body").trigger("settingchanged", { setting: "visibletablecolumns", value: $.MyCookie("visibletablecolumns") });
	}
}( jQuery ));