# TransIRC Wiki App

A cross-platform Flutter app to browse, read, and share content from the [TransIRC DokuWiki](https://wiki.transirc.chat), with full offline support and PDF export capabilities.
Which you can compile for your own DokuWiki!

---

## Features

- **Browse Any Page:** Jump to any wiki page by ID.
- **Offline Sync:** The app syncs the entire wiki for offline access, so you can read pages anytime, anywhere.
- **Dark/Light Theme:** Easily switch between dark and light modes.
- **Sidebar Menu:** Quickly access common pages and sections.
- **PDF Export:** Export any page or entire section as a PDF, including proper internal linking and emoji support.
- **Markdown Rendering:** DokuWiki syntax is automatically converted to readable Markdown.
- **Safe External Links:** External links are disabled for safety (can be customized).

---

## Screenshots

<!--
Add your screenshots here, e.g.
![Home Screen](screenshots/home.png)
![Wiki Page](screenshots/page.png)
-->

---

## Getting Started

### Requirements

- Flutter 3.x
- Dart 3.x

### Dependencies

- [hive_flutter](https://pub.dev/packages/hive_flutter) - persistent offline storage
- [printing](https://pub.dev/packages/printing) - PDF export and sharing
- [flutter_markdown](https://pub.dev/packages/flutter_markdown) - Markdown rendering
- [connectivity_plus](https://pub.dev/packages/connectivity_plus) - Detect online/offline status
- [xml_rpc](https://pub.dev/packages/xml_rpc) - DokuWiki XML-RPC API client

### Setup

1. **Clone the Repo**

   ```sh
   git clone https://github.com/TransIRC/DokuFlutter.git
   cd transirc-wiki-app
   ```

2. **Install Dependencies**

   ```sh
   flutter pub get
   ```

3. **Fonts**

   - Make sure you have these fonts in your `assets/fonts/` directory:
     - [NotoSans-Regular.ttf](https://fonts.google.com/specimen/Noto+Sans)
     - [NotoEmoji-Regular.ttf](https://github.com/googlefonts/noto-emoji)
   - Register them in your `pubspec.yaml` if not already done.

4. **Run the App**

   ```sh
   flutter run
   ```

---

## Architecture Overview

- **main.dart:** App entry point, theme management, and initial sync.
- **screens/home_screen.dart:** Home page for selecting wiki pages.
- **screens/page_screen.dart:** Wiki page viewer, handles offline/online logic, PDF export.
- **services/wiki_service.dart:** Handles API calls to DokuWiki XML-RPC.
- **services/sync_service.dart:** Manages offline syncing and cache.
- **widgets/page_content.dart:** Renders wiki text as Markdown.
- **widgets/wiki_sidebar.dart:** Sidebar menu with quick-links and theme/PDF controls.
- **widgets/wiki_text_parser.dart:** Converts DokuWiki links to Markdown links.

---

## PDF Export

- Exports support both plain text and emoji.
- Internal links within a section become clickable anchors in the PDF.
- You can share either the current page or a whole section (namespace) as a PDF.

---

## Customization

- **API Endpoint:** Change the DokuWiki API endpoint in `config/config.dart`.
- **Sidebar / Start Page:** Set default section or menu in `screens/page_screen.dart` or `widgets/wiki_sidebar.dart`.
- **External Links:** Enable or disable external links in `page_content.dart`.

---

## Roadmap / TODO

- [ ] Improve section detection for PDF export in sidebar.
- [ ] Add search by title/keyword.
- [ ] Support for page editing (if/when authentication is added).
- [ ] More robust error handling and user feedback.
