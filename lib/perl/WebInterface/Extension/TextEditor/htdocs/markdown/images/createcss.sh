#!/bin/bash

test -f buttons.css  && mv buttons.css buttons.css.old
for f in *.svg ; do
    n=${f%%.svg}
    cat - >>buttons.css <<EOF
.markdown-toolbar-$n {
    background-image: url(data:image/svg+xml;utf8,$(uriescape < "$f"));
    background-repeat: no-repeat;
    background-position: center center;
    background-size: 18px 18px;
}
.markdown-toolbar-$n:hover,.markdown-toolbar-$n:focus {
    background-image: url(data:image/svg+xml;utf8,$(sed -e 's/#808080/#000000/g' "$f" | uriescape));
}
EOF

done
