import 'dart:async';
import 'dart:io';

import 'package:cupertino_interactive_keyboard/cupertino_interactive_keyboard.dart';
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
  final TextEditingController _searchController = TextEditingController();

  final ScrollController _scrollController = ScrollController();

  final FocusNode _messageFocusNode = FocusNode();
  final FocusNode _searchFocusNode = FocusNode();

  StreamSubscription<List<Map<String, dynamic>>>? _messageSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _reactionSubscription;

  bool _isLoading = true;
  bool _isSending = false;
  bool _isSearching = false;

  String? _chatId;
  String? _familyId;
  String? _familyName;
  String? _errorMessage;

  List<_ChatMessage> _messages = [];
  List<_MessageReaction> _reactions = [];

  List<String> _searchResultIds = [];
  int _currentSearchResultIndex = -1;

  _ChatMessage? _replyingTo;
  _ChatMessage? _editingMessage;

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
    _searchController.addListener(_updateSearchResults);
    _initializeChat();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _messageSubscription?.cancel();
    _reactionSubscription?.cancel();
    _highlightTimer?.cancel();

    _removeMessageActionOverlay();

    _searchController.removeListener(_updateSearchResults);

    _messageController.dispose();
    _searchController.dispose();

    _scrollController.dispose();

    _messageFocusNode.dispose();
    _searchFocusNode.dispose();

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

      if (_isSearching) {
        _updateSearchResults();
      } else {
        _scrollToBottom(jump: true);
      }
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

            if (_isSearching) {
              _updateSearchResults();
            }

            if (!_isSearching && messages.length > previousMessageCount) {
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
    final content = _messageController.text.trim();

    if (content.isEmpty || _isSending) {
      return;
    }

    if (_editingMessage != null) {
      await _saveEditedMessage();
      return;
    }

    final chatId = _chatId;
    final replyingTo = _replyingTo;

    if (chatId == null) {
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

  Future<void> _saveEditedMessage() async {
    final message = _editingMessage;
    final content = _messageController.text.trim();

    if (message == null || content.isEmpty || _isSending) {
      return;
    }

    if (content == message.content) {
      _cancelEdit();
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      await _supabase.rpc(
        'edit_message',
        params: {'target_message_id': message.id, 'new_content': content},
      );

      _messageController.clear();

      if (mounted) {
        setState(() {
          _editingMessage = null;
        });
      }

      await _synchronizeMessages();
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
    if (message.isDeleted) {
      return;
    }

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
    if (message.isDeleted) {
      return;
    }

    setState(() {
      _editingMessage = null;
      _replyingTo = message;
    });

    _messageController.clear();
    _messageFocusNode.requestFocus();
  }

  void _cancelReply() {
    setState(() {
      _replyingTo = null;
    });
  }

  void _startEdit(_ChatMessage message) {
    if (message.isDeleted) {
      return;
    }

    setState(() {
      _replyingTo = null;
      _editingMessage = message;
    });

    _messageController.text = message.content;

    _messageController.selection = TextSelection.collapsed(
      offset: _messageController.text.length,
    );

    _messageFocusNode.requestFocus();
  }

  void _cancelEdit() {
    _messageController.clear();

    setState(() {
      _editingMessage = null;
    });
  }

  Future<void> _confirmDeleteMessage(_ChatMessage message) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Nachricht löschen?'),
          content: const Text(
            'Die Nachricht wird für alle Familienmitglieder als gelöscht angezeigt.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Löschen'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true || !mounted) {
      return;
    }

    await _deleteMessage(message);
  }

  Future<void> _deleteMessage(_ChatMessage message) async {
    try {
      await _supabase.rpc(
        'delete_message',
        params: {'target_message_id': message.id},
      );

      if (_editingMessage?.id == message.id) {
        _messageController.clear();

        if (mounted) {
          setState(() {
            _editingMessage = null;
          });
        }
      }

      if (_replyingTo?.id == message.id && mounted) {
        setState(() {
          _replyingTo = null;
        });
      }

      await _synchronizeMessages();
      await _synchronizeReactions();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_friendlyErrorMessage(error))));
    }
  }

  void _startSearch() {
    _removeMessageActionOverlay();

    FocusScope.of(context).unfocus();

    setState(() {
      _isSearching = true;
      _searchResultIds = [];
      _currentSearchResultIndex = -1;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  void _closeSearch() {
    _searchController.clear();
    _searchFocusNode.unfocus();

    _highlightTimer?.cancel();

    setState(() {
      _isSearching = false;
      _searchResultIds = [];
      _currentSearchResultIndex = -1;
      _highlightedMessageId = null;
    });
  }

  void _updateSearchResults() {
    if (!_isSearching || !mounted) {
      return;
    }

    final query = _searchController.text.trim().toLowerCase();

    if (query.isEmpty) {
      setState(() {
        _searchResultIds = [];
        _currentSearchResultIndex = -1;
        _highlightedMessageId = null;
      });

      return;
    }

    final results = _messages
        .where(
          (message) =>
              !message.isDeleted &&
              message.content.toLowerCase().contains(query),
        )
        .map((message) => message.id)
        .toList();

    setState(() {
      _searchResultIds = results;

      if (results.isEmpty) {
        _currentSearchResultIndex = -1;
        _highlightedMessageId = null;
      } else {
        _currentSearchResultIndex = results.length - 1;
      }
    });

    if (results.isNotEmpty) {
      _jumpToSearchResult(_currentSearchResultIndex);
    }
  }

  Future<void> _jumpToPreviousSearchResult() async {
    if (_searchResultIds.isEmpty) {
      return;
    }

    var nextIndex = _currentSearchResultIndex - 1;

    if (nextIndex < 0) {
      nextIndex = _searchResultIds.length - 1;
    }

    setState(() {
      _currentSearchResultIndex = nextIndex;
    });

    await _jumpToSearchResult(nextIndex);
  }

  Future<void> _jumpToNextSearchResult() async {
    if (_searchResultIds.isEmpty) {
      return;
    }

    var nextIndex = _currentSearchResultIndex + 1;

    if (nextIndex >= _searchResultIds.length) {
      nextIndex = 0;
    }

    setState(() {
      _currentSearchResultIndex = nextIndex;
    });

    await _jumpToSearchResult(nextIndex);
  }

  Future<void> _jumpToSearchResult(int resultIndex) async {
    if (resultIndex < 0 || resultIndex >= _searchResultIds.length) {
      return;
    }

    final messageId = _searchResultIds[resultIndex];

    await _jumpToMessage(messageId, searchHighlight: true);
  }

  Future<void> _showAttachmentMenu() async {
    if (_editingMessage != null || _isSending) {
      return;
    }

    _removeMessageActionOverlay();
    FocusScope.of(context).unfocus();

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Anhangmenü schließen',
      barrierColor: Colors.black.withValues(alpha: 0.28),
      transitionDuration: const Duration(milliseconds: 360),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return const SizedBox.shrink();
      },
      transitionBuilder: (dialogContext, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );

        return _AttachmentFanMenu(
          animation: curved,
          onClose: () => Navigator.of(dialogContext).pop(),
          onPhotoCamera: () {
            Navigator.of(dialogContext).pop();
            _showAttachmentComingSoon('Foto aufnehmen');
          },
          onPhotoLibrary: () {
            Navigator.of(dialogContext).pop();
            _showAttachmentComingSoon('Bild auswählen');
          },
          onVideoCamera: () {
            Navigator.of(dialogContext).pop();
            _showAttachmentComingSoon('Video aufnehmen');
          },
          onVideoLibrary: () {
            Navigator.of(dialogContext).pop();
            _showAttachmentComingSoon('Video auswählen');
          },
        );
      },
    );
  }

  void _showAttachmentComingSoon(String action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$action wird als Nächstes mit dem Upload verbunden.'),
      ),
    );
  }

  void _showChatMenu() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final colors = Theme.of(sheetContext).colorScheme;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Medien'),
                  subtitle: const Text('Bilder und Videos aus diesem Chat'),
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: colors.onSurfaceVariant,
                  ),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _showComingSoonMessage('Medien');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.link_rounded),
                  title: const Text('Links'),
                  subtitle: const Text('Geteilte Links aus diesem Chat'),
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: colors.onSurfaceVariant,
                  ),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _showComingSoonMessage('Links');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('Dokumente'),
                  subtitle: const Text('Geteilte Dateien und Dokumente'),
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: colors.onSurfaceVariant,
                  ),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _showComingSoonMessage('Dokumente');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showComingSoonMessage(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$feature werden aktiviert, sobald diese Inhalte im Chat versendet werden können.',
        ),
      ),
    );
  }

  void _removeMessageActionOverlay() {
    _messageActionOverlay?.remove();
    _messageActionOverlay = null;
  }

  void _showMessageActions(_ChatMessage message, Offset globalPosition) {
    if (message.isDeleted) {
      return;
    }

    FocusScope.of(context).unfocus();

    _removeMessageActionOverlay();

    final overlay = Overlay.of(context);

    final currentUserId = _supabase.auth.currentUser?.id;
    final isMine = message.senderId == currentUserId;

    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;
    final safeTop = mediaQuery.padding.top;

    const menuWidth = 286.0;
    const reactionHeight = 58.0;
    const gap = 8.0;
    const horizontalMargin = 12.0;

    final actionHeight = isMine ? 146.0 : 54.0;
    final totalHeight = reactionHeight + gap + actionHeight;

    double left = globalPosition.dx - (menuWidth / 2);

    if (left < horizontalMargin) {
      left = horizontalMargin;
    }

    if (left + menuWidth > screenSize.width - horizontalMargin) {
      left = screenSize.width - menuWidth - horizontalMargin;
    }

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
                      isMine: isMine,
                      onReply: () {
                        _removeMessageActionOverlay();
                        _startReply(message);
                      },
                      onEdit: isMine
                          ? () {
                              _removeMessageActionOverlay();
                              _startEdit(message);
                            }
                          : null,
                      onDelete: isMine
                          ? () {
                              _removeMessageActionOverlay();
                              _confirmDeleteMessage(message);
                            }
                          : null,
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

  Future<void> _jumpToMessage(
    String messageId, {
    bool searchHighlight = false,
  }) async {
    final key = _messageKeys[messageId];
    final targetContext = key?.currentContext;

    if (targetContext == null) {
      final index = _messages.indexWhere((message) => message.id == messageId);

      if (index >= 0 && _scrollController.hasClients) {
        final max = _scrollController.position.maxScrollExtent;

        final ratio = _messages.length <= 1
            ? 0.0
            : index / (_messages.length - 1);

        final approximateOffset = max * ratio;

        await _scrollController.animateTo(
          approximateOffset.clamp(0.0, max),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );

        await Future<void>.delayed(const Duration(milliseconds: 80));

        if (!mounted) {
          return;
        }

        final refreshedContext = _messageKeys[messageId]?.currentContext;

        if (refreshedContext != null && refreshedContext.mounted) {
          await Scrollable.ensureVisible(
            refreshedContext,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            alignment: 0.35,
          );
        }
      }
    } else {
      await Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
        alignment: 0.35,
      );
    }

    if (!mounted) {
      return;
    }

    _highlightTimer?.cancel();

    setState(() {
      _highlightedMessageId = messageId;
    });

    if (!searchHighlight) {
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

    if (text.contains('Not message owner')) {
      return 'Du kannst nur deine eigenen Nachrichten ändern.';
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

    if (text.contains('Message already deleted')) {
      return 'Diese Nachricht wurde bereits gelöscht.';
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

    if (first.isDeleted || second.isDeleted) {
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

  String get _searchCounterText {
    if (_searchController.text.trim().isEmpty) {
      return '';
    }

    if (_searchResultIds.isEmpty) {
      return '0 / 0';
    }

    return '${_currentSearchResultIndex + 1} / ${_searchResultIds.length}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _isSearching ? _buildSearchAppBar() : _buildNormalAppBar(),
      body: SafeArea(top: false, child: _buildBody()),
    );
  }

  PreferredSizeWidget _buildNormalAppBar() {
    return AppBar(
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
      actions: [
        IconButton(
          onPressed: _startSearch,
          tooltip: 'Nachrichten suchen',
          icon: const Icon(Icons.search_rounded),
        ),
        IconButton(
          onPressed: _showChatMenu,
          tooltip: 'Chat-Inhalte',
          icon: const Icon(Icons.more_vert_rounded),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  PreferredSizeWidget _buildSearchAppBar() {
    final hasResults = _searchResultIds.isNotEmpty;

    return AppBar(
      leading: IconButton(
        onPressed: _closeSearch,
        tooltip: 'Suche schließen',
        icon: const Icon(Icons.close_rounded),
      ),
      titleSpacing: 0,
      title: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        textInputAction: TextInputAction.search,
        decoration: const InputDecoration(
          hintText: 'Nachrichten durchsuchen …',
          border: InputBorder.none,
          isDense: true,
        ),
      ),
      actions: [
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              _searchCounterText,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        IconButton(
          onPressed: hasResults ? _jumpToPreviousSearchResult : null,
          tooltip: 'Vorheriger Treffer',
          icon: const Icon(Icons.keyboard_arrow_up_rounded),
        ),
        IconButton(
          onPressed: hasResults ? _jumpToNextSearchResult : null,
          tooltip: 'Nächster Treffer',
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
        ),
        const SizedBox(width: 2),
      ],
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

    final messageArea = _messages.isEmpty
        ? _buildEmptyChat()
        : _buildMessageList();

    if (_isSearching) {
      return messageArea;
    }

    if (Platform.isIOS) {
      return Column(
        children: [
          Expanded(child: CupertinoInteractiveKeyboard(child: messageArea)),
          CupertinoInputAccessory(child: _buildComposerArea()),
        ],
      );
    }

    return Column(
      children: [
        Expanded(child: messageArea),
        _buildComposerArea(),
      ],
    );
  }

  Widget _buildComposerArea() {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_editingMessage != null)
            _EditComposerPreview(
              content: _editingMessage!.content,
              onCancel: _cancelEdit,
            )
          else if (_replyingTo != null)
            _ReplyComposerPreview(
              senderName: _displayNameForMessage(_replyingTo!),
              content: _replyingTo!.content,
              onCancel: _cancelReply,
            ),
          _buildMessageComposer(),
        ],
      ),
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
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
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

        final reactions = message.isDeleted
            ? <_MessageReaction>[]
            : _reactionsForMessage(message.id);

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
          _AttachmentPlusButton(
            onPressed: _editingMessage != null || _isSending
                ? null
                : _showAttachmentMenu,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _messageController,
              focusNode: _messageFocusNode,
              minLines: 1,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: _editingMessage != null
                    ? 'Nachricht bearbeiten …'
                    : 'Nachricht schreiben …',
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
                : Icon(
                    _editingMessage != null
                        ? Icons.check_rounded
                        : Icons.send_rounded,
                  ),
          ),
        ],
      ),
    );
  }
}

class _AttachmentPlusButton extends StatelessWidget {
  const _AttachmentPlusButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Ink(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: onPressed == null
                  ? [
                      colors.surfaceContainerHighest,
                      colors.surfaceContainerHigh,
                    ]
                  : [colors.primary, colors.tertiary],
            ),
            boxShadow: onPressed == null
                ? null
                : [
                    BoxShadow(
                      color: colors.primary.withValues(alpha: 0.28),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
          ),
          child: Icon(
            Icons.add_rounded,
            size: 29,
            color: onPressed == null
                ? colors.onSurfaceVariant
                : colors.onPrimary,
          ),
        ),
      ),
    );
  }
}

