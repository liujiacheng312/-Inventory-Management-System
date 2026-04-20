import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/managed_user.dart';
import '../models/record_item.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'inventory_page.dart';

class AdminPanel extends StatefulWidget {
  final bool isSuperAdmin;

  const AdminPanel({super.key, this.isSuperAdmin = false});

  @override
  State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  List<RecordItem> _pendingRecords = [];
  List<ManagedUser> _managedUsers = [];
  bool _isLoading = true;
  bool _isUsersLoading = false;
  bool _isImporting = false;
  bool _isDragging = false;
  String? _lastImportedFileName;
  int _inventoryRefreshVersion = 0;
  final GlobalKey<InventoryPageState> _inventoryKey = GlobalKey<InventoryPageState>();

  int get _tabCount => widget.isSuperAdmin ? 3 : 2;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabCount, vsync: this);
    _tabController.addListener(_onTabChanged);
    loadPendingRecords();
    if (widget.isSuperAdmin) {
      loadManagedUsers();
    }
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    if (_tabController.index == 1) {
      _inventoryKey.currentState?.load();
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> loadManagedUsers() async {
    setState(() => _isUsersLoading = true);
    try {
      final data = await ApiService.getUsers();
      if (!mounted) return;
      setState(() {
        _managedUsers = data;
        _isUsersLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUsersLoading = false);
      _showMessage('获取用户列表失败: $e');
    }
  }

  Future<void> _changeUserRole(ManagedUser user) async {
    final newRole = user.isAdmin ? 'user' : 'admin';
    final label = newRole == 'admin' ? '管理员' : '普通用户';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认修改角色'),
        content: Text('确定要将 "${user.username}" 修改为 $label 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final response = await ApiService.updateUserRole(user.id, newRole);
      if (!mounted) return;

      if (response['success'] == true) {
        _showMessage(response['message'] ?? '修改成功');
        await loadManagedUsers();
      } else {
        _showMessage(response['message'] ?? '修改失败');
      }
    } catch (e) {
      _showMessage('修改失败: $e');
    }
  }

  bool _isExcelFileName(String fileName) {
    return fileName.toLowerCase().endsWith('.xlsx');
  }

  Future<void> loadPendingRecords() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.getPendingRecords();
      if (!mounted) return;
      setState(() {
        _pendingRecords = data.map((e) => RecordItem.fromJson(e)).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage('获取待审批记录失败：$e');
    }
  }

  Future<void> _approveRecord(RecordItem record) async {
    final success = await ApiService.approveRecord(record.id);
    _showMessage(success ? '审批通过' : '审批失败');
    if (success) {
      await loadPendingRecords();
    }
  }

  Future<void> _rejectRecord(RecordItem record) async {
    final success = await ApiService.rejectRecord(record.id);
    _showMessage(success ? '已拒绝申请' : '操作失败');
    if (success) {
      await loadPendingRecords();
    }
  }

  Future<void> _uploadExcel({
    required String fileName,
    required Uint8List bytes,
  }) async {
    if (bytes.isEmpty) {
      _showMessage('未找到文件数据。');
      return;
    }

    if (!_isExcelFileName(fileName)) {
      _showMessage('仅支持 .xlsx 文件。');
      return;
    }

    setState(() {
      _isImporting = true;
      _isDragging = false;
      _lastImportedFileName = fileName;
    });

    try {
      final response = await ApiService.importExcel(
        fileName: fileName,
        bytes: bytes,
      );
      final success = response['success'] == true;

      if (success && mounted) {
        setState(() => _inventoryRefreshVersion++);
      }

      _showMessage(
        response['message']?.toString() ?? (success ? '上传完成。' : '上传失败。'),
      );
    } catch (e) {
      _showMessage('导入失败：$e');
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  Future<void> _pickExcelFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final file = result.files.single;
      if (file.bytes == null) {
        _showMessage('无法读取文件内容。');
        return;
      }
      await _uploadExcel(
        fileName: file.name,
        bytes: file.bytes!,
      );
    } catch (e) {
      _showMessage('导入失败：$e');
    }
  }

  Future<void> _handleDroppedFiles(List<XFile> files) async {
    if (_isImporting) {
      _showMessage('正在上传中，请稍候。');
      return;
    }

    XFile? selectedFile;
    for (final file in files) {
      final name = file.name.isNotEmpty ? file.name : file.path;
      if (_isExcelFileName(name)) {
        selectedFile = file;
        break;
      }
    }

    if (selectedFile == null) {
      _showMessage('仅支持 .xlsx 文件。');
      return;
    }

    if (files.length > 1) {
      _showMessage('检测到多个文件，仅上传第一个 .xlsx 文件。');
    }

    final fileName = selectedFile.name.isNotEmpty
        ? selectedFile.name
        : selectedFile.path.split(RegExp(r'[\\/]')).last;
    final bytes = await selectedFile.readAsBytes();

    await _uploadExcel(
      fileName: fileName,
      bytes: bytes,
    );
  }

  Future<void> _exportExcel() async {
    try {
      final url = ApiService.getExportUrl();
      final uri = Uri.parse(url);

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        _showMessage('开始下载库存数据...');
      } else {
        throw Exception('无法打开下载链接');
      }
    } catch (e) {
      _showMessage('导出失败：$e');
    }
  }

  Widget _buildMetric({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.78),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 18),
          Text(value, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF8F3EC),
            Color(0xFFF0F7F7),
          ],
        ),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '管理中心',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: 28,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '统一处理待审批记录，并通过拖拽导入或一键导出维护库存数据。',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              _buildMetric(
                label: '待审批记录',
                value: '${_pendingRecords.length}',
                icon: Icons.pending_actions_outlined,
                color: AppTheme.gold,
              ),
              _buildMetric(
                label: '导入方式',
                value: '拖拽 / 选择',
                icon: Icons.file_upload_outlined,
                color: AppTheme.accent,
              ),
              _buildMetric(
                label: '导出能力',
                value: 'Excel',
                icon: Icons.download_rounded,
                color: AppTheme.mint,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUploadPanel() {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.72),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          DropTarget(
            onDragEntered: (_) {
              if (!_isImporting) {
                setState(() => _isDragging = true);
              }
            },
            onDragExited: (_) {
              if (_isDragging) {
                setState(() => _isDragging = false);
              }
            },
            onDragDone: (detail) => _handleDroppedFiles(detail.files),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
              decoration: BoxDecoration(
                color: _isDragging
                    ? AppTheme.ink.withOpacity(0.06)
                    : AppTheme.panel.withOpacity(0.86),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: _isDragging ? AppTheme.ink : AppTheme.border,
                  width: _isDragging ? 1.8 : 1,
                ),
              ),
              child: Column(
                children: [
                  Container(
                    height: 64,
                    width: 64,
                    decoration: BoxDecoration(
                      color: AppTheme.ink.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      _isImporting
                          ? Icons.cloud_upload_rounded
                          : _isDragging
                              ? Icons.file_download_done_rounded
                              : Icons.upload_file_rounded,
                      size: 30,
                      color: AppTheme.ink,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _isImporting
                        ? '正在上传 Excel 文件...'
                        : _isDragging
                            ? '松开以上传 .xlsx 文件'
                            : '将 .xlsx 文件拖到这里',
                    style: theme.textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isImporting
                        ? (_lastImportedFileName ?? '请稍候...')
                        : _lastImportedFileName == null
                            ? '支持拖拽上传，也可以点击按钮手动选择。'
                            : '最近上传：$_lastImportedFileName',
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isImporting ? null : _pickExcelFile,
                  icon: _isImporting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.upload_file_outlined),
                  label: Text(_isImporting ? '上传中...' : '选择 Excel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _exportExcel,
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('导出 Excel'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.72),
        borderRadius: BorderRadius.circular(24),
      ),
      child: TabBar(
        controller: _tabController,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          color: AppTheme.ink,
          borderRadius: BorderRadius.circular(18),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: AppTheme.ink,
        tabs: [
          const Tab(text: '待审批'),
          const Tab(text: '库存管理'),
          if (widget.isSuperAdmin) const Tab(text: '用户管理'),
        ],
      ),
    );
  }

  Widget _buildPendingCard(RecordItem record) {
    final isIn = record.type == 'in';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.84),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.72)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 46,
                width: 46,
                decoration: BoxDecoration(
                  color: (isIn ? AppTheme.mint : AppTheme.accent)
                      .withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  isIn ? Icons.call_received_rounded : Icons.call_made_rounded,
                  color: isIn ? AppTheme.mint : AppTheme.accent,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.name ?? '物品 #${record.materialId}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${record.brand ?? ''} | ${record.spec ?? ''}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.gold.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '待审批',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.gold,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _PendingBadge(
                icon: Icons.person_outline_rounded,
                label: '申请人 ${record.username ?? '未知'}',
                color: AppTheme.ink,
              ),
              _PendingBadge(
                icon: isIn ? Icons.add_box_outlined : Icons.outbox_outlined,
                label: isIn ? '入库' : '出库',
                color: isIn ? AppTheme.mint : AppTheme.accent,
              ),
              _PendingBadge(
                icon: Icons.tag_outlined,
                label: '数量 ${record.count}',
                color: AppTheme.gold,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _rejectRecord(record),
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('拒绝'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.danger,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _approveRecord(record),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('批准'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUsersTab() {
    if (_isUsersLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_managedUsers.isEmpty) {
      return Center(
        child: Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.82),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.people_outline_rounded,
                size: 72,
                color: AppTheme.accent,
              ),
              const SizedBox(height: 14),
              Text(
                '暂无用户',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: loadManagedUsers,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        itemCount: _managedUsers.length,
        itemBuilder: (context, index) {
          final user = _managedUsers[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _buildUserCard(user),
          );
        },
      ),
    );
  }

  Widget _buildUserCard(ManagedUser user) {
    final isSuperAdmin = user.role == 'super_admin';
    final isAdmin = user.role == 'admin';

    Color roleColor;
    String roleText;
    if (isSuperAdmin) {
      roleColor = Colors.purple;
      roleText = '超级管理员';
    } else if (isAdmin) {
      roleColor = Colors.blue;
      roleText = '管理员';
    } else {
      roleColor = Colors.grey;
      roleText = '普通用户';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.84),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.72)),
      ),
      child: Row(
        children: [
          Container(
            height: 46,
            width: 46,
            decoration: BoxDecoration(
              color: roleColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              isSuperAdmin
                  ? Icons.admin_panel_settings_rounded
                  : isAdmin
                      ? Icons.shield_rounded
                      : Icons.person_outline_rounded,
              color: roleColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.username,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: roleColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    roleText,
                    style: TextStyle(
                      color: roleColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (!isSuperAdmin)
            ElevatedButton(
              onPressed: () => _changeUserRole(user),
              style: ElevatedButton.styleFrom(
                backgroundColor: isAdmin ? Colors.grey : Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: Text(isAdmin ? '降级' : '提升'),
            ),
        ],
      ),
    );
  }

  Widget _buildPendingTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_pendingRecords.isEmpty) {
      return Center(
        child: Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.82),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle_outline_rounded,
                size: 72,
                color: AppTheme.mint,
              ),
              const SizedBox(height: 14),
              Text(
                '暂无待审批申请',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                '所有申请都已经处理完毕。',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: loadPendingRecords,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        itemCount: _pendingRecords.length,
        itemBuilder: (context, index) {
          final record = _pendingRecords[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _buildPendingCard(record),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildHero(),
              const SizedBox(height: 16),
              _buildUploadPanel(),
              const SizedBox(height: 16),
              _buildTabBar(),
              const SizedBox(height: 16),
              SizedBox(
                height: 780,
                child: TabBarView(
                  controller: _tabController,
                  children: widget.isSuperAdmin
                      ? [
                          _buildPendingTab(),
                          InventoryPage(
                            key: _inventoryKey,
                            isAdmin: true,
                          ),
                          _buildUsersTab(),
                        ]
                      : [
                          _buildPendingTab(),
                          InventoryPage(
                            key: _inventoryKey,
                            isAdmin: true,
                          ),
                        ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PendingBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _PendingBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.ink,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}
