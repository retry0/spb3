# API Documentation

## Overview

The SPB Secure API provides RESTful endpoints for user authentication, data management, and application functionality. All API responses follow a consistent structure with comprehensive error handling.

## Base URL

- **Development**: `http://10.0.2.2:8097/v1`
- **Staging**: `https://api-staging.spb-secure.com/v1`
- **Production**: `https://api.spb-secure.com/v1`

## Authentication

The API uses JWT (JSON Web Token) based authentication. Include the token in the Authorization header:

```http
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

### Token Lifecycle

- **Expiration**: Tokens expire after 24 hours
- **Refresh**: No refresh tokens - users must re-authenticate
- **Storage**: Tokens should be stored securely on the client

## Request/Response Format

### Content Type

All requests and responses use JSON format:

```http
Content-Type: application/json
Accept: application/json
```

### Standard Response Structure

#### Success Response
```json
{
  "data": {
    // Response data
  },
  "message": "Operation completed successfully",
  "timestamp": "2025-01-27T10:30:45.123Z"
}
```

#### Error Response
```json
{
  "statusCode": 400,
  "errorCode": "VALIDATION_ERROR",
  "message": "The request contains invalid data",
  "details": "Detailed error description",
  "suggestedActions": [
    "Check the field errors below",
    "Ensure all required fields are provided"
  ],
  "timestamp": "2025-01-27T10:30:45.123Z",
  "requestId": "req_7f8a9b2c-3d4e-5f6g-7h8i-9j0k1l2m3n4o",
  "fieldErrors": {
    "email": ["Email address is required"],
    "password": ["Password must be at least 8 characters long"]
  },
  "retryable": false
}
```

## Authentication Endpoints

### Login

Authenticate a user with username and password.

```http
POST /Account/LoginUser
```

#### Request Body
```json
{
  "userName": "string",
  "password": "string"
}
```

#### Response
```json
{
  "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "tokenType": "Bearer",
  "expiresIn": 86400
}
```

#### Status Codes
- `200 OK` - Login successful
- `400 Bad Request` - Invalid request format
- `401 Unauthorized` - Invalid credentials
- `422 Unprocessable Entity` - Validation errors
- `429 Too Many Requests` - Rate limit exceeded

#### Example Request
```bash
curl -X POST "https://api.spb-secure.com/v1/Account/LoginUser" \
  -H "Content-Type: application/json" \
  -d '{
    "userName": "john_doe",
    "password": "SecurePassword123!"
  }'
