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
function notify(type,msg) {
	console.log("notify["+type+"]: "+msg);
	if ($.MyCookie("settings.messages."+type)=="no") return;
	noty({text: msg, type: type, layout: "topCenter", timeout: 30000 });
	$("body").trigger("notify",{type:type,msg:msg});
// var notification = $("#notification");
// notification.removeClass().hide();
// notification.off("click").click(function() { $(this).hide().removeClass();
// }).addClass(type).html("<span>"+$.MyStringHelper.simpleEscape(msg)+"</span>").show();
	// .fadeOut(30000,function() { $(this).removeClass(type).html("");});
}
function notifyError(error) {
	notify("error",error);
}
function notifyInfo(info) {
	notify("message",info);
}
function notifyWarn(warn) {
	notify("warning",warn);
}