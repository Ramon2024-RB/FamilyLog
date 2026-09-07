import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with WidgetsBindingObserver {
  final SupabaseClient _supabase = Supabase.instance.client;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();

  StreamSubscription<List<Map<String, dynamic>>>? _messageSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _reactionSubscription;

  bool _isLoading = true;
  bool _isSending = false;

  String? _chatId;
  String? _familyId;
  String? _familyName;
  String? _errorMessage;

  List<_ChatMessage> _messages = [];
  List<_MessageReaction> _reactions = [];

  _ChatMessage? _replyingTo;

  String? _highlightedMessageId;
  Timer? _highlightTimer;

  OverlayEntry? _messageActionOverlay;

  final Map<String, String> _senderNames = {};
  final Map<String, GlobalKey> _messageKeys = {};

  static const List<String> _quickReactions = ['❤️', '👍', '😂', '😮', '😢'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeChat();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageSubscription?.cancel();
    _reactionSubscription?.cancel();
    _highlightTimer?.cancel();
    _removeMessageActionOverlay();
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _synchronizeMessages();
      _synchronizeReactions();
    }
  }

  Future<void> _initializeChat() async {
    try {
      final user = _supabase.auth.currentUser;

      if (user == null) {
        throw StateError('Kein Benutzer angemeldet.');
      }

      final membershipRows = await _supabase
          .from('family_memberships')
          .select('family_id')
          .eq('user_id', user.id)
          .limit(1);

      if (membershipRows.isEmpty) {
        if (!mounted) {
          return;
        }

        setState(() {
          _isLoading = false;
          _errorMessage = 'Du gehörst noch keiner Familie an.';
        });

        return;
      }

      final familyId = membershipRows.first['family_id'] as String;

      final familyRow = await _supabase
          .from('family_spaces')
          .select('name')
          .eq('id', familyId)
          .single();

      final familyName = familyRow['name'] as String;

      final chatResult = await _supabase.rpc(
        'get_or_create_family_chat',
        params: {'target_family_id': familyId},
      );

      final chatId = chatResult as String;

      if (!mounted) {
        return;
      }

      setState(() {
        _chatId = chatId;
        _familyId = familyId;
        _familyName = familyName;
        _isLoading = false;
        _errorMessage = null;
      });

      await _loadSenderNames();
      await _synchronizeMessages();
      await _synchronizeReactions();

      _startMessageStream(chatId);
      _startReactionStream();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = _friendlyErrorMessage(error);
      });
    }
  }

  Future<void> _loadSenderNames() async {
    final familyId = _familyId;

    if (familyId == null) {
      return;
    }

    try {
      final rows = await _supabase
          .from('family_members')
          .select('user_id, first_name, last_name')
          .eq('family_id', familyId);

      final names = <String, String>{};

      for (final row in rows) {
        final userId = row['user_id'] as String?;

        if (userId == null) {
          continue;
        }

        final firstName = (row['first_name'] as String? ?? '').trim();
        final lastName = (row['last_name'] as String? ?? '').trim();

        String displayName;

        if (firstName.isNotEmpty) {
          displayName = firstName;
        } else if (lastName.isNotEmpty) {
          displayName = lastName;
        } else {
          displayName = 'Familienmitglied';
        }

        names[userId] = displayName;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _senderNames
          ..clear()
          ..addAll(names);
      });
    } catch (_) {
      // Nachrichten funktionieren auch ohne geladene Namen.
    }
  }

  Future<void> _synchronizeMessages() async {
    final chatId = _chatId;

    if (chatId == null) {
      return;
    }

    try {
      final rows = await _supabase
          .from('messages')
          .select()
          .eq('chat_id', chatId)
          .order('created_at', ascending: true);

      final messages = rows
          .map((row) => _ChatMessage.fromMap(Map<String, dynamic>.from(row)))
          .toList();

      messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      if (!mounted) {
        return;
      }

      setState(() {
        _messages = messages;
        _ensureMessageKeys(messages);
      });

      _scrollToBottom(jump: true);
    } catch (_) {
      // Realtime bleibt aktiv.
    }
  }

  Future<void> _synchronizeReactions() async {
    if (_messages.isEmpty) {
      if (mounted) {
        setState(() {
          _reactions = [];
        });
      }
      return;
    }

    try {
      final messageIds = _messages.map((message) => message.id).toList();

      final rows = await _supabase
          .from('message_reactions')
          .select()
          .inFilter('message_id', messageIds);

      final reactions = rows
          .map(
            (row) => _MessageReaction.fromMap(Map<String, dynamic>.from(row)),
          )
          .toList();

      if (!mounted) {
        return;
      }

      setState(() {
        _reactions = reactions;
      });
    } catch (_) {
      // Nachrichten funktionieren auch ohne geladene Reaktionen.
    }
  }

  void _startMessageStream(String chatId) {
    _messageSubscription?.cancel();

    _messageSubscription = _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('chat_id', chatId)
        .order('created_at', ascending: true)
        .listen(
          (rows) {
            final messages = rows
                .map(
                  (row) => _ChatMessage.fromMap(Map<String, dynamic>.from(row)),
                )
                .toList();

            messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));

            if (!mounted) {
              return;
            }

            final previousMessageCount = _messages.length;

            setState(() {
              _messages = messages;
              _ensureMessageKeys(messages);
            });

            if (messages.length > previousMessageCount) {
              _scrollToBottom();
              _synchronizeReactions();
            }
          },
          onError: (Object error) {
            if (!mounted) {
              return;
            }

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(_friendlyErrorMessage(error))),
            );
          },
        );
  }

  void _startReactionStream() {
    _reactionSubscription?.cancel();

    _reactionSubscription = _supabase
        .from('message_reactions')
        .stream(primaryKey: ['id'])
        .listen(
          (rows) {
            if (!mounted) {
              return;
            }

            final messageIds = _messages.map((message) => message.id).toSet();

            final reactions = rows
                .where(
                  (row) => messageIds.contains(row['message_id'] as String?),
                )
                .map(
                  (row) =>
                      _MessageReaction.fromMap(Map<String, dynamic>.from(row)),
                )
                .toList();

            setState(() {
              _reactions = reactions;
            });
          },
          onError: (_) {
            // Fallback über Synchronisierung beim App-Resume.
          },
        );
  }

  void _ensureMessageKeys(List<_ChatMessage> messages) {
    for (final message in messages) {
      _messageKeys.putIfAbsent(message.id, GlobalKey.new);
    }

    final currentIds = messages.map((message) => message.id).toSet();

    _messageKeys.removeWhere((messageId, _) => !currentIds.contains(messageId));
  }

  Future<void> _sendMessage() async {
    final chatId = _chatId;
    final content = _messageController.text.trim();
    final replyingTo = _replyingTo;

    if (chatId == null || content.isEmpty || _isSending) {
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      await _supabase.rpc(
        'send_message',
        params: {
          'target_chat_id': chatId,
          'message_content': content,
          'reply_to_id': replyingTo?.id,
        },
      );

      _messageController.clear();

      if (mounted) {
        setState(() {
          _replyingTo = null;
        });
      }

      await _synchronizeMessages();
      await _synchronizeReactions();
      _scrollToBottom();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_friendlyErrorMessage(error))));
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _toggleReaction(_ChatMessage message, String emoji) async {
    try {
      await _supabase.rpc(
        'toggle_message_reaction',
        params: {'target_message_id': message.id, 'reaction_emoji': emoji},
      );

      await _synchronizeReactions();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_friendlyErrorMessage(error))));
    }
  }

  void _startReply(_ChatMessage message) {
    setState(() {
      _replyingTo = message;
    });

    _messageFocusNode.requestFocus();
  }

  void _cancelReply() {
    setState(() {
      _replyingTo = null;
    });
  }

  void _removeMessageActionOverlay() {
    _messageActionOverlay?.remove();
    _messageActionOverlay = null;
  }

  void _showMessageActions(_ChatMessage message, Offset globalPosition) {
    _removeMessageActionOverlay();

    final overlay = Overlay.of(context);

    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;
    final safeTop = mediaQuery.padding.top;

    const menuWidth = 286.0;
    const reactionHeight = 58.0;
    const actionHeight = 54.0;
    const gap = 8.0;
    const horizontalMargin = 12.0;

    double left = globalPosition.dx - (menuWidth / 2);

    if (left < horizontalMargin) {
      left = horizontalMargin;
    }

    if (left + menuWidth > screenSize.width - horizontalMargin) {
      left = screenSize.width - menuWidth - horizontalMargin;
    }

    final totalHeight = reactionHeight + gap + actionHeight;

    double top = globalPosition.dy - totalHeight - 16;

    if (top < safeTop + 8) {
      top = globalPosition.dy + 18;
    }

    if (top + totalHeight > screenSize.height - 20) {
      top = screenSize.height - totalHeight - 20;
    }

    _messageActionOverlay = OverlayEntry(
      builder: (overlayContext) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _removeMessageActionOverlay,
                child: const ColoredBox(color: Colors.transparent),
              ),
            ),
            Positioned(
              left: left,
              top: top,
              width: menuWidth,
              child: Material(
                color: Colors.transparent,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _MessageReactionPicker(
                      reactions: _quickReactions,
                      onReactionSelected: (emoji) {
                        _removeMessageActionOverlay();
                        _toggleReaction(message, emoji);
                      },
                    ),
                    const SizedBox(height: gap),
                    _MessageActionCard(
                      onReply: () {
                        _removeMessageActionOverlay();
                        _startReply(message);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );

    overlay.insert(_messageActionOverlay!);
  }

  List<_MessageReaction> _reactionsForMessage(String messageId) {
    return _reactions
        .where((reaction) => reaction.messageId == messageId)
        .toList();
  }

  _ChatMessage? _messageById(String? messageId) {
    if (messageId == null) {
      return null;
    }

    for (final message in _messages) {
      if (message.id == messageId) {
        return message;
      }
    }

    return null;
  }

  String _displayNameForMessage(_ChatMessage message) {
    final currentUserId = _supabase.auth.currentUser?.id;

    if (message.senderId == currentUserId) {
      return 'Du';
    }

    return _senderName(message.senderId);
  }

  Future<void> _jumpToMessage(String messageId) async {
    final key = _messageKeys[messageId];
    final targetContext = key?.currentContext;

    if (targetContext == null) {
      return;
    }

    await Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      alignment: 0.35,
    );

    if (!mounted) {
      return;
    }

    _highlightTimer?.cancel();

    setState(() {
      _highlightedMessageId = messageId;
    });

    _highlightTimer = Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) {
        return;
      }

      setState(() {
        if (_highlightedMessageId == messageId) {
          _highlightedMessageId = null;
        }
      });
    });
  }

  void _scrollToBottom({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }

      final target = _scrollController.position.maxScrollExtent;

      if (jump) {
        _scrollController.jumpTo(target);
        return;
      }

      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  String _friendlyErrorMessage(Object error) {
    final text = error.toString();

    if (text.contains('Not authenticated')) {
      return 'Du bist nicht angemeldet.';
    }

    if (text.contains('Not a family member')) {
      return 'Du bist kein Mitglied dieser Familie.';
    }

    if (text.contains('Not a chat member')) {
      return 'Du hast keinen Zugriff auf diesen Chat.';
    }

    if (text.contains('Message cannot be empty')) {
      return 'Die Nachricht darf nicht leer sein.';
    }

    if (text.contains('Message too long')) {
      return 'Die Nachricht ist zu lang.';
    }

    if (text.contains('Reply message not found')) {
      return 'Die ursprüngliche Nachricht wurde nicht gefunden.';
    }

    if (text.contains('Reaction cannot be empty')) {
      return 'Die Reaktion ist ungültig.';
    }

    if (text.contains('Reaction too long')) {
      return 'Die Reaktion ist ungültig.';
    }

    if (text.contains('Message not found')) {
      return 'Die Nachricht wurde nicht gefunden.';
    }

    return 'Etwas ist schiefgelaufen. Bitte versuche es erneut.';
  }

  String _senderName(String senderId) {
    return _senderNames[senderId] ?? 'Familienmitglied';
  }

  bool _isSameCalendarDay(DateTime first, DateTime second) {
    final firstLocal = first.toLocal();
    final secondLocal = second.toLocal();

    return firstLocal.year == secondLocal.year &&
        firstLocal.month == secondLocal.month &&
        firstLocal.day == secondLocal.day;
  }

  bool _messagesBelongTogether(_ChatMessage first, _ChatMessage second) {
    if (first.senderId != second.senderId) {
      return false;
    }

    if (first.replyToMessageId != null || second.replyToMessageId != null) {
      return false;
    }

    if (!_isSameCalendarDay(first.createdAt, second.createdAt)) {
      return false;
    }

    final difference = second.createdAt.toLocal().difference(
      first.createdAt.toLocal(),
    );

    return !difference.isNegative && difference <= const Duration(minutes: 5);
  }

  String _formatDateSeparator(DateTime dateTime) {
    final date = dateTime.toLocal();
    final now = DateTime.now();

    final today = DateTime(now.year, now.month, now.day);

    final messageDay = DateTime(date.year, date.month, date.day);

    final difference = today.difference(messageDay).inDays;

    if (difference == 0) {
      return 'Heute';
    }

    if (difference == 1) {
      return 'Gestern';
    }

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day.$month.${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Familienchat'),
            if (_familyName != null)
              Text(
                _familyName!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
      body: SafeArea(top: false, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.chat_bubble_outline,
                size: 56,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _errorMessage = null;
                  });

                  _initializeChat();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Erneut versuchen'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: _messages.isEmpty ? _buildEmptyChat() : _buildMessageList(),
        ),
        if (_replyingTo != null)
          _ReplyComposerPreview(
            senderName: _displayNameForMessage(_replyingTo!),
            content: _replyingTo!.content,
            onCancel: _cancelReply,
          ),
        _buildMessageComposer(),
      ],
    );
  }

  Widget _buildEmptyChat() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.family_restroom,
              size: 56,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Euer Familienchat',
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Schreib die erste Nachricht an deine Familie.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    final currentUserId = _supabase.auth.currentUser?.id;

    return ListView.builder(
      controller: _scrollController,
      reverse: false,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isMine = message.senderId == currentUserId;

        final showDateSeparator =
            index == 0 ||
            !_isSameCalendarDay(
              _messages[index - 1].createdAt,
              message.createdAt,
            );

        final groupedWithPrevious =
            index > 0 &&
            !showDateSeparator &&
            _messagesBelongTogether(_messages[index - 1], message);

        final groupedWithNext =
            index < _messages.length - 1 &&
            _isSameCalendarDay(
              message.createdAt,
              _messages[index + 1].createdAt,
            ) &&
            _messagesBelongTogether(message, _messages[index + 1]);

        final repliedMessage = _messageById(message.replyToMessageId);

        final messageKey = _messageKeys.putIfAbsent(message.id, GlobalKey.new);

        final reactions = _reactionsForMessage(message.id);

        return KeyedSubtree(
          key: messageKey,
          child: Column(
            children: [
              if (showDateSeparator)
                _DateSeparator(text: _formatDateSeparator(message.createdAt)),
              _MessageBubble(
                message: message,
                isMine: isMine,
                senderName: isMine ? null : _senderName(message.senderId),
                groupedWithPrevious: groupedWithPrevious,
                groupedWithNext: groupedWithNext,
                repliedMessage: repliedMessage,
                repliedSenderName: repliedMessage == null
                    ? null
                    : _displayNameForMessage(repliedMessage),
                isHighlighted: _highlightedMessageId == message.id,
                reactions: reactions,
                currentUserId: currentUserId,
                onLongPress: (position) {
                  _showMessageActions(message, position);
                },
                onReplyTap: repliedMessage == null
                    ? null
                    : () => _jumpToMessage(repliedMessage.id),
                onReactionTap: (emoji) {
                  _toggleReaction(message, emoji);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMessageComposer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              focusNode: _messageFocusNode,
              minLines: 1,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: 'Nachricht schreiben …',
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: _isSending ? null : _sendMessage,
            icon: _isSending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_rounded),
          ),
        ],
      ),
    );
  }
}

