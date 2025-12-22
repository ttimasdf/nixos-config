{ config, lib, ... }:
let
  cfg = config.rabit.me;
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
      settings = {
        user.name = cfg.fullname;
        user.email = cfg.email;

        alias = {
          ci = "commit";
        };

        init.defaultBranch = "main";
        # pull.rebase = "false";
        merge.ours.driver = "true";
      } // lib.mkIf sshSigningEnabled {
        gpg.format = "ssh";
        gpg.ssh.allowedSignersFile =
          "${config.home.homeDirectory}/.config/git/allowed_signers";
        user.signingkey =
          "${config.home.homeDirectory}/${pubKeyFileName}";
      };

      ignores = [ "*~" "*.swp" ];
    };
    lazygit.enable = true;
  };

  home.file = lib.mkIf sshSigningEnabled {
    "${pubKeyFileName}".text = cfg.git.sshSigningKey;
    ".config/git/allowed_signers".text =
      let
        signers =
          map (email: "${email} ${cfg.git.sshSigningKey}") cfg.git.allowedSigners;
      in
      lib.concatStringsSep "\n" signers;
  };
}
