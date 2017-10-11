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

function WebDAVCGIFolderTree() {
	this.initFolderTree();
}

WebDAVCGIFolderTree.prototype.initFolderTree = function() {
	function handleFolderTreeDrop(event,ui) {
		var dsturi = $(this).closest(".mft-node").data("mftn").uri;
		var srcinfo = getFileListDropSrcInfo(event,ui);
		if (dsturi != srcinfo.srcuri) doFileListDropWithConfirm(srcinfo,dsturi);
		return false;
	}
	function setActiveNodeInFolderTree(uri) {
		var duri = decodeURI(uri);
		$("#foldertree").MyFolderTree("set-active-node", function(node, data) {
			return (decodeURI(data.uri) == duri);
		});
	}
	function getNodeByUri(uri) {
		var duri = decodeURI(uri);
		return $("#foldertree").MyFolderTree("get-nodes", function(node, data) {
			return duri == decodeURI(data.uri);
		});
	}
	function initFolderTreePopupMenu() {
		$("#foldertreepopupmenu").MyPopup({
			contextmenu: $("#foldertreepopupmenu"),
			contextmenuTarget: $("#foldertree .mft-node-label, #foldertree .mft-node-expander"),
			contextmenuAnchor: "#foldertree",
			contextmenuAnchorElement: true
		}).MyPopup("close");
	}
	var flt = $("#flt");
	$(".action.toggle-foldertree").on("click", function() {
		$("#content").toggleClass("show-foldertree");
		$.MyCookie.toggleCookie("settings.show.foldertree","yes", $("#content").hasClass("show-foldertree"), true);
		$("#foldertree").MySplitPane("resize");
		$("#flt").css("margin-left",$("#content").hasClass("show-foldertree") ? ($("#foldertree").width()+12)+"px" : "");
	});
	$("body").on("windowResized", function() { $("#foldertree").MySplitPane("resize"); });
	$("#content").toggleClass("show-foldertree", $.MyCookie("settings.show.foldertree") == "yes");
	$("#foldertree")
	.MyFolderTree({ 
		nodeClickHandler: function(data) {
			if (data.isreadable && data.uri && data.uri != getURI()) changeUri(data.uri);
		},
		initDom: function(el) {
			el.MyTooltip();
		},
		droppable : {
			selector: ".mft-node.iswriteable-yes .mft-node-label",
			params: { scope: "fileList", tolerance: "intersect", drop: handleFolderTreeDrop, hoverClass: "foldertree-draghover", greedy: true }
		},
		rootNodes : [{ name: flt.data("basedn"), uri: flt.data("baseuri"), isreadable: true, iswriteable: true, classes: "isreadable-yes iswriteable-yes", labelclasses : "icon category-folderhome" }],
		getFolderTree: function(node, callback, forceRead) {
			var uri = getURI();
			var recurse = $("#foldertree").data("recurse");
			if (node.uri == uri && !forceRead && !recurse && flt.data("foldertree")) {
				callback(flt.data("foldertree"));
				$("#foldertree").trigger("foldertreeChanged");
				initFolderTreePopupMenu();
				return;
			}
			var param = { ajax: "getFolderTree" };
			if (recurse) {
				param.recurse = 1;
				$("#foldertree").removeData("recurse");
			}
			$.MyPost(node.uri, param, function(response) {
				handleJSONResponse(response);
				callback(response.children ? response.children: []);
				if (node.uri == uri) setActiveNodeInFolderTree(uri);
				$("#foldertree").trigger("foldertreeChanged");
				initFolderTreePopupMenu();
			});
		},
	})
	.on("click", function(event) {
		if (event.target == this) {
			var self = $(this);
			if (!self.is(":visible")) $(".action.toggle-foldertree:first").click();
			if (self.find(".mft-node.mft-active-node :focusable:first").focus().length == 0) self.find(":focusable:first").focus();
		}
	})
	.MySplitPane({ left: { element: "self", style: "width", min: 100, max: $("#content").width()/2 }, right: { element: $("#flt"), style: "margin-left" } });
	initFolderTreePopupMenu();
	$("#foldertreepopupmenu .action").on("click", handleFileListActionEvent);
	flt.on("fileListChanged", function() {
		var uri = getURI();
		$("#foldertree").MyFolderTree("add-node-data", function(node,data) { return data.uri == uri; });
		setActiveNodeInFolderTree(uri);
		
	});
	$(".action.foldertree-open-folder").on("click", function(event) {
		$.MyPreventDefault(event);
		changeUri($("#foldertree").MyFolderTree("get-node-data", $(this).closest(".mft-node")).uri);
	});
	$(".action.foldertree-open-current").on("click", function(event) {
		var ft = $("#foldertree");
		var basePath = getBasePath();
		var reluri = getURI().substr(basePath.length);
		var us = reluri.split(/\//);
		function openNode(path) {
			var n = getNodeByUri(path);
			var p = path + us.shift()+"/";
			if (ft.MyFolderTree("is-node-read",n)) {
				ft.MyFolderTree("expand-node",n);
				setActiveNodeInFolderTree(p);
				if (us.length>1) openNode(p);
			} else { 
				ft.off("foldertreeChanged.foc-on").on("foldertreeChanged.foc-on", function() {
					setActiveNodeInFolderTree(p);
					ft.off("foldertreeChanged.foc-on");
					if (us.length > 1) openNode(p);
				});
				ft.MyFolderTree("expand-node", n);
			}
		}
		if (reluri.length > 0) openNode(basePath);
	});
	$(".action.foldertree-expand-all").on("click", function(event) {
		$.MyPreventDefault(event);
		$("#foldertree").MyFolderTree("expand-all-nodes",$(this).closest(".mft-node"));
	});
	$(".action.foldertree-collapse-all").on("click", function(event) {
		$.MyPreventDefault(event);
		$("#foldertree").MyFolderTree("collapse-all-nodes", $(this).closest(".mft-node"));
	});
	$(".action.foldertree-refresh-current").on("click", function(event) {
		$.MyPreventDefault(event);
		$("#foldertree").MyFolderTree("reload-node", $(this).closest(".mft-node"));
		
	});
	$(".action.foldertree-read-all").on("click", function(event) {
		$.MyPreventDefault(event);
		$("#foldertree").data("recurse",true).MyFolderTree("reload-node", $(this).closest(".mft-node"));
	});
	$(".action.foldertree-new-folder").MyInplaceEditor(  
	{ 
		actionInterceptor: function() {
			return $(this).hasClass("disabled");
		},
		changeEvent: function(data) {
			var self = $(this);
			var n = self.closest(".mft-node");
			var nd = $("#foldertree").MyFolderTree("get-node-data", n);
			$.MyPost(nd.uri, { mkcol : "yes", colname : data.value }, function(response) {
				if (!response.error && response.message) 
					$("#flt").trigger("filesCreated", { base: nd.uri, files: [data.value] });
				handleJSONResponse(response);
			});
		}
	});
	$(".action.foldertree-rename-folder").on("click", function(event) {
		$.MyPreventDefault(event);
		var n = $(this).closest(".mft-node");
		var nd = $("#foldertree").MyFolderTree("get-node-data", n);
		var label = n.children(".mft-node-label:first");
		var base = $.MyStringHelper.getParentURI(nd.uri);
		var file = decodeURIComponent($.MyStringHelper.getBasename(nd.uri));
		$.MyInplaceEditor({
			editorTarget: label,
			defaultValue: file,
			changeEvent: function(data) {
				var newname = data.value.replace(/\//g,"");
				if (newname == file) return;
				if ($.MyCookie("settings.confirm.rename")!="no") {
					confirmDialog($("#movefileconfirm").html().replace(/\\n/g,"<br/>").replace(/%s/,$.MyStringHelper.quoteWhiteSpaces(file)).replace(/%s/,$.MyStringHelper.quoteWhiteSpaces(newname)), {
						confirm: function() { doRename(base, file+"/", newname); },
						setting: "settings.confirm.rename"
					});
				} else {
					doRename(base, file, newname);
				}
			}
		});
	});
	function getUriFilterFunc(data, file) {
		return function(n,d) {
			return file ? decodeURIComponent(d.uri) == decodeURIComponent(data.base) + file : d.uri == data.base;
		};
	}
	$("#flt").on("filesRemoved", function(event, data) {
		for (var i=0; i<data.files.length; i++) {
			$("#foldertree").MyFolderTree("remove-node", getUriFilterFunc(data, data.files[i]));
		}
	}).on("filesCreated fileRenamed", function(event,data) {
		var uri = getURI();
		if (data.base == uri) flt.removeData("foldertree");
		$("#foldertree").MyFolderTree("set-node-unread", getUriFilterFunc(data));
	});
};
WebDAVCGIFolderTree.prototype.getFolderTreeNodesForRows = function(rows) {
	var baseuri = decodeURIComponent(getURI());
	var uris = {};
	rows.each(function(){ uris[baseuri + $(this).data("file")]=true; });
	return $("#foldertree").MyFolderTree("get-nodes", function(node,data) {
		return uris[decodeURIComponent(data.uri)];
	});
};
WebDAVCGI.foldertree = new WebDAVCGIFolderTree();