import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../models/user_model.dart';
import '../services/firebase_service.dart';
import '../services/location_service.dart';

class MapViewModel extends ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  final LocationService _locationService = LocationService();
  StreamSubscription<List<UserModel>>? _providersSubscription;

  LatLng? _currentPosition;
  String? _currentAddress;
  bool _isFetchingLocation = false;
  String? _locationError;

  List<UserModel> _allProviders = [];
  List<UserModel> _filteredProviders = [];
  String _searchQuery = '';
  String? _selectedCategory;

  LatLng? get currentPosition => _currentPosition;
  String? get currentAddress => _currentAddress;
  bool get isFetchingLocation => _isFetchingLocation;
  String? get locationError => _locationError;
  List<UserModel> get nearbyProviders => _filteredProviders;
  List<UserModel> get allNearbyProviders =>
      _allProviders; // All providers for 'See All'

  MapViewModel() {
    fetchLocation();
    _listenToProviders();
  }

  Future<void> fetchLocation({bool force = false}) async {
    if (_currentPosition != null && !force) return;

    _isFetchingLocation = true;
    _locationError = null;
    notifyListeners();

    try {
      final position = await _locationService.getCurrentLocation();
      if (position != null) {
        _currentPosition = LatLng(position.latitude, position.longitude);

        // Fetch address
        try {
          List<Placemark> placemarks = await placemarkFromCoordinates(
            position.latitude,
            position.longitude,
          );
          if (placemarks.isNotEmpty) {
            final place = placemarks.first;
            _currentAddress =
                "${place.subLocality ?? ''}, ${place.locality ?? ''}";
            if (_currentAddress!.startsWith(", ")) {
              _currentAddress = _currentAddress!.substring(2);
            }
          }
        } catch (e) {
          _currentAddress =
              "Lat: ${position.latitude.toStringAsFixed(2)}, Lng: ${position.longitude.toStringAsFixed(2)}";
        }

        // Update the user's location in Firestore if they are logged in
        final uid = _firebaseService.currentUserId;
        if (uid != null) {
          await _firebaseService.updateUserLocation(
            uid,
            GeoPoint(position.latitude, position.longitude),
            _currentAddress,
          );
        }
      } else {
        _locationError = "Unable to fetch location";
      }
    } catch (e) {
      _locationError = "Error: $e";
    } finally {
      _isFetchingLocation = false;
      notifyListeners();
    }
  }

  void _listenToProviders() {
    _providersSubscription = _firebaseService.getNearbyActiveProviders().listen(
      (providers) {
        _allProviders = providers;
        _applyFilters();
      },
      onError: (error) {
        debugPrint('MapViewModel: provider stream error: $error');
        _allProviders = [];
        _applyFilters();
      },
    );
  }

  void setSearchQuery(String query) {
    _searchQuery = query.toLowerCase();
    _applyFilters();
  }

  void setCategory(String? category) {
    _selectedCategory = category;
    _applyFilters();
  }

  void resetFilters() {
    _searchQuery = '';
    _selectedCategory = null;
    _applyFilters();
  }

  void _applyFilters() {
    _filteredProviders = _allProviders.where((provider) {
      final matchesQuery =
          provider.name.toLowerCase().contains(_searchQuery) ||
          (provider.serviceType?.toLowerCase().contains(_searchQuery) ?? false);
      final matchesCategory =
          _selectedCategory == null ||
          provider.serviceType == _selectedCategory;
      return matchesQuery && matchesCategory;
    }).toList();
    notifyListeners();
  }

  Future<void> refreshLocation() async {
    await fetchLocation(force: true);
  }

  Future<void> fetchNearbyProviders() async {
    // This could trigger a refresh or simply ensure we are showing all
    resetFilters();
  }
}
