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
	$.fn.MyInplaceEditor = function(options) {
		var settings = $.extend({}, $.fn.MyInplaceEditor.settings, options, { actionTarget: this });
		settings.actionTarget.off("click.myinplaceeditor").on("click.myinplaceeditor", function() {
			replaceOrigHTML(settings);
		});
		return this;
	};
	$.MyInplaceEditor = function(options) {
		return replaceOrigHTML($.exend({}, $.fn.MyInplaceEditor.settings, options, { actionTarget: {} }));
	};
	function preventDefault(event) {
		if (event.preventDefault) event.preventDefault(); else event.returnValue = false;
		if (event.stopPropagation) event.stopPropagation();
	}
	function initInputField(settings) {
		var actionTarget = settings.actionTarget;
		var editorTarget = getEditorTarget(settings);

		var defaultValue = typeof settings.defaultValue === "function" ? settings.defaultValue.call(actionTarget) : settings.defaultValue;
		var input = $("<input/>").addClass(settings.inputClass)
						.on("click",function(e) { preventDefault(e); $(this).focus(); } )
						.off("dblclick").on("dblclick",preventDefault);
		if (defaultValue) input.val(defaultValue);
		
		return input.keydown(function(ev) {
			if (ev.keyCode == 13) {
				preventDefault(ev);
				var val = $(this).val();
				restoreOrigHTML(actionTarget, editorTarget).closest(":focusable").focus();
				if (settings.checkAllowedValue(val, defaultValue)) {
					triggerEvent(settings.changeEvent, actionTarget, { value : val } );
				}
				triggerEvent(settings.finalEvent, actionTarget);
			} else if (ev.keyCode == 27) {
				preventDefault(ev);
				restoreOrigHTML(actionTarget, editorTarget).closest(":focusable").focus();
				triggerEvent(settings.finalEvent, actionTarget);
			}
		}).focusout(function() {
			restoreOrigHTML(actionTarget, editorTarget);
		});
	}
	function getEditorTarget(settings) {
		if ( settings.editorTarget === null) return settings.actionTarget;
		return typeof settings.editorTarget === "function" ? settings.editorTarget.call(settings.actionTarget) : settings.editorTarget;
	}
	function replaceOrigHTML(settings) {
		var editorTarget = getEditorTarget(settings);
		if (!settings.actionInterceptor || settings.actionInterceptor.call(settings.actionTarget)) return editorTarget;
		settings.actionTarget.data("orig-html", editorTarget.html());
		triggerEvent(settings.beforeEvent, settings.actionTarget);
		return editorTarget.html(initInputField(settings)).find(":focusable").focus();
	}
	function restoreOrigHTML(store, target) {
		target.html(store.data("orig-html"));
		store.removeData("orig-html");
		return target;
	}
	function triggerEvent(target, source, data) {
		if (target) target.call(source, data);
	}
	
	$.fn.MyInplaceEditor.checkAllowedValue = function(value, defaultValue) {
		return (value !== "") && (!defaultValue || defaultValue != value);
	};
	$.fn.MyInplaceEditor.settings = {
			actionInterceptor: null,
			editorTarget: null, 
			defaultValue: null, 
			checkAllowedValue: $.fn.MyInplaceEditor.checkAllowedValue, 
			beforeEvent: null, 
			changeEvent: null, 
			finalEvent: null,
			inputClass : "myinplaceditor-input"
	};
}( jQuery ));