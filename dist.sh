#!/bin/bash
FILES="webdav.pl webdav-ui.css  webdav-ui.js  webdav-ui_de.msg  webdav-ui_default.msg  webdav-ui_fr.msg webdavwrapper-krb.c  webdavwrapper.c logout CHANGELOG LICENSE TODO doc"
RELEASE=`cat RELEASE`
TMPPATH=/tmp/webdav-${RELEASE}

test -e ${TMPPATH} && rm -rf ${TMPPATH}

svn export https://webdavcgi.svn.sourceforge.net/svnroot/webdavcgi/trunk/ ${TMPPATH}


(cd `dirname ${TMPPATH}`; zip -r  webdav-${RELEASE}.zip `basename ${TMPPATH}`)
(cd `dirname ${TMPPATH}`; tar jcf webdav-${RELEASE}.tar.bz2 `basename ${TMPPATH}`)
