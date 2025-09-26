{
  # set users.users.<name> options here
  # https://search.nixos.org/options?channel=unstable&query=users.users

  extraGroups = [
    "wheel"       # Enable ‘sudo’ for the user.
    "wireshark"   # for programs.wireshark
    "input"       # for services.espanso
  ];
}
