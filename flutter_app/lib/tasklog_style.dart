import 'package:flutter/material.dart';

/// Mobile-first dark glass design tokens for Ontario TaskLog.
class TaskLogStyle {
  static const ink = Color(0xFFF5F8FF);
  static const navy = Color(0xFF0B1427);
  static const teal = Color(0xFF34D5C0);
  static const canvas = Color(0xFF080F1F);
  static const muted = Color(0xFFA5B4CC);
  static const surface = Color(0xFF14223A);
  static const border = Color(0xFF34445D);

  static BoxDecoration get glass => BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1F3450), Color(0xFF111C32)],
        ),
        border: Border.all(color: const Color(0xFF3B516F), width: 0.8),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
              color: Color(0x32000000), blurRadius: 22, offset: Offset(0, 12)),
        ],
      );

  static ThemeData get light => dark;
  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: teal,
      brightness: Brightness.dark,
      surface: surface,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      fontFamily: 'Roboto',
      textTheme:
          ThemeData.dark().textTheme.apply(bodyColor: ink, displayColor: ink),
      appBarTheme: const AppBarTheme(
        backgroundColor: navy,
        foregroundColor: ink,
        centerTitle: false,
        elevation: 0,
        titleTextStyle:
            TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: ink),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: border, width: 0.8),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: teal,
          foregroundColor: const Color(0xFF061425),
          minimumSize: const Size(120, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          minimumSize: const Size(48, 48),
          side: const BorderSide(color: border),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF17263D),
        labelStyle: const TextStyle(color: muted),
        hintStyle: const TextStyle(color: muted),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: teal, width: 1.6),
        ),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: navy,
        indicatorColor: Color(0xFF1C4B5F),
        selectedIconTheme: IconThemeData(color: teal),
        unselectedIconTheme: IconThemeData(color: muted),
        selectedLabelTextStyle:
            TextStyle(color: ink, fontWeight: FontWeight.w700),
        unselectedLabelTextStyle: TextStyle(color: muted),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: navy,
        indicatorColor: const Color(0xFF1C4B5F),
        labelTextStyle:
            WidgetStateProperty.all(const TextStyle(fontSize: 11, color: ink)),
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
              color: states.contains(WidgetState.selected) ? teal : muted,
            )),
      ),
      dividerColor: border,
    );
  }

  /// Parses entry date whether formatted as YYYY-MM-DD, DD/MM/YYYY, or ISO 8601.
  static DateTime? parseEntryDate(dynamic raw) {
    if (raw == null) return null;
    final s = raw.toString().trim();
    if (s.isEmpty) return null;
    final ymd = RegExp(r'^(\d{4})[-/](\d{1,2})[-/](\d{1,2})').firstMatch(s);
    if (ymd != null) {
      return DateTime(
        int.parse(ymd.group(1)!),
        int.parse(ymd.group(2)!),
        int.parse(ymd.group(3)!),
      );
    }
    final dmy = RegExp(r'^(\d{1,2})[-/](\d{1,2})[-/](\d{4})').firstMatch(s);
    if (dmy != null) {
      return DateTime(
        int.parse(dmy.group(3)!),
        int.parse(dmy.group(2)!),
        int.parse(dmy.group(1)!),
      );
    }
    final dt = DateTime.tryParse(s);
    if (dt != null) {
      return DateTime(dt.year, dt.month, dt.day);
    }
    return null;
  }

  static String dateLabel(DateTime d) => [
        d.day.toString().padLeft(2, '0'),
        d.month.toString().padLeft(2, '0'),
        d.year.toString()
      ].join('/');

  static String formatDateString(dynamic raw) {
    final d = parseEntryDate(raw);
    if (d == null) return raw?.toString() ?? '';
    return dateLabel(d);
  }

  static String activityTitle(String branch, String category, String taskId) {
    if (taskId == 'other_tasks') {
      return 'Other task carried out';
    }
    if (branch == 'ONT-BB' && category == 'FRONT DESK') {
      const bbMap = {
        'registrations': 'New patient registration and cards prepared',
        'whatsapp': 'WhatsApp messages checked and responded',
        'therapist_schedule': 'Therapist schedule arranged and posted',
        'reminders': 'Next-day WhatsApp reminders sent',
        'billing_excel': 'Billing and daily collection Excel prepared',
        'registration_excel': 'New registration Excel updated',
        'appointments':
            'Appointment bookings (in software/excel) & attending calls for appointments',
        'collection': 'Daily collection (AED)',
        'card_details': 'Card date/time, therapist and treatment entered',
        'patient_cards': 'Arrival, Treatment Charts & Reporting Voucher preparation',
        'charts':
            'Charts prepared for next day including session & rearranged all cards.',
        'cards_arranged':
            'Charts prepared for next day including session & rearranged all cards.',
        'ledger_updated': 'Ledger Updated (R4) (including for insurance)',
        'room_chore_inspection': 'Room Chore Inspection',
        'daily_task_updation': 'Daily Task Updation',
        'ledger_prepared': 'Individual Ledgers Prepared (EMR-wise)',
      };
      if (bbMap.containsKey(taskId)) return bbMap[taskId]!;
    }
    const generalMap = {
      // Front Desk (ONT-BR1 & general)
      'registrations':
          'Patient Registrations (including treatment chart and case sheet)',
      'appointments': 'Appointments Booked',
      'calls': 'Calls Attended',
      'whatsapp': 'WhatsApp Enquiries Replied',
      'confirmations': 'Confirmation Messages Sent',
      'consultations': 'Consultations Coordinated',
      'enquiries': 'Enquiries Handled',
      'registration_excel': 'Patient Registration Excel updated',
      'ledger_prepared': 'Individual Ledgers Prepared (EMR-wise)',
      'ledger_updated': 'Ledger Updated (R4) (including for insurance)',
      'patient_cards': 'Arrival, Treatment Charts & Reporting Voucher preparation',
      'charts':
          'Charts prepared for next day including session & rearranged all cards.',
      'cards_arranged':
          'Charts prepared for next day including session & rearranged all cards.',
      'patient_documents': 'Patient Doc Folder Updated',
      'emr_updated': 'EMR Records Updated',
      'due_checked': 'Next Day Appointment Due Checked',
      'room_chore_inspection': 'Room Chore Inspection',
      'daily_task_updation': 'Daily Task Updation',
      'collection': 'Daily Collection (AED)',
      // Insurance User
      'insurance_claims_prepared': 'Insurance Claims Prepared',
      'insurance_invoices': 'Insurance Invoices Prepared',
      'insurance_documents': 'Insurance Documents Sent',
      'insurance_datewise': 'Insurance Datewise Updated',
      'insurance_emrwise': 'Insurance EMRwise Updated',
      'insurance_ledger_emr': 'Insurance EMR-wise Entry',
      // Accounts
      'accounts_collection_check':
          'Daily Collections Checked — White Fox and Ontario',
      'accounts_dha_attendance': 'DHA Attendance Records Updated',
      'accounts_insurance_ledgers':
          'Individual ledgers for insurance showed',
      'accounts_month_end':
          'Month-End Collection Closing and Bank Deposit Handover',
      'accounts_reception': 'Reception Duties and Reporting Vouchers',
      'accounts_zoho_updation': 'Zoho updation',
      'accounts_vat_excel_ontario': 'Vat excel entry Ontario',
      'accounts_vat_filing_ontario': 'Vat filing Ontario',
      'accounts_vat_excel_whitefox': 'Vat excel updation White fox',
      'accounts_vat_filing_whitefox': 'Vat filing White fox',
      'accounts_cash_in_hand_checking': 'Cash in hand checking',
      'accounts_staff_attendance': 'Staff attendance Ontario and Whitefox',
      'accounts_towel_import_invoice':
          'Towel import invoice preparation, cash collect from customer and excel update',
      'accounts_medicine_collect_whitefox':
          'Medicine collect from supplier for whitefox and invoice updated',
      'accounts_month_end_closing_deposit':
          'Month end closing and cash handover for deposit',
      'accounts_whitefox_consignment_sale':
          'White fox Consignment basis sale checking and update',
      'accounts_petty_cash_voucher_entry':
          'Petty cash voucher entry and filing',
      'accounts_petty_cash_excel': 'Petty cash excel',
      'accounts_purchase_request_month': 'Purchase request for one month',
      // Doctor's Zone
      'doctors_consultations': 'Number of Consultations',
      'doctors_follow_ups': 'Number of Follow-ups',
      'doctors_treatments_supervised': 'Number of Treatments Supervised',
    };
    return generalMap[taskId] ?? taskId.replaceAll('_', ' ');
  }
}

/// Rounded medical plus mark used in the original Ontario Staff Portal.
class TaskLogBrandMark extends StatelessWidget {
  const TaskLogBrandMark({super.key, this.size = 34});
  final double size;
  @override
  Widget build(BuildContext context) {
    final crossLength = size * 0.56;
    final crossThickness = size * 0.18;
    const crossColor = Color(0xFF081120);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF16C3B0),
        borderRadius: BorderRadius.circular(size * 0.2),
      ),
      alignment: Alignment.center,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: crossLength,
            height: crossThickness,
            decoration: BoxDecoration(
              color: crossColor,
              borderRadius: BorderRadius.circular(crossThickness * 0.16),
            ),
          ),
          Container(
            width: crossThickness,
            height: crossLength,
            decoration: BoxDecoration(
              color: crossColor,
              borderRadius: BorderRadius.circular(crossThickness * 0.16),
            ),
          ),
          Opacity(
            opacity: 0,
            child: Icon(
              Icons.add_rounded,
              color: crossColor,
              size: size * 0.72,
            ),
          ),
        ],
      ),
    );
  }
}
