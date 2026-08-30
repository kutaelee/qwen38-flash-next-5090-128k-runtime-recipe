# Repository instructions

- This is a public, documentation-first runtime recipe. Never add model weights, credentials, private logs, usernames, workstation paths, scheduler identifiers, or internal repository names.
- Every benchmark value must trace to a preserved validation evidence record. Keep cold/warm, prompt/decode, context depth, lane, and sample size explicit.
- Baseline correctness is the release gate. Do not present MTP or ngram as the recommended configuration until their recorded A/B checks pass.
- All examples bind to `127.0.0.1`, use placeholder paths, and run only one generation server at a time.
- Run `pwsh -NoProfile -File .\scripts\validate-release.ps1` before publishing.

