import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:snapagram/models/message_model.dart';
import 'package:snapagram/models/user_model.dart';
import 'package:snapagram/models/enums.dart';
import 'package:snapagram/services/chat_database_service.dart';

final conversationAnalysisServiceProvider = Provider<ConversationAnalysisService>((ref) {
  return ConversationAnalysisService();
});

/// Service for analyzing conversations and preparing data for AI processing
class ConversationAnalysisService {
  static const String _baseUrl = 'https://api.openai.com/v1';
  
  String get _apiKey {
    final apiKey = dotenv.env['OPENAI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('OpenAI API key not found. Please check your .env file.');
    }
    return apiKey;
  }

  /// Main method to analyze conversation for review generation
  Future<ConversationAnalysis> analyzeConversation({
    required String reviewerId,
    required String targetUserId,
    required UserModel reviewer,
    required UserModel targetUser,
    Duration lookbackPeriod = const Duration(hours: 48), // Extended to 48 hours for better analysis
  }) async {
    try {
      print('🤖 [AI-ANALYSIS] Starting conversation analysis for review...');
      print('🤖 [AI-ANALYSIS] Reviewer: ${reviewer.displayName} (${reviewerId})');
      print('🤖 [AI-ANALYSIS] Target: ${targetUser.displayName} (${targetUserId})');
      
      // Run diagnosis to understand conversation access
      await ChatDatabaseService.diagnoseConversationAccess(
        user1Id: reviewerId,
        user2Id: targetUserId,
      );
      
      // Try different lookback periods if no messages found
      final lookbackPeriods = [
        lookbackPeriod,                    // 48 hours (default)
        const Duration(days: 7),           // 1 week
        const Duration(days: 30),          // 1 month
        const Duration(days: 90),          // 3 months
      ];
      
      List<MessageModel> messages = [];
      List<MessageModel> imageMessages = [];
      Map<String, dynamic> stats = {};
      DateTime actualSince = DateTime.now();
      
      // Try each lookback period until we find messages
      for (final period in lookbackPeriods) {
        final since = DateTime.now().subtract(period);
        print('🤖 [AI-ANALYSIS] Trying lookback period: ${period.inDays} days (since $since)');
        
        // Get conversation data and statistics
        final [messagesResult, imageMessagesResult, statsResult] = await Future.wait([
          ChatDatabaseService.getMessagesSince(
            user1Id: reviewerId,
            user2Id: targetUserId,
            since: since,
          ),
          ChatDatabaseService.getMessagesByTypeSince(
            user1Id: reviewerId,
            user2Id: targetUserId,
            messageType: MessageType.image,
            since: since,
          ),
          ChatDatabaseService.getConversationStats(
            user1Id: reviewerId,
            user2Id: targetUserId,
            since: since,
          ),
        ]);
        
        messages = messagesResult as List<MessageModel>;
        imageMessages = imageMessagesResult as List<MessageModel>;
        stats = statsResult as Map<String, dynamic>;
        actualSince = since;
        
        print('🤖 [AI-ANALYSIS] Found ${messages.length} messages and ${imageMessages.length} images');
        
        // If we found enough messages, break
        if (messages.length >= 3) {
          print('🤖 [AI-ANALYSIS] ✅ Sufficient messages found with ${period.inDays} day lookback');
          break;
        }
      }
      
      if (messages.isEmpty) {
        print('🤖 [AI-ANALYSIS] ❌ No messages found in any lookback period');
        return ConversationAnalysis.empty();
      }

      print('🤖 [AI-ANALYSIS] 📊 Final analysis: ${messages.length} messages, ${imageMessages.length} images');

      // Chunk and analyze text messages
      final conversationChunks = _chunkConversation(
        messages,
        reviewer,
        targetUser,
      );

      // Process images with AI descriptions
      final imageAnalyses = await _processImages(
        imageMessages,
        targetUser,
      );

      // Create comprehensive analysis
      return ConversationAnalysis(
        conversationChunks: conversationChunks,
        imageAnalyses: imageAnalyses,
        conversationStats: ConversationStats.fromMap(stats),
        communicationPatterns: _analyzeCommunicationPatterns(
          messages,
          reviewerId,
          targetUserId,
        ),
        keyInsights: _extractKeyInsights(
          messages,
          imageAnalyses,
          reviewer,
          targetUser,
        ),
        analysisTimestamp: DateTime.now(),
      );
    } catch (e) {
      print('🤖 [AI-ANALYSIS] ❌ Error analyzing conversation: $e');
      return ConversationAnalysis.empty();
    }
  }

