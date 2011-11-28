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
#include <stdlib.h>
#include <stdio.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <string.h>
#include <time.h>

// lifetime of a ticket in seconds:
#define TICKET_LIFETIME   28800

int main(int argc, char *argv[])
{
	struct passwd *pw = NULL;

	char *remote_user = getenv("WEBDAV_USER");
	if (remote_user == NULL) remote_user = getenv("REDIRECT_WEBDAV_USER");
	if (remote_user == NULL) remote_user = getenv("REMOTE_USER");
	if (remote_user == NULL) remote_user = getenv("REDIRECT_REMOTE_USER");

	char dstfilename[1000];
	snprintf(dstfilename,1000,"/tmp/krb5cc_webdavcgi_%s", remote_user);

	/* get ticke file name from environment:*/
	char *krbticket = getenv("KRB5CCNAME");

	/* put copy into the environment: */
	char krbenv[1000];
	snprintf(krbenv,1000,"KRB5CCNAME=FILE:%s",dstfilename);
	putenv(krbenv);

	/* copy ticket file: */
	if (krbticket != NULL) {
		/* remove 'FILE:': */
		strtok(krbticket, ":");
		char *srcfilename = strtok(NULL, ":");

		struct stat dststat;
		time_t seconds = (long)time(NULL);

		if ( (stat(dstfilename, &dststat)==-1)  || (seconds - (time_t)&dststat.st_mtime > TICKET_LIFETIME) ) {
			int src,dst;
			if ((src = open(srcfilename, O_RDONLY)) !=-1 && (dst = creat(dstfilename, 0600 )) != -1 ) {
				char buf[2000];
				ssize_t count;
				while ( (count = read(src, &buf, 2000)) >0) write(dst, buf, count);
				close(src);
				close(dst);
			}
		}
	}
	execv("webdav.pl",argv);
}
