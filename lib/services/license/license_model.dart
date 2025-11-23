import 'dart:convert';

class LicenseModel {
  final String customerId;
  final String customerName;
  final String deviceFingerprint;
  final DateTime issuedOn;
  final DateTime? expiresOn;
  final List<String> features;
  final String signature;

  LicenseModel({
    required this.customerId,
    required this.customerName,
    required this.deviceFingerprint,
    required this.issuedOn,
    this.expiresOn,
    required this.features,
    required this.signature,
  });

  Map<String, dynamic> toJson() {
    return {
      'customer_id': customerId,
      'customer_name': customerName,
      'device_fingerprint': deviceFingerprint,
      'issued_on': issuedOn.toIso8601String(),
      'expires_on': expiresOn?.toIso8601String(),
      'features': features,
      'signature': signature,
    };
  }

  factory LicenseModel.fromJson(Map<String, dynamic> json) {
    return LicenseModel(
      customerId: json['customer_id'] as String,
      customerName: json['customer_name'] as String,
      deviceFingerprint: json['device_fingerprint'] as String,
      issuedOn: DateTime.parse(json['issued_on'] as String),
      expiresOn: json['expires_on'] != null ? DateTime.parse(json['expires_on'] as String) : null,
      features: List<String>.from(json['features'] as List),
      signature: json['signature'] as String,
    );
  }

  String toJsonString() {
    return json.encode(toJson());
  }

  factory LicenseModel.fromJsonString(String jsonString) {
    return LicenseModel.fromJson(json.decode(jsonString));
  }

  bool isExpired() {
    if (expiresOn == null) return false;
    return DateTime.now().isAfter(expiresOn!);
  }

  bool hasFeature(String feature) {
    return features.contains(feature);
  }
}
