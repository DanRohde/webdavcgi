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
/* %include "typemaps.i" */
%{
        #include "libsmbclient.h"
%}

/* from libsmbclient.h without unused or deprecated API: */
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
char * smbc_getNetbiosName(SMBCCTX *c);
void smbc_setNetbiosName(SMBCCTX *c, char * netbios_name);
char * smbc_getWorkgroup(SMBCCTX *c);
void smbc_setWorkgroup(SMBCCTX *c, char * workgroup);
char * smbc_getUser(SMBCCTX *c);
void smbc_setUser(SMBCCTX *c, char * user);
int smbc_getTimeout(SMBCCTX *c);
void smbc_setTimeout(SMBCCTX *c, int timeout);

smbc_bool smbc_getOptionDebugToStderr(SMBCCTX *c);
void smbc_setOptionDebugToStderr(SMBCCTX *c, smbc_bool b);
smbc_bool smbc_getOptionFullTimeNames(SMBCCTX *c);
void smbc_setOptionFullTimeNames(SMBCCTX *c, smbc_bool b);
smbc_share_mode smbc_getOptionOpenShareMode(SMBCCTX *c);
void smbc_setOptionOpenShareMode(SMBCCTX *c, smbc_share_mode share_mode);
void * smbc_getOptionUserData(SMBCCTX *c);
void smbc_setOptionUserData(SMBCCTX *c, void *user_data);
smbc_smb_encrypt_level smbc_getOptionSmbEncryptionLevel(SMBCCTX *c);
void smbc_setOptionSmbEncryptionLevel(SMBCCTX *c, smbc_smb_encrypt_level level);
smbc_bool smbc_getOptionCaseSensitive(SMBCCTX *c);
void smbc_setOptionCaseSensitive(SMBCCTX *c, smbc_bool b);
int smbc_getOptionBrowseMaxLmbCount(SMBCCTX *c);
void smbc_setOptionBrowseMaxLmbCount(SMBCCTX *c, int count);
smbc_bool smbc_getOptionUrlEncodeReaddirEntries(SMBCCTX *c);
void smbc_setOptionUrlEncodeReaddirEntries(SMBCCTX *c, smbc_bool b);
void smbc_setOptionOneSharePerServer(SMBCCTX *c, smbc_bool b);
smbc_bool smbc_getOptionUseKerberos(SMBCCTX *c);
void smbc_setOptionUseKerberos(SMBCCTX *c, smbc_bool b);
smbc_bool smbc_getOptionFallbackAfterKerberos(SMBCCTX *c);
smbc_bool smbc_getOptionFallbackAfterKerberos(SMBCCTX *c);
void smbc_setOptionFallbackAfterKerberos(SMBCCTX *c, smbc_bool b);
smbc_bool smbc_getOptionNoAutoAnonymousLogin(SMBCCTX *c);
void smbc_setOptionNoAutoAnonymousLogin(SMBCCTX *c, smbc_bool b);
smbc_bool smbc_getOptionUseCCache(SMBCCTX *c);
void smbc_setOptionUseCCache(SMBCCTX *c, smbc_bool b);

void smbc_setFunctionAuthData(SMBCCTX *c, smbc_get_auth_data_fn fn);
smbc_get_auth_data_with_context_fn smbc_getFunctionAuthDataWithContext(SMBCCTX *c);
void smbc_setFunctionAuthDataWithContext(SMBCCTX *c, smbc_get_auth_data_with_context_fn fn);

SMBCCTX * smbc_init_context(SMBCCTX * context);
SMBCCTX * smbc_set_context(SMBCCTX * new_context);

int smbc_open(const char *furl, int flags, mode_t mode);
int smbc_creat(const char *furl, mode_t mode);
ssize_t smbc_read(int fd, void *OUTPUT, size_t bufsize);
ssize_t smbc_write(int fd, const void *buf, size_t bufsize); /* use w_smbc_write  */
off_t smbc_lseek(int fd, off_t offset, int whence);
int smbc_close(int fd);

