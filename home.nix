{ config, pkgs, user, ... }:

let
  nixConfig = "${config.home.homeDirectory}/.nix-config";
in

{
  home.username = user;
  home.homeDirectory = "/Users/${user}";
  home.stateVersion = "24.11";
  home.packages = with pkgs; [
    # cli i use constantly
    #ripgrep   # fast search
    #fd        # fast find
    #fzf       # fuzzy finder
    #jq        # json on the command line
    #lazygit
    # the font everything renders in
    nerd-fonts.hack

  ];
  fonts.fontconfig.enable = true;
  home.sessionVariables.EDITOR = "zed";

  # Zed itself is installed by the Homebrew cask; Home Manager only manages its config.
  programs.zed-editor = {
    enable = true;
    package = null;  # don't install a second copy from nixpkgs
    # Zed extensions to auto-install, e.g. [ "nix" "toml" ]
    extensions = [ "nix" ];
    # Merged into ~/.config/zed/settings.json on each switch. Nix values win;
    # anything you change in Zed's UI that isn't listed here is kept.
    userSettings = {
      project_panel.dock = "left";
      agent.sidebar_side = "right";  # Threads Sidebar
      cli_default_open_behavior = "new_window";
      ui_font_size = 16;
      buffer_font_size = 15;
      theme = {
        mode = "system";
        light = "One Light";
        dark = "Gruvbox Dark Hard";
      };
    };
  };

  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;      # ghost text from history
    syntaxHighlighting.enable = true;  # commands turn green when valid
    initContent = ''
      bindkey '^f' autosuggest-accept
    '';
    shellAliases = {
      ".." = "cd ..";
      add = "git add .";
      push = "git push";
      pull = "git pull";
      m = "git switch main";
      # cc = "claude --dangerously-skip-permissions";
      co = "codex --full-auto";
    };

    oh-my-zsh = {
      enable = true;
      theme = "gnzh";
      plugins = [
#        "sudo"
#        "terraform"
#        "systemadmin"
#        "vi-mode"
      ];
    };

  };

}
