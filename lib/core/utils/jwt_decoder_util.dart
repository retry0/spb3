import 'dart:convert';
import 'package:jwt_decoder/jwt_decoder.dart';
import '../utils/logger.dart';

/// Utility class for decoding JWT tokens and extracting filtered data
class JwtDecoderUtil {
  /// Fields to exclude from the decoded JWT payload
  static const Set<String> _excludedFields = {
    'access_token',
    'accessToken',
    'refresh_token',
    'refreshToken',
    'expires_at',
    'expiresAt',
    'exp', // Standard JWT expiration claim
    'iat', // Issued at (sometimes sensitive)
  };

  /// Decodes a JWT token and returns all data except sensitive authentication fields
  ///
  /// Returns a Map containing all JWT claims except:
  /// - access_token/accessToken
  /// - refresh_token/refreshToken
  /// - expires_at/expiresAt
  /// - exp (expiration time)
  /// - iat (issued at time)
  ///
  /// Returns null if the token is invalid or cannot be decoded
  static Map<String, dynamic>? decodeAndFilterToken(String token) {
    try {
      // Validate token format first
      if (!_isValidJwtFormat(token)) {
        AppLogger.warning('Invalid JWT token format');
        return null;
      }

      // Check if token is expired
      if (JwtDecoder.isExpired(token)) {
        AppLogger.warning('JWT token is expired');
        // Still decode it but log the warning
      }

      // Decode the JWT token
      final Map<String, dynamic> decodedToken = JwtDecoder.decode(token);

      // Filter out sensitive fields
      final Map<String, dynamic> filteredData = Map<String, dynamic>.from(
        decodedToken,
      );

      // Remove excluded fields
      for (final field in _excludedFields) {
        filteredData.remove(field);
      }

      AppLogger.debug(
        'JWT token decoded successfully. Filtered ${_excludedFields.length} sensitive fields.',
      );

      return filteredData;
    } catch (e) {
      AppLogger.error('Failed to decode JWT token: $e');
      return null;
    }
  }

  /// Extracts user information from a JWT token
  /// Returns common user fields like sub, email, name, roles, etc.
  static Map<String, dynamic>? extractUserInfo(String token) {
    final filteredData = decodeAndFilterToken(token);
    if (filteredData == null) return null;

    // Common user-related JWT claims
    const userFields = {
      'Id', // Subject (user ID)
      'UserName',
      'Nama',
    };

    final Map<String, dynamic> userInfo = {};

    for (final field in userFields) {
      if (filteredData.containsKey(field)) {
        userInfo[field] = filteredData[field];
      }
    }

    return userInfo.isNotEmpty ? userInfo : null;
  }

  /// Extracts custom claims from a JWT token (non-standard claims)
  /// Excludes both sensitive fields and standard JWT claims
  static Map<String, dynamic>? extractCustomClaims(String token) {
    final filteredData = decodeAndFilterToken(token);
    if (filteredData == null) return null;

    // Standard JWT claims to exclude from custom claims
    const standardClaims = {
      'iss', // Issuer
      'sub', // Subject
      'aud', // Audience
      'exp', // Expiration time
      'nbf', // Not before
      'iat', // Issued at
      'jti', // JWT ID
      'typ', // Type
      'alg', // Algorithm
    };

    // Common user claims to exclude from custom claims
    const commonUserClaims = {
      'email',
      'email_verified',
      'name',
      'given_name',
      'family_name',
      'nickname',
      'picture',
      'locale',
      'preferred_username',
      'profile',
      'website',
      'gender',
      'birthdate',
      'phone_number',
      'phone_number_verified',
      'address',
    };

    final Map<String, dynamic> customClaims = Map<String, dynamic>.from(
      filteredData,
    );

    // Remove standard and common claims
    for (final claim in [...standardClaims, ...commonUserClaims]) {
      customClaims.remove(claim);
    }

    return customClaims.isNotEmpty ? customClaims : null;
  }

  /// Gets the token expiration time without including it in filtered data
  static DateTime? getTokenExpiration(String token) {
    try {
      final expirationTime = JwtDecoder.getExpirationDate(token);
      return expirationTime;
    } catch (e) {
      AppLogger.error('Failed to get token expiration: $e');
      return null;
    }
  }

  /// Gets the token issued time
  static DateTime? getTokenIssuedAt(String token) {
    try {
      final decodedToken = JwtDecoder.decode(token);
      final iat = decodedToken['iat'];

      if (iat != null) {
        return DateTime.fromMillisecondsSinceEpoch(iat * 1000);
      }
      return null;
    } catch (e) {
      AppLogger.error('Failed to get token issued time: $e');
      return null;
    }
  }

  /// Checks if the token is valid and not expired
  static bool isTokenValid(String token) {
    try {
      return !JwtDecoder.isExpired(token);
    } catch (e) {
      AppLogger.error('Failed to validate token: $e');
      return false;
    }
  }

  /// Gets token metadata (expiration, issued time, etc.) without sensitive data
  static Map<String, dynamic>? getTokenMetadata(String token) {
    try {
      final expiration = getTokenExpiration(token);
      final issuedAt = getTokenIssuedAt(token);
      final isValid = isTokenValid(token);

      return {
        'isValid': isValid,
        'isExpired': !isValid,
        'expirationDate': expiration?.toIso8601String(),
        'issuedAtDate': issuedAt?.toIso8601String(),
        'timeUntilExpiration':
            expiration != null
                ? expiration.difference(DateTime.now()).inSeconds
                : null,
      };
    } catch (e) {
      AppLogger.error('Failed to get token metadata: $e');
      return null;
    }
  }

  /// Validates JWT token format (basic structure check)
  static bool _isValidJwtFormat(String token) {
    if (token.isEmpty) return false;

    final parts = token.split('.');
    return parts.length == 3; // Header.Payload.Signature
  }

  /// Pretty prints the filtered JWT data for debugging
  static String prettyPrintFilteredData(String token) {
    final filteredData = decodeAndFilterToken(token);
    if (filteredData == null) {
      return 'Invalid or expired token';
    }

    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(filteredData);
  }

  /// Extracts specific claims by name
  static Map<String, dynamic> extractSpecificClaims(
    String token,
    List<String> claimNames,
  ) {
    final filteredData = decodeAndFilterToken(token);
    if (filteredData == null) return {};

    final Map<String, dynamic> specificClaims = {};

    for (final claimName in claimNames) {
      if (filteredData.containsKey(claimName)) {
        specificClaims[claimName] = filteredData[claimName];
      }
    }

    return specificClaims;
  }

  /// Checks if token contains specific claims
  static bool hasClaimsInToken(String token, List<String> requiredClaims) {
    final filteredData = decodeAndFilterToken(token);
    if (filteredData == null) return false;

    return requiredClaims.every((claim) => filteredData.containsKey(claim));
  }

  /// Gets all available claim names in the token (excluding sensitive fields)
  static List<String> getAvailableClaims(String token) {
    final filteredData = decodeAndFilterToken(token);
    if (filteredData == null) return [];

    return filteredData.keys.toList()..sort();
  }
}