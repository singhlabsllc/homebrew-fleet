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
      tag:      "v5.1.0a66",
      revision: "19ea0fd7cbef7960bae3df4788f9241adc6ad853"
  version "5.1.0a66"

  # No `depends_on "python@3.13"`, on purpose (fleet#440). The venv is built on macOS's own
  # /usr/bin/python3, the Command Line Tools' Python (3.9 on current macOS), which brew
  # does not manage. A formula that depends on brew's Python can only be installed while
  # that Python is on its latest bottle ("You must brew unpin python@3.13"), so a broken
  # python@3.13 bottle (3.13.16_1 on macOS 26.1: its pyexpat needs a newer libexpat than
  # the system's) held every fleet upgrade hostage and, once unpinned, would have stopped
  # the running fleet. The product is stdlib only and its floor is Python 3.9.
  SYSTEM_PYTHON = "/usr/bin/python3".freeze

  # The build backend, and what it needs to run. They are not unused: brew builds in a
  # sandbox with no network, and the venv has no backend of its own (it sees only the Command Line
  # Tools' pip and setuptools), so pip's isolated build — which fetches
  # pyproject.toml's `hatchling` from PyPI — dies with "No matching distribution found
  # for hatchling". Instead these go into the venv first and the build runs without
  # isolation, so `brew install` needs nothing from PyPI.
  #
  # hatchling is an sdist: it builds itself with its in-tree backend (hatchling.ouroboros).
  # Its dependencies are wheels on purpose. Each one's sdist needs a backend of its own —
  # flit_core, setuptools with setuptools-scm or calver, poetry-core — and each of those
  # would be another resource to carry. All five are pure Python (py3-none-any), so one
  # wheel serves every Mac. The list is hatchling's Requires-Dist on Python 3.9, which
  # includes tomli (hatchling reads pyproject.toml with it below 3.11). hatchling is held
  # at 1.27.0, the newest release that runs on Python 3.9: 1.28.0 and later require 3.10
  # (pip would refuse them, measured on PyPI's requires_python 2026-10-21). A hatchling
  # bump re-reads the list off the sdist's PKG-INFO and checks Requires-Python.
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

  resource "tomli" do
    url "https://files.pythonhosted.org/packages/60/3f/3e3f8fd0919249b0200c80fbc4f9a1e70be19f9883da71dfb7f8b9ab8aca/tomli-2.5.0-py3-none-any.whl"
    sha256 "32a7b79ac57a2e83670ce329ccf675798bc5a2094783a63676866b70503f2e2b"
  end

  resource "trove-classifiers" do
    url "https://files.pythonhosted.org/packages/30/81/0da8afb52a71d0a4f2bd3152357b1a441e393b286374802b9d3addab4ab5/trove_classifiers-2026.9.21.13-py3-none-any.whl"
    sha256 "8b1ff4f9c191b1040b71c37f1e445ab99732911e3cd91de52838453a854d7a17"
  end

  resource "hatchling" do
    url "https://files.pythonhosted.org/packages/8f/8a/cc1debe3514da292094f1c3a700e4ca25442489731ef7c0814358816bb03/hatchling-1.27.0.tar.gz"
    sha256 "971c296d9819abb3811112fc52c7a9751c8d381898f36533bb16f9791e941fd6"
  end

  # pip here is the Command Line Tools' (21.2.4 on Python 3.9), not brew's. It has no
  # `--python` and no `--uploaded-prior-to`, which is why brew's own `venv.pip_install`
  # and `std_pip_args` are not used: they pass both. The venv has no pip of its own
  # (--without-pip) and sees the system's through --system-site-packages, so each step
  # runs the venv's python with `-m pip`, installing into the venv it runs from.
  def pip_into(target, venv_python)
    system venv_python, "-m", "pip", "install", "--verbose", "--no-deps", "--ignore-installed",
           "--no-compile", "--no-build-isolation", "--disable-pip-version-check", "--prefix=#{libexec}", target
  end

  def install
    unless File.executable?(SYSTEM_PYTHON) &&
           quiet_system(SYSTEM_PYTHON, "-c", "import sys; sys.exit(0 if sys.version_info >= (3, 9) else 1)")
      odie "Fleet Command builds on macOS's own Python (/usr/bin/python3, 3.9 or newer), " \
           "and it is missing or too old. Install the Command Line Tools: xcode-select --install"
    end
    virtualenv_create(libexec, SYSTEM_PYTHON)
    venv_python = libexec/"bin/python"
    # Dependencies first, then hatchling, whose own build imports them; then fleet.
    resources.reject { |r| r.name == "hatchling" }.each do |r|
      r.stage { pip_into(Dir["*.whl"].first || Dir.pwd, venv_python) }
    end
    resource("hatchling").stage { pip_into(Dir.pwd, venv_python) }
    pip_into(buildpath, venv_python)
    bin.install_symlink libexec/"bin/fleet"
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

  # The menu bar app is built on the operator's Mac into ~/Applications, and `brew upgrade`
  # never touches it: an app built before an upgrade kept running for weeks, missing every
  # menu-bar change since (fleet#198). It is not rebuilt from here on purpose. A formula
  # must not write outside the keg without being asked, `post_install` runs in brew's
  # sandbox with HOME redirected (so it would build into the wrong ~/Applications), and the
  # rebuild signs, boots out and bootstraps a LaunchAgent in the user's GUI session. So
  # the caveat says it, and the app says it too: `install-menubar.sh --doctor`,
  # `fleet agent --doctor`, /health and the board's Settings page compare the bundle's
  # recorded source hash with this keg's `menubar/src` and print "stale ... rebuild with".
  def caveats
    <<~EOS
      The menu bar app (~/Applications/Fleet Command.app) is built from source on your
      Mac and is NOT rebuilt by `brew upgrade`. If you use it, rebuild it after an upgrade
      that changed it:

        sh #{opt_pkgshare}/service/install-menubar.sh

      `sh #{opt_pkgshare}/service/install-menubar.sh --doctor` (and `fleet agent --doctor`,
      and the board's Settings page) say when it is stale.

      `fleet init` seeds a new FLEET_HOME with a config, a workers file and the starter
      policies. It only creates the files that are missing and never overwrites one, so it
      is safe to re-run. The server also copies any missing starter policy on its first
      start, so `fleet init` is optional.
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/fleet --version")
    ENV["FLEET_HOME"] = testpath/"fleet-home"
    system bin/"fleet", "init"
    assert_match "OK", shell_output("#{bin}/fleet validate")
  end
end
