import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:get/get.dart';

import '../cloud/cloud_controller.dart';
import 'models.dart';

/// GuDesk's own connect dialog — shown instead of RustDesk's generic one so
/// the password can be entered (and optionally remembered) up front, rather
/// than waiting on a round trip after the connection starts. Purely a
/// convenience for the *connecting* side: it never changes what happens on
/// the target device's own screen, which is still governed entirely by that
/// device's own local accept/approve setting.
Future<void> showConnectDialog(BuildContext context, GdDevice device) async {
  final passCtrl = TextEditingController(text: device.password);
  final canRemember = device.cloudId != null;
  var remember = canRemember && device.password.isNotEmpty;
  var obscure = true;

  final connected = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text('Connect to ${device.displayName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: passCtrl,
              autofocus: true,
              obscureText: obscure,
              decoration: InputDecoration(
                labelText: 'Password',
                hintText: 'Leave empty if unattended access isn\'t set up',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(obscure
                      ? CupertinoIcons.eye
                      : CupertinoIcons.eye_slash),
                  onPressed: () => setState(() => obscure = !obscure),
                ),
              ),
              onSubmitted: (_) => Navigator.pop(ctx, true),
            ),
            if (canRemember) ...[
              const SizedBox(height: 4),
              CheckboxListTile(
                value: remember,
                onChanged: (v) => setState(() => remember = v ?? false),
                title: const Text('Remember this password',
                    style: TextStyle(fontSize: 14)),
                subtitle: const Text(
                  'Saved to this org\'s directory — every team member sees it.',
                  style: TextStyle(fontSize: 12),
                ),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Connect'),
          ),
        ],
      ),
    ),
  );

  if (connected != true || !context.mounted) return;

  final password = passCtrl.text;
  await connect(
    context,
    device.remoteId,
    password: password.isEmpty ? null : password,
    isSharedPassword: password.isNotEmpty ? true : null,
  );

  if (remember && canRemember && password.isNotEmpty &&
      password != device.password &&
      Get.isRegistered<GdCloudController>(tag: GdCloudController.tag)) {
    await Get.find<GdCloudController>(tag: GdCloudController.tag)
        .updateContactPassword(device.cloudId!, password);
  }
}
