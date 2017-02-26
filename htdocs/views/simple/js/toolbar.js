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

initToolbarActions();

function initToolbarActions() {
	$(".toolbar li.uibutton").button();
	$(".toolbar .action").click(handleFileListActionEvent).MyKeyboardEventHandler();
	$(".toolbar > li.popup").addClass("popup-click");
	$(".toolbar li.popup").MyPopup();
	$("#flt").on("beforeFileListChange fileListSelChanged", function() { $(".toolbar li.popup").MyPopup("close"); });
	
	var inplaceOptions = {
		actionInterceptor: function() {
			return $(this).hasClass("disabled");
		},
		beforeEvent: function() {
			$("#flt").enableSelection();
			$(this).closest("ul.popup:hidden").show();
		},
		cancelEvent: function() {
			$(this).next().focus();
		},
		finalEvent: function(success) {
			$("#flt").disableSelection();
			if (success) $(this).closest("ul").hide();
		}
	};
	
	$(".action.create-folder").MyInplaceEditor($.extend(inplaceOptions,  
		{ changeEvent: function(data) {
			$.MyPost(getURI(), { mkcol : "yes", colname : data.value }, function(response) {
				if (!response.error && response.message) 
					$("#flt").trigger("filesCreated", { base: getURI(), files: [data.value] });
				handleJSONResponse(response);
			});
		}}));

	$(".action.create-file").MyInplaceEditor($.extend(inplaceOptions,
		{ changeEvent: function(data) {
			$.MyPost(getURI(), { createnewfile : "yes", cnfname : data.value }, function(response) {
				if (!response.error && response.message) 
					$("#flt").trigger("filesCreated", { base: getURI(), files: [data.value] });
				handleJSONResponse(response);
			});
		}}));

	$(".action.create-symlink").MyInplaceEditor($.extend(inplaceOptions,
		{ changeEvent: function(data) {
			var row = getSelectedRows(this);
			$.MyPost(getURI(), { createsymlink: "yes", lndst: data.value, file: row.attr("data-file") }, function(response) {
				if (!response.error && response.message) 
					$("#flt").trigger("filesCreated", { base: getURI(), files: [data.value] });
				handleJSONResponse(response);
			});
		}}));
}