import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../view_models/auth_view_model.dart';
import '../../models/service_request_model.dart';
import '../../models/user_model.dart';
import '../../models/complaint_model.dart';
import '../../models/transaction_model.dart';
import '../../services/notification_service.dart';
import '../widgets/animated_bottom_nav.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shimmer/shimmer.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final FirebaseAnalytics analytics =FirebaseAnalytics.instance;
  int _selectedIndex = 0;

  final List<Widget> _tabs = [
    const RequestsAdminTab(),
    const UsersAdminTab(),
    const PaymentsAdminTab(),
    const StatsAdminTab(),
    const ComplaintsAdminTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: const Text('Admin Control Panel'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              context.read<AuthViewModel>().logout();
            }
          ),
        ],
      ),
      body: _tabs[_selectedIndex],
      bottomNavigationBar: AnimatedBottomNav(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: [
          BottomNavItem(icon: Icons.assignment, label: 'Requests'),
          BottomNavItem(icon: Icons.group, label: 'Profiles'),
          BottomNavItem(icon: Icons.payments, label: 'Payments'),
          BottomNavItem(icon: Icons.analytics, label: 'Stats'),
          BottomNavItem(icon: Icons.report_problem, label: 'Issues'),
        ],
      ),
    );
  }
}

Widget _buildShimmerListItem() {
  return Shimmer.fromColors(
    baseColor: Colors.grey[300]!,
    highlightColor: Colors.grey[100]!,
    child: Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: const CircleAvatar(backgroundColor: Colors.white),
        title: Container(width: double.infinity, height: 16, color: Colors.white),
        subtitle: Container(width: 150, height: 14, color: Colors.white),
      ),
    ),
  );
}

class RequestsAdminTab extends StatelessWidget {
  const RequestsAdminTab({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: "Service Requests"),
              Tab(text: "Provider Approvals"),
            ],
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey,
          ),
          Expanded(
            child: TabBarView(
              children: [
                const ServiceRequestsList(),
                const PendingProvidersList(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ServiceRequestsList extends StatelessWidget {
  const ServiceRequestsList({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('requests').orderBy('timestamp', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return ListView.builder(
            itemCount: 5,
            itemBuilder: (context, index) => _buildShimmerListItem(),
          );
        }
        final requests = snapshot.data!.docs.map((doc) => ServiceRequestModel.fromJson(doc.data() as Map<String, dynamic>)).toList();
        
        if (requests.isEmpty) return const Center(child: Text('No service requests found.'));

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 100),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
            return RequestAdminCard(request: request);
          },
        );
      },
    );
  }
}

