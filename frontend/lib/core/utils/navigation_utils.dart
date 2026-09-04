import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/colors.dart';

class NavigationUtils {
  /// Opens an end-to-end route with ordered charging stops and destination.
  static Future<bool> openPlannedRoute({
    required double originLatitude,
    required double originLongitude,
    required double destinationLatitude,
    required double destinationLongitude,
    List<(double, double)> waypoints = const [],
    BuildContext? context,
  }) async {
    final query = <String, String>{
      'api': '1',
      'origin': '$originLatitude,$originLongitude',
      'destination': '$destinationLatitude,$destinationLongitude',
      'travelmode': 'driving',
      if (waypoints.isNotEmpty)
        'waypoints': waypoints
            .map((point) => '${point.$1},${point.$2}')
            .join('|'),
    };
    final routeUrl = Uri.https('www.google.com', '/maps/dir/', query);
    try {
      return await launchUrl(routeUrl, mode: LaunchMode.externalApplication);
    } catch (error) {
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open route navigation: $error'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return false;
    }
  }

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
        return await launchUrl(googleMapsUrl, mode: LaunchMode.platformDefault);
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
  static void copyCode(
    BuildContext context,
    String code, {
    String label = 'Start Code',
  }) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: AppColors.primary,
              size: 20,
            ),
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
