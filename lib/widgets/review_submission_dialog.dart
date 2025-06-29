import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/review.dart';
import '../models/user_model.dart';
import '../services/review_service.dart';
import '../services/ai_review_service.dart';
import '../services/conversation_analysis_service.dart';
import '../utils/app_theme.dart';
import 'rating_display_widget.dart';

class ReviewSubmissionDialog extends ConsumerStatefulWidget {
  final UserModel currentUser;
  final UserModel targetUser;
  final String? chatId;

  const ReviewSubmissionDialog({
    super.key,
    required this.currentUser,
    required this.targetUser,
    this.chatId,
  });

  @override
  ConsumerState<ReviewSubmissionDialog> createState() => _ReviewSubmissionDialogState();
}

class _ReviewSubmissionDialogState extends ConsumerState<ReviewSubmissionDialog> {
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
        Navigator.of(context).pop(true); // Return success
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Review submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
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
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
          maxWidth: 500,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildUserInfo(),
                    const SizedBox(height: 24),
                    if (_isLoading) ...[
                      _buildLoadingState(),
                    ] else ...[
                      if (_aiSuggestion != null) _buildAISuggestionSection(),
                      const SizedBox(height: 24),
                      _buildRatingSection(),
                      const SizedBox(height: 24),
                      _buildCommentSection(),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 16),
                        _buildErrorMessage(),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.getPrimaryColor(widget.currentUser),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.rate_review,
            color: Colors.white,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Write a Review',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildUserInfo() {
    return Row(
      children: [
        CircleAvatar(
          radius: 25,
          backgroundImage: widget.targetUser.profilePictureUrl != null
              ? NetworkImage(widget.targetUser.profilePictureUrl!)
              : null,
          backgroundColor: AppTheme.getColorShade(widget.targetUser, 100),
          child: widget.targetUser.profilePictureUrl == null
              ? Icon(
                  Icons.person,
                  color: AppTheme.getPrimaryColor(widget.targetUser),
                  size: 30,
                )
              : null,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.targetUser.displayName,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              Text(
                widget.targetUser.roleText,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          CircularProgressIndicator(
            color: AppTheme.getPrimaryColor(widget.currentUser),
          ),
          const SizedBox(height: 16),
          Text(
            'Analyzing your recent interactions...',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'This may take a few moments',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAISuggestionSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
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
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'AI Generated Suggestion',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue[700],
                ),
              ),
              const Spacer(),
              Switch(
                value: _showingSuggestion,
                onChanged: (value) => _toggleSuggestionMode(),
                activeColor: Colors.blue[700],
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_showingSuggestion) ...[
            Text(
              'Based on your recent interactions:',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            if (_aiSuggestion!.conversationHighlights.isNotEmpty) ...[
              ...(_aiSuggestion!.conversationHighlights.take(3).map(
                (highlight) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('• ', style: TextStyle(color: Colors.grey[600])),
                      Expanded(
                        child: Text(
                          highlight,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )),
            ],
          ] else ...[
            Text(
              'Write your own review using the fields below.',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRatingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Rating',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 12),
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
        const SizedBox(height: 8),
        Center(
          child: Text(
            _getRatingText(_rating),
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: _getRatingColor(_rating),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCommentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Review',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _commentController,
          maxLines: 4,
          maxLength: 500,
          decoration: InputDecoration(
            hintText: 'Share your experience...',
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
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red[700], size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.red[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: (_isSubmitting || _isLoading) ? null : _submitReview,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.getPrimaryColor(widget.currentUser),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      'Submit Review',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
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