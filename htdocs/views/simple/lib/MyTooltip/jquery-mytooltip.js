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
	$.fn.MyTooltip = function(options) {
		var settings = $.extend({}, $.fn.MyTooltip.defaults, typeof options === "number" ? { delay: options }: options);
		var toel = $("body");
		var w = $(window);
		var tooltip, tooltipcontent, tooltipta;
		if (!toel.data("tooltip")) {
			tooltipcontent = $("<div/>").addClass("tooltip-content");
			tooltipta = $("<div/>").addClass("tooltip-ta");
			tooltip = $("<div/>")
						.addClass("tooltip")
						.append(
							[
							$("<div/>").addClass("tooltip-help")
										.attr({"tabindex":1})
										.on("click", function() {
											settings.helphandler.call(tooltip.data("element"), tooltip.data("help"));
										})
										.MyKeyboardEventHandler(),
							tooltipcontent,
							tooltipta
							]
						)
						.appendTo($("body")).hide()
						.on("mouseenter mousemove focus", function() {
							if (tooltip.data("help") != undefined) clearTimeout();
							else hideTooltip(settings.hidetimeout);
						})
						.on("mouseleave blur", function() {
							hideTooltip(settings.showtimeout);
						});
			toel.data("tooltip", tooltip);
		} else {
			tooltip = toel.data("tooltip");
			tooltipcontent = $(".tooltip-content", tooltip);
			tooltipta = $(".tooltip-ta", tooltip);
		}

		initElement(this.find("[title]"));
		if (this.attr("title")) initElement(this);

		function setTooltipPosition(event, el) {
			var isFocus = event.type == "focus";
			var left = isFocus ? el.offset().left + el.outerWidth() + settings.fOffsetX : event.pageX + settings.mOffsetX;
			var top = isFocus ? el.offset().top + el.outerHeight() + settings.fOffsetY : event.pageY + settings.mOffsetY;
			var maxWidth = Math.max(Math.floor(w.width() / 2), 50);
			var maxHeight = Math.max(Math.floor(w.height() / 2), 10);
			tooltip.removeClass("tooltip-left tooltip-right tooltip-top tooltip-bottom");
			if (left + tooltip.outerWidth() > w.width()) { // flip tooltip to the right 
				left = ( isFocus ? el.offset().left - settings.fOffsetX : event.pageX - settings.mOffsetX )
						- tooltip.outerWidth();
				tooltip.addClass("tooltip-right");
			} else {
				tooltip.addClass("tooltip-left");
			}
			if ( top + tooltip.outerHeight() > w.height() ) { // flip tooltip to the top
				top = (isFocus ? el.offset().top - settings.fOffsetY : event.pageY - settings.mOffsetY) - tooltip.outerHeight();
				tooltip.addClass("tooltip-top");
			} else {
				tooltip.addClass("tooltip-bottom");
			}
			return tooltip.css({
				"left" : left + "px",
				"top" : top + "px",
				"max-height" : maxHeight + "px",
				"max-width" : maxWidth + "px"
			});
		}
		function clearTimeout() {
			window.clearTimeout(toel.data("tttimeout"));
		}
		function hideTooltip(t) {
			clearTimeout();
			if (t==0) {
				tooltip.hide();
			} else {
				toel.data("tttimeout", window.setTimeout(function() {
					tooltip.hide();
				}, t));	
			}
		}
		function handleTitleAttribute(el) {
			var text = el.attr("title");
			if (!text) text = el.attr("data-tooltip");
			if (!text) text = "";
			return el.attr("data-tooltip", text).removeAttr("title");
		}
		function showTooltip(event, el) {
			clearTimeout();
			tooltip.hide();
			handleTitleAttribute(el);
			if (el.data("htmltooltip")) {
				tooltipcontent.html(el.data("htmltooltip"));
			} else {
				tooltipcontent.text(el.attr("data-tooltip"));
			}

			if (tooltipcontent.text() == "") return;

			var help = el.data("help"); 
			if (!help) help = el.parents("[data-help]:first").data("help");
			tooltip.toggleClass("help", help != undefined);
			if (help != undefined) tooltip.data("help", help);
			else tooltip.removeData("help");
			tooltip.data("element",el);

			if (settings.delay>0) {
				toel.data("tttimeout", window.setTimeout(function() {
					setTooltipPosition(event, el).show();
					hideTooltip(settings.showtimeout);
				}, settings.delay));
			} else {
				setTooltipPosition(event, el).show();
				hideTooltip(settings.showtimeout);
			}
		}
		function handleMouseOver(event) {
			if (this!=event.target) return;
			showTooltip(event, $(this));
		}
		function handleMouseMove(event) {
			if (this!=event.target) return;
			if (tooltip.is(":visible") && tooltip.data("help")!=undefined) hideTooltip(settings.showhelptimeout);
			else if (tooltip.is(":visible") && settings.delay == 0) setTooltipPosition(event, $(this));
			else showTooltip(event, $(this));
		}
		function handleMouseOut(event) {
			if (this!=event.target) return;
			if (tooltip.is(":visible") && tooltip.data("help")!=undefined) hideTooltip(settings.hidehelptimeout);
			else hideTooltip(settings.hidetimeout);
		}
		function initElement(el) {
			el.off(".tooltip")
				.on("mouseenter.tooltip focus.tooltip", handleMouseOver)
				.on("mouseleave.tooltip blur.tooltip", handleMouseOut)
				.on("mousemove.tooltip", handleMouseMove);
		}
		return this;
	};
	$.fn.MyTooltip.handleHelp = function(help) {
		var w = $(window);
		$("<div/>").append(
				$("<iframe/>").attr({ name: "help", src: help, width: "99%", height: "99%"}).text(help)
		).dialog({ width: w.width()/2, height: w.height()/2, title: $("#help").text(), dialogClass: "helpdialog" });
	};
	$.fn.MyTooltip.defaults = {
		delay: 500, // open tooltip with a daily of ... ms
		showtimeout: 3000, // hide tooltip after ... ms
		showhelptimeout: 7000, // hide tooltip with help button after ... ms
		hidetimeout: 0, // hide tooltip in case of focus lost in ... ms
		hidehelptimeout: 3000, // in case of focus lost hide tooltip with help button in ... ms
		helphandler : $.fn.MyTooltip.handleHelp, // handler for the help button
		mOffsetX : 0, // x offset from mouse cursor
		mOffsetY : 20, // y offset from mouse cursor
		fOffsetX : -10, // x offset  from focused element left or right corner
		fOffsetY : 10, // y offset from focused element from top or bottom corner
	};
}( jQuery ));