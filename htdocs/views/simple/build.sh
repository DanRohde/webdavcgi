#!/bin/bash
##################################################################
# (C) ZE Computer- Medienservice, Humboldt-Universitaet zu Berlin
# Written by Daniel Rohde <d.rohde@cms.hu-berlin.de>
##################################################################

BP=$(dirname "$0")

cd $BP

lessc --include-path=less less/style.less style.css
bash minify.sh
bash createthemes.sh
