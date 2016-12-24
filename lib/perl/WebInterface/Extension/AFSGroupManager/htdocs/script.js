/*********************************************************************
(C) ZE CMS, Humboldt-Universitaet zu Berlin
Written 2014 by Daniel Rohde <d.rohde@cms.hu-berlin.de>
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
$(document).ready(function() {
	$(".action.afsgroupmngr").click(handleAFSGroupManager);
	function handleAFSGroupManager(event) {
		ToolBox.preventDefault(event);
		var template = $(this).attr('data-template');
		var target = $("#fileList").attr('data-uri');
		if ($(this).hasClass("disabled")) return false;
		var self = this;
		$(".action.afsgroupmngr").addClass("disabled");
		$.get(target, { ajax : "getAFSGroupManager", template: template }, function(response) {
			var groupmanager = $(response);
			initGroupManager(groupmanager, template, target);
			groupmanager.dialog({modal: false, width: "auto", height: "auto", dialogClass: "afsgroupmngr", closeText: $("#close").html(), close: function() { $(".action.afsgroupmngr").removeClass("disabled"); groupmanager.remove();}}).show();
		});	
	}
	function initGroupManager(groupmanager, template, target){
		var groupManagerResponseHandler;
		var block;
		groupManagerResponseHandler = function(response) {
			if (block) block.remove();
			groupmanager.html($(response).unwrap());
			initGroupManager(groupmanager, template, target);
		};
		
		var groupSelectionHandler = function(event) {
			ToolBox.preventDefault(event);
			block=ToolBox.blockPage();
			var xhr = $.get(target, { ajax:"getAFSGroupManager", template: template, afsgrp: $(this).closest("li").attr('data-group')}, groupManagerResponseHandler);
			ToolBox.renderAbortDialog(xhr);
		};
		$("#afsgrouplist li[data-group='"+$("#afsmemberlist").attr("data-afsgrp")+"']").addClass("selected");
		$("#afsgrouplist .afsgroupdelete", groupmanager).hide();
		$("#afsgrouplist li", groupmanager)
			.click(groupSelectionHandler)
			.hover(function(){
				$(".afsgroupdelete",$(this)).show();
			},function(){
				$(".afsgroupdelete", $(this)).hide();
			});
		
		$(".afsgroupdelete", groupmanager).click(function(event){
			ToolBox.preventDefault(event);
			var afsgrp = $(this).closest("li").attr('data-group');
			ToolBox.confirmDialog($("#afsconfirmdeletegrp").html(),{
				confirm: function() {
					block=ToolBox.blockPage();
					var xhr= $.post(target,{afsdeletegrp : 1, afsgrp: afsgrp} , function(response){
						ToolBox.handleJSONResponse(response);
						var xhr = $.get(target,{ajax: "getAFSGroupManager", template: template},groupManagerResponseHandler);
						ToolBox.renderAbortDialog(xhr);
					});
					ToolBox.renderAbortDialog(xhr);
				}
			});
		});
		$("input[name='afsnewgrp']", groupmanager)
			.focus(function(event) { $(this).val($(this).attr('data-user')+":").select();})
			.keypress(function(event){
				if (event.keyCode == 13) {
					var afsgrp = $(this).val();
					block=ToolBox.blockPage();
					var xhr = $.post(target,{afscreatenewgrp: "1", afsnewgrp: afsgrp}, function(response){
						ToolBox.handleJSONResponse(response);
						var xhr = $.get(target, { ajax: "getAFSGroupManager", template: template, afsgrp: afsgrp}, groupManagerResponseHandler);
						ToolBox.renderAbortDialog(xhr);
					});		
					ToolBox.renderAbortDialog(xhr);
				}
			});
		$(".afscreatenewgrp", groupmanager).click(function(event){
			ToolBox.preventDefault(event);
			block = ToolBox.blockPage();
			var afsgrp = $("input[name='afsnewgrp']", groupmanager).val();
			var xhr = $.post(target,{afscreatenewgrp: "1", afsnewgrp: afsgrp}, function(response){
				ToolBox.handleJSONResponse(response);
				var xhr = $.get(target, { ajax: "getAFSGroupManager", template: template, afsgrp: response.error ? '' : afsgrp}, groupManagerResponseHandler);
				ToolBox.renderAbortDialog(xhr);
			});	
			ToolBox.renderAbortDialog(xhr);
		});
		$("input[name='afsaddusers']", groupmanager).keypress(function(event){
			if (event.keyCode == 13) {
				block = ToolBox.blockPage();
				var user = $(this).val();
				var afsgrp = $(this).attr('data-afsgrp');
				var xhr = $.post(target,{afsaddusr: 1, afsaddusers: user, afsselgrp: afsgrp}, function(response){
					ToolBox.handleJSONResponse(response);
					var xhr = $.get(target,{ajax: "getAFSGroupManager", template: template, afsgrp: afsgrp}, groupManagerResponseHandler);
					ToolBox.renderAbortDialog(xhr);
				});
				ToolBox.renderAbortDialog(xhr);
			}
		});
		$(".afsaddusr", groupmanager).click(function(event){
			block = ToolBox.blockPage();
			var user =$("input[name='afsaddusers']", groupmanager).val();
			var afsgrp = $("input[name='afsaddusers']", groupmanager).attr("data-afsgrp");
			var xhr = $.post(target,{afsaddusr: 1, afsaddusers: user, afsselgrp: afsgrp}, function(response){
				ToolBox.handleJSONResponse(response);
				var xhr = $.get(target,{ajax: "getAFSGroupManager", template: template, afsgrp: afsgrp}, groupManagerResponseHandler);
				ToolBox.renderAbortDialog(xhr);
			});
			ToolBox.renderAbortDialog(xhr);
		});
		$(".afsmemberdelete", groupmanager).click(function(event){
			var afsgrp = $("#afsmemberlist", groupmanager).attr("data-afsgrp");
			var member = $(this).closest("li").attr("data-member");
			ToolBox.preventDefault(event);
			ToolBox.confirmDialog($("#afsconfirmremoveuser").html(),{
				confirm: function() {
					block = ToolBox.blockPage();
					var xhr = $.post(target,{afsremoveusr:1,afsselgrp:afsgrp,afsusr: member}, function(response){
						ToolBox.handleJSONResponse(response);
						var xhr = $.get(target,{ajax: "getAFSGroupManager", template: template, afsgrp: afsgrp}, groupManagerResponseHandler);
						ToolBox.renderAbortDialog(xhr);
					});
					ToolBox.renderAbortDialog(xhr);
				}
			});
		});
		$(".afsremoveselectedmembers", groupmanager)
		.toggleClass("disabled", $("#afsmemberlist li.selected", groupmanager).length==0)
		.click(function(event){
			ToolBox.preventDefault(event);
			if ($(this).hasClass("disabled")) return;
			var afsmembers = $.map($("#afsmemberlist li.selected", groupmanager), function(val,i){ return $(val).attr("data-member");});
			var afsgrp = $("#afsmemberlist").attr("data-afsgrp");
			ToolBox.confirmDialog($("#afsconfirmremoveuser").html(),{
				confirm: function() {
					block = ToolBox.blockPage();
					var xhr = $.post(target, {afsremoveusr: 1, afsselgrp: afsgrp, afsusr: afsmembers }, function(response){
						ToolBox.handleJSONResponse(response);
						var xhr = $.get(target,{ajax: "getAFSGroupManager", template: template, afsgrp: afsgrp},groupManagerResponseHandler);
						ToolBox.renderAbortDialog(xhr);
					});
					ToolBox.renderAbortDialog(xhr);
				}
			});
		});
		$("#afsmemberlist li .afsmemberdelete", groupmanager).hide();
		$("#afsmemberlist li", groupmanager).click(function(event){
			$(this).toggleClass("selected");
			$(".afsremoveselectedmembers", groupmanager).toggleClass("disabled", $("#afsmemberlist li.selected").length==0);
		}).hover(function() {
			$(".afsmemberdelete",$(this)).show();
		},function(){
			$(".afsmemberdelete",$(this)).hide();
		});
		$("#afsgroupmanager", groupmanager).submit(function(event){return false;});

	}
});
