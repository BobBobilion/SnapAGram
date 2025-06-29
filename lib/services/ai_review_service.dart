import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:snapagram/models/review.dart';
import 'package:snapagram/models/user_model.dart';
import 'package:snapagram/services/conversation_analysis_service.dart';

final aiReviewServiceProvider = Provider<AiReviewService>((ref) {
  return AiReviewService(ref.read(conversationAnalysisServiceProvider));
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
  
  AiReviewService(this._conversationAnalysisService);
  
  // Analyze conversation and images to generate review suggestion
  Future<AiReviewSuggestion> generateReviewSuggestion({
    required String reviewerId,
    required String targetUserId,
    required UserModel reviewer,
    required UserModel targetUser,
  }) async {
    try {
      // Use the new conversation analysis service for comprehensive analysis
      final conversationAnalysis = await _conversationAnalysisService.analyzeConversation(
        reviewerId: reviewerId,
        targetUserId: targetUserId,
        reviewer: reviewer,
        targetUser: targetUser,
        lookbackPeriod: const Duration(hours: 48), // Extended analysis period
      );
      
      // Generate review using the comprehensive analysis
      final suggestion = await _generateReviewWithAI(
        reviewer: reviewer,
        targetUser: targetUser,
        conversationAnalysis: conversationAnalysis,
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



  // Generate review using OpenAI API with comprehensive conversation analysis
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
      final response = await _callOpenAI(prompt);
      
      // Parse response with enhanced data
      return _parseEnhancedAIResponse(response, conversationAnalysis);
    } catch (e) {
      print('Error generating AI review: $e');
      rethrow;
    }
  }



  // Create enhanced context-aware prompt for review generation
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
6. Keep review professional and constructive

Output format:
{
  "rating": 3.7,
  "comment": "Detailed review comment referencing specific evidence...",
  "highlights": ["specific observation 1", "specific observation 2", "specific observation 3"],
  "reasoning": "Detailed explanation of rating based on analysis"
}
''';
  }

  // Parse enhanced AI response with comprehensive data
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
        
        return AiReviewSuggestion(
          suggestedRating: (data['rating'] ?? 3.0).toDouble(),
          suggestedComment: data['comment'] ?? 'Review generated based on recent interactions.',
          conversationHighlights: List<String>.from(data['highlights'] ?? conversationAnalysis.keyInsights),
          imageAnalysis: imageDescriptions,
          analysisReasoning: data['reasoning'] ?? 'Analysis based on conversation patterns and interactions.',
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
    
    return AiReviewSuggestion(
      suggestedRating: 3.0,
      suggestedComment: response.isNotEmpty ? response : 'Review generated based on recent interactions.',
      conversationHighlights: fallbackHighlights,
      imageAnalysis: fallbackImageAnalysis,
      analysisReasoning: 'Fallback analysis completed with available data.',
    );
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


}

 