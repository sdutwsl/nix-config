{ lib, ... }:
{
  programs.plasma.powerdevil = lib.genAttrs [ "AC" "battery" "lowBattery" ] (_: {
    autoSuspend.action = "nothing";
    dimDisplay.enable = false;
    turnOffDisplay = {
      idleTimeout = "never";
      idleTimeoutWhenLocked = "whenLockedAndUnlocked";
    };
  });
}
