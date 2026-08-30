import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/colors.dart';

class NavigationUtils {
  /// Opens turn-by-turn driving directions to charger in Google Maps / Apple Maps.
  static Future<bool> openMapsNavigation({
    required double latitude,
    required double longitude,
    String? title,
    BuildContext? context,
  }) async {
    final encodedTitle = Uri.encodeComponent(title ?? 'VoltEZ EV Charger');
    final googleMapsUrl = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude&travelmode=driving',
    );
    final geoUrl = Uri.parse(
      'geo:$latitude,$longitude?q=$latitude,$longitude($encodedTitle)',
    );

    try {
      if (await canLaunchUrl(googleMapsUrl)) {
        return await launchUrl(
          googleMapsUrl,
          mode: LaunchMode.externalApplication,
        );
      } else if (await canLaunchUrl(geoUrl)) {
        return await launchUrl(geoUrl);
      } else {
        return await launchUrl(
          googleMapsUrl,
          mode: LaunchMode.platformDefault,
        );
      }
    } catch (e) {
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open map app: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return false;
    }
  }

  /// Copies OTP/Start Code to clipboard with visual confirmation.
  static void copyCode(BuildContext context, String code, {String label = 'Start Code'}) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Text('$label $code copied to clipboard!'),
          ],
        ),
        backgroundColor: AppColors.surface,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
