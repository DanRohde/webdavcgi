/*********************************************************
* (C) ZE CMS, Humboldt-Universitaet zu Berlin 
* Written 2010/2011 
*             by Daniel Rohde <d.rohde@cms.hu-berlin.de>
*            and Daniel Stoye <stoyedan@cms.hu-berlin.de>
**********************************************************/
/*** CHANGES:
  2011-31-03:
      - fixed minor direct call bug reported by Tony H. Wijnhard <Tony.Wijnhard@mymojo.nl>
  2010-22-11:
      - fixed effective groups bug reported by Hanz Makmur <makmur@cs.rugers.edu>
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

#include <stdlib.h>
#include <stdio.h>
#include <sys/types.h>
#include <unistd.h>
#include <string.h>
#include <pwd.h>
#include <grp.h>

#define STRBUFSIZE 2000

int main(int argc, char *argv[])
{
	struct passwd *pw = NULL;

	char *remote_user = getenv("WEBDAV_USER");
	if (remote_user == NULL) remote_user = getenv("REDIRECT_WEBDAV_USER");
	if (remote_user == NULL) remote_user = getenv("REMOTE_USER");
	if (remote_user == NULL) remote_user = getenv("REDIRECT_REMOTE_USER");

	char *user = NULL;
	if (remote_user != NULL) {
		char buf[STRBUFSIZE] ;
		snprintf(buf, STRBUFSIZE, "%s", remote_user); // strtok changes strings!
		user = strtok(buf, "@");
		pw = getpwnam(user);
	}

	if ((pw != NULL)  && ( pw->pw_uid != 0)) {
		if (initgroups(pw->pw_name,pw->pw_gid)==0 && setgid(pw->pw_gid)==0 && setuid(pw->pw_uid)==0) execv("webdav.pl",argv);
		else printf("Status: 500 Internal Sever Error");
	} else {
		printf("Status: 404 Not Found\r\n");
		printf("Content-Type: text/plain\r\n\r\n");
		printf("404 Not Found - your wrapper\n");
		printf("remote_user: %s\n",remote_user);
	}
}
