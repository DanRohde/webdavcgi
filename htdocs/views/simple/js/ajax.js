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
$.ajaxSetup({ traditional: true, async : true });

$(document).ajaxError(function(event, jqxhr, settings, exception) { 
	console.log(event);
	console.log(jqxhr); 
	console.log(settings);
	console.log(exception);
	$.MyPageBlocker("remove");
	if (jqxhr) {
		if (jqxhr.getResponseHeader("Location")) {
			window.open(jqxhr.getResponseHeader("Location"),"_blank");
		} else if (jqxhr.statusText && jqxhr.statusText != "abort") {
			notifyError(jqxhr.statusText == "error" ? $("#ajax-connection-error").html() : jqxhr.statusText);
		}
	}
	//if (jqxhr.status = 404) window.history.back();
}).ajaxSuccess(function(event,jqxhr) {
	if (jqxhr.getResponseHeader("X-Login-Required")) {
		window.alert($("#login-session").text());
		window.location.href = jqxhr.getResponseHeader("X-Login-Required");
	} else if (jqxhr.getResponseHeader("Location")) {
		window.open(jqxhr.getResponseHeader("Location"),"_blank");
	}
});
// allow script caching:
$.ajaxPrefilter("script",function( options ) { options.cache = true; });

function handleJSONResponse(response) {
	if (response.error) notifyError(response.error);
	if (response.warn) notifyWarn(response.warn);
	if (response.message) notifyInfo(response.message);
	if (response.quicknav) {
		$("#quicknav").html(response.quicknav).MyTooltip();
		$("#quicknav a").click(function(event) {
			$.MyPreventDefault(event);
			changeUri($(this).attr("href"));
		});
	}
}
function getDialog(data, initfunc) {
	var xhr = $.MyGet(window.location.pathname, data, function(response) {
		handleJSONResponse(response);
		initfunc(response);
	});
	renderAbortDialog(xhr);
}
function getDialogByPost(data, initfunc) {
	var xhr = $.MyPost(window.location.pathname, data, function(response) {
		handleJSONResponse(response);
		initfunc(response);
	});
	renderAbortDialog(xhr);
}