class _MessageReactionPicker extends StatelessWidget {
  const _MessageReactionPicker({
    required this.reactions,
    required this.onReactionSelected,
  });

  final List<String> reactions;
  final ValueChanged<String> onReactionSelected;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final backgroundColor = isDark
        ? const Color(0xFF4A4A52)
        : const Color(0xFFFFFFFF);

    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.10);

    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(29),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: reactions.map((emoji) {
          return _ReactionPickerButton(
            emoji: emoji,
            onTap: () {
              onReactionSelected(emoji);
            },
          );
        }).toList(),
      ),
    );
  }
}

class _ReactionPickerButton extends StatefulWidget {
  const _ReactionPickerButton({required this.emoji, required this.onTap});

  final String emoji;
  final VoidCallback onTap;

  @override
  State<_ReactionPickerButton> createState() => _ReactionPickerButtonState();
}

class _ReactionPickerButtonState extends State<_ReactionPickerButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        setState(() {
          _pressed = true;
        });
      },
      onTapCancel: () {
        setState(() {
          _pressed = false;
        });
      },
      onTapUp: (_) {
        setState(() {
          _pressed = false;
        });

        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? 1.18 : 1,
        duration: const Duration(milliseconds: 100),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: Text(widget.emoji, style: const TextStyle(fontSize: 27)),
          ),
        ),
      ),
    );
  }
}

