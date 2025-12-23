{ config, lib, pkgs, isDarwin, ... }:
{
  # https://nix-community.github.io/home-manager/options.xhtml#opt-programs.tmux.enable
  programs.tmux = {
    enable = true;

    # https://search.nixos.org/packages?channel=unstable&query=tmuxPlugins.catppuccin
    plugins = with pkgs; [
        tmuxPlugins.catppuccin
        tmuxPlugins.cpu
        tmuxPlugins.battery
    ];

    extraConfig = ''
        # Options to make tmux more pleasant
        set -g mouse on
        set -g default-terminal "tmux-256color"

        # Configure the catppuccin plugin
        set -g @catppuccin_flavor "mocha"
        set -g @catppuccin_window_status_style "rounded"

        # Load catppuccin
        run-shell ${pkgs.tmuxPlugins.catppuccin}/tmux/catppuccin.tmux
        # For TPM, instead use `run ~/.tmux/plugins/tmux/catppuccin.tmux`

        # Make the status line pretty and add some modules
        set -g status-right-length 100
        set -g status-left-length 100
        set -g status-left ""
        set -g status-right "#{E:@catppuccin_status_application}"
        set -agF status-right "#{E:@catppuccin_status_cpu}"
        set -ag status-right "#{E:@catppuccin_status_session}"
        set -ag status-right "#{E:@catppuccin_status_uptime}"
        set -agF status-right "#{E:@catppuccin_status_battery}"

        run-shell ${pkgs.tmuxPlugins.cpu}/share/tmux-plugins/cpu/cpu.tmux
        run-shell ${pkgs.tmuxPlugins.battery}/share/tmux-plugins/battery/battery.tmux
    '';

  };
}