import 'dart:io';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../services/razorpay_service.dart';
import '../../services/firebase_service.dart';
import 'home_map_screen.dart';
import 'chat_screen.dart';
import 'notifications_screen.dart';
import 'provider_details_screen.dart';
import 'all_providers_screen.dart';
import '../widgets/animated_bottom_nav.dart';
import '../../view_models/auth_view_model.dart';
import '../../view_models/map_view_model.dart';
import '../../core/theme.dart';
import '../../models/complaint_model.dart';
import '../../models/user_model.dart';
import '../../models/service_request_model.dart';
import '../../models/review_model.dart';
import 'package:uuid/uuid.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';

class MainCustomerScreen extends StatefulWidget {
  const MainCustomerScreen({super.key});

  @override
  State<MainCustomerScreen> createState() => _MainCustomerScreenState();
}

class _MainCustomerScreenState extends State<MainCustomerScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final mapVM = context.watch<MapViewModel>();

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          IndexedStack(
            index: _selectedIndex,
            children: [
              const CustomerHomeTab(),
              const HomeMapScreen(),
              const CustomerBookingsTab(),
              const CustomerProfileTab(),
            ],
          ),
          if (mapVM.isFetchingLocation)
            Container(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const PulseAnimation(),
                    const SizedBox(height: 20),
                    Text(
                      "Fetching current location...",
                      style: TextStyle(
                        color: AppTheme.baseWhite,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: AnimatedBottomNav(
        currentIndex: _selectedIndex,
        backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.white,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: [
          BottomNavItem(icon: Icons.home, label: 'Home'),
          BottomNavItem(icon: Icons.map, label: 'Map'),
          BottomNavItem(icon: Icons.assignment, label: 'Bookings'),
          BottomNavItem(icon: Icons.person, label: 'Profile'),
        ],
      ),
    );
  }
}

class PulseAnimation extends StatefulWidget {
  const PulseAnimation({super.key});

  @override
  State<PulseAnimation> createState() => _PulseAnimationState();
}

class _PulseAnimationState extends State<PulseAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.primaryColor;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: primaryColor.withOpacity(0.2 * (1 - _controller.value)),
            border: Border.all(
              color: primaryColor.withOpacity(1 - _controller.value),
              width: 4 * _controller.value,
            ),
          ),
          child: Center(
            child: Icon(
              Icons.location_on,
              color: isDark ? AppTheme.baseWhite : primaryColor,
              size: 30,
            ),
          ),
        );
      },
    );
  }
}

class CustomerHomeTab extends StatelessWidget {
  const CustomerHomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authVM = context.watch<AuthViewModel>();
    final mapVM = context.watch<MapViewModel>();
    final userName = authVM.currentUser?.name ?? 'Guest';

    final List<Map<String, dynamic>> promoCards = [
      {
        'title': 'Best Services',
        'desc': 'Professional help for your home\njust a tap away.',
        'gradient': [AppTheme.primaryDarkBlue, const Color(0xFF1E3A8A)],
        'icon': Icons.stars,
      },
      {
        'title': 'Home Sparkle Deal',
        'desc': 'Get 30% off on full home\ncleaning services this week.',
        'gradient': [const Color(0xFF1E40AF), const Color(0xFF3B82F6)],
        'icon': Icons.cleaning_services,
      },
    ];

    final List<Map<String, dynamic>> categories = [
      {'name': 'Plumbing', 'icon': Icons.plumbing},
      {'name': 'Electric', 'icon': Icons.bolt},
      {'name': 'Cleaning', 'icon': Icons.cleaning_services},
      {'name': 'Mechanic', 'icon': Icons.build},
      {'name': 'Painter', 'icon': Icons.format_paint},
    ];

