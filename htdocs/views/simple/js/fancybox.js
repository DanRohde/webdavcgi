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
initFancyBox();
function initFancyBox() {
	$("#flt").on("fileListChanged", function() {
		$("#fileList tr.isviewable-yes.isempty-no[data-mime^='image/']:visible .changeuri")
			.off("click")
			.attr("data-fancybox-group","imggallery")
			.each(function(i,v){ var self = $(v); self.data("fancybox-href", self.data("href")); self.data("fancybox-title", self.html()); })
			.fancybox({
				padding: 0,
				afterShow: function() { $(".fancybox-close").focus();},
				helpers: { buttons: {}, thumbs: { width: 60, height: 60, source: function(current) { return (current.element).attr("data-href")+"?action=thumb"; } } } 
			});
		$("#fileList tr.isviewable-no.isempty-no[data-mime^='image/']:visible .changeuri")
			.off("click")
			.attr("data-fancybox-group","wtimggallery")
			.each(function(i,v){ var self = $(v); self.data("fancybox-href", self.data("href")); self.data("fancybox-title", self.find(".nametext").html()); })
			.fancybox({
				padding: 0,
				afterShow: function() { $(".fancybox-close").focus();},
				helpers: { buttons: {} }
			});
	});
}
