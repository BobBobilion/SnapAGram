import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/review.dart';
import '../../models/user_model.dart';
import '../../services/review_service.dart';
import '../../services/ai_review_service.dart';
import '../../services/conversation_analysis_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/rating_display_widget.dart';

class ReviewSubmissionScreen extends ConsumerStatefulWidget {
  final UserModel currentUser;
  final UserModel targetUser;
  final String? chatId;

  const ReviewSubmissionScreen({
    super.key,
    required this.currentUser,
    required this.targetUser,
    this.chatId,
  });

  @override
  ConsumerState<ReviewSubmissionScreen> createState() => _ReviewSubmissionScreenState();
}

class _ReviewSubmissionScreenState extends ConsumerState<ReviewSubmissionScreen> {
  final _commentController = TextEditingController();
  double _rating = 0;
  bool _isLoading = false;
  bool _isSubmitting = false;
  AiReviewSuggestion? _aiSuggestion;
  bool _showingSuggestion = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _generateAISuggestion();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _generateAISuggestion() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final aiService = ref.read(aiReviewServiceProvider);
      final suggestion = await aiService.generateReviewSuggestion(
        reviewerId: widget.currentUser.uid,
        targetUserId: widget.targetUser.uid,
        reviewer: widget.currentUser,
        targetUser: widget.targetUser,
        chatId: widget.chatId,
      );

