# Environment Configuration Guide

This guide explains how to configure the SPB Secure App for different environments using environment variables.

## Quick Start

1. Copy `example.env` to your environment configuration
2. Set the `FLUTTER_ENV` variable to your target environment
3. Configure the appropriate API URLs and settings
4. Run the application

## Environment Variables

### Core Configuration

| Variable | Required | Description | Default |
|----------|----------|-------------|---------|
| `FLUTTER_ENV` | No | Environment type: `development`, `staging`, `production` | `development` |

### Development Environment

| Variable | Required | Description | Default |
|----------|----------|-------------|---------|
| `DEV_API_BASE_URL` | No | Development API base URL | `http://localhost:8000/api` |
| `DEV_ENABLE_LOGGING` | No | Enable debug logging | `true` |
| `DEV_TIMEOUT_SECONDS` | No | Request timeout in seconds | `30` |

### Staging Environment

| Variable | Required | Description | Default |
|----------|----------|-------------|---------|
| `STAGING_API_BASE_URL` | Yes | Staging API base URL | None |
| `STAGING_ENABLE_LOGGING` | No | Enable debug logging | `false` |
| `STAGING_TIMEOUT_SECONDS` | No | Request timeout in seconds | `60` |

### Production Environment

| Variable | Required | Description | Default |
|----------|----------|-------------|---------|
| `PROD_API_BASE_URL` | Yes | Production API base URL | None |
| `PROD_ENABLE_LOGGING` | No | Enable debug logging | `false` |
| `PROD_TIMEOUT_SECONDS` | No | Request timeout in seconds | `120` |

## Security Requirements

### Development
- HTTP and HTTPS URLs are allowed
- Localhost URLs are permitted
- Logging is enabled by default

### Staging
- HTTPS URLs are strongly recommended
- Logging is disabled by default
- Longer timeout for network stability

### Production
- **HTTPS URLs are mandatory**
- Localhost URLs are forbidden
- Logging is disabled by default
- Additional security headers are added

## URL Format Validation

All API URLs must follow these rules:

1. **Valid URI format**: Must be parseable as a URI
2. **Supported schemes**: Only `http` and `https` are allowed
3. **Valid host**: Must have a non-empty host component
4. **Production HTTPS**: Production environment requires HTTPS

### Valid Examples
```bash
# Development
DEV_API_BASE_URL=http://localhost:8000/api
DEV_API_BASE_URL=http://10.0.2.2:8000/api
DEV_API_BASE_URL=https://dev-api.example.com/api

# Staging
STAGING_API_BASE_URL=https://staging-api.example.com/api

# Production
PROD_API_BASE_URL=https://api.example.com/api
```

### Invalid Examples
```bash
# Invalid scheme
API_BASE_URL=ftp://example.com/api

# Missing host
API_BASE_URL=https:///api

# Localhost in production (forbidden)
PROD_API_BASE_URL=http://localhost:8000/api
```

## Environment Setup Examples

### Local Development
```bash
export FLUTTER_ENV=development
export DEV_API_BASE_URL=http://localhost:8000/api
export DEV_ENABLE_LOGGING=true
```

### CI/CD Pipeline (Staging)
```bash
export FLUTTER_ENV=staging
export STAGING_API_BASE_URL=https://api-staging.spb-secure.com/api
export STAGING_ENABLE_LOGGING=false
export STAGING_TIMEOUT_SECONDS=90
```

### Production Deployment
```bash
export FLUTTER_ENV=production
export PROD_API_BASE_URL=https://api.spb-secure.com/api
export PROD_ENABLE_LOGGING=false
export PROD_TIMEOUT_SECONDS=120
```

## Error Handling

The application validates environment configuration on startup:

### Validation Errors
- Missing required environment variables
- Invalid URL formats
- Security violations (e.g., HTTP in production)
- Invalid boolean/integer values

### Error Responses
- **Development**: Shows detailed error messages and continues with warnings
- **Staging/Production**: Fails fast with configuration errors

## Debugging Configuration

To debug your environment configuration:

1. **Check current configuration**:
   ```dart
   print(EnvironmentConfig.getConfigSummary());
   ```

2. **Validate environment**:
   ```dart
   final validation = EnvironmentValidator.validateEnvironment();
   print(validation.getReport());
   ```

3. **Generate example configuration**:
   ```dart
   print(EnvironmentValidator.generateExampleEnvFile());
   ```

## Best Practices

1. **Never commit real environment files** to version control
2. **Use different URLs** for each environment
3. **Disable logging** in production
4. **Use HTTPS** for staging and production
5. **Set appropriate timeouts** based on environment needs
6. **Validate configuration** in CI/CD pipelines

## Troubleshooting

### Common Issues

1. **"Environment configuration not initialized"**
   - Ensure `EnvironmentConfig.initialize()` is called before using any configuration

2. **"Required environment variable X is not set"**
   - Set the missing environment variable for your target environment

3. **"Production environment requires HTTPS URLs"**
   - Update your production URL to use HTTPS

4. **"Invalid URL format"**
   - Check your URL syntax and ensure it's a valid URI

### Getting Help

If you encounter issues:
1. Check the validation report using `EnvironmentValidator.validateEnvironment()`
2. Review the example configuration in `example.env`
3. Ensure all required variables are set for your target environment