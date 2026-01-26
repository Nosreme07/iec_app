import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qr_flutter/qr_flutter.dart';

class PatrimonioScreen extends StatefulWidget {
  const PatrimonioScreen({super.key});

  @override
  State<PatrimonioScreen> createState() => _PatrimonioScreenState();
}

class _PatrimonioScreenState extends State<PatrimonioScreen> {
  // Controladores
  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _quantidadeController = TextEditingController();
  final TextEditingController _observacoesController = TextEditingController();
  final TextEditingController _qrCodeController = TextEditingController();
  
  // Variável para o Dropdown (Situação)
  String _situacaoSelecionada = 'Em uso';
  final List<String> _opcoesSituacao = ['Em uso', 'Descartado', 'Vendido'];

  bool _isSaving = false;
  bool _isGeneratingCode = false;

  @override
  void dispose() {
    _nomeController.dispose();
    _quantidadeController.dispose();
    _observacoesController.dispose();
    _qrCodeController.dispose();
    super.dispose();
  }

  // --- LÓGICA DE NEGÓCIO ---

  Future<void> _gerarCodigoAutomatico() async {
    if (_nomeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Preencha o Nome do item primeiro.")));
      return;
    }

    setState(() => _isGeneratingCode = true);

    try {
      var snapshot = await FirebaseFirestore.instance.collection('tombamento').get();
      int proximoNumero = snapshot.size + 1;
      String codigoSequencial = proximoNumero.toString().padLeft(3, '0');

      String nome = _nomeController.text.trim();
      String qtd = _quantidadeController.text.isEmpty ? "0" : _quantidadeController.text;
      String obs = _observacoesController.text.trim();
      if (obs.isEmpty) obs = "Sem observações";

      String textoQR = """
IGREJA EVANGÉLICA CONGREGACIONAL EM MORENO
CNPJ: 30.057.670.0001-05

Nome: $nome
Qtd: $qtd
Situação: $_situacaoSelecionada
Obs: $obs
Código: $codigoSequencial""";

      _qrCodeController.text = textoQR;

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erro ao gerar sequencial.")));
    } finally {
      setState(() => _isGeneratingCode = false);
    }
  }

