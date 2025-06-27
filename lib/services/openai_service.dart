import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';

final openAIServiceProvider = Provider<OpenAIService>((ref) {
  return OpenAIService();
});

class OpenAIService {
  static const String _baseUrl = 'https://api.openai.com/v1/chat/completions';

  String get _apiKey {
    final apiKey = dotenv.env['OPENAI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('OpenAI API key not found. Please check your .env file.');
    }
    return apiKey;
  }

  /// Test method to verify API key is loaded correctly
  bool isApiKeyConfigured() {
    try {
      final apiKey = _apiKey;
      return apiKey.isNotEmpty && apiKey.startsWith('sk-');
    } catch (e) {
      return false;
    }
  }

  Future<List<String>> generateTextRecommendations({
    required List<MessageModel> recentMessages,
    required UserModel currentUser,
    UserModel? otherUser,
    String? lastMessage,
  }) async {
    try {
      // Prepare conversation context
      final conversationContext = _buildConversationContext(
        recentMessages: recentMessages,
        currentUser: currentUser,
        otherUser: otherUser,
        lastMessage: lastMessage,
      );

      // Build the prompt
      final prompt = _buildPrompt(conversationContext, currentUser, otherUser);

      // Make API call to OpenAI
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-4o-mini',
          'messages': [
            {
              'role': 'system',
              'content': '''You are a helpful assistant that suggests text responses for a dog walking app chat. 
              Generate exactly 3 short, natural, and contextually appropriate message suggestions.
              Keep suggestions under 15 words each.
              If someone is asking about a dog, suggest sending a picture as one of the options.
              Return responses as a JSON array of strings.
              Example: ["That sounds great!", "When would work for you?", "📷 Send a picture"]'''
            },
            {
              'role': 'user',
              'content': prompt,
            }
          ],
          'max_tokens': 150,
          'temperature': 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        
        // Parse the JSON response
        try {
          final List<dynamic> suggestions = jsonDecode(content);
          return suggestions.cast<String>().take(3).toList();
        } catch (e) {
          // Fallback if JSON parsing fails
          return _parseFallbackSuggestions(content);
        }
      } else {
        print('OpenAI API Error: ${response.statusCode} - ${response.body}');
        return _getFallbackSuggestions(lastMessage);
      }
    } catch (e) {
      print('Error generating text recommendations: $e');
      return _getFallbackSuggestions(lastMessage);
    }
  }

  String _buildConversationContext({
    required List<MessageModel> recentMessages,
    required UserModel currentUser,
    UserModel? otherUser,
    String? lastMessage,
  }) {
    final context = StringBuffer();
    
    // Add user roles context
    context.writeln('Chat between:');
    context.writeln('- ${currentUser.displayName} (${currentUser.roleText})');
    if (otherUser != null) {
      context.writeln('- ${otherUser.displayName} (${otherUser.roleText})');
    }
    context.writeln();

    // Add recent messages (last 5 for context)
    if (recentMessages.isNotEmpty) {
      context.writeln('Recent conversation:');
      final messagesToInclude = recentMessages.take(5).toList().reversed;
      
      for (final message in messagesToInclude) {
        final isCurrentUser = message.senderId == currentUser.uid;
        final senderName = isCurrentUser ? 'Me' : (otherUser?.displayName ?? 'Other');
        
        if (message.type == MessageType.text) {
          context.writeln('$senderName: ${message.content}');
        } else if (message.type == MessageType.image) {
          context.writeln('$senderName: [sent an image]');
        }
      }
    }

    if (lastMessage != null && lastMessage.isNotEmpty) {
      context.writeln('Last message: $lastMessage');
    }

    return context.toString();
  }

  String _buildPrompt(String conversationContext, UserModel currentUser, UserModel? otherUser) {
    final prompt = StringBuffer();
    
    prompt.writeln('Context: This is a dog walking app where owners find walkers for their dogs.');
    prompt.writeln(conversationContext);
    prompt.writeln();
    prompt.writeln('Generate 3 helpful response suggestions for ${currentUser.displayName}.');
    prompt.writeln('Consider the context of dog walking, scheduling, and pet care.');
    prompt.writeln('If someone asked about a dog, include a picture suggestion.');
    prompt.writeln('Keep responses friendly, professional, and brief.');

    return prompt.toString();
  }

  List<String> _parseFallbackSuggestions(String content) {
    // Try to extract suggestions from non-JSON format
    final lines = content.split('\n')
        .where((line) => line.trim().isNotEmpty)
        .map((line) => line.replaceAll(RegExp(r'^[\d\-\*\.\s]+'), '').trim())
        .where((line) => line.isNotEmpty)
        .take(3)
        .toList();
    
    if (lines.isNotEmpty) {
      return lines;
    }
    
    return ['Thanks!', 'Sounds good', 'Let me know'];
  }

  List<String> _getFallbackSuggestions(String? lastMessage) {
    // Provide contextual fallback suggestions
    if (lastMessage != null) {
      final lowerMessage = lastMessage.toLowerCase();
      
      if (lowerMessage.contains('dog') || lowerMessage.contains('pet')) {
        return ['📷 Send a picture', 'That sounds great!', 'When works for you?'];
      }
      
      if (lowerMessage.contains('when') || lowerMessage.contains('time')) {
        return ['How about tomorrow?', 'I\'m flexible', 'What time works?'];
      }
      
      if (lowerMessage.contains('walk') || lowerMessage.contains('exercise')) {
        return ['Sounds perfect!', 'How long?', 'Where would you like?'];
      }
      
      if (lowerMessage.contains('thank') || lowerMessage.contains('great')) {
        return ['You\'re welcome!', 'Happy to help!', 'Anytime!'];
      }
    }
    
    // Default suggestions
    return ['Thanks!', 'Sounds good', 'Let me know'];
  }

  bool _shouldSuggestPicture(List<MessageModel> recentMessages, String? lastMessage) {
    // Check if recent conversation mentions dogs
    for (final message in recentMessages.take(3)) {
      if (message.type == MessageType.text) {
        final content = message.content.toLowerCase();
        if (content.contains('dog') || content.contains('pet') || 
            content.contains('puppy') || content.contains('how is')) {
          return true;
        }
      }
    }
    
    if (lastMessage != null) {
      final lowerMessage = lastMessage.toLowerCase();
      return lowerMessage.contains('dog') || lowerMessage.contains('pet') || 
             lowerMessage.contains('puppy') || lowerMessage.contains('how is');
    }
    
    return false;
  }
} 