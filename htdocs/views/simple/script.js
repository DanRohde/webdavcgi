$(document).ready(function() {
	
	initUIEffects();
	
	initBookmarks();

	initFileListActions();

	initClipboard();

	initFolderStatistics();

	initNewActions();

	initChangeDir();

	initSearchBox();

	initFileUpload();

	initZipFileUpload();

	initSelectionStatistics();

	initDialogActions()

	initTooltips();
	
	initPermissionsDialog();
	
	initViewFilterDialog();

	initClock();
	
	initAFS(); 

	initSelectAll();
	
	$(document).ajaxError(function(event, jqxhr, settings, exception) { 
		console.log(event);
		console.log(jqxhr); 
		console.log(settings);
		console.log(exception);
		if (jqxhr && jqxhr.statusText) notifyError(jqxhr.statusText)
	});
	
	
		
	updateFileList(window.location.pathname);
function initUIEffects() {
	$(".accordion").accordion({ collapsible: true, active: false });
}
function initSelectAll() {
	$("#flt").on("fileListChanged", function() {
		$('#selectall').off("click").click(function(event) {
			preventDefault(event);
			$("#fileList tr:not(:hidden)").trigger("click");
			$(this).prop('checked',false);
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
	$("#flt").on("bookmarksChanged", buildBookmarkList).on("bookmarksChanged",toggleBookmarkButtons);
	buildBookmarkList();
	toggleBookmarkButtons();

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
			.toggleClass("disabled", epath == currentPath)
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
		window.location.href = $(this).attr('data-bookmark');	
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
	$('#pathinput form').submit(function(event) { return false; });
	$('#pathinput input[name=uri]').keyup(function(event){
		if (event.keyCode==27) $('#pathinput').hide();
		else if (event.keyCode==13) window.location.href = $(this).val();
	});
	$('#path a[data-action=changedir]').button().click(function(event) {
		$('#pathinput').show();
		$('#pathinput input[name=uri]').val(decodeURI($('#fileList').attr('data-uri'))).focus().select();
	});

}
function initSearchBox() {
	$('form.searchbox').submit(function(event) { return false;});
	$('form.searchbox input.searchbox').keyup(applySearch);
	$('#flt').on('fileListChanged', applySearch);
}
function applySearch() {
	var filter = $("form.searchbox input.searchbox").val();
	$('#fileList tr').each(function() {
		try {
			var r = new RegExp(filter,"i");
			if (filter == "" || $(this).attr('data-file').match(r)) $(this).show(); else $(this).hide();	
		} catch (error) {
			if (filter == "" || $(this).attr('data-file').toLowerCase().indexOf(filter.toLowerCase()) >-1) $(this).show(); else $(this).hide();
		}
	});

	$("#flt").trigger("fileListViewChanged");
}
function initZipFileUpload() {
	var zipfile = $("#zipfile-upload-form input[type=file]");
	$("a[data-action='uncompress']").click(function (event) { preventDefault(event); zipfile.trigger("click"); $('#new ul').addClass('hidden'); });

	$("#zipfile-upload-form").fileupload({
		url: $("#fileList").attr('data-uri'),
		sequentialUploads: true,
		dropZone: $("a[data-action='uncompress']"),
		submit: function() {
			return window.confirm($("#zipuploadconfirm").html());
		},
		done: function(e,data) {
			if (data.result) handleJSONResponse(data.result);
			updateFileList();
		}
	});

}
function initFileUpload() {
	$('#fileuploadbutton').button().click(function(event) { preventDefault(event); $("#file-upload-form input[type=file]").trigger('click'); });
	var jqXHR = $('#file-upload-form').fileupload({ 
		url: window.location.href, 
		sequentialUploads: false,
		limitConcurrentUploads: 3,
		autoUpload: true,
		done:  function(e,data) {
			if (data.result && data.result.message) $('#progress .info').append('<div>'+data.result.message+'</div>');
			else if (data.files && data.files[0]) $('#progress .info').append('<div>'+data.files[0].name+'</div>');
			$("#progress .info").scrollTop($("#progress .info")[0].scrollHeight);
		},
		fail: function(e,data) {
			$('#progress .info').append('<div class="error">'+data.textStatus+': '+$.map(data.files, function(v,i) { return v.name;}).join(", ")+'</div>');
			console.log(data);
		},
		stop: function(e,data) {
			// $('#progress').dialog('close');
			$(this).data('ask.confirm',false);
			$("#progress").dialog("option","beforeClose",function() { return true; });
			$("#progress").dialog("option","close",function() { updateFileList(); });
			$("#progress").dialog("option","buttons",[ { text: $("#close").html(), click:  function() { $(this).dialog("close"); }}]);
		},
		start: function(e,data) {
			var buttons = new Array();
			buttons.push({ text:$("#close").html(), disabled: true});
			if (jqXHR.abort) buttons.push({text:$("#cancel").html(), click: function() { if (jqXHR.abort) jqXHR.abort(); }});
			$('#progress').dialog({ modal:true, title: $("#progress").attr('data-title'), height: 370 , width: 500, buttons: buttons, beforeClose: function() { return false;} });
			$('#progress').show().each(function() {
				$(this).find('.bar').css('width','0%').html('0%');
				$(this).find('.info').html('');
			});
		},
		progressall: function(e,data) {
			var perc =  data.loaded / data.total * 100;
			$('#progress .bar').css('width', perc.toFixed(2) + '%').html(parseInt(perc)+'% ('+renderByteSize(data.loaded)+'/'+renderByteSize(data.total)+')');
		},
		send: function(e,data) {
			$('#progress .info').append('<div>'+$.map(data.files,function(v,i) { return v.name+" ("+renderByteSize(v.size)+") ...";} ).join('</div><div>')+'</div>');
			$("#progress .info").scrollTop($("#progress .info")[0].scrollHeight);
		},
		submit: function(e,data) {
			if (!$(this).data('ask.confirm')) $(this).data('ask.confirm',window.confirm($('#fileuploadconfirm').html()));
			return $(this).data('ask.confirm');
		},
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
	$("#confirmdialog").html(text).dialog({  
		modal: true,
		width: 500,
		height: "auto",
		title: $("#confirmdialog").attr('data-title'),
		buttons: [ 
			{ text: $("#cancel").html(), click: function() { $("#confirmdialog").dialog("close");  if (data && data.cancel) data.cancel();  } }, 
			{ text: "OK", click: function() { $("#confirmdialog").dialog("close"); if (data.confirm) data.confirm() } }
		],
	}).show();
}
function getVisibleAndSelectedFiles() {
	return $("#fileList tr[data-isreadable='yes'][data-unselectable='no']").filter(function() {return $(this).hasClass("selected") && $(this).is(":visible"); }).find("div.filename");
}
function initFileList() {
	var flt = $("#fileListTable");
	var fl = $("#fileList");

	initTableSorter();
	
	$("#fileList tr[data-unselectable='yes'] input[type=checkbox]").remove();
	
	// init file actions:
	if ($("#fileList tr[data-unselectable='no'] .fileactions").length==0) {
			$("#fileList tr[data-unselectable='no'] div.filename").after($('#fileactions').html());
	}
	$("#fileList tr[data-unselectable='no'] .fileactions a").click(function(event) {
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
	});
	
	// init fancybox:
	$("#fileList tr[data-isviewable='yes'][data-iseditable='no']:not([data-file$='.pdf']):not([data-size='0']) a.nametext").attr("rel","imggallery").fancybox({
		beforeLoad: function() { this.title = $(this.element).html(); }, 
		helpers: { thumbs: { width: 60, height: 60, source: function(current) { return (current.element).attr('href')+'?action=thumb'; } } } 
	});
	$("#fileList tr[data-isviewable='yes'][data-iseditable='yes']:not([data-size='0']) a.nametext,#fileList tr[data-isviewable='yes'][data-file$='.pdf'] a.nametext").attr("rel","txtgallery").fancybox({
		type: 'iframe', arrows: false, beforeLoad: function() { this.title = $(this.element).html(); }, 
		helpers: { thumbs: { width: 60, height: 60, source: function(current) { return (current.element).attr('href')+'?action=thumb'; } } } 
	});

	// init drag & drop:
	$("#fileList tr[data-iswriteable='yes'][data-type='dir']").droppable({ scope: "fileList", drop: handleFileListDrop, hoverClass: 'draghover' });
	// $("#fileList tr[data-isreadable=yes]:not([data-file='..']) div.filename").draggable({zIndex: 200, scope: "fileList", revert: true});
	$("#fileList tr[data-isreadable='yes'][data-unselectable='no'] div.filename").multiDraggable({getGroup: getVisibleAndSelectedFiles, zIndex: 200, scope: "fileList", revert: true});

	
	// mouse events:
	$("#fileList tr")
		.hover(function() {
			$(this).toggleClass("hover");
			$(".fileactions",$(this)).toggleClass("visible");
		})
		.click(handleRowClickEvent)
		.dblclick(function(event) { 
			changeUri($(this));
		})
		;
	
		
	$("#flt").trigger("fileListChanged");

}

function initTableSorter() {
	
		var flt = $("#fileListTable");
		
		$("#fileListTable thead .tablesorter-up,#fileListTable thead .tablesorter-down")
		.removeClass('tablesorter-down').removeClass('tablesorter-up');

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
			sortFileList(stype, sattr, sortorder, cidx);
		}
		
		var th = $("#fileListTable thead th:not(.sorter-false),#fileListTable thead td:not(.sorter-false)");
		
		th.on("click.tablesorter", function(event) {
	
			$("#fileListTable thead .tablesorter-up,#fileListTable thead .tablesorter-down")
				.removeClass('tablesorter-down').removeClass('tablesorter-up');
			
			
			
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
			
			sortFileList(stype,sattr,sortorder,cidx);
			
			th.off("click.tablesorter");
			initFileList();
			
	}).addClass('tablesorter-head');
	
}
function sortFileList(stype,sattr,sortorder,cidx) {
	$("#fileListTable tbody").each(function(i,val){
		var rows = new Array();
		for (var r=0; r< this.rows.length; r++) {
			rows.push(this.rows.item(r).cloneNode(true));
		}
		rows.sort(function(a,b){
			var jqa = $(a);
			var jqb = $(b);
			var vala = jqa.attr(sattr) ? (stype=='number' ? parseInt(jqa.attr(sattr)) : jqa.attr(sattr)) : a.cells.item(cidx).innerHTML.toLowerCase();
			var valb = jqb.attr(sattr) ? (stype=='number' ? parseInt(jqb.attr(sattr)) : jqb.attr(sattr)) : b.cells.item(cidx).innerHTML.toLowerCase();
	
			if (jqa.attr('data-file') == "..") return -1;
			if (jqb.attr('data-file') == "..") return 1;
			if (jqa.attr('data-type') == 'dir'  && jqb.attr('data-type') == 'file') return -1;
			if (jqa.attr('data-type') == 'file' && jqb.attr('data-type') == 'dir') return 1;
			
		
			if (stype == "number") {
				return sortorder * (vala - valb);
			} else {
				if (vala.localeCompare) {
					return sortorder * vala.localeCompare(valb);
				} else {
					return sortorder * (vala < valb ? -1 : (vala==valb ? 0 : 1));
				}
			}
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
			text.data("response",response).val(response);
			dialog.find('a[data-action=savetextdata]').button().unbind('click').click(function(event) {
				preventDefault(event);
				confirmDialog($('#confirmsavetextdata').html().replace(/%s/,row.attr('data-file')), {
					confirm: function() {
						$.post(addMissingSlash($('#fileList').attr('data-uri')), { savetextdata: 'yes', filename: row.attr('data-file'), textdata: text.val() }, function(response) {
							if (!response.error && response.message) {
								text.data("response", text.val());
								updateFileList();
							}
							handleJSONResponse(response);
						});
					}
				});

			});
			dialog.find('a[data-action=cancel-edit]').button().unbind('click').click(function(event) {
				preventDefault(event);
				dialog.dialog('close');
			});

			dialog.dialog({ modal: true, width: 'auto', title: row.attr('data-file'), beforeClose: function(event,ui) { return text.val() == text.data("response") || window.confirm($('#canceledit').html()); }  });

		}
	});
}
function concatUri(base,file) {
	return (addMissingSlash(base) + file).replace(/\/\//g,"/").replace(/\/[^\/]+\.\.\//g,"/");
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
}
function handleFileRename(row) {
	var tdfilename = row.find('td.filename');
	var filename = row.attr('data-file');

	renamefield = $('#renamefield').html();

	tdfilename.wrapInner('<div class="hidden"/>').prepend(renamefield);
	var inputfield = tdfilename.find('.renamefield input[type=text]');
	inputfield.attr('value',inputfield.attr('value').replace(/\$filename/,filename)).focus().select();

	inputfield.keypress(function(event) {
		var row = $(this).closest('tr');
		var file = $(this).closest('tr').attr('data-file');
		var newname = $(this).val().trim();
		if (event.keyCode == 13 && file != newname) {
			preventDefault(event);
			confirmDialog($("#movefileconfirm").html().replace(/\\n/g,'<br/>').replace(/%s/,file).replace(/%s/,newname), {
				confirm: function() {
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
			});
		} else if (event.keyCode == 27 || (event.keyCode==13 && file == newname)) {
			row.find('.renamefield').remove();
			row.find('td.filename div.hidden div.filename').unwrap();
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
	var action = $(this).attr('data-action');
	$("#"+action).dialog({modal:true, title: $(this).html(), width: 'auto', buttons : [ { text: $("#close").html(), click:  function() { $(this).dialog("close"); }}]}).show();
}
function initFileListActions() {
	$('a.listaction[data-action]').button().click(handleFileListActionEvent);
	$("#flt").on("fileListSelChanged", updateFileListActions).on("fileListViewChanged",updateFileListActions);
}
function updateFileListActions() {
	var s = getFolderStatistics();
	if (s["sumselcounter"] > 0 ) $('#filelistactions').show(); else $('#filelistactions').hide();
	
	toggleButton($("a[data-sel='one']"), s["sumselcounter"]!=1);
	toggleButton($("a[data-sel='multi']"), s["sumselcounter"]==0);
	toggleButton($("a[data-sel='noneorone']"), s["sumselcounter"]>1);

	toggleButton($("a[data-sel='one'][data-seltype='dir']"), s["fileselcounter"]>0 || s["dirselcounter"]!=1);
	toggleButton($("a[data-sel='multi'][data-seltype='dir']"), s["fileselcounter"]>0 || s["dirselcounter"]==0);
	toggleButton($("a[data-sel='noneorone'][data-seltype='dir']"), s["fileselcounter"]>0 || s["dirselcounter"]>1);

	toggleButton($("a[data-sel='one'][data-seltype='file']"), s["dirselcounter"]>0 || s["fileselcounter"]!=1);
	toggleButton($("a[data-sel='multi'][data-seltype='file']"), s["dirselcounter"]>0 || s["fileselcounter"]==0);
	toggleButton($("a[data-sel='noneorone'][data-seltype='file']"), s["dirselcounter"]>0 || s["fileselcounter"]>1);
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

	stats["dircounter"] =  $("#fileList tr[data-type='dir']:not([data-file='..']):visible").length;
	stats["filecounter"] = $("#fileList tr[data-type='file']:visible").length;
	stats["sumcounter"] = stats["dircounter"]+stats["filecounter"];
	stats["dirselcounter"] = $("#fileList tr.selected[data-type='dir']:not([data-file='..']):visible").length;
	stats["fileselcounter"] = $("#fileList tr.selected[data-type='file']:visible").length;
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
function changeUri(row) {
	$("body").addClass("disabled");
	window.location.href=($("#fileList").attr('data-uri')+'/'+row.attr('data-file')).replace(/\/\//,'/');
}
function changeUri_ajax(row) {

	$("#fileList").prop("disabled",true);
	$("#fileList").addClass("disabled");

	if (row.attr('data-type') == 'dir') {
		$("#fileList").html("");

		var newtarget = $("#fileList").attr('data-uri')+'/'+row.attr('data-file')+'/';
		newtarget = newtarget.replace(/\/\//,'/').replace(/\/[^\/]+\/\.\.\//,"/");

		if (newtarget.length < window.location.pathname.length) 
			window.location.href = newtarget;
		else
			updateFileList(newtarget);
	} else {
		window.location.href=$("#fileList").attr('data-uri')+'/'+row.attr('data-file');
	}
}
function updateFileList(newtarget) {
	if (!newtarget) newtarget = $('#fileList').attr('data-uri');
	$(".ajax-loader").show();
	$('#flt').hide();
	$.get(newtarget+"?ajax=getFileListTable;template="+encodeURI($('#flt').attr('data-template')), function (response) {
		$("#flt")
			.show()
			.html(response.content)
			.attr("data-uri",newtarget)
			.removeClass("disabled");
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
	var dsturi = concatUri($("#fileList").attr('data-uri'), $(this).attr('data-file')+'/');
	var srcuri = concatUri($("#fileList").attr("data-uri"),'/');
	console.log("dsturi="+dsturi+" srcuri="+srcuri);
	if (dsturi == concatUri(srcuri,dragfilerow.attr('data-file'))) return false;
	var action = event.shiftKey || event.altKey || event.ctrlKey || event.metaKey ? "copy" : "cut" ;
	var files = dragfilerow.hasClass('selected') 
				?  $.map($("#fileList tr.selected:visible"), function(val, i) { return $(val).attr("data-file"); }) 
				: new Array(dragfilerow.attr('data-file'));
	var msg = $("#paste"+action+"confirm").html();
	msg = msg.replace(/%files%/g, files.join(', ')).replace(/%srcuri%/g, srcuri).replace(/%dsturi%/g, dsturi).replace(/\\n/g,"<br/>");
	confirmDialog(decodeURI(msg), {
		confirm: function() {
			$.post(dsturi, { srcuri: srcuri, action: action , files: files.join('@/@')  }, function (response) {
				if (response.message && action=='cut') { 
					removeFileListRow($("#fileList tr[data-file='"+files.join("'],#fileList tr[data-file='")+"']"));
				}
				if (response.error) updateFileList();
				handleJSONResponse(response);
			})
		}
	});

}
function handleFileListActionEvent(event) {
	var action = $(this).attr('data-action');
	preventDefault(event);
	if ($(this).hasClass("disabled")) return;
	if (action == "download") {
		$('#filelistform').attr('action',$('#fileList').attr('data-uri'));
		$('#filelistform input[id=filelistaction]').attr('name','zip').attr('value','yes');
		$('#filelistform').submit();
	} else if (action == "delete") {
		$("#fileList tr.selected:visible").fadeTo("slow",0.5);
		$("#fileList tr.selected:not(:visible) input[name='file'][type='checkbox']").prop('checked',false);
		confirmDialog($('#deletefilesconfirm').html(), {
			confirm: function() {
				$('#filelistform input[id=filelistaction]').attr('name','delete').attr('value','yes');
				$.post($('#fileList').attr('data-uri'), $('#filelistform').serialize(), function(response) {
					removeFileListRow($("#fileList tr.selected:visible"));
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
		// $("#fileList tr.selected input[type=checkbox]").prop("checked",false);
		// $("#fileList tr.selected").removeClass("selected");
		handleClipboard();
	} else if (action == "paste") {
		var files = cookie("clpfiles");
		var action= cookie("clpaction");
		var srcuri= cookie("clpuri");
		var dsturi = concatUri($("#fileList").attr("data-uri"),"/");
		var msg = $("#paste"+action+"confirm").html().replace(/%srcuri%/g, srcuri).replace(/%dsturi%/g, dsturi).replace(/\\n/g,"<br/>").replace(/%files%/g, files.split("@/@").join(", "));
		confirmDialog(decodeURI(msg), {
			confirm: function() {
				$.post(dsturi, { action: action, files: files, srcuri: srcuri }, function(response) {
					if (cookie("clpaction") == "cut") rmcookies("clpfiles","clpaction","clpuri");
					updateFileList();
					handleJSONResponse(response);
				});
			}
		});
	}
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
	// var title =$("#paste").html();
	//if (action && srcuri && files) title += ": "+action+" "+srcuri+": "+files.split("@/@").join(", ");
	$('a.listaction.paste').button("option","disabled",  (!files || files=="" || srcuri  == datauri)); //.attr("title", decodeURI(title));
	if (srcuri == unescape(datauri) && action == "cut") 
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
		inplace.keypress(function(event) {
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
//	if ($("#afsgrouplist li.selected").length>0) $("#afsgroups").scrollTop(178);
	
	$("#afsgrouplist li", groupmanager).click(groupSelectionHandler);
	
	$("[data-action='afsgroupdelete']", groupmanager).click(function(event){
		preventDefault(event);
		var afsgrp = $(this).closest("li").attr('data-group');
		confirmDialog($("#afsconfirmdeletegrp").html(),{
			confirm: function() {
				$.post(target,{afsdeletegrp : 1, afsgrp: afsgrp} , function(response){
					handleJSONResponse(response);
					$.get(target,{ajax: "getAFSGroupManager", template: template},groupManagerResponseHandler);
				});
			},
		});
	});
	$("input[name='afsnewgrp']", groupmanager)
		.focus(function(event) { $(this).val($(this).attr('data-user')+":").select();})
		.keypress(function(event){
			if (event.keyCode == 13) {
				var afsgrp = $(this).val();
//				confirmDialog($("#afsconfirmcreategrp").html(),{
//					confirm: function(){
						$.post(target,{afscreatenewgrp: "1", afsnewgrp: afsgrp}, function(response){
							handleJSONResponse(response);
							$.get(target, { ajax: "getAFSGroupManager", template: template, afsgrp: afsgrp}, groupManagerResponseHandler);
						});		
//					},
//				});
				
			}
		});
	$("input[name='afsaddusers']").keypress(function(event){
		if (event.keyCode == 13) {
			var user = $(this).val();
			var afsgrp = $(this).attr('data-afsgrp');
//			confirmDialog($("#afsconfirmadduser").html(), {
//				confirm: function() {
					$.post(target,{afsaddusr: 1, afsaddusers: user, afsselgrp: afsgrp}, function(response){
						handleJSONResponse(response);
						$.get(target,{ajax: "getAFSGroupManager", template: template, afsgrp: afsgrp}, groupManagerResponseHandler);
					});		
//				},
//			});
			
		}
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
			},
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
	$("#afsmemberlist li").click(function(event){
		$(this).toggleClass("selected");
		
		$("a[data-action='afsremoveselectedmembers']").toggleClass("disabled", $("#afsmemberlist li.selected").length==0)
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
		groupmanager.dialog({modal: true, width: "auto", height: "auto", close: function() { groupmanager.remove();}}).show();
	});	
}
function handleAFSACLManager(event){
	preventDefault(event);
	if ($(this).hasClass("disabled")) return false;
	var target = $("#fileList").attr('data-uri');
	var seldir = $("#fileList tr.selected[data-type='dir']");
	var template = $(this).attr('data-template');
	if (seldir.length>0) target = concatUri(target,$(seldir[0]).attr('data-file'));
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
					},
				});
				return false;
			});
			permissions.dialog({modal:true, width: "auto", height: "auto", close: function() {permissions.remove();}}).show();
		});
	});
}
function initViewFilterDialog() {
	$("a[data-action='viewfilter']").click(function(event){
		preventDefault(event);
		var target =$("#fileList").attr("data-uri");
		var template = $(this).attr("data-template");
		$.get(target, {ajax: "getViewFilterDialog", template: template}, function(response){
			var vfd = $(response);
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
				console.log("remove cookies?");
				rmcookies("filter.name", "filter.size", "filter.types");
				vfd.dialog("close");
				updateFileList();
			});
			vfd.submit(function(){
				return false;
			});
			vfd.dialog({modal:true,width:"auto",height:"auto", close: function(){vfd.remove();}}).show();
		});
	});
}
// ready ends: 
});