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

initViewBar();

initFileListViewSwitches();


function initViewBar() {
	$("#viewbar").MyTooltip();
}

function initFileListViewSwitches() {
	var v = $.MyCookie("settings.filelisttable.view");
	if (v) {
		$("#flt").addClass(v);
		$(".action.flt-view-change."+v).addClass("toggle-on");
	} else {
		$("#flt").addClass($(".action.flt-view-default").data("view"));
		$(".action.flt-view-default").addClass("toggle-on");
	}
	$(".action.flt-view-change").on("click",function() {
		var self = $(this);
		$.MyCookie("settings.filelisttable.view", self.data("view"));
		$("body").trigger("settingchanged", { setting: "settings.filelisttable.view", value: self.data("view") });
	});
	$("body").on("settingchanged", function(ev,data) {
		if (data.setting == "settings.filelisttable.view") {
			$(".action.flt-view-change").removeClass("toggle-on");
			$(".action.flt-view-change."+data.value).addClass("toggle-on");
			$(".action.flt-view-change").each(function() {
				$("#flt").removeClass($(this).data("view"));
			});
			$("#flt").addClass(data.value);
		}
	});
}