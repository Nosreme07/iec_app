import 'dart:io'; 
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart'; 
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/services.dart';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'edit_profile.dart';

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

  // --- FUNÇÃO: CORTAR IMAGEM ---
  Future<File?> _cropImage(File imageFile) async {
    CroppedFile? croppedFile = await ImageCropper().cropImage(
      sourcePath: imageFile.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Ajustar Foto',
          toolbarColor: Colors.blue[900], 
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true, 
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

  // --- FUNÇÃO ALTERAR FOTO ---
  Future<void> _pickAndUploadImage(BuildContext context, String uid) async {
    final ImagePicker picker = ImagePicker();
    
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70, 
      );

      if (image == null) return;

      File? fileToUpload;
      Uint8List? webBytesToUpload;

      if (!kIsWeb) {
        File originalFile = File(image.path);
        fileToUpload = await _cropImage(originalFile);
        if (fileToUpload == null) return; 
      } else {
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
        await ref.putFile(fileToUpload!);
      }

      String downloadUrl = await ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'foto_url': downloadUrl,
      });

      if (context.mounted) {
        Navigator.pop(context); 
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
                            GestureDetector( 
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
                // --- BOTÕES DE AÇÃO ---
                _buildSettingsTile(icon: Icons.person_outline, title: "Visualizar Meus Dados", subtitle: "Confira sua ficha cadastral", color: cardColor, onTap: () => _showMyDetails(context, data)),
                
                // AQUI NÓS CHAMAMOS A NOVA TELA DE EDIÇÃO (IGUAL AO CADASTRO)
_buildSettingsTile(
  icon: Icons.edit, 
  title: "Editar Meus Dados", 
  subtitle: "Atualize suas informações pessoais", 
  color: Colors.blue[600]!, 
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfileScreen(userData: data),
      ),
    );
  }
),
                
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
                  if(context.mounted) Navigator.pop(context);
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

// ============================================================================
// NOVA TELA DE EDIÇÃO (OCUPA A TELA INTEIRA IGUAL AO ADMIN_REGISTER_SCREEN)
// ============================================================================
class EditMyProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const EditMyProfileScreen({super.key, required this.userData});

  @override
  State<EditMyProfileScreen> createState() => _EditMyProfileScreenState();
}

class _EditMyProfileScreenState extends State<EditMyProfileScreen> {
  bool _isSaving = false;

  // --- CONTROLADORES BLOQUEADOS ---
  late TextEditingController _cpfCtrl;
  late TextEditingController _situacaoCtrl;
  late TextEditingController _roleCtrl;

  // --- CONTROLADORES EDITÁVEIS ---
  late TextEditingController _nomeCtrl;
  late TextEditingController _rgCtrl;
  late TextEditingController _nascCtrl;
  late TextEditingController _sangueCtrl;
  late TextEditingController _sexoCtrl;
  late TextEditingController _naturalidadeCtrl;
  late TextEditingController _nacionalidadeCtrl;
  late TextEditingController _estadoCivilCtrl;
  late TextEditingController _conjugeCtrl;
  late TextEditingController _filhosCtrl;
  late TextEditingController _paiCtrl;
  late TextEditingController _maeCtrl;
  late TextEditingController _escolaridadeCtrl;
  late TextEditingController _profissaoCtrl;
  late TextEditingController _whatsCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _endCtrl;
  late TextEditingController _numCtrl;
  late TextEditingController _bairroCtrl;
  late TextEditingController _cidadeCtrl;
  late TextEditingController _ufCtrl;
  late TextEditingController _cepCtrl;
  late TextEditingController _cargoCtrl;
  late TextEditingController _oficialCtrl;
  late TextEditingController _deptoCtrl;
  late TextEditingController _membroDesdeCtrl;
  late TextEditingController _batismoCtrl;
  late TextEditingController _admissaoCtrl;
  late TextEditingController _igrejaAntCtrl;
  late TextEditingController _cargoAntCtrl;
  late TextEditingController _conversaoCtrl;
  late TextEditingController _consagracaoCtrl;
  late TextEditingController _obsCtrl;

