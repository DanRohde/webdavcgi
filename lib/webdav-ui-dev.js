/*
#########################################################################
# (C) ZE CMS, Humboldt-Universitaet zu Berlin
# Written 2010-2011 by Daniel Rohde <d.rohde@cms.hu-berlin.de>
#########################################################################
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/
var dragElID = null;
var dragElCID = null;
var dragOffset = new Object();
var dragZIndex = 10;
var dragOrigHandler = new Object();
var ID = 0;
function getEventPos(e) {
	var p = new Object();
	p.x = e.pageX ? e.pageX : e.clientX ? e.clientX : e.offsetX;
	p.y = e.pageY ? e.pageY : e.clientY ? e.clientY : e.offsetY;
	return p;
}
function getViewport() {
	var v = new Object();
	v.w = window.innerWidth || (document.documentElement && document.documentElement.clientWidth ? document.documentElement.clientWidth : 0) || document.getElementsByTagName('body')[0].clientWidth;
	v.h = window.innerHeight || (document.documentElement && document.documentElement.clientHeight ? document.documentElement.clientHeight : 0) || document.getElementsByTagName('body')[0].clientHeight;
	return v;
}
function getDragZIndex(z) {
	dragZIndex = getCookie('dragZIndex')!="" ? parseInt(getCookie('dragZIndex')) : dragZIndex;
	if (z && z>dragZIndex) dragZIndex = z + 10;
	setCookie('dragZIndex', ++dragZIndex,1);
	return dragZIndex;
}
function handleMouseDrag(event) {
	if (!event) event = window.event;       
	if (dragElID!=null) {
		var el = document.getElementById(dragElID);     
		if (el) {
			var p = getEventPos(event);
			var v = getViewport();
			if (p.x+dragOffset.x < 0 || p.y+dragOffset.y <0 || p.x > v.w ||  p.y > v.h ) return false;
			el.style.left = (p.x+dragOffset.x)+'px';
			el.style.top = (p.y+dragOffset.y)+'px';
			return false;
		}
	}
	return true;
}
function handleWindowMove(event, id, down) {
	if (!event) event=window.event;
	var e = document.getElementById(id);
	if (down) {
		if (e && event) {
			dragElID = id;
			var p = getEventPos(event);
			dragOffset.x = ( e.style.left ? parseInt(e.style.left) : 220 ) - p.x;
			dragOffset.y = ( e.style.top ? parseInt(e.style.top) : 120 ) - p.y;
			dragOrigHandler.onmousemove = document.onmousemove;
			document.onmousemove = handleMouseDrag;
			dragOrigHandler.onselectstart = document.onselectstart;
			document.onselectstart = function () { return false; };
			document.body.focus();
			event.ondragstart = function() { return false; };
			if (event.preventDefault) event.preventDefault(); else event.returnValue = false;
			e.style.zIndex = getDragZIndex(e.style.zIndex);
			addClassName(e,'move');
			return false;
		}
	} else {
		dragElID = null;
		document.onmousemove = dragOrigHandler.onmousemove;
		document.onselectstart = dragOrigHandler.onselectstart;
		if (e) { 
			removeClassName(e,'move');
			setCookie(id, 'true/'+e.style.left+'/'+e.style.top+'/'+e.style.zIndex+'/'+ e.className.match(/collapsed/),1);
		}
	}
	return true;
}
function handleMouseResize(event) {
	if (!event) event = window.event;
	if (dragElID!=null) {
		var el = document.getElementById(dragElID);
		if (!el) return true;
		var p = getEventPos(event);
		var nw = dragOffset.width + p.x - dragOffset.x;
		var nh = dragOffset.height + p.y - dragOffset.y;

		if (nw >= 10) el.style.width = nw + 'px';
		if (nh >= 10) el.style.height = nh + 'px';
		return false;
	}
	return true;
}
function handleWindowResize(event, id, down) {
	if (!event) event = window.event;
	var e = document.getElementById(id);
	if (down) {
		if (!e || !event) return true;
		var p = getEventPos(event);
		if (!e.style.width) e.style.width = (p.x - parseInt(e.style.left))+'px';
		if (!e.style.height) e.style.height = (p.y - parseInt(e.style.top))+'px';

		dragElID = id;
		dragOrigHandler.onmousemove = document.onmousemove;
		document.onmousemove = handleMouseResize;
		dragOrigHandler.noselectstart = document.onselectstart;
		document.onselectstart = function() { return false; }
		dragOffset.width = parseInt(e.style.width);
		dragOffset.height = parseInt(e.style.height);
		dragOffset.x = p.x;
		dragOffset.y = p.y;
		event.ondragstart = function() { return false; }
		document.body.focus();
		if (event.preventDefault) event.preventDefault(); else event.returnValue = false;
		addClassName(e, 'resize');
		return false;
	} else {
		dragElID = null;
		document.onmousemove = dragOrigHandler.onmousemove;
		document.onselectstart = dragOrigHandler.onselectstart;
		if (e) removeClassName(e,'resize');
	}
	return true;
}
function handleWindowClick(event, id, focusId) {
	var e = document.getElementById(id);
	if (!e) return true;
	e.style.zIndex = getDragZIndex(e.style.zIndex);
	setCookie(id, (e.style.visibility!='hidden')+'/'+e.style.left+'/'+e.style.top+'/'+e.style.zIndex+'/'+ e.className.match(/collapsed/),1);
	if (focusId) document.getElementById(focusId).focus();
	return true;
}
function toggleSideBar() {
	var e = document.getElementById('sidebarcontent');
	var ison = 1;
	if (e) {
		ison = !e.className.match(/collapsed/);
		toggleClassName(e, 'collapsed', ison);
		toggleClassNameById('sidebartable','collapsed', ison);
		toggleClassNameById('folderview','full', ison);
		document.getElementById('sidebartogglebutton').innerHTML = ison ? '&gt;' : '&lt;'
	}
	setCookie('sidebar', !ison, 1);
}
function showActionView(action, focusId) {
	var e = document.getElementById(action);
	if (e) { 
		var v = getViewport();
		var x = e.style.left ? e.style.left : '';
		var y = e.style.top ? e.style.top : '';
		if (x!="") if (parseInt(x) < v.w) e.style.left = x; else e.style.left = (v.w-100)+'px';
		if (y!="") if (parseInt(y) < v.h) e.style.top = y; else e.style.top = (v.h-100)+'px';
		e.style.visibility='visible';
		e.style.zIndex = getDragZIndex(e.style.zIndex);
		addClassNameById(action+'menu', 'active');
		setCookie(action, 'true/'+e.style.left+'/'+e.style.top+'/'+e.style.zIndex+'/'+e.className.match(/collapsed/),1);
		if (focusId) document.getElementById(focusId).focus();
	}
	return false;
}
function hideActionView(action) {
	var e = document.getElementById(action);
	if (e) e.style.visibility='hidden';
	removeClassNameById(action+'menu', 'active');
	setCookie(action, 'false/'+e.style.left+'/'+e.style.top+'/'+e.style.zIndex+'/'+e.className.match(/collapsed/),1);
}
function toggleActionView(action,focusId) {
	var e = document.getElementById(action);
	if (e && e.style.visibility=='visible') hideActionView(action); else showActionView(action, focusId); 
}
function addUploadField(force) {
	var e = document.getElementById('moreuploads');
	var fu = document.getElementsByName('file_upload');
	if (!force) for (var i = 0; i<fu.length; i++) if (fu[i].value == "") return false;
	e.id = 'moreuploads'+(new Date()).getTime();
	var rmid='fileuploadfield'+(new Date()).getTime();
	e.innerHTML = '<span id="'+rmid+'"><br/>'
			+ document.getElementById("file_upload").innerHTML 
			+ '<a class="rmuploadfield" title="'
			+ tl('rmuploadfieldtitle')
			+ '" href="#" onclick="document.getElementById(\''+rmid+'\').innerHTML=\'\'; return false;">'+tl('rmuploadfield')+'</a></span>'
			+ '<span id="moreuploads"></span>';
	return false;
}
function getBookmarkLocation() {
	return decodeURIComponent(window.location.pathname);
}
function addBookmark() {
	var loc = getBookmarkLocation();
	var i = 0;
	while (getCookie('bookmark'+i)!= "-" && getCookie('bookmark'+i) != "" && getCookie('bookmark'+i)!=loc) i++;
	if (getCookie('bookmark'+i) != loc) {
		setCookie('bookmark'+i, loc, 1);
		setCookie('bookmark'+i+'time', (new Date()).getTime(), 1);
		bookmarkcheck();
	}
	return false;
}
function rmBookmark() {
	var loc = getBookmarkLocation();
	var i = 0;
	while (getCookie('bookmark'+i) != "" && getCookie('bookmark'+i)!=loc) i++;
	if (getCookie('bookmark'+i) == loc) {
		setCookie('bookmark'+i, "-", 1);
		bookmarkcheck();
	}
}
function rmAllBookmarks() {
	var i = 0;
	while (getCookie('bookmark'+i) != "") {
		delCookie('bookmark'+i);
		delCookie('bookmark'+i+'time');
		i++;
	}
	bookmarkcheck();
}
function isBookmarked() {
	var loc = getBookmarkLocation();
	var i = 0;
	while (getCookie('bookmark'+i)!="") { 
		if (getCookie('bookmark'+i) == loc) return true; 
		i++; 
	}
	return false;
}
function toggleBookmarkButtons() {
	var ib = isBookmarked();
	if (document.getElementById('addbookmark')) {
		document.getElementById('addbookmark').style.display = ib ? 'none' : 'inline';
		document.getElementById('rmbookmark').style.display = ib ? 'inline' : 'none';
	}
}
function escapeQuotes(txt) {
	return txt.replace(/"/g, "&quot;");
}
function encodeSpecChars(uri) {
	uri = uri.replace(/%/g,"%25");
	uri = uri.replace(/#/g,"%23");
	uri = uri.replace(/&/g,"%26");
	uri = uri.replace(/;/g,"%3B");
	uri = uri.replace(/ /g,"%20");
	uri = uri.replace(/\+/g,"%2B");
	uri = uri.replace(/\?/g,"%3F");
	uri = uri.replace(/\"/g,"%22");
	return uri;
}
function bookmarkChanged(bm) {
	if (bm == '+') addBookmark();
	else if (bm == '-') rmBookmark();
	else if (bm == '--') rmAllBookmarks();
	else if (bm.match(/^time/) || bm.match(/^path/)) { setCookie('bookmarksort',bm,1); bookmarkcheck(); }
	else changeDir(bm);
	return true;
}
function getBookmarkTime(bm) {
	var i=0;
	while (getCookie('bookmark'+i) != "" && getCookie('bookmark'+i) != bm) i++;
	return getCookie('bookmark'+i+'time');
}
function bookmarkSort(a,b) {
	var s = getCookie('bookmarksort');
	if (s == "") s='time-desc';
	var f = s.match(/desc/) ? -1 : 1;

	if (s.match(/time/)) {
		a = getBookmarkTime(a);
		b = getBookmarkTime(b);
	}
	return f * (a == b ? 0 : a < b ? -1 : 1);
}
function buildBookmarkList() {
	var e = document.getElementById('bookmarks');
	if (!e) return;
	var loc = getBookmarkLocation();
	var b = new Array();
	var content = "";
	var i = 0;
	while (getCookie('bookmark'+i)!="") {
		var c = getCookie('bookmark'+i);
		i++;
		if (c=="-") continue;
		b.push(c);
	}
	b.sort(bookmarkSort);
	var isBookmarked = false;
	for (i=0; i<b.length; i++) {
		var c = b[i];
		var d = (c == loc) ? ' disabled="disabled"' : '';
		if (c == loc) isBookmarked = true;
		var v = c.length <= 25 ? c : c.substr(0,5)+'...'+c.substr(c.length-17);
		content = content + '<option value="'+encodeSpecChars(c)+'" title="'+c+'"'+d+'>' + v + '</option>';
	}
	var bms = getCookie('bookmarksort');
	if (bms == "") bms='time-desc';
	var sbparr,sbpadd,sbtarr,sbtadd;
	sbpadd = ''; sbparr = '';
	sbtadd = ''; sbtarr = ''; 
	if (bms.match(/^path/)) {
		sbpadd = bms.match(/desc/) ? '' : '-desc';
		sbparr = bms.match(/desc/) ? '&darr;' : '&uarr;';
	} else if (bms.match(/^time/)) {
		sbtadd = bms.match(/desc/) ? '' : '-desc';
		sbtarr = bms.match(/desc/) ? '&darr;' : '&uarr;';
	}
	e.innerHTML = '<select class="bookmark" name="bookmark" onchange="return bookmarkChanged(this.options[this.selectedIndex].value);">'
			+'<option class="title" value="">'+tl('bookmarks')+'</option>'
			+(!isBookmarked?'<option class="func" title="'+tl('addbookmarktitle')+'" value="+">'+tl('addbookmark')+'</option>' : '')
			+ (content != "" ?  content : '')
			+(isBookmarked?'<option disabled="disabled"></option><option class="func" title="'+tl('rmbookmarktitle')+'" value="-">'+tl('rmbookmark')+'</option>' : '')
			+ (b.length<=1 ? '' : '<option class="func" value="path'+sbpadd+'">'+tl('sortbookmarkbypath')+' '+sbparr+'</option><option class="func" value="time'+sbtadd+'">'+tl('sortbookmarkbytime')+' '+sbtarr+'</option>')
			+ '<option disabled="disabled"></option><option class="func" title="'+tl('rmallbookmarkstitle')+'" value="--">'+tl('rmallbookmarks')+'</option>' 
			+ '</select>' ;
}
function bookmarkcheck() {
	toggleBookmarkButtons();
	buildBookmarkList();
}
function changeDir(href) {
	window.location.href=href; 
	return true;
}
function showChangeDir(show) {
	document.getElementById('changedir').style.display = show ? 'inline' : 'none';
	document.getElementById('changedirbutton').style.display = show ? 'none' : 'inline';
	document.getElementById('quicknavpath').style.display = show ? 'none' : 'inline';
	if (show) {
		document.getElementById('changedirpath').value = document.location.pathname;
		document.getElementById('changedirpath').focus();
	}
}
function catchEnter(e, id) {
	if (!e) e = window.event;
	if (e.keyCode == 13) {
		var el = document.getElementById(id);
		if (!el) { var els = document.getElementsByName(id); if (els) el=els[0]; }
		if (el) el.click();
		return false;
	}
	return true;
}
function handleRowClick(id,e) {
	if (!e) e = window.event;
	var el=document.getElementById(id); 
	if (el) { 
		shiftsel.shifted=e.shiftKey; 
		el.click(); 
	}; 
	return true;
}
function handleSearch(el,ev) {
	if (!ev) ev = window.event;
	if (ev && el && ev.keyCode == 13) {
		window.location.href='?search='+encodeSpecChars(el.value);
		return false;
	}
	return true;
}
function encodeRegExp(v) { return v.replace(/([\*\?\+\\$\^\{\}\[\]\(\)\\])/g,'\\\$1'); }
function handleNameFilter(el,ev) {
	if (!ev) ev=window.event;
	if (ev && el && ev.keyCode != 13) {
		if (el.size>5 && el.value.length<el.size) el.size = 5;
		if (el.size<el.value.length) el.size = el.value.length;
		var regex;
		try { 
			regex = new RegExp(el.value, 'gi');
		} catch (exc) {
			regex = new RegExp(encodeRegExp(el.value), 'gi');
		}
		var matchcount = 0;
		var i = 1;
		var e;
		while ((e = document.getElementById('f'+i))) {
			var m = e.value.match(regex);
			if (m) matchcount++;
			toggleClassNameById('tr_f'+i, 'hidden', !m);
			i++;
		}
		var me = document.getElementsByName('namefiltermatches');
		for (i=0; i<me.length; i++) me[i].value=matchcount;
		me = document.getElementsByName('namefilter');
		for (i=0; i<me.length; i++) {
			if (el!=me[i]) {
				me[i].value=el.value;
				if (me[i].size>5 && el.value.length<me[i].size) me[i].size = 5;
				if (me[i].size<el.value.length) me[i].size = el.value.length;
			}
		}
		return ev.keyCode!=13;
	}
	return false;
}
var shiftsel = new Object();
function handleCheckboxClick(o,id,e) {
	if (!e) e = window.event;
	var nid = parseInt(id.substr(1));
	var nlid = shiftsel && shiftsel.lastId ? parseInt(shiftsel.lastId.substr(1)) : nid;
	if ((e.shiftKey||shiftsel.shifted) && shiftsel.lastId && nid != nlid ) {
		var start = nid > nlid ? nlid : nid;
		var end = nid > nlid ? nid : nlid;
		shiftsel.shifted=false;
		for (var i = start + 1; i < end ; i++) {
			var el = document.getElementById('f'+i);
			if (el) {       
				if (document.getElementById('tr_f'+i).className.match('hidden')) continue;
				el.checked=!el.checked; 
				toggleClassNameById("tr_f"+i, "tr_selected", el.checked); 
			}
		}
	}
	shiftsel.lastId = id;
	if (document.getElementById('tr_'+id).className.match('hidden')) return false;
	toggleFileFolderActions(); 
	toggleClassNameById("tr_"+id, "tr_selected", o.checked); 
	return true;
}
function addClassName(e, cn) {
	if (e && e.className) {
		if (e.className.indexOf(" "+cn)>-1) return;
		e.className = e.className + " " + cn;
	}
}
function addClassNameById(id, cn) { addClassName(document.getElementById(id), cn); }
function removeClassName(e,cn) {
	if (e && e.className) {
		var a = e.className.split(' ');
		for (var i=0; i<a.length; i++) {
			if (a[i] == cn) a.splice(i,1);
		}
		e.className = a.join(' ');
	}
}
function removeClassNameById(id, cn) { removeClassName(document.getElementById(id),cn); }
function toggleClassName(e, cn, s) { if (s) addClassName(e, cn); else removeClassName(e,cn); }
function toggleClassNameById(id, cn, s) { toggleClassName(document.getElementById(id), cn, s); }
function toggleFileFolderActions() {
	var disabled = true;
	var ea = document.getElementsByName("file"); 
	var checkedcounter = 0;
	for (var i=0; i<ea.length; i++) if (ea[i].checked) { disabled=false; checkedcounter++; if (checkedcounter>1) break; }
	var names = new Array('copy','cut','delete','newname','rename','zip','changeperm');
	for (var i=0; i<names.length; i++) {
		ea = document.getElementsByName(names[i]);
		if (ea) for (var j=0; j<ea.length; j++) ea[j].disabled = disabled;
	}
	names = new Array('filesubmit','file_upload','mkcol','colname','saveafsacl','uncompress','zipfile_upload','createnewfile','cnfname');
	for (var i=0; i<names.length; i++) {
		ea = document.getElementsByName(names[i]);
		if (ea) for (var j=0; j<ea.length; j++) ea[j].disabled = !disabled;
	}
	names = new Array('createsymlink','lndst');
	for (var i=0; i<names.length; i++) {
		ea = document.getElementsByName(names[i]);
		if (ea) for (var j=0; j<ea.length; j++) ea[j].disabled = checkedcounter != 1;
	}
}

function toggleAllFiles(tb) {
	tb.checked=false; 
	var ea = document.getElementsByName("file"); 
	for (var i=0; i<ea.length; i++) if (!ea[i].disabled) ea[i].click();
}
function setCookie(name,value,e,path) { 
	var expires;
	var date = new Date();
	date.setTime(date.getTime() + 315360000000);
	expires = date.toGMTString();
	if (!path) path = '/';
	document.cookie = name + '=' + escape(value) + ';'+ (e?'expires='+expires+'; ':'') +' path='+path+'; secure;'; 
}
function delCookie(name,path) {
	var date = new Date();
	date.setTime(date.getTime() - 1000000);
	if (!path) path = '/';
	document.cookie = name + '=' + escape('-') + '; expires='+date.toGMTString()+'; path='+path+'; secure;';
}
function getCookie(name) {
	if (document.cookie.length>0) {
		var c_start=document.cookie.indexOf(name + "=");
		if (c_start!=-1) {
			c_start=c_start + name.length+1;
			var c_end=document.cookie.indexOf(";",c_start);
			if (c_end==-1) c_end=document.cookie.length;
			return unescape(document.cookie.substring(c_start,c_end));
		}
	}
	return "";
}
function clpcheck() { 
	var pbuttons = document.getElementsByName('paste');
	for (var i=0; i<pbuttons.length; i++) {
		var b = pbuttons[i];
		b.disabled=(getCookie('clpfiles') == '' || REQUEST_URI == getCookie('clpuri')); 
		if (getCookie('clpfiles')!='') 
			b.title=getCookie('clpaction')+' '
					+getCookie('clpuri')+': '+getCookie('clpfiles').split("@/@").join(", ");
		else
			b.title='';
	}
}
function strshortener(str,maxlen) {
	var ret = str;
	if (!maxlen) maxlen = 40;
	if (str.length>maxlen) ret = str.substr(0,maxlen-3)+'...';
	return ret;
}
function clpaction(action) {
	var sel = new Array();
	var files = document.getElementsByName('file');
	for (var i=0; i<files.length; i++) { 
		removeClassNameById("tr_"+files[i].id, "tr_cut");
		removeClassNameById("tr_"+files[i].id, "tr_copy");
		if (files[i].checked === true) { 
			files[i].click(); 
			sel.push(files[i].value); 
			addClassNameById("tr_"+files[i].id, "tr_"+action);
		}
	}
	if (action == 'paste') {
		var clpform = document.getElementById('clpform');
		clpform.action.value=getCookie('clpaction');
		clpform.srcuri.value=getCookie('clpuri');
		clpform.files.value=getCookie('clpfiles');
		var confirmmsg = tl('paste'+getCookie('clpaction')+'confirm');
		confirmmsg = confirmmsg.replace('%files%', strshortener(getCookie('clpfiles').replace(/@\/@/g,', '))).replace('%srcuri%',getCookie('clpuri')).replace('%dsturi%',window.location.pathname);
		if (clpform.files.value!='' && window.confirm(confirmmsg)) {
			if (clpform.action.value != "copy") {
				setCookie('clpuri','');
				setCookie('clpaction','');
				setCookie('clpfiles','');
			}
			clpcheck();
			clpform.submit();
		}
	} else {
		setCookie( 'clpuri',REQUEST_URI);
		setCookie( 'clpaction', action);
		setCookie( 'clpfiles', sel.join('@/@'));
		clpcheck();
	}
}
function toggle(name,cshow,chide) {
	var button = document.getElementById('togglebutton'+name);
	var div = document.getElementById('toggle'+name);
	if (!cshow) cshow = '+';
	if (!chide) chide = '-';
	div.style.display=div.style.display=='none'?'block':'none';
	button.innerHTML = div.style.display=='none'?cshow:chide; 
	setCookie('toggle'+name, div.style.display,1);
}
function selcheck() {
	var i = 1;
	var el;
	while ((el = document.getElementById('f'+i))) {
		if (el.checked) toggleClassNameById("tr_f"+i, "tr_selected", el.checked); 
		i++;
	}
}
function check() {
	selcheck();
	clpcheck();
	bookmarkcheck();
	autorefreshcheck();
	hideMsg();
}
function fadeOut(id) {
	var obj = document.getElementById(id);
	if (!obj.fadeOutInterval) {
		obj.fadeOutInterval = window.setInterval('fadeOut("'+id+'");', 50);
		obj.fadeOutOpacity = 0.95;
		obj.style.opacity = obj.fadeOutOpacity;
		obj.style.filter = "Alpha(opacity="+(obj.fadeOutOpacity*100)+")";
		obj.fadeOutTop = 10;
		obj.style.top = obj.fadeOutTop + "px";
	}
	if (obj.fadeOutOpacity <= 0) {
		window.clearInterval(obj.fadeOutInterval);
		obj.style.display="none";
	} else  {
		if (obj.fadeOutOpacity > 0) obj.fadeOutOpacity -= 0.1;
		if (obj.fadeOutOpacity < 0) obj.fadeOutOpacity = 0;
		obj.style.opacity = obj.fadeOutOpacity; 
		obj.style.filter = "Alpha(opacity="+(obj.fadeOutOpacity*100)+")"; 
		obj.fadeOutTop -= 6;
		obj.style.top =  obj.fadeOutTop + "px";
	}
}
function fadeOutCountDown(id,fid,count) {
	var e = document.getElementById(id);
	if (!e) return;
	count--;
	e.innerHTML = count;
	if (count>0) setTimeout("fadeOutCountDown('"+id+"', '"+fid+"', "+count+");", 1000);
	else fadeOut(fid);
} 
function fadeOutWithCountdown(id, timeout) {
	var e = document.getElementById(id);
	if (!e) return;
	ID++;
	e.innerHTML = '<div class="msgcountdown" title="'+tl('msgtimeouttooltip')+'" id="countdown'+ID+'">'+(timeout/1000)+'</div>'+e.innerHTML;
	fadeOutCountDown("countdown"+ID, id, timeout/1000);
}
function hideMsg() { 
	var elnames = new Array('msg', 'notreadable', 'notwriteable', 'filtered');
	var count = 0;
	var zIndex = getDragZIndex();
	for (var i=0; i<elnames.length; i++) {
		var id = elnames[i];
		var e = document.getElementById(id);
		if (e) {
			if (count>0) e.style.top =  (10 + (10 * count)) + 'px';
			e.style.zIndex = zIndex + 100 - count;
			// setTimeout("fadeOut('"+id+"');", 30000 * ++count); 
			fadeOutWithCountdown(id, 30000 * ++count);
		}
	}
}
function toggleCollapseAction(action, event) {
	if (!event) event=window.event;
	var e = document.getElementById('v_'+action);
	if (!e) return true;
	var shown = !e.className.match(/collapsed/);
	toggleClassName(e,'collapsed', shown);
	toggleClassNameById(action, 'collapsed', shown);
	e = document.getElementById(action);
	setCookie(action, 'true/'+e.style.left+'/'+e.style.top+'/'+e.style.zIndex+'/'+e.className.match(/collapsed/),1);
	if (event.preventDefault) event.preventDefault(); else event.returnValue = false;
	return false;
}       
function handleFileAction(action, id, event, type) {
	var ret = true;
	if (!event) event = window.event;
	var ef = document.getElementById(id);
	var e = document.getElementById('tc_name_'+id);
	if (action == '--') {   
		if (document.getElementById('faction').name == 'rename') 
			handleFileAction(document.getElementById('faction').value,document.getElementById('fid').value, event, 'cancel');
	} else if (type == 'cancel') {
		e.innerHTML = document.getElementById('forigcontent').innerHTML;
		document.getElementById('faction').name = 'dummy';
	} else if (type == 'select') {
		if (document.getElementById('faction').name == action) { handleFileAction(action,document.getElementById('fid').value, event, 'cancel'); }
		var fa = document.getElementById('fileactions_'+id);
		if (fa && fa.options) fa.options[0].selected = true;
		document.getElementById('faction').name = action;
		document.getElementById('fsrc').value = ef.value;
		document.getElementById('fid').value = id;
		if (action == 'props') {
			window.location.href=window.location.pathname+(window.location.pathname.match(/\/$/)?'':'/')+ef.value+'?action=props';
		} else if (action == 'rename') {
			document.getElementById('forigcontent').innerHTML = e.innerHTML;
			e.onmousedown = function() { return true; };
			e.innerHTML = '<input size="'+MAXFILENAMESIZE+'" type="text" name="fdst_'+id+'" id="fdst_'+id+'" onfocus="this.select();" value="'+escapeQuotes(ef.value)+'" onkeypress="handleFileAction(&quot;'+action+'&quot;,&quot;'+id+'&quot;,event, &quot;rename&quot;)" onkeyup="handleFileAction(&quot;'+action+'&quot;,&quot;'+id+'&quot;,event, &quot;escape&quot;)" />';
			document.getElementById('fdst_'+id).focus();
		} else {
			var cfmsg = null;
			if (action == 'delete') cfmsg = tl('deletefileconfirm').replace('\%s', ef.value);
			if (cfmsg == null || window.confirm(cfmsg)) document.getElementById('faform').submit();
		}
	} else if (type == 'rename') {
		if (event.keyCode == 13) {
			if (event.preventDefault) event.preventDefault(); else event.returnValue = false;
			var dst = document.getElementById('fdst_'+id);
			if (ef.value.replace(/\/$/,'') != dst.value.replace(/\/$/,'')) {
				var cfmsg = tl('movefileconfirm').replace('\%s', ef.value).replace('\%s', dst.value);
				if (window.confirm(cfmsg)) {
					document.getElementById('fsrc').disabled = false;
					document.getElementById('fdst').disabled = false;
					document.getElementById('faction').disabled = false;
					document.getElementById('fdst').value = dst.value;
					e.innerHTML = dst.value;
					if (document.body && document.body.style) document.body.style.cursor='wait';
					document.getElementById('faform').submit();
				}
			}
			ret = false;
		} else if (event.keyCode == 27)  {
			ret = handleFileAction(action,id,event,'cancel');
		}
	} else if (type == 'escape') {
		if (event.keyCode == 27)  ret = handleFileAction(action,id,event,'cancel');
	}
	return ret;
}

function setTextAreaCookie(eid) {
	var e = document.getElementById(eid);
	var ff = e.className.indexOf(' mono')>-1 ? 'mono' : 'prop';
	setCookie(eid,e.cols+'/'+e.rows+'/'+ff,1);
}
function handleTextAreaSize(eid,x,y,sx,sy) {
	var e = document.getElementById(eid);
	if (!e) return false;
	if (e.cols+x >10) e.cols+=x; 
	if (e.rows+y >4) e.rows+=y;
	if (sx) e.cols=sx;
	if (sy) e.rows=sy;
	setTextAreaCookie(eid);
	return true;
}
function handleTextAreaMove(event) {
	if (!event) event = window.event;
	if (dragElID!=null) {
		var el = document.getElementById(dragElID);
		var cel = document.getElementById(dragElCID);
		if (!el) return true;
		var p = getEventPos(event);
		
		var nc = Math.round((p.x - dragOffset.x) / ( dragOffset.width / dragOffset.cols)) ;
		var nr = Math.round((p.y - dragOffset.y) / (dragOffset.height / dragOffset.rows));

		var nw = dragOffset.cwidth + p.x - dragOffset.x + 5;
		var nh = dragOffset.cheight + p.y - dragOffset.y + 5;

		if (dragOffset.cols + nc > 25) {
			el.cols = dragOffset.cols + nc;
			cel.style.width = nw + 'px';
		}
		if (dragOffset.rows + nr > 5) {
			el.rows = dragOffset.rows + nr;
			cel.style.height = nh + 'px';
		}
		return false;
	}
	return true;
}
function handleTextAreaResize(event, id, cid, down) {
	if (!event) event = window.event;
	var e = document.getElementById(id);
	var ce = document.getElementById(cid);
	if (down) {
		if (!e || !event) return true;
		var p = getEventPos(event);

		if (!ce.style.width) ce.style.width = (p.x - parseInt(ce.style.left))+'px';
		if (!ce.style.height) ce.style.height = (p.y - parseInt(ce.style.top))+'px';
 
		dragElID = id;
		dragElCID = cid;
		dragOrigHandler.onmousemove = document.onmousemove;
		document.onmousemove = handleTextAreaMove;
		dragOrigHandler.noselectstart = document.onselectstart;
		document.onselectstart = function() { return false; }
		dragOffset.cols = e.cols;
		dragOffset.rows = e.rows;
		dragOffset.width = e.width ?  parseInt(e.width) : e.clientWidth;
		dragOffset.height = e.height ? parseInt(e.height) : e.clientHeight;
		dragOffset.cwidth = parseInt(ce.style.width);
		dragOffset.cheight= parseInt(ce.style.height);
		dragOffset.x = p.x;
		dragOffset.y = p.y;
		event.ondragstart = function() { return false; }
		document.body.focus();
		if (event.preventDefault) event.preventDefault(); else event.returnValue = false;
		return false;
	} else {
		dragElID = null;
		document.onmousemove = dragOrigHandler.onmousemove;
		document.onselectstart = dragOrigHandler.onselectstart;
		setTextAreaCookie(id);
		if (ce) { ce.style.width='auto'; ce.style.height='auto'; }
	}
	return true;
}
function handleTextAreaFontFamily(eid,tid) {
	var e = document.getElementById(eid);
	var t = document.getElementById(tid);
	if (!e || !t) return true;
	var ismono = e.className.indexOf(' mono')>-1;
	toggleClassName(e, 'prop', ismono);
	toggleClassName(e, 'mono', !ismono);
	toggleClassName(t, 'prop', ismono);
	toggleClassName(t, 'mono', !ismono);
	setTextAreaCookie(eid);
	return true;
}
function startClock(eid,fmt,interval) {
	if (!eid || !document.getElementById(eid)) return;
	if (!fmt) fmt="%I:%M:%S";
	if (!interval) interval=fmt.match(/%S/) ? 1000 : 60000;
	renderClock(eid,fmt);
	window.setInterval("renderClock('"+eid+"','"+fmt+"')", interval);
}
function renderClock(eid,fmt) {
	// %H = 00-23; %I = 01-12; %k = 0-23; %l = 1-12
	// %M = 00-59; %S = 0-60
	function addzero(v) { return v<10 ? "0"+v : v; }
	var e = document.getElementById(eid);
	if (!e) return;
	var d = new Date();
	var s = fmt;
	s = s.replace(/\%(H|k)/, addzero(d.getHours()));
	s = s.replace(/\%(I|l)/, addzero(d.getHours() % 12 == 0 ? 12 : d.getHours() % 12) );
	s = s.replace(/\%M/, addzero(d.getMinutes()));
	s = s.replace(/\%S/, addzero(d.getSeconds()));
	e.innerHTML = s;
}

var autorefreshtimeout = 0;
var autorefreshinterval = null;
function autorefreshcheck() {
	var timeout = getCookie('autorefresh');
	if (timeout>0) startAutoRefresh(timeout);
}
function startAutoRefresh(timeout) {
	if (timeout == 'now') {
		pleaseWait();
		window.location.reload();
		return false;
	}
	if (timeout<=0 || !document.getElementById('autorefreshtimer')) {
		stopAutoRefresh();
		return false;
	}
	if (autorefreshinterval != null) window.clearInterval(autorefreshinterval);
	setCookie('autorefresh',timeout,1);
	autorefreshtimeout=timeout;
	refreshTimer();
	removeClassNameById('autorefreshpauseresume','resume');
	addClassNameById('autorefreshpauseresume','pause');
	removeClassNameById('autorefreshtimer','hidden');
	autorefreshinterval = window.setInterval('refreshTimer()',1000);
	return false;
}
function refreshTimer() {
	var e = document.getElementById('autorefreshcurrtime');
	var minutes = Math.floor(autorefreshtimeout / 60);
	var seconds = autorefreshtimeout % 60;
	if (seconds < 10) seconds='0'+seconds;
	var str = tl("autorefresh.format");
	if (!str || str=="autorefresh.format") str="%sm %ss";
	e.innerHTML = str.replace('%s',minutes).replace('%s', seconds);
	autorefreshtimeout--;

	if (autorefreshtimeout < 0) {
		stopAutoRefresh(1);
		pleaseWait();
		window.location.reload();
	}
}
function toggleAutoRefresh() {
	if (autorefreshtimeout<=0) return false;
	if (autorefreshinterval != null) {
		window.clearInterval(autorefreshinterval);
		autorefreshinterval = null;
		removeClassNameById('autorefreshpauseresume','pause');
		addClassNameById('autorefreshpauseresume','resume');
	} else {
		removeClassNameById('autorefreshpauseresume','resume');
		addClassNameById('autorefreshpauseresume','pause');
		autorefreshinterval = window.setInterval('refreshTimer()',1000);
	}
	return false;
}
function stopAutoRefresh(dontforget) {
	window.clearInterval(autorefreshinterval);
	autorefreshinterval = null;
	autorefreshtimeout = 0;
	addClassNameById('autorefreshtimer','hidden');
	if (!dontforget) delCookie('autorefresh');
}

function applyFilters() {
	var els;
	var typefilter = "";
	var path = 0;
	els = document.getElementsByName('filter.pathonly');
	if (els && els[0] && els[0].checked) path = window.location.pathname;

	els = document.getElementsByName('filter.types');
	for (var i=0; i<els.length; i++) {
		if (els[i].checked) typefilter+=els[i].value;
	}
	if (typefilter == "") typefilter = '-';
	setCookie('filter.types', typefilter, 0, path);

	els = document.getElementsByName('filter.size.op');
	var sizeop = els[0].value;
	els = document.getElementsByName('filter.size.val');
	var sizeval = els[0].value;
	els = document.getElementsByName('filter.size.unit');
	var sizeunit = els[0].value;

	if (sizeval != "") setCookie('filter.size', sizeop+sizeval+sizeunit, 1, path);
	else delCookie('filter.size',path);

	els = document.getElementsByName('filter.name.op');
	var nameop = els ? els[0].value : '';
	els = document.getElementsByName('filter.name.val');
	var nameval = els ? els[0].value : '';

	if (nameval != "") setCookie('filter.name', nameop+' '+nameval, 1, path);
	else delCookie('filter.name', path);

	window.location.href = window.location.pathname;
	return 0;
}
function resetFilters() {
	var cookies = new Array('filter.size','filter.time','filter.types','filter.name');
	for (var i=0; i<cookies.length; i++) {
		delCookie(cookies[i]);
		delCookie(cookies[i],window.location.pathname);
	}
	window.location.href=window.location.pathname;
	return 0;
}
function saveTableConfig() {
	var els = document.getElementsByName('tablecolumns');
	var visibletablecolumns="";
	var changed = false;
	for (var i=0; i<els.length; i++) {
		if (els[i].checked) {
			if (visibletablecolumns != "") visibletablecolumns += ",";
			visibletablecolumns+=els[i].value;
		}
	}
	var oldvis = getCookie("visibletablecolumns");
	changed |= oldvis != visibletablecolumns;
	if (oldvis!=visibletablecolumns) setCookie("visibletablecolumns",visibletablecolumns,1);

	var order='name';
	els = document.getElementsByName('sortingcolumns');
	for (var i=0; i<els.length; i++) {
		if (els[i].checked) order = els[i].value;
	}
	els = document.getElementsByName('sortingorder');
	for (var i=0; i<els.length; i++) {
		if (els[i].checked && els[i].value == 'desc') order=order+'_desc'; 
	}

	var oldorder = getCookie("order");
	changed |= order!=oldorder;
	if (order!=oldorder) setCookie('order',order);


	if (changed) window.location.href=window.location.pathname;
}
function pleaseWait() {
	var bodies = document.getElementsByTagName('body');
	var body = bodies[0];
	if (body) body.className = 'disabled';
	return true;
}
