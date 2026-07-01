import 'dart:async';

import 'package:flutter_hbb/models/platform_model.dart';

import 'chat_db.dart';
import 'chat_models.dart';

const _kOperatorNameKey = 'gd-operator-name';

/// Singleton that intercepts upstream ChatModel events and persists them to SQLite.
/// Called from model.dart (incoming) and chat_model.dart (outgoing) after the
/// upstream in-memory model has already processed the message.
class GdChatPersister {
  GdChatPersister._();
  static final instance = GdChatPersister._();

  /// Returns the configured operator name, or empty string if unset.
  String get operatorName => bind.getLocalFlutterOption(k: _kOperatorNameKey);

  Future<void> setOperatorName(String name) async {
    await bind.setLocalFlutterOption(k: _kOperatorNameKey, v: name);
  }

  /// Persist an incoming message from [remoteId].
  void onReceived(String remoteId, String text) {
    if (remoteId.isEmpty || text.isEmpty) return;
    unawaited(
      GdChatDb.saveMessage(remoteId, GdChatDirection.incoming, '', text),
    );
  }

  /// Persist an outgoing message to [remoteId].
  void onSent(String remoteId, String text) {
    if (remoteId.isEmpty || text.isEmpty) return;
    final sender = operatorName;
    unawaited(
      GdChatDb.saveMessage(remoteId, GdChatDirection.outgoing, sender, text),
    );
  }
}
