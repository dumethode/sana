import 'package:intl/intl.dart';

/// Human-friendly time strings used across tickets, timelines and stats.
abstract final class TimeFormat {
  static String relative(DateTime time, {DateTime? now}) {
    final diff = (now ?? DateTime.now()).difference(time);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('d MMM').format(time);
  }

  static String stamp(DateTime time) => DateFormat('d MMM yyyy, HH:mm').format(time);

  /// Compact duration for stats, e.g. "3h", "2d 4h".
  static String duration(Duration d) {
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    final hours = d.inHours % 24;
    return hours == 0 ? '${d.inDays}d' : '${d.inDays}d ${hours}h';
  }
}
