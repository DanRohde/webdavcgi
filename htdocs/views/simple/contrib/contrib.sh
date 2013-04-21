#!/bin/bash
set -e
JS="jquery.min.js jquery-ui.custom.min.js jquery.fileupload.js jquery.fancybox.pack.js jquery.fancybox-thumbs.min.js jquery.cookie.min.js multidraggable.min.js jquery.noty.min.js jquery.noty.layout.topCenter.min.js jquery.noty.themes.default.min.js"
#jquery.fileupload-fp.js
#jquery.fileupload-ui.js
#jquery.powertip.min.js

CSS="jquery-ui.custom.min.css jquery.fancybox.min.css jquery.fancybox-thumbs.min.css"
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
bash minify.sh contrib.js
rm contrib.js

test -f contrib.css && rm contrib.css
for css in $CSS ; do
	concat $css contrib.css
done
bash minify.sh contrib.css
rm contrib.css
