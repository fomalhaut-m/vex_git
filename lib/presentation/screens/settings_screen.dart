import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/errors/exceptions.dart';

const _storage = FlutterSecureStorage();

final githubTokenProvider = StateProvider<String?>((ref) => null);
final giteeTokenProvider = StateProvider<String?>((ref) => null);
final scanIntervalProvider = StateProvider<int>((ref) => 20); // minutes

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _githubController = TextEditingController();
  final _giteeController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTokens();
  }

  Future<void> _loadTokens() async {
    final github = await _storage.read(key: 'github_token');
    final gitee = await _storage.read(key: 'gitee_token');
    final interval = await SharedPreferences.getInstance()
        .then((p) => p.getInt('scan_interval') ?? 20);

    if (mounted) {
      setState(() {
        _githubController.text = github ?? '';
        _giteeController.text = gitee ?? '';
        ref.read(githubTokenProvider.notifier).state = github;
        ref.read(giteeTokenProvider.notifier).state = gitee;
        ref.read(scanIntervalProvider.notifier).state = interval;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveGithubToken() async {
    final token = _githubController.text.trim();
    if (token.isEmpty) {
      await _storage.delete(key: 'github_token');
      ref.read(githubTokenProvider.notifier).state = null;
    } else {
      await _storage.write(key: 'github_token', value: token);
      ref.read(githubTokenProvider.notifier).state = token;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('GitHub Token 已保存')),
      );
    }
  }

  Future<void> _saveGiteeToken() async {
    final token = _giteeController.text.trim();
    if (token.isEmpty) {
      await _storage.delete(key: 'gitee_token');
      ref.read(giteeTokenProvider.notifier).state = null;
    } else {
      await _storage.write(key: 'gitee_token', value: token);
      ref.read(giteeTokenProvider.notifier).state = token;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gitee Token 已保存')),
      );
    }
  }

  Future<void> _saveScanInterval(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('scan_interval', minutes);
    ref.read(scanIntervalProvider.notifier).state = minutes;
  }

  @override
  void dispose() {
    _githubController.dispose();
    _giteeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('设置')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          // HTTPS Token section
          _sectionHeader('HTTPS 令牌'),
          ListTile(
            title: const Text('GitHub Token'),
            subtitle: const Text('https://github.com/settings/tokens',
                style: TextStyle(fontSize: 11, color: Colors.grey)),
            trailing: SizedBox(
              width: 200,
              child: TextField(
                controller: _githubController,
                obscureText: true,
                decoration: const InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(),
                  hintText: 'ghp_xxx',
                ),
              ),
            ),
            onLongPress: _saveGithubToken,
          ),
          ListTile(
            title: const Text('Gitee Token'),
            subtitle: const Text('https://gitee.com/profile/personal_access_token',
                style: TextStyle(fontSize: 11, color: Colors.grey)),
            trailing: SizedBox(
              width: 200,
              child: TextField(
                controller: _giteeController,
                obscureText: true,
                decoration: const InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(),
                  hintText: '私人令牌',
                ),
              ),
            ),
            onLongPress: _saveGiteeToken,
          ),
          const Divider(),

          // SSH section
          _sectionHeader('SSH 密钥'),
          ListTile(
            leading: const Icon(Icons.key),
            title: const Text('SSH 密钥管理'),
            subtitle: const Text('查看 / 生成 / 导入 SSH 密钥',
                style: TextStyle(fontSize: 12)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showSshDialog(context),
          ),
          const Divider(),

          // Scan interval
          _sectionHeader('定时巡检'),
          ListTile(
            title: const Text('巡检周期'),
            subtitle: const Text('自动检测远程版本更新间隔',
                style: TextStyle(fontSize: 12)),
            trailing: DropdownButton<int>(
              value: ref.watch(scanIntervalProvider),
              items: const [
                DropdownMenuItem(value: 10, child: Text('10 分钟')),
                DropdownMenuItem(value: 20, child: Text('20 分钟')),
                DropdownMenuItem(value: 30, child: Text('30 分钟')),
                DropdownMenuItem(value: 60, child: Text('1 小时')),
              ],
              onChanged: (v) {
                if (v != null) _saveScanInterval(v);
              },
            ),
          ),
          const Divider(),

          // Cache
          _sectionHeader('存储'),
          ListTile(
            leading: const Icon(Icons.cleaning_services),
            title: const Text('清除缓存'),
            subtitle: const Text('清理临时文件和缓存',
                style: TextStyle(fontSize: 12)),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('确认清除'),
                  content: const Text('确定清除所有缓存数据？'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('取消'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('清除', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
              if (confirm == true && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('缓存已清除')),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('恢复默认配置'),
            subtitle: const Text('重置所有设置为默认值',
                style: TextStyle(fontSize: 12)),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('确认恢复'),
                  content: const Text('确定恢复所有设置为默认值？'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('取消'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('恢复', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await _storage.deleteAll();
                await _saveScanInterval(20);
                _githubController.clear();
                _giteeController.clear();
                ref.read(githubTokenProvider.notifier).state = null;
                ref.read(giteeTokenProvider.notifier).state = null;
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已恢复默认配置')),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
    );
  }

  void _showSshDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('SSH 密钥'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SSH 密钥管理功能开发中...'),
            SizedBox(height: 8),
            Text('可手动在设置中生成 SSH 密钥对',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}