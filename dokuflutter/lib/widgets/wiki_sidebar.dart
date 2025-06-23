import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'wiki_text_parser.dart';

class WikiSidebar extends StatelessWidget {
  final String text;
  final void Function(String pageId) onTapLink;
  final void Function(String namespace)? onShareSection;
  final VoidCallback? onToggleTheme;
  final ThemeMode? themeMode;

  const WikiSidebar({
    super.key,
    required this.text,
    required this.onTapLink,
    this.onShareSection,
    this.onToggleTheme,
    this.themeMode,
  });

  @override
  Widget build(BuildContext context) {
    final markdown = dokuwikiToMarkdown(text);
    final baseStyle = Theme.of(context).textTheme.bodyMedium!;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8.0, left: 8.0, right: 8.0, bottom: 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Menu",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    IconButton(
                      tooltip: "Share this section as PDF",
                      icon: const Icon(Icons.picture_as_pdf),
                      onPressed: () {
                        // Assume current section is the top-level namespace or customize as needed
                        final section = _detectCurrentSection(context);
                        if (onShareSection != null) {
                          onShareSection!(section);
                        }
                      },
                    ),
                    IconButton(
                      tooltip: isDark ? "Switch to Light Mode" : "Switch to Dark Mode",
                      icon: Icon(isDark ? Icons.wb_sunny : Icons.nightlight_round),
                      onPressed: onToggleTheme,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Markdown(
                data: markdown,
                styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                  p: baseStyle.copyWith(fontSize: baseStyle.fontSize! * 2),
                ),
                onTapLink: (text, href, title) {
                  if (href != null && !_isExternal(href)) {
                    Navigator.of(context).pop();
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      onTapLink(href);
                    });
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _detectCurrentSection(BuildContext context) {
    // This is a placeholder - you may want to pass the section/namespace down or detect from nav stack
    // For now, just return 'start' or whatever you want as default
    return 'start';
  }

  bool _isExternal(String link) =>
      link.startsWith('http://') ||
      link.startsWith('https://') ||
      link.startsWith('mailto:');
}