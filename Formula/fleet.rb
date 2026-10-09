# Homebrew formula for Fleet Command, published through a private tap.
#
# This is the TEMPLATE the tap is written from, not the copy brew reads. `service/tap.sh`
# copies it into the tap's Formula/fleet.rb and fills in the two values that cannot live
# in this repository:
#
#   url       the real forge account. This tree is a clean-room export, so the account
#             is spelled `acme` here (SANITIZATION.md, "org or forge account"); tap.sh
#             reads the real one off this checkout's `origin` remote. It is written as
#             a URI, ssh://git@host/owner/repo.git: brew parses the url with Ruby's URI,
#             which refuses the scp-style git@host:owner/repo.git that git remotes
#             usually use ("bad URI (is not URI?)"), and tap.sh rewrites that form.
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
  homepage "https://github.com/psingh24/fleet"
  url "ssh://git@github.com/psingh24/fleet.git",
      tag:      "v5.1.0a39",
      revision: "9819078d144347a4d422fed0140e74d95a84ed89"
  version "5.1.0a39"

  depends_on "python@3.13"

  # The build backend, and what it needs to run. They are not unused: brew builds in a
  # sandbox with no network, and the venv has no backend of its own (brew's python@3.13
  # ships pip and wheel, nothing else), so pip's isolated build — which fetches
  # pyproject.toml's `hatchling` from PyPI — dies with "No matching distribution found
  # for hatchling". Instead these go into the venv first and the build runs without
  # isolation, so `brew install` needs nothing from PyPI.
  #
  # hatchling is an sdist: it builds itself with its in-tree backend (hatchling.ouroboros).
  # Its dependencies are wheels on purpose. Each one's sdist needs a backend of its own —
  # flit_core, setuptools with setuptools-scm or calver, poetry-core — and each of those
  # would be another resource to carry. All five are pure Python (py3-none-any), so one
  # wheel serves every Mac. The list is hatchling's Requires-Dist on Python 3.13; a
  # hatchling bump re-reads it off the sdist's PKG-INFO.
  resource "packaging" do
    url "https://files.pythonhosted.org/packages/63/34/ba1c580383c9eada3711951fef0795c80b829a078d72188184bcab9dd527/packaging-26.3-py3-none-any.whl"
    sha256 "d7193f7c8e4e93f444fde0262bf90af30e16fa0ad0ad44cb553c87339b23cd1c"
  end

  resource "pathspec" do
    url "https://files.pythonhosted.org/packages/f1/d9/7fb5aa316bc299258e68c73ba3bddbc499654a07f151cba08f6153988714/pathspec-1.1.1-py3-none-any.whl"
    sha256 "a00ce642f577bf7f473932318056212bc4f8bfdf53128c78bbd5af0b9b20b189"
  end

  resource "pluggy" do
    url "https://files.pythonhosted.org/packages/54/20/4d324d65cc6d9205fabedc306948156824eb9f0ee1633355a8f7ec5c66bf/pluggy-1.6.0-py3-none-any.whl"
    sha256 "e920276dd6813095e9377c0bc5566d94c932c33b27a3e3945d8389c374dd4746"
  end

  resource "tomlkit" do
    url "https://files.pythonhosted.org/packages/13/bc/8c13eb66537dce1d2bd3a57132902f38d0e7f5bb46fa9f4daed9fe9d76ee/tomlkit-0.15.1-py3-none-any.whl"
    sha256 "177a05aece5a8ca5266fd3c448abb47b8d352f09d477d3ca8332db4d89b24304"
  end

  resource "trove-classifiers" do
    url "https://files.pythonhosted.org/packages/30/81/0da8afb52a71d0a4f2bd3152357b1a441e393b286374802b9d3addab4ab5/trove_classifiers-2026.9.21.13-py3-none-any.whl"
    sha256 "8b1ff4f9c191b1040b71c37f1e445ab99732911e3cd91de52838453a854d7a17"
  end

  resource "hatchling" do
    url "https://files.pythonhosted.org/packages/f6/97/b5312f01a8c6daf729a9d272dd442e0c546dbcc630495788786c4b567ed0/hatchling-1.32.4.tar.gz"
    sha256 "c4468f73144c054d2aab4ef0f0378c43b9878bf07f8ffd6b79690e970d375f07"
  end

  def install
    venv = virtualenv_create(libexec, "python3.13")
    # Dependencies first, then hatchling, whose own build imports them; then fleet.
    venv.pip_install resources.reject { |r| r.name == "hatchling" }, build_isolation: false
    venv.pip_install resource("hatchling"), build_isolation: false
    venv.pip_install_and_link buildpath, build_isolation: false
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
