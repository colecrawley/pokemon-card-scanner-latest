import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/theme_provider.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 2,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.blue.shade100,
                Colors.green.shade100,
              ],
            ),
          ),
        ),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          _buildSection(
            title: 'Appearance',
            children: [
              _buildSettingTile(
                icon: Icons.dark_mode,
                title: 'Dark Mode',
                subtitle: 'Toggle dark theme for the app',
                trailing: Switch(
                  value: themeProvider.isDarkMode,
                  onChanged: (_) {
                    themeProvider.toggleTheme();
                  },
                  activeColor: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSection(
            title: 'Account',
            children: [
              _buildSettingTile(
                icon: Icons.person,
                title: 'Account Information',
                subtitle: 'Manage your account details',
                onTap: () {
                  // TODO: Navigate to account info page
                },
              ),
              _buildSettingTile(
                icon: Icons.notifications,
                title: 'Notifications',
                subtitle: 'Manage your notification preferences',
                onTap: () {
                  // TODO: Navigate to notifications page
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSection(
            title: 'Application',
            children: [
              _buildSettingTile(
                icon: Icons.info,
                title: 'About',
                subtitle: 'Learn more about the app',
                onTap: () {
                  // TODO: Navigate to about page
                },
              ),
              _buildSettingTile(
                icon: Icons.help,
                title: 'Help & Support',
                subtitle: 'Get assistance with the app',
                onTap: () {
                  // TODO: Navigate to help page
                },
              ),
              _buildSettingTile(
                icon: Icons.logout,
                title: 'Logout',
                subtitle: 'Sign out of your account',
                onTap: () {
                  // TODO: Implement logout functionality
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Logout'),
                      content: const Text('Are you sure you want to logout?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () {
                            // TODO: Implement logout logic
                            Navigator.pop(context);
                          },
                          child: const Text('Logout'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'Version 1.0.0',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSection({required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              // Using a gradient text color that matches the theme but darker
              foreground: Paint()
                ..shader = LinearGradient(
                  colors: [
                    Colors.blue.shade700,
                    Colors.green.shade700,
                  ],
                ).createShader(const Rect.fromLTWH(0.0, 0.0, 200.0, 70.0)),
            ),
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        // Using a darker blue-green color for icons to match the theme
        color: Colors.teal.shade600,
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: trailing,
      onTap: trailing == null ? onTap : null,
    );
  }
}