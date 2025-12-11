import 'package:flutter/material.dart';
import '../services/voice_service.dart';

/// Bottom sheet widget that displays real-time speech transcription
class ListeningSheet extends StatefulWidget {
  final Function(String) onTextReceived;
  final VoidCallback? onCancel;

  const ListeningSheet({
    super.key,
    required this.onTextReceived,
    this.onCancel,
  });

  @override
  State<ListeningSheet> createState() => _ListeningSheetState();
}

class _ListeningSheetState extends State<ListeningSheet>
    with SingleTickerProviderStateMixin {
  String _transcription = '';
  bool _isListening = true;
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    
    // Start listening when sheet opens
    _startListening();
  }
  
  Future<void> _startListening() async {
    final result = await VoiceService.listen(
      onTranscription: (text) {
        if (mounted) {
          setState(() {
            _transcription = text;
          });
        }
      },
    );
    
    if (!mounted) return;
    
    if (result != null && result.isNotEmpty) {
      widget.onTextReceived(result);
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(result);
      }
    } else if (_transcription.isNotEmpty) {
      widget.onTextReceived(_transcription);
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(_transcription);
      }
    }
  }

  @override
  void dispose() {
    VoiceService.stop();
    VoiceService.cancel();
    _animationController.dispose();
    super.dispose();
  }


  void stopListening() {
    if (mounted) {
      setState(() {
        _isListening = false;
      });
      _animationController.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Listening indicator with animation
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _isListening ? _pulseAnimation.value : 1.0,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: _isListening
                              ? [
                                  theme.colorScheme.primary,
                                  theme.colorScheme.primary.withOpacity(0.7),
                                ]
                              : [
                                  theme.colorScheme.outline.withOpacity(0.3),
                                  theme.colorScheme.outline.withOpacity(0.2),
                                ],
                        ),
                        boxShadow: _isListening
                            ? [
                                BoxShadow(
                                  color: theme.colorScheme.primary.withOpacity(0.4),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ]
                            : null,
                      ),
                      child: Icon(
                        Icons.mic,
                        size: 40,
                        color: _isListening
                            ? Colors.white
                            : theme.colorScheme.outline,
                      ),
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 24),
              
              // Status text
              Text(
                _isListening ? 'Listening...' : 'Processing...',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Transcription text
              Container(
                constraints: const BoxConstraints(maxHeight: 150),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _transcription.isEmpty
                        ? (_isListening
                            ? 'Speak your event...'
                            : 'Processing your request...')
                        : _transcription,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: _transcription.isEmpty
                          ? theme.colorScheme.onSurface.withOpacity(0.5)
                          : theme.colorScheme.onSurface,
                      fontStyle: _transcription.isEmpty
                          ? FontStyle.italic
                          : FontStyle.normal,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Cancel button
                  TextButton.icon(
                    onPressed: () {
                      VoiceService.stop();
                      VoiceService.cancel();
                      stopListening();
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      }
                    },
                    icon: const Icon(Icons.close),
                    label: const Text('Cancel'),
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                  ),
                  
                  // Stop/Submit button
                  ElevatedButton.icon(
                    onPressed: () {
                      VoiceService.stop();
                      stopListening();
                      if (_transcription.isNotEmpty) {
                        widget.onTextReceived(_transcription);
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop(_transcription);
                        }
                      } else {
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        }
                      }
                    },
                    icon: Icon(_isListening ? Icons.stop : Icons.check),
                    label: Text(_isListening ? 'Stop' : 'Done'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

