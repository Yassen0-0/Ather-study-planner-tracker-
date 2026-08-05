import 'package:flutter/material.dart';

/// Whether the platform has asked for reduced motion.
///
/// Checked before every non-trivial animation. Vestibular disorders are real,
/// and a celebration that cannot be turned off is a bug, not a delight.
bool prefersReducedMotion(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;
