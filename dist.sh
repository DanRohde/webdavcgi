#!/bin/bash
RELEASE=`cat RELEASE`
TMPPATH=/tmp/webdav-${RELEASE}

test -e ${TMPPATH} && rm -rf ${TMPPATH}

svn export https://webdavcgi.svn.sourceforge.net/svnroot/webdavcgi/trunk/ ${TMPPATH}


(cd `dirname ${TMPPATH}`; zip -r  webdavcgi-${RELEASE}.zip `basename ${TMPPATH}`)
(cd `dirname ${TMPPATH}`; tar jcf webdavcgi-${RELEASE}.tar.bz2 `basename ${TMPPATH}`)
