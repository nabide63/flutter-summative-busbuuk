// Launches the device dialer with a tel: URI - shared by the passenger's
// "call the operator" ticket action and the onboarder's "call the client" flow.
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> launchPhoneCall(BuildContext context, String phoneNumber) async {
  final uri = Uri(scheme: 'tel', path: phoneNumber);
  final launched = await launchUrl(uri);

  if (!launched && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('could not start a call to $phoneNumber')),
    );
  }
}