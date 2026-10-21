# modules/user/app/pdfcraft.nix
# storytold/pdfcraft — the ArtCraft PDF reader/editor (sibling of wordcraft),
# NOT the unrelated PDFCraftTool/pdfcraft browser toolkit.
{ lib, pkgs, ... }:

let
  pdfcraft = pkgs.callPackage ../../../pkgs/pdfcraft { };
in
{
  home.packages = [ pdfcraft ];

  # Default PDF handler (user decision 2026-10-20). mkDefault — the generic
  # xdg module or a host override (modules.user.desktop.xdg.extraDefaultApplications)
  # always wins.
  xdg.mimeApps.defaultApplications."application/pdf" =
    lib.mkDefault "ai.storyteller.pdfcraft.desktop";
}