class _MessageActionCard extends StatelessWidget {
  const _MessageActionCard({required this.onReply});

  final VoidCallback onReply;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final backgroundColor = isDark
        ? const Color(0xFF4A4A52)
        : const Color(0xFFFFFFFF);

    final foregroundColor = isDark ? Colors.white : const Color(0xFF202124);

    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.10);

    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onReply,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Icon(Icons.reply_rounded, color: foregroundColor, size: 22),
                const SizedBox(width: 12),
                Text(
                  'Antworten',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: foregroundColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReplyComposerPreview extends StatelessWidget {
  const _ReplyComposerPreview({
    required this.senderName,
    required this.content,
    required this.onCancel,
  });

  final String senderName;
  final String content;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 6),
      color: colors.surface,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 9, 4, 9),
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 38,
              decoration: BoxDecoration(
                color: colors.primary,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    senderName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    content,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onCancel,
              tooltip: 'Antwort abbrechen',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close_rounded, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateSeparator extends StatelessWidget {
  const _DateSeparator({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            text,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatefulWidget {
  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.senderName,
    required this.groupedWithPrevious,
    required this.groupedWithNext,
    required this.repliedMessage,
    required this.repliedSenderName,
    required this.isHighlighted,
    required this.reactions,
    required this.currentUserId,
    required this.onLongPress,
    required this.onReplyTap,
    required this.onReactionTap,
  });

  final _ChatMessage message;
  final bool isMine;
  final String? senderName;
  final bool groupedWithPrevious;
  final bool groupedWithNext;
  final _ChatMessage? repliedMessage;
  final String? repliedSenderName;
  final bool isHighlighted;
  final List<_MessageReaction> reactions;
  final String? currentUserId;
  final ValueChanged<Offset> onLongPress;
  final VoidCallback? onReplyTap;
  final ValueChanged<String> onReactionTap;

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> {
  Offset? _longPressPosition;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final showSenderName =
        !widget.isMine &&
        widget.senderName != null &&
        !widget.groupedWithPrevious;

    final topLeftRadius = widget.isMine
        ? 18.0
        : widget.groupedWithPrevious
        ? 7.0
        : 18.0;

    final topRightRadius = widget.isMine
        ? widget.groupedWithPrevious
              ? 7.0
              : 18.0
        : 18.0;

    final bottomLeftRadius = widget.isMine
        ? 18.0
        : widget.groupedWithNext
        ? 7.0
        : 4.0;

    final bottomRightRadius = widget.isMine
        ? widget.groupedWithNext
              ? 7.0
              : 4.0
        : 18.0;

    final normalColor = widget.isMine
        ? colors.primaryContainer
        : colors.surfaceContainerHighest;

    final highlightedColor = Color.alphaBlend(
      colors.primary.withValues(alpha: 0.18),
      normalColor,
    );

    final reactionGroups = _buildReactionGroups();

    return Align(
      alignment: widget.isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: widget.isMine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onLongPressStart: (details) {
              _longPressPosition = details.globalPosition;
            },
            onLongPress: () {
              final position = _longPressPosition;

              if (position != null) {
                widget.onLongPress(position);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              constraints: const BoxConstraints(maxWidth: 320),
              margin: EdgeInsets.only(
                bottom: reactionGroups.isEmpty
                    ? widget.groupedWithNext
                          ? 2
                          : 8
                    : 3,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: widget.isHighlighted ? highlightedColor : normalColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(topLeftRadius),
                  topRight: Radius.circular(topRightRadius),
                  bottomLeft: Radius.circular(bottomLeftRadius),
                  bottomRight: Radius.circular(bottomRightRadius),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (showSenderName) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        widget.senderName!,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: colors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  if (widget.repliedMessage != null) ...[
                    _ReplyBubblePreview(
                      senderName:
                          widget.repliedSenderName ?? 'Familienmitglied',
                      content: widget.repliedMessage!.content,
                      isMine: widget.isMine,
                      onTap: widget.onReplyTap,
                    ),
                    const SizedBox(height: 6),
                  ],
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      widget.message.content,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _formatTime(widget.message.createdAt),
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          if (reactionGroups.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(
                left: widget.isMine ? 0 : 8,
                right: widget.isMine ? 8 : 0,
                bottom: widget.groupedWithNext ? 2 : 8,
              ),
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: reactionGroups.map((group) {
                  return _ReactionChip(
                    emoji: group.emoji,
                    count: group.count,
                    selected: group.selected,
                    onTap: () {
                      widget.onReactionTap(group.emoji);
                    },
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  List<_ReactionGroup> _buildReactionGroups() {
    final grouped = <String, List<_MessageReaction>>{};

    for (final reaction in widget.reactions) {
      grouped.putIfAbsent(reaction.emoji, () => []).add(reaction);
    }

    final groups = grouped.entries.map((entry) {
      final selected = entry.value.any(
        (reaction) => reaction.userId == widget.currentUserId,
      );

      return _ReactionGroup(
        emoji: entry.key,
        count: entry.value.length,
        selected: selected,
      );
    }).toList();

    groups.sort((a, b) {
      final aIndex = _ChatPageState._quickReactions.indexOf(a.emoji);

      final bIndex = _ChatPageState._quickReactions.indexOf(b.emoji);

      if (aIndex == -1 && bIndex == -1) {
        return a.emoji.compareTo(b.emoji);
      }

      if (aIndex == -1) {
        return 1;
      }

      if (bIndex == -1) {
        return -1;
      }

      return aIndex.compareTo(bIndex);
    });

    return groups;
  }

  String _formatTime(DateTime dateTime) {
    final local = dateTime.toLocal();

    final hour = local.hour.toString().padLeft(2, '0');

    final minute = local.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }
}

class _ReactionChip extends StatelessWidget {
  const _ReactionChip({
    required this.emoji,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String emoji;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: selected
                ? colors.primaryContainer
                : colors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? colors.primary.withValues(alpha: 0.45)
                  : colors.outlineVariant,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 15)),
              if (count > 1) ...[
                const SizedBox(width: 3),
                Text(
                  '$count',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: selected ? colors.primary : colors.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ReplyBubblePreview extends StatelessWidget {
  const _ReplyBubblePreview({
    required this.senderName,
    required this.content,
    required this.isMine,
    required this.onTap,
  });

  final String senderName;
  final String content;
  final bool isMine;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(9, 7, 10, 7),
          decoration: BoxDecoration(
            color: isMine
                ? colors.surface.withValues(alpha: 0.52)
                : colors.surface.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(10),
            border: Border(left: BorderSide(color: colors.primary, width: 3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                senderName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatMessage {
  const _ChatMessage({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.content,
    required this.createdAt,
    this.replyToMessageId,
    this.editedAt,
  });

  final String id;
  final String chatId;
  final String senderId;
  final String content;
  final String? replyToMessageId;
  final DateTime? editedAt;
  final DateTime createdAt;

  factory _ChatMessage.fromMap(Map<String, dynamic> map) {
    return _ChatMessage(
      id: map['id'] as String,
      chatId: map['chat_id'] as String,
      senderId: map['sender_id'] as String,
      content: map['content'] as String,
      replyToMessageId: map['reply_to_message_id'] as String?,
      editedAt: map['edited_at'] == null
          ? null
          : DateTime.parse(map['edited_at'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

class _MessageReaction {
  const _MessageReaction({
    required this.id,
    required this.messageId,
    required this.userId,
    required this.emoji,
    required this.createdAt,
  });

  final String id;
  final String messageId;
  final String userId;
  final String emoji;
  final DateTime createdAt;

  factory _MessageReaction.fromMap(Map<String, dynamic> map) {
    return _MessageReaction(
      id: map['id'] as String,
      messageId: map['message_id'] as String,
      userId: map['user_id'] as String,
      emoji: map['emoji'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

class _ReactionGroup {
  const _ReactionGroup({
    required this.emoji,
    required this.count,
    required this.selected,
  });

  final String emoji;
  final int count;
  final bool selected;
}
