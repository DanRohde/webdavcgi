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

initFilterBox();
initDotFilter();

function initFilterBox() {
	$("form#filterbox").submit(function(event) { return false;});
	$("form#filterbox input")
		.keydown(function(e) { if (e.keyCode==27) $(this).val(""); })
		.on("keyup change", applyFilter)
		.autocomplete({minLength: 1, select: applyFilter, close: applyFilter});
	// clear button:
	$("form#filterbox .action.clearfilter").toggleClass("invisible",$("form#filterbox input").val()=== "");
	$("form#filterbox input").keyup(function() {
		$("form#filterbox .action.clearfilter").toggleClass("invisible",$(this).val()=== "");
	});
	$("form#filterbox .action.clearfilter").click(function(event) {
		$.MyPreventDefault(event);
		$("form#filterbox input").val("");
		applyFilter();
		$(this).addClass("invisible");
	});
	
	$("#flt")
		.on("fileListChanged", applyFilter)
		.on("fileListChanged", function() {
			var files = $.map($("#fileList tr"),function(val) { return $(val).attr("data-file");});
			$("form#filterbox input")
				.autocomplete({ 
					source: function(request, response) {
						try {
							var matcher = new RegExp(request.term);
							response($.grep(files, function(item){ return matcher.test(item); }));
						} catch (e) {
							response($.grep(files, function(item){ return item.indexOf(request.term)>-1; }));
						}
					}
				});
		});
}
function applyFilter() {
	var filter = $("form#filterbox input").val();
	$("#fileList tr").each(function() {
		try {
			var r = new RegExp(filter,"i");
			if (filter === "" || $(this).attr("data-file").match(r)) $(this).show(); else $(this).hide();	
		} catch (error) {
			if (filter === "" || $(this).attr("data-file").toLowerCase().indexOf(filter.toLowerCase()) >-1) $(this).show(); else $(this).hide();
		}
	});

	$("#flt").trigger("fileListViewChanged");
	return true;
}
function initDotFilter() {
	$("body").off("settingchanged.initDotFilter").on("settingchanged.initDotFilter",function(e,data) {
		if (data.setting == "settings.show.dotfiles") {
			$("body").toggleClass("hidedotfiles", !data.value);
			$("#flt").trigger("fileListViewChanged");
		} else if (data.setting == "settings.show.dotfolders") {
			$("body").toggleClass("hidedotfolders", !data.value);
			$("#flt").trigger("fileListViewChanged");
		}
	});
	$("body").toggleClass("hidedotfiles", $.MyCookie("settings.show.dotfiles") == "no");
	$("body").toggleClass("hidedotfolders", $.MyCookie("settings.show.dotfolders") == "no");
}