      setState(() {
        _aiSuggestion = suggestion;
        _rating = suggestion.suggestedRating;
        _commentController.text = suggestion.suggestedComment;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Unable to generate AI suggestion. You can still write your own review.';
        _rating = 3.0; // Default rating
      });
    }
  }

  Future<void> _submitReview() async {
    if (_rating == 0) {
      _showError('Please select a rating');
      return;
    }

    if (_commentController.text.trim().isEmpty) {
      _showError('Please write a comment');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final reviewService = ref.read(reviewServiceProvider);
      
      await reviewService.submitReview(
        reviewerId: widget.currentUser.uid,
        reviewerName: widget.currentUser.displayName,
        reviewerProfilePictureUrl: widget.currentUser.profilePictureUrl ?? '',
        targetUserId: widget.targetUser.uid,
        rating: _rating,
        comment: _commentController.text.trim(),
        wasAiGenerated: _showingSuggestion && _aiSuggestion != null,
        aiSuggestion: _aiSuggestion?.suggestedComment,
      );

      if (mounted) {
        print('🎯 [UI] Review submission completed, navigating back...');
        Navigator.of(context).pop(true); // Return success
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Review submitted successfully!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        
        print('🎯 [UI] Success message shown, should trigger UI refresh');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to submit review: $e';
        _isSubmitting = false;
      });
    }
  }

  void _showError(String message) {
    setState(() {
      _errorMessage = message;
    });
  }

  void _toggleSuggestionMode() {
    setState(() {
      _showingSuggestion = !_showingSuggestion;
      if (_showingSuggestion && _aiSuggestion != null) {
        // Switch back to AI suggestion
        _rating = _aiSuggestion!.suggestedRating;
        _commentController.text = _aiSuggestion!.suggestedComment;
      } else {
        // Switch to manual mode
        _rating = 3.0;
        _commentController.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.grey[600]),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Write a Review',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        actions: [
          TextButton(
            onPressed: (_isSubmitting || _isLoading) ? null : _submitReview,
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    'Submit',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.getPrimaryColor(widget.currentUser),
                    ),
                  ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildUserInfo(),
              const SizedBox(height: 24),
              if (_isLoading) ...[
                _buildLoadingState(),
              ] else ...[
                if (_aiSuggestion != null) ...[
                  _buildAISuggestionSection(),
                  const SizedBox(height: 24),
                ],
                _buildRatingSection(),
                const SizedBox(height: 24),
                _buildCommentSection(),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  _buildErrorMessage(),
                ],
                const SizedBox(height: 32),
                _buildSubmitButton(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserInfo() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 35,
              backgroundImage: widget.targetUser.profilePictureUrl != null
                  ? NetworkImage(widget.targetUser.profilePictureUrl!)
                  : null,
              backgroundColor: AppTheme.getColorShade(widget.targetUser, 100),
              child: widget.targetUser.profilePictureUrl == null
                  ? Icon(
                      Icons.person,
                      color: AppTheme.getPrimaryColor(widget.targetUser),
                      size: 40,
                    )
                  : null,
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.targetUser.displayName,
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.targetUser.roleText,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  if (widget.targetUser.handle != null && widget.targetUser.handle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      widget.targetUser.handle!,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            CircularProgressIndicator(
              color: AppTheme.getPrimaryColor(widget.currentUser),
            ),
            const SizedBox(height: 20),
            Text(
              'Analyzing your recent interactions...',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'This may take a few moments',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAISuggestionSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.blue[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.blue[200]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  color: Colors.blue[700],
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'AI Generated Suggestion',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue[700],
                    ),
                  ),
                ),
                Switch(
                  value: _showingSuggestion,
                  onChanged: (value) => _toggleSuggestionMode(),
                  activeColor: Colors.blue[700],
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_showingSuggestion) ...[
              Text(
                'Based on your recent interactions:',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 12),
              if (_aiSuggestion!.conversationHighlights.isNotEmpty) ...[
                ...(_aiSuggestion!.conversationHighlights.take(3).map(
                  (highlight) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 6),
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: Colors.blue[600],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            highlight,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )),
              ],
              if (_aiSuggestion!.imageAnalysis.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Image Analysis:',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.blue[700],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _aiSuggestion!.imageAnalysis.first,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              // Debug section for detailed image analysis
              if (kDebugMode) ...[
                const SizedBox(height: 16),
                _buildDebugImageAnalysisSection(),
              ],
            ] else ...[
              Text(
                'Write your own review using the fields below.',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Debug section to show detailed image analysis
  Widget _buildDebugImageAnalysisSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.bug_report,
                color: Colors.orange[700],
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'DEBUG: Detailed Image Analysis',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Show detailed image analysis if available
          if (_aiSuggestion?.detailedImageAnalyses != null && _aiSuggestion!.detailedImageAnalyses!.isNotEmpty) ...[
            Text(
              'Image Analysis Count: ${_aiSuggestion!.detailedImageAnalyses!.length}',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.orange[700],
              ),
            ),
            const SizedBox(height: 8),
            ...(_aiSuggestion!.detailedImageAnalyses!.asMap().entries.map(
              (entry) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Image ${entry.key + 1}:',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange[700],
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange[100],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Q: ${entry.value.qualityScore.toStringAsFixed(1)} | R: ${entry.value.relevanceScore.toStringAsFixed(1)}',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: Colors.orange[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Description:',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                    Text(
                      entry.value.description,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                    if (entry.value.observations.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Observations:',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[700],
                        ),
                      ),
                      Text(
                        entry.value.observations,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                    if (entry.value.tags.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Tags:',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[700],
                        ),
                      ),
                      Wrap(
                        spacing: 4,
                        children: entry.value.tags.map((tag) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            tag,
                            style: GoogleFonts.poppins(
                              fontSize: 9,
                              color: Colors.blue[700],
                            ),
                          ),
                        )).toList(),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      'Timestamp: ${entry.value.timestamp.toString().substring(0, 19)}',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            )),
          ] else if (_aiSuggestion?.imageAnalysis != null && _aiSuggestion!.imageAnalysis.isNotEmpty) ...[
            // Fallback to string-based image analysis
            Text(
              'Image Analysis Count: ${_aiSuggestion!.imageAnalysis.length}',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.orange[700],
              ),
            ),
            const SizedBox(height: 8),
            ...(_aiSuggestion!.imageAnalysis.asMap().entries.map(
              (entry) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Image ${entry.key + 1}:',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange[700],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Description: ${entry.value}',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Note: Full ImageAnalysis data not available in current implementation',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            )),
          ] else ...[
            Text(
              'No images analyzed',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRatingSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your Rating',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: StarRatingInput(
                initialRating: _rating,
                onRatingChanged: (rating) {
                  setState(() {
                    _rating = rating;
                    // If user changes rating manually, switch off suggestion mode
                    if (_showingSuggestion && _aiSuggestion != null && rating != _aiSuggestion!.suggestedRating) {
                      _showingSuggestion = false;
                    }
                  });
                },
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                _getRatingText(_rating),
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: _getRatingColor(_rating),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your Review',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _commentController,
              maxLines: 6,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: 'Share your experience with ${widget.targetUser.displayName}...',
                hintStyle: GoogleFonts.poppins(
                  color: Colors.grey[500],
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.getPrimaryColor(widget.currentUser)),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.grey[800],
              ),
              onChanged: (text) {
                // If user edits comment manually, switch off suggestion mode
                if (_showingSuggestion && _aiSuggestion != null && text != _aiSuggestion!.suggestedComment) {
                  setState(() {
                    _showingSuggestion = false;
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red[700], size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage!,
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.red[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: (_isSubmitting || _isLoading) ? null : _submitReview,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.getPrimaryColor(widget.currentUser),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: _isSubmitting
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Submitting...',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              )
            : Text(
                'Submit Review',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  String _getRatingText(double rating) {
    if (rating == 0) return 'Select a rating';
    if (rating <= 1) return 'Poor';
    if (rating <= 2) return 'Fair';
    if (rating <= 3) return 'Good';
    if (rating <= 4) return 'Very Good';
    return 'Excellent';
  }

  Color _getRatingColor(double rating) {
    if (rating == 0) return Colors.grey[600]!;
    if (rating <= 2) return Colors.red[600]!;
    if (rating <= 3) return Colors.orange[600]!;
    if (rating <= 4) return Colors.blue[600]!;
    return Colors.green[600]!;
  }
} 