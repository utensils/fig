# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.x.x   | :white_check_mark: |
| < 1.0   | :x:                |

## Reporting a Vulnerability

We take security vulnerabilities seriously. If you discover a security issue, please report it responsibly.

### How to Report

1. **Do not** open a public GitHub issue for security vulnerabilities
2. Email your report to security@example.com (or use GitHub's private vulnerability reporting)
3. Include as much detail as possible:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)

### What to Expect

- **Initial Response**: Within 48 hours
- **Status Update**: Within 5 business days
- **Resolution Timeline**: Depends on severity, typically 30-90 days

### Disclosure Policy

- We will acknowledge your report within 48 hours
- We will work with you to understand and validate the issue
- We will keep you informed about our progress
- We will credit you (unless you prefer anonymity) when we publish the fix

## Security Best Practices

When using Fig:

1. **Configuration Files**: Fig manages Claude Code configuration files which may contain sensitive information like API keys and tokens. Ensure these files have appropriate permissions.

2. **MCP Servers**: Be cautious when configuring MCP servers, especially those from untrusted sources.

3. **Backups**: Fig creates automatic backups of configuration files. Ensure backup directories have appropriate access controls.

## Security Features

- Automatic backups before file modifications
- No network requests except when explicitly configured
- All data stored locally on your machine
- No telemetry or analytics
