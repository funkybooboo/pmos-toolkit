{
  description = "Toolkit to install postmarketOS on any device: support check, backup, flashing (per-device profiles)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          pmbootstrap # postmarketOS build/flash driver (the actual installer)
          heimdall # Samsung download-mode (Odin protocol) flasher
          android-tools # adb, fastboot
          libmtp # mtp-detect
          simple-mtpfs # FUSE mount for MTP backup
          rsync
          dtc # device tree compiler (for kernel porting)
          strace # debugging apk.static against chroots
          unzip # porter flash-recovery.sh validates the zip first
          python3 # scripts/pmindex.py
        ];
        shellHook = ''
          echo "pmos-toolkit dev shell"
          echo "Start with: scripts/identify.sh && scripts/check-device.sh"
          echo "NOTE: heimdall/fastboot USB access needs root; scripts wrap them with sudo -E."
        '';
      };
    };
}