{ config
, pkgs
, lib
, inputs
, ...
}:
let
  cfg = config.dae;

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
    secret_file=

    for candidate in /run/agenix/sing-box-subscription-url /etc/sing-box/subscription-url; do
      if [ -s "$candidate" ]; then
        secret_file="$candidate"
        break
      fi
    done

    if [ -z "$secret_file" ] && [ ! -s "$extra_config" ]; then
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
    ./dae-service.nix
    ./sing-box-service.nix
  ];

  options.dae.lanInterface = lib.mkOption {
    type = lib.types.str;
    default = "";
    description = "LAN interfaces for DAE transparent proxy bypass";
  };

  config = {
    _module.args = {
      singBoxUpdateSubscription = updateSubscription;
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

    services.dae = {
      enable = true;
      assets = with pkgs; [
        v2ray-geoip
        v2ray-domain-list-community
      ];
      config = builtins.replaceStrings
        [ "  lan_interface: enp2s0,docker0,virbr0,tailscale0,wlan0" ]
        [ "  lan_interface: ${cfg.lanInterface}" ]
        (builtins.readFile ./dotfiles/dae.dae);
    };
  };
}
