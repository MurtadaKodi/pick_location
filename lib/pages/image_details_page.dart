// ignore_for_file: deprecated_member_use

part of '../main.dart';

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
  late DateTime _now;
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    _detailsController = TextEditingController(text: widget.details);
    _images = List<XFile>.from(widget.images);
    _now = DateTime.now();
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _now = DateTime.now();
      });
    });
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

  int get _detailsWordCount {
    final text = _detailsController.text.trim();
    if (text.isEmpty) {
      return 0;
    }

    return text.split(RegExp(r'\s+')).where((part) => part.isNotEmpty).length;
  }

  void _onDetailsChanged() {
    widget.onDetailsChanged(_detailsController.text);
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _detailsController.removeListener(_onDetailsChanged);
    _detailsController.dispose();
    super.dispose();
  }

  String _formatCurrentDateTime(DateTime value) {
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    final date = '${value.year}-${twoDigits(value.month)}-${twoDigits(value.day)}';
    final time = '${twoDigits(value.hour)}:${twoDigits(value.minute)}';
    return '$date $time';
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
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.strings.isArabic ? 'إضافة الصور والتفاصيل' : 'Photos & details',
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: 170,
                          child: FilledButton.icon(
                            onPressed: _pickFromGallery,
                            icon: const Icon(Icons.photo_library_outlined),
                            label: Text(widget.strings.chooseGallery),
                          ),
                        ),
                        SizedBox(
                          width: 170,
                          child: FilledButton.icon(
                            onPressed: _captureFromCamera,
                            icon: const Icon(Icons.photo_camera_outlined),
                            label: Text(widget.strings.takePhoto),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.strings.currentDateTime}:',
                      style: Theme.of(
                        context,
                      ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _formatCurrentDateTime(_now),
                        style: Theme.of(
                          context,
                        ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      widget.strings.details,
                      style: Theme.of(
                        context,
                      ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                          width: 1,
                        ),
                      ),
                      child: TextField(
                        controller: _detailsController,
                        maxLines: 8,
                        minLines: 6,
                        textAlign: TextAlign.start,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.transparent,
                          hintText: widget.strings.isArabic
                              ? 'اكتب اي تفاصيل مرتبطة بالموقع او الصور...'
                              : 'Write any details related to the location or photos...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                              width: 1.2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '$_detailsWordCount ${widget.strings.isArabic ? 'كلمة' : 'words'}',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.strings.photos,
                            style: Theme.of(
                              context,
                            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${_images.length}',
                            style: Theme.of(
                              context,
                            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_images.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 30),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Text(
                            widget.strings.noPhotos,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      )
                    else
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
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
                                borderRadius: BorderRadius.circular(12),
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
                    const SizedBox(height: 16),
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
          ],
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
