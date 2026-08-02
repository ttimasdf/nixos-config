{ config, lib, ... }:
let
  cfg = config.rabit.home.pi;
in
{
  options.rabit.home.pi.agents = lib.mkOption {
    type = lib.types.nullOr lib.types.lines;
    default = null;
    description = "Contents of Pi's global AGENTS.md context file.";
  };

  config = lib.mkIf (cfg.agents != null) {
    home.file.".pi/agent/AGENTS.md".text = cfg.agents;
  };
}
