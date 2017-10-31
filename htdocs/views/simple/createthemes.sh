#!/bin/bash
BP=$(dirname $0)
TP=${BP}/themes/
for t in "${BP}"/less/themes/*.less ; do
	BN=$(basename $t .less)
	f="${TP}"/"${BN}".min.css
	lessc - --include-path="${BP}"/less:"${BP}"/less/themes < "${t}" | yuglify --terminal --type css > "${f}"
	brotli < "${f}" > "${f}.br"
	gzip -f "${f}"
done