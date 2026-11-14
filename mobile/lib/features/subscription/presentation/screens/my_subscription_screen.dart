import 'package:flutter/material.dart';
import 'subscription_screen.dart';

/// Screen 02 — My Subscription Screen alias (`اشتراكي / عضويتي في نَصِيبُكَ`)
///
/// Under Google Play's consumption-only model, both new subscribers and active
/// members view their status, entitlement details, and refresh their membership
/// from the unified, policy-compliant `SubscriptionScreen`.
class MySubscriptionScreen extends StatelessWidget {
  const MySubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SubscriptionScreen();
  }
}
