{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = {
    domain = "www.sdutwsl.cn";
    httpsConfigFile = config.age.secrets.nginx-locations.path;
  };
  stackDir = "${config.xdg.configHome}/services/docker-compose/nginx";
  dataDir = "${config.xdg.dataHome}/personal-nginx";
  certDir = "${config.home.homeDirectory}/certs";
  statusDomain = "status.sdutwsl.cn";
  resumeDomain = "resume.sdutwsl.cn";
  mcpDomain = "mcp.sdutwsl.cn";
  docker = "${pkgs.docker}/bin/docker";
  compose = "${docker} compose --project-name personal-nginx --file ${lib.escapeShellArg "${stackDir}/compose.yaml"}";
  httpConfig = pkgs.writeText "personal-nginx-http.conf" ''
    server {
        listen 80 default_server;
        listen [::]:80 default_server;
        server_name ${cfg.domain};

        location ^~ /.well-known/acme-challenge/ {
            root /var/www/acme;
            default_type text/plain;
            try_files $uri =404;
        }

        location / {
            root /var/www/default;
            index index.html;
            try_files $uri $uri/ =404;
        }
    }
  '';
  httpsConfig = pkgs.writeText "personal-nginx-https.conf" ''
    server {
        listen 443 ssl default_server;
        listen [::]:443 ssl default_server;
        http2 on;
        server_name ${cfg.domain};

        ssl_certificate /etc/letsencrypt/live/${cfg.domain}/fullchain.pem;
        ssl_certificate_key /etc/letsencrypt/live/${cfg.domain}/privkey.pem;
        ssl_protocols TLSv1.2 TLSv1.3;

        location / {
            root /var/www/default;
            index index.html;
            try_files $uri $uri/ =404;
        }
        include /etc/nginx/private/locations.conf;
    }
  '';
  statusConfig = pkgs.writeText "personal-nginx-status.conf" ''
    server {
        listen 80;
        listen [::]:80;
        server_name ${statusDomain};

        location ^~ /.well-known/acme-challenge/ {
            root /var/www/acme;
            try_files $uri =404;
        }

        location / { return 301 https://$host$request_uri; }
    }

    server {
        listen 443 ssl;
        listen [::]:443 ssl;
        http2 on;
        server_name ${statusDomain};

        ssl_certificate /etc/letsencrypt/live/${statusDomain}/fullchain.pem;
        ssl_certificate_key /etc/letsencrypt/live/${statusDomain}/privkey.pem;
        ssl_protocols TLSv1.2 TLSv1.3;

        location / {
            proxy_pass http://aio:3001;
            proxy_http_version 1.1;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_read_timeout 300s;
        }
    }
  '';
  resumeHttpConfig = pkgs.writeText "personal-nginx-resume-http.conf" ''
    server {
        listen 80;
        listen [::]:80;
        server_name ${resumeDomain};

        location ^~ /.well-known/acme-challenge/ {
            root /var/www/acme;
            try_files $uri =404;
        }

        location / { return 301 https://$host$request_uri; }
    }
  '';
  resumeHttpsConfig = pkgs.writeText "personal-nginx-resume-https.conf" ''
    # WebSocket upgrade only for requests that actually ask for it.
    map $http_upgrade $resume_connection_upgrade {
        default upgrade;
        "" close;
    }

    server {
        listen 443 ssl;
        listen [::]:443 ssl;
        http2 on;
        server_name ${resumeDomain};

        ssl_certificate /etc/letsencrypt/live/${resumeDomain}/fullchain.pem;
        ssl_certificate_key /etc/letsencrypt/live/${resumeDomain}/privkey.pem;
        ssl_protocols TLSv1.2 TLSv1.3;

        # The whole site (resume page, big-screen and the three demos) now runs as a
        # container stack on aio; this host only terminates TLS and forwards.
        # Static rules, SPA fallbacks and API routing live in that stack's nginx.
        # The reports demo uploads CSV files, so allow slightly more than its 2 MiB limit.
        client_max_body_size 3m;

        location / {
            proxy_pass http://aio:18080;
            proxy_http_version 1.1;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            # Send exactly one hop and drop any client-supplied value: otherwise a
            # client could forge its own source address for the upstream's rate limits.
            proxy_set_header X-Forwarded-For $remote_addr;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection $resume_connection_upgrade;
            # Larger than the helpdesk demo's 25s WebSocket heartbeat.
            proxy_read_timeout 120s;
            proxy_send_timeout 120s;
        }
    }
  '';
  mcpConfig = pkgs.writeText "personal-nginx-mcp.conf" ''
    server {
        listen 80;
        listen [::]:80;
        server_name ${mcpDomain};

        location ^~ /.well-known/acme-challenge/ {
            root /var/www/acme;
            try_files $uri =404;
        }

        location / { return 301 https://$host$request_uri; }
    }

    server {
        listen 443 ssl;
        listen [::]:443 ssl;
        http2 on;
        server_name ${mcpDomain};

        ssl_certificate /etc/letsencrypt/live/${mcpDomain}/fullchain.pem;
        ssl_certificate_key /etc/letsencrypt/live/${mcpDomain}/privkey.pem;
        ssl_protocols TLSv1.2 TLSv1.3;

        # local-mcp on aio (Bearer token is checked upstream); /mcp is Streamable HTTP, /sse is legacy SSE.
        location / {
            proxy_pass http://aio:18765;
            proxy_http_version 1.1;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $remote_addr;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header Connection "";
            # Event streams must reach the client unbuffered and stay open while idle.
            proxy_buffering off;
            proxy_cache off;
            proxy_read_timeout 1h;
            proxy_send_timeout 1h;
        }
    }
  '';
  prepare = pkgs.writeShellApplication {
    name = "prepare-personal-nginx";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      install -d -m 755 ${lib.escapeShellArg dataDir}/{conf.d,acme,html}
      install -d -m 755 ${lib.escapeShellArg "${dataDir}/html/resume"}
      install -m 644 ${./dotfiles/nginx-index.html} ${lib.escapeShellArg "${dataDir}/html/index.html"}
      install -d -m 700 ${lib.escapeShellArg certDir}
      install -d -m 700 ${lib.escapeShellArg "${dataDir}/private"}
      install -m 600 ${lib.escapeShellArg cfg.httpsConfigFile} ${lib.escapeShellArg "${dataDir}/private/locations.conf"}
      install -m 644 ${httpConfig} ${lib.escapeShellArg "${dataDir}/conf.d/http.conf"}
      install -m 644 ${resumeHttpConfig} ${lib.escapeShellArg "${dataDir}/conf.d/resume-http.conf"}
      # Copy real files: Home Manager symlinks target /nix/store outside the container.
      if [ -s ${lib.escapeShellArg "${certDir}/live/${cfg.domain}/fullchain.pem"} ] &&
         [ -s ${lib.escapeShellArg "${certDir}/live/${cfg.domain}/privkey.pem"} ]; then
        install -m 644 ${httpsConfig} ${lib.escapeShellArg "${dataDir}/conf.d/https.conf"}
      else
        rm -f ${lib.escapeShellArg "${dataDir}/conf.d/https.conf"}
      fi
      if [ -s ${lib.escapeShellArg "${certDir}/live/${statusDomain}/fullchain.pem"} ] &&
         [ -s ${lib.escapeShellArg "${certDir}/live/${statusDomain}/privkey.pem"} ]; then
        install -m 644 ${statusConfig} ${lib.escapeShellArg "${dataDir}/conf.d/status.conf"}
      else
        rm -f ${lib.escapeShellArg "${dataDir}/conf.d/status.conf"}
      fi
      if [ -s ${lib.escapeShellArg "${certDir}/live/${resumeDomain}/fullchain.pem"} ] &&
         [ -s ${lib.escapeShellArg "${certDir}/live/${resumeDomain}/privkey.pem"} ]; then
        install -m 644 ${resumeHttpsConfig} ${lib.escapeShellArg "${dataDir}/conf.d/resume-https.conf"}
      else
        rm -f ${lib.escapeShellArg "${dataDir}/conf.d/resume-https.conf"}
      fi
      if [ -s ${lib.escapeShellArg "${certDir}/live/${mcpDomain}/fullchain.pem"} ] &&
         [ -s ${lib.escapeShellArg "${certDir}/live/${mcpDomain}/privkey.pem"} ]; then
        install -m 644 ${mcpConfig} ${lib.escapeShellArg "${dataDir}/conf.d/mcp.conf"}
      else
        rm -f ${lib.escapeShellArg "${dataDir}/conf.d/mcp.conf"}
      fi
    '';
  };
  reload = pkgs.writeShellApplication {
    name = "reload-personal-nginx";
    text = ''
      ${prepare}/bin/prepare-personal-nginx
      ${compose} exec -T nginx nginx -t
      ${compose} exec -T nginx nginx -s reload
    '';
  };
in
{
  xdg.configFile."services/docker-compose/nginx/compose.yaml".text = ''
    services:
      nginx:
        image: nginx:stable
        container_name: personal-nginx
        restart: unless-stopped
        network_mode: host
        volumes:
          - /etc/hosts:/etc/hosts:ro
          - ${builtins.toJSON "${dataDir}/conf.d:/etc/nginx/conf.d:ro"}
          - ${builtins.toJSON "${dataDir}/private:/etc/nginx/private:ro"}
          - ${builtins.toJSON "${dataDir}/acme:/var/www/acme:ro"}
          - ${builtins.toJSON "${dataDir}/html:/var/www/default:ro"}
          - ${builtins.toJSON "${certDir}:/etc/letsencrypt:ro"}

  '';

  systemd.user.services.personal-nginx = {
    Unit.Description = "Personal nginx docker stack";
    Service = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStartPre = "${prepare}/bin/prepare-personal-nginx";
      ExecStart = "${compose} up --force-recreate --detach --wait --wait-timeout 120";
      ExecReload = "${reload}/bin/reload-personal-nginx";
      ExecStop = "${compose} down";
      Restart = "on-failure";
      RestartSec = "30s";
      TimeoutStartSec = "10min";
      TimeoutStopSec = "2min";
    };
    Install.WantedBy = [ "default.target" ];
  };

}
