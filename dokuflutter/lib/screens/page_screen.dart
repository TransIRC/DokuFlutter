import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart'; // Add this import for PdfColor
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

  // Load both text and emoji fonts for PDF export
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
    // fallback to cache
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

  // --- SHARE AS PDF FEATURE START ---
  Future<void> _shareCurrentPage() async {
    await _fontLoader;
    final pageText = await _getPage(widget.pageId);
    final pdf = await _generatePdf(widget.pageId, pageText);
    await Printing.sharePdf(bytes: await pdf.save(), filename: "${widget.pageId.replaceAll(':', '_')}.pdf");
  }

  Future<void> _shareSection(String namespace) async {
    await _fontLoader;
    final allPages = await WikiService().getAllPages();
    // Only include pages in this namespace
    final sectionPages = allPages
        .where((p) => p['id'].toString().startsWith(namespace))
        .toList();

    // Make sure start page is first if it exists
    String startId = namespace.endsWith(':') ? '${namespace}start' : '$namespace:start';
    final startPage = sectionPages.where((p) => p['id'] == startId).toList();
    final otherPages = sectionPages.where((p) => p['id'] != startId).toList();

    final List<Map<String, dynamic>> orderedPages = [
      ...startPage,
      ...otherPages,
    ];

    final pdf = await _generateSectionPdf(namespace, orderedPages);
    await Printing.sharePdf(bytes: await pdf.save(), filename: "${namespace.replaceAll(':', '_')}.pdf");
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

    // Collect IDs for anchor lookup
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

  // Internal link support in markdown
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
          // Any text before the link
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
                    color: PdfColor.fromInt(0xff1976d2), // Material blue 700
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
        // Any trailing text after the last link
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
  // --- SHARE AS PDF FEATURE END ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.pageId.replaceAll('_', ' ')),
        actions: [
          IconButton(
            tooltip: 'Share this page as PDF',
            icon: const Icon(Icons.share),
            onPressed: _shareCurrentPage,
          ),
          PopupMenuButton<String>(
            tooltip: 'Share section as PDF',
            icon: const Icon(Icons.picture_as_pdf),
            onSelected: (section) {
              _shareSection(section);
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: widget.pageId.contains(':') ? widget.pageId.split(':').first + ':' : 'start',
                child: const Text('Share whole section'),
              ),
            ],
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
                onShareSection: _shareSection,
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
                "Copying the wiki to your phone. Pages will appear as they're synced...",
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