  /// Chunk conversation into logical segments for AI processing
  List<ConversationChunk> _chunkConversation(
    List<MessageModel> messages,
    UserModel reviewer,
    UserModel targetUser,
  ) {
    if (messages.isEmpty) return [];

    final chunks = <ConversationChunk>[];
    const maxChunkSize = 15; // Optimal size for AI processing
    const maxTimeGap = Duration(hours: 3); // Break chunks on long gaps

    List<MessageModel> currentChunk = [];
    DateTime? lastMessageTime;

    for (final message in messages) {
      // Start new chunk if time gap is too large or chunk is too big
      if (currentChunk.isNotEmpty && 
          (lastMessageTime != null && 
           message.createdAt.difference(lastMessageTime).abs() > maxTimeGap ||
           currentChunk.length >= maxChunkSize)) {
        
        chunks.add(_createChunk(currentChunk, reviewer, targetUser));
        currentChunk = [];
      }

      currentChunk.add(message);
      lastMessageTime = message.createdAt;
    }

    // Add final chunk
    if (currentChunk.isNotEmpty) {
      chunks.add(_createChunk(currentChunk, reviewer, targetUser));
    }

    return chunks;
  }

  /// Create a conversation chunk with analysis
  ConversationChunk _createChunk(
    List<MessageModel> messages,
    UserModel reviewer,
    UserModel targetUser,
  ) {
    final reviewerMessages = messages.where((m) => m.senderId == reviewer.uid).toList();
    final targetMessages = messages.where((m) => m.senderId == targetUser.uid).toList();

    // Calculate engagement metrics
    final totalWords = messages
        .where((m) => m.type == MessageType.text)
        .map((m) => m.content.split(' ').length)
        .fold(0, (a, b) => a + b);

    final responseRatio = messages.length > 1
        ? targetMessages.length / messages.length
        : 0.0;

    // Identify conversation topics
    final topics = _identifyTopics(messages);

    // Create formatted conversation text
    final conversationText = _formatConversationForAI(messages, reviewer, targetUser);

    return ConversationChunk(
      startTime: messages.first.createdAt,
      endTime: messages.last.createdAt,
      messageCount: messages.length,
      reviewerMessageCount: reviewerMessages.length,
      targetMessageCount: targetMessages.length,
      totalWordCount: totalWords,
      responseRatio: responseRatio,
      topics: topics,
      conversationText: conversationText,
      sentiment: _analyzeSentiment(messages, targetUser.uid),
      urgencyLevel: _assessUrgencyLevel(messages),
    );
  }

  /// Format conversation for AI processing with clear structure
  String _formatConversationForAI(
    List<MessageModel> messages,
    UserModel reviewer,
    UserModel targetUser,
  ) {
    final buffer = StringBuffer();
    
    buffer.writeln('=== CONVERSATION SEGMENT ===');
    buffer.writeln('Timespan: ${messages.first.createdAt} to ${messages.last.createdAt}');
    buffer.writeln('Participants: ${reviewer.displayName} (Reviewer) & ${targetUser.displayName} (Target)');
    buffer.writeln();

    for (final message in messages) {
      final isReviewer = message.senderId == reviewer.uid;
      final senderLabel = isReviewer ? 'REVIEWER' : 'TARGET';
      final timestamp = message.createdAt.toString().substring(11, 16); // HH:MM

      buffer.writeln('[$timestamp] $senderLabel: ${_getMessageContent(message)}');
      
      // Add response time if applicable
      if (messages.indexOf(message) > 0) {
        final prevMessage = messages[messages.indexOf(message) - 1];
        if (prevMessage.senderId != message.senderId) {
          final responseTime = message.createdAt.difference(prevMessage.createdAt);
          if (responseTime.inMinutes > 30) {
            buffer.writeln('    [Response after ${responseTime.inHours}h ${responseTime.inMinutes % 60}m]');
          }
        }
      }
    }

    buffer.writeln('=== END SEGMENT ===\n');
    return buffer.toString();
  }

