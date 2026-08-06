import 'package:flutter/material.dart';
import '../services/geocoding_service.dart';
import '../core/app_theme.dart';

/// Widget that displays a location name from coordinates
/// Shows coordinates while loading, then replaces with place name
class LocationNameWidget extends StatefulWidget {
  final double latitude;
  final double longitude;
  final bool showCoordinates;
  final TextStyle? style;
  final bool shortName;

  const LocationNameWidget({
    super.key,
    required this.latitude,
    required this.longitude,
    this.showCoordinates = true,
    this.style,
    this.shortName = false,
  });

  @override
  State<LocationNameWidget> createState() => _LocationNameWidgetState();
}

class _LocationNameWidgetState extends State<LocationNameWidget> {
  String? _locationName;
  bool _isLoading = true;
  final _geocodingService = GeocodingService();

  @override
  void initState() {
    super.initState();
    _loadLocationName();
  }

  @override
  void didUpdateWidget(LocationNameWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.latitude != widget.latitude ||
        oldWidget.longitude != widget.longitude) {
      _loadLocationName();
    }
  }

  Future<void> _loadLocationName() async {
    setState(() => _isLoading = true);
    
    try {
      final name = widget.shortName
          ? await _geocodingService.getShortLocationName(
              widget.latitude, widget.longitude)
          : await _geocodingService.getLocationName(
              widget.latitude, widget.longitude);
      
      if (mounted) {
        setState(() {
          _locationName = name;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _locationName = null;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Text(
        widget.showCoordinates
            ? '${widget.latitude.toStringAsFixed(4)}, ${widget.longitude.toStringAsFixed(4)}'
            : 'Loading location...',
        style: widget.style ??
            const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
      );
    }

    if (_locationName == null || _locationName!.isEmpty) {
      return Text(
        '${widget.latitude.toStringAsFixed(4)}, ${widget.longitude.toStringAsFixed(4)}',
        style: widget.style ??
            const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
      );
    }

    // Show location name with optional coordinates below
    if (widget.showCoordinates) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _locationName!,
            style: widget.style ??
                const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                ),
          ),
          Text(
            '${widget.latitude.toStringAsFixed(4)}, ${widget.longitude.toStringAsFixed(4)}',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
              fontFamily: 'monospace',
            ),
          ),
        ],
      );
    }

    // Just show location name
    return Text(
      _locationName!,
      style: widget.style ??
          const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 12,
          ),
    );
  }
}
