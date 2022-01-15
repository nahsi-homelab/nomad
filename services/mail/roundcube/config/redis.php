<?php
  $config['redis_hosts'] = ['master.redis-mail.service.consul:6379:5:{{- with secret "secret/redis/mail/users/default" -}}{{ .Data.data.password }}{{ end -}}'];
  $config['session_storage'] = 'redis';
  $config['imap_cache'] = 'redis';
