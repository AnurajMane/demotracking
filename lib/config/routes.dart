import 'package:demotracking/screens/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:demotracking/screens/auth/login_screen.dart';
import 'package:demotracking/screens/auth/forgot_password_screen.dart';
import 'package:demotracking/screens/admin/admin_dashboard_screen.dart';
import 'package:demotracking/screens/admin/manage_users_screen.dart';
import 'package:demotracking/screens/admin/manage_buses_screen.dart';
import 'package:demotracking/screens/admin/route_management_screen.dart';
import 'package:demotracking/screens/admin/assign_route_screen.dart';
import 'package:demotracking/screens/admin/track_all_buses_screen.dart';
import 'package:demotracking/screens/admin/reports_screen.dart';
import 'package:demotracking/screens/admin/notifications_screen.dart';
import 'package:demotracking/screens/admin/route_optimization_screen.dart';
import 'package:demotracking/screens/admin/geospatial_data_screen.dart';
import 'package:demotracking/screens/student/student_dashboard_screen.dart';
import 'package:demotracking/screens/student/live_tracking_screen.dart';
import 'package:demotracking/screens/student/attendance_screen.dart';
import 'package:demotracking/screens/student/offline_map_screen.dart';
import 'package:demotracking/screens/driver/driver_dashboard_screen.dart';
import 'package:demotracking/screens/driver/navigation_screen.dart';
import 'package:demotracking/screens/driver/pickup_drop_screen.dart';
import 'package:demotracking/screens/driver/incident_report_screen.dart';
import 'package:demotracking/screens/driver/start_trip_screen.dart';
import 'package:demotracking/screens/driver/offline_mode_screen.dart';
import 'package:demotracking/screens/parent/parent_dashboard_screen.dart';
import 'package:demotracking/screens/parent/child_tracking_screen.dart';
import 'package:demotracking/screens/parent/notifications_screen.dart';
import 'package:demotracking/screens/parent/attendance_screen.dart';
import 'package:demotracking/screens/parent/sos_alert_screen.dart';
import 'package:demotracking/screens/parent/custom_basemap_screen.dart';
import 'package:demotracking/screens/map/real_time_tracking_screen.dart';
import 'package:demotracking/screens/map/geofencing_alerts_screen.dart';
import 'package:demotracking/screens/map/route_editor_screen.dart';
import 'package:demotracking/screens/map/offline_map_download_screen.dart';
import 'package:demotracking/screens/map/geospatial_reports_screen.dart';
import 'package:demotracking/screens/utility/profile_screen.dart';
import 'package:demotracking/screens/utility/help_support_screen.dart';
import 'package:demotracking/screens/admin/settings_screen.dart';

class AppRoutes {
  static const String initial = 'splashscreen';
  static const String login = '/login';
  static const String forgotPassword = '/forgot-password';
  
  // Admin Routes
  static const String adminDashboard = '/admin/dashboard';
  static const String manageUsers = '/admin/manage-users';
  static const String manageBuses = '/admin/manage-buses';
  static const String manageRoutes = '/admin/manage-routes';
  static const String assignRoutes = '/admin/assign-routes';
  static const String assignRoute = '/admin/assign-route';
  static const String trackAllBuses = '/admin/track-buses';
  static const String reports = '/admin/reports';
  static const String notifications = '/admin/notifications';
  static const String routeOptimization = '/admin/route-optimization';
  static const String geospatialData = '/admin/geospatial-data';
  static const String setttings = '/admin/settings';
  
  // Student Routes
  static const String studentDashboard = '/student/dashboard';
  static const String liveTracking = '/student/live-tracking';
  static const String attendance = '/student/attendance';
  static const String sosAlert = '/student/sos-alert';
  static const String offlineMap = '/student/offline-map';
  
  // Driver Routes
  static const String driverDashboard = '/driver/dashboard';
  static const String navigation = '/driver/navigation';
  static const String pickupDrop = '/driver/pickup-drop';
  static const String incidentReport = '/driver/incident-report';
  static const String startTrip = '/driver/start-trip';
  static const String offlineMode = '/driver/offline-mode';
  
  // Parent Routes
  static const String parentDashboard = '/parent/dashboard';
  static const String childTracking = '/parent/child-tracking';
  static const String parentNotifications = '/parent/notifications';
  static const String parentAttendance = '/parent/attendance';
  static const String parentSosAlert = '/parent/sos-alert';
  static const String customBasemap = '/parent/custom-basemap';
  
