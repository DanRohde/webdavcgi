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
(function ( $ ) {
	$(".action.afsgroupmngr").click(handleAFSGroupManager);
	function handleAFSGroupManager(event) {
		$.MyPreventDefault(event);
		var template = $(this).attr("data-template");
		var target = $("#fileList").attr("data-uri");
		if ($(this).hasClass("disabled")) return false;
		$(".action.afsgroupmngr").addClass("disabled");
		$.MyPost(target, { ajax : "getAFSGroupManager", template: template }, function(response) {
			var groupmanager = $(response);
			initGroupManager(groupmanager, target, template);
			groupmanager.dialog({modal: false, width: "auto", height: "auto", dialogClass: "afsgroupmngr", closeText: $("#close").html(), close: function() { $(".action.afsgroupmngr").removeClass("disabled"); groupmanager.remove();}}).show();
		});
		return true;
	}
	function getAFSGroupManager(groupmanager, target, template, params) {
		var p = $.extend({ajax: "getAFSGroupManager", template: template}, params);
		var x = $.MyPost(target, p, function(response) {
			groupmanager.html($(response).unwrap());
			initGroupManager(groupmanager, target, template);
		});
		ToolBox.renderAbortDialog(x);
	}
	function initGroupManager(groupmanager, target, template){
		
		
		var groupSelectionHandler = function(event) {
			$.MyPreventDefault(event);
			getAFSGroupManager(groupmanager, target, template, {afsgrp: $(this).closest("li").attr("data-group")});
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
			$.MyPreventDefault(event);
			var afsgrp = $(this).closest("li").attr("data-group");
			ToolBox.confirmDialog($("#afsconfirmdeletegrp").html(),{
				confirm: function() {
					var xhr = $.MyPost(target,{afsdeletegrp : 1, afsgrp: afsgrp} , function(response){
						ToolBox.handleJSONResponse(response);
						getAFSGroupManager(groupmanager, target, template);
					});
					ToolBox.renderAbortDialog(xhr);
				}
			});
		});
		$("input[name='afsnewgrp']", groupmanager)
			.focus(function() { $(this).val($(this).attr("data-user")+":").select();})
			.keypress(function(event) {
				if (event.keyCode === 13) {
					var afsgrp = $(this).val();
					var xhr = $.MyPost(target,{afscreatenewgrp: 1, afsnewgrp: afsgrp}, function(response){
						ToolBox.handleJSONResponse(response);
						getAFSGroupManager(groupmanager, target, template, {afsgrp: afsgrp});
					});		
					ToolBox.renderAbortDialog(xhr);
				}
			});
		$(".afscreatenewgrp", groupmanager).click(function(event){
			$.MyPreventDefault(event);
			var afsgrp = $("input[name='afsnewgrp']", groupmanager).val();
			var xhr = $.MyPost(target,{afscreatenewgrp: "1", afsnewgrp: afsgrp}, function(response){
				ToolBox.handleJSONResponse(response);
				getAFSGroupManager(groupmanager, target, template, {afsgrp: response.error ? "" : afsgrp});
			});	
			ToolBox.renderAbortDialog(xhr);
		});
		$("input[name='afsaddusers']", groupmanager).keypress(function(event){
			if (event.keyCode == 13) {
				var user = $(this).val();
				var afsgrp = $(this).attr("data-afsgrp");
				var xhr = $.MyPost(target,{afsaddusr: 1, afsaddusers: user, afsselgrp: afsgrp}, function(response){
					ToolBox.handleJSONResponse(response);
					getAFSGroupManager(groupmanager, target, template, {afsgrp: afsgrp});
				});
				ToolBox.renderAbortDialog(xhr);
			}
		});
		$(".afsaddusr", groupmanager).click(function(){
			var user =$("input[name='afsaddusers']", groupmanager).val();
			var afsgrp = $("input[name='afsaddusers']", groupmanager).attr("data-afsgrp");
			var xhr = $.MyPost(target,{afsaddusr: 1, afsaddusers: user, afsselgrp: afsgrp}, function(response){
				ToolBox.handleJSONResponse(response);
				getAFSGroupManager(groupmanager, target, template, {afsgrp: afsgrp});
			});
			ToolBox.renderAbortDialog(xhr);
		});
		$(".afsmemberdelete", groupmanager).click(function(event){
			$.MyPreventDefault(event);
			var afsgrp = $("#afsmemberlist", groupmanager).attr("data-afsgrp");
			var member = $(this).closest("li").attr("data-member");
			ToolBox.confirmDialog($("#afsconfirmremoveuser").html(),{
				confirm: function() {
					var xhr = $.MyPost(target,{afsremoveusr:1,afsselgrp:afsgrp,afsusr: member}, function(response){
						ToolBox.handleJSONResponse(response);
						getAFSGroupManager(groupmanager, target, template, {afsgrp: afsgrp});
					});
					ToolBox.renderAbortDialog(xhr);
				}
			});
		});
		$(".afsremoveselectedmembers", groupmanager)
		.toggleClass("disabled", $("#afsmemberlist li.selected", groupmanager).length === 0)
		.click(function(event){
			$.MyPreventDefault(event);
			if ($(this).hasClass("disabled")) return;
			var afsmembers = $.map($("#afsmemberlist li.selected", groupmanager), function(v){ return $(v).data("member");});
			var afsgrp = $("#afsmemberlist").attr("data-afsgrp");
			ToolBox.confirmDialog($("#afsconfirmremoveuser").html(),{
				confirm: function() {
					var xhr = $.MyPost(target, {afsremoveusr: 1, afsselgrp: afsgrp, afsusr: afsmembers }, function(response){
						ToolBox.handleJSONResponse(response);
						getAFSGroupManager(groupmanager, target, template, {afsgrp: afsgrp});
					});
					ToolBox.renderAbortDialog(xhr);
				}
			});
		});
		$("#afsmemberlist li .afsmemberdelete", groupmanager).hide();
		$("#afsmemberlist li", groupmanager).click(function(){
			$(this).toggleClass("selected");
			$(".afsremoveselectedmembers", groupmanager).toggleClass("disabled", $("#afsmemberlist li.selected").length === 0);
		}).hover(function() {
			$(".afsmemberdelete",$(this)).show();
		},function(){
			$(".afsmemberdelete",$(this)).hide();
		});
		$("#afsgroupmanager", groupmanager).submit(function(){return false;});

	}
}( jQuery ));