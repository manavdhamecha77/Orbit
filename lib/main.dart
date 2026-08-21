import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import 'services/llm_service.dart';

void main() => runApp(const OrbitApp());

class OrbitApp extends StatefulWidget {
  const OrbitApp({super.key});

  @override
  State<OrbitApp> createState() => _OrbitAppState();
}

class _OrbitAppState extends State<OrbitApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark
          ? ThemeMode.light
          : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Orbit',
      themeMode: _themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFE5ECF2),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF1E2D3D),
          surface: Color(0xFFF1F5F9),
          onSurface: Color(0xFF1E2D3D),
          onPrimary: Color(0xFFFFFFFF),
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0C1015),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF8BA2B8),
          surface: Color(0xFF151C26),
          onSurface: Color(0xFFE6EDF3),
          onPrimary: Color(0xFF0C1015),
        ),
      ),
      home: ChatScreen(onThemeToggle: _toggleTheme),
    );
  }
}

class Message {
  String text;
  final bool isUser;
  Message({required this.text, required this.isUser});
}

class ChatScreen extends StatefulWidget {
  final VoidCallback onThemeToggle;
  const ChatScreen({super.key, required this.onThemeToggle});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController controller = TextEditingController();
  final ScrollController scrollController = ScrollController();
  final LlmService llmService = LlmService();
  final List<Message> messages = <Message>[];
  String status = 'Loading';
  bool generating = false;
  String activeModelName = 'No model loaded';

  @override
  void initState() {
    super.initState();
    controller.addListener(_onTextChanged);
    loadModel();
  }

