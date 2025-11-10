{ config, ... }:
{
  home.shellAliases = {
    g = "git";
    lg = "lazygit";
  };

  # https://nixos.asia/en/git
  programs = {
    git = {
      enable = true;
      settings = {
        user.name = config.rabit.me.fullname;
        user.email = config.rabit.me.email;

        alias = {
          ci = "commit";
        };

        init.defaultBranch = "main";
        # pull.rebase = "false";
      };

      ignores = [ "*~" "*.swp" ];
    };
    lazygit.enable = true;
  };

}
