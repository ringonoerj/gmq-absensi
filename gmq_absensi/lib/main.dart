import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'services/supabase_service.dart';
import 'providers/auth_provider.dart';
import 'providers/absensi_provider.dart';
import 'providers/master_provider.dart';
import 'providers/theme_provider.dart';
import 'utils/theme.dart';
import 'widgets/confetti_overlay.dart';
import 'screens/auth/login_screen.dart';
import 'screens/operator/dashboard_operator.dart';
import 'screens/supervisor/dashboard_supervisor.dart';
import 'screens/superadmin/dashboard_superadmin.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Hive for offline storage
  await Hive.initFlutter();
  await Hive.openBox('gmq_cache');
  
  await SupabaseService.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => AbsensiProvider()),
        ChangeNotifierProvider(create: (_) => MasterProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'GMQ Absensi Mobile',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            home: ConfettiOverlay(
              child: Consumer<AuthProvider>(
                builder: (context, auth, _) {
                  if (auth.isLoading) {
                    return const Scaffold(
                      body: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (auth.isAuthenticated) {
                    if (auth.isSuperadmin) {
                      return const DashboardSuperadmin();
                    } else if (auth.isOperator) {
                      return const DashboardOperator();
                    } else {
                      return const DashboardSupervisor();
                    }
                  }
                  return const LoginScreen();
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

