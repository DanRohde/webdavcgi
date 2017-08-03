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
initSettingsDialog();
function initSettingsDialog() {
	var settings = $("#settings");
	settings.data("initHandler", { init: function() {
		$("input[type=checkbox][name^='settings.']", settings).each(function(i,v) {
			$(v).prop("checked", $.MyCookie($(v).prop("name")) != "no").click(function() {
				if ($.MyCookie($(this).prop("name")+".keep")) 
					$.MyCookie($(this).prop("name"),$(this).is(":checked")?"yes":"no",1);
				else 
					$.MyCookie.toggleCookie($(this).prop("name"),"no",!$(this).is(":checked"), 1);
				$("body").trigger("settingchanged", { setting: $(this).prop("name"), value: $(this).is(":checked") });
			});
		});
		$("select[name^='settings.']", settings)
			.change(function(){
				if ($(this).prop("name") == "settings.lang") {
					$.MyCookie($(this).prop("name").replace(/^settings./,""),$("option:selected",$(this)).val(),1);
					window.location.href = window.location.pathname; // reload bug fixed (if query view=...)
				} else {
					$.MyCookie($(this).prop("name"), $("option:selected",$(this)).val(),1);
					$("body").trigger("settingchanged", { setting: $(this).prop("name"), value: $("option:selected",$(this)).val()});
				}
			})
			.each(function(i,v) {
				var s = $(v);
				var name = s.prop("name");
				if (name == "settings.lang") name = name.replace(/^settings\./,"");
				$("option[value='"+$.MyCookie(name)+"']", s).prop("selected",true);
			});
		$(".tabsel.activetabsel").focus();
	}});
}