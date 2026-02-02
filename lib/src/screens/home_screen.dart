import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart'; 

// IMPORTS DAS TELAS
import 'profile_screen.dart';
import 'bible_screen.dart';
import 'hymnal_screen.dart';
import 'members_screen.dart';
import 'unified_agenda_screen.dart'; 
import 'scale_screen.dart';
import 'patrimonio_screen.dart'; 
import 'finance_screen.dart'; 
import 'devocional_screen.dart';
import 'notices_history_screen.dart'; 
import 'liturgia_screen.dart';

// IMPORTS DOS WIDGETS
import '../widgets/home_notices_widget.dart'; 
import '../widgets/monthly_birthdays_widget.dart';
import '../widgets/mural_avisos_widget.dart'; 

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const HomeContent(),   
    const ProfileScreen(), 
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text("IEC-MORENO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue[900],
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots(),
            builder: (context, snapshot) {
              String role = 'membro';
              if (snapshot.hasData && snapshot.data!.exists) {
                final data = snapshot.data!.data() as Map<String, dynamic>;
                role = data['role'] ?? 'membro';
              }

              return IconButton(
                icon: const Icon(Icons.notifications),
                tooltip: "Mural de Avisos",
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NoticesHistoryScreen(userRole: role),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Início"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Perfil"),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue[900],
        onTap: _onItemTapped,
      ),
    );
  }
}

class HomeContent extends StatelessWidget {
  const HomeContent({super.key});

  Future<void> _launchSocialMedia(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Não foi possível abrir $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return const Center(child: CircularProgressIndicator());

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        
        // A variável role continua útil para outras lógicas se precisar
        String role = 'membro';
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          role = data['role'] ?? 'membro';
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  "Bem-vindo à IEC-Moreno!",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 20),

              // --- GRADE DE ÍCONES ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.85,
                  children: [
                    _buildMenuCard(context, icon: Icons.menu_book, label: "Bíblia", color: Colors.brown, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const BibleScreen()))),
                    _buildMenuCard(context, icon: Icons.library_music, label: "Salmos & Hinos", color: Colors.orange, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const HymnalScreen()))),
                    _buildMenuCard(context, icon: Icons.local_florist, label: "Devocional", color: Colors.pink, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const DevocionalScreen()))),
                    _buildMenuCard(context, icon: Icons.calendar_month, label: "Agenda", color: Colors.blue, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const UnifiedAgendaScreen()))),
                    _buildMenuCard(context, icon: Icons.view_timeline, label: "Escala", color: Colors.teal, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ScaleScreen()))),
                    _buildMenuCard(context, icon: Icons.inventory_2, label: "Patrimônio", color: Colors.blueGrey, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PatrimonioScreen()))),
                    _buildMenuCard(context, icon: Icons.groups, label: "Membros", color: Colors.indigo, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MembersScreen()))),
                    _buildMenuCard(context, icon: Icons.attach_money, label: "Finanças", color: Colors.green[700]!, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const FinanceScreen()))),
                    _buildMenuCard(context, icon: Icons.format_list_bulleted, label: "Liturgia", color: Colors.deepOrange, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const LiturgiaScreen()))),
                  ],
                ),
              ),

              const SizedBox(height: 30),
              
              const MuralAvisosWidget(), 
              const WeeklyNoticesWidget(),
              const SizedBox(height: 20),
              const MonthlyBirthdaysWidget(),
              const SizedBox(height: 30),

              _buildSocialMediaSection(),
              const SizedBox(height: 30),
            ],
          ),
        );
      }
    );
  }

  // --- WIDGET DAS REDES SOCIAIS ---
  Widget _buildSocialMediaSection() {
    return Column(
      children: [
        Divider(color: Colors.grey[300]),
        const SizedBox(height: 10),
        Text("Siga nossas redes sociais", style: TextStyle(color: Colors.grey[600], fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 15),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _socialButton(icon: Icons.camera_alt, color: Colors.pink, label: "Instagram", onTap: () => _launchSocialMedia("https://www.instagram.com/iec.moreno")),
            const SizedBox(width: 20),
            _socialButton(icon: Icons.play_circle_fill, color: Colors.red, label: "YouTube", onTap: () => _launchSocialMedia("https://www.youtube.com/@IecMoreno")),
            const SizedBox(width: 20),
            _socialButton(icon: Icons.facebook, color: Colors.blue[800]!, label: "Facebook", onTap: () => _launchSocialMedia("https://www.facebook.com/iecmorenope")),
          ],
        ),
      ],
    );
  }

  Widget _socialButton({required IconData icon, required Color color, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(50),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.3), width: 1),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold))
        ],
      ),
    );
  }

  Widget _buildMenuCard(BuildContext context, {required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return Material(
      color: Colors.white,
      elevation: 2,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, size: 30, color: color),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}