class RequestAdminCard extends StatelessWidget {
  final ServiceRequestModel request;
  const RequestAdminCard({super.key, required this.request});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: _getStatusColor(request.status).withOpacity(0.1),
          child: Icon(_getServiceIcon(request.serviceType), color: _getStatusColor(request.status)),
        ),
        title: Text(request.serviceType, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('Status: ${request.status.name.toUpperCase()}', style: TextStyle(color: _getStatusColor(request.status), fontSize: 12)),
        trailing: Text(DateFormat('MMM dd').format(request.timestamp), style: const TextStyle(color: Colors.grey, fontSize: 12)),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                const SizedBox(height: 8),
                _buildUserDetailRow(context, 'Customer', request.consumerId),
                const SizedBox(height: 8),
                _buildUserDetailRow(context, 'Provider', request.providerId),
                const SizedBox(height: 12),
                const Text('Request Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                _buildInfoRow(Icons.description, 'Task', request.description ?? 'No description provided'),
                _buildInfoRow(Icons.access_time, 'Time', DateFormat('MMM dd, yyyy • hh:mm a').format(request.timestamp)),
                if (request.agreedPrice != null)
                  _buildInfoRow(Icons.payments, 'Price', '\$${request.agreedPrice!.toStringAsFixed(2)}'),
                _buildInfoRow(Icons.payment, 'Payment', request.paymentStatus.toUpperCase()),
                const SizedBox(height: 16),
                if (request.status == RequestStatus.pending || request.status == RequestStatus.accepted)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        FirebaseFirestore.instance.collection('requests').doc(request.requestId).update({'status': 'cancelled'});
                      },
                      icon: const Icon(Icons.cancel, size: 18),
                      label: const Text('Cancel Request'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                    ),
                  ),
                if (request.status == RequestStatus.cancelled)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _showDeleteConfirmation(context),
                      icon: const Icon(Icons.delete_forever, size: 18, color: Colors.red),
                      label: const Text('Delete Permanently', style: TextStyle(color: Colors.red)),
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Request?"),
        content: const Text("This action cannot be undone. Are you sure you want to permanently delete this cancelled request from the database?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Keep it")),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('requests').doc(request.requestId).delete();
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Request deleted successfully.")));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Yes, Delete"),
          ),
        ],
      ),
    );
  }

  Widget _buildUserDetailRow(BuildContext context, String label, String userId) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Text('Loading...');
        if (!snapshot.data!.exists) return Text('$label: Unknown User');
        
        final user = UserModel.fromJson(snapshot.data!.data() as Map<String, dynamic>);
        return Row(
          children: [
            Text('$label: ', style: const TextStyle(color: Colors.grey)),
            Expanded(child: Text(user.name, style: const TextStyle(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
            Flexible(child: Text(user.email, style: const TextStyle(fontSize: 11, color: Colors.blue), overflow: TextOverflow.ellipsis)),
          ],
        );
      },
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Color _getStatusColor(RequestStatus status) {
    switch (status) {
      case RequestStatus.accepted: return Colors.green;
      case RequestStatus.inProgress: return Colors.blue;
      case RequestStatus.completed: return Colors.orange;
      case RequestStatus.declined:
      case RequestStatus.cancelled: return Colors.red;
      default: return Colors.grey;
    }
  }

  IconData _getServiceIcon(String type) {
    type = type.toLowerCase();
    if (type.contains('plumb')) return Icons.plumbing;
    if (type.contains('elect')) return Icons.bolt;
    if (type.contains('clean')) return Icons.cleaning_services;
    if (type.contains('mech')) return Icons.build;
    if (type.contains('paint')) return Icons.format_paint;
    return Icons.settings;
  }
}

class PendingProvidersList extends StatelessWidget {
  const PendingProvidersList({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'provider')
          .where('isVerified', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return ListView.builder(
             itemCount: 5,
             itemBuilder: (context, index) => _buildShimmerListItem(),
          );
        }
        final providers = snapshot.data!.docs.map((doc) => UserModel.fromJson(doc.data() as Map<String, dynamic>)).toList();

        if (providers.isEmpty) return const Center(child: Text('No pending provider requests'));

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 100),
          itemCount: providers.length,
          itemBuilder: (context, index) {
            final provider = providers[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(provider.name),
                subtitle: Text('${provider.serviceType} | ${provider.city}, ${provider.state}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check_circle, color: Colors.green),
                      onPressed: () => _showApprovalDialog(context, provider),
                    ),
                    IconButton(
                      icon: const Icon(Icons.cancel, color: Colors.red),
                      onPressed: () {
                        FirebaseFirestore.instance.collection('users').doc(provider.uid).delete();
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showApprovalDialog(BuildContext context, UserModel provider) {
    final TextEditingController passwordController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Approve Provider"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Assign a temporary password for ${provider.name}"),
            const SizedBox(height: 15),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(
                hintText: "Enter temporary password",
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              final password = passwordController.text.trim();
              if (password.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Password must be at least 6 characters")),
                );
                return;
              }

              try {
                final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
                  email: provider.email,
                  password: password,
                );

                final newUid = userCredential.user!.uid;

                final providerData = provider.toJson();
                providerData['uid'] = newUid;
                providerData['isVerified'] = true;
                providerData['isActive'] = true;

                await FirebaseFirestore.instance.collection('users').doc(newUid).set(providerData);
                await FirebaseFirestore.instance.collection('users').doc(provider.uid).delete();
                
                // Notify provider of approval (might need to wait for them to log in first to get token, 
                // but we can send it anyway if they registered with one)
                await NotificationService().sendNotification(
                  recipientId: newUid,
                  title: 'Account Approved!',
                  body: 'Welcome to Quick Hub! Your provider account has been approved. Please login with your temporary password.',
                  data: {'type': 'approval'},
                );

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("${provider.name} approved! They can now login.")),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error: ${e.toString()}")),
                  );
                }
              }
            },
            child: const Text("Approve & Create Account"),
          ),
        ],
      ),
    );
  }
}