  Future<void> _salvarItem({String? docId}) async {
    if (_nomeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("O nome é obrigatório!")));
      return;
    }

    setState(() => _isSaving = true);

    try {
      double qtd = double.tryParse(_quantidadeController.text.replaceAll(',', '.')) ?? 0;

      Map<String, dynamic> dados = {
        'nome': _nomeController.text.trim(),
        'quantidade': qtd,
        'observacoes': _observacoesController.text.trim(),
        'situacao': _situacaoSelecionada,
        'qr_code_data': _qrCodeController.text.trim(),
        'data_atualizacao': FieldValue.serverTimestamp(),
      };

      if (docId == null) {
        dados['data_criacao'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('tombamento').add(dados);
      } else {
        await FirebaseFirestore.instance.collection('tombamento').doc(docId).set(dados, SetOptions(merge: true));
      }

      if (mounted) {
        Navigator.pop(context); // Fecha o Dialog
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(docId == null ? "Item registrado!" : "Item atualizado!"),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao salvar: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _excluirItem(String docId) async {
    bool confirm = await showDialog(
      context: context, 
      builder: (ctx) => AlertDialog(
        title: const Text("Excluir Item"),
        content: const Text("Tem certeza que deseja remover este item do patrimônio?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("EXCLUIR", style: TextStyle(color: Colors.red))),
        ],
      )
    ) ?? false;

    if (confirm) {
      await FirebaseFirestore.instance.collection('tombamento').doc(docId).delete();
      if (mounted) Navigator.pop(context); // Fecha o popup de detalhes
    }
  }

  // --- POPUP DE DETALHES ---
  void _showDetailsDialog(String docId, Map<String, dynamic> data, bool canManage) {
    String nome = data['nome'] ?? "Sem Nome";
    double qtd = (data['quantidade'] ?? 0).toDouble();
    String obs = data['observacoes'] ?? "Sem observações";
    String situacao = data['situacao'] ?? "Em uso";
    String qrData = data['qr_code_data'] ?? "";

    Color corSituacao = Colors.green;
    if (situacao == 'Descartado') corSituacao = Colors.red;
    if (situacao == 'Vendido') corSituacao = Colors.blue;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Column(
            children: [
              Text(nome, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: corSituacao.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: corSituacao)),
                child: Text(situacao.toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: corSituacao)),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                _buildDetailRow("Quantidade:", "${qtd.toInt()}"),
                const SizedBox(height: 8),
                const Text("Observações:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text(obs, style: TextStyle(color: Colors.grey[800], fontSize: 14)),
                const SizedBox(height: 20),
                
                if (qrData.isNotEmpty)
                  Center(
                    child: Column(
                      children: [
                        const Text("Etiqueta QR Code", style: TextStyle(fontSize: 12, color: Colors.grey)),
                        Container(
                          margin: const EdgeInsets.only(top: 5),
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300)),
                          child: QrImageView(data: qrData, version: QrVersions.auto, size: 120.0),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            if (canManage) ...[
              TextButton.icon(
                icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                label: const Text("Excluir", style: TextStyle(color: Colors.red)),
                onPressed: () => _excluirItem(docId),
              ),
              TextButton.icon(
                icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                label: const Text("Editar", style: TextStyle(color: Colors.blue)),
                onPressed: () {
                  Navigator.pop(ctx); 
                  _showFormDialog(docId: docId, data: data); 
                },
              ),
            ],
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Fechar")),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(width: 8),
        Text(value),
      ],
    );
  }

  // --- FORMULÁRIO (ADIÇÃO/EDIÇÃO) ---
  void _showFormDialog({String? docId, Map<String, dynamic>? data}) {
    if (data != null) {
      _nomeController.text = data['nome'] ?? '';
      _quantidadeController.text = (data['quantidade'] ?? 0).toString();
      _observacoesController.text = data['observacoes'] ?? '';
      _qrCodeController.text = data['qr_code_data'] ?? '';
      _situacaoSelecionada = data['situacao'] ?? 'Em uso';
    } else {
      _nomeController.clear();
      _quantidadeController.clear();
      _observacoesController.clear();
      _qrCodeController.clear();
      _situacaoSelecionada = 'Em uso';
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            void refreshDialog() => setStateDialog(() {});
            _qrCodeController.addListener(refreshDialog);

            return AlertDialog(
              title: Text(docId == null ? "Novo Item" : "Editar Item"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: _nomeController, decoration: const InputDecoration(labelText: "Nome do Item *", border: OutlineInputBorder())),
                    const SizedBox(height: 12),
                    
                    Row(
                      children: [
                        Expanded(child: TextField(controller: _quantidadeController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Qtd", border: OutlineInputBorder()))),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            value: _situacaoSelecionada,
                            decoration: const InputDecoration(labelText: "Situação", border: OutlineInputBorder()),
                            items: _opcoesSituacao.map((String situacao) {
                              return DropdownMenuItem<String>(
                                value: situacao,
                                child: Text(situacao, style: const TextStyle(fontSize: 14)),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                setStateDialog(() => _situacaoSelecionada = newValue);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(controller: _observacoesController, maxLines: 3, decoration: const InputDecoration(labelText: "Observações", hintText: "Estado, local, etc...", border: OutlineInputBorder())),
                    
                    const SizedBox(height: 20),
                    const Divider(),
                    const Text("QR CODE / Identificação", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 8),
                    
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: TextField(controller: _qrCodeController, maxLines: 4, style: const TextStyle(fontSize: 12), decoration: const InputDecoration(labelText: "Dados da Etiqueta", hintText: "Clique em Gerar", isDense: true, border: OutlineInputBorder()))),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _isGeneratingCode ? null : () async { await _gerarCodigoAutomatico(); refreshDialog(); },
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8)),
                          child: _isGeneratingCode 
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Column(children: [Icon(Icons.qr_code, color: Colors.white), Text("Gerar", style: TextStyle(color: Colors.white, fontSize: 10))]),
                        ),
                      ],
                    ),

                    if (_qrCodeController.text.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 15),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300)),
                            child: QrImageView(data: _qrCodeController.text, version: QrVersions.auto, size: 140.0),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: _isSaving ? null : () => Navigator.pop(ctx), child: const Text("Cancelar")),
                ElevatedButton(
                  onPressed: _isSaving ? null : () async { _qrCodeController.removeListener(refreshDialog); setStateDialog(() => _isSaving = true); await _salvarItem(docId: docId); },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
                  child: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text("Salvar", style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          }
        );
      },
    );
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
           
           // --- ATUALIZADO: Incluindo 'administrativo' na permissão visual ---
             canManage = role == 'admin' || role == 'financeiro' || role == 'administrativo';
          }

        return Scaffold(
          appBar: AppBar(
            title: const Text("Controle de Patrimônio", style: TextStyle(color: Colors.white, fontSize: 18)),
            backgroundColor: Colors.indigo,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          backgroundColor: Colors.grey[100],
          
          body: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('tombamento').orderBy('nome').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return const Center(child: Text("Erro ao carregar dados."));
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

              final docs = snapshot.data!.docs;

              if (docs.isEmpty) {
                return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.inventory_2_outlined, size: 60, color: Colors.grey[400]), const SizedBox(height: 10), Text("Nenhum item registrado.", style: TextStyle(color: Colors.grey[600]))]));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(10),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final id = docs[index].id;
                  
                  String nome = data['nome'] ?? "Sem Nome";
                  double qtd = (data['quantidade'] ?? 0).toDouble();
                  String observacoes = data['observacoes'] ?? "";
                  String situacao = data['situacao'] ?? "Em uso";
                  String qrFullText = data['qr_code_data'] ?? "";
                  
                  Color statusColor = Colors.green;
                  if (situacao == 'Descartado') statusColor = Colors.red;
                  if (situacao == 'Vendido') statusColor = Colors.blue;

                  return Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: qrFullText.isNotEmpty 
                          ? Icon(Icons.qr_code_2, color: Colors.indigo[800], size: 30)
                          : const Icon(Icons.label_outline, color: Colors.indigo),
                      title: Text(nome, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(width: 8, height: 8, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                              const SizedBox(width: 5),
                              Text(situacao, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold)),
                              const SizedBox(width: 10),
                              Text("|  Qtd: ${qtd.toInt()}", style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                          if (observacoes.isNotEmpty)
                            Text(observacoes, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                        ],
                      ),
                      onTap: () => _showDetailsDialog(id, data, canManage),
                    ),
                  );
                },
              );
            },
          ),
          
          floatingActionButton: canManage 
            ? FloatingActionButton(
                backgroundColor: Colors.indigo,
                onPressed: () => _showFormDialog(), 
                child: const Icon(Icons.add, color: Colors.white),
              )
            : null,
        );
      }
    );
  }
}