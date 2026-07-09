import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

enum AppLanguage { ar, en }

enum AppMapStyle { street, satellite }

class AppStrings {
  const AppStrings(this.language);

  final AppLanguage language;

  bool get isArabic => language == AppLanguage.ar;

  String get mapTitle => isArabic ? 'اختيار الموقع' : 'Pick Location';
  String get photosTitle => isArabic ? 'اضافة صور وتفاصيل' : 'Photos & Details';
  String get reviewTitle => isArabic ? 'مراجعة البيانات والإرسال' : 'Review & Send';
  String get feedbackTitle => isArabic ? 'الملاحظات والمتابعة' : 'Feedback & Logs';
  String get navMap => isArabic ? 'الخريطة' : 'Map';
  String get navPhotos => isArabic ? 'الصور والتفاصيل' : 'Photos';
  String get navReview => isArabic ? 'المراجعة والإرسال' : 'Review';
  String get navFeedback => isArabic ? 'الملاحظات' : 'Feedback';
  String get currentLocation => isArabic ? 'موقعي الحالي' : 'My Location';
  String get selectedLocation => isArabic ? 'الموقع المختار' : 'Selected Location';
  String get details => isArabic ? 'التفاصيل' : 'Details';
  String get location => isArabic ? 'الموقع' : 'Location';
  String get photos => isArabic ? 'الصور' : 'Photos';
  String get noPhotos => isArabic ? 'لم يتم اضافة صور بعد' : 'No photos yet';
  String get saveData => isArabic ? 'حفظ البيانات' : 'Save Data';
  String get chooseGallery => isArabic ? 'اختيار من المعرض' : 'Pick from Gallery';
  String get takePhoto => isArabic ? 'التقاط صورة' : 'Take Photo';
  String get mapStreet => isArabic ? 'خرائط جغرافية' : 'Street';
  String get mapSatellite => isArabic ? 'صور جوية' : 'Satellite';
  String get sendWithAttachments => isArabic ? 'ارسال بمرفقات (مشاركة)' : 'Send with Attachments';
  String get sendWithoutAttachments =>
      isArabic ? 'ارسال بدون مرفقات (mailto)' : 'Send without Attachments';
  String get copyReport => isArabic ? 'نسخ نص التقرير' : 'Copy Report';
  String get copySubject => isArabic ? 'نسخ عنوان البريد' : 'Copy Subject';
  String get comments => isArabic ? 'الملاحظات' : 'Comments';
  String get themeDark => isArabic ? 'داكن' : 'Dark';
  String get themeLight => isArabic ? 'فاتح' : 'Light';
  String get langArabic => isArabic ? 'العربية' : 'Arabic';
  String get langEnglish => isArabic ? 'الإنجليزية' : 'English';
  String get toggleLanguage => isArabic ? 'اللغة' : 'Language';
  String get toggleTheme => isArabic ? 'الوضع' : 'Theme';
  String get toggleMap => isArabic ? 'الخريطة' : 'Map';
  String get notesSaved => isArabic ? 'تم حفظ الملاحظة محليا' : 'Feedback saved locally';
  String get addNoteBeforeSave => isArabic ? 'اكتب ملاحظة قبل الحفظ' : 'Write a note before saving';
  String get noLogs => isArabic ? 'لا توجد سجلات بعد' : 'No logs yet';
  String get noFeedback => isArabic ? 'لا توجد ملاحظات محفوظة بعد' : 'No feedback yet';
  String get versionLabel => isArabic ? 'نسخة التطبيق' : 'App version';
  String get errorCountLabel => isArabic ? 'عدد الأخطاء المسجلة' : 'Errors logged';
  String get eventCountLabel => isArabic ? 'عدد الأحداث المسجلة' : 'Events logged';
  String get chooseEmail => isArabic ? 'البريد الالكتروني للمستلم' : 'Recipient email';
}

void main() {
  FlutterError.onError = (details) {
    unawaited(AppLogger.logError(details.exceptionAsString(), context: 'flutter_error'));
    FlutterError.presentError(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    unawaited(AppLogger.logError(error.toString(), context: 'platform_error'));
    return false;
  };

  runApp(const PickLocationApp());
}

class AppLogger {
  static const _logKey = 'app_logs_v1';
  static const _feedbackKey = 'app_feedback_v1';
  static const _maxLogs = 200;

  static Future<void> logUsage(String event, {String? details}) {
    return _append(type: 'usage', message: event, details: details);
  }

  static Future<void> logError(String error, {String? context}) {
    return _append(type: 'error', message: error, details: context);
  }

  static Future<void> saveFeedback(String text) async {
    final prefs = await SharedPreferences.getInstance();
    final items = prefs.getStringList(_feedbackKey) ?? <String>[];
    items.insert(0, '${DateTime.now().toIso8601String()}|$text');
    if (items.length > 100) {
      items.removeRange(100, items.length);
    }
    await prefs.setStringList(_feedbackKey, items);
  }

  static Future<List<String>> readFeedback() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_feedbackKey) ?? <String>[];
  }

  static Future<List<String>> readLogs({int limit = 20}) async {
    final prefs = await SharedPreferences.getInstance();
    final logs = prefs.getStringList(_logKey) ?? <String>[];
    return logs.take(limit).toList();
  }

  static Future<int> countErrors() async {
    final prefs = await SharedPreferences.getInstance();
    final logs = prefs.getStringList(_logKey) ?? <String>[];
    return logs.where((item) => item.startsWith('error|')).length;
  }

  static Future<void> _append({
    required String type,
    required String message,
    String? details,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final logs = prefs.getStringList(_logKey) ?? <String>[];
    final sanitizedMessage = message.replaceAll('\n', ' ').trim();
    final sanitizedDetails = (details ?? '').replaceAll('\n', ' ').trim();
    logs.insert(0, '$type|${DateTime.now().toIso8601String()}|$sanitizedMessage|$sanitizedDetails');
    if (logs.length > _maxLogs) {
      logs.removeRange(_maxLogs, logs.length);
    }
    await prefs.setStringList(_logKey, logs);
  }
}

