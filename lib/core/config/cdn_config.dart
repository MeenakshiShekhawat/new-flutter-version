class CdnConfig {
  static const String imageCdn = 'https://d1f02fefkbso7w.cloudfront.net/';
  static const String videoCdn = 'https://d2plk5mvjwgdxq.cloudfront.net/';

  static String getImageUrl(String? path) {
    if (path == null || path.trim().isEmpty) return '';
    final trimmed = path.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    final normalized = trimmed.startsWith('/') ? trimmed.substring(1) : trimmed;
    return '$imageCdn$normalized';
  }

  static String getVideoUrl(String? videoLink) {
    if (videoLink == null || videoLink.trim().isEmpty) return '';
    return '${videoCdn}videos/reels/$videoLink/master.m3u8';
  }
}
