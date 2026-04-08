import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http; // NOVO PACOTE PARA BAIXAR A IMAGEM

class DevocionalScreen extends StatefulWidget {
  const DevocionalScreen({super.key});

  @override
  State<DevocionalScreen> createState() => _DevocionalScreenState();
}

class _DevocionalScreenState extends State<DevocionalScreen> {
  final TextEditingController _tituloController = TextEditingController();
  final TextEditingController _versiculoController = TextEditingController();
  final TextEditingController _textoController = TextEditingController();
  final TextEditingController _autorController = TextEditingController();
  
  final ImagePicker _picker = ImagePicker();

  // --- FUNÇÃO PARA ADICIONAR DEVOCIONAL ---
  void _showAddDialog(BuildContext context) {
    _tituloController.clear();
    _versiculoController.clear();
    _textoController.clear();
    _autorController.clear();
    
    XFile? imagemSelecionada;
    Uint8List? imagemBytes; 
    bool isSavingLocal = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("Novo Devocional"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // --- SELEÇÃO DE IMAGEM ---
                    InkWell(
                      onTap: isSavingLocal ? null : () async {
                        final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
                        if (image != null) {
                          var bytes = await image.readAsBytes();
                          setStateDialog(() {
                            imagemSelecionada = image;
                            imagemBytes = bytes;
                          });
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        height: 150,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey[400]!, style: BorderStyle.solid),
                        ),
                        child: imagemBytes != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.memory(imagemBytes!, fit: BoxFit.cover, width: double.infinity),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_photo_alternate, size: 40, color: Colors.grey[600]),
                                  const SizedBox(height: 8),
                                  Text("Adicionar Imagem de Capa", style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.bold)),
                                  Text("(Opcional)", style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                                ],
                              ),
                      ),
                    ),
                    if (imagemBytes != null)
                      TextButton(
                        onPressed: isSavingLocal ? null : () => setStateDialog(() { imagemSelecionada = null; imagemBytes = null; }),
                        child: const Text("Remover imagem", style: TextStyle(color: Colors.red)),
                      ),
                    
                    const SizedBox(height: 15),
                    TextField(
                      controller: _tituloController,
                      decoration: const InputDecoration(labelText: "Título", border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _autorController,
                      decoration: const InputDecoration(labelText: "Autor", border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _versiculoController,
                      decoration: const InputDecoration(labelText: "Versículo Chave", border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _textoController,
                      maxLines: 8,
                      decoration: const InputDecoration(labelText: "Mensagem", border: OutlineInputBorder(), alignLabelWithHint: true),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSavingLocal ? null : () => Navigator.pop(ctx), 
                  child: const Text("Cancelar", style: TextStyle(color: Colors.grey))
                ),
                ElevatedButton(
                  onPressed: isSavingLocal ? null : () async {
                    if (_tituloController.text.isEmpty || _textoController.text.isEmpty || _autorController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Preencha Título, Autor e Mensagem.")));
                      return;
                    }
                    
                    setStateDialog(() => isSavingLocal = true);

                    try {
                      final user = FirebaseAuth.instance.currentUser;
                      String? imageUrl;

                      if (imagemBytes != null) {
                        final storageRef = FirebaseStorage.instance.ref().child('devocionais/${DateTime.now().millisecondsSinceEpoch}.jpg');
                        await storageRef.putData(imagemBytes!); 
                        imageUrl = await storageRef.getDownloadURL(); 
                      }
                      
                      await FirebaseFirestore.instance.collection('devocionais').add({
                        'titulo': _tituloController.text.trim(),
                        'versiculo': _versiculoController.text.trim(),
                        'texto': _textoController.text,
                        'data': FieldValue.serverTimestamp(),
                        'autor_uid': user?.uid, 
                        'autor_nome': _autorController.text.trim(), 
                        'imagem_url': imageUrl, 
                      });
                      
                      if (mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Devocional publicado!"), backgroundColor: Colors.green));
                      }
                      
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao publicar: $e"), backgroundColor: Colors.red));
                      }
                    } finally {
                      if (mounted) setStateDialog(() => isSavingLocal = false);
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
                  child: isSavingLocal 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                    : const Text("PUBLICAR", style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          }
        );
      }
    );
  }

  // --- TELA DE LEITURA COMPLETA E COMPARTILHAMENTO ---
  void _openDetail(Map<String, dynamic> data) {
    String dataExtensa = "";
    if (data['data'] != null) {
      dataExtensa = DateFormat("d 'de' MMMM 'de' y", "pt_BR").format((data['data'] as Timestamp).toDate());
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text("Leitura", style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.indigo,
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              // --- BOTÃO DE COMPARTILHAMENTO COM IMAGEM ---
              IconButton(
                icon: const Icon(Icons.share),
                tooltip: "Compartilhar Devocional",
                onPressed: () async {
                  String titulo = data['titulo'] ?? "Devocional";
                  String autor = data['autor_nome'] ?? "Autor Desconhecido";
                  String versiculo = data['versiculo'] ?? "";
                  String texto = data['texto'] ?? "";
                  String? imageUrl = data['imagem_url'];

                  // Prepara o texto formatado
                  StringBuffer sb = StringBuffer();
                  sb.writeln("📖 *$titulo*");
                  sb.writeln("✍️ Por: $autor");
                  if (dataExtensa.isNotEmpty) sb.writeln("📅 $dataExtensa");
                  sb.writeln(); 
                  
                  if (versiculo.isNotEmpty) {
                    sb.writeln("_\"$versiculo\"_");
                    sb.writeln(); 
                  }
                  
                  sb.writeln(texto);
                  sb.writeln(); 

                  // Lógica de envio: Com Imagem ou Só Texto
                  if (imageUrl != null && imageUrl.isNotEmpty) {
                    // Mostra um loading enquanto baixa a imagem pro celular
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.white)),
                    );

                    try {
                      // Baixa a imagem da internet
                      final response = await http.get(Uri.parse(imageUrl));
                      
                      // Transforma a imagem num arquivo temporário do celular para enviar pro Zap
                      final xFile = XFile.fromData(
                        response.bodyBytes, 
                        mimeType: 'image/jpeg', 
                        name: 'devocional.jpg'
                      );

                      if (mounted) Navigator.pop(context); // Fecha o loading
                      
                      // Compartilha Foto + Texto
                      await Share.shareXFiles([xFile], text: sb.toString().trim());

                    } catch (e) {
                      if (mounted) Navigator.pop(context); // Fecha o loading se der erro
                      // Se a imagem falhar por algum motivo (net fraca), envia só o texto
                      await Share.share(sb.toString().trim());
                    }
                  } else {
                    // Se o devocional não tem imagem, compartilha só o texto direto
                    await Share.share(sb.toString().trim());
                  }
                },
              ),
            ],
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (data['imagem_url'] != null && data['imagem_url'].toString().isNotEmpty)
                  Image.network(
                    data['imagem_url'],
                    width: double.infinity,
                    height: 250,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return SizedBox(height: 250, child: Center(child: CircularProgressIndicator(value: loadingProgress.expectedTotalBytes != null ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes! : null)));
                    },
                    errorBuilder: (context, error, stackTrace) => Container(height: 250, color: Colors.grey[200], child: const Center(child: Icon(Icons.broken_image, size: 50, color: Colors.grey))),
                  ),
                
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data['titulo'] ?? "", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.indigo)),
                      const SizedBox(height: 10),
                      
                      Row(
                        children: [
                          if (dataExtensa.isNotEmpty)
                            Text(dataExtensa, style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic, fontSize: 13)),
                          
                          if (dataExtensa.isNotEmpty && data['autor_nome'] != null)
                            Text(" • ", style: TextStyle(color: Colors.grey[600])),
                          
                          if (data['autor_nome'] != null)
                            Expanded(
                              child: Text(
                                "Por: ${data['autor_nome']}",
                                style: TextStyle(color: Colors.indigo[800], fontWeight: FontWeight.bold, fontStyle: FontStyle.italic, fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),

                      const SizedBox(height: 20),
                      if (data['versiculo'] != null && data['versiculo'].toString().isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(15),
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.indigo[50],
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.indigo[100]!),
                          ),
                          child: Text(
                            "\"${data['versiculo']}\"",
                            style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic, color: Colors.indigo[900]),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      const SizedBox(height: 25),
                      Text(
                        data['texto'] ?? "",
                        style: const TextStyle(fontSize: 18, height: 1.6, color: Colors.black87),
                        textAlign: TextAlign.justify,
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: CircularProgressIndicator());

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, userSnapshot) {
        
        bool canPost = false;
        if (userSnapshot.hasData && userSnapshot.data!.exists) {
           final userData = userSnapshot.data!.data() as Map<String, dynamic>;
           String role = userData['role'] ?? 'membro';
           canPost = role == 'admin' || role == 'financeiro'; 
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text("Pão Diário", style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.indigo,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          backgroundColor: Colors.grey[100],
          
          floatingActionButton: canPost 
            ? FloatingActionButton(
                backgroundColor: Colors.indigo,
                onPressed: () => _showAddDialog(context),
                child: const Icon(Icons.add, color: Colors.white),
              )
            : null,

          body: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('devocionais').orderBy('data', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text("Nenhum devocional postado ainda.", style: TextStyle(color: Colors.grey)));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final doc = snapshot.data!.docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final id = doc.id;

                  String dataFormatada = "";
                  if (data['data'] != null) {
                    dataFormatada = DateFormat('dd/MM').format((data['data'] as Timestamp).toDate());
                  }

                  // --- NOVO CARD PEQUENO E COMPACTO ---
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    child: InkWell(
                      onTap: () => _openDetail(data),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(color: Colors.orange[100], borderRadius: BorderRadius.circular(6)),
                                      child: Text(dataFormatada, style: TextStyle(color: Colors.orange[900], fontWeight: FontWeight.bold, fontSize: 11)),
                                    ),
                                    if (data['autor_nome'] != null) ...[
                                      const SizedBox(width: 8),
                                      Text(
                                        "• ${data['autor_nome']}",
                                        style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic),
                                      ),
                                    ]
                                  ],
                                ),
                                if (canPost)
                                  IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    icon: const Icon(Icons.delete, color: Colors.grey, size: 18),
                                    onPressed: () async {
                                      bool confirm = await showDialog(
                                        context: context, 
                                        builder: (ctx) => AlertDialog(
                                          title: const Text("Excluir"), content: const Text("Apagar devocional?"),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Não")),
                                            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Sim", style: TextStyle(color: Colors.red)))
                                          ]
                                        )
                                      ) ?? false;

                                      if (confirm) {
                                        if (data['imagem_url'] != null && data['imagem_url'].toString().isNotEmpty) {
                                          try {
                                            await FirebaseStorage.instance.refFromURL(data['imagem_url']).delete();
                                          } catch (e) {
                                            debugPrint("Aviso: Falha ao apagar imagem do storage: $e");
                                          }
                                        }
                                        await FirebaseFirestore.instance.collection('devocionais').doc(id).delete();
                                      }
                                    },
                                  )
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              data['titulo'] ?? "Sem Título",
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.indigo),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}