  /// Get message content with type indicators
  String _getMessageContent(MessageModel message) {
    switch (message.type) {
      case MessageType.text:
        return message.content;
      case MessageType.image:
        return '[SENT IMAGE]';
      case MessageType.video:
        return '[SENT VIDEO]';
      case MessageType.location:
        return '[SHARED LOCATION]';
      case MessageType.contact:
        return '[SHARED CONTACT]';
      default:
        return '[${message.type.name.toUpperCase()}]';
    }
  }

  /// Process images with AI analysis and convert to text descriptions
  Future<List<ImageAnalysis>> _processImages(
    List<MessageModel> imageMessages,
    UserModel targetUser,
  ) async {
    final analyses = <ImageAnalysis>[];
    
    // Process up to 10 most recent images to avoid API costs
    final imagesToProcess = imageMessages.take(10).toList();
    
    for (final message in imagesToProcess) {
      try {
        final analysis = await _analyzeImageWithAI(message, targetUser);
        analyses.add(analysis);
      } catch (e) {
        print('Error analyzing image ${message.id}: $e');
        analyses.add(ImageAnalysis(
          messageId: message.id,
          senderId: message.senderId,
          timestamp: message.createdAt,
          imageUrl: message.content,
          description: 'Image analysis failed',
          tags: [],
          qualityScore: 0.0,
          relevanceScore: 0.0,
        ));
      }
    }
    
    return analyses;
  }

