<?php
$config['db'] = array (
  'server' => 'mariadb.service.consul',
  'port' => '3106',
  'database' => 'filerun',
  {{- with secret "mariadb/static-creds/filerun" }}
  'username' => '{{ .Data.username }}',
  'password' => '{{ .Data.password }}',
  {{- end }}
);
$config['url']['detected_root'] = 'https://filerun.nahsi.dev';
