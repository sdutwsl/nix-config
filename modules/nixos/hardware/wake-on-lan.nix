{ ... }:
{
  # Enable magic-packet wake-up through NetworkManager on wired connections.
  # A .link matching OriginalName would miss the interface before its rename.
  networking.networkmanager.settings.connection."ethernet.wake-on-lan" = 64;
}
