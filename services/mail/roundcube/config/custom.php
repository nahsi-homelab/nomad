<?php
  $config['product_name'] = 'nahsi.dev mail';
  $config['temp_dir'] = '{{ env "NOMAD_ALLOC_DIR" }}/tmp';
  $config['smtp_helo_host'] = 'mail.nahsi.dev';
  $config['support_url'] = 'maitlto:nahsi@nahsi.dev';
  $config['log_driver'] = 'stdout';
  $config['database_attachments_cache'] = 'db';
  $config['session_lifetime'] = 20;
