import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kofund/core/constants/app_colors.dart';
import 'package:kofund/core/widgets/gradient_sheet_scaffold.dart';

class DatabaseToolsScreen extends StatefulWidget {
  const DatabaseToolsScreen({super.key});

  @override
  State<DatabaseToolsScreen> createState() => _DatabaseToolsScreenState();
}

class _DatabaseToolsScreenState extends State<DatabaseToolsScreen> {
  final _fs = FirebaseFirestore.instance;

  // Stats
  bool _isLoadingStats = false;
  Map<String, int> _collectionCounts = {};

  // Query tester
  final _valueController = TextEditingController();
  bool _isQuerying = false;
  List<Map<String, dynamic>> _queryResults = [];
  String? _queryError;
  String? _selectedCollection;
  String? _selectedField;

  // Dynamic fields discovered from Firestore
  List<String> _discoveredFields = [];
  bool _isLoadingFields = false;

  static const _trackedCollections = [
    'users',
    'communities',
    'events',
    'participants',
    'contributions',
    'expenses',
    'notifications',
    'announcements',
    'polls',
    'issues',
    'deleted_contributions',
  ];

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  Future<void> _loadCollectionStats() async {
    setState(() {
      _isLoadingStats = true;
      _collectionCounts = {};
    });

    final Map<String, int> counts = {};
    for (final col in _trackedCollections) {
      try {
        final agg = await _fs.collection(col).count().get();
        counts[col] = agg.count ?? 0;
      } catch (_) {
        counts[col] = -1;
      }
    }

    if (mounted) {
      setState(() {
        _collectionCounts = counts;
        _isLoadingStats = false;
      });
    }
  }

  /// Fetch the first document in the selected collection to discover all field names.
  Future<void> _discoverFields(String collection) async {
    setState(() {
      _isLoadingFields = true;
      _discoveredFields = [];
      _selectedField = null;
    });

    try {
      final snap = await _fs.collection(collection).limit(1).get();
      if (snap.docs.isNotEmpty) {
        final data = snap.docs.first.data();
        final fields = data.keys.toList()..sort();
        setState(() => _discoveredFields = fields);
      }
    } catch (_) {
      // silently fail — the dropdown will just be empty
    } finally {
      if (mounted) setState(() => _isLoadingFields = false);
    }
  }

