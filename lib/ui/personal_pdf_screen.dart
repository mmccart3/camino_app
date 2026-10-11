import '../services/personal_pdf.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import '../services/personal_store.dart';

class PersonalPdfScreen extends StatefulWidget {
  final String title;
  final List<PersonalEntry> entries;
  const PersonalPdfScreen({
    super.key,
    required this.title,
    required this.entries,
  });
  @override
  State<PersonalPdfScreen> createState() => _PersonalPdfScreenState();
}

class _PersonalPdfScreenState extends State<PersonalPdfScreen> {
  Uint8List? bytes;
  String? error;
  bool sharing = false;
  @override
  void initState() {
    super.initState();
    generate();
  }

  Future<void> generate() async {
    setState(() => error = null);
    try {
      final regular = await rootBundle.load(
        'assets/fonts/LiberationSans-Regular.ttf',
      );
      final bold = await rootBundle.load(
        'assets/fonts/LiberationSans-Bold.ttf',
      );
      final result = await buildPersonalPdf(
        widget.title,
        widget.entries,
        regular,
        bold,
      );
      if (mounted) setState(() => bytes = result);
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Could not generate PDF. Tap to retry.');
      }
    }
  }

  Future<void> share(BuildContext buttonContext) async {
    setState(() => sharing = true);
    try {
      final box = buttonContext.findRenderObject() as RenderBox?;
      final opened = await Printing.sharePdf(
        bytes: bytes!,
        filename: '${widget.title.replaceAll(' ', '-')}.pdf',
        subject: widget.title,
        body: 'Shared from Saint Jean to Santiago.',
        bounds: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      );
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Sharing was not completed. You can retry or save the PDF.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open sharing. Please retry.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title), centerTitle: true),
    body: SafeArea(
      child: error != null
          ? Center(
              child: TextButton(onPressed: generate, child: Text(error!)),
            )
          : bytes == null
          ? const Center(child: CircularProgressIndicator())
          : PdfPreview(
              build: (_) => bytes!,
              allowSharing: false,
              canChangeOrientation: false,
              canChangePageFormat: false,
            ),
    ),
    bottomNavigationBar: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Builder(
          builder: (context) => FilledButton.icon(
            onPressed: bytes == null || sharing ? null : () => share(context),
            icon: const Icon(Icons.share),
            label: const Text('Share PDF / email'),
          ),
        ),
      ),
    ),
  );
}
