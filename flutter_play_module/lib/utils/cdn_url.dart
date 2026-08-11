/// Product/media CDN — matches RN `CDN_BASE_URL` in constants/urlconstants.ts
const kCdnBaseUrl = 'https://d1f02fefkbso7w.cloudfront.net';

/// Video/reels CDN base URL
const kVideoCdnUrl = 'https://d2plk5mvjwgdxq.cloudfront.net';

// https://media.welfog.com/
// https://image.welfog.com/
/// Builds a full CDN URL from a relative path like `1116/1116-020626-830061.webp`.
String cdnImageUrl(String? path) {
  if (path == null || path.isEmpty) return '';
  final trimmed = path.trim();
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return trimmed;
  }
  final normalized = trimmed.startsWith('/') ? trimmed.substring(1) : trimmed;
  return '$kCdnBaseUrl/$normalized';
}

/// Builds a full reels video master.m3u8 URL from a video link path.
String cdnVideoUrl(String? videoLink) {
  if (videoLink == null || videoLink.trim().isEmpty) return '';
  final trimmed = videoLink.trim();
  if (trimmed.startsWith('http')) return trimmed;
  return '$kVideoCdnUrl/videos/reels/$trimmed/master.m3u8';
}
