// Placeholder so the project compiles before Firebase is configured.
//
// Run `flutterfire configure` from the project root (see README.md). It
// overwrites this file with the options for your own Firebase project.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    throw UnsupportedError(
      'Firebase is not configured yet. Run `flutterfire configure` to generate lib/firebase_options.dart.',
    );
  }
}
