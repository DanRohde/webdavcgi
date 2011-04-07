All data in this directory can be accessed with a URI like '/_webdavcgi_/README.txt'
('_webdavcgi_/' is the default and can be changed with the parameter $VHTDOCS).
Subfolders are allowed and all files and folders should be readable (folders readable+executable) 
by your WebDAV users.

You can use this folder for own icons, online documentation, and so on.

Another way to deliver files on a WebDAV CGI controlled site is a Apache rewrite rule preceding the
webdav.pl rewrite rule.