  // Map Routes
  static const String realTimeTracking = '/map/real-time-tracking';
  static const String geofencingAlerts = '/map/geofencing-alerts';
  static const String routeEditor = '/map/route-editor';
  static const String offlineMapDownload = '/map/offline-map-download';
  static const String geospatialReports = '/map/geospatial-reports';
  
  // Utility Routes
  static const String profile = '/profile';
  static const String helpSupport = '/help-support';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case initial:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case forgotPassword:
        return MaterialPageRoute(builder: (_) => const ForgotPasswordScreen());
        
      // Admin Routes
      case adminDashboard:
        return MaterialPageRoute(builder: (_) => const AdminDashboardScreen());
      case manageUsers:
        return MaterialPageRoute(builder: (_) => const ManageUsersScreen());
      case manageBuses:
        return MaterialPageRoute(builder: (_) => const ManageBusesScreen());
      case manageRoutes:
        return MaterialPageRoute(builder: (_) => const RouteManagementScreen());
      case assignRoute:
        return MaterialPageRoute(builder: (_) => const AssignRouteScreen());
      case trackAllBuses:
        return MaterialPageRoute(builder: (_) => const TrackAllBusesScreen());
      case reports:
        return MaterialPageRoute(builder: (_) => const ReportsScreen());
      case notifications:
        return MaterialPageRoute(builder: (_) => const AdminNotificationsScreen());
      case routeOptimization:
        return MaterialPageRoute(builder: (_) => const RouteOptimizationScreen());
      case geospatialData:
        return MaterialPageRoute(builder: (_) => const GeospatialDataScreen());
      case setttings:
        return MaterialPageRoute(builder: (_) => const SettingsScreen());
        

      // Student Routes
      case studentDashboard:
        return MaterialPageRoute(builder: (_) => const StudentDashboardScreen());
      case liveTracking:
        return MaterialPageRoute(builder: (_) => const LiveTrackingScreen());
      case attendance:
        return MaterialPageRoute(builder: (_) => const AttendanceScreen());
      case sosAlert:
        return MaterialPageRoute(builder: (_) => const ParentSOSAlertsScreen());
      //case offlineMap:
        //return MaterialPageRoute(builder: (_) => const OfflineMapScreen());
        
      // Driver Routes
      case driverDashboard:
        return MaterialPageRoute(builder: (_) => const DriverDashboardScreen());
      case navigation:
        return MaterialPageRoute(builder: (_) => const NavigationScreen());
      case pickupDrop:
        return MaterialPageRoute(builder: (_) => const PickupDropScreen());
      case incidentReport:
        return MaterialPageRoute(builder: (_) => const IncidentReportScreen());
      case startTrip:
        return MaterialPageRoute(builder: (_) => const StartTripScreen(busId: '', busName: '', routeName: ''));
      case offlineMode:
        return MaterialPageRoute(builder: (_) => const OfflineModeScreen());
        
      // Parent Routes
      case parentDashboard:
        return MaterialPageRoute(builder: (_) => const ParentDashboardScreen());
      case childTracking:
        return MaterialPageRoute(builder: (_) => const ChildTrackingScreen());
      case parentNotifications:
        return MaterialPageRoute(builder: (_) => const ParentNotificationsScreen());
      case parentAttendance:
        return MaterialPageRoute(builder: (_) => const ParentAttendanceScreen());
      case parentSosAlert:
        return MaterialPageRoute(builder: (_) => const ParentSOSAlertsScreen());
      case customBasemap:
        return MaterialPageRoute(builder: (_) => const CustomBasemapScreen());
        
      // Map Routes
      case realTimeTracking:
        return MaterialPageRoute(builder: (_) => const RealTimeTrackingScreen());
      case geofencingAlerts:
        return MaterialPageRoute(builder: (_) => const GeofencingAlertsScreen());
      case routeEditor:
        return MaterialPageRoute(builder: (_) => const RouteEditorScreen());
      case offlineMapDownload:
        return MaterialPageRoute(builder: (_) => const OfflineMapDownloadScreen());
      case geospatialReports:
        return MaterialPageRoute(builder: (_) => const GeospatialReportsScreen());
        
      // Utility Routes
      case profile:
        return MaterialPageRoute(builder: (_) => const ProfileScreen());
      case helpSupport:
        return MaterialPageRoute(builder: (_) => const HelpSupportScreen());
        
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('No route defined for ${settings.name}'),
            ),
          ),
        );
    }
  }
} 