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

initKeyboardSupport();

function initKeyboardSupport() {
	$("#flt").on("fileListChanged", function() { 
		$("#fileList tr").off("keydown.flctr").on("keydown.flctr",function(event) {
			var tabindex = this.tabIndex || 1;
			var self = $(this);
			if (self.is(":focus")) {
				if (event.keyCode ==32) handleRowClickEvent.call(this,event);
				else if (event.keyCode==13) 
					changeUri($.MyStringHelper.concatUri(getURI(), encodeURIComponent($.MyStringHelper.stripSlash(self.attr("data-file")))),self.attr("data-type") == "file");
				else if (event.keyCode==46) {
					if ($("#fileList tr.selected:visible").length === 0) { 
						if (isSelectableRow(self)) handleFileDelete(self);
					} else handleFileListActionEventDelete();
				} else if (event.keyCode==36) 
					$("#fileList tr:visible").first().focus();
				else if (event.keyCode==35) 
					$("#fileList tr:visible").last().focus();
				else if (event.keyCode==45) 
					$(".paste").trigger("click");
			}
			if (event.keyCode==38 && tabindex > -1 ) {
				$.MyPreventDefault(event);
				if (isSelectableRow(self) && (event.shiftKey || event.altKey || event.ctrlKey || event.metaKey)) {
					toggleRowSelection(self, true);
					$("#flt").trigger("fileListSelChanged");
				}
				self.prevAll(":focusable:first").focus();
				$.MyRemoveTextSelections();
			} else if (event.keyCode==40) {
				$.MyPreventDefault(event);
				if (isSelectableRow(self) && (event.shiftKey || event.altKey || event.ctrlKey || event.metaKey)) {
					toggleRowSelection(self, true);
					$("#flt").trigger("fileListSelChanged");
				}
				self.nextAll(":focusable:first").focus();
				$.MyRemoveTextSelections();
			} 
		});
		$("#fileList tr[tabindex='1']").focus();
	});
	$("#accesskeydetailseventcatcher").on("focus", renderAccessKeyDetails);
	$("#gotofilelisteventcatcher").on("focus", function() { $("#fileList tr:focusable:first").focus(); });
	$("#gotoappsmenueventcatcher").on("focus", function() { $("#apps :focusable:first").focus(); });
	$("#gototoolbareventcatcher").on("focus", function() { $(".toolbar :focusable:first").focus(); });
}
function renderAccessKeyDetails() {
	if ($("#accesskeydetails").length>0) {
		$("#accesskeydetails").dialog("destroy").remove();
		$("#fileList tr:focusable:first").focus();
		return;
	}
	var text = "";
	var refs = $("*[accesskey]").get().sort(function(a,b) {
		var aa = $(a).attr("accesskey");
		var bb = $(b).attr("accesskey");
		return aa < bb ? -1 : aa > bb ? 1 : 0; 
	});
	var dup = [];
	$.each(refs, function(i,v) {
		var qv = $(v);
		var ak = qv.attr("accesskey");
		if (!dup[ak]) {
			text += '<li tabindex="0" role="definition">'+ak+": "+( qv.attr("aria-label") || qv.attr("title") || qv.attr("data-tooltip") || qv.html() )+"</li>";
			dup[ak]=true;
		} else {
			console.log("found accesskey "+ak+" more than on time");
		}
	});
	$('<div id="accesskeydetails" tabindex="-1"/>')
		.html('<ul class="accesskeydetails">'+text+"</ul>")
		.dialog({title: $(this).attr("title"), width: "auto", height: "auto", dialogClass : "accesskeydialog",
				buttons : [ { text: $("#close").html(), click:  function() { $(this).dialog("destroy").remove(); }}],
				open: function() { $("#accesskeydetails li:focusable:first").focus(); } });
}
function toggleRowSelection(row,on) {
	if (!row) return;
	row.toggleClass("selected", on);
	row.find(".selectbutton").prop("checked", row.hasClass("selected"));
}
