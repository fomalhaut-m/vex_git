import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/screens/clone_screen.dart';
import 'presentation/screens/repo_detail_screen.dart';
import 'presentation/screens/commit_screen.dart';
import 'presentation/screens/branch_screen.dart';
import 'presentation/screens/settings_screen.dart';

final router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
    GoRoute(path: '/clone', builder: (_, __) => const CloneScreen()),
    GoRoute(
      path: '/repo/:id',
      builder: (_, state) => RepoDetailScreen(
        repoId: state.pathParameters['id']!,
      ),
    ),
    GoRoute(
      path: '/repo/:id/commit',
      builder: (_, state) => CommitScreen(
        repoId: state.pathParameters['id']!,
      ),
    ),
    GoRoute(
      path: '/repo/:id/branch',
      builder: (_, state) => BranchScreen(
        repoId: state.pathParameters['id']!,
      ),
    ),
    GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
  ],
);

void main() {
  runApp(const ProviderScope(child: GitVexApp()));
}

class GitVexApp extends StatelessWidget {
  const GitVexApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'GitVex',
      theme: ThemeData.dark(useMaterial3: true),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}