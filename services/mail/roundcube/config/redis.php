<?php
  $config['redis_hosts'] = ['keydb.service.consul:6379:1:{{- with secret "secret/keydb/users/default" -}}{{ .Data.data.password }}{{ end -}}'];
  $config['session_storage'] = 'redis';
  $config['imap_cache'] = 'redis';
