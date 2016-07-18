/*********************************************************************
(C) ZE CMS, Humboldt-Universitaet zu Berlin
Written 2016 by Daniel Rohde <d.rohde@cms.hu-berlin.de>
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
(function($) {
    $.fn.markdownEditor = function(options) {
        if (!options) options = {};
        if (!options.locale) options.locale={};
        var self = $(this);
        var editor = $("<div/>").addClass("markdown-editor");
        var preview = $("<div/>").addClass("markdown-preview");
        var toolbar = $("<div/>").addClass("markdown-toolbar");
        function renderPreview() {
            if ($(".markdown-preview").is(":visible")) preview.renderMarkdown(self.val());
        }
        function getLineStart(val, pos) {
        	var ls = pos;
        	for (var i=pos - 1; i>=0; i--) {
        		ls = i;
        		if (val.substr(i,1)  == "\n" || val.substr(i,1) =="\r") {
        			ls = i+1;
        			break;
        		}
        	}
        	return ls;
        }
        function getLineEnd(val, pos) {
        	var le = pos;
        	for (var i=pos,length=val.length; i<length;i++) {
        		if (val.substr(i,1) == "\n" || val.substr(i,1) == "\r") {
        			le = i;
        			break;
        		}
        	}
        	return le;
        }
        function wrapText(val, wrapper, start,end) {
        	var wl = wrapper.length;
        	var we = wrapper.replace(/(.)/g,"\\$1");
        	var rewrapper = new RegExp("^"+we+"(.*?)"+we+"$");
        	if (val.substr(start,end-start).match(rewrapper)) {
				val = val.substr(0,start) + val.substr(start,end-start).replace(rewrapper, "$1") + val.substr(end);
				end-=wl*2;
			} else if (val.substr(start-wl,wl) == wrapper && val.substr(end,wl) == wrapper) {
				val = val.substr(0, start - wl ) + val.substr(start,end-start) + val.substr(end+wl);
				end-=wl;
			} else { 
				val = val.substr(0, start) + wrapper + val.substr(start,end-start) + wrapper + val.substr(end);
				end+=wl;
			}
        	return { val: val, end: end };
        }
        function prependText(val, prep, start, end, preserve) {
        	var pe = prep.replace(/([*])/g, "\\$1");
        	var reprep = new RegExp("^"+pe, "mg");
        	if (!preserve  && val.substr(start,end).match(reprep)) {
				val = val.substr(0,start) + val.substr(start, end-start).replace(reprep,"") + val.substr(end); 
			} else {
				val = val.substr(0,start) + val.substr(start, end-start).replace(/^/mg, prep) + val.substr(end);
			}
        	return val;
        }
        function appendText(val, app, start, end, preserve) {
        	var ae = app.replace(/([*])/g, "\\$1");
        	var reapp = new RegExp(ae+"$","mg");
        	if (!preserve && val.substr(start,end).match(reapp)) {
        		val = val.substr(0,start) + val.substr(start, end-start).replace(reapp,"") + val.substr(end);
        	} else {
        		val = val.substr(0,start) + val.substr(start, end-start).replace(/$/mg, app) + val.substr(end);
        	}
        	return val;
        }
        function insertText(val, text, start, end) {
        	val = val.substr(0,start) + text + val.substr(end);
        	return val;
        }
        function setPreviewSize() {
        	//preview.width(self.width());
        	//preview.height(self.height());
            $(".markdown-preview").css("maxWidth", ($(window).width()*0.94) +"px");
        }
        function removePreviewSize() {
        	preview.removeAttr("style");
        }
        function userPrompt(text,defaultval,required) {
        	var ret;
        	do {
        		ret = window.prompt(text,defaultval || "");
        	} while (ret != null && required && ret.trim()=="");
        	return ret;
        }
        function handleToolbarActions(ev) {
        	if (ev.type == "keyup" && ev.keyCode!=32  && ev.keyCode!=13 ) return;
        	if ($(this).hasClass("disabled")) return;
			var action = $(this).data("action");
			
			var start = self.prop("selectionStart");
			var end = self.prop("selectionEnd");
			var val = self.val();
			var linestart = getLineStart(val,start);
			var lineend = getLineEnd(val,end);
			if (action == "split") {
				self.parent().toggleClass("split");
				preview.toggleClass("display");
				$(".markdown-toolbar-preview",toolbar).toggleClass("disabled");
				setPreviewSize();
                renderPreview();
			} else if (action == "fullscreen") {
				setPreviewSize();
				self.parent().parent().toggleClass("fullscreen");
			} else if (action == "preview")  {
				setPreviewSize();
				self.toggle();
				preview.toggleClass("display");
				$(".markdown-toolbar-split",toolbar).toggleClass("disabled");
                renderPreview();
			} else if (action  == "heading") {
				val = prependText(val, val.substr(linestart,lineend-linestart).match(/^#/) ? "#" : "# ", linestart,lineend, true);
			} else if (action == "bold") {
				var r = wrapText(val, "**", start, end);
				val = r.val;
				end = r.end;
			} else if (action == "italic") {
				var r = wrapText(val, "*", start, end);
				val = r.val;
				end = r.end;
			} else if (action == "strikethrough") {
				var r = wrapText(val, "~~", start, end);
				val = r.val;
				end = r.end;
			} else if (action == "code") {
				var r = wrapText(val, '`', start, end);
				val = r.val;
				end = r.end;
			} else if (action == "br") {
				val = appendText(val, "  ", linestart, lineend);
			} else if (action == "p") {
				val = appendText(val, "\n", linestart, lineend);
			} else if (action == "ul") {
				val = prependText(val, "* ",linestart,lineend);
				end = start;
			} else if (action == "ol") {
				if (val.substr(linestart,lineend).match(/^\d+[.] /mg)) {
					val = val.substr(0,linestart) + val.substr(linestart, lineend-linestart).replace(/^\d+[.] /mg,"") + val.substr(lineend);
				} else {
					var bl= 1;
					val = val.substr(0,linestart) + val.substr(linestart, lineend-linestart).replace(/^/mg,function() { return (bl++)+". "; }) + val.substr(lineend);
				}
				end = start;
			} else if (action == "quote") {
				val = prependText(val, "> ",linestart,lineend);
			} else if (action == "codeblock") { 
				val = prependText(val, "    ",linestart,lineend);
			} else if (action == "hr") {
				val = appendText(val, "\n---\n",linestart, lineend);
			} else if (action == "link") {
				var link;
				var linktext = userPrompt(options.locale["linktext"] || "link text", val.substr(start,end-start), true);
				if (!linktext) return;
				var url = userPrompt(options.locale["url"] || "url", null, true);
				if (!url) return;
				var title = userPrompt(options.locale["title"] ||  "title", linktext, false);
				if (title === null) return;
				link = "[" + linktext + "]("+url+(title && title.trim()!=""? ' "'+title+'"' : "")+")"; 
				val = insertText(val, link, start, end);
				end = start + link.length;
			} else if (action == "image") {
				var image;
				var alttext = userPrompt(options.locale["alttext"] || "alt text", val.substr(start,end-start), true);
				if (!alttext) return;
				var src = userPrompt(options.locale["imagesrc"] || "image source", null, true);
				if (!src) return;
				var title = userPrompt(options.locale["title"] || "title", alttext, false);
				if (title === null ) return;
				image = "!["+alttext+"]("+src+(title && title.trim() !="" ? ' "'+title+'"' : "" )+")";
				val = insertText(val, image, start, end);
				end = start + image.length;
			}
			setPreviewSize();
			if (self.val() != val) self.val(val).trigger("change");
			self.focus()[0].setSelectionRange(end,end);
			
        }
        function renderToolbar() {
        	if (!options.toolbar) options.toolbar = [ "bold","italic", "strikethrough", "sep", "hr", "br", "p", "sep", "heading","ul","ol", "sep", "code", "codeblock", "quote", "sep", "link", "image", "sepflex", "preview", "split", "fullscreen" ];
        	for (var i=0,length=options.toolbar.length; i<length; i++) {
        		var bd = options.toolbar[i];
        		var b = $("<div/>")
        			.addClass('markdown-toolbar-'+bd);
        		if (bd != "sep" && bd != "sepflex") {
        			b.addClass('markdown-toolbar-button')
        			 .data("action", bd)
        			 .attr("title", options.locale && options.locale[bd] ? options.locale[bd] : bd)
        			 .attr("tabindex", 0)
        			 .on("mousedown keydown", function(ev) {
        				if (ev.type == "keydown" && ev.keyCode!=32 && ev.keyCode!=13 ) return;
        				$(this).addClass("clicked");
        			}).on("mouseup mouseout mouseleave keyup", function() {
        				$(this).removeClass("clicked");
        			}).on("click keyup", handleToolbarActions);
        		}
        		toolbar.append(b);
        	}
        }
        self.addClass("markdown-textarea")
            .wrap(editor)
            .on("input change", renderPreview)
            .parent()
                .prepend(toolbar)
        ;
        self.wrap("<div/>").parent().addClass("markdown-editorpane")
                .append(preview);

        renderPreview();
        renderToolbar();
        return this;
    };
    $.fn.renderMarkdown = function(val) {
    	if (!val) val = $(this).text();
        Array.prototype.last = function () { return this[this.length - 1]; };
        function encodeHTML(txt) {
            return $("<div/>").text(txt).html();
        }
    	// replace escaped characters with &#..;
    	var blocks = [];
		val = val
				.replace(/\\[\\`*_{}\[\]()#+\-.!]/g, function(t) { return "&#"+t.charCodeAt(1)+";";  })
                .replace(/^( {4}|\t).*$/mg, function(t) {// code block: 4 spaces ... 
                        if (t.match(/^\s*([*\-]|\d[.]) /)) { return t;} // fixes (un)ordered list bug
                        blocks.push("<div class='markdown-codeblock'>"+encodeHTML(t.replace(/^( {4}|\t)/,""))+"</div>");
                        return 'BlX('+blocks.length+')BlX';
                 }) 
                .replace(/(((^|\r?\n)>\s.*)+)/mg, function(t) { // quotes: > ...
                    var txt = t.replace(/^>\s/mg,"");
                    var div = $("<div/>").renderMarkdown(txt);
                    blocks.push("<div class='markdown-quote'>"+div.html()+"</div>");
                    return 'BlX('+blocks.length+')BlX';
                })
        		.replace(/```(.|[\r\n])*?```/g, function(t) { var txt = t.replace(/```((.|[\r\n])*)```/,"$1"); blocks.push("<pre class='markdown-code'><code>"+encodeHTML(txt)+"</code></pre>"); return 'BlX('+blocks.length+')BlX';}) 				// code: ``` ... ```
        		.replace(/``(.|[\r\n])*?``/g, function(t) { var txt = t.replace(/``((.|[\r\n])*)``/,"$1"); blocks.push("<pre class='markdown-code'><code>"+encodeHTML(txt)+"</code></pre>"); return 'BlX('+blocks.length+')BlX'	})				// code: `` ... ``
                .replace(/`([^`]+)`/mg, function(t) {var txt = t.replace(/`((.|[\r\n])*)`/,"$1"); blocks.push("<code class='markdown-code'>"+encodeHTML(txt)+"</code>"); return 'BlX('+blocks.length+')BlX';} )	    // code: ` ... `
        ;
        var lines = val.split(/\r?\n/);
        var text = ""
        var listtypes = [];
        var listlevels = [];
        var m;
        for (var i=0, length = lines.length; i< length; i++) {
            var line = lines[i];
            // look forward:
            if (i<length-1) {
                if (lines[i+1].match(/^={2,}$/m) && lines[i].length == lines[i+1].length) {
                    line = "# "+line;       
                    lines[i+1] = "";
                }
                if (lines[i+1].match(/^-{2,}$/m) && lines[i].length == lines[i+1].length) {
                    line = "## "+line;
                    lines[i+1] = "";
                }
            }
            if ( (m = line.match(/^(\s*)([*+\-]|\d+[.]) /)) ) { // a (sub) list
                var listlevel = m[1].replace(/\t/g, '    ').length;
                var listtype = m[2].match(/\d+/) ? 'ol' : 'ul';
                if (listtypes.length == 0 || listlevel > listlevels.last()) {  // looks like a new list
                        listtypes.push(listtype); 
                        listlevels.push(listlevel);
                        text+='<'+listtype+' class="markdown-'+listtype+'">\n';
                } else if (listlevel < listlevels.last()) { // close all sub levels
                    while ( listtypes.length > 0 && listlevels.last() > listlevel) { 
                        text+='</li></'+listtypes.pop()+'>'; 
                        listlevels.pop();
                    }
                }
                if (listtype != listtypes.last()) { // type change? -> close and open new type
                    text+='</li></'+listtypes.pop()+'>';  
                    listtypes.push(listtype);
                    text+='<'+listtype+' class="markdown-'+listtype+'">\n';
                }
                line = line.replace(/^\s*([*+\-]|\d+[.]) (.*)$/mg, "<li>$2");
            } else if (line.match(/^\s*$/m)) { // list ends with an empty line:
                while ( listtypes.length > 0 ) { // close all (sub)lists
                    text += "</li></"+listtypes.pop()+">\n";
                    listlevels.pop();
                }
            }
            text += line+"\n";
        }
        var imgids = {};
        var linkids = {};

        text = text 
                    .replace(/&lt;(https?:\/\/[^ >]+)>/mg, '<a class="markdown-link" href="$1" target="_blank">$1</a>' )	// links: <http://...>
                    .replace(/&lt;([^ @>]+@[^ >]+)>/mg,'<a class="markdown-link" href="mailto:$1">$1</a>') //e-mail links: <email@example.org>
                    .replace(/(\W)[*]{3}([^*\r\n]+)[*]{3}/mg, "$1<span class='markdown-bold markdown-italic'>$2</span>")	// bold and italic: *** ... ***
                    .replace(/(\W)[*]{2}([^*\r\n]+)[*]{2}/mg, "$1<span class='markdown-bold'>$2</span>")					// bold: ** ... **
                    .replace(/(\W)[*]([^*\r\n]+)[*]/mg, "$1<span class='markdown-italic'>$2</span>")						// italic: * ... *
                    .replace(/(\W)_{3}([^_\r\n]+)_{3}/mg, "$1<span class='markdown-bold markdown-italic'>$2</span>")		// bold and italic: ___ ... ___
                    .replace(/(\W)_{2}([^_\r\n]+)_{2}/mg, "$1<span class='markdown-bold'>$2</span>")						// bold: __ ... ___
                    .replace(/(\W)_([^_\r\n]+)_/mg, "$1<span class='markdown-italic'>$2</span>")							// italic: _ ..: _
                    .replace(/(\W)~~([^~]+)~~/mg, "$1<span class='markdown-strikethrough'>$2</span>")					// strike through: ~~ ... ~~
                    .replace(/^\s*!\[[^\]]+\]:\s+\S+(\s+"[^"]+")?/mg, function(t) { 	// image link definition: ![id]: url "title"
                    		var a = t.trim().split(/\s+/);
                    		var id = a.shift().replace(/(!\[|\]:)/g,"");
                    		var url = a.shift();
                    		var title = a.length>0 ? a.join(" ").replace(/"/g,"") : "";
                    		imgids[id] = { url: url, title: title };
                    		blocks.push("<div><a class='markdown-link' href='"+url+"' title='"+title+"' target='_blank'>"+t+"</a></div>");
                            return 'BlX('+blocks.length+')BlX';
                    	} )
                    .replace(/^\s*\[[^\]]+\]:\s+\S+(\s+"[^"]*")?/mg, function(t) { 		// link definition: [id]: url "title"
                    		var a = t.trim().split(/\s+/);
                    		var id = a.shift().replace(/(\[|\]:)/g,"");
                    		var url = a.shift();
                    		var title = a.length>0 ? a.join(" ").replace(/"/g,"") : "";
                    		linkids[id] = { url: url, title: title };
                    		blocks.push("<div><a class='markdown-link' href='"+url+"' title='"+title+"' target='_blank'>"+t+"</a></div>");
                            return 'BlX('+blocks.length+')BlX';
                    })
                    .replace(/!\[([^\]]*)\][(]([^\)]*) "([^"]*)"[)]/mg, "<img class='markdown-image' src='$2' title='$3' alt='$1'>")	// image link  with title: ![alt text](url "title")
                    .replace(/!\[[\]]*\][(]([^\)]*)[)]/mg, "<img class='markdown-image' src='$2' title='$1' alt='$1'>")			// image link without title: ![alt text](url)
                    .replace(/!\[[^\]]+\]\[[^\]]*\]/mg, function(t) {	// implicite image link: ![Alt Text][id] 
                    		var m = t.match(/!\[([^\]]+)\]\[([^\]]*)\]/);
                    		var text = m[1];
                    		var id = m[2] || text;
                    		if (!imgids[id]) return t;
                    		blocks.push('<img class="markdown-image" alt="'+text+'" src="'+imgids[id].url+'" title="'+imgids[id].title+'" >');
                            return 'BlX('+blocks.length+')BlX';
                    })
                    .replace(/\[([^\]]*)\][(]([^\)]*) "([^"]*)"[)]/mg, "<a class='markdown-link' href='$2' title='$3' target='_blank'>$1</a>")			// link with title: [link text](url "title")
                    .replace(/\[([^\]]*)\][(]([^\)]*)[)]/mg, "<a class='markdown-link' href='$2' target='_blank'>$1</a>")								// link without title: [link text](url)
                    .replace(/\[[^\]]+\]\[[^\]]*\]/mg, function(t) {	// implicite link: [Link text][id]
                    		var m = t.match(/\[([^\]]+)\]\[([^\]]*)\]/);
                    		var text = m[1];
                    		var id = m[2] || text;
                    		if (!linkids[id]) return t;
                    		blocks.push('<a  class="markdown-link" href="'+linkids[id].url+'" title="'+linkids[id].title+'" target="_blank">'+text+"</a>");
                            return 'BlX('+blocks.length+')BlX';
                    })
                   .replace(/^######([^#\r\n]*)#* *$/mg, "<h6>$1</h6>")		// headlines: ######
                   .replace(/^#####([^#\r\n]*)#* *$/mg, "<h5>$1</h5>")		// headlines: #####
                   .replace(/^####([^#\r\n]*)#* *$/mg, "<h4>$1</h4>")		// headlines: ####
                   .replace(/^###([^#\r\n]*)#* *$/mg, "<h3>$1</h3>") 		// headlines: ###
                   .replace(/^##([^#\r\n]*)#* *$/mg, "<h2>$1</h2>")			// headlines: ##
                   .replace(/^#([^#\r\n]*)#* *$/mg, "<h1>$1</h1>")			// headlines: # 
                   .replace(/^\s*[\-*]{3,}\s*$/mg, "<hr>")				// horizontal rules: --- or ***
                   .replace(/^\s*([\-*] ){3,}\s*$/mg, "<hr>")				// horizontal rules: - - - or * * *
                   .replace(/^\s*$/mg, "<div class='markdown-paragraph'></div>")	// empty lines -> paragraphs
                   .replace(/(\S)\s{2,}$/mg, "$1<br>")				// lines breaks: two or more spaces at end of line
                   .replace(/BlX\(\d+\)BlX/mg,function(t) { var m = t.match(/BlX\((\d+)\)BlX/); return blocks[m[1]-1]; })
        ; 
        $(this).html(text);
        return this;
    }
}( jQuery ));