class PickLocationApp extends StatefulWidget {
  const PickLocationApp({super.key});

  @override
  State<PickLocationApp> createState() => _PickLocationAppState();
}

class _PickLocationAppState extends State<PickLocationApp> {
  static const _themeKey = 'app_theme_v1';
  static const _languageKey = 'app_language_v1';
  static const _mapStyleKey = 'app_map_style_v1';

  ThemeMode _themeMode = ThemeMode.light;
  AppLanguage _language = AppLanguage.ar;
  AppMapStyle _mapStyle = AppMapStyle.street;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final theme = prefs.getString(_themeKey);
    final language = prefs.getString(_languageKey);
    final mapStyle = prefs.getString(_mapStyleKey);

    if (!mounted) {
      return;
    }

    setState(() {
      _themeMode = theme == 'dark' ? ThemeMode.dark : ThemeMode.light;
      _language = language == 'en' ? AppLanguage.en : AppLanguage.ar;
      _mapStyle = mapStyle == 'satellite' ? AppMapStyle.satellite : AppMapStyle.street;
    });
  }

  Future<void> _saveString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  Future<void> _toggleTheme() async {
    final next = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    setState(() {
      _themeMode = next;
    });
    await _saveString(_themeKey, next == ThemeMode.dark ? 'dark' : 'light');
    unawaited(AppLogger.logUsage('toggle_theme', details: next.name));
  }

  Future<void> _toggleLanguage() async {
    final next = _language == AppLanguage.ar ? AppLanguage.en : AppLanguage.ar;
    setState(() {
      _language = next;
    });
    await _saveString(_languageKey, next == AppLanguage.en ? 'en' : 'ar');
    unawaited(AppLogger.logUsage('toggle_language', details: next.name));
  }

  Future<void> _toggleMapStyle() async {
    final next = _mapStyle == AppMapStyle.street ? AppMapStyle.satellite : AppMapStyle.street;
    setState(() {
      _mapStyle = next;
    });
    await _saveString(_mapStyleKey, next == AppMapStyle.satellite ? 'satellite' : 'street');
    unawaited(AppLogger.logUsage('toggle_map_style', details: next.name));
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(_language);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Pick Location',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0A7C86)),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0A7C86),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: _themeMode,
      locale: Locale(_language == AppLanguage.ar ? 'ar' : 'en'),
      home: HomeNavigationPage(
        strings: strings,
        themeMode: _themeMode,
        language: _language,
        mapStyle: _mapStyle,
        onToggleTheme: _toggleTheme,
        onToggleLanguage: _toggleLanguage,
        onToggleMapStyle: _toggleMapStyle,
      ),
    );
  }
}

class HomeNavigationPage extends StatefulWidget {
  const HomeNavigationPage({
    super.key,
    required this.strings,
    required this.themeMode,
    required this.language,
    required this.mapStyle,
    required this.onToggleTheme,
    required this.onToggleLanguage,
    required this.onToggleMapStyle,
  });

  final AppStrings strings;
  final ThemeMode themeMode;
  final AppLanguage language;
  final AppMapStyle mapStyle;
  final VoidCallback onToggleTheme;
  final VoidCallback onToggleLanguage;
  final VoidCallback onToggleMapStyle;

  @override
  State<HomeNavigationPage> createState() => _HomeNavigationPageState();
}

class _HomeNavigationPageState extends State<HomeNavigationPage> {
  static const _currentIndexKey = 'home_current_index_v1';
  static const _selectedLatKey = 'home_selected_lat_v1';
  static const _selectedLngKey = 'home_selected_lng_v1';
  static const _detailsKey = 'home_details_v1';
  static const _lastSeenVersionKey = 'last_seen_app_version_v1';
  static const _androidPackageId = 'com.archeology.picklocation';
  static const _iosAppStoreUrl = '';

  int _currentIndex = 0;
  LatLng? _currentLocation;
  LatLng? _selectedLocation;
  final List<XFile> _images = [];
  String _details = '';
  String _appVersion = '...';

  @override
  void initState() {
    super.initState();
    unawaited(AppLogger.logUsage('app_open'));
    _restoreSessionState();
    _loadVersion();
  }

