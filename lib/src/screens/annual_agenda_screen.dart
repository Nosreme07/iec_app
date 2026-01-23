import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'add_event_screen.dart';
import '../services/pdf_generator.dart'; 

class AnnualAgendaScreen extends StatefulWidget {
  const AnnualAgendaScreen({super.key});

  @override
  State<AnnualAgendaScreen> createState() => _AnnualAgendaScreenState();
}

class _AnnualAgendaScreenState extends State<AnnualAgendaScreen> {
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

  // --- FUNÇÃO DE IMPRESSÃO ---
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

  // --- LÓGICA DE EDIÇÃO ---
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

  // --- LÓGICA DE EXCLUSÃO ---
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

    // 1. STREAM PARA VERIFICAR PERMISSÕES
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, userSnapshot) {
        
        bool canManage = false;
        if (userSnapshot.hasData && userSnapshot.data!.exists) {
           final userData = userSnapshot.data!.data() as Map<String, dynamic>;
           String role = userData['role'] ?? 'membro';
           
           // --- MUDANÇA: Admin OU Financeiro têm poder total ---
           canManage = role == 'admin' || role == 'financeiro';
        }

        DateTime inicioAno = DateTime(_anoSelecionado, 1, 1);
        DateTime fimAno = DateTime(_anoSelecionado, 12, 31, 23, 59, 59);

        return Scaffold(
          appBar: AppBar(
            title: const Text("Agenda Anual", style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.purple,
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              IconButton(icon: const Icon(Icons.arrow_back_ios, size: 16), onPressed: () => _trocarAno(-1)),
              Text("$_anoSelecionado", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
              IconButton(icon: const Icon(Icons.arrow_forward_ios, size: 16), onPressed: () => _trocarAno(1)),
              
              const SizedBox(width: 10),
              
              // --- BOTÃO DE IMPRIMIR ---
              IconButton(
                icon: const Icon(Icons.print, size: 22),
                tooltip: "Exportar PDF",
                onPressed: _printCalendar,
              ),
              const SizedBox(width: 10),
            ],
          ),
          backgroundColor: Colors.grey[100],
          
          // BOTÃO NOVO EVENTO (SÓ PARA QUEM TEM PERMISSÃO)
          floatingActionButton: canManage 
            ? FloatingActionButton.extended(
                onPressed: _addAnnualEvent,
                backgroundColor: Colors.purple,
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text("Novo Evento", style: TextStyle(color: Colors.white)),
              )
            : null,
          
          // 2. STREAM DA AGENDA
          body: StreamBuilder<QuerySnapshot>(
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
                  // Passamos canManage para o widget do mês
                  return _buildMonthGrid(mes, eventosAnuais, canManage);
                },
              );
            },
          ),
        );
      }
    );
  }

  Widget _buildMonthGrid(int month, List<DocumentSnapshot> eventosDoAno, bool canManage) {
    DateTime dataBase = DateTime(_anoSelecionado, month, 1);
    String nomeMes = DateFormat('MMMM', 'pt_BR').format(dataBase);
    
    // Filtra eventos deste mês
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
                      // Passamos canManage para o popup
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
                  // BOTÕES DE AÇÃO (SÓ SE TIVER PERMISSÃO)
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