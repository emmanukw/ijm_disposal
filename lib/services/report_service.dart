import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:web/web.dart' as web;

import '../models/bid.dart';
import '../models/item.dart';

final _dateFmt = DateFormat('yyyy-MM-dd HH:mm:ss');
String _fmt(DateTime? d) => d == null ? 'pending' : _dateFmt.format(d);

const _bidHeaders = [
  'No.',
  'Bidder Name',
  'Item',
  'Quantity',
  'Unit Price',
  'Total',
  'Date & Time',
];

const _itemHeaders = [
  'Item',
  'Description',
  'Total Qty',
  'Booked',
  'Remaining',
  'Unit Price',
  'Value Booked',
  'Status',
];

List<List<Object>> _bidRows(List<Bid> bids) => [
      for (var i = 0; i < bids.length; i++)
        [
          i + 1,
          bids[i].bidderName,
          bids[i].itemName,
          bids[i].quantity,
          bids[i].unitPrice,
          bids[i].total,
          _fmt(bids[i].createdAt),
        ],
    ];

List<List<Object>> _itemRows(List<Item> items) => [
      for (final it in items)
        [
          it.name,
          it.description,
          it.quantity,
          it.booked,
          it.remaining,
          it.price,
          it.price * it.booked,
          it.soldOut ? 'Finished' : 'Available',
        ],
    ];

String _stamp() => DateFormat('yyyyMMdd_HHmm').format(DateTime.now());

/// CSV of every bid (opens cleanly in Excel thanks to the BOM).
void downloadBidsCsv(List<Bid> bids) {
  final csv = Csv(addBom: true).encode([_bidHeaders, ..._bidRows(bids)]);
  _download(
    Uint8List.fromList(utf8.encode(csv)),
    'ijm_disposal_bids_${_stamp()}.csv',
    'text/csv;charset=utf-8',
  );
}

/// Excel workbook with two sheets: "Bids" and "Items Summary".
void downloadExcelReport(List<Bid> bids, List<Item> items) {
  final excel = Excel.createExcel();
  final defaultSheet = excel.getDefaultSheet()!;
  excel.rename(defaultSheet, 'Bids');

  void fill(Sheet sheet, List<String> headers, List<List<Object>> rows) {
    final bold = CellStyle(bold: true);
    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());
    for (var c = 0; c < headers.length; c++) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0))
          .cellStyle = bold;
      sheet.setColumnWidth(c, 20);
    }
    for (final r in rows) {
      sheet.appendRow(r.map<CellValue>((v) {
        if (v is int) return IntCellValue(v);
        if (v is num) return DoubleCellValue(v.toDouble());
        return TextCellValue(v.toString());
      }).toList());
    }
  }

  fill(excel['Bids'], _bidHeaders, _bidRows(bids));
  fill(excel['Items Summary'], _itemHeaders, _itemRows(items));

  final bytes = excel.encode();
  if (bytes == null) return;
  _download(
    Uint8List.fromList(bytes),
    'ijm_disposal_report_${_stamp()}.xlsx',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  );
}

void _download(Uint8List bytes, String filename, String mime) {
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mime));
  final url = web.URL.createObjectURL(blob);
  final a = web.HTMLAnchorElement()
    ..href = url
    ..download = filename;
  web.document.body!.append(a);
  a.click();
  a.remove();
  web.URL.revokeObjectURL(url);
}