  Future<void> _restoreSessionState() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIndex = prefs.getInt(_currentIndexKey);
    final savedLat = prefs.getDouble(_selectedLatKey);
    final savedLng = prefs.getDouble(_selectedLngKey);
    final savedDetails = prefs.getString(_detailsKey);

    if (!mounted) {
      return;
    }

    setState(() {
      if (savedIndex != null && savedIndex >= 0 && savedIndex <= 3) {
        _currentIndex = savedIndex;
      }
      if (savedLat != null && savedLng != null) {
        _selectedLocation = LatLng(savedLat, savedLng);
      }
      if (savedDetails != null) {
        _details = savedDetails;
      }
    });
  }

  Future<void> _saveCurrentIndex(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_currentIndexKey, index);
  }

  Future<void> _saveSelectedLocation(LatLng value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_selectedLatKey, value.latitude);
    await prefs.setDouble(_selectedLngKey, value.longitude);
  }

  Future<void> _saveDetails(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_detailsKey, value);
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    final currentVersion = '${info.version}+${info.buildNumber}';

    await _checkAndShowUpdateNotice(currentVersion);

    if (!mounted) {
      return;
    }
    setState(() {
      _appVersion = currentVersion;
    });
  }

  Future<void> _checkAndShowUpdateNotice(String currentVersion) async {
    final prefs = await SharedPreferences.getInstance();
    final lastSeenVersion = prefs.getString(_lastSeenVersionKey);

    if (lastSeenVersion == null || lastSeenVersion.isEmpty) {
      await prefs.setString(_lastSeenVersionKey, currentVersion);
      return;
    }

    if (lastSeenVersion == currentVersion) {
      return;
    }

    await prefs.setString(_lastSeenVersionKey, currentVersion);

    if (!mounted) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(
        AppLogger.logUsage(
          'app_update_notice_shown',
          details: 'from=$lastSeenVersion,to=$currentVersion',
        ),
      );

      showDialog<void>(
        context: context,
        builder: (context) {
          final isArabic = widget.strings.isArabic;
          return AlertDialog(
            title: Text(isArabic ? 'تحديث متاح' : 'Update Available'),
            content: Text(
              isArabic
                  ? 'تم اكتشاف إصدار أحدث للتطبيق.\nالإصدار السابق: $lastSeenVersion\nالإصدار الحالي: $currentVersion\n\nهل تريد التحديث الآن؟'
                  : 'A newer app version was detected.\nPrevious version: $lastSeenVersion\nCurrent version: $currentVersion\n\nDo you want to update now?',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  unawaited(AppLogger.logUsage('app_update_prompt_declined'));
                },
                child: Text(isArabic ? 'لا' : 'No'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  unawaited(AppLogger.logUsage('app_update_prompt_accepted'));
                  unawaited(_openUpdateSource());
                },
                child: Text(isArabic ? 'نعم' : 'Yes'),
              ),
            ],
          );
        },
      );
    });
  }

  Future<void> _openUpdateSource() async {
    final isArabic = widget.strings.isArabic;

    try {
      if (kIsWeb) {
        await launchUrl(Uri.base, webOnlyWindowName: '_self');
        return;
      }

      if (Platform.isAndroid) {
        final marketUri = Uri.parse('market://details?id=$_androidPackageId');
        final playWebUri = Uri.parse(
          'https://play.google.com/store/apps/details?id=$_androidPackageId',
        );

        if (await canLaunchUrl(marketUri)) {
          final launched = await launchUrl(marketUri, mode: LaunchMode.externalApplication);
          if (launched) {
            return;
          }
        }

        if (await canLaunchUrl(playWebUri)) {
          final launched = await launchUrl(playWebUri, mode: LaunchMode.externalApplication);
          if (launched) {
            return;
          }
        }
      }

      if (Platform.isIOS && _iosAppStoreUrl.isNotEmpty) {
        final appStoreUri = Uri.parse(_iosAppStoreUrl);
        if (await canLaunchUrl(appStoreUri)) {
          final launched = await launchUrl(appStoreUri, mode: LaunchMode.externalApplication);
          if (launched) {
            return;
          }
        }
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic
                ? 'تعذر فتح صفحة التحديث تلقائيا. يرجى التحديث يدويًا من المتجر.'
                : 'Could not open update page automatically. Please update manually from the store.',
          ),
        ),
      );
    } catch (e) {
      unawaited(AppLogger.logError(e.toString(), context: 'open_update_source'));

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic
                ? 'حدث خطأ أثناء محاولة التحديث. يرجى المحاولة لاحقًا.'
                : 'An error occurred while trying to update. Please try again later.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      MapPickerPage(
        strings: widget.strings,
        currentLocation: _currentLocation,
        selectedLocation: _selectedLocation,
        mapStyle: widget.mapStyle,
        onToggleMapStyle: widget.onToggleMapStyle,
        onToggleLanguage: widget.onToggleLanguage,
        onToggleTheme: widget.onToggleTheme,
        onCurrentLocationChanged: (value) {
          setState(() {
            _currentLocation = value;
          });
        },
        onSelectedLocationChanged: (value) {
          setState(() {
            _selectedLocation = value;
          });
          unawaited(_saveSelectedLocation(value));
        },
      ),
      ImageDetailsPage(
        strings: widget.strings,
        images: _images,
        details: _details,
        onToggleLanguage: widget.onToggleLanguage,
        onToggleTheme: widget.onToggleTheme,
        onImagesChanged: (value) {
          setState(() {
            _images
              ..clear()
              ..addAll(value);
          });
        },
        onDetailsChanged: (value) {
          setState(() {
            _details = value;
          });
          unawaited(_saveDetails(value));
        },
      ),
      ReviewSubmitPage(
        strings: widget.strings,
        currentLocation: _currentLocation,
        selectedLocation: _selectedLocation,
        images: _images,
        details: _details,
        onToggleLanguage: widget.onToggleLanguage,
        onToggleTheme: widget.onToggleTheme,
      ),
      FeedbackPage(
        strings: widget.strings,
        appVersion: _appVersion,
        onToggleLanguage: widget.onToggleLanguage,
        onToggleTheme: widget.onToggleTheme,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          unawaited(AppLogger.logUsage('switch_tab', details: 'tab=$index'));
          setState(() {
            _currentIndex = index;
          });
          unawaited(_saveCurrentIndex(index));
        },
        destinations:
            const [
              NavigationDestination(
                icon: Icon(Icons.map_outlined),
                selectedIcon: Icon(Icons.map),
                label: '',
              ),
              NavigationDestination(
                icon: Icon(Icons.photo_library_outlined),
                selectedIcon: Icon(Icons.photo_library),
                label: '',
              ),
              NavigationDestination(
                icon: Icon(Icons.assignment_outlined),
                selectedIcon: Icon(Icons.assignment_turned_in),
                label: '',
              ),
              NavigationDestination(
                icon: Icon(Icons.feedback_outlined),
                selectedIcon: Icon(Icons.feedback),
                label: '',
              ),
            ].asMap().entries.map((entry) {
              final index = entry.key;
              final destination = entry.value;
              final labels = [
                widget.strings.navMap,
                widget.strings.navPhotos,
                widget.strings.navReview,
                widget.strings.navFeedback,
              ];
              return NavigationDestination(
                icon: destination.icon,
                selectedIcon: destination.selectedIcon ?? destination.icon,
                label: labels[index],
              );
            }).toList(),
      ),
    );
  }
}

