{ config
, pkgs
, lib
, inputs
, ...
}:
let
  singBoxSettings = lib.recursiveUpdate
    (builtins.fromJSON (builtins.readFile ./dotfiles/sing-box.json))
    {
      experimental.clash_api.external_ui = "${pkgs.zashboard}";
    };
  singBoxBaseConfig = pkgs.writeText "sing-box-base.json" (builtins.toJSON singBoxSettings);
  updateSubscription = pkgs.writeShellScript "sing-box-update-subscription" ''
    set -euo pipefail

    config=/run/sing-box/config.json
    clash_secret=/run/agenix/sing-box-clash-secret
    extra_config=/run/agenix/sing-box-hy-nodes
    content_file=/run/agenix/sing-box-subscription-content
    secret_file=

    for candidate in /run/agenix/sing-box-subscription-url /etc/sing-box/subscription-url; do
      if [ -s "$candidate" ]; then
        secret_file="$candidate"
        break
      fi
    done

    if [ -z "$secret_file" ] && [ ! -s "$extra_config" ] && [ ! -s "$content_file" ]; then
      ${pkgs.coreutils}/bin/install -m 0600 -o sing-box -g sing-box ${singBoxBaseConfig} "$config"
    else
      tmp=$(${pkgs.coreutils}/bin/mktemp /run/sing-box/config.json.XXXXXX)
      cleanup() {
        ${pkgs.coreutils}/bin/rm -f "$tmp"
      }
      trap cleanup EXIT

      args=(
        --base-config ${singBoxBaseConfig}
        --output "$tmp"
      )
      if [ -n "$secret_file" ]; then
        args+=(--url-file "$secret_file")
      fi
      if [ -s "$content_file" ]; then
        args+=(--content-file "$content_file")
      fi
      if [ -s "$extra_config" ]; then
        args+=(--extra-config-file "$extra_config")
      fi

      ${pkgs.python3.withPackages (ps: [ ps.pyyaml ])}/bin/python3 ${./import-subscription.py} "''${args[@]}"

      ${lib.getExe config.services.sing-box.package} check -c "$tmp"
      ${pkgs.coreutils}/bin/chown --reference=/run/sing-box "$tmp"
      ${pkgs.coreutils}/bin/chmod 0600 "$tmp"
      ${pkgs.coreutils}/bin/mv "$tmp" "$config"
      trap - EXIT
    fi

    if [ -s "$clash_secret" ]; then
      ${pkgs.jq}/bin/jq \
        --arg s "$(${pkgs.coreutils}/bin/cat "$clash_secret")" \
        '.experimental.clash_api.secret = $s' \
        "$config" > "$config.tmp" \
        && ${pkgs.coreutils}/bin/mv "$config.tmp" "$config"
    fi
  '';
in
{
  imports = [
    ./sing-box-service.nix
  ];

  config = {
    _module.args = {
      singBoxUpdateSubscription = updateSubscription;
    };

    systemd.services = lib.mkIf (config.services.dae.enable or false) {
      dae = {
        after = [ "sing-box.service" ];
        requires = [ "sing-box.service" ];
      };
    };

    age.secrets.sing-box-subscription-url = {
      file = inputs.privateConfig.lib.secretFile "sing-box-subscription-url";
      path = "/run/agenix/sing-box-subscription-url";
      owner = "root";
      group = "root";
      mode = "0400";
    };

    age.secrets.sing-box-clash-secret = {
      file = inputs.privateConfig.lib.secretFile "sing-box-clash-secret";
      path = "/run/agenix/sing-box-clash-secret";
      owner = "root";
      group = "root";
      mode = "0400";
    };

    age.secrets.sing-box-subscription-content = {
      file = inputs.privateConfig.lib.secretFile "sing-box-subscription-content";
      path = "/run/agenix/sing-box-subscription-content";
      owner = "root";
      group = "root";
      mode = "0400";
    };

    age.secrets.sing-box-hy-nodes = {
      file = inputs.privateConfig.lib.secretFile "sing-box-hy-nodes";
      path = "/run/agenix/sing-box-hy-nodes";
      owner = "root";
      group = "root";
      mode = "0400";
    };

    services.sing-box = {
      enable = true;
      settings = singBoxSettings;
    };
  };
}
