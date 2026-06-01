# Security Policy

## Supported Versions

| Version | Supported | End of Life |
|---------|-----------|-------------|
| 3.x     | ✅        | TBD         |
| 2.x     | ❌        | 2025-12-31  |

## Reporting a Vulnerability

**DO NOT** report vulnerabilities through public GitHub issues.

Please report security issues to: **security@bioshield.secure-bank.internal**

You should receive a response within 24 hours. 

### What to include:
- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

## Disclosure Policy

1. Security report received
2. Acknowledgment within 24 hours
3. Investigation and validation
4. Fix development
5. Coordinated disclosure

## Security Best Practices

### For Deployments:
- Always use TLS 1.3
- Rotate API keys every 90 days
- Enable audit logging
- Use hardware security modules for key storage

### For Integration:
- Never hardcode API keys
- Use environment variables
- Implement rate limiting
- Validate all inputs

## Bug Bounty

We offer bounties for qualifying security findings:
- Critical: $10,000
- High: $5,000
- Medium: $1,000
- Low: $500
