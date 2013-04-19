#!/bin/bash 

java -jar /etc/webdavcgi/minify/yuicompressor-2.4.2.jar style.css  | gzip -c > style.min.css.gz
java -jar /etc/webdavcgi/minify/yuicompressor-2.4.2.jar script.js  | gzip -c > script.min.js.gz

