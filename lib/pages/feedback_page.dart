// part of '../main.dart';

// class FeedbackPage extends StatefulWidget {
//   const FeedbackPage({
//     super.key,
//     required this.strings,
//     required this.appVersion,
//     required this.onToggleLanguage,
//     required this.onToggleTheme,
//   });

//   final AppStrings strings;
//   final String appVersion;
//   final VoidCallback onToggleLanguage;
//   final VoidCallback onToggleTheme;

//   @override
//   State<FeedbackPage> createState() => _FeedbackPageState();
// }

// class _FeedbackPageState extends State<FeedbackPage> {
//   final TextEditingController _feedbackController = TextEditingController();
//   List<String> _feedbackItems = const [];
//   List<String> _logs = const [];
//   int _errorCount = 0;
//   bool _loading = true;

//   @override
//   void initState() {
//     super.initState();
//     _loadData();
//   }

//   @override
//   void dispose() {
//     _feedbackController.dispose();
//     super.dispose();
//   }

//   Future<void> _loadData() async {
//     final feedback = await AppLogger.readFeedback();
//     final logs = await AppLogger.readLogs(limit: 15);
//     final errors = await AppLogger.countErrors();

//     if (!mounted) {
//       return;
//     }

//     setState(() {
//       _feedbackItems = feedback;
//       _logs = logs;
//       _errorCount = errors;
//       _loading = false;
//     });
//   }

//   Future<void> _saveFeedback() async {
//     final text = _feedbackController.text.trim();
//     if (text.isEmpty) {
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(const SnackBar(content: Text('اكتب ملاحظة قبل الحفظ')));
//       return;
//     }

//     await AppLogger.saveFeedback(text);
//     await AppLogger.logUsage('feedback_saved');
//     _feedbackController.clear();
//     await _loadData();

//     if (!mounted) {
//       return;
//     }

//     ScaffoldMessenger.of(
//       context,
//     ).showSnackBar(const SnackBar(content: Text('تم حفظ الملاحظة محليا')));
//   }

//   String _formatFeedbackItem(String item) {
//     final split = item.split('|');
//     if (split.length < 2) {
//       return item;
//     }
//     final timestamp = split.first;
//     final text = split.sublist(1).join('|');
//     return '$timestamp\n$text';
//   }

//   String _formatLogItem(String item) {
//     final split = item.split('|');
//     if (split.length < 4) {
//       return item;
//     }
//     return '${split[0]} | ${split[1]}\n${split[2]}${split[3].isEmpty ? '' : ' (${split[3]})'}';
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text(widget.strings.feedbackTitle),
//         actions: [
//           IconButton(
//             onPressed: widget.onToggleLanguage,
//             icon: const Icon(Icons.translate),
//             tooltip: widget.strings.toggleLanguage,
//           ),
//           IconButton(
//             onPressed: widget.onToggleTheme,
//             icon: Icon(
//               Theme.of(context).brightness == Brightness.dark ? Icons.light_mode : Icons.dark_mode,
//             ),
//             tooltip: widget.strings.toggleTheme,
//           ),
//           IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh), tooltip: 'تحديث'),
//         ],
//       ),
//       body: _loading
//           ? const Center(child: CircularProgressIndicator())
//           : ListView(
//               padding: const EdgeInsets.all(16),
//               children: [
//                 Card(
//                   child: Padding(
//                     padding: const EdgeInsets.all(12),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text('${widget.strings.versionLabel}: ${widget.appVersion}'),
//                         const SizedBox(height: 6),
//                         Text('${widget.strings.errorCountLabel}: $_errorCount'),
//                         const SizedBox(height: 6),
//                         Text('${widget.strings.eventCountLabel}: ${_logs.length} (آخر 15 حدث)'),
//                       ],
//                     ),
//                   ),
//                 ),
//                 const SizedBox(height: 12),
//                 TextField(
//                   controller: _feedbackController,
//                   minLines: 2,
//                   maxLines: 4,
//                   decoration: const InputDecoration(
//                     border: OutlineInputBorder(),
//                     labelText: 'ملاحظة المستخدم',
//                     hintText: 'اكتب الملاحظة أو الاقتراح...',
//                   ),
//                 ),
//                 const SizedBox(height: 8),
//                 FilledButton.icon(
//                   onPressed: _saveFeedback,
//                   icon: const Icon(Icons.save_outlined),
//                   label: const Text('حفظ الملاحظة'),
//                 ),
//                 const SizedBox(height: 16),
//                 Text(
//                   widget.strings.isArabic ? 'آخر الملاحظات' : 'Latest Feedback',
//                   style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
//                 ),
//                 const SizedBox(height: 8),
//                 if (_feedbackItems.isEmpty)
//                   Text(widget.strings.noFeedback)
//                 else
//                   ..._feedbackItems
//                       .take(5)
//                       .map(
//                         (item) => Card(
//                           child: Padding(
//                             padding: const EdgeInsets.all(10),
//                             child: Text(_formatFeedbackItem(item)),
//                           ),
//                         ),
//                       ),
//                 const SizedBox(height: 12),
//                 Text(
//                   widget.strings.isArabic ? 'آخر الأحداث والأخطاء' : 'Latest Events & Errors',
//                   style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
//                 ),
//                 const SizedBox(height: 8),
//                 if (_logs.isEmpty)
//                   Text(widget.strings.noLogs)
//                 else
//                   ..._logs.map(
//                     (log) => Card(
//                       child: Padding(
//                         padding: const EdgeInsets.all(10),
//                         child: Text(_formatLogItem(log)),
//                       ),
//                     ),
//                   ),
//               ],
//             ),
//     );
//   }
// }
