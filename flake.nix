{
  description = "My NixOS configurations.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.05";
    home-manager.url = "github:nix-community/home-manager/release-22.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    nur_rycee.url = "gitlab:rycee/nur-expressions/master";
    nur_rycee.flake = false;
  };

  outputs = inputs:
    let
      patch_nixpkgs = input_nixpkgs: patches:
        let pkgs = input_nixpkgs.legacyPackages.x86_64-linux;
        in pkgs.applyPatches {
          name = "nixpkgs";
          src = pkgs.path;
          inherit patches;
        };

      nixpkgs = patch_nixpkgs inputs.nixpkgs [];

      mk_nixos = path:
        import "${nixpkgs}/nixos/lib/eval-config.nix" {
          system = "x86_64-linux";
          specialArgs = inputs // { inherit nixpkgs; };
          modules = [ path ];
        };

    in {
      nixosConfigurations.jules-pc = mk_nixos host/home;
      nixosConfigurations.jules-work = mk_nixos host/work;

    };
}