import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class MasterProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _data = [];
  bool _isLoading = false;
  String? _errorMessage;
  
  List<Map<String, dynamic>> get data => _data;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  
  Future<void> fetchData(String table, {String? orderBy, Map<String, dynamic>? filter}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    try {
      dynamic query = SupabaseService.client.from(table).select();
      
      if (filter != null) {
        filter.forEach((key, value) {
          query = query.eq(key, value);
        });
      }
      
      if (orderBy != null) {
        query = query.order(orderBy);
      }
      
      final response = await query;
      _data = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      _errorMessage = 'Error fetching $table: ${e.toString()}';
      print(_errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<bool> addData(String table, Map<String, dynamic> data) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    try {
      await SupabaseService.client.from(table).insert(data);
      return true;
    } catch (e) {
      _errorMessage = 'Error adding to $table: ${e.toString()}';
      print(_errorMessage);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<bool> updateData(String table, dynamic id, Map<String, dynamic> data) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    try {
      await SupabaseService.client.from(table).update(data).eq('id', id);
      return true;
    } catch (e) {
      _errorMessage = 'Error updating $table: ${e.toString()}';
      print(_errorMessage);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<bool> deleteData(String table, dynamic id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    try {
      await SupabaseService.client.from(table).delete().eq('id', id);
      return true;
    } catch (e) {
      _errorMessage = 'Error deleting from $table: ${e.toString()}';
      print(_errorMessage);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  void clearData() {
    _data = [];
    notifyListeners();
  }
}
