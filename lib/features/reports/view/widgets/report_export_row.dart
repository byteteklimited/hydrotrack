import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/action_error.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../organizations/data/models/business_header.dart';
import '../../../organizations/data/providers/organization_providers.dart';
import '../../data/models/report_summary.dart';
import 'report_csv.dart';
import 'report_pdf.dart';

/// Export actions for the current [summary] — PDF hands the generated
/// document to the OS/browser's own print-or-save flow (same mechanism
/// Sales' receipt already uses); Excel saves a CSV, which Excel,
/// Sheets, and Numbers all open directly without needing a second
/// binary-format-generating dependency.
class ReportExportRow extends ConsumerStatefulWidget {
  const ReportExportRow({super.key, required this.summary});

  final ReportSummary summary;

  @override
  ConsumerState<ReportExportRow> createState() => _ReportExportRowState();
}

class _ReportExportRowState extends ConsumerState<ReportExportRow> {
  bool _isExportingPdf = false;
  bool _isExportingCsv = false;

  /// Exports carry the organization's own logo, name and profile.
  Future<BusinessHeader> get _header => ref.read(businessHeaderProvider.future);

  /// e.g. "sunny-water-report-2026-11" — the organization's name, not the
  /// platform's.
  String get _fileBase =>
      '${fileSlug(ref.read(currentOrganizationProvider)?.name ?? '')}-report-$_fileNameDate';

  String get _fileNameDate => DateTime.now().toIso8601String().split('T').first;

  Future<void> _exportPdf() async {
    setState(() => _isExportingPdf = true);
    try {
      final doc = await buildReportPdf(widget.summary, header: await _header);
      await Printing.sharePdf(
        bytes: await doc.save(),
        filename: '$_fileBase.pdf',
      );
    } catch (_) {
      if (mounted) {
        showActionErrorSnackBar(
          context,
          message: "Couldn't export the PDF. Try again.",
        );
      }
    } finally {
      if (mounted) setState(() => _isExportingPdf = false);
    }
  }

  Future<void> _exportCsv() async {
    setState(() => _isExportingCsv = true);
    try {
      final bytes = buildReportCsv(widget.summary, header: await _header);
      await FileSaver.instance.saveFile(
        name: _fileBase,
        bytes: bytes,
        fileExtension: 'csv',
        mimeType: MimeType.csv,
      );
    } catch (_) {
      if (mounted) {
        showActionErrorSnackBar(
          context,
          message: "Couldn't export the spreadsheet. Try again.",
        );
      }
    } finally {
      if (mounted) setState(() => _isExportingCsv = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: AppButton(
            label: 'Export PDF',
            variant: AppButtonVariant.secondary,
            leadingIcon: Icons.picture_as_pdf_outlined,
            isLoading: _isExportingPdf,
            onPressed: _isExportingPdf ? null : _exportPdf,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: AppButton(
            label: 'Export Excel',
            variant: AppButtonVariant.secondary,
            leadingIcon: Icons.grid_on_outlined,
            isLoading: _isExportingCsv,
            onPressed: _isExportingCsv ? null : _exportCsv,
          ),
        ),
      ],
    );
  }
}
