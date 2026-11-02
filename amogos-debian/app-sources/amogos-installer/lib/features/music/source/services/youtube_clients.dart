// Adapted from the user's AmogOS Music project.
class YoutubeClientProfile {
  const YoutubeClientProfile({
    required this.label,
    required this.name,
    required this.version,
    required this.id,
    required this.agent,
    this.device = const {},
    this.musicEndpoint = true,
    this.signatureTimestamp = false,
    this.contextAgent = false,
    this.embedded = false,
    this.minimal = false,
  });
  final String label, name, version, id, agent;
  final Map<String, dynamic> device;
  final bool musicEndpoint, signatureTimestamp, contextAgent, embedded, minimal;
  String get host => musicEndpoint ? 'music.youtube.com' : 'www.youtube.com';
  String get key => '$name:$version:$label';

  Map<String, String> headers() => {
    'User-Agent': agent,
    'X-Youtube-Client-Name': id,
    'X-Youtube-Client-Version': version,
    'Origin': 'https://$host',
    'Referer': 'https://$host/',
    'Cookie': 'SOCS=CAI',
  };

  Map<String, dynamic> body(
    String videoId, {
    String? visitor,
    int? timestamp,
    String? webRemixVersion,
  }) => {
    'context': {
      'client': {
        'clientName': name,
        'clientVersion': name == 'WEB_REMIX'
            ? webRemixVersion ?? version
            : version,
        ...device,
        'hl': 'en',
        'gl': 'GB',
        if (visitor != null && !minimal) 'visitorData': visitor,
        if (contextAgent) 'userAgent': agent,
      },
      if (embedded) 'thirdParty': {'embedUrl': 'https://www.youtube.com/'},
    },
    'videoId': videoId,
    'contentCheckOk': true,
    'racyCheckOk': true,
    if (!musicEndpoint) 'videoCheckOk': true,
    if (signatureTimestamp || embedded)
      'playbackContext': {
        'contentPlaybackContext': {
          if (!musicEndpoint) 'html5Preference': 'HTML5_PREF_WANTS',
          if (timestamp != null && signatureTimestamp)
            'signatureTimestamp': timestamp,
        },
      },
  };
}

const _webAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/130.0.0.0 Safari/537.36';
const _safariAgent =
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 15_7_3) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Safari/605.1.15';
const _tvAgent =
    'Mozilla/5.0 (ChromiumStylePlatform) Cobalt/25.lts.30.1034943-gold';

