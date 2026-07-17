import 'dart:async';

import 'package:drift/drift.dart';

/// Global test bootstrap. Tests create a fresh in-memory [AppDatabase] per case
/// (see individual `setUp`s), which trips drift's multiple-instances debug
/// warning; silence it so it doesn't spam the test output.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  await testMain();
}
