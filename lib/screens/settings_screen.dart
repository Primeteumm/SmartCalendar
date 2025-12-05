import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isThemeExpanded = false;
  bool _isLocationExpanded = false;
  bool _isNotificationsExpanded = false;
  bool _isAboutExpanded = false;

  @override
  void initState() {
    super.initState();
    // Check permission status when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<SettingsProvider>(context, listen: false).checkPermissionStatus();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
              Theme.of(context).colorScheme.surface,
              Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.2),
            ],
          ),
        ),
        child: SafeArea(
          child: Consumer<ThemeProvider>(
            builder: (context, themeProvider, child) {
              return Column(
                children: [
                  // Modern AppBar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Row(
                      children: [
                        // Geri Butonu
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceVariant,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.arrow_back_rounded,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              size: 24,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.settings_rounded,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Ayarlar',
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Tema ve görünüm ayarları',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Settings Content
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(20.0),
                      children: [
                        const SizedBox(height: 8),
                        // Modern Theme Section
                        _buildSectionCard(
                          context,
                          icon: Icons.palette_rounded,
                          title: 'Tema Ayarları',
                          subtitle: 'Görünüm ve renk tercihlerinizi değiştirin',
                          isExpanded: _isThemeExpanded,
                          onExpansionChanged: (expanded) {
                            setState(() {
                              _isThemeExpanded = expanded;
                            });
                          },
                          child: _buildThemeSection(context, themeProvider),
                        ),
                        const SizedBox(height: 16),
                        // Location Section
                        _buildSectionCard(
                          context,
                          icon: Icons.location_on_rounded,
                          title: 'Konum',
                          subtitle: 'Konum izinleri ve doğruluk',
                          isExpanded: _isLocationExpanded,
                          onExpansionChanged: (expanded) {
                            setState(() {
                              _isLocationExpanded = expanded;
                            });
                          },
                          child: _buildLocationSection(context),
                        ),
                        const SizedBox(height: 16),
                        // Notifications Section
                        _buildSectionCard(
                          context,
                          icon: Icons.notifications_rounded,
                          title: 'Bildirimler',
                          subtitle: 'Hatırlatma bildirimlerini yönetin',
                          isExpanded: _isNotificationsExpanded,
                          onExpansionChanged: (expanded) {
                            setState(() {
                              _isNotificationsExpanded = expanded;
                            });
                          },
                          child: _buildNotificationsSection(context),
                        ),
                        const SizedBox(height: 16),
                        // About Section
                        _buildSectionCard(
                          context,
                          icon: Icons.info_rounded,
                          title: 'Hakkında',
                          subtitle: 'Uygulama sürümü ve bilgileri',
                          isExpanded: _isAboutExpanded,
                          onExpansionChanged: (expanded) {
                            setState(() {
                              _isAboutExpanded = expanded;
                            });
                          },
                          child: _buildAboutSection(context),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isExpanded,
    required ValueChanged<bool> onExpansionChanged,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Theme(
          data: Theme.of(context).copyWith(
            dividerColor: Colors.transparent,
          ),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 8,
            ),
            childrenPadding: const EdgeInsets.only(
              bottom: 24,
              left: 24,
              right: 24,
            ),
            backgroundColor: Theme.of(context).colorScheme.surface,
            collapsedBackgroundColor: Theme.of(context).colorScheme.surface,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(24),
                bottom: Radius.circular(24),
              ),
            ),
            collapsedShape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(24)),
            ),
            leading: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.primary.withOpacity(0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 24,
              ),
            ),
            title: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            subtitle: Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            initiallyExpanded: isExpanded,
            onExpansionChanged: onExpansionChanged,
            children: [child],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeSection(BuildContext context, ThemeProvider themeProvider) {
    return Column(
      children: [
                        const Divider(height: 32),
                        // Dark Mode Section
                        _buildModernToggle(
                          context,
                          icon: Icons.dark_mode_rounded,
                          title: 'Karanlık Mod',
                          subtitle: 'Karanlık temayı etkinleştir',
                          value: themeProvider.themeMode == ThemeMode.dark,
                          onChanged: (value) {
                            themeProvider.setThemeMode(
                              value ? ThemeMode.dark : ThemeMode.light,
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                        // Color Theme Section
                        Text(
                          'Renk Teması',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildModernColorOption(
                              context,
                              AppColor.blue,
                              Colors.blue,
                              'Mavi',
                              themeProvider.appColor == AppColor.blue,
                              () => themeProvider.setAppColor(AppColor.blue),
                            ),
                            _buildModernColorOption(
                              context,
                              AppColor.teal,
                              Colors.teal,
                              'Turkuaz',
                              themeProvider.appColor == AppColor.teal,
                              () => themeProvider.setAppColor(AppColor.teal),
                            ),
                            _buildModernColorOption(
                              context,
                              AppColor.purple,
                              Colors.purple,
                              'Mor',
                              themeProvider.appColor == AppColor.purple,
                              () => themeProvider.setAppColor(AppColor.purple),
                            ),
                          ],
                        ),
                      ],
                    );
                  }

  Widget _buildLocationSection(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, child) {
        return Column(
          children: [
            const Divider(height: 32),
            _buildModernToggle(
              context,
              icon: Icons.location_on_rounded,
              title: 'Konum Servisleri',
              subtitle: 'Etkinlikleriniz için konum bilgisi kullan',
              value: settingsProvider.locationEnabled,
              onChanged: (value) async {
                final success = await settingsProvider.toggleLocation();
                if (!success && value) {
                  // Show error message if permission was denied
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Konum izni verilmedi. Lütfen ayarlardan izin verin.'),
                        action: SnackBarAction(
                          label: 'Tamam',
                          onPressed: () {},
                        ),
                      ),
                    );
                  }
                }
              },
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Konum servisleri, etkinliklerinize konum eklemenize ve haritada görüntülemenize olanak sağlar.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNotificationsSection(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, child) {
        return Column(
          children: [
            const Divider(height: 32),
            _buildModernToggle(
              context,
              icon: Icons.notifications_rounded,
              title: 'Bildirimler',
              subtitle: 'Etkinlik hatırlatmaları için bildirim al',
              value: settingsProvider.notificationsEnabled,
              onChanged: (value) async {
                final success = await settingsProvider.toggleNotifications();
                if (!success && value) {
                  // Show error message if permission was denied
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Bildirim izni verilmedi. Lütfen ayarlardan izin verin.'),
                        action: SnackBarAction(
                          label: 'Tamam',
                          onPressed: () {},
                        ),
                      ),
                    );
                  }
                }
              },
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Bildirimler açıkken, yaklaşan etkinlikleriniz için hatırlatma bildirimleri alırsınız.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAboutSection(BuildContext context) {
    return Column(
      children: [
        const Divider(height: 32),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'SmartCalendar',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Versiyon: 1.0.0',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Akıllı takvim uygulamanız. Etkinliklerinizi yönetin, notlar alın ve AI asistanı ile planlarınızı organize edin.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModernToggle(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          Transform.scale(
            scale: 1.1,
            child: Switch(
              value: value,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernColorOption(
    BuildContext context,
    AppColor color,
    Color colorValue,
    String label,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        child: Column(
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    colorValue,
                    colorValue.withOpacity(0.7),
                  ],
                ),
                shape: BoxShape.circle,
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: colorValue.withOpacity(0.5),
                          blurRadius: 20,
                          spreadRadius: 2,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                border: Border.all(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                  width: 3,
                ),
              ),
              child: isSelected
                  ? Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.2),
                      ),
                      child: Icon(
                        Icons.check_circle_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected
                          ? Theme.of(context).colorScheme.onPrimaryContainer
                          : Theme.of(context).colorScheme.onSurface,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

