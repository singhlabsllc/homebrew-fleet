# Homebrew formula for Fleet Command, published through a private tap.
#
# This is the TEMPLATE the tap is written from, not the copy brew reads. `service/tap.sh`
# copies it into the tap's Formula/fleet.rb and fills in the two values that cannot live
# in this repository:
#
#   url       the real forge account. This tree is a clean-room export, so the account
#             is spelled `acme` here (SANITIZATION.md, "org or forge account"); tap.sh
#             reads the real one off this checkout's `origin` remote.
#   revision  the commit the release tag points at, known only once the tag exists.
#
# The version below is held equal to fleet_command.__version__ by tests/test_homebrew.py,
# so a release that forgets this file fails the suite. It is the PEP 440 string as is:
# brew's Version orders 5.1.0a24 < 5.1.0a25 < 5.1.0a26 < 5.1.0, measured 2026-10-01.
#
# The source is fetched over SSH from a private repository, so anyone whose SSH key can
# read it can install; there is no token and nothing tied to one person.
class Fleet < Formula
  include Language::Python::Virtualenv

  desc "Work router and board for AI coding agents"
  homepage "https://github.com/psingh24/fleet-command"
  url "ssh://git@github.com/psingh24/fleet-command.git",
      tag:      "v5.1.0a26",
      revision: "6aced580f8ef38f57f94841a92e2218377bab2f8"
  version "5.1.0a26"

  depends_on "python@3.13"

  def install
    venv = virtualenv_create(libexec, "python3.13")
    venv.pip_install_and_link buildpath
    # The menu bar's source and the service scripts, which the wheel does not carry.
    # Under pkgshare they are reached through opt/fleet/share/fleet, a path an upgrade
    # does not move: service/install-menubar.sh builds from there on a brew install.
    pkgshare.install "menubar", "service"
  end

  # `brew services start fleet` runs this. One instance per formula is all brew services
  # allows, so this is the machine's one brew-run fleet; a staging or dev fleet beside it
  # stays on service/dev.sh or a LaunchAgent of its own (install-service.sh with its own
  # LABEL, FLEET_HOME and CODE).
  #
  # FLEET_HOME is written with its tilde on purpose. launchd does not expand one, and
  # fleet does (config.HOME is expanduser'd), so the server resolves it under the home of
  # whoever started the service. To point this service at another home, or to add a
  # backend CLI's directory to its PATH, put the line in brew's per-user override file,
  # services/fleet.env under HOMEBREW_USER_CONFIG_HOME, and restart the service;
  # docs/homebrew.md has the details.
  #
  # PATH is brew's standard service PATH. It holds brew's own bin, so a tmux or a
  # git from brew is found; a backend CLI installed elsewhere, such as an app bundle's
  # bin directory, is not, and `fleet health` from a shell cannot tell you, because the
  # shell has it.
  service do
    run [opt_bin/"fleet", "serve"]
    environment_variables FLEET_HOME: "~/.config/fleet", PATH: std_service_path_env
    keep_alive true
    process_type :background
    working_dir var
    # One file for both streams, as the LaunchAgent has: the server's traceback belongs
    # beside the line it interrupted.
    log_path var/"log/fleet.log"
    error_log_path var/"log/fleet.log"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/fleet --version")
    ENV["FLEET_HOME"] = testpath/"fleet-home"
    system bin/"fleet", "init"
    assert_match "OK", shell_output("#{bin}/fleet validate")
  end
end
