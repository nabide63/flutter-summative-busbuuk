// holds search query + results state for Home / Search Results screens
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/bus_model.dart';
import '../services/firestore_service.dart';

typedef BusSearcher = Stream<List<BusModel>> Function({
  required String from,
  required String to,
});

class SearchProvider extends ChangeNotifier {
  // searchBuses is injectable so previews/tests can swap in mock data
  // without needing Firebase.initializeApp() to have run.
  SearchProvider({BusSearcher? searchBuses})
    : _searchBuses = searchBuses ?? FirestoreService().streamBuses;

  final BusSearcher _searchBuses;
  StreamSubscription<List<BusModel>>? _subscription;

  String? _from;
  String? _to;
  DateTime? _travelDate;
  int _passengers = 1;
  bool _isRoundTrip = false;
  List<BusModel> _results = [];
  bool _isLoading = false;
  String? _errorMessage;

  // just keeping the last few searches in memory for the "recent searches" bit on Home
  final List<String> _recentSearches = [];

  String? get from => _from;
  String? get to => _to;
  DateTime? get travelDate => _travelDate;
  int get passengers => _passengers;
  bool get isRoundTrip => _isRoundTrip;
  List<BusModel> get results => _results;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<String> get recentSearches => _recentSearches;

  void search({
    required String from,
    required String to,
    DateTime? travelDate,
    int passengers = 1,
    bool isRoundTrip = false,
  }) {
    _from = from;
    _to = to;
    _travelDate = travelDate;
    _passengers = passengers;
    _isRoundTrip = isRoundTrip;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _addRecentSearch('$from → $to');
    _subscription?.cancel();
    _subscription = _searchBuses(from: from, to: to).listen(
      (results) {
        _results = results;
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
      },
      onError: (Object e) {
        _errorMessage = e.toString();
        _results = [];
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  void _addRecentSearch(String query) {
    _recentSearches.remove(query); // avoid dupes, bump it to the top instead
    _recentSearches.insert(0, query);
    if (_recentSearches.length > 5) {
      _recentSearches.removeLast();
    }
  }

  void clearResults() {
    _subscription?.cancel();
    _subscription = null;
    _results = [];
    _errorMessage = null;
    notifyListeners();
  }

  void clearRecentSearches() {
    _recentSearches.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}