class _AttachmentFanMenu extends StatelessWidget {
  const _AttachmentFanMenu({
    required this.animation,
    required this.onClose,
    required this.onPhotoCamera,
    required this.onPhotoLibrary,
    required this.onVideoCamera,
    required this.onVideoLibrary,
  });

  final Animation<double> animation;
  final VoidCallback onClose;
  final VoidCallback onPhotoCamera;
  final VoidCallback onPhotoLibrary;
  final VoidCallback onVideoCamera;
  final VoidCallback onVideoLibrary;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottom = mediaQuery.padding.bottom + 92;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onClose,
              child: const SizedBox.expand(),
            ),
          ),
          Positioned(
            left: 12,
            bottom: bottom,
            child: SizedBox(
              width: 338,
              height: 318,
              child: AnimatedBuilder(
                animation: animation,
                builder: (context, child) {
                  final value = animation.value.clamp(0.0, 1.0);

                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _buildGlowArc(context, value),
                      _FanAction(
                        animation: animation,
                        intervalStart: 0.00,
                        endOffset: const Offset(16, -238),
                        icon: Icons.photo_camera_rounded,
                        label: 'Foto aufnehmen',
                        colors: const [Color(0xFFFF4F83), Color(0xFFFF759C)],
                        onTap: onPhotoCamera,
                      ),
                      _FanAction(
                        animation: animation,
                        intervalStart: 0.10,
                        endOffset: const Offset(78, -184),
                        icon: Icons.photo_library_rounded,
                        label: 'Bild auswählen',
                        colors: const [Color(0xFF238BFF), Color(0xFF5AA8FF)],
                        onTap: onPhotoLibrary,
                      ),
                      _FanAction(
                        animation: animation,
                        intervalStart: 0.20,
                        endOffset: const Offset(120, -120),
                        icon: Icons.videocam_rounded,
                        label: 'Video aufnehmen',
                        colors: const [Color(0xFF7C4DFF), Color(0xFFA06BFF)],
                        onTap: onVideoCamera,
                      ),
                      _FanAction(
                        animation: animation,
                        intervalStart: 0.30,
                        endOffset: const Offset(140, -48),
                        icon: Icons.video_library_rounded,
                        label: 'Video auswählen',
                        colors: const [Color(0xFF16B981), Color(0xFF55D6A7)],
                        onTap: onVideoLibrary,
                      ),
                      Positioned(
                        left: 0,
                        bottom: 0,
                        child: Transform.rotate(
                          angle: value * 0.785398,
                          child: _FanCloseButton(onTap: onClose),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlowArc(BuildContext context, double value) {
    final colors = Theme.of(context).colorScheme;

    return Positioned(
      left: -80,
      bottom: -80,
      child: IgnorePointer(
        child: Opacity(
          opacity: 0.78 * value,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  colors.primary.withValues(alpha: 0.24),
                  colors.tertiary.withValues(alpha: 0.12),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.52, 1.0],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FanAction extends StatelessWidget {
  const _FanAction({
    required this.animation,
    required this.intervalStart,
    required this.endOffset,
    required this.icon,
    required this.label,
    required this.colors,
    required this.onTap,
  });

  final Animation<double> animation;
  final double intervalStart;
  final Offset endOffset;
  final IconData icon;
  final String label;
  final List<Color> colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final intervalEnd = (intervalStart + 0.60).clamp(0.0, 1.0).toDouble();
    final itemAnimation = CurvedAnimation(
      parent: animation,
      curve: Interval(intervalStart, intervalEnd, curve: Curves.easeOutBack),
    );

    return AnimatedBuilder(
      animation: itemAnimation,
      builder: (context, child) {
        final value = itemAnimation.value.clamp(0.0, 1.0);
        final offset = Offset(endOffset.dx * value, endOffset.dy * value);

        return Positioned(
          left: offset.dx,
          bottom: -offset.dy,
          child: Opacity(
            opacity: value,
            child: Transform.scale(
              scale: 0.45 + (0.55 * value),
              alignment: Alignment.bottomLeft,
              child: child,
            ),
          ),
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _FanActionBubble(icon: icon, colors: colors, onTap: onTap),
          const SizedBox(width: 10),
          _FanActionLabel(label: label, onTap: onTap),
        ],
      ),
    );
  }
}

class _FanActionBubble extends StatefulWidget {
  const _FanActionBubble({
    required this.icon,
    required this.colors,
    required this.onTap,
  });

  final IconData icon;
  final List<Color> colors;
  final VoidCallback onTap;

  @override
  State<_FanActionBubble> createState() => _FanActionBubbleState();
}

class _FanActionBubbleState extends State<_FanActionBubble> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.90 : 1,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: widget.colors,
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.36),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.colors.first.withValues(alpha: 0.45),
                blurRadius: 22,
                spreadRadius: 1,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Icon(widget.icon, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}

class _FanActionLabel extends StatelessWidget {
  const _FanActionLabel({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF34343C).withValues(alpha: 0.96)
                : Colors.white.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.10)
                  : Colors.black.withValues(alpha: 0.07),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.12),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

class _FanCloseButton extends StatelessWidget {
  const _FanCloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Ink(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [colors.primary, colors.tertiary],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.32),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: colors.primary.withValues(alpha: 0.42),
                blurRadius: 22,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Icon(Icons.close_rounded, color: colors.onPrimary, size: 30),
        ),
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
  const _MessageActionCard({
    required this.isMine,
    required this.onReply,
    required this.onEdit,
    required this.onDelete,
  });

  final bool isMine;
  final VoidCallback onReply;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

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
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _MessageActionRow(
              icon: Icons.reply_rounded,
              label: 'Antworten',
              foregroundColor: foregroundColor,
              onTap: onReply,
            ),
            if (isMine) ...[
              Divider(height: 1, thickness: 1, color: borderColor),
              _MessageActionRow(
                icon: Icons.edit_outlined,
                label: 'Bearbeiten',
                foregroundColor: foregroundColor,
                onTap: onEdit!,
              ),
              Divider(height: 1, thickness: 1, color: borderColor),
              _MessageActionRow(
                icon: Icons.delete_outline_rounded,
                label: 'Löschen',
                foregroundColor: Colors.redAccent,
                onTap: onDelete!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MessageActionRow extends StatelessWidget {
  const _MessageActionRow({
    required this.icon,
    required this.label,
    required this.foregroundColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color foregroundColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 48,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            children: [
              Icon(icon, color: foregroundColor, size: 22),
              const SizedBox(width: 12),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: foregroundColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditComposerPreview extends StatelessWidget {
  const _EditComposerPreview({required this.content, required this.onCancel});

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
                    'Nachricht bearbeiten',
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
              tooltip: 'Bearbeiten abbrechen',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close_rounded, size: 20),
            ),
          ],
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
      colors.primary.withValues(alpha: 0.22),
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
              if (widget.message.isDeleted) {
                return;
              }

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
                  if (widget.repliedMessage != null &&
                      !widget.message.isDeleted) ...[
                    _ReplyBubblePreview(
                      senderName:
                          widget.repliedSenderName ?? 'Familienmitglied',
                      content: widget.repliedMessage!.isDeleted
                          ? 'Diese Nachricht wurde gelöscht.'
                          : widget.repliedMessage!.content,
                      isMine: widget.isMine,
                      isDeleted: widget.repliedMessage!.isDeleted,
                      onTap: widget.onReplyTap,
                    ),
                    const SizedBox(height: 6),
                  ],
                  Align(
                    alignment: Alignment.centerLeft,
                    child: widget.message.isDeleted
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.block_rounded,
                                size: 17,
                                color: colors.onSurfaceVariant,
                              ),
                              const SizedBox(width: 7),
                              Flexible(
                                child: Text(
                                  'Diese Nachricht wurde gelöscht.',
                                  style: Theme.of(context).textTheme.bodyLarge
                                      ?.copyWith(
                                        color: colors.onSurfaceVariant,
                                        fontStyle: FontStyle.italic,
                                      ),
                                ),
                              ),
                            ],
                          )
                        : Text(
                            widget.message.content,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.message.isEdited &&
                          !widget.message.isDeleted) ...[
                        Text(
                          'bearbeitet',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '•',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                        const SizedBox(width: 5),
                      ],
                      Text(
                        _formatTime(widget.message.createdAt),
                        style: Theme.of(context).textTheme.labelSmall
                            ?.copyWith(color: colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (reactionGroups.isNotEmpty && !widget.message.isDeleted)
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
    required this.isDeleted,
    required this.onTap,
  });

  final String senderName;
  final String content;
  final bool isMine;
  final bool isDeleted;
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
            border: Border(
              left: BorderSide(
                color: isDeleted ? colors.outline : colors.primary,
                width: 3,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                senderName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: isDeleted ? colors.onSurfaceVariant : colors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontStyle: isDeleted ? FontStyle.italic : FontStyle.normal,
                ),
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
    this.deletedAt,
  });

  final String id;
  final String chatId;
  final String senderId;
  final String content;
  final String? replyToMessageId;
  final DateTime? editedAt;
  final DateTime? deletedAt;
  final DateTime createdAt;

  bool get isDeleted => deletedAt != null;

  bool get isEdited => editedAt != null && deletedAt == null;

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
      deletedAt: map['deleted_at'] == null
          ? null
          : DateTime.parse(map['deleted_at'] as String),
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
