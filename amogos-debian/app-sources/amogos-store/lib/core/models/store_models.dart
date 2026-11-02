// Typed catalog entries and queue records preserve the selected package source.
enum StorePage { home, categories, updates, sources, fresh, installed }

const pageLabels = [
  'Home',
  'Categories',
  'Updates',
  'Sources',
  'New',
  'Installed',
];
const sourceLabels = {
  'all': 'All',
  'deb': 'APT',
  'flatpak': 'Flatpak',
  'appimage': 'AppImage',
};
const categoryLabels = {
  'AudioVideo': 'Audio & video',
  'Game': 'Games',
  'Graphics': 'Graphics & photography',
  'Network': 'Internet & communication',
  'Office': 'Office & writing',
  'Development': 'Development',
  'Utility': 'Utilities',
  'Education': 'Education & science',
};

class StorePackage {
  StorePackage(Map<String, dynamic> value) : data = Map.of(value);
  final Map<String, dynamic> data;
  String get id => data['id']?.toString() ?? '';
  String get source => data['source'] ?? 'deb';
  String get repo => data['repo'] ?? '';
  String get name => data['name'] ?? id;
  String get summary => data['summary'] ?? '';
  String get description => data['description'] ?? summary;
  String get version => data['version']?.toString() ?? '';
  String get icon => data['icon'] ?? '';
  String get iconId => data['iconId'] ?? id;
  String get homepage => data['homepage'] ?? '';
  String get license => data['license'] ?? '';
  bool get installed => data['installed'] == true;
  bool get updatable => data['updatable'] == true;
  List<String> get categories => List<String>.from(data['categories'] ?? []);
  List<String> get screenshots => List<String>.from(data['screenshots'] ?? []);
  List<Map<String, dynamic>> get downloads => [
    for (final v in data['downloads'] ?? []) Map<String, dynamic>.from(v),
  ];
  bool get runtime => data['runtime'] == true;
  String get scope => data['scope'] ?? 'system';
  String get key =>
      '$source:$id:$repo${data['scope'] == null ? '' : ':$scope:${data['reference'] ?? ''}'}';
  Map<String, dynamic> get request => {
    'id': id,
    'source': source,
    'repo': repo,
    if (source == 'flatpak') 'scope': scope,
    if (data['reference'] != null) 'reference': data['reference'],
  };
}

enum JobStatus { queued, preparing, running, completed, failed, removed }

class StoreNotification {
  const StoreNotification(this.message, this.id, {this.showQueue = false});
  final String message;
  final int id;
  final bool showQueue;
}

class StoreJob {
  StoreJob({
    required this.title,
    required this.source,
    required this.operation,
    required this.request,
    required this.review,
  });
  final String title, source, operation;
  final Map<String, dynamic> request, review;
  String? transactionId;
  bool recovered = false;
  JobStatus status = JobStatus.queued;
  String message = 'Waiting in the queue';
  double? progress;
  final List<String> log = [];
  bool get pending => status == JobStatus.queued;
  bool get active =>
      status == JobStatus.preparing || status == JobStatus.running;
  String get activity => operation == 'remove'
      ? 'Uninstalling'
      : operation.startsWith('repair')
      ? 'Repairing'
      : source == 'refresh'
      ? 'Refreshing indexes'
      : operation.startsWith('update') || operation == 'upgrade-system'
      ? 'Updating'
      : 'Installing';
}

String byteSize(num? bytes) {
  if (bytes == null || bytes == 0) return 'Calculated during install';
  final absolute = bytes.abs();
  if (absolute >= 1073741824) {
    return '${(bytes / 1073741824).toStringAsFixed(1)} GB';
  }
  if (absolute >= 1048576) return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  return '${(bytes / 1024).toStringAsFixed(0)} KB';
}
