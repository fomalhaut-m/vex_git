import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../application/providers/git_providers.dart';
import '../../domain/entities/entities.dart';

class CommitScreen extends ConsumerStatefulWidget {
  final String repoId;

  const CommitScreen({super.key, required this.repoId});

  @override
  ConsumerState<CommitScreen> createState() => _CommitScreenState();
}

class _CommitScreenState extends ConsumerState<CommitScreen> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final Set<String> _selectedFiles = {};
  bool _isCommitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _doCommit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写提交标题')),
      );
      return;
    }

    if (_selectedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择要提交的文件')),
      );
      return;
    }

    final repo = ref.read(currentRepoProvider);
    if (repo == null) return;

    setState(() => _isCommitting = true);

    try {
      final git = ref.read(gitServiceProvider);

      // Stage selected files
      await git.stage(repo.localPath, _selectedFiles.toList());

      // Commit
      final body = _bodyController.text.trim();
      await git.commit(repo.localPath, title, body: body.isEmpty ? null : body);

      // Invalidate providers to refresh
      ref.invalidate(statusProvider(repo.localPath));
      ref.invalidate(logProvider(repo.localPath));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('提交成功')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('提交失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCommitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(currentRepoProvider);
    if (repo == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('提交')),
        body: const Center(child: Text('仓库未找到')),
      );
    }

    final status = ref.watch(statusProvider(repo.localPath));

    return Scaffold(
      appBar: AppBar(
        title: const Text('提交变更'),
        actions: [
          TextButton(
            onPressed: _isCommitting ? null : _doCommit,
            child: _isCommitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('提交'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Commit message
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: '提交标题',
                    hintText: '简短描述本次改动',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _bodyController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: '详细说明（可选）',
                    hintText: '补充更多细节...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // File list
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  '变更文件 (${_selectedFiles.length})',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    setState(() => _selectedFiles.clear());
                  },
                  child: const Text('清空'),
                ),
              ],
            ),
          ),
          Expanded(
            child: status.when(
              data: (changes) {
                if (changes.isEmpty) {
                  return const Center(
                    child: Text('工作区干净，无变更', style: TextStyle(color: Colors.grey)),
                  );
                }
                return ListView.builder(
                  itemCount: changes.length,
                  itemBuilder: (_, i) {
                    final c = changes[i];
                    final selected = _selectedFiles.contains(c.path);
                    return CheckboxListTile(
                      value: selected,
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            _selectedFiles.add(c.path);
                          } else {
                            _selectedFiles.remove(c.path);
                          }
                        });
                      },
                      title: Text(c.path),
                      subtitle: Text(c.status.name, style: TextStyle(
                        color: _colorForStatus(c.status),
                        fontSize: 11,
                      )),
                      secondary: Icon(_iconForStatus(c.status), color: _colorForStatus(c.status)),
                      dense: true,
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('加载失败: $e')),
            ),
          ),
        ],
      ),
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
}