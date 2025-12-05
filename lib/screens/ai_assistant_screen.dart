import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/gemini_service.dart';
import '../services/calendar_action_parser.dart';
import '../models/calendar_action.dart';
import '../models/event.dart';
import '../models/note.dart';
import '../providers/event_provider.dart';
import '../providers/note_provider.dart';

class AIAssistantScreen extends StatefulWidget {
  const AIAssistantScreen({super.key});

  @override
  State<AIAssistantScreen> createState() => _AIAssistantScreenState();
}

class _AIAssistantScreenState extends State<AIAssistantScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _addWelcomeMessage();
  }

  void _addWelcomeMessage() {
    _messages.add(ChatMessage(
      text: 'Merhaba! Ben SmartCalendar AI asistanınızım. Size nasıl yardımcı olabilirim?\n\n'
          '💡 İpucu: Bana "Yarın saat 2\'de John\'u ara" veya "Cuma günü spor salonu ekle" gibi komutlar vererek takviminize etkinlik ve notlar ekleyebilirsiniz.',
      isUser: false,
      timestamp: DateTime.now(),
    ));
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _isLoading) return;

    setState(() {
      _messages.add(ChatMessage(
        text: message,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isLoading = true;
    });

    _messageController.clear();
    _scrollToBottom();

    try {
      // Use calendar message method which includes system prompt
      final result = await GeminiService.sendCalendarMessage(message);
      final responseText = result['response'] as String;
      final hasCalendarAction = result['hasCalendarAction'] as bool;

      // Try to parse calendar action from response
      CalendarAction? calendarAction;
      if (hasCalendarAction) {
        calendarAction = CalendarActionParser.parseResponse(responseText);
      }

      String finalResponse = responseText;

      // If calendar action was parsed, save it and update response
      if (calendarAction != null) {
        // Pass user message to save function so it can be stored in JSON format
        final saved = await _saveCalendarAction(calendarAction, userMessage: message);
        if (saved) {
          finalResponse = _generateConfirmationMessage(calendarAction);
        } else {
          finalResponse = 'Üzgünüm, takvime eklerken bir hata oluştu.';
        }
      }

      setState(() {
        _messages.add(ChatMessage(
          text: finalResponse,
          isUser: false,
          timestamp: DateTime.now(),
        ));
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(
          text: 'Bir hata oluştu: ${e.toString()}',
          isUser: false,
          timestamp: DateTime.now(),
        ));
        _isLoading = false;
      });
    }

    _scrollToBottom();
  }

  /// Save calendar action to database
  Future<bool> _saveCalendarAction(CalendarAction action, {required String userMessage}) async {
    try {
      if (action.type == 'event') {
        // Create Event
        final event = Event(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: action.title,
          date: action.datetime,
          description: action.description,
          time: DateFormat('HH:mm').format(action.datetime),
        );

        final eventProvider = Provider.of<EventProvider>(context, listen: false);
        await eventProvider.addEvent(event);
        return true;
      } else if (action.type == 'note') {
        // Create Note with JSON formatted content
        // Content will contain the JSON representation of the calendar action
        final jsonContent = jsonEncode({
          'userMessage': userMessage,
          'title': action.title,
          'description': action.description,
          'datetime': action.datetime.toIso8601String(),
          'type': action.type,
        });

        final note = Note(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          eventId: '', // Standalone note, not attached to an event
          content: jsonContent, // JSON formatında kullanıcı mesajı ve action bilgileri
          createdAt: DateTime.now(),
          title: action.title, // Title olarak action title'ı kullan
          date: action.datetime,
        );

        final noteProvider = Provider.of<NoteProvider>(context, listen: false);
        await noteProvider.addNote(note);
        
        // Force reload to ensure the note appears in the calendar
        await noteProvider.loadNotes();
        
        debugPrint('Note saved successfully: ${note.id}');
        debugPrint('Note date: ${note.date}');
        debugPrint('Note title: ${note.title}');
        
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error saving calendar action: $e');
      return false;
    }
  }

  /// Generate confirmation message for calendar action
  String _generateConfirmationMessage(CalendarAction action) {
    final dateFormat = DateFormat('d MMMM yyyy', 'tr_TR');
    final timeFormat = DateFormat('HH:mm');
    final formattedDate = dateFormat.format(action.datetime);
    final formattedTime = timeFormat.format(action.datetime);

    if (action.type == 'event') {
      return '✅ "${action.title}" etkinliğini takviminize ${formattedDate} tarihinde saat ${formattedTime} için ekledim.';
    } else {
      return '✅ "${action.title}" notunu takviminize ${formattedDate} tarihinde saat ${formattedTime} için ekledim.';
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
              Theme.of(context).colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.arrow_back_rounded,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.teal,
                            Colors.teal.withOpacity(0.7),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.teal.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AI Asistan',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'SmartCalendar AI',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Messages
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(20),
                  itemCount: _messages.length + (_isLoading ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _messages.length) {
                      return _buildLoadingIndicator();
                    }
                    return _buildMessage(_messages[index]);
                  },
                ),
              ),
              // Input Area
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          decoration: InputDecoration(
                            hintText: 'Mesajınızı yazın...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(
                                color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(
                                color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(
                                color: Theme.of(context).colorScheme.primary,
                                width: 2,
                              ),
                            ),
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                          ),
                          maxLines: null,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.teal,
                              Colors.teal.withOpacity(0.7),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.teal.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: IconButton(
                          onPressed: _isLoading ? null : _sendMessage,
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.send_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessage(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.teal,
                    Colors.teal.withOpacity(0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: message.isUser
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(20).copyWith(
                  topRight: message.isUser
                      ? const Radius.circular(4)
                      : const Radius.circular(20),
                  topLeft: message.isUser
                      ? const Radius.circular(20)
                      : const Radius.circular(4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                message.text,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: message.isUser
                          ? Theme.of(context).colorScheme.onPrimaryContainer
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
              ),
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.person,
                color: Colors.white,
                size: 20,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.teal,
                  Colors.teal.withOpacity(0.7),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(20).copyWith(
                topLeft: const Radius.circular(4),
              ),
            ),
            child: const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}


