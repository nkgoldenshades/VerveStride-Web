import 'dart:async';

import 'dart:convert';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

import 'package:flutter/material.dart';

import 'package:flutter/services.dart';

import 'package:geolocator/geolocator.dart' hide ActivityType;

import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:vervestride/utils/polyline_codec.dart';
import 'package:vervestride/utils/route_share_utils.dart';

import '../../core/app_theme.dart';

import '../../core/ui_constants.dart';

import '../../services/local_storage_service.dart';

import '../../services/excel_service.dart';

import '../../services/activity_tracking_service.dart';

import '../../widgets/gradient_scaffold.dart';

import '../../widgets/ad_banner_widget.dart';

import '../../widgets/section_card.dart';

import '../../widgets/shimmer_loader.dart';

import '../../widgets/empty_state_view.dart';

import '../../widgets/location_name_widget.dart';

import 'package:vervestride/models/activity_data.dart';

import 'home_screen.dart';



class ActivityScreen extends StatefulWidget {

  const ActivityScreen({super.key});



  @override

  State<ActivityScreen> createState() => _ActivityScreenState();

}



class _ActivityScreenState extends State<ActivityScreen> {

  final LocalStorageService _storage = LocalStorageService.instance;

  final ActivityTrackingService _trackingService =

      ActivityTrackingService.instance;

  static const MethodChannel _platformShareChannel =
      MethodChannel('com.vervestride.app/share');



  List<ActivityData> _todayActivities = [];

  final TextEditingController _noteController = TextEditingController();

  ActivityType _selectedActivityType = ActivityType.running;

  bool _hasLocationPermission = false;

  ActivityData? _currentActivity;

  bool _isLoadingActivities = true;



  @override

  void initState() {

    super.initState();

    _trackingService.addListener(_onTrackingUpdate);

    _initializeLocation();

    _loadTodayActivities();

  }

  String _buildGoogleMapsRouteUrl(List<Map<String, double>> route) {
    return RouteShareUtils.buildGoogleMapsRouteUrl(route);
  }

