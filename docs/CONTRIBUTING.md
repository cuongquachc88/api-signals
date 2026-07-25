# Contributing

Thank you for your interest in contributing to API Signals!

## Getting Started

### Requirements

- macOS 14+
- Xcode 16+ or Swift 6.0+
- Git

### Build

```bash
cd macOS
swift build
```

### Run Tests

```bash
cd macOS
swift test
```

> Note: `swift test` requires full Xcode installation to access XCTest.

## Project Structure

- `macOS/` — Swift/SwiftUI app
- `windows/` — WinUI 3 app (future)
- `shared/` — Shared specs and JSON schemas
- `docs/` — Documentation
- `tests/` — Cross-platform test utilities

## Code Style

- Swift 6 strict concurrency enabled.
- Prefer structs for value types.
- Use `async/await` for asynchronous code.
- Domain layer must remain pure Swift with no external dependencies.
- All public entities should be `Sendable`.

## Pull Request Process

1. Open an issue first for major changes.
2. Fork and create a feature branch.
3. Write tests for new domain logic.
4. Ensure `swift build` passes.
5. Update relevant documentation.
6. Submit PR with clear description.

## Commit Messages

Use conventional commits:

```
feat: add OAuth2 auth handler
fix: resolve variable interpolation in headers
docs: update API model documentation
test: add history repository tests
```

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
