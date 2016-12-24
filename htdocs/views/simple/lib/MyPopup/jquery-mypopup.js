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
	$.fn.MyPopup = function(options) {
		if (options === "close") {
			$("ul.popup:visible",this).hide();
			return this;	
		}
		
		var settings = $.extend( {
			namespace: "popupnavigation",
			timername: "popupnavigationtimer"
		}, options);
		
		/* IDEA: don't close a popup if a popup was leaved or lost focus -> look at siblings */
		
		function preventDefault(event) {
			if (event.preventDefault) event.preventDefault(); else event.returnValue = false;
			if (event.stopPropagation) event.stopPropagation();
		}
		function toggle_popup(obj, toggle) {
			if (obj.hasClass("disabled")) return obj;
			$("ul.popup:first", obj).toggle(toggle);
			if (!$("ul.popup:first", obj).is(":visible")) {
				$("ul.popup", obj).hide(); /* hide all sub popups */
			}
			return obj;
		}
		function clear_timeout(obj) {
			window.clearTimeout($("body").data(settings.timername));
			return obj;
		}
		function hide_siblings(obj) {
			$("ul.popup:visible", obj.siblings("li.popup")).hide();
			return obj;
		}
		
		this.filter(":not(.popup-click)").off("."+settings.namespace).on("mouseenter."+settings.namespace, function() { /* show popup if mouse entered it and after a little timeout */
			var self = $(this);
			clear_timeout(self);
			$("body").data(settings.timername,
					window.setTimeout(function() {
						toggle_popup(hide_siblings(self), true);
					}, 350)
			);
		}).on("click."+settings.namespace+" dblclick."+settings.namespace, function(ev) {
			preventDefault(ev);
			var self = $(this);
			toggle_popup(hide_siblings(clear_timeout(self)));
			$(":focusable:first",self).focus();
		}).MyKeyboardEventHandler();
		
		/* clean up all events for .popup-click popups and handle click separatly:*/
		this.filter(".popup-click").off("."+settings.namespace).on("click."+settings.namespace+" dblclick."+settings.namespace, function(ev) {
			preventDefault(ev);
			toggle_popup(hide_siblings($(this)));
		}).MyKeyboardEventHandler();
		
		/* close siblings on focus change: */
		this.on("focus."+settings.namespace, function() {
			hide_siblings($(this));
		});
		
		/* close popups if siblings in navigation are entered or clicked:*/
		this.siblings(":not(.popup)").off("."+settings.namespace).on("focus."+settings.namespace+" click."+settings.namespace+" mouseenter."+settings.namespace, function() {
			hide_siblings($(this));
		});
		/* don't close siblings on mouseenter if a popup menu is a .popup-click popup: */
		this.filter(".popup-click").siblings("li:not(.popup)").off("mouseenter."+settings.namespace);
		
		return this;
	};
	
}( jQuery ));
