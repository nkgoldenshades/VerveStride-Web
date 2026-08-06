import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../core/app_theme.dart';

class ReportBugScreen extends StatefulWidget {
  const ReportBugScreen({super.key});

  @override
  State<ReportBugScreen> createState() => _ReportBugScreenState();
}

class _ReportBugScreenState extends State<ReportBugScreen> {
  static const String _supportEmail = 'vervestride.app@gmail.com';
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _share() async {
    final title = _titleCtrl.text.trim();
    final desc = _descCtrl.text.trim();

    final payload = StringBuffer()
      ..writeln('VerveStride - Bug Report')
      ..writeln('')
      ..writeln('Contact: $_supportEmail')
      ..writeln('')
      ..writeln('Title: ${title.isEmpty ? '(no title)' : title}')
      ..writeln('')
      ..writeln('Description:')
      ..writeln(desc.isEmpty ? '(no description)' : desc);

    await Share.share(payload.toString());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report a bug'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.25),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.email_outlined, size: 18),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      _supportEmail,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      await Clipboard.setData(
                        const ClipboardData(text: _supportEmail),
                      );
                      if (!mounted) return;
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Email copied')),
                      );
                    },
                    child: const Text('Copy'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'Short summary',
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                controller: _descCtrl,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  labelText: 'What happened?',
                  hintText:
                      'Steps to reproduce, what you expected, what you saw...',
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _share,
                child: const Text('Share bug report'),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Send the details to the email above. Tip: include what screen you were on and what you tapped.',
              style: TextStyle(
                color: AppColors.textSecondary.withOpacity(0.9),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