  /// Open a bottom sheet with a two-column grid of field nnames to choose from.
  void _showFieldPicker(BuildContext context) {
    if (_discoveredFields.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
          decoration: BoxDecoration(
            color: AppColors.background(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border(context), borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.filter_list_rounded, color: AppColors.primary(context)),
                    const SizedBox(width: 8),
                    Text('Select Field', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary(context))),
                    const Spacer(),
                    if (_selectedField != null)
                      TextButton(
                        onPressed: () {
                          setState(() => _selectedField = null);
                          Navigator.pop(ctx);
                        },
                        child: Text('Clear', style: TextStyle(color: AppColors.error(context))),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: GridView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 3.2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: _discoveredFields.length,
                  itemBuilder: (context, index) {
                    final field = _discoveredFields[index];
                    final isSelected = field == _selectedField;
                    return GestureDetector(
                      onTap: () {
                        setState(() => _selectedField = field);
                        Navigator.pop(ctx);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary(context).withValues(alpha: 0.15)
                              : AppColors.card(context),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary(context)
                                : AppColors.border(context),
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected ? Icons.check_circle : Icons.circle_outlined,
                              size: 16,
                              color: isSelected ? AppColors.primary(context) : AppColors.textTertiary(context),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                field,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  color: isSelected ? AppColors.primary(context) : AppColors.textPrimary(context),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Future<void> _runQuery() async {
    if (_selectedCollection == null) {
      setState(() => _queryError = 'Please select a collection first');
      return;
    }

    setState(() {
      _isQuerying = true;
      _queryResults = [];
      _queryError = null;
    });

    try {
      Query query = _fs.collection(_selectedCollection!).limit(20);

      final field = _selectedField;
      final value = _valueController.text.trim();
      if (field != null && field.isNotEmpty && value.isNotEmpty) {
        // Try to parse the value to its correct type
        dynamic parsedValue = value;
        if (value == 'true') parsedValue = true;
        if (value == 'false') parsedValue = false;
        if (double.tryParse(value) != null && !value.contains('.')) {
          parsedValue = int.parse(value);
        } else if (double.tryParse(value) != null) {
          parsedValue = double.parse(value);
        }
        query = query.where(field, isEqualTo: parsedValue);
      }

      final snap = await query.get();
      setState(() {
        _queryResults = snap.docs.map((doc) => {'__id__': doc.id, ...doc.data() as Map<String, dynamic>}).toList();
      });
    } catch (e) {
      setState(() => _queryError = e.toString());
    } finally {
      if (mounted) setState(() => _isQuerying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientSheetScaffold(
      title: 'Database Tools',
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: AppColors.textPrimary(context)),
        onPressed: () => Navigator.pop(context),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // — Query Tester —
            _buildSectionHeader(
              context,
              icon: Icons.search_rounded,
              title: 'Query Tester',
              color: Colors.teal,
            ),
            const SizedBox(height: 12),
            Card(
              color: AppColors.card(context),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Collection dropdown
                    DropdownButtonFormField<String>(
                      initialValue: _selectedCollection,
                      decoration: InputDecoration(
                        labelText: 'Collection',
                        prefixIcon: const Icon(Icons.folder_rounded, size: 18),
                        filled: true,
                        fillColor: AppColors.background(context),
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: AppColors.border(context)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                      ),
                      hint: const Text('Select a collection'),
                      items: _trackedCollections.map((col) => DropdownMenuItem(
                        value: col,
                        child: Text(col, style: const TextStyle(fontSize: 14)),
                      )).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedCollection = val;
                            _selectedField = null;
                            _queryResults = [];
                            _queryError = null;
                          });
                          _discoverFields(val);
                        }
                      },
                    ),

                    const SizedBox(height: 12),

                    // Filter field picker button + value input
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Field picker button
                        Expanded(
                          child: GestureDetector(
                            onTap: (_selectedCollection != null && !_isLoadingFields)
                                ? () => _showFieldPicker(context)
                                : null,
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'Filter Field',
                                prefixIcon: Icon(
                                  Icons.filter_list,
                                  size: 18,
                                  color: _selectedCollection == null ? AppColors.textTertiary(context) : null,
                                ),
                                suffixIcon: _isLoadingFields
                                    ? const Padding(
                                        padding: EdgeInsets.all(12),
                                        child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                                      )
                                    : Icon(Icons.arrow_drop_down, color: AppColors.textSecondary(context)),
                                filled: true,
                                fillColor: AppColors.background(context),
                                isDense: true,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: AppColors.border(context)),
                                ),
                                contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                              ),
                              child: Text(
                                _selectedField ?? 'Optional',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _selectedField != null
                                      ? AppColors.textPrimary(context)
                                      : AppColors.textTertiary(context),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Value input
                        Expanded(child: _buildInput(context, _valueController, 'Filter Value', 'e.g. true', Icons.text_fields)),
                      ],
                    ),

                    const SizedBox(height: 4),
                    Text(
                      'Leave filter blank to fetch first 20 documents',
                      style: TextStyle(fontSize: 11, color: AppColors.textTertiary(context)),
                    ),
                    const SizedBox(height: 12),

                    // Run query button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isQuerying ? null : _runQuery,
                        icon: _isQuerying
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.play_arrow_rounded),
                        label: const Text('Run Query'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary(context),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),

                    // Error display
                    if (_queryError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.error(context).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.error(context).withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline, color: AppColors.error(context), size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _queryError!,
                                  style: TextStyle(fontSize: 12, color: AppColors.error(context)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Query results
            if (_queryResults.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.table_rows_rounded, size: 16, color: AppColors.textSecondary(context)),
                  const SizedBox(width: 6),
                  Text(
                    '${_queryResults.length} document(s) returned (max 20)',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // If a field is selected, show a focused list of that field's values
              if (_selectedField != null)
                ..._queryResults.map((doc) => _buildFieldValueCard(context, doc))
              else
                ..._queryResults.map((doc) => _buildDocCard(context, doc)),
            ],

            const SizedBox(height: 28),

            // — Collection Stats —
            _buildSectionHeader(
              context,
              icon: Icons.bar_chart_rounded,
              title: 'Collection Stats',
              color: Colors.blue,
              action: _isLoadingStats
                  ? null
                  : TextButton.icon(
                      onPressed: _loadCollectionStats,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Load'),
                    ),
            ),
            const SizedBox(height: 8),
            if (_isLoadingStats)
              const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
            else if (_collectionCounts.isEmpty)
              _buildEmptyHint(context, 'Tap "Load" to fetch document counts for each collection.')
            else
              Card(
                color: AppColors.card(context),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Column(
                  children: _collectionCounts.entries.toList().asMap().entries.map((entry) {
                    final i = entry.key;
                    final col = entry.value.key;
                    final count = entry.value.value;
                    final isLast = i == _collectionCounts.length - 1;
                    return Column(
                      children: [
                        ListTile(
                          leading: Icon(Icons.storage_rounded, size: 20, color: AppColors.primary(context)),
                          title: Text(col, style: TextStyle(color: AppColors.textPrimary(context), fontSize: 14)),
                          trailing: count == -1
                              ? const Icon(Icons.error_outline, color: Colors.red, size: 18)
                              : Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary(context).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    count.toString(),
                                    style: TextStyle(
                                      color: AppColors.primary(context),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                        ),
                        if (!isLast) Divider(height: 1, color: AppColors.border(context)),
                      ],
                    );
                  }).toList(),
                ),
              ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Color color,
    Widget? action,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary(context),
          ),
        ),
        const Spacer(),
        if (action != null) action,
      ],
    );
  }

  Widget _buildEmptyHint(BuildContext context, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Text(
        message,
        style: TextStyle(fontSize: 13, color: AppColors.textSecondary(context)),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildInput(
    BuildContext context,
    TextEditingController controller,
    String label,
    String hint,
    IconData icon,
  ) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 18),
        filled: true,
        fillColor: AppColors.background(context),
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.border(context)),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      ),
    );
  }

  /// Shows a compact card with doc ID + selected field value, expandable to show all fields.
  Widget _buildFieldValueCard(BuildContext context, Map<String, dynamic> doc) {
    final id = doc['__id__'] as String;
    final value = doc[_selectedField!];
    final fields = Map<String, dynamic>.from(doc)..remove('__id__');

    return Card(
      color: AppColors.card(context),
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: AppColors.border(context)),
      ),
      child: ExpansionTile(
        leading: Icon(Icons.insert_drive_file_rounded, size: 16, color: AppColors.primary(context)),
        title: Row(
          children: [
            Expanded(
              child: Text(
                id,
                style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppColors.textTertiary(context)),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary(context).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                value?.toString() ?? 'null',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary(context),
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
        children: [
          ...fields.entries.map((e) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 120,
                  child: Text(
                    e.key,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary(context)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    e.value?.toString() ?? 'null',
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary(context), fontFamily: 'monospace'),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          )),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// Shows full document data in an expandable tile.
  Widget _buildDocCard(BuildContext context, Map<String, dynamic> doc) {
    final id = doc['__id__'] as String;
    final fields = Map<String, dynamic>.from(doc)..remove('__id__');

    return Card(
      color: AppColors.card(context),
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: AppColors.border(context)),
      ),
      child: ExpansionTile(
        leading: Icon(Icons.insert_drive_file_rounded, size: 18, color: AppColors.primary(context)),
        title: Text(
          id,
          style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: AppColors.textPrimary(context)),
          overflow: TextOverflow.ellipsis,
        ),
        children: [
          ...fields.entries.map((e) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 120,
                  child: Text(
                    e.key,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary(context)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    e.value?.toString() ?? 'null',
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary(context), fontFamily: 'monospace'),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          )),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}





