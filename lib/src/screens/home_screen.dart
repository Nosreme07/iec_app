import 'package:flutter/material.dart';
import '../utils/admin_config.dart'; // Importante para verificar se é Admin
import 'profile_screen.dart';
import 'bible_screen.dart';
import 'hymnal_screen.dart';
import 'members_screen.dart'; // Garante que a tela de membros está importada

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  // Lista das telas principais (Bottom Navigation)
  final List<Widget> _screens = [
    const HomeContent(),   // Índice 0: Grade de ícones
    const ProfileScreen(), // Índice 1: Perfil
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("IEC App", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue[900],
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(icon: const Icon(Icons.notifications), onPressed: () {}),
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

// --- CONTEÚDO DA TELA INICIAL (SCROLLABLE) ---
class HomeContent extends StatelessWidget {
  const HomeContent({super.key});

  @override
  Widget build(BuildContext context) {
    // Verifica na configuração se o usuário logado é Admin
    final bool isAdmin = AdminConfig.isUserAdmin();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Bem-vindo à IEC-Moreno!",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          // --- GRADE DE ÍCONES ---
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            // Layout de 3 colunas
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.85,

            children: [
              // 1. BÍBLIA
              _buildMenuCard(
                context,
                icon: Icons.menu_book,
                label: "Bíblia",
                color: Colors.brown,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const BibleScreen()),
                  );
                },
              ),

              // 2. SALMOS E HINOS
              _buildMenuCard(
                context,
                icon: Icons.library_music,
                label: "Salmos & Hinos",
                color: Colors.orange,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const HymnalScreen()),
                  );
                },
              ),

              // 3. AGENDA SEMANAL
              _buildMenuCard(
                context,
                icon: Icons.calendar_view_week,
                label: "Agenda Semanal",
                color: Colors.blue,
                onTap: () {},
              ),

              // 4. AGENDA ANUAL
              _buildMenuCard(
                context,
                icon: Icons.calendar_month,
                label: "Agenda Anual",
                color: Colors.purple,
                onTap: () {},
              ),

              // 5. ESCALA
              _buildMenuCard(
                context,
                icon: Icons.view_timeline,
                label: "Escala",
                color: Colors.teal,
                onTap: () {},
              ),

              // 6. TOMBAMENTO
              _buildMenuCard(
                context,
                icon: Icons.inventory_2,
                label: "Tombamento",
                color: Colors.blueGrey,
                onTap: () {},
              ),

              // 7. MEMBROS (Rol de Membros)
              _buildMenuCard(
                context,
                icon: Icons.groups,
                label: "Membros",
                color: Colors.indigo,
                onTap: () {
                  // Navega para a tela de membros que corrigimos
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const MembersScreen()),
                  );
                },
              ),

              // 8. FINANÇAS (SÓ APARECE SE FOR ADMIN)
              if (isAdmin)
                _buildMenuCard(
                  context,
                  icon: Icons.attach_money,
                  label: "Finanças",
                  color: Colors.green[700]!,
                  onTap: () {},
                ),
            ],
          ),

          const SizedBox(height: 30),

          // --- SEÇÃO DE ANIVERSARIANTES ---
          _buildBirthdayCard(),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // --- WIDGET DO BOTÃO DO MENU ---
  Widget _buildMenuCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
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
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 30, color: color),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGET DO CARD DE ANIVERSARIANTES ---
  Widget _buildBirthdayCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue[100]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cake, color: Colors.pink[400], size: 28),
              const SizedBox(width: 10),
              const Text(
                "Aniversariantes",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const Divider(height: 20, thickness: 1),
          _buildBirthdayItem("15/01", "Maria Silva"),
          _buildBirthdayItem("22/01", "Lucas Pereira"),
          const SizedBox(height: 10),
          Center(
            child: TextButton(onPressed: () {}, child: const Text("Ver todos")),
          ),
        ],
      ),
    );
  }

  Widget _buildBirthdayItem(String date, String name) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Text(
              date,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue[800],
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            name,
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
        ],
      ),
    );
  }
}