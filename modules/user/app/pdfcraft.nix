# modules/user/app/pdfcraft.nix
# storytold/pdfcraft — the ArtCraft PDF reader/editor (sibling of wordcraft),
# NOT the unrelated PDFCraftTool/pdfcraft browser toolkit.
{ pkgs, ... }:

let
  pdfcraft = pkgs.callPackage ../../../pkgs/pdfcraft { };
in
{
  home.packages = [ pdfcraft ];
}
