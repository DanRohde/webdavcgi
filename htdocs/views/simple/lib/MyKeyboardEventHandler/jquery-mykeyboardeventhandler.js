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
	$.fn.MyKeyboardEventHandler = function(options) {
		var settings = $.extend( {
			namespace : "mykeyboardeventhandler"
		}, options);
		
		this.off("keyup."+settings.namespace).on("keyup."+settings.namespace, keyboardEventHelper);
		function preventDefault(event) {
			if (event.preventDefault) event.preventDefault(); else event.returnValue = false;
			if (event.stopPropagation) event.stopPropagation();
		}

		function keyboardEventHelper(event) {
			if (event.target != this) return;
			preventDefault(event);
			var self = $(this);
			var d;
			switch (event.keyCode) {
			case 32: // space
			case 13: // return/enter
				if (self.data("input-finished")) {
					self.removeData("input-finished");
					return;
				}
				self.trigger("click", { origEvent : event });
				break;
			case 27: // escape
				if (self.data("input-canceled")) { // hack for inplace inputs in popups, ...
					self.removeData("input-canceled");
					return;
				}
				self.closest(".dropdown-menu").hide();
				self.closest("ul.popup:visible").hide();
				$("ul.popup:visible", self).hide();
				self.closest(":focusable").focus();
				break;
			case 34: // page down
			case 35: // end
				self.nextAll(":not([tabindex=-1]):focusable:last").focus(); // last sibling
				break;
			case 33: // page up
			case 36: // home
				self.prevAll(":not([tabindex=-1]):focusable:last").focus(); // top sibling
				break;
			case 37: // left
				if ( (d = self.prevAll(":not([tabindex=-1]):focusable")).length >0 ) //  next sibling
					d.first().focus();
				else 
					self.parents(":focusable").prevAll(":not([tabindex=-1]):focusable:first").focus(); // first parent sibling
				break;
			case 38: // up
				if ( (d = self.prevAll(":not([tabindex=-1]):focusable")).length >0 ) // prev. sibling
					d.first().focus();
				else
					self.parents(":not([tabindex=-1]):focusable").first().focus(); // parent
				break;
			case 39: // right
				if ( (d=self.nextAll(":not([tabindex=-1]):focusable")).length>0) // next sibling 
					d.first().focus();
				else
					self.parents(":focusable").nextAll(":not([tabindex=-1]):focusable:first").focus(); // prev. parent sibling
				break;
			case 40: // down 
				if ((d=$(":not([tabindex=-1]):focusable",self)).length > 0) // first child
					d.first().focus();
				 else 
					self.nextAll(":not([tabindex=-1]):focusable:first").focus(); // next sibling
				break;
			}
		}
		return this;
	};
}( jQuery ));