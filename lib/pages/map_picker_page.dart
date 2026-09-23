// ignore_for_file: deprecated_member_use

part of '../main.dart';

class MapPickerPage extends StatefulWidget {
  const MapPickerPage({
    super.key,
    required this.strings,
    required this.currentLocation,
    required this.selectedLocation,
    required this.mapStyle,
    required this.onMapStyleChanged,
    required this.onToggleLanguage,
    required this.onToggleTheme,
    required this.onCurrentLocationChanged,
    required this.onSelectedLocationChanged,
    required this.focusRequestVersion,
  });

  final AppStrings strings;
  final LatLng? currentLocation;
  final LatLng? selectedLocation;
  final AppMapStyle mapStyle;
  final ValueChanged<AppMapStyle> onMapStyleChanged;
  final VoidCallback onToggleLanguage;
  final VoidCallback onToggleTheme;
  final ValueChanged<LatLng> onCurrentLocationChanged;
  final ValueChanged<LatLng> onSelectedLocationChanged;
  final int focusRequestVersion;

  @override
  State<MapPickerPage> createState() => _MapPickerPageState();
}

class _NavigationOption {
  const _NavigationOption({
    required this.id,
    required this.label,
    required this.icon,
    required this.uri,
  });

  final String id;
  final String label;
  final IconData icon;
  final Uri uri;
}

double calculateBearingBetweenPoints(LatLng from, LatLng to) {
  final lat1 = from.latitude * math.pi / 180;
  final lat2 = to.latitude * math.pi / 180;
  final deltaLon = (to.longitude - from.longitude) * math.pi / 180;

  final y = math.sin(deltaLon) * math.cos(lat2);
  final x = math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * math.cos(lat2) * math.cos(deltaLon);

  final angle = math.atan2(y, x) * 180 / math.pi;
  return (angle + 360) % 360;
}

class _MapPickerPageState extends State<MapPickerPage> {
  final MapController _mapController = MapController();
  StreamSubscription<Position>? _positionSubscription;
  LatLng? _currentLocation;
  LatLng? _selectedLocation;
  List<LatLng> _routePoints = const [];
  LatLng? _pendingMovePoint;
  double _mapRotationDeg = 0;
  bool _isNavigationActive = false;
  bool _isFollowingCurrentLocation = false;
  bool _isMapReady = false;
  bool _isLoading = false;
  String? _error;
  int _lastHandledFocusRequestVersion = -1;

  Future<List<_NavigationOption>> _buildNavigationOptions(LatLng target, {LatLng? origin}) async {
    final options = <_NavigationOption>[];
    final isArabic = widget.strings.isArabic;
    final routeOrigin = origin ?? _currentLocation ?? target;

    if (!kIsWeb && Platform.isIOS) {
      final appleUri = Uri.parse(
        'maps://?saddr=${routeOrigin.latitude},${routeOrigin.longitude}&daddr=${target.latitude},${target.longitude}&dirflg=d',
      );
      final canOpenApple = await canLaunchUrl(appleUri);
      if (canOpenApple) {
        options.add(
          _NavigationOption(
            id: 'apple_maps',
            label: isArabic ? 'خرائط Apple' : 'Apple Maps',
            icon: Icons.map_outlined,
            uri: appleUri,
          ),
        );
      }
    }

    if (!kIsWeb) {
      final googleAppUri = Uri.parse(
        'comgooglemaps://?saddr=${routeOrigin.latitude},${routeOrigin.longitude}&daddr=${target.latitude},${target.longitude}&directionsmode=driving',
      );
      final canOpenGoogleApp = await canLaunchUrl(googleAppUri);
      if (canOpenGoogleApp) {
        options.add(
          _NavigationOption(
            id: 'google_maps_app',
            label: isArabic ? 'Google Maps (تطبيق)' : 'Google Maps (App)',
            icon: Icons.map,
            uri: googleAppUri,
          ),
        );
      }

      final wazeUri = Uri.parse('waze://?ll=${target.latitude},${target.longitude}&navigate=yes');
      final canOpenWaze = await canLaunchUrl(wazeUri);
      if (canOpenWaze) {
        options.add(
          _NavigationOption(
            id: 'waze',
            label: 'Waze',
            icon: Icons.navigation_outlined,
            uri: wazeUri,
          ),
        );
      }
    }

    final googleWebUri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&origin=${routeOrigin.latitude},${routeOrigin.longitude}&destination=${target.latitude},${target.longitude}',
    );
    options.add(
      _NavigationOption(
        id: 'google_maps_web',
        label: isArabic ? 'Google Maps (ويب)' : 'Google Maps (Web)',
        icon: Icons.public,
        uri: googleWebUri,
      ),
    );

