/*********************************************************************
(C) ZE CMS, Humboldt-Universitaet zu Berlin
Written 2014 by Daniel Rohde <d.rohde@cms.hu-berlin.de>
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
	ToolBox.initUpload($("#zipfile-up-form"), $("#zipupconfirm").html(),$("#progress").attr('data-title'), false);
	$(".action.zipup").click(function(event) {
		ToolBox.preventDefault(event);
		if ($(this).hasClass('disabled')) return;
		$("#zipfile-up-form input[type=file]").trigger("click");
	})
	$("body").on('fileActionEvent', function(event, data) {
		if (data.obj.hasClass('zipdwnload')) {
			ToolBox.postAction({'action' : 'zipdwnload', 'files' : data.obj.hasClass('listaction') ? data.selected : data.file});
			/*if (data.obj.hasClass('listaction')) ToolBox.uncheckSelectedRows();*/
		} else if (data.obj.hasClass('zipup')) {
			$("#zipfile-up-form input[type=file]").trigger("click");
		}
	});
});