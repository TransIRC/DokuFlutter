import 'dart:async';
import 'package:hive/hive.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'wiki_service.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  late Box _pagesBox;
  late Box _metaBox;

  Future<void> init() async {
    _pagesBox = await Hive.openBox('wiki_pages');
    _metaBox = await Hive.openBox('wiki_meta');
  }

  Future<bool> get isOnline async {
    final result = await Connectivity().checkConnectivity();
    return result != ConnectivityResult.none;
  }

  /// Syncs all pages, but only updates if the fetched content is different from what's already cached.
  Future<void> syncAllPages() async {
    final pages = await WikiService().getAllPages();
    DateTime now = DateTime.now();

    for (final page in pages) {
      final id = page['id'];
      final fetchedContent = await WikiService().getPage(id);
      final cachedContent = _pagesBox.get(id) as String?;
      if (cachedContent != fetchedContent) {
        await _pagesBox.put(id, fetchedContent);
      }
    }
    await _metaBox.put('lastSync', now.toIso8601String());
  }

  String? getCachedPage(String pageId) {
    return _pagesBox.get(pageId) as String?;
  }

  String? get lastSync => _metaBox.get('lastSync') as String?;
}