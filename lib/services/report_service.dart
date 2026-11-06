import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:web/web.dart' as web;

import '../models/bid.dart';
import '../models/bid_status.dart';
import '../models/item.dart';

final _dateFmt = DateFormat('yyyy-MM-dd HH:mm:ss');
String _fmt(DateTime? d) => d == null ? 'pending' : _dateFmt.format(d);

const _bidHeaders = [
  'No.',
  'Bidder Name',
  'Email',
  'Item',
  'Quantity',
  'Unit Price',
  'Total',
  'Date & Time',
  'Paid',
  'Paid At',
  'Collected',
  'Collected At',
  'Note',
];

const _itemHeaders = [
  'Item',
  'Description',
  'Total Qty',
  'Booked',
  'Remaining',
  'Unit Price',
  'Value Booked',
  'Value Paid',
  'Status',
];

const _personHeaders = [
  'Bidder Name',
  'Email',
  'Bookings',
  'Pieces',
  'Amount',
  'Paid',
  'Outstanding',
  'Items Collected',
  'Items Not Collected',
];

String _opt(DateTime? d) => d == null ? '' : _dateFmt.format(d);

List<List<Object>> _bidRows(List<Bid> bids, Map<String, BidStatus> st) => [
      for (var i = 0; i < bids.length; i++)
        () {
          final b = bids[i];
          final s = st[b.id] ?? BidStatus.none;
          return <Object>[
            i + 1,
            b.bidderName,
            b.email,
            b.itemName,
            b.quantity,
            b.unitPrice,
            b.total,
            _fmt(b.createdAt),
            s.paid ? 'Yes' : 'No',
            _opt(s.paidAt),
            s.collected ? 'Yes' : 'No',
            _opt(s.collectedAt),
            s.note,
          ];
        }(),
    ];

List<List<Object>> _itemRows(
        List<Item> items, List<Bid> bids, Map<String, BidStatus> st) =>
    [
      for (final it in items)
        [
          it.name,
          it.description,
          it.quantity,
          it.booked,
          it.remaining,
          it.price,
          it.price * it.booked,
          bids
              .where((b) => b.itemId == it.id && (st[b.id]?.paid ?? false))
              .fold<num>(0, (a, b) => a + b.total),
          it.soldOut ? 'Finished' : 'Available',
        ],
    ];

/// One row per person (grouped by email, or by name for older bids).
List<List<Object>> _personRows(List<Bid> bids, Map<String, BidStatus> st) {
  final groups = <String, List<Bid>>{};
  for (final b in bids) {
    final key = b.email.isNotEmpty ? b.email.toLowerCase() : b.bidderName.toLowerCase();
    groups.putIfAbsent(key, () => []).add(b);
  }
  final rows = groups.values.map((list) {
    final amount = list.fold<num>(0, (a, b) => a + b.total);
    final paid = list
        .where((b) => st[b.id]?.paid ?? false)
        .fold<num>(0, (a, b) => a + b.total);
    final collected = list.where((b) => st[b.id]?.collected ?? false).toList();
    final notCollected = list.where((b) => !(st[b.id]?.collected ?? false)).toList();
    String names(List<Bid> l) => l.map((b) => '${b.quantity} × ${b.itemName}').join('; ');
    return <Object>[
      list.last.bidderName,
      list.first.email,
      list.length,
      list.fold<int>(0, (a, b) => a + b.quantity),
      amount,
      paid,
      amount - paid,
      names(collected),
      names(notCollected),
    ];
  }).toList()
    ..sort((a, b) => (a[0] as String).toLowerCase().compareTo((b[0] as String).toLowerCase()));
  return rows;
}

String _stamp() => DateFormat('yyyyMMdd_HHmm').format(DateTime.now());

/// CSV of every bid (opens cleanly in Excel thanks to the BOM).
void downloadBidsCsv(List<Bid> bids, Map<String, BidStatus> statuses) {
  final csv =
      Csv(addBom: true).encode([_bidHeaders, ..._bidRows(bids, statuses)]);
  _download(
    Uint8List.fromList(utf8.encode(csv)),
    'ijm_disposal_bids_${_stamp()}.csv',
    'text/csv;charset=utf-8',
  );
}

/// Excel workbook with sheets "Bids", "Items Summary" and "By Person".
void downloadExcelReport(
    List<Bid> bids, List<Item> items, Map<String, BidStatus> statuses) {
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

  fill(excel['Bids'], _bidHeaders, _bidRows(bids, statuses));
  fill(excel['Items Summary'], _itemHeaders, _itemRows(items, bids, statuses));
  fill(excel['By Person'], _personHeaders, _personRows(bids, statuses));

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
