import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/purchase.dart';

/// Генерирует PDF-чек для покупки и возвращает байты
class PdfReceiptService {
  static Future<List<int>> generateReceipt({
    required Purchase purchase,
    required String beatTitle,
    required String producerName,
    required String fileType,
    required String licenseType,
    required String buyerUsername,
  }) async {
    final pdf = pw.Document();

    final dateStr = purchase.createdAt != null
        ? '${purchase.createdAt!.day.toString().padLeft(2, '0')}'
          '.${purchase.createdAt!.month.toString().padLeft(2, '0')}'
          '.${purchase.createdAt!.year}'
          '  ${purchase.createdAt!.hour.toString().padLeft(2, '0')}'
          ':${purchase.createdAt!.minute.toString().padLeft(2, '0')}'
        : '—';

    final accentColor = PdfColor.fromHex('#CDFF00');
    final darkColor = PdfColor.fromHex('#0A0A0F');
    final grayColor = PdfColor.fromHex('#888899');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // ─── Header ───
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              decoration: pw.BoxDecoration(
                color: darkColor,
                borderRadius: pw.BorderRadius.circular(12),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('BuyBeats',
                          style: pw.TextStyle(
                              color: accentColor,
                              fontSize: 26,
                              fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 4),
                      pw.Text('Чек об оплате',
                          style: pw.TextStyle(color: PdfColors.white, fontSize: 13)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('№ ${purchase.id}',
                          style: pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 13,
                              fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 4),
                      pw.Text(dateStr,
                          style: pw.TextStyle(color: grayColor, fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 28),

            // ─── Beat info ───
            pw.Text('Информация о товаре',
                style: pw.TextStyle(fontSize: 13, color: grayColor)),
            pw.SizedBox(height: 10),
            _infoRow('Бит', beatTitle),
            _infoRow('Продюсер', producerName),
            _infoRow('Формат файла', fileType),
            _infoRow('Тип лицензии', licenseType),
            pw.SizedBox(height: 24),

            // ─── Purchase info ───
            pw.Text('Детали покупки',
                style: pw.TextStyle(fontSize: 13, color: grayColor)),
            pw.SizedBox(height: 10),
            _infoRow('Покупатель', buyerUsername),
            _infoRow('Способ оплаты', 'Кошелёк BuyBeats'),
            _infoRow('Статус', 'Оплачено'),
            pw.SizedBox(height: 24),

            // ─── Total ───
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: accentColor, width: 1.2),
                borderRadius: pw.BorderRadius.circular(10),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Итого:',
                      style: pw.TextStyle(
                          fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  pw.Text('\$${purchase.amount.toStringAsFixed(2)}',
                      style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                          color: accentColor)),
                ],
              ),
            ),
            pw.Spacer(),

            // ─── Footer ───
            pw.Divider(color: grayColor),
            pw.SizedBox(height: 8),
            pw.Text(
              'Данный документ является подтверждением покупки лицензии на использование бита.\n'
              'BuyBeats — платформа для продажи и покупки музыкальных битов.',
              style: pw.TextStyle(color: grayColor, fontSize: 9),
              textAlign: pw.TextAlign.center,
            ),
          ],
        ),
      ),
    );

    return pdf.save();
  }

  static pw.Widget _infoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 140,
            child: pw.Text(label,
                style: pw.TextStyle(
                    color: PdfColor.fromHex('#888899'), fontSize: 11)),
          ),
          pw.Expanded(
            child: pw.Text(value,
                style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold, fontSize: 11)),
          ),
        ],
      ),
    );
  }
}
