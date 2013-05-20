#!/bin/bash 

gzip -c < style.css > style.min.css.gz
gzip -c < script.js > script.min.js.gz

