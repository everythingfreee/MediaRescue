import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import '../../models/file_item.dart';

class PdfViewerScreen extends StatefulWidget {
  final FileItem item;

  const PdfViewerScreen({super.key, required this.item});

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  int _currentPage = 0;
  int _totalPages = 0;
  bool _isLoading = true;
  String? _error;
  String? _cachedPath;

  @override
  void initState() {
    super.initState();
    _preparePdf();
  }

  /// Copies the PDF to app cache so flutter_pdfview can access it reliably.
  Future<void> _preparePdf() async {
    try {
      final source = File(widget.item.path);
      if (!source.existsSync()) {
        setState(() {
          _error = 'File not found';
          _isLoading = false;
        });
        return;
      }

      // Copy to cache directory
      final cacheDir = Directory(
        '${Directory.systemTemp.path}/mediarescue_pdfs',
      );
      if (!cacheDir.existsSync()) {
        cacheDir.createSync(recursive: true);
      }

      final cachedFile = File('${cacheDir.path}/${widget.item.name}');
      if (!cachedFile.existsSync()) {
        await source.copy(cachedFile.path);
      }

      if (!mounted) return;
      setState(() {
        _cachedPath = cachedFile.path;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to prepare PDF: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.item.name,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (_totalPages > 0)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text('${_currentPage + 1} / $_totalPages'),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () {
                            setState(() {
                              _isLoading = true;
                              _error = null;
                            });
                            _preparePdf();
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _cachedPath != null
                  ? PDFView(
                      filePath: _cachedPath!,
                      autoSpacing: true,
                      enableSwipe: true,
                      pageFling: true,
                      swipeHorizontal: false,
                      onRender: (pages) {
                        setState(() {
                          _totalPages = pages ?? 0;
                        });
                      },
                      onError: (error) {
                        setState(() {
                          _error = error.toString();
                        });
                      },
                      onPageChanged: (page, total) {
                        setState(() {
                          _currentPage = page ?? 0;
                          _totalPages = total ?? 0;
                        });
                      },
                    )
                  : const Center(child: Text('No PDF to display')),
    );
  }
}