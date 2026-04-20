import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/record_item.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class RecordPage extends StatefulWidget {
  final bool isAdmin;

  const RecordPage({super.key, this.isAdmin = false});

  @override
  State<RecordPage> createState() => _RecordPageState();
}

class _RecordPageState extends State<RecordPage> {
  List<RecordItem> _records = [];
  bool _isLoading = true;
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    load();
  }

  List<RecordItem> get _filteredRecords {
    if (_statusFilter == 'all') {
      return _records;
    }

    return _records.where((record) => record.status == _statusFilter).toList();
  }

  Future<void> load() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.getRecords();
      if (!mounted) return;
      setState(() {
        _records = data.map((e) => RecordItem.fromJson(e)).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('获取记录失败：$e')),
      );
    }
  }

  String _formatTime(DateTime? time) {
    if (time == null) {
      return '时间未知';
    }
    return DateFormat('MM-dd HH:mm').format(time);
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return AppTheme.mint;
      case 'rejected':
        return AppTheme.danger;
      case 'pending':
        return AppTheme.gold;
      default:
        return AppTheme.inkMuted;
    }
  }

  String _statusText(String status) {
    switch (status) {
      case 'approved':
        return '已通过';
      case 'rejected':
        return '已拒绝';
      case 'pending':
        return '待审批';
      default:
        return status;
    }
  }

  String _typeText(String type) {
    switch (type) {
      case 'in':
        return '入库';
      case 'out':
        return '出库';
      case 'export':
        return '导出';
      default:
        return type;
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'in':
        return Icons.add_box_outlined;
      case 'out':
        return Icons.outbox_outlined;
      case 'export':
        return Icons.file_download_outlined;
      default:
        return Icons.history_toggle_off_rounded;
    }
  }

  Widget _buildHero(BuildContext context) {
    final approvedCount =
        _records.where((record) => record.status == 'approved').length;
    final pendingCount =
        _records.where((record) => record.status == 'pending').length;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF4F8FC),
            Color(0xFFFDF4EC),
          ],
        ),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.isAdmin ? '流转记录总览' : '我的操作记录',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: 28,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.isAdmin
                ? '查看所有用户的入库、出库和审批状态，快速发现待处理事项。'
                : '查看你的领用与处理进度，了解每一条申请的最新状态。',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              _RecordMetric(
                label: '总记录',
                value: '${_records.length}',
                color: AppTheme.ink,
                icon: Icons.layers_outlined,
              ),
              _RecordMetric(
                label: '已通过',
                value: '$approvedCount',
                color: AppTheme.mint,
                icon: Icons.check_circle_outline,
              ),
              _RecordMetric(
                label: '待审批',
                value: '$pendingCount',
                color: AppTheme.gold,
                icon: Icons.hourglass_top_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    const statuses = [
      ('all', '全部'),
      ('pending', '待审批'),
      ('approved', '已通过'),
      ('rejected', '已拒绝'),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.74),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: statuses
            .map(
              (entry) => ChoiceChip(
                label: Text(entry.$2),
                selected: _statusFilter == entry.$1,
                onSelected: (_) {
                  setState(() => _statusFilter = entry.$1);
                },
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.78),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.history_toggle_off_rounded,
            size: 72,
            color: AppTheme.inkMuted,
          ),
          const SizedBox(height: 14),
          Text(
            '暂无记录',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            '当前筛选条件下还没有可展示的记录。',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRecordCard(RecordItem record) {
    final statusColor = _statusColor(record.status);
    final typeColor = record.type == 'in'
        ? AppTheme.mint
        : record.type == 'out'
            ? AppTheme.accent
            : AppTheme.ink;

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
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: typeColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(_typeIcon(record.type), color: typeColor),
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
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  _statusText(record.status),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: statusColor,
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
              _RecordBadge(
                icon: _typeIcon(record.type),
                label: _typeText(record.type),
                color: typeColor,
              ),
              _RecordBadge(
                icon: Icons.tag_outlined,
                label: '数量 ${record.count}',
                color: AppTheme.ink,
              ),
              _RecordBadge(
                icon: Icons.schedule_rounded,
                label: _formatTime(record.createdAt),
                color: AppTheme.gold,
              ),
              if (widget.isAdmin && record.username != null)
                _RecordBadge(
                  icon: Icons.person_outline_rounded,
                  label: record.username!,
                  color: AppTheme.mint,
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final filtered = _filteredRecords;

    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildHero(context),
          const SizedBox(height: 16),
          _buildFilterBar(),
          const SizedBox(height: 16),
          if (filtered.isEmpty)
            _buildEmptyState()
          else
            ...filtered.map(
              (record) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _buildRecordCard(record),
              ),
            ),
        ],
      ),
    );
  }
}

class _RecordMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _RecordMetric({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
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
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _RecordBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _RecordBadge({
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
