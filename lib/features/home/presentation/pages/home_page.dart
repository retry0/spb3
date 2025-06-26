import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/utils/jwt_token_manager.dart';
import '../../../../core/storage/user_profile_repository.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../bloc/home_bloc.dart';
import '../widgets/dashboard_metrics.dart';
import '../widgets/activity_feed.dart';
import '../widgets/quick_actions.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _userName = 'User';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      // Get JWT token manager
      final tokenManager = getIt<JwtTokenManager>();

      // Get user data from token
      final userData = await tokenManager.getCurrentUserData();

      if (userData != null) {
        setState(() {
          // Extract user name from token data
          _userName = userData['Nama'] ?? userData['UserName'] ?? 'User';
        });

        // Sync user data with local storage if needed
        //await _syncUserData(userData);
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  // Future<void> _syncUserData(Map<String, dynamic> userData) async {
  //   try {
  //     // Get user profile repository to sync data
  //     final userProfileRepository = getIt<UserProfileRepository>();

  //     // Sync user profile with local storage
  //     await userProfileRepository.updateUserProfile(userData);
  //   } catch (e) {
  //     debugPrint('Error syncing user data: $e');
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<HomeBloc>()..add(const HomeDataRequested()),
      child: Scaffold(
        body: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // App Bar
              SliverAppBar(
                floating: true,
                pinned: false,
                expandedHeight: 80,
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                elevation: 0,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                    alignment: Alignment.topLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dashboard',
                          style: Theme.of(
                            context,
                          ).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Welcome back, $_userName',
                          style: Theme.of(
                            context,
                          ).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(
                              context,
                            ).colorScheme.onBackground.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    onPressed: () {
                      // Show notifications
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () {
                      context.read<HomeBloc>().add(const HomeDataRequested());
                      _loadUserData(); // Refresh user data
                    },
                  ),
                  const SizedBox(width: 8),
                ],
              ),

              // Content
              SliverToBoxAdapter(
                child: RefreshIndicator(
                  onRefresh: () async {
                    context.read<HomeBloc>().add(const HomeDataRequested());
                    await _loadUserData(); // Refresh user data
                    return Future.delayed(const Duration(milliseconds: 1500));
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        const QuickActions(),
                        const SizedBox(height: 24),
                        const DashboardMetrics(),
                        const SizedBox(height: 24),
                        const ActivityFeed(),
                        const SizedBox(height: 100), // Bottom padding for FAB
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
