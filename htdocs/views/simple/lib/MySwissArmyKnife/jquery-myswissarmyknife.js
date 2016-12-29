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
	
	$.fn.MyFileTableSorter = function(stype,sattr,sortorder,cidx,ssattr) {
		var rows = this.children("tr").get();
		rows.sort(function(a,b){
			var ret = 0;
			var jqa = $(a);
			var jqb = $(b);
			var vala = jqa.attr(sattr) ? (stype=="number" ? parseInt(jqa.attr(sattr)) : jqa.attr(sattr)) : a.cells.item(cidx).innerHTML.toLowerCase();
			var valb = jqb.attr(sattr) ? (stype=="number" ? parseInt(jqb.attr(sattr)) : jqb.attr(sattr)) : b.cells.item(cidx).innerHTML.toLowerCase();
	
			if (jqa.attr("data-file").match(/^\.\.?$/)) return -1;
			if (jqb.attr("data-file").match(/^\.\.?$/)) return 1;
			if (jqa.attr("data-type") == "dir" && jqb.attr("data-type") != "dir") return -1;
			if (jqa.attr("data-type") != "dir" && jqb.attr("data-type") == "dir") return 1;
			
		
			if (stype == "number") {
				ret = vala - valb;
			} else {
				if (vala.localeCompare) {
					ret = vala.localeCompare(valb);
				} else {
					ret = (vala < valb ? -1 : (vala==valb ? 0 : 1));
				}
			}
			if (ret === 0 && sattr!=ssattr) {
				if (vala.localeCompare) {
					ret = jqa.attr(ssattr).localeCompare(jqb.attr(ssattr));
				} else {
					ret = jqa.attr(ssattr) < jqb.attr(ssattr) ? -1 : jqa.attr(ssattr) > jqb.attr(ssattr) ? 1 : 0;
				}
			}
			return sortorder * ret;
		});
		for (var r=0; r<rows.length; r++) {
			this.append(rows[r]);
		}
		return this;
	};
	
}( jQuery ));
