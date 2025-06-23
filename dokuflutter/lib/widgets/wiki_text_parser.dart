// Converts DokuWiki links to Markdown links for markdown rendering.
final RegExp wikiLink = RegExp(r'\[\[([^\]|]+)(?:\|([^\]]+))?\]\]');

String dokuwikiToMarkdown(String wikiText) {
  // Convert [[page|Text]] to [Text](page), [[page]] to [page](page)
  return wikiText.replaceAllMapped(wikiLink, (match) {
    final target = match[1] ?? '';
    final text = match[2] ?? target;
    return '[$text]($target)';
  });
}