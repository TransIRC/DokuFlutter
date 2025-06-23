import 'package:xml_rpc/client.dart' as xml_rpc;
import '../config/config.dart';

class WikiService {
  final String apiUrl = AppConfig.dokuwikiApiUrl;

  Future<String> getPage(String pageId) async {
    final result = await xml_rpc.call(Uri.parse(apiUrl), 'wiki.getPage', [pageId]);
    return result as String;
  }

  Future<List<dynamic>> getAllPages() async {
    // Returns list of page maps with 'id' and 'title'
    final result = await xml_rpc.call(Uri.parse(apiUrl), 'wiki.getAllPages', []);
    return result as List<dynamic>;
  }
}