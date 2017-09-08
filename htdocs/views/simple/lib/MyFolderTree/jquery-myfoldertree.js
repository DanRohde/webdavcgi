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
				var anode = getNodes(param).addClass("mft-active-node");
				anode.children(".mft-node-label:first").addClass("mft-active-node");
				anode.parents(".mft-collapsed").removeClass("mft-collapsed");
				if (anode.length>0 && anode[0].scrollIntoView) anode[0].scrollIntoView();
			} else if ( options == "add-node-data") { // param: function(element, data)
				var anode = getNodes(param);
				if (anode.length > 0) readUnreadNodes(anode, anode.data("mftn"), false);
			} else if ( options == "get-node-data" ) { // param: node
				return param.closest(".mft-node").data("mftn");
			} else if ( options == "get-nodes" ) { // param: function(element, data):bool
				return getNodes(param);
			} else if ( options == "remove-node") { // param: function(element, data)
				var anode = getNodes(param);
				var parent = anode.parents(".mft-node:first");
				anode.remove();
				parent.toggleClass("mft-node-empty", parent.find(".mft-node").length == 0);
			} else if ( options == "set-node-unread" ) { // param: function(element, data):bool
				var anode = getNodes(param);
				var data = anode.data("mftn");
				anode.removeClass("mft-node-read mft-node-empty").addClass("mft-collapsed").find(".mft-list").remove();
				delete data.children;
				delete data.read;
			} else if ( options == "collapse-all-nodes" ) { // param: node
				param.closest(".mft-node").addClass("mft-collapsed").find(".mft-node").addClass("mft-collapsed");
			} else if ( options == "expand-all-nodes") { // param: node
				readUnreadNodes(param, param.data("mftn"), false);
				param.closest(".mft-node").removeClass("mft-collapsed").find(".mft-node.mft-node-read").removeClass("mft-collapsed");
			} else if ( options == "expand-node" ) { // param: node
				readUnreadNodes(param, param.data("mftn"), true);
			} else if ( options == "reload-node" ) { // param: node
				reloadNode(param.closest(".mft-node"));
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
				reloadNode($(this).closest(".mft-node"));
			});
			if (settings.droppable) {
				settings.droppable.params.over_orig = settings.droppable.params.over;
				settings.droppable.params.over = function(event,ui) {
					if (event.target != this) return;
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
			el.find(".mft-node-expander,.mft-node-label").off("keyup.mft").on("keyup.mft", keyboardEventHandler);
			settings.initDom(el);
			return el;
		}
		function reloadNode(node) {
			var data = node.data("mftn");
			data.read=false;
			node.children(".mft-list").remove();
			data.children = [];
			readUnreadNodes(node, data, true, true);
			toggleNode(node, false);
		}
		function readUnreadNodes(node, data, expand, forceRead) {
			if (data.read) return;
			data.read = true;
			settings.getFolderTree(data, function(children) {
				initClickHandler(node.append(renderFolderTree(children)));
				node.addClass("mft-node-read").toggleClass("mft-node-empty", children.length == 0);
				if (expand || settings.autoExpandOnRead) toggleNode(node, false);
			}, forceRead);
		}
		function toggleNode(node, collapse) {
			node.toggleClass("mft-collapsed", collapse);
			if (!node.hasClass("mft-collapsed")) $(".mft-node", node).addClass("mft-collapsed");
			$(".mft-node-expander", node).attr({"aria-expanded":!node.hasClass("mft-collapsed")});
		}
		function renderFolderTreeNode(node) {
			if (!node.ext_attributes) node.ext_attributes = "";
			var li = $("<li "+node.ext_attributes+"></li>").addClass("mft-node");
			var expander = $("<div/>").addClass("mft-node-expander").attr({"tabindex":0, role:"tree", "aria-label" : node.name+" expander", "aria-expanded": !node.expand}).appendTo(li);
			var label = $("<div/>").addClass("mft-node-label").addClass(node.labelclasses).appendTo(li).attr({"tabindex":0,"aria-label":node.name, role:"treeitem"});
			var icon = $("<div/>").addClass("mft-node-icon").addClass(node.iconclasses).appendTo(label);
			var text = $("<div/>").addClass("mft-node-label-text").text(node.name).appendTo(label);
			if (node.read == 'yes') li.addClass("mft-node-read");
			if (node.classes) li.addClass(node.classes);
			if (node.ext_classes) li.addClass(node.ext_classes);
			if (!node.expand) li.addClass("mft-collapsed");
			if (node.title) label.attr("title", node.title);
			if (node.help) li.attr("title", node.help);
			if (node.attr) li.attr(node.attr);
			if (node.labelAttr) label.attr(node.labelAttr);
			if (node.expanderAttr) expander.attr(node.expanderAttr);
			li.data("mftn", node );
			if (node.children)
				li.toggleClass("mft-node-empty", node.read == "yes" && node.children.length == 0).append(renderFolderTree(node.children));
			else
				li.toggleClass("mft-node-empty", node.read == "yes" );
			return li;
		} 
		function renderFolderTree(tree) {
			var ul = $("<ul/>").addClass("mft-list");
			tree.sort(function(a,b) {
				return a.name.localeCompare ? a.name.localeCompare(b.name) : a.name < b.name ? -1 : a.name > b.name ? 1 : 0; 
			});
			ul.data("mft", tree );
			for (var n = 0; n < tree.length; n++) {
				ul.append(renderFolderTreeNode(tree[n]));
			}
			return ul;
		}
		function getNodes(filter) {
			return foldertree.find(".mft-node").filter(function(i,e) {
				var node = $(e);
				return filter(node, node.data("mftn"));
			});
		}
		function keyboardEventHandler(event) {
			if (event.target != this) return;
			var self = $(this);
			var cl = self.hasClass("mft-node-label") ? ".mft-node-label" : ".mft-node-expander";
			function goUp() {
				if (self.parent().prev().find(cl+":focusable:last").focus().length == 0) { // sibling
					self.parents(".mft-list:first").parents(".mft-node:first").find(cl+":focusable:first").focus(); // parent
				}
			}
			function goDown() {
				if (self.parent().find(".mft-list:first").find(cl+":focusable:first").focus().length == 0) // child
					if (self.parent().next().find(cl+":focusable:first").focus().length == 0) // sibling
						self.parents(".mft-list:first").parents(".mft-node:first").next().find(cl+":focusable:first").focus(); // next parent
			}
			switch (event.keyCode) {
			case 32:
			case 13:
				if (self.data("input-finished")) {
					self.removeData("input-finished");
					return;
				}
				self.trigger("click", { origEvent : event });
				break;
			case 33: // page up
				self.parent().siblings().first().find(cl+":focusable:first").focus();
				break;
			case 34: // page down
				self.parent().siblings().last().find(cl+":focusable:last").focus()
				break;
			case 35: // end
				foldertree.find(cl+":focusable:last").focus();
				break;
			case 36: // home
				foldertree.find(cl+":focusable:first").focus();
				break;
			case 37: // left
				if (self.prevAll(":focusable:first").focus().length == 0) { cl = ".mft-node-label"; goUp(); }
				break;
			case 38: // up
				goUp(self);
				break;
			case 39: // right
				if (self.nextAll(":focusable:first").focus().length == 0) { cl = ".mft-node-expander"; goDown(); }
				break;
			case 40: // down
				goDown();
				break;
			}
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