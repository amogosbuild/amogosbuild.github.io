// Location, keyboard, and account pages collect validated configuration without logging passwords.
import 'package:flutter/material.dart';

import '../../../core/controllers/install_controller.dart';
import '../widgets/setup_widgets.dart';

class LocationPage extends StatelessWidget {
  const LocationPage({super.key, required this.controller});
  final InstallController controller;
  @override
  Widget build(BuildContext context) {
    final c = controller;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageIntro(
            eyebrow: 'A world of possibilities',
            title: 'Where do you call home?',
            description:
                'Let’s get your language and local time feeling familiar.',
          ),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const InfoLine(
                  icon: Icons.public_rounded,
                  title: 'Your corner of the world',
                  detail: 'Your time zone keeps the clock, calendar, and daylight saving in sync.',
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  initialValue: c.timezone,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Time zone',
                    prefixIcon: Icon(Icons.schedule_rounded),
                  ),
                  items: [
                    for (final z in [
                      'Europe/London',
                      'Europe/Paris',
                      'Europe/Berlin',
                      'Europe/Madrid',
                      'Europe/Rome',
                      'Europe/Warsaw',
                      'Europe/Kyiv',
                      'Europe/Istanbul',
                      'America/New_York',
                      'America/Chicago',
                      'America/Denver',
                      'America/Los_Angeles',
                      'America/Toronto',
                      'America/Sao_Paulo',
                      'Asia/Kolkata',
                      'Asia/Tokyo',
                      'Asia/Shanghai',
                      'Asia/Singapore',
                      'Asia/Dubai',
                      'Australia/Sydney',
                      'Pacific/Auckland',
                      'Africa/Johannesburg',
                      'Africa/Cairo',
                      'UTC',
                    ])
                      DropdownMenuItem(
                        value: z,
                        child: Text(
                          z.replaceAll('_', ' '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) => c.change(() => c.timezone = v!),
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  initialValue: c.locale,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'System language',
                    prefixIcon: Icon(Icons.translate_rounded),
                  ),
                  items: [
                    for (final l in [
                      ('en_GB.UTF-8', 'English (United Kingdom)'),
                      ('en_US.UTF-8', 'English (United States)'),
                      ('de_DE.UTF-8', 'Deutsch'),
                      ('fr_FR.UTF-8', 'Français'),
                      ('es_ES.UTF-8', 'Español'),
                      ('pt_BR.UTF-8', 'Português (Brasil)'),
                      ('pl_PL.UTF-8', 'Polski'),
                      ('ja_JP.UTF-8', '日本語'),
                    ])
                      DropdownMenuItem(
                        value: l.$1,
                        child: Text(
                          l.$2,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) => c.change(() => c.locale = v!),
                ),
                const SizedBox(height: 16),
                Text(
                  'These settings apply to your installed system. You can change them later.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class KeyboardPage extends StatelessWidget {
  const KeyboardPage({super.key, required this.controller});
  final InstallController controller;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PageIntro(
          eyebrow: 'Just your type',
          title: 'Make yourself understood.',
          description: 'Choose the layout that matches your keyboard, then give it a little test.',
        ),
        SurfaceCard(
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                initialValue: controller.keyboard,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Keyboard layout',
                  prefixIcon: Icon(Icons.keyboard_outlined),
                ),
                items: [
                  for (final l in [
                    ('gb', 'English (UK)'),
                    ('us', 'English (US)'),
                    ('de', 'German'),
                    ('fr', 'French'),
                    ('es', 'Spanish'),
                    ('it', 'Italian'),
                    ('br', 'Portuguese (Brazil)'),
                    ('pt', 'Portuguese'),
                    ('pl', 'Polish'),
                    ('jp', 'Japanese'),
                    ('in', 'Indian'),
                    ('tr', 'Turkish'),
                  ])
                    DropdownMenuItem(
                      value: l.$1,
                      child: Text(
                        l.$2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (v) =>
                    controller.change(() => controller.keyboard = v!),
              ),
              const SizedBox(height: 26),
              for (final row in [
                'Q W E R T Y U I O P',
                'A S D F G H J K L',
                'Z X C V B N M',
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (final letter in row.split(' '))
                          Container(
                            width: 42,
                            height: 40,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerLow,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Theme.of(context)
                                    .colorScheme
                                    .outlineVariant,
                              ),
                            ),
                            child: Text(
                              letter,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 22),
              const TextField(
                decoration: InputDecoration(
                  labelText: 'Try your keyboard here',
                  hintText: 'Hello, AmogOS 2 Pro! @ # £ €',
                  prefixIcon: Icon(Icons.edit_outlined),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'The test field uses your current live-session layout. The selected layout is saved for the installed system.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class AccountPage extends StatefulWidget {
  const AccountPage({super.key, required this.controller});
  final InstallController controller;
  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  bool reveal = false;
  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageIntro(
            eyebrow: 'A place with your name on it',
            title: 'Hello, you.',
            description: 'Create your account and give this computer a name.',
          ),
          SurfaceCard(
            child: Column(
              children: [
                AdaptiveFields(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: c.fullName,
                        onChanged: (v) => c.change(() => c.fullName = v),
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Your name',
                          hintText: 'Alex',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        initialValue: c.username,
                        onChanged: (v) => c.change(() => c.username = v),
                        decoration: const InputDecoration(
                          labelText: 'Username',
                          hintText: 'alex',
                          prefixIcon: Icon(Icons.alternate_email_rounded),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                TextFormField(
                  initialValue: c.hostname,
                  onChanged: (v) => c.change(() => c.hostname = v),
                  decoration: const InputDecoration(
                    labelText: 'Computer name',
                    prefixIcon: Icon(Icons.computer_rounded),
                  ),
                ),
                const SizedBox(height: 18),
                AdaptiveFields(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: c.password,
                        onChanged: (v) => c.change(() => c.password = v),
                        obscureText: !reveal,
                        enableSuggestions: false,
                        autocorrect: false,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          helperText: 'At least 8 characters',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            tooltip: reveal ? 'Hide password' : 'Show password',
                            onPressed: () => setState(() => reveal = !reveal),
                            icon: Icon(
                              reveal
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        initialValue: c.passwordAgain,
                        onChanged: (v) => c.change(() => c.passwordAgain = v),
                        obscureText: !reveal,
                        enableSuggestions: false,
                        autocorrect: false,
                        decoration: const InputDecoration(
                          labelText: 'Confirm password',
                          helperText: 'Type it once more',
                          prefixIcon: Icon(Icons.lock_outline_rounded),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Log in automatically',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    'Otherwise, you’ll use your password when this computer starts.',
                    style: TextStyle(fontSize: 11),
                  ),
                  value: c.autoLogin,
                  onChanged: (v) => c.change(() => c.autoLogin = v),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
