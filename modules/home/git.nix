{ config, lib, osConfig, ... }:
let
  inherit (lib) mkIf;
  cfg = config.rabit.me;
  oscfg = osConfig.rabit.nixos;
  sshSigningEnabled = cfg.git.sshSigningKey != null;

  # Dynamically determine the public key filename from the key content.
  # "ssh-ed25519 ..." -> ".ssh/git-id_ed25519.pub"
  pubKeyFileName = if sshSigningEnabled then
    let
      # "ssh-ed25519"
      keyAlgo = lib.elemAt (lib.strings.splitString " " cfg.git.sshSigningKey) 0;
      # "ed25519"
      keyType = lib.elemAt (lib.strings.splitString "-" keyAlgo) 1;
    in
    ".ssh/git-id_${keyType}.pub"
  else
    null;
in
{
  # https://nixos.asia/en/git
  programs = {
    git = {
      enable = true;
      settings = lib.mkMerge [
        {
          user.name = cfg.fullname;
          user.email = cfg.email;

          alias = {
            ci = "commit";
          };

          credential.helper = "cache --timeout=14400";

          init.defaultBranch = "main";
          # pull.rebase = "false";
          merge.ours.driver = "true";
        }
        (mkIf sshSigningEnabled {
          gpg.ssh.allowedSignersFile =
            "${config.home.homeDirectory}/.config/git/allowed_signers";
        })
        (mkIf (oscfg.http_proxy != null) {
          http."https://github.com".proxy = oscfg.http_proxy;
        })
      ];

      signing = mkIf sshSigningEnabled {
        format = "ssh";
        key = "${config.home.homeDirectory}/${pubKeyFileName}";
      };

      ignores = [ "*~" "*.swp" ];
    };
    lazygit.enable = true;
  };

  home.file = mkIf sshSigningEnabled {
    "${pubKeyFileName}".text = cfg.git.sshSigningKey;
    ".config/git/allowed_signers".text =
      let
        signers =
          map (email: "${email} ${cfg.git.sshSigningKey}") cfg.git.allowedSigners;
      in
      lib.concatStringsSep "\n" signers;
  };
}
