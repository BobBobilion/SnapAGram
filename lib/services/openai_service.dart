import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';

final openAIServiceProvider = Provider<OpenAIService>((ref) {
  return OpenAIService();
});

final chatContextManagerProvider = Provider<ChatContextManager>((ref) {
  return ChatContextManager(ref.read(openAIServiceProvider));
});

// Background chat context manager for instant review generation
class ChatContextManager {
  final OpenAIService _openAIService;
  final Map<String, ChatContext> _contextCache = {};
  final Set<String> _processingImages = {}; // Track images being processed

  ChatContextManager(this._openAIService);

  // Get or create chat context for a conversation
  Future<ChatContext> getChatContext(String chatId, List<MessageModel> messages, UserModel currentUser, UserModel? otherUser) async {
    final contextKey = '${chatId}_${currentUser.uid}_${otherUser?.uid}';
    
    // Check if we have cached context
    if (_contextCache.containsKey(contextKey)) {
      final cached = _contextCache[contextKey]!;
      // Update with new messages if needed
      if (messages.length > cached.processedMessageCount) {
        return await _updateChatContext(cached, messages, currentUser, otherUser);
      }
      return cached;
    }

    // Create new context
    return await _createChatContext(contextKey, messages, currentUser, otherUser);
  }

  // Process new message in background (only if needed)
  Future<void> processNewMessage(String chatId, MessageModel message, UserModel currentUser, UserModel? otherUser) async {
    final contextKey = '${chatId}_${currentUser.uid}_${otherUser?.uid}';
    
    if (!_contextCache.containsKey(contextKey)) return;

    final context = _contextCache[contextKey]!;
    
    // Add message to context
    context.messages.add(message);
    context.processedMessageCount++;
    context.lastUpdated = DateTime.now();

    // Only process image if it hasn't been analyzed before
    if (message.type == MessageType.image && 
        !context.imageAnalyses.containsKey(message.id) &&
        !_processingImages.contains(message.id)) {
      _processImageInBackground(message, context);
    }

    // Update conversation summary (no AI call needed)
    context.conversationSummary = _buildConversationSummary(context.messages, currentUser, otherUser);
  }

  // Create new chat context with full processing
  Future<ChatContext> _createChatContext(String contextKey, List<MessageModel> messages, UserModel currentUser, UserModel? otherUser) async {
    print('🔄 Creating new chat context for $contextKey');
    
    final context = ChatContext(
      contextKey: contextKey,
      messages: List.from(messages),
      processedMessageCount: messages.length,
      lastUpdated: DateTime.now(),
      imageAnalyses: {},
      conversationSummary: '',
    );

    // Process only images that haven't been analyzed before
    final imageMessages = messages.where((m) => m.type == MessageType.image).toList();
    final unprocessedImages = imageMessages.where((m) => 
      !context.imageAnalyses.containsKey(m.id) && 
      !_processingImages.contains(m.id)
    ).toList();

    // Process unprocessed images in parallel (but limit to avoid API spam)
    final imagesToProcess = unprocessedImages.take(5).toList(); // Limit to 5 images max
    for (final imageMessage in imagesToProcess) {
      await _processImageAnalysis(imageMessage, context);
    }

    // Build conversation summary
    context.conversationSummary = _buildConversationSummary(messages, currentUser, otherUser);

    _contextCache[contextKey] = context;
    print('✅ Chat context created with ${imagesToProcess.length} new images processed');
    
    return context;
  }

  // Update existing context with new messages
  Future<ChatContext> _updateChatContext(ChatContext context, List<MessageModel> messages, UserModel currentUser, UserModel? otherUser) async {
    final newMessages = messages.skip(context.processedMessageCount).toList();
    
    for (final message in newMessages) {
      context.messages.add(message);
      
      // Only process images that haven't been analyzed
      if (message.type == MessageType.image && 
          !context.imageAnalyses.containsKey(message.id) &&
          !_processingImages.contains(message.id)) {
        await _processImageAnalysis(message, context);
      }
    }

    context.processedMessageCount = messages.length;
    context.lastUpdated = DateTime.now();
    context.conversationSummary = _buildConversationSummary(context.messages, currentUser, otherUser);

    return context;
  }

