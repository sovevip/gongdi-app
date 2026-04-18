import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/database_service.dart';
import '../utils/site_time_helper.dart';

class MaterialStockPage extends StatefulWidget {
  const MaterialStockPage({super.key});

  @override
  State<MaterialStockPage> createState() => _MaterialStockPageState();
}

class _MaterialStockPageState extends State<MaterialStockPage> {
  final DatabaseService _db = DatabaseService();
  List<Map<String, dynamic>> _materials = [];
  List<Map<String, dynamic>> _records = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final materials = await _db.getMaterialsWithStock();
      final records = await _db.getAllMaterialRecords();
      setState(() {
        _materials = materials;
        _records = records;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showAddMaterialDialog() {
    final nameController = TextEditingController();
    final unitController = TextEditingController();
    final minStockController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Row(
                    children: [
                      Icon(Icons.inventory_2, color: AppTheme.primaryColor),
                      SizedBox(width: 12),
                      Text(
                        '添加材料',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: '材料名称 *',
                      prefixIcon: Icon(Icons.label, color: AppTheme.primaryColor),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: unitController,
                    decoration: const InputDecoration(
                      labelText: '单位 *',
                      prefixIcon: Icon(Icons.straighten, color: AppTheme.primaryColor),
                      hintText: '例如：袋、吨、立方米',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: minStockController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: '最低库存预警值',
                      prefixIcon: Icon(Icons.warning_amber, color: Colors.orange),
                      hintText: '低于此值将标红提醒',
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('取消'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            if (nameController.text.trim().isEmpty ||
                                unitController.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('请填写材料名称和单位'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                              return;
                            }
                            try {
                              await _db.insertMaterial({
                                'name': nameController.text.trim(),
                                'unit': unitController.text.trim(),
                                'min_stock': double.tryParse(minStockController.text) ?? 0,
                                'created_at': DateTime.now().toIso8601String(),
                              });
                              if (mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('材料添加成功'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                                _loadData();
                              }
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('添加失败: $e'), backgroundColor: Colors.red),
                              );
                            }
                          },
                          child: const Text('确认添加'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showRecordDialog(int materialId, String materialName, String unit, bool isIn) {
    final quantityController = TextEditingController();
    final noteController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Icon(
                        isIn ? Icons.add_box : Icons.remove_circle,
                        color: isIn ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${isIn ? "入库" : "领用"} - $materialName',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: quantityController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: '数量 *',
                      prefixIcon: Icon(
                        isIn ? Icons.add : Icons.remove,
                        color: isIn ? Colors.green : Colors.red,
                      ),
                      suffixText: unit,
                    ),
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        locale: const Locale('zh', 'CN'),
                      );
                      if (picked != null) {
                        setModalState(() => selectedDate = picked);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: '日期',
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(
                        SiteTimeHelper.formatDate(selectedDate),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: noteController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: '备注（可选）',
                      hintText: isIn ? '例如：供应商、批次号' : '例如：领用班组、用途',
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('取消'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            if (quantityController.text.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('请输入数量'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                              return;
                            }
                            try {
                              await _db.insertMaterialRecord({
                                'material_id': materialId,
                                'type': isIn ? 'in' : 'out',
                                'quantity': double.tryParse(quantityController.text) ?? 0,
                                'date': selectedDate.toIso8601String().split('T').first,
                                'note': noteController.text.trim(),
                                'created_at': DateTime.now().toIso8601String(),
                              });
                              if (mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('${isIn ? "入库" : "领用"}成功'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                                _loadData();
                              }
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('操作失败: $e'), backgroundColor: Colors.red),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isIn ? Colors.green : Colors.red,
                          ),
                          child: Text(isIn ? '确认入库' : '确认领用'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showMaterialDetail(Map<String, dynamic> material) {
    final materialId = material['id'] as int;
    final stock = (material['stock'] as num?)?.toDouble() ?? 0;
    final minStock = (material['min_stock'] as num?)?.toDouble() ?? 0;
    final isLow = stock < minStock && minStock > 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isLow ? Colors.red.withOpacity(0.1) : AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.inventory_2,
                              color: isLow ? Colors.red : AppTheme.primaryColor,
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              material['name'] ?? '',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: isLow ? Colors.red : AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        if (isLow)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              '库存不足',
                              style: TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStockItem('当前库存', '${stock.toStringAsFixed(1)}', material['unit'], isLow ? Colors.red : Colors.green),
                        _buildStockItem('入库总量', '${(material['total_in'] as num?)?.toDouble().toStringAsFixed(1) ?? "0"}', material['unit'], Colors.blue),
                        _buildStockItem('出库总量', '${(material['total_out'] as num?)?.toDouble().toStringAsFixed(1) ?? "0"}', material['unit'], Colors.orange),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _showRecordDialog(materialId, material['name'], material['unit'], true);
                        },
                        icon: const Icon(Icons.add_box),
                        label: const Text('入库'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: stock <= 0
                            ? null
                            : () {
                                Navigator.pop(context);
                                _showRecordDialog(materialId, material['name'], material['unit'], false);
                              },
                        icon: const Icon(Icons.remove_circle),
                        label: const Text('领用'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _db.getMaterialRecords(materialId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final records = snapshot.data ?? [];
                    if (records.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history, size: 48, color: Colors.grey[300]),
                            const SizedBox(height: 8),
                            Text('暂无记录', style: TextStyle(color: Colors.grey[500])),
                          ],
                        ),
                      );
                    }
                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: records.length,
                      itemBuilder: (context, index) {
                        final record = records[index];
                        final isIn = record['type'] == 'in';
                        final quantity = (record['quantity'] as num?)?.toDouble() ?? 0;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: (isIn ? Colors.green : Colors.red).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                isIn ? Icons.arrow_downward : Icons.arrow_upward,
                                color: isIn ? Colors.green : Colors.red,
                              ),
                            ),
                            title: Text(
                              '${isIn ? "入库" : "领用"} ${quantity.toStringAsFixed(1)} ${record['unit']}',
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(record['date'] ?? ''),
                                if (record['note'] != null && record['note'].toString().isNotEmpty)
                                  Text(
                                    record['note'],
                                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                  ),
                              ],
                            ),
                            trailing: Text(
                              isIn ? '+${quantity.toStringAsFixed(1)}' : '-${quantity.toStringAsFixed(1)}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isIn ? Colors.green : Colors.red,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStockItem(String label, String value, String? unit, Color color) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                unit ?? '',
                style: TextStyle(fontSize: 12, color: color),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('材料管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: '刷新',
          ),
          if (kDebugMode)
            IconButton(
              icon: const Icon(Icons.science),
              onPressed: _generateDemoData,
              tooltip: '生成演示数据',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildQuickActions(context),
                  const SizedBox(height: 20),
                  _buildSummaryCard(context),
                  const SizedBox(height: 20),
                  _buildMaterialsList(context),
                  const SizedBox(height: 20),
                  _buildRecentRecords(context),
                  const SizedBox(height: 100),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddMaterialDialog,
        icon: const Icon(Icons.add),
        label: const Text('添加材料'),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildQuickActionCard(
            context,
            icon: Icons.add_box,
            title: '入库登记',
            subtitle: '材料入库',
            color: Colors.green,
            onTap: _materials.isEmpty ? null : () => _showQuickInDialog(),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildQuickActionCard(
            context,
            icon: Icons.remove_circle,
            title: '领用记录',
            subtitle: '材料领用',
            color: Colors.orange,
            onTap: _materials.isEmpty ? null : () => _showQuickOutDialog(),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: onTap == null ? Colors.grey[200] : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: onTap == null ? Colors.grey[300]! : color.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: onTap == null ? Colors.grey[400] : color,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: onTap == null ? Colors.grey : color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: onTap == null ? Colors.grey : color.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showQuickInDialog() {
    int? selectedMaterialId;
    final quantityController = TextEditingController();
    final noteController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Row(
                    children: [
                      Icon(Icons.add_box, color: Colors.green),
                      SizedBox(width: 12),
                      Text(
                        '入库登记',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  DropdownButtonFormField<int>(
                    value: selectedMaterialId,
                    decoration: const InputDecoration(
                      labelText: '选择材料',
                      prefixIcon: Icon(Icons.inventory_2, color: Colors.green),
                    ),
                    items: _materials.map((m) => DropdownMenuItem(
                      value: m['id'] as int,
                      child: Text('${m['name']} (${m['unit']})'),
                    )).toList(),
                    onChanged: (value) => setModalState(() => selectedMaterialId = value),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: quantityController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: '入库数量',
                      prefixIcon: Icon(Icons.add, color: Colors.green),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: noteController,
                    decoration: const InputDecoration(
                      labelText: '备注（可选）',
                      hintText: '例如：供应商、批次号',
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('取消'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            if (selectedMaterialId == null || quantityController.text.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('请选择材料并输入数量'), backgroundColor: Colors.orange),
                              );
                              return;
                            }
                            try {
                              await _db.insertMaterialRecord({
                                'material_id': selectedMaterialId,
                                'type': 'in',
                                'quantity': double.tryParse(quantityController.text) ?? 0,
                                'date': DateTime.now().toIso8601String().split('T').first,
                                'note': noteController.text.trim(),
                                'created_at': DateTime.now().toIso8601String(),
                              });
                              if (mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('入库成功'), backgroundColor: Colors.green),
                                );
                                _loadData();
                              }
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('入库失败: $e'), backgroundColor: Colors.red),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                          child: const Text('确认入库'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showQuickOutDialog() {
    int? selectedMaterialId;
    final quantityController = TextEditingController();
    final noteController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Row(
                    children: [
                      Icon(Icons.remove_circle, color: Colors.orange),
                      SizedBox(width: 12),
                      Text(
                        '领用记录',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  DropdownButtonFormField<int>(
                    value: selectedMaterialId,
                    decoration: const InputDecoration(
                      labelText: '选择材料',
                      prefixIcon: Icon(Icons.inventory_2, color: Colors.orange),
                    ),
                    items: _materials.where((m) => ((m['stock'] as num?)?.toDouble() ?? 0) > 0).map((m) {
                      final stock = (m['stock'] as num?)?.toDouble() ?? 0;
                      return DropdownMenuItem(
                        value: m['id'] as int,
                        child: Text('${m['name']} (库存: ${stock.toStringAsFixed(1)} ${m['unit']})'),
                      );
                    }).toList(),
                    onChanged: (value) => setModalState(() => selectedMaterialId = value),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: quantityController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: '领用数量',
                      prefixIcon: Icon(Icons.remove, color: Colors.orange),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: noteController,
                    decoration: const InputDecoration(
                      labelText: '备注（可选）',
                      hintText: '例如：领用班组、用途',
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('取消'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            if (selectedMaterialId == null || quantityController.text.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('请选择材料并输入数量'), backgroundColor: Colors.orange),
                              );
                              return;
                            }
                            try {
                              await _db.insertMaterialRecord({
                                'material_id': selectedMaterialId,
                                'type': 'out',
                                'quantity': double.tryParse(quantityController.text) ?? 0,
                                'date': DateTime.now().toIso8601String().split('T').first,
                                'note': noteController.text.trim(),
                                'created_at': DateTime.now().toIso8601String(),
                              });
                              if (mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('领用成功'), backgroundColor: Colors.green),
                                );
                                _loadData();
                              }
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('领用失败: $e'), backgroundColor: Colors.red),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                          child: const Text('确认领用'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _generateDemoData() async {
    try {
      final demoMaterials = [
        {'name': '水泥', 'unit': '袋', 'min_stock': 50.0},
        {'name': '沙子', 'unit': '吨', 'min_stock': 20.0},
        {'name': '钢筋', 'unit': '吨', 'min_stock': 5.0},
        {'name': '砖块', 'unit': '块', 'min_stock': 5000.0},
        {'name': '木材', 'unit': '立方米', 'min_stock': 10.0},
      ];

      for (var material in demoMaterials) {
        final id = await _db.insertMaterial({
          'name': material['name'],
          'unit': material['unit'],
          'min_stock': material['min_stock'],
          'created_at': DateTime.now().toIso8601String(),
        });
        
        await _db.insertMaterialRecord({
          'material_id': id,
          'type': 'in',
          'quantity': (material['min_stock'] as double) * 2,
          'date': DateTime.now().toIso8601String().split('T').first,
          'note': '初始库存',
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已生成 5 种演示材料'),
            backgroundColor: Colors.green,
          ),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('生成失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildSummaryCard(BuildContext context) {
    final totalMaterials = _materials.length;
    final lowStockCount = _materials.where((m) {
      final stock = (m['stock'] as num?)?.toDouble() ?? 0;
      final minStock = (m['min_stock'] as num?)?.toDouble() ?? 0;
      return stock < minStock && minStock > 0;
    }).length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryColor, AppTheme.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem('材料种类', '$totalMaterials', '种'),
          Container(height: 40, width: 1, color: Colors.white24),
          _buildSummaryItem('库存预警', '$lowStockCount', '种', highlight: lowStockCount > 0),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, String unit, {bool highlight = false}) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: highlight ? Colors.amber : Colors.white,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                unit,
                style: TextStyle(
                  fontSize: 14,
                  color: highlight ? Colors.amber : Colors.white70,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildMaterialsList(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '材料库存',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  '点击查看详情',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_materials.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 8),
                      Text('暂无材料数据', style: TextStyle(color: Colors.grey[500])),
                      const SizedBox(height: 8),
                      if (kDebugMode)
                        Text(
                          '点击右上角烧瓶图标生成演示数据',
                          style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                        ),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _materials.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final material = _materials[index];
                  final stock = (material['stock'] as num?)?.toDouble() ?? 0;
                  final minStock = (material['min_stock'] as num?)?.toDouble() ?? 0;
                  final isLow = stock < minStock && minStock > 0;
                  final isWarning = stock < 10;

                  return ListTile(
                    onTap: () => _showMaterialDetail(material),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (isLow || isWarning ? Colors.red : AppTheme.primaryColor).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.inventory_2,
                        color: isLow || isWarning ? Colors.red : AppTheme.primaryColor,
                      ),
                    ),
                    title: Row(
                      children: [
                        Text(
                          material['name'] ?? '',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: isLow || isWarning ? Colors.red : AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            material['unit'] ?? '',
                            style: const TextStyle(fontSize: 10, color: AppTheme.primaryColor),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      '预警值: ${minStock.toStringAsFixed(1)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              stock.toStringAsFixed(1),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isLow || isWarning ? Colors.red : Colors.green,
                              ),
                            ),
                            if (isLow || isWarning)
                              const Text(
                                '库存预警',
                                style: TextStyle(fontSize: 10, color: Colors.red),
                              ),
                          ],
                        ),
                        if (isWarning) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.warning,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentRecords(BuildContext context) {
    final recentRecords = _records.take(10).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '最近出入库记录',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  '共 ${_records.length} 条',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (recentRecords.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.history, size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 8),
                      Text('暂无记录', style: TextStyle(color: Colors.grey[500])),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: recentRecords.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final record = recentRecords[index];
                  final isIn = record['type'] == 'in';
                  final quantity = (record['quantity'] as num?)?.toDouble() ?? 0;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: (isIn ? Colors.green : Colors.red).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            isIn ? Icons.arrow_downward : Icons.arrow_upward,
                            color: isIn ? Colors.green : Colors.red,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${record['name'] ?? ''} ${isIn ? "入库" : "领用"}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                record['date'] ?? '',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${isIn ? "+" : "-"}${quantity.toStringAsFixed(1)} ${record['unit']}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isIn ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
