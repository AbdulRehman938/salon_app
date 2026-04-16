import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'dart:ui';

import 'package:file_saver/file_saver.dart';
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/receipt_download.dart';
import '../../data/services/booking_checkout_service.dart';
import '../models/salon_sub_service_data.dart';
import 'bookings_page.dart';

class ReceiptPage extends StatelessWidget {
  const ReceiptPage({super.key, required this.receipt});

  final StoredReceiptData receipt;

  String _formatPrice(double value) {
    return '\$${value.toStringAsFixed(2)}';
  }

  String _bookingDateLabel(DateTime date) {
    const months = <int, String>{
      1: 'January',
      2: 'February',
      3: 'March',
      4: 'April',
      5: 'May',
      6: 'June',
      7: 'July',
      8: 'August',
      9: 'September',
      10: 'October',
      11: 'November',
      12: 'December',
    };
    final month = months[date.month] ?? '';
    return '$month ${date.day}, ${date.year}';
  }

  Future<List<int>> _buildStyledReceiptPdfBytes() async {
    final document = pw.Document(title: 'Receipt ${receipt.bookingId}');

    document.addPage(
      pw.Page(
        pageFormat: pdf.PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(24, 24, 24, 24),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Receipt',
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Booking ID: ${receipt.bookingId}',
                style: const pw.TextStyle(fontSize: 11),
              ),
              pw.SizedBox(height: 16),
              pw.Center(
                child: pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: receipt.qrPayloadJson,
                  width: 150,
                  height: 150,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Center(
                child: pw.Text(
                  'Scan this QR code at the salon for quick check-in.',
                  style: const pw.TextStyle(fontSize: 11),
                ),
              ),
              pw.SizedBox(height: 16),
              _pdfInfoSection(),
              pw.SizedBox(height: 14),
              _pdfPricingSection(),
            ],
          );
        },
      ),
    );

    return document.save();
  }

  pw.Widget _pdfInfoSection() {
    pw.Widget row(String label, String value) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 7),
        child: pw.Row(
          children: [
            pw.Expanded(
              child: pw.Text(
                label,
                style: pw.TextStyle(
                  fontSize: 11,
                  color: pdf.PdfColor.fromHex('#1A1A1A'),
                ),
              ),
            ),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 11,
                color: pdf.PdfColor.fromHex('#6E6E6E'),
              ),
            ),
          ],
        ),
      );
    }

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: pw.BoxDecoration(
        color: pdf.PdfColor.fromHex('#F8F8F8'),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        children: [
          row('Salon', receipt.salonName),
          row('Customer Name', receipt.customerName),
          row('Phone', receipt.customerPhone),
          row('Booking Date', _bookingDateLabel(receipt.bookingDate)),
          row('Booking Time', receipt.bookingTime),
          row('Stylist', receipt.stylistLabel),
          row('Payment', receipt.paymentModeLabel),
        ],
      ),
    );
  }

  pw.Widget _pdfPricingSection() {
    pw.Widget row(String label, String value, {bool emphasize = false}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 7),
        child: pw.Row(
          children: [
            pw.Expanded(
              child: pw.Text(
                label,
                style: pw.TextStyle(
                  fontSize: emphasize ? 12 : 11,
                  fontWeight: emphasize
                      ? pw.FontWeight.bold
                      : pw.FontWeight.normal,
                  color: pdf.PdfColor.fromHex('#1A1A1A'),
                ),
              ),
            ),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: emphasize ? 12 : 11,
                fontWeight: emphasize
                    ? pw.FontWeight.bold
                    : pw.FontWeight.normal,
                color: emphasize
                    ? pdf.PdfColor.fromHex('#111111')
                    : pdf.PdfColor.fromHex('#6E6E6E'),
              ),
            ),
          ],
        ),
      );
    }

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: pw.BoxDecoration(
        color: pdf.PdfColor.fromHex('#F8F8F8'),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        children: [
          ...receipt.services.map(
            (service) => row(service.name, _formatPrice(service.charge)),
          ),
          row('Discount', _formatPrice(receipt.discountAmount)),
          row('Total', _formatPrice(receipt.totalAmount), emphasize: true),
        ],
      ),
    );
  }

  Future<void> _downloadReceipt(BuildContext context) async {
    final fileName = 'receipt_${receipt.bookingId}.pdf';
    final pdfBytes = await _buildStyledReceiptPdfBytes();
    final ok = await downloadReceiptBytes(
      fileName: fileName,
      bytes: Uint8List.fromList(pdfBytes),
      mimeType: MimeType.pdf,
    );

    if (!context.mounted) {
      return;
    }

    if (ok) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Receipt downloaded.')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to download receipt.')),
      );
    }
  }

  void _goToBookings(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const BookingsPage()),
      (route) => false,
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.dark1,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: AppColors.gray1,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final qrUrl =
        'https://quickchart.io/qr?size=320&text=${Uri.encodeComponent(receipt.qrPayloadJson)}';

    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F3),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 84, 12, 82),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: SizedBox(
                      width: 180,
                      height: 180,
                      child: Image.network(
                        qrUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.white,
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.qr_code_2_rounded,
                              size: 90,
                              color: AppColors.dark1,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Center(
                    child: Text(
                      'Scan this QR code at the salon for\nquick check-in.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.dark1,
                        fontSize: 20 / 1.2,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9F9F9),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        _summaryRow('Salon', receipt.salonName),
                        _summaryRow('Customer Name', receipt.customerName),
                        _summaryRow('Phone', receipt.customerPhone),
                        _summaryRow(
                          'Booking Date',
                          _bookingDateLabel(receipt.bookingDate),
                        ),
                        _summaryRow('Booking Time', receipt.bookingTime),
                        _summaryRow('Stylist', receipt.stylistLabel),
                        _summaryRow('Payment', receipt.paymentModeLabel),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9F9F9),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        ...receipt.services.map(
                          (SalonSubServiceData service) => _summaryRow(
                            service.name,
                            _formatPrice(service.charge),
                          ),
                        ),
                        _summaryRow(
                          'Discount',
                          _formatPrice(receipt.discountAmount),
                        ),
                        _summaryRow('Total', _formatPrice(receipt.totalAmount)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 0,
              left: 12,
              right: 12,
              child: SafeArea(
                bottom: false,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      height: 56,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.78),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => _goToBookings(context),
                            icon: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 19,
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Text(
                            'Receipt',
                            style: TextStyle(
                              color: AppColors.dark1,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 10,
              child: SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () => _downloadReceipt(context),
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: const Color(0xFF2F57F0),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Download Receipt',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
