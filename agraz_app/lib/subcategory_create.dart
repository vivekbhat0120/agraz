import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'app_theme.dart';
import 'l10n/app_l10n.dart';

class SubcategoryManagementPage extends StatefulWidget {
  const SubcategoryManagementPage({super.key});

  @override
  State<SubcategoryManagementPage> createState() =>
      _SubcategoryManagementPageState();
}

class _SubcategoryManagementPageState extends State<SubcategoryManagementPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();

  List<Map<String, dynamic>> subcategories = [];
  List<Map<String, dynamic>> categories = [];
  bool isLoading = true;
  bool isEditing = false;
  String? editingId;
  String? selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    _fetchSubcategories();
    _searchController.addListener(_searchSubcategories);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    _remarksController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _fetchCategories() async {
    try {
      final response = await http.get(
        Uri.parse('https://your-api.com/categories'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          categories = List<Map<String, dynamic>>.from(data['categories']);
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading categories: $e')));
    }
  }

  Future<void> _fetchSubcategories() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('https://your-api.com/subcategories'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          subcategories = List<Map<String, dynamic>>.from(
            data['subcategories'],
          );
          isLoading = false;
        });
      } else {
        throw Exception('Failed to load subcategories');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _searchSubcategories() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      _fetchSubcategories();
      return;
    }

    setState(() => isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('https://your-api.com/subcategories/search?query=$query'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          subcategories = List<Map<String, dynamic>>.from(
            data['subcategories'],
          );
          isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Search error: $e')));
    }
  }

  Future<void> _submitSubcategory() async {
    if (!_formKey.currentState!.validate()) return;
    if (selectedCategoryId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('Please select a category'))));
      return;
    }

    final subcategory = {
      'name': _nameController.text.trim(),
      'categoryId': selectedCategoryId,
      'remarks': _remarksController.text.trim(),
    };

    try {
      final response =
          isEditing
              ? await http.put(
                Uri.parse('https://your-api.com/subcategories/$editingId'),
                headers: {'Content-Type': 'application/json'},
                body: json.encode(subcategory),
              )
              : await http.post(
                Uri.parse('https://your-api.com/subcategories'),
                headers: {'Content-Type': 'application/json'},
                body: json.encode(subcategory),
              );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _resetForm();
        _fetchSubcategories();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEditing ? 'Updated successfully' : 'Added successfully',
            ),
          ),
        );
      } else {
        throw Exception('Failed to save subcategory');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _deleteSubcategory(String id) async {
    try {
      final response = await http.delete(
        Uri.parse('https://your-api.com/subcategories/$id'),
      );
      if (response.statusCode == 200) {
        _fetchSubcategories();
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(tr('Deleted successfully'))));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _editSubcategory(Map<String, dynamic> subcategory) {
    setState(() {
      isEditing = true;
      editingId = subcategory['_id'];
      _nameController.text = subcategory['name'];
      _remarksController.text = subcategory['remarks'] ?? '';
      selectedCategoryId = subcategory['categoryId'];
      _categoryController.text =
          categories.firstWhere(
            (cat) => cat['_id'] == subcategory['categoryId'],
          )['name'];
    });
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _nameController.clear();
    _remarksController.clear();
    _categoryController.clear();
    setState(() {
      isEditing = false;
      editingId = null;
      selectedCategoryId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GradientAppBar(
        title: tr('Subcategory Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchSubcategories,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: tr('Search Subcategories'),
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
            ),
          ),
          Expanded(
            child:
                isLoading
                    ? Center(child: CircularProgressIndicator())
                    : subcategories.isEmpty
                    ? Center(child: Text(tr('No subcategories found')))
                    : ListView.builder(
                      itemCount: subcategories.length,
                      itemBuilder: (context, index) {
                        final subcategory = subcategories[index];
                        final category = categories.firstWhere(
                          (cat) => cat['_id'] == subcategory['categoryId'],
                          orElse: () => {'name': 'Unknown'},
                        );
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 8.0,
                            vertical: 4.0,
                          ),
                          child: ListTile(
                            title: Text(subcategory['name']),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Category: ${category['name']}'),
                                if (subcategory['remarks'] != null &&
                                    subcategory['remarks'].isNotEmpty)
                                  Text(subcategory['remarks']),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit,
                                    color: Colors.blue,
                                  ),
                                  onPressed:
                                      () => _editSubcategory(subcategory),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  onPressed:
                                      () => _deleteSubcategory(
                                        subcategory['_id'],
                                      ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed:
            () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (context) => _buildSubcategoryForm(),
            ),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSubcategoryForm() {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16.0,
        right: 16.0,
        top: 16.0,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isEditing ? 'Edit Subcategory' : 'Add New Subcategory',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: tr('Subcategory Name'),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter subcategory name';
                }
                return null;
              },
            ),
            SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: tr('Category'),
                border: OutlineInputBorder(),
              ),
              initialValue: selectedCategoryId,
              items:
                  categories.map((category) {
                    return DropdownMenuItem<String>(
                      value: category['_id'],
                      child: Text(category['name']),
                    );
                  }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  selectedCategoryId = newValue;
                  if (newValue != null) {
                    _categoryController.text =
                        categories.firstWhere(
                          (cat) => cat['_id'] == newValue,
                        )['name'];
                  }
                });
              },
              validator: (value) {
                if (value == null) {
                  return 'Please select a category';
                }
                return null;
              },
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _remarksController,
              decoration: InputDecoration(
                labelText: tr('Remarks (Optional)'),
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _resetForm();
                  },
                  child: Text(tr('Cancel')),
                ),
                SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _submitSubcategory,
                  child: Text(isEditing ? 'Update' : 'Save'),
                ),
              ],
            ),
            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
