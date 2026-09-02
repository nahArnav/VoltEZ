import 'package:geocoding/geocoding.dart';

/// Helper utility for cleaning and formatting address suggestions,
/// removing Plus Codes (e.g. "FV38+53H"), deduplicating components, and ensuring
/// local subLocalities (e.g. Katraj, Baner, Viman Nagar) are included.
class AddressFormatter {
  static final RegExp _plusCodeRegex = RegExp(
    r'^[A-Z0-9]{2,8}\+[A-Z0-9]{2,4}$',
    caseSensitive: false,
  );

  static final RegExp _leadingPlusCodeRegex = RegExp(
    r'^[A-Z0-9]{2,8}\+[A-Z0-9]{2,4}\s*,\s*',
    caseSensitive: false,
  );

  /// Checks if a string is an Open Location Code / Plus Code.
  static bool isPlusCode(String? text) {
    if (text == null) return false;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    return _plusCodeRegex.hasMatch(trimmed) ||
        (trimmed.contains('+') && trimmed.length <= 12 && !trimmed.contains(' '));
  }

  /// Cleans raw API address strings (e.g. from Nominatim/Google API).
  static String cleanAddressString(String rawAddress) {
    if (rawAddress.trim().isEmpty) return rawAddress;

    // Strip leading Plus Code (e.g. "FV38+53H, Katraj, Pune" -> "Katraj, Pune")
    final cleaned = rawAddress.replaceFirst(_leadingPlusCodeRegex, '').trim();

    final parts = cleaned.split(',').map((p) => p.trim()).where((p) => p.isNotEmpty);
    final seen = <String>{};
    final uniqueParts = <String>[];

    for (final part in parts) {
      if (isPlusCode(part)) continue;
      final lower = part.toLowerCase();
      if (!seen.contains(lower)) {
        seen.add(lower);
        uniqueParts.add(part);
      }
    }

    return uniqueParts.isNotEmpty ? uniqueParts.join(', ') : rawAddress;
  }

  /// Formats native [Placemark] instances into human-friendly address labels.
  static String formatPlacemark(Placemark place, String fallbackQuery) {
    final parts = <String>[];

    // Include place name if not a Plus Code, not identical to street/postal code
    if (place.name != null &&
        place.name!.trim().isNotEmpty &&
        !isPlusCode(place.name) &&
        place.name != place.street &&
        place.name != place.postalCode) {
      parts.add(place.name!.trim());
    }

    // Include street if valid and not a Plus Code
    if (place.street != null &&
        place.street!.trim().isNotEmpty &&
        !isPlusCode(place.street) &&
        place.street != place.postalCode) {
      parts.add(place.street!.trim());
    }

    // Include subLocality (neighbourhood e.g. Katraj, Baner, Kothrud, Viman Nagar)
    if (place.subLocality != null &&
        place.subLocality!.trim().isNotEmpty &&
        !isPlusCode(place.subLocality)) {
      parts.add(place.subLocality!.trim());
    }

    // Include thoroughfare if present
    if (place.thoroughfare != null &&
        place.thoroughfare!.trim().isNotEmpty &&
        !isPlusCode(place.thoroughfare)) {
      parts.add(place.thoroughfare!.trim());
    }

    // Include locality (city e.g. Pune, Mumbai)
    if (place.locality != null &&
        place.locality!.trim().isNotEmpty &&
        !isPlusCode(place.locality)) {
      parts.add(place.locality!.trim());
    }

    // Include administrativeArea (state e.g. Maharashtra)
    if (place.administrativeArea != null &&
        place.administrativeArea!.trim().isNotEmpty &&
        !isPlusCode(place.administrativeArea)) {
      parts.add(place.administrativeArea!.trim());
    }

    final seen = <String>{};
    final uniqueParts = <String>[];
    for (final p in parts) {
      final lower = p.toLowerCase();
      if (!seen.contains(lower)) {
        seen.add(lower);
        uniqueParts.add(p);
      }
    }

    if (uniqueParts.isEmpty) {
      return cleanAddressString(fallbackQuery);
    }

    return uniqueParts.join(', ');
  }
}
