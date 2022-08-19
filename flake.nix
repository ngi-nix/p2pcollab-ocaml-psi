{
  description = "FSQ library in OCaml";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-22.05";
    # flake-utils.url = "github:numtide";
    psi-src = {
      url = github:p2pcollab/ocaml-psi;
      flake = false;
    };
  };
  
  outputs = { self, nixpkgs, flake-utils, psi-src }:
    let
      # Generate a user-friendly version numer.
      version = builtins.substring 0 8 psi-src.lastModifiedDate;
      
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "armv7l-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      
      supportedOcamlPackages = [
        "ocamlPackages_4_10"
        "ocamlPackages_4_11"
        "ocamlPackages_4_12"
        "ocamlPackages_4_13"
      ];
      defaultOcamlPackages = "ocamlPackages_4_13";

      forAllOcamlPackages = nixpkgs.lib.genAttrs (supportedOcamlPackages ++ [ "ocamlPackages" ]);
      forAllSystems = f: nixpkgs.lib.genAttrs supportedSystems (system: f system);
      
      nixpkgsFor =
        forAllSystems (system:
          import nixpkgs {
            inherit system;
            overlays = [ self.overlays.default ];
          });
    in {
        overlays.default = final: prev:
          with final;
          let mkOcamlPackages = prevOcamlPackages:
                with prevOcamlPackages;
                let ocamlPackages = {
                      inherit ocaml;
                      inherit findlib;
                      inherit ocamlbuild;
                      inherit opam-file-format;
                      inherit buildDunePackage;
                      inherit version;
                      name = "ocaml-packages";

                      psi = buildDunePackage rec {
                        # inherit version;
                        minimumOCamlVersion = "4.10";
                        enableParallelBuilding = true;
                        pname = "psi";
                        version = "0.0.1";
                        src = self;

                        useDune2 = true;
                        doCheck = true;
                        
                        nativeBuildInputs = with ocamlPackages; [ odoc ];

                        propagatedBuildInputs = with ocamlPackages; [
                          psq
                          nocrypto
                          hkdf
                        ];
                        
                        checkInputs = [
                          psq
                          ounit
                          nocrypto
                          hkdf
                        ];

                        meta = with lib; {
                          homepage = "https://github.com/p2pcollab/ocaml-psi";
                          description = "PSI is a collection of Private Set Intersection protocols.";
                          license = licenses.mpl20;
                        };
                      };
                    };
                in ocamlPackages;
          in
            let allOcamlPackages =
                  forAllOcamlPackages (ocamlPackages:
                    mkOcamlPackages ocaml-ng.${ocamlPackages});
            in
              allOcamlPackages // {
                ocamlPackages = allOcamlPackages.${defaultOcamlPackages};
              };

        packages = 
          forAllSystems (system:
            forAllOcamlPackages (ocamlPackages:
              nixpkgsFor.${system}.${ocamlPackages}));

        defaultPackage =
          forAllSystems (system:
            nixpkgsFor.${system}.ocamlPackages.psi);
      };
}