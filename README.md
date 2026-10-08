# Tilt Admin

## Install

`brew install Jleagle/tilt-admin/tilt-admin`

Homebrew compiles it from source on your machine, which needs Xcode 16 or newer
(the Command Line Tools alone are not enough) on macOS 15 or newer.

### Upgrading from the old tap

Up to 1.0.0 the formula lived in this repo, tapped as `jleagle/tilt-admin`
straight from the repo URL, and installed a prebuilt binary. `brew` now reports
that formula as disabled. The new tap has the same name, so untap the old one
before installing:

```
brew uninstall tilt-admin
brew untap jleagle/tilt-admin
brew install Jleagle/tilt-admin/tilt-admin
```

## Configuration

The config is yours to write — it isn't bundled. On launch the app looks for it in
this order:

1. `./tilt-admin.yml` (or `.yaml`) in the current working directory
2. `~/.tilt-admin.yml` (or `.yaml`) — use this for brew installs

The config maps each service to its dependencies; `top_level: true` marks the groups
shown in the sidebar:

```yaml
services:
  service1:
    depends_on: [ service2 ]
    top_level: true
  service2:
    depends_on: [ service3, service4 ]
```
