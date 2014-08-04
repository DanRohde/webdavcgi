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
	function addErrorToField(field,dialog) {
		showInputFailure(dialog);
		$("input[name="+field+"]",dialog).addClass("error").focus();
	}
	function showInputFailure(dialog) {
		$("#inputfailure",dialog).show(1000);
		window.setTimeout(function() {  $("#inputfailure",dialog).hide(800); }, 5000);
	}
	function checkInputField(field,dialog) {
		if ($("input[name="+field+"]",dialog).val().trim() == "") {
			addErrorToField(field,dialog);
			return false;
		}
		return true;
	}
	function checkInputFields(fields,dialog) {
		var i;
		for (i=0; i<fields.length; i++) {
			if (!checkInputField(fields[i],dialog)) return false;
		}
		return true;
	}
	$("body").on("fileActionEvent", function(event,data) {
		if (data.obj.hasClass("disabled")) return;
		if (!data.obj.hasClass("sendbymail")) return;
		var loc = window.location.pathname;
		$.post(loc, { action: 'sendbymail', ajax: 'preparemail', files: data.selected}, function(response) {
			var dialog = $(response);
			
			$("input[name=download]",dialog).click(function(event) {
				event.preventDefault();
				dialog.dialog("close");
				$('form',dialog).off("submit").append('<input type="hidden" name="download" value="yes"/>').submit();
				return false;
			});
			var tofield = $("input[name=to],textarea[name=to]", dialog).autosize().autocomplete(
						{ minLength: 4, 
							source: function(request,response) {
								var rt = request.term.split(/\s*,\s*/);
								var term = rt.pop();
								$.post(window.location.pathname, {action:'sendbymail', ajax: 'addressbooksearch', query: term}, function(resp) {
									response(resp.result ? resp.result : new Array());
									
								});
							},
							select: function(e,ui) {
								ToolBox.preventDefault(e);
								var entries = tofield.val().split(/\s*,\s*/);
								entries.pop();
								entries.push(ui.item.value);
								tofield.val(entries.join(", "));
								return false;
							}
						}
			);
			$("input",dialog).on("keydown", function(event) {
				$(this).next("input").focus();
				return event.which !==13;
			});
			
			$("input[name=zipfilename]",dialog).prop("disabled", true);
			$("input[name=zip]", dialog).change(function(){
				if ($(".sendbymail.files.dir",dialog).length>0) $(this).prop("checked", true);
				$("input[name=zipfilename]",dialog).prop("disabled", !$(this).is(":checked"));
			});

			if ($(".sendbymail.files.dir",dialog).length>0) $("input[name=zip]",dialog).prop("checked", true).trigger("change");

			
			if ($(".sendbymail.remove", dialog).length==1)	$(".sendbymail.remove",dialog).remove();
			$(".sendbymail.remove", dialog).click(function() {
				$(".sendbymail.sumfilesizes").remove();
				$(this).parent().remove();
				if ($(".sendbymail.remove",dialog).length==1) $(".sendbymail.remove",dialog).remove();
			});
			
			$("form.sendbymail", dialog).submit(function() {
			
				$("input.error",dialog).removeClass("error");
				if (!checkInputFields(new Array("from","to","subject"),dialog)) return false;
				
				$("input[type=submit]",dialog).prop("disabled",true);
				var block = ToolBox.blockPage();
				$.post(loc, $(this).serialize(), function(resp) {
					block.remove();
					var type = "info", msg=resp.msg;
					if (resp.error) { 
						type="error"; msg=resp.error;
						if (resp.field)  addErrorToField(resp.field, dialog);
					}
					noty({text: msg, type: type, layout: 'topCenter', timeout: 30000 });
					if (!resp.error) dialog.dialog("close");
					else $("input[type=submit]",dialog).prop("disabled",false);
				});
				return false;
			});
			
			dialog.dialog({modal: true, width: "auto", height: "auto"});
			
		});
		
	});
});
/*!
Autosize v1.18.9 - 2014-05-27
Automatically adjust textarea height based on user input.
(c) 2014 Jack Moore - http://www.jacklmoore.com/autosize
license: http://www.opensource.org/licenses/mit-license.php
*/
(function(e){var t,o={className:"autosizejs",id:"autosizejs",append:"\n",callback:!1,resizeDelay:10,placeholder:!0},i='<textarea tabindex="-1" style="position:absolute; top:-999px; left:0; right:auto; bottom:auto; border:0; padding: 0; -moz-box-sizing:content-box; -webkit-box-sizing:content-box; box-sizing:content-box; word-wrap:break-word; height:0 !important; min-height:0 !important; overflow:hidden; transition:none; -webkit-transition:none; -moz-transition:none;"/>',n=["fontFamily","fontSize","fontWeight","fontStyle","letterSpacing","textTransform","wordSpacing","textIndent"],s=e(i).data("autosize",!0)[0];s.style.lineHeight="99px","99px"===e(s).css("lineHeight")&&n.push("lineHeight"),s.style.lineHeight="",e.fn.autosize=function(i){return this.length?(i=e.extend({},o,i||{}),s.parentNode!==document.body&&e(document.body).append(s),this.each(function(){function o(){var t,o=window.getComputedStyle?window.getComputedStyle(u,null):!1;o?(t=u.getBoundingClientRect().width,(0===t||"number"!=typeof t)&&(t=parseInt(o.width,10)),e.each(["paddingLeft","paddingRight","borderLeftWidth","borderRightWidth"],function(e,i){t-=parseInt(o[i],10)})):t=p.width(),s.style.width=Math.max(t,0)+"px"}function a(){var a={};if(t=u,s.className=i.className,s.id=i.id,d=parseInt(p.css("maxHeight"),10),e.each(n,function(e,t){a[t]=p.css(t)}),e(s).css(a).attr("wrap",p.attr("wrap")),o(),window.chrome){var r=u.style.width;u.style.width="0px",u.offsetWidth,u.style.width=r}}function r(){var e,n;t!==u?a():o(),s.value=!u.value&&i.placeholder?(p.attr("placeholder")||"")+i.append:u.value+i.append,s.style.overflowY=u.style.overflowY,n=parseInt(u.style.height,10),s.scrollTop=0,s.scrollTop=9e4,e=s.scrollTop,d&&e>d?(u.style.overflowY="scroll",e=d):(u.style.overflowY="hidden",c>e&&(e=c)),e+=w,n!==e&&(u.style.height=e+"px",f&&i.callback.call(u,u))}function l(){clearTimeout(h),h=setTimeout(function(){var e=p.width();e!==g&&(g=e,r())},parseInt(i.resizeDelay,10))}var d,c,h,u=this,p=e(u),w=0,f=e.isFunction(i.callback),z={height:u.style.height,overflow:u.style.overflow,overflowY:u.style.overflowY,wordWrap:u.style.wordWrap,resize:u.style.resize},g=p.width(),y=p.css("resize");p.data("autosize")||(p.data("autosize",!0),("border-box"===p.css("box-sizing")||"border-box"===p.css("-moz-box-sizing")||"border-box"===p.css("-webkit-box-sizing"))&&(w=p.outerHeight()-p.height()),c=Math.max(parseInt(p.css("minHeight"),10)-w||0,p.height()),p.css({overflow:"hidden",overflowY:"hidden",wordWrap:"break-word"}),"vertical"===y?p.css("resize","none"):"both"===y&&p.css("resize","horizontal"),"onpropertychange"in u?"oninput"in u?p.on("input.autosize keyup.autosize",r):p.on("propertychange.autosize",function(){"value"===event.propertyName&&r()}):p.on("input.autosize",r),i.resizeDelay!==!1&&e(window).on("resize.autosize",l),p.on("autosize.resize",r),p.on("autosize.resizeIncludeStyle",function(){t=null,r()}),p.on("autosize.destroy",function(){t=null,clearTimeout(h),e(window).off("resize",l),p.off("autosize").off(".autosize").css(z).removeData("autosize")}),r())})):this}})(window.jQuery||window.$);