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
(function ( $ ) {
	$.fn.MySplitPane = function(options) {
		var handleContainer = this;
		var settings = $.extend({}, $.fn.MySplitPane.defaults, options);
		
		if (settings.left.element == "self") settings.left.element = handleContainer;
		var dragHandle = $("<div/>");
		var handle = $("<div/>").html("&harr;").addClass("mysplitpane-handle").draggable({
			drag: function(e,ui) {
				if (settings.left.min && settings.left.min > 0 && ui.position.left <= settings.left.min) return;
				if (settings.left.max && settings.left.max > 0 && ui.position.left >= settings.left.max) return;
				
				settings.left.element.css(settings.left.style, ui.position.left + "px");
				settings.right.element.css(settings.right.style, ui.position.left + "px");
				handleContainer.resize();
			},
			stop: function(e,ui) {
				if (settings.stop) settings.stop(ui.position.left);
			},
			helper: function() {
				return dragHandle;
			},
		});
		handle.css({left: getHandlePos().left+"px", top: getHandlePos().top+"px" });
		handleContainer.on("resize", function() {
			var handlePos = getHandlePos();
			handle.css( { left : handlePos.left + "px", top: handlePos.top + "px" } );
		});
		handleContainer.append(handle);
		function getHandlePos() {
			return {
					left: handleContainer.offset().left + handleContainer.outerWidth() - handle.outerWidth()/2,
					top: handleContainer.offset().top + 100
			};
		}
		return this;
	};
	$.fn.MySplitPane.defaults = {
		stop: function(left) { },
		left: { style : "width", element: undefined, min: 0, max: 0 },
		right: { style : "margin-left", element: undefined }
	};
}( jQuery ));