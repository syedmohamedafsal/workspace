/// Centralized REST API endpoints for all REBS modules.
abstract final class ApiEndpoints {
  // HRMS - Attendance
  static const String attendanceBase = '/hrms/attendance';
  static const String attendanceCheckIn = '/hrms/attendance/check-in';
  static const String attendanceCheckOut = '/hrms/attendance/check-out';
  static const String attendanceHistory = '/hrms/attendance/history';

  // HRMS - Leave
  static const String leaveRequests = '/hrms/leaves';
  static const String leaveBalances = '/hrms/leaves/balances';
  static String cancelLeave(String id) => '/hrms/leaves/$id/cancel';

  // CRM (Module placeholder endpoints)
  static const String crmLeads = '/crm/leads';
  static const String crmDeals = '/crm/deals';

  // Accounts (Module placeholder endpoints)
  static const String accountsInvoices = '/accounts/invoices';
  static const String accountsExpenses = '/accounts/expenses';
}
