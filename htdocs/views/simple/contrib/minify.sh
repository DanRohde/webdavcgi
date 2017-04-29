#!/bin/bash 

while (( "$#" )) ; do
	echo $1
    mfn=${1%.*}.min.${1##*.}
#    java -jar /etc/webdavcgi/minify/yuicompressor-2.4.8.jar $1  > $mfn
    yuglify $1
    brotli < $mfn > ${mfn}.br
    gzip -f $mfn
    shift
done

