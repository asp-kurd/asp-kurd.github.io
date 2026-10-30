/// ل Android/iOS (ئەپا ئاسایی) Web Push نینە.
bool get pushSupported => false;
String get pushPermission => 'unsupported';
Future<Map<String, dynamic>?> subscribePush(String vapidPublicKey) async => null;
String get platformKind => 'other';
bool get isStandalone => true;
bool get canPromptInstall => false;
Future<bool> promptInstall() async => false;
