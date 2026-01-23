import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'add_event_screen.dart';

class AgendaScreen extends StatefulWidget {
  const AgendaScreen({super.key});

  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  DateTime _dataFocada = DateTime.now();
  DateTime _inicioDaSemana = DateTime.now();

  final TextEditingController _prioridadesController = TextEditingController();
  bool _isSavingPrioridades = false;

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
    _carregarPrioridades();
  }

  @override
  void dispose() {
    _prioridadesController.dispose();
    super.dispose();
  }

  void _calcularInicioSemana() {
    _inicioDaSemana = _dataFocada.subtract(Duration(days: _dataFocada.weekday - 1));
    _inicioDaSemana = DateTime(_inicioDaSemana.year, _inicioDaSemana.month, _inicioDaSemana.day);
  }

  String _getSemanaId() {
    return DateFormat('yyyy-MM-dd').format(_inicioDaSemana);
  }

  Future<void> _carregarPrioridades() async {
    String semanaId = _getSemanaId();
    _prioridadesController.text = "";

    try {
      var doc = await FirebaseFirestore.instance.collection('agenda_avisos').doc(semanaId).get();
      if (doc.exists && mounted) {
        setState(() {
          _prioridadesController.text = doc['texto'] ?? "";
        });
      }
    } catch (e) {
      print("Erro ao carregar prioridades: $e");
    }
  }

  Future<void> _salvarPrioridades() async {
    setState(() => _isSavingPrioridades = true);
    try {
      String semanaId = _getSemanaId();
      await FirebaseFirestore.instance.collection('agenda_avisos').doc(semanaId).set({
        'texto': _prioridadesController.text,
        'ultima_atualizacao': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Avisos salvos!"), backgroundColor: Colors.green));
        FocusScope.of(context).unfocus();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erro ao salvar."), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSavingPrioridades = false);
    }
  }

  void _trocarSemana(int semanas) {
    setState(() {
      _dataFocada = _dataFocada.add(Duration(days: 7 * semanas));
      _calcularInicioSemana();
    });
    _carregarPrioridades();
  }

  void _addEvent(DateTime dateForThisBox) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => AddEventScreen(preSelectedDate: dateForThisBox)));
  }

  void _editEvent(String id, Map<String, dynamic> data) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => AddEventScreen(eventId: id, eventData: data)));
  }

  Future<void> _deleteEvent(String id) async {
    bool confirm = await showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("Excluir"), 
      content: const Text("Apagar este evento permanentemente?"), 
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar")), 
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("EXCLUIR", style: TextStyle(color: Colors.red)))
      ]
    )) ?? false;
    
    if (confirm) await FirebaseFirestore.instance.collection('agenda').doc(id).delete();
  }

  // --- POPUP COM DETALHES ---
  // Agora recebe 'canManage' em vez de apenas 'isAdmin'
  void _showEventDetails(String id, Map<String, dynamic> data, bool canManage) {
    
    String hora = DateFormat('HH:mm').format((data['data_hora'] as Timestamp).toDate());
    String titulo = data['titulo'] ?? data['tipo'] ?? "Evento";
    String local = data['local'] ?? "Igreja";
    String dirigente = data['dirigente'] ?? "Não informado";
    String pregador = data['pregador'] ?? "Não informado";
    String descricao = data['descricao'] ?? "";

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Column(
            children: [
              Text(titulo.toUpperCase(), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              Text("Horário: $hora", style: TextStyle(fontSize: 14, color: Colors.grey[600])),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                _buildDetailRow(Icons.location_on, "Local:", local),
                const SizedBox(height: 8),
                _buildDetailRow(Icons.person, "Dirigente:", dirigente),
                const SizedBox(height: 8),
                _buildDetailRow(Icons.mic, "Pregador:", pregador),
                
                if (descricao.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text("Observações:", style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(descricao, style: TextStyle(color: Colors.grey[800])),
                ]
              ],
            ),
          ),
          actions: [
            // BOTÕES DE AÇÃO (SÓ SE TIVER PERMISSÃO)
            if (canManage) ...[
              TextButton.icon(
                icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                label: const Text("Excluir", style: TextStyle(color: Colors.red)),
                onPressed: () {
                  Navigator.pop(ctx); 
                  _deleteEvent(id);
                },
              ),
              TextButton.icon(
                icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                label: const Text("Editar", style: TextStyle(color: Colors.blue)),
                onPressed: () {
                  Navigator.pop(ctx); 
                  _editEvent(id, data); 
                },
              ),
            ],
            // BOTÃO FECHAR (PARA TODOS)
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Fechar"),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.indigo),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(color: Colors.black87, fontSize: 14),
              children: [
                TextSpan(text: "$label ", style: const TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return const Center(child: CircularProgressIndicator());

    // 1. STREAM PRINCIPAL: Verifica permissões
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, userSnapshot) {
        
        bool canManage = false;
        if (userSnapshot.hasData && userSnapshot.data!.exists) {
           final userData = userSnapshot.data!.data() as Map<String, dynamic>;
           String role = userData['role'] ?? 'membro';
           
           // --- MUDANÇA: ADMIN OU FINANCEIRO PODEM GERENCIAR A AGENDA ---
           canManage = role == 'admin' || role == 'financeiro';
        }

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
                  _carregarPrioridades();
                }, tooltip: "Semana Atual"),
              IconButton(icon: const Icon(Icons.arrow_forward_ios, size: 18), onPressed: () => _trocarSemana(1), tooltip: "Próxima Semana"),
            ],
          ),
          backgroundColor: Colors.grey[100],
          
          // 2. STREAM DA AGENDA
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
                  childAspectRatio: 0.55, 
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: 8,
                itemBuilder: (context, index) {
                  if (index < 7) {
                    DateTime dayDate = _inicioDaSemana.add(Duration(days: index));
                    // Passamos canManage para o card
                    return _buildDayCard(dayDate, allDocs, canManage);
                  } else {
                    // Passamos canManage para o card de avisos
                    return _buildPriorityCard(canManage);
                  }
                },
              );
            },
          ),
        );
      }
    );
  }

  Widget _buildDayCard(DateTime dayDate, List<QueryDocumentSnapshot> allDocs, bool canManage) {
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
                    String evento = data['tipo'] ?? (data['titulo'] ?? "Evento");
                    String local = data['local'] ?? "";
                    String dirigente = data['dirigente'] ?? "";
                    String pregador = data['pregador'] ?? "";
                    final colors = _eventColors[i % _eventColors.length];

                    return InkWell(
                      // Passa canManage para o popup
                      onTap: () => _showEventDetails(dayEvents[i].id, data, canManage),
                      borderRadius: BorderRadius.circular(8),
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
                            Text(
                              "$hora - ${evento.toUpperCase()}",
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.black87),
                              maxLines: 2, overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            if (local.isNotEmpty) Row(children: [Icon(Icons.location_on, size: 10, color: Colors.grey[700]), const SizedBox(width: 2), Expanded(child: Text(local, style: TextStyle(fontSize: 10, color: Colors.grey[800]), maxLines: 1, overflow: TextOverflow.ellipsis))]),
                            if (dirigente.isNotEmpty) Row(children: [Icon(Icons.person, size: 10, color: Colors.grey[700]), const SizedBox(width: 2), Expanded(child: Text("Dir: $dirigente", style: TextStyle(fontSize: 10, color: Colors.grey[800]), maxLines: 1, overflow: TextOverflow.ellipsis))]),
                            if (pregador.isNotEmpty) Row(children: [Icon(Icons.mic, size: 10, color: Colors.grey[700]), const SizedBox(width: 2), Expanded(child: Text("Preg: $pregador", style: TextStyle(fontSize: 10, color: Colors.grey[800]), maxLines: 1, overflow: TextOverflow.ellipsis))]),
                          ],
                        ),
                      ),
                    );
                  },
                ),
          ),

          // BOTÃO ADICIONAR (SÓ SE TIVER PERMISSÃO)
          if (canManage)
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

  Widget _buildPriorityCard(bool canManage) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.yellow[50], 
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade300, width: 2),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: Colors.orange[100], borderRadius: const BorderRadius.vertical(top: Radius.circular(10))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Expanded(
                  child: Text("Avisos", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.brown)),
                ),
                // ÍCONE DE SALVAR (SÓ SE TIVER PERMISSÃO)
                if (canManage)
                  SizedBox(
                    height: 24,
                    width: 24,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: _isSavingPrioridades 
                        ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.brown))
                        : const Icon(Icons.save, size: 18, color: Colors.brown),
                      onPressed: _salvarPrioridades,
                      tooltip: "Salvar Aviso",
                    ),
                  )
              ],
            ),
          ),
          
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              // SE FOR GESTOR: TextField Editável
              // SE NÃO: Texto simples (read-only)
              child: canManage 
                ? TextField( 
                    controller: _prioridadesController,
                    maxLines: 20, 
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                    decoration: const InputDecoration(
                      hintText: "Escreva os avisos da semana aqui...",
                      border: InputBorder.none,
                    ),
                  )
                : StreamBuilder<DocumentSnapshot>( 
                    stream: FirebaseFirestore.instance.collection('agenda_avisos').doc(_getSemanaId()).snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || !snapshot.data!.exists) {
                          return const Center(child: Text("Sem avisos.", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic, fontSize: 12)));
                      }
                      String texto = snapshot.data!['texto'] ?? "";
                      if (texto.isEmpty) return const Center(child: Text("Sem avisos.", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic, fontSize: 12)));
                      
                      return SingleChildScrollView(
                        child: Text(texto, style: const TextStyle(fontSize: 12, color: Colors.black87)),
                      );
                    },
                  ),
            ),
          ),
        ],
      ),
    );
  }
}