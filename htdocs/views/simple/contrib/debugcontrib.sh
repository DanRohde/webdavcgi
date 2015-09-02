#!/bin/bash
set -e
JS="jquery.js jquery-ui.js jquery.fileupload.js jquery.fancybox.js jquery.fancybox-thumbs.js js.cookie.js multidraggable.js jquery.noty.js jquery.noty.layout.topCenter.js jquery.noty.themes.default.js"
#jquery.fileupload-fp.js
#jquery.fileupload-ui.js
#jquery.powertip.min.js

CSS="jquery-ui.css query.fancybox.css jquery.fancybox-thumbs.css"
#jquery.powertip.min.css

concat() {
	src=$1
	dst=$2
	test -f "$src" && cat "$src" >> "$dst"
	test -f "$src.gz" && zcat "$src" >> "$dst"
}

for js in $JS ; do
	concat $js contrib.js
done
gzip contrib.js

test -f contrib.css && rm contrib.css
for css in $CSS ; do
	concat $css contrib.css
done
gzip contrib.css
