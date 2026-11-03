{ ... }:

{
  programs.clash-verge = {
    enable = true;
    autoStart = true;
  };

  dae.upstream = "socks5://127.0.0.1:7897";
  dae.directProcesses = [
    "verge-mihomo"
    "mihomo"
    "clash-verge"
  ];
}
