import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/review.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';
import '../models/enums.dart';
import 'chat_database_service.dart';

final aiReviewServiceProvider = Provider<AiReviewService>((ref) {
  return AiReviewService();
});

class AiReviewService {
  static const String _baseUrl = 'https://api.openai.com/v1';
  static const String _apiKey = 'your-openai-api-key'; // TODO: Move to environment variables
  
  // Analyze conversation and images to generate review suggestion
  Future<AiReviewSuggestion> generateReviewSuggestion({
    required String reviewerId,
    required String targetUserId,
    required UserModel reviewer,
    required UserModel targetUser,
  }) async {
    try {
      // Get conversation from last 24 hours
      final conversationData = await _getRecentConversation(reviewerId, targetUserId);
      
      // Get images from last 24 hours
      final imageData = await _getRecentImages(reviewerId, targetUserId);
      
      // Generate review based on roles
      final suggestion = await _generateReviewWithAI(
        reviewer: reviewer,
        targetUser: targetUser,
        conversationData: conversationData,
        imageData: imageData,
      );
      
      return suggestion;
    } catch (e) {
      print('Error generating AI review suggestion: $e');
      // Return default suggestion on error
      return AiReviewSuggestion(
        suggestedRating: 3.0,
        suggestedComment: 'Had a good experience overall.',
        conversationHighlights: [],
        imageAnalysis: [],
        analysisReasoning: 'Unable to analyze conversation data.',
      );
    }
  }

  // Get conversation messages from last 24 hours
  Future<List<MessageModel>> _getRecentConversation(String user1Id, String user2Id) async {
    try {
      // TODO: Implement getMessagesSince in ChatDatabaseService
      // For now, return empty list until the method is implemented
      return [];
      
      // final yesterday = DateTime.now().subtract(const Duration(hours: 24));
      // final messages = await ChatDatabaseService.getMessagesSince(
      //   user1Id: user1Id,
      //   user2Id: user2Id,
      //   since: yesterday,
      // );
      // return messages;
    } catch (e) {
      print('Error getting recent conversation: $e');
      return [];
    }
  }

  // Get images from last 24 hours
  Future<List<MessageModel>> _getRecentImages(String user1Id, String user2Id) async {
    try {
      // TODO: Implement getMessagesSince in ChatDatabaseService
      // For now, return empty list until the method is implemented
      return [];
      
      // final yesterday = DateTime.now().subtract(const Duration(hours: 24));
      // final messages = await ChatDatabaseService.getMessagesSince(
      //   user1Id: user1Id,
      //   user2Id: user2Id,
      //   since: yesterday,
      // );
      // return messages.where((msg) => msg.type == MessageType.image).toList();
    } catch (e) {
      print('Error getting recent images: $e');
      return [];
    }
  }

  // Generate review using OpenAI API
  Future<AiReviewSuggestion> _generateReviewWithAI({
    required UserModel reviewer,
    required UserModel targetUser,
    required List<MessageModel> conversationData,
    required List<MessageModel> imageData,
  }) async {
    try {
      // Create conversation summary
      final conversationSummary = _createConversationSummary(conversationData, targetUser.uid);
      
      // Analyze images
      final imageAnalysis = await _analyzeImages(imageData);
      
      // Create context-aware prompt
      final prompt = _createReviewPrompt(
        reviewer: reviewer,
        targetUser: targetUser,
        conversationSummary: conversationSummary,
        imageAnalysis: imageAnalysis,
      );
      
      // Make API call to OpenAI
      final response = await _callOpenAI(prompt);
      
      // Parse response
      return _parseAIResponse(response, conversationSummary, imageAnalysis);
    } catch (e) {
      print('Error generating AI review: $e');
      rethrow;
    }
  }

  // Create conversation summary for analysis
  String _createConversationSummary(List<MessageModel> messages, String targetUserId) {
    if (messages.isEmpty) return 'No recent conversation found.';
    
    final summary = StringBuffer();
    final targetMessages = messages.where((msg) => msg.senderId == targetUserId).toList();
    final reviewerMessages = messages.where((msg) => msg.senderId != targetUserId).toList();
    
    summary.writeln('Conversation Summary (Last 24 hours):');
    summary.writeln('Total messages: ${messages.length}');
    summary.writeln('Target user messages: ${targetMessages.length}');
    summary.writeln('Reviewer messages: ${reviewerMessages.length}');
    
    // Check for communication patterns
    if (targetMessages.isEmpty) {
      summary.writeln('⚠️ Target user did not send any messages.');
    } else {
      // Analyze response time and communication quality
      final responsePatterns = _analyzeResponsePatterns(messages, targetUserId);
      summary.writeln('Response patterns: $responsePatterns');
    }
    
    // Include actual message content (limited)
    summary.writeln('\nKey messages:');
    for (final message in messages.take(10)) {
      final sender = message.senderId == targetUserId ? 'Target' : 'Reviewer';
      summary.writeln('$sender: ${message.content}');
    }
    
    return summary.toString();
  }

