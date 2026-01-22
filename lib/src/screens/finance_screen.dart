import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../utils/admin_config.dart';

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  DateTime _mesAtual = DateTime.now();
  
  // Controladores do Formulário
  final TextEditingController _nomeController = TextEditingController(); // NOVO
  final TextEditingController _descricaoController = TextEditingController();
  final TextEditingController _valorController = TextEditingController();
  
  String _tipoSelecionado = 'entrada';
  String _categoriaSelecionada = 'Dízimo';
  
  final List<String> _categoriasEntrada = ['Dízimo', 'Oferta', 'Outros'];
  final List<String> _categoriasSaida = ['Prebenda Pastoral','INSS Pastor', 'FGTM', 'Ajuda de Custo Zeladoria',
  'INSS Zeladoria', 'FGTS Zeladoria', 'Neoenergia (igreja)', 'Neoenergia (comunidade)', 'Compesa', 
  'Internet', 'GFIP', 'Material de Limpeza', 'Descartáveis', 'Ítens da Sta Ceia', 'Ofertas Missionárias','Assistência Social',
  'Papelaria', 'Man. do Templo', 'Man. do Som', 'Outros'];

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('pt_BR', null);
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _descricaoController.dispose();
    _valorController.dispose();
    super.dispose();
  }

  // --- LÓGICA DE DATAS ---
  void _trocarMes(int meses) {
    setState(() {
      _mesAtual = DateTime(_mesAtual.year, _mesAtual.month + meses, 1);
    });
  }

  DateTime _getInicioMes() => DateTime(_mesAtual.year, _mesAtual.month, 1);
  DateTime _getFimMes() => DateTime(_mesAtual.year, _mesAtual.month + 1, 0, 23, 59, 59);

  // --- LÓGICA DE CRUD ---
  Future<void> _salvarTransacao({String? docId}) async {
    // Validação básica
    if (_valorController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("O valor é obrigatório.")));
      return;
    }

    setState(() => _isSaving = true);

    try {
      String valorRaw = _valorController.text.replaceAll('.', '').replaceAll(',', '.');
      double valor = double.tryParse(valorRaw) ?? 0.0;

      Map<String, dynamic> dados = {
        'tipo': _tipoSelecionado, 
        'categoria': _categoriaSelecionada,
        'nome': _nomeController.text.trim(), // Salva o Nome
        'descricao': _descricaoController.text.trim(),
        'valor': valor,
        'data': Timestamp.fromDate(DateTime.now()),
      };

      if (docId == null) {
        await FirebaseFirestore.instance.collection('financas').add(dados);
      } else {
        await FirebaseFirestore.instance.collection('financas').doc(docId).update(dados);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lançamento salvo!"), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erro ao salvar."), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _excluirTransacao(String docId) async {
    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Excluir"),
        content: const Text("Deseja apagar este lançamento?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Apagar", style: TextStyle(color: Colors.red))),
        ],
      )
    ) ?? false;

    if (confirm) {
      await FirebaseFirestore.instance.collection('financas').doc(docId).delete();
    }
  }

  // --- FORMULÁRIO ---
  void _showFormDialog({String? docId, Map<String, dynamic>? data}) {
    if (data != null) {
      _tipoSelecionado = data['tipo'];
      _categoriaSelecionada = data['categoria'];
      _nomeController.text = data['nome'] ?? ''; // Carrega nome
      _descricaoController.text = data['descricao'] ?? '';
      _valorController.text = (data['valor'] as double).toStringAsFixed(2).replaceAll('.', ',');
    } else {
      _tipoSelecionado = 'entrada';
      _categoriaSelecionada = 'Dízimo';
      _nomeController.clear();
      _descricaoController.clear();
      _valorController.clear();
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            List<String> categoriasAtuais = _tipoSelecionado == 'entrada' ? _categoriasEntrada : _categoriasSaida;
            if (!categoriasAtuais.contains(_categoriaSelecionada)) {
              _categoriaSelecionada = categoriasAtuais.first;
            }

            return AlertDialog(
              title: Text(docId == null ? "Novo Lançamento" : "Editar Lançamento"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // SELETOR DE TIPO
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setStateDialog(() => _tipoSelecionado = 'entrada'),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: _tipoSelecionado == 'entrada' ? Colors.green[100] : Colors.grey[200],
                                border: Border.all(color: _tipoSelecionado == 'entrada' ? Colors.green : Colors.transparent),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: const [
                                  Icon(Icons.arrow_upward, color: Colors.green),
                                  Text("Entrada", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green))
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setStateDialog(() => _tipoSelecionado = 'saida'),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: _tipoSelecionado == 'saida' ? Colors.red[100] : Colors.grey[200],
                                border: Border.all(color: _tipoSelecionado == 'saida' ? Colors.red : Colors.transparent),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: const [
                                  Icon(Icons.arrow_downward, color: Colors.red),
                                  Text("Saída", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red))
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),

                    // CAMPO NOME (NOVO)
                    TextField(
                      controller: _nomeController,
                      decoration: const InputDecoration(
                        labelText: "Nome (Pessoa/Empresa)", 
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person_outline)
                      ),
                    ),
                    const SizedBox(height: 12),

                    // VALOR
                    TextField(
                      controller: _valorController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: "Valor (R\$)", hintText: "0,00", border: OutlineInputBorder(), prefixIcon: Icon(Icons.attach_money)),
                    ),
                    const SizedBox(height: 12),

                    // CATEGORIA
                    DropdownButtonFormField<String>(
                      value: _categoriaSelecionada,
                      decoration: const InputDecoration(labelText: "Categoria", border: OutlineInputBorder()),
                      items: categoriasAtuais.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (val) => setStateDialog(() => _categoriaSelecionada = val!),
                    ),
                    const SizedBox(height: 12),

                    // DESCRIÇÃO
                    TextField(
                      controller: _descricaoController,
                      decoration: const InputDecoration(labelText: "Observação / Detalhes", border: OutlineInputBorder()),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
                ElevatedButton(
                  onPressed: _isSaving ? null : () async {
                    setStateDialog(() => _isSaving = true);
                    await _salvarTransacao(docId: docId);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
                  child: _isSaving 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text("Salvar", style: TextStyle(color: Colors.white)),
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
    final bool isAdmin = AdminConfig.isUserAdmin();
    String mesFormatado = DateFormat('MMMM yyyy', 'pt_BR').format(_mesAtual).toUpperCase();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Financeiro", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.green[800],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          // --- BARRA DE MÊS ---
          Container(
            color: Colors.green[800],
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white70), onPressed: () => _trocarMes(-1)),
                    Text(mesFormatado, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.arrow_forward_ios, color: Colors.white70), onPressed: () => _trocarMes(1)),
                  ],
                ),
              ],
            ),
          ),

          // --- LISTA E RESUMO ---
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('financas')
                  .where('data', isGreaterThanOrEqualTo: Timestamp.fromDate(_getInicioMes()))
                  .where('data', isLessThanOrEqualTo: Timestamp.fromDate(_getFimMes()))
                  .orderBy('data', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return const Center(child: Text("Erro ao carregar dados."));
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

                final docs = snapshot.data!.docs;

                // --- CÁLCULO DOS TOTAIS ---
                double totalEntrada = 0;
                double totalSaida = 0;

                for (var doc in docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  double valor = (data['valor'] ?? 0).toDouble();
                  if (data['tipo'] == 'entrada') {
                    totalEntrada += valor;
                  } else {
                    totalSaida += valor;
                  }
                }
                double saldo = totalEntrada - totalSaida;

                return Column(
                  children: [
                    // CARD DE RESUMO
                    Transform.translate(
                      offset: const Offset(0, -25),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, 5))],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildInfoColumn("Entradas", totalEntrada, Colors.green),
                            _buildInfoColumn("Saídas", totalSaida, Colors.red),
                            Container(width: 1, height: 40, color: Colors.grey[300]),
                            _buildInfoColumn("Saldo", saldo, saldo >= 0 ? Colors.blue[800]! : Colors.red[800]!),
                          ],
                        ),
                      ),
                    ),

                    // LISTA DE LANÇAMENTOS
                    Expanded(
                      child: docs.isEmpty 
                        ? const Center(child: Text("Nenhum lançamento neste mês.", style: TextStyle(color: Colors.grey)))
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            itemCount: docs.length,
                            itemBuilder: (context, index) {
                              final data = docs[index].data() as Map<String, dynamic>;
                              final id = docs[index].id;
                              
                              bool isEntrada = data['tipo'] == 'entrada';
                              double valor = (data['valor'] ?? 0).toDouble();
                              String categoria = data['categoria'] ?? "";
                              String nome = data['nome'] ?? ""; // Pega o nome
                              String descricao = data['descricao'] ?? "";
                              DateTime dataTransacao = (data['data'] as Timestamp).toDate();
                              String dia = DateFormat('dd/MM').format(dataTransacao);

                              // Monta o subtítulo inteligente
                              String subtitulo = "$dia";
                              if (nome.isNotEmpty) subtitulo += " - $nome";
                              if (descricao.isNotEmpty) subtitulo += " ($descricao)";

                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: isEntrada ? Colors.green[50] : Colors.red[50],
                                    child: Icon(
                                      isEntrada ? Icons.arrow_upward : Icons.arrow_downward, 
                                      color: isEntrada ? Colors.green : Colors.red,
                                      size: 20,
                                    ),
                                  ),
                                  title: Text(categoria, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text(subtitulo, maxLines: 1, overflow: TextOverflow.ellipsis),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        isEntrada ? "+ ${NumberFormat.simpleCurrency(locale: 'pt_BR').format(valor)}" 
                                                  : "- ${NumberFormat.simpleCurrency(locale: 'pt_BR').format(valor)}",
                                        style: TextStyle(
                                          color: isEntrada ? Colors.green[700] : Colors.red[700],
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (isAdmin) 
                                        PopupMenuButton<String>(
                                          padding: EdgeInsets.zero,
                                          icon: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
                                          onSelected: (v) {
                                            if (v == 'edit') _showFormDialog(docId: id, data: data);
                                            if (v == 'delete') _excluirTransacao(id);
                                          },
                                          itemBuilder: (ctx) => [
                                            const PopupMenuItem(value: 'edit', child: Text("Editar")),
                                            const PopupMenuItem(value: 'delete', child: Text("Excluir", style: TextStyle(color: Colors.red))),
                                          ],
                                        )
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: isAdmin 
        ? FloatingActionButton(
            backgroundColor: Colors.green[800],
            onPressed: () => _showFormDialog(),
            child: const Icon(Icons.add, color: Colors.white),
          )
        : null,
    );
  }

  Widget _buildInfoColumn(String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          NumberFormat.simpleCurrency(locale: 'pt_BR').format(value),
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ],
    );
  }
}