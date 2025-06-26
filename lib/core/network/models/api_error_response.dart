import 'package:equatable/equatable.dart';

/// Professional REST API error response model following industry best practices
class ApiErrorResponse extends Equatable {
  /// HTTP status code
  final int statusCode;
  
  /// Application-specific error code for programmatic handling
  final String errorCode;
  
  /// Human-readable error message
  final String message;
  
  /// Detailed technical description for developers
  final String? details;
  
  /// Suggested actions to resolve the issue
  final List<String>? suggestedActions;
  
  /// ISO 8601 timestamp when the error occurred
  final String? timestamp;
  
  /// Unique request identifier for tracking and debugging
  final String? requestId;
  
  /// Additional context or metadata about the error
  final Map<String, dynamic>? context;
  
  /// Field-specific validation errors (for 422 responses)
  final Map<String, List<String>>? fieldErrors;
  
  /// Link to documentation or help resources
  final String? documentationUrl;
  
  /// Whether this error can be retried
  final bool? retryable;

  const ApiErrorResponse({
    required this.statusCode,
    required this.errorCode,
    required this.message,
    this.details,
    this.suggestedActions,
    this.timestamp,
    this.requestId,
    this.context,
    this.fieldErrors,
    this.documentationUrl,
    this.retryable,
  });

  factory ApiErrorResponse.fromJson(Map<String, dynamic> json) {
    return ApiErrorResponse(
      statusCode: json['statusCode'] ?? 0,
      errorCode: json['errorCode'] ?? '',
      message: json['message'] ?? '',
      details: json['details'],
      suggestedActions: json['suggestedActions'] != null 
          ? List<String>.from(json['suggestedActions']) 
          : null,
      timestamp: json['timestamp'],
      requestId: json['requestId'],
      context: json['context'] as Map<String, dynamic>?,
      fieldErrors: json['fieldErrors'] != null 
          ? _parseFieldErrors(json['fieldErrors']) 
          : null,
      documentationUrl: json['documentationUrl'],
      retryable: json['retryable'],
    );
  }

  static Map<String, List<String>>? _parseFieldErrors(dynamic fieldErrors) {
    if (fieldErrors == null) return null;
    
    try {
      final result = <String, List<String>>{};
      final map = fieldErrors as Map<String, dynamic>;
      
      map.forEach((key, value) {
        if (value is List) {
          result[key] = List<String>.from(value.map((e) => e.toString()));
        } else if (value is String) {
          result[key] = [value];
        }
      });
      
      return result;
    } catch (e) {
      return null;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'statusCode': statusCode,
      'errorCode': errorCode,
      'message': message,
      'details': details,
      'suggestedActions': suggestedActions,
      'timestamp': timestamp,
      'requestId': requestId,
      'context': context,
      'fieldErrors': fieldErrors,
      'documentationUrl': documentationUrl,
      'retryable': retryable,
    };
  }

  @override
  List<Object?> get props => [
    statusCode,
    errorCode,
    message,
    details,
    suggestedActions,
    timestamp,
    requestId,
    context,
    fieldErrors,
    documentationUrl,
    retryable,
  ];

  /// Creates a user-friendly error summary
  String get userFriendlySummary {
    final buffer = StringBuffer();
    buffer.writeln('Error: $message');
    
    if (suggestedActions != null && suggestedActions!.isNotEmpty) {
      buffer.writeln('\nWhat you can do:');
      for (int i = 0; i < suggestedActions!.length; i++) {
        buffer.writeln('${i + 1}. ${suggestedActions![i]}');
      }
    }
    
    if (retryable == true) {
      buffer.writeln('\nThis operation can be retried.');
    }
    
    return buffer.toString();
  }

  /// Creates a technical summary for developers
  String get technicalSummary {
    final buffer = StringBuffer();
    buffer.writeln('HTTP $statusCode - $errorCode');
    if (requestId != null) buffer.writeln('Request ID: $requestId');
    if (timestamp != null) buffer.writeln('Timestamp: $timestamp');
    if (details != null) buffer.writeln('Details: $details');
    
    if (context != null && context!.isNotEmpty) {
      buffer.writeln('Context: $context');
    }
    
    if (fieldErrors != null && fieldErrors!.isNotEmpty) {
      buffer.writeln('Field Errors:');
      fieldErrors!.forEach((field, errors) {
        buffer.writeln('  $field: ${errors.join(', ')}');
      });
    }
    
    return buffer.toString();
  }
}