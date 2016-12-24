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
	$.fn.MyTooltip = function(delay, hidetimeout, showtimeout) {
		var toel = $("body");
		var w = $(window);
		var tooltip;
		if (!toel.data("tooltip")) {
			tooltip = $("<div/>").addClass("tooltip").appendTo($("body")).hide();
			toel.data("tooltip", tooltip);
		} else {
			tooltip = toel.data("tooltip");
		}
		toel.off("click.tooltip").on("click.tooltip", function() {
			clearTimeout();
			tooltip.hide();
		});
		tooltip.off("mouseover.tooltip").on("mouseover.tooltip", function(e) {
			preventDefault(e);
			clearTimeout();
			tooltip.hide();
		});
		function clearTimeout() {
			window.clearTimeout(toel.data("tttimeout"));
		}
		function setDelayTimeout(e, el) {
			clearTimeout();
			tooltip.hide();
			toel.data("tttimeout", window.setTimeout(function() {
				setTooltipPosition(e, el);
			}, delay));
		}
		function hideTooltip(t, el) {
			toel.data("tttimeout", window.setTimeout(function() {
				tooltip.hide();
			}, t));
		}
		function preventDefault(event) {
			if (event.preventDefault) event.preventDefault(); else event.returnValue = false;
			if (event.stopPropagation) event.stopPropagation();
		}
		function setTooltipPosition(e, el) {
			clearTimeout();
			var isFocus = e.type == "focus";
			var left = (isFocus ? el.offset().left : e.pageX) - Math.floor(tooltip.outerWidth() / 2);
			var top = el.offset().top - tooltip.outerHeight() - 4;
			var maxWidth = Math.max(Math.floor(w.width() / 2), 50);
			var maxHeight = Math.max(Math.floor(w.height() / 2), 10);
			if (left - w.scrollLeft() < 0)
				left = 4;
			if (left + tooltip.outerWidth() > w.width())
				left = w.width() - tooltip.outerWidth() - 4;
			if (top - w.scrollTop() < 0)
				top = Math.floor(el.offset().top + el.outerHeight() + 4);
			if (!isFocus && Math.abs(e.pageY - top) > 50)
				top = Math.max(e.pageY - tooltip.outerHeight() - 14, 0);
	
			tooltip.css({
				"left" : left + "px",
				"top" : top + "px",
				"max-height" : maxHeight + "px",
				"max-width" : maxWidth + "px"
			});
			tooltip.toggle(tooltip.text() !== "");
			hideTooltip(showtimeout || 7000, el);
		}
		function isBlocked(el) {
			return el.attr("data-tooltip-block") == "true";
		}
		function blockParentElements(el) {
			el.parents("[data-tooltip], [title]").each(function(i, e) {
				$(e).attr("data-tooltip-block", "true");
			});
			return el;
		}
		function unblockParentElements(el) {
			el.parents("[data-tooltip-block]").removeAttr("data-tooltip-block");
		}
		function handleMouseOver(e, u) {
			var el = $(this);
			handleTitleAttribute(el);
			if (isBlocked(el))
				return;
			blockParentElements(el);
			if (el.data("htmltooltip"))
				tooltip.html(el.data("htmltooltip"));
			else
				tooltip.text(el.attr("data-tooltip"));
			if (delay) {
				setDelayTimeout(e, el);
			} else {
				setTooltipPosition(e, el);
			}
		}
		function handleMouseMove(e, u) {
			var el = $(this);
			handleTitleAttribute(el);
			if (isBlocked(el))
				return;
			if (tooltip.is(":visible") && !delay)
				setTooltipPosition(e, el);
			else
				setDelayTimeout(e, el);
		}
		function handleMouseOut(e, u) {
			clearTimeout();
			hideTooltip(hidetimeout || 500, u);
			unblockParentElements($(this));
		}
		function handleTitleAttribute(el) {
			return el.attr(
					"data-tooltip",
					el.attr("title") !== undefined ? el.attr("title") : el
							.attr("data-tooltip")).removeAttr("title");
		}
		function cleanupMouseHandler(el) {
			return el.off(".tooltip");
		}
		function initElement(el) {
			cleanupMouseHandler(el).on("mouseover.tooltip focus.tooltip",
					handleMouseOver).on("mouseout.tooltip blur.tooltip",
					handleMouseOut).on("mousemove.tooltip", handleMouseMove);
		}
		initElement(this.find("[title]"));
		if (this.attr("title"))
			initElement(this);
	
		return this;
	};
}( jQuery ));