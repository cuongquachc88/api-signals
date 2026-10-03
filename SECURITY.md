# Security policy

## Supported versions

| Version | Supported |
| --- | --- |
| Latest [GitHub Release](https://github.com/apisignals/api-signals/releases) | Yes |
| `main` branch | Best-effort fixes |
| Older tags | No |

## Reporting a vulnerability

**Please do not open public issues for security vulnerabilities.**

1. Use [GitHub Private vulnerability reporting](https://github.com/apisignals/api-signals/security/advisories/new) if enabled for the repo, **or**
2. Open a minimal issue asking maintainers for a private contact channel (no exploit details in public).

Include:

- Affected version or commit
- Steps to reproduce
- Impact assessment
- Suggested fix (optional)

We aim to acknowledge reports within **7 days** and provide a remediation plan or status update when possible.

## Threat model (summary)

API Signals is a **local-first** desktop client. It executes HTTP requests you configure, runs user-provided scripts, and stores data in SQLite on disk. Treat collections and environments like sensitive configuration — they may contain tokens and secrets.

Do not commit secrets to the repository. Use environment-specific values in local app data, not in git.
