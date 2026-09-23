// ignore_for_file: deprecated_member_use

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
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'services/coordinate_converter.dart';
import 'services/navigation.dart';

// part 'pages/feedback_page.dart';
part 'pages/image_details_page.dart';
part 'pages/map_picker_page.dart';
part 'pages/review_submit_page.dart';

enum AppLanguage { ar, en }

enum AppMapStyle { street, satellite, hybrid }

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
  String get currentDateTime => isArabic ? 'تاريخ ووقت اليوم' : 'Current date & time';
  String get noPhotos => isArabic ? 'لم يتم اضافة صور بعد' : 'No photos yet';
  String get saveData => isArabic ? 'حفظ البيانات' : 'Save Data';
  String get chooseGallery => isArabic ? 'اختيار من المعرض' : 'Pick from Gallery';
  String get takePhoto => isArabic ? 'التقاط صورة' : 'Take Photo';
  String get mapStreet => isArabic ? 'خرائط جغرافية' : 'Street';
  String get mapSatellite => isArabic ? 'صور جوية' : 'Satellite';
  String get mapHybrid => isArabic ? 'هجين' : 'Hybrid';
  String get sendWithAttachments => isArabic ? 'ارسال بمرفقات (مشاركة)' : 'Send with Attachments';
  String get sendWhatsApp => isArabic ? 'ارسال واتساب' : 'Send via WhatsApp';
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

bool isPrintingSupportedOnCurrentPlatform() {
  if (kIsWeb) {
    return true;
  }

  return Platform.isAndroid ||
      Platform.isIOS ||
      Platform.isMacOS ||
      Platform.isWindows ||
      Platform.isLinux;
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
      _mapStyle = switch (mapStyle) {
        'satellite' => AppMapStyle.satellite,
        'hybrid' => AppMapStyle.hybrid,
        _ => AppMapStyle.street,
      };
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

  Future<void> _setMapStyle(AppMapStyle next) async {
    if (_mapStyle == next) {
      return;
    }
    setState(() {
      _mapStyle = next;
    });
    await _saveString(_mapStyleKey, next.name);
    unawaited(AppLogger.logUsage('toggle_map_style', details: next.name));
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(_language);

    final baseTheme = ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFF3F5F8),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF0F766E),
        primary: const Color(0xFF0F766E),
        secondary: const Color(0xFFF59E0B),
        tertiary: const Color(0xFF2563EB),
        brightness: Brightness.light,
      ),
      textTheme: ThemeData.light(
        useMaterial3: true,
      ).textTheme.apply(bodyColor: const Color(0xFF16232A), displayColor: const Color(0xFF16232A)),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: const Color(0xFFFFFFFF),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        elevation: 0,
        indicatorColor: const Color(0xFF0A7C86).withOpacity(0.12),
        iconTheme: WidgetStatePropertyAll(IconThemeData(color: const Color(0xFF0A7C86), size: 24)),
        labelTextStyle: WidgetStatePropertyAll(
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    );

    final darkBaseTheme = ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFF0B1418),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF14B8A6),
        primary: const Color(0xFF2DD4BF),
        secondary: const Color(0xFFF59E0B),
        tertiary: const Color(0xFF60A5FA),
        brightness: Brightness.dark,
      ),
      textTheme: ThemeData.dark(
        useMaterial3: true,
      ).textTheme.apply(bodyColor: const Color(0xFFEAF8F7), displayColor: const Color(0xFFEAF8F7)),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: const Color(0xFF17262B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        filled: true,
        fillColor: const Color(0xFF17262B),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF17262B),
        elevation: 0,
        indicatorColor: const Color(0xFF4FA9B0).withOpacity(0.18),
        iconTheme: WidgetStatePropertyAll(IconThemeData(color: const Color(0xFF8AE4E7), size: 24)),
        labelTextStyle: WidgetStatePropertyAll(
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Pick Location',
      theme: baseTheme,
      darkTheme: darkBaseTheme,
      themeMode: _themeMode,
      locale: Locale(_language == AppLanguage.ar ? 'ar' : 'en'),
      home: HomeNavigationPage(
        strings: strings,
        themeMode: _themeMode,
        language: _language,
        mapStyle: _mapStyle,
        onToggleTheme: _toggleTheme,
        onToggleLanguage: _toggleLanguage,
        onMapStyleChanged: _setMapStyle,
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
    required this.onMapStyleChanged,
  });

  final AppStrings strings;
  final ThemeMode themeMode;
  final AppLanguage language;
  final AppMapStyle mapStyle;
  final VoidCallback onToggleTheme;
  final VoidCallback onToggleLanguage;
  final ValueChanged<AppMapStyle> onMapStyleChanged;

  @override
  State<HomeNavigationPage> createState() => _HomeNavigationPageState();
}

class _HomeNavigationPageState extends State<HomeNavigationPage> {
  static const _currentIndexKey = 'home_current_index_v1';
  static const _selectedLatKey = 'home_selected_lat_v1';
  static const _selectedLngKey = 'home_selected_lng_v1';
  static const _lastSeenVersionKey = 'last_seen_app_version_v1';
  static const _androidPackageId = 'com.archeology.picklocation';
  static const _iosAppStoreUrl = '';

  int _currentIndex = 0;
  int _focusCurrentLocationRequest = 0;
  LatLng? _currentLocation;
  LatLng? _selectedLocation;
  final List<XFile> _images = [];
  String _details = '';

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

    if (!mounted) {
      return;
    }

    setState(() {
      if (savedIndex != null && savedIndex >= 0 && savedIndex <= 2) {
        _currentIndex = savedIndex;
      }
      if (savedLat != null && savedLng != null) {
        _selectedLocation = LatLng(savedLat, savedLng);
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

  Future<void> _clearDraftFields() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _details = '';
      _images.clear();
    });
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    final currentVersion = '${info.version}+${info.buildNumber}';

    await _checkAndShowUpdateNotice(currentVersion);
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
        onMapStyleChanged: widget.onMapStyleChanged,
        onToggleLanguage: widget.onToggleLanguage,
        onToggleTheme: widget.onToggleTheme,
        focusRequestVersion: _focusCurrentLocationRequest,
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
        onReportSent: () {
          unawaited(_clearDraftFields());
        },
        onGoToCurrentLocation: () {
          setState(() {
            _currentIndex = 0;
            _focusCurrentLocationRequest++;
          });
          unawaited(AppLogger.logUsage('review_go_to_current_location'));
        },
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
            ].asMap().entries.map((entry) {
              final index = entry.key;
              final destination = entry.value;
              final labels = [
                widget.strings.navMap,
                widget.strings.navPhotos,
                widget.strings.navReview,
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
