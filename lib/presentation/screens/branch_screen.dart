import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/providers/git_providers.dart';
import '../../domain/entities/entities.dart';

class BranchScreen extends ConsumerStatefulWidget {
  final String repoId;

  const BranchScreen({super.key, required this.repoId});

  @override
  ConsumerState<BranchScreen> createState() => _BranchScreenState();
}

class _BranchScreenState extends ConsumerState<BranchScreen> {
  final _newBranchController = TextEditingController();

  @override
  void dispose() {
    _newBranchController.dispose();
    super.dispose();
  }

  Future<void> _createBranch() async {
    final name = _newBranchController.text.trim();
    if (name.isEmpty) return;

    final repo = ref.read(currentRepoProvider);
    if (repo == null) return;

    try {
      final git = ref.read(gitServiceProvider);
      await git.createBranch(repo.localPath, name);
      ref.invalidate(branchesProvider(repo.localPath));
      ref.invalidate(statusProvider(repo.localPath));
      _newBranchController.clear();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('创建分支失败: $e')),
        );
      }
    }
  }

  Future<void> _deleteBranch(GitBranch branch) async {
    if (branch.name == 'main' || branch.name == 'master') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('不能删除主干分支')),
      );
      return;
    }

    final repo = ref.read(currentRepoProvider);
    if (repo == null) return;

    try {
      final git = ref.read(gitServiceProvider);
      await git.deleteBranch(repo.localPath, branch.name);
      ref.invalidate(branchesProvider(repo.localPath));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: $e')),
        );
      }
    }
  }

  Future<void> _checkoutBranch(GitBranch branch) async {
    final repo = ref.read(currentRepoProvider);
    if (repo == null) return;

    try {
      final git = ref.read(gitServiceProvider);
      await git.checkout(repo.localPath, branch.name);
      ref.invalidate(branchesProvider(repo.localPath));
      ref.invalidate(statusProvider(repo.localPath));
      ref.invalidate(logProvider(repo.localPath));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('切换分支失败: $e')),
        );
      }
    }
  }

  void _showCreateDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('新建分支'),
        content: TextField(
          controller: _newBranchController,
          decoration: const InputDecoration(
            labelText: '分支名',
            hintText: 'feature/xxx',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: _createBranch,
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(currentRepoProvider);
    if (repo == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('分支管理')),
        body: const Center(child: Text('仓库未找到')),
      );
    }

    final branches = ref.watch(branchesProvider(repo.localPath));

    return Scaffold(
      appBar: AppBar(
        title: const Text('分支管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showCreateDialog,
            tooltip: '新建分支',
          ),
        ],
      ),
      body: branches.when(
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('暂无分支'));
          }
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (_, i) {
              final b = list[i];
              return ListTile(
                leading: Icon(
                  b.isCurrent ? Icons.check_circle : Icons.call_split,
                  color: b.isCurrent ? Colors.green : null,
                ),
                title: Text(b.name),
                subtitle: Text(
                  b.type == BranchType.remote ? '远程分支' : '本地分支',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: b.isCurrent
                    ? const Chip(label: Text('当前', style: TextStyle(fontSize: 11)))
                    : PopupMenuButton<String>(
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'checkout', child: Text('切换')),
                          const PopupMenuItem(value: 'delete', child: Text('删除')),
                        ],
                        onSelected: (v) async {
                          if (v == 'checkout') {
                            await _checkoutBranch(b);
                          } else if (v == 'delete') {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('确认删除'),
                                content: Text('确定删除分支 "${b.name}" 吗？'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text('取消'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    child: const Text('删除', style: TextStyle(color: Colors.red)),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              await _deleteBranch(b);
                            }
                          }
                        },
                      ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
      ),
    );
  }
}