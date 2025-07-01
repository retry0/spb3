import 'dart:io';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
//import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../../data/models/spb_model.dart';

class PdfResult {
  final bool success;
  final String? filePath;
  final String? errorMessage;

  PdfResult({required this.success, this.filePath, this.errorMessage});
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

      // // Show file picker to select save location
      final saveLocation = await _pickSaveLocation(spb.noSpb);
      if (saveLocation == null) {
        return PdfResult(
          success: false,
          errorMessage: 'Save location not selected',
        );
      }
      await _buildPdfContent(spb);
      return PdfResult(success: true, filePath: saveLocation);
    } catch (e) {
      return PdfResult(success: false, errorMessage: e.toString());
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
        fileName:
            'SPB_${spbNumber}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf',
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      return result;
    } catch (e) {
      // If FilePicker fails, fallback to default location
      final directory = await getApplicationDocumentsDirectory();
      final path = directory.path;
      final fileName =
          'SPB_${spbNumber}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
      return '$path/$fileName';
    }
  }

  Future<void> _buildPdfContent(SpbModel spb) async {
    // Create document
    final PdfDocument document = PdfDocument();
    final dateTime = DateTime.parse(spb.tglAntarBuah);
    final dateFormat = DateFormat('dd MMMM yyyy');
    // Add a page
    final PdfPage page = document.pages.add();

    // Create font
    final PdfFont baseFont = PdfStandardFont(PdfFontFamily.helvetica, 12);
    final PdfFont boldFont = PdfStandardFont(
      PdfFontFamily.helvetica,
      12,
      style: PdfFontStyle.bold,
    );
    final PdfFont headerFont = PdfStandardFont(
      PdfFontFamily.helvetica,
      18,
      style: PdfFontStyle.bold,
    );
    final PdfBrush redBrush = PdfSolidBrush(PdfColor(255, 0, 0));

    double y = 0;

    // Header
    page.graphics.drawString(
      'PT ${spb.kodeVendor}',
      baseFont,
      bounds: Rect.fromLTWH(0, y, 300, 20),
    );
    page.graphics.drawString(
      'Kepada YTH\n ${spb.millTujuanName}',
      baseFont,
      bounds: Rect.fromLTWH(400, y, 150, 40),
      //format: PdfStringFormat(alignment: PdfTextAlignment.right),
    );
    y += 50;

    // Title
    page.graphics.drawString(
      'Surat Pengantar Buah',
      headerFont,
      brush: redBrush,
      bounds: Rect.fromLTWH(0, y, page.getClientSize().width, 30),
      format: PdfStringFormat(alignment: PdfTextAlignment.center),
    );
    y += 30;

    // SPB No
    page.graphics.drawString(
      'No SPB: ${spb.noSpb}',
      baseFont,
      bounds: Rect.fromLTWH(0, y, page.getClientSize().width, 20),
      format: PdfStringFormat(alignment: PdfTextAlignment.center),
    );
    y += 30;

    // Info block
    final double leftCol = 0;
    final double rightCol = 150;
    final double labelWidth = 130;
    page.graphics.drawString(
      'Dikirim Tgl',
      baseFont,
      bounds: Rect.fromLTWH(leftCol, y, labelWidth, 20),
    );
    page.graphics.drawString(
      ': ${dateFormat.format(dateTime)}',
      baseFont,
      bounds: Rect.fromLTWH(rightCol, y, 300, 20),
    );
    y += 20;
    page.graphics.drawString(
      'No Pol Kendaraan',
      baseFont,
      bounds: Rect.fromLTWH(leftCol, y, labelWidth, 20),
    );
    page.graphics.drawString(
      ': ${spb.noPolisi}',
      baseFont,
      bounds: Rect.fromLTWH(rightCol, y, 300, 20),
    );
    y += 20;
    page.graphics.drawString(
      'Nama Supir',
      baseFont,
      bounds: Rect.fromLTWH(leftCol, y, labelWidth, 20),
    );
    page.graphics.drawString(
      ': ${spb.driverName}',
      baseFont,
      bounds: Rect.fromLTWH(rightCol, y, 300, 20),
    );
    y += 30;

    // Table
    final PdfGrid grid = PdfGrid();
    grid.columns.add(count: 2);
    grid.headers.add(1);

    grid.headers[0].cells[0].value = 'No.';
    grid.headers[0].cells[1].value = 'Taksasi';
    grid.headers[0].style = PdfGridRowStyle(
      font: boldFont,
      //cellPadding: PdfPaddings(left: 5, right: 5, top: 3, bottom: 3),
    );

    final PdfGridRow row = grid.rows.add();
    row.cells[0].value = '1';
    row.cells[1].value =
        'Janjang : ${spb.jumJjg} Kg\nBrondolan : ${spb.brondolan} Kg\nTotal : ${spb.totBeratTaksasi} Kg';
    row.style = PdfGridRowStyle(
      font: baseFont,
      // cellPadding: PdfPaddings(left: 5, right: 5, top: 3, bottom: 3),
    );

    grid.style = PdfGridStyle(
      cellPadding: PdfPaddings(left: 5, right: 5),
      font: baseFont,
    );

    grid.draw(
      page: page,
      bounds: Rect.fromLTWH(0, y, page.getClientSize().width, 80),
    );

    y += 100;

    // Signatures
    page.graphics.drawString(
      'Penerima',
      baseFont,
      bounds: Rect.fromLTWH(30, y, 100, 20),
    );
    page.graphics.drawString(
      'Pengangkut',
      baseFont,
      bounds: Rect.fromLTWH(200, y, 100, 20),
    );
    page.graphics.drawString(
      'Pengirim',
      baseFont,
      bounds: Rect.fromLTWH(370, y, 100, 20),
    );
    y += 100;
    page.graphics.drawString(
      '${spb.driverName}',
      baseFont,
      bounds: Rect.fromLTWH(30, y, 100, 20),
    );
    page.graphics.drawString(
      '${spb.driverName}',
      baseFont,
      bounds: Rect.fromLTWH(200, y, 100, 20),
    );
    page.graphics.drawString(
      '${spb.kodeVendor}',
      baseFont,
      bounds: Rect.fromLTWH(370, y, 100, 20),
    );

    final fileName =
        'SPB_${spb.noSpb}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';

    document.security.userPassword = spb.driver;
    document.security.ownerPassword = spb.driver;

    // Save the PDF
    final List<int> bytes = await document.save();
    document.dispose();

    // Get path
    final Directory dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/${fileName}');

    await file.writeAsBytes(bytes);
  }
  // pw.Widget _buildPdfContent(SpbModel spb, String driverName) {
  //   final dateFormat = DateFormat('dd MMMM yyyy');
  //   final timeFormat = DateFormat('HH:mm');
  //   final dateTime = DateTime.parse(spb.tglAntarBuah);
  //   final supir = spb.driverName;
  //   final mill = spb.millTujuanName;
  //   final vendor = spb.kodeVendor;
  //   return pw.Container(
  //     padding: const pw.EdgeInsets.all(20),
  //     child: pw.Column(
  //       crossAxisAlignment: pw.CrossAxisAlignment.start,
  //       children: [
  //         // Header
  //         pw.Row(
  //           mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
  //           children: [
  //             pw.Text(
  //               'PT ${vendor}',
  //               style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
  //             ),
  //             pw.Column(
  //               crossAxisAlignment: pw.CrossAxisAlignment.end,
  //               children: [
  //                 pw.Text(
  //                   'Kepada YTH',
  //                   style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
  //                 ),
  //                 pw.Text(
  //                   mill,
  //                   style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
  //                 ),
  //               ],
  //             ),
  //           ],
  //         ),

  //         pw.SizedBox(height: 20),

  //         // Title
  //         pw.Center(
  //           child: pw.Text(
  //             'Surat Pengantar Buah',
  //             style: pw.TextStyle(
  //               fontSize: 18,
  //               fontWeight: pw.FontWeight.bold,
  //               color: PdfColors.red,
  //             ),
  //           ),
  //         ),

  //         pw.SizedBox(height: 5),

  //         // SPB Number
  //         pw.Center(
  //           child: pw.Text(
  //             'No SPB: ${spb.noSpb}',
  //             style: pw.TextStyle(fontSize: 12, color: PdfColors.black),
  //           ),
  //         ),

  //         pw.SizedBox(height: 15),

  //         // Delivery Info
  //         pw.Row(
  //           crossAxisAlignment: pw.CrossAxisAlignment.start,
  //           children: [
  //             pw.Column(
  //               crossAxisAlignment: pw.CrossAxisAlignment.start,
  //               children: [
  //                 pw.Text(
  //                   'Dikirim Tgl',
  //                   style: pw.TextStyle(fontSize: 10, color: PdfColors.black),
  //                 ),
  //                 pw.Text(
  //                   'No Pol Kendaraan',
  //                   style: pw.TextStyle(fontSize: 10, color: PdfColors.black),
  //                 ),
  //                 pw.Text(
  //                   'Nama Supir',
  //                   style: pw.TextStyle(fontSize: 10, color: PdfColors.black),
  //                 ),
  //               ],
  //             ),
  //             pw.SizedBox(width: 5),
  //             pw.Column(
  //               crossAxisAlignment: pw.CrossAxisAlignment.start,
  //               children: [
  //                 pw.Text(
  //                   ': ${dateFormat.format(dateTime)}',
  //                   style: pw.TextStyle(fontSize: 10, color: PdfColors.black),
  //                 ),
  //                 pw.Text(
  //                   ': ${spb.noPolisi ?? "N/A"}',
  //                   style: pw.TextStyle(fontSize: 10, color: PdfColors.black),
  //                 ),
  //                 pw.Text(
  //                   ': ${supir}',
  //                   style: pw.TextStyle(fontSize: 10, color: PdfColors.black),
  //                 ),
  //               ],
  //             ),
  //           ],
  //         ),

  //         pw.SizedBox(height: 20),

  //         // Table
  //         pw.Table(
  //           border: pw.TableBorder.all(color: PdfColors.black),
  //           children: [
  //             // Table Header
  //             pw.TableRow(
  //               children: [
  //                 pw.Padding(
  //                   padding: const pw.EdgeInsets.all(5),
  //                   child: pw.Text(
  //                     'No.',
  //                     style: pw.TextStyle(
  //                       fontSize: 10,
  //                       fontWeight: pw.FontWeight.bold,
  //                     ),
  //                   ),
  //                 ),
  //                 pw.Padding(
  //                   padding: const pw.EdgeInsets.all(5),
  //                   child: pw.Text(
  //                     'Taksasi',
  //                     style: pw.TextStyle(
  //                       fontSize: 10,
  //                       fontWeight: pw.FontWeight.bold,
  //                     ),
  //                   ),
  //                 ),
  //               ],
  //             ),
  //             // Table Data
  //             pw.TableRow(
  //               children: [
  //                 pw.Padding(
  //                   padding: const pw.EdgeInsets.all(5),
  //                   child: pw.Text('1', style: pw.TextStyle(fontSize: 10)),
  //                 ),
  //                 pw.Padding(
  //                   padding: const pw.EdgeInsets.all(5),
  //                   child: pw.Column(
  //                     crossAxisAlignment: pw.CrossAxisAlignment.start,
  //                     children: [
  //                       pw.Text(
  //                         'Janjang : ${spb.jumJjg} Kg',
  //                         style: pw.TextStyle(fontSize: 10),
  //                       ),
  //                       pw.Text(
  //                         'Brondolan : ${spb.brondolan} Kg',
  //                         style: pw.TextStyle(fontSize: 10),
  //                       ),
  //                       pw.Text(
  //                         'Total : ${spb.totBeratTaksasi} Kg',
  //                         style: pw.TextStyle(
  //                           fontSize: 10,
  //                           fontWeight: pw.FontWeight.bold,
  //                         ),
  //                       ),
  //                     ],
  //                   ),
  //                 ),
  //               ],
  //             ),
  //           ],
  //         ),

  //         pw.SizedBox(height: 30),

  //         // Signatures
  //         pw.Row(
  //           mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
  //           children: [
  //             pw.Column(
  //               crossAxisAlignment: pw.CrossAxisAlignment.center,
  //               children: [
  //                 pw.Text('Penerima', style: pw.TextStyle(fontSize: 10)),
  //                 pw.SizedBox(height: 40),
  //                 pw.Text(supir, style: pw.TextStyle(fontSize: 10)),
  //               ],
  //             ),
  //             pw.Column(
  //               crossAxisAlignment: pw.CrossAxisAlignment.center,
  //               children: [
  //                 pw.Text('Pengangkut', style: pw.TextStyle(fontSize: 10)),
  //                 pw.SizedBox(height: 40),
  //                 pw.Text(supir, style: pw.TextStyle(fontSize: 10)),
  //               ],
  //             ),
  //             pw.Column(
  //               crossAxisAlignment: pw.CrossAxisAlignment.center,
  //               children: [
  //                 pw.Text('Pengirim', style: pw.TextStyle(fontSize: 10)),
  //                 pw.SizedBox(height: 40),
  //                 pw.Text(
  //                   vendor,
  //                   textAlign: pw.TextAlign.center,
  //                   style: pw.TextStyle(fontSize: 10),
  //                 ),
  //               ],
  //             ),
  //           ],
  //         ),
  //       ],
  //     ),
  //   );
  // }
}
