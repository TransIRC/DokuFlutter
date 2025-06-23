import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'wiki_text_parser.dart';

class PageContent extends StatelessWidget {
  final String text;
  final void Function(String pageId) onTapLink;

  const PageContent({
    super.key,
    required this.text,
    required this.onTapLink,
  });

  bool _isExternal(String link) =>
      link.startsWith('http://') ||
      link.startsWith('https://') ||
      link.startsWith('mailto:');

  @override
  Widget build(BuildContext context) {
    final markdown = dokuwikiToMarkdown(text);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: MarkdownBody(
          data: markdown,
          selectable: true,
          styleSheet: MarkdownStyleSheet(
            a: const TextStyle(
                color: Colors.blue, decoration: TextDecoration.underline),
          ),
          onTapLink: (text, href, title) {
            if (href == null) return;
            if (_isExternal(href)) {
              // Optionally show a snackbar or do nothing
              // ScaffoldMessenger.of(context).showSnackBar(
              //   SnackBar(content: Text("External links are disabled")),
              // );
            } else {
              onTapLink(href);
            }
          },
        ),
      ),
    );
  }
}