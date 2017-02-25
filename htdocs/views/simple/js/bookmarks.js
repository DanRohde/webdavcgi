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

initBookmarks();

function initBookmarks() {
	$("#flt")
		.on("bookmarksChanged", buildBookmarkList)
		.on("bookmarksChanged fileListSelChanged",toggleBookmarkButtons)
		.on("fileListChanged", function() {
			buildBookmarkList();
			toggleBookmarkButtons();
		});
	$("#flt").on("fileListChanged", function() {
		$("#bookmarks").MyTooltip();
	}).on("bookmarksChanged",function() {
		$("#bookmarks").MyTooltip();
	});
	// register bookmark actions:
	$(".action.addbookmark,.action.rmbookmark,.action.rmallbookmarks,.action.bookmarksortpath,.action.bookmarksorttime,.action.gotobookmark")
		.click(handleBookmarkActions);

	function toggleBookmarkButtons() {
		var currentPath = $.MyStringHelper.concatUri($("#flt").attr("data-uri"),"/");	
		var isCurrentPathBookmarked = false;
		var count = 0;
		var i = 0;
		while ($.MyCookie("bookmark"+i)!=null) {
			if ($.MyCookie("bookmark"+i) == currentPath) isCurrentPathBookmarked=true;
			if ($.MyCookie("bookmark"+i) != "-") count+=1;
			i+=1;
		}
		toggleButton($(".action.addbookmark"), isCurrentPathBookmarked);
		//toggleButton($(".action.rmbookmark"), !isCurrentPathBookmarked);
		toggleButton($(".action.bookmarksortpath"), count<2);
		toggleButton($(".action.bookmarksorttime"), count<2);
		toggleButton($(".action.rmallbookmarks"), count===0);
	
		var sort = $.MyCookie("bookmarksort")==null ? "time-desc" : $.MyCookie("bookmarksort");
		$(".action.bookmarksortpath .path").hide();
		$(".action.bookmarksortpath .path-desc").hide();
		$(".action.bookmarksorttime .time").hide();
		$(".action.bookmarksorttime .time-desc").hide();
		if (sort == "path" || sort=="path-desc" || sort=="time" || sort=="time-desc") {
			$(".action.bookmarksort"+sort.replace(/-desc/,"")+" ."+sort).show();
		}
	}
	function buildBookmarkList() {
		var currentPath = $.MyStringHelper.concatUri($("#flt").attr("data-uri"),"/");
		// remove all bookmark list entries:
		$(".dyn-bookmark").each(function(i,val) {
			$(val).remove();
		});
		// read existing bookmarks:
		var bookmarks = [];
		var i=0;
		while ($.MyCookie("bookmark"+i)!=null) {
			if ($.MyCookie("bookmark"+i)!="-") bookmarks.push({ path : $.MyCookie("bookmark"+i), time: parseInt($.MyCookie("bookmark"+i+"time"),10)});
			i+=1;
		}
		// sort bookmarks:
		var s = $.MyCookie("bookmarksort") ? $.MyCookie("bookmarksort") : "time-desc";
		var sortorder = 1;
		if (s.indexOf("-desc")>0) { sortorder = -1; s= s.replace(/-desc/,""); }
		bookmarks.sort(function(b1,b2) {
			if (s == "path") return sortorder * b1[s].localeCompare(b2[s]);
			else return sortorder * ( b2[s] - b1[s]);
		});
		// build bookmark list:
		var tmpl = $(".bookmarktemplate").first().html();
		$.each(bookmarks, function(idx,val) {
			var epath = unescape(val.path);
			$("<li>" + tmpl.replace(/\$bookmarkpath/g,val.path).replace(/\$bookmarktext/,$.MyStringHelper.quoteWhiteSpaces($.MyStringHelper.simpleEscape($.MyStringHelper.trimString(epath,20)))) + "</li>")
				.clone(false).insertAfter($(".bookmarktemplate"))
				.click(handleBookmarkActions).MyKeyboardEventHandler()
				.addClass("action dyn-bookmark")
				.attr("data-bookmark",val.path)
				.attr("data-htmltooltip",$.MyStringHelper.simpleEscape(epath)+"%0D"+(new Date(parseInt(val.time,10))))
				.attr("tabindex", val.path == currentPath ? -1 : 0)
				.toggleClass("disabled", val.path == currentPath)
				.find(".action.rmsinglebookmark").click(handleBookmarkActions).MyKeyboardEventHandler();
		});
	}
	function removeBookmark(path) {
		var i = 0;
		while ($.MyCookie("bookmark"+i) != null && $.MyCookie("bookmark"+i)!=path) i+=1;
		if ($.MyCookie("bookmark"+i) == path) $.MyCookie("bookmark"+i, "-", 1);
		$("#flt").trigger("bookmarksChanged");
	}
	function handleBookmarkActions(event) {
		$.MyPreventDefault(event);
		if ($(this).hasClass("disabled")) return;
		var self = $(this);
		var uri = $("#fileList").attr("data-uri");
		if (self.hasClass("addbookmark")) {
			var i = 0;
			while ($.MyCookie("bookmark"+i)!=null && $.MyCookie("bookmark"+i)!= "-" && $.MyCookie("bookmark"+i) != "" && $.MyCookie("bookmark"+i)!=uri) i+=1;
			$.MyCookie("bookmark"+i, uri, 1);
			$.MyCookie("bookmark"+i+"time", (new Date()).getTime(), 1);
			$("#flt").trigger("bookmarksChanged");
		} else if (self.hasClass("dyn-bookmark")) {
			changeUri(self.attr("data-bookmark"));	
			self.closest("ul").hide();
		} else if (self.hasClass("rmbookmark")) {
			removeBookmark(uri);
		} else if (self.hasClass("rmallbookmarks")) {
			var i = 0;
			while ($.MyCookie("bookmark"+i)!=null) {
				$.MyCookie.rmCookies("bookmark"+i, "bookmark"+i+"time");
				i+=1;
			}
			$("#flt").trigger("bookmarksChanged");
		} else if (self.hasClass("rmsinglebookmark")) {
			removeBookmark($(this).attr("data-bookmark"));
		} else if (self.hasClass("bookmarksortpath")) {
			$.MyCookie("bookmarksort", $.MyCookie("bookmarksort")=="path" || $.MyCookie("bookmarksort") == null ? "path-desc" : "path");
			$("#flt").trigger("bookmarksChanged");
		} else if (self.hasClass("bookmarksorttime")) {
			$.MyCookie("bookmarksort", $.MyCookie("bookmarksort")=="time" ? "time-desc" : "time");
			$("#flt").trigger("bookmarksChanged");
		}
	}
}
