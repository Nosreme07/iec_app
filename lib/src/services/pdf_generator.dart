import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart' as material;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/holiday_util.dart';

class PdfGenerator {
  
  // ===========================================================================
  // 1. FUNÇÃO DA AGENDA ANUAL (MANTIDA)
  // ===========================================================================
  static Future<void> generateAndPrint(int year, List<QueryDocumentSnapshot> events) async {
    final pdf = pw.Document();
    final holidays = HolidayUtil.getHolidays(year);

    final fontRegular = await PdfGoogleFonts.openSansRegular();
    final fontBold = await PdfGoogleFonts.openSansBold();

    pdf.addPage(
      pw.Page(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 15, vertical: 15),
          theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
        ),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              pw.SizedBox(height: 5),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                color: PdfColors.grey200,
                child: pw.Text(
                  "AGENDA ANUAL $year", 
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                  textAlign: pw.TextAlign.center
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Expanded(
                child: pw.GridView(
                  crossAxisCount: 3,
                  childAspectRatio: 0.92,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  children: List.generate(12, (index) {
                    return _buildMonthCard(index + 1, year, events, holidays);
                  }),
                ),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  // ===========================================================================
  // 2. RELATÓRIO FINANCEIRO (CORRIGIDO E AJUSTADO)
  // ===========================================================================
  static Future<void> generateFinanceReport(DateTime mesReferencia, List<QueryDocumentSnapshot> docs) async {
    final pdf = pw.Document();
    
    // Fontes
    final fontRegular = await PdfGoogleFonts.openSansRegular();
    final fontBold = await PdfGoogleFonts.openSansBold();

    // Formatadores
    final currencyFormat = NumberFormat.simpleCurrency(locale: 'pt_BR');
    final dateFormat = DateFormat('dd/MM/yyyy');
    final monthFormat = DateFormat('MMMM yyyy', 'pt_BR');

    // Cálculos
    double totalEntrada = 0;
    double totalSaida = 0;
    
    final List<List<String>> tableData = [];

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      double valor = (data['valor'] ?? 0).toDouble();
      bool isEntrada = data['tipo'] == 'entrada';
      
      if (isEntrada) totalEntrada += valor;
      else totalSaida += valor;

      tableData.add([
        dateFormat.format((data['data'] as Timestamp).toDate()), // Data
        data['nome'] ?? '', // Nome
        data['categoria'] ?? '', // Categoria
        data['descricao'] ?? '', // Observações
        isEntrada ? 'Entrada' : 'Saída', // Tipo
        currencyFormat.format(valor), // Valor
      ]);
    }

    double saldo = totalEntrada - totalSaida;

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(30),
          theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
        ),
        header: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              pw.SizedBox(height: 10),
              pw.Center(
                child: pw.Text(
                  "RELATÓRIO FINANCEIRO - ${monthFormat.format(mesReferencia).toUpperCase()}",
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 15),
            ],
          );
        },
        footer: (pw.Context context) {
          return pw.Column(
            children: [
              pw.SizedBox(height: 30),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly, 
                children: [
                  _buildSignatureLine("Tesoureiro"),
                  _buildSignatureLine("Pr. Presidente"),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  "Gerado em: ${dateFormat.format(DateTime.now())} - Página ${context.pageNumber} de ${context.pagesCount}",
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                ),
              ),
            ],
          );
        },
        build: (pw.Context context) {
          return [
            // 1. QUADRO DE TOTAIS
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
                color: PdfColors.grey100,
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  _buildTotalItem("Total de Entrada:", totalEntrada, PdfColors.green800, currencyFormat),
                  _buildTotalItem("Total de Saída:", totalSaida, PdfColors.red800, currencyFormat),
                  pw.Container(width: 1, height: 20, color: PdfColors.grey400),
                  _buildTotalItem("Saldo Mensal:", saldo, saldo >= 0 ? PdfColors.blue800 : PdfColors.red800, currencyFormat, isBold: true),
                ],
              ),
            ),
            
            pw.SizedBox(height: 15),

            // 2. TABELA DE DADOS
            pw.Table.fromTextArray(
              headers: ['Data', 'Nome', 'Categoria', 'Obs', 'Tipo', 'Valor'],
              data: tableData,
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
              
              // --- AQUI ESTÁ O AJUSTE DA FONTE ---
              cellStyle: const pw.TextStyle(fontSize: 8), // Fonte menor para caber
              cellHeight: 22,
              
              columnWidths: {
                0: const pw.FixedColumnWidth(60),  // Aumentado de 50 para 60 para a Data caber
                1: const pw.FlexColumnWidth(2),    // Nome
                2: const pw.FlexColumnWidth(1.5),  // Categoria
                3: const pw.FlexColumnWidth(2),    // Obs
                4: const pw.FixedColumnWidth(40),  // Tipo
                5: const pw.FixedColumnWidth(60),  // Valor
              },
              cellAlignments: {
                0: pw.Alignment.center,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.centerLeft,
                4: pw.Alignment.center,
                5: pw.Alignment.centerRight,
              },
              oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey50),
            ),
          ];
        },
      ),
    );

    String nomeArquivo = 'Financeiro_${DateFormat('MM_yyyy').format(mesReferencia)}.pdf';
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: nomeArquivo
    );
  }

  // ===========================================================================
  // WIDGETS AUXILIARES
  // ===========================================================================

  static pw.Widget _buildHeader() {
    return pw.Column(
      children: [
        pw.Text("Igreja Evangélica Congregacional em Moreno", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 2),
        pw.Text("Rua Luiz Cavalcante Lins, 353. Alto da Liberdade - Moreno/PE", style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        pw.Text("CNPJ: 30.057.670.0001-05", style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        pw.SizedBox(height: 5),
        pw.Divider(thickness: 1, color: PdfColors.grey400),
      ],
    );
  }

  static pw.Widget _buildTotalItem(String label, double value, PdfColor color, NumberFormat format, {bool isBold = false}) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.black)),
        pw.Text(
          format.format(value),
          style: pw.TextStyle(fontSize: 11, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color),
        ),
      ],
    );
  }

  static pw.Widget _buildSignatureLine(String label) {
    return pw.Column(
      children: [
        pw.Container(
          width: 150,
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 1)),
          ),
        ),
        pw.SizedBox(height: 5),
        pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
      ],
    );
  }

  // --- CORREÇÃO DO WITHOPACITY (FINANCE SUMMARY CARD) ---
  static pw.Widget _buildFinanceSummaryCard(String title, double value, PdfColor color) {
    final currencyFormat = NumberFormat.simpleCurrency(locale: 'pt_BR');
    
    // Criando a cor de fundo manualmente (R, G, B, Opacidade)
    final backgroundColor = PdfColor(color.red, color.green, color.blue, 0.1);

    return pw.Container(
      width: 150,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: color, width: 1),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        color: backgroundColor, // Uso da cor corrigida
      ),
      child: pw.Column(
        children: [
          pw.Text(title, style: pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
          pw.SizedBox(height: 4),
          pw.Text(
            currencyFormat.format(value),
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  // --- MÉTODOS DA AGENDA ANUAL (Mantidos) ---
  static pw.Widget _buildMonthCard(int month, int year, List<QueryDocumentSnapshot> allEvents, Map<DateTime, String> holidays) {
    DateTime dateBase = DateTime(year, month, 1);
    String monthName = DateFormat('MMMM', 'pt_BR').format(dateBase).toUpperCase();

    List<Map<String, dynamic>> monthEvents = [];
    
    holidays.forEach((date, name) {
      if (date.month == month && date.year == year) {
        monthEvents.add({'day': date.day, 'title': name, 'type': 'holiday'});
      }
    });

    var churchEvents = allEvents.where((doc) {
      DateTime d = (doc['data_hora'] as Timestamp).toDate();
      return d.month == month && d.year == year;
    });

    for (var doc in churchEvents) {
      var data = doc.data() as Map<String, dynamic>;
      DateTime d = (data['data_hora'] as Timestamp).toDate();
      monthEvents.add({
        'day': d.day,
        'title': data['titulo'] ?? data['tipo'], 
        'type': 'church'
      });
    }

    monthEvents.sort((a, b) => (a['day'] as int).compareTo(b['day'] as int));

    Set<int> daysWithEvents = monthEvents.map((e) => e['day'] as int).toSet();
    Set<int> daysWithHolidays = monthEvents.where((e) => e['type'] == 'holiday').map((e) => e['day'] as int).toSet();

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        children: [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(vertical: 2),
            decoration: const pw.BoxDecoration(
              color: PdfColors.red800,
              borderRadius: pw.BorderRadius.vertical(top: pw.Radius.circular(4)),
            ),
            child: pw.Text(monthName, textAlign: pw.TextAlign.center, style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 8)),
          ),
          
          pw.Expanded(
            child: pw.Padding(
              padding: const pw.EdgeInsets.all(3),
              child: pw.Column(
                children: [
                  _buildCompactCalendarGrid(year, month, daysWithEvents, daysWithHolidays),
                  pw.SizedBox(height: 4), 
                  pw.Divider(thickness: 0.5, color: PdfColors.grey200),
                  
                  if (monthEvents.isNotEmpty)
                    pw.Expanded(
                      child: pw.Column(
                        children: monthEvents.take(5).map((e) { 
                          bool isHol = e['type'] == 'holiday';
                          return pw.Padding(
                            padding: const pw.EdgeInsets.only(bottom: 1),
                            child: pw.Row(
                              children: [
                                pw.Text("${e['day']}: ", style: pw.TextStyle(fontSize: 5, fontWeight: pw.FontWeight.bold, color: isHol ? PdfColors.red800 : PdfColors.purple800)),
                                pw.Expanded(child: pw.Text(e['title'], maxLines: 1, overflow: pw.TextOverflow.clip, style: const pw.TextStyle(fontSize: 5))),
                              ],
                            ),
                          );
                        }).toList(),
                      )
                    )
                  else
                     pw.Spacer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildCompactCalendarGrid(int year, int month, Set<int> eventDays, Set<int> holidayDays) {
    final daysInMonth = material.DateUtils.getDaysInMonth(year, month);
    final firstWeekday = DateTime(year, month, 1).weekday;
    final offset = firstWeekday - 1; 

    final List<String> weekDays = ['S', 'T', 'Q', 'Q', 'S', 'S', 'D'];

    return pw.Table(
      children: [
        pw.TableRow(
          children: weekDays.map((d) => pw.Center(child: pw.Text(d, style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)))).toList()
        ),
        
        ...List.generate((daysInMonth + offset) ~/ 7 + 1, (rowIndex) {
          return pw.TableRow(
            children: List.generate(7, (colIndex) {
              int day = rowIndex * 7 + colIndex - offset + 1;
              if (day < 1 || day > daysInMonth) return pw.SizedBox(height: 13); 

              bool isHoliday = holidayDays.contains(day);
              bool isChurchEvent = eventDays.contains(day) && !isHoliday;

              PdfColor? bgColor;
              PdfColor textColor = PdfColors.black;

              if (isHoliday) {
                bgColor = PdfColors.red100;
                textColor = PdfColors.red900;
              } else if (isChurchEvent) {
                bgColor = PdfColors.purple100;
                textColor = PdfColors.purple900;
              }

              return pw.Container(
                height: 13, 
                alignment: pw.Alignment.center,
                decoration: bgColor != null ? pw.BoxDecoration(color: bgColor, shape: pw.BoxShape.circle) : null,
                child: pw.Text(
                  "$day", 
                  style: pw.TextStyle(
                    fontSize: 7, 
                    color: textColor, 
                    fontWeight: (isHoliday || isChurchEvent) ? pw.FontWeight.bold : pw.FontWeight.normal
                  )
                ),
              );
            }),
          );
        })
      ]
    );
  }
}