class UsersAdminTab extends StatelessWidget {
  const UsersAdminTab({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: "Active Providers"),
              Tab(text: "Consumers"),
            ],
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey,
          ),
          Expanded(
            child: TabBarView(
              children: [
                const ActiveProvidersList(),
                _buildConsumersList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsumersList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'consumer')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return ListView.builder(
            itemCount: 5,
            itemBuilder: (context, index) => _buildShimmerListItem(),
          );
        }
        final consumers = snapshot.data!.docs.map((doc) => UserModel.fromJson(doc.data() as Map<String, dynamic>)).toList();

        if (consumers.isEmpty) return const Center(child: Text('No consumers enrolled'));

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 100),
          itemCount: consumers.length,
          itemBuilder: (context, index) {
            final consumer = consumers[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(consumer.name),
                subtitle: Text(consumer.email),
                trailing: Switch(
                  value: consumer.isActive,
                  onChanged: (val) {
                    FirebaseFirestore.instance.collection('users').doc(consumer.uid).update({'isActive': val});
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class ActiveProvidersList extends StatelessWidget {
  const ActiveProvidersList({super.key});

  void _showProviderDetails(BuildContext context, UserModel provider) {
    final nameController = TextEditingController(text: provider.name);
    final ageController = TextEditingController(text: provider.age?.toString() ?? '');
    final bioController = TextEditingController(text: provider.bio ?? '');
    final aadhaarController = TextEditingController(text: provider.aadhaarNumber ?? '');
    final panController = TextEditingController(text: provider.panNumber ?? '');
    final hourlyRateController = TextEditingController(text: provider.hourlyRate?.toString() ?? '');
    String? gender = provider.gender;
    String? preferredLanguage = provider.preferredLanguage;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => DraggableScrollableSheet(
          initialChildSize: 0.8,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) => SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.blue.withOpacity(0.1),
                    child: const Icon(Icons.engineering, size: 50, color: Colors.blue),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(provider.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                ),
                Center(
                  child: Text(provider.serviceType ?? 'General Provider', style: const TextStyle(color: Colors.grey)),
                ),
                const SizedBox(height: 24),
                const Text('Personal Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Divider(),
                const SizedBox(height: 10),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: ageController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Age', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: ['Male', 'Female', 'Other'].contains(gender) ? gender : null,
                        decoration: const InputDecoration(labelText: 'Gender', border: OutlineInputBorder()),
                        items: ['Male', 'Female', 'Other'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                        onChanged: (val) => setModalState(() => gender = val),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: aadhaarController,
                  decoration: const InputDecoration(labelText: 'Aadhaar Number', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: panController,
                  decoration: const InputDecoration(labelText: 'PAN Number', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: ['English', 'Hindi', 'Punjabi', 'Other'].contains(preferredLanguage) ? preferredLanguage : null,
                  decoration: const InputDecoration(labelText: 'Language', border: OutlineInputBorder()),
                  items: ['English', 'Hindi', 'Punjabi', 'Other'].map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                  onChanged: (val) => setModalState(() => preferredLanguage = val),
                ),
                const SizedBox(height: 24),
                const Text('Professional Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Divider(),
                const SizedBox(height: 10),
                TextField(
                  controller: hourlyRateController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText:"Hourly Rate: - ${provider.hourlyRate}", border: const OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: bioController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Bio', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () async {
                      await FirebaseAnalytics.instance.logEvent(name: 'update_provider_details');
                      final updatedUser = UserModel(
                        uid: provider.uid,
                        name: nameController.text.trim(),
                        email: provider.email,
                        role: provider.role,
                        createdAt: provider.createdAt,
                        age: int.tryParse(ageController.text),
                        gender: gender,
                        aadhaarNumber: aadhaarController.text.trim(),
                        panNumber: panController.text.trim(),
                        preferredLanguage: preferredLanguage,
                        hourlyRate: double.tryParse(hourlyRateController.text),
                        bio: bioController.text.trim(),
                        serviceType: provider.serviceType,
                        rating: provider.rating,
                        reviewCount: provider.reviewCount,
                        isVerified: provider.isVerified,
                        isActive: provider.isActive,
                        isPremium: provider.isPremium,
                        location: provider.location,
                        fullAddress: provider.fullAddress,
                        city: provider.city,
                        state: provider.state,
                      );

                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(provider.uid)
                          .update(updatedUser.toJson());

                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Provider details updated successfully!')),
                        );
                      }
                    },
                    child: const Text('Update Provider Details'),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'provider')
          .where('isVerified', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return ListView.builder(
            itemCount: 5,
            itemBuilder: (context, index) => _buildShimmerListItem(),
          );
        }
        final providers = snapshot.data!.docs.map((doc) => UserModel.fromJson(doc.data() as Map<String, dynamic>)).toList();

        if (providers.isEmpty) return const Center(child: Text('No active providers'));

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 100),
          itemCount: providers.length,
          itemBuilder: (context, index) {
            final provider = providers[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                onTap: () => _showProviderDetails(context, provider),
                leading: Stack(
                  children: [
                    const CircleAvatar(child: Icon(Icons.engineering)),
                    if (provider.isPremium)
                       const Positioned(
                         bottom: 0,
                         right: 0,
                         child: Icon(Icons.star, color: Colors.amber, size: 14)
                       )
                  ],
                ),
                title: Text(provider.name),
                subtitle: Text(provider.serviceType ?? 'No Service'),
                trailing: SizedBox(
                  width: 100,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        tooltip: provider.isPremium ? "Remove Premium" : "Make Premium",
                        icon: Icon(Icons.workspace_premium, color: provider.isPremium ? Colors.amber : Colors.grey),
                        onPressed: () {
                           FirebaseFirestore.instance.collection('users').doc(provider.uid).update({'isPremium': !provider.isPremium});
                        }
                      ),
                      Expanded(
                        child: Switch(
                          value: provider.isActive,
                          onChanged: (val) {
                            FirebaseFirestore.instance.collection('users').doc(provider.uid).update({'isActive': val});
                          },
                        ),
                      ),
                    ],
                  ),
                )
              ),
            );
          },
        );
      },
    );
  }
}

