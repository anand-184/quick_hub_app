import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quick_hub_project/core/theme.dart';
import 'package:uuid/uuid.dart';
import '../../models/user_model.dart';
import '../../models/notification_model.dart';
import '../../models/review_model.dart';
import '../../view_models/auth_view_model.dart';
import '../../view_models/request_view_model.dart';
import '../../services/notification_service.dart';
import 'package:intl/intl.dart';

class ProviderDetailsScreen extends StatefulWidget {
  final UserModel provider;

  const ProviderDetailsScreen({super.key, required this.provider});

  @override
  State<ProviderDetailsScreen> createState() => _ProviderDetailsScreenState();
}

class _ProviderDetailsScreenState extends State<ProviderDetailsScreen> {
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  final _descriptionController = TextEditingController();
  bool isDark = false;

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  void _showRequestDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Schedule Service'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: Text(_selectedDate == null 
                        ? 'Select Date' 
                        : DateFormat('EEE, MMM dd, yyyy').format(_selectedDate!)),
                    leading: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now().add(const Duration(days: 1)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 30)),
                      );
                      if (picked != null) {
                        setDialogState(() => _selectedDate = picked);
                        setState(() {});
                      }
                    },
                  ),
                  ListTile(
                    title: Text(_selectedTime == null 
                        ? 'Select Time' 
                        : _selectedTime!.format(context)),
                    leading: const Icon(Icons.access_time),
                    onTap: () async {
                      final TimeOfDay? picked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      if (picked != null) {
                        setDialogState(() => _selectedTime = picked);
                        setState(() {});
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _descriptionController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Task Description',
                      hintText: 'Describe what needs to be done...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: (_selectedDate == null || _selectedTime == null) 
                    ? null 
                    : () => _submitRequest(),
                child: const Text('Send Request'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _submitRequest() async {
    final consumer = context.read<AuthViewModel>().currentUser;
    if (consumer == null) return;

    final scheduledDateTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    try {
      await context.read<RequestViewModel>().sendRequest(
        consumerId: consumer.uid,
        providerId: widget.provider.uid,
        serviceType: widget.provider.serviceType ?? 'General',
        location: consumer.location ?? widget.provider.location ?? const GeoPoint(0, 0),
        scheduledDate: scheduledDateTime,
        description: _descriptionController.text,
      );

      // Send notification
      await NotificationService().sendNotification(
        recipientId: widget.provider.uid,
        title: 'New Service Request',
        body: '${consumer.name} requested ${widget.provider.serviceType} for ${DateFormat('MMM dd, hh:mm a').format(scheduledDateTime)}',
        data: {
          'type': 'new_request',
          'requestId': const Uuid().v4(), // This should ideally match the request.requestId if available
        },
      );

      if (mounted) {
        Navigator.pop(context); // Close dialog
        Navigator.pop(context); // Go back to home
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Service request sent successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Provider Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: isDark ? Colors.grey.shade800 : AppTheme.primaryDarkBlue,
                    child: Icon(Icons.person, size: 60, color: isDark ? Colors.white : Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.provider.name, 
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppTheme.baseWhite : AppTheme.primaryDarkBlue,
                    )
                  ),
                  Text(
                    widget.provider.serviceType ?? 'General Service', 
                    style: TextStyle(
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, 
                      fontSize: 16
                    )
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            _buildInfoSection('About', widget.provider.bio ?? 'No bio available.'),
            const SizedBox(height: 20),
            _buildInfoSection('Hourly Rate', '₹${widget.provider.hourlyRate ?? 0} / hour'),
            const SizedBox(height: 20),
            
            // Rating Header
            Row(
              children: [
                const Icon(Icons.star, color: Colors.amber),
                const SizedBox(width: 8),
                Text(
                  '${widget.provider.rating.toStringAsFixed(1)} (${widget.provider.reviewCount} reviews)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppTheme.baseWhite : AppTheme.primaryDarkBlue,
                  )
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Reviews Section
            Text(
              'Reviews', 
              style: TextStyle(
                fontSize: 18, 
                fontWeight: FontWeight.bold,
                color: isDark ? AppTheme.baseWhite : AppTheme.primaryDarkBlue
              )
            ),
            const Divider(),
            StreamBuilder<List<ReviewModel>>(
              stream: FirebaseService().streamProviderReviews(widget.provider.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
                }
                final reviews = snapshot.data ?? [];
                if (reviews.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Text('No reviews yet.', style: TextStyle(color: isDark ? Colors.grey : Colors.grey.shade600)),
                  );
                }
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: reviews.length,
                  itemBuilder: (context, index) {
                    final review = reviews[index];
                    return _buildReviewItem(review);
                  },
                );
              },
            ),

            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.all(20),
        color: theme.scaffoldBackgroundColor,
        child: SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton(
            onPressed: _showRequestDialog,
            child: const Text('Request Service', style: TextStyle(fontSize: 18)),
          ),
        ),
      ),
    );
  }

  Widget _buildReviewItem(ReviewModel review) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Row(
                children: List.generate(5, (index) {
                  return Icon(
                    index < review.rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 16,
                  );
                }),
              ),
              const SizedBox(width: 8),
              Text(
                DateFormat('MMM dd, yyyy').format(review.timestamp),
                style: TextStyle(fontSize: 12, color: isDark ? Colors.grey : Colors.grey.shade600),
              ),
            ],
          ),
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              review.comment!,
              style: TextStyle(color: isDark ? AppTheme.baseWhite : Colors.black87),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title, 
          style: TextStyle(
            fontSize: 18, 
            fontWeight: FontWeight.bold,
            color: isDark ? AppTheme.baseWhite : AppTheme.primaryDarkBlue
          )
        ),
        const SizedBox(height: 8),
        Text(
          content, 
          style: TextStyle(
            fontSize: 15, 
            color: isDark ? Colors.grey.shade300 : Colors.black87
          )
        ),
      ],
    );
  }
}
