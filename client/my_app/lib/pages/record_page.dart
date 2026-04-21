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

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 640;
        const metricSpacing = 10.0;
        final metricWidth = isCompact
            ? (constraints.maxWidth - metricSpacing * 2) / 3
            : 180.0;

        return Container(
          padding: EdgeInsets.all(isCompact ? 16 : 22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFF4F8FC),
                Color(0xFFFDF4EC),
              ],
            ),
            borderRadius: BorderRadius.circular(isCompact ? 24 : 30),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.isAdmin ? '记录概览' : '我的记录',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontSize: isCompact ? 20 : 28,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.isAdmin ? '查看审批与处理进度。' : '查看你的领用与处理进度。',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              SizedBox(height: isCompact ? 12 : 18),
              Wrap(
                spacing: metricSpacing,
                runSpacing: metricSpacing,
                children: [
                  SizedBox(
                    width: metricWidth,
                    child: _RecordMetric(
                      label: '总记录',
                      value: '${_records.length}',
                      color: AppTheme.ink,
                      icon: Icons.layers_outlined,
                      compact: isCompact,
                    ),
                  ),
                  SizedBox(
                    width: metricWidth,
                    child: _RecordMetric(
                      label: '已通过',
                      value: '$approvedCount',
                      color: AppTheme.mint,
                      icon: Icons.check_circle_outline,
                      compact: isCompact,
                    ),
                  ),
                  SizedBox(
                    width: metricWidth,
                    child: _RecordMetric(
                      label: '待审批',
                      value: '$pendingCount',
                      color: AppTheme.gold,
                      icon: Icons.hourglass_top_rounded,
                      compact: isCompact,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterBar(BuildContext context) {
    const statuses = [
      ('all', '全部'),
      ('pending', '待审批'),
      ('approved', '已通过'),
      ('rejected', '已拒绝'),
    ];
    final isCompact = MediaQuery.sizeOf(context).width < 640;

    return Container(
      padding: EdgeInsets.all(isCompact ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.74),
        borderRadius: BorderRadius.circular(isCompact ? 20 : 26),
      ),
      child: isCompact
          ? SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: statuses
                    .map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(entry.$2),
                          selected: _statusFilter == entry.$1,
                          onSelected: (_) {
                            setState(() => _statusFilter = entry.$1);
                          },
                        ),
                      ),
                    )
                    .toList(),
              ),
            )
          : Wrap(
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

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.78),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.history_toggle_off_rounded,
            size: 64,
            color: AppTheme.inkMuted,
          ),
          const SizedBox(height: 12),
          Text(
            '暂无记录',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            '当前筛选条件下还没有可展示的记录。',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRecordCard(BuildContext context, RecordItem record) {
    final isCompact = MediaQuery.sizeOf(context).width < 640;
    final statusColor = _statusColor(record.status);
    final typeColor = record.type == 'in'
        ? AppTheme.mint
        : record.type == 'out'
            ? AppTheme.accent
            : AppTheme.ink;

    return Container(
      padding: EdgeInsets.all(isCompact ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.84),
        borderRadius: BorderRadius.circular(isCompact ? 24 : 28),
        border: Border.all(color: Colors.white.withOpacity(0.72)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: isCompact ? 42 : 48,
                width: isCompact ? 42 : 48,
                decoration: BoxDecoration(
                  color: typeColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(_typeIcon(record.type), color: typeColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.name ?? '物品 #${record.materialId}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${record.brand ?? ''} | ${record.spec ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
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
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
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
    final isCompact = MediaQuery.sizeOf(context).width < 640;

    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: EdgeInsets.all(isCompact ? 14 : 20),
        children: [
          _buildHero(context),
          SizedBox(height: isCompact ? 12 : 16),
          _buildFilterBar(context),
          SizedBox(height: isCompact ? 12 : 16),
          if (filtered.isEmpty)
            _buildEmptyState(context)
          else
            ...filtered.map(
              (record) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildRecordCard(context, record),
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
  final bool compact;

  const _RecordMetric({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 12 : 18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.78),
        borderRadius: BorderRadius.circular(compact ? 18 : 24),
      ),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 32,
                  width: 32,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(height: 10),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 11,
                      ),
                ),
              ],
            )
          : Column(
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
