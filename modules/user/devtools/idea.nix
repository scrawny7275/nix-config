# modules/user/devtools/idea.nix
{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  niriCfg = config.modules.user.desktop.niri;

  myIdea = pkgs.jetbrains.idea.override {
    jdk = pkgs.jetbrains.jdk;
    vmopts = ''
      -Dawt.toolkit.name=WLToolkit
      -Dsun.java2d.vulkan=true
      -Dsun.java2d.vulkan.accelsd=true
      -Dsun.awt.disableGrab=true
      -Djbre.popupwindow.settype=true
      -Dsun.java2d.opengl=false
    '';
  };

  ideaVersion = lib.versions.majorMinor myIdea.version;
  productName = "IntelliJIdea";
in
{
  home.packages = with inputs.nix-jetbrains-plugins.lib; [
    (buildIdeWithPlugins pkgs myIdea [
      "org.intellij.scala"
      "com.github.tomasmilata.intelliroutes"
      "org.jetbrains.plugins.hocon"
      "nix-idea"
      "al.aoli.intellijdirenv"
    ])
    pkgs.shellcheck
    pkgs.hunspellDicts.es-any
    pkgs.hunspellDicts.es_MX
  ];

  # ---------------------------------------------------------------------------
  # Hunspell dictionaries (built-in spellchecker)
  # ---------------------------------------------------------------------------
  xdg.configFile."JetBrains/${productName}${ideaVersion}/dictionaries/es_ANY.dic" = {
    source = "${pkgs.hunspellDicts.es-any}/share/hunspell/es_ANY.dic";
    force = true;
  };
  xdg.configFile."JetBrains/${productName}${ideaVersion}/dictionaries/es_ANY.aff" = {
    source = "${pkgs.hunspellDicts.es-any}/share/hunspell/es_ANY.aff";
    force = true;
  };
  xdg.configFile."JetBrains/${productName}${ideaVersion}/dictionaries/es_MX.dic" = {
    source = "${pkgs.hunspellDicts.es_MX}/share/hunspell/es_MX.dic";
    force = true;
  };
  xdg.configFile."JetBrains/${productName}${ideaVersion}/dictionaries/es_MX.aff" = {
    source = "${pkgs.hunspellDicts.es_MX}/share/hunspell/es_MX.aff";
    force = true;
  };

  xdg.configFile."JetBrains/${productName}${ideaVersion}/options/spelling.xml" = {
    text = ''
      <application>
        <component name="SpellCheckerSettings" bundledDictionaryPath="$APPLICATION_CONFIG_DIR$/dictionaries">
          <option name="customDictionariesPaths">
            <list>
              <option value="$APPLICATION_CONFIG_DIR$/dictionaries/es_ANY.dic" />
              <option value="$APPLICATION_CONFIG_DIR$/dictionaries/es_MX.dic" />
            </list>
          </option>
        </component>
      </application>
    '';
    force = true;
  };

  # ---------------------------------------------------------------------------
  # Window decorations (close button only)
  # ---------------------------------------------------------------------------
  xdg.configFile."JetBrains/${productName}${ideaVersion}/options/ide.general.xml" = {
    text = ''
      <application>
        <component name="Registry">
          <entry key="ide.linux.window.buttons.config" value=":close" />
        </component>
      </application>
    '';
    force = true;
  };

  # ---------------------------------------------------------------------------
  # Niri window rule
  # ---------------------------------------------------------------------------
  modules.user.desktop.niri.extraWindowRules = lib.mkIf (niriCfg.enable or false) [
    {
      matches = [ { app-id = "^jetbrains-idea"; } ];
      border = false;
    }
  ];
}
