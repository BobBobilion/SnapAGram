import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/review.dart';
import '../services/review_service.dart';
import '../utils/app_theme.dart';
import 'rating_display_widget.dart';

class ReviewsListWidget extends ConsumerWidget {
  final String userId;
  final bool showUserInfo;
  final ScrollPhysics? physics;

  const ReviewsListWidget({
    super.key,
    required this.userId,
    this.showUserInfo = true,
    this.physics,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewService = ref.watch(reviewServiceProvider);

    return StreamBuilder<List<Review>>(
      stream: reviewService.getUserReviews(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }

        if (snapshot.hasError) {
          return _buildErrorState(snapshot.error.toString());
        }

        final reviews = snapshot.data ?? [];

        if (reviews.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.separated(
          physics: physics,
          shrinkWrap: true,
          itemCount: reviews.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            return ReviewCard(
              review: reviews[index],
              showUserInfo: showUserInfo,
            );
          },
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.red[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading reviews',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.rate_review_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No reviews yet',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Reviews from connections will appear here',
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
}

class ReviewCard extends StatelessWidget {
  final Review review;
  final bool showUserInfo;
  final VoidCallback? onTap;

  const ReviewCard({
    super.key,
    required this.review,
    this.showUserInfo = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 12),
              _buildRating(),
              if (review.comment.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildComment(),
              ],
              const SizedBox(height: 12),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    if (!showUserInfo) {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundImage: review.reviewerProfilePictureUrl.isNotEmpty
              ? NetworkImage(review.reviewerProfilePictureUrl)
              : null,
          backgroundColor: Colors.grey[300],
          child: review.reviewerProfilePictureUrl.isEmpty
              ? Icon(
                  Icons.person,
                  color: Colors.grey[600],
                  size: 20,
                )
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                review.reviewerName,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
              Text(
                _formatTimeAgo(review.createdAt),
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        if (review.wasAiGenerated) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.auto_awesome,
                  size: 12,
                  color: Colors.blue[700],
                ),
                const SizedBox(width: 4),
                Text(
                  'AI',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRating() {
    return Row(
      children: [
        RatingDisplayWidget(
          reviewSummary: ReviewSummary(
            averageRating: review.rating,
            totalReviews: 1,
            ratingBreakdown: {},
            lastUpdated: review.createdAt,
          ),
          compact: true,
        ),
        const Spacer(),
        Text(
          _getRatingText(review.rating),
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: _getRatingColor(review.rating),
          ),
        ),
      ],
    );
  }

  Widget _buildComment() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Text(
        review.comment,
        style: GoogleFonts.poppins(
          fontSize: 14,
          color: Colors.grey[700],
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Row(
      children: [
        Icon(
          Icons.access_time,
          size: 14,
          color: Colors.grey[500],
        ),
        const SizedBox(width: 4),
        Text(
          _formatDate(review.createdAt),
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.grey[500],
          ),
        ),
        const Spacer(),
        if (review.wasAiGenerated) ...[
          Tooltip(
            message: 'This review was generated using AI based on recent interactions',
            child: Icon(
              Icons.info_outline,
              size: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ],
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '${weeks}w ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '${months}mo ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return '${years}y ago';
    }
  }

  String _formatDate(DateTime dateTime) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    
    return '${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year}';
  }

  String _getRatingText(double rating) {
    if (rating <= 1) return 'Poor';
    if (rating <= 2) return 'Fair';
    if (rating <= 3) return 'Good';
    if (rating <= 4) return 'Very Good';
    return 'Excellent';
  }

  Color _getRatingColor(double rating) {
    if (rating <= 2) return Colors.red[600]!;
    if (rating <= 3) return Colors.orange[600]!;
    if (rating <= 4) return Colors.blue[600]!;
    return Colors.green[600]!;
  }
}

class ReviewsSummaryCard extends StatelessWidget {
  final ReviewSummary reviewSummary;
  final VoidCallback? onViewAll;

  const ReviewsSummaryCard({
    super.key,
    required this.reviewSummary,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Reviews',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const Spacer(),
                if (onViewAll != null)
                  TextButton(
                    onPressed: onViewAll,
                    child: Text(
                      'View All',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            RatingDisplayWidget(
              reviewSummary: reviewSummary,
              showBreakdown: true,
            ),
          ],
        ),
      ),
    );
  }
} 