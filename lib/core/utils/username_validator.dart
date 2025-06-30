import 'package:flutter/services.dart';

class UserNameValidator {
  /// Validates userName format and returns error message if invalid
  static String? validateFormat(String? userName) {
    if (userName == null || userName.isEmpty) {
      return 'Harap masukkan nama pengguna';
    }
    return null; // Valid userName
  }

  /// Normalizes userName by converting to lowercase and trimming
  static String normalize(String userName) {
    return userName.toLowerCase().trim();
  }

  /// Checks if userName is available (format validation only)
  static bool isValidFormat(String userName) {
    return validateFormat(userName) == null;
  }
}

/// Custom text formatter to convert input to lowercase
class LowerCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toLowerCase(),
      selection: newValue.selection,
    );
  }
}