  // Process image analysis and store in context (with deduplication)
  Future<void> _processImageAnalysis(MessageModel message, ChatContext context) async {
    // Check if already processed or being processed
    if (context.imageAnalyses.containsKey(message.id) || _processingImages.contains(message.id)) {
      return;
    }

    // Mark as being processed
    _processingImages.add(message.id);
    
    try {
      final analysis = await _openAIService.analyzeImage(message.content);
      if (analysis != null) {
        context.imageAnalyses[message.id] = analysis;
        print('📸 Image analysis completed for message ${message.id}');
      }
    } catch (e) {
      print('❌ Error analyzing image ${message.id}: $e');
    } finally {
      // Remove from processing set
      _processingImages.remove(message.id);
    }
  }

  // Process image in background (fire and forget) - only if not already processed
  void _processImageInBackground(MessageModel message, ChatContext context) {
    // Skip if already processed or being processed
    if (context.imageAnalyses.containsKey(message.id) || _processingImages.contains(message.id)) {
      return;
    }
    
    _processImageAnalysis(message, context).catchError((e) {
      print('Background image processing failed: $e');
      _processingImages.remove(message.id);
    });
  }

  // Build comprehensive conversation summary (no AI calls)
  String _buildConversationSummary(List<MessageModel> messages, UserModel currentUser, UserModel? otherUser) {
    final summary = StringBuffer();
    
    summary.writeln('=== CHAT CONTEXT SUMMARY ===');
    summary.writeln('Participants: ${currentUser.displayName} & ${otherUser?.displayName ?? 'Unknown'}');
    summary.writeln('Total Messages: ${messages.length}');
    summary.writeln('Last Updated: ${DateTime.now()}');
    summary.writeln();

    // Add recent conversation (last 10 messages)
    final recentMessages = messages.take(10).toList().reversed;
    summary.writeln('Recent Conversation:');
    
    for (final message in recentMessages) {
      final isCurrentUser = message.senderId == currentUser.uid;
      final senderName = isCurrentUser ? currentUser.displayName.split(' ').first : (otherUser?.displayName.split(' ').first ?? 'Other');
      final timestamp = message.createdAt.toString().substring(11, 16);
      
      if (message.type == MessageType.text) {
        summary.writeln('[$timestamp] $senderName: ${message.content}');
      } else if (message.type == MessageType.image) {
        // Include analysis if available
        final analysis = message.metadata['imageAnalysis'] as String?;
        if (analysis != null) {
          summary.writeln('[$timestamp] $senderName: [Image: $analysis]');
        } else {
          summary.writeln('[$timestamp] $senderName: [Image sent]');
        }
      }
    }

    return summary.toString();
  }

  // Get ready-to-use context for review generation
  String getContextForReview(String chatId, UserModel currentUser, UserModel? otherUser) {
    final contextKey = '${chatId}_${currentUser.uid}_${otherUser?.uid}';
    final context = _contextCache[contextKey];
    
    if (context == null) return 'No conversation context available.';

    final reviewContext = StringBuffer();
    reviewContext.writeln(context.conversationSummary);
    
    // Add image analyses that aren't already in the summary
    final summaryImages = context.messages
        .where((m) => m.type == MessageType.image && m.metadata['imageAnalysis'] == null)
        .toList();
    
    if (summaryImages.isNotEmpty) {
      reviewContext.writeln();
      reviewContext.writeln('=== ADDITIONAL IMAGE ANALYSES ===');
      summaryImages.forEach((message) {
        final analysis = context.imageAnalyses[message.id];
        if (analysis != null) {
          reviewContext.writeln('Image Analysis: $analysis');
          reviewContext.writeln();
        }
      });
    }

    return reviewContext.toString();
  }

