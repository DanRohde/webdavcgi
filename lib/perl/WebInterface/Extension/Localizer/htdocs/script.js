/*********************************************************************
(C) ZE CMS, Humboldt-Universitaet zu Berlin
Written 2016 by Daniel Rohde <d.rohde@cms.hu-berlin.de>
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
$(document).ready(function() {
	$(".action.localizer").on("click", function() {
		$.MyPost(window.location.href, { action: "getLocalizerDialog" }, function(response) {
			ToolBox.handleJSONResponse(response);
			initDialog($(response));
		});
	});
	function protectedPost(dialog, data, handler) {
		if (!haveUnsavedChanges(dialog)) {
			$.MyPost(window.location.href, data, handler);
		}
	}
	function initDialog(dialog) {
		$(".contexthelp", dialog).MyContextHelp();
		$(".localizer-lang-required", dialog).prop("disabled", true).trigger("property-changed");
		$(".localizer-extension-required", dialog).prop("disabled", true).trigger("property-changed");
		$(".localizer-select-lang", dialog).on("change", function() { // language selector
			var self = $(this);
			var val = self.val();
			$(".localizer-lang-required", dialog).prop("disabled", val == "").prop("selectedIndex",0).val("").trigger("property-changed");
			$(".localizer-lang-notrequired", dialog).prop("disabled", val != "").prop("selectedIndex",0).val("").trigger("propery-changed");
			
		});
		$(".localizer-add-new-lang", dialog) // add new language input
		.on("change keyup", function() {
			var self = $(this);
			var val = self.val().trim();
			var isokay = val.match(/^[a-z]{2}(_[a-z]{2})?$/i) != null;
			$(".localizer-lang-required", dialog).prop("disabled", !isokay).trigger("property-changed");
			$(".localizer-select-lang", dialog).prop("disabled", isokay).trigger("property-changed");
		});
		$(".localizer-select-extension", dialog) // extension selector
		.on("change click property-changed", function() {
			$(".localizer-extension-required",dialog).prop("disabled", $(this).val().trim()=="" || $(this).prop("disabled")).trigger("property-changed");
		});
		$(".localizer-edit-extension-locale",dialog) // edit button of extension selector
		.on("click", function() {
			var sel = $(".localizer-select-extension",dialog);
			if (sel.val().trim() == "") return;
			protectedPost(dialog, { action: "getLocaleEditor", extension: sel.val(), localizerlang: getLang(dialog) }, function (response) {
				ToolBox.handleJSONResponse(response);
				initLocaleEditor(dialog, $(response.editor));
			});
		});
		
		$(".localizer-edit-uilocale",dialog) // edit buttonfor UI locale
		.on("click", function() {
			protectedPost(dialog, { action: "getLocaleEditor", localizerlang: getLang(dialog)}, function(response) {
				$(".localizer-select-extension",dialog).prop("selectedIndex",0);
				ToolBox.handleJSONResponse(response);
				initLocaleEditor(dialog, $(response.editor));
			});
		});
		$(".localizer-edit-help",dialog) // edit help button
		.on("click", function() {
			protectedPost(dialog, { action: "getHelpEditor", extension: $(".localizer-select-extension",dialog).val() , localizerlang: getLang(dialog)}, function(response) {
				ToolBox.handleJSONResponse(response);
				initHelpEditor(dialog, $(response.editor));
			});
		});
		$(".localizer-download-all", dialog) // download all button
		.on("click", function() {
			if (!haveUnsavedChanges(dialog)) ToolBox.postAction({ action:"downloadAllLocaleFiles", localizerlang: getLang(dialog) });
		});
		haveUnsavedChanges(dialog, false);
		$(".localizer-protect-unsaved-changes", dialog)
		.on("click change keydown", function(event) {
			if (haveUnsavedChanges(dialog)) {
				$.MyPreventDefault(event);
				return false;
			}
			return true;
		});
		var w = $(window);
		dialog.dialog({width: w.width()*0.8, maxHeight: w.height()*0.8, 
					 	dialogClass:"localizerdialog", closeOnEscape: false, 
					 	beforeClose: function() { return !haveUnsavedChanges(dialog); }
		});
		
	}
	function haveUnsavedChanges(dialog, flag) {
		if (flag === undefined) {
			if (dialog.data("unsavedchanges") && window.confirm($(".localizer-unsafed-changes-message",dialog).data("message"))) {
				dialog.data("unsavedchanges", false);
			}
		} else {
			dialog.data("unsavedchanges", flag);
		}
		$(".localizer-unsaved-changes-listener", dialog).toggleClass("localizer-unsaved-changes", dialog.data("unsavedchanges"));
		return dialog.data("unsavedchanges");
	}
	function getLang(dialog) {
		var lls = $(".localizer-select-lang",dialog);
		return lls.prop("disabled") ? $(".localizer-add-new-lang", dialog).val().trim() : lls.val();
	}
	function initHelpEditor(dialog, editor) {
		editor.find(".accordion").accordion({heightStyle: "content", collapsible: true, active: false});
		$(".localizer-download-helpfile, .localizer-save-helpfile", editor).click(function() {
			var self = $(this);
			var action = self.hasClass("localizer-download-helpfile") ? "downloadHelpFile" : "saveHelpFile";
			var data = { action : action, source: $(self.data("source")).val(), extension: self.data("extension"), filename: self.data("filename") };
			if (action == "saveHelpFile") {
				$.MyPost(window.location.href, data , function(response) { 
					ToolBox.handleJSONResponse(response); 
					if (!response.error && !response.warn) haveUnsavedChanges(dialog, false);
				});
			} else {
				haveUnsavedChanges(dialog, false);
				ToolBox.postAction(data);
			}
		});
		$(".localizer-preview", editor).click(function() {
			var self = $(this);
			var source = $(self.data("source"), editor);
			var preview = $(self.data("preview"), editor);
			
			source.toggle();
			preview.toggle();
			
			if (preview.is(":visible")) {
				if (!self.data("backuptext")) self.data("backuptext", self.html());
				self.html(self.data("buttontext"));
			} else {
				self.html(self.data("backuptext"));
			}
			var text = source.val().replace(/<head>/,"<head><base href=\""+self.data("docbase")+"\">");
			var doc = (preview[0].contentWindow || preview[0].contentDocument).document;
			doc.open();
			doc.write(text);
			doc.close();
			
		});
		$(".localizer-source", editor).on("keyup", function() { haveUnsavedChanges(dialog,true); });
		
		$(".localizer-editor-pane",dialog).empty().append(editor);
	}
	function initLocaleEditor(dialog, editor) {
		editor.find(".localizer-locale-editor-entry").on("click", function(ev) {
			var self = $(this);
			var trans = self.find(".localizer-locale-editor-entry-translation");
			self.addClass("localizer-locale-editor-entry-active");
			$.MyInplaceEditor({ 
				editorTarget: trans,
				spellcheck: true,
				lang: $(".localizer-editor-lang", editor).val(),
				allowtab: true,
				defaultValue: trans.text(), 
				changeEvent: function(data) {
					trans.text(data.value);
					//self.nextAll(":has(.localizer-locale-editor-entry-translation)").first().focus().click();
					self.nextAll(":focusable").first().focus().click();
					haveUnsavedChanges(dialog, true);
				},
				checkAllowedValue: function() {
					return true;
				},
				canvelEvent: function() {
					self.focus();
				},
				finalEvent: function() {
					self.removeClass("localizer-locale-editor-entry-active");
				}
			});
		}).MyKeyboardEventHandler();
		
		editor.find(".localizer-locale-editor-button-save").on("click", function() {
			$.MyPost(window.location.href, getLocaleEditorPostData(editor, "saveLocalization") , function(response) {
				ToolBox.handleJSONResponse(response);
				if (!response.error && !response.warn) haveUnsavedChanges(dialog, false);
			});
		});

		editor.find(".localizer-locale-editor-button-download").on("click", function() {
			haveUnsavedChanges(dialog, false);
			ToolBox.postAction(getLocaleEditorPostData(editor, "downloadLocalization"));
		});

		$(".localizer-editor-pane",dialog).empty().append(editor);
		
	}
	function getLocaleEditorPostData(editor, action) {
		return { 
				action: action,
				localizerlang: editor.find(".localizer-editor-lang").val(),
				localizertype: editor.find(".localizer-editor-type").val(),
				localizertypeval: editor.find(".localizer-editor-typeval").val(),
				localization: getLocalization(editor)
		};
	}
	function getLocalization(editor) {
		var localization = {};
		editor.find(".localizer-locale-editor-entry-translation").each(function(i,v) {
			var self = $(v);
			if (self.text().match(/^\s*$/)==null) localization[self.data("key")] = self.text();
		});
		return JSON.stringify(localization);
	}
});