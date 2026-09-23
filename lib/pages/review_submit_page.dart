// ignore_for_file: deprecated_member_use

part of '../main.dart';

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
    required this.onReportSent,
    required this.onGoToCurrentLocation,
  });

  final AppStrings strings;
  final LatLng? currentLocation;
  final LatLng? selectedLocation;
  final List<XFile> images;
  final String details;
  final VoidCallback onToggleLanguage;
  final VoidCallback onToggleTheme;
  final VoidCallback onReportSent;
  final VoidCallback onGoToCurrentLocation;

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
    return widget.strings.isArabic
        ? 'تقرير موقع  - ${DateTime.now().toIso8601String()}'
        : ' Location Report - ${DateTime.now().toIso8601String()}';
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

  Future<void> _sendWithImagesToRecipientEmail() async {
    final recipient = _emailController.text.trim();
    if (recipient.isEmpty) {
      _showMessage('يرجى إدخال البريد الإلكتروني للمستلم أولاً.');
      FocusScope.of(context).requestFocus(FocusNode());
      return;
    }

    final subject = _buildEmailSubject();
    final body = _buildEmailBody();

    _showMessage(
      widget.strings.isArabic
          ? 'سيتم فتح تطبيق البريد مع المرفقات المحددة.'
          : 'The mail app will open with the selected attachments.',
    );

    try {
      if (widget.images.isEmpty) {
        final mailtoUri = Uri.parse(
          'mailto:$recipient?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
        );

        if (await canLaunchUrl(mailtoUri)) {
          final launched = await launchUrl(mailtoUri, mode: LaunchMode.externalApplication);
          if (launched) {
            widget.onReportSent();
            unawaited(
              AppLogger.logUsage(
                'send_email_without_attachments',
                details: 'recipient=$recipient|count=${widget.images.length}',
              ),
            );
            return;
          }
        }
      }

      await Share.shareXFiles(widget.images, subject: subject, text: '$body\n\nTo: $recipient');
      widget.onReportSent();
      unawaited(
        AppLogger.logUsage(
          'send_email_with_attachments',
          details: 'recipient=$recipient|count=${widget.images.length}',
        ),
      );
    } on MissingPluginException {
      _showMessage(
        'ميزة البريد والمرفقات غير متاحة الآن. جرّب المشاركة العادية أو اعد تشغيل التطبيق.',
      );
      unawaited(AppLogger.logError('missing_plugin', context: 'send_email_with_attachments'));
    } catch (e) {
      _showMessage('تعذر فتح البريد الإلكتروني مع المرفقات على هذا الجهاز.');
      unawaited(AppLogger.logError(e.toString(), context: 'send_email_with_attachments'));
    }
  }

  Future<void> _sendToWhatsAppTextOnly() async {
    final message = _buildEmailBody();
    final encoded = Uri.encodeComponent(message);
    final whatsappAppUri = Uri.parse('whatsapp://send?text=$encoded');
    final whatsappWebUri = Uri.parse('https://wa.me/?text=$encoded');

    try {
      if (await canLaunchUrl(whatsappAppUri)) {
        final launched = await launchUrl(whatsappAppUri, mode: LaunchMode.externalApplication);
        if (launched) {
          widget.onReportSent();
          unawaited(
            AppLogger.logUsage('send_whatsapp', details: 'app|images=${widget.images.length}'),
          );
          return;
        }
      }

      final webLaunched = await launchUrl(whatsappWebUri, mode: LaunchMode.externalApplication);
      if (webLaunched) {
        widget.onReportSent();
        unawaited(
          AppLogger.logUsage('send_whatsapp', details: 'web|images=${widget.images.length}'),
        );
        return;
      }

      _showMessage('تعذر فتح واتساب على هذا الجهاز');
      unawaited(AppLogger.logError('launch_failed', context: 'send_whatsapp'));
    } catch (e) {
      _showMessage('حدث خطا اثناء فتح واتساب: $e');
      unawaited(AppLogger.logError(e.toString(), context: 'send_whatsapp'));
    }
  }

  Future<void> _sendToWhatsApp() async {
    if (widget.images.isEmpty) {
      await _sendToWhatsAppTextOnly();
      return;
    }

    try {
      _showMessage('سيتم فتح المشاركة. اختر واتساب لإرسال الصور مع التقرير.');
      await Share.shareXFiles(
        widget.images,
        subject: _buildEmailSubject(),
        text: _buildEmailBody(),
      );
      widget.onReportSent();
      unawaited(
        AppLogger.logUsage(
          'send_whatsapp_with_attachments',
          details: 'count=${widget.images.length}',
        ),
      );
    } on MissingPluginException {
      _showMessage('ميزة المرفقات غير متاحة حاليا. سيتم ارسال التقرير كنص عبر واتساب.');
      unawaited(AppLogger.logError('missing_plugin', context: 'send_whatsapp_attachments'));
      await _sendToWhatsAppTextOnly();
    } catch (e) {
      _showMessage('تعذر مشاركة المرفقات. سيتم ارسال التقرير كنص عبر واتساب.');
      unawaited(AppLogger.logError(e.toString(), context: 'send_whatsapp_attachments'));
      await _sendToWhatsAppTextOnly();
    }
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
    } catch (_) {
      return widget.strings.isArabic ? 'تعذر التحويل' : 'Conversion failed';
    }
  }

  bool get _hasVeryLongDetails {
    final text = widget.details.trim();
    if (text.isEmpty) {
      return false;
    }

    final words = text.split(RegExp(r'\s+')).where((part) => part.isNotEmpty).length;
    return words >= 80;
  }

  Future<bool> _confirmLongDescriptionPdfExport() async {
    if (!_hasVeryLongDetails) {
      return true;
    }

    final didConfirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.strings.isArabic ? 'تنبيه' : 'Warning'),
        content: Text(
          widget.strings.isArabic
              ? 'الوصف طويل جدًا، وسيتم تقسيم التقرير على أكثر من صفحة PDF. هل تريد المتابعة؟'
              : 'The description is very long and the report will be split across multiple PDF pages. Do you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(widget.strings.isArabic ? 'إلغاء' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(widget.strings.isArabic ? 'متابعة' : 'Continue'),
          ),
        ],
      ),
    );

    return didConfirm ?? false;
  }

  List<String> _splitLongPdfText(String value, {int maxWordsPerChunk = 35}) {
    final cleaned = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.isEmpty) {
      return const <String>[];
    }

    final words = cleaned.split(' ');
    final chunks = <String>[];
    for (var i = 0; i < words.length; i += maxWordsPerChunk) {
      final end = (i + maxWordsPerChunk < words.length) ? i + maxWordsPerChunk : words.length;
      final chunk = words.sublist(i, end).join(' ').trim();
      if (chunk.isNotEmpty) {
        chunks.add(chunk);
      }
    }

    return chunks.isEmpty ? <String>[cleaned] : chunks;
  }

  Future<Uint8List> _buildPdfReportBytes() async {
    final isArabic = widget.strings.isArabic;
    final baseFontData = await rootBundle.load(
      isArabic
          ? 'assets/fonts/Cairo-VariableFont_slnt,wght.ttf'
          : 'assets/fonts/NotoSans-VariableFont_wdth,wght.ttf',
    );
    // QArcheology
    // تمييز المشاريع المكتملة باللون

    final boldFontData = await rootBundle.load(
      isArabic
          ? 'assets/fonts/Cairo-VariableFont_slnt,wght.ttf'
          : 'assets/fonts/NotoSans-VariableFont_wdth,wght.ttf',
    );

    final baseFont = pw.Font.ttf(baseFontData);
    final boldFont = pw.Font.ttf(boldFontData);
    final textDirection = isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr;
    final cellAlignment = isArabic ? pw.Alignment.centerRight : pw.Alignment.centerLeft;

    final reportDateTime = _formatReportDateTime(DateTime.now());
    final details = widget.details.trim().isEmpty
        ? (isArabic ? 'لا توجد تفاصيل' : 'No details')
        : widget.details.trim();
    final imageNames = widget.images.isEmpty
        ? (isArabic ? 'لا توجد صور' : 'No images')
        : widget.images.map((img) => img.name).join(', ');
    final detailChunks = _splitLongPdfText(details, maxWordsPerChunk: 35);
    final imageNameChunks = _splitLongPdfText(imageNames, maxWordsPerChunk: 20);
    final currentLink = _buildLocationLink(widget.currentLocation) ?? '-';
    final selectedLink = _buildLocationLink(widget.selectedLocation) ?? '-';
    final title = isArabic ? 'تقرير الموقع' : 'Pick Location Report';
    final generatedAtLabel = isArabic ? 'وقت الإنشاء' : 'Generated At';
    final fieldLabel = isArabic ? 'البند' : 'Field';
    final valueLabel = isArabic ? 'القيمة' : 'Value';

    final tableRows = <List<String>>[
      [generatedAtLabel, reportDateTime],
      [
        isArabic ? 'الموقع الحالي (WGS84)' : 'Current Location (WGS84)',
        _formatCoordinates(widget.currentLocation),
      ],
      [
        isArabic ? 'الموقع الحالي (QND)' : 'Current Location (QND)',
        _formatQndCoordinates(widget.currentLocation),
      ],
      [isArabic ? 'رابط الموقع الحالي' : 'Current Location Link', currentLink],
      [
        isArabic ? 'الموقع المختار (WGS84)' : 'Selected Location (WGS84)',
        _formatCoordinates(widget.selectedLocation),
      ],
      [
        isArabic ? 'الموقع المختار (QND)' : 'Selected Location (QND)',
        _formatQndCoordinates(widget.selectedLocation),
      ],
      [isArabic ? 'رابط الموقع المختار' : 'Selected Location Link', selectedLink],
      [isArabic ? 'عدد الصور' : 'Images Count', widget.images.length.toString()],
    ];

    final watermarkBytes = await rootBundle.load('assets/branding/app_icon_simple.png');
    final watermark = pw.MemoryImage(watermarkBytes.buffer.asUint8List());

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        theme: pw.ThemeData.withFont(base: baseFont, bold: boldFont),
        build: (context) {
          return [
            pw.Stack(
              children: [
                pw.Positioned.fill(
                  child: pw.Center(
                    child: pw.Transform.rotate(
                      angle: math.pi / 6,
                      child: pw.Opacity(
                        opacity: 0.08,
                        child: pw.Image(watermark, width: 420, height: 420),
                      ),
                    ),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Directionality(
                    textDirection: textDirection,
                    child: pw.Column(
                      crossAxisAlignment: isArabic
                          ? pw.CrossAxisAlignment.end
                          : pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          title,
                          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
                        ),
                        pw.SizedBox(height: 12),
                        pw.TableHelper.fromTextArray(
                          headers: [fieldLabel, valueLabel],
                          data: tableRows,
                          border: pw.TableBorder.all(width: 0.8),
                          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
                          headerDecoration: pw.BoxDecoration(color: pdf.PdfColors.grey300),
                          cellStyle: const pw.TextStyle(fontSize: 10),
                          cellAlignment: cellAlignment,
                          headerAlignment: cellAlignment,
                          cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          columnWidths: {
                            0: const pw.FlexColumnWidth(2),
                            1: const pw.FlexColumnWidth(5),
                          },
                        ),
                        pw.SizedBox(height: 12),
                        pw.Text(
                          isArabic ? 'أسماء الصور' : 'Image Names',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12),
                        ),
                        pw.SizedBox(height: 4),
                        ...imageNameChunks.map(
                          (chunk) => pw.Padding(
                            padding: const pw.EdgeInsets.only(bottom: 4),
                            child: pw.Paragraph(
                              text: chunk,
                              style: pw.TextStyle(fontSize: 10),
                            ),
                          ),
                        ),
                        pw.SizedBox(height: 12),
                        pw.Text(
                          isArabic ? 'التفاصيل' : 'Details',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12),
                        ),
                        pw.SizedBox(height: 4),
                        ...detailChunks.map(
                          (chunk) => pw.Padding(
                            padding: const pw.EdgeInsets.only(bottom: 4),
                            child: pw.Paragraph(
                              text: chunk,
                              style: pw.TextStyle(fontSize: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ];
        },
      ),
    );

    return doc.save();
  }

  Future<void> _downloadPdfReport() async {
    final shouldContinue = await _confirmLongDescriptionPdfExport();
    if (!shouldContinue) {
      return;
    }

    try {
      final bytes = await _buildPdfReportBytes();
      await Printing.sharePdf(bytes: bytes, filename: 'pick_location_report.pdf');
      _showMessage(
        widget.strings.isArabic ? 'تم تنزيل ملف PDF بنجاح.' : 'PDF downloaded successfully.',
      );
      unawaited(
        AppLogger.logUsage('download_pdf_report', details: 'images=${widget.images.length}'),
      );
    } catch (e) {
      _showMessage(
        widget.strings.isArabic ? 'تعذر تنزيل ملف PDF: $e' : 'Failed to download the PDF: $e',
      );
      unawaited(AppLogger.logError(e.toString(), context: 'download_pdf_report'));
    }
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onPressed,
    bool isPrimary = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = isPrimary
        ? (isDark ? const Color(0xFF1F352D) : const Color(0xFFE8F3ED))
        : (isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF2F2F0));
    final iconBg = isPrimary
        ? (isDark ? const Color(0xFF2E7D32) : const Color(0xFFBFE3D1))
        : (isDark ? const Color(0xFF2F332F) : const Color(0xFFDDE4D9));
    final titleColor = isDark ? Colors.white : const Color(0xFF1E1E1E);
    final subtitleColor = isDark ? const Color(0xFFB8C1C5) : const Color(0xFF4A4F52);
    final arrowColor = isDark ? const Color(0xFFE4E4E4) : const Color(0xFF4D5861);

    return Material(
      color: surfaceColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 22, color: isDark ? Colors.white : const Color(0xFF1E2F27)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(color: subtitleColor),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 14, color: arrowColor),
            ],
          ),
        ),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  String _formatCoordinates(LatLng? point) {
    if (point == null) {
      return 'غير متاح';
    }
    return '${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}';
  }

  String _formatReportDateTime(DateTime value) {
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    final date = '${value.year}-${twoDigits(value.month)}-${twoDigits(value.day)}';
    final time = '${twoDigits(value.hour)}:${twoDigits(value.minute)}';
    return '$date $time';
  }

  String _buildEmailBody() {
    final reportDateTime = _formatReportDateTime(DateTime.now());
    final details = widget.details.trim().isEmpty
        ? 'لا توجد تفاصيل / No details'
        : widget.details.trim();

    return [
      'Report / التقرير',
      '----------------------------------------',
      'تاريخ التقرير: $reportDateTime',
      'Report Date: $reportDateTime',
      '',
      'الموقع الحالي / Current Location',
      '- WGS84: ${_formatCoordinates(widget.currentLocation)}',
      '- QND: ${_formatQndCoordinates(widget.currentLocation)}',
      '',
      'الموقع المختار / Selected Location',
      '- WGS84: ${_formatCoordinates(widget.selectedLocation)}',
      '- QND: ${_formatQndCoordinates(widget.selectedLocation)}',
      '',
      'التفاصيل / Details',
      details,
      '',
      'الصور / Images',
      'عدد الصور: ${widget.images.length}',
      'Number of Images: ${widget.images.length}',
      '----------------------------------------',
    ].join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = widget.strings.isArabic;

    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF090909)
          : const Color(0xFFF4F7F3),
      appBar: AppBar(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF090909)
            : const Color(0xFFF4F7F3),
        foregroundColor: Theme.of(context).brightness == Brightness.dark
            ? Colors.white
            : Colors.black,
        elevation: 0,
        toolbarHeight: 78,
        titleSpacing: 12,
        title: Transform.translate(
          offset: const Offset(0, 2),
          child: Text(
            widget.strings.reviewTitle,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 22,
              letterSpacing: -0.7,
              color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: IconButton(
              onPressed: widget.onToggleLanguage,
              icon: const Icon(Icons.translate, size: 28),
              tooltip: widget.strings.toggleLanguage,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              onPressed: widget.onToggleTheme,
              icon: Icon(
                Theme.of(context).brightness == Brightness.dark
                    ? Icons.light_mode
                    : Icons.dark_mode,
                size: 22,
              ),
              tooltip: widget.strings.toggleTheme,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Container(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF090909)
              : const Color(0xFFF4F7F3),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
          child: ListView(
            children: [
              Material(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF090909)
                    : const Color(0xFFE7F0E9),
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: widget.onGoToCurrentLocation,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : const Color(0xFF2E7D32),
                        width: .2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest.withAlpha(180),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.location_on_rounded,
                            size: 26,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.white
                                : Color(0xFF1D3B2A),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: widget.onGoToCurrentLocation,
                            child: Text(
                              isArabic ? 'بيانات الموقع' : 'Location data',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white
                                    : const Color(0xFF1D3B2A),
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Material(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest.withAlpha(180),
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: widget.onGoToCurrentLocation,
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Icon(
                                Icons.my_location_rounded,
                                size: 22,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white
                                    : const Color(0xFF1D3B2A),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              GridView.count(
                crossAxisSpacing: 8,
                mainAxisSpacing: 10,
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.38,
                children: [
                  _buildMiniSummary(
                    title: widget.strings.currentLocation,
                    value: _formatCoordinates(widget.currentLocation),
                    secondary: _formatQndCoordinates(widget.currentLocation),
                    isPrimary: true,
                  ),
                  _buildMiniSummary(
                    title: widget.strings.selectedLocation,
                    value: _formatCoordinates(widget.selectedLocation),
                    secondary: _formatQndCoordinates(widget.selectedLocation),
                    isPrimary: false,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF2A2A2A)
                      : const Color(0xFFEAE9E6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF2A2A2A)
                        : const Color(0xFFB5C5B7),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.strings.details,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : const Color(0xFF1A1E1B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.details.trim().isEmpty
                          ? (widget.strings.isArabic ? 'لا توجد تفاصيل' : 'No details')
                          : widget.details,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFFE6E6E6)
                            : const Color(0xFF2A2F32),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text(
                widget.strings.isArabic ? 'بيانات التواصل' : 'Contact details',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : const Color(0xFF111111),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _emailController,
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF1B1B1B)
                      : const Color(0xFFF4F5F4),
                  labelText: widget.strings.chooseEmail,
                  hintText: 'example@domain.com',
                  hintStyle: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF9AA1A8)
                        : const Color(0xFF697177),
                  ),
                  labelStyle: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFFE6E6E6)
                        : const Color(0xFF1D1D1D),
                  ),
                  suffixIcon: IconButton(
                    onPressed: _clearSavedEmail,
                    tooltip: 'مسح البريد المحفوظ',
                    icon: Icon(
                      Icons.clear,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white70
                          : const Color(0xFF49525A),
                    ),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF2A2A2A)
                          : const Color(0xFFB7C5C1),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF2A2A2A)
                          : const Color(0xFFB7C5C1),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF66BB6A)),
                  ),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF111111)
                      : const Color(0xFFF2F2F0),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF2C2C2C)
                        : const Color(0xFFCBD5D1),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.strings.isArabic ? 'إجراءات التقرير' : 'Report actions',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : const Color(0xFF111111),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Column(
                      children: [
                        _buildActionTile(
                          icon: Icons.my_location_outlined,
                          title: widget.strings.isArabic
                              ? 'مشاركة موقعي الحالي'
                              : 'Share current location',
                          subtitle: widget.strings.isArabic
                              ? 'رابط مباشر للموقع الحالي'
                              : 'Direct link to current location',
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
                        ),
                        const SizedBox(height: 10),
                        _buildActionTile(
                          icon: Icons.location_on_outlined,
                          title: widget.strings.isArabic
                              ? 'مشاركة الموقع المختار'
                              : 'Share selected location',
                          subtitle: widget.strings.isArabic
                              ? 'رابط مباشر للموقع المختار'
                              : 'Direct link to selected location',
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
                        ),
                        const SizedBox(height: 10),
                        _buildActionTile(
                          icon: Icons.attach_email_outlined,
                          title: widget.strings.sendWithAttachments,
                          subtitle: widget.strings.isArabic
                              ? 'إرسال الصور والتفاصيل إلى البريد الإلكتروني المختار'
                              : 'Send photos and details to the selected email address',
                          onPressed: _sendWithImagesToRecipientEmail,
                          isPrimary: true,
                        ),
                        const SizedBox(height: 10),
                        _buildActionTile(
                          icon: Icons.file_download_outlined,
                          title: widget.strings.isArabic ? 'تنزيل PDF' : 'Download PDF',
                          subtitle: widget.strings.isArabic
                              ? 'تنزيل التقرير كملف PDF مباشرة'
                              : 'Download the report as a PDF file',
                          onPressed: _downloadPdfReport,
                        ),
                        const SizedBox(height: 10),
                        _buildActionTile(
                          icon: Icons.chat_outlined,
                          title: widget.strings.sendWhatsApp,
                          subtitle: widget.strings.isArabic
                              ? 'إرسال التقرير مباشرة عبر واتساب'
                              : 'Send the report directly via WhatsApp',
                          onPressed: _sendToWhatsApp,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniSummary({
    required String title,
    required String value,
    required String secondary,
    required bool isPrimary,
  }) {
    final isArabic = widget.strings.isArabic;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F0F0F) : const Color(0xFFE7E7E3),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFF9FB79F)),
      ),
      child: Column(
        // mainAxisAlignment: MainAxisAlignment.center,
        // crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              title,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFFE5E5E5) : const Color(0xFF3C3C3C),
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => _copyCoordinateValue(secondary, label: 'QND'),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Text(
                  secondary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF111111),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 15),
                GestureDetector(
                  onTap: () => _copyCoordinateValue(value, label: 'WGS84'),
                  child: Align(
                    alignment: isArabic ? Alignment.centerRight : Alignment.centerLeft,
                    child: Center(
                      child: Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: isDark ? const Color(0xFFE9E9E9) : const Color(0xFF1D1D1D),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