  // Clear old contexts to manage memory (more aggressive cleanup)
  void clearOldContexts() {
    final cutoff = DateTime.now().subtract(const Duration(hours: 24)); // Changed back to 24h
    final removedCount = _contextCache.length;
    _contextCache.removeWhere((key, context) => context.lastUpdated.isBefore(cutoff));
    final remainingCount = _contextCache.length;
    
    if (removedCount != remainingCount) {
      print('🧹 Cleaned up ${removedCount - remainingCount} old chat contexts');
    }
  }

  // Get cache statistics for monitoring
  Map<String, dynamic> getCacheStats() {
    return {
      'totalContexts': _contextCache.length,
      'processingImages': _processingImages.length,
      'totalImageAnalyses': _contextCache.values
          .map((c) => c.imageAnalyses.length)
          .fold(0, (a, b) => a + b),
    };
  }

  // Get detailed context information for debugging
  List<Map<String, dynamic>> getDetailedContextInfo() {
    return _contextCache.entries.map((entry) {
      final context = entry.value;
      return {
        'contextKey': context.contextKey,
        'messageCount': context.messages.length,
        'processedMessageCount': context.processedMessageCount,
        'imageAnalysisCount': context.imageAnalyses.length,
        'lastUpdated': context.lastUpdated,
        'ageInHours': DateTime.now().difference(context.lastUpdated).inHours,
        'imageAnalyses': context.imageAnalyses.keys.toList(),
        'conversationSummary': context.conversationSummary.length > 100 
            ? '${context.conversationSummary.substring(0, 100)}...' 
            : context.conversationSummary,
      };
    }).toList();
  }
}

// Chat context data structure
class ChatContext {
  final String contextKey;
  final List<MessageModel> messages;
  int processedMessageCount;
  DateTime lastUpdated;
  final Map<String, String> imageAnalyses; // messageId -> analysis
  String conversationSummary;

