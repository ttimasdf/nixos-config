{ config, lib, pkgs, isDarwin, ... }:
{
  programs.tmux = {
    enable = true;
    terminal = "tmux-256color";
    prefix = "C-o";
    mouse = true;
    baseIndex = 1;
    extraConfig = ''
      set -g update-environment 'DISPLAY SSH_ASKPASS SSH_AGENT_PID SSH_CONNECTION WINDOWID XAUTHORITY TERM XMODIFIERS'
    '';
  };
}
