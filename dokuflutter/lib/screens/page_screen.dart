import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../services/wiki_service.dart';
import '../services/sync_service.dart';
import '../widgets/page_content.dart';
import '../widgets/wiki_sidebar.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../widgets/wiki_text_parser.dart';

class PageScreen extends StatefulWidget {
  final String pageId;
  final VoidCallback? onToggleTheme;
  final ThemeMode? themeMode;

  const PageScreen({
    super.key,
    required this.pageId,
    this.onToggleTheme,
    this.themeMode,
  });

  @override
  State<PageScreen> createState() => _PageScreenState();
}

class _PageScreenState extends State<PageScreen> {
  late Future<String> _pageFuture;
  late Future<String> _sidebarFuture;
  bool _isSyncing = false;
  bool _offline = false;
  String? _lastSync;

  List<pw.Font>? _pdfFonts;
  Future<void>? _fontLoader;

  @override
  void initState() {
    super.initState();
    _fontLoader = _loadPdfFonts();
    _syncIfNeeded();
    _loadPage();
    _loadSidebar();
    _lastSync = SyncService().lastSync;
  }

  Future<void> _loadPdfFonts() async {
    final regularFontData = await rootBundle.load("assets/fonts/NotoSans-Regular.ttf");
    final emojiFontData = await rootBundle.load("assets/fonts/NotoEmoji-Regular.ttf");
    setState(() {
      _pdfFonts = [
        pw.Font.ttf(regularFontData),
        pw.Font.ttf(emojiFontData),
      ];
    });
  }

  Future<void> _syncIfNeeded() async {
    final isOnline = await SyncService().isOnline;
    if (isOnline) {
      setState(() => _isSyncing = true);
      try {
        await SyncService().syncAllPages();
        setState(() => _lastSync = SyncService().lastSync);
      } catch (_) {}
      setState(() => _isSyncing = false);
    } else {
      setState(() => _offline = true);
    }
  }

  void _loadPage() {
    _pageFuture = _getPage(widget.pageId);
  }

  void _loadSidebar() {
    _sidebarFuture = _getPage('sidebar');
  }

  Future<String> _getPage(String pageId) async {
    final isOnline = await SyncService().isOnline;
    if (isOnline) {
      try {
        return await WikiService().getPage(pageId);
      } catch (_) {}
    }
    final cached = SyncService().getCachedPage(pageId);
    if (cached != null) return cached;
    throw Exception('Page not available offline.');
  }

