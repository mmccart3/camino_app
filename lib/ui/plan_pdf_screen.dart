import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../services/plan_pdf.dart';
import '../services/plan_pdf_data.dart';

class PlanPdfScreen extends StatefulWidget {
  final Future<PlanPdfData> Function() load;
  const PlanPdfScreen({super.key, required this.load});
  @override
  State<PlanPdfScreen> createState() => _PlanPdfScreenState();
}

class _PlanPdfScreenState extends State<PlanPdfScreen> {
  bool references = true, notes = true, sharing = false;
  PlanPdfData? data;
  ByteData? regular, bold;
  String? error;
  Uint8List? bytes;
  int revision = 0;
  @override
  void initState() {
    super.initState();
    generate();
  }

  Future<void> generate() async {
    final token = ++revision;
    final options = PlanPdfOptions(
      includeReferences: references,
      includeNotes: notes,
    );
    setState(() {
      bytes = null;
      error = null;
    });
    try {
      data ??= await widget.load();
      regular ??= await rootBundle.load(
        'assets/fonts/LiberationSans-Regular.ttf',
      );
      bold ??= await rootBundle.load('assets/fonts/LiberationSans-Bold.ttf');
      final result = await PlanPdf.build(
        data!,
        regularFont: regular!,
        boldFont: bold!,
        options: options,
      );
      if (mounted && revision == token) setState(() => bytes = result);
    } catch (_) {
      if (mounted && revision == token) {
        setState(() => error = 'Could not create this PDF. Please retry.');
      }
    }
  }

  Future<void> share(BuildContext buttonContext) async {
    final document = bytes;
    if (document == null || sharing) return;
    final box = buttonContext.findRenderObject() as RenderBox?;
    final bounds = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    setState(() => sharing = true);
    try {
      final opened = await Printing.sharePdf(
        bytes: document,
        filename: PlanPdf.filename(data!.title),
        subject: data!.title,
        body: 'My Camino plan - created with Saint Jean to Santiago.',
        bounds: bounds,
      );
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Sharing was not completed. You can retry or use the print/save option.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not open sharing. Please retry or use the print/save option below.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Share plan PDF'), centerTitle: true),
    body: SafeArea(
      child: Column(
        children: [
          SwitchListTile(
            title: const Text('Include booking references'),
            value: references,
            onChanged: bytes == null || sharing
                ? null
                : (value) {
                    references = value;
                    generate();
                  },
          ),
          SwitchListTile(
            title: const Text('Include notes'),
            value: notes,
            onChanged: bytes == null || sharing
                ? null
                : (value) {
                    notes = value;
                    generate();
                  },
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              Platform.isWindows
                  ? 'Preview your copy, then open it in your PDF viewer to save it and attach it to an email.'
                  : 'Preview your copy, then choose an email or messaging app. You select the recipients and send it.',
            ),
          ),
          Builder(
            builder: (buttonContext) => FilledButton.icon(
              onPressed: bytes == null || sharing
                  ? null
                  : () => share(buttonContext),
              icon: const Icon(Icons.share_outlined),
              label: Text(
                sharing
                    ? 'Opening...'
                    : Platform.isWindows
                    ? 'Open PDF to save or attach'
                    : 'Share / save PDF',
              ),
            ),
          ),
          Expanded(
            child: error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(error!),
                        TextButton(
                          onPressed: generate,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : bytes == null
                ? const Center(child: CircularProgressIndicator())
                : PdfPreview(
                    key: ValueKey(revision),
                    build: (_) => bytes!,
                    initialPageFormat: PdfPageFormat.a4,
                    canChangePageFormat: false,
                    canChangeOrientation: false,
                    canDebug: false,
                    allowSharing: false,
                    pdfFileName: PlanPdf.filename(data!.title),
                    onError: (context, error) => const Center(
                      child: Text(
                        'Preview is unavailable on this device. You can still share or save the PDF.',
                      ),
                    ),
                  ),
          ),
        ],
      ),
    ),
  );
}
