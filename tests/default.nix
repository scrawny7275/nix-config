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
}