    return Container(
      color: isDark ? AppTheme.darkBackground : const Color(0xFFFBFBFF),
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 15),
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.primaryLightBlue,
                        child: Icon(Icons.person, color: isDark ? AppTheme.baseWhite : theme.primaryColor),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hello $userName',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppTheme.baseWhite : AppTheme.primaryDarkBlue,
                            ),
                          ),
                          GestureDetector(
                            onTap: () async {
                              await FirebaseAnalytics.instance.logEvent(name: "location_Fatched");
                              mapVM.fetchLocation(force: true);
                            child: Row(
                              children: [
                                const Icon(Icons.location_on, size: 12, color: Colors.redAccent),
                                const SizedBox(width: 4),
                                SizedBox(
                                  width: MediaQuery.of(context).size.width * 0.5,
                                  child: Text(
                                    mapVM.locationError ?? (mapVM.currentAddress ?? "Fetching location..."),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: mapVM.locationError != null
                                          ? Colors.red
                                          : (isDark ? Colors.grey.shade400 : Colors.grey),
                                      decoration: TextDecoration.underline,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            );
                            }
                          ),
                        ],
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkSurface : AppTheme.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), 
                            blurRadius: 10
                          )
                        ],
                      ),
                      child: Icon(
                        Icons.notifications_none_rounded, 
                        color: isDark ? AppTheme.baseWhite : AppTheme.primaryDarkBlue
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 25),

              // Search Bar
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      height: 55,
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkSurface : AppTheme.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.2 : 0.03), 
                            blurRadius: 10
                          )
                        ],
                      ),
                      child: TextField(

                        onChanged: (value) async {
                          context.read<MapViewModel>().setSearchQuery(value);
                        },
                        style: TextStyle(color: isDark ? AppTheme.baseWhite : Colors.black),
                        decoration: InputDecoration(
                          hintText: 'Search Service',
                          hintStyle: TextStyle(color: isDark ? Colors.grey.shade500 : Colors.grey.shade400),
                          icon: Icon(Icons.search, color: isDark ? Colors.grey.shade500 : Colors.grey.shade400),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  GestureDetector(
                    onTap: () {
                      // Filter dialog could be added here
                    },
                    child: Container(
                      height: 55,
                      width: 55,
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkSurface : AppTheme.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                              blurRadius: 10
                          )
                        ],
                      ),
                      child: Icon(Icons.tune_rounded, color: isDark ? AppTheme.baseWhite : theme.primaryColor),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              // Horizontal Sliding Promo Cards
              SizedBox(
                height: 170,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: promoCards.length,
                  itemBuilder: (context, index) {
                    final card = promoCards[index];
                    return Container(
                      width: MediaQuery.of(context).size.width * 0.82,
                      margin: const EdgeInsets.only(right: 15),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: card['gradient'],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: (card['gradient'] as List<Color>)[0].withOpacity(0.2),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          )
                        ],
                      ),
                      child: Stack(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(25.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  card['title'],
                                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  card['desc'],
                                  style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            right: -10,
                            bottom: -10,
                            child: Icon(card['icon'], size: 120, color: Colors.white.withOpacity(0.15)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 30),

              // Categories Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Categories', 
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppTheme.baseWhite : null,
                    )
                  ),
                  GestureDetector(
                    onTap: () {
                      context.read<MapViewModel>().resetFilters();
                    },
                    child: Text(
                      'See All', 
                      style: TextStyle(
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade500, 
                        fontSize: 13
                      )
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Horizontal Categories
              SizedBox(
                height: 105,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 20),
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: () {
                              context.read<MapViewModel>().setCategory(cat['name']);
                            },
                            child: Container(
                              height: 65,
                              width: 65,
                              decoration: BoxDecoration(
                                color: isDark ? AppTheme.darkSurface : AppTheme.primaryLightBlue,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Icon(
                                cat['icon'], 
                                color: isDark ? AppTheme.baseWhite : AppTheme.primaryDarkBlue, 
                                size: 28
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            cat['name'],
                            style: TextStyle(
                              fontSize: 12, 
                              fontWeight: FontWeight.w500,
                              color: isDark ? AppTheme.baseWhite : Colors.black,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 25),

              // Nearby Providers Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Nearby Providers', 
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppTheme.baseWhite : null,
                    )
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const AllProvidersScreen()));
                    },
                    child: Text(
                      'See All', 
                      style: TextStyle(
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade500, 
                        fontSize: 13
                      )
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              // Nearby Providers Grid/List
              SizedBox(
                height: 220,
                child: mapVM.nearbyProviders.isEmpty 
                  ? Center(
                      child: Text(
                        "No providers found in this area.",
                        style: TextStyle(color: isDark ? AppTheme.baseWhite : Colors.black),
                      )
                    )
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: mapVM.nearbyProviders.length,
                      itemBuilder: (context, index) {
                        final provider = mapVM.nearbyProviders[index];
                        return _buildProviderCard(context, provider);
                      },
                    ),
              ),

              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProviderCard(BuildContext context, UserModel provider) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProviderDetailsScreen(provider: provider),
          ),
        );
      },
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 15, bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : AppTheme.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.02), 
              blurRadius: 10
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 100,
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkBackground : AppTheme.primaryLightBlue,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.person, 
                color: isDark ? AppTheme.baseWhite : AppTheme.primaryDarkBlue, 
                size: 40
              ),
            ),
            const SizedBox(height: 12),
            Text(
              provider.name,
              style: TextStyle(
                fontWeight: FontWeight.bold, 
                fontSize: 14,
                color: isDark ? AppTheme.baseWhite : Colors.black,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              provider.serviceType ?? 'General',
              style: TextStyle(
                color: isDark ? Colors.grey.shade400 : Colors.grey, 
                fontSize: 12
              ),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 14),
                    Text(
                      ' ${provider.rating.toStringAsFixed(1)}', 
                      style: TextStyle(
                        fontWeight: FontWeight.bold, 
                        fontSize: 12,
                        color: isDark ? AppTheme.baseWhite : Colors.black,
                      )
                    ),
                  ],
                ),
                Text(
                  '₹${provider.hourlyRate ?? 0}/hr', 
                  style: const TextStyle(
                    color: Colors.green, 
                    fontSize: 11, 
                    fontWeight: FontWeight.bold
                  )
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class CustomerBookingsTab extends StatefulWidget {
  const CustomerBookingsTab({super.key});

  @override
  State<CustomerBookingsTab> createState() => _CustomerBookingsTabState();
}

class _CustomerBookingsTabState extends State<CustomerBookingsTab> {
  late final RazorpayService _razorpayService;
  String? _processingRequestId;

  @override
  void initState() {
    super.initState();
    _razorpayService = RazorpayService();
    _razorpayService.onSuccess = _handlePaymentSuccess;
    _razorpayService.onFailure = _handlePaymentError;
  }

  @override
  void dispose() {
    _razorpayService.dispose();
    super.dispose();
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    if (_processingRequestId == null) return;
    
    final authVM = context.read<AuthViewModel>();
    final consumerId = authVM.currentUser!.uid;

    try {
      final doc = await FirebaseFirestore.instance.collection('requests').doc(_processingRequestId).get();
      final data = doc.data()!;
      final totalAmount = (data['agreedPrice'] as num).toDouble();
      final providerId = data['providerId'];

      await FirebaseService().processPayment(
        requestId: _processingRequestId!,
        consumerId: consumerId,
        providerId: providerId,
        totalAmount: totalAmount,
        paymentMethod: 'Razorpay',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment Successful!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error recording payment: $e')));
      }
    } finally {
      _processingRequestId = null;
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    _processingRequestId = null;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payment Failed: ${response.message}')));
  }

  void _startPayment(BuildContext context, String requestId, double amount) {
    final user = context.read<AuthViewModel>().currentUser;
    if (user == null) return;

    _processingRequestId = requestId;

    _razorpayService.openCheckout(
      amount: amount,
      name: 'Quick Hub Services',
      description: 'Payment for completed service',
      contact: '9999999999',
      email: user.email,
    );
  }

  void _showComplaintDialog(BuildContext context, String requestId, String accusedId) {
    final TextEditingController textController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.white,
          title: Text(
            'Report an Issue',
            style: TextStyle(color: isDark ? AppTheme.baseWhite : Colors.black),
          ),
          content: TextField(
            controller: textController,
            maxLines: 3,
            style: TextStyle(color: isDark ? AppTheme.baseWhite : Colors.black),
            decoration: InputDecoration(
              hintText: 'Describe the problem clearly...',
              hintStyle: TextStyle(color: isDark ? Colors.grey.shade500 : Colors.grey),
              border: const OutlineInputBorder(),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: isDark ? AppTheme.baseWhite.withOpacity(0.3) : Colors.grey),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final text = textController.text.trim();
                if (text.isEmpty) return;
                
                final consumerId = context.read<AuthViewModel>().currentUser?.uid;
                if (consumerId != null) {
                  final complaint = ComplaintModel(
                    complaintId: const Uuid().v4(),
                    reporterId: consumerId,
                    accusedId: accusedId,
                    requestId: requestId,
                    description: text,
                    timestamp: DateTime.now(),
                  );
                  await FirebaseService().submitComplaint(complaint);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report submitted successfully.')));
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Submit Report'),
            ),
          ],
        );
      },
    );
  }

  void _showRequestDetails(BuildContext context, ServiceRequestModel request) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RequestDetailsSheet(
        request: request,
        onPay: (id, amount) => _startPayment(context, id, amount),
        onReport: (id, accusedId) => _showComplaintDialog(context, id, accusedId),
        onRate: (id, providerId) => _showRatingDialog(context, id, providerId),
      ),
    );
  }

  void _showRatingDialog(BuildContext context, String requestId, String providerId) {
    double rating = 0;
    final commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return AlertDialog(
            backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.white,
            title: Text('Rate Service', style: TextStyle(color: isDark ? AppTheme.baseWhite : Colors.black)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return IconButton(
                      icon: Icon(
                        index < rating ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 32,
                      ),
                      onPressed: () => setDialogState(() => rating = index + 1.0),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: commentController,
                  maxLines: 3,
                  style: TextStyle(color: isDark ? AppTheme.baseWhite : Colors.black),
                  decoration: InputDecoration(
                    hintText: 'Share your experience...',
                    hintStyle: TextStyle(color: isDark ? Colors.grey.shade500 : Colors.grey),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: rating == 0 ? null : () async {
                  final authVM = context.read<AuthViewModel>();
                  final consumerId = authVM.currentUser!.uid;
                  
                  final review = ReviewModel(
                    reviewId: const Uuid().v4(),
                    consumerId: consumerId,
                    providerId: providerId,
                    requestId: requestId,
                    rating: rating,
                    comment: commentController.text.trim(),
                    timestamp: DateTime.now(),
                  );

                  await FirebaseService().submitReview(review);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thank you for your feedback!')));
                  }
                },
                child: const Text('Submit'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final consumerId = context.read<AuthViewModel>().currentUser?.uid;
    if (consumerId == null) {
      return Center(
        child: Text(
          "Please Login to see bookings.",
          style: TextStyle(color: isDark ? AppTheme.baseWhite : Colors.black),
        )
      );
    }

    return Column(
      children: [
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'My Bookings', 
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? AppTheme.baseWhite : Colors.black,
              )
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<ServiceRequestModel>>(
            stream: FirebaseService().streamConsumerRequests(consumerId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error: ${snapshot.error}',
                    style: TextStyle(color: isDark ? AppTheme.baseWhite : Colors.black),
                  )
                );
              }

              final bookings = snapshot.data ?? [];

              if (bookings.isEmpty) {
                return Center(
                  child: Text(
                    'You have no bookings.',
                    style: TextStyle(color: isDark ? AppTheme.baseWhite : Colors.black),
                  )
                );
              }

              return ListView.builder(
                itemCount: bookings.length,
                padding: const EdgeInsets.only(bottom: 100, left: 16, right: 16),
                itemBuilder: (context, index) {
                  final request = bookings[index];
                  return BookingListItem(
                    request: request,
                    onTap: () => _showRequestDetails(context, request),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class BookingListItem extends StatelessWidget {
  final ServiceRequestModel request;
  final VoidCallback onTap;

  const BookingListItem({super.key, required this.request, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color statusColor;
    switch (request.status) {
      case RequestStatus.accepted: statusColor = Colors.green; break;
      case RequestStatus.inProgress: statusColor = Colors.blue; break;
      case RequestStatus.completed: statusColor = Colors.orange; break;
      case RequestStatus.declined:
      case RequestStatus.cancelled: statusColor = Colors.red; break;
      default: statusColor = Colors.grey;
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: isDark ? AppTheme.darkSurface : AppTheme.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? AppTheme.baseWhite.withOpacity(0.1) : Colors.black.withOpacity(0.05)),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.build_circle_outlined, color: statusColor),
        ),
        title: Text(
          request.serviceType,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? AppTheme.baseWhite : Colors.black,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              DateFormat('MMM dd, yyyy • hh:mm a').format(request.timestamp),
              style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                request.status.name.toUpperCase(),
                style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        trailing: Icon(
          Icons.chevron_right, 
          color: isDark ? AppTheme.baseWhite.withOpacity(0.5) : Colors.grey
        ),
      ),
    );
  }
}

class RequestDetailsSheet extends StatelessWidget {
  final ServiceRequestModel request;
  final Function(String, double) onPay;
  final Function(String, String) onReport;
  final Function(String, String) onRate;

  const RequestDetailsSheet({
    super.key,
    required this.request,
    required this.onPay,
    required this.onReport,
    required this.onRate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Booking Details', 
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppTheme.baseWhite : Colors.black,
                )
              ),
              IconButton(
                onPressed: () => Navigator.pop(context), 
                icon: Icon(Icons.close, color: isDark ? AppTheme.baseWhite : Colors.black)
              ),
            ],
          ),
          const Divider(),
          const SizedBox(height: 16),
          _buildDetailRow(context, 'Service', request.serviceType),
          _buildDetailRow(context, 'Status', request.status.name.toUpperCase()),
          _buildDetailRow(context, 'Date', DateFormat('MMM dd, yyyy').format(request.timestamp)),
          _buildDetailRow(context, 'Time', DateFormat('hh:mm a').format(request.timestamp)),
          if (request.description != null && request.description!.isNotEmpty)
            _buildDetailRow(context, 'Description', request.description!),
          if (request.agreedPrice != null)
            _buildDetailRow(context, 'Agreed Price', '₹${request.agreedPrice!.toStringAsFixed(2)}'),
          _buildDetailRow(context, 'Payment Status', request.paymentStatus.toUpperCase()),
          const SizedBox(height: 32),
          Row(
            children: [
              if (request.status == RequestStatus.accepted || request.status == RequestStatus.inProgress)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(requestId: request.requestId, otherUserId: request.providerId)));
                    },
                    icon: const Icon(Icons.chat),
                    label: const Text('Chat'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryColor,
                      foregroundColor: AppTheme.baseWhite,
                    ),
                  ),
                ),
              if (request.status == RequestStatus.completed && request.paymentStatus == 'pending')
                const SizedBox(width: 12),
              if (request.status == RequestStatus.completed && request.paymentStatus == 'pending')
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      onPay(request.requestId, request.agreedPrice ?? 0);
                    },
                    icon: const Icon(Icons.payment),
                    label: const Text('Pay Now'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  ),
                ),
              if (request.status == RequestStatus.completed && request.paymentStatus == 'paid')
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      onRate(request.requestId, request.providerId);
                    },
                    icon: const Icon(Icons.star),
                    label: const Text('Rate Service'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                onReport(request.requestId, request.providerId);
              },
              icon: const Icon(Icons.report_problem, color: Colors.red),
              label: const Text('Report an Issue', style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120, 
            child: Text(
              label, 
              style: TextStyle(
                color: isDark ? Colors.grey.shade400 : Colors.grey, 
                fontWeight: FontWeight.w500
              )
            )
          ),
          Expanded(
            child: Text(
              value, 
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? AppTheme.baseWhite : Colors.black,
              )
            )
          ),
        ],
      ),
    );
  }
}

