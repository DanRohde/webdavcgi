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

initGuide();

function initGuide() {
	$.fn.MyTooltip.defaults.helphandler = handleGuide;
	$(".contexthelp").MyContextHelp();
	$(".action.guide").click(function() {
		handleGuide.call(this, $(this).data("help"));
	});
}
function handleGuide(help) {
	var w = $(window);
	$("<div/>").append(
			$("<iframe/>").attr({ name: "guide", src: help, width: "99%", height: "99%"}).text(help)
	).dialog({ width: w.width()/2, height: w.height()/2, title:$(".action.guide").data("title"), dialogClass: "guidedialog" });
}