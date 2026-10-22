# tests/default.nix — unit tests for this repo's own module logic.
# Shape: lib.debug.runTests-compatible attrset (each test { expr; expected; }).
# Scope rule: test our conditionals/templates/derived structures — never
# upstream option plumbing (see docs). The flake turns this into a `checks`
# derivation; `nix flake check` runs it.
{ lib }:

let
  stubInput = ../share/private-stub;
  stubValues = import (stubInput + "/values.nix");
  fakeInputs = { private = stubInput; };

  evalSystem =
    extra:
    (lib.evalModules {
      modules = [
        { _module.args.inputs = fakeInputs; }
        stubBase
        ../modules/system/private.nix
      ] ++ extra;
    }).config;

  evalUser =
    extra:
    (lib.evalModules {
      modules = [
        { _module.args.inputs = fakeInputs; }
        stubBase
        ../modules/user/private.nix
      ] ++ extra;
    }).config;

  # minimal option scaffolding: bare evalModules lacks the NixOS/HM base
  # modules that declare `assertions`/`warnings`, and the ssh consumer test
  # needs programs.ssh.settings to exist without the full home-manager base
  stubBase =
    { lib, ... }:
    {
      options.assertions = lib.mkOption {
        type = lib.types.listOf lib.types.attrs;
        default = [ ];
      };
      options.warnings = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
      };
      options.programs.ssh.settings = lib.mkOption {
        type = lib.types.attrs;
        default = { };
      };
      options.programs.ssh.enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
      options.programs.ssh.enableDefaultConfig = lib.mkOption {
        type = lib.types.bool;
        default = true;
      };
      options.security.certificates.policyFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
      };
      options.services.ssh-agent.enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
    };

  # fixture roles for the pure xdg mimeApps mapping test
  testRoleApps = {
    browser = "test-browser.desktop";
    file-manager = "test-file-manager.desktop";
    image-viewer = "test-image-viewer.desktop";
    video-player = "test-video-player.desktop";
    music-player = "test-music-player.desktop";
    text-editor = "test-text-editor.desktop";
    document-viewer = "test-document-viewer.desktop";
    file-archiver = "test-file-archiver.desktop";
    torrent-client = "test-torrent-client.desktop";
    office-suite = "test-office-suite.desktop";
  };

  # registry fixtures: every role's selected value registered as candidate
  roleValidation = import ../modules/user/desktop/xdg/role-validation.nix { inherit lib; };
  testRoleCandidates = builtins.mapAttrs (_: v: [ v ]) testRoleApps;
