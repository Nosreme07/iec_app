import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../utils/admin_config.dart';

class ScaleScreen extends StatefulWidget {
  const ScaleScreen({super.key});

  @override
  State<ScaleScreen> createState() => _ScaleScreenState();
}

class _ScaleScreenState extends State<ScaleScreen> {
  DateTime _currentDate = DateTime.now();
  final bool _isAdmin = AdminConfig.isUserAdmin();

  // Função para mudar o mês
  void _changeMonth(int monthsToAdd) {
    setState(() {
      _currentDate = DateTime(_currentDate.year, _currentDate.month + monthsToAdd, 1);
    });
  }

  // Função para Editar Escala (Dialog)
  void _editScale(String docId, String currentDirigente, String currentPregador, String titulo) {
    final dirigenteController = TextEditingController(text: currentDirigente);
    final pregadorController = TextEditingController(text: currentPregador);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Escala: $titulo", style: const TextStyle(fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: dirigenteController,
                decoration: const InputDecoration(
                  labelText: "👤 Dirigente",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: pregadorController,
                decoration: const InputDecoration(
                  labelText: "📖 Pregador",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.menu_book),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar"),
            ),
            ElevatedButton(
              onPressed: () async {
                await FirebaseFirestore.instance.collection('agenda').doc(docId).update({
                  'dirigente': dirigenteController.text.trim(),
                  'pregador': pregadorController.text.trim(),
                });
                if (mounted) Navigator.pop(context);
              },
              child: const Text("Salvar"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Definir início e fim do mês para o filtro
    DateTime startOfMonth = DateTime(_currentDate.year, _currentDate.month, 1);
    DateTime endOfMonth = DateTime(_currentDate.year, _currentDate.month + 1, 0, 23, 59, 59);
    
    String monthLabel = DateFormat('MMMM yyyy', 'pt_BR').format(_currentDate).toUpperCase();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Escala de Cultos"),
        backgroundColor: Colors.teal[800],
      ),
      body: Column(
        children: [
          // --- SELETOR DE MÊS ---
          Container(
            color: Colors.teal[50],
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios),
                  onPressed: () => _changeMonth(-1),
                ),
                Text(
                  monthLabel,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal[900]),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios),
                  onPressed: () => _changeMonth(1),
                ),
              ],
            ),
          ),

          // --- LISTA DE CULTOS ---
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('agenda')
                  .where('data_hora', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
                  .where('data_hora', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
                  .orderBy('data_hora')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                var docs = snapshot.data!.docs;

                if (docs.isEmpty) {
                  return const Center(
                    child: Text("Nenhum culto agendado para este mês."),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var data = docs[index].data() as Map<String, dynamic>;
                    String docId = docs[index].id;
                    
                    DateTime dataHora = (data['data_hora'] as Timestamp).toDate();
                    String dia = DateFormat('dd').format(dataHora);
                    String diaSemana = DateFormat('EEE', 'pt_BR').format(dataHora).toUpperCase();
                    String hora = DateFormat('HH:mm').format(dataHora);
                    String titulo = data['titulo'] ?? data['tipo'];

                    String dirigente = data['dirigente'] ?? '';
                    String pregador = data['pregador'] ?? '';

                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            // LINHA DO TÍTULO E DATA
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.teal[100],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(dia, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal[900])),
                                      Text(diaSemana, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.teal[900])),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(titulo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                      Text("⏰ $hora", style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                                    ],
                                  ),
                                ),
                                if (_isAdmin)
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.teal),
                                    onPressed: () => _editScale(docId, dirigente, pregador, titulo),
                                  )
                              ],
                            ),
                            const Divider(),
                            
                            // LINHA DA ESCALA (DIRIGENTE E PREGADOR)
                            Row(
                              children: [
                                Expanded(
                                  child: _buildScaleItem(
                                    icon: Icons.person, 
                                    label: "Dirigente", 
                                    value: dirigente
                                  ),
                                ),
                                Container(width: 1, height: 40, color: Colors.grey[300]), // Divisória vertical
                                Expanded(
                                  child: _buildScaleItem(
                                    icon: Icons.menu_book, 
                                    label: "Pregador", 
                                    value: pregador
                                  ),
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScaleItem({required IconData icon, required String label, required String value}) {
    bool isEmpty = value.isEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            isEmpty ? "---" : value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: isEmpty ? Colors.grey[400] : Colors.black87
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}