# Contributing to AI Usage Pro

Thanks for your interest in contributing!

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/YOUR_USERNAME/ai-usage-pro.git`
3. Install dependencies: `brew install swiftlint swiftformat`
4. Create a branch: `git checkout -b feature/your-feature`

## Development

```bash
# Build
swift build

# Run tests
swift test

# Check linting
swiftlint lint

# Format code
swiftformat Sources Tests
```

## Code Style

- Run `swiftformat Sources Tests` before committing
- Ensure `swiftlint lint` passes with no errors
- Follow existing code patterns and conventions

## Pull Request Process

1. Ensure CI passes (build, tests, linting)
2. Update documentation if needed
3. Fill out the PR template
4. Request review

## Commit Messages

Use conventional commits:
- `feat:` new features
- `fix:` bug fixes
- `docs:` documentation
- `style:` formatting
- `refactor:` code restructuring
- `test:` adding tests
- `chore:` maintenance

## Reporting Issues

- Check existing issues first
- Use issue templates
- Include macOS version and steps to reproduce

## Questions?

Open a discussion or issue if you need help.
