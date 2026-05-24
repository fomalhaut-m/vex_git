import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../application/providers/git_providers.dart';
import '../../domain/entities/entities.dart';
import '../widgets/file_tree_widget.dart';

class RepoDetailScreen extends ConsumerStatefulWidget {
  final String repoId;

  const RepoDetailScreen({super.key, required this.repoId});

  @override
  ConsumerState<RepoDetailScreen> createState() => _RepoDetailScreenState();
}

class _RepoDetailScreenState extends ConsumerState<RepoDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _pull() async {
    final repo = ref.read(currentRepoProvider);
    if (repo == null) return;
    ref.read(syncStatusProvider.notifier).state = SyncStatus.syncing;
    try {
      final git = ref.read(gitServiceProvider);
      await git.pull(repo.localPath);
      ref.read(syncStatusProvider.notifier).state = SyncStatus.success;
      ref.invalidate(statusProvider(repo.localPath));
      ref.invalidate(logProvider(repo.localPath));
    } catch (e) {
      _showError(e);
      ref.read(syncStatusProvider.notifier).state = SyncStatus.idle;
    }
  }

  Future<void> _push() async {
    final repo = ref.read(currentRepoProvider);
    if (repo == null) return;
    ref.read(syncStatusProvider.notifier).state = SyncStatus.syncing;
    try {
      final git = ref.read(gitServiceProvider);
      await git.push(repo.localPath);
      ref.read(syncStatusProvider.notifier).state = SyncStatus.success;
    } catch (e) {
      _showError(e);
      ref.read(syncStatusProvider.notifier).state = SyncStatus.idle;
    }
  }

  void _showError(Object e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('操作失败: $e')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(currentRepoProvider);
    final syncStatus = ref.watch(syncStatusProvider);

    if (repo == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('仓库详情')),
        body: const Center(child: Text('仓库未找到')),
      );
    }

    final branches = ref.watch(branchesProvider(repo.localPath));
    final status = ref.watch(statusProvider(repo.localPath));
    final log = ref.watch(logProvider(repo.localPath));

    return Scaffold(
      appBar: AppBar(
        title: Text(repo.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open),
            onPressed: () {
              if (repo != null) {
                context.push('/repo/${repo.id}/file?path=');
              }
            },
            tooltip: '浏览文件',
          ),
          IconButton(
            icon: const Icon(Icons.call_merge),
            onPressed: () {},
            tooltip: '合并',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '文件'),
            Tab(text: '提交'),
            Tab(text: '分支'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Sync bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey[900],
            child: Row(
              children: [
                _buildBranchChip(repo, branches),
                const Spacer(),
                if (syncStatus == SyncStatus.syncing)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else ...[
                  IconButton(
                    icon: const Icon(Icons.download, size: 20),
                    onPressed: _pull,
                    tooltip: '拉取',
                  ),
                  IconButton(
                    icon: const Icon(Icons.upload, size: 20),
                    onPressed: _push,
                    tooltip: '推送',
                  ),
                ],
              ],
            ),
          ),
          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildFilesTab(repo),
                _buildLogTab(repo, log),
                _buildBranchTab(repo, branches),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBranchChip(Repository repo, AsyncValue<List<GitBranch>> branches) {
    return branches.when(
      data: (list) {
        final current = list.firstWhere(
          (b) => b.isCurrent,
          orElse: () => const GitBranch(name: 'main', type: BranchType.local),
        );
        return PopupMenuButton<GitBranch>(
          child: Chip(
            avatar: const Icon(Icons.call_split, size: 16),
            label: Text(current.name, style: const TextStyle(fontSize: 12)),
            backgroundColor: Colors.blueGrey[800],
          ),
          itemBuilder: (_) => list
              .where((b) => b.type == BranchType.local)
              .map((b) => PopupMenuItem(
                    value: b,
                    child: Row(
                      children: [
                        if (b.isCurrent)
                          const Icon(Icons.check, size: 16, color: Colors.green)
                        else
                          const SizedBox(width: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text(b.name)),
                      ],
                    ),
                  ))
              .toList(),
          onSelected: (b) async {
            if (b.isCurrent) return;
            try {
              final git = ref.read(gitServiceProvider);
              await git.checkout(repo.localPath, b.name);
              ref.invalidate(branchesProvider(repo.localPath));
              ref.invalidate(logProvider(repo.localPath));
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('切换分支失败: $e')),
                );
              }
            }
          },
        );
      },
      loading: () => Chip(
        avatar: const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
        label: const Text('...', style: TextStyle(fontSize: 12)),
        backgroundColor: const Color(0xFF37474F),
      ),
      error: (_, __) => Chip(
        avatar: const Icon(Icons.error, size: 16),
        label: const Text('错误', style: TextStyle(fontSize: 12)),
        backgroundColor: Colors.red[800],
      ),
    );
  }

  Widget _buildFilesTab(Repository repo) {
    return FileTreeWidget(
      repo: repo,
      onFileTap: (path) {
        context.push('/repo/${repo.id}/file?path=${Uri.encodeComponent(path)}');
      },
    );
  }

  Widget _buildLogTab(Repository repo, AsyncValue<List<GitCommit>> log) {
    return log.when(
      data: (commits) => ListView.builder(
        itemCount: commits.length,
        itemBuilder: (_, i) {
          final c = commits[i];
          return ListTile(
            leading: CircleAvatar(
              radius: 16,
              backgroundColor: Colors.blueGrey[700],
              child: Text(c.author[0].toUpperCase(), style: const TextStyle(fontSize: 12)),
            ),
            title: Text(c.message, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text('${c.shortSha} · ${c.author} · ${_formatTime(c.timestamp)}'),
            dense: true,
            onTap: () => context.push('/repo/${repo.id}/commit/${c.shortSha}'),
          );
        },
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('加载失败: $e')),
    );
  }

  Widget _buildBranchTab(Repository repo, AsyncValue<List<GitBranch>> branches) {
    return branches.when(
      data: (list) => ListView.builder(
        itemCount: list.length,
        itemBuilder: (_, i) {
          final b = list[i];
          return ListTile(
            leading: Icon(
              b.isCurrent ? Icons.check_circle : Icons.call_split,
              color: b.isCurrent ? Colors.green : null,
            ),
            title: Text(b.name),
            subtitle: Text(b.type == BranchType.remote ? '远程分支' : '本地分支'),
            trailing: b.isCurrent ? null : PopupMenuButton<String>(
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'checkout', child: Text('切换')),
                const PopupMenuItem(value: 'delete', child: Text('删除')),
              ],
              onSelected: (v) async {
                if (v == 'checkout') {
                  await ref.read(gitServiceProvider).checkout(repo.localPath, b.name);
                  ref.invalidate(branchesProvider(repo.localPath));
                }
              },
            ),
          );
        },
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('加载失败: $e')),
    );
  }

  IconData _iconForStatus(ChangeStatus s) {
    switch (s) {
      case ChangeStatus.added:
        return Icons.add_circle_outline;
      case ChangeStatus.modified:
        return Icons.edit;
      case ChangeStatus.deleted:
        return Icons.remove_circle_outline;
      case ChangeStatus.renamed:
        return Icons.drive_file_rename_outline;
      case ChangeStatus.copied:
        return Icons.copy;
    }
  }

  Color _colorForStatus(ChangeStatus s) {
    switch (s) {
      case ChangeStatus.added:
        return Colors.green;
      case ChangeStatus.modified:
        return Colors.orange;
      case ChangeStatus.deleted:
        return Colors.red;
      case ChangeStatus.renamed:
        return Colors.blue;
      case ChangeStatus.copied:
        return Colors.purple;
    }
  }

  String _formatTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    if (diff.inDays < 30) return '${diff.inDays}天前';
    return '${t.month}/${t.day}';
  }
}