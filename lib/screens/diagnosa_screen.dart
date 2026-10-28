import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/diagnosa_service.dart';
import '../utils/constants.dart';

class DiagnosaScreen extends StatefulWidget {
  const DiagnosaScreen({super.key});

  @override
  State<DiagnosaScreen> createState() => _DiagnosaScreenState();
}

class _ChatMessage {
  final String role; // 'user' atau 'model'
  final String text;
  final File? photo;

  const _ChatMessage({
    required this.role,
    required this.text,
    this.photo,
  });

  bool get isUser => role == 'user';
}

class _DiagnosaScreenState extends State<DiagnosaScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _picker = ImagePicker();
  final _service = DiagnosaService();

  final List<_ChatMessage> _messages = [];
  File? _pendingPhoto;
  bool _loading = false;
  String? _error;

  static const _darkGreen = Color(0xFF1E5A43);
  static const _green = Color(0xFF2F7957);
  static const _paleGreen = Color(0xFFE7F3E9);
  static const _page = Color(0xFFF7FAF7);

  static const _suggestions = <String>[
    'Daun menguning',
    'Cara merawat tanaman',
    'Bercak pada daun',
  ];

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _choosePhoto(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 82,
      );
      if (picked == null || !mounted) return;
      setState(() {
        _pendingPhoto = File(picked.path);
        _error = null;
      });
    } catch (_) {
      if (mounted) _showMessage('Foto tidak dapat diakses. Coba lagi.');
    }
  }

  void _showPhotoOptions() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Ambil foto'),
              onTap: () {
                Navigator.pop(sheetContext);
                _choosePhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Pilih dari galeri'),
              onTap: () {
                Navigator.pop(sheetContext);
                _choosePhoto(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendMessage({String? suggestedText}) async {
    final text = (suggestedText ?? _controller.text).trim();
    final photo = _pendingPhoto;

    if (text.isEmpty && photo == null) return;
    if (_loading) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _messages.add(_ChatMessage(role: 'user', text: text, photo: photo));
      _controller.clear();
      _pendingPhoto = null;
      _loading = true;
      _error = null;
    });
    _scrollToBottom();

    try {
      final history = _messages
          .map((message) => <String, dynamic>{
                'role': message.role,
                'text': message.text,
                'photo': message.photo,
              })
          .toList();

      final answer = await _service.chat(history: history);
      if (!mounted) return;

      setState(() {
        _messages.add(_ChatMessage(role: 'model', text: answer));
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        _scrollToBottom();
      }
    }
  }

  Future<void> _retryLastMessage() async {
    if (_loading || _messages.isEmpty || _messages.last.isUser == false) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final history = _messages
          .map((message) => <String, dynamic>{
                'role': message.role,
                'text': message.text,
                'photo': message.photo,
              })
          .toList();
      final answer = await _service.chat(history: history);
      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMessage(role: 'model', text: answer));
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _page,
      appBar: AppBar(
        backgroundColor: _page,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 28),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: _paleGreen,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.eco_rounded, color: _green, size: 23),
            ),
            const SizedBox(width: 9),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FlorAI',
                  style: TextStyle(
                    color: _darkGreen,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Asisten pintar tanaman',
                  style: TextStyle(fontSize: 10, color: Colors.black54),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Percakapan baru',
            icon: const Icon(Icons.history_rounded, color: _darkGreen),
            onPressed: _loading
                ? null
                : () {
                    setState(() {
                      _messages.clear();
                      _pendingPhoto = null;
                      _error = null;
                    });
                  },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                if (_messages.isEmpty) ...[
                  _welcomeCard(),
                  const SizedBox(height: 18),
                  _assistantBubble(
                    'Hai, Agrivers! 🌱 Aku FlorAI, teman konsultasi tanamanmu. '
                    'FlorAI siap membantu kamu memahami kondisi tanamanmu ',
    
                  ),
                ],
                for (final message in _messages)
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: message.isUser
                        ? _userBubble(message)
                        : _assistantBubble(message.text),
                  ),
                if (_loading)
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 15,
                              height: 15,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _green,
                              ),
                            ),
                            SizedBox(width: 10),
                            Text(
                              'FlorAI sedang berpikir...',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEEEE),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.error_outline,
                              color: Colors.red, size: 19),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          TextButton(
                            onPressed: _loading ? null : _retryLastMessage,
                            child: const Text('Coba lagi'),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (_messages.isEmpty && !_loading) _suggestionChips(),
          _composer(),
        ],
      ),
    );
  }

  Widget _welcomeCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _paleGreen,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.spa_rounded, color: _green, size: 23),
          ),
          const SizedBox(width: 11),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Halo, Saya FlorAI 🌿'
                  ' Asisten konsultasi tanamanmu.',
                  style: TextStyle(
                    color: _darkGreen,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _assistantBubble(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            color: _paleGreen,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.eco_rounded, color: _green, size: 17),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15).copyWith(
                topLeft: const Radius.circular(4),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(10),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: SelectableText(
              text,
              style: const TextStyle(
                color: Color(0xFF263B30),
                fontSize: 12.5,
                height: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _userBubble(_ChatMessage message) {
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: const BoxDecoration(
            color: _darkGreen,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(15),
              topRight: Radius.circular(5),
              bottomLeft: Radius.circular(15),
              bottomRight: Radius.circular(15),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message.photo != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(
                    message.photo!,
                    width: 210,
                    height: 140,
                    fit: BoxFit.cover,
                  ),
                ),
                if (message.text.isNotEmpty) const SizedBox(height: 8),
              ],
              if (message.text.isNotEmpty)
                Text(
                  message.text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _suggestionChips() {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
        scrollDirection: Axis.horizontal,
        itemCount: _suggestions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 7),
        itemBuilder: (context, index) => ActionChip(
          label: Text(
            _suggestions[index],
            style: const TextStyle(fontSize: 10.5, color: _darkGreen),
          ),
          backgroundColor: Colors.white,
          side: const BorderSide(color: Color(0xFFD7E8DA)),
          visualDensity: VisualDensity.compact,
          onPressed: () => _sendMessage(suggestedText: _suggestions[index]),
        ),
      ),
    );
  }

  Widget _composer() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        decoration: const BoxDecoration(
          color: _page,
          border: Border(top: BorderSide(color: Color(0xFFE6ECE7))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_pendingPhoto != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8, left: 4),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(
                          _pendingPhoto!,
                          width: 76,
                          height: 64,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: InkWell(
                          onTap: () => setState(() => _pendingPhoto = null),
                          child: const CircleAvatar(
                            radius: 10,
                            backgroundColor: Colors.black54,
                            child: Icon(Icons.close,
                                size: 12, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'Kirim foto',
                  onPressed: _loading ? null : _showPhotoOptions,
                  icon: const Icon(Icons.add_circle_outline,
                      color: _green, size: 25),
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: InputDecoration(
                      hintText: 'Tanya FlorAI...',
                      hintStyle: const TextStyle(
                        color: Colors.black45,
                        fontSize: 12,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: const BorderSide(color: Color(0xFFE0E8E1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: const BorderSide(color: Color(0xFFE0E8E1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: const BorderSide(color: _green),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: _green,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _loading ? null : _sendMessage,
                    child: Padding(
                      padding: const EdgeInsets.all(11),
                      child: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.arrow_upward_rounded,
                              color: Colors.white, size: 19),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
