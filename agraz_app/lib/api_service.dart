import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_token.dart';
import 'income_expense_data.dart';
import 'config.dart'; // Import the config file
import 'offline_sync.dart' as offline;

class ApiService {
  Future<bool> submitTransaction(IncomeExpenseData data) async {
    try {
      final jsonData = data.toJson();

      debugPrint('=== DATA SENDING TO BACKEND ===');
      debugPrint('URL: $BASE_URL/api/income_expense');
      debugPrint(jsonEncode(jsonData));

      final headers = await authJsonHeaders();
      final response = await offline.post(
        Uri.parse('$BASE_URL/api/income_expense'),
        headers: headers,
        body: jsonEncode(jsonData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('Transaction submitted successfully');
        return true;
      } else {
        debugPrint('API Error: ${response.statusCode} - ${response.body}');
        String msg = 'Failed to submit transaction (${response.statusCode})';
        try {
          final err = jsonDecode(response.body);
          if (err is Map && err['error'] != null) {
            msg = err['error'].toString();
          } else if (err is Map && err['message'] != null) {
            msg = err['message'].toString();
          }
        } catch (_) {}
        throw Exception(msg);
      }
    } catch (e) {
      debugPrint('Error submitting transaction: $e');
      rethrow;
    }
  }

  Future<bool> updateTransaction(int id, IncomeExpenseData data) async {
    try {
      final headers = await authJsonHeaders();
      final response = await offline.put(
        Uri.parse('$BASE_URL/api/income_expense/$id'),
        headers: headers,
        body: jsonEncode(data.toJson()),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      }
      String msg = 'Failed to update (${response.statusCode})';
      try {
        final err = jsonDecode(response.body);
        if (err is Map && err['error'] != null) msg = err['error'].toString();
      } catch (_) {}
      throw Exception(msg);
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> deleteTransaction(int id) async {
    try {
      final headers = await authGetHeaders();
      final response = await offline.delete(
        Uri.parse('$BASE_URL/api/income_expense/$id'),
        headers: headers,
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      debugPrint('Error deleting transaction: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> fetchApprovedServices({String? query}) async {
    final headers = await authGetHeaders();
    final uri = Uri.parse('$BASE_URL/api/services').replace(
      queryParameters: {
        if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
      },
    );
    final response = await offline.get(uri, headers: headers);
    if (response.statusCode != 200) {
      throw Exception('Failed to load services (${response.statusCode})');
    }
    final decoded = jsonDecode(response.body);
    final list = decoded is Map ? (decoded['data'] as List? ?? []) : (decoded as List? ?? []);
    return list
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<Map<String, dynamic>?> fetchUserByMobile(String mobile) async {
    try {
      debugPrint('Fetching user details for mobile: $mobile');
      final headers = await authGetHeaders();
      final response = await offline.get(
        Uri.parse('$BASE_URL/api/income_expense/mobile/$mobile'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final userData = jsonDecode(response.body);
        debugPrint('Fetched user data: $userData');
        // Assuming the response is the direct user object, not wrapped in 'data'
        return userData;
      } else {
        debugPrint(
          'Failed to fetch user: ${response.statusCode} - ${response.body}',
        );
        return null;
      }
    } catch (e) {
      debugPrint('Error fetching user: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> submitServiceRegistration(
    String mobile,
    String name,
    String mainCategory,
    String businessName, {
    String? subCategory,
    String? email,
    String? remarks,
  }) async {
    try {
      debugPrint('ðŸ“¡ Making API request to: $BASE_URL/api/register-business');
      debugPrint('ðŸ“¦ Request data:');
      debugPrint('  - mobile: $mobile');
      debugPrint('  - name: $name');
      debugPrint('  - main_category: $mainCategory');
      debugPrint('  - sub_category: $subCategory');
      debugPrint('  - business_name: $businessName');
      debugPrint('  - email: $email');
      debugPrint('  - remarks: $remarks');

      final headers = await authJsonHeaders();
      final response = await offline.post(
        Uri.parse('$BASE_URL/api/register-business'),
        headers: headers,
        body: jsonEncode({
          'mobile': mobile,
          'name': name,
          'main_category': mainCategory,
          'sub_category': subCategory,
          'business_name': businessName,
          'email': email,
          'remarks': remarks,
        }),
      );

      debugPrint('ðŸ“¥ Response status code: ${response.statusCode}');
      debugPrint('ðŸ“¥ Response body: ${response.body}');

      if (response.statusCode == 200) {
        try {
          final responseData =
              jsonDecode(response.body) as Map<String, dynamic>;
          debugPrint('âœ… Parsed response: $responseData');

          // Add success flag if not present
          final bool isSuccess =
              responseData['success'] == true ||
              responseData['status'] == 'success' ||
              responseData['message']?.toString().toLowerCase().contains(
                    'success',
                  ) ==
                  true ||
              responseData['error'] == false ||
              responseData['insertId'] != null ||
              responseData['id'] != null;

          // Return consistent response format
          return {
            'success': isSuccess,
            'message':
                responseData['message'] ??
                (isSuccess
                    ? 'Service registered successfully!'
                    : 'Registration failed'),
            'data': responseData,
          };
        } catch (e) {
          // If JSON parsing fails but status is 200
          debugPrint('âš ï¸ Could not parse JSON response, but status is 200');
          return {
            'success': true,
            'message': 'Service registered successfully!',
            'data': {},
          };
        }
      } else {
        // Handle error responses
        Map<String, dynamic> errorResponse = {
          'success': false,
          'message': 'Request failed with status ${response.statusCode}',
        };

        try {
          final errorData = jsonDecode(response.body);
          errorResponse['data'] = errorData;
          if (errorData['message'] != null) {
            errorResponse['message'] = errorData['message'];
          }
        } catch (e) {
          errorResponse['message'] =
              response.body.isNotEmpty
                  ? response.body
                  : errorResponse['message'];
        }

        debugPrint('âŒ Error response: $errorResponse');
        return errorResponse;
      }
    } on SocketException catch (e) {
      debugPrint('ðŸ”Œ Socket error: $e');
      return {
        'success': false,
        'message':
            'Cannot connect to server. Please check if the server is running.',
        'error': e.toString(),
      };
    } on TimeoutException catch (e) {
      debugPrint('â±ï¸ Request timeout: $e');
      return {
        'success': false,
        'message': 'Request timeout. The server might be slow or unresponsive.',
        'error': e.toString(),
      };
    } on FormatException catch (e) {
      debugPrint('ðŸ“„ JSON format error: $e');
      return {
        'success': false,
        'message': 'Invalid response from server',
        'error': e.toString(),
      };
    } on http.ClientException catch (e) {
      debugPrint('ðŸŒ Network error: $e');
      return {
        'success': false,
        'message':
            'Network error: check your internet connection and server URL.',
        'error': e.toString(),
      };
    } catch (e, stackTrace) {
      debugPrint('âŒ Unexpected error in submitServiceRegistration: $e');
      debugPrint('Stack trace: $stackTrace');
      return {
        'success': false,
        'message': 'Failed to register business: $e',
        'error': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> createLabor(Map<String, dynamic> data) async {
    try {
      final headers = await authJsonHeaders();
      final response = await offline.post(
        Uri.parse('$BASE_URL/api/labors'),
        headers: headers,
        body: jsonEncode(data),
      );
      final decoded = response.body.isNotEmpty
          ? jsonDecode(response.body)
          : <String, dynamic>{};
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'data': decoded is Map ? (decoded['data'] ?? decoded) : decoded,
          'message': decoded is Map
              ? (decoded['message'] ?? 'Laborer added successfully')
              : 'Laborer added successfully',
        };
      }
      return {
        'success': false,
        'message': _apiErrorMessage(decoded, response.statusCode,
            fallback: 'Failed to add laborer'),
        'statusCode': response.statusCode,
      };
    } catch (e) {
      return {'success': false, 'message': 'Failed to add laborer: $e'};
    }
  }

  Future<Map<String, dynamic>> createLaborsBatch(
      List<Map<String, dynamic>> rows) async {
    try {
      final headers = await authJsonHeaders();
      final response = await offline.post(
        Uri.parse('$BASE_URL/api/labors/batch'),
        headers: headers,
        body: jsonEncode(rows),
      );
      final decoded = response.body.isNotEmpty
          ? jsonDecode(response.body)
          : <String, dynamic>{};
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'data': decoded is Map ? (decoded['data'] ?? decoded) : decoded,
          'message': decoded is Map
              ? (decoded['message'] ?? 'Labourers added successfully')
              : 'Labourers added successfully',
        };
      }
      return {
        'success': false,
        'message': _apiErrorMessage(decoded, response.statusCode,
            fallback: 'Failed to add labourers'),
        'statusCode': response.statusCode,
      };
    } catch (e) {
      return {'success': false, 'message': 'Failed to add labourers: $e'};
    }
  }

  /// Prefer API `error`, then `message`, then a status-aware fallback.
  String _apiErrorMessage(
    dynamic decoded,
    int statusCode, {
    required String fallback,
  }) {
    if (decoded is Map) {
      final err = decoded['error']?.toString().trim();
      if (err != null && err.isNotEmpty) return err;
      final msg = decoded['message']?.toString().trim();
      if (msg != null && msg.isNotEmpty) return msg;
      final details = decoded['details']?.toString().trim();
      if (details != null && details.isNotEmpty) return details;
    }
    if (statusCode == 401) {
      return 'Invalid or expired JWT';
    }
    if (statusCode == 403) {
      return 'Forbidden';
    }
    return '$fallback ($statusCode)';
  }

  Future<List<Map<String, dynamic>>> fetchLabors({
    String? mobile,
    String? name,
    String? q,
    String? from,
    String? to,
    String? category,
    String? entryKind,
    int limit = 100,
  }) async {
    try {
      final uri = Uri.parse('$BASE_URL/api/labors').replace(
        queryParameters: {
          'limit': limit.toString(),
          if (mobile != null && mobile.isNotEmpty) 'mobile': mobile,
          if (name != null && name.isNotEmpty) 'name': name,
          if (q != null && q.isNotEmpty) 'q': q,
          if (from != null && from.isNotEmpty) 'from': from,
          if (to != null && to.isNotEmpty) 'to': to,
          if (category != null && category.isNotEmpty) 'category': category,
          if (entryKind != null && entryKind.isNotEmpty) 'entry_kind': entryKind,
        },
      );
      final headers = await authGetHeaders();
      final response = await offline.get(uri, headers: headers);
      if (response.statusCode != 200) return [];
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['data'] is List) {
        return (decoded['data'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching labors: $e');
      return [];
    }
  }

  /// Payable / paid / balance / receivable for one labourer.
  /// GET /api/labors/balance?name=&mobile=
  Future<Map<String, dynamic>?> fetchLaborBalance({
    String? name,
    String? mobile,
  }) async {
    try {
      final n = name?.trim() ?? '';
      final m = mobile?.trim() ?? '';
      if (n.isEmpty && m.isEmpty) return null;
      final uri = Uri.parse('$BASE_URL/api/labors/balance').replace(
        queryParameters: {
          if (m.isNotEmpty) 'mobile': m,
          if (n.isNotEmpty) 'name': n,
        },
      );
      final headers = await authGetHeaders();
      final response = await offline.get(uri, headers: headers);
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return null;
    } catch (e) {
      debugPrint('Error fetching labor balance: $e');
      return null;
    }
  }

  /// Distinct labourers with totals. Optional search [q] on name/mobile.
  Future<List<Map<String, dynamic>>> fetchLaborPeople({String? q}) async {
    final headers = await authGetHeaders();
    final uri = Uri.parse('$BASE_URL/api/labors/people').replace(
      queryParameters: {
        if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
        'limit': '200',
      },
    );
    final response = await offline.get(uri, headers: headers);
    if (response.statusCode != 200) {
      throw Exception('Failed to load labourers (${response.statusCode})');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map && decoded['data'] is List) {
      return (decoded['data'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return [];
  }

  /// Labour-wise monthly/weekly/category schedule report.
  Future<Map<String, dynamic>> fetchLaborReports({
    int? year,
    int? month,
    int months = 6,
    String? mobile,
    String? name,
    String? category,
    String? workType,
  }) async {
    final now = DateTime.now();
    final headers = await authGetHeaders();
    final uri = Uri.parse('$BASE_URL/api/labors/reports').replace(
      queryParameters: {
        'year': (year ?? now.year).toString(),
        'month': (month ?? now.month).toString(),
        'months': months.toString(),
        if (mobile != null && mobile.isNotEmpty) 'mobile': mobile,
        if (name != null && name.isNotEmpty) 'name': name,
        if (category != null && category.isNotEmpty) 'category': category,
        if (workType != null && workType.isNotEmpty) 'work_type': workType,
      },
    );
    final response = await offline.get(uri, headers: headers);
    if (response.statusCode != 200) {
      throw Exception('Failed to load labour report (${response.statusCode})');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    throw Exception('Invalid labour report response');
  }

  Future<bool> deleteLabor(int id) async {
    try {
      final headers = await authGetHeaders();
      final response = await offline.delete(
        Uri.parse('$BASE_URL/api/labors/$id'),
        headers: headers,
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      debugPrint('Error deleting labor: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> updateLabor(
      int id, Map<String, dynamic> data) async {
    try {
      final headers = await authJsonHeaders();
      final response = await offline.put(
        Uri.parse('$BASE_URL/api/labors/$id'),
        headers: headers,
        body: jsonEncode(data),
      );
      final decoded = response.body.isNotEmpty
          ? jsonDecode(response.body)
          : <String, dynamic>{};
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'data': decoded is Map ? (decoded['data'] ?? decoded) : decoded,
          'message': decoded is Map
              ? (decoded['message'] ?? 'Labor record updated')
              : 'Labor record updated',
        };
      }
      final err = decoded is Map
          ? (decoded['error']?.toString() ?? 'Failed to update laborer')
          : 'Failed to update laborer';
      return {'success': false, 'message': err};
    } catch (e) {
      return {'success': false, 'message': 'Failed to update laborer: $e'};
    }
  }

  /// Income/expense reports: monthly, weekly, category, trends.
  Future<Map<String, dynamic>> fetchIncomeExpenseReports({
    int? year,
    int? month,
    int months = 6,
    String? type,
    String? mobile,
    String? category,
  }) async {
    final now = DateTime.now();
    final headers = await authGetHeaders();
    final uri = Uri.parse('$BASE_URL/api/income_expense/reports').replace(
      queryParameters: {
        'year': (year ?? now.year).toString(),
        'month': (month ?? now.month).toString(),
        'months': months.toString(),
        if (type != null && type.isNotEmpty) 'type': type,
        if (mobile != null && mobile.isNotEmpty) 'mobile': mobile,
        if (category != null && category.isNotEmpty) 'category': category,
      },
    );
    final response = await offline.get(uri, headers: headers);
    if (response.statusCode != 200) {
      throw Exception('Failed to load reports (${response.statusCode})');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    throw Exception('Invalid report response');
  }

  /// Party ledger balance for a mobile. Positive side=credit, negative=debit.
  Future<Map<String, dynamic>?> fetchPartyBalance(String mobile) async {
    try {
      final headers = await authGetHeaders();
      final response = await offline.get(
        Uri.parse('$BASE_URL/api/income_expense/balance/$mobile'),
        headers: headers,
      );
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return null;
    } catch (e) {
      debugPrint('Error fetching party balance: $e');
      return null;
    }
  }

  /// Lookup income/expense rows by name (for search suggestions).
  Future<List<Map<String, dynamic>>> searchUsersByName(
    String name, {
    int limit = 8,
  }) async {
    try {
      final headers = await authGetHeaders();
      final uri = Uri.parse('$BASE_URL/api/income_expense').replace(
        queryParameters: {
          'name': name.trim(),
          'limit': limit.toString(),
          'page': '1',
        },
      );
      final response = await offline.get(uri, headers: headers);
      if (response.statusCode != 200) return [];
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['data'] is List) {
        final seen = <String>{};
        final out = <Map<String, dynamic>>[];
        for (final item in decoded['data'] as List) {
          if (item is! Map) continue;
          final row = Map<String, dynamic>.from(item);
          final key =
              '${row['name'] ?? ''}|${row['mobile'] ?? ''}'.toLowerCase();
          if (key.trim() == '|' || seen.contains(key)) continue;
          seen.add(key);
          out.add(row);
        }
        return out;
      }
      return [];
    } catch (e) {
      debugPrint('Error searching users by name: $e');
      return [];
    }
  }

  /// Lookup latest income/expense row by name (for autofill).
  Future<Map<String, dynamic>?> fetchUserByName(String name) async {
    final rows = await searchUsersByName(name, limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Map<String, dynamic>>> fetchLaborRates({
    String? mobile,
    String? name,
  }) async {
    try {
      final headers = await authGetHeaders();
      final uri = Uri.parse('$BASE_URL/api/labor_rates').replace(
        queryParameters: {
          if (mobile != null && mobile.isNotEmpty) 'mobile': mobile,
          if (name != null && name.isNotEmpty) 'name': name,
        },
      );
      final response = await offline.get(uri, headers: headers);
      if (response.statusCode != 200) return [];
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['data'] is List) {
        return (decoded['data'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching labor rates: $e');
      return [];
    }
  }

  /// Saves category rates for a labourer identified by [mobile] and/or
  /// [name] â€” at least one of the two must be provided.
  Future<bool> saveLaborRates({
    String? mobile,
    String? name,
    required Map<String, double> rates,
  }) async {
    try {
      final headers = await authJsonHeaders();
      final body = {
        'mobile': mobile ?? '',
        'name': name ?? '',
        'rates': rates.entries
            .map((e) => {'category': e.key, 'rate': e.value})
            .toList(),
      };
      final response = await offline.put(
        Uri.parse('$BASE_URL/api/labor_rates'),
        headers: headers,
        body: jsonEncode(body),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Error saving labor rates: $e');
      return false;
    }
  }

  /// PUT /api/labors/bulk-rate â€” update wage on payable/opening rows in a date range.
  Future<Map<String, dynamic>> bulkUpdateLaborRate({
    required String name,
    String? mobile,
    required String from,
    required String to,
    required double rate,
  }) async {
    final headers = await authJsonHeaders();
    final response = await offline.put(
      Uri.parse('$BASE_URL/api/labors/bulk-rate'),
      headers: headers,
      body: jsonEncode({
        'name': name,
        if (mobile != null && mobile.isNotEmpty) 'mobile': mobile,
        'from': from,
        'to': to,
        'rate': rate,
      }),
    );
    final decoded =
        response.body.isNotEmpty ? jsonDecode(response.body) : <String, dynamic>{};
    if (response.statusCode == 200 || response.statusCode == 201) {
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return {'success': true};
    }
    throw Exception(
      _apiErrorMessage(decoded, response.statusCode,
          fallback: 'Failed to update labour rates'),
    );
  }

  // â”€â”€ Diary labels â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<Map<String, dynamic>> fetchDiaryLabels() async {
    try {
      final headers = await authGetHeaders();
      final response = await offline.get(
        Uri.parse('$BASE_URL/api/diary/labels'),
        headers: headers,
      );
      final decoded =
          response.body.isNotEmpty ? jsonDecode(response.body) : <String, dynamic>{};
      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': _mapListFromBody(response.body),
        };
      }
      return {
        'success': false,
        'statusCode': response.statusCode,
        'message': _apiErrorMessage(decoded, response.statusCode,
            fallback: 'Failed to load diary labels'),
        'data': <Map<String, dynamic>>[],
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to load diary labels: $e',
        'data': <Map<String, dynamic>>[],
      };
    }
  }

  Future<Map<String, dynamic>> createDiaryLabel({
    required String name,
    String icon = 'label',
  }) async {
    try {
      final headers = await authJsonHeaders();
      final response = await offline.post(
        Uri.parse('$BASE_URL/api/diary/labels'),
        headers: headers,
        body: jsonEncode({'name': name, 'icon': icon}),
      );
      final decoded =
          response.body.isNotEmpty ? jsonDecode(response.body) : <String, dynamic>{};
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'data': decoded is Map ? (decoded['data'] ?? decoded) : decoded,
          'message': decoded is Map
              ? (decoded['message'] ?? 'Label created')
              : 'Label created',
        };
      }
      return {
        'success': false,
        'statusCode': response.statusCode,
        'message': _apiErrorMessage(decoded, response.statusCode,
            fallback: 'Failed to create diary label'),
      };
    } catch (e) {
      return {'success': false, 'message': 'Failed to create diary label: $e'};
    }
  }

  Future<Map<String, dynamic>> updateDiaryLabel(
    int id, {
    required String name,
    String? icon,
  }) async {
    try {
      final headers = await authJsonHeaders();
      final response = await offline.put(
        Uri.parse('$BASE_URL/api/diary/labels/$id'),
        headers: headers,
        body: jsonEncode({
          'name': name,
          if (icon != null && icon.isNotEmpty) 'icon': icon,
        }),
      );
      final decoded =
          response.body.isNotEmpty ? jsonDecode(response.body) : <String, dynamic>{};
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'data': decoded is Map ? (decoded['data'] ?? decoded) : decoded,
          'message': decoded is Map
              ? (decoded['message'] ?? 'Label updated')
              : 'Label updated',
        };
      }
      return {
        'success': false,
        'statusCode': response.statusCode,
        'message': _apiErrorMessage(decoded, response.statusCode,
            fallback: 'Failed to update diary label'),
      };
    } catch (e) {
      return {'success': false, 'message': 'Failed to update diary label: $e'};
    }
  }

  Future<Map<String, dynamic>> deleteDiaryLabel(int id) async {
    try {
      final headers = await authGetHeaders();
      final response = await offline.delete(
        Uri.parse('$BASE_URL/api/diary/labels/$id'),
        headers: headers,
      );
      final decoded =
          response.body.isNotEmpty ? jsonDecode(response.body) : <String, dynamic>{};
      if (response.statusCode == 200 || response.statusCode == 204) {
        return {'success': true, 'message': 'Label deleted'};
      }
      return {
        'success': false,
        'statusCode': response.statusCode,
        'message': _apiErrorMessage(decoded, response.statusCode,
            fallback: 'Failed to delete diary label'),
      };
    } catch (e) {
      return {'success': false, 'message': 'Failed to delete diary label: $e'};
    }
  }

  // â”€â”€ Diary list items (reusable checklist catalog) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  static const _listCatalogPrefsKey = 'diary_list_catalog_v1';
  static const _listItemApiPaths = [
    '/api/diary/list-items',
    '/api/diary/list_items',
  ];
  bool _listCatalogLocal = false;

  dynamic _safeJsonDecode(String body) {
    final t = body.trim();
    if (t.isEmpty) return <String, dynamic>{};
    try {
      return jsonDecode(t);
    } catch (_) {
      return t;
    }
  }

  bool _isMissingHttpRoute(int statusCode, dynamic decoded, String body) {
    if (statusCode == 404 || statusCode == 405) return true;
    final text = (decoded is String ? decoded : body).toLowerCase();
    return text.contains('cannot get') ||
        text.contains('cannot post') ||
        text.contains('cannot put') ||
        text.contains('cannot patch') ||
        text.contains('cannot delete');
  }

  Future<http.Response> _diaryListItemHttp({
    required String method,
    int? id,
    String? body,
  }) async {
    final headers =
        body == null ? await authGetHeaders() : await authJsonHeaders();
    http.Response? last;
    for (final base in _listItemApiPaths) {
      final uri = Uri.parse(
        id == null ? '$BASE_URL$base' : '$BASE_URL$base/$id',
      );
      final response = switch (method) {
        'POST' => await offline.post(uri, headers: headers, body: body),
        'PUT' => await offline.put(uri, headers: headers, body: body),
        'DELETE' => await offline.delete(uri, headers: headers),
        _ => await offline.get(uri, headers: headers),
      };
      last = response;
      final decoded = _safeJsonDecode(response.body);
      if (!_isMissingHttpRoute(response.statusCode, decoded, response.body)) {
        return response;
      }
    }
    return last!;
  }

  Future<List<Map<String, dynamic>>> _loadLocalListCatalog() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_listCatalogPrefsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveLocalListCatalog(List<Map<String, dynamic>> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_listCatalogPrefsKey, jsonEncode(items));
  }

  Map<String, dynamic> _localCatalogOk(List<Map<String, dynamic>> items,
      {String message = 'List items saved'}) {
    _listCatalogLocal = true;
    return {'success': true, 'data': items, 'message': message};
  }

  Future<Map<String, dynamic>> fetchDiaryListItems() async {
    if (_listCatalogLocal) {
      return _localCatalogOk(await _loadLocalListCatalog());
    }
    try {
      final response = await _diaryListItemHttp(method: 'GET');
      final decoded = _safeJsonDecode(response.body);
      if (response.statusCode == 200 && decoded is! String) {
        _listCatalogLocal = false;
        return {
          'success': true,
          'data': _mapListFromBody(response.body),
        };
      }
      if (_isMissingHttpRoute(response.statusCode, decoded, response.body)) {
        return _localCatalogOk(await _loadLocalListCatalog());
      }
      return {
        'success': false,
        'statusCode': response.statusCode,
        'message': _apiErrorMessage(decoded, response.statusCode,
            fallback: 'Failed to load list items'),
        'data': <Map<String, dynamic>>[],
      };
    } catch (e) {
      return _localCatalogOk(await _loadLocalListCatalog());
    }
  }

  Future<Map<String, dynamic>> createDiaryListItem({
    required String name,
    String icon = 'check',
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return {'success': false, 'message': 'name is required'};
    }
    Future<Map<String, dynamic>> saveLocal() async {
      final items = await _loadLocalListCatalog();
      final row = <String, dynamic>{
        'id': -DateTime.now().millisecondsSinceEpoch,
        'name': trimmed,
        'icon': icon,
      };
      items.add(row);
      await _saveLocalListCatalog(items);
      return {
        ..._localCatalogOk(items, message: 'List item created'),
        'data': row,
      };
    }

    if (_listCatalogLocal) return saveLocal();
    try {
      final response = await _diaryListItemHttp(
        method: 'POST',
        body: jsonEncode({'name': trimmed, 'icon': icon}),
      );
      final decoded = _safeJsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        _listCatalogLocal = false;
        return {
          'success': true,
          'data': decoded is Map ? (decoded['data'] ?? decoded) : decoded,
          'message': decoded is Map
              ? (decoded['message'] ?? 'List item created')
              : 'List item created',
        };
      }
      if (_isMissingHttpRoute(response.statusCode, decoded, response.body)) {
        return saveLocal();
      }
      return {
        'success': false,
        'statusCode': response.statusCode,
        'message': _apiErrorMessage(decoded, response.statusCode,
            fallback: 'Failed to create list item'),
      };
    } catch (e) {
      return saveLocal();
    }
  }

  Future<Map<String, dynamic>> updateDiaryListItem(
    int id, {
    required String name,
    String? icon,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return {'success': false, 'message': 'name is required'};
    }
    Future<Map<String, dynamic>> saveLocal() async {
      final items = await _loadLocalListCatalog();
      final idx = items.indexWhere((e) => int.tryParse('${e['id']}') == id);
      if (idx < 0) {
        return {'success': false, 'message': 'List item not found'};
      }
      items[idx] = {
        ...items[idx],
        'name': trimmed,
        if (icon != null && icon.isNotEmpty) 'icon': icon,
      };
      await _saveLocalListCatalog(items);
      return {
        ..._localCatalogOk(items, message: 'List item updated'),
        'data': items[idx],
      };
    }

    if (_listCatalogLocal || id < 0) return saveLocal();
    try {
      final response = await _diaryListItemHttp(
        method: 'PUT',
        id: id,
        body: jsonEncode({
          'name': trimmed,
          if (icon != null && icon.isNotEmpty) 'icon': icon,
        }),
      );
      final decoded = _safeJsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'data': decoded is Map ? (decoded['data'] ?? decoded) : decoded,
          'message': decoded is Map
              ? (decoded['message'] ?? 'List item updated')
              : 'List item updated',
        };
      }
      if (_isMissingHttpRoute(response.statusCode, decoded, response.body)) {
        return saveLocal();
      }
      return {
        'success': false,
        'statusCode': response.statusCode,
        'message': _apiErrorMessage(decoded, response.statusCode,
            fallback: 'Failed to update list item'),
      };
    } catch (e) {
      return saveLocal();
    }
  }

  Future<Map<String, dynamic>> deleteDiaryListItem(int id) async {
    Future<Map<String, dynamic>> saveLocal() async {
      final items = await _loadLocalListCatalog();
      items.removeWhere((e) => int.tryParse('${e['id']}') == id);
      await _saveLocalListCatalog(items);
      return _localCatalogOk(items, message: 'List item deleted');
    }

    if (_listCatalogLocal || id < 0) return saveLocal();
    try {
      final response = await _diaryListItemHttp(method: 'DELETE', id: id);
      final decoded = _safeJsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 204) {
        return {'success': true, 'message': 'List item deleted'};
      }
      if (_isMissingHttpRoute(response.statusCode, decoded, response.body)) {
        return saveLocal();
      }
      return {
        'success': false,
        'statusCode': response.statusCode,
        'message': _apiErrorMessage(decoded, response.statusCode,
            fallback: 'Failed to delete list item'),
      };
    } catch (e) {
      return saveLocal();
    }
  }

  // â”€â”€ Diary entries â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<Map<String, dynamic>> fetchDiaryEntries({
    String? from,
    String? to,
    String? q,
    String? kind,
    int? labelId,
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final headers = await authGetHeaders();
      final uri = Uri.parse('$BASE_URL/api/diary/entries').replace(
        queryParameters: {
          'page': page.toString(),
          'limit': limit.toString(),
          if (from != null && from.isNotEmpty) 'from': from,
          if (to != null && to.isNotEmpty) 'to': to,
          if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
          if (kind != null && kind.isNotEmpty) 'kind': kind,
          if (labelId != null) 'label_id': labelId.toString(),
        },
      );
      final response = await offline.get(uri, headers: headers);
      final decoded =
          response.body.isNotEmpty ? jsonDecode(response.body) : <String, dynamic>{};
      if (response.statusCode == 200) {
        if (decoded is Map) {
          return {
            'success': true,
            ...Map<String, dynamic>.from(decoded),
          };
        }
        return {'success': true, 'data': _mapListFromBody(response.body)};
      }
      return {
        'success': false,
        'statusCode': response.statusCode,
        'message': _apiErrorMessage(decoded, response.statusCode,
            fallback: 'Failed to load diary entries'),
        'data': <dynamic>[],
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to load diary entries: $e',
        'data': <dynamic>[],
      };
    }
  }

  Future<Map<String, dynamic>> createDiaryEntry(Map<String, dynamic> data) async {
    try {
      final headers = await authJsonHeaders();
      final response = await offline.post(
        Uri.parse('$BASE_URL/api/diary/entries'),
        headers: headers,
        body: jsonEncode(data),
      );
      final decoded =
          response.body.isNotEmpty ? jsonDecode(response.body) : <String, dynamic>{};
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'data': decoded is Map ? (decoded['data'] ?? decoded) : decoded,
          'message': decoded is Map
              ? (decoded['message'] ?? 'Diary entry created')
              : 'Diary entry created',
        };
      }
      return {
        'success': false,
        'statusCode': response.statusCode,
        'message': _apiErrorMessage(decoded, response.statusCode,
            fallback: 'Failed to create diary entry'),
      };
    } catch (e) {
      return {'success': false, 'message': 'Failed to create diary entry: $e'};
    }
  }

  Future<Map<String, dynamic>> updateDiaryEntry(
    int id,
    Map<String, dynamic> data,
  ) async {
    try {
      final headers = await authJsonHeaders();
      final response = await offline.put(
        Uri.parse('$BASE_URL/api/diary/entries/$id'),
        headers: headers,
        body: jsonEncode(data),
      );
      final decoded =
          response.body.isNotEmpty ? jsonDecode(response.body) : <String, dynamic>{};
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'data': decoded is Map ? (decoded['data'] ?? decoded) : decoded,
          'message': decoded is Map
              ? (decoded['message'] ?? 'Diary entry updated')
              : 'Diary entry updated',
        };
      }
      return {
        'success': false,
        'statusCode': response.statusCode,
        'message': _apiErrorMessage(decoded, response.statusCode,
            fallback: 'Failed to update diary entry'),
      };
    } catch (e) {
      return {'success': false, 'message': 'Failed to update diary entry: $e'};
    }
  }

  Future<Map<String, dynamic>> deleteDiaryEntry(int id) async {
    try {
      final headers = await authGetHeaders();
      final response = await offline.delete(
        Uri.parse('$BASE_URL/api/diary/entries/$id'),
        headers: headers,
      );
      final decoded =
          response.body.isNotEmpty ? jsonDecode(response.body) : <String, dynamic>{};
      if (response.statusCode == 200 || response.statusCode == 204) {
        return {'success': true, 'message': 'Diary entry deleted'};
      }
      return {
        'success': false,
        'statusCode': response.statusCode,
        'message': _apiErrorMessage(decoded, response.statusCode,
            fallback: 'Failed to delete diary entry'),
      };
    } catch (e) {
      return {'success': false, 'message': 'Failed to delete diary entry: $e'};
    }
  }

  // â”€â”€ Future plans â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<List<Map<String, dynamic>>> fetchFuturePlans({
    int? year,
    int? month,
    String? status,
    String? q,
  }) async {
    final headers = await authGetHeaders();
    final uri = Uri.parse('$BASE_URL/api/future_plans').replace(
      queryParameters: {
        if (year != null && year > 0) 'year': year.toString(),
        if (month != null && month > 0) 'month': month.toString(),
        if (status != null && status.isNotEmpty) 'status': status,
        if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
      },
    );
    final response = await offline.get(uri, headers: headers);
    if (response.statusCode != 200) {
      throw Exception('Failed to load future plans (${response.statusCode})');
    }
    return _mapListFromBody(response.body);
  }

  Future<Map<String, dynamic>> fetchFuturePlan(int id) async {
    final headers = await authGetHeaders();
    final response = await offline.get(
      Uri.parse('$BASE_URL/api/future_plans/$id'),
      headers: headers,
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to load plan (${response.statusCode})');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return {};
  }

  Future<Map<String, dynamic>> createFuturePlan(Map<String, dynamic> data) async {
    final headers = await authJsonHeaders();
    final response = await offline.post(
      Uri.parse('$BASE_URL/api/future_plans'),
      headers: headers,
      body: jsonEncode(data),
    );
    final decoded =
        response.body.isNotEmpty ? jsonDecode(response.body) : <String, dynamic>{};
    if (response.statusCode == 200 || response.statusCode == 201) {
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded['data'] ?? decoded);
      }
      return {};
    }
    throw Exception(
      _apiErrorMessage(decoded, response.statusCode,
          fallback: 'Failed to create future plan'),
    );
  }

