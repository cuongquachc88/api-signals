# GitHub Wiki source

Pages in this directory are **copies** of the main docs, formatted for [GitHub Wiki](https://docs.github.com/en/communities/documenting-your-project-with-wikis/about-wikis). The canonical versions live under [`docs/`](../docs/).

## Why two places?

- **`docs/`** — versioned with the repo, linked from README, usable offline.
- **Wiki** — editable in the GitHub UI, good for quick notes and community edits.

Prefer updating `docs/` first, then sync wiki pages.

## Publish / update the wiki

GitHub wikis are separate git repositories.

```bash
# One-time clone (replace org/repo)
git clone https://github.com/apisignals/api-signals.wiki.git

# Copy pages from this repo
cp ../wiki/*.md api-signals.wiki/
cd api-signals.wiki
git add .
git commit -m "Sync wiki from main repo"
git push
```

Wiki home page must be named `Home.md`.

## Page map

| Wiki file | Canonical doc |
| --- | --- |
| [Home.md](./Home.md) | [README.md](../README.md) (overview) |
| [Build-from-source.md](./Build-from-source.md) | [docs/BUILD.md](../docs/BUILD.md) |
| [Architecture.md](./Architecture.md) | [docs/ARCHITECTURE.md](../docs/ARCHITECTURE.md) |
| [Contributing.md](./Contributing.md) | [docs/CONTRIBUTING.md](../docs/CONTRIBUTING.md) |
| [Release-process.md](./Release-process.md) | [docs/RELEASE.md](../docs/RELEASE.md) |
| [Roadmap.md](./Roadmap.md) | [docs/ROADMAP.md](../docs/ROADMAP.md) |
