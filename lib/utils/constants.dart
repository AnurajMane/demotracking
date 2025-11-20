class Constants {
  // Supabase Configuration
  static const String supabaseUrl = 'https://gbencpvbrgozxgnjdxph.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdiZW5jcHZicmdvenhnbmpkeHBoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDI4MzY1MjEsImV4cCI6MjA1ODQxMjUyMX0.XgU0XP8iFMWG1AgwrQrn_zLZheLsoXBRGQzqgY2AnIo';
  static const String supabaseServiceRoleKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdiZW5jcHZicmdvenhnbmpkeHBoIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0MjgzNjUyMSwiZXhwIjoyMDU4NDEyNTIxfQ.hvKAkNNiz6rgiWlwYKSqSNA-V_VMhRQDJl1fQ96zQfs';

  // Map Configuration
  static const String mapTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String mapStoreName = 'mapStore';
  static const int maxMapTiles = 2000;
  static const double defaultMapZoom = 15.0;
  static const double mapPadding = 0.01; // approximately 1km

  // Location Settings
  static const double stopProximityThreshold = 100.0; // meters
  static const int locationUpdateInterval = 3; // seconds
  static const double locationAccuracy = 10.0; // meters

  // API Endpoints
  static const String apiBaseUrl = 'https://api.demotracking.com';
  static const String apiVersion = 'v1';

  // Storage Keys
  static const String authTokenKey = 'auth_token';
  static const String userDataKey = 'user_data';
  static const String offlineDataKey = 'offline_data';

  // Timeouts
  static const int connectionTimeout = 30000; // 30 seconds
  static const int receiveTimeout = 30000; // 30 seconds

  // Cache Settings
  static const int maxCacheSize = 100 * 1024 * 1024; // 100 MB
  static const Duration cacheExpiration = Duration(days: 7);

  // Error Messages
  static const String networkError = 'Please check your internet connection';
  static const String authError = 'Authentication failed. Please try again';
  static const String locationError = 'Unable to get your location';
  static const String offlineError = 'You are offline. Some features may be limited';

  // Success Messages
  static const String loginSuccess = 'Successfully logged in';
  static const String logoutSuccess = 'Successfully logged out';
  static const String dataSyncSuccess = 'Data synchronized successfully';

  // Validation Messages
  static const String requiredField = 'This field is required';
  static const String invalidEmail = 'Please enter a valid email address';
  static const String invalidPassword = 'Password must be at least 6 characters';
  static const String passwordMismatch = 'Passwords do not match';
}