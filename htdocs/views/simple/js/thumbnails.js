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

initThumbnailSwitch();

function updateThumbnails() {
	var enabled = $.MyCookie("settings.enable.thumbnails") != "no";
	$("#flt .icon").each(function() {
		var self = $(this);
		if (self.data("thumb")!=self.data("icon")) {
			var thumb = self.data("thumb");
			var icon = self.data("icon");
			var empty = $("#emptyimage").attr("src");
			self.attr("src", enabled ? ( thumb === "" ? empty : thumb ) : ( icon === "" ? empty : icon));
			self.toggleClass("thumbnail", enabled);
		}
	});
	
}
function initThumbnailSwitch() {
	$("body").off("settingchanged.initThumbnailSwitch").on("settingchanged.initThumbnailSwitch", function(e,data) {
		if (data.setting == "settings.enable.thumbnails") {
			updateThumbnails();
		}
	});
	$("#flt").on("fileListChanged", function() {
		// fix broken thumbnails bug
		$("#flt img.icon.thumbnail").on("error", function(){ 
			var self=$(this);
			var icon = self.data("icon");
			self.removeClass("thumbnail").attr("src", icon !== "" ? icon : $("#emptyimage").attr("src"));
		});
	});
}