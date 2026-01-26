import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class MuralAvisosWidget extends StatelessWidget {
  const MuralAvisosWidget({super.key});

  // Função ajustada para tentar encontrar o ID correto
  // Ela retorna uma lista com duas possibilidades: Data da Segunda e Data do Domingo
  List<String> _getPossiveisIdsDaSemana() {
    DateTime now = DateTime.now();
    DateTime today = DateTime(now.year, now.month, now.day);
    
    // 1. Calcula assumindo que a semana começa na SEGUNDA (weekday = 1)
    DateTime startMonday = today.subtract(Duration(days: today.weekday - 1));
    
    // 2. Calcula assumindo que a semana começa no DOMINGO (weekday 7 no sistema do Dart vira 0 na lógica de domingo)
    // Se hoje é domingo (7), subtract(0) é hoje. Se é segunda (1), subtract(1) é domingo.
    DateTime startSunday = today.subtract(Duration(days: today.weekday % 7)); 

    return [
      DateFormat('yyyy-MM-dd').format(startMonday), // ID usado pela AgendaScreen (Provável)
      DateFormat('yyyy-MM-dd').format(startSunday), // ID alternativo caso a lógica mude
    ];
  }

  @override
  Widget build(BuildContext context) {
    List<String> idsPossiveis = _getPossiveisIdsDaSemana();

    return StreamBuilder<QuerySnapshot>(
      // Em vez de buscar um DOC específico, buscamos na COLEÇÃO filtrando pelos IDs possíveis
      // Isso resolve o problema de "qual dia a semana começa"
      stream: FirebaseFirestore.instance
          .collection('agenda_avisos')
          .where(FieldPath.documentId, whereIn: idsPossiveis)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox();
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          // Se não achar nada, mostra mensagem padrão (ou SizedBox() se preferir esconder)
          return _buildAvisoContainer("Nenhum aviso cadastrado para esta semana."); 
        }

        // Pega o primeiro documento encontrado (já que só deve ter um por semana)
        var doc = snapshot.data!.docs.first;
        var data = doc.data() as Map<String, dynamic>;
        String texto = data['texto'] ?? "";

        if (texto.trim().isEmpty) {
          return const SizedBox();
        }

        return _buildAvisoContainer(texto);
      },
    );
  }

  Widget _buildAvisoContainer(String texto) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1), // Amarelo clarinho
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFE082), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.push_pin, color: Colors.amber[900], size: 20),
              const SizedBox(width: 8),
              Text(
                "Avisos & Lembretes",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber[900],
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            texto,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black87,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}