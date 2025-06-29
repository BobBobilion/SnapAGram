import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:snapagram/models/review.dart';
import 'package:snapagram/models/user_model.dart';
import 'package:snapagram/services/conversation_analysis_service.dart';
import 'package:snapagram/services/openai_service.dart';

final aiReviewServiceProvider = Provider<AiReviewService>((ref) {
  return AiReviewService(
    ref.read(conversationAnalysisServiceProvider),
    ref.read(chatContextManagerProvider),
  );
});

class AiReviewService {
  static const String _baseUrl = 'https://api.openai.com/v1';
  
  String get _apiKey {
    final apiKey = dotenv.env['OPENAI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('OpenAI API key not found. Please check your .env file.');
    }
    return apiKey;
  }
  
  final ConversationAnalysisService _conversationAnalysisService;
  final ChatContextManager _chatContextManager;
  
  AiReviewService(this._conversationAnalysisService, this._chatContextManager);
  
  // Fast review generation using pre-processed context
  Future<AiReviewSuggestion> generateReviewSuggestion({
    required String reviewerId,
    required String targetUserId,
    required UserModel reviewer,
    required UserModel targetUser,
    String? chatId,
  }) async {
    try {
      print('🚀 [FAST-REVIEW] Starting instant review generation...');
      
      // Try to get pre-processed context first (instant)
      String? contextData;
      if (chatId != null) {
        contextData = _chatContextManager.getContextForReview(chatId, reviewer, targetUser);
        print('📋 [FAST-REVIEW] Using pre-processed context');
      }
      
      // If no pre-processed context available, fall back to full analysis
      if (contextData == null || contextData == 'No conversation context available.') {
        print('⚠️ [FAST-REVIEW] No pre-processed context, falling back to full analysis');
        return await _generateWithFullAnalysis(reviewerId, targetUserId, reviewer, targetUser);
      }

      // Generate review using pre-processed context (much faster)
      final suggestion = await _generateReviewWithPreprocessedContext(
        reviewer: reviewer,
        targetUser: targetUser,
        contextData: contextData,
      );
      
      print('✅ [FAST-REVIEW] Review generated instantly using cached context');
      return suggestion;
    } catch (e) {
      print('❌ [FAST-REVIEW] Error: $e');
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

  // Fast review generation with pre-processed context
  Future<AiReviewSuggestion> _generateReviewWithPreprocessedContext({
    required UserModel reviewer,
    required UserModel targetUser,
    required String contextData,
  }) async {
    try {
      final prompt = _createFastReviewPrompt(reviewer, targetUser, contextData);
      final response = await _callOpenAI(prompt, maxTokens: 200); // Reduced for 400 character limit
      return _parseAIResponse(response);
    } catch (e) {
      print('Error generating fast review: $e');
      rethrow;
    }
  }

  // Fallback to full analysis if no cached context
  Future<AiReviewSuggestion> _generateWithFullAnalysis(
    String reviewerId,
    String targetUserId,
    UserModel reviewer,
    UserModel targetUser,
  ) async {
    // Use the existing conversation analysis service as fallback
    final conversationAnalysis = await _conversationAnalysisService.analyzeConversation(
      reviewerId: reviewerId,
      targetUserId: targetUserId,
      reviewer: reviewer,
      targetUser: targetUser,
      lookbackPeriod: const Duration(hours: 48),
    );
    
    return await _generateReviewWithAI(
      reviewer: reviewer,
      targetUser: targetUser,
      conversationAnalysis: conversationAnalysis,
    );
  }

  // Create optimized prompt for fast review generation
  String _createFastReviewPrompt(UserModel reviewer, UserModel targetUser, String contextData) {
    final targetRole = targetUser.isWalker ? 'dog walker' : 'dog owner';
    final reviewerRole = reviewer.isOwner ? 'dog owner' : 'dog walker';
    
    return '''
Generate a concise review for a $targetRole based on pre-analyzed conversation data.

Reviewer: $reviewerRole (${reviewer.displayName})
Target: $targetRole (${targetUser.displayName})

PRE-PROCESSED CONTEXT:
$contextData

Generate a balanced review with:
- Rating: 1-5 (decimals allowed)
- Comment: Maximum 400 characters, professional and specific
- Key highlights: 2-3 specific observations

Focus on: ${targetUser.isWalker ? 'communication, reliability, care quality' : 'cooperation, clarity, payment reliability'}

Return JSON format:
{
  "rating": 4.2,
  "comment": "Brief, specific review under 400 characters...",
  "highlights": ["specific point 1", "specific point 2"]
}''';
  }

  // Generate review using OpenAI API with comprehensive conversation analysis (fallback)
  Future<AiReviewSuggestion> _generateReviewWithAI({
    required UserModel reviewer,
    required UserModel targetUser,
    required ConversationAnalysis conversationAnalysis,
  }) async {
    try {
      // Create enhanced prompt using comprehensive analysis
      final prompt = _createEnhancedReviewPrompt(
        reviewer: reviewer,
        targetUser: targetUser,
        conversationAnalysis: conversationAnalysis,
      );
      
      // Make API call to OpenAI
      final response = await _callOpenAI(prompt, maxTokens: 200); // Reduced for 400 character limit
      
      // Parse response with enhanced data
      return _parseEnhancedAIResponse(response, conversationAnalysis);
    } catch (e) {
      print('Error generating AI review: $e');
      rethrow;
    }
  }

  // Create enhanced context-aware prompt for review generation (fallback)
  String _createEnhancedReviewPrompt({
    required UserModel reviewer,
    required UserModel targetUser,
    required ConversationAnalysis conversationAnalysis,
  }) {
    final targetRole = targetUser.isWalker ? 'dog walker' : 'dog owner';
    final reviewerRole = reviewer.isWalker ? 'dog walker' : 'dog owner';
    
    return '''
You are helping to generate a balanced review for a $targetRole based on comprehensive conversation analysis.

Context:
- Reviewer: $reviewerRole (${reviewer.displayName})
- Target: $targetRole (${targetUser.displayName})
- Review Type: ${reviewer.isOwner ? 'Owner reviewing Walker' : 'Walker reviewing Owner'}
- Analysis Period: Last 48 hours

${conversationAnalysis.toAIPromptSummary()}

EVALUATION CRITERIA for ${targetUser.isWalker ? 'Dog Walker' : 'Dog Owner'}:
${targetUser.isWalker ? '''
- Communication responsiveness and clarity
- Reliability and punctuality indicators
- Care quality evidence from images/messages
- Professionalism in interactions
- Problem-solving and adaptability''' : '''
- Communication clarity and timeliness
- Cooperation and flexibility
- Dog care instructions and information sharing
- Payment and scheduling reliability
- Overall collaboration quality'''}

Instructions:
1. Generate a balanced, evidence-based review
2. Consider communication patterns, response times, and engagement quality
3. Reference specific observations from conversation chunks and image analyses
4. Provide a rating from 1-5 (decimals allowed, e.g., 3.7)
5. Be objective and fair, acknowledging both strengths and areas for improvement
6. Keep review comment under 400 characters - be concise and professional

Output format:
{
  "rating": 3.7,
  "comment": "Concise review under 400 characters referencing specific evidence...",
  "highlights": ["specific observation 1", "specific observation 2", "specific observation 3"],
  "reasoning": "Brief explanation of rating"
}
''';
  }

  // Parse AI response for fast reviews
  AiReviewSuggestion _parseAIResponse(String response) {
    try {
      final jsonStart = response.indexOf('{');
      final jsonEnd = response.lastIndexOf('}') + 1;
      
      if (jsonStart >= 0 && jsonEnd > jsonStart) {
        final jsonStr = response.substring(jsonStart, jsonEnd);
        final data = jsonDecode(jsonStr);
        
        return AiReviewSuggestion(
          suggestedRating: (data['rating'] ?? 3.0).toDouble(),
          suggestedComment: data['comment'] ?? 'Review generated based on recent interactions.',
          conversationHighlights: List<String>.from(data['highlights'] ?? []),
          imageAnalysis: [], // Will be filled from context if available
          analysisReasoning: data['reasoning'] ?? 'Analysis based on pre-processed conversation context.',
        );
      }
    } catch (e) {
      print('Error parsing AI response: $e');
    }
    
    return AiReviewSuggestion(
      suggestedRating: 3.0,
      suggestedComment: response.length > 400 ? response.substring(0, 400) : response,
      conversationHighlights: ['Communication analyzed from recent interactions'],
      imageAnalysis: [],
      analysisReasoning: 'Fast analysis completed with available data.',
    );
  }

  // Parse enhanced AI response with comprehensive data (fallback)
  AiReviewSuggestion _parseEnhancedAIResponse(
    String response, 
    ConversationAnalysis conversationAnalysis,
  ) {
    try {
      // Try to parse JSON response
      final jsonStart = response.indexOf('{');
      final jsonEnd = response.lastIndexOf('}') + 1;
      
      if (jsonStart >= 0 && jsonEnd > jsonStart) {
        final jsonStr = response.substring(jsonStart, jsonEnd);
        final data = jsonDecode(jsonStr);
        
        // Extract image descriptions for highlights
        final imageDescriptions = conversationAnalysis.imageAnalyses
            .map((img) => img.description)
            .toList();
        
        // Ensure comment is under 400 characters
        String comment = data['comment'] ?? 'Review generated based on recent interactions.';
        if (comment.length > 400) {
          comment = comment.substring(0, 397) + '...';
        }
        
        return AiReviewSuggestion(
          suggestedRating: (data['rating'] ?? 3.0).toDouble(),
          suggestedComment: comment,
          conversationHighlights: List<String>.from(data['highlights'] ?? conversationAnalysis.keyInsights),
          imageAnalysis: imageDescriptions,
          analysisReasoning: data['reasoning'] ?? 'Analysis based on conversation patterns and interactions.',
          detailedImageAnalyses: conversationAnalysis.imageAnalyses, // Pass full ImageAnalysis objects for debug
        );
      }
    } catch (e) {
      print('Error parsing enhanced AI response: $e');
    }
    
    // Fallback with conversation analysis data
    final fallbackHighlights = conversationAnalysis.keyInsights.isNotEmpty 
        ? conversationAnalysis.keyInsights
        : ['Communication analyzed from recent interactions'];
        
    final fallbackImageAnalysis = conversationAnalysis.imageAnalyses
        .map((img) => img.description)
        .toList();
    
    String fallbackComment = response.isNotEmpty ? response : 'Review generated based on recent interactions.';
    if (fallbackComment.length > 400) {
      fallbackComment = fallbackComment.substring(0, 397) + '...';
    }
    
    return AiReviewSuggestion(
      suggestedRating: 3.0,
      suggestedComment: fallbackComment,
      conversationHighlights: fallbackHighlights,
      imageAnalysis: fallbackImageAnalysis,
      analysisReasoning: 'Fallback analysis completed with available data.',
      detailedImageAnalyses: conversationAnalysis.imageAnalyses, // Pass full ImageAnalysis objects for debug
    );
  }

  // Call OpenAI API with configurable token limit
  Future<String> _callOpenAI(String prompt, {int maxTokens = 200}) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/chat/completions'),
      headers: {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'gpt-4o-mini', // Using faster, cheaper model for reviews
        'messages': [
          {'role': 'user', 'content': prompt}
        ],
        'max_tokens': maxTokens,
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
}

 