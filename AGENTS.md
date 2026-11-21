# Repository instructions

- Write simple, human-readable Swift. Prefer small, focused types and keep code split by domain: app/UI, Caddy lifecycle and config, and MCP transport and tools.
- Keep target management shared between the window and MCP. Do not duplicate validation or persistence.
- Do not add tests.
- Do not run checks (lint, builds for verification, or tests) via tool calls. The repository-local Pi Hooks plugin runs SwiftLint automatically before the agent turn settles and reports failures. Fix reported failures without running checks manually.
