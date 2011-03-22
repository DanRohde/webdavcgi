/**********************************************************
* (C) ZE CMS, Humboldt-Universitaet zu Berlin
* Written 2010 by Daniel Rohde <d.rohde@cms.hu-berlin.de>
***********************************************************/
var zoomId=0;
function startZoom(obj, speed, size, max, step) {
	obj.startWidth = size;
	obj.maxWidth = max;
	obj.curWidth = size;
	if (!step) step = 10;
	obj.step = step;
	zoomId++;
	if (!obj.id) obj.id="zoomId"+zoomId;
	obj.zoomFunc = function() {
		if (this.curWidth < this.maxWidth) {
			this.curWidth+=this.step;
			this.style.width = this.curWidth + "px"; 
			// if (this.width) this.width = this.curWidth;
		} else {
			window.clearInterval(this.zoomInterval);
		}
	};
	obj.zoomInterval = window.setInterval("document.getElementById(\""+obj.id+"\").zoomFunc();", speed);
}
function stopZoom(obj) {
	window.clearInterval(obj.zoomInterval);
	obj.style.width = obj.startWidth + "px";
	// if (obj.width) obj.width = obj.startWidth;
}
