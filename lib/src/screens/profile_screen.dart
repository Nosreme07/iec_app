import 'dart:io'; 
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart'; // IMPORTANTE: PACOTE DE CORTE
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/services.dart';

// --- IMPORTAÇÕES PARA PDF ---
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  // --- FUNÇÃO DE LOGOUT ---
  Future<void> _signOut(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao sair: $e")));
      }
    }
  }

  // --- NOVA FUNÇÃO: CORTAR IMAGEM ---
  Future<File?> _cropImage(File imageFile) async {
    CroppedFile? croppedFile = await ImageCropper().cropImage(
      sourcePath: imageFile.path,
      // Força a proporção 1:1 (Quadrado) para caber no círculo
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Ajustar Foto',
          toolbarColor: Colors.blue[900], // Cor do seu App
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true, // Trava no quadrado
          hideBottomControls: false,
        ),
        IOSUiSettings(
          title: 'Ajustar Foto',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
        ),
      ],
    );

    if (croppedFile != null) {
      return File(croppedFile.path);
    }
    return null;
  }

  // --- FUNÇÃO ALTERAR FOTO (ATUALIZADA COM CROP) ---
  Future<void> _pickAndUploadImage(BuildContext context, String uid) async {
    final ImagePicker picker = ImagePicker();
    
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70, // Qualidade um pouco melhor para o corte
      );

      if (image == null) return;

      File? fileToUpload;
      Uint8List? webBytesToUpload;

      // LÓGICA DE CORTE (APENAS PARA MOBILE)
      if (!kIsWeb) {
        File originalFile = File(image.path);
        // Chama a função de corte
        fileToUpload = await _cropImage(originalFile);
        
        // Se o usuário cancelou o corte, paramos aqui
        if (fileToUpload == null) return; 
      } else {
        // Na Web não usamos o cropper nativo
        webBytesToUpload = await image.readAsBytes();
      }

      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(child: CircularProgressIndicator()),
        );
      }

      Reference ref = FirebaseStorage.instance.ref().child('profile_photos').child('$uid.jpg');
      
      if (kIsWeb) {
        await ref.putData(
          webBytesToUpload!, 
          SettableMetadata(contentType: 'image/jpeg'),
        );
      } else {
        // Upload do arquivo CORTADO
        await ref.putFile(fileToUpload!);
      }

      String downloadUrl = await ref.getDownloadURL();

      // Atualiza Firestore
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'foto_url': downloadUrl,
      });

      if (context.mounted) {
        Navigator.pop(context); // Fecha loading
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Foto atualizada com sucesso!"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      debugPrint("Erro no processo: $e");
      if (context.mounted) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erro ao atualizar foto.")));
      }
    }
  }

  String _gerarTextoQrCode(Map<String, dynamic> data, String uid) {
    String get(String key) => (data[key] ?? "").toString().toUpperCase();
    StringBuffer qrBuffer = StringBuffer();
    qrBuffer.writeln("IEC MORENO - FICHA DE MEMBRO");
    qrBuffer.writeln("================================");
    qrBuffer.writeln("NOME: ${get('nome_completo')}");
    if(get('cpf').isNotEmpty) qrBuffer.writeln("CPF: ${get('cpf')}");
    qrBuffer.writeln("CARGO: ${get('cargo_atual')}");
    qrBuffer.writeln("ID SISTEMA: $uid");
    return qrBuffer.toString();
  }

  Future<void> _generatePdf(BuildContext context, Map<String, dynamic> data, String uid) async {
    final pdf = pw.Document();
    final logoImage = await imageFromAssetBundle('assets/images/logo.png');
    
    pw.ImageProvider? profileImage;
    if (data['foto_url'] != null && data['foto_url'].toString().isNotEmpty) {
      try {
        profileImage = await networkImage(data['foto_url']);
      } catch (e) {
        profileImage = null;
      }
    }

    String get(String key) => (data[key] ?? "").toString().toUpperCase();
    String nomeCompleto = get('nome_completo');
    String oficial = get('oficial_igreja');
    String cargo = (oficial.isNotEmpty && oficial != "NENHUM") ? oficial : get('cargo_atual');
    String qrData = _gerarTextoQrCode(data, uid);

    final cardColor = PdfColor.fromInt(0xFF616C7C); 
    const double cardWidth = 8.56 * PdfPageFormat.cm;
    const double cardHeight = 5.39 * PdfPageFormat.cm;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text("Recorte nas linhas contínuas e dobre ao meio na linha pontilhada", 
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                pw.SizedBox(height: 10),
                pw.Container(
                  decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black, width: 0.5)),
                  child: pw.Row(
                    mainAxisSize: pw.MainAxisSize.min,
                    children: [
                      pw.Container(
                        width: cardWidth, height: cardHeight, color: cardColor,
                        child: pw.Stack(
                          children: [
                            pw.Positioned(right: -10, bottom: -10, child: pw.Opacity(opacity: 0.1, child: pw.Image(logoImage, width: 100))),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(12),
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Row(
                                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                    children: [
                                      pw.Column(
                                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                                        children: [
                                          pw.Text("IGREJA EVANGÉLICA", style: pw.TextStyle(color: PdfColors.white, fontSize: 6)),
                                          pw.Text("CONGREGACIONAL", style: pw.TextStyle(color: PdfColors.white, fontSize: 10, fontWeight: pw.FontWeight.bold)),
                                          pw.Text("MORENO - PE", style: pw.TextStyle(color: PdfColors.white, fontSize: 6)),
                                        ],
                                      ),
                                      pw.Image(logoImage, width: 25, height: 25),
                                    ],
                                  ),
                                  pw.Spacer(),
                                  pw.Row(
                                    children: [
                                      pw.Container(
                                        width: 45, height: 45,
                                        decoration: pw.BoxDecoration(shape: pw.BoxShape.circle, color: PdfColors.grey300, border: pw.Border.all(color: PdfColors.white, width: 1.5)),
                                        child: profileImage != null 
                                          ? pw.ClipOval(child: pw.Image(profileImage, fit: pw.BoxFit.cover))
                                          : pw.Center(child: pw.Text("FOTO", style: const pw.TextStyle(fontSize: 6))),
                                      ),
                                      pw.SizedBox(width: 10),
                                      pw.Expanded(
                                        child: pw.Column(
                                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                                          children: [
                                            pw.Text(nomeCompleto, style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 8), maxLines: 2),
                                            pw.SizedBox(height: 2),
                                            pw.Container(
                                              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                              decoration: pw.BoxDecoration(color: PdfColors.white, borderRadius: pw.BorderRadius.circular(2)),
                                              child: pw.Text(cargo, style: pw.TextStyle(color: cardColor, fontSize: 6, fontWeight: pw.FontWeight.bold)),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      pw.Container(width: 1, height: cardHeight, color: PdfColors.grey400),
                      pw.Container(
                        width: cardWidth, height: cardHeight, color: PdfColors.white,
                        child: pw.Center(
                          child: pw.Column(
                            mainAxisAlignment: pw.MainAxisAlignment.center,
                            children: [
                              pw.BarcodeWidget(barcode: pw.Barcode.qrCode(), data: qrData, width: 80, height: 80, drawText: false),
                              pw.SizedBox(height: 5),
                              pw.Text("Valide os dados via QR Code", style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey700)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text("Usuário não logado")));

    const Color cardColor = Color.fromARGB(255, 97, 108, 124);

    return Scaffold(
      backgroundColor: Colors.grey[100], 
      appBar: AppBar(
        title: const Text("Minha Carteirinha", style: TextStyle(color: Colors.white)),
        backgroundColor: cardColor, 
        elevation: 0,
        actions: [
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox();
              return IconButton(
                icon: const Icon(Icons.print, color: Colors.white),
                onPressed: () {
                  final data = snapshot.data!.data() as Map<String, dynamic>;
                  _generatePdf(context, data, user.uid);
                },
              );
            }
          ),
          IconButton(icon: const Icon(Icons.logout, color: Colors.white), onPressed: () => _signOut(context))
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text("Erro ao carregar perfil."));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          final data = snapshot.hasData && snapshot.data!.exists ? snapshot.data!.data() as Map<String, dynamic> : <String, dynamic>{};
          String get(String key) => (data[key] ?? "").toString();

          String nomeDisplay = get('nome_completo').isNotEmpty ? get('nome_completo') : (user.email ?? "Membro");
          String fotoUrl = get('foto_url');
          String oficial = get('oficial_igreja');
          String cargoAtual = get('cargo_atual');
          String cargo = (oficial.isNotEmpty && oficial.toUpperCase() != "NENHUM") ? oficial : (cargoAtual.isNotEmpty ? cargoAtual : "Membro");
          String membroDesde = get('membro_desde');
          String qrDataString = _gerarTextoQrCode(data, user.uid);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const SizedBox(height: 10),
                // --- CARTÃO VIRTUAL ---
                Container(
                  width: double.infinity, height: 220, 
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20), color: cardColor, 
                    image: const DecorationImage(image: AssetImage('assets/images/logo.png'), fit: BoxFit.contain, alignment: Alignment.centerRight, opacity: 0.15),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const Text("IGREJA EVANGÉLICA", style: TextStyle(color: Colors.white70, fontSize: 10, letterSpacing: 1.5)),
                              const Text("CONGREGACIONAL", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                              Text("MORENO - PE", style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 10)),
                            ]),
                            Container(width: 40, height: 40, decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle), padding: const EdgeInsets.all(5), child: Image.asset('assets/images/logo.png')),
                        ]),
                        const Spacer(),
                        Row(children: [
                            GestureDetector( // Permite clicar na foto do cartão também
                              onTap: () => _pickAndUploadImage(context, user.uid),
                              child: Container(
                                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)), 
                                child: CircleAvatar(
                                  radius: 35, 
                                  backgroundColor: Colors.grey[300], 
                                  backgroundImage: (fotoUrl.isNotEmpty && fotoUrl != "null") ? NetworkImage(fotoUrl) : null, 
                                  child: (fotoUrl.isEmpty || fotoUrl == "null") ? const Icon(Icons.person, size: 40, color: Colors.grey) : null
                                )
                              ),
                            ),
                            const SizedBox(width: 15),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(nomeDisplay.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 4),
                                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(4)), child: Text(cargo.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                                  if (membroDesde.isNotEmpty) Text("Membro desde: $membroDesde", style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 10)),
                            ])),
                        ]),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                
                // --- QR CODE ---
                Container(
                  width: double.infinity, padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))]),
                  child: Column(children: [
                      const Text("Seu Código de Membro", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
                      const SizedBox(height: 15),
                      QrImageView(
                        data: qrDataString, version: QrVersions.auto, size: 180.0, backgroundColor: Colors.white, 
                        embeddedImage: const AssetImage('assets/images/logo.png'), embeddedImageStyle: const QrEmbeddedImageStyle(size: Size(30, 30))
                      ),
                      const SizedBox(height: 10),
                      Text("ID: ${user.uid.substring(0, 8).toUpperCase()}...", style: const TextStyle(letterSpacing: 2, color: Colors.grey, fontSize: 12)),
                  ]),
                ),
                
                const SizedBox(height: 30),
                _buildSettingsTile(icon: Icons.person_outline, title: "Meus Dados (Completo)", subtitle: "Visualize e altere sua foto", color: cardColor, onTap: () => _showMyDetails(context, data)),
                _buildSettingsTile(icon: Icons.lock_outline, title: "Alterar Senha", subtitle: "Atualize sua segurança", color: Colors.orange, onTap: () => _showChangePasswordDialog(context)),
                _buildSettingsTile(icon: Icons.logout, title: "Sair", subtitle: "Deslogar do aplicativo", color: Colors.red, onTap: () => _signOut(context)),
                const SizedBox(height: 40),
                Text("Versão 1.0.0", style: TextStyle(color: Colors.grey[400], fontSize: 12)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSettingsTile({required IconData icon, required String title, required String subtitle, required Color color, required VoidCallback onTap}) {
    return Card(margin: const EdgeInsets.symmetric(vertical: 6), elevation: 0, color: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey[200]!)), child: ListTile(leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 22)), title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)), subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])), trailing: const Icon(Icons.chevron_right, color: Colors.grey), onTap: onTap));
  }

  void _showMyDetails(BuildContext context, Map<String, dynamic> data) {
    String get(String key) => (data[key] ?? "").toString();
    String nomeDisplay = get('nome_completo').isNotEmpty ? get('nome_completo') : "Membro";
    String? fotoUrl = data['foto_url'];
    const Color headerColor = Color.fromARGB(255, 97, 108, 124);

    Widget buildRow(IconData icon, String label, String value) {
      if (value.trim().isEmpty || value == "null") return const SizedBox.shrink();
      return Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, size: 18, color: Colors.grey[600]), const SizedBox(width: 10), Expanded(child: RichText(text: TextSpan(style: const TextStyle(color: Colors.black87, fontSize: 14), children: [TextSpan(text: "$label: ", style: TextStyle(color: Colors.grey[700], fontSize: 12)), TextSpan(text: value, style: const TextStyle(fontWeight: FontWeight.w500))])))]));
    }
    Widget section(String title) => Padding(padding: const EdgeInsets.only(top: 20, bottom: 5), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Color.fromARGB(255, 97, 108, 124), fontWeight: FontWeight.bold, fontSize: 16)), const Divider(height: 5, color: Colors.grey)]));

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.90,
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          child: Column(
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context); 
                      _pickAndUploadImage(context, FirebaseAuth.instance.currentUser!.uid); 
                    },
                    child: CircleAvatar(
                      radius: 50, 
                      backgroundColor: headerColor.withOpacity(0.2), 
                      backgroundImage: (fotoUrl != null && fotoUrl.isNotEmpty) ? NetworkImage(fotoUrl) : null, 
                      child: (fotoUrl == null || fotoUrl.isEmpty) ? const Icon(Icons.person, size: 60, color: headerColor) : null
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: headerColor, shape: BoxShape.circle),
                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                  )
                ],
              ),
              const SizedBox(height: 10),
              const Text("Toque na foto para alterar", style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 20), const Divider(),
              Expanded(
                child: ListView(
                  children: [
                    section("Dados Pessoais"),
                    buildRow(Icons.badge, "CPF", get('cpf')),
                    buildRow(Icons.badge, "RG", get('rg')),
                    buildRow(Icons.cake, "Nascimento", get('nascimento')),
                    buildRow(Icons.bloodtype, "Sangue", get('grupo_sanguineo')),
                    buildRow(Icons.face, "Sexo", get('sexo')),
                    buildRow(Icons.person, "Pai", get('pai')),
                    buildRow(Icons.person, "Mãe", get('mae')),
                    buildRow(Icons.school, "Escolaridade", get('escolaridade')),
                    buildRow(Icons.work, "Profissão", get('profissao')),
                    section("Endereço & Contato"),
                    buildRow(Icons.location_on, "Endereço", "${get('endereco')}, ${get('numero')}"),
                    buildRow(Icons.map, "Bairro", get('bairro')),
                    buildRow(Icons.location_city, "Cidade/UF", "${get('cidade')} - ${get('uf')}"),
                    buildRow(Icons.markunread_mailbox, "CEP", get('cep')),
                    buildRow(Icons.phone_android, "WhatsApp", get('whatsapp')),
                    buildRow(Icons.email, "E-mail", get('email')),
                    section("Vida Eclesiástica"),
                    buildRow(Icons.star, "Cargo", get('cargo_atual')),
                    buildRow(Icons.shield, "Oficial", get('oficial_igreja')),
                    buildRow(Icons.groups, "Departamento", get('departamento')),
                    buildRow(Icons.church, "Membro Desde", get('membro_desde')),
                    buildRow(Icons.water_drop, "Batismo", get('batismo_aguas')),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Alterar Senha"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Por segurança, confirme sua senha atual.", style: TextStyle(fontSize: 14, color: Colors.grey)),
                const SizedBox(height: 20),
                TextField(controller: currentPasswordController, obscureText: true, decoration: const InputDecoration(labelText: "Senha Atual", border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: newPasswordController, obscureText: true, decoration: const InputDecoration(labelText: "Nova Senha", border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: confirmPasswordController, obscureText: true, decoration: const InputDecoration(labelText: "Confirmar Nova Senha", border: OutlineInputBorder())),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
            ElevatedButton(
              onPressed: () async {
                if (newPasswordController.text != confirmPasswordController.text) return;
                try {
                  final user = FirebaseAuth.instance.currentUser;
                  AuthCredential cred = EmailAuthProvider.credential(email: user!.email!, password: currentPasswordController.text);
                  await user.reauthenticateWithCredential(cred);
                  await user.updatePassword(newPasswordController.text);
                  Navigator.pop(context);
                } catch (e) {
                  debugPrint(e.toString());
                }
              }, 
              child: const Text("Salvar")
            ),
          ],
        );
      },
    );
  }
}