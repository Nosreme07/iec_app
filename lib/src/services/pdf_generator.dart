import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart' as material;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/holiday_util.dart';

class PdfGenerator {
  
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
              // 1. CABEÇALHO
              _buildHeader(),
              
              pw.SizedBox(height: 5),
              
              // 2. TÍTULO
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

              // 3. GRADE DOS 12 MESES
              pw.Expanded(
                child: pw.GridView(
                  crossAxisCount: 3,
                  childAspectRatio: 0.92, // Mantemos a proporção do cartão que funcionou na página
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

  static pw.Widget _buildHeader() {
    return pw.Column(
      children: [
        pw.Text("Igreja Evangélica Congregacional em Moreno", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 2),
        pw.Text("Rua Luiz Cavalcante Lins, 353. Alto da Liberdade - Moreno/PE CEP: 54.806-163", style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
        pw.Text("CNPJ: 30.057.670.0001-05", style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
        pw.SizedBox(height: 2),
        pw.Divider(thickness: 0.5, color: PdfColors.grey500),
      ],
    );
  }

  static pw.Widget _buildMonthCard(int month, int year, List<QueryDocumentSnapshot> allEvents, Map<DateTime, String> holidays) {
    DateTime dateBase = DateTime(year, month, 1);
    String monthName = DateFormat('MMMM', 'pt_BR').format(dateBase).toUpperCase();

    List<Map<String, dynamic>> monthEvents = [];
    
    // Feriados
    holidays.forEach((date, name) {
      if (date.month == month && date.year == year) {
        monthEvents.add({'day': date.day, 'title': name, 'type': 'holiday'});
      }
    });

    // Eventos
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
          // Header Vermelho do Mês
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
                  // CALENDÁRIO (Agora com mais altura)
                  _buildCompactCalendarGrid(year, month, daysWithEvents, daysWithHolidays),
                  
                  pw.SizedBox(height: 4), // Mais espaço entre o calendário e a linha
                  pw.Divider(thickness: 0.5, color: PdfColors.grey200),
                  
                  // LISTA DE EVENTOS
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
        // Cabeçalho dos Dias (S T Q...)
        pw.TableRow(
          children: weekDays.map((d) => pw.Center(child: pw.Text(d, style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)))).toList()
        ),
        
        // Linhas dos Números
        ...List.generate((daysInMonth + offset) ~/ 7 + 1, (rowIndex) {
          return pw.TableRow(
            children: List.generate(7, (colIndex) {
              int day = rowIndex * 7 + colIndex - offset + 1;
              
              // Células vazias
              if (day < 1 || day > daysInMonth) return pw.SizedBox(height: 13); // Altura consistente mesmo nas vazias

              // Cores e Estilos
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
                height: 13, // AUMENTADO: Era 5, agora 13. Isso resolve o achatamento!
                alignment: pw.Alignment.center,
                decoration: bgColor != null ? pw.BoxDecoration(color: bgColor, shape: pw.BoxShape.circle) : null,
                child: pw.Text(
                  "$day", 
                  style: pw.TextStyle(
                    fontSize: 7, // AUMENTADO: Era 5, agora 7 para melhor leitura
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