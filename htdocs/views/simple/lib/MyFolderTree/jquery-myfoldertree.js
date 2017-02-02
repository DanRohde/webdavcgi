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
(function ( $ ) {
	$.fn.MyFolderTree = function(options, param, value) {
		var foldertree = this;
		var settings;
		if (typeof options == "string") {
			settings = foldertree.data("myfoldertree-settings");
			if (options == "set-active-node") { // param: function(element, data)
				foldertree.find(".mft-active-node").removeClass("mft-active-node");
				var anode = foldertree.find(".mft-node").filter(function(i, e) {
					var node = $(e);
					return param(node, node.data("mftn"));
				}).addClass("mft-active-node");
				anode.children(".mft-node-label:first").addClass("mft-active-node");
				anode.parents(".mft-collapsed").removeClass("mft-collapsed");
				if (anode.length>0 && anode[0].scrollIntoView) anode[0].scrollIntoView();
			} else if ( options == "add-node-data") { // param: function(element, data)
				var anode = foldertree.find(".mft-node").filter(function(i,e) {
					var node = $(e);
					return param(node, node.data("mftn"));
				});
				if (anode.length > 0) readUnreadNodes(anode, anode.data("mftn"), false);
			}
			return foldertree;
		}
		settings = $.extend({}, $.fn.MyFolderTree.defaults, options);
		foldertree.data("myfoldertree-settings", settings);
		var root = initClickHandler(renderFolderTree(settings.rootNodes));
		foldertree.addClass("mft-foldertree").append(root);
		function initClickHandler(el) {
			el.find(".mft-node-label").off(".mft").on("click.mft", function() {
				var node = $(this).closest(".mft-node");
				var data = node.data("mftn")
				node.data("mft-clicktimeout", window.setTimeout(function() {
					if (!node.data("mft-clicktimeout")) return;
					else node.removeData("mft-clicktimeout");
					settings.nodeClickHandler(data);
					if (settings.readOnFolderClick) readUnreadNodes(node, data, true);
					foldertree.find(".mft-active-node").removeClass("mft-active-node");
					node.addClass("mft-active-node").children(".mft-node-label:first").addClass("mft-active-node");
				}, 300));
			}).on("dblclick.mft", function(ev) {
				var node = $(this).closest(".mft-node");
				var data = node.data("mftn");
				window.clearTimeout(node.data("mft-clicktimeout"));
				node.removeData("mft-clicktimeout");
				readUnreadNodes(node, data);
				toggleNode(node);
				if (document.selection && document.selection.empty) document.selection.empty();
				else if (window.getSelection) {
					var sel = window.getSelection();
					if (sel && sel.removeAllRanges) sel.removeAllRanges();
				}
			});
			el.find(".mft-node-expander").off(".mft").on("click.mft", function(ev) {
				var self = $(this);
				var node = self.closest(".mft-node");
				var data = node.data("mftn");
				readUnreadNodes(node, data, false);
				toggleNode(node);
			}).on("dblclick.mft", function(ev) {
				if (!settings.rereadOnDblClick) return;
				var node = $(this).closest(".mft-node");
				var data = node.data("mftn");
				data.read=false;
				node.children(".mft-list").remove();
				data.children = [];
				readUnreadNodes(node, data, true, true);
				toggleNode(node, false);
			});
			if (settings.droppable) {
				settings.droppable.params.over_orig = settings.droppable.params.over;
				settings.droppable.params.over = function(event,ui) {
					if (even.target != this) return;
					var node = $(this).closest(".mft-node");
					foldertree.data("mft-drop-timeout", window.setTimeout(
							function() {
								readUnreadNodes(node, node.data("mftn"));
								toggleNode(node, false);
							},
							2000
					));
					if (settings.droppable.params.over_orig) settings.droppable.params.over_orig.call(this,event,ui);
				};
				settings.droppable.params.out_orig = settings.droppable.params.out;
				settings.droppable.params.out = function(event,ui) {
					window.clearTimeout(foldertree.data("mft-drop-timeout"));
					if (settings.droppable.params.out_orig) settings.droppable.params.out_orig.call(this,event,ui);
				};
				el.find(settings.droppable.selector).droppable(settings.droppable.params);
			}
			settings.initDom(el);
			return el;
		}
		function readUnreadNodes(node, data, expand, forceRead) {
			if (data.read) return;
			data.read = true;
			settings.getFolderTree(data, function(children) {
				initClickHandler(node.append(renderFolderTree(children)));
				node.toggleClass("mft-node-empty", children.length == 0);
				if (expand || settings.autoExpandOnRead) toggleNode(node, false);
			}, forceRead);
		}
		function toggleNode(node, collapse) {
			node.toggleClass("mft-collapsed", collapse);
			if (!node.hasClass("mft-collapsed")) $(".mft-node", node).addClass("mft-collapsed");
		}
		function renderFolderTreeNode(node) {
			var li = $("<li/>").addClass("mft-node");
			var label = $("<div/>").addClass("mft-node-label").text(node.name).attr("tabindex",0);
			li.append($("<div/>").addClass("mft-node-expander").attr("tabindex",0)).append(label);
			if (node.read) li.addClass("mft-node-read");
			if (node.classes) li.addClass(node.classes);
			if (!node.expand) li.addClass("mft-collapsed");
			if (node.title) label.attr("title", node.title);
			if (node.help) li.attr("title", node.help);
			li.data("mftn", node );
			if (node.children)
				li.toggleClass("mft-node-empty", node.read === true && node.children.length == 0).append(renderFolderTree(node.children));
			else
				li.toggleClass("mft-node-empty", node.read === true );
			return li;
		} 
		function renderFolderTree(tree) {
			var ul = $("<ul/>").addClass("mft-list");
			ul.data("mft", tree );
			for (var n = 0; n < tree.length; n++) {
				ul.append(renderFolderTreeNode(tree[n]));
			}
			return ul;
		}
		
		return this;
	};
	$.fn.MyFolderTree.defaults = {
		rootNodes: [{name:"/",read:true,expand:true,children:[{name:"test1",title:"/test1/"},{name:"test2"}]}],
		readOnFolderClick: false,
		autoExpandOnRead: false,
		rereadOnDblClick: true,
		getFolderTree: function(node, callback) {
			node.children = [];
			for (var i=0; i<3; i++) node.children.push({ name: node.name+"."+i});
			callback(node.children);
			return node;
		},
		nodeClickHandler : function(node) { return node; },
		initDom: function(element) { return element; }
	};
	
}( jQuery ));