/**************************************************************
* (C) ZE CMS, Humboldt-Universitaet zu Berlin 
* Written 2011,2012 by Daniel Rohde <d.rohde@cms.hu-berlin.de>
***************************************************************/
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
#include <sys/file.h>

// lifetime of a ticket in seconds (depends on your KDC setup):
#define DEFAULT_TICKET_LIFETIME 28800

#define STRBUFSIZE 2000

int main(int argc, char *argv[])
{
	struct passwd *pw = NULL;

	char *remote_user = getenv("WEBDAV_USER");
	if (remote_user == NULL) remote_user = getenv("REDIRECT_WEBDAV_USER");
	if (remote_user == NULL) remote_user = getenv("REMOTE_USER");
	if (remote_user == NULL) remote_user = getenv("REDIRECT_REMOTE_USER");

	char dstfilename[STRBUFSIZE];
	snprintf(dstfilename,STRBUFSIZE,"/tmp/krb5cc_webdavcgi_%s", remote_user);

	char dstmtimefilename[STRBUFSIZE];
	snprintf(dstmtimefilename,STRBUFSIZE,"/tmp/krb5cc_webdavcgi_age_%s", remote_user);

	/* get ticket file name from environment:*/
	char *krbticket = getenv("KRB5CCNAME");

	/* put copy into the environment: */
	char krbenv[STRBUFSIZE];
	snprintf(krbenv,STRBUFSIZE,"FILE:%s",dstfilename);
	setenv("KRB5CCNAME",krbenv,1);

	setenv("WEBDAVISWRAPPED","TRUE",1);

	/* copy ticket file: */
	if (krbticket != NULL) {
		/* remove 'FILE:': */
		strtok(krbticket, ":");
		char *srcfilename = strtok(NULL, ":");

		struct stat dststat;
		time_t seconds = time(NULL);

		char *tlt = getenv("TICKET_LIFETIME");
		long ticket_lifetime = tlt != NULL ? atol(tlt) : DEFAULT_TICKET_LIFETIME;

		/* dstfilename does not exists or the ticket lifetime is exceeded: */
		int exists = stat(dstmtimefilename, &dststat);
		if ( (exists == -1)  || (seconds - dststat.st_mtime > ticket_lifetime) ) {
			if (exists == 0) {
				unlink(dstfilename); 
				unlink(dstmtimefilename);
			}
			int src,dst,dstmtime;
			if ((src = open(srcfilename, O_RDONLY)) !=-1 && (dst = open(dstfilename,O_CREAT|O_WRONLY|O_TRUNC, S_IRUSR|S_IWUSR)) != -1 && flock(dst, LOCK_EX | LOCK_NB) != -1 ) {
				char buf[STRBUFSIZE];
				ssize_t count;
				while ( (count = read(src, &buf, STRBUFSIZE)) >0) write(dst, buf, count);
				close(src);
				if ( (dstmtime=open(dstmtimefilename,O_CREAT|O_WRONLY|O_TRUNC, S_IRUSR|S_IWUSR))!=-1) {
					write(dstmtime, "age checking", 12);
					close(dstmtime);
				}
				flock(dst, LOCK_UN);
				close(dst);
			} else {
				fprintf(stderr, "%s: ERROR: Cannot copy %s to %s: %s\n", argv[0], srcfilename, dstfilename, strerror(errno));
			}
		}
	}
	if (execv("webdav.pl",argv) == -1) fprintf(stderr, "%s: ERROR: Cannot execute webdav.pl: %s\n", argv[0], strerror(errno));
}
