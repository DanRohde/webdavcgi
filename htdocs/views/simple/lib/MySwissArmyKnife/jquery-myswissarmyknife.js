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
(function ( $ ) {
	$.fn.MyClock = function(format) {
		var clock = this;
		var fmt = format;
		if (!fmt) fmt = clock.data("format");
		if (!fmt) fmt = "%H:%M:%S";
		window.setInterval(function() {
			function addzero(v) { return v<10 ? "0"+v : v; }
			var d = new Date();
			var s = fmt;
			// %H = 00-23; %I = 01-12; %k = 0-23; %l = 1-12
			// %M = 00-59; %S = 0-60
			s = s.replace(/%(H|k)/, addzero(d.getHours()))
			.replace(/%(I|l)/, addzero(d.getHours() % 12 === 0 ? 12 : d.getHours() % 12) )
			.replace(/%M/, addzero(d.getMinutes()))
			.replace(/%S/, addzero(d.getSeconds()));
			clock.html(s);	
		}, fmt.match(/%S/) ? 1000 : 60000);
		return this;
	};
	
	$.fn.MyFixedElementDragger = function(cookiename) {
		var drag = this;
		var cn = cookiename === undefined ? this.attr("id") : cookiename;
		this.css("position","fixed");
		drag.draggable({ 
			stop: function(e,ui) { 
				$.MyCookie(cn, JSON.stringify(fixElementPosition(ui.offset))); 
			}
		});
		if ($.MyCookie(cn)) fixElementPosition(JSON.parse($.MyCookie(cn)));
		function fixElementPosition(position) {
			var w = $(window);
			var newposition = { 
					left: Math.min(Math.max(position.left, 0), w.width() - drag.outerWidth() + w.scrollLeft() ), 
					top:  Math.min(Math.max(position.top, 0), w.height() - drag.outerHeight() + w.scrollTop() ) 
			};
			drag.offset(newposition);
			return newposition;
		}
		return this;
	};
	
	$.MyStringHelper = {};
	$.MyStringHelper.renderByteSizes = function(size) {
		var text = "";
		text += size+" Byte(s)";
		var nfs = size / 1024;
		if (nfs.toFixed(2) > 0) text +=" = "+nfs.toFixed(2)+"KB";
		nfs /= 1024;
		if (nfs.toFixed(2) > 0) text +=" = "+nfs.toFixed(2)+"MB";
		nfs /= 1024;
		if (nfs.toFixed(2) > 0) text +=" = "+nfs.toFixed(2)+"GB";
		nfs /= 1024;
		if (nfs.toFixed(2) > 0) text +=" = "+nfs.toFixed(2)+"TB";
		return text;
	};
	$.MyStringHelper.renderByteSize = function(size) {
		var text = size+" Byte(s)";
		var nfs = size / 1024;
		if (nfs.toFixed(2) > 0 && nfs > 1) text = nfs.toFixed(2)+"KB";
		nfs /= 1024;
		if (nfs.toFixed(2) > 0 && nfs > 1) text =nfs.toFixed(2)+"MB";
		nfs /= 1024;
		if (nfs.toFixed(2) > 0 && nfs > 1) text =nfs.toFixed(2)+"GB";
		nfs /= 1024;
		if (nfs.toFixed(2) > 0 && nfs > 1) text =nfs.toFixed(2)+"TB";
		return text;
	};
	$.MyStringHelper.trimString = function(str,charcount) {
		var ret = str;
		if (str.length > charcount) ret = str.substr(0,4)+"..."+str.substr(str.length-charcount+7,charcount-7);
		return ret;
	};
	$.MyStringHelper.simpleEscape = function(text) {
		// return text.replace(/&/,'&amp;').replace(/</,'&lt;').replace(/>/,'&gt;');
		return $("<div/>").text(text).html();
	};
	$.MyStringHelper.uri2html = function(uri) {
		return $.MyStringHelper.simpleEscape(decodeURIComponent(uri));
	};
	$.MyStringHelper.quoteWhiteSpaces = function(filename) {
		return filename.replace(/( {2,})/g, '<span class="ws">$1</span>');
	};
	$.MyStringHelper.addMissingSlash = function(base) {
		return (base+"/").replace(/\/\//g,"/");
	};
	$.MyStringHelper.concatUri = function(base,file) {
		return ($.MyStringHelper.addMissingSlash(base) + file).replace(/\/\//g,"/").replace(/\/[^\/]+\/\.\.\//g,"/");
	};
	$.MyStringHelper.stripSlash = function(uri) {
		return uri.replace(/\/$/,"");
	};
	
	
	$.MyTokenExtender = function(param) {
		var result = param;
		var token = $("#token");
		if (token.length>0) {
			result[token.attr("name")] = token.val();
		}
		return result;
	};
	$.MyPageBlocker = function(param) {
		if (param === "remove") {
			$(".pageblocker").remove();
			return 1;
		}
		return $("<div/>").addClass("pageblocker").appendTo("body");
	};
	$.MyGet = function(uri, param, callback, unblocked, dataType) {
		if (!unblocked) $.MyPageBlocker();
		var xhr = $.get(uri, $.MyTokenExtender(param), function(response) {
			if (!unblocked) $.MyPageBlocker("remove");
			callback.call(this, response);
			
		}, dataType);
		return xhr;
	};
	$.MyPost = function(uri, param, callback, unblocked, dataType) {
		if (!unblocked) $.MyPageBlocker();
		var xhr = $.post(uri, $.MyTokenExtender(param), function(response) {
			if (!unblocked) $.MyPageBlocker("remove");
			callback.call(this,response);
		}, dataType);
		return xhr;
	};
	
	$.MyCookie = function(name,val,expires) {
		var date = new Date();
       	date.setTime(date.getTime() + 315360000000);
       	if (val) return Cookies.set(name, val, { path:$("#flt").attr("data-baseuri"), secure: true, expires: expires ? date : undefined});
       	return Cookies.get(name);
	};
	$.MyCookie.rmCookies = function() {
		for (var i=0; i < arguments.length; i++) Cookies.remove(arguments[i], { path:$("#flt").attr("data-baseuri"), secure: true});
	};
	$.MyCookie.toggleCookie = function(name,val,toggle,expires) {
		if (toggle) $.MyCookie(name,val,expires);
		else $.MyCookie.rmCookies(name);
	};


	$.MyPreventDefault = function(event) {
		if (event.preventDefault) event.preventDefault(); else event.returnValue = false;
		if (event.stopPropagation) event.stopPropagation();
	};
	
	$.toggleFullscreen = function(on) {
		var e = document.documentElement;
		if (on) {
			if (e.requestFullScreen) e.requestFullScreen();
			else if (e.mozRequestFullScreen) e.mozRequestFullScreen();
			else if (e.webkitRequestFullscreen) e.webkitRequestFullscreen();
			else if (e.webkitRequestFullScreen) e.webkitRequestFullScreen();
			else if (e.msRequestFullscreen) e.msRequestFullscreen();
		} else {
			if (document.cancelFullScreen) document.cancelFullScreen();
			else if (document.mozCancelFullScreen) document.mozCancelFullScreen();
			else if (document.webkitCancelFullScreen) document.webkitCancelFullScreen();
			else if (document.webkitCancelFullscreen) document.webkitCancelFullscreen();
			else if (document.msExitFullscreen) document.msExitFullscreen();
		}
	};
	$.isFullscreen = function() {
		return document.fullscreenElement || document.mozFullScreenElement || document.webkitFullscreenElement || document.msFullscreenElement ? true : false;
	}
	$.addFullscreenChangeListener = function(fn) {
		$(document).on("webkitfullscreenchange mozfullscreenchange fullscreenchange MSFullscreenChange", fn);
	}

}( jQuery ));
