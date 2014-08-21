/*********************************************************************
(C) ssystems, Harald Strack
Written 2012 by Harald Strack <hstrack@ssystems.de>
Modified 2013 by Daniel Rohde <d.rohde@cms.hu-berlin.de>
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
$(document).ready(
		function() {
			$("body").on("fileActionEvent", handlePublicUriFileActionEvent);
			function handlePublicUriFileActionEvent(event, obj) {
				var data = $(obj.obj);
				var row = data.closest("tr");
				if (data.hasClass("puri")) {
					handleFilePuri(row);
				} else if (data.hasClass("depuri")) {
					handleFileDepuri(row);
				} else if (data.hasClass("spuri")) {
					handleFileShowPuri(row);
				}
			}
			function handleFilePuri(row) {
				row.fadeTo('slow', 0.5);
				ToolBox.confirmDialog($('#purifileconfirm').html().replace(/%s/,
						ToolBox.simpleEscape(row.attr('data-file'))), {
					confirm : function() {
						var file = row.attr('data-file');
						var block = ToolBox.blockPage();
						var xhr = $.post($('#fileList').attr('data-uri'), { 'puri' : 'yes', file : file	}, function(response) {
							block.remove();
							if (response.error)
								ToolBox.updateFileList();
							else {
								row.removeClass('unshared').addClass('shared');
								ToolBox.refreshFileListEntry(file);
							}
							handleJSONResponseConfirm(response);
						});
						ToolBox.renderAbortDialog(xhr);
					},
					cancel : function() {
						row.fadeTo('fast', 1);
					}
				});
			}
			function handleFileShowPuri(row) {
				var file = row.attr('data-file');
				var block = ToolBox.blockPage();
				var xhr = $.post($('#fileList').attr('data-uri'), {'spuri' : 'yes', file : file }, function(response) {
					block.remove();
					if (response.error)
						ToolBox.updateFileList();
					handleJSONResponseConfirm(response);
				});
				ToolBox.renderAbortDialog(xhr);
			}
			function handleFileDepuri(row) {
				row.fadeTo('slow', 0.5);
				ToolBox.confirmDialog($('#depurifileconfirm').html().replace(/%s/,
						ToolBox.simpleEscape(row.attr('data-file'))), {
					confirm : function() {
						var file = row.attr('data-file');
						var block = ToolBox.blockPage();
						var xhr = $.post($('#fileList').attr('data-uri'), {'depuri' : 'yes', file : file }, function(response) {
							block.remove();
							if (response.error)
								ToolBox.updateFileList();
							else {
								row.removeClass('shared').addClass('unshared').attr("data-puri","no");
								ToolBox.refreshFileListEntry(file);
							}
							ToolBox.handleJSONResponse(response);
						});
						ToolBox.renderAbortDialog(xhr);
					},
					cancel : function() {
						row.fadeTo('fast', 1);
					}
				});
			}
			function confirm(type, msg) {
				console.log("confirm[" + type + "]: " + msg);
				noty({
					text : msg,
					type : type,
					layout : 'topCenter',
					timeout : 30000,
					closeWith : [ 'button' ],
				});
				// var notification = $("#notification");
				// notification.removeClass().hide();
				// notification.unbind('click').click(function() {
				// $(this).hide().removeClass();
				// }).addClass(type).html('<span>'+simpleEscape(msg)+'</span>').show();
				// .fadeOut(30000,function() {
				// $(this).removeClass(type).html("");});
			}
			function confirmError(error) {
				confirm('confirmation', error);
			}
			function confirmInfo(info) {
				confirm('confirmation', info);
			}
			function confirmWarn(warn) {
				confirm('confirmation', warn);
			}
			function submitFileForm(fileaction, filename) {
				$('#fileform').attr('action', $('#fileList').attr('data-uri'));
				$('#fileform #fileaction').attr('name', fileaction).attr(
						'value', 'yes');
				$('#fileform #filename').attr('value', filename);
				$('#fileform').submit();
			}
			function handleJSONResponseConfirm(response) {
					if (response.error)  confirmError(response.error);
					if (response.warn) confirmWarn(response.warn);
					if (response.message) confirmInfo(response.message);
					if (response.quicknav) {
						$("#quicknav").html(response.quicknav);
						$("#quicknav a").click(function(event) {
							preventDefault(event);
							changeUri($(this).attr("href"));
						});
					}
				}
		});