const youtubePlaybackClients = <YoutubeClientProfile>[
  YoutubeClientProfile(
    label: 'VisionOS',
    name: 'VISIONOS',
    version: '1.02',
    id: '101',
    agent: _safariAgent,
    device: {
      'osName': 'visionOS',
      'osVersion': '26.5.23O471',
      'deviceMake': 'Apple',
      'deviceModel': 'RealityDevice17,1',
    },
  ),
  YoutubeClientProfile(
    label: 'VisionOS compatibility',
    name: 'VISIONOS',
    version: '0.1',
    id: '101',
    agent: _safariAgent,
    device: {
      'osName': 'VISION_OS',
      'osVersion': '1.3',
      'deviceMake': 'Apple',
      'deviceModel': 'RealityDevice14,1',
      'platform': 'MOBILE',
    },
  ),
  YoutubeClientProfile(
    label: 'YouTube Music Web',
    name: 'WEB_REMIX',
    version: '1.20260707.12.00',
    id: '67',
    agent: _webAgent,
    signatureTimestamp: true,
  ),
  YoutubeClientProfile(
    label: 'Android VR',
    name: 'ANDROID_VR',
    version: '1.65.10',
    id: '28',
    agent: 'com.google.android.apps.youtube.vr.oculus/1.65.10 (Linux; U; Android 12L; eureka-user Build/SQ3A.220605.009.A1) gzip',
    contextAgent: true,
    device: {
      'osName': 'Android',
      'osVersion': '12L',
      'deviceMake': 'Oculus',
      'deviceModel': 'Quest 3',
      'androidSdkVersion': '32',
    },
  ),
  YoutubeClientProfile(
    label: 'Android VR compatibility',
    name: 'ANDROID_VR',
    version: '1.61.48',
    id: '28',
    agent: 'com.google.android.apps.youtube.vr.oculus/1.61.48 (Linux; U; Android 12; en_US; Quest 3; Build/SQ3A.220605.009.A1; Cronet/132.0.6808.3)',
    contextAgent: true,
    device: {
      'osName': 'Android',
      'osVersion': '12',
      'deviceMake': 'Oculus',
      'deviceModel': 'Quest 3',
      'androidSdkVersion': '32',
    },
  ),
  YoutubeClientProfile(
    label: 'Android VR legacy',
    name: 'ANDROID_VR',
    version: '1.43.32',
    id: '28',
    agent: 'com.google.android.apps.youtube.vr.oculus/1.43.32 (Linux; U; Android 12; en_US; Quest 3; Build/SQ3A.220605.009.A1; Cronet/107.0.5284.2)',
    contextAgent: true,
    device: {
      'osName': 'Android',
      'osVersion': '12',
      'deviceMake': 'Oculus',
      'deviceModel': 'Quest 3',
      'androidSdkVersion': '32',
    },
  ),
  YoutubeClientProfile(
    label: 'iOS',
    name: 'IOS',
    version: '21.26.4',
    id: '5',
    agent: 'com.google.ios.youtube/21.26.4 (iPhone16,2; U; CPU iOS 18_3_2 like Mac OS X;)',
    contextAgent: true,
    device: {
      'osName': 'iPhone',
      'osVersion': '18.3.2.22D82',
      'deviceMake': 'Apple',
      'deviceModel': 'iPhone16,2',
    },
  ),
  YoutubeClientProfile(
    label: 'iOS compatibility',
    name: 'IOS',
    version: '20.10.4',
    id: '5',
    agent: _webAgent,
    minimal: true,
    device: {'deviceModel': 'iPhone16,2'},
  ),
  YoutubeClientProfile(
    label: 'Android Music',
    name: 'ANDROID_MUSIC',
    version: '5.34.51',
    id: '21',
    agent: 'com.google.android.apps.youtube.music/5.34.51 (Linux; U; Android 11) gzip',
    contextAgent: true,
    device: {'osName': 'Android', 'osVersion': '11', 'androidSdkVersion': '30'},
  ),
  YoutubeClientProfile(
    label: 'Android Music compatibility',
    name: 'ANDROID_MUSIC',
    version: '7.29.52',
    id: '21',
    agent: _webAgent,
    minimal: true,
    device: {'androidSdkVersion': 30},
  ),
  YoutubeClientProfile(
    label: 'Android',
    name: 'ANDROID',
    version: '21.26.364',
    id: '3',
    musicEndpoint: false,
    agent: 'com.google.android.youtube/21.26.364 (Linux; U; Android 11) gzip',
    contextAgent: true,
    device: {'osName': 'Android', 'osVersion': '11', 'androidSdkVersion': '30'},
  ),
  YoutubeClientProfile(
    label: 'Mobile Web',
    name: 'MWEB',
    version: '2.20260708.05.00',
    id: '2',
    musicEndpoint: false,
    agent: 'Mozilla/5.0 (iPad; CPU OS 16_7_10 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1,gzip(gfe)',
    contextAgent: true,
    signatureTimestamp: true,
  ),
  YoutubeClientProfile(
    label: 'Web Safari',
    name: 'WEB',
    version: '2.20260708.00.00',
    id: '1',
    musicEndpoint: false,
    agent: _safariAgent,
    signatureTimestamp: true,
  ),
  YoutubeClientProfile(
    label: 'TV',
    name: 'TVHTML5',
    version: '7.20260707.07.00',
    id: '7',
    musicEndpoint: false,
    agent: _tvAgent,
    signatureTimestamp: true,
    contextAgent: true,
  ),
  YoutubeClientProfile(
    label: 'TV embedded',
    name: 'TVHTML5_SIMPLY_EMBEDDED_PLAYER',
    version: '2.0',
    id: '85',
    musicEndpoint: false,
    agent: _tvAgent,
    signatureTimestamp: true,
    embedded: true,
  ),
];