  /// Analyze single image with AI and extract meaningful information
  Future<ImageAnalysis> _analyzeImageWithAI(
    MessageModel message,
    UserModel targetUser,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/chat/completions'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'gpt-4o-mini', // Using vision-capable model
          'messages': [
            {
              'role': 'user',
              'content': [
                {
                  'type': 'text',
                  'text': '''Analyze this image in the context of dog walking/pet care services. Provide:
1. A detailed description (2-3 sentences)
2. Dog-related observations (mood, environment, care quality)
3. Relevant tags (comma-separated)
4. Quality score (0-10 for image clarity/usefulness)
5. Relevance score (0-10 for review context)

Return as JSON:
{
  "description": "detailed description",
  "observations": "dog-specific observations", 
  "tags": ["tag1", "tag2"],
  "qualityScore": 8.5,
  "relevanceScore": 9.0
}''',
                },
                {
                  'type': 'image_url',
                  'image_url': {'url': message.content}
                }
              ]
            }
          ],
          'max_tokens': 300,
          'temperature': 0.3, // Lower temperature for consistent analysis
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        
        // Parse JSON response
        try {
          final analysis = jsonDecode(content);
          return ImageAnalysis(
            messageId: message.id,
            senderId: message.senderId,
            timestamp: message.createdAt,
            imageUrl: message.content,
            description: analysis['description'] ?? 'No description available',
            observations: analysis['observations'] ?? '',
            tags: List<String>.from(analysis['tags'] ?? []),
            qualityScore: (analysis['qualityScore'] ?? 0.0).toDouble(),
            relevanceScore: (analysis['relevanceScore'] ?? 0.0).toDouble(),
          );
        } catch (e) {
          // Fallback if JSON parsing fails
          return ImageAnalysis(
            messageId: message.id,
            senderId: message.senderId,
            timestamp: message.createdAt,
            imageUrl: message.content,
            description: content,
            tags: [],
            qualityScore: 5.0,
            relevanceScore: 5.0,
          );
        }
      } else {
        throw Exception('Vision API error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Image analysis failed: $e');
    }
  }

  /// Identify conversation topics using keyword analysis
  List<String> _identifyTopics(List<MessageModel> messages) {
    final topicKeywords = {
      'scheduling': ['when', 'time', 'schedule', 'meet', 'appointment', 'available'],
      'walking': ['walk', 'exercise', 'route', 'park', 'leash', 'run'],
      'care': ['feed', 'water', 'treat', 'medicine', 'vet', 'health'],
      'behavior': ['bark', 'bite', 'friendly', 'aggressive', 'calm', 'excited'],
      'payment': ['pay', 'cost', 'price', 'money', 'fee', 'rate'],
      'emergency': ['urgent', 'emergency', 'help', 'problem', 'issue', 'sick'],
    };

    final content = messages
        .where((m) => m.type == MessageType.text)
        .map((m) => m.content.toLowerCase())
        .join(' ');

    final identifiedTopics = <String>[];
    
    topicKeywords.forEach((topic, keywords) {
      if (keywords.any((keyword) => content.contains(keyword))) {
        identifiedTopics.add(topic);
      }
    });

    return identifiedTopics;
  }

  /// Analyze communication patterns for insights
  CommunicationPatterns _analyzeCommunicationPatterns(
    List<MessageModel> messages,
    String reviewerId,
    String targetUserId,
  ) {
    if (messages.isEmpty) {
      return CommunicationPatterns.empty();
    }

    final reviewerMessages = messages.where((m) => m.senderId == reviewerId).toList();
    final targetMessages = messages.where((m) => m.senderId == targetUserId).toList();

    // Calculate response times
    final responseTimes = <Duration>[];
    for (int i = 0; i < messages.length - 1; i++) {
      final current = messages[i];
      final next = messages[i + 1];
      if (current.senderId != next.senderId) {
        responseTimes.add(next.createdAt.difference(current.createdAt));
      }
    }

    // Analyze message timing patterns
    final messageHours = messages.map((m) => m.createdAt.hour).toList();
    final mostActiveHour = _getMostFrequent(messageHours);

    return CommunicationPatterns(
      averageResponseTime: responseTimes.isNotEmpty 
          ? responseTimes.map((d) => d.inMinutes).reduce((a, b) => a + b) / responseTimes.length
          : 0.0,
      responseConsistency: _calculateResponseConsistency(responseTimes),
      initiationRatio: reviewerMessages.length / messages.length,
      mostActiveHour: mostActiveHour,
      communicationFrequency: messages.length / 
          (messages.last.createdAt.difference(messages.first.createdAt).inHours + 1),
      longestGap: responseTimes.isNotEmpty 
          ? responseTimes.map((d) => d.inMinutes).reduce((a, b) => a > b ? a : b)
          : 0,
    );
  }

  /// Extract key insights for AI processing
  List<String> _extractKeyInsights(
    List<MessageModel> messages,
    List<ImageAnalysis> imageAnalyses,
    UserModel reviewer,
    UserModel targetUser,
  ) {
    final insights = <String>[];

    // Communication insights
    if (messages.isNotEmpty) {
      final targetMessages = messages.where((m) => m.senderId == targetUser.uid).toList();
      if (targetMessages.isEmpty) {
        insights.add('Target user did not respond to any messages');
      } else if (targetMessages.length / messages.length < 0.3) {
        insights.add('Target user had limited engagement in conversation');
      }
    }

    // Image insights
    final highQualityImages = imageAnalyses.where((img) => img.qualityScore > 7.0).toList();
    if (highQualityImages.isNotEmpty) {
      insights.add('${highQualityImages.length} high-quality images shared');
    }

    final relevantImages = imageAnalyses.where((img) => img.relevanceScore > 7.0).toList();
    if (relevantImages.isNotEmpty) {
      insights.add('${relevantImages.length} relevant service-related images');
    }

    return insights;
  }

  /// Analyze sentiment of messages
  String _analyzeSentiment(List<MessageModel> messages, String targetUserId) {
    final targetMessages = messages
        .where((m) => m.senderId == targetUserId && m.type == MessageType.text)
        .map((m) => m.content.toLowerCase())
        .join(' ');

    final positiveWords = ['good', 'great', 'excellent', 'happy', 'thanks', 'perfect', 'love'];
    final negativeWords = ['bad', 'terrible', 'awful', 'hate', 'problem', 'issue', 'wrong'];

    final positiveCount = positiveWords.where((word) => targetMessages.contains(word)).length;
    final negativeCount = negativeWords.where((word) => targetMessages.contains(word)).length;

    if (positiveCount > negativeCount) return 'positive';
    if (negativeCount > positiveCount) return 'negative';
    return 'neutral';
  }

  /// Assess urgency level of messages
  String _assessUrgencyLevel(List<MessageModel> messages) {
    final urgentWords = ['urgent', 'emergency', 'asap', 'immediately', 'help', 'now'];
    final content = messages
        .where((m) => m.type == MessageType.text)
        .map((m) => m.content.toLowerCase())
        .join(' ');

    if (urgentWords.any((word) => content.contains(word))) return 'high';
    
    // Check for multiple exclamation marks or caps
    if (content.contains('!!!') || content.split(' ').any((word) => word == word.toUpperCase() && word.length > 3)) {
      return 'medium';
    }
    
    return 'low';
  }

  /// Calculate response consistency score
  double _calculateResponseConsistency(List<Duration> responseTimes) {
    if (responseTimes.length < 2) return 1.0;

    final times = responseTimes.map((d) => d.inMinutes.toDouble()).toList();
    final average = times.reduce((a, b) => a + b) / times.length;
    final variance = times.map((t) => (t - average) * (t - average)).reduce((a, b) => a + b) / times.length;
    final standardDeviation = math.sqrt(variance);
    
    // Consistency score: lower std dev = higher consistency
    return 1.0 - (standardDeviation / (average + 1)).clamp(0.0, 1.0);
  }

  /// Get most frequent item from a list
  int _getMostFrequent(List<int> items) {
    if (items.isEmpty) return 0;
    
    final frequency = <int, int>{};
    for (final item in items) {
      frequency[item] = (frequency[item] ?? 0) + 1;
    }
    
    return frequency.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }
}

