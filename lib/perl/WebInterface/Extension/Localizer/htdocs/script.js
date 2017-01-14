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
	
	function initDialog(dialog) {
		$(".contexthelp", dialog).MyContextHelp();
		$(".localizer-lang-required", dialog).prop("disabled", true);
		$(".localizer-select-lang", dialog).on("change", function() {
			var self = $(this);
			var val = self.val();
			$(".localizer-lang-required", dialog).prop("disabled", val == "");
			
			var lse = $(".localizer-select-extension",dialog);
			if (val != "" && lse.val()!="") lse.trigger("change"); 
		});
		$(".localizer-add-new-lang", dialog)
		.on("change keyup", function() {
			var self = $(this);
			var val = self.val().trim();
			var isokay = val.match(/^[a-z]{2}(_[a-z]{2})?$/i) != null;
			$(".localizer-lang-required", dialog).prop("disabled", !isokay);
			$(".localizer-select-lang", dialog).prop("disabled", isokay);
		});
		$(".localizer-select-extension",dialog)
		.on("change", function() {
			$.MyPost(window.location.href, { action: "getLocaleEditor", extension: $(this).val(), localizerlang: getLang(dialog) }, function (response) {
				ToolBox.handleJSONResponse(response);
				initLocaleEditor(dialog, $(response.editor));
			});
		});
		
		$(".localizer-edit-uilocale",dialog)
		.on("click", function() {
			$(".localizer-select-extension",dialog).prop("selectedIndex",0);
			$.MyPost(window.location.href, { action: "getLocaleEditor", localizerlang: getLang(dialog)}, function(response) {
				ToolBox.handleJSONResponse(response);
				initLocaleEditor(dialog, $(response.editor));
			});
		});
		$(".localizer-download-all", dialog)
		.on("click", function() {
			ToolBox.postAction({ action:"downloadAllLocaleFiles", localizerlang: getLang(dialog) });
		});
		var w = $(window);
		dialog.dialog({width: w.width()*0.8, maxHeight: w.height()*0.8, dialogClass:"localizerdialog", closeOnEscape: false});
		
	}
	function getLang(dialog) {
		var lls = $(".localizer-select-lang",dialog);
		return lls.prop("disabled") ? $(".localizer-add-new-lang", dialog).val().trim() : lls.val();
	}
	function initLocaleEditor(dialog, editor) {
		editor.find(".localizer-locale-editor-entry-translation").on("click", function() {
			var self = $(this);
			self.closest("tr").addClass("localizer-locale-editor-entry-active");
			$.MyInplaceEditor({ 
				editorTarget: self,
				spellcheck: true,
				lang: $(".localizer-editor-lang", editor).val(),
				allowtab: true,
				defaultValue: self.text(), 
				changeEvent: function(data) {
					self.text(data.value);
					self.closest("tr")
						.nextAll(":has(.localizer-locale-editor-entry-translation):first")
						.find(".localizer-locale-editor-entry-translation").focus().click();
				},
				checkAllowedValue: function() {
					return true;
				},
				canvelEvent: function() {
					self.focus();
				},
				finalEvent: function() {
					self.closest("tr").removeClass("localizer-locale-editor-entry-active");
				}
			});
		}).MyKeyboardEventHandler();
		
		editor.find(".localizer-locale-editor-button-save").on("click", function() {
			$.MyPost(window.location.href, getLocaleEditorPostData(editor, "saveLocalization") , function(response) {
				ToolBox.handleJSONResponse(response);
			});
		});

		editor.find(".localizer-locale-editor-button-download").on("click", function() {
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