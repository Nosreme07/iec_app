import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

// Certifique-se que estes arquivos existem no seu projeto com estes nomes
import 'add_event_screen.dart'; 
import '../services/pdf_generator.dart'; 

// ==========================================
// TELA PRINCIPAL (CONTROLLER DAS ABAS)
// ==========================================
class UnifiedAgendaScreen extends StatelessWidget {
  const UnifiedAgendaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // DefaultTabController gerencia a troca entre as abas
    return DefaultTabController(
      length: 2, // Quantidade de abas
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Agenda da Igreja", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.blue[900], 
          iconTheme: const IconThemeData(color: Colors.white),
          // A TabBar fica na parte inferior da AppBar
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: "SEMANAL", icon: Icon(Icons.calendar_view_week)),
              Tab(text: "ANUAL", icon: Icon(Icons.calendar_month)),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            WeeklyAgendaTab(), // O conteúdo da aba 1
            AnnualAgendaTab(), // O conteúdo da aba 2
          ],
        ),
      ),
    );
  }
}

// ==========================================
// ABA 1: LÓGICA DA AGENDA SEMANAL
// ==========================================
class WeeklyAgendaTab extends StatefulWidget {
  const WeeklyAgendaTab({super.key});

  @override
  State<WeeklyAgendaTab> createState() => _WeeklyAgendaTabState();
}

