import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
// Certifique-se de que este arquivo existe e tem a classe PdfGenerator
import '../services/pdf_generator.dart'; 

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  DateTime _mesAtual = DateTime.now();
  
  // Variáveis para controle de acesso
  String _userRole = ''; 
  bool _isLoadingRole = true;

  // Controladores do Formulário
  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _descricaoController = TextEditingController();
  final TextEditingController _valorController = TextEditingController();
  
  String _tipoSelecionado = 'entrada';
  String _categoriaSelecionada = 'Dízimo';
  
  final List<String> _categoriasEntrada = ['Dízimo', 'Oferta', 'EBD', 'Outros'];
  
  final List<String> _categoriasSaida = ['Prebenda Pastoral','INSS Pastor', 'FGTM', 'Ajuda de Custo Zeladoria',
  'INSS Zeladoria', 'FGTS Zeladoria', 'Neoenergia (igreja)', 'Neoenergia (comunidade)', 'Compesa', 
  'Internet', 'GFIP', 'Material de Limpeza', 'Descartáveis', 'Ítens da Sta Ceia', 'Ofertas Missionárias','Assistência Social',
  'Papelaria', 'Man. do Templo', 'Man. do Som','UIECB','KOINONIA', 'Outros'];

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('pt_BR', null);
    _checkUserRole();
  }

  // --- BUSCA A FUNÇÃO DO USUÁRIO NO BANCO ---
  Future<void> _checkUserRole() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        DocumentSnapshot doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists) {
          setState(() {
            _userRole = doc.get('role') ?? 'membro';
            _isLoadingRole = false;
          });
        }
      } catch (e) {
        print("Erro ao verificar permissão: $e");
        setState(() => _isLoadingRole = false);
      }
    }
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

  // --- 1. FUNÇÃO DE EXPORTAR PDF (APENAS FINANCEIRO) ---
  Future<void> _gerarPdfMensal() async {
    // Mostra indicador de carregamento
    showDialog(
      context: context, 
      barrierDismissible: false, 
      builder: (c) => const Center(child: CircularProgressIndicator())
    );

    try {
      // Busca os dados do mês atual para o PDF
      var snapshot = await FirebaseFirestore.instance
          .collection('financas')
          .where('data', isGreaterThanOrEqualTo: Timestamp.fromDate(_getInicioMes()))
          .where('data', isLessThanOrEqualTo: Timestamp.fromDate(_getFimMes()))
          .orderBy('data', descending: false) // Ordem cronológica para o relatório
          .get();

      // Fecha o loading
      if (mounted) Navigator.pop(context); 

      if (snapshot.docs.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sem dados neste mês para gerar PDF.")));
        return;
      }

      // --- CHAMADA REAL AO GERADOR DE PDF ---
      await PdfGenerator.generateFinanceReport(_mesAtual, snapshot.docs);

    } catch (e) {
      // Garante que o loading feche em caso de erro
      if (mounted && Navigator.canPop(context)) {
         Navigator.pop(context);
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao gerar PDF: $e")));
    }
  }

  // --- 2. FUNÇÃO DE RESUMO ANUAL (ADMIN E FINANCEIRO) ---
  Future<void> _mostrarRelatorioAnual() async {
    int ano = _mesAtual.year;
    DateTime inicioAno = DateTime(ano, 1, 1);
    DateTime fimAno = DateTime(ano, 12, 31, 23, 59, 59);

    showDialog(
      context: context, 
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator())
    );

    try {
      var snapshot = await FirebaseFirestore.instance
          .collection('financas')
          .where('data', isGreaterThanOrEqualTo: Timestamp.fromDate(inicioAno))
          .where('data', isLessThanOrEqualTo: Timestamp.fromDate(fimAno))
          .get();

      double totalEntrada = 0;
      double totalSaida = 0;

      for (var doc in snapshot.docs) {
        double valor = (doc['valor'] ?? 0).toDouble();
        if (doc['tipo'] == 'entrada') {
          totalEntrada += valor;
        } else {
          totalSaida += valor;
        }
      }
      double saldo = totalEntrada - totalSaida;

      if (mounted) Navigator.pop(context); // Fecha loading

      // MOSTRA O RESULTADO
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Column(
              children: [
                const Text("Resumo Anual", style: TextStyle(fontWeight: FontWeight.bold)),
                Text("$ano", style: const TextStyle(fontSize: 14, color: Colors.grey)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildInfoColumn("Total Entradas", totalEntrada, Colors.green),
                const Divider(),
                _buildInfoColumn("Total Saídas", totalSaida, Colors.red),
                const Divider(),
                _buildInfoColumn("Saldo Anual", saldo, saldo >= 0 ? Colors.blue[800]! : Colors.red[800]!),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Fechar")),
            ],
          ),
        );
      }

    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao calcular anual: $e")));
    }
  }

  // --- LÓGICA DE CRUD ---
  Future<void> _salvarTransacao({String? docId}) async {
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
        'nome': _nomeController.text.trim(),
        'descricao': _descricaoController.text.trim(),
        'valor': valor,
        'data': Timestamp.fromDate(DateTime.now()), 
        'mes_referencia': Timestamp.fromDate(_mesAtual),
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
      _nomeController.text = data['nome'] ?? '';
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

                    // CAMPO NOME
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
                      // AQUI FOI REMOVIDO O 'const' QUE CAUSAVA O ERRO
                      decoration: const InputDecoration(
                        labelText: "Valor (R\$)", 
                        hintText: "0,00", 
                        border: OutlineInputBorder(), 
                        prefixIcon: Icon(Icons.attach_money)
                      ),
                    ),
                    const SizedBox(height: 12),

                    // CATEGORIA
                    DropdownButtonFormField<String>(
                      value: _categoriaSelecionada,
                      // AQUI TAMBÉM REMOVIDO O 'const'
                      decoration: const InputDecoration(labelText: "Categoria", border: OutlineInputBorder()),
                      items: categoriasAtuais.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (val) => setStateDialog(() => _categoriaSelecionada = val!),
                    ),
                    const SizedBox(height: 12),

                    // DESCRIÇÃO
                    TextField(
                      controller: _descricaoController,
                      // AQUI TAMBÉM REMOVIDO O 'const'
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
    if (_isLoadingRole) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Permissões
    bool isFinanceiro = _userRole == 'financeiro';
    bool isAdmin = _userRole == 'admin';

    // Se não for nem admin nem financeiro, mostra acesso negado
    if (!isFinanceiro && !isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text("Financeiro"), backgroundColor: Colors.green[800]),
        body: const Center(child: Text("Você não tem acesso a este módulo.", style: TextStyle(color: Colors.grey))),
      );
    }

    String mesFormatado = DateFormat('MMMM yyyy', 'pt_BR').format(_mesAtual).toUpperCase();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Financeiro", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.green[800],
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // BOTÃO RESUMO ANUAL (ADMIN E FINANCEIRO)
          if (isAdmin || isFinanceiro)
            IconButton(
              icon: const Icon(Icons.analytics_outlined),
              tooltip: "Resumo Anual",
              onPressed: _mostrarRelatorioAnual,
            ),
          
          // BOTÃO EXPORTAR PDF (APENAS FINANCEIRO)
          if (isFinanceiro)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              tooltip: "Exportar PDF do Mês",
              onPressed: _gerarPdfMensal,
            ),
            
          const SizedBox(width: 10),
        ],
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

          // --- CONTEÚDO (STREAM) ---
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

                // --- CÁLCULO GERAL (COMUM A TODOS) ---
                double totalEntrada = 0;
                double totalSaida = 0;
                
                // --- CÁLCULOS ESPECÍFICOS PARA O DASHBOARD DO ADMIN ---
                double totalDizimo = 0;
                double totalOferta = 0;
                double totalEBD = 0;
                double totalOutrasEntradas = 0;

                for (var doc in docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  double valor = (data['valor'] ?? 0).toDouble();
                  String cat = data['categoria'] ?? '';

                  if (data['tipo'] == 'entrada') {
                    totalEntrada += valor;
                    if (cat == 'Dízimo') totalDizimo += valor;
                    else if (cat == 'Oferta') totalOferta += valor;
                    else if (cat == 'EBD') totalEBD += valor;
                    else totalOutrasEntradas += valor;
                  } else {
                    totalSaida += valor;
                  }
                }
                double saldo = totalEntrada - totalSaida;

                // ---------------------------------------------
                // VISÃO DE ADMINISTRADOR (DASHBOARD RESUMIDO)
                // ---------------------------------------------
                if (isAdmin) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                         // CARD DE SALDO GERAL
                        _buildSaldoCard(totalEntrada, totalSaida, saldo),
                        const SizedBox(height: 20),
                        
                        const Text("Detalhamento de Entradas", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 10),
                        
                        // GRID DE ENTRADAS
                        GridView.count(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          childAspectRatio: 1.5,
                          children: [
                            _buildDashCard("Dízimos", totalDizimo, Colors.green),
                            _buildDashCard("Ofertas", totalOferta, Colors.lightGreen),
                            _buildDashCard("EBD", totalEBD, Colors.teal),
                            _buildDashCard("Outros", totalOutrasEntradas, Colors.blueGrey),
                          ],
                        ),

                        const SizedBox(height: 20),
                        const Text("Resumo de Saídas", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 10),
                         _buildDashCard("Total de Despesas", totalSaida, Colors.red, isWide: true),
                      ],
                    ),
                  );
                }

                // ---------------------------------------------
                // VISÃO DO FINANCEIRO (COMPLETA COM LISTA)
                // ---------------------------------------------
                return Column(
                  children: [
                    // CARD DE SALDO
                    Transform.translate(
                      offset: const Offset(0, -25),
                      child: _buildSaldoCard(totalEntrada, totalSaida, saldo),
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
                              String nome = data['nome'] ?? "";
                              String descricao = data['descricao'] ?? "";
                              DateTime dataTransacao = (data['data'] as Timestamp).toDate();
                              String dia = DateFormat('dd/MM').format(dataTransacao);

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
      // Botão Flutuante (Apenas para Financeiro)
      floatingActionButton: (isFinanceiro) 
        ? FloatingActionButton(
            backgroundColor: Colors.green[800],
            onPressed: () => _showFormDialog(),
            child: const Icon(Icons.add, color: Colors.white),
          )
        : null,
    );
  }

  // --- WIDGETS AUXILIARES ---

  Widget _buildSaldoCard(double entrada, double saida, double saldo) {
    return Container(
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
          _buildInfoColumn("Entradas", entrada, Colors.green),
          _buildInfoColumn("Saídas", saida, Colors.red),
          Container(width: 1, height: 40, color: Colors.grey[300]),
          _buildInfoColumn("Saldo", saldo, saldo >= 0 ? Colors.blue[800]! : Colors.red[800]!),
        ],
      ),
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

  Widget _buildDashCard(String title, double value, Color color, {bool isWide = false}) {
    return Container(
      width: isWide ? double.infinity : null,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            NumberFormat.simpleCurrency(locale: 'pt_BR').format(value),
            style: TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}