// Data classes for structured conversation analysis

class ConversationAnalysis {
  final List<ConversationChunk> conversationChunks;
  final List<ImageAnalysis> imageAnalyses;
  final ConversationStats conversationStats;
  final CommunicationPatterns communicationPatterns;
  final List<String> keyInsights;
  final DateTime analysisTimestamp;

  ConversationAnalysis({
    required this.conversationChunks,
    required this.imageAnalyses,
    required this.conversationStats,
    required this.communicationPatterns,
    required this.keyInsights,
    required this.analysisTimestamp,
  });

  factory ConversationAnalysis.empty() {
    return ConversationAnalysis(
      conversationChunks: [],
      imageAnalyses: [],
      conversationStats: ConversationStats.empty(),
      communicationPatterns: CommunicationPatterns.empty(),
      keyInsights: [],
      analysisTimestamp: DateTime.now(),
    );
  }

  /// Create formatted summary for AI processing
  String toAIPromptSummary() {
    final buffer = StringBuffer();
    
    buffer.writeln('=== CONVERSATION ANALYSIS SUMMARY ===');
    buffer.writeln('Analysis Date: $analysisTimestamp');
    buffer.writeln('Total Message Chunks: ${conversationChunks.length}');
    buffer.writeln('Total Images Analyzed: ${imageAnalyses.length}');
    buffer.writeln();
    
    buffer.writeln('STATISTICS:');
    buffer.writeln('- Total Messages: ${conversationStats.totalMessages}');
    buffer.writeln('- Average Response Time: ${conversationStats.averageResponseTimeMinutes.toStringAsFixed(1)} minutes');
    buffer.writeln('- Communication Frequency: ${communicationPatterns.communicationFrequency.toStringAsFixed(1)} messages/hour');
    buffer.writeln();
    
    if (keyInsights.isNotEmpty) {
      buffer.writeln('KEY INSIGHTS:');
      for (final insight in keyInsights) {
        buffer.writeln('- $insight');
      }
      buffer.writeln();
    }
    
    if (conversationChunks.isNotEmpty) {
      buffer.writeln('CONVERSATION CHUNKS:');
      for (int i = 0; i < conversationChunks.length; i++) {
        final chunk = conversationChunks[i];
        buffer.writeln('Chunk ${i + 1}: ${chunk.messageCount} messages, topics: ${chunk.topics.join(", ")}');
        buffer.writeln(chunk.conversationText);
      }
    }
    
    if (imageAnalyses.isNotEmpty) {
      buffer.writeln('IMAGE ANALYSES:');
      for (int i = 0; i < imageAnalyses.length; i++) {
        final img = imageAnalyses[i];
        buffer.writeln('Image ${i + 1}: ${img.description}');
        if (img.observations.isNotEmpty) {
          buffer.writeln('Observations: ${img.observations}');
        }
        buffer.writeln('Quality: ${img.qualityScore}/10, Relevance: ${img.relevanceScore}/10');
        buffer.writeln();
      }
    }
    
    return buffer.toString();
  }
}

