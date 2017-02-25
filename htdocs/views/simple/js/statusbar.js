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

initStatusbar();

function initStatusbar() {
	if (!$.MyCookie("settings.show.statusbar")) {
		$.MyCookie("settings.show.statusbar","no");
		$.MyCookie("settings.show.statusbar.keep","yes");
	}
	$("#statusbar").toggleClass("enabled", $.MyCookie("settings.show.statusbar") == "yes");
	$("#statusbar .unselectable").off("change").on("change", function(e) {$(this).prop("checked",true); $.MyPreventDefault(e); });
	$("body").on("notify",function(ev,data) {
		$("#statusbar .notify").attr("title",data.msg).removeClass("error message warning").addClass(data.type).html(data.msg).MyTooltip();
	});
	$("body").on("settingchanged",function(ev,data) {
		if (data.setting == "settings.show.statusbar") {
			$("#statusbar").toggleClass("enabled", data.value);
		}
	});
	$("#statusbar").MyTooltip();
	
}
