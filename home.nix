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
  codex =
    inputs.codex-cli-nix.packages.${pkgs.stdenv.hostPlatform.system}.default;
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

    # claude code and codex, and the statusline wired into ~/.claude/settings.json below
    claude-code
    codex
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

  # Matt Pocock's skills (github.com/mattpocock/skills), installed with the
  # cross-agent `skills` CLI after Node, Claude Code and Codex are in place. One
  # copy lands in ~/.agents/skills, which Codex reads directly; Claude Code gets a
  # link per skill in ~/.claude/skills. Both agents are named rather than left to
  # auto-detection, which goes by whether ~/.claude and ~/.codex exist - on a fresh
  # machine they may not yet. Node comes from the store, so PATH doesn't matter.
  #
  # Installs once, then leaves the skills alone: re-running `add` overwrites the
  # files, and they are meant to be edited. Update deliberately with
  # `npx skills update -g`. Never fails the switch - it needs the network, and a
  # missing skill set shouldn't stop the rest of the machine from building.
  home.activation.mattPocockSkills =
    lib.hm.dag.entryAfter [ "writeBoundary" "claudeStatusLine" ] ''
      skillsLock="${config.home.homeDirectory}/.agents/.skill-lock.json"
      if [ -f "$skillsLock" ] && grep -q '"mattpocock/skills"' "$skillsLock"; then
        verboseEcho "Matt Pocock's skills already installed; leaving them as they are"
      else
        skillsLog="$(mktemp)"
        # cd ~ so the CLI doesn't treat the repo build.sh ran from as a project;
        # stdin from /dev/null so it can never sit waiting on a prompt.
        if (cd "${config.home.homeDirectory}" &&
            PATH="${pkgs.nodejs}/bin:/usr/bin:/bin:$PATH" \
              run npx -y skills@latest add mattpocock/skills -g -y \
                -a claude-code codex \
              </dev/null >"$skillsLog" 2>&1); then
          echo "Installed Matt Pocock's skills into ~/.agents/skills"
        else
          echo "warning: Matt Pocock's skills were not installed; log follows" >&2
          tail -n 20 "$skillsLog" >&2
        fi
        rm -f "$skillsLog"
      fi
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

  # GitHub CLI. Logging in stays manual - run `gh auth login` once; the token goes
  # to the macOS keychain, not the nix store. gh/config.yml becomes a read-only
  # link into the store, so change settings here rather than with `gh config set`.
  programs.gh = {
    enable = true;
    settings = {
      git_protocol = "https";
      # gh needs an editor that blocks until the file is closed; bare `zed`
      # returns immediately and gh would read back an empty PR body.
      editor = "zed --wait";
    };
    # On by default: makes git use gh's login for github.com over https.
    gitCredentialHelper.enable = true;
  };

  # The credential helper above is written into git's config, which home-manager
  # only writes when programs.git is enabled. package = null keeps using the
  # system git rather than installing a second one. This writes
  # ~/.config/git/config, which git reads alongside ~/.gitconfig, so the name and
  # email already in ~/.gitconfig keep working.
  programs.git = {
    enable = true;
    package = null;
    # With home.stateVersion 24.11 this defaults to openpgp, which writes a [gpg]
    # section and pulls gnupg in. Commits aren't signed here, so leave it unset.
    signing.format = null;
  };

  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;      # ghost text from history
    syntaxHighlighting.enable = true;  # commands turn green when valid
    initContent = lib.mkMerge [
      ''
        bindkey '^f' autosuggest-accept
      ''
      # Machine-local layer on top of everything Nix generates: PATH entries,
      # aliases, exports - anything you want without a rebuild. Nix never creates
      # or touches ~/.zshrc.local. Order 2000 puts it after all of home-manager's
      # own init (its highest is 1250), so its settings win. `if` rather than
      # `[[ ]] &&`, so a missing file doesn't leave the first prompt showing a
      # failed exit status.
      (lib.mkOrder 2000 ''
        if [[ -r ~/.zshrc.local ]]; then source ~/.zshrc.local; fi
      '')
    ];
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
