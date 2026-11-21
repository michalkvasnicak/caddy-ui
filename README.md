# Caddy UI

A macOS 14+ menu bar app for running a dedicated Caddy instance and managing local reverse proxies. It does not modify an existing Caddyfile or control Homebrew services.

## Install and open

With the Xcode command-line tools installed:

```sh
brew install caddy
make app
open .build/CaddyUI.app
```

Use the server icon in the menu bar to start or stop Caddy or open **Manage Targets…**. Add a hostname such as `app.localhost` and an upstream such as `127.0.0.1:3000`, then visit `http://app.localhost:8080`. The listener is IPv4 loopback only, uses HTTP, and requires port 8080 to be free. Frontend hostnames must be `localhost` or end in `.localhost`; upstreams use a hostname or IPv4 address and a port.

Edits are saved immediately and loaded into the running instance. If a reload fails, the saved changes are kept; retry from the targets window or restart Caddy. Quitting the app requests shutdown of its Caddy process. Targets and Caddy logs live in `~/Library/Application Support/CaddyUI/`.

## Local MCP

Keep the menu bar app open. In a client that supports stdio MCP servers, point it at the app executable using an absolute path:

```json
{
  "mcpServers": {
    "caddy-ui": {
      "command": "/absolute/path/to/.build/CaddyUI.app/Contents/MacOS/CaddyUI",
      "args": ["--mcp"]
    }
  }
}
```

The stdio bridge talks to the running app over a Unix socket in its private data directory; no MCP TCP port is opened. Only configure clients you trust to manage the targets and Caddy process.

| Tool | Arguments |
| --- | --- |
| `list_targets` | None; also returns Caddy status and whether a reload is pending |
| `add_target` | `host`, `upstream` |
| `edit_target` | `original_host`, `host`, `upstream` |
| `remove_target` | `host` |
| `start_caddy` | None |
| `stop_caddy` | None |

## Pi setup

Install SwiftLint with `brew install swiftlint`. Trust this repository in Pi and start a new Pi session (or use `/reload`) to load the pinned repository-local Pi Hooks package. The hook runs SwiftLint when Swift or hook configuration changes.
