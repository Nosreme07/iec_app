import 'package:flutter/material.dart';
import 'add_event_screen.dart'; // Importe a tela nova

class AgendaScreen extends StatelessWidget {
  const AgendaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // --- SIMULAÇÃO DE PERMISSÃO ---
    // Se mudar para 'false', o botão de adicionar some.
    // Futuramente isso virá do Firebase do usuário logado.
    bool isAdmin = true;
    // ------------------------------

    // Simulação de dados
    final eventos = [
      {
        "dia": "15",
        "mes": "JAN",
        "titulo": "Culto de Doutrina",
        "hora": "19:30",
      },
      {"dia": "18", "mes": "JAN", "titulo": "Culto Jovem", "hora": "19:00"},
    ];

    return Scaffold(
      // Se for admin, mostra o botão (+). Se não, mostra nada (null).
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              backgroundColor: Colors.blue[900],
              child: const Icon(Icons.add, color: Colors.white),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddEventScreen(),
                  ),
                );
              },
            )
          : null,

      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: eventos.length,
        separatorBuilder: (_, __) => const Divider(),
        itemBuilder: (context, index) {
          final evento = eventos[index];
          return ListTile(
            leading: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    evento["dia"]!,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(evento["mes"]!, style: const TextStyle(fontSize: 10)),
                ],
              ),
            ),
            title: Text(
              evento["titulo"]!,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(evento["hora"]!),
            // Se for admin, mostra ícone de editar, senão seta normal
            trailing: isAdmin
                ? IconButton(
                    icon: const Icon(Icons.edit, color: Colors.grey),
                    onPressed: () {
                      // Futuramente: Editar evento
                    },
                  )
                : const Icon(Icons.arrow_forward_ios, size: 14),
          );
        },
      ),
    );
  }
}
