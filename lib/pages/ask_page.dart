import 'package:flutter/material.dart';
import '../widgets/app_gradients.dart';
import '../widgets/glass_card.dart';
import '../../services/ai_service.dart';
import '../../services/user_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Represents a single chat message.
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'text': text,
    'isUser': isUser,
    'timestamp': timestamp.toIso8601String(),
  };

  static ChatMessage fromJson(Map<String, dynamic> json) => ChatMessage(
    text: json['text'],
    isUser: json['isUser'],
    timestamp: DateTime.parse(json['timestamp']),
  );
}

// Page allowing users to chat with the AI farming assistant.
class AskPage extends StatefulWidget {
  const AskPage({super.key});

  @override
  State<AskPage> createState() => _AskPageState();
}

class _AskPageState extends State<AskPage> {
  final TextEditingController _questionController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AIService _aiService = AIService();
  List<ChatMessage> _messages = [];
  bool _isLoading = false;
  final int _chatLimit = 5;
  bool _chatLimitReached = false; //Track if limit is reached

  // For jump to latest button
  bool _showJumpToLatest = false;
  Set<int> _selectedMessageIndexes = {};

  final UserService _userService = UserService();

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
    _scrollController.addListener(_handleScroll);
    _checkChatLimit(); // Check limit on init
  }

  @override
  void dispose() {
    _questionController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final current = _scrollController.offset;
    // Show button if not at bottom
    final shouldShow = (maxScroll - current) > 80;
    if (_showJumpToLatest != shouldShow) {
      setState(() {
        _showJumpToLatest = shouldShow;
      });
    }
  }

  void _jumpToLatest() {
    _scrollToBottom();
  }

  Future<void> _loadChatHistory() async {
    // load from Firestore
    final user = _userService.currentUser;
    if (user != null) {
      try {
        final doc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('ai_chats')
                .doc('history')
                .get();
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          final messages = data['messages'] as List<dynamic>?;
          if (messages != null) {
            setState(() {
              _messages = messages.map((e) => ChatMessage.fromJson(e)).toList();
            });
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _scrollToBottom();
            });
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to load chat from fireStore: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _saveChatHistory() async {
    //Save to Firestore
    final user = _userService.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('ai_chats')
            .doc('history')
            .set({
              'messages': _messages.map((e) => e.toJson()).toList(),
            }, SetOptions(merge: true));
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to save chat to fireStore: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // Helper to build Cohere chat history from _messages
  List<Map<String, String>> _buildCohereHistory(List<ChatMessage> messages) {
    return messages
        .map(
          (msg) => {
            'role': msg.isUser ? 'USER' : 'CHATBOT',
            'message': msg.text,
          },
        )
        .toList();
  }

  Future<void> _checkChatLimit() async {
    final isPremium = await UserService().isPremium();
    if (isPremium) {
      setState(() => _chatLimitReached = false);
      return;
    }
    final reached = await _userService.isDailyChatLimitReached(
      chatLimit: _chatLimit,
    );
    setState(() {
      _chatLimitReached = reached;
    });
  }

  Future<void> _sendMessage() async {
    final question = _questionController.text.trim();
    if (question.isEmpty || _isLoading || _chatLimitReached) return;

    final isPremium = await UserService().isPremium();
    if (!isPremium) {
      final allowed = await _userService.checkAndIncrementDailyChatLimit(
        chatLimit: _chatLimit,
      );
      if (!allowed) {
        setState(() {
          _chatLimitReached = true;
        });
        return;
      }
    }
    setState(() {
      _messages.add(
        ChatMessage(text: question, isUser: true, timestamp: DateTime.now()),
      );
      _isLoading = true;
      _questionController.clear();
    });
    await _saveChatHistory();
    _scrollToBottom();

    try {
      // Build chat history for Cohere
      final cohereHistory = _buildCohereHistory(_messages);
      // Fetch user profile details
      final userProfile = await _userService.getUserProfile();
      final userName = userProfile?['name'] ?? 'User';
      final userProfession = userProfile?['profession'] ?? 'Farmer';
      final userLocation = userProfile?['location'] ?? 'Not set';
      final primaryCrops = List<String>.from(
        userProfile?['primaryCrops'] ?? [],
      );
      final response = await _aiService.askQuestionWithHistory(
        cohereHistory,
        userName: userName,
        userProfession: userProfession,
        userLocation: userLocation,
        primaryCrops: primaryCrops,
      );
      setState(() {
        _messages.add(
          ChatMessage(
            text: response ?? "Sorry, I couldn't find an answer.",
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
        _isLoading = false;
      });
      await _saveChatHistory();
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _messages.add(
          ChatMessage(
            text: "Error: $e",
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
        _isLoading = false;
      });
      await _saveChatHistory();
      _scrollToBottom();
    }
  }

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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: UserService().userStream(),
      builder: (context, snapshot) {
        final isPremium =
            snapshot.data?.data()?['membershipStatus'] == 'premium';
        // Always re-check the limit when membership changes
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _checkChatLimit();
        });
        if (isPremium && _chatLimitReached) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _chatLimitReached = false);
          });
        }
        return Scaffold(
          body: Container(
            decoration: BoxDecoration(gradient: appBackgroundGradient(context)),
            child: SafeArea(
              child: Stack(
                children: [
                  Column(
                    children: [
                      Expanded(
                        child:
                            _messages.isEmpty
                                ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.chat_bubble_outline,
                                        size: 64,
                                        color: colorScheme.onSurface.withAlpha(
                                          (0.3 * 255).toInt(),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No recent chats',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w500,
                                          color: colorScheme.onSurface
                                              .withAlpha((0.7 * 255).toInt()),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Ask me anything about farming!',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: colorScheme.onSurface
                                              .withAlpha((0.5 * 255).toInt()),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                                : ListView.builder(
                                  controller: _scrollController,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 16,
                                  ),
                                  itemCount: _messages.length,
                                  itemBuilder: (context, index) {
                                    final msg = _messages[index];
                                    final isSelected = _selectedMessageIndexes
                                        .contains(index);
                                    return GestureDetector(
                                      onLongPress: () {
                                        setState(() {
                                          if (_selectedMessageIndexes.contains(
                                            index,
                                          )) {
                                            _selectedMessageIndexes.remove(
                                              index,
                                            );
                                          } else {
                                            _selectedMessageIndexes.add(index);
                                          }
                                        });
                                      },
                                      child: Stack(
                                        children: [
                                          Align(
                                            alignment:
                                                msg.isUser
                                                    ? Alignment.centerRight
                                                    : Alignment.centerLeft,
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 4,
                                                  ),
                                              child: GlassCard(
                                                borderRadius: 18,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 12,
                                                    ),
                                                gradient: LinearGradient(
                                                  colors:
                                                      msg.isUser
                                                          ? [
                                                            colorScheme.primary
                                                                .withAlpha(
                                                                  (0.18 * 255)
                                                                      .toInt(),
                                                                ),
                                                            colorScheme.primary
                                                                .withAlpha(
                                                                  (0.10 * 255)
                                                                      .toInt(),
                                                                ),
                                                          ]
                                                          : [
                                                            colorScheme
                                                                .secondary
                                                                .withAlpha(
                                                                  (0.13 * 255)
                                                                      .toInt(),
                                                                ),
                                                            colorScheme
                                                                .secondary
                                                                .withAlpha(
                                                                  (0.07 * 255)
                                                                      .toInt(),
                                                                ),
                                                          ],
                                                ),
                                                borderColor:
                                                    msg.isUser
                                                        ? colorScheme.primary
                                                            .withAlpha(
                                                              (0.18 * 255)
                                                                  .toInt(),
                                                            )
                                                        : colorScheme.secondary
                                                            .withAlpha(
                                                              (0.18 * 255)
                                                                  .toInt(),
                                                            ),
                                                borderWidth: 1.2,
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      msg.text,
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        color:
                                                            colorScheme
                                                                .onSurface,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      _formatTimestamp(
                                                        msg.timestamp,
                                                      ),
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: colorScheme
                                                            .onSurface
                                                            .withAlpha(
                                                              (0.5 * 255)
                                                                  .toInt(),
                                                            ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                          if (isSelected)
                                            Positioned(
                                              top: 0,
                                              right: msg.isUser ? 0 : null,
                                              left: msg.isUser ? null : 0,
                                              child: IconButton(
                                                icon: Icon(
                                                  Icons.delete,
                                                  color: colorScheme.error,
                                                  size: 36,
                                                ),
                                                iconSize: 36,
                                                tooltip: 'Delete message',
                                                onPressed: () async {
                                                  setState(() {
                                                    _messages.removeAt(index);
                                                    _selectedMessageIndexes
                                                        .remove(index);
                                                    // Re-index selection set
                                                    _selectedMessageIndexes =
                                                        _selectedMessageIndexes
                                                            .map(
                                                              (i) =>
                                                                  i > index
                                                                      ? i - 1
                                                                      : i,
                                                            )
                                                            .toSet();
                                                  });
                                                  await _saveChatHistory();
                                                },
                                              ),
                                            ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                      ),
                      if (_isLoading)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8.0),
                          child: CircularProgressIndicator(),
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                        child:
                            _chatLimitReached && !isPremium
                                ? Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    TextField(
                                      enabled: false,
                                      decoration: InputDecoration(
                                        labelText: 'Daily chat limit reached',
                                        labelStyle: TextStyle(
                                          color: colorScheme.onSurface,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                        prefixIcon: Icon(
                                          Icons.lock,
                                          color: colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.upgrade),
                                      label: const Text('Upgrade to Premium'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: colorScheme.primary,
                                        foregroundColor: colorScheme.onPrimary,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                        elevation: 2,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                      ),
                                      onPressed: () {
                                        Navigator.of(
                                          context,
                                        ).pushNamed('/premium_upgrade_page');
                                      },
                                    ),
                                  ],
                                )
                                : Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _questionController,
                                        minLines: 1,
                                        maxLines: 4,
                                        decoration: InputDecoration(
                                          labelText: 'Type your question...',
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                          ),
                                          prefixIcon: Icon(
                                            Icons.question_answer,
                                            color: colorScheme.primary,
                                          ),
                                        ),
                                        onSubmitted: (_) => _sendMessage(),
                                        enabled:
                                            !_isLoading && !_chatLimitReached,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.send),
                                      color: colorScheme.primary,
                                      onPressed:
                                          _isLoading || _chatLimitReached
                                              ? null
                                              : _sendMessage,
                                    ),
                                  ],
                                ),
                      ),
                    ],
                  ),
                  // Jump to Latest button (bottom right)
                  if (_showJumpToLatest)
                    Positioned(
                      bottom: 90,
                      right: 16,
                      child: FloatingActionButton(
                        mini: true,
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        onPressed: _jumpToLatest,
                        tooltip: 'Jump to latest',
                        elevation: 2,
                        child: const Icon(Icons.arrow_downward),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    if (now.difference(timestamp).inDays == 0) {
      // Today
      return "${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}";
    } else {
      return "${timestamp.month}/${timestamp.day} ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}";
    }
  }
}
