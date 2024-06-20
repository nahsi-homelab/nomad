variables {
  versions = {
    spotifyd = "0.3.4"
  }
}

job "spotifyd" {
  datacenters = [
    "asia",
  ]
  namespace = "services"
  type      = "system"

  constraint {
    attribute = meta.workstation
    value     = true
  }

  group "spotifyd" {
    ephemeral_disk {}

    task "spotifyd" {
      driver = "docker"

      vault {
        policies = ["spotifyd"]
      }

      resources {
        cpu        = 100
        memory     = 64
        memory_max = 256
      }

      env = {
        PULSE_SERVER = "tcp:172.17.0.1:4713"
      }

      config {
        image = "nahsihub/spotifyd:${var.versions.spotifyd}"
        args = [
          "--device-type", "computer",
          "--device-name", "${node.unique.name}",

          "--bitrate", "320",
          "--volume-normalisation",
          "--volume-controller", "softvol",
          "--backend", "pulseaudio",
          "--cache-path", "${NOMAD_ALLOC_DIR}/data/",

          "--username-cmd", "cat ${NOMAD_SECRETS_DIR}/username",
          "--password-cmd", "cat ${NOMAD_SECRETS_DIR}/password",
        ]
      }

      template {
        data        = <<-EOF
        {{ with secret "secret/spotify" }}{{ .Data.data.username }}{{ end }}
        EOF
        destination = "secrets/username"
      }

      template {
        data        = <<-EOF
        {{ with secret "secret/spotify" }}{{ .Data.data.password }}{{ end }}
        EOF
        destination = "secrets/password"
      }
    }
  }
}