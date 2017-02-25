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
initTableConfigDialog();

function initTableConfigDialog() {
	$("#flt").on("fileListChanged", function() {
		$(".tableconfigbutton").click(function(event) {
			$.MyPreventDefault(event);
			if ($(this).hasClass("disabled")) return;
			$(".tableconfigbutton").addClass("disabled");
			
			var dialog = $("#flt").data("TableConfigDialog");
			if (dialog) {
				setupTableConfigDialog($(dialog));
			} else if ($("#tableconfigdialogtemplate").length>0) {
				var tct = $("#tableconfigdialogtemplate").html();
				$("#flt").data("TableConfigDialog", tct);
				setupTableConfigDialog($(tct));
			} else {
				$.MyPost($("#fileList").attr("data-uri"),{ ajax : "getTableConfigDialog", template : $(this).attr("data-template")}, function(response) {
					if (response.error) handleJSONResponse(response);
					$("#flt").data("TableConfigDialog", response);
					setupTableConfigDialog($(response));
				});
			}
		}).MyKeyboardEventHandler();
	});
}
function setupTableConfigDialog(dialog) {
	// init dialog:
	var visiblecolumns = $.map($("#fileListTable thead th[data-name]:not(.hidden)"), function(val) { return $(val).attr("data-name");});
	$.each(visiblecolumns, function(i,val) {
		dialog.find("input[name='visiblecolumn'][value='"+val+"']").prop("checked",true);	
	});
	dialog.find("input[name='visiblecolumn'][value='name']").attr("readonly","readonly").prop("checked",true).click(function(e) { $.MyPreventDefault(e);}).closest("li").addClass("disabled");
	$("#fileListTable thead th.sorter-false").each(function(i,val) {
		dialog.find("input[name='sortingcolumn'][value='"+$(val).attr("data-name")+"']").prop("disabled",true).click(function(e){$.MyPreventDefault(e);}).closest("li").addClass("disabled");
	});
	
	var so = $.MyCookie("order") ? $.MyCookie("order").split("_") : "name_asc".split("_");
	var column = so[0];
	var order = so[1] || "asc";
	
	dialog.find("input[name='sortingcolumn'][value='"+column+"']").prop("checked",true);
	dialog.find("input[name='sortingorder'][value='"+order+"']").prop("checked", true);
	
	dialog.find("input[value='fileactions']").closest("li").hide();
	
	// register dialog actions:
	dialog.find(".tableconfig-save").button().click(function() {
		// preserve table column order:
		var vc = visiblecolumns.slice(0); // clone visiblecolumns
		var vtc = $.map($("input[name='visiblecolumn']:checked"), function (val) { return $(val).attr("value"); });
		
		// this is more inefficient than
		// $.MyCookie("visibletablecolumns,vtc.join(","));
		// but preserves table column order:
		// remove unselected elements:
		var removedEls = [];
		for (var i=vc.length-1; i>=0; i--) {
			if ($.inArray(vc[i], vtc)==-1) {
				removedEls.push(vc[i]);
				vc.splice(i,1);
			}
		}
		// add missing selected elements:
		var addedEls = [];
		$.each(vtc, function(idx,val) {
			if ($.inArray(val, vc)==-1) {
				addedEls.push(val);
				vc.push(val);
			}
		});
		
		var c = dialog.find("input[name='sortingcolumn']:checked").attr("value");
		var o = dialog.find("input[name='sortingorder']:checked").attr("value");
		
		var table = $("#fileListTable");
		if (vtc.sort().join(",") != visiblecolumns.sort().join(",")) {
			$.each(addedEls, function(idx,val) {
				$.MyTableManager.toggleTableColumn(table, val, true);
			});
			$.each(removedEls, function(idx,val) {
				$.MyTableManager.toggleTableColumn(table, val, false);
			});
		}
		$.MyTableManager.sortTable(table, c, o == "desc" ? -1 : 1);
		
		dialog.dialog("close");
	});
	dialog.find(".tableconfig-cancel").button().click(function(event) {
		$.MyPreventDefault(event);
		dialog.dialog("close");
		return false;
	});
	
	dialog.find("#tableconfigform").submit(function() { return false; });
	
	dialog.dialog({ modal: true, width: "auto", title: dialog.attr("data-title") || dialog.attr("title"), dialogClass: "tableconfigdialog", height: "auto", close: function() { $(".tableconfigbutton").removeClass("disabled"); dialog.dialog("destroy");}});
	
}