int smbc_unlink(const char *furl);
int smbc_rename(const char *ourl, const char *nurl);

int smbc_opendir(const char *durl);
int smbc_closedir(int dh);
int smbc_getdents(unsigned int dh, struct smbc_dirent *OUTPUT, int count);

struct smbc_dirent* smbc_readdir(unsigned int dh);
off_t smbc_telldir(int dh);
int smbc_lseekdir(int fd, off_t offset);

int smbc_mkdir(const char *durl, mode_t mode);
int smbc_rmdir(const char *durl);

int smbc_stat(const char *url, struct stat *st);
int smbc_fstat(int fd, struct stat *st);
int smbc_statvfs(char *url, struct statvfs *OUTPUT);
int smbc_fstatvfs(int fd, struct statvfs *OUTPUT);

int smbc_ftruncate(int fd, off_t size);

int smbc_chmod(const char *url, mode_t mode);
int smbc_utimes(const char *url, struct timeval *tbuf);

int smbc_setxattr(const char *url, const char *name, const void *value, size_t size, int flags);
int smbc_lsetxattr(const char *url, const char *name, const void *value, size_t size, int flags);
int smbc_fsetxattr(int fd, const char *name, const void *value, size_t size, int flags);
int smbc_getxattr(const char *url, const char *name, const void *OUTPUT, size_t size);
int smbc_lgetxattr(const char *url, const char *name, const void *OUTPUT, size_t size);
int smbc_fgetxattr(int fd, const char *name, const void *OUTPUT, size_t size);
int smbc_removexattr(const char *url, const char *name);
int smbc_lremovexattr(const char *url, const char *name);
int smbc_fremovexattr(int fd, const char *name);
int smbc_listxattr(const char *url, char *OUTPUT, size_t size);
int smbc_llistxattr(const char *url, char *OUTPUT, size_t size);
int smbc_flistxattr(int fd, char *OUTPUT, size_t size);

void smbc_set_credentials(const char *workgroup, const char *user, const char *password, smbc_bool use_kerberos, const char *signing_state);
void smbc_set_credentials_with_fallback(SMBCCTX *ctx, const char *workgroup, const char *user, const char *password);



/* additional wrapper interface definitions */

%inline %{

mode_t w_int2mode(int mode) { return (mode_t) mode; }
off_t w_int2offt(int v) {  return (off_t) v; };
int w_offt2int(off_t v) {  return (int) v; };
char * w_offt2str(off_t v) { 
        char *s = (char *) malloc(1025);
        snprintf(s, 1024, "%lu", v);
        return s;
}

char * w_stat2str(struct stat * buf) {
        if (buf == NULL) return NULL;
        char *s = (char *) malloc(1025);
        snprintf(s, 1024, "%lu,%lu,%lu,%lu,%lu,%lu,%lu,%lu,%lu,%lu,%lu,%lu,%lu\0", buf->st_dev, buf->st_ino, buf->st_mode, buf->st_nlink, buf->st_uid, buf->st_gid,buf->st_rdev,buf->st_size,buf->st_atime,buf->st_mtime,buf->st_ctime,buf->st_blksize,buf->st_blocks);
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
        if (!bufsize) bufsize=4096;
        char * buf = (char *)malloc(bufsize + 1);
        ssize_t ret = smbc_read(fd, buf, (ssize_t) bufsize);
        if (ret>0) {
                char * copy = (char *)malloc(ret+1);
                strncpy(copy,buf,ret);
                free(buf);
                return copy;
        }
        return NULL;
}
struct stat * w_create_struct_stat() {
        struct stat * st = (struct stat *) malloc(sizeof(struct stat));
        return st;
}
void w_free_struct_stat(struct stat *st) {
        free(st);
}
void w_debug(SMBCCTX *ctx, char *str) {
        if (smbc_getDebug(ctx)>0) fprintf(stderr, "%s\n", str);
}

%}