  Future<void> _openRouteInMaps(List<Map<String, double>> route) async {
    final url = _buildGoogleMapsRouteUrl(route);
    if (url.isEmpty) {
      _showMessage('No route data available');
      return;
    }

    final uri = Uri.tryParse(url);
    if (uri == null) {
      _showMessage('Invalid map link');
      return;
    }

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      _showMessage('Could not open Maps app');
    }
  }



  @override

  void dispose() {

    _trackingService.removeListener(_onTrackingUpdate);

    _noteController.dispose();

    super.dispose();

  }



  void _onTrackingUpdate() {

    if (mounted) setState(() {});

  }



  Future<void> _initializeLocation() async {

    try {

      if (kIsWeb) {

        try {

          await Geolocator.getCurrentPosition(

            desiredAccuracy: LocationAccuracy.high,

          );

          if (!mounted) return;

          setState(() {

            _hasLocationPermission = true;

          });



          await _trackingService.initialize();

        } catch (e) {

          debugPrint('Web geolocation error: $e');

          if (!mounted) return;

          setState(() {

            _hasLocationPermission = false;

          });

          _showMessage('Location permission is required for activity tracking');

        }

        return;

      }



      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {

        serviceEnabled = await Geolocator.openLocationSettings();

        if (!mounted) return;

        if (!serviceEnabled) {

          setState(() => _hasLocationPermission = false);

          _showMessage(

            'Location services are disabled. Please enable them in settings.',

          );

          return;

        }

      }



      final permission = await Geolocator.checkPermission();

      final resolvedPermission = permission == LocationPermission.denied

          ? await Geolocator.requestPermission()

          : permission;



      if (!mounted) return;



      if (resolvedPermission == LocationPermission.denied ||

          resolvedPermission == LocationPermission.deniedForever) {

        setState(() => _hasLocationPermission = false);

        _showMessage(

            'Location permission denied. Please enable it in settings.');

        return;

      }



      setState(() => _hasLocationPermission = true);

      await _trackingService.initialize();

    } catch (e) {

      debugPrint('Location initialization error: $e');

      if (!mounted) return;

      setState(() => _hasLocationPermission = false);

      _showMessage('Failed to get location: $e');

    }

  }



  Future<void> _loadTodayActivities() async {

    if (mounted) {

      setState(() => _isLoadingActivities = true);

    }



    try {

      final today = DateTime.now();

      final activities = await _storage.getActivitiesForDate(today);



      final mapped = activities.map((a) {

        final createdAt = a.createdAt;

        final end = createdAt.add(Duration(minutes: a.durationMinutes));



        final routePoints = <Map<String, double>>[];

        var notes = '';

        if (a.routeData.isNotEmpty) {

          try {

            final parsed = jsonDecode(a.routeData);

            if (parsed is Map) {
              final polyline = parsed['route_polyline']?.toString();
              if (polyline != null && polyline.isNotEmpty) {
                routePoints.addAll(PolylineCodec.decodeRoute(polyline));
              } else if (parsed['route_points'] is List) {
                final points = parsed['route_points'] as List;

                for (final p in points) {
                  if (p is Map && p['lat'] != null && p['lng'] != null) {
                    final lat = (p['lat'] as num).toDouble();
                    final lng = (p['lng'] as num).toDouble();
                    routePoints.add({'lat': lat, 'lng': lng});
                  }
                }
              }
            }



            final parsedNotes = parsed is Map ? parsed['notes'] : null;

            if (parsedNotes is String) {

              notes = parsedNotes;

            }

          } catch (_) {

            // ignore malformed route data

          }

        }



        return ActivityData(

          id: a.uuid,

          type: ActivityType.values.firstWhere(

            (t) => t.name == a.activityType,

            orElse: () => ActivityType.running,

          ),

          startTime: createdAt,

          endTime: end,

          distance: a.distanceKm,

          calories: (a.caloriesBurned).toDouble(),

          notes: notes,

          route: routePoints,

        );

      }).toList();



      mapped.sort((a, b) => b.startTime.compareTo(a.startTime));



      if (!mounted) return;

      setState(() {

        _todayActivities = mapped;

        _isLoadingActivities = false;

      });

    } catch (e) {

      debugPrint('Error loading activities: $e');

      if (mounted) {

        setState(() => _isLoadingActivities = false);

      }

    }

  }



  void _startActivity() {

    if (!_hasLocationPermission) {

      _initializeLocation();

      _showMessage('Location permission is required for activity tracking');

      return;

    }



    if (_trackingService.currentPosition == null) {

      _showMessage('Waiting for location signal...');

      return;

    }



    _trackingService.startActivity(_selectedActivityType);

    _showMessage('${_selectedActivityType.displayName} started!');

  }



  void _stopActivity() async {

    if (_trackingService.currentActivity == null) return;



    final name = _trackingService.currentActivity!.type.displayName;

    await _trackingService.stopActivity(

      notes: _noteController.text.trim().isEmpty

          ? null

          : _noteController.text.trim(),

    );



    _noteController.clear();

    await _loadTodayActivities();

    _showMessage('$name stopped!');

  }



  Map<String, dynamic> _activityToPayload(ActivityData activity) {

    return {

      'id': activity.id,

      'activity_type': activity.type.name,

      'activity_date': activity.startTime.toIso8601String(),

      'distance_km': activity.distance,

      'duration_minutes': activity.durationSeconds == 0
          ? 0
          : ((activity.durationSeconds + 59) ~/ 60),

      'calories_burned': activity.calories.toInt(),

      'route_data': jsonEncode({

        'route_polyline': PolylineCodec.encodeRoute(activity.route),

        'notes': activity.notes,

      }),

      'created_at': DateTime.now().toIso8601String(),

    };

  }



  void _showMessage(String message) {

    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(

      SnackBar(

        content: Text(message),

        backgroundColor: AppColors.primary,

        duration: const Duration(seconds: 2),

      ),

    );

  }



  Future<void> _exportToExcel() async {

    try {

      final activitiesData = _todayActivities

          .map(

            (activity) => {

              'date': activity.startTime.toString().split(' ')[0],

              'activityType': activity.type.displayName,

              'durationMinutes': activity.durationSeconds ~/ 60,

              'distanceKm': activity.distance,

              'caloriesBurned': activity.calories.toInt(),

              'startTime': activity.startTime.toString().split('.')[0],

              'endTime': activity.endTime?.toString().split('.')[0] ?? '',

              'notes': activity.notes,

              'route': activity.route,

            },

          )

          .toList();



      await ExcelService.exportActivitiesToExcel(activitiesData);



      if (mounted) {

        _showMessage('Activities exported to Excel successfully!');

      }

    } catch (e) {

      debugPrint('Error exporting to Excel: $e');

      if (mounted) {

        _showMessage('Failed to export to Excel: $e');

      }

    }

  }



  @override

  Widget build(BuildContext context) {

    return GradientScaffold(

      appBar: AppBar(

        title: const Text(

          'Activity',

          style: TextStyle(fontWeight: FontWeight.bold),

        ),

        backgroundColor: Colors.transparent,

      ),

      body: SingleChildScrollView(

        padding: const EdgeInsets.all(20),

        child: Column(

          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            _buildActivityTypeSelector(),

            const SizedBox(height: 20),

            _buildNoteField(),

            if (_trackingService.currentActivity != null) ...[

              _buildActivityStats(),

              const SizedBox(height: 12),

              _buildNotesButton(),

              const SizedBox(height: 20),

            ],

            if (_getDisplayedRoute().isNotEmpty) ...[

              _buildRoutePointsCard(),

              const SizedBox(height: 16),

            ],

            _buildTravelLocationButton(),

            const SizedBox(height: 20),

            if (_trackingService.currentActivity == null)

              _buildPrimaryButton(

                label: 'START ACTIVITY',

                onPressed: _startActivity,

                icon: _selectedActivityType.icon,

                colors: [

                  _selectedActivityType.color,

                  _selectedActivityType.color.withOpacity(0.8),

                ],

              )

            else

              Row(

                children: [

                  Expanded(

                    child: _buildPrimaryButton(

                      label: _trackingService.currentActivity!.isPaused

                          ? 'RESUME'

                          : 'PAUSE',

                      onPressed: _trackingService.currentActivity!.isPaused

                          ? _trackingService.resumeActivity

                          : _trackingService.pauseActivity,

                      icon: _trackingService.currentActivity!.isPaused

                          ? Icons.play_arrow

                          : Icons.pause,

                      colors: [Colors.orange.shade400, Colors.orange.shade700],

                    ),

                  ),

                  const SizedBox(width: 12),

                  Expanded(

                    child: _buildPrimaryButton(

                      label: 'STOP',

                      onPressed: _stopActivity,

                      icon: Icons.stop,

                      colors: [Colors.red.shade400, Colors.red.shade700],

                    ),

                  ),

                ],

              ),

            const SizedBox(height: 20),

            _buildTodaySummary(),

            const SizedBox(height: 16),

            _buildExportButton(),

            const SizedBox(height: 20),

            _buildTodayActivitiesList(),

            if (!kIsWeb) ...[

              const SizedBox(height: 16),

              const SafeArea(

                top: false,

                child: Center(

                  child: AdBannerWidget(

                    adUnitId: AdBannerWidget.bannerActivitiesId,

                  ),

                ),

              ),

            ],

          ],

        ),

      ),

    );

  }



  List<Map<String, double>> _getDisplayedRoute() {

    if (_trackingService.currentActivity != null)

      return _trackingService.currentActivity!.route;

    if (_todayActivities.isNotEmpty) return _todayActivities.first.route;

    return const <Map<String, double>>[];

  }



  Widget _buildTravelLocationButton() {

    final route = _getDisplayedRoute();

    return _buildPrimaryButton(

      label: 'VIEW ROUTE',

      onPressed: () => _showRouteDialog(route),

      icon: Icons.map,

      colors: [

        AppColors.secondary,

        AppColors.secondary.withOpacity(0.85),

      ],

    );

  }



  void _showRouteDialog(List<Map<String, double>> route) {

    showDialog(

      context: context,

      builder: (context) => AlertDialog(

        title: Text('Route Points (${route.length})'),

        content: SizedBox(

          width: double.maxFinite,

          height: 400,

          child: route.isEmpty

              ? const Center(child: Text('No route data available'))

              : Column(

                  children: [

                    const Padding(

                      padding: EdgeInsets.only(bottom: 8),

                      child: Text(

                        'Tip: In Google Maps you may see letters like A, B, C... These are just route stops/waypoints (A = start, last letter = end).',

                        style: TextStyle(fontSize: 12),

                      ),

                    ),

                    Expanded(

                      child: ListView.builder(

                        itemCount: route.length,

                        itemBuilder: (context, index) {

                          final point = route[index];

                          return ListTile(

                            leading: Icon(

                              index == 0

                                  ? Icons.play_arrow

                                  : index == route.length - 1

                                      ? Icons.stop

                                      : Icons.location_on,

                              color: index == 0

                                  ? Colors.green

                                  : index == route.length - 1

                                      ? Colors.red

                                      : AppColors.secondary,

                            ),

                            title: Text(

                              'Point ${index + 1}',

                              style:

                                  const TextStyle(fontWeight: FontWeight.bold),

                            ),

                            subtitle: LocationNameWidget(

                              latitude: point['lat']!,

                              longitude: point['lng']!,

                              showCoordinates: true,

                              style: const TextStyle(

                                fontSize: 12,

                              ),

                            ),

                          );

                        },

                      ),

                    ),

                  ],

                ),

        ),

        actions: [

          TextButton(

            onPressed: () => Navigator.pop(context),

            child: const Text('CLOSE'),

          ),

          if (route.isNotEmpty) ...[

            TextButton(

              onPressed: () {

                Navigator.pop(context);

                _copyRouteToClipboard(route);

              },

              child: const Text('COPY ALL'),

            ),

            TextButton(

              onPressed: () {

                Navigator.pop(context);

                _openRouteInMaps(route);

              },

              child: const Text('OPEN IN MAPS'),

            ),

            TextButton(

              onPressed: () {

                Navigator.pop(context);

                _shareActivityRoute(ActivityData(

                  id: 'temp',

                  type: ActivityType.running,

                  startTime: DateTime.now(),

                  route: route,

                ));

              },

              child: const Text('SHARE LINK'),

            ),

          ],

        ],

      ),

    );

  }



  void _copyRouteToClipboard(List<Map<String, double>> route) async {

    final routeText = route.map((p) => '${p['lat']},${p['lng']}').join('\n');



    try {

      await Clipboard.setData(ClipboardData(text: routeText));

      if (mounted) {

        _showMessage('Route points copied to clipboard');

      }

    } catch (e) {

      if (mounted) {

        _showMessage('Failed to copy: $e');

      }

    }

  }



  void _shareActivityRoute(ActivityData activity) async {

    if (activity.route.isEmpty) {

      _showMessage('No route points to share for this activity');

      return;

    }



    try {

      final url = _buildGoogleMapsRouteUrl(activity.route);

      final shareText =
          'VerveStride: ${activity.type.displayName} route\n${activity.formattedDistance} in ${activity.formattedDuration}${activity.notes.trim().isEmpty ? '' : '\n\nNotes: ${activity.notes.trim()}'}\n\nGoogle Maps: $url\n\nShared from VerveStride';
      final subject = 'VerveStride - ${activity.type.displayName} Route';

      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        try {
          await _platformShareChannel.invokeMethod<void>(
            'shareRouteWithMaps',
            {
              'text': shareText,
              'subject': subject,
              'mapsUrl': url,
            },
          );
          return;
        } catch (_) {
          // Fallback to share_plus
        }
      }

      if (!mounted) return;

      final box = context.findRenderObject() as RenderBox?;
      final sharePosition =
          box != null ? box.localToGlobal(Offset.zero) & box.size : Rect.zero;

      await Share.share(
        shareText,
        subject: subject,
        sharePositionOrigin: sharePosition,
      );
    } catch (e) {
      _showMessage('Error sharing route: $e');
    }

  }



  Widget _buildNotesButton() {

    final hasNotes = _currentActivity?.notes.trim().isNotEmpty ?? false;

    return SizedBox(

      width: double.infinity,

      child: OutlinedButton.icon(

        onPressed: _currentActivity == null ? null : _editCurrentNotes,

        icon: Icon(

          hasNotes ? Icons.sticky_note_2 : Icons.sticky_note_2_outlined,

          color: AppColors.textPrimary,

        ),

        label: Text(

          hasNotes ? 'EDIT NOTES' : 'ADD NOTES',

          style: const TextStyle(

            color: AppColors.textPrimary,

            fontWeight: FontWeight.bold,

          ),

        ),

        style: OutlinedButton.styleFrom(

          side: BorderSide(color: Colors.white.withOpacity(0.2)),

          padding: const EdgeInsets.symmetric(vertical: 14),

          shape:

              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),

        ),

      ),

    );

  }



  Future<void> _editCurrentNotes() async {

    if (_currentActivity == null) return;



    final controller = TextEditingController(text: _currentActivity!.notes);

    final result = await showModalBottomSheet<String>(

      context: context,

      isScrollControlled: true,

      backgroundColor: AppColors.card,

      shape: const RoundedRectangleBorder(

        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),

      ),

      builder: (context) {

        return Padding(

          padding: EdgeInsets.only(

            left: 16,

            right: 16,

            top: 16,

            bottom: MediaQuery.of(context).viewInsets.bottom + 16,

          ),

          child: Column(

            mainAxisSize: MainAxisSize.min,

            crossAxisAlignment: CrossAxisAlignment.start,

            children: [

              const Text(

                'Notes',

                style: TextStyle(

                  color: AppColors.textPrimary,

                  fontSize: 18,

                  fontWeight: FontWeight.bold,

                ),

              ),

              const SizedBox(height: 12),

              TextField(

                controller: controller,

                maxLines: 5,

                autofocus: true,

                decoration: const InputDecoration(

                  hintText: 'Add notes about your activity...',

                  border: OutlineInputBorder(),

                ),

              ),

              const SizedBox(height: 16),

              Row(

                mainAxisAlignment: MainAxisAlignment.end,

                children: [

                  TextButton(

                    onPressed: () => Navigator.pop(context),

                    child: const Text('CANCEL'),

                  ),

                  const SizedBox(width: 8),

                  ElevatedButton(

                    onPressed: () {

                      Navigator.pop(context, controller.text);

                    },

                    child: const Text('SAVE'),

                  ),

                ],

              ),

            ],

          ),

        );

      },

    );



    if (result != null) {

      if (!mounted) return;

      // Notes are now handled by passing to stopActivity or through the service if we want live editing

      // For now, let's just keep them in the note controller or service

      _noteController.text = result;

    }

  }



  Widget _buildRoutePointsCard() {

    final route = _getDisplayedRoute();



    return Container(

      padding: UIConstants.cardPadding,

      decoration: BoxDecoration(

        color: AppColors.card.withOpacity(0.85),

        borderRadius: BorderRadius.circular(UIConstants.radiusLG),

        border: Border.all(color: Colors.white.withOpacity(0.1)),

      ),

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          const Text(

            'Stored Locations (Lat/Lng)',

            style: TextStyle(

              color: AppColors.textPrimary,

              fontSize: 16,

              fontWeight: FontWeight.bold,

            ),

          ),

          const SizedBox(height: 8),

          if (!_hasLocationPermission)

            const Text(

              'Location permission required to record points.',

              style: TextStyle(color: AppColors.textSecondary),

            )

          else if (_trackingService.currentPosition == null)

            const Text(

              'Acquiring GPS signal…',

              style: TextStyle(color: AppColors.textSecondary),

            )

          else if (route.isEmpty)

            const Text(

              'No points recorded yet. Start an activity to record your route.',

              style: TextStyle(color: AppColors.textSecondary),

            )

          else

            Column(

              children: route.take(8).map((p) {

                return Padding(

                  padding: const EdgeInsets.symmetric(vertical: 4),

                  child: Row(

                    children: [

                      Icon(

                        Icons.place,

                        size: 16,

                        color: AppColors.primary,

                      ),

                      const SizedBox(width: 8),

                      Expanded(

                        child: LocationNameWidget(

                          latitude: p['lat']!,

                          longitude: p['lng']!,

                          showCoordinates: true,

                        ),

                      ),

                    ],

                  ),

                );

              }).toList(),

            ),

          if (route.length > 8) ...[

            const SizedBox(height: 8),

            Text(

              '+${route.length - 8} more points',

              style: const TextStyle(color: AppColors.textSecondary),

            ),

          ],

        ],

      ),

    );

  }



  Widget _buildPrimaryButton({

    required String label,

    required VoidCallback onPressed,

    required IconData icon,

    required List<Color> colors,

  }) {

    return Container(

      width: double.infinity,

      decoration: BoxDecoration(

        borderRadius: BorderRadius.circular(UIConstants.radiusXL),

        gradient: LinearGradient(colors: colors),

      ),

      child: ElevatedButton(

        onPressed: onPressed,

        style: ElevatedButton.styleFrom(

          backgroundColor: Colors.transparent,

          shadowColor: Colors.transparent,

          minimumSize:

              const Size(double.infinity, UIConstants.standardButtonHeight),

          shape: RoundedRectangleBorder(

            borderRadius: BorderRadius.circular(UIConstants.radiusXL),

          ),

        ),

        child: Row(

          mainAxisAlignment: MainAxisAlignment.center,

          children: [

            Icon(icon, size: 24),

            const SizedBox(width: 12),

            Text(

              label,

              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),

            ),

          ],

        ),

      ),

    );

  }



  Widget _buildActivityTypeSelector() {

    return Column(

      crossAxisAlignment: CrossAxisAlignment.start,

      children: [

        const Text(

          'Select Activity Type',

          style: TextStyle(

            color: AppColors.textPrimary,

            fontSize: 18,

            fontWeight: FontWeight.bold,

          ),

        ),

        const SizedBox(height: 12),

        SingleChildScrollView(

          scrollDirection: Axis.horizontal,

          child: Row(

            children: [

              const SizedBox(width: 8),

              ...ActivityType.values.map((type) {

                final isSelected = _selectedActivityType == type;

                return Padding(

                  padding: EdgeInsets.only(

                    right: UIConstants.spacingXS,

                  ),

                  child: GestureDetector(

                    onTap: _trackingService.currentActivity == null

                        ? () {

                            setState(() {

                              _selectedActivityType = type;

                            });

                          }

                        : null,

                    child: Opacity(

                      opacity:

                          _trackingService.currentActivity == null ? 1.0 : 0.5,

                      child: AnimatedContainer(

                        duration: const Duration(milliseconds: 200),

                        width: 80, // Fixed width for all chips

                        height: 88, // Fixed height for all chips

                        decoration: BoxDecoration(

                          color: isSelected

                              ? type.color

                              : AppColors.card.withOpacity(0.7),

                          borderRadius:

                              BorderRadius.circular(UIConstants.radiusMD),

                          border: Border.all(

                            color: isSelected

                                ? type.color

                                : Colors.white.withOpacity(0.08),

                          ),

                          boxShadow: isSelected

                              ? [

                                  BoxShadow(

                                    color: type.color.withOpacity(0.3),

                                    blurRadius: 8,

                                    spreadRadius: 1,

                                  ),

                                ]

                              : null,

                        ),

                        child: Column(

                          mainAxisAlignment: MainAxisAlignment

                              .center, // Perfect vertical centering

                          children: [

                            Icon(

                              type.icon,

                              color: isSelected ? Colors.white : type.color,

                              size: 24,

                            ),

                            const SizedBox(height: UIConstants.spacingXS),

                            Text(

                              type.displayName,

                              style: TextStyle(

                                color: isSelected ? Colors.white : type.color,

                                fontSize: 12,

                                fontWeight: FontWeight.w600,

                              ),

                              textAlign: TextAlign.center,

                              maxLines: 2,

                              overflow: TextOverflow.ellipsis,

                            ),

                          ],

                        ),

                      ),

                    ),

                  ),

                );

              }).toList(),

              const SizedBox(width: 8),

            ],

          ),

        ),

      ],

    );

  }



  Widget _buildNoteField() {

    return Padding(

      padding: const EdgeInsets.symmetric(

          horizontal: UIConstants.paddingXL, vertical: UIConstants.paddingMD),

      child: TextField(

        controller: _noteController,

        decoration: InputDecoration(

          hintText: 'Add notes about your activity...',

          hintStyle:

              TextStyle(color: AppColors.textSecondary.withOpacity(0.6)),

          border: OutlineInputBorder(

            borderRadius: BorderRadius.circular(UIConstants.radiusMD),

            borderSide: BorderSide(

                color: AppColors.textSecondary.withOpacity(0.2)),

          ),

          focusedBorder: OutlineInputBorder(

            borderRadius: BorderRadius.circular(UIConstants.radiusMD),

            borderSide: BorderSide(color: AppColors.primary),

          ),

          filled: true,

          fillColor: Colors.white.withOpacity(0.05),

          contentPadding: UIConstants.cardPaddingCompact,

        ),

        style: const TextStyle(fontSize: 16),

        maxLines: 3,

      ),

    );

  }



  Widget _buildActivityStats() {

    final activity = _trackingService.currentActivity;

    if (activity == null) return const SizedBox();



    return Container(

      padding: UIConstants.cardPadding,

      decoration: BoxDecoration(

        color: AppColors.card.withOpacity(0.85),

        borderRadius: BorderRadius.circular(UIConstants.radiusLG),

        border: Border.all(color: Colors.white.withOpacity(0.1)),

      ),

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          Row(

            mainAxisAlignment: MainAxisAlignment.spaceBetween,

            children: [

              const Text(

                'Current Activity',

                style: TextStyle(

                  color: AppColors.textPrimary,

                  fontSize: 16,

                  fontWeight: FontWeight.bold,

                ),

              ),

              Icon(

                activity.type.icon,

                color: activity.type.color,

                size: 24,

              ),

            ],

          ),

          const SizedBox(height: 12),

          Text(

            'Type: ${activity.type.displayName}',

            style: const TextStyle(color: AppColors.textPrimary),

          ),

          const SizedBox(height: 4),

          Text(

            'Duration: ${activity.formattedDuration}',

            style: const TextStyle(color: AppColors.textPrimary),

          ),

          const SizedBox(height: 4),

          Text(

            'Distance: ${activity.formattedDistance}',

            style: const TextStyle(color: AppColors.textPrimary),

          ),

          const SizedBox(height: 4),

          Text(

            'Calories: ${activity.formattedCalories}',

            style: const TextStyle(color: AppColors.textPrimary),

          ),

        ],

      ),

    );

  }



  Widget _buildTodaySummary() {

    if (_todayActivities.isEmpty) return const SizedBox();



    final totalDistance = _todayActivities.fold<double>(

        0.0, (sum, activity) => sum + activity.distance);

    final totalCalories = _todayActivities.fold<double>(

        0.0, (sum, activity) => sum + activity.calories);

    final totalDuration = _todayActivities.fold<int>(

        0, (sum, activity) => sum + activity.durationSeconds);



    return SectionCard(

      title: 'Today\'s Summary',

      child: Column(

        children: [

          _buildSummaryRow('Activities', '${_todayActivities.length}'),

          _buildSummaryRow(

              'Total Distance', '${totalDistance.toStringAsFixed(2)} km'),

          _buildSummaryRow('Total Duration',

              '${(totalDuration ~/ 60)} min ${(totalDuration % 60)} sec'),

          _buildSummaryRow('Total Calories', '${totalCalories.toInt()} kcal'),

        ],

      ),

    );

  }



  Widget _buildSummaryRow(String label, String value) {

    return Padding(

      padding: const EdgeInsets.symmetric(vertical: 4),

      child: Row(

        mainAxisAlignment: MainAxisAlignment.spaceBetween,

        children: [

          Text(

            label,

            style: const TextStyle(

              color: AppColors.textSecondary,

              fontSize: 14,

            ),

          ),

          Text(

            value,

            style: const TextStyle(

              color: AppColors.textPrimary,

              fontSize: 14,

              fontWeight: FontWeight.bold,

            ),

          ),

        ],

      ),

    );

  }



  Widget _buildExportButton() {

    return _buildPrimaryButton(

      label: 'EXPORT TO EXCEL',

      onPressed: _exportToExcel,

      icon: Icons.file_download,

      colors: [

        AppColors.secondary,

        AppColors.secondary.withOpacity(0.85),

      ],

    );

  }



  Widget _buildTodayActivitiesList() {

    // Show shimmer loading

    if (_isLoadingActivities) {

      return SectionCard(

        title: 'Today\'s Activities',

        child: ShimmerList(itemCount: 3),

      );

    }



    // Show empty state

    if (_todayActivities.isEmpty) {

      return SectionCard(

        title: 'Today\'s Activities',

        child: EmptyStates.noActivities(

          onAdd: _startActivity,

        ),

      );

    }



    return SectionCard(

      title: 'Today\'s Activities',

      child: Column(

        children: _todayActivities.map((activity) {

          return Padding(

            padding: const EdgeInsets.only(bottom: 12),

            child: Container(

              padding: const EdgeInsets.all(12),

              decoration: BoxDecoration(

                color: AppColors.card.withOpacity(0.85),

                borderRadius: BorderRadius.circular(12),

                border: Border.all(color: Colors.white.withOpacity(0.1)),

              ),

              child: Column(

                crossAxisAlignment: CrossAxisAlignment.start,

                children: [

                  Row(

                    children: [

                      Icon(

                        activity.type.icon,

                        color: activity.type.color,

                        size: 20,

                      ),

                      const SizedBox(width: 8),

                      Expanded(

                        child: Column(

                          crossAxisAlignment: CrossAxisAlignment.start,

                          children: [

                            Text(

                              activity.type.displayName,

                              style: const TextStyle(

                                color: AppColors.textPrimary,

                                fontSize: 16,

                                fontWeight: FontWeight.bold,

                              ),

                            ),

                            const SizedBox(height: 4),

                            Text(

                              'Duration: ${activity.formattedDuration}',

                              style: const TextStyle(

                                color: AppColors.textSecondary,

                                fontSize: 12,

                              ),

                            ),

                            if (activity.type != ActivityType.workout &&

                                activity.type.name != 'workout') ...[

                              const SizedBox(height: 2),

                              Text(

                                'Distance: ${activity.formattedDistance}',

                                style: const TextStyle(

                                  color: AppColors.textSecondary,

                                  fontSize: 12,

                                ),

                              ),

                            ],

                            const SizedBox(height: 2),

                            Text(

                              'Started: ${activity.startTime.toString().split('.')[0]}',

                              style: const TextStyle(

                                fontSize: 12,

                                color: Colors.grey,

                              ),

                            ),

                            if (activity.endTime != null) ...[

                              const SizedBox(height: 6),

                              Text(

                                'Ended: ${activity.endTime!.toString().split('.')[0]}',

                                style: const TextStyle(

                                  fontSize: 12,

                                  color: Colors.grey,

                                ),

                              ),

                            ],

                            if (activity.notes.trim().isNotEmpty) ...[

                              const SizedBox(height: 6),

                              Text(

                                activity.notes.trim(),

                                maxLines: 2,

                                overflow: TextOverflow.ellipsis,

                                style: const TextStyle(

                                  fontSize: 12,

                                  color: AppColors.textSecondary,

                                ),

                              ),

                            ],

                          ],

                        ),

                      ),

                    ],

                  ),

                  const SizedBox(width: 8),

                  Column(

                    crossAxisAlignment: CrossAxisAlignment.end,

                    children: [

                      Text(

                        '${activity.calories.toInt()} kcal',

                        style: TextStyle(

                          color: AppColors.primary,

                          fontSize: 16,

                          fontWeight: FontWeight.bold,

                        ),

                      ),

                      const SizedBox(height: 8),

                      Row(

                        mainAxisAlignment: MainAxisAlignment.end,

                        mainAxisSize: MainAxisSize.min,

                        children: [

                          SizedBox(

                            width: 32,

                            height: 32,

                            child: IconButton(

                              icon: Icon(Icons.edit_outlined,

                                  color: AppColors.secondary, size: 16),

                              onPressed: () => _editActivity(activity),

                              padding: EdgeInsets.zero,

                              constraints: const BoxConstraints(

                                minWidth: 32,

                                minHeight: 32,

                              ),

                            ),

                          ),

                          SizedBox(

                            width: 32,

                            height: 32,

                            child: IconButton(

                              icon: Icon(Icons.share_outlined,

                                  color: AppColors.primary, size: 16),

                              onPressed: () => _shareActivityRoute(activity),

                              padding: EdgeInsets.zero,

                              constraints: const BoxConstraints(

                                minWidth: 32,

                                minHeight: 32,

                              ),

                            ),

                          ),

                          SizedBox(

                            width: 32,

                            height: 32,

                            child: IconButton(

                              icon: const Icon(Icons.delete_outline,

                                  color: Colors.redAccent, size: 16),

                              onPressed: () => _deleteActivity(activity),

                              padding: EdgeInsets.zero,

                              constraints: const BoxConstraints(

                                minWidth: 32,

                                minHeight: 32,

                              ),

                            ),

                          ),

                        ],

                      ),

                    ],

                  ),

                ],

              ),

            ),

          );

        }).toList(),

      ),

    );

  }



  Future<void> _editActivity(ActivityData activity) async {

    final isWorkout = activity.type.name == 'workout';

    final durationCtrl = TextEditingController(

        text: ((activity.durationSeconds + 59) ~/ 60).toString());

    final distanceCtrl = TextEditingController(

      text: activity.distance.toStringAsFixed(2),

    );

    final caloriesCtrl =

        TextEditingController(text: activity.calories.toStringAsFixed(0));

    final notesCtrl = TextEditingController(text: activity.notes);



    final navigator = Navigator.of(context);

    await showDialog(

      context: context,

      builder: (context) => AlertDialog(

        title: const Text('Edit Activity'),

        content: Column(

          mainAxisSize: MainAxisSize.min,

          children: [

            TextField(

              controller: durationCtrl,

              keyboardType: TextInputType.number,

              decoration:

                  const InputDecoration(labelText: 'Duration (minutes)'),

            ),

            if (!isWorkout)

              TextField(

                controller: distanceCtrl,

                keyboardType: TextInputType.number,

                decoration: const InputDecoration(labelText: 'Distance (km)'),

              ),

            TextField(

              controller: caloriesCtrl,

              keyboardType: TextInputType.number,

              decoration: const InputDecoration(labelText: 'Calories'),

            ),

            TextField(

              controller: notesCtrl,

              maxLines: 3,

              decoration: const InputDecoration(labelText: 'Notes'),

            ),

          ],

        ),

        actions: [

          TextButton(

            onPressed: () => navigator.pop(),

            child: const Text('Cancel'),

          ),

          TextButton(

            onPressed: () async {

              final newDurationMinutes = int.tryParse(durationCtrl.text) ?? 0;

              final newDistance =

                  isWorkout ? 0.0 : (double.tryParse(distanceCtrl.text) ?? 0);

              final newCalories = double.tryParse(caloriesCtrl.text) ?? 0;

              if (newDurationMinutes <= 0 || newDistance < 0 || newCalories < 0) {

                _showMessage('Invalid values');

                return;

              }

              final newEndTime =
                  activity.startTime.add(Duration(minutes: newDurationMinutes));

              final updated = activity.copyWith(

                endTime: newEndTime,

                distance: newDistance,

                calories: newCalories,

                notes: notesCtrl.text,

              );

              await _storage.updateActivity(

                  activity.id, _activityToPayload(updated));

              await _loadTodayActivities();

              if (mounted) navigator.pop();

              _showMessage('Activity updated');

            },

            child: const Text('Save'),

          ),

        ],

      ),

    );

  }



  Future<void> _deleteActivity(ActivityData activity) async {

    final confirmed = await showDialog<bool>(

      context: context,

      builder: (context) => AlertDialog(

        title: const Text('Delete Activity'),

        content: const Text('Are you sure you want to delete this activity?'),

        actions: [

          TextButton(

            onPressed: () => Navigator.pop(context, false),

            child: const Text('Cancel'),

          ),

          TextButton(

            onPressed: () => Navigator.pop(context, true),

            child: const Text('Delete'),

          ),

        ],

      ),

    );



    if (confirmed == true) {

      try {

        await _storage.deleteActivity(activity.id);

        await _loadTodayActivities();

        // Refresh home screen to update progress rings

        HomeScreen.globalRefresh();

        if (mounted) {

          _showMessage('Activity deleted');

        }

      } catch (e) {

        if (mounted) {

          _showMessage('Failed to delete activity: $e');

        }

      }

    }

  }

}


