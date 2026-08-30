# Platforms & configuration

<!-- Extracted from README.md so the README stays an overview. -->

## Platform Support

<table>
<tr><th>Platform</th><th>Status</th><th>Notes</th></tr>
<tr><td><b>macOS</b></td><td>Full support</td><td>Native desktop app. All features including torrent streaming and glassmorphism GPU effects. Primary development target.</td></tr>
<tr><td><b>iOS</b></td><td>Full support</td><td>Includes libass native framework for ASS/SSA subtitle rendering. All scrapers and streaming work.</td></tr>
<tr><td><b>Android</b></td><td>Full support</td><td>Min SDK 21 (Android 5.0). All features functional.</td></tr>
<tr><td><b>Linux</b></td><td>Full support</td><td>Native Linux desktop via GTK embedding. Torrent engine compiled for Linux.</td></tr>
<tr><td><b>Windows</b></td><td>Full support</td><td>Native Win32 desktop. All features functional.</td></tr>
<tr><td><b>Web</b></td><td>Experimental</td><td>Runs in Chrome but native plugins (libtorrent, fvp, libass) are unavailable. Limited to direct VOD streaming and metadata browsing.</td></tr>
</table>

<br/>

---

## Configuration

### pubspec.yaml — Key Dependencies

| Package | Version | Purpose |
|:--------|:--------|:--------|
| `flutter` | SDK | Core Flutter framework |
| `torrserver_flutter` | ^0.0.1 | Embedded TorrServer engine & HTTP streaming client |
| `fvp` | ^0.37.3 | FFmpeg-based video player with broad codec support |
| `video_player` | ^2.11.1 | Standard video playback widget |
| `liquid_glass_easy` | ^4.1.1 | GPU-accelerated glassmorphism shader effects |
| `cached_network_image` | ^3.4.1 | Image caching with placeholder and error states |
| `http` | ^1.2.2 | HTTP client for all API and scraper requests |
| `html` | ^0.15.5 | Server-side DOM parsing for web scrapers |
| `shared_preferences` | ^2.3.3 | Persistent key-value storage |
| `url_launcher` | ^6.3.2 | Open external URLs in browser |
| `archive` | ^4.0.9 | ZIP extraction for subtitle downloads |
| `path_provider` | ^2.1.6 | Platform-appropriate file paths |
| `photo_view` | ^0.15.0 | Pinch-to-zoom image viewing (manga reader) |
| `flutter_js` | ^0.8.1 | JavaScript runtime bridge for JS-based scrapers |
| `cupertino_icons` | ^1.0.8 | iOS-style icon set |
| `libass_plugin` | path: ./libass_plugin | Local iOS plugin for ASS/SSA subtitle rendering |

### Scraper Configuration — sources.json

```json
{
  "version": "1.0.0",
  "updated": "2026-08-09",
  "sources": [
    {"id": "flystream",     "name": "FlyStream",     "provider": "PlayTorrioHTTP", "script": "flystream.js"},
    {"id": "videasy",       "name": "Videasy",       "provider": "PlayTorrioHTTP", "script": "videasy.js"},
    {"id": "vidsrc",        "name": "VidSrc",        "provider": "PlayTorrioHTTP", "script": "vidsrc.js"},
    {"id": "multiembed",    "name": "MultiEmbed",    "provider": "PlayTorrioHTTP", "script": "multiembed.js"},
    {"id": "vidcore",       "name": "VidCore",       "provider": "PlayTorrioHTTP", "script": "vidcore.js"},
    {"id": "fourkhdhub",    "name": "4KHDHub",       "provider": "PlayTorrioHTTP", "script": "fourkhdhub.js"},
    {"id": "xdownloader",   "name": "XDownloader",   "provider": "PlayTorrioHTTP", "script": "xdownloader.js"},
    {"id": "knaben",        "name": "Knaben",        "provider": "PlayTorrio",     "script": "knaben.js"},
    {"id": "torrent_galaxy","name": "TorrentGalaxy", "provider": "PlayTorrio",     "script": "torrent_galaxy.js"}
  ]
}
```

### Glass Settings

```dart
// Toggle in Settings page — persisted to SharedPreferences
GlassSettings.enabled.value = true;   // Full liquid glass shaders
GlassSettings.enabled.value = false;  // Lightweight gradient fallback
```

### Launch Icons

The `flutter_launcher_icons` package generates app icons for all platforms from `assets/icon.png`. Configuration:

```yaml
flutter_launcher_icons:
  android: true
  ios: true
  windows:
    generate: true
    image_path: "assets/icon.png"
  image_path: "assets/icon.png"
  min_sdk_android: 21
```

<br/>