```

#### Example Response
```json
{
  "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ1c3JfMTIzNDU2IiwidXNlck5hbWUiOiJqb2huX2RvZSIsImVtYWlsIjoiam9obkBleGFtcGxlLmNvbSIsIm5hbWUiOiJKb2huIERvZSIsInJvbGVzIjpbInVzZXIiXSwiaWF0IjoxNjQzNzIzNDAwLCJleHAiOjE2NDM4MDk4MDB9.signature",
  "tokenType": "Bearer",
  "expiresIn": 86400
}
```

### Logout

Invalidate the current user session.

```http
POST /auth/logout
Authorization: Bearer {token}
```

#### Response
```json
{
  "message": "Logout successful",
  "timestamp": "2025-01-27T10:30:45.123Z"
}
```

#### Status Codes
- `200 OK` - Logout successful
- `401 Unauthorized` - Invalid or expired token

### Check Username Availability

Check if a username is available for registration.

```http
GET /auth/userName/check?userName={userName}
```

#### Query Parameters
- `userName` (string, required) - Username to check

#### Response
```json
{
  "available": true,
  "suggestions": ["john_doe_2", "john_doe_2025"]
}
```

#### Status Codes
- `200 OK` - Check completed
- `400 Bad Request` - Invalid username format

## User Management Endpoints

### Get Current User

Retrieve the authenticated user's profile information.

```http
GET /user/profile
Authorization: Bearer {token}
```

#### Response
```json
{
  "id": "usr_123456789",
  "userName": "john_doe",
  "email": "john@example.com",
  "name": "John Doe",
  "avatar": "https://example.com/avatars/john_doe.jpg",
  "createdAt": "2025-01-01T00:00:00.000Z",
  "updatedAt": "2025-01-27T10:30:45.123Z",
  "lastLoginAt": "2025-01-27T09:15:30.456Z",
  "roles": ["user"],
  "permissions": ["read_profile", "update_profile"]
}
```

#### Status Codes
- `200 OK` - User data retrieved
- `401 Unauthorized` - Invalid or expired token
- `404 Not Found` - User not found

### Update User Profile

Update the authenticated user's profile information.

```http
PUT /user/profile
Authorization: Bearer {token}
```

#### Request Body
```json
{
  "name": "John Smith",
  "email": "john.smith@example.com",
  "avatar": "https://example.com/avatars/new_avatar.jpg"
}
```

#### Response
```json
{
  "id": "usr_123456789",
  "userName": "john_doe",
  "email": "john.smith@example.com",
  "name": "John Smith",
  "avatar": "https://example.com/avatars/new_avatar.jpg",
  "updatedAt": "2025-01-27T10:30:45.123Z"
}
```

#### Status Codes
- `200 OK` - Profile updated successfully
- `400 Bad Request` - Invalid request format
- `401 Unauthorized` - Invalid or expired token
- `422 Unprocessable Entity` - Validation errors

### Change Password

Change the authenticated user's password.

```http
POST /auth/password/change
Authorization: Bearer {token}
```

#### Request Body
```json
{
  "currentPassword": "OldPassword123!",
  "newPassword": "NewSecurePassword456!"
}
```

#### Response
```json
{
  "message": "Password changed successfully",
  "timestamp": "2025-01-27T10:30:45.123Z"
}
```

#### Status Codes
- `200 OK` - Password changed successfully
- `400 Bad Request` - Invalid request format
- `401 Unauthorized` - Invalid current password or token
- `422 Unprocessable Entity` - Password validation errors

## Data Management Endpoints

### Get Data Entries

Retrieve paginated data entries with optional filtering.

```http
GET /data?page={page}&limit={limit}&status={status}&search={search}
Authorization: Bearer {token}
```

#### Query Parameters
- `page` (integer, optional) - Page number (default: 1)
- `limit` (integer, optional) - Items per page (default: 20, max: 100)
- `status` (string, optional) - Filter by status (active, inactive, pending)
- `search` (string, optional) - Search term for name or email
- `sortBy` (string, optional) - Sort field (name, email, createdAt)
- `sortOrder` (string, optional) - Sort order (asc, desc)

#### Response
```json
{
  "data": [
    {
      "id": "entry_123",
      "name": "John Doe",
      "email": "john@example.com",
      "status": "active",
      "createdAt": "2025-01-01T00:00:00.000Z",
      "updatedAt": "2025-01-27T10:30:45.123Z"
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 150,
    "totalPages": 8,
    "hasNext": true,
    "hasPrev": false
  }
}
```

#### Status Codes
- `200 OK` - Data retrieved successfully
- `401 Unauthorized` - Invalid or expired token
- `422 Unprocessable Entity` - Invalid query parameters

### Create Data Entry

Create a new data entry.

```http
POST /data
Authorization: Bearer {token}
```

#### Request Body
```json
{
  "name": "Jane Smith",
  "email": "jane@example.com",
  "status": "active"
}
```

#### Response
```json
{
  "id": "entry_456",
  "name": "Jane Smith",
  "email": "jane@example.com",
  "status": "active",
  "createdAt": "2025-01-27T10:30:45.123Z",
  "updatedAt": "2025-01-27T10:30:45.123Z"
}
```

#### Status Codes
- `201 Created` - Entry created successfully
- `400 Bad Request` - Invalid request format
- `401 Unauthorized` - Invalid or expired token
- `422 Unprocessable Entity` - Validation errors

### Update Data Entry

Update an existing data entry.

```http
PUT /data/{id}
Authorization: Bearer {token}
```

#### Path Parameters
- `id` (string, required) - Entry ID

#### Request Body
```json
{
  "name": "Jane Doe",
  "email": "jane.doe@example.com",
  "status": "inactive"
}
```

#### Response
```json
{
  "id": "entry_456",
  "name": "Jane Doe",
  "email": "jane.doe@example.com",
  "status": "inactive",
  "createdAt": "2025-01-01T00:00:00.000Z",
  "updatedAt": "2025-01-27T10:30:45.123Z"
}
```

#### Status Codes
- `200 OK` - Entry updated successfully
- `400 Bad Request` - Invalid request format
- `401 Unauthorized` - Invalid or expired token
- `404 Not Found` - Entry not found
- `422 Unprocessable Entity` - Validation errors

### Delete Data Entry

Delete a data entry.

```http
DELETE /data/{id}
Authorization: Bearer {token}
```

#### Path Parameters
- `id` (string, required) - Entry ID

#### Response
```json
{
  "message": "Entry deleted successfully",
  "timestamp": "2025-01-27T10:30:45.123Z"
}
```

#### Status Codes
- `200 OK` - Entry deleted successfully
- `401 Unauthorized` - Invalid or expired token
- `404 Not Found` - Entry not found

### Export Data

Export data entries in various formats.

```http
GET /data/export?format={format}&status={status}
Authorization: Bearer {token}
```

#### Query Parameters
- `format` (string, required) - Export format (csv, pdf, json)
- `status` (string, optional) - Filter by status
- `search` (string, optional) - Search term

#### Response
- **CSV/PDF**: Binary file download
- **JSON**: JSON array of entries

#### Status Codes
- `200 OK` - Export successful
- `401 Unauthorized` - Invalid or expired token
- `422 Unprocessable Entity` - Invalid parameters

## Dashboard Endpoints

### Get Dashboard Metrics

Retrieve dashboard metrics and statistics.

```http
GET /dashboard/metrics
Authorization: Bearer {token}
```

#### Response
```json
{
  "totalUsers": 1234,
  "activeSessions": 89,
  "dataPoints": 5678,
  "securityScore": 98,
  "metrics": {
    "userGrowth": {
      "current": 1234,
      "previous": 1180,
      "change": 4.6
    },
    "activityTrend": {
      "daily": [45, 52, 48, 61, 55, 67, 59],
      "labels": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    }
  }
}
```

#### Status Codes
- `200 OK` - Metrics retrieved successfully
- `401 Unauthorized` - Invalid or expired token

### Get Recent Activities

Retrieve recent user activities.

```http
GET /dashboard/activities?limit={limit}
Authorization: Bearer {token}
```

#### Query Parameters
- `limit` (integer, optional) - Number of activities (default: 10, max: 50)

#### Response
```json
{
  "activities": [
    {
      "id": "activity_123",
      "type": "login",
      "description": "User logged in",
      "user": {
        "id": "usr_456",
        "userName": "john_doe",
        "name": "John Doe"
      },
      "timestamp": "2025-01-27T10:30:45.123Z",
      "metadata": {
        "ipAddress": "192.168.1.100",
        "userAgent": "Mozilla/5.0..."
      }
    }
  ]
}
```

#### Status Codes
- `200 OK` - Activities retrieved successfully
- `401 Unauthorized` - Invalid or expired token

## Error Codes

### Authentication Errors

| Code | HTTP Status | Description |
|------|-------------|-------------|
| `AUTHENTICATION_REQUIRED` | 401 | Valid authentication token required |
| `INVALID_CREDENTIALS` | 401 | Username or password is incorrect |
| `TOKEN_EXPIRED` | 401 | Authentication token has expired |
| `TOKEN_INVALID` | 401 | Authentication token is malformed or invalid |
| `INSUFFICIENT_PERMISSIONS` | 403 | User lacks required permissions |

### Validation Errors

| Code | HTTP Status | Description |
|------|-------------|-------------|
| `VALIDATION_ERROR` | 422 | Request data validation failed |
| `REQUIRED_FIELD_MISSING` | 422 | Required field is missing |
| `INVALID_FORMAT` | 422 | Field format is invalid |
| `VALUE_OUT_OF_RANGE` | 422 | Field value is out of acceptable range |

### Resource Errors

| Code | HTTP Status | Description |
|------|-------------|-------------|
| `RESOURCE_NOT_FOUND` | 404 | Requested resource does not exist |
| `RESOURCE_CONFLICT` | 409 | Resource already exists or conflicts |
| `RESOURCE_GONE` | 410 | Resource has been permanently deleted |

### Rate Limiting

| Code | HTTP Status | Description |
|------|-------------|-------------|
| `RATE_LIMIT_EXCEEDED` | 429 | Too many requests in time window |

### Server Errors

| Code | HTTP Status | Description |
|------|-------------|-------------|
| `INTERNAL_SERVER_ERROR` | 500 | Unexpected server error |
| `SERVICE_UNAVAILABLE` | 503 | Service temporarily unavailable |
| `GATEWAY_TIMEOUT` | 504 | Upstream service timeout |

## Rate Limiting

### Limits

- **Authentication**: 10 requests per minute per IP
- **General API**: 100 requests per hour per user
- **Data Export**: 5 requests per hour per user

### Headers

Rate limit information is included in response headers:

```http
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1643809800
X-RateLimit-Window: 3600
```

### Rate Limit Exceeded Response

```json
{
  "statusCode": 429,
  "errorCode": "RATE_LIMIT_EXCEEDED",
  "message": "Too many requests - rate limit exceeded",
  "details": "You have exceeded the rate limit of 100 requests per hour.",
  "suggestedActions": [
    "Wait 3600 seconds before retrying",
    "Implement exponential backoff in your client",
    "Consider upgrading your plan for higher rate limits"
  ],
  "context": {
    "retryAfterSeconds": 3600,
    "requestsPerWindow": 100,
    "windowDuration": "hour"
  },
  "retryable": true
}
```

## Webhooks

### Webhook Events

The API can send webhook notifications for certain events:

- `user.created` - New user registration
- `user.updated` - User profile updated
- `user.deleted` - User account deleted
- `data.created` - New data entry created
- `data.updated` - Data entry updated
- `data.deleted` - Data entry deleted

### Webhook Payload

```json
{
  "event": "user.created",
  "timestamp": "2025-01-27T10:30:45.123Z",
  "data": {
    "id": "usr_123456789",
    "userName": "john_doe",
    "email": "john@example.com",
    "name": "John Doe"
  },
  "metadata": {
    "source": "api",
    "version": "1.0"
  }
}
```

### Webhook Security

- Webhooks are signed using HMAC-SHA256
- Signature is included in the `X-Webhook-Signature` header
- Verify the signature to ensure webhook authenticity

## SDK and Libraries

### Official SDKs

- **Flutter/Dart**: Built-in HTTP client with Dio
- **JavaScript/TypeScript**: Coming soon
- **Python**: Coming soon

### Community Libraries

- **Postman Collection**: Available for API testing
- **OpenAPI Specification**: Available for code generation

## Testing

### Test Environment

- **Base URL**: `https://api-test.spb-secure.com/v1`
- **Test Credentials**: Contact support for test account access
- **Rate Limits**: Relaxed for testing purposes

### Postman Collection

Import the Postman collection for easy API testing:

```bash
curl -o spb-api.postman_collection.json \
  https://api.spb-secure.com/docs/postman-collection.json
```

## Support

### Documentation

- **API Reference**: https://api-docs.spb-secure.com
- **Status Page**: https://status.spb-secure.com
- **Changelog**: https://api-docs.spb-secure.com/changelog

### Contact

- **Support Email**: api-support@spb-secure.com
- **Developer Portal**: https://developers.spb-secure.com
- **GitHub Issues**: https://github.com/spb-secure/api-issues

### SLA

- **Uptime**: 99.9% availability
- **Response Time**: < 200ms for 95% of requests
- **Support Response**: < 24 hours for technical issues