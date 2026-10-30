/// ل Android/iOS (ئەپا ئاسایی) Web Push نینە.
bool get pushSupported => false;
String get pushPermission => 'unsupported';
Future<Map<String, dynamic>?> subscribePush(String vapidPublicKey) async => null;
