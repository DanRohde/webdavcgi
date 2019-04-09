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

initFileUpload();

function checkUploadedFilesExist(data) {
	for (var i=0; i<data.files.length; i++) {
		var relaPath;
		if (data.files[i].relativePath && data.files[i].relativePath != "") {
			relaPath = data.files[i].relativePath.split(/[\\\/]/)[0] + "/";
		} else if (data.files[i].webkitRelativePath && data.files[i].webkitRelativePath != "") {
			relaPath = data.files[i].webkitRelativePath.split(/[\\\/]/).slice(0,-1).join("/") + "/";
		}
		if (relaPath && $("#fileList tr[data-file='"+$.MyStringHelper.escapeHTML(relaPath)+"']").length>0) return true;
		else if ($("#fileList tr[data-file='"+$.MyStringHelper.escapeHTML(data.files[i].name)+"']").length>0) return true;
	}
	return false;
}
function initFileUpload() {
	initUpload($("#file-upload-form"),$("#fileuploadconfirm").html(), $("#progress").attr("data-title"), $(document));
	$(".action.upload").off("click.upload").on("click.upload", function() {
		if ($(this).hasClass("disabled")) return;
		$("#file-upload-form input[type=file]").removeAttr("directory webkitdirectory mozdirectory").trigger("click"); 
	});
	$(".action.uploaddir.uibutton").button();
	$(".action.uploaddir").off("click.uploaddir").on("click.uploaddir", function() {
		if ($(this).hasClass("disabled")) return;
		$("#file-upload-form input[type=file]").attr({"directory":"directory","webkitdirectory":"webkitdirectory","mozdirectory":"mozdirectory"}).trigger("click");
	});
	$(document).on("dragenter", function () {
		$("#fileList").addClass("draghover");
	}).on("dragleave", function() {
		$("#fileList").removeClass("draghover");
	}).on("drop", function() {
		$("#fileList").removeClass("hover");
	});

}
function renderUploadProgressAll(uploadState, dataparam) {
	var data = dataparam;
	if (!data) data=uploadState;
	var perc = data.loaded / data.total * 100;
	$("#progress .bar").css("width", perc.toFixed(2) + "%").addClass(uploadState.failed>0 ? "failed" : "done")
		.html(parseInt(perc, 10)+"% ("+$.MyStringHelper.renderByteSize(data.loaded)+"/"+$.MyStringHelper.renderByteSize(data.total)+")" + "; " + uploadState.done+"/"+uploadState.uploads
				);	
}
function initUpload(form,confirmmsg,dialogtitle, dropZone) {
	$("#flt").on("fileListChanged",function() {
		form.fileupload("option", "url", getURI());
	});
	var uploadState = {
		aborted: false,
		transports: [],
		done: 0,
		failed: 0,
		uploads: 0
	};
	form.fileupload({ 
		url: getURI(), 
		sequentialUploads: false,
		limitConcurrentUploads: 3,
		dropZone: dropZone,
		singleFileUploads: true,
		autoUpload: false,
		add: function(e,data) {
			if (!uploadState.aborted) {
				var transport = data.submit();
				var filename = data.files[0].name;
				var pid = "fpb" + $.MyStringHelper.getIdFromString(filename);
				uploadState.transports.push(transport);
				var up =$("<div></div>").appendTo("#progress .info").attr("id",pid).addClass("fileprogress");
				$("<div/>").click(function(event) {
					$.MyPreventDefault(event);
					$(this).data("transport").abort($("#uploadaborted").html()+": "+$(this).data("filename"));
					up.find(".fileprogressbar.running").removeClass("running").addClass("aborted");
				}).appendTo(up).attr("title",$("#cancel").html()).MyTooltip().addClass("cancel cancel-icon").data({ filename: filename, transport: transport });
				$("<div/>").appendTo(up).addClass("fileprogressbar running").html(data.files[0].name+" ("+$.MyStringHelper.renderByteSize(data.files[0].size)+"): 0%");
				uploadState.uploads+=1;
				return true;
			}
			return false;
		},
		done:  function(e,data) {
			var id = "fpb" + $.MyStringHelper.getIdFromString(data.files[0].name);
			$("#progress [id='"+id+"'] .cancel").remove();
			$("div[id='"+id+"'] .fileprogressbar", "#progress .info")
				.removeClass("running")
				.addClass(data.result.message ? "done" : "failed")
				.css("width","100%")
				.html(data.result && data.result.error ? data.result.error : data.result.message ? data.result.message : data.files[0].name);
			if (data.result.message) uploadState.done+=1; else uploadState.failed+=1;
			renderUploadProgressAll(uploadState);
		},
		fail: function(e,data) {
			var pid = "fpb" + $.MyStringHelper.getIdFromString(data.files[0].name);
			$("#progress [id='"+pid+"'] .cancel").remove();
			$("div[id='fpb"+pid+"'] .fileprogressbar", "#progress .info")
				.removeClass("running")
				.addClass("failed")
				.css("width","100%")
				.html(data.textStatus+": "+$.map(data.files, function(v) { return v.name;}).join(", "));
			uploadState.failed+=1;
			renderUploadProgressAll(uploadState);
			console.log(data);
		},
		stop: function() {
			renderUploadProgressAll(uploadState);
			$(this).data("ask.confirm",false);
			$("#progress").dialog("option","beforeClose",function() { return true; });
			$("#progress").dialog("option","close",function() { updateFileList(); });
			$("#progress").dialog("option","buttons", [{ text: $("#close").html(), click:  function() { $(this).dialog("close"); }}]);
		},
		change: function() {
			uploadState.transports = [];
			uploadState.aborted = false;
			uploadState.files = [];
			uploadState.uploads = 0;
			uploadState.failed = 0;
			uploadState.done = 0;
			return true;
		},
		start: function() {
			var buttons = [];
			buttons.push({ text:$("#close").html(), disabled: true});
			buttons.push({
				text:$("#cancel").html(), 
				click: function() {
					if (uploadState.aborted) return;
					uploadState.aborted=true;
					$.each(uploadState.transports, function(i,jqXHR) {
						if (jqXHR && jqXHR.abort) jqXHR.abort($("#uploadaborted").html());
					});
					uploadState.transports = [];
				}
			});
			$("#progress").dialog({ modal:true, title: dialogtitle, height: 370 , width: 500, buttons: buttons, dialogClass: "uploaddialog", beforeClose: function() { return false;} });
			$("#progress").show().each(function() {
				$(this).find(".bar").css("width","0%").html("0%");
				$(this).find(".info").html("");
			});
		},
		progress: function(e,data) {
			var pid = "fpb" + $.MyStringHelper.getIdFromString(data.files[0].name);
			var perc = parseInt(data.loaded/data.total * 100, 10)+"%";
			$("div[id='"+pid+"'] .fileprogressbar", "#progress .info").css("width", perc).html(data.files[0].name+" ("+$.MyStringHelper.renderByteSize(data.files[0].size)+"): "+perc);
			
		},
		progressall: function(e,data) {
			uploadState.total = data.total;
			uploadState.loaded = data.loaded;
			renderUploadProgressAll(uploadState, data);
		},
		submit: function(e,data) {
			if (!$(this).data("ask.confirm")) $(this).data("ask.confirm", $.MyCookie("settings.confirm.upload") == "no" || !checkUploadedFilesExist(data) || window.confirm(confirmmsg));
			$("#file-upload-form-relapath").val(data.files[0].relativePath || (data.files[0].webkitRelativePath && data.files[0].webkitRelativePath.split(/[\\\/]/).slice(0,-1).join("/")+"/") || "");
			$("#file-upload-form-token").val($("#token").val());
			return $(this).data("ask.confirm");
		}
	});	
}