  // Analyze response patterns for communication quality
  String _analyzeResponsePatterns(List<MessageModel> messages, String targetUserId) {
    final patterns = <String>[];
    
    // Sort messages by createdAt
    messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    
    // Analyze response times
    final targetMessages = messages.where((msg) => msg.senderId == targetUserId).toList();
    final reviewerMessages = messages.where((msg) => msg.senderId != targetUserId).toList();
    
    if (targetMessages.isEmpty) {
      patterns.add('No responses from target user');
    } else {
      // Check for delayed responses
      for (int i = 0; i < reviewerMessages.length; i++) {
        final reviewerMsg = reviewerMessages[i];
        final nextTargetMsg = targetMessages.firstWhere(
          (msg) => msg.createdAt.isAfter(reviewerMsg.createdAt),
          orElse: () => MessageModel(
            id: '',
            chatId: '',
            senderId: '',
            senderUsername: '',
            content: '',
            createdAt: DateTime.now().add(const Duration(hours: 1)),
            type: MessageType.text,
          ),
        );
        
        if (nextTargetMsg.id.isNotEmpty) {
          final responseTime = nextTargetMsg.createdAt.difference(reviewerMsg.createdAt);
          if (responseTime.inMinutes > 60) {
            patterns.add('Delayed response: ${responseTime.inHours}h ${responseTime.inMinutes % 60}m');
          }
        }
      }
    }
    
    return patterns.join(', ');
  }

  // Analyze images using OpenAI Vision API
  Future<List<String>> _analyzeImages(List<MessageModel> imageMessages) async {
    final analyses = <String>[];
    
    for (final message in imageMessages.take(5)) { // Limit to 5 images
      try {
        if (message.content.isNotEmpty) {
          final analysis = await _analyzeImageWithAI(message.content);
          analyses.add(analysis);
        }
      } catch (e) {
        print('Error analyzing image: $e');
        analyses.add('Unable to analyze image');
      }
    }
    
    return analyses;
  }

  // Analyze single image with OpenAI Vision
  Future<String> _analyzeImageWithAI(String imageUrl) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/chat/completions'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'gpt-4-vision-preview',
          'messages': [
            {
              'role': 'user',
              'content': [
                {
                  'type': 'text',
                  'text': 'Analyze this image in the context of dog walking or pet care. Focus on: 1) Dog\'s apparent mood/happiness, 2) Environment quality, 3) Care quality indicators. Be specific and balanced.',
                },
                {
                  'type': 'image_url',
                  'image_url': {'url': imageUrl}
                }
              ]
            }
          ],
          'max_tokens': 200,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'];
      } else {
        return 'Unable to analyze image';
      }
    } catch (e) {
      print('Error in image analysis: $e');
      return 'Image analysis failed';
    }
  }

  // Create context-aware prompt for review generation
  String _createReviewPrompt({
    required UserModel reviewer,
    required UserModel targetUser,
    required String conversationSummary,
    required List<String> imageAnalysis,
  }) {
    final targetRole = targetUser.isWalker ? 'dog walker' : 'dog owner';
    final reviewerRole = reviewer.isWalker ? 'dog walker' : 'dog owner';
    
    return '''
You are helping to generate a balanced review for a $targetRole based on recent interactions.

Context:
- Reviewer: $reviewerRole (${reviewer.displayName})
- Target: $targetRole (${targetUser.displayName})
- Review Type: ${reviewer.isOwner ? 'Owner reviewing Walker' : 'Walker reviewing Owner'}

Conversation Analysis:
$conversationSummary

Image Analysis:
${imageAnalysis.join('\n')}

Instructions:
1. Generate a balanced review (not overly positive or negative)
2. Focus on communication, reliability, and ${targetUser.isWalker ? 'care quality' : 'cooperation'}
3. Mention specific observations from the conversation and images
4. Provide a rating from 1-5 (can use decimals like 3.5)
5. Keep the review concise but informative
6. Be fair and objective

Output format:
{
  "rating": 3.5,
  "comment": "Detailed review comment here...",
  "highlights": ["key observation 1", "key observation 2"],
  "reasoning": "Brief explanation of the rating"
}
''';
  }

  // Call OpenAI API
  Future<String> _callOpenAI(String prompt) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/chat/completions'),
      headers: {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'gpt-4',
        'messages': [
          {'role': 'user', 'content': prompt}
        ],
        'max_tokens': 500,
        'temperature': 0.7,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'];
    } else {
      throw Exception('OpenAI API error: ${response.statusCode}');
    }
  }

  // Parse AI response into structured format
  AiReviewSuggestion _parseAIResponse(
    String response, 
    String conversationSummary, 
    List<String> imageAnalysis,
  ) {
    try {
      // Try to parse JSON response
      final jsonStart = response.indexOf('{');
      final jsonEnd = response.lastIndexOf('}') + 1;
      
      if (jsonStart >= 0 && jsonEnd > jsonStart) {
        final jsonStr = response.substring(jsonStart, jsonEnd);
        final data = jsonDecode(jsonStr);
        
        return AiReviewSuggestion(
          suggestedRating: (data['rating'] ?? 3.0).toDouble(),
          suggestedComment: data['comment'] ?? 'No specific feedback available.',
          conversationHighlights: List<String>.from(data['highlights'] ?? []),
          imageAnalysis: imageAnalysis,
          analysisReasoning: data['reasoning'] ?? 'Analysis completed.',
        );
      }
    } catch (e) {
      print('Error parsing AI response: $e');
    }
    
    // Fallback parsing
    return AiReviewSuggestion(
      suggestedRating: 3.0,
      suggestedComment: response.isNotEmpty ? response : 'Review generated based on recent interactions.',
      conversationHighlights: [],
      imageAnalysis: imageAnalysis,
      analysisReasoning: 'Basic analysis completed.',
    );
  }
}

// Extension to ChatDatabaseService for time-based queries
extension ChatDatabaseServiceExtension on ChatDatabaseService {
  static Future<List<MessageModel>> getMessagesSince({
    required String user1Id,
    required String user2Id,
    required DateTime since,
  }) async {
    try {
      // This would need to be implemented in the actual ChatDatabaseService
      // For now, return empty list
      return [];
    } catch (e) {
      print('Error getting messages since: $e');
      return [];
    }
  }
} 