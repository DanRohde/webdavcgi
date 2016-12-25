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
		var tooltip, tooltipcontent, tooltipta;
		if (!toel.data("tooltip")) {
			tooltipcontent = $("<div/>").addClass("tooltip-content");
			tooltipta = $("<div/>").addClass("tooltip-ta");
			tooltip = $("<div/>")
						.addClass("tooltip")
						.append(
							tooltipcontent,
							[
							$("<div/>").addClass("tooltip-help").attr("tabindex",0).on("click",handleHelp),
							tooltipta
							]
						)
						.appendTo($("body")).hide();
			toel.data("tooltip", tooltip);
		} else {
			tooltip = toel.data("tooltip");
			tooltipcontent = $(".tooltip-content", tooltip);
			tooltipta = $(".tooltip-ta", tooltip);
		}
		
		toel.off("click.tooltip mouseover.tooltip").on("click.tooltip mouseover.tooltip", function(ev) {
			clearTimeout();
			tooltip.hide();
		});
		
		function handleHelp(ev) {
			console.log(tooltip.data("help"));
		}
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
			var left = isFocus ? el.offset().left + el.outerWidth() - 15 : e.pageX -5;
			var top = isFocus ? el.offset().top + el.outerHeight() + 10 : e.pageY + 20;
			var maxWidth = Math.max(Math.floor(w.width() / 2), 50);
			var maxHeight = Math.max(Math.floor(w.height() / 2), 10);
			tooltip.removeClass("tooltip-left tooltip-right tooltip-top tooltip-bottom");
			if (left + tooltip.outerWidth() > w.width()) { // flip tooltip to the right 
				left = ( isFocus ? el.offset().left + el.outerWidth() : e.pageX ) - tooltip.outerWidth() - Math.min(el.outerWidth(), 15);
				tooltip.addClass("tooltip-right");
			} else {
				tooltip.addClass("tooltip-left");
			}
			if ( top + tooltip.outerHeight() > w.height() ) { // flip tooltip to the top
				top = (isFocus ? el.offset().top : e.pageY) - tooltip.outerHeight() - 10;
				tooltip.addClass("tooltip-top");
			} else {
				tooltip.addClass("tooltip-bottom");
			}
			tooltip.css({
				"left" : left + "px",
				"top" : top + "px",
				"max-height" : maxHeight + "px",
				"max-width" : maxWidth + "px"
			});
			tooltip.toggle(tooltipcontent.text() != "");
			hideTooltip(showtimeout || 7000, el);
		}
		function isBlocked(el) {
			return el.attr("data-tooltip-block");
		}
		function blockParentElements(el) {
			el.parents("[data-tooltip], [title]").each(function(i, e) {
				$(e).attr("data-tooltip-block", true);
			});
			return el;
		}
		function unblockParentElements(el) {
			el.parents("[data-tooltip-block]").removeAttr("data-tooltip-block");
		}
		function handleMouseOver(event) {
			var el = $(this);
			handleTitleAttribute(el);
			if (isBlocked(el)) return;
			blockParentElements(el);
			if (el.data("htmltooltip"))
				tooltipcontent.html(el.data("htmltooltip"));
			else
				tooltipcontent.text(el.attr("data-tooltip"));

			var help = el.data("help") || el.parents("[data-help]:first").data("help");
			tooltip.toggleClass("help", help != undefined ).data("help", help);
			
			if (help != undefined) {
				hidetimeout=3000;
				//showtimeout=3000;
			}
			
			if (delay) {
				setDelayTimeout(event, el);
			} else {
				setTooltipPosition(event, el);
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
			tooltipcontent.text("");
		}
		function handleTitleAttribute(el) {
			return el.attr("data-tooltip", el.attr("title") != undefined ? el.attr("title") : el.attr("data-tooltip")).removeAttr("title");
		}
		function initElement(el) {
			el.off(".tooltip")
				.on("mouseenter.tooltip focus.tooltip", handleMouseOver)
				.on("mouseleave.tooltip blur.tooltip", handleMouseOut)
				.on("mousemove.tooltip", handleMouseMove);
		}
		initElement(this.find("[title]"));
		if (this.attr("title"))
			initElement(this);
	
		return this;
	};
}( jQuery ));