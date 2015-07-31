/*********************************************************************
(C) ZE CMS, Humboldt-Universitaet zu Berlin
Written 2014 by Daniel Rohde <d.rohde@cms.hu-berlin.de>
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
	$(".quicktoggle").button({text:false});
	//$(".quicktoggles").buttonset();
	$(".quicktoggle.fullscreen").click(function(ev) {
		ToolBox.preventDefault(ev);
		var self = $(this);
		self.toggleClass("off");
		ToolBox.toggleFullscreen(self.hasClass("off"));
	});
	
	$(".quicktoggle.dot").toggleClass("off",ToolBox.cookie("settings.show.dotfiles") != "no" && ToolBox.cookie("settings.show.dotfolders") != "no").click(function(ev) {
		ToolBox.preventDefault(ev);
		var self = $(this);
		self.toggleClass("off");
		ToolBox.togglecookie("settings.show.dotfiles", self.hasClass("off") ? "yes" : "no", !self.hasClass("off"));
		ToolBox.togglecookie("settings.show.dotfolders", self.hasClass("off") ? "yes" : "no", !self.hasClass("off"));
		$("body").trigger("settingchanged",{setting: "settings.show.dotfiles",value: self.hasClass("off")})
			     .trigger("settingchanged",{setting: "settings.show.dotfolders",value: self.hasClass("off")});
	});
	$("body").on("settingchanged.quicktoggle",function(e,data) {
		$(".quicktoggle.dot").toggleClass("off",ToolBox.cookie("settings.show.dotfiles") != "no" && ToolBox.cookie("settings.show.dotfolders") != "no");
	});
	
	$(".quicktoggle.bars").click(function(ev) {
		ToolBox.preventDefault(ev);
		var self = $(this);
		// TODO
	});
	$(".quicktoggle.thumbnails").click(function(ev) {
		ToolBox.preventDefault(ev);
		var self = $(this);
		// TODO
	});
});