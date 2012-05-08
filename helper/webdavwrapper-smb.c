/*********************************************************
* (C) ZE CMS, Humboldt-Universitaet zu Berlin 
* Written 2011 by Daniel Rohde <d.rohde@cms.hu-berlin.de>
**********************************************************/
/*
This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/
#include <errno.h>
#include <stdlib.h>
#include <stdio.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <string.h>
#include <time.h>

// lifetime of a ticket in seconds (depends on your KDC setup):
#define TICKET_LIFETIME 28800

int main(int argc, char *argv[])
{
	struct passwd *pw = NULL;

	char *remote_user = getenv("WEBDAV_USER");
	if (remote_user == NULL) remote_user = getenv("REDIRECT_WEBDAV_USER");
	if (remote_user == NULL) remote_user = getenv("REMOTE_USER");
	if (remote_user == NULL) remote_user = getenv("REDIRECT_REMOTE_USER");

	char dstfilename[1000];
	snprintf(dstfilename,1000,"/tmp/krb5cc_webdavcgi_%s", remote_user);

	/* get ticket file name from environment:*/
	char *krbticket = getenv("KRB5CCNAME");

	/* prevent copying KRB5CCNAME file in the SMB backend */
	putenv("KRB5CCNAME=");

	/* copy ticket file: */
	if (krbticket != NULL) {
		/* remove 'FILE:': */
		strtok(krbticket, ":");
		char *srcfilename = strtok(NULL, ":");

		struct stat dststat;
		time_t seconds = time(NULL);

		/* dstfilename does not exists or the ticket lifetime is exceeded: */
		if ( (stat(dstfilename, &dststat)==-1)  || (seconds - dststat.st_mtime > TICKET_LIFETIME) ) {
			int src,dst;
			if ((src = open(srcfilename, O_RDONLY)) !=-1 && (dst = creat(dstfilename, 0600 )) != -1 ) {
				char buf[2000];
				ssize_t count;
				while ( (count = read(src, &buf, 2000)) >0) write(dst, buf, count);
				close(src);
				close(dst);
			} else {
				fprintf(stderr, "%s: ERROR: Cannot copy %s to %s: %s\n", argv[0], srcfilename, dstfilename, strerror(errno));
			}
		}
	}
	if (execv("webdav.pl",argv) == -1) fprintf(stderr, "%s: ERROR: Cannot execute webdav.pl: %s\n", argv[0], strerror(errno));
}
