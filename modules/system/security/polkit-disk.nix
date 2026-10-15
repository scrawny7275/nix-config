# modules/system/security/polkit-disk.nix
# Polkit rules for disk management tools (GParted, KDE Partition Manager, udisks2)
{ pkgs, ... }:

{
  security.polkit = {
    enable = true;
    extraConfig = ''
      polkit.addRule(function(action, subject) {
        if ((action.id == "org.freedesktop.udisks2.filesystem-mount-system" ||
             action.id == "org.freedesktop.udisks2.filesystem-mount" ||
             action.id == "org.freedesktop.udisks2.encrypted-unlock" ||
             action.id == "org.freedesktop.udisks2.eject-media" ||
             action.id == "org.freedesktop.udisks2.power-off-drive" ||
             action.id.indexOf("org.gparted") == 0 ||
             action.id.indexOf("org.kde.kpmcore") == 0) &&
            subject.isInGroup("wheel")) {
          return polkit.Result.YES;
        }
      });
    '';
  };
}
