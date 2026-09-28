{ config, inputs, lib, pkgs, user, ... }:

let
  nixConfig = "${config.home.homeDirectory}/.nix-config";

  # Not in nixpkgs; packaged from the published npm tarball. See ccstatusline.nix.
  ccstatusline = pkgs.callPackage ./ccstatusline.nix { };

  # Built against the flake's own nixpkgs on purpose - see the input comment in
  # flake.nix. Derived from hostPlatform rather than written out again, so the
  # architecture stays named in exactly one place.
  claude-code =
    inputs.claude-code-nix.packages.${pkgs.stdenv.hostPlatform.system}.default;
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
    # languages, tracking whatever nixpkgs defaults to on the pinned channel.
    # a channel bump can move these across majors; use python314 / nodejs_26 to pin.
    python3     # 3.13.15 on nixpkgs 26.05
    uv          # venvs + package installs for python (pip cant write to the nix store)
    nodejs      # 24.19.0 on nixpkgs 26.05 (the LTS line)
    pnpm        # 11.25.0, installed directly rather than through corepack

    # claude code, and the statusline wired into ~/.claude/settings.json below
    claude-code
    ccstatusline

    # the font everything renders in
    nerd-fonts.hack

  ];
  fonts.fontconfig.enable = true;
  home.sessionVariables = {
    EDITOR = "zed";
    # `npm -g` and `pnpm add -g` need a writable prefix; the nix store is read-only.
    npm_config_prefix = "${config.home.homeDirectory}/.npm-global";
    PNPM_HOME = "${config.home.homeDirectory}/Library/pnpm";  # pnpms own default on darwin
  };
  home.sessionPath = [
    "${config.home.homeDirectory}/.npm-global/bin"
    "${config.home.homeDirectory}/Library/pnpm"
  ];

  # Point Claude Code at ccstatusline. This runs during home-manager activation,
  # which the generated activate script sequences after the Homebrew bundle, so
  # the claude-code cask is already installed by the time we get here.
  #
  # ~/.claude/settings.json is shared with Claude Code and edited by hand, so
  # this merges rather than writes: it sets only `type` and `command` - where the
  # binary is, which is Nix's business - and leaves everything else alone,
  # including cosmetic statusLine keys like `padding` and `refreshInterval` that
  # ccstatusline's own TUI manages. The tool's config lives in
  # ~/.config/ccstatusline/settings.json and is not touched here.
  home.activation.claudeStatusLine =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      ${lib.getExe pkgs.python3} ${./claude-statusline.py} \
        "${config.home.homeDirectory}/.claude/settings.json" \
        "${ccstatusline}/bin/ccstatusline"
    '';

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
