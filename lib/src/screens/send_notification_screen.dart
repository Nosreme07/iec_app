import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SendNotificationScreen extends StatefulWidget {
  const SendNotificationScreen({super.key});

  @override
  State<SendNotificationScreen> createState() => _SendNotificationScreenState();
}

class _SendNotificationScreenState extends State<SendNotificationScreen> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _confirmarEnvio() {
    if (_titleController.text.trim().isEmpty || _bodyController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Preencha o título e a mensagem!"),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // Pergunta se o usuário quer realmente enviar
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirmar Envio"),
        content: const Text("Esta mensagem será enviada para o celular de todos os membros. Confirma?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), 
            child: const Text("CANCELAR")
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx); // Fecha o alerta
              _processarEnvioAutomatico(); // Chama a função de salvar
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[900]),
            child: const Text("ENVIAR AGORA", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Função que salva no banco (e o Robô na nuvem faz o envio)
  Future<void> _processarEnvioAutomatico() async {
    setState(() => _isLoading = true);
    
    try {
      final String titulo = _titleController.text.trim();
      final String mensagem = _bodyController.text.trim();

      // AO SALVAR AQUI, A CLOUD FUNCTION VAI DISPARAR O PUSH SOZINHA
      await FirebaseFirestore.instance.collection('notices').add({
        'title': titulo,
        'body': mensagem,
        'timestamp': FieldValue.serverTimestamp(),
        'sentBy': FirebaseAuth.instance.currentUser?.uid,
        'role': 'geral',
      });

      if (mounted) {
        // Mostra sucesso e fecha a tela
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Sucesso! O sistema está enviando as notificações."), 
            backgroundColor: Colors.green
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao salvar: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Novo Comunicado", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue[900],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView( 
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const Icon(Icons.rocket_launch, size: 80, color: Colors.blue),
            const SizedBox(height: 10),
            const Text(
              "Disparo Automático",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            Text(
              "Ao salvar, a notificação será enviada para todos.",
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _titleController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: "Título do Alerta",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.title),
                hintText: "Ex: Culto hoje às 19:30",
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _bodyController,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: "Mensagem para todos",
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
                hintText: "Escreva os detalhes do aviso aqui...",
              ),
            ),
            const SizedBox(height: 30),
            _isLoading 
              ? const CircularProgressIndicator()
              : SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton.icon(
                    onPressed: _confirmarEnvio,
                    icon: const Icon(Icons.send, color: Colors.white),
                    label: const Text(
                      "PUBLICAR E NOTIFICAR", 
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[900],
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}