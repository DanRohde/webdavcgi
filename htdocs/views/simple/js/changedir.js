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

initChangeDir();

function initChangeDir() {
	$("#pathinputform").submit(function() { return false; });
	$("#pathinputform input[name='uri']").keydown(function(event){
		if (event.keyCode==27) {
			$("#pathinput").hide();
			$("#quicknav").show();
			$(".filterbox").show();
		} else if (event.keyCode==13) {
			$.MyPreventDefault(event);
			$("#pathinput").hide();
			$("#quicknav").show();
			$(".filterbox").show();
			changeUri($(this).val());
		}
	});
	$(".action.changedir").button().click(function(event) {
		$.MyPreventDefault(event);
		$("#pathinput").toggle();
		$("#quicknav").toggle();
		$("#pathinput input[name=uri]").focus().select();
		$(".filterbox").toggle();
	});
	$("#path [data-action='chdir']").button().click(function(event){
		$.MyPreventDefault(event);
		$("#pathinput").hide();
		$("#quicknav").show();
		changeUri($("#pathinput input[name='uri']").val());
	});
	$("#flt").on("fileListChanged", function() {
		$("#pathinput input[name=uri]").val(decodeURI($("#fileList").attr("data-uri")));
	});
}