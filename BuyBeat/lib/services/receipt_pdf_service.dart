import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

import '../services/cart_service.dart';

/// Сервис генерации PDF-чеков с поддержкой русского языка (Noto Sans / кириллица)
class ReceiptPdfService {
  /// Генерирует PDF-чек покупки
  static Future<Uint8List> generateReceipt({
    required List<CartItemSnapshot> items,
    required double totalAmount,
    required String buyerName,
    required String buyerEmail,
    required DateTime purchaseDate,
    String? transactionId,
  }) async {
    // Шрифты Noto Sans с поддержкой кириллицы
    final regular = await PdfGoogleFonts.notoSansRegular();
    final bold    = await PdfGoogleFonts.notoSansBold();
    final italic  = await PdfGoogleFonts.notoSansItalic();

    final pdf = pw.Document();
    final dateStr = DateFormat('dd.MM.yyyy HH:mm').format(purchaseDate);

    final greenColor = PdfColor.fromHex('#22C55E');
    final darkColor  = PdfColor.fromHex('#111111');

    pw.TextStyle body({pw.Font? font, double size = 11, PdfColor? color}) =>
        pw.TextStyle(font: font ?? regular, fontSize: size, color: color);

    pw.TextStyle bodyBold({double size = 11, PdfColor? color}) =>
        pw.TextStyle(font: bold, fontSize: size, color: color);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => [
          // ── Шапка ───────────────────────────────────────────────────
          pw.Center(
            child: pw.Column(children: [
              pw.Text('BuyBeats',
                  style: pw.TextStyle(font: bold, fontSize: 30, color: darkColor)),
              pw.SizedBox(height: 4),
              pw.Text('Маркетплейс битов',
                  style: body(size: 12, color: PdfColors.grey600)),
            ]),
          ),

          pw.SizedBox(height: 20),
          pw.Divider(color: PdfColors.grey300),
          pw.SizedBox(height: 16),

          // ── Заголовок чека ───────────────────────────────────────────
          pw.Text('ЧЕК / ЛИЦЕНЗИОННОЕ СОГЛАШЕНИЕ',
              style: bodyBold(size: 16)),
          pw.SizedBox(height: 16),

          _infoRow('Дата:',          dateStr,       bold: bold, regular: regular),
          _infoRow('Покупатель:',    buyerName,     bold: bold, regular: regular),
          _infoRow('Email:',         buyerEmail,    bold: bold, regular: regular),
          if (transactionId != null)
            _infoRow('ID транзакции:', transactionId, bold: bold, regular: regular),

          pw.SizedBox(height: 20),
          pw.Divider(color: PdfColors.grey300),
          pw.SizedBox(height: 16),

          // ── Таблица покупок ──────────────────────────────────────────
          pw.Text('ПРИОБРЕТЁННЫЕ БИТЫ', style: bodyBold(size: 14)),
          pw.SizedBox(height: 12),

          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(font: bold, fontSize: 11),
            cellStyle: pw.TextStyle(font: regular, fontSize: 10),
            headerDecoration:
                const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF3F4F6)),
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.center,
              2: pw.Alignment.center,
              3: pw.Alignment.centerRight,
            },
            headers: ['Название бита', 'Формат', 'Лицензия', 'Цена'],
            data: items
                .map((item) => [
                      item.beatTitle,
                      item.format,
                      item.licenseType,
                      '\$${item.price.toStringAsFixed(2)}',
                    ])
                .toList(),
          ),

          pw.SizedBox(height: 16),

          // ── Итого ────────────────────────────────────────────────────
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#F0FDF4'),
                border: pw.Border.all(color: greenColor),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Text(
                'ИТОГО: \$${totalAmount.toStringAsFixed(2)}',
                style: bodyBold(size: 18, color: greenColor),
              ),
            ),
          ),

          pw.SizedBox(height: 30),
          pw.Divider(color: PdfColors.grey300),
          pw.SizedBox(height: 16),

          // ── Условия лицензии ─────────────────────────────────────────
          pw.Text('УСЛОВИЯ ЛИЦЕНЗИИ', style: bodyBold(size: 14)),
          pw.SizedBox(height: 8),

          ..._licenseTerms(regular: regular, bold: bold, italic: italic),

          pw.SizedBox(height: 24),
          pw.Divider(color: PdfColors.grey300),
          pw.SizedBox(height: 12),

          // ── Подпись ──────────────────────────────────────────────────
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Платформа BuyBeats', style: bodyBold()),
                  pw.Text('support@buybeats.com',
                      style: body(size: 10, color: PdfColors.grey600)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Покупатель: $buyerName', style: bodyBold()),
                  pw.Text(buyerEmail,
                      style: body(size: 10, color: PdfColors.grey600)),
                ],
              ),
            ],
          ),

          pw.SizedBox(height: 20),
          pw.Center(
            child: pw.Text(
              'Настоящий документ является подтверждением оплаты и лицензионным соглашением.',
              style: body(font: italic, size: 9, color: PdfColors.grey500),
              textAlign: pw.TextAlign.center,
            ),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _infoRow(
    String label,
    String value, {
    required pw.Font bold,
    required pw.Font regular,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(children: [
        pw.SizedBox(
          width: 130,
          child: pw.Text(label,
              style: pw.TextStyle(font: bold, fontSize: 11)),
        ),
        pw.Text(value, style: pw.TextStyle(font: regular, fontSize: 11)),
      ]),
    );
  }

  static List<pw.Widget> _licenseTerms({
    required pw.Font regular,
    required pw.Font bold,
    required pw.Font italic,
  }) {
    final terms = [
      'Настоящая лицензия предоставляет покупателю право использовать приобретённый бит(ы) в коммерческих или некоммерческих музыкальных проектах.',
      'Лицензия «Аренда» (Lease): покупатель вправе использовать бит в тираже до 5 000 экземпляров (цифровых/физических). Права сохраняются у автора.',
      'Эксклюзивная лицензия: покупатель получает исключительные права. После продажи автор прекращает продажу данного бита другим покупателям.',
      'Покупатель НЕ вправе перепродавать, распространять или сублицензировать аудиофайл(ы) в виде самостоятельного продукта.',
      'В публичных релизах обязательно указание автора (например: «Prod. by [Имя продюсера]»).',
      'Лицензия является персональной и распространяется исключительно на покупателя, указанного в настоящем чеке.',
    ];
    return terms
        .asMap()
        .entries
        .map((e) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 6),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('${e.key + 1}. ',
                      style: pw.TextStyle(font: bold, fontSize: 10)),
                  pw.Expanded(
                      child: pw.Text(e.value,
                          style: pw.TextStyle(
                              font: regular,
                              fontSize: 10,
                              color: PdfColors.grey700))),
                ],
              ),
            ))
        .toList();
  }
}

/// Снимок элемента корзины для PDF (чтобы не зависеть от Beat/BeatFile объектов)
class CartItemSnapshot {
  final String beatTitle;
  final String format;
  final String licenseType;
  final double price;
  final String? producerName;

  CartItemSnapshot({
    required this.beatTitle,
    required this.format,
    required this.licenseType,
    required this.price,
    this.producerName,
  });

  factory CartItemSnapshot.fromCartItem(CartItem item) {
    return CartItemSnapshot(
      beatTitle: item.beat.title,
      format: item.formatLabel,
      licenseType: item.licenseLabel,
      price: item.price,
      producerName: item.beat.producerName,
    );
  }
}