in
{
  # --- stub semantics (public surface must stay generic) ---
  testStubIsNotReal = {
    expr = stubValues.real;
    expected = false;
  };
  testStubCarriesNoRegistries = {
    expr = stubValues.registries;
    expected = [ ];
  };
  testStubCarriesNoSshIdentities = {
    expr = stubValues.sshIdentities;
    expected = { };
  };
  testStubCarriesNoExtraHosts = {
    expr = stubValues.extraHosts;
    expected = { };
  };
  testStubHasNoVpnEndpoint = {
    expr = stubValues.vpnRemote;
    expected = null;
  };

  # --- adapter defaults (stranger safety) ---
  testSystemEnableDefaultsFalse = {
    expr = (evalSystem [ ]).modules.private.enable;
    expected = false;
  };
  testUserEnableDefaultsFalse = {
    expr = (evalUser [ ]).modules.private.enable;
    expected = false;
  };
  testStubWarningEmitted = {
    expr = builtins.length ((evalSystem [ ]).warnings);
    expected = 1;
  };

  # --- interlock boolean (enable against stub must trip the assertion) ---
  testInterlockTripsWhenForced = {
    expr = builtins.any (a: !a.assertion) ((evalSystem [ { modules.private.enable = true; } ]).assertions);
    expected = true;
  };
  testInterlockSilentWhenOverride = {
    # simulate the private override: stub replaced by a real-shape fixture
    expr =
      let
        cfg =
          (lib.evalModules {
            modules = [
              {
                _module.args.inputs.private = ./fixture-real;
              }
              stubBase
              ../modules/system/private.nix
              { modules.private.enable = true; }
            ];
          }).config;
      in
      builtins.any (a: !a.assertion) cfg.assertions;
    expected = false;
  };

  # --- ssh matrix empty under stub (no identity leakage) ---
  testSshSettingsEmptyUnderStub = {
    expr =
      (lib.evalModules {
        modules = [
          { _module.args.inputs = fakeInputs; }
          stubBase
          ../modules/user/security/ssh.nix
          ../modules/user/private.nix
        ];
      }).config.programs.ssh.settings;
    expected = { };
  };

  # --- xdg mimeApps generic mapping (pure function of roleApps) ---
  # Locks the role → MIME-type mapping shape; app-module-owned families
  # (pdf/word/presentation) are deliberately absent here and verified
  # against the live merged config separately (forced-eval baseline).
  testXdgMimeAppsMapping = {
    expr =
      (import ../modules/user/desktop/xdg/mimeApps.nix { roleApps = testRoleApps; }).defaultApplications;
    expected = {
      "inode/directory" = "test-file-manager.desktop";
      "x-scheme-handler/file" = [ "test-file-manager.desktop" ];
      "x-scheme-handler/about" = [ "test-file-manager.desktop" ];

      "application/cbz" = "test-document-viewer.desktop";
      "application/x-bzip2" = "test-file-archiver.desktop";
      "application/x-gzip" = "test-file-archiver.desktop";
      "application/x-tar" = "test-file-archiver.desktop";
      "application/zip" = "test-file-archiver.desktop";
      "application/json" = "test-text-editor.desktop";
      "application/txt" = "test-text-editor.desktop";
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" = "test-office-suite.desktop";
      "application/x-zerosize" = "test-text-editor.desktop";

      "audio/mpeg" = "test-music-player.desktop";
      "audio/flac" = "test-music-player.desktop";
      "audio/vnd.wave" = "test-music-player.desktop";

      "image/gif" = "test-image-viewer.desktop";
      "image/jpeg" = "test-image-viewer.desktop";
      "image/png" = "test-image-viewer.desktop";
      "image/svg" = "test-image-viewer.desktop";
      "image/tiff" = "test-image-viewer.desktop";
      "image/webp" = "test-image-viewer.desktop";

      "text/html" = "test-browser.desktop";
      "text/xml" = "test-text-editor.desktop";
      "text/markdown" = "test-text-editor.desktop";
      "text/plain" = "test-text-editor.desktop";

      "video/mpeg" = "test-video-player.desktop";
      "video/webm" = "test-video-player.desktop";
      "video/x-matroska" = "test-video-player.desktop";
      "video/mp4" = "test-video-player.desktop";

      "x-scheme-handler/http" = "test-browser.desktop";
      "x-scheme-handler/https" = "test-browser.desktop";
      "x-scheme-handler/magnet" = "test-torrent-client.desktop";
      "application/x-bittorrent" = "test-torrent-client.desktop";
    };
  };

  # --- xdg closed candidate registry (pure roleSelectionErrors) ---
  testRoleSelectionValid = {
    expr = roleValidation.roleSelectionErrors testRoleApps testRoleCandidates { };
    expected = [ ];
  };

  # the historical org.system76.* bug class must fail with the registered
  # alternative named
  testRoleSelectionTypoFails = {
    expr = roleValidation.roleSelectionErrors
      (testRoleApps // { file-manager = "org.system76.CosmicFiles.desktop"; })
      testRoleCandidates
      { };
    expected = [
      "xdg.roleApps.file-manager: \"org.system76.CosmicFiles.desktop\" is not a registered candidate (registered for file-manager: test-file-manager.desktop). Register it in modules.user.desktop.xdg.roleCandidates.file-manager or fix the desktop ID."
    ];
  };

  testRoleRegistrationTypoFails = {
    expr = roleValidation.roleSelectionErrors
      testRoleApps
      (testRoleCandidates // { brower = [ "x.desktop" ]; })
      { };
    expected = [
      "xdg.roleCandidates.\"brower\" is not a known role (known roles: browser, document-viewer, file-archiver, file-manager, image-viewer, music-player, office-suite, text-editor, torrent-client, video-player)."
    ];
  };

  testOverrideUnregisteredFails = {
    expr = roleValidation.roleSelectionErrors
      testRoleApps
      testRoleCandidates
      { "application/pdf" = "ghost.desktop"; };
    expected = [
      "xdg.mimeTypeOverrides.\"application/pdf\": references unregistered desktop ID(s) (known IDs: test-browser.desktop, test-document-viewer.desktop, test-file-archiver.desktop, test-file-manager.desktop, test-image-viewer.desktop, test-music-player.desktop, test-office-suite.desktop, test-text-editor.desktop, test-torrent-client.desktop, test-video-player.desktop). Register the app as a candidate for some role, or fix the ID."
    ];
  };
}