  Future<Map<String, dynamic>> updateFuturePlan(
    int id,
    Map<String, dynamic> data,
  ) async {
    final headers = await authJsonHeaders();
    final response = await offline.put(
      Uri.parse('$BASE_URL/api/future_plans/$id'),
      headers: headers,
      body: jsonEncode(data),
    );
    final decoded =
        response.body.isNotEmpty ? jsonDecode(response.body) : <String, dynamic>{};
    if (response.statusCode == 200 || response.statusCode == 201) {
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded['data'] ?? decoded);
      }
      return {};
    }
    throw Exception(
      _apiErrorMessage(decoded, response.statusCode,
          fallback: 'Failed to update future plan'),
    );
  }

  Future<void> deleteFuturePlan(int id) async {
    final headers = await authGetHeaders();
    final response = await offline.delete(
      Uri.parse('$BASE_URL/api/future_plans/$id'),
      headers: headers,
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      final decoded =
          response.body.isNotEmpty ? jsonDecode(response.body) : null;
      throw Exception(
        _apiErrorMessage(decoded, response.statusCode,
            fallback: 'Failed to delete future plan'),
      );
    }
  }

  // â”€â”€ Labor works (self receivable / receipt) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<Map<String, dynamic>> createLaborWork(Map<String, dynamic> data) async {
    final headers = await authJsonHeaders();
    final response = await offline.post(
      Uri.parse('$BASE_URL/api/labor_works'),
      headers: headers,
      body: jsonEncode(data),
    );
    final decoded =
        response.body.isNotEmpty ? jsonDecode(response.body) : <String, dynamic>{};
    if (response.statusCode == 200 || response.statusCode == 201) {
      return {
        'success': true,
        'data': decoded is Map ? (decoded['data'] ?? decoded) : decoded,
        'message': decoded is Map
            ? (decoded['message'] ?? 'Work entry created')
            : 'Work entry created',
      };
    }
    return {
      'success': false,
      'message': _apiErrorMessage(decoded, response.statusCode,
          fallback: 'Failed to create work entry'),
      'statusCode': response.statusCode,
    };
  }

  Future<Map<String, dynamic>> createLaborWorksBatch(
    List<Map<String, dynamic>> rows,
  ) async {
    final headers = await authJsonHeaders();
    final response = await offline.post(
      Uri.parse('$BASE_URL/api/labor_works/batch'),
      headers: headers,
      body: jsonEncode(rows),
    );
    final decoded =
        response.body.isNotEmpty ? jsonDecode(response.body) : <String, dynamic>{};
    if (response.statusCode == 200 || response.statusCode == 201) {
      return {
        'success': true,
        'data': decoded is Map ? (decoded['data'] ?? decoded) : decoded,
        'message': decoded is Map
            ? (decoded['message'] ?? 'Work entries created')
            : 'Work entries created',
      };
    }
    return {
      'success': false,
      'message': _apiErrorMessage(decoded, response.statusCode,
          fallback: 'Failed to create work entries'),
      'statusCode': response.statusCode,
    };
  }

  Future<Map<String, dynamic>> fetchLaborWorks({
    String? name,
    String? q,
    String? entryKind,
    String? from,
    String? to,
    int page = 1,
    int limit = 50,
  }) async {
    final headers = await authGetHeaders();
    final uri = Uri.parse('$BASE_URL/api/labor_works').replace(
      queryParameters: {
        'page': page.toString(),
        'limit': limit.toString(),
        if (name != null && name.isNotEmpty) 'name': name,
        if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
        if (entryKind != null && entryKind.isNotEmpty) 'entry_kind': entryKind,
        if (from != null && from.isNotEmpty) 'from': from,
        if (to != null && to.isNotEmpty) 'to': to,
      },
    );
    final response = await offline.get(uri, headers: headers);
    if (response.statusCode != 200) {
      throw Exception('Failed to load labor works (${response.statusCode})');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return {'data': _mapListFromBody(response.body)};
  }

  Future<Map<String, dynamic>> updateLaborWork(
    int id,
    Map<String, dynamic> data,
  ) async {
    final headers = await authJsonHeaders();
    final response = await offline.put(
      Uri.parse('$BASE_URL/api/labor_works/$id'),
      headers: headers,
      body: jsonEncode(data),
    );
    final decoded =
        response.body.isNotEmpty ? jsonDecode(response.body) : <String, dynamic>{};
    if (response.statusCode == 200 || response.statusCode == 201) {
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded['data'] ?? decoded);
      }
      return {};
    }
    throw Exception(
      _apiErrorMessage(decoded, response.statusCode,
          fallback: 'Failed to update work entry'),
    );
  }

  Future<void> deleteLaborWork(int id) async {
    final headers = await authGetHeaders();
    final response = await offline.delete(
      Uri.parse('$BASE_URL/api/labor_works/$id'),
      headers: headers,
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      final decoded =
          response.body.isNotEmpty ? jsonDecode(response.body) : null;
      throw Exception(
        _apiErrorMessage(decoded, response.statusCode,
            fallback: 'Failed to delete work entry'),
      );
    }
  }

  Future<Map<String, dynamic>> fetchLaborWorkReports({
    String? name,
    String? from,
    String? to,
  }) async {
    final headers = await authGetHeaders();
    final uri = Uri.parse('$BASE_URL/api/labor_works/reports').replace(
      queryParameters: {
        if (name != null && name.isNotEmpty) 'name': name,
        if (from != null && from.isNotEmpty) 'from': from,
        if (to != null && to.isNotEmpty) 'to': to,
      },
    );
    final response = await offline.get(uri, headers: headers);
    if (response.statusCode != 200) {
      throw Exception(
          'Failed to load labor work reports (${response.statusCode})');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    throw Exception('Invalid labor work report response');
  }

  // â”€â”€ Labor share confirmations (farmer â†’ labourer reverse entry) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<int> fetchLaborSharePendingCount() async {
    final headers = await authGetHeaders();
    final response = await offline.get(
      Uri.parse('$BASE_URL/api/labor_shares/pending_count'),
      headers: headers,
    );
    if (response.statusCode != 200) return 0;
    final decoded = jsonDecode(response.body);
    if (decoded is Map) {
      final v = decoded['pending'];
      if (v is int) return v;
      return int.tryParse('$v') ?? 0;
    }
    return 0;
  }

  Future<List<Map<String, dynamic>>> fetchLaborShares({
    String status = 'pending',
  }) async {
    final headers = await authGetHeaders();
    final uri = Uri.parse('$BASE_URL/api/labor_shares').replace(
      queryParameters: {
        if (status.isNotEmpty) 'status': status,
      },
    );
    final response = await offline.get(uri, headers: headers);
    if (response.statusCode != 200) {
      throw Exception('Failed to load confirmations (${response.statusCode})');
    }
    return _mapListFromBody(response.body);
  }

  Future<Map<String, dynamic>> acceptLaborShare(int id) async {
    final headers = await authJsonHeaders();
    final response = await offline.post(
      Uri.parse('$BASE_URL/api/labor_shares/$id/accept'),
      headers: headers,
    );
    final decoded =
        response.body.isNotEmpty ? jsonDecode(response.body) : <String, dynamic>{};
    if (response.statusCode == 200 || response.statusCode == 201) {
      return {
        'success': true,
        'data': decoded is Map ? decoded : <String, dynamic>{},
        'message': decoded is Map
            ? (decoded['message'] ?? 'Entry confirmed')
            : 'Entry confirmed',
      };
    }
    return {
      'success': false,
      'message': _apiErrorMessage(decoded, response.statusCode,
          fallback: 'Failed to confirm entry'),
    };
  }

  Future<Map<String, dynamic>> rejectLaborShare(int id) async {
    final headers = await authJsonHeaders();
    final response = await offline.post(
      Uri.parse('$BASE_URL/api/labor_shares/$id/reject'),
      headers: headers,
    );
    final decoded =
        response.body.isNotEmpty ? jsonDecode(response.body) : <String, dynamic>{};
    if (response.statusCode == 200 || response.statusCode == 201) {
      return {
        'success': true,
        'data': decoded is Map ? decoded : <String, dynamic>{},
        'message': decoded is Map
            ? (decoded['message'] ?? 'Entry rejected')
            : 'Entry rejected',
      };
    }
    return {
      'success': false,
      'message': _apiErrorMessage(decoded, response.statusCode,
          fallback: 'Failed to reject entry'),
    };
  }


  List<Map<String, dynamic>> _mapListFromBody(String body) {
    final decoded = jsonDecode(body);
    if (decoded is Map && decoded['data'] is List) {
      return (decoded['data'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (decoded is List) {
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return [];
  }

  /// POST /api/feedbacks
  Future<Map<String, dynamic>> createFeedback({
    required String subject,
    required String message,
    String menu = '',
  }) async {
    final headers = await authJsonHeaders();
    final response = await offline.post(
      Uri.parse('$BASE_URL/api/feedbacks'),
      headers: headers,
      body: jsonEncode({
        'subject': subject,
        'message': message,
        'menu': menu,
      }),
    );
    final decoded =
        response.body.isNotEmpty ? jsonDecode(response.body) : <String, dynamic>{};
    if (response.statusCode == 200 || response.statusCode == 201) {
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return {'success': true};
    }
    throw Exception(
      _apiErrorMessage(decoded, response.statusCode, fallback: 'Failed to submit feedback'),
    );
  }

  /// GET /api/feedbacks â€” current user's feedbacks.
  Future<List<Map<String, dynamic>>> fetchMyFeedbacks({
    int page = 1,
    int limit = 50,
  }) async {
    final headers = await authGetHeaders();
    final uri = Uri.parse('$BASE_URL/api/feedbacks').replace(
      queryParameters: {
        'page': page.toString(),
        'limit': limit.toString(),
      },
    );
    final response = await offline.get(uri, headers: headers);
    if (response.statusCode != 200) {
      throw Exception('Failed to load feedback (${response.statusCode})');
    }
    return _feedbackListFromBody(response.body);
  }

  /// GET /api/feedbacks/all
  Future<List<Map<String, dynamic>>> fetchAllFeedbacks({
    int page = 1,
    int limit = 50,
  }) async {
    final headers = await authGetHeaders();
    final uri = Uri.parse('$BASE_URL/api/feedbacks/all').replace(
      queryParameters: {
        'page': page.toString(),
        'limit': limit.toString(),
      },
    );
    final response = await offline.get(uri, headers: headers);
    if (response.statusCode != 200) {
      throw Exception('Failed to load feedback (${response.statusCode})');
    }
    return _feedbackListFromBody(response.body);
  }

  /// GET /api/app_contents
  Future<List<Map<String, dynamic>>> fetchAppContents() async {
    final headers = await authGetHeaders();
    final response = await offline.get(
      Uri.parse('$BASE_URL/api/app_contents'),
      headers: headers,
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to load app contents (${response.statusCode})');
    }
    final decoded = jsonDecode(response.body);
    final list = decoded is Map
        ? (decoded['data'] as List? ?? [])
        : (decoded as List? ?? []);
    return list
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  List<Map<String, dynamic>> _feedbackListFromBody(String body) {
    final decoded = jsonDecode(body);
    if (decoded is Map && decoded['data'] is List) {
      return (decoded['data'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (decoded is List) {
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> fetchOrganizations() async {
    final headers = await authGetHeaders();
    final response = await offline.get(
      Uri.parse('$BASE_URL/api/organizations'),
      headers: headers,
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to load organizations (${response.statusCode})');
    }
    final decoded = jsonDecode(response.body);
    final list = decoded is Map ? (decoded['data'] as List? ?? []) : [];
    return list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<Map<String, dynamic>> createOrganization(String name) async {
    final headers = await authJsonHeaders();
    final response = await offline.post(
      Uri.parse('$BASE_URL/api/organizations'),
      headers: headers,
      body: jsonEncode({'name': name}),
    );
    final decoded = response.body.isNotEmpty ? jsonDecode(response.body) : {};
    if (response.statusCode == 200 || response.statusCode == 201) {
      return Map<String, dynamic>.from(decoded is Map ? (decoded['data'] ?? decoded) : {});
    }
    throw Exception(_apiErrorMessage(decoded, response.statusCode, fallback: 'Failed to create organization'));
  }

  Future<Map<String, dynamic>> updateOrganization(int id, String name) async {
    final headers = await authJsonHeaders();
    final response = await offline.put(
      Uri.parse('$BASE_URL/api/organizations/$id'),
      headers: headers,
      body: jsonEncode({'name': name}),
    );
    final decoded = response.body.isNotEmpty ? jsonDecode(response.body) : {};
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(decoded is Map ? (decoded['data'] ?? decoded) : {});
    }
    throw Exception(_apiErrorMessage(decoded, response.statusCode, fallback: 'Failed to update organization'));
  }

  Future<bool> deleteOrganization(int id) async {
    final headers = await authGetHeaders();
    final response = await offline.delete(
      Uri.parse('$BASE_URL/api/organizations/$id'),
      headers: headers,
    );
    if (response.statusCode == 200 || response.statusCode == 204) return true;
    final decoded = response.body.isNotEmpty ? jsonDecode(response.body) : {};
    throw Exception(_apiErrorMessage(decoded, response.statusCode, fallback: 'Failed to delete organization'));
  }

  Future<List<Map<String, dynamic>>> fetchOrgLedgers() async {
    final headers = await authGetHeaders();
    final response = await offline.get(
      Uri.parse('$BASE_URL/api/org_ledgers'),
      headers: headers,
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to load ledgers (${response.statusCode})');
    }
    final decoded = jsonDecode(response.body);
    final list = decoded is Map ? (decoded['data'] as List? ?? []) : [];
    return list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<Map<String, dynamic>> createOrgLedger(String name) async {
    final headers = await authJsonHeaders();
    final response = await offline.post(
      Uri.parse('$BASE_URL/api/org_ledgers'),
      headers: headers,
      body: jsonEncode({'name': name}),
    );
    final decoded = response.body.isNotEmpty ? jsonDecode(response.body) : {};
    if (response.statusCode == 200 || response.statusCode == 201) {
      return Map<String, dynamic>.from(decoded is Map ? (decoded['data'] ?? decoded) : {});
    }
    throw Exception(_apiErrorMessage(decoded, response.statusCode, fallback: 'Failed to create ledger'));
  }

  Future<Map<String, dynamic>> updateOrgLedger(int id, String name) async {
    final headers = await authJsonHeaders();
    final response = await offline.put(
      Uri.parse('$BASE_URL/api/org_ledgers/$id'),
      headers: headers,
      body: jsonEncode({'name': name}),
    );
    final decoded = response.body.isNotEmpty ? jsonDecode(response.body) : {};
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(decoded is Map ? (decoded['data'] ?? decoded) : {});
    }
    throw Exception(_apiErrorMessage(decoded, response.statusCode, fallback: 'Failed to update ledger'));
  }

  Future<bool> deleteOrgLedger(int id) async {
    final headers = await authGetHeaders();
    final response = await offline.delete(
      Uri.parse('$BASE_URL/api/org_ledgers/$id'),
      headers: headers,
    );
    if (response.statusCode == 200 || response.statusCode == 204) return true;
    final decoded = response.body.isNotEmpty ? jsonDecode(response.body) : {};
    throw Exception(_apiErrorMessage(decoded, response.statusCode, fallback: 'Failed to delete ledger'));
  }

  Future<Map<String, dynamic>> fetchOrgSummary({int? organizationId}) async {
    final headers = await authGetHeaders();
    final uri = Uri.parse('$BASE_URL/api/org_transactions/summary').replace(
      queryParameters: {
        if (organizationId != null) 'organization_id': organizationId.toString(),
      },
    );
    final response = await offline.get(uri, headers: headers);
    if (response.statusCode != 200) {
      throw Exception('Failed to load summary (${response.statusCode})');
    }
    final decoded = jsonDecode(response.body);
    return decoded is Map ? Map<String, dynamic>.from(decoded) : {};
  }

  Future<Map<String, dynamic>> fetchOrgReports({
    int? organizationId,
    int? ledgerId,
    String? from,
    String? to,
  }) async {
    final headers = await authGetHeaders();
    final uri = Uri.parse('$BASE_URL/api/org_transactions/reports').replace(
      queryParameters: {
        if (organizationId != null) 'organization_id': organizationId.toString(),
        if (ledgerId != null) 'ledger_id': ledgerId.toString(),
        if (from != null && from.isNotEmpty) 'from': from,
        if (to != null && to.isNotEmpty) 'to': to,
      },
    );
    final response = await offline.get(uri, headers: headers);
    if (response.statusCode != 200) {
      throw Exception('Failed to load reports (${response.statusCode})');
    }
    final decoded = jsonDecode(response.body);
    return decoded is Map ? Map<String, dynamic>.from(decoded) : {};
  }

  Future<Map<String, dynamic>> fetchOrgTransactions({
    int page = 1,
    int limit = 20,
    int? organizationId,
    int? ledgerId,
    String? type,
    String? from,
    String? to,
  }) async {
    final headers = await authGetHeaders();
    final uri = Uri.parse('$BASE_URL/api/org_transactions').replace(
      queryParameters: {
        'page': page.toString(),
        'limit': limit.toString(),
        if (organizationId != null) 'organization_id': organizationId.toString(),
        if (ledgerId != null) 'ledger_id': ledgerId.toString(),
        if (type != null && type.isNotEmpty) 'type': type,
        if (from != null && from.isNotEmpty) 'from': from,
        if (to != null && to.isNotEmpty) 'to': to,
      },
    );
    final response = await offline.get(uri, headers: headers);
    if (response.statusCode != 200) {
      throw Exception('Failed to load transactions (${response.statusCode})');
    }
    final decoded = jsonDecode(response.body);
    return decoded is Map ? Map<String, dynamic>.from(decoded) : {'data': [], 'total': 0};
  }

  Future<Map<String, dynamic>> createOrgTransaction(Map<String, dynamic> body) async {
    final headers = await authJsonHeaders();
    final response = await offline.post(
      Uri.parse('$BASE_URL/api/org_transactions'),
      headers: headers,
      body: jsonEncode(body),
    );
    final decoded = response.body.isNotEmpty ? jsonDecode(response.body) : {};
    if (response.statusCode == 200 || response.statusCode == 201) {
      return decoded is Map ? Map<String, dynamic>.from(decoded) : {};
    }
    throw Exception(_apiErrorMessage(decoded, response.statusCode, fallback: 'Failed to create transaction'));
  }

  Future<bool> deleteOrgTransaction(int id) async {
    final headers = await authGetHeaders();
    final response = await offline.delete(
      Uri.parse('$BASE_URL/api/org_transactions/$id'),
      headers: headers,
    );
    if (response.statusCode == 200 || response.statusCode == 204) return true;
    final decoded = response.body.isNotEmpty ? jsonDecode(response.body) : {};
    throw Exception(_apiErrorMessage(decoded, response.statusCode, fallback: 'Failed to delete transaction'));
  }

  // --- Land RTC ---

  Future<List<Map<String, dynamic>>> fetchMyLandRtcs({
    int page = 1,
    int limit = 100,
  }) async {
    final headers = await authGetHeaders();
    final uri = Uri.parse('$BASE_URL/api/land_rtcs').replace(
      queryParameters: {
        'page': page.toString(),
        'limit': limit.toString(),
      },
    );
    final response = await offline.get(uri, headers: headers);
    if (response.statusCode != 200) {
      throw Exception('Failed to load RTC list (${response.statusCode})');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map && decoded['data'] is List) {
      return (decoded['data'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (decoded is List) {
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> createLandRtc(Map<String, dynamic> body) async {
    final headers = await authJsonHeaders();
    final response = await offline.post(
      Uri.parse('$BASE_URL/api/land_rtcs'),
      headers: headers,
      body: jsonEncode(body),
    );
    final decoded = response.body.isNotEmpty ? jsonDecode(response.body) : {};
    if (response.statusCode == 200 || response.statusCode == 201) {
      return decoded is Map ? Map<String, dynamic>.from(decoded) : {};
    }
    throw Exception(
      _apiErrorMessage(decoded, response.statusCode, fallback: 'Failed to save RTC'),
    );
  }

  Future<Map<String, dynamic>> updateLandRtc(int id, Map<String, dynamic> body) async {
    final headers = await authJsonHeaders();
    final response = await offline.put(
      Uri.parse('$BASE_URL/api/land_rtcs/$id'),
      headers: headers,
      body: jsonEncode(body),
    );
    final decoded = response.body.isNotEmpty ? jsonDecode(response.body) : {};
    if (response.statusCode == 200 || response.statusCode == 201) {
      return decoded is Map ? Map<String, dynamic>.from(decoded) : {};
    }
    throw Exception(
      _apiErrorMessage(decoded, response.statusCode, fallback: 'Failed to update RTC'),
    );
  }

  Future<bool> deleteLandRtc(int id) async {
    final headers = await authGetHeaders();
    final response = await offline.delete(
      Uri.parse('$BASE_URL/api/land_rtcs/$id'),
      headers: headers,
    );
    if (response.statusCode == 200 || response.statusCode == 204) return true;
    final decoded = response.body.isNotEmpty ? jsonDecode(response.body) : {};
    throw Exception(
      _apiErrorMessage(decoded, response.statusCode, fallback: 'Failed to delete RTC'),
    );
  }

  /// Multipart upload field "file" â†’ { url: "/uploads/land-rtcs/..." }
  Future<String> uploadLandRtcDocument({
    required String filePath,
    String? filename,
  }) async {
    final token = await getAuthToken();
    final uri = Uri.parse('$BASE_URL/api/land_rtcs/upload');
    final req = http.MultipartRequest('POST', uri);
    mergeTenantHeaders(req.headers);
    if (token != null && token.isNotEmpty) {
      req.headers['Authorization'] = 'Bearer $token';
    }
    req.files.add(
      await http.MultipartFile.fromPath(
        'file',
        filePath,
        filename: filename ?? filePath.split(Platform.pathSeparator).last,
      ),
    );
    final streamed = await req.send();
    final response = await http.Response.fromStream(streamed);
    final decoded = response.body.isNotEmpty ? jsonDecode(response.body) : {};
    if (response.statusCode == 200 || response.statusCode == 201) {
      if (decoded is Map && decoded['url'] != null) {
        return decoded['url'].toString();
      }
    }
    throw Exception(
      _apiErrorMessage(decoded, response.statusCode, fallback: 'Failed to upload document'),
    );
  }

  // â”€â”€ Dairy (milk ledger) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<Map<String, dynamic>> fetchDairySummary({
    String? from,
    String? to,
    String? kind,
    String? q,
  }) async {
    final headers = await authGetHeaders();
    final uri = Uri.parse('$BASE_URL/api/dairy/summary').replace(
      queryParameters: {
        if (from != null && from.isNotEmpty) 'from': from,
        if (to != null && to.isNotEmpty) 'to': to,
        if (kind != null && kind.isNotEmpty) 'kind': kind,
        if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
      },
    );
    final response = await offline.get(uri, headers: headers);
    if (response.statusCode != 200) {
      throw Exception('Failed to load dairy summary (${response.statusCode})');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return {};
  }

  Future<List<Map<String, dynamic>>> fetchDairyEntries({
    String? from,
    String? to,
    String? kind,
    String? q,
  }) async {
    final headers = await authGetHeaders();
    final uri = Uri.parse('$BASE_URL/api/dairy/entries').replace(
      queryParameters: {
        if (from != null && from.isNotEmpty) 'from': from,
        if (to != null && to.isNotEmpty) 'to': to,
        if (kind != null && kind.isNotEmpty) 'kind': kind,
        if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
      },
    );
    final response = await offline.get(uri, headers: headers);
    if (response.statusCode != 200) {
      throw Exception('Failed to load dairy entries (${response.statusCode})');
    }
    return _mapListFromBody(response.body);
  }

  Future<Map<String, dynamic>> createDairyEntry(Map<String, dynamic> data) async {
    return _postDairyJson('$BASE_URL/api/dairy/entries', data, 'Failed to save dairy entry');
  }

  Future<Map<String, dynamic>> updateDairyEntry(
    int id,
    Map<String, dynamic> data,
  ) async {
    return _putDairyJson('$BASE_URL/api/dairy/entries/$id', data, 'Failed to update dairy entry');
  }

  Future<void> deleteDairyEntry(int id) async {
    final headers = await authGetHeaders();
    final response = await offline.delete(
      Uri.parse('$BASE_URL/api/dairy/entries/$id'),
      headers: headers,
    );
    if (response.statusCode == 200 || response.statusCode == 204) return;
    final decoded = response.body.isNotEmpty ? jsonDecode(response.body) : {};
    throw Exception(
      _apiErrorMessage(decoded, response.statusCode, fallback: 'Failed to delete dairy entry'),
    );
  }

  Future<Map<String, dynamic>> fetchOwnerDairySummary({
    String? from,
    String? to,
    int? customerId,
    String? q,
  }) async {
    final headers = await authGetHeaders();
    final uri = Uri.parse('$BASE_URL/api/dairy/owner/summary').replace(
      queryParameters: {
        if (from != null && from.isNotEmpty) 'from': from,
        if (to != null && to.isNotEmpty) 'to': to,
        if (customerId != null && customerId > 0) 'customer_id': customerId.toString(),
        if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
      },
    );
    final response = await offline.get(uri, headers: headers);
    if (response.statusCode != 200) {
      throw Exception('Failed to load dairy summary (${response.statusCode})');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return {};
  }

  Future<List<Map<String, dynamic>>> fetchDairyCustomers({String? q}) async {
    final headers = await authGetHeaders();
    final uri = Uri.parse('$BASE_URL/api/dairy/owner/customers').replace(
      queryParameters: {
        if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
      },
    );
    final response = await offline.get(uri, headers: headers);
    if (response.statusCode != 200) {
      throw Exception('Failed to load customers (${response.statusCode})');
    }
    return _mapListFromBody(response.body);
  }

  Future<Map<String, dynamic>> createDairyCustomer(Map<String, dynamic> data) async {
    return _postDairyJson(
      '$BASE_URL/api/dairy/owner/customers',
      data,
      'Failed to save customer',
    );
  }

  Future<Map<String, dynamic>> updateDairyCustomer(
    int id,
    Map<String, dynamic> data,
  ) async {
    return _putDairyJson(
      '$BASE_URL/api/dairy/owner/customers/$id',
      data,
      'Failed to update customer',
    );
  }

  Future<void> deleteDairyCustomer(int id) async {
    final headers = await authGetHeaders();
    final response = await offline.delete(
      Uri.parse('$BASE_URL/api/dairy/owner/customers/$id'),
      headers: headers,
    );
    if (response.statusCode == 200 || response.statusCode == 204) return;
    final decoded = response.body.isNotEmpty ? jsonDecode(response.body) : {};
    throw Exception(
      _apiErrorMessage(decoded, response.statusCode, fallback: 'Failed to delete customer'),
    );
  }

  Future<List<Map<String, dynamic>>> fetchOwnerDairyEntries({
    String? from,
    String? to,
    String? kind,
    int? customerId,
    String? q,
  }) async {
    final headers = await authGetHeaders();
    final uri = Uri.parse('$BASE_URL/api/dairy/owner/entries').replace(
      queryParameters: {
        if (from != null && from.isNotEmpty) 'from': from,
        if (to != null && to.isNotEmpty) 'to': to,
        if (kind != null && kind.isNotEmpty) 'kind': kind,
        if (customerId != null && customerId > 0) 'customer_id': customerId.toString(),
        if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
      },
    );
    final response = await offline.get(uri, headers: headers);
    if (response.statusCode != 200) {
      throw Exception('Failed to load dairy entries (${response.statusCode})');
    }
    return _mapListFromBody(response.body);
  }

  Future<Map<String, dynamic>> createOwnerDairyEntry(Map<String, dynamic> data) async {
    return _postDairyJson(
      '$BASE_URL/api/dairy/owner/entries',
      data,
      'Failed to save milk entry',
    );
  }

  Future<Map<String, dynamic>> updateOwnerDairyEntry(
    int id,
    Map<String, dynamic> data,
  ) async {
    return _putDairyJson(
      '$BASE_URL/api/dairy/owner/entries/$id',
      data,
      'Failed to update milk entry',
    );
  }

  Future<void> deleteOwnerDairyEntry(int id) async {
    final headers = await authGetHeaders();
    final response = await offline.delete(
      Uri.parse('$BASE_URL/api/dairy/owner/entries/$id'),
      headers: headers,
    );
    if (response.statusCode == 200 || response.statusCode == 204) return;
    final decoded = response.body.isNotEmpty ? jsonDecode(response.body) : {};
    throw Exception(
      _apiErrorMessage(decoded, response.statusCode, fallback: 'Failed to delete milk entry'),
    );
  }

  Future<Map<String, dynamic>> _postDairyJson(
    String url,
    Map<String, dynamic> data,
    String fallback,
  ) async {
    final headers = await authJsonHeaders();
    final response = await offline.post(
      Uri.parse(url),
      headers: headers,
      body: jsonEncode(data),
    );
    final decoded =
        response.body.isNotEmpty ? jsonDecode(response.body) : <String, dynamic>{};
    if (response.statusCode == 200 || response.statusCode == 201) {
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return {'success': true};
    }
    throw Exception(_apiErrorMessage(decoded, response.statusCode, fallback: fallback));
  }

  Future<Map<String, dynamic>> _putDairyJson(
    String url,
    Map<String, dynamic> data,
    String fallback,
  ) async {
    final headers = await authJsonHeaders();
    final response = await offline.put(
      Uri.parse(url),
      headers: headers,
      body: jsonEncode(data),
    );
    final decoded =
        response.body.isNotEmpty ? jsonDecode(response.body) : <String, dynamic>{};
    if (response.statusCode == 200 || response.statusCode == 201) {
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return {'success': true};
    }
    throw Exception(_apiErrorMessage(decoded, response.statusCode, fallback: fallback));
  }

  // â”€â”€ Personal documents (folders + multi-image papers) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<Map<String, dynamic>> browseDocuments({int? folderId, String? q}) async {
    final headers = await authGetHeaders();
    final uri = Uri.parse('$BASE_URL/api/documents/browse').replace(
      queryParameters: {
        if (folderId != null && folderId > 0) 'folder_id': '$folderId',
        if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
      },
    );
    final response = await offline.get(uri, headers: headers);
    if (response.statusCode != 200) {
      throw Exception(
        _apiErrorMessage(
          response.body.isNotEmpty ? jsonDecode(response.body) : {},
          response.statusCode,
          fallback: 'Failed to load documents',
        ),
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return {'folders': [], 'documents': []};
  }

  Future<Map<String, dynamic>> createDocumentFolder(String name) async {
    return _postDairyJson(
      '$BASE_URL/api/documents/folders',
      {'name': name},
      'Failed to create folder',
    );
  }

  Future<Map<String, dynamic>> updateDocumentFolder(int id, String name) async {
    return _putDairyJson(
      '$BASE_URL/api/documents/folders/$id',
      {'name': name},
      'Failed to rename folder',
    );
  }

  Future<void> deleteDocumentFolder(int id) async {
    final headers = await authGetHeaders();
    final response = await offline.delete(
      Uri.parse('$BASE_URL/api/documents/folders/$id'),
      headers: headers,
    );
    if (response.statusCode == 200 || response.statusCode == 204) return;
    final decoded = response.body.isNotEmpty ? jsonDecode(response.body) : {};
    throw Exception(
      _apiErrorMessage(decoded, response.statusCode, fallback: 'Failed to delete folder'),
    );
  }

  Future<Map<String, dynamic>> getUserDocument(int id) async {
    final headers = await authGetHeaders();
    final response = await offline.get(
      Uri.parse('$BASE_URL/api/documents/$id'),
      headers: headers,
    );
    final decoded = response.body.isNotEmpty ? jsonDecode(response.body) : {};
    if (response.statusCode == 200 && decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    throw Exception(
      _apiErrorMessage(decoded, response.statusCode, fallback: 'Failed to load document'),
    );
  }

  Future<Map<String, dynamic>> createUserDocument(Map<String, dynamic> body) async {
    return _postDairyJson(
      '$BASE_URL/api/documents',
      body,
      'Failed to save document',
    );
  }

  Future<Map<String, dynamic>> updateUserDocument(
    int id,
    Map<String, dynamic> body,
  ) async {
    return _putDairyJson(
      '$BASE_URL/api/documents/$id',
      body,
      'Failed to update document',
    );
  }

  Future<void> deleteUserDocument(int id) async {
    final headers = await authGetHeaders();
    final response = await offline.delete(
      Uri.parse('$BASE_URL/api/documents/$id'),
      headers: headers,
    );
    if (response.statusCode == 200 || response.statusCode == 204) return;
    final decoded = response.body.isNotEmpty ? jsonDecode(response.body) : {};
    throw Exception(
      _apiErrorMessage(decoded, response.statusCode, fallback: 'Failed to delete document'),
    );
  }

  /// Multipart fields "file" (repeatable). Returns uploaded `/uploads/documents/...` paths.
  Future<List<String>> uploadDocumentImages({
    required List<String> filePaths,
    List<String?>? filenames,
  }) async {
    if (filePaths.isEmpty) return [];
    final token = await getAuthToken();
    final all = <String>[];
    const batch = 12;
    for (var i = 0; i < filePaths.length; i += batch) {
      final end = i + batch > filePaths.length ? filePaths.length : i + batch;
      final uri = Uri.parse('$BASE_URL/api/documents/upload');
      final req = http.MultipartRequest('POST', uri);
      mergeTenantHeaders(req.headers);
      if (token != null && token.isNotEmpty) {
        req.headers['Authorization'] = 'Bearer $token';
      }
      for (var j = i; j < end; j++) {
        final path = filePaths[j];
        var name = (filenames != null && j < filenames.length) ? filenames[j] : null;
        name ??= path.split(Platform.pathSeparator).last;
        req.files.add(
          await http.MultipartFile.fromPath('file', path, filename: name),
        );
      }
      final streamed = await req.send();
      final response = await http.Response.fromStream(streamed);
      final decoded = response.body.isNotEmpty ? jsonDecode(response.body) : {};
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception(
          _apiErrorMessage(decoded, response.statusCode, fallback: 'Failed to upload images'),
        );
      }
      if (decoded is Map && decoded['urls'] is List) {
        for (final u in decoded['urls'] as List) {
          final s = u?.toString() ?? '';
          if (s.isNotEmpty) all.add(s);
        }
      } else if (decoded is Map && decoded['url'] != null) {
        all.add(decoded['url'].toString());
      }
    }
    return all;
  }

  // â”€â”€ Event manage (birthdays, renewals) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<List<Map<String, dynamic>>> fetchManagedEvents({String? q}) async {
    final headers = await authGetHeaders();
    final uri = Uri.parse('$BASE_URL/api/events').replace(
      queryParameters: {
        if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
      },
    );
    final response = await offline.get(uri, headers: headers);
    if (response.statusCode != 200) {
      throw Exception(
        _apiErrorMessage(
          response.body.isNotEmpty ? jsonDecode(response.body) : null,
          response.statusCode,
          fallback: 'Failed to load events',
        ),
      );
    }
    return _mapListFromBody(response.body);
  }

  Future<Map<String, dynamic>> createManagedEvent(
    Map<String, dynamic> data,
  ) async {
    final headers = await authJsonHeaders();
    final response = await offline.post(
      Uri.parse('$BASE_URL/api/events'),
      headers: headers,
      body: jsonEncode(data),
    );
    final decoded =
        response.body.isNotEmpty ? jsonDecode(response.body) : <String, dynamic>{};
    if (response.statusCode == 200 || response.statusCode == 201) {
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded['data'] ?? decoded);
      }
      return {};
    }
    throw Exception(
      _apiErrorMessage(decoded, response.statusCode,
          fallback: 'Failed to create event'),
    );
  }

  Future<Map<String, dynamic>> updateManagedEvent(
    int id,
    Map<String, dynamic> data,
  ) async {
    final headers = await authJsonHeaders();
    final response = await offline.put(
      Uri.parse('$BASE_URL/api/events/$id'),
      headers: headers,
      body: jsonEncode(data),
    );
    final decoded =
        response.body.isNotEmpty ? jsonDecode(response.body) : <String, dynamic>{};
    if (response.statusCode == 200 || response.statusCode == 201) {
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded['data'] ?? decoded);
      }
      return {};
    }
    throw Exception(
      _apiErrorMessage(decoded, response.statusCode,
          fallback: 'Failed to update event'),
    );
  }

  Future<void> deleteManagedEvent(int id) async {
    final headers = await authGetHeaders();
    final response = await offline.delete(
      Uri.parse('$BASE_URL/api/events/$id'),
      headers: headers,
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      final decoded =
          response.body.isNotEmpty ? jsonDecode(response.body) : null;
      throw Exception(
        _apiErrorMessage(decoded, response.statusCode,
            fallback: 'Failed to delete event'),
      );
    }
  }
}