class PaymentsAdminTab extends StatelessWidget {
  const PaymentsAdminTab({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('transactions').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(
            child: Shimmer.fromColors(
              baseColor: Colors.grey[300]!,
              highlightColor: Colors.grey[100]!,
              child: Container(
                margin: const EdgeInsets.all(20),
                height: 400,
                width: double.infinity,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              ),
            ),
          );
        }
        
        double totalRevenue = 0;
        double totalCommission = 0;
        double payoutsDue = 0;
        double totalPayoutCompleted = 0;

        for (var doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final txn = TransactionModel.fromJson(data);
          
          if (txn.status == PaymentStatus.completed) {
            totalRevenue += txn.totalAmount;
            totalCommission += txn.commissionAmount;
            if (!txn.isProviderPaid) {
              payoutsDue += txn.providerEarnings;
            } else {
              totalPayoutCompleted += txn.providerEarnings;
            }
          }
        }

        return ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
             const Text("Financial Analytics", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
             const SizedBox(height: 20),
             SizedBox(
               height: 200,
               child: Stack(
                 alignment: Alignment.center,
                 children: [
                   PieChart(
                     PieChartData(
                       sectionsSpace: 2,
                       centerSpaceRadius: 60,
                       sections: [
                         PieChartSectionData(
                           value: totalCommission,
                           color: Colors.green,
                           title: '10%\nCommission',
                           radius: 40,
                           titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                         ),
                         PieChartSectionData(
                           value: totalPayoutCompleted + payoutsDue,
                           color: Colors.blue,
                           title: '90%\nProviders',
                           radius: 40,
                           titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                         ),
                       ],
                     )
                   ),
                   const Text("Revenue\nSplit", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                 ],
               ),
             ),
             const SizedBox(height: 30),
            _buildStatCard('Total Platform Revenue', '\$${totalRevenue.toStringAsFixed(2)}', Colors.blue, 'Gross volume from consumers'),
            const SizedBox(height: 12),
            _buildStatCard('Retained Commission', '\$${totalCommission.toStringAsFixed(2)}', Colors.green, 'Platform earnings (10%)'),
            const SizedBox(height: 12),
            _buildStatCard('Provider Payouts Due', '\$${payoutsDue.toStringAsFixed(2)}', Colors.orange, 'Funds pending transfer to providers'),
            const SizedBox(height: 12),
            _buildStatCard('Payouts Complete', '\$${totalPayoutCompleted.toStringAsFixed(2)}', Colors.purple, 'Total funds disbursed'),
            const SizedBox(height: 100),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, Color color, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(title, style: TextStyle(fontSize: 16, color: color, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 8),
              Icon(Icons.monetization_on, color: color.withOpacity(0.5)),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }
}

class StatsAdminTab extends StatelessWidget {
  const StatsAdminTab({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('requests').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(
            child: Shimmer.fromColors(
              baseColor: Colors.grey[300]!,
              highlightColor: Colors.grey[100]!,
              child: Container(
                margin: const EdgeInsets.all(20),
                height: 400,
                width: double.infinity,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              ),
            ),
          );
        }
        
        int total = 0;
        int completed = 0;
        int pending = 0;
        int cancelled = 0;

        for (var doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          total++;
          final status = data['status'];
          if (status == 'completed') completed++;
          else if (status == 'cancelled' || status == 'declined') cancelled++;
          else pending++;
        }

        return ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            const Text("App Performance Analytics", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            if (total > 0)
              SizedBox(
                height: 150,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceEvenly,
                    maxY: total.toDouble(),
                    barTouchData: BarTouchData(enabled: false),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (val, meta) {
                            switch (val.toInt()) {
                              case 0: return const Text('Complete');
                              case 1: return const Text('Pending');
                              case 2: return const Text('Cancel');
                              default: return const Text('');
                            }
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    barGroups: [
                      BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: completed.toDouble(), color: Colors.green, width: 30, borderRadius: BorderRadius.circular(4))]),
                      BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: pending.toDouble(), color: Colors.orange, width: 30, borderRadius: BorderRadius.circular(4))]),
                      BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: cancelled.toDouble(), color: Colors.red, width: 30, borderRadius: BorderRadius.circular(4))]),
                    ],
                  )
                ),
              ),
            const SizedBox(height: 30),
            _buildMetricCard("Total Requests", "$total", Icons.layers),
            const SizedBox(height: 10),
            _buildMetricCard("Completed Services", "$completed", Icons.check_circle_outline, color: Colors.green),
            const SizedBox(height: 10),
            _buildMetricCard("Pending/In-Progress", "$pending", Icons.hourglass_empty, color: Colors.orange),
            const SizedBox(height: 10),
            _buildMetricCard("Cancelled/Declined", "$cancelled", Icons.cancel_outlined, color: Colors.red),
            const SizedBox(height: 100),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, {Color color = Colors.blue}) {
    return Card(
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
      ),
    );
  }
}

