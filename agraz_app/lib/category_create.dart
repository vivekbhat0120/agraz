import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'app_theme.dart';
import 'l10n/app_l10n.dart';

class CategoryManagementPage extends StatefulWidget {
  const CategoryManagementPage({super.key});

  @override
  State<CategoryManagementPage> createState() => _CategoryManagementPageState();
}

class _CategoryManagementPageState extends State<CategoryManagementPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();

  List<Map<String, dynamic>> categories = [];
  bool isLoading = true;
  bool isEditing = false;
  String? editingId;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    _searchController.addListener(_searchCategories);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _fetchCategories() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('https://your-api.com/categories'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          categories = List<Map<String, dynamic>>.from(data['categories']);
          isLoading = false;
        });
      } else {
        throw Exception('Failed to load categories');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _searchCategories() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      _fetchCategories();
      return;
    }

    setState(() => isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('https://your-api.com/categories/search?query=$query'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          categories = List<Map<String, dynamic>>.from(data['categories']);
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

  Future<void> _submitCategory() async {
    if (!_formKey.currentState!.validate()) return;

    final category = {
      'name': _nameController.text.trim(),
      'remarks': _remarksController.text.trim(),
    };

    try {
      final response =
          isEditing
              ? await http.put(
                Uri.parse('https://your-api.com/categories/$editingId'),
                headers: {'Content-Type': 'application/json'},
                body: json.encode(category),
              )
              : await http.post(
                Uri.parse('https://your-api.com/categories'),
                headers: {'Content-Type': 'application/json'},
                body: json.encode(category),
              );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _resetForm();
        _fetchCategories();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEditing ? 'Updated successfully' : 'Added successfully',
            ),
          ),
        );
      } else {
        throw Exception('Failed to save category');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _deleteCategory(String id) async {
    try {
      final response = await http.delete(
        Uri.parse('https://your-api.com/categories/$id'),
      );
      if (response.statusCode == 200) {
        _fetchCategories();
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

  void _editCategory(Map<String, dynamic> category) {
    setState(() {
      isEditing = true;
      editingId = category['_id'];
      _nameController.text = category['name'];
      _remarksController.text = category['remarks'] ?? '';
    });
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _nameController.clear();
    _remarksController.clear();
    setState(() {
      isEditing = false;
      editingId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GradientAppBar(
        title: tr('Category Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchCategories,
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
                labelText: tr('Search Categories'),
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
                    : categories.isEmpty
                    ? Center(child: Text(tr('No categories found')))
                    : ListView.builder(
                      itemCount: categories.length,
                      itemBuilder: (context, index) {
                        final category = categories[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 8.0,
                            vertical: 4.0,
                          ),
                          child: ListTile(
                            title: Text(category['name']),
                            subtitle:
                                category['remarks'] != null &&
                                        category['remarks'].isNotEmpty
                                    ? Text(category['remarks'])
                                    : null,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit,
                                    color: Colors.blue,
                                  ),
                                  onPressed: () => _editCategory(category),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  onPressed:
                                      () => _deleteCategory(category['_id']),
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
              builder: (context) => _buildCategoryForm(),
            ),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildCategoryForm() {
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
              isEditing ? 'Edit Category' : 'Add New Category',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: tr('Category Name'),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter category name';
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
                  onPressed: _submitCategory,
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
