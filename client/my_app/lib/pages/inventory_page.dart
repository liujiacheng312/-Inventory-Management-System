import 'package:flutter/material.dart';

import '../models/material_item.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';

class InventoryPage extends StatefulWidget {
  final bool isAdmin;

  const InventoryPage({super.key, this.isAdmin = false});

  @override
  State<InventoryPage> createState() => InventoryPageState();
}

class InventoryPageState extends State<InventoryPage> {
  final TextEditingController _searchController = TextEditingController();

  List<MaterialItem> _materials = [];
  bool _isLoading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<MaterialItem> get _filteredMaterials {
    if (_query.isEmpty) {
      return _materials;
    }

    final query = _query.toLowerCase();
    return _materials.where((item) {
      return item.name.toLowerCase().contains(query) ||
          item.brand.toLowerCase().contains(query) ||
          item.model.toLowerCase().contains(query) ||
          item.spec.toLowerCase().contains(query) ||
          item.remark.toLowerCase().contains(query);
    }).toList();
  }

  int get _totalQuantity =>
      _materials.fold<int>(0, (sum, item) => sum + item.quantity);

  int get _lowStockCount =>
      _materials.where((item) => item.quantity <= 5).length;

  Future<void> load() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.getMaterials();
      if (!mounted) return;
      setState(() {
        _materials = data.map((e) => MaterialItem.fromJson(e)).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('获取库存失败：$e')),
      );
    }
  }

  Future<void> _showMaterialDialog({MaterialItem? item}) async {
    final isEditing = item != null;
    final nameController = TextEditingController(text: item?.name ?? '');
    final brandController = TextEditingController(text: item?.brand ?? '');
    final modelController = TextEditingController(text: item?.model ?? '');
    final specController = TextEditingController(text: item?.spec ?? '');
    final quantityController =
        TextEditingController(text: item?.quantity.toString() ?? '');
    final remarkController = TextEditingController(text: item?.remark ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? '编辑库存' : '新增库存'),
        content: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _DialogInputField(
                  controller: nameController,
                  label: '物料名称',
                  icon: Icons.inventory_2_outlined,
                ),
                const SizedBox(height: 12),
                _DialogInputField(
                  controller: brandController,
                  label: '品牌',
                  icon: Icons.sell_outlined,
                ),
                const SizedBox(height: 12),
                _DialogInputField(
                  controller: modelController,
                  label: '型号',
                  icon: Icons.straighten_outlined,
                ),
                const SizedBox(height: 12),
                _DialogInputField(
                  controller: specController,
                  label: '规格',
                  icon: Icons.tune_outlined,
                ),
                const SizedBox(height: 12),
                _DialogInputField(
                  controller: quantityController,
                  label: '数量',
                  icon: Icons.tag_outlined,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                _DialogInputField(
                  controller: remarkController,
                  label: '备注',
                  icon: Icons.edit_note_outlined,
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(isEditing ? '保存修改' : '创建库存'),
          ),
        ],
      ),
    );

    if (result != true) return;

    if (nameController.text.trim().isEmpty ||
        brandController.text.trim().isEmpty ||
        modelController.text.trim().isEmpty ||
        specController.text.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请完整填写物料信息')),
      );
      return;
    }

    final payload = {
      'name': nameController.text.trim(),
      'brand': brandController.text.trim(),
      'model': modelController.text.trim(),
      'spec': specController.text.trim(),
      'quantity': int.tryParse(quantityController.text) ?? 0,
      'remark': remarkController.text.trim(),
    };

    final success = isEditing
        ? await ApiService.updateMaterial(item.id, payload)
        : await ApiService.addMaterial(payload);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(success ? '保存成功' : '保存失败')),
    );
    if (success) {
      await load();
    }
  }

  Future<void> _deleteItem(MaterialItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除库存'),
        content: Text('确定要删除“${item.name}”吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            child: const Text('确认删除'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final success = await ApiService.deleteMaterial(item.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(success ? '删除成功' : '删除失败')),
    );
    if (success) {
      await load();
    }
  }

  Future<void> _takeItem(MaterialItem item) async {
    final countController = TextEditingController(text: '1');
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('领用物料'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MetaLine(label: '物料', value: item.name),
              _MetaLine(label: '品牌', value: item.brand),
              _MetaLine(label: '型号', value: item.model),
              _MetaLine(label: '规格', value: item.spec),
              _MetaLine(label: '可用库存', value: '${item.quantity}'),
              if (item.remark.isNotEmpty)
                _MetaLine(label: '备注', value: item.remark),
              const SizedBox(height: 14),
              _DialogInputField(
                controller: countController,
                label: '领用数量',
                icon: Icons.remove_shopping_cart_outlined,
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('提交领用'),
          ),
        ],
      ),
    );

    if (result != true) return;

    final count = int.tryParse(countController.text) ?? 0;
    final response = await ApiService.takeMaterial(item.id, count);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(response['message']?.toString() ?? '操作完成')),
    );

    if (response['success'] == true) {
      await load();
    }
  }

  Future<void> _returnItem(MaterialItem item) async {
    if (item.borrowedCount <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没有可归还的物品')),
      );
      return;
    }

    final countController = TextEditingController(text: '${item.borrowedCount}');
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('归还物料'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MetaLine(label: '物料', value: item.name),
              _MetaLine(label: '品牌', value: item.brand),
              _MetaLine(label: '型号', value: item.model),
              _MetaLine(label: '规格', value: item.spec),
              _MetaLine(label: '已借出', value: '${item.borrowedCount}'),
              const SizedBox(height: 14),
              _DialogInputField(
                controller: countController,
                label: '归还数量（最多 ${item.borrowedCount}）',
                icon: Icons.assignment_return_outlined,
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('提交归还'),
          ),
        ],
      ),
    );

    if (result != true) return;

    int count = int.tryParse(countController.text) ?? 0;
    if (count <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入有效的归还数量')),
      );
      return;
    }
    if (count > item.borrowedCount) {
      count = item.borrowedCount;
    }

    final response = await ApiService.returnMaterial(item.id, count);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(response['message']?.toString() ?? '操作完成')),
    );

    if (response['success'] == true) {
      await load();
    }
  }

  Color _quantityColor(int quantity) {
    if (quantity <= 5) return AppTheme.danger;
    if (quantity <= 20) return AppTheme.gold;
    return AppTheme.mint;
  }

  Widget _buildSummaryCard({
    required BuildContext context,
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: 180,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.78),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.7)),
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
          Text(value, style: textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(label, style: textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildHero(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFDF7F0),
            Color(0xFFF0F6FA),
          ],
        ),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 540),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isAdmin ? '库存控制台' : '可领用库存',
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontSize: 28,
                              ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.isAdmin
                          ? '集中查看库存健康度，快速新增、编辑和维护物料。'
                          : '查询当前库存状态，找到需要的物料并发起领用。',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
              if (widget.isAdmin)
                ElevatedButton.icon(
                  onPressed: () => _showMaterialDialog(),
                  icon: const Icon(Icons.add),
                  label: const Text('新增物料'),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              _buildSummaryCard(
                context: context,
                label: '物料种类',
                value: '${_materials.length}',
                icon: Icons.category_outlined,
                color: AppTheme.ink,
              ),
              _buildSummaryCard(
                context: context,
                label: '库存总数',
                value: '$_totalQuantity',
                icon: Icons.stacked_bar_chart_rounded,
                color: AppTheme.mint,
              ),
              _buildSummaryCard(
                context: context,
                label: '低库存预警',
                value: '$_lowStockCount',
                icon: Icons.warning_amber_rounded,
                color: AppTheme.gold,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.72),
        borderRadius: BorderRadius.circular(28),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() => _query = value.trim());
        },
        decoration: InputDecoration(
          hintText: '搜索物料名称、品牌、型号、规格或备注',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _query = '');
                  },
                  icon: const Icon(Icons.close_rounded),
                ),
        ),
      ),
    );
  }

  Widget _buildMaterialCard(MaterialItem item) {
    final quantityColor = _quantityColor(item.quantity);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.84),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _TinyBadge(label: item.brand, color: AppTheme.ink),
                        _TinyBadge(
                          label: item.model,
                          color: AppTheme.accent,
                        ),
                        _TinyBadge(label: item.spec, color: AppTheme.mint),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: quantityColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${item.quantity}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: quantityColor,
                          ),
                    ),
                    Text(
                      '库存',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: quantityColor,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (item.remark.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.canvas.withOpacity(0.5),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                item.remark,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.ink,
                    ),
              ),
            ),
          ],
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: widget.isAdmin
                ? [
                    OutlinedButton.icon(
                      onPressed: () => _showMaterialDialog(item: item),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('编辑'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _deleteItem(item),
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('删除'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.danger,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed:
                          item.quantity > 0 ? () => _takeItem(item) : null,
                      icon: const Icon(Icons.shopping_bag_outlined),
                      label: Text(item.quantity > 0 ? '领用' : '库存不足'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _returnItem(item),
                      icon: const Icon(Icons.assignment_return_outlined),
                      label: const Text('归还'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.mint,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ]
                : [
                    ElevatedButton.icon(
                      onPressed:
                          item.quantity > 0 ? () => _takeItem(item) : null,
                      icon: const Icon(Icons.shopping_bag_outlined),
                      label: Text(item.quantity > 0 ? '领用' : '库存不足'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _returnItem(item),
                      icon: const Icon(Icons.assignment_return_outlined),
                      label: const Text('归还'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.mint,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final isSearching = _query.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.78),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          Icon(
            isSearching ? Icons.search_off_rounded : Icons.inventory_2_outlined,
            size: 72,
            color: AppTheme.inkMuted,
          ),
          const SizedBox(height: 14),
          Text(
            isSearching ? '没有找到匹配的物料' : '当前还没有库存数据',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            isSearching ? '试试换个关键词，或者清空搜索条件。' : '添加第一条物料后，库存会显示在这里。',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          if (widget.isAdmin && !isSearching) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _showMaterialDialog(),
              icon: const Icon(Icons.add),
              label: const Text('新增物料'),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final filteredMaterials = _filteredMaterials;

    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildHero(context),
          const SizedBox(height: 16),
          _buildSearchBar(),
          const SizedBox(height: 16),
          if (filteredMaterials.isEmpty)
            _buildEmptyState()
          else
            ...filteredMaterials.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _buildMaterialCard(item),
              ),
            ),
        ],
      ),
    );
  }
}

class _DialogInputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final int maxLines;

  const _DialogInputField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  final String label;
  final String value;

  const _MetaLine({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodyLarge,
          children: [
            TextSpan(
              text: '$label：',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.inkMuted,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

class _TinyBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _TinyBadge({
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
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.ink,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
