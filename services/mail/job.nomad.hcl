variables {
  versions = {
    wildduck          = "1.34.0"
    haraka            = "latest"
    zone-mta          = "latest"
    zone-mta-webadmin = "latest"
    ducky-api         = "latest"
    roundcube         = "1.5.x"
    caddy             = "2.4.6"

    redis = "6.2"
  resec = "latest" }
}

job "mail" {
  datacenters = [
    "syria",
    "asia"
  ]
  namespace = "services"

  spread {
    attribute = "${node.datacenter}"
    weight    = 100
  }

  group "wildduck" {
    ephemeral_disk {
      sticky  = true
      migrate = true
    }

    count = 2
    update {
      max_parallel = 1
      stagger      = "1m"
    }

    network {
      mode = "bridge"
      port "wildduck" {
        to = 8080
      }
      port "imap" {
        to = 993
      }
      port "ducky" {}
    }

    service {
      name = "wildduck"
      port = "wildduck"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.wildduck.entrypoints=https",
        "traefik.http.routers.wildduck.rule=Host(`wildduck.service.consul`)",
      ]

      check {
        name     = "Wildduck TCP"
        type     = "tcp"
        port     = "imap"
        interval = "20s"
        timeout  = "2s"
      }
    }

    service {
      name = "wildduck-imap"
      port = "imap"

      tags = [
        "ingress.enable=true",
        "ingress.tcp.routers.wildduck-imap.entrypoints=imap",
        "ingress.tcp.routers.wildduck-imap.rule=HostSNI(`mail.nahsi.dev`)",
        "ingress.tcp.routers.wildduck-imap.tls.passthrough=true"
      ]
    }

    service {
      name = "ducky"
      port = "ducky"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.ducky-api.entrypoints=https",
        "traefik.http.routers.ducky-api.rule=Host(`ducky.service.consul`)",
      ]
    }

    task "wildduck" {
      driver = "docker"

      vault {
        policies = ["wildduck"]
      }

      resources {
        cpu        = 300
        memory     = 64
        memory_max = 128
      }

      env {
        WILDDUCK_CONFIG = "/local/wildduck/config/default.toml"
      }

      config {
        image = "nodemailer/wildduck:v${var.versions.wildduck}"

        ports = [
          "wildduck",
          "imap"
        ]

        volumes = [
          "local/wildduck/emails:/wildduck/emails:ro"
        ]
      }

      dynamic "template" {
        for_each = fileset(".", "wildduck/secrets/**")

        content {
          data        = file(template.value)
          destination = "secrets/${template.value}"
        }
      }

      dynamic "template" {
        for_each = fileset(".", "wildduck/emails/**")

        content {
          data        = file(template.value)
          destination = "local/${template.value}"
        }
      }

      dynamic "template" {
        for_each = fileset(".", "wildduck/config/**")

        content {
          data        = file(template.value)
          destination = "local/${template.value}"
        }
      }

      # CA
      template {
        data = <<-EOH
        {{- with secret "pki/issue/internal" "ttl=30d" "common_name=*.service.consul" -}}
        {{ .Data.issuing_ca }}{{ end }}
        EOH

        destination = "secrets/certs/CA.pem"
        change_mode = "restart"
        splay       = "1m"
      }

      # bundle
      template {
        data = <<-EOH
        {{- with secret "pki/issue/internal" "ttl=30d" "common_name=wildduck.service.consul" -}}
        {{ .Data.private_key }}
        {{ .Data.certificate }}{{ end }}
        EOH

        destination = "secrets/certs/bundle.pem"
        change_mode = "restart"
        splay       = "1m"
      }

      template {
        data = <<-EOH
        {{- with secret "secret/certificate" -}}
        {{ .Data.data.ca_bundle }}{{ end }}
        EOH

        destination = "secrets/tls/cert.pem"
        change_mode = "restart"
        splay       = "1m"
      }

      template {
        data = <<-EOH
        {{- with secret "secret/certificate" -}}
        {{ .Data.data.key }}{{ end }}
        EOH

        destination = "secrets/tls/key.pem"
        change_mode = "restart"
        splay       = "1m"
      }
    }

    task "redis" {
      driver = "docker"
      user   = "nobody"

      config {
        image   = "redis:6-alpine"
        command = "redis-server"
        args = [
          "--bind", "127.0.0.1",
          "--maxmemory", "48mb",
          "--dir", "${NOMAD_ALLOC_DIR}/data"
        ]
      }

      resources {
        cpu    = 100
        memory = 64
      }
    }

    task "ducky-api" {
      driver = "docker"

      vault {
        policies = ["ducky-api"]
      }

      lifecycle {
        hook = "poststart"
        sidecar = true
      }

      resources {
        cpu        = 100
        memory     = 64
        memory_max = 256
      }

      config {
        image = "nahsihub/ducky-api:${var.versions.ducky-api}"

        ports = [
          "ducky"
        ]

        volumes = [
          "secrets/config.env:/usr/local/ducky-api/config/production.env"
        ]
      }

      template {
        data        = file("ducky-api/config.env")
        destination = "secrets/config.env"
      }

      # CA
      template {
        data = <<-EOH
        {{- with secret "pki/issue/internal" "ttl=30d" "common_name=*.service.consul" -}}
        {{ .Data.issuing_ca }}{{ end }}
        EOH

        destination = "secrets/certs/CA.pem"
        change_mode = "restart"
        splay       = "1m"
      }

      # bundle
      template {
        data = <<-EOH
        {{- with secret "pki/issue/internal" "ttl=30d" "common_name=ducky.service.consul" -}}
        {{ .Data.private_key }}
        {{ .Data.certificate }}{{ end }}
        EOH

        destination = "secrets/certs/bundle.pem"
        change_mode = "restart"
        splay       = "1m"
      }
    }
  }

  group "webmail" {
    count = 2
    update {
      max_parallel = 1
      stagger      = "1m"
    }

    ephemeral_disk {
      sticky = true
    }

    network {
      mode = "bridge"
      port "http" {
        to = 80
      }
    }

    service {
      name = "roundcube"
      port = "http"

      tags = [
        "ingress.enable=true",
        "ingress.http.routers.roundcube.entrypoints=https",
        "ingress.http.routers.roundcube.rule=Host(`mail.nahsi.dev`)",
        "ingress.http.services.roundcube.loadBalancer.sticky.cookie=true",
      ]

      check {
        name     = "Roundcube HTTP"
        type     = "http"
        path     = "/"
        interval = "20s"
        timeout  = "2s"
      }
    }

    task "roundcube" {
      driver = "docker"

      vault {
        policies = ["roundcube"]
      }

      resources {
        cpu        = 100
        memory     = 32
        memory_max = 64
      }

      env {
        ROUNDCUBEMAIL_DEFAULT_HOST = "ssl://mail.nahsi.dev"
        ROUNDCUBEMAIL_DEFAULT_PORT = "993"
        ROUNDCUBEMAIL_SMTP_SERVER  = "ssl://mail.nahsi.dev"
        ROUNDCUBEMAIL_SMTP_PORT    = "465"
        ROUNDCUBEMAIL_SKIN         = "elastic"

        ROUNDCUBEMAIL_DB_TYPE = "pgsql"
        ROUNDCUBEMAIL_DB_HOST = "master.postgres.service.consul"
        ROUNDCUBEMAIL_DB_PORT = 5432
        ROUNDCUBEMAIL_DB_NAME = "roundcube"

        ROUNDCUBEMAIL_ASPELL_DICTS    = "en,ru"
        ROUNDCUBEMAIL_PLUGINS_PLUGINS = "archive,zipdownload,database_attachments"
      }

      config {
        image    = "roundcube/roundcubemail:${var.versions.roundcube}-fpm-alpine"
        work_dir = "${NOMAD_ALLOC_DIR}/data"
        volumes = [
          "local/roundcube/config:/var/roundcube/config",
          "local/roundcube/php.ini:/usr/local/etc/php/conf.d/zzz_custom.ini:ro"
        ]
      }

      template {
        data = <<-EOH
        ROUNDCUBEMAIL_DB_USER=roundcube
        ROUNDCUBEMAIL_DB_PASSWORD={{- with secret "postgres/static-creds/roundcube" -}}{{ .Data.password }}{{ end -}}
        EOH

        destination = "secrets/db.env"
        env         = true
      }

      dynamic "template" {
        for_each = fileset(".", "roundcube/**")

        content {
          data        = file(template.value)
          destination = "local/${template.value}"
        }
      }
    }

    task "caddy" {
      driver = "docker"
      user   = "nobody"

      lifecycle {
        hook    = "poststart"
        sidecar = true
      }

      resources {
        cpu    = 50
        memory = 32
      }

      config {
        image   = "caddy:${var.versions.caddy}-alpine"
        command = "caddy"
        args = [
          "run", "--config", "/local/Caddyfile", "--adapter", "caddyfile"
        ]
      }

      template {
        data = <<-EOH
        :80
        root * {{ env "NOMAD_ALLOC_DIR" }}/data
        php_fastcgi 127.0.0.1:9000
        file_server
        EOH

        destination = "local/Caddyfile"
      }
    }
  }

  group "haraka" {
    count = 2
    update {
      max_parallel = 1
      stagger      = "1m"
    }

    vault {
      policies = ["haraka"]
    }

    network {
      port "smtp" {}
    }

    service {
      name = "haraka"
      port = "smtp"

      tags = [
        "ingress.enable=true",
        "ingress.tcp.routers.haraka.entrypoints=smtp-relay",
        "ingress.tcp.routers.haraka.rule=HostSNI(`*`)",
      ]

      check {
        name     = "Haraka TCP"
        type     = "tcp"
        port     = "smtp"
        interval = "20s"
        timeout  = "2s"
      }
    }

    task "haraka" {
      driver = "docker"

      resources {
        cpu        = 500
        memory     = 150
        memory_max = 256
      }

      env {
        NODE_CLUSTER_SCHED_POLICY = "none"
        HARAKA_HOME               = "/local/haraka"
      }

      config {
        image = "nahsihub/haraka-wildduck:${var.versions.haraka}"

        ports = [
          "smtp"
        ]
      }

      dynamic "template" {
        for_each = fileset(".", "haraka/**")

        content {
          data        = file(template.value)
          destination = "local/${template.value}"
        }
      }

      # CA
      template {
        data = <<-EOH
        {{- with secret "pki/issue/internal" "ttl=30d" "common_name=*.service.consul" -}}
        {{ .Data.issuing_ca }}{{ end }}
        EOH

        destination = "secrets/certs/CA.pem"
        change_mode = "restart"
        splay       = "1m"
      }

      # bundle
      template {
        data = <<-EOH
        {{- with secret "pki/issue/internal" "ttl=30d" "common_name=haraka.service.consul" -}}
        {{ .Data.private_key }}
        {{ .Data.certificate }}{{ end }}
        EOH

        destination = "secrets/certs/bundle.pem"
        change_mode = "restart"
        splay       = "1m"
      }

      template {
        data = <<-EOH
        {{- with secret "secret/certificate" -}}
        {{ .Data.data.ca_bundle }}{{ end }}
        EOH

        destination = "secrets/starttls/cert.pem"
        change_mode = "restart"
        splay       = "1m"
      }

      template {
        data = <<-EOH
        {{- with secret "secret/certificate" -}}
        {{ .Data.data.key }}{{ end }}
        EOH

        destination = "secrets/starttls/key.pem"
        change_mode = "restart"
        splay       = "1m"
      }
    }
  }

  group "zone-mta" {
    count = 1
    update {
      max_parallel = 1
      stagger      = "1m"
    }

    constraint {
      attribute = "${node.datacenter}"
      value     = "syria"
    }

    network {
      mode = "bridge"
      port "api" {}
      port "webadmin" {}
      port "smtp" {
        to = 465
      }
    }

    service {
      name = "zone-mta"
      port = "webadmin"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.zone-mta.entrypoints=https",
        "traefik.http.routers.zone-mta.rule=Host(`zone-mta.service.consul`)",
      ]

      check {
        name     = "zone-mta webadmin"
        type     = "http"
        path     = "/"
        port     = "webadmin"
        interval = "20s"
        timeout  = "2s"
      }
    }

    service {
      name = "zone-mta-api"
      port = "api"

      check {
        name     = "zone-mta TCP"
        type     = "tcp"
        port     = "smtp"
        interval = "20s"
        timeout  = "2s"
      }
    }

    service {
      name = "zone-mta-smtp"
      port = "smtp"

      tags = [
        "ingress.enable=true",
        "ingress.tcp.routers.zone-mta-smtp.entrypoints=smtp",
        "ingress.tcp.routers.zone-mta-smtp.rule=HostSNI(`mail.nahsi.dev`)",
        "ingress.tcp.routers.zone-mta-smtp.tls.passthrough=true"
      ]
    }

    task "zone-mta" {
      driver = "docker"

      vault {
        policies = ["zone-mta"]
      }

      resources {
        cpu        = 300
        memory     = 256
        memory_max = 350
      }

      env {
        NODE_CLUSTER_SCHED_POLICY = "none"
        ZONEMTA_CONFIG_DIR        = "/local/zone-mta/config"
      }

      config {
        image = "nahsihub/zone-mta-wildduck:${var.versions.zone-mta}"

        ports = [
          "smtp"
        ]
      }

      dynamic "template" {
        for_each = fileset(".", "zone-mta/secrets/**")

        content {
          data        = file(template.value)
          destination = "secrets/${template.value}"
        }
      }

      dynamic "template" {
        for_each = fileset(".", "zone-mta/config/**")

        content {
          data        = file(template.value)
          destination = "local/${template.value}"
        }
      }

      # CA
      template {
        data = <<-EOH
        {{- with secret "pki/issue/internal" "ttl=30d" "common_name=*.service.consul" -}}
        {{ .Data.issuing_ca }}{{ end }}
        EOH

        destination = "secrets/certs/CA.pem"
        change_mode = "restart"
        splay       = "1m"
      }

      # bundle
      template {
        data = <<-EOH
        {{- with secret "pki/issue/internal" "ttl=30d" "common_name=zone-mta.service.consul" -}}
        {{ .Data.private_key }}
        {{ .Data.certificate }}{{ end }}
        EOH

        destination = "secrets/certs/bundle.pem"
        change_mode = "restart"
        splay       = "1m"
      }

      template {
        data = <<-EOH
        {{- with secret "secret/certificate" -}}
        {{ .Data.data.ca_bundle }}{{ end }}
        EOH

        destination = "secrets/tls/cert.pem"
        change_mode = "restart"
        splay       = "1m"
      }

      template {
        data = <<-EOH
        {{- with secret "secret/certificate" -}}
        {{ .Data.data.key }}{{ end }}
        EOH

        destination = "secrets/tls/key.pem"
        change_mode = "restart"
        splay       = "1m"
      }

      template {
        data = <<-EOH
        {{- with secret "secret/mail/dkim" -}}
        {{ .Data.data.private_key }}{{ end }}
        EOH

        destination = "secrets/dkim.pem"
        change_mode = "restart"
        splay       = "1m"
      }
    }

    task "webadmin" {
      driver = "docker"

      lifecycle {
        sidecar = true
      }

      vault {
        policies = ["zone-mta-webadmin"]
      }

      resources {
        cpu    = 50
        memory = 64
      }

      config {
        image = "nahsihub/zone-mta-webadmin:${var.versions.zone-mta-webadmin}"
        ports = ["webadmin"]
        volumes = [
          "secrets/default.toml:/usr/local/zone-mta-webadmin/config/default.toml"
        ]
      }

      template {
        data        = file("zone-mta-webadmin/default.toml")
        destination = "secrets/default.toml"
      }

      # CA
      template {
        data = <<-EOH
        {{- with secret "pki/issue/internal" "ttl=30d" "common_name=*.service.consul" -}}
        {{ .Data.issuing_ca }}{{ end }}
        EOH

        destination = "secrets/certs/CA.pem"
        change_mode = "restart"
        splay       = "1m"
      }

      # bundle
      template {
        data = <<-EOH
        {{- with secret "pki/issue/internal" "ttl=30d" "common_name=zone-mta-webadmin.service.consul" -}}
        {{ .Data.private_key }}
        {{ .Data.certificate }}{{ end }}
        EOH

        destination = "secrets/certs/bundle.pem"
        change_mode = "restart"
        splay       = "1m"
      }
    }
  }

  group "redis" {
    count = 2
    update {
      max_parallel = 1
      stagger      = "1m"
    }

    network {
      mode = "bridge"
      port "redis" {
        to     = 6379
        static = 6379
      }

      port "resec" {
        to = 8080
      }
    }

    vault {
      policies = ["redis-mail"]
    }

    volume "mail" {
      type   = "host"
      source = "redis-mail"
    }

    task "redis" {
      driver = "docker"
      user   = "nobody"

      volume_mount {
        volume      = "mail"
        destination = "/data"
      }

      resources {
        cpu    = 100
        memory = 64
      }

      config {
        image   = "redis:${var.versions.redis}-alpine"
        ports   = ["redis"]
        command = "redis-server"
        args = [
          "/local/redis.conf"
        ]
      }

      template {
        data        = file("redis/redis.conf")
        destination = "/local/redis.conf"
        change_mode = "restart"
        splay       = "1m"
      }

      template {
        data        = file("redis/auth.conf")
        destination = "/secrets/auth.conf"
        change_mode = "restart"
        splay       = "1m"
      }

      template {
        data        = file("redis/users.acl")
        destination = "/secrets/users.acl"
        change_mode = "restart"
        splay       = "1m"
      }
    }

    task "resec" {
      driver = "docker"

      resources {
        cpu    = 100
        memory = 64
      }

      kill_timeout = "10s"

      service {
        name = "resec"
        port = "resec"

        check {
          name     = "Redis readiness"
          type     = "http"
          path     = "/health"
          interval = "20s"
          timeout  = "2s"
        }

        check_restart {
          limit = 2
          grace = "5s"
        }
      }

      env {
        CONSUL_HTTP_ADDR    = "http://${attr.unique.network.ip-address}:8500"
        CONSUL_SERVICE_NAME = "redis-mail"
        CONSUL_LOCK_KEY     = "resec/mail/.lock"
        MASTER_TAGS         = "master"
        SLAVE_TAGS          = "replica"
        REDIS_ADDR          = "127.0.0.1:6379"
        ANNOUNCE_ADDR       = "${NOMAD_ADDR_redis}"
        STATE_SERVER        = "true"
      }

      config {
        image = "nahsihub/resec:${var.versions.resec}"
        ports = ["resec"]
      }

      template {
        data = <<-EOH
        REDIS_PASSWORD={{ with secret "secret/data/redis/mail/users/default" }}{{ .Data.data.password }}{{ end }}
        EOH

        destination = "secrets/password"
        env         = true
        change_mode = "restart"
        splay       = "1m"
      }
    }
  }
}
