$(document).ready(function() {
	
	initUIEffects();
	
	initBookmarks();

	initFileListActions();

	initClipboard();

	initFolderStatistics();

	initNewActions();

	initChangeDir();

	initFilterBox();

	initFileUpload();

	initZipFileUpload();

	initSelectionStatistics();

	initDialogActions()

	initTooltips();
	
	initPermissionsDialog();
	
	initViewFilterDialog();

	initClock();
	
	initAFS(); 

	initSelect();
	
	initChangeUriAction();

	initWindowResize();
	
	initSearch();
	
	initSettingsDialog();
	
	initAutoRefresh();
	
	$(document).ajaxError(function(event, jqxhr, settings, exception) { 
		console.log(event);
		console.log(jqxhr); 
		console.log(settings);
		console.log(exception);
		if (jqxhr && jqxhr.statusText) notifyError(jqxhr.statusText);
		$("div.overlay").remove();
	});
		
	updateFileList($("#flt").attr("data-uri"));
	
function initAutoRefresh() {
	$("a[data-action='autorefreshmenu']").button().click(function(event) {
		preventDefault(event);
		$("#autorefresh ul").toggleClass("hidden");
	});
	$("a.autorefreshrunning").addClass("disabled");
	$("#autorefresh").on("started", function() {
		$("a.autorefreshrunning").removeClass("disabled");
		$("#autorefreshtimer").show();
		$("a[data-action='autorefreshtoggle']").addClass("running")
	}).on("stopped", function() {
		$("a.autorefreshrunning").addClass("disabled");
		$("#autorefreshtimer").hide();
		$("a[data-action='autorefreshtoggle']").removeClass("running");
	});
	
	$("#flt").on("fileListChanged", function() {
		if (cookie("autorefresh") != "" && parseInt(cookie("autorefresh"))>0) startAutoRefreshTimer(parseInt(cookie("autorefresh")));
	});
	$("a[data-action='setautorefresh']").click(function(event){
		preventDefault(event);
		$("#autorefresh ul").addClass("hidden");
		if ($(this).attr("data-value") == "now") {
			updateFileList();
			return;
		}
		cookie("autorefresh", $(this).attr("data-value"));
		startAutoRefreshTimer(parseInt($(this).attr("data-value")));
	});
	$("a[data-action='autorefreshclear']").click(function(event) {
		preventDefault(event);
		if ($(this).hasClass("disabled")) return;
		window.clearInterval($("#autorefresh").data("timer"));
		rmcookies("autorefresh");
		$("#autorefresh").trigger("stopped");
		$("#autorefresh ul").addClass("hidden");
	});
	$("a[data-action='autorefreshtoggle']").click(function(event) {
		preventDefault(event);
		if ($(this).hasClass("disabled")) return;
		var af = $("#autorefresh");
		if (af.data("timer")!=null) {
			window.clearInterval(af.data("timer"));
			af.data("timer",null);
			$("a[data-action='autorefreshtoggle']").removeClass("running");
		} else {
			startAutoRefreshTimer(af.data("timeout"));
			$("a[data-action='autorefreshtoggle']").addClass("running");
		}
		$("#autorefresh ul").addClass("hidden");
	});
}
function renderAutoRefreshTimer(aftimeout) {
	var t = $("[data-action='autorefreshtimer']");
	var f = t.attr("data-template") || "%sm %ss";
	var minutes = Math.floor(aftimeout / 60);
	var seconds = aftimeout % 60;
	if (seconds < 10) seconds='0'+seconds;
	t.html(f.replace("%s", minutes).replace("%s", seconds));
}
function startAutoRefreshTimer(timeout) {
	var af = $("#autorefresh");
	if (af.data("timer")!=null) window.clearInterval(af.data("timer"));
	af.data("timeout", timeout);
	renderAutoRefreshTimer(timeout);
	af.data("timer", window.setInterval(function() {
		var aftimeout = af.data("timeout") -1;
		renderAutoRefreshTimer(aftimeout);
		af.data("timeout", aftimeout);
		if (aftimeout < 0) {
			window.clearInterval(af.data("timer"));
			af.data("timer",null);
			renderAutoRefreshTimer(0);
			af.trigger("stopped");
			updateFileList();
		}
	}, 1000));
	af.trigger("started");
}
function initSettingsDialog() {
	var settings = $("#settings");
	settings.data("initHandler", { init: function() {
		$.each(["confirm.upload","confirm.dnd","confirm.paste","confirm.save","confirm.rename"], function(i,setting) {
			$("input[name='settings."+setting+"']")
				.prop("checked", cookie("settings."+setting) != "no")
				.click(function(event) {
					cookie("settings."+setting, $(this).is(":checked") ? "yes" : "no");
				});	
		});
		$.each(["view","lang"], function(i,setting) {
			$("select[name='settings."+setting+"'] option[value='"+cookie(setting)+"']").prop("selected",true);	
			$("select[name='settings."+setting+"']").change(function() {
				cookie(setting, $("option:selected",$(this)).val());
				window.location.href= window.location.pathname; // reload bug fixed (if query view=...) 
			});	
		});
	}});
	
}
function initSearch() {
	var mutex = false;
	$("a[data-action='search']").click(function(event) {
		preventDefault(event)
		if (mutex) return;
		mutex = true;
		var resulttemplate = $(this).attr("data-resulttemplate");
		$.get($("#fileList").attr("data-uri"),{ajax: "getSearchDialog", template: $(this).attr("data-dialogtemplate")}, function(response){
			var dialog = $(response);
			
			$("div[data-action='search.apply']", dialog).button().click(function(event){
				preventDefault(event);
				var f = $("form",dialog);
				// XXX check all form elements (only one must have values)
				
				
				var data = { ajax: "search", template: resulttemplate };
				
				if ($("input[name='search.size.val']",f).val() != "") {
					$.extend(data, {
						"search.size" : $("select[name='search.size.op'] option:selected",f).val() 
										+ $("input[name='search.size.val']",f).val() 
										+ $("select[name='search.size.unit'] option:selected",f).val()
					});
				}
				if ($("input[name='search.name.val']",f).val() != "") {
					$.extend(data, {
						"search.name" : $("select[name='search.name.op'] option:selected",f).val() 
										+ " "
										+ $("input[name='search.name.val']",f).val()
					});
				}	
				if ($("input[name='search.types']:checked", f).length > 0) {
					var filtertypes = "";
					$("input[name='search.types']:checked", f).each(function(i,val) {
						filtertypes += $(val).val();
					});
					$.extend(data, { "search.types" : filtertypes});
				}
				dialog.dialog("close");
				
				updateFileList($("#fileList").attr("data-uri"), data);
			
			});
			handleJSONResponse(response);
			dialog.dialog({modal: true, width: "auto", height: "auto", close: function(){ mutex=false; dialog.dialog("destroy");}}).show();
		});
	});
}
function initUIEffects() {
	$(".accordion").accordion({ collapsible: true, active: false });
}
function initWindowResize() {
	$("#flt").on("fileListChanged", handleWindowResize).on("fileListViewChanged", handleWindowResize);
	$(window).resize(handleWindowResize);
	handleWindowResize();
}
function handleWindowResize() {
	var width = $(window).width()-$("#nav").width()
	$("#content").width(width);
	$("#controls").width(width);
}

function initChangeUriAction() {
	$("a[data-action=changeuri]").click(handleChangeUriAction);
	$("a[data-action=refresh]").click(function(event) {
		preventDefault(event);
		updateFileList();
	});
	$("#flt").on("fileListChanged", function() {
		$("#fileList tr[data-type='dir'] a[data-action=changeuri]").click(handleChangeUriAction);
	});
}
function handleChangeUriAction(event) {
	preventDefault(event);
	if ($(this).closest("div.filename").is(".ui-draggable-dragging")) {
		return;
	} else {
		changeUri($(this).attr("href"));
	}
}
function initSelect() {
	$("#flt").on("fileListChanged", function() {
		$("#fileListTable #headerName .toggleselection").off("click").click(function(event) {
			preventDefault(event);
			$("#fileList tr:not(:hidden)[data-unselectable='no']").each(function(i,row) {
				$(this).toggleClass("selected");
				$("input[type=checkbox]", $(this)).prop("checked", $(this).hasClass("selected"));
			});
			$("#flt").trigger("fileListSelChanged");
		});	
		$("#fileListTable #headerName .selectnone").off("click").click(function(event) {
			preventDefault(event);
			$("#fileList tr.selected:not(:hidden)").removeClass("selected");
			$("#fileList tr:not(:hidden) input[type=checkbox]:checked").prop("checked", false);
			$("#flt").trigger("fileListSelChanged");
		});
		$("#fileListTable #headerName .selectall").off("click").click(function(event) {
			preventDefault(event);
			$("#fileList tr:not(.selected):not(:hidden)[data-unselectable='no']").addClass("selected");
			$("#fileList tr:not(:hidden)[data-unselectable='no'] input[type=checkbox]:not(:checked)").prop("checked", true);
			$("#flt").trigger("fileListSelChanged");
		});
	});
}
function initClock() {
	var clock = $("#clock");
	if (clock.length==0) return;
	var fmt = clock.attr("data-format");
    if (!fmt) fmt="%I:%M:%S";
    window.setInterval(function() {
    	function addzero(v) { return v<10 ? "0"+v : v; }
        var d = new Date();
        var s = fmt;
        // %H = 00-23; %I = 01-12; %k = 0-23; %l = 1-12
        // %M = 00-59; %S = 0-60
        s = s.replace(/\%(H|k)/, addzero(d.getHours()))
             .replace(/\%(I|l)/, addzero(d.getHours() % 12 == 0 ? 12 : d.getHours() % 12) )
             .replace(/\%M/, addzero(d.getMinutes()))
             .replace(/\%S/, addzero(d.getSeconds()));
        clock.html(s);	
    }, fmt.match(/%S/) ? 1000 : 60000);
}
function initTooltips() {
/*
	$("[title]").powerTip({smartPlacement: true});
	$("#flt")
		.on("fileListChanged",  function() { $("#content [title]").powerTip({smartPlacement: true}); })
		.on("fileListViewChanged",  function() { $("#content [title]").powerTip({smartPlacement: true}); })
		.on("fileListSelChanged",  function() { $("#content [title]").powerTip({smartPlacement: true}); })
		.on("bookmarksChanged", function() { $("#bookmarks [title]").powerTip({smartPlacement: true}); });
*/
}
function initBookmarks() {
	var bookmarks = $("#bookmarks");
	$("[data-action='addbookmark']", bookmarks).button();
	$("#flt").on("bookmarksChanged", buildBookmarkList)
	.on("bookmarksChanged",toggleBookmarkButtons)
	.on("fileListChanged", function() {
		buildBookmarkList();
		toggleBookmarkButtons();	
	});
	
	// register bookmark actions:
	$("[data-action='addbookmark'],[data-action='rmbookmark'],[data-action='rmallbookmarks'],[data-action='bookmarksortpath'],[data-action='bookmarksorttime'],[data-action='gotobookmark']",bookmarks).click(handleBookmarkActions);
	// enable bookmark menu button:
	$("[data-action='bookmarkmenu']", bookmarks).click(
		function(event) {
			preventDefault(event);
			$("#bookmarksmenu ul").toggleClass("hidden");
		}
	).button();
	
	

}
function toggleButton(button, disabled) {
	if (button.hasClass("button")) button.button("option","disabled",disabled);
	button.toggleClass("disabled", disabled);
	$.each(button, function(i,v) { if ($(v).hasClass("hideit")) $(v).toggle(!disabled) });
}
function toggleBookmarkButtons() {
	var currentPath = concatUri($("#flt").attr("data-uri"),"/");	
	var isCurrentPathBookmarked = false;
	var count = 0;
	var i = 0;
	while (cookie("bookmark"+i)!=null) {
		if (cookie("bookmark"+i) == currentPath) isCurrentPathBookmarked=true;
		if (cookie("bookmark"+i) != "-") count++;
		i++;
	}
	toggleButton($("#bookmarks [data-action='addbookmark']"), isCurrentPathBookmarked);
	toggleButton($("#bookmarks [data-action='rmbookmark']"), !isCurrentPathBookmarked);
	toggleButton($("#bookmarks [data-action='bookmarksortpath']"), count<2);
	toggleButton($("#bookmarks [data-action='bookmarksorttime']"), count<2);
	toggleButton($("#bookmarks [data-action='rmallbookmarks']"), count==0);

	var sort= cookie("bookmarksort")==null ? "time-desc" : cookie("bookmarksort");
	$("#bookmarks [data-action='bookmarksortpath'] .path").hide();
	$("#bookmarks [data-action='bookmarksortpath'] .path-desc").hide();
	$("#bookmarks [data-action='bookmarksorttime'] .time").hide();
	$("#bookmarks [data-action='bookmarksorttime'] .time-desc").hide();
	if (sort == "path" || sort=="path-desc" || sort=="time" || sort=="time-desc") {
		$("#bookmarks [data-action='bookmarksort"+sort.replace(/-desc/,"")+"'] ."+sort).show();
	}
}
function buildBookmarkList() {
	var currentPath = concatUri($("#flt").attr("data-uri"),"/");
	// remove all bookmark list entries:
	$("#bookmarks [data-dyn='bookmark']").each(function(i,val) {
		$(val).remove();
	});
	// read existing bookmarks:
	var bookmarks = new Array();
	var i=0;
	while (cookie("bookmark"+i)!=null) {
		if (cookie("bookmark"+i)!="-") bookmarks.push({ path : cookie("bookmark"+i), time: parseInt(cookie("bookmark"+i+"time"))});
		i++;
	}
	// sort bookmarks:
	var s = cookie("bookmarksort") ? cookie("bookmarksort") : "time-desc";
	var sortorder = 1;
	if (s.indexOf("-desc")>0) { sortorder = -1; s= s.replace(/-desc/,"") } ;
	bookmarks.sort(function(b1,b2) {
		if (s == "path") return sortorder * b1[s].localeCompare(b2[s]);
		else return sortorder * ( b2[s] - b1[s]);
	});
	// build bookmark list:
	var tmpl = $("#bookmarktemplate").html();
	$.each(bookmarks, function(i,val) {
		var epath = unescape(val["path"]);
		$("<li>" + tmpl.replace(/\$bookmarkpath/g,val["path"]).replace(/\$bookmarktext/,simpleEscape(trimString(epath,20))) + "</li>")
			.insertAfter($("#bookmarktemplate"))
			.attr("data-dyn","bookmark")
			.click(handleBookmarkActions)
			.addClass("link")
			.attr('data-action','gotobookmark')
			.attr('data-bookmark',val["path"])
			.attr("title",simpleEscape(epath)+" ("+(new Date(parseInt(val["time"])))+")")
			.toggleClass("disabled", val["path"] == currentPath)
			.find("[data-action='rmsinglebookmark']").click(handleBookmarkActions);
	});
}
function removeBookmark(path) {
	var i = 0;
	while (cookie('bookmark'+i) != null && cookie('bookmark'+i)!=path) i++;
	if (cookie('bookmark'+i) == path) cookie('bookmark'+i, "-", 1);
	$('#flt').trigger("bookmarksChanged");
}
function handleBookmarkActions(event) {
	preventDefault(event);
	if ($(this).hasClass("disabled")) return;
	var action = $(this).attr('data-action');
	var uri = $("#fileList").attr('data-uri');
	if (action == 'addbookmark') {
		var i = 0;
	        while (cookie('bookmark'+i)!=null && cookie('bookmark'+i)!= "-" && cookie('bookmark'+i) != "" && cookie('bookmark'+i)!=uri) i++;
		cookie('bookmark'+i, uri, 1);
		cookie('bookmark'+i+'time', (new Date()).getTime(), 1);
		$("#flt").trigger("bookmarksChanged");
	} else if (action == 'gotobookmark') {
		changeUri($(this).attr('data-bookmark'));	
		$("#bookmarksmenu ul").toggleClass("hidden");
	} else if (action == 'rmbookmark') {
		removeBookmark(uri);
	} else if (action == 'rmallbookmarks') {
		var i = 0;
		while (cookie('bookmark'+i)!=null) {
			rmcookies('bookmark'+i, 'bookmark'+i+'time');
			i++;
		}
		$('#flt').trigger("bookmarksChanged");
	} else if (action == 'rmsinglebookmark') {
		removeBookmark($(this).attr("data-bookmark"));
	} else if (action == 'bookmarksortpath') {
		cookie("bookmarksort", cookie("bookmarksort")=="path" || cookie("bookmarksort") == null ? "path-desc" : "path");
		$("#flt").trigger("bookmarksChanged");
	} else if (action == 'bookmarksorttime') {
		cookie("bookmarksort", cookie("bookmarksort")=="time" ? "time-desc" : "time");
		$("#flt").trigger("bookmarksChanged");
	}
}
function initSelectionStatistics() {
	$('#selstats').data('selstats', $('#selstats').html());
	$("#flt").on("fileListSelChanged",handleSelectionStatistics).on("fileListViewChanged",handleSelectionStatistics);
}
function handleSelectionStatistics() {
	var selstats = $('#selstats');
	var tmpl = selstats.data('selstats');

	var s = getFolderStatistics();

	selstats.html(tmpl.replace(/\$filecount/,s["fileselcounter"]).replace(/\$dircount/,s["dirselcounter"]).replace(/\$sum/,s["sumselcounter"])).attr('title',renderByteSizes(s["folderselsize"]));
}

function initChangeDir() {
	$("#pathinputform").submit(function(event) { return false; });
	$("#pathinputform input[name='uri']").keydown(function(event){
		if (event.keyCode==27) {
			$('#pathinput').hide();
			$('#quicknav').show();
			$('.filterbox').show();
		} else if (event.keyCode==13) {
			preventDefault(event);
			$('#pathinput').hide();
			$('#quicknav').show();
			$('.filterbox').show();
			changeUri($(this).val());
		}
	});
	$("#path a[data-action='changedir']").button().click(function(event) {
		preventDefault(event);
		$('#pathinput').toggle();
		$('#quicknav').toggle();
		$('#pathinput input[name=uri]').focus().select();
		$('.filterbox').toggle();
	});
	$("#path [data-action='chdir']").button().click(function(event){
		preventDefault(event);
		$('#pathinput').hide();
		$('#quicknav').show();
		changeUri($("#pathinput input[name='uri']").val());
	});
	$("#flt").on("fileListChanged", function() {
		$('#pathinput input[name=uri]').val(decodeURI($('#fileList').attr('data-uri')));	
	});
	

}
function initFilterBox() {
	$("form#filterbox").submit(function(event) { return false;});
	$("form#filterbox input").keyup(applyFilter).change(applyFilter).autocomplete({minLength: 1, select: applyFilter, close: applyFilter});
	// clear button:
	$("form#filterbox [data-action=clearfilter]").toggleClass("invisible",$("form#filterbox input").val() == "");
	$("form#filterbox input").keyup(function() {
		$("form#filterbox [data-action=clearfilter]").toggleClass("invisible",$(this).val() == "");
	});
	$("form#filterbox [data-action=clearfilter]").click(function(event) {
		preventDefault(event);
		$("form#filterbox input").val("");
		applyFilter();
		$(this).addClass("invisible");
	});
	
	$("#flt")
		.on("fileListChanged", applyFilter)
		.on("fileListChanged", function() {
			var files = $.map($("#fileList tr"),function(val,i) { return $(val).attr("data-file");});
			$("form#filterbox input")
				.autocomplete("option", "source", function(request, response) {
					try {
						var matcher = new RegExp(request.term);
						response($.grep(files, function(item){ return matcher.test(item)}));
					} catch (e) {
						return files;
					}
				});
		});
}
function applyFilter() {
	var filter = $("form#filterbox input").val();
	$('#fileList tr').each(function() {
		try {
			var r = new RegExp(filter,"i");
			if (filter == "" || $(this).attr('data-file').match(r)) $(this).show(); else $(this).hide();	
		} catch (error) {
			if (filter == "" || $(this).attr('data-file').toLowerCase().indexOf(filter.toLowerCase()) >-1) $(this).show(); else $(this).hide();
		}
	});

	$("#flt").trigger("fileListViewChanged");
	return true;
}
function initUpload(form,confirmmsg,dialogtitle, dropZone) {
	$("#flt").on("fileListChanged",function() {
		form.fileupload("option","url",$("#fileList").attr("data-uri"));
	});
	var uploadState = {
		aborted: false,
		transports: new Array()
	};
	form.fileupload({ 
		url: $("#fileList").attr("data-uri"), 
		sequentialUploads: false,
		limitConcurrentUploads: 3,
		dropZone: dropZone,
		singleFileUploads: true,
		autoUpload: false,
		add: function(e,data) {
			if (!uploadState.aborted) {
				uploadState.transports.push(data.submit());
				var up =$("<div></div>").appendTo("#progress .info").attr("id","fpb"+data.files[0]["name"]).addClass("fileprogress");
				$("<div></div>").appendTo(up).addClass("fileprogressbar running").html(data.files[0]["name"]+" ("+renderByteSize(data.files[0]["size"])+"): 0%");;
				//$("#progress .info").scrollTop($("#progress .info")[0].scrollHeight);
				return true;
			}
			return false;
		},
		done:  function(e,data) {
			$("div[id='fpb"+data.files[0]["name"]+"'] .fileprogressbar", "#progress .info")
				.removeClass("running")
				.addClass("done")
				.css("width","100%")
				.html(data.result && data.result.message ? data.result.message : data.files[0]["name"]);
		},
		fail: function(e,data) {
			$("div[id='fpb"+data.files[0]["name"]+"'] .fileprogressbar", "#progress .info")
				.removeClass("running")
				.addClass("failed")
				.css("width","100%")
				.html(data.textStatus+": "+$.map(data.files, function(v,i) { return v.name;}).join(", "));
			console.log(data);
		},
		stop: function(e,data) {
			// $('#progress').dialog('close');
			$(this).data('ask.confirm',false);
			$("#progress").dialog("option","beforeClose",function() { return true; });
			$("#progress").dialog("option","close",function() { updateFileList(); });
			$("#progress").dialog("option","buttons",[ { text: $("#close").html(), click:  function() { $(this).dialog("close"); }}]);
		},
		change: function(e,data) {
			uploadState.transports = new Array();
			uploadState.aborted = false;
			uploadState.files = new Array();
			return true;
		},
		start: function(e,data) {
			
			var buttons = new Array();
			buttons.push({ text:$("#close").html(), disabled: true});
			buttons.push({text:$("#cancel").html(), click: function() {
				if (uploadState.aborted) return;
				uploadState.aborted=true;
				$.each(uploadState.transports, function(i,jqXHR) {
					if (jqXHR && jqXHR.abort) jqXHR.abort($("#uploadaborted").html());
				});
				uploadState.transports = [];
			}});
			$('#progress').dialog({ modal:true, title: dialogtitle, height: 370 , width: 500, buttons: buttons, beforeClose: function() { return false;} });
			$('#progress').show().each(function() {
				$(this).find('.bar').css('width','0%').html('0%');
				$(this).find('.info').html('');
			});
		},
		progress: function(e,data) {
			var perc = parseInt(data.loaded/data.total * 100)+"%";
			$("div[id='fpb"+data.files[0]["name"]+"'] .fileprogressbar", "#progress .info").css("width", perc).html(data.files[0]["name"]+" ("+renderByteSize(data.files[0]["size"])+"): "+perc);
			
		},
		progressall: function(e,data) {
			var perc =  data.loaded / data.total * 100;
			$('#progress .bar').css('width', perc.toFixed(2) + '%').html(parseInt(perc)+'% ('+renderByteSize(data.loaded)+'/'+renderByteSize(data.total)+')');
		},
		submit: function(e,data) {
			if (!$(this).data('ask.confirm')) $(this).data('ask.confirm', cookie("settings.confirm.upload") == "no" || !checkUploadedFilesExist(data) || window.confirm(confirmmsg));
			return $(this).data('ask.confirm');
		}
	});	
}
function checkUploadedFilesExist(data) {
	for (var i=0; i<data.files.length; i++) {
		if ($("#fileList tr[data-file='"+simpleEscape(data.files[i].name)+"']").length>0) return true;
	}
	return false;
}
function initZipFileUpload() { 
	initUpload($("#zipfile-upload-form"), $("#zipuploadconfirm").html(),$("#progress").attr('data-title'), false);
	$("a[data-action='uncompress']").click(
			function (event) { 
				preventDefault(event);
				$("#zipfile-upload-form input[type=file]").trigger("click"); 
				$('#new ul').addClass('hidden'); 
			}
	);
}
function initFileUpload() {
	initUpload($("#file-upload-form"),$('#fileuploadconfirm').html(), $("#progress").attr('data-title'), $(document));
	
	$('#fileuploadbutton').button().click(function(event) { 
		preventDefault(event); 
		$("#file-upload-form input[type=file]").trigger('click'); 
	});
	
	$(document).bind('dragenter', function (e) {
		$("#fileList").addClass('draghover');
	}).bind('dragleave', function(e) {
		$("#fileList").removeClass('draghover');
	}).bind('drop', function(e) {
		$("#fileList").removeClass('hover');
	});

}

function confirmDialog(text, data) {
	var oldsetting;
	if (data.setting) {
		text+='<div class="confirmdialogsetting"><input type="checkbox" name="'+data.setting+'"/> '+$("#confirmdialogsetting").html()+'</div>';
		oldsetting = cookie(data.setting);
	}
	$("#confirmdialog").html(text).dialog({  
		modal: true,
		width: 500,
		height: "auto",
		title: $("#confirmdialog").attr('data-title'),
		buttons: [ 
			{ 
				text: $("#cancel").html(), 
				click: function() {
					if (data.setting) {
						if (!oldsetting || oldsetting == "") rmcookies(data.setting); 
						else cookie(data.setting, oldsetting);
					}
					$("#confirmdialog").dialog("close");  
					if (data.cancel) data.cancel();
				} 
			}, 
			{ 	
				text: "OK", 
				click: function() { 
					$("#confirmdialog").dialog("close");
					if (data.confirm) data.confirm() 
				} 
			},
		],
		open: function() {
			if (data.setting) {
				$("input[name='"+data.setting+"']",$(this)).click(function(event) {
					cookie(data.setting, $(this).is(":checked") ? "yes" : "no");
				}).prop("checked", cookie(data.setting)!="no");
			}
		},
		close: function() {
			if (data.cancel) data.cancel();
		}
	}).show();
}
function getVisibleAndSelectedFiles() {
	return $("#fileList tr[data-isreadable='yes'][data-unselectable='no']").filter(function() {return $(this).hasClass("selected") && $(this).is(":visible"); }).find("div.filename");
}
function handleFileActions(event) {
	preventDefault(event);
	var row = $(this).closest("tr");
	var action = $(this).attr('data-action');
	if (action == 'download') {
		submitFileForm('zip',row.attr('data-file'));
	} else if (action == 'rename') {
		handleFileRename(row);
	} else if (action == 'delete') {
		handleFileDelete(row);
	} else if (action == 'edit') {
		handleFileEdit(row);
	}
}
function initFileList() {
	var flt = $("#fileListTable");
	var fl = $("#fileList");
	
	initTableSorter();

	$("#fileList.selectable-false tr").attr("data-unselectable", "yes");
	
	$("#fileList tr[data-unselectable='yes'] input[type=checkbox]").attr("disabled","disabled");
	
	// init single file actions:
	$("#fileList tr[data-unselectable='no']").hover(
			function() {
				if ($(".fileactions",$(this)).length==0) {
					$("div.filename",$(this)).after($("#fileactions").html());
					$(".fileactions a[data-action]", $(this)).click(handleFileActions);
				}
			},
			function() {
				$(".fileactions",$(this)).off("click").remove();	
			}
	);
	
	// mouse events on a file row:
	$("#fileList tr")
		.click(handleRowClickEvent)
		.dblclick(function(event) { 
			changeUri(concatUri($("#fileList").attr('data-uri'), encodeURIComponent(stripSlash($(this).attr('data-file')))),
					$(this).attr("data-type") == 'file');
		}
	);
	
	// fix selections after tablesorter:
	$("#fileList tr.selected td input[type='checkbox']:not(:checked)").prop("checked",true);

	// fix annyoing text selection for shift+click:
	$('#fileList').disableSelection();
	
	// init fancybox:
	$("#fileList tr[data-isviewable='yes'][data-iseditable='no']:not([data-file$='.pdf'])[data-size!='0'] td.filename a")
		.attr("rel","imggallery")
		.fancybox({
			beforeLoad: function() { this.title = $(this.element).html(); }, 
			helpers: { thumbs: { width: 60, height: 60, source: function(current) { return (current.element).attr('href')+'?action=thumb'; } } } 
		});
	$("#fileList tr[data-isviewable='yes'][data-iseditable='yes'][data-size!='0'] td.filename a,#fileList tr[data-isviewable='yes'][data-file$='.pdf'] td.filename a")
		.attr("rel","txtgallery")
		.fancybox({
			type: 'iframe', arrows: false, beforeLoad: function() { this.title = $(this.element).html(); }, 
			helpers: { thumbs: { width: 60, height: 60, source: function(current) { return (current.element).attr('href')+'?action=thumb'; } } } 
		});

	// init drag & drop:
	$("#fileList:not(.dnd-false) tr[data-iswriteable='yes'][data-type='dir']")
			.droppable({ scope: "fileList", tolerance: "pointer", drop: handleFileListDrop, hoverClass: 'draghover' });
	$("#fileList:not(.dnd-false) tr[data-isreadable='yes'][data-unselectable='no'] div.filename")
			.multiDraggable({getGroup: getVisibleAndSelectedFiles, zIndex: 200, scope: "fileList", revert: true, axis: "y" });
	
	$("#flt").trigger("fileListChanged");
}

function initTableSorter() {
	
	var flt = $("#fileListTable");
	
	if (cookie('order')) {
		var so = cookie('order').split("_");
		var sname = so[0];
		var sortorder = so[1] && so[1] == 'desc' ? -1 : 1;
		var col = $("#fileListTable thead th[data-name='"+sname+"']");
		var sattr = col.attr('data-sort');
		var stype = col.attr('data-sorttype') ? col.attr('data-sorttype') : 'string';
		var cidx = col.prop("cellIndex");
		//console.log("stype="+stype+", sattr="+sattr+"; sortorder="+sortorder+"; cidx="+cidx);
		flt.data("tablesorter-lastclickedcolumn", cidx);
		flt.data("tablesorter-sortorder", sortorder);
		col.addClass(sortorder == 1 ? 'tablesorter-up' : 'tablesorter-down');
		sortFileList(stype, sattr, sortorder, cidx, "data-file");
	}
	
	var th = $("th:not(.sorter-false),td:not(.sorter-false)",$("#fileListTable thead"));
	
	th.addClass('tablesorter-head').on("click.tablesorter", function(event) {

		$("#fileListTable .tablesorter-head").removeClass('tablesorter-down').removeClass('tablesorter-up');
		
		var lcc = flt.data("tablesorter-lastclickedcolumn");
		var sortorder = flt.data("tablesorter-sortorder");
		var stype = $(this).attr("data-sorttype") ? $(this).attr("data-sorttype") : "string";
		var sattr = $(this).attr("data-sort");
		var cidx = this.cellIndex;
		if (!sortorder) sortorder = -1;
		if (lcc == cidx) sortorder = -sortorder;
		flt.data("tablesorter-lastclickedcolumn", cidx);
		flt.data("tablesorter-sortorder", sortorder);
		//console.log("stype="+stype+"; sattr="+sattr+"; sortorder="+sortorder+"; cidx="+cidx+"; lcc="+lcc);
		$(this).addClass(sortorder == 1 ? 'tablesorter-up' : 'tablesorter-down');
		cookie("order",$(this).attr('data-name') + (sortorder==-1?'_desc':''));
		
		sortFileList(stype,sattr,sortorder,cidx,"data-file");
		
		th.off("click.tablesorter");
		initFileList();
		
	});
	
}
function sortFileList(stype,sattr,sortorder,cidx,ssattr) {
	$("#fileListTable tbody").each(function(i,val){
		var rows = new Array();
		for (var r=0; r< this.rows.length; r++) {
			rows.push(this.rows.item(r).cloneNode(true));
		}
		rows.sort(function(a,b){
			var ret = 0;
			var jqa = $(a);
			var jqb = $(b);
			var vala = jqa.attr(sattr) ? (stype=='number' ? parseInt(jqa.attr(sattr)) : jqa.attr(sattr)) : a.cells.item(cidx).innerHTML.toLowerCase();
			var valb = jqb.attr(sattr) ? (stype=='number' ? parseInt(jqb.attr(sattr)) : jqb.attr(sattr)) : b.cells.item(cidx).innerHTML.toLowerCase();
	
			if (jqa.attr('data-file') == "..") return -1;
			if (jqb.attr('data-file') == "..") return 1;
			if (jqa.attr('data-type') == 'dir'  && jqb.attr('data-type') == 'file') return -1;
			if (jqa.attr('data-type') == 'file' && jqb.attr('data-type') == 'dir') return 1;
			
		
			if (stype == "number") {
				ret = vala - valb;
			} else {
				if (vala.localeCompare) {
					ret = vala.localeCompare(valb);
				} else {
					ret = (vala < valb ? -1 : (vala==valb ? 0 : 1));
				}
			}
			if (ret == 0 && sattr!=ssattr) {
				if (vala.localeCompare) 
					ret = jqa.attr(ssattr).localeCompare(jqb.attr(ssattr));
				else
					ret = jqa.attr(ssattr) < jqb.attr(ssattr) 
							? -1 : jqa.attr(ssattr) > jqb.attr(ssattr)	? 1 : 0; 
			}
			return sortorder * ret;
		});
		for (var r=0; r<rows.length; r++) {
			val.replaceChild(rows[r], val.children[r]);
		}
		
	});
}
function handleFileEdit(row) {
	$.get(concatUri($('#fileList').attr('data-uri'), encodeURIComponent(row.attr('data-file'))), function(response) {
		if (response.message || response.error) {
			handleJSONResponse(response);
		} else {
			var dialog = $('#edittextdata');
			var text = $("textarea[name=textdata]", dialog);
			dialog.attr('title',row.attr('data-file'));
			text.attr("data-file",row.attr("data-file"));
			text.val(response);
			text.data("response", text.val());
			dialog.find('a[data-action=savetextdata]').button().unbind('click').click(function(event) {
				preventDefault(event);
				
				function doSaveTextData() {
					text.trigger("editsubmit");
					$.post(addMissingSlash($('#fileList').attr('data-uri')), { savetextdata: 'yes', filename: row.attr('data-file'), textdata: text.val() }, function(response) {
						if (!response.error && response.message) {
							text.data("response", text.val());
							updateFileList();
						}
						handleJSONResponse(response);
					});	
				}
				if (cookie("settings.confirm.save") != "no") 
					confirmDialog($('#confirmsavetextdata').html().replace(/%s/,row.attr('data-file')), { confirm: doSaveTextData, setting: "settings.confirm.save" });
				else
					doSaveTextData();
			});
			dialog.find('a[data-action=cancel-edit]').button().unbind('click').click(function(event) {
				preventDefault(event);
				text.trigger("editsubmit");
				dialog.dialog('close');
			});
			
			dialog.dialog({ 
				modal: true, width: "auto", height: "auto",
				title: row.attr('data-file'),
				open: function() { text.trigger("editstart");},
				close: function(event) { text.trigger("editdone");},
				beforeClose: function(event,ui) { return text.val() == text.data("response") || window.confirm($('#canceledit').html());}
			});

		}
	});
}
function concatUri(base,file) {
	return (addMissingSlash(base) + file).replace(/\/\//g,"/").replace(/\/[^\/]+\/\.\.\//g,"/");
}
function addMissingSlash(base) {
	return (base+'/').replace(/\/\//g,"/");
}
function handleFileDelete(row) {
	row.fadeTo('slow',0.5);
	confirmDialog($('#deletefileconfirm').html().replace(/%s/,simpleEscape(row.attr('data-file'))),{
		confirm: function() {
			var file = row.attr('data-file');
			removeFileListRow(row);
			$.post($('#fileList').attr('data-uri'), { 'delete': 'yes', file: file }, function(response) {
				if (response.error) updateFileList();
				handleJSONResponse(response);
			});
		},
		cancel: function() {
			row.fadeTo('fast',1);
		}
	});
}
function handleJSONResponse(response) {
	if (response.error)  notifyError(response.error);
	if (response.warn) notifyWarn(response.warn);
	if (response.message) notifyInfo(response.message);
	if (response.quicknav) {
		$("#quicknav").html(response.quicknav);
		$("#quicknav a").click(function(event) {
			preventDefault(event);
			changeUri($(this).attr("href"));
		});
	}
}
function handleFileRename(row) {
	var tdfilename = row.find('td.filename');
	var filename = row.attr('data-file');

	renamefield = $('#renamefield').html();

	tdfilename.wrapInner('<div class="hidden"/>').prepend(renamefield);
	var inputfield = tdfilename.find('.renamefield input[type=text]');
	inputfield.attr('value',inputfield.attr('value').replace(/\$filename/,filename)).focus().select();
	$("#fileList").enableSelection();
	inputfield.keydown(function(event) {
		var row = $(this).closest('tr');
		var file = $(this).closest('tr').attr('data-file');
		var newname = $(this).val();
		if (event.keyCode == 13 && file != newname) {
			preventDefault(event);
			function doRename() {
				$.post($('#fileList').attr('data-uri'), { rename: 'yes', newname: newname, file: file  }, function(response) {
					if (response.error) {
						row.find('.renamefield').remove();
						row.find('td.filename div.hidden div.filename').unwrap();
					} else if (response.message) {
						updateFileList();
					}
					handleJSONResponse(response);
				});
			}
			if (cookie("settings.confirm.rename")!="no") {
				confirmDialog($("#movefileconfirm").html().replace(/\\n/g,'<br/>').replace(/%s/,file).replace(/%s/,newname), {
					confirm: doRename,
					setting: "settings.confirm.rename"
				});
			} else {
				doRename();
			}
		} else if (event.keyCode == 27 || (event.keyCode==13 && file == newname)) {
			row.find('.renamefield').remove();
			row.find('td.filename div.hidden div.filename').unwrap();
			$("#fileList").disableSelection();
		}
	});
}
function notify(type,msg) {
	console.log("notify["+type+"]: "+msg);
	noty({text: msg, type: type, layout: 'topCenter', timeout: 30000 });
//	var notification = $("#notification");
//	notification.removeClass().hide();
//	notification.unbind('click').click(function() { $(this).hide().removeClass(); }).addClass(type).html('<span>'+simpleEscape(msg)+'</span>').show();
	// .fadeOut(30000,function() { $(this).removeClass(type).html("");});
}
function notifyError(error) {
	notify('error',error);
}
function notifyInfo(info) {
	notify('message',info);
}
function notifyWarn(warn) {
	notify('warning',warn);
}
function submitFileForm(fileaction, filename) {
	$('#fileform').attr('action',$('#fileList').attr('data-uri'));
	$('#fileform #fileaction').attr('name',fileaction).attr('value','yes');
	$('#fileform #filename').attr('value',filename);
	$('#fileform').submit(); 
}


function handleRowClickEvent(event) {
	var flt = $('#fileListTable');
	if ($(this).attr('data-file') != '..' && $(this).attr('data-unselectable')!='yes' ) {
		var start = this.rowIndex;
		var end = start;
		if ((event.ctrlKey || event.shiftKey || event.metaKey || event.altKey) && flt.data('lastSelectedRowIndex')) {
			end = flt.data('lastSelectedRowIndex');
			if (end < start ) {
				var c = end;
				end = start;
				start = c;
			}
			for (var r = start + 1 ; r < end ; r++ ) {
				var row = $("#fileList tr").filter(function(i){ return this.rowIndex == r});
				if (!row) continue;
				row.toggleClass("selected");
				row.find("input[name='file'][type='checkbox']").prop('checked', row.hasClass("selected"));
				row = row.next();

			}
		} 
		$(this).toggleClass("selected");
		$(this).find("input[type=checkbox]").prop('checked', $(this).hasClass("selected"));
		flt.data('lastSelectedRowIndex', this.rowIndex);
		$("#flt").trigger("fileListSelChanged");
	}
}
function initDialogActions() {
	$('a.dialog').click(handleDialogActionEvent);
}
function handleDialogActionEvent(event) {
	preventDefault(event);
	var action = $("#"+$(this).attr('data-action'));
	action.dialog({modal:true, title: $(this).html(), width: 'auto', 
					open: function() { if (action.data("initHandler")) action.data("initHandler").init(); }, 
					buttons : [ { text: $("#close").html(), click:  function() { $(this).dialog("close"); }}]}).show();
}
function initFileListActions() {
	$('a.listaction[data-action]').button().click(handleFileListActionEvent);
	$("#flt").on("fileListSelChanged", updateFileListActions).on("fileListViewChanged",updateFileListActions);
}
function updateFileListActions() {
	var s = getFolderStatistics();
	//if (s["sumselcounter"] > 0 ) $('#filelistactions').show(); else $('#filelistactions').hide();
	
	toggleButton($("[data-sel='none']"), s["sumselcounter"]!=0);
	toggleButton($("[data-sel='one']"), s["sumselcounter"]!=1);
	toggleButton($("[data-sel='multi']"), s["sumselcounter"]==0);
	toggleButton($("[data-sel='noneorone']"), s["sumselcounter"]>1);

	toggleButton($("[data-sel='none'][data-seltype='dir']"), s["fileselcounter"]!=0 );
	toggleButton($("[data-sel='one'][data-seltype='dir']"), s["fileselcounter"]>0 || s["dirselcounter"]!=1);
	toggleButton($("[data-sel='multi'][data-seltype='dir']"), s["fileselcounter"]>0 || s["dirselcounter"]==0);
	toggleButton($("[data-sel='noneorone'][data-seltype='dir']"), s["fileselcounter"]>0 || s["dirselcounter"]>1);

	toggleButton($("[data-sel='none'][data-seltype='file']"),  s["fileselcounter"]!=0)
	toggleButton($("[data-sel='one'][data-seltype='file']"), s["dirselcounter"]>0 || s["fileselcounter"]!=1);
	toggleButton($("[data-sel='multi'][data-seltype='file']"), s["dirselcounter"]>0 || s["fileselcounter"]==0);
	toggleButton($("[data-sel='noneorone'][data-seltype='file']"), s["dirselcounter"]>0 || s["fileselcounter"]>1);
}
function initFolderStatistics() {
	$("#flt").on("fileListChanged", updateFolderStatistics).on("fileListViewChanged", updateFolderStatistics);
}
function resetFileListCounters(flt) {
	if (!flt) flt=$('#fileListTable');
	if (flt && flt.attr) 
		flt.attr('data-filecounter',0).attr('data-dircounter',0).attr('data-foldersize',0)
			.attr('data-fileselcounter',0).attr('data-dirselcounter',0).attr('data-folderselsize',0);
}
function updateFileListCounters() {
	var flt = $("#fileListTable");
	// file list counters:
	resetFileListCounters(flt);

	var s = getFolderStatistics();

	flt.attr('data-dircounter', s["dircounter"]);
	flt.attr('data-filecounter', s["filecounter"]);
	flt.attr('data-foldersize', s["foldersize"]);
}
function getFolderStatistics() {
	var stats = new Array();

	stats["dircounter"] =  $("#fileList tr[data-mime='<folder>']:visible").length;
	stats["filecounter"] = $("#fileList tr[data-type!='dir']:visible").length;
	stats["sumcounter"] = stats["dircounter"]+stats["filecounter"];
	stats["dirselcounter"] = $("#fileList tr.selected[data-mime='<folder>']:visible").length;
	stats["fileselcounter"] = $("#fileList tr.selected[data-type!='dir']:visible").length;
	stats["sumselcounter"] = stats["dirselcounter"]+stats["fileselcounter"];

	var foldersize = 0;
	var folderselsize = 0;
	$("#fileList tr:visible").each(function(i,val) {  
		var size = parseInt($(this).attr('data-size'));
		if ($(this).hasClass('selected')) folderselsize +=size;
		foldersize += size;
	});

	stats["foldersize"]=foldersize;
	stats["folderselsize"]=folderselsize;

	return stats;
}
function updateFolderStatistics() {
	var hn = $('#headerName');
	var flt = $('#fileListTable');
	var hs = $('#headerSize');

	updateFileListCounters();

	if (!hn.attr('data-title')) hn.attr('data-title',hn.attr('title'));
	if (!hs.attr('data-title')) hs.attr('data-title',hs.attr('title'));
	hn.attr('title', 
			hn.attr('data-title')
				.replace(/\$filecount/, flt.attr('data-filecounter'))
				.replace(/\$dircount/,flt.attr('data-dircounter'))
				.replace(/\$sum/,parseInt(flt.attr('data-dircounter'))+parseInt(flt.attr('data-filecounter')))
		);
	var fs = parseInt(flt.attr('data-foldersize'));
	hs.attr('title', hs.attr('data-title').replace(/\$foldersize/, renderByteSizes(fs)));
}
function simpleEscape(text) {
	//return text.replace(/&/,'&amp;').replace(/</,'&lt;').replace(/>/,'&gt;');
	return $('<div/>').text(text).html();
}
function changeUri(uri, leaveUnblocked) {
	// try browser history manipulations:
	try {
		if (!leaveUnblocked) {
			if (window.history.pushState) {
				window.history.pushState({path: uri},"",uri);
				updateFileList(uri);
				$(window).off("popstate.changeuri").on("popstate.changeuri", function() {
					var loc = history.location || document.location;
					updateFileList(loc.pathname);
				});
				return true;
			} else {
				updateFileList(uri);
				return true;
			}
		}
	} catch (e) {
		console.log(e);		
	}
	// fallback for errors and unblocked links:
	if (!leaveUnblocked) blockPage();
	window.location.href=uri;
	
}
function updateFileList(newtarget, data) {
	if (!newtarget) newtarget = $('#fileList').attr('data-uri');
	if (!newtarget) newtarget = window.location.href;
	if (!data) {
		data={ajax: "getFileListTable", template: $('#flt').attr('data-template')};
	}
	$(".ajax-loader").show();
	$("#flt").hide();
	$.get(newtarget, data, function(response) {
		$("#flt")
			.show()
			.html(response.content)
			.attr("data-uri",newtarget);
		$(".ajax-loader").hide();
		initFileList();
		handleJSONResponse(response);
	});
}
function removeFileListRow(row) {
	row.remove();
	$("#flt").trigger("fileListChanged");
}
function handleFileListDrop(event, ui) {
	var dragfilerow = ui.draggable.closest('tr');
	var dsturi = concatUri($("#fileList").attr('data-uri'), encodeURIComponent(stripSlash($(this).attr('data-file')))+"/");
	var srcuri = concatUri($("#fileList").attr("data-uri"),'/');
	if (dsturi == concatUri(srcuri,encodeURIComponent(stripSlash(dragfilerow.attr('data-file'))))+"/") return false;
	var action = event.shiftKey || event.altKey || event.ctrlKey || event.metaKey ? "copy" : "cut" ;
	var files = dragfilerow.hasClass('selected') 
				?  $.map($("#fileList tr.selected:visible"), function(val, i) { return $(val).attr("data-file"); }) 
				: new Array(dragfilerow.attr('data-file'));

	function doFileListDrop() {
		var block = blockPage(); 
		$.post(dsturi, { srcuri: srcuri, action: action , files: files.join('@/@')  }, function (response) {
			if (response.message && action=='cut') { 
				removeFileListRow($("#fileList tr[data-file='"+files.join("'],#fileList tr[data-file='")+"']"));
			}
			block.remove();
			if (response.error) updateFileList();
			handleJSONResponse(response);
		});
	}			
	
	if (cookie("settings.confirm.dnd")!="no") {
		var msg = $("#paste"+action+"confirm").html();
		msg = msg.replace(/%files%/g, uri2html(files.join(', ')))
				.replace(/%srcuri%/g, uri2html(srcuri))
				.replace(/%dsturi%/g, uri2html(dsturi))
				.replace(/\\n/g,"<br/>");
		confirmDialog(msg, { confirm: doFileListDrop, setting: "settings.confirm.dnd" });
	} else {
		doFileListDrop();
	}
}
function blockPage() {
	return $("<div></div>").prependTo("body").addClass("overlay");
}
function stripSlash(uri) {
	return uri.replace(/\/$/,"");
}
function handleFileListActionEvent(event) {
	var action = $(this).attr('data-action');
	preventDefault(event);
	function uncheckSelectedRows() {
		$("#fileList tr.selected:visible input[type=checkbox]").prop('checked',false);
		$("#fileList tr.selected:visible").removeClass("selected");
		$("#flt").trigger("fileListSelChanged");
	}
	if ($(this).hasClass("disabled")) return;
	if (action == "download") {
		$('#filelistform').attr('action',$('#fileList').attr('data-uri'));
		$('#filelistform input[id=filelistaction]').attr('name','zip').attr('value','yes');
		$('#filelistform').submit();
		uncheckSelectedRows();
	} else if (action == "delete") {
		$("#fileList tr.selected:visible").fadeTo("slow",0.5);
		$("#fileList tr.selected:not(:visible) input[name='file'][type='checkbox']").prop('checked',false);
		confirmDialog($('#deletefilesconfirm').html(), {
			confirm: function() {
				$('#filelistform input[id=filelistaction]').attr('name','delete').attr('value','yes');
				$.post($('#fileList').attr('data-uri'), $('#filelistform').serialize(), function(response) {
					removeFileListRow($("#fileList tr.selected:visible"));
					uncheckSelectedRows();
					$("#fileList tr.selected:not(:visible) input[name='file'][type='checkbox']").prop('checked',true);
					if (response.error) updateFileList();
					handleJSONResponse(response);
				});
			},
			cancel: function() {
				$("#fileList tr.selected:visible").fadeTo("fast",1);
				$("#fileList tr.selected:not(:visible) input[name='file'][type='checkbox']").prop('checked',true);
			}
		});
	} else if (action == "cut"||action=="copy") {
		$("#fileList tr").removeClass("cutted").fadeTo("fast",1);
		var selfiles = $.map($("#fileList tr.selected"), function(val,i) { return $(val).attr("data-file"); });	
		var baseuri = $("#fileList").attr("data-baseuri");
		cookie('clpfiles', selfiles.join('@/@'));
		cookie('clpaction',action);
		cookie('clpuri',concatUri($("#fileList").attr('data-uri'),"/"));
		if (action=="cut") $("#fileList tr.selected").addClass("cutted").fadeTo("slow",0.5);
		handleClipboard();
		uncheckSelectedRows();
	} else if (action == "paste") {
		var files = cookie("clpfiles");
		var action= cookie("clpaction");
		var srcuri= cookie("clpuri");
		var dsturi = concatUri($("#fileList").attr("data-uri"),"/");
		
		function doPasteAction() {
			var block = blockPage();
			$.post(dsturi, { action: action, files: files, srcuri: srcuri }, function(response) {
				if (cookie("clpaction") == "cut") rmcookies("clpfiles","clpaction","clpuri");
				block.remove();
				updateFileList();
				handleJSONResponse(response);
			});
		}
		if (cookie("settings.confirm.paste") != "no") {
			var msg = $("#paste"+action+"confirm").html()
					.replace(/%srcuri%/g, uri2html(srcuri))
					.replace(/%dsturi%/g, uri2html(dsturi)).replace(/\\n/g,"<br/>")
					.replace(/%files%/g, uri2html(files.split("@/@").join(", ")));
			confirmDialog(msg, { confirm: doPasteAction, setting: "settings.confirm.paste" });
		} else doPasteAction();
	}
}
function uri2html(uri) {
	return simpleEscape(decodeURIComponent(uri));
}
function cookie(name,val,expires) {
	var date = new Date();
       	date.setTime(date.getTime() + 315360000000);
	if (val) return $.cookie(name, val, { path:$("#fileList").attr("data-baseuri"), secure: true, expires: expires ? date : undefined});
	return $.cookie(name);
}
function rmcookies() {
	for (var i=0; i < arguments.length; i++) $.removeCookie(arguments[i], { path:$("#fileList").attr("data-baseuri"), secure: true});
}
function renderByteSizes(size) {
	var text = "";
	text += size+" Byte(s)";
	var nfs = size / 1024;
	if (nfs.toFixed(2) > 0) text +=' = '+nfs.toFixed(2)+'KB';
	nfs = nfs / 1024;
	if (nfs.toFixed(2) > 0) text +=' = '+nfs.toFixed(2)+'MB';
	nfs = nfs / 1024;
	if (nfs.toFixed(2) > 0) text +=' = '+nfs.toFixed(2)+'GB';
	nfs = nfs / 1024;
	if (nfs.toFixed(2) > 0) text +=' = '+nfs.toFixed(2)+'TB';
	return text;
}
function renderByteSize(size) {
	var text = size+" Byte(s)";
	var nfs = size / 1024;
	if (nfs.toFixed(2) > 0 && nfs > 1) text = nfs.toFixed(2)+'KB';
	nfs = nfs / 1024;
	if (nfs.toFixed(2) > 0 && nfs > 1) text =nfs.toFixed(2)+'MB';
	nfs = nfs / 1024;
	if (nfs.toFixed(2) > 0 && nfs > 1) text =nfs.toFixed(2)+'GB';
	nfs = nfs / 1024;
	if (nfs.toFixed(2) > 0 && nfs > 1) text =nfs.toFixed(2)+'TB';
	return text;
}
function initClipboard() {
	handleClipboard();
	$('#flt').on('fileListChanged', handleClipboard);
}
function handleClipboard() {
	var action = cookie("clpaction");
	var datauri = concatUri($("#fileList").attr("data-uri"),"/");
	var srcuri = cookie("clpuri");
	var files = cookie("clpfiles");
	$('a.listaction.paste').button("option","disabled",  (!files || files=="" || srcuri  == datauri)); 
	if (srcuri == datauri && action == "cut") 
		$.each(files.split("@/@"), function(i,val) { 
			$("[data-file='"+val+"']").addClass("cutted").fadeTo("fast",0.5);
		}) ;
}

function handleInplaceInput(target, defval) {
	target.click(function(event) {
		preventDefault(event);
		if (target.hasClass("disabled")) return;
		if (target.data('is-active')) return;
		target.data('is-active', true);
		target.data('orig-html', target.html());
		inplace=$('<div class="inplace"><form method="post" action="#"><input class="inplace input"/></form></div>');
		var input = inplace.find('input');
		if (defval) input.val(defval);
		inplace.keydown(function(event) {
			if (event.keyCode == 13) {
				preventDefault(event);
				target.data('is-active', false);
				target.html(target.data('orig-html'));
				if ((defval && input.val() == defval)||(input.val() == "")) {
					target.data('value',input.val()).trigger('unchanged');
				} else {
					target.data('value',input.val()).trigger('changed');
				}
			} else if (event.keyCode == 27) {
				target.data('is-active', false);
				target.html(target.data('orig-html'));
				target.trigger('canceled');
			}
		});
		target.html(inplace);
		input.focus();
	});
	return target;
}
function initNewActions() {
	$('#new [data-action=new]').button().click(function(event) {
		preventDefault(event);
		$('#new ul').toggleClass('hidden');
	});
	$('#new ul').mouseout(function(event) {
		// $('#new ul').addClass('hidden');
	}).keypress(function(event) {
		if (event.keyCode == 27) $('#new ul').toggleClass('hidden');
	});
	handleInplaceInput($('#new a[data-action=create-folder]')).on('changed', function(event) {
		$('#new ul').toggleClass('hidden');
		$.post($('#fileList').attr('data-uri'), { mkcol : 'yes', colname : $(this).data('value') }, function(response) {
			if (!response.error && response.message) updateFileList();
			handleJSONResponse(response);
		});
	});

	handleInplaceInput($('#new [data-action=create-file]')).on('changed', function(event) {
		$('#new ul').toggleClass('hidden');
		$.post($('#fileList').attr('data-uri'), { createnewfile : 'yes', cnfname : $(this).data('value') }, function(response) {
			if (!response.error && response.message) updateFileList();
			handleJSONResponse(response);
		});
	});

	handleInplaceInput($('#new a[data-action=create-symlink]')).on('changed', function(event) {
		$('#new ul').toggleClass('hidden');
		var row = $('#fileList tr.selected');
		$.post($('#fileList').attr('data-uri'), { createsymlink: 'yes', lndst: $(this).data('value'), file: row.attr('data-file') }, function(response) {
			if (!response.error && response.message) updateFileList();
			handleJSONResponse(response);
		});

	});
}
function preventDefault(event) {
	if (event.preventDefault) event.preventDefault(); else event.returnValue = false;
	if (event.stopPropagation) event.stopPropagation();
}

function trimString(str,charcount) {
	if (str.length > charcount)  str = str.substr(0,4)+'...'+str.substr(str.length-charcount+7,charcount-7);
	return str;
}
function initAFS() {
	$("[data-action='afsaclmanager']").click(handleAFSACLManager);
	$("[data-action='afsgroupmanager']").click(handleAFSGroupManager);
}
function initGroupManager(groupmanager, template, target){
	var groupmanager, groupManagerResponseHandler;
	groupManagerResponseHandler = function(response) {
		groupmanager.html($(response).unwrap());
		initGroupManager(groupmanager, template, target);
	};
	
	var groupSelectionHandler = function(event) {
		preventDefault(event);
		$.get(target, { ajax:"getAFSGroupManager", template: template, afsgrp: $(this).closest("li").attr('data-group')}, groupManagerResponseHandler);
	};
	$("#afsgrouplist li[data-group='"+$("#afsmemberlist").attr("data-afsgrp")+"']").addClass("selected");
	$("#afsgrouplist a[data-action='afsgroupdelete']", groupmanager).hide();
	$("#afsgrouplist li", groupmanager)
		.click(groupSelectionHandler)
		.hover(function(){
			$("a[data-action='afsgroupdelete']",$(this)).show();
		},function(){
			$("a[data-action='afsgroupdelete']", $(this)).hide();
		});
	
	$("[data-action='afsgroupdelete']", groupmanager).click(function(event){
		preventDefault(event);
		var afsgrp = $(this).closest("li").attr('data-group');
		confirmDialog($("#afsconfirmdeletegrp").html(),{
			confirm: function() {
				$.post(target,{afsdeletegrp : 1, afsgrp: afsgrp} , function(response){
					handleJSONResponse(response);
					$.get(target,{ajax: "getAFSGroupManager", template: template},groupManagerResponseHandler);
				});
			}
		});
	});
	$("input[name='afsnewgrp']", groupmanager)
		.focus(function(event) { $(this).val($(this).attr('data-user')+":").select();})
		.keypress(function(event){
			if (event.keyCode == 13) {
				var afsgrp = $(this).val();
				$.post(target,{afscreatenewgrp: "1", afsnewgrp: afsgrp}, function(response){
					handleJSONResponse(response);
					$.get(target, { ajax: "getAFSGroupManager", template: template, afsgrp: afsgrp}, groupManagerResponseHandler);
				});		
			}
		});
	$("img[data-action='afscreatenewgrp']", groupmanager).click(function(event){
		preventDefault(event);
		var afsgrp = $("input[name='afsnewgrp']", groupmanager).val();
		$.post(target,{afscreatenewgrp: "1", afsnewgrp: afsgrp}, function(response){
			handleJSONResponse(response);
			$.get(target, { ajax: "getAFSGroupManager", template: template, afsgrp: afsgrp}, groupManagerResponseHandler);
		});		
	});
	$("input[name='afsaddusers']", groupmanager).keypress(function(event){
		if (event.keyCode == 13) {
			var user = $(this).val();
			var afsgrp = $(this).attr('data-afsgrp');
			$.post(target,{afsaddusr: 1, afsaddusers: user, afsselgrp: afsgrp}, function(response){
				handleJSONResponse(response);
				$.get(target,{ajax: "getAFSGroupManager", template: template, afsgrp: afsgrp}, groupManagerResponseHandler);
			});					
		}
	});
	$("img[data-action='afsaddusr']", groupmanager).click(function(event){
		var user =$("input[name='afsaddusers']", groupmanager).val();
		var afsgrp = $("input[name='afsaddusers']", groupmanager).attr("data-afsgrp");
		$.post(target,{afsaddusr: 1, afsaddusers: user, afsselgrp: afsgrp}, function(response){
			handleJSONResponse(response);
			$.get(target,{ajax: "getAFSGroupManager", template: template, afsgrp: afsgrp}, groupManagerResponseHandler);
		});
	});
	$("a[data-action='afsmemberdelete']").click(function(event){
		var afsgrp = $("#afsmemberlist").attr("data-afsgrp");
		var member = $(this).closest("li").attr("data-member");
		preventDefault(event);
		confirmDialog($("#afsconfirmremoveuser").html(),{
			confirm: function() {
				$.post(target,{afsremoveusr:1,afsselgrp:afsgrp,afsusr: member}, function(response){
					handleJSONResponse(response);
					$.get(target,{ajax: "getAFSGroupManager", template: template, afsgrp: afsgrp}, groupManagerResponseHandler);
				});		
			}
		});
	});
	$("a[data-action='afsremoveselectedmembers']")
	.toggleClass("disabled", $("#afsmemberlist li.selected").length==0)
	.click(function(event){
		preventDefault(event);
		if ($(this).hasClass("disabled")) return;
		var afsmembers = $.map($("#afsmemberlist li.selected"), function(val,i){ return $(val).attr("data-member");});
		var afsgrp = $("#afsmemberlist").attr("data-afsgrp");
		confirmDialog($("#afsconfirmremoveuser").html(),{
			confirm: function() {
				$.post(target, {afsremoveusr: 1, afsselgrp: afsgrp, afsusr: afsmembers }, function(response){
					handleJSONResponse(response);
					$.get(target,{ajax: "getAFSGroupManager", template: template, afsgrp: afsgrp},groupManagerResponseHandler);
				});
			}
		});
	});
	$("#afsmemberlist li a[data-action='afsmemberdelete']", groupmanager).hide();
	$("#afsmemberlist li", groupmanager).click(function(event){
		$(this).toggleClass("selected");
		$("a[data-action='afsremoveselectedmembers']").toggleClass("disabled", $("#afsmemberlist li.selected").length==0)
	}).hover(function() {
		$("a[data-action='afsmemberdelete']",$(this)).show();
	},function(){
		$("a[data-action='afsmemberdelete']",$(this)).hide();
	});
	$("#afsgroupmanager", groupmanager).submit(function(event){return false;});

}
function handleAFSGroupManager(event) {
	preventDefault(event);
	var template = $(this).attr('data-template');
	var target = $("#fileList").attr('data-uri');
		
	$.get(target, { ajax : "getAFSGroupManager", template: template }, function(response) {
		var groupmanager = $(response);
		initGroupManager(groupmanager, template, target);
		groupmanager.dialog({modal: false, width: "auto", height: "auto", close: function() { groupmanager.remove();}}).show();
	});	
}
function handleAFSACLManager(event){
	preventDefault(event);
	if ($(this).hasClass("disabled")) return false;
	var target = $("#fileList").attr('data-uri');
	var seldir = $("#fileList tr.selected[data-type='dir']");
	var template = $(this).attr('data-template');
	if (seldir.length>0) target = concatUri(target,encodeURIComponent(stripSlash($(seldir[0]).attr('data-file')))+"/");
	$.get(target, { ajax : "getAFSACLManager", template : template }, function(response) {
		var aclmanager = $(response);
		$("input[readonly='readonly']",aclmanager).click(function(e) { preventDefault(e); });
		("#afasaclmanager",aclmanager).submit(function() {
			$("input[type='submit']",aclmanager).attr("disabled","disable");
			$.post(target, $("#afsaclmanager",aclmanager).serialize(), function(response) {
				handleJSONResponse(response);
				//aclmanager.dialog("close");
				$.get(target, {ajax: "getAFSACLManager", template: template}, function(response) {
					aclmanager.html($(response).unwrap());
					$("input[readonly='readonly']",aclmanager).click(function(e) { preventDefault(e); });
				});
			});
			return false;
		});
		aclmanager.dialog({modal: true, width: "auto", height: "auto", close: function() { aclmanager.remove(); }}).show();
	});
}
function initPermissionsDialog() {
	$("a[data-action='permissions']").click(function(event){
		preventDefault(event);
		if ($(this).hasClass("disabled")) return;
		var target = $("#fileList").attr("data-uri");
		var template = $(this).attr("data-template");
		$.get(target, {ajax: "getPermissionsDialog", template: template},function(response){
			var permissions = $(response);
			$("form",permissions).submit(function(){
				var permissionsform = $(this);
				confirmDialog($("#changepermconfirm").html(), {
					confirm: function() {
						$.post(target, permissionsform.serialize()+"&"+$("#filelistform").serialize(), function(resp){
							handleJSONResponse(resp);
							permissions.dialog("close");
							updateFileList();
						});
					}
				});
				return false;
			});
			permissions.dialog({modal:true, width: "auto", height: "auto", close: function() {permissions.remove();}}).show();
		});
	});
}
function initViewFilterDialog() {
	var mutex = false;
	$("a[data-action='viewfilter']").click(function(event){
		preventDefault(event);
		if (mutex) return;
		mutex = true;
		var target =$("#fileList").attr("data-uri");
		var template = $(this).attr("data-template");
		$.get(target, {ajax: "getViewFilterDialog", template: template}, function(response){
			var vfd = $(response);
			$("input[name='filter.size.val']", vfd).spinner({min: 0, page: 10, numberFormat: "n", step: 1});
			$("[data-action='filter.apply']", vfd).button().click(function(event){
				preventDefault(event);
				if ($("input[name='filter.name.val']", vfd).val() != "") 
					cookie("filter.name", $("select[name='filter.name.op'] option:selected", vfd).val()+" "+$("input[name='filter.name.val']",vfd).val());
				else rmcookies("filter.name");
				if ($("input[name='filter.size.val']", vfd).val() != "")
					cookie("filter.size",
						$("select[name='filter.size.op'] option:selected",vfd).val() 
						+ $("input[name='filter.size.val']",vfd).val() 
						+ $("select[name='filter.size.unit'] option:selected",vfd).val());
				else rmcookies("filter.size");
				if ($("input[name='filter.types']:checked", vfd).length > 0) {
					var filtertypes = "";
					$("input[name='filter.types']:checked", vfd).each(function(i,val) {
						filtertypes += $(val).val();
					});
					cookie("filter.types", filtertypes);
				} else rmcookies("filter.types");
				vfd.dialog("close");
				updateFileList();
			});
			$("[data-action='filter.reset']", vfd).button().click(function(event){
				preventDefault(event);
				rmcookies("filter.name", "filter.size", "filter.types");
				vfd.dialog("close");
				updateFileList();
			});
			vfd.submit(function(){
				return false;
			});
			vfd.dialog({modal:true,width:"auto",height:"auto", close: function(){vfd.remove(); mutex=false;}}).show();
		});
	});
}
// ready ends: 
});
