import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class WeeklyNoticesWidget extends StatefulWidget {
  const WeeklyNoticesWidget({super.key});

  @override
  State<WeeklyNoticesWidget> createState() => _WeeklyNoticesWidgetState();
}

class _WeeklyNoticesWidgetState extends State<WeeklyNoticesWidget> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startAutoScroll();
  }

  void _startAutoScroll() {
    _timer = Timer.periodic(const Duration(seconds: 5), (Timer timer) {
      if (_pageController.hasClients) {
        int nextPage = _currentPage + 1;
        if (nextPage > 6) nextPage = 0;
        
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  DateTime _getStartOfWeek() {
    DateTime now = DateTime.now();
    return now.subtract(Duration(days: now.weekday - 1)); 
  }

  @override
  Widget build(BuildContext context) {
    DateTime startOfWeek = _getStartOfWeek();
    DateTime endOfWeek = startOfWeek.add(const Duration(days: 6));
    
    DateTime startQuery = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
    DateTime endQuery = DateTime(endOfWeek.year, endOfWeek.month, endOfWeek.day, 23, 59, 59);

    return StreamBuilder<QuerySnapshot>(
      // 1. Agenda
      stream: FirebaseFirestore.instance
          .collection('agenda')
          .where('data_hora', isGreaterThanOrEqualTo: Timestamp.fromDate(startQuery))
          .where('data_hora', isLessThanOrEqualTo: Timestamp.fromDate(endQuery))
          .snapshots(),
      builder: (context, snapshotAgenda) {
        
        return StreamBuilder<QuerySnapshot>(
          // 2. Users (Membros)
          stream: FirebaseFirestore.instance.collection('users').snapshots(),
          builder: (context, snapshotMembros) {
            
            if (!snapshotAgenda.hasData || !snapshotMembros.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            List<Widget> dayCards = [];

            for (int i = 0; i < 7; i++) {
              DateTime diaAtual = startOfWeek.add(Duration(days: i));
              String diaSemana = DateFormat('EEEE', 'pt_BR').format(diaAtual);
              String dataFormatada = DateFormat('dd/MM').format(diaAtual);

              var eventosDoDia = snapshotAgenda.data!.docs.where((doc) {
                DateTime dataEvento = (doc['data_hora'] as Timestamp).toDate();
                return dataEvento.day == diaAtual.day && dataEvento.month == diaAtual.month;
              }).toList();

              var aniversariantesDoDia = snapshotMembros.data!.docs.where((doc) {
                var data = doc.data() as Map<String, dynamic>;
                var rawDate = data['data_nascimento'] ?? data['dataNascimento'] ?? data['nascimento'];
                if (rawDate == null) return false;

                DateTime? nascimento;
                try {
                  if (rawDate is Timestamp) {
                    nascimento = rawDate.toDate();
                  } else if (rawDate is String) {
                    String dateStr = rawDate.trim();
                    if (dateStr.contains('/')) {
                      nascimento = DateFormat('dd/MM/yyyy').parse(dateStr);
                    } else if (dateStr.contains('-')) {
                      nascimento = DateTime.parse(dateStr);
                    }
                  }
                } catch (e) { return false; }
                if (nascimento == null) return false;
                return nascimento.day == diaAtual.day && nascimento.month == diaAtual.month;
              }).toList();

              dayCards.add(_buildDayCard(diaSemana, dataFormatada, eventosDoDia, aniversariantesDoDia));
            }

            return Container(
              height: 180, // Aumentei um pouco a altura para caber Pregador e Dirigente
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (idx) => setState(() => _currentPage = idx),
                  children: dayCards,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDayCard(String diaSemana, String data, List<DocumentSnapshot> eventos, List<DocumentSnapshot> nivers) {
    bool temAniversario = nivers.isNotEmpty;
    bool temEvento = eventos.isNotEmpty;
    bool isLivre = !temAniversario && !temEvento;

    Color bgColor = Colors.white;
    Color titleColor = Colors.blue[900]!;
    
    if (temAniversario) {
      bgColor = const Color(0xFFFFF8E1); 
      titleColor = const Color(0xFFF57F17); 
    } else if (temEvento) {
      bgColor = const Color(0xFFE3F2FD); 
    }

    return Container(
      color: bgColor,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "${diaSemana.toUpperCase()} - $data",
                style: TextStyle(fontWeight: FontWeight.bold, color: titleColor, fontSize: 16),
              ),
              if (temAniversario) 
                const Icon(Icons.cake, color: Color(0xFFF57F17), size: 24)
              else if (temEvento)
                Icon(Icons.event, color: Colors.blue[900], size: 24),
            ],
          ),
          const Divider(),
          
          Expanded(
            child: isLivre 
            ? Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_outline, color: Colors.grey[400]),
                    const SizedBox(width: 8),
                    Text("Agenda Livre", style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                  ],
                ),
              )
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- ANIVERSARIANTES ---
                    if (temAniversario)
                      ...nivers.map((doc) {
                         var data = doc.data() as Map<String, dynamic>;
                         String nomeExibicao = data['nome_completo'] ?? data['nome'] ?? 'Membro';
                         return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              const Text("🎉 ", style: TextStyle(fontSize: 14)),
                              Expanded(child: Text("- $nomeExibicao", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE65100)))),
                            ],
                          ),
                        );
                      }),

                    if (temAniversario && temEvento) const SizedBox(height: 8),

                    // --- EVENTOS (CULTOS) COM PREGADOR E DIRIGENTE ---
                    if (temEvento)
                      ...eventos.map((doc) {
                        var data = doc.data() as Map<String, dynamic>;
                        String hora = DateFormat('HH:mm').format((data['data_hora'] as Timestamp).toDate());
                        String titulo = data['titulo'] ?? data['tipo'];
                        
                        // Captura os campos opcionais
                        String? dirigente = data['dirigente'];
                        String? pregador = data['pregador'];

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Título do Evento
                              Row(
                                children: [
                                  Text("$hora ", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[900])),
                                  Expanded(child: Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                                ],
                              ),
                              // Detalhes (Dirigente e Pregador)
                              if (dirigente != null && dirigente.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(left: 45), // Indentação para ficar alinhado
                                  child: Text("👤 Dirigente: $dirigente", style: TextStyle(fontSize: 12, color: Colors.grey[800])),
                                ),
                              if (pregador != null && pregador.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(left: 45),
                                  child: Text("📖 Pregador: $pregador", style: TextStyle(fontSize: 12, color: Colors.grey[800])),
                                ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
          ),
        ],
      ),
    );
  }
}