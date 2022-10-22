{
  description = "Testing Bluetooth on a Raspberry Pi 4B";

  inputs = {
    nixpkgs = {
      url = github:NixOS/nixpkgs/nixos-22.05;
    };
    flake-utils-plus = {
      url = github:gytis-ivaskevicius/flake-utils-plus/v1.3.1;
    };
  };

  outputs = { self, nixpkgs, flake-utils-plus }@attrs: rec {
    nixosConfigurations.btpi = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules = [
        ({ config, lib, ... }: flake-utils-plus.nixosModules.autoGenFromInputs { inputs = attrs; inherit config; inherit lib; })
        {
          nix.generateNixPathFromInputs = true;
        }
        ({ pkgs, lib, ... }: {
          
          # Host
          networking.hostName = "btpi";
          system.stateVersion = "22.05";

          # Flakes
          nix.settings.experimental-features = [ "nix-command" "flakes" ];
          nix.settings.trusted-users = [ "root" "@wheel" ];

          # SD card longevity
          fileSystems."/".options = [ "noatime" ];

          # Kernel
          boot.kernelPackages = pkgs.linuxPackages_rpi4;
          boot.kernelParams = lib.mkForce [ "8250.nr_uarts=1" "console=ttyS0,115200n8" "console=tty0" ];

          # User
          users.users.test = {
            isNormalUser = true;
            initialPassword = "test";
            extraGroups = [ "wheel" ];
          };

          # SSH
          services.openssh = {
            enable = true;
            permitRootLogin = "no";
          };
          networking.firewall.allowedTCPPorts = [ 22 ];

          # Bluetooth
          hardware.bluetooth.enable = true;

          # SD image
          sdImage.compressImage = false;
          imports = [
            "${nixpkgs}/nixos/modules/installer/sd-card/sd-image.nix"
            "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
          ];
          disabledModules = [
            "profiles/all-hardware.nix"
            "profiles/base.nix"
          ];

          # Edit config.txt
          #
          # These changes will only be reflected in the SD image and are
          # not applied upon system activation.
          sdImage.populateFirmwareCommands = lib.mkAfter ''
            chmod u+w firmware/config.txt
            cat <<EOF >> firmware/config.txt

            # Configure bluetooth controller
            dtparam=krnbt=on
            
            EOF
            chmod u-w firmware/config.txt
          '';

        })
      ];
    };

    packages.x86_64-linux = {
      btpi-sd = nixosConfigurations.btpi.config.system.build.sdImage;
    };
  };
}