  void _onTextChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    controller.removeListener(_onTextChanged);
    controller.dispose();
    scrollController.dispose();
    super.dispose();
  }

  Future<void> loadModel() async {
    try {
      final modelName = await llmService.initialize();
      if (mounted) {
        setState(() {
          status = 'Ready';
          activeModelName = modelName;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          status = 'Select model';
          activeModelName = 'No model loaded';
        });
      }
    }
  }

  Future<void> selectModel() async {
    setState(() => status = 'Loading');
    try {
      final modelName = await llmService.pickModel();
      if (mounted) {
        setState(() {
          status = 'Ready';
          activeModelName = modelName;
        });
      }
    } catch (e) {
      if (mounted) setState(() => status = 'Select model');
    }
  }

  void scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> sendMessage() async {
    final text = controller.text.trim();
    if (text.isEmpty || generating || status != 'Ready') return;
    setState(() {
      generating = true;
      status = 'Generating';
      controller.clear();
      messages.add(Message(text: text, isUser: true));
      messages.add(Message(text: '', isUser: false));
    });
    scrollToBottom();

    try {
      await for (final chunk in llmService.generate(text)) {
        if (mounted) {
          setState(() => messages.last.text += chunk);
          scrollToBottom();
        }
      }
      if (mounted) setState(() => status = 'Ready');
    } catch (e) {
      if (mounted) {
        setState(() {
          status = 'Error: $e';
          messages.last.text = 'I could not generate a response.';
        });
      }
    } finally {
      if (mounted) setState(() => generating = false);
    }
  }

  Future<void> stopGeneration() async {
    await llmService.stopGeneration();
    if (mounted) {
      setState(() {
        generating = false;
        status = 'Ready';
      });
    }
  }

  void showModelModal() {
    final isLight = Theme.of(context).brightness == Brightness.light;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) {
        return ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Container(
              decoration: BoxDecoration(
                color: isLight
                    ? Colors.white.withValues(alpha: 0.68)
                    : const Color(0xFF1A232E).withValues(alpha: 0.72),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                border: Border.all(
                  color: isLight
                      ? Colors.white.withValues(alpha: 0.72)
                      : Colors.white.withValues(alpha: 0.12),
                  width: 1.0,
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Local AI Model',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: isLight
                              ? const Color(0xFF1E2D3D)
                              : const Color(0xFFE6EDF3),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isLight
                              ? Colors.black.withValues(alpha: 0.03)
                              : Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isLight
                                ? Colors.black.withValues(alpha: 0.06)
                                : Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Active Model',
                              style: TextStyle(
                                fontSize: 12,
                                color: isLight
                                    ? const Color(0xFF5C6B7B)
                                    : const Color(0xFF7A8B9C),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              activeModelName,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: isLight
                                    ? const Color(0xFF1E2D3D)
                                    : const Color(0xFFE2EAF1),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: isLight
                                    ? const Color(0xFF1E2D3D)
                                    : const Color(0xFFC0CDDB),
                                side: BorderSide(
                                  color: isLight
                                      ? Colors.black.withValues(alpha: 0.12)
                                      : Colors.white.withValues(alpha: 0.12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text('Close'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: () {
                                Navigator.pop(context);
                                selectModel();
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: isLight
                                    ? const Color(0xFF1E2D3D)
                                    : const Color(0xFFE2E9F0),
                                foregroundColor: isLight
                                    ? const Color(0xFFFFFFFF)
                                    : const Color(0xFF131922),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text('Change Model'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String get statusLabel => status.startsWith('Error') ? 'Error' : status;

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final isReady = status == 'Ready';
    final hasText = controller.text.trim().isNotEmpty;
    final canSend = isReady && !generating && hasText;

    final primaryTextColor = isLight
        ? const Color(0xFF1E2D3D)
        : const Color(0xFFE6EDF3);
    final secondaryTextColor = isLight
        ? const Color(0xFF5C6B7B)
        : const Color(0xFF7A8B9C);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leadingWidth: 52,
        titleSpacing: 8,
        leading: IconButton(
          onPressed: widget.onThemeToggle,
          icon: Icon(
            isLight ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
            color: secondaryTextColor,
            size: 20,
          ),
          tooltip: isLight ? 'Switch to dark theme' : 'Switch to light theme',
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Orbit',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: primaryTextColor,
                letterSpacing: -0.2,
              ),
            ),
            Text(
              'Private · runs on your phone',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: secondaryTextColor,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 18, left: 6),
            child: Center(
              child: _StatusPill(
                label: statusLabel,
                generating: generating,
                onTap: showModelModal,
              ),
            ),
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0.0, -0.35),
            radius: 1.25,
            colors: isLight
                ? const [
                    Color(0xFFF4F7FA), // Soft light center
                    Color(0xFFE5ECF2), // Intermediate light
                    Color(0xFFD6DFE8), // Darker edge light
                  ]
                : const [
                    Color(0xFF1B2430), // Soft blue-gray dark center
                    Color(0xFF131922),
                    Color(0xFF0B0E13),
                  ],
            stops: const [0.0, 0.55, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Message list or Welcome screen
              Expanded(
                child: messages.isEmpty
                    ? _Welcome(ready: isReady, onSelectModel: selectModel)
                    : SelectionArea(
                        child: ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
                          itemCount: messages.length,
                          itemBuilder: (context, index) =>
                              _MessageBubble(message: messages[index]),
                        ),
                      ),
              ),

              // Single-Line Glassmorphism Chat Box
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                child: _FrostedChatBox(
                  controller: controller,
                  enabled: isReady || generating,
                  canSend: canSend,
                  generating: generating,
                  onSend: sendMessage,
                  onStop: stopGeneration,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FrostedChatBox extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final bool canSend;
  final bool generating;
  final VoidCallback onSend;
  final VoidCallback onStop;

  const _FrostedChatBox({
    required this.controller,
    required this.enabled,
    required this.canSend,
    required this.generating,
    required this.onSend,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: isLight
                ? const Color(0xFF334A63).withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.35),
            blurRadius: 24,
            spreadRadius: 0,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: const Color(0xFF3B4E63).withValues(alpha: 0.12),
            blurRadius: 16,
            spreadRadius: -2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
            decoration: BoxDecoration(
              color: isLight
                  ? const Color(0xFFFFFFFF).withValues(alpha: 0.75)
                  : const Color(0xFF1E2836).withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isLight
                    ? const Color(0xFF000000).withValues(alpha: 0.08)
                    : Colors.white.withValues(alpha: 0.12),
                width: 1.0,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    enabled: enabled && !generating,
                    maxLines: 1,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) {
                      if (canSend) onSend();
                    },
                    style: TextStyle(
                      color: isLight
                          ? const Color(0xFF1F2E3D)
                          : const Color(0xFFE6EDF3),
                      fontSize: 15,
                      height: 1.4,
                    ),
                    cursorColor: isLight
                        ? const Color(0xFF1E2D3D)
                        : const Color(0xFFA0B3C6),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Ask me anything...',
                      hintStyle: TextStyle(
                        color: isLight
                            ? const Color(0xFF7A8B9C)
                            : const Color(0xFF788899),
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _CircularActionButton(
                  canSend: canSend,
                  generating: generating,
                  onSend: onSend,
                  onStop: onStop,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CircularActionButton extends StatelessWidget {
  final bool canSend;
  final bool generating;
  final VoidCallback onSend;
  final VoidCallback onStop;

  const _CircularActionButton({
    required this.canSend,
    required this.generating,
    required this.onSend,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;

    final activeBg = isLight
        ? const Color(0xFF1E2D3D)
        : const Color(0xFFDDE5ED);
    final disabledBg = isLight
        ? const Color(0xFF000000).withValues(alpha: 0.05)
        : Colors.white.withValues(alpha: 0.08);

    final showStop = generating;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: showStop ? onStop : (canSend ? onSend : null),
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: (showStop || canSend) ? activeBg : disabledBg,
            border: Border.all(
              color: (showStop || canSend)
                  ? (isLight
                        ? Colors.black.withValues(alpha: 0.1)
                        : Colors.white.withValues(alpha: 0.3))
                  : (isLight
                        ? Colors.black.withValues(alpha: 0.04)
                        : Colors.white.withValues(alpha: 0.08)),
              width: 1,
            ),
            boxShadow: (showStop || canSend)
                ? [
                    BoxShadow(
                      color: isLight
                          ? const Color(0xFF1E2D3D).withValues(alpha: 0.15)
                          : const Color(0xFFB0C4DE).withValues(alpha: 0.25),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: showStop
                ? Icon(
                    Icons.stop_rounded,
                    size: 20,
                    color: isLight
                        ? const Color(0xFFFFFFFF)
                        : const Color(0xFF121922),
                  )
                : Icon(
                    Icons.arrow_upward_rounded,
                    size: 20,
                    color: canSend
                        ? (isLight
                              ? const Color(0xFFFFFFFF)
                              : const Color(0xFF121922))
                        : (isLight
                              ? const Color(0xFF7A8B9C)
                              : const Color(0xFF637383)),
                  ),
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final bool generating;
  final VoidCallback? onTap;

  const _StatusPill({
    required this.label,
    required this.generating,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final dotColor = label == 'Error'
        ? const Color(0xFFE27373)
        : label == 'Ready'
        ? const Color(0xFF6BCA98)
        : const Color(0xFFDFB668);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isLight
              ? Colors.black.withValues(alpha: 0.03)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isLight
                ? Colors.black.withValues(alpha: 0.06)
                : Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (generating)
              const Padding(
                padding: EdgeInsets.only(right: 6),
                child: SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.8,
                    color: Color(0xFFDFB668),
                  ),
                ),
              )
            else
              Container(
                width: 7,
                height: 7,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dotColor,
                  boxShadow: [
                    BoxShadow(
                      color: dotColor.withValues(alpha: 0.45),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            Text(
              label,
              style: TextStyle(
                color: isLight
                    ? const Color(0xFF5C6B7B)
                    : const Color(0xFFC2CFDB),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Welcome extends StatelessWidget {
  final bool ready;
  final VoidCallback onSelectModel;

  const _Welcome({required this.ready, required this.onSelectModel});

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Your private AI companion',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: isLight
                    ? const Color(0xFF1E2D3D)
                    : const Color(0xFFE6EDF3),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              ready
                  ? 'Ask a question to start a completely offline conversation.'
                  : 'Choose a GGUF model stored on your phone to begin.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isLight
                    ? const Color(0xFF5C6B7B)
                    : const Color(0xFF7E8F9F),
                fontSize: 14,
                height: 1.4,
              ),
            ),
            if (!ready) ...[
              const SizedBox(height: 24),
              GestureDetector(
                onTap: onSelectModel,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: isLight
                        ? const Color(0xFFFFFFFF).withValues(alpha: 0.8)
                        : const Color(0xFF222E3D).withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isLight
                          ? Colors.black.withValues(alpha: 0.08)
                          : Colors.white.withValues(alpha: 0.12),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.folder_open_rounded,
                        size: 18,
                        color: isLight
                            ? const Color(0xFF1E2D3D)
                            : const Color(0xFFBDCCD9),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Select GGUF model',
                        style: TextStyle(
                          color: isLight
                              ? const Color(0xFF1E2D3D)
                              : const Color(0xFFE2EAF1),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Message message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: message.isUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            constraints: const BoxConstraints(maxWidth: 580),
            margin: const EdgeInsets.symmetric(vertical: 5),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: message.isUser
                  ? (isLight
                        ? const Color(0xFFD4E3F3).withValues(alpha: 0.9)
                        : const Color(0xFF2A3748).withValues(alpha: 0.85))
                  : (isLight
                        ? const Color(0xFFF1F5F9).withValues(alpha: 0.95)
                        : const Color(0xFF18222D).withValues(alpha: 0.7)),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(message.isUser ? 18 : 4),
                bottomRight: Radius.circular(message.isUser ? 4 : 18),
              ),
              border: Border.all(
                color: message.isUser
                    ? (isLight
                          ? const Color(0xFF2B3A4C).withValues(alpha: 0.08)
                          : Colors.white.withValues(alpha: 0.12))
                    : (isLight
                          ? const Color(0xFF1E2D3B).withValues(alpha: 0.06)
                          : Colors.white.withValues(alpha: 0.07)),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.16),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: GptMarkdown(
              message.text.isEmpty ? '…' : message.text,
              style: TextStyle(
                color: message.isUser
                    ? (isLight
                          ? const Color(0xFF1F2E3D)
                          : const Color(0xFFF0F4F8))
                    : (isLight
                          ? const Color(0xFF253342)
                          : const Color(0xFFD3DDE6)),
                fontSize: 14.5,
              ),
            ),
          ),
          if (!message.isUser && message.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 6, bottom: 6),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: message.text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Copied to clipboard',
                          style: TextStyle(
                            color: isLight
                                ? const Color(0xFF1F2E3D)
                                : const Color(0xFFE6EDF3),
                            fontSize: 13,
                          ),
                        ),
                        backgroundColor: isLight
                            ? const Color(0xFFE5ECF2)
                            : const Color(0xFF1E2836),
                        duration: const Duration(seconds: 1),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: isLight
                                ? Colors.black.withValues(alpha: 0.05)
                                : Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.copy_rounded,
                          size: 13,
                          color: isLight
                              ? const Color(0xFF5C6B7B)
                              : const Color(0xFF7A8B9C),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Copy',
                          style: TextStyle(
                            fontSize: 12,
                            color: isLight
                                ? const Color(0xFF5C6B7B)
                                : const Color(0xFF7A8B9C),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