  @override
  void initState() {
    super.initState();
    final data = widget.userData;

    // Traduz o 'role'
    String nivelAcesso = 'Membro';
    if (data['role'] == 'admin') nivelAcesso = 'Administrador';
    if (data['role'] == 'financeiro') nivelAcesso = 'Financeiro';

    _cpfCtrl = TextEditingController(text: data['cpf']);
    _situacaoCtrl = TextEditingController(text: data['situacao'] ?? 'Ativo');
    _roleCtrl = TextEditingController(text: nivelAcesso);

    _nomeCtrl = TextEditingController(text: data['nome_completo']);
    _rgCtrl = TextEditingController(text: data['rg']);
    _nascCtrl = TextEditingController(text: data['nascimento']);
    _sangueCtrl = TextEditingController(text: data['grupo_sanguineo']);
    _sexoCtrl = TextEditingController(text: data['sexo']);
    _naturalidadeCtrl = TextEditingController(text: data['naturalidade']);
    _nacionalidadeCtrl = TextEditingController(text: data['nacionalidade']);
    _estadoCivilCtrl = TextEditingController(text: data['estado_civil']);
    _conjugeCtrl = TextEditingController(text: data['conjuge']);
    _filhosCtrl = TextEditingController(text: data['filhos']);
    _paiCtrl = TextEditingController(text: data['pai']);
    _maeCtrl = TextEditingController(text: data['mae']);
    _escolaridadeCtrl = TextEditingController(text: data['escolaridade']);
    _profissaoCtrl = TextEditingController(text: data['profissao']);
    _whatsCtrl = TextEditingController(text: data['whatsapp']);
    _emailCtrl = TextEditingController(text: data['email']);
    _endCtrl = TextEditingController(text: data['endereco']);
    _numCtrl = TextEditingController(text: data['numero']);
    _bairroCtrl = TextEditingController(text: data['bairro']);
    _cidadeCtrl = TextEditingController(text: data['cidade']);
    _ufCtrl = TextEditingController(text: data['uf']);
    _cepCtrl = TextEditingController(text: data['cep']);
    _cargoCtrl = TextEditingController(text: data['cargo_atual']);
    _oficialCtrl = TextEditingController(text: data['oficial_igreja']);
    _deptoCtrl = TextEditingController(text: data['departamento']);
    _membroDesdeCtrl = TextEditingController(text: data['membro_desde']);
    _batismoCtrl = TextEditingController(text: data['batismo_aguas']);
    _admissaoCtrl = TextEditingController(text: data['tipo_admissao']);
    _igrejaAntCtrl = TextEditingController(text: data['igreja_anterior']);
    _cargoAntCtrl = TextEditingController(text: data['cargo_anterior']);
    _conversaoCtrl = TextEditingController(text: data['data_conversao']);
    _consagracaoCtrl = TextEditingController(text: data['data_consagracao']);
    _obsCtrl = TextEditingController(text: data['observacoes']);
  }

  @override
  void dispose() {
    _cpfCtrl.dispose(); _situacaoCtrl.dispose(); _roleCtrl.dispose(); _nomeCtrl.dispose();
    _rgCtrl.dispose(); _nascCtrl.dispose(); _sangueCtrl.dispose(); _sexoCtrl.dispose();
    _naturalidadeCtrl.dispose(); _nacionalidadeCtrl.dispose(); _estadoCivilCtrl.dispose();
    _conjugeCtrl.dispose(); _filhosCtrl.dispose(); _paiCtrl.dispose(); _maeCtrl.dispose();
    _escolaridadeCtrl.dispose(); _profissaoCtrl.dispose(); _whatsCtrl.dispose(); _emailCtrl.dispose();
    _endCtrl.dispose(); _numCtrl.dispose(); _bairroCtrl.dispose(); _cidadeCtrl.dispose();
    _ufCtrl.dispose(); _cepCtrl.dispose(); _cargoCtrl.dispose(); _oficialCtrl.dispose();
    _deptoCtrl.dispose(); _membroDesdeCtrl.dispose(); _batismoCtrl.dispose(); _admissaoCtrl.dispose();
    _igrejaAntCtrl.dispose(); _cargoAntCtrl.dispose(); _conversaoCtrl.dispose(); _consagracaoCtrl.dispose();
    _obsCtrl.dispose();
    super.dispose();
  }

