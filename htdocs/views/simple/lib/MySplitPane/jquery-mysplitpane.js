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
		if (options == "resize") {
			var handle = handleContainer.find(".mysplitpane-handle");
			if (handle.length>0) handleResize(handle);
			return this;
		}
		var settings = $.extend({}, $.fn.MySplitPane.defaults, options);
		if (settings.left.element == "self") settings.left.element = handleContainer;
		handleContainer.data("MySplitPaneSettings", settings);
		
		var dragHandle = $("<div/>");
		var handle = $("<div/>").addClass("mysplitpane-handle").draggable({
			drag: function(e,ui) {
				setElementsCss(ui.position.left);
			},
			stop: function(e,ui) {
				if (settings.stop) settings.stop(ui.position.left);
			},
			helper: function() {
				return dragHandle;
			},
		}).attr("tabindex",0).on("keydown", function(event) {
			if (event.keyCode == 37) {
				setElementsCss(parseInt(settings.left.element.css(settings.left.style), 10) - settings.keyboardOffset);
			} else if (event.keyCode == 39)  {
				setElementsCss(parseInt(settings.left.element.css(settings.left.style), 10) + settings.keyboardOffset);
			}
		});
		handle.css({left: getHandlePos(handle).left+"px", top: getHandlePos(handle).top+"px" });
		handleContainer.append(handle);
		function setElementsCss(pos) {
			if (settings.left.min && settings.left.min > 0 && pos <= settings.left.min) return;
			if (settings.left.max && settings.left.max > 0 && pos >= settings.left.max) return;
			settings.left.element.css(settings.left.style, pos + "px");
			settings.right.element.css(settings.right.style, pos + "px");
			handleResize(handle);
		}
		function handleResize(handle) {
			var handlePos = getHandlePos(handle);
			handle.css( { left : handlePos.left + "px", top: handlePos.top + "px" } );
		}
		function getHandlePos(handle) {
			var w = $(window);
			return {
					left: handleContainer.offset().left + handleContainer.outerWidth() - handle.outerWidth()/2 - w.scrollLeft(),
					top: handleContainer.offset().top + handleContainer.data("MySplitPaneSettings").offsetY - w.scrollTop()
			};
		}
		return this;
	};
	$.fn.MySplitPane.defaults = {
		stop: function(left) { },
		offsetY: 0,
		keyboardOffset: 10,
		left: { style : "width", element: undefined, min: 0, max: 0 },
		right: { style : "margin-left", element: undefined }
	};
}( jQuery ));
