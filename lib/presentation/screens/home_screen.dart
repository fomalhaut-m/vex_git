import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../application/providers/git_providers.dart';
import '../../domain/entities/entities.dart';
import '../../infrastructure/git/git_on_dart_impl.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

final changeCountProvider = FutureProvider.family<int, String>((ref, localPath) async {
  final git = ref.read(gitServiceProvider);
  final changes = await git.getStatus(localPath);
  return changes.length;
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reposAsync = ref.watch(repositoriesProvider);
    final currentRepo = ref.watch(currentRepoProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('GitVex'),
        actions: [
          if (currentRepo != null)
            _ChangeBadge(repo: currentRepo),
        ],
      ),
      drawer: _buildDrawer(context, ref),
      body: reposAsync.when(
        data: (repos) => repos.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.source, size: 64, color: Colors.grey[600]),
                    const SizedBox(height: 16),
                    const Text('暂无仓库', style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 8),
                    const Text(
                      '点击右上角 + 克隆或新建仓库',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                itemCount: repos.length,
                itemBuilder: (_, i) {
                  final repo = repos[i];
                  final isSelected = currentRepo?.id == repo.id;
                  return ListTile(
                    selected: isSelected,
                    leading: Icon(
                      isSelected ? Icons.folder_open : Icons.folder,
                      color: isSelected ? Colors.blue : null,
                    ),
                    title: Text(repo.name),
                    subtitle: Text(
                      repo.remoteUrl ?? repo.localPath,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11),
                    ),
                    onTap: () {
                      ref.read(currentRepoProvider.notifier).state = repo;
                      context.push('/repo/${repo.id}');
                    },
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('错误: $e')),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'clone',
            onPressed: () => context.push('/clone'),
            child: const Icon(Icons.download),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'import',
            onPressed: () => _importLocalRepo(context, ref),
            child: const Icon(Icons.folder_open),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, WidgetRef ref) {
    return Drawer(
      child: ListView(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Colors.blueGrey[800],
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(Icons.source, size: 40, color: Colors.white),
                SizedBox(height: 8),
                Text('GitVex', style: TextStyle(fontSize: 20, color: Colors.white)),
                Text('Flutter Git 客户端', style: TextStyle(fontSize: 12, color: Colors.white70)),
              ],
            ),
          ),
          _drawerSection('仓库项目', [
            ListTile(
              leading: const Icon(Icons.folder),
              title: const Text('仓库列表'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('新建仓库'),
              onTap: () {
                Navigator.pop(context);
                _createRepo(context, ref);
              },
            ),
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('克隆仓库'),
              onTap: () {
                Navigator.pop(context);
                context.push('/clone');
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder_open),
              title: const Text('导入本地仓库'),
              onTap: () {
                Navigator.pop(context);
                _importLocalRepo(context, ref);
              },
            ),
          ]),
          _drawerSection('分支快捷入口', [
            ListTile(
              leading: const Icon(Icons.call_split),
              title: const Text('切换分支'),
              onTap: () {
                Navigator.pop(context);
                final repo = ref.read(currentRepoProvider);
                if (repo != null) {
                  context.push('/repo/${repo.id}/branch');
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('请先选择一个仓库')),
                  );
                }
              },
            ),
          ]),
          _drawerSection('系统设置', [
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('设置'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                context.push('/settings');
              },
            ),
          ]),
        ],
      ),
    );
  }

  Widget _drawerSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ),
        ...children,
        const Divider(),
      ],
    );
  }

  Future<void> _importLocalRepo(BuildContext context, WidgetRef ref) async {
    final appDir = await getApplicationDocumentsDirectory();
    final reposDir = Directory('${appDir.path}/repos');

    if (!await reposDir.exists()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('本地无仓库，请先克隆')),
        );
      }
      return;
    }

    try {
      final entities = await reposDir.list().toList();
      final repoDirs = <Directory>[];

      for (final entity in entities) {
        if (entity is Directory) {
          final gitDir = Directory('${entity.path}/.git');
          if (await gitDir.exists()) {
            repoDirs.add(entity);
          }
        }
      }

      if (context.mounted) {
        if (repoDirs.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('未找到本地 Git 仓库')),
          );
          return;
        }

        final selected = await showDialog<Directory>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('选择仓库'),
            content: SizedBox(
              width: double.maxFinite,
              height: 300,
              child: ListView.builder(
                itemCount: repoDirs.length,
                itemBuilder: (_, i) {
                  final dir = repoDirs[i];
                  final name = dir.path.split('/').last;
                  return ListTile(
                    title: Text(name),
                    subtitle: Text(dir.path, style: const TextStyle(fontSize: 10)),
                    onTap: () => Navigator.pop(context, dir),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
            ],
          ),
        );

        if (selected != null) {
          await _addRepoFromDir(context, ref, selected);
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入失败: $e')),
        );
      }
    }
  }

  Future<void> _addRepoFromDir(BuildContext context, WidgetRef ref, Directory dir) async {
    final name = dir.path.split('/').last;
    final repo = Repository(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      localPath: dir.path,
      platform: GitPlatform.unknown,
      defaultBranch: 'main',
      createdAt: DateTime.now(),
    );

    final repos = ref.read(repositoriesProvider).valueOrNull ?? [];
    ref.read(repositoriesProvider.notifier).state = AsyncValue.data([...repos, repo]);
    ref.read(currentRepoProvider.notifier).state = repo;

    if (context.mounted) {
      context.push('/repo/${repo.id}');
    }
  }

  Future<void> _createRepo(BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController();
    final pathController = TextEditingController();

    final appDir = await getApplicationDocumentsDirectory();
    pathController.text = '${appDir.path}/repos/';

    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('新建仓库'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: '仓库名',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pathController,
              decoration: const InputDecoration(
                labelText: '本地路径',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('创建'),
          ),
        ],
      ),
    );

    if (name != null && name.isNotEmpty) {
      try {
        final git = ref.read(gitServiceProvider);
        final localPath = '${pathController.text}/$name';
        await Directory(localPath).create(recursive: true);
        await git.init(localPath);

        final repo = Repository(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: name,
          localPath: localPath,
          platform: GitPlatform.unknown,
          defaultBranch: 'main',
          createdAt: DateTime.now(),
        );

        final repos = ref.read(repositoriesProvider).valueOrNull ?? [];
        ref.read(repositoriesProvider.notifier).state = AsyncValue.data([...repos, repo]);
        ref.read(currentRepoProvider.notifier).state = repo;

        if (context.mounted) {
          context.push('/repo/${repo.id}');
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('创建失败: $e')),
          );
        }
      }
    }
  }
}

class _ChangeBadge extends ConsumerWidget {
  final Repository repo;

  const _ChangeBadge({required this.repo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countAsync = ref.watch(changeCountProvider(repo.localPath));

    return countAsync.when(
      data: (count) {
        if (count == 0) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: InkWell(
            onTap: () => context.push('/repo/${repo.id}/commit'),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$count',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}