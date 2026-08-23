import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'income_expense_data.dart';
import 'api_service.dart';
import 'l10n/app_l10n.dart';

class AddressPage extends StatefulWidget {
  final IncomeExpenseData formData;

  const AddressPage({super.key, required this.formData});

  @override
  AddressPageState createState() => AddressPageState();
}

class AddressPageState extends State<AddressPage> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();
  bool isLoading = false;

  // Add controllers for prefilling
  late TextEditingController nameController;
  late TextEditingController villageController;
  late TextEditingController postController;
  late TextEditingController talukController;
  late TextEditingController districtController;
  late TextEditingController extraAddressController;
  late TextEditingController pincodeController;

  @override
  void initState() {
    super.initState();
    // Initialize controllers
    nameController = TextEditingController();
    villageController = TextEditingController();
    postController = TextEditingController();
    talukController = TextEditingController();
    districtController = TextEditingController();
    extraAddressController = TextEditingController();
    pincodeController = TextEditingController();

    // Fetch user details if mobile is available
    if (widget.formData.mobile != null && widget.formData.mobile!.isNotEmpty) {
      _fetchUserDetails();
    }
  }

  @override
  void dispose() {
    // Dispose controllers
    nameController.dispose();
    villageController.dispose();
    postController.dispose();
    talukController.dispose();
    districtController.dispose();
    extraAddressController.dispose();
    pincodeController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserDetails() async {
    try {
      final responseData = await _apiService.fetchUserByMobile(
        widget.formData.mobile!,
      );
      if (responseData != null &&
          responseData['data'] != null &&
          responseData['data'].isNotEmpty) {
        final transaction = responseData['data'][0];
        setState(() {
          // Prefill controllers with fetched transaction data
          nameController.text = transaction['name'] ?? '';
          villageController.text = transaction['village'] ?? '';
          postController.text = transaction['post'] ?? '';
          talukController.text = transaction['taluk'] ?? '';
          districtController.text = transaction['district'] ?? '';
          extraAddressController.text = transaction['extraAddress'] ?? '';
          pincodeController.text = transaction['pincode'] ?? '';
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to fetch user details: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _submitForm() async {
    // Remove form validation since all fields are optional
    _formKey.currentState?.save();

    setState(() {
      isLoading = true;
    });

    try {
      final success = await _apiService.submitTransaction(widget.formData);

      if (!mounted) return;
      setState(() {
        isLoading = false;
      });

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('Transaction recorded successfully!')),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate back to home and clear stack
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('Failed to record transaction. Please try again.')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildAddressField(
    String label,
    IconData icon,
    Function(String?) onSaved,
    TextEditingController controller, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          prefixIcon: Icon(icon),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 12,
          ),
        ),
        style: const TextStyle(fontSize: 16),
        keyboardType: keyboardType,
        onSaved: onSaved,
        // No validator - field is optional
        validator: null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: GradientAppBar(title: 'Address Details'),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE8F5E8), Color(0xFFF8F9FA)],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Transaction Summary
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Transaction Summary',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                      SizedBox(height: 12),
                      _buildSummaryRow(
                        'Type',
                        widget.formData.receiptPaymentType ?? '',
                      ),
                      _buildSummaryRow(
                        'Category',
                        widget.formData.category ?? '',
                      ),
                      if (widget.formData.subCategory != null)
                        _buildSummaryRow(
                          'Sub Category',
                          widget.formData.subCategory!,
                        ),
                      _buildSummaryRow(
                        'Amount',
                        '₹${widget.formData.amount?.toStringAsFixed(2) ?? ''}',
                      ),
                      if (widget.formData.narration != null)
                        _buildSummaryRow(
                          'Narration',
                          widget.formData.narration!,
                        ),
                      _buildSummaryRow('Mobile', widget.formData.mobile ?? ''),
                    ],
                  ),
                ),

                // Address Fields
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.location_pin,
                            color: const Color(0xFF2E7D32),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Address Details (Optional)',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      _buildAddressField(
                        'Name',
                        Icons.person,
                        (value) => widget.formData.name = value,
                        nameController,
                      ),
                      _buildAddressField(
                        'Village',
                        Icons.location_city,
                        (value) => widget.formData.village = value,
                        villageController,
                      ),
                      _buildAddressField(
                        'Post',
                        Icons.local_post_office,
                        (value) => widget.formData.post = value,
                        postController,
                      ),
                      _buildAddressField(
                        'Taluk',
                        Icons.map,
                        (value) => widget.formData.taluk = value,
                        talukController,
                      ),
                      _buildAddressField(
                        'District',
                        Icons.place,
                        (value) => widget.formData.district = value,
                        districtController,
                      ),
                      _buildAddressField(
                        'Extra Address',
                        Icons.note_add,
                        (value) => widget.formData.extraAddress = value,
                        extraAddressController,
                      ),
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: TextFormField(
                          controller: pincodeController,
                          decoration: InputDecoration(
                            labelText: tr('Pincode'),
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.pin_drop),
                            contentPadding: EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 12,
                            ),
                          ),
                          style: const TextStyle(fontSize: 16),
                          keyboardType: TextInputType.number,
                          // No validator - field is optional
                          validator: null,
                          onSaved: (value) {
                            widget.formData.pincode = value;
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // Submit Button
                SizedBox(height: 24),
                Container(
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2E7D32).withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child:
                        isLoading
                            ? SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3,
                              ),
                            )
                            : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.save, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'SAVE TRANSACTION',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                  ),
                ),
                SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }
}
