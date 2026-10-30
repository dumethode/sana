import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/data/user_repository.dart';
import 'features/incidents/data/incident_repository.dart';
import 'features/incidents/data/photo_storage.dart';
import 'firebase_options.dart';

/// Logs every state change in debug builds. Handy while demoing how one
/// Firestore snapshot updates several blocs at once.
class _DebugObserver extends BlocObserver {
  @override
  void onChange(BlocBase<dynamic> bloc, Change<dynamic> change) {
    super.onChange(bloc, change);
    if (kDebugMode) debugPrint('[${bloc.runtimeType}] ${change.nextState.runtimeType}');
  }

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    debugPrint('[${bloc.runtimeType}] error: $error');
    super.onError(bloc, error, stackTrace);
  }
}

/// Initialises Firebase, local persistence and dependencies, then runs the app.
Future<void> bootstrap() async {
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

    // Offline cache: reads come from disk when Wi-Fi drops, and writes are
    // queued and replayed on reconnect.
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: 50 * 1024 * 1024,
    );

    HydratedBloc.storage = await HydratedStorage.build(
      storageDirectory: HydratedStorageDirectory((await getApplicationSupportDirectory()).path),
    );

    Bloc.observer = _DebugObserver();

    final users = UserRepository();
    final auth = AuthRepository(users: users);
    final incidents = IncidentRepository(photos: PhotoStorage());

    runApp(SanaApp(authRepository: auth, userRepository: users, incidentRepository: incidents));
  }, (error, stack) {
    debugPrint('Uncaught error: $error\n$stack');
  });
}
