/*********************************************************
* (C) ZE CMS, Humboldt-Universitaet zu Berlin 
* Written 2010 by Daniel Rohde <d.rohde@cms.hu-berlin.de>
**********************************************************/
/*** CHANGES:
  2010-22-11:
    - fixed effective groups bug reported by Hanz Makmur <makmur@cs.rugers.edu>
    - removed file owner checks
  2010-21-09:
    - fixed security bugs (setuid/setgid, sprintf) reported by Thomas Roessler <roessler@does-not-exist.org>
*/
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
#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <sys/types.h>
#include <pwd.h>
#include <grp.h>


int main(int argc, char *argv[])
{
	struct passwd *pw = NULL;
	struct group  *gr = NULL;
	int errcode = 0;

	char *remote_user = getenv("WEBDAV_USER");
	if (remote_user == NULL) remote_user = getenv("REDIRECT_WEBDAV_USER");
	if (remote_user == NULL) remote_user = getenv("REMOTE_USER");
	if (remote_user == NULL) remote_user = getenv("REDIRECT_REMOTE_USER");

	if (remote_user != NULL) pw = getpwnam(remote_user);
	
	char *webdavgroup = getenv("WEBDAV_GROUP");
	if (webdavgroup == NULL) webdavgroup = getenv("REDIRECT_WEBDAV_GROUP");

	if (webdavgroup != NULL) gr = getgrnam(webdavgroup);

	if ((pw != NULL)  && ( pw->pw_uid != 0)) {
		if (initgroups(pw->pw_name,pw->pw_gid)==0)
			if (setgid(gr!=NULL && gr->gr_gid!=0 ? gr->gr_gid : pw->pw_gid)==0)
				if (setuid(pw->pw_uid)==0) execv("webdav.pl",argv);
				else printf("Status: 500 Internal Server Error: setuid failed for %s",pw->pw_name);
			else printf("Status: 500 Internal Server Error: setgid failed for %s",pw->pw_name);
		else printf("Status: 500 Internal Server Error: initgroups failed for %s (errno=%d,%s)",pw->pw_name,errno,strerror(errno));
	} else {
		printf("Status: 404 Not Found\r\n");
		printf("Content-Type: text/plain\r\n\r\n");
		printf("404 Not Found - your wrapper");
	}
}
