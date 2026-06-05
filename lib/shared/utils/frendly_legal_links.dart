import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const frendlyLegalUrl = 'https://frendly.tech/legal';
const frendlyTermsUrl = 'https://frendly.tech/legal/terms';
const frendlyPrivacyUrl = 'https://frendly.tech/legal/privacy';
const frendlyCommunityRulesUrl = 'https://frendly.tech/legal/community-rules';

const frendlyLegalLaunchMode = LaunchMode.inAppBrowserView;

Future<bool> openFrendlyLegalUrl(String url) {
  return launchUrl(Uri.parse(url), mode: frendlyLegalLaunchMode);
}

Future<void> openFrendlyLegalUrlOrNotify(
  BuildContext context,
  String url,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final opened = await openFrendlyLegalUrl(url);
  if (opened) {
    return;
  }
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    const SnackBar(
      content: Text('Не удалось открыть ссылку.'),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
