import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/services/sync_service.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../bloc/profile_bloc.dart';
import '../widgets/profile_info_section.dart';
import '../widgets/password_change_form.dart';
import '../widgets/logout_button.dart';
import '../widgets/sync_status_indicator.dart';
import '../widgets/profile_edit_form.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isEditing = false;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        // Check if user is authenticated
        final authState = context.read<AuthBloc>().state;
        if (authState is! AuthAuthenticated) {
          // If not authenticated, trigger auth check
          context.read<AuthBloc>().add(const AuthCheckRequested());
        }

        // Create and initialize profile bloc
        return getIt<ProfileBloc>()..add(const ProfileLoadRequested());
      },
      child: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthUnauthenticated) {
            // If user becomes unauthenticated, redirect to login
            context.go('/login');
          }
        },
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
                      child: Text(
                        'My Profile',
                        style: Theme.of(
                          context,
                        ).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                  actions: [
                    // BlocBuilder<ProfileBloc, ProfileState>(
                    //   builder: (context, state) {
                    //     if (state is ProfileLoaded) {
                    //       return IconButton(
                    //         icon: Icon(_isEditing ? Icons.close : Icons.edit),
                    //         onPressed: () {
                    //           setState(() {
                    //             _isEditing = !_isEditing;
                    //           });
                    //         },
                    //         tooltip: _isEditing ? 'Cancel' : 'Edit Profile',
                    //       );
                    //     }
                    //     return const SizedBox.shrink();
                    //   },
                    // ),
                    // IconButton(
                    //   icon: const Icon(Icons.refresh),
                    //   onPressed: () {
                    //     context.read<ProfileBloc>().add(
                    //       const ProfileSyncRequested(),
                    //     );
                    //   },
                    //   tooltip: 'Sync Profile',
                    // ),
                    const LogoutButton(),
                    const SizedBox(width: 8),
                  ],
                ),

                // Content
                SliverToBoxAdapter(
                  child: BlocListener<ProfileBloc, ProfileState>(
                    listener: (context, state) {
                      if (state is PasswordChangeSuccess) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(state.message),
                            backgroundColor: Colors.green,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            margin: const EdgeInsets.all(16),
                          ),
                        );
                      } else if (state is PasswordChangeError) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(state.message),
                            backgroundColor: Colors.red,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            margin: const EdgeInsets.all(16),
                          ),
                        );
                      } else if (state is ProfileUpdateSuccess) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(state.message),
                            backgroundColor: Colors.green,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            margin: const EdgeInsets.all(16),
                          ),
                        );
                        setState(() {
                          _isEditing = false;
                        });
                      } else if (state is ProfileUpdateError) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(state.message),
                            backgroundColor: Colors.red,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            margin: const EdgeInsets.all(16),
                          ),
                        );
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Sync Status Indicator
                          const SyncStatusIndicator(),
                          // Profile Info or Edit Form
                          BlocBuilder<ProfileBloc, ProfileState>(
                            builder: (context, state) {
                              if (state is ProfileLoaded) {
                                return _isEditing
                                    ? ProfileEditForm(user: state.user)
                                    : const ProfileInfoSection();
                              } else if (state is ProfileLoading) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              } else if (state is ProfileError) {
                                return Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.error_outline,
                                        size: 48,
                                        color: Colors.red,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Failed to load profile: ${state.message}',
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 16),
                                      ElevatedButton(
                                        onPressed: () {
                                          context.read<ProfileBloc>().add(
                                            const ProfileLoadRequested(),
                                          );
                                        },
                                        child: const Text('Retry'),
                                      ),
                                    ],
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),

                          const SizedBox(height: 24),

                          // Password Change Form (only show when not editing)
                          if (!_isEditing) const PasswordChangeForm(),

                          const SizedBox(
                            height: 100,
                          ), // Bottom padding for navigation
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
