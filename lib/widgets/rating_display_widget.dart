import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/review.dart';

class RatingDisplayWidget extends StatelessWidget {
  final ReviewSummary? reviewSummary;
  final bool showBreakdown;
  final bool compact;
  final VoidCallback? onTap;

  const RatingDisplayWidget({
    super.key,
    this.reviewSummary,
    this.showBreakdown = false,
    this.compact = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (reviewSummary == null || !reviewSummary!.hasReviews) {
      return _buildNoReviews(context);
    }

    if (compact) {
      return _buildCompactRating(context);
    }

    return _buildFullRating(context);
  }

  Widget _buildNoReviews(BuildContext context) {
    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildStars(0, size: 14),
          const SizedBox(width: 4),
          Text(
            'No reviews',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStars(0),
        const SizedBox(height: 4),
        Text(
          'No reviews yet',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildCompactRating(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStars(reviewSummary!.averageRating, size: 14),
            const SizedBox(width: 6),
            Text(
              reviewSummary!.formattedRating,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '(${reviewSummary!.totalReviews})',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullRating(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  reviewSummary!.formattedRating,
                  style: GoogleFonts.poppins(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStars(reviewSummary!.averageRating),
                      const SizedBox(height: 4),
                      Text(
                        '${reviewSummary!.totalReviews} review${reviewSummary!.totalReviews == 1 ? '' : 's'}',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (showBreakdown) ...[
              const SizedBox(height: 16),
              _buildRatingBreakdown(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStars(double rating, {double size = 20}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final starRating = index + 1;
        IconData iconData;
        Color color;

        if (rating >= starRating) {
          iconData = Icons.star;
          color = Colors.amber[600]!;
        } else if (rating >= starRating - 0.5) {
          iconData = Icons.star_half;
          color = Colors.amber[600]!;
        } else {
          iconData = Icons.star_border;
          color = Colors.grey[400]!;
        }

        return Icon(
          iconData,
          size: size,
          color: color,
        );
      }),
    );
  }

  Widget _buildRatingBreakdown(BuildContext context) {
    final breakdown = reviewSummary!.ratingBreakdown;
    final total = reviewSummary!.totalReviews;

    return Column(
      children: [
        for (int i = 5; i >= 1; i--) ...[
          Row(
            children: [
              Text(
                '$i',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.star,
                size: 14,
                color: Colors.amber[600],
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: total > 0 ? (breakdown[i] ?? 0) / total : 0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.amber[600],
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${breakdown[i] ?? 0}',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          if (i > 1) const SizedBox(height: 4),
        ],
      ],
    );
  }
}

class StarRatingInput extends StatefulWidget {
  final double initialRating;
  final ValueChanged<double> onRatingChanged;
  final bool allowHalfRatings;
  final double size;

  const StarRatingInput({
    super.key,
    this.initialRating = 0,
    required this.onRatingChanged,
    this.allowHalfRatings = true,
    this.size = 32,
  });

  @override
  State<StarRatingInput> createState() => _StarRatingInputState();
}

class _StarRatingInputState extends State<StarRatingInput> {
  late double _currentRating;

  @override
  void initState() {
    super.initState();
    _currentRating = widget.initialRating;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return GestureDetector(
          onTap: () {
            setState(() {
              _currentRating = (index + 1).toDouble();
            });
            widget.onRatingChanged(_currentRating);
          },
          onTapDown: widget.allowHalfRatings ? (details) {
            final RenderBox box = context.findRenderObject() as RenderBox;
            final localPosition = box.globalToLocal(details.globalPosition);
            final starWidth = widget.size;
            final starIndex = (localPosition.dx / starWidth).floor();
            final withinStar = (localPosition.dx % starWidth) / starWidth;
            
            double newRating;
            if (withinStar < 0.5) {
              newRating = starIndex + 0.5;
            } else {
              newRating = starIndex + 1.0;
            }
            
            newRating = newRating.clamp(0.5, 5.0);
            
            setState(() {
              _currentRating = newRating;
            });
            widget.onRatingChanged(_currentRating);
          } : null,
          child: Container(
            width: widget.size,
            height: widget.size,
            padding: const EdgeInsets.all(2),
            child: _buildStar(index + 1),
          ),
        );
      }),
    );
  }

  Widget _buildStar(int starNumber) {
    IconData iconData;
    Color color;

    if (_currentRating >= starNumber) {
      iconData = Icons.star;
      color = Colors.amber[600]!;
    } else if (_currentRating >= starNumber - 0.5) {
      iconData = Icons.star_half;
      color = Colors.amber[600]!;
    } else {
      iconData = Icons.star_border;
      color = Colors.grey[400]!;
    }

    return Icon(
      iconData,
      size: widget.size - 4,
      color: color,
    );
  }
} 