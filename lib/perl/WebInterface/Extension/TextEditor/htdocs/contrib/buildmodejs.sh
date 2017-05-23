#!/bin/bash

MODES="css dtd javascript perl php python r shell sql tcl vb vbscript xml yaml"

rm codemirror-modes.js
for m in $MODES ; do
    cat codemirror/mode/${m}/${m}.js >> codemirror-modes.js
done
