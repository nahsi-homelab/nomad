variables {
  versions = {
    jaeger = "1.27"
    promtail = "2.3.0"
  }
}

job "jaeger" {
  datacenters = ["syria", "asia"]
  namespace   = "infra"
  type        = "system"

  group "jaeger" {
    network {
      port "jaeger" {
        to = 14271
      }

      port "jaeger-thrift" {
        to = 6831
        static = 6831
      }
    }

    service {
      name = "jaeger"
      port = "jaeger"

      check {
        name     = "Jaeger HTTP"
        type     = "http"
        path     = "/"
        interval = "10s"
        timeout  = "2s"
      }
    }


    task "jaeger" {
      driver = "docker"
      user   = "nobody"

      config {
        image = "jaegertracing/jaeger-agent:${var.versions.jaeger}"

        ports = [
          "jaeger",
          "jaeger-thrift"
        ]

        args = [
          "--reporter.grpc.host-port=tempo.service.consul:9095"
        ]
      }
    }
  }
}
