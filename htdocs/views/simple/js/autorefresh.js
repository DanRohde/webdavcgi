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
initAutoRefresh();

function initAutoRefresh() {
	$(".autorefreshmenu").on("dblclick", function() { updateFileList(); } );
	toggleButton($(".action.autorefreshrunning, .autorefreshtimer"), true);
	$(document).on("mycountdowntimer-started", function(e, data) {
		toggleButton($(".action.autorefreshrunning, .autorefreshtimer"), false);
		$("#autorefreshtimer").show();
		$(".action.autorefreshtoggle").addClass("running");
		renderAutoRefreshTimer(data.timeout);
	}).on("mycountdowntimer-paused", function(e, data) {
		renderAutoRefreshTimer(data.timeout);
		$(".action.autorefreshtoggle").removeClass("running");
	}).on("mycountdowntimer-stopped", function() {
		toggleButton($(".action.autorefreshrunning, .autorefreshtimer"), true);
		$("#autorefreshtimer").hide();
		$(".action.autorefreshtoggle").removeClass("running");
	}).on("mycountdowntimer-elapsed", function(e,data) {
		renderAutoRefreshTimer(data.timeout);
	}).on("mycountdowntimer-lapsed", function() {
		renderAutoRefreshTimer(0);
		updateFileList();
	});
	
	$("#flt").on("fileListChanged", function() {
		if ($.MyCookie("autorefresh") !== "" && parseInt($.MyCookie("autorefresh"),10)>0) $(document).MyCountdownTimer("start", parseInt($.MyCookie("autorefresh"),10));
	});
	$(".action.setautorefresh").click(function(){
		if ($(this).attr("data-value") === "now") {
			updateFileList();
			return;
		}
		$.MyCookie("autorefresh", $(this).attr("data-value"));
		$(document).MyCountdownTimer("start", parseInt($(this).data("value"),10));
	});
	$(".action.autorefreshclear").click(function() {
		if ($(this).hasClass("disabled")) return;
		$(document).MyCountdownTimer("stop");
		$.MyCookie.rmCookies("autorefresh");
	});
	$(".action.autorefreshtoggle").click(function() {
		if ($(this).hasClass("disabled")) return;
		$(document).MyCountdownTimer("toggle");
	});
	
	$("#autorefreshtimer").MyFixedElementDragger().MyTooltip();
}

function renderAutoRefreshTimer(aftimeout) {
	var t = $(".autorefreshtimer");
	var f = t.attr("data-template") || "%sm %ss";
	var minutes = Math.floor(aftimeout / 60);
	var seconds = aftimeout % 60;
	if (seconds < 10) seconds="0"+seconds;
	t.html(f.replace("%s", minutes).replace("%s", seconds));
}

