# Contributing to SPB Secure

Thank you for considering contributing to the SPB Secure Flutter application! This document provides guidelines and instructions for contributing to the project.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Workflow](#development-workflow)
- [Coding Standards](#coding-standards)
- [Commit Guidelines](#commit-guidelines)
- [Pull Request Process](#pull-request-process)
- [Testing Guidelines](#testing-guidelines)
- [Documentation](#documentation)
- [Issue Reporting](#issue-reporting)
- [Feature Requests](#feature-requests)
- [Security Vulnerabilities](#security-vulnerabilities)
- [Community](#community)

## Code of Conduct

This project and everyone participating in it is governed by our Code of Conduct. By participating, you are expected to uphold this code. Please report unacceptable behavior to [conduct@spb-secure.com](mailto:conduct@spb-secure.com).

## Getting Started

### Prerequisites

- Flutter SDK (3.27.0 or higher)
- Dart SDK (3.7.0 or higher)
- Android Studio / VS Code with Flutter extensions
- Git

### Setup

1. **Fork the repository**

2. **Clone your fork**
   ```bash
   git clone https://github.com/your-username/spb-secure-app.git
   cd spb-secure-app
   ```

3. **Add the upstream remote**
   ```bash
   git remote add upstream https://github.com/original-org/spb-secure-app.git
   ```

4. **Install dependencies**
   ```bash
   flutter pub get
   ```

5. **Generate code**
   ```bash
   flutter packages pub run build_runner build --delete-conflicting-outputs
   ```

6. **Set up environment**
   ```bash
   cp example.env .env
   # Edit .env with your development settings
   ```

7. **Run the app**
   ```bash
   flutter run
   ```

## Development Workflow

### Branching Strategy

We follow a simplified Git Flow workflow:

- `main`: Production-ready code
- `develop`: Latest development changes
- `feature/*`: New features
- `bugfix/*`: Bug fixes
- `hotfix/*`: Urgent fixes for production
- `release/*`: Release preparation

### Creating a Feature Branch

```bash
# Ensure you're on the latest develop branch
git checkout develop
git pull upstream develop

# Create a feature branch
git checkout -b feature/amazing-feature
```

### Keeping Your Branch Updated

```bash
# Fetch upstream changes
git fetch upstream

# Rebase your branch on the latest develop
git rebase upstream/develop

# Or merge if preferred
git merge upstream/develop
```

### Running Tests

```bash
# Run all tests
flutter test

# Run specific tests
flutter test test/features/auth/

# Run with coverage
flutter test --coverage
```

## Coding Standards

We follow the [Dart Style Guide](https://dart.dev/guides/language/effective-dart/style) and have additional project-specific standards:

### Code Formatting

```bash
# Format code
flutter format lib/ test/

# Verify formatting
flutter format --set-exit-if-changed lib/ test/
```

### Static Analysis

```bash
# Run analyzer
flutter analyze
```

### Key Principles

1. **Clean Architecture**: Maintain separation between layers
2. **Single Responsibility**: Each class should have one responsibility
3. **Testability**: Write code that's easy to test
4. **Documentation**: Document public APIs and complex logic
5. **Error Handling**: Implement proper error handling

See [CODE_STYLE.md](CODE_STYLE.md) for detailed coding standards.

## Commit Guidelines

We follow [Conventional Commits](https://www.conventionalcommits.org/) for clear and structured commit messages:

```
<type>(<scope>): <description>

[optional body]

[optional footer(s)]
```

### Types

- `feat`: A new feature
- `fix`: A bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code changes that neither fix bugs nor add features
- `perf`: Performance improvements
- `test`: Adding or correcting tests
- `chore`: Changes to the build process or auxiliary tools

### Examples

```
feat(auth): add biometric authentication

Implement fingerprint and face recognition login using local_auth package.

Closes #123
```

```
fix(network): resolve Android emulator connection issues

Convert localhost references to 10.0.2.2 for Android emulator compatibility.
```

## Pull Request Process

1. **Create a pull request** from your feature branch to the `develop` branch
2. **Fill out the PR template** with all required information
3. **Ensure all checks pass** (tests, linting, etc.)
4. **Request reviews** from maintainers
5. **Address review feedback** with additional commits
6. **Squash commits** if requested by reviewers
7. **Wait for approval and merge**

### PR Template

```markdown
## Description
[Describe the changes in this PR]

## Related Issues
[Link to related issues, e.g., "Fixes #123"]

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update
- [ ] Code refactoring
- [ ] Performance improvement
- [ ] Tests

## Checklist
- [ ] I have read the CONTRIBUTING.md document
- [ ] My code follows the project's coding standards
- [ ] I have added tests that prove my fix/feature works
- [ ] All tests pass locally
- [ ] I have updated the documentation accordingly
- [ ] My changes don't introduce new warnings
- [ ] I have added comments to hard-to-understand areas
```

## Testing Guidelines

### Test Coverage

We aim for high test coverage:
- **Core Layer**: 90%+ coverage
- **Domain Layer**: 95%+ coverage
- **Data Layer**: 85%+ coverage
- **Presentation Layer**: 70%+ coverage

### Types of Tests

1. **Unit Tests**: Test individual components in isolation
2. **Widget Tests**: Test UI components
3. **Integration Tests**: Test component interactions
4. **Golden Tests**: Visual regression testing

### Testing Best Practices

1. **Test Behavior, Not Implementation**: Focus on what the code does, not how it does it
2. **Arrange-Act-Assert**: Structure tests with clear setup, action, and verification
3. **One Assertion Per Test**: Keep tests focused on a single behavior
4. **Descriptive Test Names**: Use clear, descriptive test names
5. **Mock External Dependencies**: Isolate the code being tested

See [TESTING.md](TESTING.md) for detailed testing guidelines.

## Documentation

Good documentation is crucial for the project's success:

### Code Documentation

- Document all public APIs using dartdoc comments
- Explain complex algorithms and business logic
- Add comments for non-obvious code

Example:
```dart
/// Authenticates a user with username and password.
///
/// Returns a [Future] that completes with [AuthResult] containing
/// the authentication result and user information if successful.
///
/// Throws [AuthException] if authentication fails.
///
/// Parameters:
/// - [userName]: The user's username
/// - [password]: The user's password
Future<AuthResult> login(String userName, String password) async {
  // Implementation
}
```

### Project Documentation

- Update README.md with new features or changes
- Document architecture decisions in ARCHITECTURE.md
- Update API documentation in API.md
- Add usage examples for new features

## Issue Reporting

### Bug Reports

When reporting bugs, please include:

1. **Description**: Clear description of the bug
2. **Reproduction Steps**: Detailed steps to reproduce
3. **Expected Behavior**: What you expected to happen
4. **Actual Behavior**: What actually happened
5. **Environment**: Flutter version, device/OS, etc.
6. **Screenshots/Logs**: If applicable
7. **Possible Solution**: If you have suggestions

### Issue Template

```markdown
## Bug Description
[Clear description of the bug]

## Steps to Reproduce
1. [First step]
2. [Second step]
3. [And so on...]

## Expected Behavior
[What you expected to happen]

## Actual Behavior
[What actually happened]

## Environment
- Flutter version: [e.g., 3.27.0]
- Device: [e.g., iPhone 14 Pro, Pixel 7]
- OS: [e.g., iOS 16.5, Android 13]
- App version: [e.g., 1.0.0]

## Additional Information
[Any other information that might be relevant]
```

## Feature Requests

When requesting features, please include:

1. **Description**: Clear description of the feature
2. **Rationale**: Why this feature would be valuable
3. **Proposed Implementation**: If you have ideas
4. **Alternatives**: Any alternative solutions
5. **Additional Context**: Any other relevant information

### Feature Request Template

```markdown
## Feature Description
[Clear description of the proposed feature]

## Problem It Solves
[What problem or need does this feature address?]

## Proposed Implementation
[If you have ideas about how to implement it]

## Alternatives Considered
[Any alternative solutions or features you've considered]

## Additional Context
[Any other information or screenshots about the feature request]
```

## Security Vulnerabilities

If you discover a security vulnerability, please do NOT open an issue. Instead, email [security@spb-secure.com](mailto:security@spb-secure.com) with details.

We will:
1. Acknowledge receipt within 24 hours
2. Provide an estimated timeline for a fix
3. Notify you when the issue is fixed
4. Publicly disclose the issue after it's resolved

## Community

### Communication Channels

- **GitHub Discussions**: For feature discussions and community help
- **Slack Channel**: For real-time communication (invitation required)
- **Monthly Meetings**: Virtual meetings for contributors

### Recognition

All contributors will be recognized in the project:
- Listed in CONTRIBUTORS.md
- Mentioned in release notes for significant contributions

## License

By contributing to SPB Secure, you agree that your contributions will be licensed under the project's MIT License.