    return options;
  }

  Future<void> _launchNavigationOption(_NavigationOption option, LatLng target) async {
    final launched = await launchUrl(option.uri, mode: LaunchMode.externalApplication);
    if (!mounted) {
      return;
    }

    if (launched) {
      unawaited(
        AppLogger.logUsage(
          'go_navigation',
          details:
              '${option.id}|${target.latitude.toStringAsFixed(6)},${target.longitude.toStringAsFixed(6)}',
        ),
      );
      return;
    }

    _showMessage(widget.strings.isArabic ? 'تعذر بدء التنقل' : 'Unable to start navigation');
  }

  Future<void> _openNavigationPicker(LatLng target) async {
    final options = await _buildNavigationOptions(target, origin: _currentLocation);
    if (!mounted) {
      return;
    }

    if (options.isEmpty) {
      _showMessage(
        widget.strings.isArabic
            ? 'تعذر فتح تطبيق التنقل على هذا الجهاز'
            : 'Unable to open a navigation app on this device',
      );
      unawaited(AppLogger.logError('no_navigation_app', context: 'open_navigation_picker'));
      return;
    }

    if (options.length == 1) {
      await _launchNavigationOption(options.first, target);
      return;
    }

    final selected = await showModalBottomSheet<_NavigationOption>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text(
                  widget.strings.isArabic ? 'اختر تطبيق الملاحة' : 'Choose Navigation App',
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
              ),
              ...options.map(
                (option) => ListTile(
                  leading: Icon(option.icon),
                  title: Text(option.label),
                  onTap: () => Navigator.of(sheetContext).pop(option),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (selected != null) {
      await _launchNavigationOption(selected, target);
    }
  }

  Future<void> _openNavigation() async {
    final target = _selectedLocation ?? _currentLocation;
    if (target == null) {
      _showMessage(
        widget.strings.isArabic
            ? 'لا يوجد موقع متاح للانتقال'
            : 'No location available for navigation',
      );
      return;
    }

    try {
      await _openNavigationPicker(target);
    } catch (e) {
      unawaited(AppLogger.logError(e.toString(), context: 'open_navigation'));
      _showMessage(
        widget.strings.isArabic
            ? 'حدث خطا اثناء فتح التنقل: $e'
            : 'Error while opening navigation: $e',
      );
    }
  }

  Future<void> _toggleNavigation() async {
    if (_isNavigationActive) {
      setState(() {
        _routePoints = const [];
        _isNavigationActive = false;
      });
      _showMessage(widget.strings.isArabic ? 'تم إخفاء مسار التنقل' : 'Navigation route hidden');
      return;
    }

    if (_currentLocation == null || (_selectedLocation == null && _currentLocation == null)) {
      _showMessage(
        widget.strings.isArabic
            ? 'يجب تحديد موقعك الحالي ونقطة الوجهة أولاً'
            : 'Current location and destination must be available first',
      );
      return;
    }

    final target = _selectedLocation ?? _currentLocation;
    if (target == null) {
      _showMessage(
        widget.strings.isArabic
            ? 'لا توجد وجهة للتنقل إليها'
            : 'No destination available for navigation',
      );
      return;
    }

    await _startDirectNavigation();
  }

  Future<void> _startDirectNavigation() async {
    final origin = _currentLocation;
    final target = _selectedLocation ?? _currentLocation;

    if (origin == null || target == null) {
      _showMessage(
        widget.strings.isArabic
            ? 'يجب تحديد موقعك الحالي ونقطة الوجهة أولاً'
            : 'Current location and destination must be available first',
      );
      return;
    }

    if (!_isMapReady) {
      _pendingMovePoint = origin;
    }

    final routePoints = await NavigationService.fetchRoadRoute(origin, target);
    final bearing = NavigationService.calculateBearingBetweenPoints(origin, target);
    final heading = (bearing + 360) % 360;

    if (_isMapReady) {
      final dynamic controller = _mapController;
      controller.rotate(heading);
    }

    setState(() {
      _mapRotationDeg = heading;
      _routePoints = routePoints;
      _isNavigationActive = true;
    });
    _moveMapSafely(origin, 16);

    _showMessage(
      widget.strings.isArabic
          ? 'وضع التنقل المباشر مفعل: يتبع المسار على الطرق'
          : 'Direct navigation enabled: following road route',
    );
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _zoomIn() {
    if (!_isMapReady) {
      return;
    }
    final target = _selectedLocation ?? _currentLocation;
    if (target == null) {
      return;
    }
    final nextZoom = (_mapController.camera.zoom + 1).clamp(2.0, 20.0);
    _mapController.move(target, nextZoom);
  }

  void _zoomOut() {
    if (!_isMapReady) {
      return;
    }
    final target = _selectedLocation ?? _currentLocation;
    if (target == null) {
      return;
    }
    final nextZoom = (_mapController.camera.zoom - 1).clamp(2.0, 20.0);
    _mapController.move(target, nextZoom);
  }

  void _focusCurrentLocation() {
    final target = _currentLocation;
    if (target == null) {
      _showMessage(
        widget.strings.isArabic ? 'موقعي الحالي غير متاح' : 'Current location is unavailable',
      );
      return;
    }
    setState(() {
      _isFollowingCurrentLocation = true;
    });
    _moveMapSafely(target, 15);
  }

  void _toggleFollowCurrentLocation() {
    if (_isFollowingCurrentLocation) {
      setState(() {
        _isFollowingCurrentLocation = false;
      });
      _showMessage(
        widget.strings.isArabic
            ? 'تم إيقاف متابعة الموقع الحالي'
            : 'Stopped following current location',
      );
      return;
    }

    if (_currentLocation == null) {
      _showMessage(
        widget.strings.isArabic ? 'موقعي الحالي غير متاح' : 'Current location is unavailable',
      );
      return;
    }

    setState(() {
      _isFollowingCurrentLocation = true;
    });
    _moveMapSafely(_currentLocation!, 15);
    _showMessage(
      widget.strings.isArabic ? 'تمت متابعة الموقع الحالي' : 'Following current location',
    );
  }

  void _focusSelectedLocation() {
    final target = _selectedLocation;
    if (target == null) {
      _showMessage(widget.strings.isArabic ? 'لا يوجد موقع مختار بعد' : 'No selected location yet');
      return;
    }
    _moveMapSafely(target, 15);
  }

  void _fitMapToVisiblePoints() {
    if (!_isMapReady) {
      return;
    }

    final points = <LatLng>[?_currentLocation, ?_selectedLocation];

    if (points.isEmpty) {
      _showMessage(widget.strings.isArabic ? 'لا يوجد نقاط لعرضها' : 'No points to fit');
      return;
    }

    if (points.length == 1) {
      _mapController.move(points.first, 12);
      unawaited(AppLogger.logUsage('fit_map_view', details: 'single_point'));
      return;
    }

    final bounds = LatLngBounds.fromPoints(points);
    _mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(56)));
    unawaited(AppLogger.logUsage('fit_map_view', details: 'multi_point'));
  }

  void _resetNorthUp() {
    if (!_isMapReady) {
      return;
    }

    try {
      // Use dynamic call to stay compatible with flutter_map API changes across versions.
      final dynamic controller = _mapController;
      controller.rotate(0.0);
      if (mounted) {
        setState(() {
          _mapRotationDeg = 0;
        });
      }
      unawaited(AppLogger.logUsage('reset_north_up'));
    } catch (_) {
      _showMessage(
        widget.strings.isArabic ? 'تعذر إعادة الاتجاه للشمال' : 'Unable to reset heading',
      );
    }
  }

  Future<void> _showManualCoordinateInput() async {
    final xController = TextEditingController();
    final yController = TextEditingController();
    var inputType = _CoordinateInputType.qnd;
    String? validationMessage;

    try {
      final selectedPoint = await showDialog<LatLng>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              final isArabic = widget.strings.isArabic;
              final xLabel = inputType == _CoordinateInputType.qnd
                  ? (isArabic ? 'Easting (X)' : 'Easting (X)')
                  : (isArabic ? 'Longitude' : 'Longitude');
              final yLabel = inputType == _CoordinateInputType.qnd
                  ? (isArabic ? 'Northing (Y)' : 'Northing (Y)')
                  : (isArabic ? 'Latitude' : 'Latitude');

              return AlertDialog(
                title: Text(isArabic ? 'إضافة إحداثية' : 'Add Coordinate'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SegmentedButton<_CoordinateInputType>(
                        segments: [
                          ButtonSegment<_CoordinateInputType>(
                            value: _CoordinateInputType.qnd,
                            label: const Text('QND'),
                          ),
                          ButtonSegment<_CoordinateInputType>(
                            value: _CoordinateInputType.wgs84,
                            label: const Text('WGS84'),
                          ),
                        ],
                        selected: {inputType},
                        onSelectionChanged: (selection) {
                          if (selection.isEmpty) {
                            return;
                          }
                          setDialogState(() {
                            inputType = selection.first;
                            validationMessage = null;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: xController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: xLabel,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: yController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: yLabel,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      if (validationMessage != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          validationMessage!,
                          style: TextStyle(color: Theme.of(context).colorScheme.error),
                        ),
                      ],
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: Text(isArabic ? 'إلغاء' : 'Cancel'),
                  ),
                  FilledButton(
                    onPressed: () {
                      final x = _parseCoordinate(xController.text);
                      final y = _parseCoordinate(yController.text);

                      if (x == null || y == null) {
                        setDialogState(() {
                          validationMessage = isArabic
                              ? 'أدخل قيمة رقمية صحيحة في الحقول المطلوبة'
                              : 'Enter valid numeric values in both fields';
                        });
                        return;
                      }
                      final result = _convertToLatLng(inputType: inputType, x: x, y: y);

                      if (result == null) {
                        return;
                      }

                      Navigator.of(dialogContext).pop(result);
                    },
                    child: Text(isArabic ? 'تحديد' : 'Set'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (!mounted || selectedPoint == null) {
        return;
      }

      setState(() {
        _selectedLocation = selectedPoint;
      });
      widget.onSelectedLocationChanged(selectedPoint);
      _moveMapSafely(selectedPoint, 15);

      unawaited(
        AppLogger.logUsage(
          'manual_coordinate_added',
          details:
              '${selectedPoint.latitude.toStringAsFixed(6)},${selectedPoint.longitude.toStringAsFixed(6)}',
        ),
      );
    } finally {
      xController.dispose();
      yController.dispose();
    }
  }

  double? _parseCoordinate(String? value) {
    if (value == null) {
      return null;
    }
    final normalized = value.trim().replaceAll(',', '.');
    if (normalized.isEmpty) {
      return null;
    }
    return double.tryParse(normalized);
  }

  LatLng? _convertToLatLng({
    required _CoordinateInputType inputType,
    required double x,
    required double y,
  }) {
    final isArabic = widget.strings.isArabic;
    try {
      if (inputType == _CoordinateInputType.qnd) {
        return CoordinateConverter.qndToWgs(easting: x, northing: y);
      }

      final lat = y;
      final lng = x;
      final isLatValid = lat >= -90 && lat <= 90;
      final isLngValid = lng >= -180 && lng <= 180;
      if (!isLatValid || !isLngValid) {
        _showMessage(
          isArabic
              ? 'قيم WGS84 غير صحيحة. خط العرض بين -90 و90 وخط الطول بين -180 و180.'
              : 'Invalid WGS84 values. Latitude must be -90..90 and longitude -180..180.',
        );
        return null;
      }
      return LatLng(lat, lng);
    } catch (e) {
      unawaited(AppLogger.logError(e.toString(), context: 'manual_coordinate_convert'));
      _showMessage(
        isArabic ? 'تعذر تحويل الإحداثية المدخلة' : 'Unable to convert the entered coordinate',
      );
      return null;
    }
  }

  void _updateMapRotationFromHeading(double heading) {
    if (!_isMapReady || heading.isNaN || heading.isInfinite) {
      return;
    }

    final rotation = heading % 360;
    _mapRotationDeg = rotation;
    _mapController.rotate(rotation);
  }

  Future<void> _startTrackingCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          return;
        }
      }

      _positionSubscription?.cancel();
      _positionSubscription =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 5,
            ),
          ).listen((position) {
            if (!mounted) {
              return;
            }

            final point = LatLng(position.latitude, position.longitude);
            setState(() {
              _currentLocation = point;
              _selectedLocation ??= point;
            });

            widget.onCurrentLocationChanged(point);
            widget.onSelectedLocationChanged(_selectedLocation ?? point);

            if (position.heading.isFinite) {
              _updateMapRotationFromHeading(position.heading);
            }

            if (_isFollowingCurrentLocation) {
              _moveMapSafely(point, 15);
            }
          });
    } catch (e) {
      unawaited(AppLogger.logError(e.toString(), context: 'start_tracking_current_location'));
    }
  }

  @override
  void initState() {
    super.initState();
    _currentLocation = widget.currentLocation;
    _selectedLocation = widget.selectedLocation;
    unawaited(_startTrackingCurrentLocation());
    _loadCurrentLocation();
  }

  @override
  void didUpdateWidget(covariant MapPickerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentLocation != oldWidget.currentLocation) {
      _currentLocation = widget.currentLocation;
    }
    if (widget.selectedLocation != oldWidget.selectedLocation) {
      _selectedLocation = widget.selectedLocation;
    }

    if (widget.focusRequestVersion != oldWidget.focusRequestVersion &&
        widget.focusRequestVersion != _lastHandledFocusRequestVersion) {
      _lastHandledFocusRequestVersion = widget.focusRequestVersion;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _focusCurrentLocation();
      });
    }
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentLocation() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _error = 'خدمة الموقع غير مفعلة على الجهاز.';
          _isLoading = false;
        });
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() {
          _error = 'تم رفض صلاحية الموقع.';
          _isLoading = false;
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      final point = LatLng(position.latitude, position.longitude);

      setState(() {
        _currentLocation = point;
        _selectedLocation ??= point;
        _isLoading = false;
      });
      widget.onCurrentLocationChanged(point);
      widget.onSelectedLocationChanged(_selectedLocation!);

      if (position.heading.isFinite) {
        _updateMapRotationFromHeading(position.heading);
      }

      unawaited(AppLogger.logUsage('location_loaded'));

      _moveMapSafely(point, 14);
    } catch (e) {
      unawaited(AppLogger.logError(e.toString(), context: 'load_current_location'));
      setState(() {
        _error = 'حدث خطا اثناء قراءة الموقع: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final initialPoint = _currentLocation ?? const LatLng(24.7136, 46.6753);
    final isSatellite = widget.mapStyle == AppMapStyle.satellite;
    final isHybrid = widget.mapStyle == AppMapStyle.hybrid;
    final currentLanguage = widget.strings.isArabic ? AppLanguage.ar : AppLanguage.en;
    final currentMapStyleLabel = switch (widget.mapStyle) {
      AppMapStyle.street => widget.strings.mapStreet,
      AppMapStyle.satellite => widget.strings.mapSatellite,
      AppMapStyle.hybrid => widget.strings.mapHybrid,
    };
    final mapStyleIcon = switch (widget.mapStyle) {
      AppMapStyle.street => Icons.map_outlined,
      AppMapStyle.satellite => Icons.satellite_alt,
      AppMapStyle.hybrid => Icons.layers_outlined,
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.strings.mapTitle),
        actions: [
          PopupMenuButton<AppMapStyle>(
            tooltip: '${widget.strings.toggleMap}: $currentMapStyleLabel',
            icon: Icon(mapStyleIcon),
            initialValue: widget.mapStyle,
            onSelected: widget.onMapStyleChanged,
            itemBuilder: (context) => [
              CheckedPopupMenuItem<AppMapStyle>(
                value: AppMapStyle.street,
                checked: widget.mapStyle == AppMapStyle.street,
                child: Row(
                  children: [
                    const Icon(Icons.map_outlined),
                    const SizedBox(width: 10),
                    Expanded(child: Text(widget.strings.mapStreet)),
                  ],
                ),
              ),
              CheckedPopupMenuItem<AppMapStyle>(
                value: AppMapStyle.satellite,
                checked: widget.mapStyle == AppMapStyle.satellite,
                child: Row(
                  children: [
                    const Icon(Icons.satellite_alt),
                    const SizedBox(width: 10),
                    Expanded(child: Text(widget.strings.mapSatellite)),
                  ],
                ),
              ),
              CheckedPopupMenuItem<AppMapStyle>(
                value: AppMapStyle.hybrid,
                checked: widget.mapStyle == AppMapStyle.hybrid,
                child: Row(
                  children: [
                    const Icon(Icons.layers_outlined),
                    const SizedBox(width: 10),
                    Expanded(child: Text(widget.strings.mapHybrid)),
                  ],
                ),
              ),
            ],
          ),
          PopupMenuButton<AppLanguage>(
            tooltip: widget.strings.toggleLanguage,
            icon: const Icon(Icons.translate),
            initialValue: currentLanguage,
            onSelected: (selected) {
              if (selected != currentLanguage) {
                widget.onToggleLanguage();
              }
            },
            itemBuilder: (context) => [
              CheckedPopupMenuItem<AppLanguage>(
                value: AppLanguage.ar,
                checked: currentLanguage == AppLanguage.ar,
                child: Text(widget.strings.langArabic),
              ),
              CheckedPopupMenuItem<AppLanguage>(
                value: AppLanguage.en,
                checked: currentLanguage == AppLanguage.en,
                child: Text(widget.strings.langEnglish),
              ),
            ],
          ),
          IconButton(
            onPressed: widget.onToggleTheme,
            icon: Icon(
              Theme.of(context).brightness == Brightness.dark ? Icons.light_mode : Icons.dark_mode,
            ),
            tooltip: widget.strings.toggleTheme,
          ),
          IconButton(
            onPressed: _loadCurrentLocation,
            icon: const Icon(Icons.my_location),
            tooltip: 'تحديث الموقع الحالي',
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: initialPoint,
                initialZoom: 13,
                interactionOptions: InteractionOptions(flags: InteractiveFlag.all),
                onMapReady: () {
                  _isMapReady = true;
                  _mapRotationDeg = _mapController.camera.rotation;
                  if (_pendingMovePoint != null) {
                    _mapController.move(_pendingMovePoint!, 14);
                    _pendingMovePoint = null;
                  }
                },
                onPositionChanged: (position, _) {
                  final dynamic camera = position;
                  final rotation = (camera.rotation as num?)?.toDouble() ?? 0;
                  if ((rotation - _mapRotationDeg).abs() < 0.1 || !mounted) {
                    return;
                  }
                  setState(() {
                    _mapRotationDeg = rotation;
                  });
                },
                onTap: (_, latLng) {
                  setState(() {
                    _selectedLocation = latLng;
                  });
                  unawaited(
                    AppLogger.logUsage(
                      'map_point_selected',
                      details:
                          '${latLng.latitude.toStringAsFixed(6)},${latLng.longitude.toStringAsFixed(6)}',
                    ),
                  );
                  widget.onSelectedLocationChanged(latLng);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: isSatellite || isHybrid
                      ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                      : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.archeology.picklocation',
                  subdomains: isSatellite || isHybrid ? const [] : const ['a', 'b', 'c'],
                ),
                if (isHybrid)
                  TileLayer(
                    urlTemplate:
                        'https://{s}.basemaps.cartocdn.com/light_only_labels/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.archeology.picklocation',
                    subdomains: const ['a', 'b', 'c', 'd'],
                  ),
                if (_isNavigationActive)
                  if (_routePoints.length > 1)
                    PolylineLayer(
                      polylines: <Polyline<Object>>[
                        Polyline<Object>(points: _routePoints, strokeWidth: 5, color: Colors.blue),
                      ],
                    )
                  else if (_currentLocation != null && _selectedLocation != null)
                    PolylineLayer(
                      polylines: <Polyline<Object>>[
                        Polyline<Object>(
                          points: NavigationService.buildDirectRoute(
                            _currentLocation!,
                            _selectedLocation!,
                          ),
                          strokeWidth: 5,
                          color: Colors.blue,
                        ),
                      ],
                    ),
                MarkerLayer(
                  markers: [
                    if (_currentLocation != null)
                      Marker(
                        point: _currentLocation!,
                        width: 48,
                        height: 48,
                        child: const Icon(Icons.my_location, size: 32, color: Colors.blue),
                      ),
                    if (_selectedLocation != null)
                      Marker(
                        point: _selectedLocation!,
                        width: 58,
                        height: 58,
                        child: Transform.rotate(
                          angle:
                              ((NavigationService.calculateBearingBetweenPoints(
                                    _currentLocation ?? _selectedLocation!,
                                    _selectedLocation!,
                                  ) +
                                  180) *
                              math.pi /
                              180),
                          child: const Icon(Icons.arrow_drop_up, size: 54, color: Colors.red),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            left: 12,
            top: 112,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface.withOpacity(0.92),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.35),
                  width: 1,
                ),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 3)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildMapToolButton(
                    icon: Icons.add,
                    tooltip: widget.strings.isArabic ? 'تكبير' : 'Zoom in',
                    onPressed: _zoomIn,
                  ),
                  _buildMapToolButton(
                    icon: Icons.remove,
                    tooltip: widget.strings.isArabic ? 'تصغير' : 'Zoom out',
                    onPressed: _zoomOut,
                  ),
                  const Divider(height: 1),
                  _buildMapToolButton(
                    icon: _isFollowingCurrentLocation
                        ? Icons.location_searching
                        : Icons.my_location,
                    tooltip: _isFollowingCurrentLocation
                        ? (widget.strings.isArabic
                              ? 'إيقاف متابعة الموقع الحالي'
                              : 'Stop following current location')
                        : (widget.strings.isArabic
                              ? 'تتبع الموقع الحالي'
                              : 'Follow current location'),
                    onPressed: _toggleFollowCurrentLocation,
                    accentColor: _isFollowingCurrentLocation
                        ? Theme.of(context).colorScheme.primary
                        : null,
                    filled: _isFollowingCurrentLocation,
                  ),
                  _buildMapToolButton(
                    icon: Icons.place_outlined,
                    tooltip: widget.strings.isArabic
                        ? 'الانتقال للموقع المختار'
                        : 'Focus selected location',
                    onPressed: _focusSelectedLocation,
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    decoration: BoxDecoration(
                      color: _isNavigationActive
                          ? Theme.of(context).colorScheme.primary.withOpacity(0.18)
                          : Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _buildMapToolButton(
                      icon: _isNavigationActive
                          ? Icons.directions_car_filled
                          : Icons.directions_car_filled,
                      tooltip: _isNavigationActive
                          ? (widget.strings.isArabic
                                ? 'إخفاء مسار التنقل'
                                : 'Hide navigation route')
                          : (widget.strings.isArabic
                                ? 'إظهار مسار التنقل'
                                : 'Show navigation route'),
                      onPressed: _toggleNavigation,
                      accentColor: _isNavigationActive
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      filled: true,
                    ),
                  ),
                  _buildMapToolButton(
                    icon: Icons.explore_outlined,
                    tooltip: widget.strings.isArabic ? 'تثبيت الشمال للأعلى' : 'North up',
                    onPressed: _resetNorthUp,
                    iconRotation: -_mapRotationDeg,
                  ),
                  const Divider(height: 1),
                  _buildMapToolButton(
                    icon: Icons.fit_screen,
                    tooltip: widget.strings.isArabic
                        ? 'عرض كل النقاط على الخريطة'
                        : 'Fit points in view',
                    onPressed: _fitMapToVisiblePoints,
                  ),
                  _buildMapToolButton(
                    icon: Icons.edit_location_alt_outlined,
                    tooltip: widget.strings.isArabic
                        ? 'إضافة إحداثية QND أو WGS84'
                        : 'Add QND or WGS84 coordinate',
                    onPressed: _showManualCoordinateInput,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 18,
            child: Opacity(
              opacity: 0.96,
              child: FilledButton.icon(
                onPressed: _openNavigation,
                style: FilledButton.styleFrom(
                  elevation: 6,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
                icon: const Icon(Icons.directions),
                label: Text(widget.strings.isArabic ? 'انطلق' : 'Go'),
              ),
            ),
          ),
          if (_error != null)
            Positioned(
              left: 16,
              right: 16,
              top: MediaQuery.of(context).padding.top + 8,
              child: SafeArea(
                bottom: false,
                child: Material(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Text(
                      _error!,
                      style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
                    ),
                  ),
                ),
              ),
            ),
          if (_isLoading)
            const Positioned.fill(
              child: IgnorePointer(
                ignoring: true,
                child: Center(
                  child: SizedBox(
                    width: 34,
                    height: 34,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                ),
              ),
            ),
          Align(
            alignment: Alignment.bottomCenter,
            child: DraggableScrollableSheet(
              initialChildSize: 0.28,
              minChildSize: 0.16,
              maxChildSize: 0.78,
              snap: true,
              snapSizes: const [0.16, 0.28, 0.6, 0.78],
              builder: (context, scrollController) {
                return Material(
                  color: Theme.of(context).colorScheme.surface,
                  elevation: 18,
                  shadowColor: Colors.black26,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                  clipBehavior: Clip.antiAlias,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isCompact = constraints.maxWidth < 600;
                      final theme = Theme.of(context);

                      return CustomScrollView(
                        controller: scrollController,
                        slivers: [
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(
                                isCompact ? 12 : 16,
                                10,
                                isCompact ? 12 : 16,
                                10,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Center(
                                    child: Container(
                                      width: 46,
                                      height: 5,
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.25),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.map_outlined,
                                        size: 20,
                                        color: theme.colorScheme.primary,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          widget.strings.isArabic
                                              ? 'المواقع والإحداثيات'
                                              : 'Locations and coordinates',
                                          style: theme.textTheme.titleSmall?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                ],
                              ),
                            ),
                          ),
                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(
                              isCompact ? 12 : 16,
                              0,
                              isCompact ? 12 : 16,
                              16 + MediaQuery.of(context).padding.bottom,
                            ),
                            sliver: SliverToBoxAdapter(
                              child: isCompact
                                  ? Column(
                                      children: [
                                        _buildLocationSummaryCard(
                                          title: widget.strings.currentLocation,
                                          wgs84: _formatCoordinates(_currentLocation),
                                          qnd: _formatQndCoordinates(_currentLocation),
                                          color: Colors.blue,
                                          icon: Icons.location_history,
                                          compact: true,
                                        ),
                                        const SizedBox(height: 10),
                                        _buildLocationSummaryCard(
                                          title: widget.strings.selectedLocation,
                                          wgs84: _formatCoordinates(_selectedLocation),
                                          qnd: _formatQndCoordinates(_selectedLocation),
                                          color: Colors.red,
                                          icon: Icons.place,
                                          compact: true,
                                        ),
                                      ],
                                    )
                                  : Row(
                                      children: [
                                        Expanded(
                                          child: _buildLocationSummaryCard(
                                            title: widget.strings.currentLocation,
                                            wgs84: _formatCoordinates(_currentLocation),
                                            qnd: _formatQndCoordinates(_currentLocation),
                                            color: Colors.blue,
                                            icon: Icons.location_history,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: _buildLocationSummaryCard(
                                            title: widget.strings.selectedLocation,
                                            wgs84: _formatCoordinates(_selectedLocation),
                                            qnd: _formatQndCoordinates(_selectedLocation),
                                            color: Colors.red,
                                            icon: Icons.place,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copyCoordinateValue(String value, {required String label}) async {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return;
    }

    await Clipboard.setData(ClipboardData(text: normalized));
    if (!mounted) {
      return;
    }

    _showMessage(
      widget.strings.isArabic ? 'تم نسخ $label إلى الحافظة' : 'Copied $label to clipboard',
    );
  }

  Widget _buildMapToolButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    double iconRotation = 0,
    Color? accentColor,
    bool filled = false,
  }) {
    final iconWidget = Transform.rotate(angle: iconRotation * math.pi / 180, child: Icon(icon));
    final button = IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      style: filled
          ? IconButton.styleFrom(
              backgroundColor: accentColor?.withOpacity(0.12),
              foregroundColor: accentColor,
            )
          : null,
      icon: iconWidget,
    );

    return Tooltip(message: tooltip, child: button);
  }

  Widget _buildLocationSummaryCard({
    required String title,
    required String wgs84,
    required String qnd,
    required Color color,
    required IconData icon,
    bool compact = false,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.all(compact ? 10 : 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.28), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: compact ? 32 : 36,
            height: compact ? 32 : 36,
            margin: EdgeInsets.only(top: compact ? 0 : 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.14),
              borderRadius: BorderRadius.circular(compact ? 10 : 12),
            ),
            child: Icon(icon, color: color, size: compact ? 18 : 20),
          ),
          SizedBox(width: compact ? 8 : 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    fontSize: compact ? 10.5 : null,
                  ),
                ),
                SizedBox(height: compact ? 6 : 8),
                _buildMiniCoordinateRow(label: 'WGS', value: wgs84, color: color, compact: compact),
                SizedBox(height: compact ? 4 : 6),
                _buildMiniCoordinateRow(label: 'QND', value: qnd, color: color, compact: compact),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniCoordinateRow({
    required String label,
    required String value,
    required Color color,
    bool compact = false,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _copyCoordinateValue(value, label: label),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: compact ? 34 : 40,
              child: Text(
                label,
                textDirection: TextDirection.ltr,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  fontSize: compact ? 10 : null,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                maxLines: compact ? 3 : 2,
                overflow: TextOverflow.ellipsis,
                textDirection: TextDirection.ltr,
                style: (compact ? theme.textTheme.bodySmall : theme.textTheme.bodyMedium)?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: compact ? 11.5 : null,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Icon(Icons.copy_all_rounded, size: compact ? 13 : 14),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCoordinates(LatLng? point) {
    if (point == null) {
      return widget.strings.isArabic ? 'غير متاح' : 'Unavailable';
    }
    return '${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}';
  }

  String _formatQndCoordinates(LatLng? point) {
    if (point == null) {
      return widget.strings.isArabic ? 'غير متاح' : 'Unavailable';
    }

    try {
      final qnd = CoordinateConverter.wgsToQnd(
        latitude: point.latitude,
        longitude: point.longitude,
      );
      return '${qnd.x.toStringAsFixed(3)}, ${qnd.y.toStringAsFixed(3)}';
    } catch (e) {
      unawaited(AppLogger.logError(e.toString(), context: 'format_qnd_coordinates'));
      return widget.strings.isArabic ? 'تعذر التحويل' : 'Conversion failed';
    }
  }

  void _moveMapSafely(LatLng point, double zoom) {
    if (_isMapReady) {
      _mapController.move(point, zoom);
      return;
    }
    _pendingMovePoint = point;
  }
}

enum _CoordinateInputType { qnd, wgs84 }
