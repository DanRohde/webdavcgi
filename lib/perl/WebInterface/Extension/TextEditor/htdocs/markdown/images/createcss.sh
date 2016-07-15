#!/bin/bash

test -f buttons.css  && mv buttons.css buttons.css.old
for f in *.png ; do
    n=${f%%.png}
    cat - >>buttons.css <<EOF
.markdown-toolbar-$n {
    background-image: url(data:image/png;base64,$(base64 -w0 "$f"));
    background-repeat: no-repeat;
    background-position: center center;
}

EOF

done
