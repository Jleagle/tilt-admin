class TiltAdmin < Formula
  desc "Native macOS app for managing Tilt dev services"
  homepage "https://github.com/jleagle/tilt-admin"
  url "https://github.com/jleagle/tilt-admin/releases/download/v1.0.0/tilt-admin-1.0.0-universal-macos.tar.gz"
  sha256 "b83aa9caa15ba174624eb20aec5fd1dd77a6d930394a5db032163350052dec5d"
  version "1.0.0"

  depends_on :macos

  def install
    bin.install "bin/tilt-admin"
  end

  def caveats
    <<~EOS
      tilt-admin needs a config describing your Tilt service dependencies.
      Create one at ~/.tilt-admin.yml — see
      https://github.com/jleagle/tilt-admin#configuration
    EOS
  end
end
