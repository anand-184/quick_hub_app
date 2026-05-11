import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';

// Services
import 'services/notification_service.dart';

// ViewModels
import 'view_models/auth_view_model.dart';
import 'view_models/map_view_model.dart';
import 'view_models/request_view_model.dart';
import 'view_models/chat_view_model.dart';

// Views
import 'package:quick_hub_project/view/screens/login_screen.dart';
import 'view/screens/splash_screen.dart';
import 'view/screens/main_customer_screen.dart';
import 'view/screens/provider_dashboard_screen.dart';
import 'view/screens/admin_dashboard_screen.dart';
import 'view/screens/auth_screen.dart';
import 'models/user_model.dart';

import 'core/theme.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  NotificationService().initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthViewModel()),
        ChangeNotifierProvider(create: (_) => MapViewModel()),
        ChangeNotifierProvider(create: (_) => RequestViewModel()),
        ChangeNotifierProvider(create: (_) => ChatViewModel()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'QuickHub',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const SplashScreen(),
      // Adding a named route for the wrapper if needed manually, 
      // but home: SplashScreen already handles the flow.
      routes: {
        '/authentication': (context) => const AuthenticationWrapper(),
      },
    );
  }
}

class AuthenticationWrapper extends StatelessWidget {
  const AuthenticationWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // context.watch ensures this widget rebuilds whenever AuthViewModel calls notifyListeners()
    final authViewModel = context.watch<AuthViewModel>();
    
    if (authViewModel.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (authViewModel.currentUser != null) {
      final user = authViewModel.currentUser!;
      debugPrint("AuthenticationWrapper: User detected: ${user.email}, Role: ${user.role}");
      
      if (user.role == UserRole.admin) {
        return const AdminDashboardScreen();
      } else if (user.role == UserRole.provider) {
        return const ProviderDashboardScreen();
      } else {
        debugPrint("AuthenticationWrapper: Defaulting to MainCustomerScreen for role: ${user.role}");
        return const MainCustomerScreen();
      }
    }
    
    debugPrint("AuthenticationWrapper: No user detected, showing AuthScreen");
    return const AuthScreen();
  }
}
