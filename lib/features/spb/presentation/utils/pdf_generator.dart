import 'dart:io';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../data/models/spb_model.dart';

class PdfResult {
  final bool success;
  final String? filePath;
  final String? errorMessage;

  PdfResult({
    required this.success,
    this.filePath,
    this.errorMessage,
  });
}

class SpbPdfGenerator {
  Future<PdfResult> generateSpbPdf({
    required SpbModel spb,
    required String driverName,
    String? password,
  }) async {
    try {
      // Check storage permission
      final permissionStatus = await _checkPermission();
      if (!permissionStatus) {
        return PdfResult(
          success: false,
          errorMessage: 'Storage permission denied',
        );
      }

      // Create PDF document
      final pdf = pw.Document();

      // Add content to the PDF
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a5,
          build: (pw.Context context) {
            return _buildPdfContent(spb, driverName);
          },
        ),
      );

      // Show file picker to select save location
      final saveLocation = await _pickSaveLocation(spb.noSpb);
      if (saveLocation == null) {
        return PdfResult(
          success: false,
          errorMessage: 'Save location not selected',
        );
      }

      // Save the PDF with password protection if provided
      final file = File(saveLocation);
      if (password != null && password.isNotEmpty) {
        await file.writeAsBytes(await pdf.save(
          onlySelected: false,
          userPassword: password,
        ));
      } else {
        await file.writeAsBytes(await pdf.save());
      }

      return PdfResult(
        success: true,
        filePath: saveLocation,
      );
    } catch (e) {
      return PdfResult(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<bool> _checkPermission() async {
    // For Android 13+ (API level 33+), we need to request specific permissions
    if (await Permission.photos.request().isGranted) {
      return true;
    }
    
    // For older Android versions, request storage permission
    final status = await Permission.storage.request();
    return status.isGranted;
  }

  Future<String?> _pickSaveLocation(String spbNumber) async {
    try {
      // Use FilePicker to select save location
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Save SPB PDF',
        fileName: 'SPB_${spbNumber}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf',
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      return result;
    } catch (e) {
      // If FilePicker fails, fallback to default location
      final directory = await getApplicationDocumentsDirectory();
      final path = directory.path;
      final fileName = 'SPB_${spbNumber}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
      return '$path/$fileName';
    }
  }

  pw.Widget _buildPdfContent(SpbModel spb, String driverName) {
    final dateFormat = DateFormat('dd MMMM yyyy');
    final timeFormat = DateFormat('HH:mm');
    final dateTime = DateTime.parse(spb.tglAntarBuah);
    
    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Header
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'PT MILL.....',
                style: pw.TextStyle(
                  fontSize: 12,
                  color: PdfColors.grey700,
                ),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'Kepada YTH',
                    style: pw.TextStyle(
                      fontSize: 12,
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.Text(
                    'PT Mill.......',
                    style: pw.TextStyle(
                      fontSize: 12,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          pw.SizedBox(height: 20),
          
          // Title
          pw.Center(
            child: pw.Text(
              'Surat Pengantar Buah',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.red,
              ),
            ),
          ),
          
          pw.SizedBox(height: 5),
          
          // SPB Number
          pw.Center(
            child: pw.Text(
              'No SPB: ${spb.noSpb}',
              style: pw.TextStyle(
                fontSize: 12,
                color: PdfColors.black,
              ),
            ),
          ),
          
          pw.SizedBox(height: 15),
          
          // Delivery Info
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Dikirim Tgl',
                    style: pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.black,
                    ),
                  ),
                  pw.Text(
                    'No Pol Kendaraan',
                    style: pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.black,
                    ),
                  ),
                  pw.Text(
                    'Nama Supir',
                    style: pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.black,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(width: 5),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    ': ${dateFormat.format(dateTime)}',
                    style: pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.black,
                    ),
                  ),
                  pw.Text(
                    ': ${spb.noPolisi ?? "N/A"}',
                    style: pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.black,
                    ),
                  ),
                  pw.Text(
                    ': ${driverName}',
                    style: pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.black,
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          pw.SizedBox(height: 20),
          
          // Table
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.black),
            children: [
              // Table Header
              pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text(
                      'No.',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text(
                      'Taksasi',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              // Table Data
              pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text(
                      '1',
                      style: pw.TextStyle(
                        fontSize: 10,
                      ),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          '-Janjang : ${spb.jumJjg} Kg',
                          style: pw.TextStyle(
                            fontSize: 10,
                          ),
                        ),
                        pw.Text(
                          '-Brondolan : ${spb.brondolan} Kg',
                          style: pw.TextStyle(
                            fontSize: 10,
                          ),
                        ),
                        pw.Text(
                          '-Total : ${spb.totBeratTaksasi} Kg',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          pw.SizedBox(height: 30),
          
          // Signatures
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    'Penerima',
                    style: pw.TextStyle(
                      fontSize: 10,
                    ),
                  ),
                  pw.SizedBox(height: 40),
                  pw.Text(
                    driverName,
                    style: pw.TextStyle(
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    'Pengangkut',
                    style: pw.TextStyle(
                      fontSize: 10,
                    ),
                  ),
                  pw.SizedBox(height: 40),
                  pw.Text(
                    driverName,
                    style: pw.TextStyle(
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    'Pengirim',
                    style: pw.TextStyle(
                      fontSize: 10,
                    ),
                  ),
                  pw.SizedBox(height: 40),
                  pw.Text(
                    'Kelompok Jasa\nSawit Sumber\nSejahtera\nKJSSJ',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}