class _WeeklyAgendaTabState extends State<WeeklyAgendaTab> {
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
    // Pega a data atual e volta até a segunda-feira (ou domingo, dependendo da lógica desejada)
    _inicioDaSemana = _dataFocada.subtract(Duration(days: _dataFocada.weekday - 1));
    // Zera as horas para evitar problemas de comparação
    _inicioDaSemana = DateTime(_inicioDaSemana.year, _inicioDaSemana.month, _inicioDaSemana.day);
  }

  String _getSemanaId() {
    return DateFormat('yyyy-MM-dd').format(_inicioDaSemana);
  }

  Future<void> _carregarPrioridades() async {
    String semanaId = _getSemanaId();
    try {
      var doc = await FirebaseFirestore.instance.collection('agenda_avisos').doc(semanaId).get();
      if (doc.exists && mounted) {
        setState(() {
          _prioridadesController.text = doc['texto'] ?? "";
        });
      } else {
        if (mounted) setState(() => _prioridadesController.text = "");
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
        'autor_uid': FirebaseAuth.instance.currentUser?.uid,
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Avisos salvos!"), backgroundColor: Colors.green));
        FocusScope.of(context).unfocus();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro: $e"), backgroundColor: Colors.red));
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

  void _showEventDetails(String id, Map<String, dynamic> data, bool canManage) {
    Timestamp? ts = data['data_hora'] as Timestamp?;
    String hora = ts != null ? DateFormat('HH:mm').format(ts.toDate()) : "--:--";
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
            if (canManage) ...[
              TextButton.icon(
                icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                label: const Text("Excluir", style: TextStyle(color: Colors.red)),
                onPressed: () { Navigator.pop(ctx); _deleteEvent(id); },
              ),
              TextButton.icon(
                icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                label: const Text("Editar", style: TextStyle(color: Colors.blue)),
                onPressed: () { Navigator.pop(ctx); _editEvent(id, data); },
              ),
            ],
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Fechar")),
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

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, userSnapshot) {
        
        // Verifica permissão (Admin ou Financeiro)
        bool canManage = false;
        if (userSnapshot.hasData && userSnapshot.data!.exists) {
           final userData = userSnapshot.data!.data() as Map<String, dynamic>;
           String role = userData['role'] ?? 'membro';
           canManage = role == 'admin' || role == 'financeiro';
        }

        DateTime fimDaSemana = _inicioDaSemana.add(const Duration(days: 7));
        String intervaloTexto = "${DateFormat('dd MMM').format(_inicioDaSemana)} - ${DateFormat('dd MMM').format(fimDaSemana.subtract(const Duration(days: 1)))}";

        // Usamos Column aqui pois o Scaffold já está no pai (UnifiedAgendaScreen)
        return Column(
          children: [
            // --- BARRA DE CONTROLE DA SEMANA ---
            Container(
              color: Colors.indigo.withOpacity(0.1),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(icon: const Icon(Icons.arrow_back_ios, size: 18), onPressed: () => _trocarSemana(-1), tooltip: "Semana Anterior"),
                  Column(
                    children: [
                      Text("Semana Atual", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo[900])),
                      Text(intervaloTexto, style: TextStyle(color: Colors.indigo[700], fontSize: 12)),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(icon: const Icon(Icons.calendar_today, size: 20), onPressed: () {
                          setState(() {
                            _dataFocada = DateTime.now();
                            _calcularInicioSemana();
                          });
                          _carregarPrioridades();
                        }, tooltip: "Hoje"),
                      IconButton(icon: const Icon(Icons.arrow_forward_ios, size: 18), onPressed: () => _trocarSemana(1), tooltip: "Próxima Semana"),
                    ],
                  )
                ],
              ),
            ),
            
            // --- CONTEÚDO (GRID DE DIAS) ---
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
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
                      crossAxisCount: 2, // 2 colunas
                      childAspectRatio: 0.55, // Ajuste a altura dos cards
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: 8, // 7 dias da semana + 1 card de avisos
                    itemBuilder: (context, index) {
                      if (index < 7) {
                        DateTime dayDate = _inicioDaSemana.add(Duration(days: index));
                        return _buildDayCard(dayDate, allDocs, canManage);
                      } else {
                        // O último card é o de Avisos
                        return _buildPriorityCard(canManage);
                      }
                    },
                  );
                },
              ),
            ),
          ],
        );
      }
    );
  }

  Widget _buildDayCard(DateTime dayDate, List<QueryDocumentSnapshot> allDocs, bool canManage) {
    String diaSemana = DateFormat('EEEE', 'pt_BR').format(dayDate);
    String diaMes = DateFormat('dd/MM').format(dayDate);
    bool isToday = dayDate.day == DateTime.now().day && dayDate.month == DateTime.now().month && dayDate.year == DateTime.now().year;

    List<QueryDocumentSnapshot> dayEvents = allDocs.where((doc) {
      Timestamp? ts = doc['data_hora'] as Timestamp?;
      if (ts == null) return false;
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
                    Timestamp? ts = data['data_hora'] as Timestamp?;
                    String hora = ts != null ? DateFormat('HH:mm').format(ts.toDate()) : "--:--";
                    String evento = data['tipo'] ?? (data['titulo'] ?? "Evento");
                    String local = data['local'] ?? "";
                    String dirigente = data['dirigente'] ?? "";
                    String pregador = data['pregador'] ?? "";
                    final colors = _eventColors[i % _eventColors.length];

                    return InkWell(
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
                            if (local.isNotEmpty) Text(local, style: TextStyle(fontSize: 10, color: Colors.grey[800]), maxLines: 1, overflow: TextOverflow.ellipsis),
                            if (dirigente.isNotEmpty) Text("Dir: $dirigente", style: TextStyle(fontSize: 10, color: Colors.grey[800]), maxLines: 1, overflow: TextOverflow.ellipsis),
                            if (pregador.isNotEmpty) Text("Preg: $pregador", style: TextStyle(fontSize: 10, color: Colors.grey[800]), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    );
                  },
                ),
          ),

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
              child: canManage 
                ? TextField( 
                    controller: _prioridadesController,
                    maxLines: 20, 
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                    decoration: const InputDecoration(hintText: "Escreva os avisos...", border: InputBorder.none),
                  )
                : StreamBuilder<DocumentSnapshot>( 
                    stream: FirebaseFirestore.instance.collection('agenda_avisos').doc(_getSemanaId()).snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || !snapshot.data!.exists) {
                          return const Center(child: Text("Sem avisos.", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic, fontSize: 12)));
                      }
                      String texto = snapshot.data!['texto'] ?? "";
                      if (texto.isEmpty) return const Center(child: Text("Sem avisos.", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic, fontSize: 12)));
                      
                      return SingleChildScrollView(child: Text(texto, style: const TextStyle(fontSize: 12, color: Colors.black87)));
                    },
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// ABA 2: LÓGICA DA AGENDA ANUAL
// ==========================================
class AnnualAgendaTab extends StatefulWidget {
  const AnnualAgendaTab({super.key});

