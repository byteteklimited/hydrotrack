import 'organization.dart';

/// One thing a new organization should do before relying on HydroTrack.
class SetupStep {
  const SetupStep({required this.title, required this.missing});

  final String title;

  /// What's still to do; empty when the step is done.
  final List<String> missing;

  bool get isDone => missing.isEmpty;
}

/// The agreed checklist: complete the business profile (address, phone,
/// logo and a registration number), which receipts, reports and
/// reminders print.
class SetupChecklist {
  const SetupChecklist(this.steps);

  final List<SetupStep> steps;

  factory SetupChecklist.forOrganization(Organization organization) {
    final profile = organization.profile;
    return SetupChecklist([
      SetupStep(
        title: 'Complete your business profile',
        missing: [
          if (profile.address == null) 'address',
          if (profile.phone == null) 'phone number',
          if (organization.logoPath == null) 'logo',
          if (profile.rcNumber == null && profile.nafdacNumber == null)
            'CAC/RC or NAFDAC number',
        ],
      ),
    ]);
  }

  int get doneCount => steps.where((step) => step.isDone).length;
  bool get isComplete => doneCount == steps.length;
}
