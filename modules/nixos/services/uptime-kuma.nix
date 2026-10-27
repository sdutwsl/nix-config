{
  virtualisation.oci-containers = {
    backend = "docker";
    containers.uptime-kuma = {
      # uptime-kuma 2.5.5 (2026-09-16), pinned by digest for reproducibility.
      # Upstream keeps :latest and :1 on the abandoned 1.x line — never use a tag here.
      image = "louislam/uptime-kuma@sha256:c74379ac4509ce2d2c2633f509e67003ee2e45b6e995c5e43fc101f45a0e1fbe";
      ports = [ "3001:3001" ];
      volumes = [
        "/var/lib/uptime-kuma:/app/data"
        "/var/run/docker.sock:/var/run/docker.sock"
      ];
    };
  };
}
