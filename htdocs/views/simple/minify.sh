#!/bin/bash 

java -jar /etc/webdavcgi/minify/yuicompressor.jar style.css  | gzip -c > style.min.css.gz
java -jar /etc/webdavcgi/minify/yuicompressor.jar script.js  | gzip -c > script.min.js.gz