class CustomerProfileTab extends StatefulWidget {
  const CustomerProfileTab({super.key});

  @override
  State<CustomerProfileTab> createState() => _CustomerProfileTabState();
}

class _CustomerProfileTabState extends State<CustomerProfileTab> {
  final _nameController = TextEditingController();
  final _houseNoController = TextEditingController();
  final _buildingController = TextEditingController();
  final _landmarkController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _ageController = TextEditingController();
  String? _gender;
  GeoPoint? _currentLocation;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthViewModel>().currentUser;
    if (user != null) {
      _nameController.text = user.name;
      _houseNoController.text = user.houseNo ?? '';
      _buildingController.text = user.buildingName ?? '';
      _landmarkController.text = user.landmark ?? '';
      _cityController.text = user.city ?? '';
      _stateController.text = user.state ?? '';
      _ageController.text = user.age?.toString() ?? '';
      _gender = user.gender;
      _currentLocation = user.location;
    }
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.white,
          title: Text('Logout', style: TextStyle(color: isDark ? AppTheme.baseWhite : Colors.black)),
          content: Text('Are you sure you want to log out?', style: TextStyle(color: isDark ? AppTheme.baseWhite : Colors.black)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                await FirebaseAnalytics.instance.logEvent(name: "Customer_LogOut");
                Navigator.pop(context);
                context.read<AuthViewModel>().logout();
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(content: Text('Logged out successfully.'), backgroundColor: Colors.blue),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }

