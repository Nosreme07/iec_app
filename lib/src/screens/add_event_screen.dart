import 'package:flutter/material.dart';

class AddEventScreen extends StatefulWidget {
  const AddEventScreen({super.key});

  @override
  State<AddEventScreen> createState() => _AddEventScreenState();
}

class _AddEventScreenState extends State<AddEventScreen> {
  final _tituloController = TextEditingController();
  final _dataController = TextEditingController();
  final _horaController = TextEditingController();

  @override
  void dispose() {
    _tituloController.dispose();
    _dataController.dispose();
    _horaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Novo Evento", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue[900],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Adicionar Culto ou Evento",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // Campo Título
            TextField(
              controller: _tituloController,
              decoration: const InputDecoration(
                labelText: "Título (ex: Culto Jovem)",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.title),
              ),
            ),
            const SizedBox(height: 16),

            // Campo Data (Futuramente abriremos um calendário aqui)
            TextField(
              controller: _dataController,
              decoration: const InputDecoration(
                labelText: "Data (ex: 25/12)",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.calendar_today),
              ),
              keyboardType: TextInputType.datetime,
            ),
            const SizedBox(height: 16),

            // Campo Hora
            TextField(
              controller: _horaController,
              decoration: const InputDecoration(
                labelText: "Horário (ex: 19:30)",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.access_time),
              ),
              keyboardType: TextInputType.datetime,
            ),
            const SizedBox(height: 30),

            // Botão Salvar
            ElevatedButton(
              onPressed: () {
                // Aqui depois vamos enviar para o Firebase
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Evento salvo! (Simulação)")),
                );
                Navigator.pop(context); // Volta para a tela anterior
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[900],
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text(
                "SALVAR EVENTO",
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
