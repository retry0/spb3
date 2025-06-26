import 'package:json_annotation/json_annotation.dart';
import 'spb_model.dart';

part 'spb_response.g.dart';

@JsonSerializable()
class SpbResponse {
  final bool success;
  final String? message;
  final List<SpbModel>? data;

  SpbResponse({required this.success, this.message, this.data});

  factory SpbResponse.fromJson(Map<String, dynamic> json) {
    // Handle different API response formats
    if (json.containsKey('data') && json['data'] is List) {
      return _$SpbResponseFromJson(json);
    } else if (json.containsKey('data') &&
        json['data'] is Map<String, dynamic>) {
      // Handle case where data is an object with list inside
      final dataObj = json['data'] as Map<String, dynamic>;
      if (dataObj.containsKey('items') && dataObj['items'] is List) {
        return SpbResponse(
          success: json['success'] as bool? ?? true,
          message: json['message'] as String?,
          data:
              (dataObj['items'] as List)
                  .map((e) => SpbModel.fromJson(e as Map<String, dynamic>))
                  .toList(),
        );
      }
    }

    // Default case - try to parse as is
    return _$SpbResponseFromJson(json);
  }

  Map<String, dynamic> toJson() => _$SpbResponseToJson(this);
}
