# Tilt Admin

## Install

```sh
brew tap jleagle/tilt-admin https://github.com/Jleagle/tilt-admin
brew trust --tap jleagle/tilt-admin
brew install tilt-admin
```

(The `brew trust` step is required when `HOMEBREW_REQUIRE_TAP_TRUST` is set.)

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