  Future<void> _salvarDados() async {
    setState(() => _isSaving = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      
      // Salva apenas os campos permitidos
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'nome_completo': _nomeCtrl.text.trim(),
        'rg': _rgCtrl.text.trim(),
        'nascimento': _nascCtrl.text.trim(),
        'grupo_sanguineo': _sangueCtrl.text.trim(),
        'sexo': _sexoCtrl.text.trim(),
        'naturalidade': _naturalidadeCtrl.text.trim(),
        'nacionalidade': _nacionalidadeCtrl.text.trim(),
        'estado_civil': _estadoCivilCtrl.text.trim(),
        'conjuge': _conjugeCtrl.text.trim(),
        'filhos': _filhosCtrl.text.trim(),
        'pai': _paiCtrl.text.trim(),
        'mae': _maeCtrl.text.trim(),
        'escolaridade': _escolaridadeCtrl.text.trim(),
        'profissao': _profissaoCtrl.text.trim(),
        'whatsapp': _whatsCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'cep': _cepCtrl.text.trim(),
        'endereco': _endCtrl.text.trim(),
        'numero': _numCtrl.text.trim(),
        'bairro': _bairroCtrl.text.trim(),
        'cidade': _cidadeCtrl.text.trim(),
        'uf': _ufCtrl.text.trim(),
        'cargo_atual': _cargoCtrl.text.trim(),
        'oficial_igreja': _oficialCtrl.text.trim(),
        'departamento': _deptoCtrl.text.trim(),
        'membro_desde': _membroDesdeCtrl.text.trim(),
        'batismo_aguas': _batismoCtrl.text.trim(),
        'tipo_admissao': _admissaoCtrl.text.trim(),
        'igreja_anterior': _igrejaAntCtrl.text.trim(),
        'cargo_anterior': _cargoAntCtrl.text.trim(),
        'data_conversao': _conversaoCtrl.text.trim(),
        'data_consagracao': _consagracaoCtrl.text.trim(),
        'observacoes': _obsCtrl.text.trim(),
      });
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ficha atualizada com sucesso!"), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erro ao atualizar."), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildBlockedField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        readOnly: true,
        style: const TextStyle(color: Colors.black54),
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.grey[200],
          prefixIcon: const Icon(Icons.lock, color: Colors.grey, size: 18),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, {int flex = 1, int maxLines = 1}) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            labelText: label,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 15, bottom: 10),
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.grey[300])),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(title, style: TextStyle(color: Colors.indigo[900], fontWeight: FontWeight.bold)),
          ),
          Expanded(child: Divider(color: Colors.grey[300])),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Editar Meus Dados", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.indigo,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text("Atualize suas informações pessoais com atenção.", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 10),
            
            _buildSectionHeader("Dados Restritos"),
            _buildBlockedField("Nível de Acesso no App", _roleCtrl),
            Row(
              children: [
                Expanded(child: _buildBlockedField("CPF (Login)", _cpfCtrl)),
                const SizedBox(width: 10),
                Expanded(child: _buildBlockedField("Situação Atual", _situacaoCtrl)),
              ],
            ),

            _buildSectionHeader("Dados Pessoais"),
            Row(children: [_buildField("Nome Completo", _nomeCtrl)]),
            Row(children: [_buildField("RG", _rgCtrl), const SizedBox(width: 10), _buildField("Nascimento", _nascCtrl)]),
            Row(children: [_buildField("Sexo", _sexoCtrl), const SizedBox(width: 10), _buildField("Tipo Sanguíneo", _sangueCtrl)]),
            Row(children: [_buildField("Naturalidade", _naturalidadeCtrl), const SizedBox(width: 10), _buildField("Nacionalidade", _nacionalidadeCtrl)]),
            Row(children: [_buildField("Estado Civil", _estadoCivilCtrl), const SizedBox(width: 10), _buildField("Filhos", _filhosCtrl)]),
            Row(children: [_buildField("Nome do Cônjuge", _conjugeCtrl)]),

            _buildSectionHeader("Filiação"),
            Row(children: [_buildField("Nome do Pai", _paiCtrl)]),
            Row(children: [_buildField("Nome da Mãe", _maeCtrl)]),

            _buildSectionHeader("Profissional & Acadêmico"),
            Row(children: [_buildField("Escolaridade", _escolaridadeCtrl)]),
            Row(children: [_buildField("Profissão", _profissaoCtrl)]),

            _buildSectionHeader("Contato e Endereço"),
            Row(children: [_buildField("WhatsApp", _whatsCtrl), const SizedBox(width: 10), _buildField("E-mail", _emailCtrl)]),
            Row(children: [_buildField("CEP", _cepCtrl)]),
            Row(children: [_buildField("Endereço", _endCtrl, flex: 3), const SizedBox(width: 10), _buildField("Nº", _numCtrl, flex: 1)]),
            Row(children: [_buildField("Bairro", _bairroCtrl, flex: 2), const SizedBox(width: 10), _buildField("Cidade", _cidadeCtrl, flex: 2), const SizedBox(width: 10), _buildField("UF", _ufCtrl, flex: 1)]),

            _buildSectionHeader("Vida Eclesiástica"),
            Row(children: [_buildField("Cargo Atual", _cargoCtrl), const SizedBox(width: 10), _buildField("Oficial da Igreja", _oficialCtrl)]),
            Row(children: [_buildField("Departamento", _deptoCtrl)]),
            Row(children: [_buildField("Membro Desde", _membroDesdeCtrl), const SizedBox(width: 10), _buildField("Batismo (Águas)", _batismoCtrl)]),
            Row(children: [_buildField("Data Conversão", _conversaoCtrl), const SizedBox(width: 10), _buildField("Data Consagração", _consagracaoCtrl)]),
            Row(children: [_buildField("Tipo de Admissão", _admissaoCtrl)]),
            Row(children: [_buildField("Igreja Anterior", _igrejaAntCtrl)]),
            Row(children: [_buildField("Cargo na Igreja Anterior", _cargoAntCtrl)]),

            _buildSectionHeader("Observações"),
            Row(children: [_buildField("Notas Adicionais", _obsCtrl, maxLines: 3)]),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo, 
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                ),
                onPressed: _isSaving ? null : _salvarDados,
                child: _isSaving 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text("SALVAR ALTERAÇÕES", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}