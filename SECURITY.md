# Security policy

This repository contains configuration examples and benchmark documentation. It does not host or redistribute model weights.

- Every example server binds to `127.0.0.1`.
- Model and runtime paths are environment-variable placeholders.
- Only one generation runtime should be resident at a time.
- Do not post credentials, private prompts, source code, logs, or local filesystem paths in public issues.
- Run `scripts/validate-release.ps1` and manually review the full diff before publishing.