class ConversationChunk {
  final DateTime startTime;
  final DateTime endTime;
  final int messageCount;
  final int reviewerMessageCount;
  final int targetMessageCount;
  final int totalWordCount;
  final double responseRatio;
  final List<String> topics;
  final String conversationText;
  final String sentiment;
  final String urgencyLevel;

  ConversationChunk({
    required this.startTime,
    required this.endTime,
    required this.messageCount,
    required this.reviewerMessageCount,
    required this.targetMessageCount,
    required this.totalWordCount,
    required this.responseRatio,
    required this.topics,
    required this.conversationText,
    required this.sentiment,
    required this.urgencyLevel,
  });
}

class ImageAnalysis {
  final String messageId;
  final String senderId;
  final DateTime timestamp;
  final String imageUrl;
  final String description;
  final String observations;
  final List<String> tags;
  final double qualityScore;
  final double relevanceScore;

  ImageAnalysis({
    required this.messageId,
    required this.senderId,
    required this.timestamp,
    required this.imageUrl,
    required this.description,
    this.observations = '',
    required this.tags,
    required this.qualityScore,
    required this.relevanceScore,
  });
}

class ConversationStats {
  final int totalMessages;
  final int user1MessageCount;
  final int user2MessageCount;
  final double averageResponseTimeMinutes;
  final int imageCount;
  final int videoCount;
  final DateTime? lastMessageTime;
  final Duration conversationSpan;

  ConversationStats({
    required this.totalMessages,
    required this.user1MessageCount,
    required this.user2MessageCount,
    required this.averageResponseTimeMinutes,
    required this.imageCount,
    required this.videoCount,
    this.lastMessageTime,
    required this.conversationSpan,
  });

  factory ConversationStats.fromMap(Map<String, dynamic> map) {
    return ConversationStats(
      totalMessages: map['totalMessages'] ?? 0,
      user1MessageCount: map['user1MessageCount'] ?? 0,
      user2MessageCount: map['user2MessageCount'] ?? 0,
      averageResponseTimeMinutes: (map['averageResponseTimeMinutes'] ?? 0.0).toDouble(),
      imageCount: map['imageCount'] ?? 0,
      videoCount: map['videoCount'] ?? 0,
      lastMessageTime: map['lastMessageTime'] as DateTime?,
      conversationSpan: map['conversationSpan'] ?? Duration.zero,
    );
  }

  factory ConversationStats.empty() {
    return ConversationStats(
      totalMessages: 0,
      user1MessageCount: 0,
      user2MessageCount: 0,
      averageResponseTimeMinutes: 0.0,
      imageCount: 0,
      videoCount: 0,
      conversationSpan: Duration.zero,
    );
  }
}

class CommunicationPatterns {
  final double averageResponseTime;
  final double responseConsistency;
  final double initiationRatio;
  final int mostActiveHour;
  final double communicationFrequency;
  final int longestGap;

  CommunicationPatterns({
    required this.averageResponseTime,
    required this.responseConsistency,
    required this.initiationRatio,
    required this.mostActiveHour,
    required this.communicationFrequency,
    required this.longestGap,
  });

  factory CommunicationPatterns.empty() {
    return CommunicationPatterns(
      averageResponseTime: 0.0,
      responseConsistency: 0.0,
      initiationRatio: 0.0,
      mostActiveHour: 0,
      communicationFrequency: 0.0,
      longestGap: 0,
    );
  }
} 