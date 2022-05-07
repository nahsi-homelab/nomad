{{- with secret "secret/mariadb/users/maxscale" -}}
CREATE USER '{{ .Data.data.username }}'@'%' IDENTIFIED BY '{{ .Data.data.password }}';
GRANT SELECT ON mysql.user TO '{{ .Data.data.username }}'@'%';
GRANT SELECT ON mysql.db TO '{{ .Data.data.username }}'@'%';
GRANT SELECT ON mysql.tables_priv TO '{{ .Data.data.username }}'@'%';
GRANT SELECT ON mysql.columns_priv TO '{{ .Data.data.username }}'@'%';
GRANT SELECT ON mysql.procs_priv TO '{{ .Data.data.username }}'@'%';
GRANT SELECT ON mysql.proxies_priv TO '{{ .Data.data.username }}'@'%';
GRANT SELECT ON mysql.roles_mapping TO '{{ .Data.data.username }}'@'%';
GRANT SUPER, RELOAD, PROCESS, SHOW DATABASES, EVENT ON *.* TO '{{ .Data.data.username }}'@'%';
GRANT REPLICATION CLIENT, REPLICATION SLAVE, SLAVE MONITOR ON *.* TO '{{ .Data.data.username }}'@'%';
{{- end }}
