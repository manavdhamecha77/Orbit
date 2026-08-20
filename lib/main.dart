import 'package:flutter/material.dart';

import 'services/llm_service.dart';

void main() => runApp(const OrbitApp());

class OrbitApp extends StatelessWidget {
  const OrbitApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xff65d6c2),
      brightness: Brightness.dark,
    );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Orbit',
      theme: ThemeData(
        colorScheme: scheme,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xff101314),
        appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Color(0xff1b2223),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(24)),
            borderSide: BorderSide.none,
          ),
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
  final controller = TextEditingController();
  final scrollController = ScrollController();
  final llmService = LlmService();
  final messages = <Message>[];
  String status = 'Loading';
  bool generating = false;

  @override
  void initState() {
    super.initState();
    loadModel();
  }

  @override
  void dispose() {
    controller.dispose();
    scrollController.dispose();
    super.dispose();
  }

  Future<void> loadModel() async {
    try {
      await llmService.initialize();
      if (mounted) setState(() => status = 'Ready');
    } catch (e) {
      if (mounted) setState(() => status = 'Error: $e');
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

  String get statusLabel => status.startsWith('Error') ? 'Error' : status;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final ready = status == 'Ready' && !generating;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: .15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.auto_awesome, color: colors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Orbit', style: TextStyle(fontWeight: FontWeight.w700)),
                Text(
                  'Private · runs on your phone',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.normal),
                ),
              ],
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: _StatusPill(label: statusLabel, generating: generating),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty
                ? _Welcome(colors: colors, ready: ready)
                : ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                    itemCount: messages.length,
                    itemBuilder: (context, index) =>
                        _MessageBubble(message: messages[index]),
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      enabled: ready,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => sendMessage(),
                      decoration: const InputDecoration(
                        hintText: 'Ask Orbit anything…',
                        prefixIcon: Icon(Icons.chat_bubble_outline, size: 20),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filled(
                    onPressed: ready ? sendMessage : null,
                    icon: Icon(
                      generating ? Icons.hourglass_top : Icons.arrow_upward,
                    ),
                    tooltip: 'Send message',
                    style: IconButton.styleFrom(
                      padding: const EdgeInsets.all(15),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final bool generating;
  const _StatusPill({required this.label, required this.generating});

  @override
  Widget build(BuildContext context) {
    final color = label == 'Error'
        ? Colors.redAccent
        : label == 'Ready'
        ? Colors.greenAccent
        : Colors.amberAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            generating ? Icons.sync : Icons.circle,
            color: color,
            size: generating ? 14 : 8,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Welcome extends StatelessWidget {
  final ColorScheme colors;
  final bool ready;
  const _Welcome({required this.colors, required this.ready});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.psychology_alt, size: 64, color: colors.primary),
          const SizedBox(height: 20),
          const Text(
            'Your private AI companion',
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Text(
            ready
                ? 'Ask a question to start a completely offline conversation.'
                : 'Loading the local model…',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    ),
  );
}

class _MessageBubble extends StatelessWidget {
  final Message message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: message.isUser ? colors.primary : const Color(0xff202728),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(message.isUser ? 18 : 5),
            bottomRight: Radius.circular(message.isUser ? 5 : 18),
          ),
        ),
        child: Text(
          message.text.isEmpty ? '…' : message.text,
          style: TextStyle(
            color: message.isUser ? colors.onPrimary : colors.onSurface,
            height: 1.35,
          ),
        ),
      ),
    );
  }
}