  void _openPage(String pageId) {
    if (pageId == widget.pageId) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PageScreen(
          pageId: pageId,
          onToggleTheme: widget.onToggleTheme,
          themeMode: widget.themeMode,
        ),
      ),
    );
  }

  // Share the entire section as PDF (no popup)
  Future<void> _shareSectionDirect() async {
    await _fontLoader;

    // Determine the section namespace
    String namespace;
    if (widget.pageId.contains(':')) {
      namespace = widget.pageId.substring(0, widget.pageId.lastIndexOf(':') + 1);
    } else {
      namespace = 'start';
    }

    final allPages = await WikiService().getAllPages();
    final sectionPages = allPages
        .where((p) => p['id'].toString().startsWith(namespace))
        .toList();

    String startId = namespace.endsWith(':') ? '${namespace}start' : '$namespace:start';
    final startPage = sectionPages.where((p) => p['id'] == startId).toList();
    final otherPages = sectionPages.where((p) => p['id'] != startId).toList();

    final List<Map<String, dynamic>> orderedPages = [
      ...startPage,
      ...otherPages,
    ];

    final pdf = await _generateSectionPdf(namespace, orderedPages);
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: "${namespace.replaceAll(':', '_')}.pdf",
    );
  }

  Future<pw.Document> _generatePdf(String pageId, String content) async {
    final regularFont = _pdfFonts![0];
    final emojiFont = _pdfFonts![1];

    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        theme: pw.ThemeData.withFont(
          base: regularFont,
          bold: regularFont,
          italic: regularFont,
          boldItalic: regularFont,
        ),
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              pageId,
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                font: regularFont,
                fontFallback: [emojiFont],
              ),
            ),
          ),
          ..._markdownToPdfWidgetsWithLinks(content, regularFont, emojiFont, [pageId]),
        ],
      ),
    );
    return pdf;
  }

  Future<pw.Document> _generateSectionPdf(
      String namespace, List<Map<String, dynamic>> sectionPages) async {
    final regularFont = _pdfFonts![0];
    final emojiFont = _pdfFonts![1];
    final pdf = pw.Document();

    final pageIds = sectionPages.map((p) => p['id'] as String).toList();

    for (final p in sectionPages) {
      final pageId = p['id'] as String;
      final content = await _getPage(pageId);

      pdf.addPage(
        pw.MultiPage(
          theme: pw.ThemeData.withFont(
            base: regularFont,
            bold: regularFont,
            italic: regularFont,
            boldItalic: regularFont,
          ),
          build: (context) => [
            pw.Anchor(
              name: pageId,
              child: pw.Header(
                level: 0,
                child: pw.Text(
                  pageId,
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    font: regularFont,
                    fontFallback: [emojiFont],
                  ),
                ),
              ),
            ),
            ..._markdownToPdfWidgetsWithLinks(content, regularFont, emojiFont, pageIds),
            pw.SizedBox(height: 20),
          ],
        ),
      );
    }
    return pdf;
  }

  List<pw.Widget> _markdownToPdfWidgetsWithLinks(
      String markdown, pw.Font regularFont, pw.Font emojiFont, List<String> pageIds) {
    final wikiLink = RegExp(r'\[([^\]]+)\]\(([^)]+)\)');
    final lines = dokuwikiToMarkdown(markdown).split('\n');
    List<pw.Widget> widgets = [];
    for (final line in lines) {
      if (wikiLink.hasMatch(line)) {
        List<pw.Widget> row = [];
        int lastEnd = 0;
        for (final match in wikiLink.allMatches(line)) {
          if (match.start > lastEnd) {
            row.add(pw.Text(
              line.substring(lastEnd, match.start),
              style: pw.TextStyle(font: regularFont, fontFallback: [emojiFont]),
            ));
          }
          final text = match.group(1) ?? '';
          final target = match.group(2) ?? '';
          if (pageIds.contains(target)) {
            row.add(
              pw.UrlLink(
                destination: '#$target',
                child: pw.Text(
                  text,
                  style: pw.TextStyle(
                    color: PdfColor.fromInt(0xff1976d2),
                    decoration: pw.TextDecoration.underline,
                    font: regularFont,
                    fontFallback: [emojiFont],
                  ),
                ),
              ),
            );
          } else {
            row.add(
              pw.Text(
                text,
                style: pw.TextStyle(font: regularFont, fontFallback: [emojiFont]),
              ),
            );
          }
          lastEnd = match.end;
        }
        if (lastEnd < line.length) {
          row.add(pw.Text(
            line.substring(lastEnd),
            style: pw.TextStyle(font: regularFont, fontFallback: [emojiFont]),
          ));
        }
        widgets.add(pw.Row(
          children: row,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
        ));
      } else if (line.startsWith('#')) {
        widgets.add(
          pw.Text(
            line.replaceAll(RegExp(r'^#+\s*'), ''),
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 16,
              font: regularFont,
              fontFallback: [emojiFont],
            ),
          ),
        );
      } else if (line.startsWith('- ') || line.startsWith('* ')) {
        widgets.add(
          pw.Bullet(
            text: line.replaceFirst(RegExp(r'^[-*]\s*'), ''),
            style: pw.TextStyle(font: regularFont, fontFallback: [emojiFont]),
          ),
        );
      } else {
        widgets.add(
          pw.Text(
            line,
            style: pw.TextStyle(font: regularFont, fontFallback: [emojiFont]),
          ),
        );
      }
    }
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.pageId.replaceAll('_', ' ')),
        actions: [
          IconButton(
            tooltip: 'Share section as PDF',
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _shareSectionDirect,
          ),
        ],
      ),
      drawer: Drawer(
        child: SizedBox(
          width: 110,
          child: FutureBuilder<String>(
            future: _sidebarFuture,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return WikiSidebar(
                text: snapshot.data!,
                onTapLink: _openPage,
                onShareSection: (section) {
                  _shareSectionDirect();
                },
                onToggleTheme: widget.onToggleTheme,
                themeMode: widget.themeMode,
              );
            },
          ),
        ),
      ),
      body: Column(
        children: [
          if (_isSyncing)
            Container(
              width: double.infinity,
              color: Colors.yellow[100],
              padding: const EdgeInsets.all(8),
              child: const Text(
                "Downloading WiKi Contents...",
                textAlign: TextAlign.center,
              ),
            ),
          if (_offline)
            Container(
              width: double.infinity,
              color: Colors.red[100],
              padding: const EdgeInsets.all(8),
              child: const Text(
                "Offline mode: showing last downloaded copy.",
                textAlign: TextAlign.center,
              ),
            ),
          if (_lastSync != null)
            Container(
              width: double.infinity,
              color: Colors.blue[50],
              padding: const EdgeInsets.all(8),
              child: Text(
                "Last updated: $_lastSync",
                textAlign: TextAlign.center,
              ),
            ),
          Expanded(
            child: FutureBuilder<String>(
              future: _pageFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                } else {
                  return PageContent(
                    text: snapshot.data ?? '',
                    onTapLink: _openPage,
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}