  void _showUpdateConfirmation() {
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.white,
          title: Text(
            'Update Profile',
            style: TextStyle(color: isDark ? AppTheme.baseWhite : Colors.black),
          ),
          content: Text(
            'Are you sure you want to save these changes?',
            style: TextStyle(color: isDark ? AppTheme.baseWhite : Colors.black),
          ),
          actions: [
            TextButton(onPressed: () async {
              await FirebaseAnalytics.instance.logEvent(name: "Customer_details_updated");
              Navigator.pop(context);
            }, child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _saveProfile();
              },
              child: const Text('Confirm Update'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveProfile() async {
    final authVM = context.read<AuthViewModel>();
    final user = authVM.currentUser;
    if (user != null) {
      final fullAddress = "${_houseNoController.text}, ${_buildingController.text}, ${_landmarkController.text}, ${_cityController.text}, ${_stateController.text}";
      
      final updatedUser = UserModel(
        uid: user.uid,
        name: _nameController.text,
        email: user.email,
        role: user.role,
        createdAt: user.createdAt,
        houseNo: _houseNoController.text,
        buildingName: _buildingController.text,
        landmark: _landmarkController.text,
        city: _cityController.text,
        state: _stateController.text,
        fullAddress: fullAddress,
        age: int.tryParse(_ageController.text),
        gender: _gender,
        isActive: user.isActive,
        profileImage: user.profileImage,
        location: _currentLocation ?? user.location,
      );
      
      final success = await authVM.updateProfile(updatedUser);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Profile updated successfully!' : 'Failed to update profile.'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _useGPS() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location services are disabled.')));
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permission denied.')));
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permissions are permanently denied.')));
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition();
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      Placemark place = placemarks[0];
      
      setState(() {
        _currentLocation = GeoPoint(position.latitude, position.longitude);
        _houseNoController.text = place.name ?? '';
        _buildingController.text = place.subLocality ?? '';
        _landmarkController.text = place.thoroughfare ?? '';
        _cityController.text = place.locality ?? '';
        _stateController.text = place.administrativeArea ?? '';
      });
      
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location fetched successfully!'), backgroundColor: Colors.green));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to fetch location.'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textStyle = TextStyle(color: isDark ? AppTheme.baseWhite : Colors.black);
    final inputDecoration = InputDecoration(
      labelStyle: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey),
      border: const OutlineInputBorder(),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: isDark ? AppTheme.baseWhite.withOpacity(0.3) : Colors.grey),
      ),
    );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16.0, 10.0, 16.0, 100.0), // Reduced top padding
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'My Profile', 
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppTheme.baseWhite : Colors.black,
                  )
                ),
                IconButton(

                  icon: const Icon(Icons.logout, color: Colors.red),
                  onPressed: _showLogoutConfirmation,
                ),
              ],
            ),
            const SizedBox(height: 10), // Small gap before profile image
            Center(
              child: CircleAvatar(
                radius: 50,
                backgroundColor: isDark ? AppTheme.darkSurface : Theme.of(context).primaryColor.withOpacity(0.1),
                child: Icon(
                  Icons.person, 
                  size: 50, 
                  color: isDark ? AppTheme.baseWhite : Theme.of(context).primaryColor
                ),
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _nameController,
              style: textStyle,
              decoration: inputDecoration.copyWith(labelText: 'Full Name'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ageController,
                    keyboardType: TextInputType.number,
                    style: textStyle,
                    decoration: inputDecoration.copyWith(labelText: 'Age'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _gender,
                    dropdownColor: isDark ? AppTheme.darkSurface : AppTheme.white,
                    decoration: inputDecoration.copyWith(labelText: 'Gender'),
                    items: ['Male', 'Female', 'Other'].map((g) => DropdownMenuItem(
                      value: g, 
                      child: Text(g, style: textStyle)
                    )).toList(),
                    onChanged: (val) => setState(() => _gender = val),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Location Details', 
                  style: TextStyle(
                    fontSize: 18, 
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppTheme.baseWhite : Colors.black,
                  )
                ),
                TextButton.icon(
                  onPressed: _useGPS,
                  icon: const Icon(Icons.my_location),
                  label: const Text('Use GPS'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _houseNoController,
              style: textStyle,
              decoration: inputDecoration.copyWith(labelText: 'House No. / Flat No.'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _buildingController,
              style: textStyle,
              decoration: inputDecoration.copyWith(labelText: 'Building Name / Apartment'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _landmarkController,
              style: textStyle,
              decoration: inputDecoration.copyWith(labelText: 'Landmark'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _cityController,
                    style: textStyle,
                    decoration: inputDecoration.copyWith(labelText: 'City'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _stateController,
                    style: textStyle,
                    decoration: inputDecoration.copyWith(labelText: 'State'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _showUpdateConfirmation,
                child: const Text('Save Profile'),
              ),
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
}
