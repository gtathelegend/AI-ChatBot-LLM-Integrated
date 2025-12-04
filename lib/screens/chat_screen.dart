import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../models/chat_message.dart';
import '../services/llm_service.dart';
import '../services/voice_service.dart';
import '../widgets/chat_bubble.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late LlmService _llmService;
  late VoiceService _voiceService;

  bool _isSending = false;
  bool _voiceReady = false;
  bool _isListening = false;

  final List<ChatMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    _llmService = LlmService(
      baseUrl: "http://192.168.1.5:8000", // change to your laptop IP/port
      modelName: "deepseek-r1",
    );
    _voiceService = VoiceService();
    _initVoice();
  }

  Future<void> _initVoice() async {
    final ok = await _voiceService.init();
    setState(() => _voiceReady = ok);
  }

  String _id() => Random().nextInt(1 << 32).toString();

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendText({List<Attachment> attachments = const []}) async {
    final text = _controller.text.trim();
    if (text.isEmpty && attachments.isEmpty) return;
    if (_isSending) return;

    final userMsg = ChatMessage(
      id: _id(),
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
      attachments: attachments,
    );

    setState(() {
      _messages.add(userMsg);
      _isSending = true;
      _controller.clear();
    });
    _scrollToBottom();

    try {
      final reply = await _llmService.sendMessage(
        message: text.isEmpty ? "(attachment only)" : text,
        attachments: attachments,
      );

      final botMsg = ChatMessage(
        id: _id(),
        text: reply,
        isUser: false,
        timestamp: DateTime.now(),
      );

      setState(() => _messages.add(botMsg));
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(
          id: _id(),
          text: "Error contacting LLM: $e",
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
    } finally {
      setState(() => _isSending = false);
      _scrollToBottom();
    }
  }

  Future<void> _pickAttachment() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: false,
    );
    if (result == null) return;

    final attachments = result.files.map((f) {
      return Attachment(
        name: f.name,
        path: f.path ?? "",
        mimeType: f.extension ?? "file",
      );
    }).toList();

    await _sendText(attachments: attachments);
  }

  void _toggleListen() {
    if (!_voiceReady) return;

    if (_isListening) {
      _voiceService.stopListening();
      setState(() => _isListening = false);
    } else {
      setState(() => _isListening = true);
      _voiceService.startListening((recognized) {
        setState(() {
          _controller.text = recognized;
        });
      });
    }
  }

  void _sendSuggestion(String text) {
    _controller.text = text;
    _sendText();
  }

  @override
  Widget build(BuildContext context) {
    final gradient = const LinearGradient(
      colors: [Color(0xFF0F172A), Color(0xFF020617)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: gradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildSuggestions(),
              const SizedBox(height: 8),
              Expanded(child: _buildMessages()),
              _buildInputBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding:
          const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.tealAccent.withOpacity(0.2),
            child: const Icon(Icons.stars, color: Colors.tealAccent),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                "Your AI Companion",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                "Powered by your local LLM",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          const Spacer(),
          if (_isSending)
            const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }

  Widget _buildSuggestions() {
    final chips = [
      "Summarize my day",
      "Plan a 3-step workout",
      "Explain AI agents simply",
      "Help me write a message",
    ];

    return SizedBox(
      height: 38,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          return ActionChip(
            label: Text(
              chips[index],
              style: const TextStyle(fontSize: 12),
            ),
            onPressed: () => _sendSuggestion(chips[index]),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemCount: chips.length,
      ),
    );
  }

  Widget _buildMessages() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        return ChatBubble(message: msg);
      },
    );
  }

  Widget _buildInputBar() {
    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(
            icon: const Icon(Icons.attach_file),
            onPressed: _pickAttachment,
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF020617),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white10),
              ),
              child: TextField(
                controller: _controller,
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendText(),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: "Ask anything, or give a task...",
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            icon: Icon(
              _isListening ? Icons.mic : Icons.mic_none,
              color: _isListening ? Colors.redAccent : Colors.white,
            ),
            onPressed: _toggleListen,
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: _sendText,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.tealAccent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Icon(Icons.send, size: 18, color: Colors.black),
            ),
          )
        ],
      ),
    );
  }
}