  @override
  State<AnnualAgendaTab> createState() => _AnnualAgendaTabState();
}

class _AnnualAgendaTabState extends State<AnnualAgendaTab> {
  int _anoSelecionado = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('pt_BR', null);
  }

  void _trocarAno(int delta) {
    setState(() => _anoSelecionado += delta);
  }

  void _addAnnualEvent() {
    Navigator.push(
      context, 
      MaterialPageRoute(builder: (context) => const AddEventScreen(isAnnual: true))
    );
  }

  Future<void> _printCalendar() async {
    DateTime inicioAno = DateTime(_anoSelecionado, 1, 1);
    DateTime fimAno = DateTime(_anoSelecionado, 12, 31, 23, 59, 59);

    showDialog(
      context: context, 
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator())
    );

    try {
      var snapshot = await FirebaseFirestore.instance
          .collection('agenda')
          .where('data_hora', isGreaterThanOrEqualTo: Timestamp.fromDate(inicioAno))
          .where('data_hora', isLessThanOrEqualTo: Timestamp.fromDate(fimAno))
          .where('is_annual', isEqualTo: true)
          .get();

      if (mounted) Navigator.pop(context);

      await PdfGenerator.generateAndPrint(_anoSelecionado, snapshot.docs);
      
    } catch (e) {
      if (mounted) Navigator.pop(context); 
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao gerar PDF: $e")));
    }
  }

  void _editAnnualEvent(String id, Map<String, dynamic> data) {
    Navigator.pop(context);
    Navigator.push(
      context, 
      MaterialPageRoute(
        builder: (context) => AddEventScreen(
          eventId: id, 
          eventData: data, 
          isAnnual: true
        )
      )
    );
  }

  Future<void> _deleteEvent(String id) async {
    Navigator.pop(context); 
    
    bool confirm = await showDialog(
      context: context, 
      builder: (ctx) => AlertDialog(
        title: const Text("Excluir Evento"), 
        content: const Text("Tem certeza que deseja apagar este evento anual?"), 
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar")), 
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("EXCLUIR", style: TextStyle(color: Colors.red)))
        ]
      )
    ) ?? false;

    if (confirm) {
      await FirebaseFirestore.instance.collection('agenda').doc(id).delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return const Center(child: CircularProgressIndicator());

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, userSnapshot) {
        
        bool canManage = false;
        if (userSnapshot.hasData && userSnapshot.data!.exists) {
           final userData = userSnapshot.data!.data() as Map<String, dynamic>;
           String role = userData['role'] ?? 'membro';
           canManage = role == 'admin' || role == 'financeiro';
        }

        DateTime inicioAno = DateTime(_anoSelecionado, 1, 1);
        DateTime fimAno = DateTime(_anoSelecionado, 12, 31, 23, 59, 59);

        // Usamos Scaffold aqui apenas para ter o FloatingActionButton na aba
        return Scaffold(
          backgroundColor: Colors.transparent, 
          floatingActionButton: canManage 
            ? FloatingActionButton.extended(
                onPressed: _addAnnualEvent,
                backgroundColor: Colors.purple,
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text("Novo Evento", style: TextStyle(color: Colors.white)),
              )
            : null,
          body: Column(
            children: [
              // --- BARRA DE CONTROLE DO ANO ---
               Container(
                color: Colors.purple.withOpacity(0.1),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        IconButton(icon: const Icon(Icons.arrow_back_ios, size: 16), onPressed: () => _trocarAno(-1)),
                        Text("$_anoSelecionado", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.purple[800])),
                        IconButton(icon: const Icon(Icons.arrow_forward_ios, size: 16), onPressed: () => _trocarAno(1)),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.print, size: 24, color: Colors.purple),
                      tooltip: "Exportar PDF",
                      onPressed: _printCalendar,
                    ),
                  ],
                ),
              ),

              // --- CONTEÚDO LISTA DE MESES ---
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('agenda')
                      .where('data_hora', isGreaterThanOrEqualTo: Timestamp.fromDate(inicioAno))
                      .where('data_hora', isLessThanOrEqualTo: Timestamp.fromDate(fimAno))
                      .where('is_annual', isEqualTo: true) 
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) return const Center(child: Text("Erro ao carregar agenda"));
                    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

                    List<DocumentSnapshot> eventosAnuais = snapshot.data!.docs;

                    return ListView.builder(
                      padding: const EdgeInsets.all(10),
                      itemCount: 12,
                      itemBuilder: (context, index) {
                        int mes = index + 1;
                        return _buildMonthGrid(mes, eventosAnuais, canManage);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildMonthGrid(int month, List<DocumentSnapshot> eventosDoAno, bool canManage) {
    DateTime dataBase = DateTime(_anoSelecionado, month, 1);
    String nomeMes = DateFormat('MMMM', 'pt_BR').format(dataBase);
    
    // Filtra eventos deste mês específico
    List<DocumentSnapshot> eventosMes = eventosDoAno.where((doc) {
      DateTime data = (doc['data_hora'] as Timestamp).toDate();
      return data.month == month;
    }).toList();

    int diasNoMes = DateUtils.getDaysInMonth(_anoSelecionado, month);
    int primeiroDiaSemana = dataBase.weekday; 
    int offset = primeiroDiaSemana - 1; 

    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          // Título do Mês
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: const BoxDecoration(
              color: Color.fromARGB(255, 212, 120, 228),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Text(
              nomeMes.toUpperCase(),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: ["Seg", "Ter", "Qua", "Qui", "Sex", "Sáb", "Dom"]
                      .map((d) => Text(d, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey[700])))
                      .toList(),
                ),
                const Divider(),
                
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: diasNoMes + offset,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    childAspectRatio: 1.0,
                  ),
                  itemBuilder: (context, index) {
                    if (index < offset) return const SizedBox(); 
                    
                    int dia = index - offset + 1;
                    
                    var eventosDia = eventosMes.where((doc) {
                      DateTime d = (doc['data_hora'] as Timestamp).toDate();
                      return d.day == dia;
                    }).toList();

                    bool temEvento = eventosDia.isNotEmpty;

                    return InkWell(
                      onTap: temEvento ? () => _showEventDetails(dia, month, eventosDia, canManage) : null,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: temEvento ? const Color.fromARGB(255, 212, 120, 228) : Colors.transparent, 
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          "$dia",
                          style: TextStyle(
                            fontWeight: temEvento ? FontWeight.bold : FontWeight.normal,
                            color: temEvento ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showEventDetails(int dia, int mes, List<DocumentSnapshot> eventos, bool canManage) {
    String dataFormatada = "$dia/${mes.toString().padLeft(2, '0')}/$_anoSelecionado";

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Column(
            children: [
              const Icon(Icons.event, color: Colors.purple, size: 40),
              const SizedBox(height: 8),
              Text("Eventos de $dataFormatada", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: eventos.length,
              separatorBuilder: (c, i) => const Divider(),
              itemBuilder: (ctx, i) {
                var doc = eventos[i];
                var data = doc.data() as Map<String, dynamic>;
                String hora = DateFormat('HH:mm').format((data['data_hora'] as Timestamp).toDate());
                String titulo = data['titulo'] ?? data['tipo'];
                String local = data['local'] ?? "Local não informado";

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.purple[50], shape: BoxShape.circle),
                    child: const Icon(Icons.star, color: Colors.purple, size: 20),
                  ),
                  title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("$hora - $local", style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                      if (data['dirigente'] != null && data['dirigente'].toString().isNotEmpty)
                        Text("Dir: ${data['dirigente']}", style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                    ],
                  ),
                  trailing: canManage 
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _editAnnualEvent(doc.id, data),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteEvent(doc.id),
                          ),
                        ],
                      )
                    : null,
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), 
              child: const Text("Fechar", style: TextStyle(color: Colors.purple))
            )
          ],
        );
      },
    );
  }
}