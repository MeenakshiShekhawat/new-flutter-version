class CdnConfig {
  static const String imageCdn = 'https://image.welfog.com/';
  static const String videoCdn = 'https://media.welfog.com/';

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
