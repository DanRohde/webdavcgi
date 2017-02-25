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

initViewFilterDialog();

function initViewFilterDialog() {
	$(".action.viewfilter").click(function(event){
		$.MyPreventDefault(event);
		if ($(this).hasClass("disabled")) return;
		var self = $(this);
		$(".action.viewfilter").addClass("disabled");
		var target =$("#fileList").attr("data-uri");
		var template = self.attr("data-template");
		$.MyPost(target, {ajax: "getViewFilterDialog", template: template}, function(response){
			var vfd = $(response);
			$("input[name='filter.size.val']", vfd).spinner({min: 0, page: 10, numberFormat: "n", step: 1});
			$(".filter-apply", vfd).button().click(function(){
				$.MyCookie.toggleCookie(
						"filter.name", 
						$("select[name='filter.name.op'] option:selected", vfd).val()+" "+$("input[name='filter.name.val']",vfd).val(),
						$("input[name='filter.name.val']", vfd).val() !== ""
				);
				$.MyCookie.toggleCookie(
						"filter.size",
						$("select[name='filter.size.op'] option:selected",vfd).val() + $("input[name='filter.size.val']",vfd).val() + $("select[name='filter.size.unit'] option:selected",vfd).val(),
						$("input[name='filter.size.val']", vfd).val() !== ""
				);
				if ($("input[name='filter.types']:checked", vfd).length > 0) {
					var filtertypes = "";
					$("input[name='filter.types']:checked", vfd).each(function(i,val) {
						filtertypes += $(val).val();
					});
					$.MyCookie("filter.types", filtertypes);
				} else $.MyCookie.rmCookies("filter.types");
				vfd.dialog("close");
				updateFileList();
			});
			$(".filter-reset", vfd).button().click(function(ev){
				$.MyPreventDefault(ev);
				$.MyCookie.rmCookies("filter.name", "filter.size", "filter.types");
				vfd.dialog("close");
				updateFileList();
			});
			vfd.submit(function(){
				return false;
			});
			vfd.dialog({modal:true,width:"auto",height:"auto", dialogClass: "viewfilterdialog", title: self.attr("title") || self.data("title"), close: function(){$(".action.viewfilter").removeClass("disabled"); vfd.remove();}}).show();
		});
	});
}