/*
#########################################################################
# (C) ZE CMS, Humboldt-Universitaet zu Berlin
# Written 2014 by Daniel Rohde <d.rohde@cms.hu-berlin.de>
#########################################################################
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#########################################################################
*/
%module smbclient
%{
        #include "libsmbclient.h"
%}

/* prevent type casts */
typedef int mode_t;
typedef int off_t;

/* from libsmbclient.h without unused or deprecated API: */
/* #include "libsmbclieht.h" is too much */

#define SMB_CTX_FLAG_USE_KERBEROS (1 << 0)
#define SMB_CTX_FLAG_FALLBACK_AFTER_KERBEROS (1 << 1)
#define SMBCCTX_FLAG_NO_AUTO_ANONYMOUS_LOGON (1 << 2)
#define SMB_CTX_FLAG_USE_CCACHE (1 << 3)

#define SMBC_WORKGROUP      1
#define SMBC_SERVER         2
#define SMBC_FILE_SHARE     3
#define SMBC_PRINTER_SHARE  4
#define SMBC_COMMS_SHARE    5
#define SMBC_IPC_SHARE      6
#define SMBC_DIR            7
#define SMBC_FILE           8
#define SMBC_LINK           9

typedef int smbc_bool;

/* use smbclientc::smbc_dirent_<smbc_dirent member>_get to read members */
struct smbc_dirent 
{
        unsigned int smbc_type; 
        unsigned int dirlen;
        unsigned int commentlen;
        char *comment;
        unsigned int namelen;
        char name[1];  /* use smbclient::w_smbc_dirent_name_get(struct smbc_dirent) to read the complete name */
};

typedef void (*smbc_get_auth_data_with_context_fn)(SMBCCTX *c,const char *srv,const char *shr,char *wg, int wglen,char *un, int unlen,char *pw, int pwlen);

SMBCCTX * smbc_new_context(void);
int smbc_free_context(SMBCCTX * context, int shutdown_ctx);

int smbc_getDebug(SMBCCTX *c);
void smbc_setDebug(SMBCCTX *c, int debug);

int smbc_getTimeout(SMBCCTX *c);
void smbc_setTimeout(SMBCCTX *c, int timeout);

smbc_bool smbc_getOptionDebugToStderr(SMBCCTX *c);
void smbc_setOptionDebugToStderr(SMBCCTX *c, smbc_bool b);

void * smbc_getOptionUserData(SMBCCTX *c);
void smbc_setOptionUserData(SMBCCTX *c, void *user_data);

smbc_bool smbc_getOptionUseKerberos(SMBCCTX *c);
void smbc_setOptionUseKerberos(SMBCCTX *c, smbc_bool b);

smbc_bool smbc_getOptionFallbackAfterKerberos(SMBCCTX *c);
void smbc_setOptionFallbackAfterKerberos(SMBCCTX *c, smbc_bool b);

smbc_bool smbc_getOptionNoAutoAnonymousLogin(SMBCCTX *c);
void smbc_setOptionNoAutoAnonymousLogin(SMBCCTX *c, smbc_bool b);

smbc_bool smbc_getOptionUseCCache(SMBCCTX *c);
void smbc_setOptionUseCCache(SMBCCTX *c, smbc_bool b);

smbc_get_auth_data_with_context_fn smbc_getFunctionAuthDataWithContext(SMBCCTX *c);
void smbc_setFunctionAuthDataWithContext(SMBCCTX *c, smbc_get_auth_data_with_context_fn fn);

SMBCCTX * smbc_init_context(SMBCCTX * context);
SMBCCTX * smbc_set_context(SMBCCTX * new_context);

int smbc_open(const char *furl, int flags, mode_t mode);
off_t smbc_lseek(int fd, off_t offset, int whence);
int smbc_close(int fd);
int smbc_unlink(const char *furl);
int smbc_rename(const char *ourl, const char *nurl);

int smbc_opendir(const char *durl);
int smbc_closedir(int dh);
struct smbc_dirent* smbc_readdir(unsigned int dh);
int smbc_mkdir(const char *durl, mode_t mode);
int smbc_rmdir(const char *durl);

int smbc_stat(const char *url, struct stat *st);
int smbc_fstat(int fd, struct stat *st);

/* additional wrapper interface definitions */

%inline %{

char * w_stat2str(struct stat * buf) {
        if (buf == NULL) return NULL;
        char *s = (char *) malloc(1025);
        snprintf(s, 1024, "%li,%li,%li,%li,%li,%li,%li,%li,%li,%li,%li,%li,%li", buf->st_dev, buf->st_ino, (long int) buf->st_mode, buf->st_nlink, (long int)buf->st_uid, (long int) buf->st_gid,buf->st_rdev,buf->st_size, buf->st_blksize,buf->st_blocks, buf->st_atime,buf->st_mtime,buf->st_ctime);
        return s;
}
char * w_ssize2str(ssize_t val) {
        char *s = (char *) malloc(1025);
        snprintf(s, 1024, "%lu", val);
        return s;
}

#define W_USERDATA_BUFLEN 256
struct w_userdata {
        char * username;
        char * password;
        char * workgroup;
};
void w_debug(SMBCCTX *ctx, char *str) {
        if (smbc_getDebug(ctx)>0) fprintf(stderr, "%s\n", str);
}
smbc_get_auth_data_with_context_fn w_get_auth_data_with_context(SMBCCTX *ctx, const char *srv, const char *shr, char *wg, int wglen, char *un, int unlen, char *pw, int pwlen) {
        w_debug(ctx, "w_get_auth_data_with_context...");
        struct w_userdata *d = (struct w_userdata *) smbc_getOptionUserData(ctx);
        strncpy(un,d->username, unlen - 1);
        strncpy(wg,d->workgroup, wglen - 1);
        if (!smbc_getOptionUseKerberos(ctx)) strncpy(pw,d->password, pwlen - 1);
        w_debug(ctx, "w_get_auth_data_with_context done.");
}
int w_initAuth(SMBCCTX *ctx, char *un, char *pw, char *wg) {
        w_debug(ctx,"w_initAuth ..."); 
        struct w_userdata *d = (struct w_userdata *)malloc(sizeof(struct w_userdata)+1);
        d->username = (char * ) malloc(W_USERDATA_BUFLEN);
        d->password = (char * ) malloc(W_USERDATA_BUFLEN);
        d->workgroup = (char *) malloc(W_USERDATA_BUFLEN);
        strncpy(d->username, un, W_USERDATA_BUFLEN - 1);
        strncpy(d->password, pw, W_USERDATA_BUFLEN - 1);
        strncpy(d->workgroup, wg, W_USERDATA_BUFLEN - 1);
        smbc_setOptionUserData(ctx, d);
        smbc_setFunctionAuthDataWithContext(ctx, (smbc_get_auth_data_with_context_fn)w_get_auth_data_with_context);
        w_debug(ctx,"w_initAuth done");
        return 1;
}
char * w_smbc_dirent_name_get(struct smbc_dirent * e) {
        return e->name;
}
int w_smbc_write(int fd, char *buf, int bufsize) {
        return (int)smbc_write(fd, buf, bufsize);
}
char * w_smbc_read(int fd, int bufsize) {
        char * buf;
        int ret;
        buf = (char *)malloc(sizeof(char)*(bufsize + 1));
        ret = smbc_read(fd, buf, bufsize);
        if (ret>0) {
                buf[ret]='\0';
                return buf;
        }
        return NULL;
}
struct stat * w_create_struct_stat() {
        return (struct stat *) malloc(sizeof(struct stat));
}
void w_free_struct_stat(struct stat *st) {
        free(st);
}

%}