  ChatContext({
    required this.contextKey,
    required this.messages,
    required this.processedMessageCount,
    required this.lastUpdated,
    required this.imageAnalyses,
    required this.conversationSummary,
  });
}

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

  Future<String?> analyzeImage(String imageUrl) async {
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-4o',
          'messages': [
            {
              'role': 'system',
              'content': '''You are an expert AI assistant for a dog walking app. Your task is to analyze an image from a chat between a dog owner and a dog walker. Provide a detailed, objective description of the image in plain text. This description will be used by another LLM to understand the context of the conversation.

Focus on these key areas:
1.  **Environment:** Describe the location (e.g., park, sidewalk, inside a home), weather conditions, time of day, and any notable objects or hazards.
2.  **Dog's Apparent State:** Describe the dog's breed (if identifiable), size, and any visible emotional indicators (e.g., "The dog appears relaxed, with a loosely wagging tail," or "The dog seems anxious, with its ears back and body tense"). Be objective.
3.  **Interaction & Safety:** Note any interactions between the dog and people or other animals. Identify potential safety concerns (e.g., "The dog is off-leash near a busy street," or "The leash appears frayed").
4.  **Other Relevant Details:** Mention any other details that could be relevant for a dog walker or owner, such as toys, food, or other equipment present.

Do not offer advice or opinions. Simply describe what you see in a structured, clear format. The output must be a single block of text.'''
            },
            {
              'role': 'user',
              'content': [
                {
                  'type': 'image_url',
                  'image_url': {
                    'url': imageUrl,
                  }
                }
              ]
            }
          ],
          'max_tokens': 400,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'] as String?;
      } else {
        print('OpenAI Image Analysis Error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error analyzing image: $e');
      return null;
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

  /// Generate a caption for a photo using AI with user context
  Future<String?> generatePhotoCaption(String imagePath, {UserModel? user}) async {
    try {
      // Debug: Log user context
      print('🐕 CAPTION GENERATION DEBUG START');
      print('📸 Image path: $imagePath');
      
      if (user != null) {
        print('👤 User: ${user.displayName} (${user.uid})');
        print('🎭 Role: ${user.isWalker ? 'Dog Walker' : 'Dog Owner'}');
        
        if (user.isWalker) {
          final walkerProfile = user.walkerProfile;
          if (walkerProfile != null) {
            print('🚶‍♂️ Walker Profile:');
            print('   - City: ${walkerProfile.city}');
            print('   - Rating: ${walkerProfile.averageRating}/5 (${walkerProfile.totalReviews} reviews)');
            print('   - Recent walks: ${walkerProfile.recentWalks.length}');
            if (walkerProfile.recentWalks.isNotEmpty) {
              print('   - Recent dog names: ${walkerProfile.recentWalks.map((w) => w.dogName).join(', ')}');
            }
          } else {
            print('   - No walker profile found');
          }
        } else {
          final ownerProfile = user.ownerProfile;
          if (ownerProfile != null) {
            print('🐕 Owner Profile:');
            print('   - Dog Name: "${ownerProfile.dogName}"');
            print('   - Dog Breed: ${ownerProfile.dogBreed ?? 'Not specified'}');
            print('   - Dog Age: ${ownerProfile.dogAge != null ? '${ownerProfile.dogAge} years' : 'Not specified'}');
            print('   - Dog Size: ${ownerProfile.dogSizeText}');
            print('   - Dog Bio: ${ownerProfile.dogBio ?? 'Not specified'}');
          } else {
            print('   - No owner profile found');
          }
        }
      } else {
        print('❌ No user context provided');
      }

      // Convert local file path to base64 for API call
      final imageFile = File(imagePath);
      if (!await imageFile.exists()) {
        throw Exception('Image file not found');
      }

      final imageBytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(imageBytes);
      final imageUrl = 'data:image/jpeg;base64,$base64Image';

      // Build contextual prompt based on user role
      String contextualPrompt = _buildContextualCaptionPrompt(user);
      
      // Debug: Log the prompt being sent to AI
      print('🤖 AI Prompt being sent:');
      print('=' * 50);
      print(contextualPrompt);
      print('=' * 50);

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-4o',
          'messages': [
            {
              'role': 'system',
              'content': contextualPrompt,
            },
            {
              'role': 'user',
              'content': [
                {
                  'type': 'text',
                  'text': 'Generate a compelling social media caption for this photo:'
                },
                {
                  'type': 'image_url',
                  'image_url': {
                    'url': imageUrl,
                  }
                }
              ]
            }
          ],
          'max_tokens': 100,
          'temperature': 0.8,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final caption = data['choices'][0]['message']['content'] as String?;
        
        // Debug: Log the AI response
        print('🤖 AI Response:');
        print('   - Status: ${response.statusCode}');
        print('   - Caption: "${caption?.trim()}"');
        print('🐕 CAPTION GENERATION DEBUG END');
        
        return caption?.trim();
      } else {
        print('❌ OpenAI API Error: ${response.statusCode} - ${response.body}');
        print('🐕 CAPTION GENERATION DEBUG END');
        return null;
      }
    } catch (e) {
      print('❌ Error generating photo caption: $e');
      print('🐕 CAPTION GENERATION DEBUG END');
      return null;
    }
  }

  /// Build contextual prompt based on user role and profile
  String _buildContextualCaptionPrompt(UserModel? user) {
    if (user == null) {
      return '''You are a creative social media caption generator. Generate engaging, natural captions for photos that people would want to post on social media. 

Guidelines:
- Keep it under 150 characters
- Make it engaging and authentic 
- Include relevant emojis where appropriate
- Avoid being too generic - be specific to what you see
- Match the mood/vibe of the image
- Don't mention technical details about the photo itself

Return only the caption text, nothing else.''';
    }

    final isWalker = user.isWalker;
    final userName = user.displayName.split(' ').first;
    final userRole = isWalker ? 'dog walker' : 'dog owner';
    
    String contextualGuidelines = '';
    
    if (isWalker) {
      // Dog walker context
      final walkerProfile = user.walkerProfile;
      String walkerContext = '';
      
      if (walkerProfile != null) {
        final rating = walkerProfile.averageRating;
        final totalReviews = walkerProfile.totalReviews;
        final city = walkerProfile.city;
        final recentWalks = walkerProfile.recentWalks;
        
        walkerContext = '''
WALKER PROFILE:
- City: $city
- Rating: ${rating > 0 ? '$rating/5 (${totalReviews} reviews)' : 'No reviews yet'}
- Recent walks: ${recentWalks.length} completed

IMPORTANT: If you see a dog in the photo, this is likely a dog ${recentWalks.isNotEmpty ? 'from a recent walk' : 'they are walking'}. Focus on the professional care and service aspect.
''';
      }
      
      contextualGuidelines = '''
You are helping ${userName}, a professional dog walker, create engaging social media captions for their dog walking business.

CONTEXT:
- User: ${userName} (Professional Dog Walker)
- Platform: Snapagram (dog walking social app)
- Audience: Other dog owners and walkers
- Purpose: Showcase professional dog walking services and care

$walkerContext

GUIDELINES:
- Keep it under 150 characters
- Make it engaging and authentic 
- Include relevant emojis where appropriate
- Focus on dog care, walking, and professional service
- If you see a dog, mention the activity (walking, playing, training)
- Highlight the quality of care and attention to detail
- Use a professional but friendly tone
- Don't mention technical details about the photo itself

EXAMPLES:
- "Another happy pup enjoying their afternoon walk! 🐕‍🦺"
- "Quality time with this sweetheart during our walk 🐕"
- "Professional care, happy dogs! 🐾"

Return only the caption text, nothing else.''';
    } else {
      // Dog owner context - include dog information
      final ownerProfile = user.ownerProfile;
      String dogContext = '';
      
      if (ownerProfile != null) {
        final dogName = ownerProfile.dogName;
        final dogBreed = ownerProfile.dogBreed;
        final dogAge = ownerProfile.dogAge;
        final dogSize = ownerProfile.dogSizeText;
        
        dogContext = '''
DOG INFORMATION:
- Dog's Name: ${dogName.isNotEmpty ? dogName : 'Not specified'}
- Breed: ${dogBreed ?? 'Not specified'}
- Age: ${dogAge != null ? '${dogAge} years old' : 'Not specified'}
- Size: $dogSize

IMPORTANT: If you see a dog in the photo and the dog's name is provided (${dogName.isNotEmpty ? dogName : 'not available'}), use the dog's name in the caption to make it personal. If no name is available, use "my pup" or "my dog".
''';
      }
      
      contextualGuidelines = '''
You are helping ${userName}, a dog owner, create engaging social media captions for their personal dog photos.

CONTEXT:
- User: ${userName} (Dog Owner)
- Platform: Snapagram (dog walking social app)
- Audience: Other dog owners and walkers
- Purpose: Share personal moments with their dog

$dogContext

GUIDELINES:
- Keep it under 150 characters
- Make it engaging and authentic 
- Include relevant emojis where appropriate
- Focus on the personal bond and relationship with the dog
- If you see a dog, make it personal and emotional
- Use the dog's name if provided.
- Show love and care for the dog
- Use a warm, personal tone
- Don't mention technical details about the photo itself

EXAMPLES:
${ownerProfile?.dogName.isNotEmpty == true ? '- "${ownerProfile!.dogName} and I enjoying the sunshine! ☀️🐕"' : '- "My best friend and I enjoying the sunshine! ☀️🐕"'}
- "Nothing beats quality time with my pup 🐾"
- "This little one always knows how to make me smile 😊"

Return only the caption text, nothing else.''';
    }

    return contextualGuidelines;
  }
} 