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

initPopupMenu();

function initPopupMenu() {
	$("#popupmenu .action")
		.off(".popupmenu")
		.on("click.popupmenu", handleFileListActionEvent)
		.on("dblclick.popupmenu", $.MyPreventDefault)
		.MyKeyboardEventHandler();

	initTableColumnPopupActions();
	$("#flt")
		.off(".popupmenu")
		.on("beforeFileListChange.popupmenu", function() {
			hidePopupMenu();
		})
		.on("fileListChanged.popupmenu", function(){
			$("#popupmenu li.popup").MyPopup({
				contextmenu: $("#popupmenu"), 
				contextmenuTarget: $("#fileList tr"), 
				contextmenuAnchor: "#content"
			});

			$("#tc_popupmenu li.popup").MyPopup({contextmenu: $("#tc_popupmenu"), contextmenuTarget: $("#fileListTable .fileListHead th"), contextmenuAnchor: "#content", contextmenuAnchorElement: true});
		});
	$("#filler").on("contextmenu", function(event) { if (event.which==3) { if (event.originalEvent.detail === 1 ) $.MyPreventDefault(event); hidePopupMenu(); } });
}
function initTableColumnPopupActions() {
	$("#tc_popupmenu .action")
	.off(".popupmenu")
	.on("click.popupmenu", handleTableConfigActionEvent)
	.on("dblclick.popupmenu", $.MyPreventDefault)
	.MyKeyboardEventHandler();
	
	$("#flt").on("fileListChanged", function() {
		
		$("#fileListTable th[data-name].sorter-false").each(function(i,v) {
			$(".action.table-sort."+$(v).data("name")).addClass("hidden").hide();
		});
		$(".action.table-sort.fileactions").hide();
		setupContextActions();
	});
	setupContextActions();
	function setupContextActions() {
		var lts = $.MyTableManager.getLastTableSort();
		//$(".action.table-sort .symbol").html("&#8597;");
		//$(".action.table-sort."+lts.name+" .symbol").html( lts.sortorder == 1 ? "&#8600;" : "&#8599;");
		$(".action.table-sort .symbol").removeClass("descending ascending");
		$(".action.table-sort."+lts.name+" .symbol").addClass(lts.sortorder == 1 ? "descending" : "ascending");
		
		$(".action.table-column .symbol").removeClass("column-hidden");
		$(".action.table-column").addClass("hidden disabled");
		$("#fileListTable th[data-name]").each(function(i,v) {
			$(".action.table-column."+$(v).data("name")).removeClass("hidden").toggleClass("disabled", $(v).hasClass("table-column-not-hide"))
				.find(".symbol").toggleClass("column-hidden",$(v).is(":not(:visible)"));
		});
	}
	$("body").on("settingchanged", function(event,data) {
		if (data.setting == "order" || data.setting == "visibletablecolumns") setupContextActions();
	});
	$("#popupmenu,#tc_popupmenu").MyTooltip();
	
	// var visiblecolumns = $.map($("#fileListTable thead th[data-name]:not(.hidden)"), function(val,i) { return $(val).attr("data-name");});
}
function hidePopupMenu() {
	$("#popupmenu li.popup").MyPopup("close");
	$("#tc_popupmenu li.popup").MyPopup("close");
}
function handleTableConfigActionEvent(event) {
	$.MyPreventDefault(event);
	var self = $(this);
	if (self.hasClass("disabled")) return;
	if (self.hasClass("table-sort")) {
		var lts = $.MyTableManager.getLastTableSort();
		$.MyTableManager.sortTable(self.closest("table"), self.data("name"), lts.name == self.data("name") ? -lts.sortorder : 1);
	} else if (self.hasClass("table-sort-this-asc")) {
		$.MyTableManager.sortTable(self.closest("table"), self.closest("th").data("name"), 1 );
	} else if (self.hasClass("table-sort-this-desc")) {
		$.MyTableManager.sortTable(self.closest("table"), self.closest("th").data("name"), -1 );
	} else if (self.hasClass("table-column-hide-this")) {
		$.MyTableManager.toggleTableColumn(self.closest("table"), self.closest("th:not(.table-column-not-hide)").data("name"), false);
	} else if (self.hasClass("table-column")) {
		$.MyTableManager.toggleTableColumn(self.closest("table"), self.data("name"));
	} else if (self.hasClass("table-column-width-default")) {
		$.MyTableManager.setTableColumnWidth(self.closest("th"), "default");
	} else if (self.hasClass("table-column-width-minimum")) {
		$.MyTableManager.setTableColumnWidth(self.closest("th"), "minimum");
	}
}
