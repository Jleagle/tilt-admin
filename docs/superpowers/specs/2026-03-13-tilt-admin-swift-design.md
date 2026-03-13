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

## Architecture

### Pure SwiftUI — macOS 14+, Swift 5.9+

Single external dependency: **Yams** for YAML parsing.

### Core Types

**Models:**
- `ServiceConfig` — parsed from YAML: name, depends_on, top_level flag.
- `TiltResource` — parsed from `tilt get uiresource -o json`: name, runtime status (ok/pending/error), update status, enabled state.
- `MergedService` — combines config + Tilt runtime into one view model per service.

**Services:**
- `TiltClient` (actor) — isolates all `Process` subprocess calls. Methods: `fetchResources()`, `enableServices([String])`, `disableServices([String])`. All `async throws`.
- `ConfigLoader` — discovers config file, parses YAML via Yams, builds dependency graph, reports cycles as warnings.
- `DependencyGraph` — transitive dependency resolution, reverse dependency lookups, cycle detection.

**State:**
- `TiltManager` (`@Observable`) — single source of truth shared between main window and menu bar. Holds config, dependency graph, merged services, loading/error state, visibility tracking.

### Refresh Behavior

- Polls `TiltClient.fetchResources()` every 5 seconds.
- Only polls when the main window or menu bar popover is visible.
- Stops polling when both are hidden. Resumes with an immediate fetch when either becomes visible.
- Timer resets on visibility change for immediate data.

### Enable/Disable Flow

- Enabling a service automatically enables all transitive dependencies (resolved via `DependencyGraph`).
- Disabling a service disables only that service (does not cascade to dependents).

## UI — Main Window

`NavigationSplitView` with two columns:

**Sidebar:**
- Top-level services as expandable tree nodes.
- Each node: name, colored status dot (green=ok, yellow=pending, red=error, gray=disabled), disclosure triangle.
- Expanding shows the dependency tree nested underneath.
- Search/filter field at the top.
- Non-top-level services that aren't a dependency of any top-level service appear in an "Other" section.

**Detail pane (on service selection):**
- Service name and status.
- Enable/Disable toggle button.
- Direct dependencies list (clickable navigation).
- "Depended on by" list (reverse deps, clickable).
- When enabling: shows transitive dependencies that will also be enabled.

**Status indicators:** Green (ok), yellow (pending), red (error), gray (disabled).

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
