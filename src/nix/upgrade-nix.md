R""(

# Examples

* Upgrade Nix to the stable version declared in Nixpkgs:

  ```console
  # nix upgrade-nix
  ```

* Upgrade Nix in a specific profile:

  ```console
  # nix upgrade-nix --profile ~alice/.local/state/nix/profiles/profile
  ```

# Description

This command upgrades Lix to the latest stable version.
This stable version is defined in [the Lix manifest](https://releases.lix.systems/manifest.nix)
and updated manually. It may not always be the latest tagged release.

By default, it locates the directory containing the `nix` binary in the `$PATH`
environment variable. If that directory is a Nix profile, it will
upgrade the `nix` package in that profile to the latest stable binary
release.

You cannot use this command to upgrade Nix in the system profile of a
NixOS system (that is, if `nix` is found in `/run/current-system`).

)""
