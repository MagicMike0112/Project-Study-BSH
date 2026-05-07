import 'supabase_config.dart';

String buildGuestShareUrl(String identifier, {Uri? currentBase}) {
  final trimmedId = identifier.trim();
  final base = currentBase ?? Uri.base;

  String normalizedBase;
  if (base.scheme.startsWith('http') && base.hasAuthority) {
    normalizedBase = base.origin.replaceAll(RegExp(r'[#/]+$'), '');
  } else {
    normalizedBase = kPublicShareBaseUrl.replaceAll(RegExp(r'[#/]+$'), '');
  }

  if (trimmedId.isEmpty) {
    return '$normalizedBase/#/share';
  }
  return '$normalizedBase/#/share/$trimmedId';
}
