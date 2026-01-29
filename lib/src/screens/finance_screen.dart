import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart'; 
import 'package:image_picker/image_picker.dart'; 
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter/services.dart'; // NECESSÁRIO PARA COPIAR O PIX
import '../services/pdf_generator.dart'; 

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  DateTime _mesAtual = DateTime.now();
  String _userRole = ''; 
  bool _isLoadingRole = true;

  // Controladores
  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _descricaoController = TextEditingController();
  final TextEditingController _valorController = TextEditingController();
  
  String _tipoSelecionado = 'entrada';
  String _categoriaSelecionada = 'Dízimo';
  
  // Variáveis para Imagem
  File? _imageFile; 
  String? _imageUrl; 
  final ImagePicker _picker = ImagePicker();

  final List<String> _categoriasEntrada = ['Dízimo', 'Oferta', 'EBD', 'Outros'];
  final List<String> _categoriasSaida = ['Prebenda Pastoral','INSS Pastor', 'FGTM', 'Ajuda de Custo Zeladoria', 'INSS Zeladoria', 'FGTS Zeladoria', 'Neoenergia (igreja)', 'Neoenergia (comunidade)', 'Compesa', 'Internet', 'GFIP', 'Material de Limpeza', 'Descartáveis', 'Ítens da Sta Ceia', 'Ofertas Missionárias','Assistência Social', 'Papelaria', 'Man. do Templo', 'Man. do Som','UIECB','KOINONIA', 'Outros'];

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('pt_BR', null);
    _checkUserRole();
  }

  Future<void> _checkUserRole() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        DocumentSnapshot doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists && mounted) {
          setState(() {
            _userRole = doc.get('role') ?? 'membro';
            _isLoadingRole = false;
          });
        }
      } catch (e) {
        if(mounted) setState(() => _isLoadingRole = false);
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

  // --- DATAS ---
  void _trocarMes(int meses) {
    setState(() {
      _mesAtual = DateTime(_mesAtual.year, _mesAtual.month + meses, 1);
    });
  }
  DateTime _getInicioMes() => DateTime(_mesAtual.year, _mesAtual.month, 1);
  DateTime _getFimMes() => DateTime(_mesAtual.year, _mesAtual.month + 1, 0, 23, 59, 59);

  // --- POPUP DE DADOS BANCÁRIOS ---
  void _exibirDadosBancarios() {
    const String pixKey = "30057670000105"; 

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.pix, color: Colors.green),
            SizedBox(width: 10),
            Text("Dados para PIX"),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text("Chave PIX (CNPJ):", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(pixKey, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                    IconButton(
                      icon: const Icon(Icons.copy, color: Colors.blue),
                      onPressed: () {
                        Clipboard.setData(const ClipboardData(text: pixKey));
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Chave PIX copiada!"), backgroundColor: Colors.green),
                        );
                      },
                    )
                  ],
                ),
              ),
              const SizedBox(height: 15),
              const Text("Ou escaneie o QR Code:", style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 5),
              Image.asset('assets/images/qrcode_pix.png', height: 150, errorBuilder: (context, error, stackTrace) => const Icon(Icons.qr_code_2, size: 100)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Fechar")),
        ],
      ),
    );
  }

  // --- SELEÇÃO DE IMAGEM OTIMIZADA ---
  Future<void> _pickImage(StateSetter setStateDialog) async {
    showModalBottomSheet(
      context: context,
      builder: (context) => Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text('Tirar Foto'),
            onTap: () async {
              Navigator.pop(context);
              final XFile? photo = await _picker.pickImage(
                source: ImageSource.camera,
                imageQuality: 25, 
                maxWidth: 800,    
                maxHeight: 800,   
              );
              if (photo != null) {
                setStateDialog(() => _imageFile = File(photo.path));
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Galeria'),
            onTap: () async {
              Navigator.pop(context);
              final XFile? image = await _picker.pickImage(
                source: ImageSource.gallery,
                imageQuality: 25, 
                maxWidth: 800,    
                maxHeight: 800,
              );
              if (image != null) {
                setStateDialog(() => _imageFile = File(image.path));
              }
            },
          ),
        ],
      ),
    );
  }

  // --- UPLOAD DE IMAGEM ---
  Future<String?> _uploadImage() async {
    if (_imageFile == null) return _imageUrl; 

    try {
      String fileName = DateTime.now().millisecondsSinceEpoch.toString();
      Reference ref = FirebaseStorage.instance.ref().child('comprovantes/$fileName.jpg');
      UploadTask uploadTask = ref.putFile(_imageFile!);
      TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print("Erro no upload: $e");
      return null;
    }
  }

  // --- SALVAR ---
  Future<void> _salvarTransacao({String? docId}) async {
    if (_valorController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("O valor é obrigatório.")));
      return;
    }

    setState(() => _isSaving = true); 

    try {
      String? downloadUrl = await _uploadImage();

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
        'comprovante_url': downloadUrl, 
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

  // --- EXCLUIR ---
  Future<void> _excluirTransacao(String docId, String? imageUrl) async {
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
      if (imageUrl != null && imageUrl.isNotEmpty) {
        try {
          await FirebaseStorage.instance.refFromURL(imageUrl).delete();
        } catch (e) {
          print("Erro ao deletar imagem antiga: $e");
        }
      }
      await FirebaseFirestore.instance.collection('financas').doc(docId).delete();
    }
  }

  // --- VISUALIZAR COMPROVANTE ---
  void _verComprovante(String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InteractiveViewer(child: Image.network(url)),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Fechar"))
          ],
        ),
      ),
    );
  }

  // --- FORMULÁRIO ---
  void _showFormDialog({String? docId, Map<String, dynamic>? data}) {
    _imageFile = null; 
    
    if (data != null) {
      _tipoSelecionado = data['tipo'];
      _categoriaSelecionada = data['categoria'];
      _nomeController.text = data['nome'] ?? '';
      _descricaoController.text = data['descricao'] ?? '';
      _valorController.text = (data['valor'] as double).toStringAsFixed(2).replaceAll('.', ',');
      _imageUrl = data['comprovante_url'];
    } else {
      _tipoSelecionado = 'entrada';
      _categoriaSelecionada = 'Dízimo';
      _nomeController.clear();
      _descricaoController.clear();
      _valorController.clear();
      _imageUrl = null;
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

                    TextField(
                      controller: _nomeController,
                      decoration: const InputDecoration(
                        labelText: "Nome (Pessoa/Empresa)", 
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person_outline)
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: _valorController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: "Valor (R\$)", 
                        hintText: "0,00", 
                        border: OutlineInputBorder(), 
                        prefixIcon: Icon(Icons.attach_money)
                      ),
                    ),
                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      value: _categoriaSelecionada,
                      decoration: const InputDecoration(labelText: "Categoria", border: OutlineInputBorder()),
                      items: categoriasAtuais.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (val) => setStateDialog(() => _categoriaSelecionada = val!),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: _descricaoController,
                      decoration: const InputDecoration(labelText: "Observação / Detalhes", border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 20),

                    GestureDetector(
                      onTap: () => _pickImage(setStateDialog),
                      child: Container(
                        width: double.infinity,
                        height: 150,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          border: Border.all(color: Colors.grey[400]!),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: _imageFile != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.file(_imageFile!, fit: BoxFit.cover),
                            )
                          : (_imageUrl != null && _imageUrl!.isNotEmpty)
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(_imageUrl!, fit: BoxFit.cover),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.camera_alt, size: 40, color: Colors.grey),
                                  SizedBox(height: 8),
                                  Text("Anexar Comprovante", style: TextStyle(color: Colors.grey)),
                                  Text("(Qualidade Otimizada)", style: TextStyle(color: Colors.grey, fontSize: 10)),
                                ],
                              ),
                      ),
                    ),
                    if (_imageFile != null || (_imageUrl != null && _imageUrl!.isNotEmpty))
                      TextButton.icon(
                        onPressed: () {
                          setStateDialog(() {
                            _imageFile = null;
                            _imageUrl = null;
                          });
                        },
                        icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                        label: const Text("Remover Imagem", style: TextStyle(color: Colors.red)),
                      )
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

  // --- PDF ---
  Future<void> _gerarPdfMensal() async {
     showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));
     try {
       var snapshot = await FirebaseFirestore.instance.collection('financas').where('data', isGreaterThanOrEqualTo: Timestamp.fromDate(_getInicioMes())).where('data', isLessThanOrEqualTo: Timestamp.fromDate(_getFimMes())).orderBy('data', descending: false).get();
       if(mounted) Navigator.pop(context);
       if(snapshot.docs.isEmpty) { if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sem dados."))); return; }
       await PdfGenerator.generateFinanceReport(_mesAtual, snapshot.docs);
     } catch (e) { if(mounted) Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro PDF: $e"))); }
  }

  // --- RELATÓRIO ANUAL (CORRIGIDO COM CORES) ---
  Future<void> _mostrarRelatorioAnual() async {
     int ano = _mesAtual.year;
     DateTime inicio = DateTime(ano, 1, 1);
     DateTime fim = DateTime(ano, 12, 31, 23, 59, 59);
     showDialog(context: context, builder: (c) => const Center(child: CircularProgressIndicator()));
     try {
       var snap = await FirebaseFirestore.instance.collection('financas').where('data', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio)).where('data', isLessThanOrEqualTo: Timestamp.fromDate(fim)).get();
       double ent = 0, sai = 0;
       for(var doc in snap.docs) { if(doc['tipo']=='entrada') ent += (doc['valor']??0); else sai += (doc['valor']??0); }
       double saldo = ent - sai;

       if(mounted) Navigator.pop(context); // Fecha loading
       
       if(mounted) {
         showDialog(
           context: context, 
           builder: (ctx) => AlertDialog(
             title: Text("Resumo $ano"), 
             content: Column(
               mainAxisSize: MainAxisSize.min,
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 _buildSummaryRow("Entradas", ent, Colors.green),
                 const SizedBox(height: 10),
                 _buildSummaryRow("Saídas", sai, Colors.red),
                 const Divider(height: 20),
                 _buildSummaryRow("Saldo", saldo, Colors.blue[800]!),
               ],
             ), 
             actions: [
               TextButton(onPressed:()=>Navigator.pop(ctx), child: const Text("OK"))
             ]
           )
         );
       }
     } catch(e) { if(mounted) Navigator.pop(context); }
  }

  // Helper para as linhas do resumo anual
  Widget _buildSummaryRow(String label, double value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 16, color: Colors.grey[700])),
        Text(
          NumberFormat.simpleCurrency(locale: 'pt_BR').format(value),
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)
        ),
      ],
    );
  }

  // --- WIDGETS AUXILIARES ---
  Widget _buildSaldoCard(double entrada, double saida, double saldo) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, 5))]),
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
    return Column(crossAxisAlignment: CrossAxisAlignment.center, children: [Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)), const SizedBox(height: 4), Text(NumberFormat.simpleCurrency(locale: 'pt_BR').format(value), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14))]);
  }

  Widget _buildDashCard(String title, double value, Color color, {bool isWide = false}) {
    return Container(
      width: isWide ? double.infinity : null, padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.3))),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold)), const SizedBox(height: 8), Text(NumberFormat.simpleCurrency(locale: 'pt_BR').format(value), style: TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.bold))]),
    );
  }

  // --- TELA ESPECIAL PARA MEMBROS (VISUALIZAÇÃO DIRETA) ---
  Widget _buildMemberView() {
    const String pixKey = "30057670000105"; 

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.handshake, size: 60, color: Colors.green),
          const SizedBox(height: 10),
          const Text(
            "Contribuição",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green),
          ),
          const Text(
            "Dízimos e Ofertas",
            style: TextStyle(fontSize: 16, color: Colors.black54),
          ),
          const SizedBox(height: 20),

          // CARTÃO DE DADOS BANCÁRIOS
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text("Chave PIX (CNPJ):", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!)
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(pixKey, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87))),
                        IconButton(
                          icon: const Icon(Icons.copy, color: Colors.blue),
                          tooltip: "Copiar PIX",
                          onPressed: () {
                            Clipboard.setData(const ClipboardData(text: pixKey));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Chave PIX copiada!"), backgroundColor: Colors.green),
                            );
                          },
                        )
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  const Text("Ou escaneie o QR Code:", style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 10),
                  
                  // QR CODE IMAGEM
                  Image.asset(
                    'assets/images/qrcode_pix.png', 
                    height: 200,
                    errorBuilder: (context, error, stackTrace) => Column(
                      children: const [
                        Icon(Icons.qr_code_2, size: 80, color: Colors.grey),
                        Text("QR Code não encontrado", style: TextStyle(fontSize: 10))
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 30),
          
          // VERSÍCULO
          const Text(
            "\"Cada um contribua segundo propôs no seu coração; não com tristeza, ou por necessidade; porque Deus ama ao que dá com alegria.\"",
            textAlign: TextAlign.center,
            style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 5),
          const Text(
            "2 Coríntios 9:7",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingRole) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    bool isFinanceiro = _userRole == 'financeiro';
    bool isAdmin = _userRole == 'admin';
    bool hasFullAccess = isAdmin || isFinanceiro;

    String mesFormatado = DateFormat('MMMM yyyy', 'pt_BR').format(_mesAtual).toUpperCase();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Financeiro", style: TextStyle(color: Colors.white)), backgroundColor: Colors.green[800], iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // Ícone do Banco visível para TODOS
          if (hasFullAccess) IconButton(icon: const Icon(Icons.pix), onPressed: _exibirDadosBancarios, tooltip: "Dados PIX"),
          
          if (hasFullAccess) IconButton(icon: const Icon(Icons.analytics_outlined), onPressed: _mostrarRelatorioAnual),
          if (isFinanceiro) IconButton(icon: const Icon(Icons.picture_as_pdf), onPressed: _gerarPdfMensal),
          const SizedBox(width: 10),
        ],
      ),
      backgroundColor: Colors.grey[100],
      
      // SE FOR MEMBRO, MOSTRA TELA SIMPLIFICADA COM DADOS BANCÁRIOS DIRETO
      // SE FOR ADMIN/FINANCEIRO, MOSTRA O DASHBOARD
      body: hasFullAccess 
        ? Column(
            children: [
              Container(
                color: Colors.green[800], padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white70), onPressed: () => _trocarMes(-1)), Text(mesFormatado, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)), IconButton(icon: const Icon(Icons.arrow_forward_ios, color: Colors.white70), onPressed: () => _trocarMes(1))]),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('financas').where('data', isGreaterThanOrEqualTo: Timestamp.fromDate(_getInicioMes())).where('data', isLessThanOrEqualTo: Timestamp.fromDate(_getFimMes())).orderBy('data', descending: true).snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) return const Center(child: Text("Erro ao carregar dados."));
                    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                    final docs = snapshot.data!.docs;
                    
                    double totalEntrada = 0, totalSaida = 0, totalDizimo = 0, totalOferta = 0, totalEBD = 0, totalOutros = 0;
                    for (var doc in docs) {
                      final d = doc.data() as Map<String, dynamic>;
                      double v = (d['valor'] ?? 0).toDouble();
                      if (d['tipo'] == 'entrada') {
                        totalEntrada += v;
                        if (d['categoria'] == 'Dízimo') totalDizimo += v; else if (d['categoria'] == 'Oferta') totalOferta += v; else if (d['categoria'] == 'EBD') totalEBD += v; else totalOutros += v;
                      } else { totalSaida += v; }
                    }
                    double saldo = totalEntrada - totalSaida;

                    if (isAdmin) {
                      return SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [_buildSaldoCard(totalEntrada, totalSaida, saldo), const SizedBox(height: 20), GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), childAspectRatio: 1.5, crossAxisSpacing: 10, mainAxisSpacing: 10, children: [_buildDashCard("Dízimos", totalDizimo, Colors.green), _buildDashCard("Ofertas", totalOferta, Colors.lightGreen), _buildDashCard("EBD", totalEBD, Colors.teal), _buildDashCard("Outros", totalOutros, Colors.blueGrey)]), const SizedBox(height: 20), _buildDashCard("Total Saídas", totalSaida, Colors.red, isWide: true)]));
                    }

                    return Column(
                      children: [
                        Transform.translate(offset: const Offset(0, -25), child: _buildSaldoCard(totalEntrada, totalSaida, saldo)),
                        Expanded(
                          child: docs.isEmpty ? const Center(child: Text("Nenhum lançamento.")) : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 10), itemCount: docs.length,
                            itemBuilder: (context, index) {
                              final data = docs[index].data() as Map<String, dynamic>;
                              final id = docs[index].id;
                              bool isEntrada = data['tipo'] == 'entrada';
                              bool temComprovante = data['comprovante_url'] != null && data['comprovante_url'].toString().isNotEmpty;

                              return Card(
                                margin: const EdgeInsets.only(bottom: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                child: ListTile(
                                  leading: CircleAvatar(backgroundColor: isEntrada ? Colors.green[50] : Colors.red[50], child: Icon(isEntrada ? Icons.arrow_upward : Icons.arrow_downward, color: isEntrada ? Colors.green : Colors.red, size: 20)),
                                  title: Text(data['categoria']??"", style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Row(
                                    children: [
                                      Text(DateFormat('dd/MM').format((data['data'] as Timestamp).toDate())),
                                      if (data['nome'] != null) Text(" - ${data['nome']}"),
                                      if (temComprovante) ...[const SizedBox(width: 5), const Icon(Icons.attach_file, size: 14, color: Colors.blue)]
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text((isEntrada ? "+ " : "- ") + NumberFormat.simpleCurrency(locale: 'pt_BR').format(data['valor']), style: TextStyle(color: isEntrada ? Colors.green[700] : Colors.red[700], fontWeight: FontWeight.bold)),
                                      PopupMenuButton<String>(
                                        icon: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
                                        onSelected: (v) {
                                          if (v == 'edit') _showFormDialog(docId: id, data: data);
                                          if (v == 'delete') _excluirTransacao(id, data['comprovante_url']);
                                          if (v == 'view' && temComprovante) _verComprovante(data['comprovante_url']);
                                        },
                                        itemBuilder: (ctx) => [
                                          if (temComprovante) const PopupMenuItem(value: 'view', child: Text("Ver Comprovante")),
                                          const PopupMenuItem(value: 'edit', child: Text("Editar")),
                                          const PopupMenuItem(value: 'delete', child: Text("Excluir", style: TextStyle(color: Colors.red))),
                                        ]
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
          )
        : _buildMemberView(), // VIEW PARA MEMBROS

      floatingActionButton: (isFinanceiro) ? FloatingActionButton(backgroundColor: Colors.green[800], onPressed: () => _showFormDialog(), child: const Icon(Icons.add, color: Colors.white)) : null,
    );
  }
}