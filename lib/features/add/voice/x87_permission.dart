// P24 (SCREENS X87; SPEC 8.19; flow F04 step 1): the microphone explainer.
//
// The dialog explains what the microphone does before the system prompt: it
// listens only while active, the text is made on this phone, and no audio is
// saved or sent. "Not now" keeps typed entry (F04-B).
library;

import 'package:flutter/widgets.dart';

import '../../../design/design.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Shows X87 and returns true when the person chooses "Allow microphone".
Future<bool> showMicrophonePermission(BuildContext context) async {
  final l = AppLocalizations.of(context);
  final body = <String>[
    l.voicePermissionLineListen,
    l.voicePermissionLineOnDevice,
    l.voicePermissionLineNoAudio,
  ].join('\n\n');
  final allowed = await showAppDialog<bool>(
    context,
    leading: const IconTile(icon: AppIcons.mic),
    title: l.voicePermissionTitle,
    body: body,
    primaryLabel: l.voicePermissionAllow,
    secondaryLabel: l.voicePermissionNotNow,
    semanticLabel: l.voicePermissionTitle,
    onPrimary: () => Navigator.of(context).pop(true),
    onSecondary: () => Navigator.of(context).pop(false),
  );
  return allowed ?? false;
}
