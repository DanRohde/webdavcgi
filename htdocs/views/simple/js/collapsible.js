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

initCollapsible();

function handleSidebarCollapsible(event) {
	if (event) $.MyPreventDefault(event);
	var collapsed = $(this).hasClass("collapsed");
	var iconsonly = $(this).hasClass("iconsonly");
	if (!collapsed && !iconsonly) iconsonly = true;
	else if (iconsonly) {
		iconsonly=false;
		collapsed=true;
	} else collapsed = false;
	
	$(".collapse-sidebar-listener").toggleClass("sidebar-collapsed", collapsed).toggleClass("sidebar-iconsonly", iconsonly);
	$(".action.collapse-sidebar").toggleClass("collapsed",collapsed).toggleClass("iconsonly",iconsonly);
	
	if (!iconsonly&&!collapsed) $.MyCookie.rmCookies("sidebar");
	else $.MyCookie("sidebar", iconsonly?"iconsonly":collapsed?"false":"true");
	
	handleWindowResize();
}
function initCollapsible() {
	$(".action.collapse-sidebar").click(handleSidebarCollapsible).MyKeyboardEventHandler().MyTooltip();
	if ($.MyCookie("sidebar") && $.MyCookie("sidebar") != "true") {
		$(".collapse-sidebar-listener").toggleClass("sidebar-collapsed", $.MyCookie("sidebar") == "false").toggleClass("sidebar-iconsonly", $.MyCookie("sidebar") == "iconsonly");
		$(".action.collapse-sidebar").toggleClass("collapsed", $.MyCookie("sidebar") == "false").toggleClass("iconsonly", $.MyCookie("sidebar") == "iconsonly");
		handleWindowResize();
	}
	
	$(".action.collapse-head").click(function(event) {
		$(".action.collapse-head").toggleClass("collapsed");
		var collapsed = $(this).hasClass("collapsed");
		$(".collapse-head-collapsible").toggle(!collapsed);
		$(".collapse-head-listener").toggleClass("head-collapsed", collapsed);
		$.MyCookie.toggleCookie("head","false",collapsed, 1);
		handleWindowResize();
	}).MyTooltip().MyKeyboardEventHandler();
	if ($.MyCookie("head") == "false") $(".action.collapse-head").first().trigger("click");
}
