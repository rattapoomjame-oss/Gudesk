import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'cloud_controller.dart';

class GdRegisterPage extends StatefulWidget {
  const GdRegisterPage({super.key});

  @override
  State<GdRegisterPage> createState() => _GdRegisterPageState();
}

class _GdRegisterPageState extends State<GdRegisterPage> {
  final _formKey      = GlobalKey<FormState>();
  final _urlCtrl      = TextEditingController();
  final _orgNameCtrl  = TextEditingController();
  final _orgSlugCtrl  = TextEditingController();
  final _nameCtrl     = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _passCtrl     = TextEditingController();
  bool  _loading      = false;
  bool  _obscure      = true;
  String? _error;

  // Auto-fill slug from org name
  void _onOrgNameChanged(String value) {
    final slug = value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    _orgSlugCtrl.text = slug;
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _orgNameCtrl.dispose();
    _orgSlugCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  GdCloudController get _ctrl =>
      Get.find<GdCloudController>(tag: GdCloudController.tag);

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    final err = await _ctrl.registerOrg(
      cloudUrl: _urlCtrl.text.trim(),
      orgName:  _orgNameCtrl.text.trim(),
      orgSlug:  _orgSlugCtrl.text.trim(),
      email:    _emailCtrl.text.trim(),
      password: _passCtrl.text,
      name:     _nameCtrl.text.trim(),
    );

    if (!mounted) return;
    if (err == null) {
      // Pop both register and login pages back to directory
      Navigator.of(context).popUntil((r) => r.isFirst);
    } else {
      setState(() { _loading = false; _error = err; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Organization'),
        centerTitle: false,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Set up your team',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'The account you create here becomes the organization admin.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 24),

                  // Server URL
                  TextFormField(
                    controller: _urlCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Server URL',
                      hintText: 'https://cloud.example.com',
                      prefixIcon: Icon(Icons.dns_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      if (!v.trim().startsWith('http')) return 'Must start with http/https';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Org name
                  TextFormField(
                    controller: _orgNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Organization Name',
                      hintText: 'My Company',
                      prefixIcon: Icon(Icons.business_outlined),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: _onOrgNameChanged,
                    validator: (v) {
                      if (v == null || v.trim().length < 2) return 'At least 2 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Org slug
                  TextFormField(
                    controller: _orgSlugCtrl,
                    decoration: const InputDecoration(
                      labelText: 'URL Slug',
                      hintText: 'my-company',
                      helperText: 'Letters and numbers only, used in URLs',
                      prefixIcon: Icon(Icons.link_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().length < 2) return 'At least 2 characters';
                      if (!RegExp(r'^[a-z0-9-]+$').hasMatch(v.trim())) {
                        return 'Lowercase letters, numbers, and hyphens only';
                      }
                      return null;
                    },
                  ),
                  const Divider(height: 32),

                  Text('Your account', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 12),

                  // Full name
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: Icon(Icons.person_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),

                  // Email
                  TextFormField(
                    controller: _emailCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      if (!v.contains('@')) return 'Enter a valid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Password
                  TextFormField(
                    controller: _passCtrl,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      helperText: 'Minimum 10 characters',
                      prefixIcon: const Icon(Icons.lock_outlined),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (v.length < 10) return 'At least 10 characters';
                      return null;
                    },
                  ),

                  // Error
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cs.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(children: [
                        Icon(Icons.error_outline, color: cs.error, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_error!,
                              style: TextStyle(color: cs.onErrorContainer)),
                        ),
                      ]),
                    ),
                  ],

                  const SizedBox(height: 24),

                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            height: 20, width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Create Organization'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
