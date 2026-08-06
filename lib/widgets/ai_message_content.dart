import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import '../core/app_theme.dart';
import '../models/conversation_thread.dart';

/// Renders AI message content with markdown support and media (images, videos, audio).
/// Code blocks get syntax highlighting + a copy button — just like ChatGPT.
class AIMessageContent extends StatelessWidget {
  final String content;
  final bool isUser;
  final ChatMessage? message; // Pass full message for media access

  const AIMessageContent({
    super.key,
    required this.content,
    required this.isUser,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Display user-attached images (like Gemini/ChatGPT)
        if (message?.attachedImages != null && message!.attachedImages!.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: message!.attachedImages!.map((base64Image) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  base64Decode(base64Image),
                  fit: BoxFit.cover,
                  height: 150,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
        ],
        
        // Display generated image if present
        if (message?.imageBase64 != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              base64Decode(message!.imageBase64!),
              fit: BoxFit.cover,
              width: double.infinity,
            ),
          ),
          const SizedBox(height: 8),
        ],
        
        // Display video if present
        if (message?.videoUrl != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.video_library, color: AppColors.primary, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Generated Video',
                          style: TextStyle(color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text(message!.videoUrl!,
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        
        // Display audio if present
        if (message?.audioUrl != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orangeAccent.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.music_note, color: Colors.orangeAccent, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Generated Audio',
                          style: TextStyle(color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text(message!.audioUrl!,
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        
        // Text content
        if (isUser)
          Text(
            content,
            style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
          )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: double.infinity),
            child: MarkdownBody(
              data: content,
              selectable: true,
              softLineBreak: true,
              styleSheet: _markdownStyle(),
              builders: {
                'code': _CodeBlockBuilder(),
              },
              onTapLink: (text, href, title) {
                // Handle link taps if needed
              },
            ),
          ),
      ],
    );
  }

  MarkdownStyleSheet _markdownStyle() {
    return MarkdownStyleSheet(
      p: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 14,
        height: 1.6,
      ),
      strong: const TextStyle(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.bold,
        fontSize: 14,
      ),
      em: const TextStyle(
        color: AppColors.textPrimary,
        fontStyle: FontStyle.italic,
        fontSize: 14,
      ),
      h1: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.bold,
        height: 1.4,
      ),
      h2: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.bold,
        height: 1.4,
      ),
      h3: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.bold,
        height: 1.4,
      ),
      listBullet: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      blockquoteDecoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(4),
        border: Border(
          left: BorderSide(color: AppColors.primary, width: 3),
        ),
      ),
      blockquotePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      blockquote: TextStyle(
        color: AppColors.textSecondary,
        fontSize: 14,
        fontStyle: FontStyle.italic,
      ),
      // Inline code style
      code: TextStyle(
        color: AppColors.secondary,
        backgroundColor: AppColors.card,
        fontSize: 13,
        fontFamily: 'monospace',
      ),
      codeblockDecoration: const BoxDecoration(), // handled by custom builder
      horizontalRuleDecoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.divider, width: 1),
        ),
      ),
    );
  }
}

/// Custom builder that renders fenced code blocks with:
/// - Dark background
/// - Language label
/// - Syntax highlighting
/// - Copy button
class _CodeBlockBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(element, TextStyle? preferredStyle) {
    final code = element.textContent;
    // Extract language from class like "language-dart"
    final rawLang = element.attributes['class'] ?? '';
    final language = rawLang.replaceFirst('language-', '').trim();

    return _CodeBlock(code: code, language: language.isEmpty ? null : language);
  }
}

class _CodeBlock extends StatefulWidget {
  final String code;
  final String? language;

  const _CodeBlock({required this.code, this.language});

  @override
  State<_CodeBlock> createState() => _CodeBlockState();
}

class _CodeBlockState extends State<_CodeBlock> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.code.trim()));
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B2A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Minimal header: language + copy only
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(
              children: [
                if (widget.language != null)
                  Text(
                    widget.language!,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                const Spacer(),
                GestureDetector(
                  onTap: _copy,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _copied
                        ? Row(
                            key: const ValueKey('copied'),
                            children: [
                              const Icon(Icons.check, size: 13, color: Colors.greenAccent),
                              const SizedBox(width: 4),
                              Text('Copied!',
                                  style: TextStyle(color: Colors.greenAccent, fontSize: 11)),
                            ],
                          )
                        : Row(
                            key: const ValueKey('copy'),
                            children: [
                              Icon(Icons.copy, size: 13, color: AppColors.textSecondary),
                              const SizedBox(width: 4),
                              Text('Copy',
                                  style: TextStyle(
                                      color: AppColors.textSecondary, fontSize: 11)),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),

          // Code with syntax highlighting
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
            child: HighlightView(
              widget.code.trim(),
              language: widget.language ?? 'plaintext',
              theme: atomOneDarkTheme,
              padding: EdgeInsets.zero,
              textStyle: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
