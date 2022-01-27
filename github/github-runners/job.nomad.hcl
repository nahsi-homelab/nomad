variables {
  github-runner = {
    version = "2.286.1"
    sha     = "7b1509c353ea4e6561b2ed2e916dcbf2a0d8ce21172edd9f8c846a20b6462cd6"
  }
}

job "github-runners" {
  datacenters = [
    "syria",
  ]
  namespace = "github"

  update {
    max_parallel = 1
  }

  group "homelab-exec" {
    count = 2
    constraint {
      distinct_hosts = true
    }

    volume "docker-socket" {
      type   = "host"
      source = "docker-socket"
    }

    volume "vboxdrv" {
      type   = "host"
      source = "vboxdrv"
    }

    volume "vboxnetctl" {
      type   = "host"
      source = "vboxnetctl"
    }

    task "download-runner" {
      driver = "raw_exec"

      lifecycle {
        hook = "prestart"
      }

      resources {
        cpu    = 10
        memory = 10
      }

      config {
        command = "chown"
        args = [
          "-R", "github", "${NOMAD_ALLOC_DIR}/data/runner",
        ]
      }

      artifact {
        source = "https://github.com/actions/runner/releases/download/v${var.github-runner.version}/actions-runner-linux-x64-${var.github-runner.version}.tar.gz"
        options {
          checksum = "sha256:${var.github-runner.sha}"
        }

        destination = "${NOMAD_ALLOC_DIR}/data/runner/"
      }
    }

    task "github-runner" {
      driver = "exec"
      user   = "github"

      resources {
        cpu    = 2000
        memory = 2048
      }

      vault {
        policies = ["github-runner"]
      }

      kill_signal  = "SIGINT"
      kill_timeout = "30s"

      volume_mount {
        volume      = "docker-socket"
        destination = "/var/run/docker.sock"
      }

      volume_mount {
        volume      = "vboxdrv"
        destination = "/dev/vboxdrv"
      }

      volume_mount {
        volume      = "vboxnetctl"
        destination = "/dev/vboxnetctl"
      }

      env {
        RUNNER_DIR    = "${NOMAD_ALLOC_DIR}/data/runner"
        RUNNER_LABELS = "${node.unique.name},driver-exec"
        RUNNER_TYPE   = "org"
        GITHUB_ORG    = "nahsi-homelab"
      }

      config {
        command = "bash"
        args = [
          "local/runner.sh",
        ]
      }

      template {
        data        = file("runner.sh")
        destination = "local/runner.sh"
      }

      template {
        data = <<-EOF
        GITHUB_PAT={{ with secret "secret/github/nahsi-homelab/runner-token" }}{{ .Data.data.token }}{{ end }}
        EOF

        destination = "secrets/pat"
        env         = true
      }
    }
  }
}
