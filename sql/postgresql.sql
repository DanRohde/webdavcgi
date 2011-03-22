CREATE TABLE webdav_locks (basefn VARCHAR(255) NOT NULL, fn VARCHAR(255) NOT NULL, 
			   type VARCHAR(255) NOT NULL, scope VARCHAR(255), 
			   token VARCHAR(255) NOT NULL, depth VARCHAR(255) NOT NULL, 
			   timeout VARCHAR(255) NULL, owner TEXT NULL, 
			   timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP);
CREATE TABLE webdav_props (fn VARCHAR(255) NOT NULL, propname VARCHAR(255) NOT NULL, value TEXT);
CREATE INDEX webdav_locks_idx1 ON webdav_locks (fn);
CREATE INDEX webdav_locks_idx2 ON webdav_locks (basefn);
CREATE INDEX webdav_locks_idx3 ON webdav_locks (fn,basefn);
CREATE INDEX webdav_locks_idx4 ON webdav_locks (fn,basefn,token);
CREATE INDEX webdav_props_idx1 ON webdav_props (fn);
CREATE INDEX webdav_props_idx2 ON webdav_props (fn,propname);
