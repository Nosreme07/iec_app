import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../utils/admin_config.dart';
import 'add_event_screen.dart';

class AgendaScreen extends StatefulWidget {
  const AgendaScreen({super.key});

  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  DateTime _dataFocada = DateTime.now();
  DateTime _inicioDaSemana = DateTime.now();

  final List<Map<String, Color>> _eventColors = [
    {'bg': Colors.blue[50]!, 'border': Colors.blue[200]!},
    {'bg': Colors.green[50]!, 'border': Colors.green[200]!},
    {'bg': Colors.orange[50]!, 'border': Colors.orange[200]!},
    {'bg': Colors.purple[50]!, 'border': Colors.purple[200]!},
    {'bg': Colors.teal[50]!, 'border': Colors.teal[200]!},
  ];

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('pt_BR', null);
    _calcularInicioSemana();
  }

  void _calcularInicioSemana() {
    _inicioDaSemana = _dataFocada.subtract(Duration(days: _dataFocada.weekday - 1));
    _inicioDaSemana = DateTime(_inicioDaSemana.year, _inicioDaSemana.month, _inicioDaSemana.day);
    setState(() {});
  }

  void _trocarSemana(int semanas) {
    setState(() {
      _dataFocada = _dataFocada.add(Duration(days: 7 * semanas));
      _calcularInicioSemana();
    });
  }

  void _addEvent(DateTime dateForThisBox) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => AddEventScreen(preSelectedDate: dateForThisBox)));
  }

  void _editEvent(String id, Map<String, dynamic> data) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => AddEventScreen(eventId: id, eventData: data)));
  }

  Future<void> _deleteEvent(String id) async {
    bool confirm = await showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text("Excluir"), content: const Text("Apagar este evento?"), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar")), TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("EXCLUIR", style: TextStyle(color: Colors.red)))])) ?? false;
    if (confirm) await FirebaseFirestore.instance.collection('agenda').doc(id).delete();
  }

  @override
  Widget build(BuildContext context) {
    final bool isAdmin = AdminConfig.isUserAdmin();
    DateTime fimDaSemana = _inicioDaSemana.add(const Duration(days: 7));
    String intervaloTexto = "${DateFormat('dd MMM').format(_inicioDaSemana)} - ${DateFormat('dd MMM').format(fimDaSemana.subtract(const Duration(days: 1)))}";

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            const Text("Agenda Semanal", style: TextStyle(color: Colors.white, fontSize: 16)),
            Text(intervaloTexto, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
        backgroundColor: Colors.indigo,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(icon: const Icon(Icons.arrow_back_ios, size: 18), onPressed: () => _trocarSemana(-1), tooltip: "Semana Anterior"),
          IconButton(icon: const Icon(Icons.calendar_today, size: 20), onPressed: () {
              setState(() {
                _dataFocada = DateTime.now();
                _calcularInicioSemana();
              });
            }, tooltip: "Semana Atual"),
          IconButton(icon: const Icon(Icons.arrow_forward_ios, size: 18), onPressed: () => _trocarSemana(1), tooltip: "Próxima Semana"),
        ],
      ),
      backgroundColor: Colors.grey[100],
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('agenda')
            .where('data_hora', isGreaterThanOrEqualTo: Timestamp.fromDate(_inicioDaSemana))
            .where('data_hora', isLessThan: Timestamp.fromDate(fimDaSemana))
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text("Erro: ${snapshot.error}"));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          final allDocs = snapshot.data!.docs;

          return GridView.builder(
            padding: const EdgeInsets.all(10),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.55, // Aumentei um pouco a altura para caber tudo
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: 8,
            itemBuilder: (context, index) {
              if (index < 7) {
                DateTime dayDate = _inicioDaSemana.add(Duration(days: index));
                return _buildDayCard(dayDate, allDocs, isAdmin);
              } else {
                return _buildPriorityCard();
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildDayCard(DateTime dayDate, List<QueryDocumentSnapshot> allDocs, bool isAdmin) {
    String diaSemana = DateFormat('EEEE', 'pt_BR').format(dayDate);
    String diaMes = DateFormat('dd/MM').format(dayDate);
    bool isToday = dayDate.day == DateTime.now().day && dayDate.month == DateTime.now().month && dayDate.year == DateTime.now().year;

    List<QueryDocumentSnapshot> dayEvents = allDocs.where((doc) {
      Timestamp ts = doc['data_hora'];
      DateTime dt = ts.toDate();
      return dt.year == dayDate.year && dt.month == dayDate.month && dt.day == dayDate.day;
    }).toList();

    dayEvents.sort((a, b) => a['data_hora'].compareTo(b['data_hora']));

    return Container(
      decoration: BoxDecoration(
        color: isToday ? Colors.blue[50] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isToday ? Colors.blue : Colors.pink.shade100, width: isToday ? 2 : 2),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: isToday ? Colors.blue : Colors.pink[50],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Text("$diaSemana ($diaMes)", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isToday ? Colors.white : Colors.black87)),
          ),
          
          Expanded(
            child: dayEvents.isEmpty 
              ? const Center(child: Text("-", style: TextStyle(color: Colors.grey))) 
              : ListView.builder(
                  padding: const EdgeInsets.all(4),
                  itemCount: dayEvents.length,
                  itemBuilder: (ctx, i) {
                    final data = dayEvents[i].data() as Map<String, dynamic>;
                    String hora = DateFormat('HH:mm').format((data['data_hora'] as Timestamp).toDate());
                    // AGORA USAMOS 'TIPO' COMO NOME DO EVENTO
                    String evento = data['tipo'] ?? (data['titulo'] ?? "Evento"); 
                    String local = data['local'] ?? "";
                    String dirigente = data['dirigente'] ?? "";
                    String pregador = data['pregador'] ?? "";
                    final colors = _eventColors[i % _eventColors.length];

                    return InkWell(
                      onTap: isAdmin ? () => _editEvent(dayEvents[i].id, data) : null,
                      onLongPress: isAdmin ? () => _deleteEvent(dayEvents[i].id) : null,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: colors['bg'],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: colors['border']!, width: 1),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. HORA - EVENTO (Negrito)
                            Text(
                              "$hora - ${evento.toUpperCase()}",
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.black87),
                              maxLines: 2, overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            
                            // 2. LOCAL
                            if (local.isNotEmpty)
                              Row(children: [
                                Icon(Icons.location_on, size: 10, color: Colors.grey[700]),
                                const SizedBox(width: 2),
                                Expanded(child: Text(local, style: TextStyle(fontSize: 10, color: Colors.grey[800]), maxLines: 1, overflow: TextOverflow.ellipsis)),
                              ]),

                            // 3. DIRIGENTE
                            if (dirigente.isNotEmpty)
                              Row(children: [
                                Icon(Icons.person, size: 10, color: Colors.grey[700]),
                                const SizedBox(width: 2),
                                Expanded(child: Text("Dir: $dirigente", style: TextStyle(fontSize: 10, color: Colors.grey[800]), maxLines: 1, overflow: TextOverflow.ellipsis)),
                              ]),

                            // 4. PREGADOR
                            if (pregador.isNotEmpty)
                              Row(children: [
                                Icon(Icons.mic, size: 10, color: Colors.grey[700]),
                                const SizedBox(width: 2),
                                Expanded(child: Text("Preg: $pregador", style: TextStyle(fontSize: 10, color: Colors.grey[800]), maxLines: 1, overflow: TextOverflow.ellipsis)),
                              ]),
                          ],
                        ),
                      ),
                    );
                  },
                ),
          ),

          if (isAdmin)
            InkWell(
              onTap: () => _addEvent(dayDate),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.pink.shade100))),
                child: const Icon(Icons.add_circle, color: Colors.indigo, size: 22),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPriorityCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200, width: 2),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(color: Colors.orange[50], borderRadius: const BorderRadius.vertical(top: Radius.circular(10))),
            child: const Text("Prioridades", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
          ),
          const Expanded(
            child: Padding(
              padding: EdgeInsets.all(8.0),
              child: TextField(
                maxLines: 10,
                decoration: InputDecoration(hintText: "Anotações...", border: InputBorder.none),
                style: TextStyle(fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}