class MapPickerPage extends StatefulWidget {
  const MapPickerPage({
    super.key,
    required this.strings,
    required this.currentLocation,
    required this.selectedLocation,
    required this.mapStyle,
    required this.onToggleMapStyle,
    required this.onToggleLanguage,
    required this.onToggleTheme,
    required this.onCurrentLocationChanged,
    required this.onSelectedLocationChanged,
  });

  final AppStrings strings;
  final LatLng? currentLocation;
  final LatLng? selectedLocation;
  final AppMapStyle mapStyle;
  final VoidCallback onToggleMapStyle;
  final VoidCallback onToggleLanguage;
  final VoidCallback onToggleTheme;
  final ValueChanged<LatLng> onCurrentLocationChanged;
  final ValueChanged<LatLng> onSelectedLocationChanged;

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

class _MapPickerPageState extends State<MapPickerPage> {
  final MapController _mapController = MapController();
  LatLng? _currentLocation;
  LatLng? _selectedLocation;
  LatLng? _pendingMovePoint;
  double _mapRotationDeg = 0;
  bool _isMapReady = false;
  bool _isLoading = false;
  String? _error;

  Future<List<_NavigationOption>> _buildNavigationOptions(LatLng target) async {
    final options = <_NavigationOption>[];
    final isArabic = widget.strings.isArabic;

    if (!kIsWeb && Platform.isIOS) {
      final appleUri = Uri.parse('maps://?daddr=${target.latitude},${target.longitude}&dirflg=d');
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
        'comgooglemaps://?daddr=${target.latitude},${target.longitude}&directionsmode=driving',
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
      'https://www.google.com/maps/dir/?api=1&destination=${target.latitude},${target.longitude}',
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
    final options = await _buildNavigationOptions(target);
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
    _moveMapSafely(target, 15);
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

  @override
  void initState() {
    super.initState();
    _currentLocation = widget.currentLocation;
    _selectedLocation = widget.selectedLocation;
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

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.strings.mapTitle),
        actions: [
          IconButton(
            onPressed: widget.onToggleMapStyle,
            icon: Icon(isSatellite ? Icons.map_outlined : Icons.satellite_alt),
            tooltip: isSatellite ? widget.strings.mapStreet : widget.strings.mapSatellite,
          ),
          IconButton(
            onPressed: widget.onToggleLanguage,
            icon: const Icon(Icons.translate),
            tooltip: widget.strings.toggleLanguage,
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
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
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
                      urlTemplate: isSatellite
                          ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                          : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.archeology.picklocation',
                      subdomains: isSatellite ? const [] : const ['a', 'b', 'c'],
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
                            width: 48,
                            height: 48,
                            child: const Icon(Icons.location_pin, size: 42, color: Colors.red),
                          ),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  left: 12,
                  top: 12,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      // ignore: deprecated_member_use
                      color: Theme.of(context).colorScheme.surface.withOpacity(0.88),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2)),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: _zoomIn,
                          tooltip: widget.strings.isArabic ? 'تكبير' : 'Zoom in',
                          icon: const Icon(Icons.add),
                        ),
                        IconButton(
                          onPressed: _zoomOut,
                          tooltip: widget.strings.isArabic ? 'تصغير' : 'Zoom out',
                          icon: const Icon(Icons.remove),
                        ),
                        const Divider(height: 1),
                        IconButton(
                          onPressed: _focusCurrentLocation,
                          tooltip: widget.strings.isArabic
                              ? 'الانتقال لموقعي الحالي'
                              : 'Focus current location',
                          icon: const Icon(Icons.my_location),
                        ),
                        IconButton(
                          onPressed: _focusSelectedLocation,
                          tooltip: widget.strings.isArabic
                              ? 'الانتقال للموقع المختار'
                              : 'Focus selected location',
                          icon: const Icon(Icons.place_outlined),
                        ),
                        IconButton(
                          onPressed: _resetNorthUp,
                          tooltip: widget.strings.isArabic ? 'تثبيت الشمال للأعلى' : 'North up',
                          icon: Transform.rotate(
                            angle: -_mapRotationDeg * math.pi / 180,
                            child: const Icon(Icons.explore_outlined),
                          ),
                        ),
                        const Divider(height: 1),
                        IconButton(
                          onPressed: _fitMapToVisiblePoints,
                          tooltip: widget.strings.isArabic
                              ? 'عرض كل النقاط على الخريطة'
                              : 'Fit points in view',
                          icon: const Icon(Icons.fit_screen),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  right: 16,
                  bottom: 18,
                  child: Opacity(
                    opacity: 0.92,
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
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${widget.strings.currentLocation}: ${_formatCoordinates(_currentLocation)}'),
                const SizedBox(height: 8),
                Text(
                  '${widget.strings.selectedLocation}: ${_formatCoordinates(_selectedLocation)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatCoordinates(LatLng? point) {
    if (point == null) {
      return 'غير متاح';
    }
    return '${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}';
  }

  void _moveMapSafely(LatLng point, double zoom) {
    if (_isMapReady) {
      _mapController.move(point, zoom);
      return;
    }
    _pendingMovePoint = point;
  }
}

class ImageDetailsPage extends StatefulWidget {
  const ImageDetailsPage({
    super.key,
    required this.strings,
    required this.images,
    required this.details,
    required this.onToggleLanguage,
    required this.onToggleTheme,
    required this.onImagesChanged,
    required this.onDetailsChanged,
  });

  final AppStrings strings;
  final List<XFile> images;
  final String details;
  final VoidCallback onToggleLanguage;
  final VoidCallback onToggleTheme;
  final ValueChanged<List<XFile>> onImagesChanged;
  final ValueChanged<String> onDetailsChanged;

  @override
  State<ImageDetailsPage> createState() => _ImageDetailsPageState();
}

class _ImageDetailsPageState extends State<ImageDetailsPage> {
  final ImagePicker _picker = ImagePicker();
  late final TextEditingController _detailsController;
  late List<XFile> _images;

  @override
  void initState() {
    super.initState();
    _detailsController = TextEditingController(text: widget.details);
    _images = List<XFile>.from(widget.images);
    _detailsController.addListener(_onDetailsChanged);
  }

  @override
  void didUpdateWidget(covariant ImageDetailsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.details != oldWidget.details && widget.details != _detailsController.text) {
      _detailsController.text = widget.details;
      _detailsController.selection = TextSelection.fromPosition(
        TextPosition(offset: _detailsController.text.length),
      );
    }
    if (!listEquals(widget.images, oldWidget.images)) {
      _images = List<XFile>.from(widget.images);
    }
  }

  void _onDetailsChanged() {
    widget.onDetailsChanged(_detailsController.text);
  }

  @override
  void dispose() {
    _detailsController.removeListener(_onDetailsChanged);
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _pickFromGallery() async {
    final picked = await _picker.pickMultiImage();
    if (picked.isEmpty) {
      return;
    }

    setState(() {
      _images.addAll(picked);
    });
    unawaited(AppLogger.logUsage('gallery_pick', details: 'count=${picked.length}'));
    widget.onImagesChanged(List<XFile>.from(_images));
  }

  Future<void> _captureFromCamera() async {
    if (kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'في متصفح الكمبيوتر قد يفتح اختيار الملفات بدل الكاميرا. جرب من جوال او تطبيق مثبت.',
          ),
        ),
      );
    }

    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
    );
    if (picked == null) {
      return;
    }

