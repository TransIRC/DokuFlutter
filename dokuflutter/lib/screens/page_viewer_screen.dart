import 'package:flutter/material.dart';
import '../services/wiki_service.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class PageViewerScreen extends StatefulWidget {
  final String pageId;
  const PageViewerScreen({Key? key, required this.pageId}) : super(key: key);

  @override
  State<PageViewerScreen> createState() => _PageViewerScreenState();
}

class _PageViewerScreenState extends State<PageViewerScreen> {
  late Future<String> _pageText;

  @override
  void initState() {
    super.initState();
    _pageText = WikiService().getPage(widget.pageId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.pageId)),
      body: FutureBuilder<String>(
        future: _pageText,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else {
            return Markdown(data: snapshot.data ?? '');
          }
        },
      ),
    );
  }
}