class ComplaintsAdminTab extends StatelessWidget {
  const ComplaintsAdminTab({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('complaints').orderBy('timestamp', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return ListView.builder(
            itemCount: 5,
            itemBuilder: (context, index) => _buildShimmerListItem(),
          );
        }
        
        final complaints = snapshot.data!.docs.map((doc) => ComplaintModel.fromJson(doc.data() as Map<String, dynamic>)).toList();

        if (complaints.isEmpty) return const Center(child: Text('No complaints submitted.'));

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 100),
          itemCount: complaints.length,
          itemBuilder: (context, index) {
            final complaint = complaints[index];
            final isOpen = complaint.status == 'open';

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Reported By: ${complaint.reporterId.substring(0, 5)}...', style: const TextStyle(fontWeight: FontWeight.bold)),
                        Chip(
                          label: Text(complaint.status.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10)),
                          backgroundColor: isOpen ? Colors.red : Colors.green,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(complaint.description),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(DateFormat('MMM dd, hh:mm a').format(complaint.timestamp), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        if (isOpen)
                          TextButton(
                            onPressed: () async {
                              await FirebaseAnalytics.instance.logEvent(name: 'resolve_complaint');
                              FirebaseFirestore.instance.collection('complaints').doc(complaint.complaintId).update({'status': 'resolved'});
                            },
                            child: const Text('Mark Resolved'),
                          )
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