    setState(() {
      _images.add(picked);
    });
    unawaited(AppLogger.logUsage('camera_capture'));
    widget.onImagesChanged(List<XFile>.from(_images));
  }

  void _saveData() {
    final details = _detailsController.text.trim();
    unawaited(AppLogger.logUsage('save_details', details: 'images=${_images.length}'));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'تم الحفظ. عدد الصور: ${_images.length} | التفاصيل: ${details.isEmpty ? 'لا توجد' : details}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.strings.photosTitle),
        actions: [
          IconButton(
            onPressed: widget.onToggleLanguage,
            icon: const Icon(Icons.translate),
            tooltip: widget.strings.toggleLanguage,
          ),
          IconButton(
            onPressed: widget.onToggleTheme,
            icon: Icon(
              Theme.of(context).brightness == Brightness.dark ? Icons.light_mode : Icons.dark_mode,
            ),
            tooltip: widget.strings.toggleTheme,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ElevatedButton.icon(
                    onPressed: _pickFromGallery,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(widget.strings.chooseGallery),
                  ),
                  ElevatedButton.icon(
                    onPressed: _captureFromCamera,
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: Text(widget.strings.takePhoto),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _detailsController,
                maxLines: 4,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: widget.strings.details,
                  hintText: widget.strings.isArabic
                      ? 'اكتب اي تفاصيل مرتبطة بالموقع او الصور...'
                      : 'Write any details related to the location or photos...',
                ),
              ),
              const SizedBox(height: 16),
              Text('${widget.strings.photos}: ${_images.length}'),
              const SizedBox(height: 8),
              Expanded(
                child: _images.isEmpty
                    ? Center(child: Text(widget.strings.noPhotos))
                    : GridView.builder(
                        itemCount: _images.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 1,
                        ),
                        itemBuilder: (context, index) {
                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: _buildImagePreview(_images[index]),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: CircleAvatar(
                                  radius: 14,
                                  backgroundColor: Colors.black54,
                                  child: IconButton(
                                    onPressed: () {
                                      setState(() {
                                        _images.removeAt(index);
                                      });
                                      widget.onImagesChanged(List<XFile>.from(_images));
                                    },
                                    icon: const Icon(Icons.close, size: 14, color: Colors.white),
                                    padding: EdgeInsets.zero,
                                    splashRadius: 14,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saveData,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(widget.strings.saveData),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePreview(XFile image) {
    if (kIsWeb) {
      return Image.network(image.path, fit: BoxFit.cover);
    }
    return Image.file(File(image.path), fit: BoxFit.cover);
  }
}

class ReviewSubmitPage extends StatefulWidget {
  const ReviewSubmitPage({
    super.key,
    required this.strings,
    required this.currentLocation,
    required this.selectedLocation,
    required this.images,
    required this.details,
    required this.onToggleLanguage,
    required this.onToggleTheme,
  });

  final AppStrings strings;
  final LatLng? currentLocation;
  final LatLng? selectedLocation;
  final List<XFile> images;
  final String details;
  final VoidCallback onToggleLanguage;
  final VoidCallback onToggleTheme;

  @override
  State<ReviewSubmitPage> createState() => _ReviewSubmitPageState();
}

class _ReviewSubmitPageState extends State<ReviewSubmitPage> {
  static const String _savedEmailKey = 'saved_recipient_email';
  final TextEditingController _emailController = TextEditingController();

  String? _buildLocationLink(LatLng? point) {
    if (point == null) {
      return null;
    }
    return 'https://www.google.com/maps?q=${point.latitude},${point.longitude}';
  }

  Future<void> _shareLocationLink({
    required LatLng? point,
    required String usageEvent,
    required String emptyMessage,
    required String title,
  }) async {
    final link = _buildLocationLink(point);
    if (link == null) {
      _showMessage(emptyMessage);
      return;
    }

    await Share.share('$title\n$link');
    unawaited(AppLogger.logUsage(usageEvent, details: link));
  }

  String _buildEmailSubject() {
    return 'بلاغ موقع جديد - ${DateTime.now().toIso8601String()}';
  }

  @override
  void initState() {
    super.initState();
    _loadSavedEmail();
    _emailController.addListener(_saveEmailToDevice);
  }

  @override
  void dispose() {
    _emailController.removeListener(_saveEmailToDevice);
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString(_savedEmailKey);
    if (!mounted || savedEmail == null || savedEmail.isEmpty) {
      return;
    }

    _emailController.text = savedEmail;
    _emailController.selection = TextSelection.fromPosition(
      TextPosition(offset: _emailController.text.length),
    );
  }

  Future<void> _saveEmailToDevice() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_savedEmailKey, _emailController.text.trim());
  }

  Future<void> _clearSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_savedEmailKey);
    _emailController.clear();
    if (!mounted) {
      return;
    }
    _showMessage('تم مسح البريد المحفوظ');
  }

  Future<void> _sendByEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showMessage('ادخل البريد الالكتروني للمستلم');
      return;
    }

    if (!email.contains('@')) {
      _showMessage('صيغة البريد الالكتروني غير صحيحة');
      return;
    }

    final subject = _buildEmailSubject();
    final body = _buildEmailBody();
    final uri = Uri.parse(
      'mailto:$email?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
    );

    try {
      unawaited(
        AppLogger.logUsage(
          'send_email_attempt',
          details: 'with_images=${widget.images.isNotEmpty}',
        ),
      );
      final canOpen = await canLaunchUrl(uri);
      if (!canOpen) {
        _showMessage('لا يوجد تطبيق بريد متاح على هذا الجهاز');
        unawaited(AppLogger.logError('no_mail_app', context: 'send_email'));
        return;
      }

      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!mounted) {
        return;
      }
      if (launched) {
        _showMessage('تم فتح تطبيق البريد. اكمل الارسال من هناك.');
        unawaited(AppLogger.logUsage('send_email_opened'));
      } else {
        _showMessage('تعذر فتح تطبيق البريد على هذا الجهاز');
        unawaited(AppLogger.logError('launch_failed', context: 'send_email'));
      }
    } on MissingPluginException {
      _showMessage(
        'ميزة البريد غير محملة في جلسة التشغيل الحالية. اوقف التطبيق تماما ثم شغله مرة اخرى.',
      );
      unawaited(AppLogger.logError('missing_plugin', context: 'url_launcher'));
    } catch (e) {
      _showMessage('حدث خطا اثناء فتح البريد: $e');
      unawaited(AppLogger.logError(e.toString(), context: 'send_email'));
    }
  }

  Future<void> _shareWithImages() async {
    if (widget.images.isEmpty) {
      _showMessage('لا توجد صور مضافة لإرفاقها');
      return;
    }

    try {
      await Share.shareXFiles(
        widget.images,
        subject: _buildEmailSubject(),
        text: _buildEmailBody(),
      );
      unawaited(
        AppLogger.logUsage('share_with_attachments', details: 'count=${widget.images.length}'),
      );
    } on MissingPluginException {
      _showMessage('ميزة المرفقات غير متاحة في جلسة التشغيل الحالية، سيتم فتح البريد بدون مرفقات.');
      unawaited(AppLogger.logError('missing_plugin', context: 'share_plus'));
      await _sendByEmail();
    } catch (e) {
      _showMessage('تعذر إرفاق الصور تلقائيا. سيتم فتح البريد بدون مرفقات.');
      unawaited(AppLogger.logError(e.toString(), context: 'share_with_images'));
      await _sendByEmail();
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatCoordinates(LatLng? point) {
    if (point == null) {
      return 'غير متاح';
    }
    return '${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}';
  }

  String _buildEmailBody() {
    final imagesNames = widget.images.isEmpty
        ? 'لا توجد صور'
        : widget.images.map((img) => '- ${img.name}').join('\n');

    return [
      'بيانات البلاغ:',
      '',
      'احداثيات موقعي الحالي: ${_formatCoordinates(widget.currentLocation)}',
      'احداثيات الموقع المختار: ${_formatCoordinates(widget.selectedLocation)}',
      '',
      'التفاصيل:',
      widget.details.trim().isEmpty ? 'لا توجد تفاصيل' : widget.details.trim(),
      '',
      'عدد الصور: ${widget.images.length}',
      'اسماء الصور:',
      imagesNames,
      '',
      'ملاحظة: في mailto يتم ادراج الاسماء فقط، والمرفقات تضاف يدويا من تطبيق البريد.',
    ].join('\n');
  }

  Future<void> _copyReportToClipboard() async {
    final report = _buildEmailBody();
    await Clipboard.setData(ClipboardData(text: report));
    if (!mounted) {
      return;
    }
    _showMessage('تم نسخ نص التقرير إلى الحافظة');
  }

  Future<void> _copySubjectToClipboard() async {
    final subject = _buildEmailSubject();
    await Clipboard.setData(ClipboardData(text: subject));
    if (!mounted) {
      return;
    }
    _showMessage('تم نسخ عنوان البريد إلى الحافظة');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.strings.reviewTitle),
        actions: [
          IconButton(
            onPressed: widget.onToggleLanguage,
            icon: const Icon(Icons.translate),
            tooltip: widget.strings.toggleLanguage,
          ),
          IconButton(
            onPressed: widget.onToggleTheme,
            icon: Icon(
              Theme.of(context).brightness == Brightness.dark ? Icons.light_mode : Icons.dark_mode,
            ),
            tooltip: widget.strings.toggleTheme,
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.strings.location,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${widget.strings.currentLocation}: ${_formatCoordinates(widget.currentLocation)}',
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.strings.selectedLocation}: ${_formatCoordinates(widget.selectedLocation)}',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.strings.details,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(widget.details.trim().isEmpty ? 'لا توجد تفاصيل' : widget.details),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.strings.photos,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text('${widget.strings.photos}: ${widget.images.length}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                labelText: widget.strings.chooseEmail,
                hintText: 'example@domain.com',
                suffixIcon: IconButton(
                  onPressed: _clearSavedEmail,
                  tooltip: 'مسح البريد المحفوظ',
                  icon: const Icon(Icons.clear),
                ),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            Text(
              widget.strings.isArabic
                  ? 'سيتم فتح تطبيق البريد مع تعبئة الموضوع ومحتوى الرسالة تلقائيا.'
                  : 'The mail app will open with the subject and body prefilled.',
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _copyReportToClipboard,
              icon: const Icon(Icons.copy_all_outlined),
              label: Text(widget.strings.copyReport),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _copySubjectToClipboard,
              icon: const Icon(Icons.title_outlined),
              label: Text(widget.strings.copySubject),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _shareLocationLink(
                        point: widget.currentLocation,
                        usageEvent: 'share_current_location_link',
                        emptyMessage: widget.strings.isArabic
                            ? 'الموقع الحالي غير متاح للمشاركة'
                            : 'Current location is not available',
                        title: widget.strings.isArabic
                            ? 'رابط موقعي الحالي'
                            : 'Current location link',
                      );
                    },
                    icon: const Icon(Icons.my_location_outlined),
                    label: Text(
                      widget.strings.isArabic ? 'مشاركة موقعي الحالي' : 'Share Current Location',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _shareLocationLink(
                        point: widget.selectedLocation,
                        usageEvent: 'share_selected_location_link',
                        emptyMessage: widget.strings.isArabic
                            ? 'الموقع المختار غير متاح للمشاركة'
                            : 'Selected location is not available',
                        title: widget.strings.isArabic
                            ? 'رابط الموقع المختار'
                            : 'Selected location link',
                      );
                    },
                    icon: const Icon(Icons.location_on_outlined),
                    label: Text(
                      widget.strings.isArabic ? 'مشاركة الموقع المختار' : 'Share Selected Location',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () {
                _showMessage('سيتم فتح المشاركة. اختر تطبيق البريد لإرسال الصور كمرفقات.');
                _shareWithImages();
              },
              icon: const Icon(Icons.attach_email_outlined),
              label: Text(widget.strings.sendWithAttachments),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _sendByEmail,
              icon: const Icon(Icons.mail_outline),
              label: Text(widget.strings.sendWithoutAttachments),
            ),
          ],
        ),
      ),
    );
  }
}

