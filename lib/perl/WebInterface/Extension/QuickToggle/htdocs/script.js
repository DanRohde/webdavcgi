/*********************************************************************
(C) ZE CMS, Humboldt-Universitaet zu Berlin
Written 2015 by Daniel Rohde <d.rohde@cms.hu-berlin.de>
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
	//$(".quicktoggle").button({text:false, label:null});
	
	$(".quicktoggle.fullscreen").click(function(ev) {
		var self = $(this);
		self.toggleClass("off");
		$.MyFullscreen.toggle(self.hasClass("off"));
	});
	$.MyFullscreen.addChangeListener(function() { $(".quicktoggle.fullscreen").toggleClass("off", $.MyFullscreen.is());  } );
	
	$(".quicktoggle.dot").toggleClass("off",$.MyCookie("settings.show.dotfiles") != "no" && $.MyCookie("settings.show.dotfolders") != "no").click(function(ev) {
		var self = $(this);
		self.toggleClass("off");
		var disabled = self.hasClass("off"); 
		if ($.MyCookie("settings.show.dotfiles.keep")) $.MyCookie("settings.show.dotfiles", disabled ? "yes" : "no", 1);
		else $.MyCookie.toggleCookie("settings.show.dotfiles", disabled ? "yes" : "no", 1);
		if ($.MyCookie("settings.show.dotfolders.keep")) $.MyCookie("settings.show.dotfolders", disabled ? "yes" : "no", 1);
		else $.MyCookie.toggleCookie("settings.show.dotfolders", disabled ? "yes" : "no", 1);
		$("body").trigger("settingchanged",{setting: "settings.show.dotfiles", value: disabled})
			     .trigger("settingchanged",{setting: "settings.show.dotfolders",value: disabled});
	});
	$("body").on("settingchanged.quicktoggledot",function(e,data) {
		$(".quicktoggle.dot").toggleClass("off",$.MyCookie("settings.show.dotfiles") != "no" && $.MyCookie("settings.show.dotfolders") != "no");
	});
	
	$(".quicktoggle.bars").click(function(ev) {
		var self = $(this);
		self.toggleClass("off");
		var collapsed = self.hasClass("off");
		$.MyCookie.toggleCookie("sidebar", collapsed ? "iconsonly" : "true", collapsed);
		$.MyCookie.toggleCookie("head", collapsed ? "false" : "true", collapsed);
		
		
		$(".collapse-sidebar-listener").toggleClass("sidebar-collapsed",false).toggleClass("sidebar-iconsonly", collapsed);
		$(".action.collapse-sidebar").toggleClass("collapsed",false).toggleClass("iconsonly",collapsed);
		
		$(".action.collapse-head").toggleClass("collapsed", collapsed);
		$(".collapse-head-collapsible").toggle(!collapsed);
		$(".collapse-head-listener").toggleClass("head-collapsed", collapsed);
		ToolBox.handleWindowResize();
		
	});
	$("body").on("windowResized", function() {
		$(".quicktoggle.bars").toggleClass("off", $.MyCookie("sidebar") != "true" && $.MyCookie("head") == "false");
	});
	$(".quicktoggle.bars").toggleClass("off", $.MyCookie("sidebar") != "true" && $.MyCookie("head") == "false");
	
	$(".quicktoggle.thumbnails").click(function(ev) {
		var state = $.MyCookie("settings.enable.thumbnails");
		var newstate = state == "no" ? "yes" : "no";
		$.MyCookie.toggleCookie("settings.enable.thumbnails", newstate, newstate == "no");
		$("body").trigger("settingchanged", {setting:"settings.enable.thumbnails",value:newstate=="yes"});
	}).toggleClass("off", !$.MyCookie("settings.enable.thumbnails"));
	
	$("body").on("settingchanged.quicktogglethumbnails", function(e,data) {
		if (data.setting == "settings.enable.thumbnails") $(".quicktoggle.thumbnails").toggleClass("off", data.value);
	});

	$(".quicktoggle-icon").on("click", function() {
		$(this).closest(".quicktoggle-content").toggleClass("quicktoggle-focus");
	});
	$(".quicktoggle-content").on("focusin mouseenter", function() {
		$(this).addClass("quicktoggle-focus");
	}).on(" mouseleave", function() {
		$(this).removeClass("quicktoggle-focus");
	});
	$(".quicktoggleaction").on("focusin mouseenter", function() {
		$(this).closest(".quicktoggle-content").addClass("quicktoggle-focus");
	});
	$(".quicktoggles").siblings().on("focusin mouseenter", function() {
		$(".quicktoggle-content.quicktoggle-focus").removeClass("quicktoggle-focus");
	});
	/*$(".action.quicktoggle-button").click(function(e) { $.MyPreventDefault(e);})*/
});