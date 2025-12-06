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
      text: 'Hello! I am your SmartCalendar AI assistant. How can I help you?\n\n'
          '📅 To add events to your calendar: "Call John tomorrow at 2 PM" or "Add gym on Friday"\n\n'
          '❓ To ask questions about your calendar: "What\'s on Tuesday?", "What\'s my schedule next week?", "Do I have time to study?"',
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
      // Check if this is a question about the schedule (Q&A mode)
      final isScheduleQuestion = _isScheduleQuestion(message);
      
      if (isScheduleQuestion) {
        // Q&A Mode: Get calendar context and ask question
        debugPrint('Detected schedule question, using Q&A mode');
        
        final eventProvider = Provider.of<EventProvider>(context, listen: false);
        final noteProvider = Provider.of<NoteProvider>(context, listen: false);
        
        // Get upcoming events and notes as text
        final eventsText = eventProvider.getUpcomingEventsAsText(days: 14);
        final notesText = noteProvider.getUpcomingNotesAsText(days: 14);
        
        // Combine both into calendar context
        final calendarContext = '''EVENTS:
$eventsText

NOTES:
$notesText''';
        
        debugPrint('Calendar context length: ${calendarContext.length} characters');
        
        // Ask the question with calendar context
        final responseText = await GeminiService.askCalendar(message, calendarContext);
        
        setState(() {
          _messages.add(ChatMessage(
            text: responseText,
            isUser: false,
            timestamp: DateTime.now(),
          ));
          _isLoading = false;
        });
      } else {
        // Add Mode: Use existing calendar message method
        final result = await GeminiService.sendCalendarMessage(message);
        final responseText = result['response'] as String;

        // Try to parse calendar action from response
        // ALWAYS try to parse to ensure we capture every request
        CalendarAction? calendarAction = CalendarActionParser.parseResponse(responseText);
        
        // If no JSON was found but response contains calendar intent, create a note anyway
        if (calendarAction == null && CalendarActionParser.hasCalendarIntent(responseText)) {
          debugPrint('No JSON found but calendar intent detected, creating fallback note');
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
            finalResponse = 'Sorry, an error occurred while adding to calendar.';
          }
        } else {
          // Even if parsing failed, if the message seems calendar-related, create a note
          if (CalendarActionParser.hasCalendarIntent(message)) {
            debugPrint('Creating note from user message directly');
            final fallbackAction = CalendarAction(
              noteContent: message,
              datetime: DateTime.now(),
              isAllDay: true,
              type: 'note',
            );
            final saved = await _saveCalendarAction(fallbackAction, userMessage: message);
            if (saved) {
              finalResponse = '✅ Your note has been added to calendar: "$message"';
            }
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
      }

    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(
          text: 'An error occurred: ${e.toString()}',
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
          title: action.displayTitle, // Use displayTitle which is always non-null
          date: action.datetime,
          description: action.description ?? action.noteContent, // Use noteContent as fallback
          time: DateFormat('HH:mm').format(action.datetime),
        );

        final eventProvider = Provider.of<EventProvider>(context, listen: false);
        await eventProvider.addEvent(event);
        return true;
      } else if (action.type == 'note' || action.type == null) {
        // Create Note with note_content as primary content
        // Store the full JSON representation for reference
        final jsonContent = jsonEncode({
          'userMessage': userMessage,
          'note_content': action.noteContent,
          'datetime': action.datetime.toIso8601String(),
          'is_all_day': action.isAllDay,
          // Legacy fields for backward compatibility
          if (action.title != null) 'title': action.title,
          if (action.description != null) 'description': action.description,
          'type': action.type ?? 'note',
        });

        // Use noteContent as the primary content, with JSON as metadata
        // For display, we'll use noteContent directly
        final note = Note(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          eventId: '', // Standalone note, not attached to an event
          content: action.noteContent, // Use note_content as primary content
          createdAt: DateTime.now(),
          title: action.displayTitle.isNotEmpty ? action.displayTitle : action.noteContent.split('\n').first, // Use display title for UI, fallback to first line of content
          date: action.datetime,
        );

        final noteProvider = Provider.of<NoteProvider>(context, listen: false);
        await noteProvider.addNote(note);
        
        // Force reload to ensure the note appears in the calendar
        await noteProvider.loadNotes();
        
        debugPrint('Note saved successfully: ${note.id}');
        debugPrint('Note date: ${note.date}');
        debugPrint('Note content: ${note.content}');
        debugPrint('Note title: ${note.title}');
        debugPrint('Full JSON: $jsonContent');
        
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
    final dateFormat = DateFormat('d MMMM yyyy', 'en_US');
    final timeFormat = DateFormat('HH:mm');
    final formattedDate = dateFormat.format(action.datetime);
    
    final displayText = action.displayTitle;
    
    if (action.isAllDay) {
      return '✅ I added "$displayText" to your calendar for ${formattedDate} (all day).';
    } else {
      final formattedTime = timeFormat.format(action.datetime);
      return '✅ I added "$displayText" to your calendar for ${formattedDate} at ${formattedTime}.';
    }
  }

  /// Check if the message is a question about the schedule (Q&A mode)
  /// vs a command to add something (Add mode)
  bool _isScheduleQuestion(String message) {
    final lowerMessage = message.toLowerCase();
    
    // Question keywords
    final questionKeywords = [
      'ne var',
      'nedir',
      'ne zaman',
      'hangi',
      'var mı',
      'yok mu',
      'program',
      'agenda',
      'schedule',
      'zamanım var mı',
      'müsait mi',
      'boş mu',
      'dolu mu',
      'kaç',
      'nasıl',
      'nerede',
      'kim',
      'hangi gün',
      'hangi saat',
      'ne gün',
      'ne saat',
      'sor',
      'söyle',
      'göster',
      'listele',
      'hakkında',
      'ile ilgili',
    ];
    
    // Add/command keywords (if these are present, it's likely an add command)
    final addKeywords = [
      'ekle',
      'add',
      'oluştur',
      'create',
      'kaydet',
      'save',
      'hatırlat',
      'remind',
      'planla',
      'plan',
      'ayarla',
      'set',
      'yap',
      'do',
    ];
    
    // Check if it contains question keywords
    final hasQuestionKeyword = questionKeywords.any((keyword) => lowerMessage.contains(keyword));
    
    // Check if it contains add keywords
    final hasAddKeyword = addKeywords.any((keyword) => lowerMessage.contains(keyword));
    
    // Check if it ends with question mark
    final endsWithQuestionMark = message.trim().endsWith('?');
    
    // If it has question keywords and doesn't have add keywords, it's likely a question
    if (hasQuestionKeyword && !hasAddKeyword) {
      return true;
    }
    
    // If it ends with question mark and doesn't have add keywords, it's likely a question
    if (endsWithQuestionMark && !hasAddKeyword) {
      return true;
    }
    
    // If it starts with question words, it's likely a question
    if (lowerMessage.startsWith('ne ') || 
        lowerMessage.startsWith('hangi ') ||
        lowerMessage.startsWith('kaç ') ||
        lowerMessage.startsWith('nasıl ') ||
        lowerMessage.startsWith('nerede ') ||
        lowerMessage.startsWith('kim ')) {
      return true;
    }
    
    return false;
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
                            hintText: 'Type your message...',
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


