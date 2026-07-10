# Tilt Admin

## Build

```sh
swift build                 # debug build
swift build -c release      # release build
swift test                  # run tests
```

## Run

Needs the `tilt` CLI (`brew install tilt`) and a running Tilt session.

```sh
swift run TiltAdmin         # from source
tilt-admin                  # brew install
```

The app lives in the menu bar (circular-arrows icon) and also opens a main window.
Closing the window keeps it running in the menu bar.

## Configuration

On launch the app looks for a config in this order:

1. `./dependencies.yml` (or `.yaml`) in the current working directory
2. `~/.config/tilt-admin/config.yaml`

The config maps each service to its dependencies; `top_level: true` marks the groups
shown in the sidebar:

```yaml
services:
  Chive:
    depends_on: [ keystone-group ]
    top_level: true
  assemble:
    depends_on: [ ch-datastore, ch-redis ]
```
