#!/bin/bash
#set -e
JS="jquery.js jquery-ui.js jquery.fileupload.js jquery.fancybox.js jquery.fancybox-thumbs.js jquery.fancybox-buttons.js js.cookie.js multidraggable.js jquery.noty.js jquery.noty.layout.topCenter.js jquery.noty.themes.default.js jquery.hoverIntent.js"

CSS="jquery-ui.css jquery.fancybox.css jquery.fancybox-thumbs.css jquery.fancybox-buttons.css"

concat() {
	src=$1
	dst=$2
	test -f "$src" && cat "$src" >> "$dst"
	test -f "$src.gz" && zcat "$src" >> "$dst"
}

test -f contrib.js && rm contrib.js
for js in $JS ; do
	concat $js contrib.js
done
if [ "$1" = "-d" ] ; then
	gzip -c < contrib.js >contrib.min.js.gz
else
	bash minify.sh contrib.js
	rm contrib.js
fi

test -f contrib.css && rm contrib.css
for css in $CSS ; do
	concat $css contrib.css
done
if [ "$1" = "-d" ] ; then
	gzip -c < contrib.css >contrib.min.css.gz
else 
	bash minify.sh contrib.css
	rm contrib.css
fi
