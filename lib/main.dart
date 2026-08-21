import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import 'services/llm_service.dart';

void main() => runApp(const OrbitApp());

class OrbitApp extends StatelessWidget {
  const OrbitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Orbit',
      theme: ThemeData(
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
      home: const ChatScreen(),
    );
  }
}

class Message {
  String text;
  final bool isUser;
  Message({required this.text, required this.isUser});
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

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
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A232E).withValues(alpha: 0.95),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.12),
                width: 1.0,
              ),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Local AI Model',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFE6EDF3),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Active Model',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF7A8B9C),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          activeModelName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFFE2EAF1),
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
                            foregroundColor: const Color(0xFFC0CDDB),
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
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
                            backgroundColor: const Color(0xFFE2E9F0),
                            foregroundColor: const Color(0xFF131922),
                            padding: const EdgeInsets.symmetric(vertical: 14),
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
        );
      },
    );
  }

  String get statusLabel => status.startsWith('Error') ? 'Error' : status;

  @override
  Widget build(BuildContext context) {
    final isReady = status == 'Ready';
    final hasText = controller.text.trim().isNotEmpty;
    final canSend = isReady && !generating && hasText;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 20,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Orbit',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Color(0xFFE6EDF3),
                letterSpacing: -0.2,
              ),
            ),
            Text(
              'Private · runs on your phone',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: Color(0xFF7A8B9C),
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 18),
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
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.0, -0.35),
            radius: 1.25,
            colors: [
              Color(0xFF1B2430), // Soft blue-gray center
              Color(0xFF131922), // Intermediate tone
              Color(0xFF0B0E13), // Darker edge
            ],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Message list or Welcome screen
              Expanded(
                child: messages.isEmpty
                    ? _Welcome(
                        ready: isReady,
                        onSelectModel: selectModel,
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
                        itemCount: messages.length,
                        itemBuilder: (context, index) =>
                            _MessageBubble(message: messages[index]),
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
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
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
              color: const Color(0xFF1E2836).withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
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
                    style: const TextStyle(
                      color: Color(0xFFE6EDF3),
                      fontSize: 15,
                      height: 1.4,
                    ),
                    cursorColor: const Color(0xFFA0B3C6),
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: 'Ask me anything...',
                      hintStyle: TextStyle(
                        color: Color(0xFF788899),
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
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
    const activeBg = Color(0xFFDDE5ED);
    final disabledBg = Colors.white.withValues(alpha: 0.08);

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
                  ? Colors.white.withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.08),
              width: 1,
            ),
            boxShadow: (showStop || canSend)
                ? [
                    BoxShadow(
                      color: const Color(0xFFB0C4DE).withValues(alpha: 0.25),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: showStop
                ? const Icon(
                    Icons.stop_rounded,
                    size: 20,
                    color: Color(0xFF121922),
                  )
                : Icon(
                    Icons.arrow_upward_rounded,
                    size: 20,
                    color: canSend
                        ? const Color(0xFF121922)
                        : const Color(0xFF637383),
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
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
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
              style: const TextStyle(
                color: Color(0xFFC2CFDB),
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

  const _Welcome({
    required this.ready,
    required this.onSelectModel,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Your private AI companion',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: Color(0xFFE6EDF3),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              ready
                  ? 'Ask a question to start a completely offline conversation.'
                  : 'Choose a GGUF model stored on your phone to begin.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF7E8F9F),
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
                    color: const Color(0xFF222E3D).withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
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
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.folder_open_rounded,
                        size: 18,
                        color: Color(0xFFBDCCD9),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Select GGUF model',
                        style: TextStyle(
                          color: Color(0xFFE2EAF1),
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
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 580),
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: message.isUser
              ? const Color(0xFF2A3748).withValues(alpha: 0.85)
              : const Color(0xFF18222D).withValues(alpha: 0.7),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(message.isUser ? 18 : 4),
            bottomRight: Radius.circular(message.isUser ? 4 : 18),
          ),
          border: Border.all(
            color: message.isUser
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: 0.07),
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
                ? const Color(0xFFF0F4F8)
                : const Color(0xFFD3DDE6),
            fontSize: 14.5,
          ),
        ),
      ),
    );
  }
}
