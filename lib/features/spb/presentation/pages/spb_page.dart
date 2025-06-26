import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../bloc/spb_bloc.dart';
import '../widgets/spb_data_table.dart';
import 'cek_espb_page.dart';

class SpbPage extends StatelessWidget {
  const SpbPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        // Get user info from auth state
        final authState = context.read<AuthBloc>().state;
        String driver = '';
        String kdVendor = '';

        if (authState is AuthAuthenticated) {
          driver = authState.user.UserName;
          kdVendor = authState.user.Id;
        }

        return getIt<SpbBloc>()
          ..add(SpbLoadRequested(driver: driver, kdVendor: kdVendor));
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('E-SPB Data'),
          actions: [
            BlocBuilder<SpbBloc, SpbState>(
              builder: (context, state) {
                if (state is SpbLoaded && !state.isConnected) {
                  return IconButton(
                    icon: const Icon(Icons.sync_disabled),
                    onPressed: null,
                    tooltip: 'Offline Mode',
                  );
                } else if (state is SpbSyncing) {
                  return const IconButton(
                    icon: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                    onPressed: null,
                    tooltip: 'Syncing...',
                  );
                } else {
                  return IconButton(
                    icon: const Icon(Icons.sync),
                    onPressed: () {
                      final authState = context.read<AuthBloc>().state;
                      if (authState is AuthAuthenticated) {
                        context.read<SpbBloc>().add(
                          SpbSyncRequested(
                            driver: authState.user.UserName,
                            kdVendor: authState.user.Id,
                          ),
                        );
                      }
                    },
                    tooltip: 'Sync Data',
                  );
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                final authState = context.read<AuthBloc>().state;
                if (authState is AuthAuthenticated) {
                  context.read<SpbBloc>().add(
                    SpbRefreshRequested(
                      driver: authState.user.UserName,
                      kdVendor: authState.user.Id,
                    ),
                  );
                }
              },
              tooltip: 'Refresh',
            ),
          ],
        ),
        body: const SpbDataTable(),
      ),
    );
  }
}