class FeedbackPage extends StatefulWidget {
  const FeedbackPage({
    super.key,
    required this.strings,
    required this.appVersion,
    required this.onToggleLanguage,
    required this.onToggleTheme,
  });

  final AppStrings strings;
  final String appVersion;
  final VoidCallback onToggleLanguage;
  final VoidCallback onToggleTheme;

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  final TextEditingController _feedbackController = TextEditingController();
  List<String> _feedbackItems = const [];
  List<String> _logs = const [];
  int _errorCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final feedback = await AppLogger.readFeedback();
    final logs = await AppLogger.readLogs(limit: 15);
    final errors = await AppLogger.countErrors();

    if (!mounted) {
      return;
    }

    setState(() {
      _feedbackItems = feedback;
      _logs = logs;
      _errorCount = errors;
      _loading = false;
    });
  }

  Future<void> _saveFeedback() async {
    final text = _feedbackController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('اكتب ملاحظة قبل الحفظ')));
      return;
    }

    await AppLogger.saveFeedback(text);
    await AppLogger.logUsage('feedback_saved');
    _feedbackController.clear();
    await _loadData();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('تم حفظ الملاحظة محليا')));
  }

  String _formatFeedbackItem(String item) {
    final split = item.split('|');
    if (split.length < 2) {
      return item;
    }
    final timestamp = split.first;
    final text = split.sublist(1).join('|');
    return '$timestamp\n$text';
  }

  String _formatLogItem(String item) {
    final split = item.split('|');
    if (split.length < 4) {
      return item;
    }
    return '${split[0]} | ${split[1]}\n${split[2]}${split[3].isEmpty ? '' : ' (${split[3]})'}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.strings.feedbackTitle),
        actions: [
          IconButton(
            onPressed: widget.onToggleLanguage,
            icon: const Icon(Icons.translate),
            tooltip: widget.strings.toggleLanguage,
          ),
          IconButton(
            onPressed: widget.onToggleTheme,
            icon: Icon(
              Theme.of(context).brightness == Brightness.dark ? Icons.light_mode : Icons.dark_mode,
            ),
            tooltip: widget.strings.toggleTheme,
          ),
          IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh), tooltip: 'تحديث'),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${widget.strings.versionLabel}: ${widget.appVersion}'),
                        const SizedBox(height: 6),
                        Text('${widget.strings.errorCountLabel}: $_errorCount'),
                        const SizedBox(height: 6),
                        Text('${widget.strings.eventCountLabel}: ${_logs.length} (آخر 15 حدث)'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _feedbackController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'ملاحظة المستخدم',
                    hintText: 'اكتب الملاحظة أو الاقتراح...',
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _saveFeedback,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('حفظ الملاحظة'),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.strings.isArabic ? 'آخر الملاحظات' : 'Latest Feedback',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                if (_feedbackItems.isEmpty)
                  Text(widget.strings.noFeedback)
                else
                  ..._feedbackItems
                      .take(5)
                      .map(
                        (item) => Card(
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Text(_formatFeedbackItem(item)),
                          ),
                        ),
                      ),
                const SizedBox(height: 12),
                Text(
                  widget.strings.isArabic ? 'آخر الأحداث والأخطاء' : 'Latest Events & Errors',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                if (_logs.isEmpty)
                  Text(widget.strings.noLogs)
                else
                  ..._logs.map(
                    (log) => Card(
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Text(_formatLogItem(log)),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
