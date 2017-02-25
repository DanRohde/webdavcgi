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

initFileStatistics();
initFolderStatistics();

function updateFileStatistics() {
	var s = getFolderStatistics();
	$(".filestats-filecount").html(s.filecounter);
	$(".filestats-dircount").html(s.dircounter);
	$(".filestats-sum").html(s.sumcounter);
	$(".filestats-foldersize").attr("title",$.MyStringHelper.renderByteSizes(s.foldersize)).html($.MyStringHelper.renderByteSize(s.foldersize));
	
	$(".filestats-selfilecount").html(s.fileselcounter);
	$(".filestats-seldircount").html(s.dirselcounter);
	$(".filestats-selsum").html(s.sumselcounter);
	$(".filestats-selfoldersize").attr("title", $.MyStringHelper.renderByteSizes(s.folderselsize)).html($.MyStringHelper.renderByteSize(s.folderselsize));
}
function initFileStatistics() {
	updateFileStatistics();
	$("#flt").on("fileListChanged counterUpdated fileListSelChanged", updateFileStatistics);
}

function initFolderStatistics() {
	$("#flt").on("fileListChanged", updateFolderStatistics).on("fileListViewChanged", updateFolderStatistics);
}
function resetFileListCounters(fltparam) {
	var flt = fltparam;
	if (!flt) flt=$("#fileListTable");
	if (flt && flt.attr) 
		flt.attr("data-filecounter",0).attr("data-dircounter",0).attr("data-foldersize",0).attr("data-sumcounter",0)
			.attr("data-fileselcounter",0).attr("data-dirselcounter",0).attr("data-folderselsize",0).attr("data-sumselcounter",0);
}
function updateFileListCounters() {
	var flt = $("#fileListTable");
	// file list counters:
	resetFileListCounters(flt);

	var s = getFolderStatistics();

	flt.attr("data-dircounter", s.dircounter);
	flt.attr("data-filecounter", s.filecounter);
	flt.attr("data-foldersize", s.foldersize);
	flt.attr("data-sumcounter", s.sumcounter);
	
	$("#flt").trigger("counterUpdated");
}
function updateFolderStatistics() {
	var hn = $("#headerName");
	var flt = $("#fileListTable");
	var hs = $("#headerSize");

	updateFileListCounters();

	if (hn.length>0 && !hn.attr("data-title")) hn.attr("data-title",hn.attr("title"));
	if (hs.length>0 && !hs.attr("data-title")) hs.attr("data-title",hs.attr("title"));
	if (hn.length>0) 
		hn.attr("title", 
			hn.attr("data-title")
				.replace(/\$filecount/, flt.attr("data-filecounter"))
				.replace(/\$dircount/,flt.attr("data-dircounter"))
				.replace(/\$sum/,parseInt(flt.attr("data-dircounter"), 10)+parseInt(flt.attr("data-filecounter"), 10))
		);
	var fs = parseInt(flt.attr("data-foldersize"), 10);
	if (hs.length > 0) hs.attr("title", hs.attr("data-title").replace(/\$foldersize/, $.MyStringHelper.renderByteSizes(fs)));
}
function getFolderStatistics(focus) {
	var stats = [];
	var es = focus ? ".focus" : ".selected:visible";
	stats.focus = focus;
	
	stats.dircounter = $("#fileList tr.is-subdir-yes:visible, #fileList tr.is-current-dir-yes:visible").length;
	stats.filecounter = $("#fileList tr.is-file:visible").length;
	stats.sumcounter = stats.dircounter+stats.filecounter;
	stats.dirselcounter = $("#fileList tr.is-subdir-yes"+es+", #fileList tr.is-current-dir-yes"+es).length;
	stats.fileselcounter = $("#fileList tr.is-file"+es).length;
	stats.sumselcounter = stats.dirselcounter+stats.fileselcounter;

	var selfiles = $("#fileList tr.is-file"+es);
	stats.selectedmimetypes = selfiles.map(function() { return $(this).data("mime"); }).get().sort().join(",").replace(/([^,]+)(,\1)*/g,"$1");
	stats.selectedsuffixes = selfiles.map(function() { return $(this).data("file").toLocaleLowerCase().match(/\.\w+$/)!=null ? $(this).data("file").split(".").pop() : ""; }).get().sort().join(",").replace(/([^,]+)(,\1)*/g,"$1");
	stats.selectedfilenames = selfiles.map(function() { return $(this).data("file").toLocaleLowerCase(); }).get().sort().join("/");
	
	var foldersize = 0;
	var folderselsize = 0;
	$("#fileList tr:visible").each(function() {  
		var size = parseInt($(this).attr("data-size"), 10);
		if ($(this).is(es)) folderselsize +=size;
		foldersize += size;
	});

	stats.foldersize=foldersize;
	stats.folderselsize=folderselsize;

	return stats;
}