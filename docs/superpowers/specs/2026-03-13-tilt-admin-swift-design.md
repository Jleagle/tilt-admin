# Tilt Admin — Native macOS Swift App

## Overview

A native macOS SwiftUI app that manages Tilt services. It reads a YAML config defining service dependencies, talks to the Tilt CLI to get live status and enable/disable services, and automatically resolves dependencies when enabling a service. Runs as both a menu bar app and a full windowed app.

## YAML Configuration

Simplified format with `top_level` replacing the old `group` concept:

```yaml
services:
  traefik:
    depends_on: []
    top_level: true
  chargehive-namespace:
    depends_on: [traefik]
  chargehive-assemble:
    depends_on: [chargehive-namespace, chargehive-db]
    top_level: true
  chargehive-db:
    depends_on: [chargehive-namespace]
```

- `top_level: true` marks services that appear as root nodes in the sidebar hierarchy.
- `depends_on` lists direct dependencies.
- Services in Tilt but not in the YAML are shown without dependency info.

Config discovery order: `./dependencies.yml` → `./dependencies.yaml` → `~/.config/tilt-admin/config.yaml`.

The existing Rust `dependencies.yml` uses the same `services` → `depends_on` structure but includes `group` fields. Migration: remove `group` keys and add `top_level: true` to the services that were group roots. This is a one-time manual edit of the YAML file.

Config is loaded once on startup. Editing the YAML while the app is running requires a restart to pick up changes.

## Architecture

### Pure SwiftUI — macOS 14+, Swift 5.9+

Single external dependency: **Yams** for YAML parsing.

### Core Types

**Models:**
- `ServiceConfig` — parsed from YAML: name, depends_on, top_level flag.
- `TiltResource` — parsed from `tilt get uiresource -o json`. Response is a K8s-style List; iterate over `items`. Key JSON paths per item: `metadata.name` for the service name, `status.runtimeStatus` (ok/pending/error/not_applicable), `status.updateStatus` (ok/pending/in_progress/error/not_applicable), and `status.disableStatus.disabled` (bool) for enabled state.
- `MergedService` — combines config + Tilt runtime into one view model per service.

**Services:**
- `TiltClient` (actor) — isolates all `Process` subprocess calls. Methods: `fetchResources()` runs `tilt get uiresource -o json`, `enableServices([String])` runs `tilt enable svc1 svc2 ...` (batched into a single command), `disableServices([String])` runs `tilt disable svc1 svc2 ...`. All `async throws` with a 10-second timeout per subprocess call. On startup, validates that `tilt` is in `$PATH` — if not, sets a persistent error state shown in the UI ("Tilt CLI not found"). Only one enable/disable operation runs at a time; the UI disables toggles while an operation is in flight.
- `ConfigLoader` — discovers config file, parses YAML via Yams, builds dependency graph. Reports cycles as warnings in the UI. Services involved in a cycle can still be enabled individually, but transitive resolution stops at cyclic edges to prevent infinite loops.
- `DependencyGraph` — transitive dependency resolution, reverse dependency lookups, cycle detection.

**State:**
- `TiltManager` (`@Observable`) — single source of truth shared between main window and menu bar. Holds config, dependency graph, merged services, loading/error state, visibility tracking.

### Refresh Behavior

- Polls `TiltClient.fetchResources()` every 5 seconds.
- Only polls when the main window or menu bar popover is visible.
- Visibility tracked via `onAppear`/`onDisappear` on the main content view and popover view, incrementing/decrementing a visibility counter on `TiltManager`.
- Stops polling when counter reaches 0. Resumes with an immediate fetch when counter goes above 0.
- On app launch, polling does not start until a view becomes visible (the menu bar icon alone does not count).

### Enable/Disable Flow

- Enabling a service automatically enables all transitive dependencies (resolved via `DependencyGraph`).
- Disabling a service disables only that service (does not cascade to dependents).
- Enable/disable is a single batched `tilt enable/disable` call. If it fails, the error is shown in the UI and the next refresh cycle will reflect the actual Tilt state. No rollback — Tilt itself is the source of truth for what's enabled.

## UI — Main Window

`NavigationSplitView` with two columns:

**Sidebar:**
- Top-level services as expandable tree nodes.
- Each node: name, colored status dot (green=ok, yellow=pending, red=error, gray=disabled), disclosure triangle.
- Expanding shows the dependency tree nested underneath.
- Search/filter field at the top. Filters by service name substring match, searches within collapsed trees (matching children are revealed).
- Non-top-level services that aren't a transitive dependency of any top-level service appear in an "Other" section. This includes both services defined in the YAML without a top-level ancestor and services found in Tilt but not in the YAML. Services not in the YAML show a subtle "unconfigured" indicator.

**Detail pane (on service selection):**
- Service name and status.
- Enable/Disable toggle button.
- Direct dependencies list (clickable navigation).
- "Depended on by" list (reverse deps, clickable).
- When enabling: shows transitive dependencies that will also be enabled.

**Status indicators:** Green (ok), yellow (pending), red (error), gray (disabled or not_applicable).

## UI — Menu Bar

`MenuBarExtra` with popover style:

- Tilt icon always present in menu bar.
- Popover shows compact list of top-level services only: name, status dot, toggle switch.
- Toggle enables/disables with automatic dependency resolution (no confirmation).
- Footer: status line (e.g., "12/45 enabled") and "Open Tilt Admin" button.
- "Quit" option at the bottom.

**Window management:**
- Menu bar icon always present while app runs.
- Main window opens/closes independently.
- Closing main window does not quit the app.

## Migration

The existing Rust/egui project files (`Cargo.toml`, `src/`, `Cargo.lock`) will be removed. The `dependencies.yml` config file is kept and updated to the new format. This is a full rewrite, not a port — the Rust code serves as reference only.

## Project Structure

```
tilt-admin/
├── Package.swift
├── Sources/
│   └── TiltAdmin/
│       ├── TiltAdminApp.swift        # App entry, MenuBarExtra + Window
│       ├── Models/
│       │   ├── ServiceConfig.swift
│       │   ├── TiltResource.swift
│       │   └── MergedService.swift
│       ├── Services/
│       │   ├── TiltClient.swift
│       │   ├── ConfigLoader.swift
│       │   └── DependencyGraph.swift
│       ├── State/
│       │   └── TiltManager.swift
│       └── Views/
│           ├── MainWindow.swift
│           ├── ServiceSidebar.swift
│           ├── ServiceDetail.swift
│           └── MenuBarPopover.swift
├── Tests/
│   └── TiltAdminTests/
│       ├── DependencyGraphTests.swift
│       └── ConfigLoaderTests.swift
└── dependencies.yml
```

## Testing

- `DependencyGraphTests` — transitive resolution, reverse deps, cycle detection.
- `ConfigLoaderTests` — YAML parsing, missing file handling, malformed config.
- Tilt CLI integration is not unit tested (requires running Tilt); manual testing only.
