# Up to 1.0.0 this repo was itself the Homebrew tap: users ran
# `brew tap jleagle/tilt-admin https://github.com/Jleagle/tilt-admin` and the
# release workflow committed a prebuilt-binary formula here. tilt-admin is now
# compiled from source by a formula in the Jleagle/homebrew-tilt-admin tap (see
# homebrew/formula.sh). This file stays, disabled, so that machines still on the
# old tap are told how to move over. The release workflow no longer touches it.
#
# The new tap has the same name, so the old one must be untapped first; see
# "Upgrading from the old tap" in the README.
class TiltAdmin < Formula
  desc "Native macOS app for managing Tilt dev services"
  homepage "https://github.com/Jleagle/tilt-admin"
  url "https://github.com/Jleagle/tilt-admin/releases/download/v1.0.0/tilt-admin-1.0.0-universal-macos.tar.gz"
  sha256 "b83aa9caa15ba174624eb20aec5fd1dd77a6d930394a5db032163350052dec5d"

  disable! date:                "2026-10-08",
           because:             "moved to Jleagle/homebrew-tilt-admin; uninstall and untap jleagle/tilt-admin first",
           replacement_formula: "jleagle/tilt-admin/tilt-admin"

  depends_on :macos

  def install
    bin.install "bin/tilt-admin"
  end
end
