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

initUIEffects();
initTabs();

function initUIEffects() {
	$(".accordion").accordion({ collapsible: true, active: false });
	
	$("#flt").on("fileListChanged", function() {
		$(".dropdown-hover")
			.off(".dropdown-hover")
			.on("mouseenter.dropdown-hover", function() { $(".dropdown-menu",$(this)).show(); })
			.on("mouseleave.dropdown-hover", function() { $(".dropdown-menu",$(this)).hide(); })
			.on("focus.dropdown-hover", function() { $(".dropdown-menu",$(this)).show(); } )
			.on("keyup.dropdown-hover", function(e) { if (e.keyCode==13 || e.keyCode == 32) $(".dropdown-menu" , $(this)).hide(); } );
		$(".dropdown-click")
			.off(".dropdown-click")
			.on("click.dropdown-click dblclick.dropdown-click", function(e) { $.MyPreventDefault(e); $(".dropdown-menu",$(this)).toggle(); })
			.MyKeyboardEventHandler({namespace:"dropdown-click"});
	});
}

function initTabs(elparam) {
	var el = elparam;
	if (!el) el=$(document);
	$(".tabsel",el).on("click keyup", function(ev) {
		if (ev.type == "keyup" && ev.keyCode != 32 && ev.keyCode != 13) return;
		$.MyPreventDefault(ev);
		var self = $(this);
		$(".tabsel.activetabsel",el).removeClass("activetabsel");
		self.addClass("activetabsel");
		$(".tab.showtab",el).removeClass("showtab");
		var tab = $(".tab."+self.data("group"),el).addClass("showtab");
		$(":focusable:visible:first", tab).focus();
	});
}
