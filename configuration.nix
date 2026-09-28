{ user, ... }:
{
  # Determinate already manages the Nix daemon, so nix-darwin shouldn't.
  nix.enable = false;

  nixpkgs.config.allowUnfree = true;
  nixpkgs.hostPlatform = "aarch64-darwin"; # use x86_64-darwin for Intel CPU

  system.primaryUser = user;
  users.users.${user} = {
    home = "/Users/${user}";
  };

  system.stateVersion = 6;
  system.defaults = {
    NSGlobalDomain = {
      AppleInterfaceStyle = "Dark";
      KeyRepeat = 2;          # fast key repeat
      InitialKeyRepeat = 15;  # short delay before repeat
      _HIHideMenuBar = false;  # auto-hide the menu bar
      AppleShowAllExtensions = true;
    };
    dock.autohide = true;
    finder.FXPreferredViewStyle = "Nlsv";  # list view by default
#    finder.CreateDesktop = false;          # clean desktop
    trackpad.Clicking = true;              # tap to click

    # Accessibility > Display > Text Size = 16pt (see also postActivation below).
    # macOS stores the slider as a size category, not points; these are the
    # values it writes for 16pt. Apps may need a relaunch to pick it up.
    CustomUserPreferences.NSGlobalDomain.UIPreferredContentSizeCategoryName = "UICTContentSizeCategoryXXXL";
  };

  # com.apple.universalaccess is protected: writing it needs Full Disk Access for
  # the terminal running the rebuild. Done here instead of CustomUserPreferences
  # so a missing permission only warns instead of aborting the whole switch.
  # customFonts switches the slider off "Default"; FontSizeCategory picks the size.
  system.activationScripts.postActivation.text = ''
    if ! { launchctl asuser "$(id -u -- ${user})" sudo --user=${user} -- \
             defaults write com.apple.universalaccess customFonts -bool true &&
           launchctl asuser "$(id -u -- ${user})" sudo --user=${user} -- \
             defaults write com.apple.universalaccess FontSizeCategory -dict-add global XXL; } 2>/dev/null; then
      echo "warning: couldn't set Text Size (com.apple.universalaccess)." >&2
      echo "  Give your terminal Full Disk Access (System Settings > Privacy & Security), then rebuild." >&2
    fi
  '';

  nix-homebrew = {
    enable = true;
    inherit user;
  };
  homebrew = {
    enable = true;
    onActivation.cleanup = "zap";  # remove anything not listed here
    onActivation.autoUpdate = true;
    onActivation.extraFlags = [ "--force" ];
    brews = [
      "herdr"
    ];
    casks = [
      "karabiner-elements"
      "claude"        # desktop app; the CLI comes from claude-code-nix
      "ghostty"
      "slack"
      "zed"
    ];
  };

}
