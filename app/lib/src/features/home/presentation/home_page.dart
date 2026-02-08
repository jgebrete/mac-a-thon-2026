import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/src/features/auth/providers/auth_providers.dart';
import 'package:app/src/features/camera/presentation/camera_page.dart';
import 'package:app/src/features/pantry/data/pantry_repository.dart';
import 'package:app/src/features/pantry/domain/pantry_item.dart';
import 'package:app/src/features/pantry/presentation/manual_add_sheet.dart';
import 'package:app/src/features/pantry/presentation/pantry_list_page.dart';
import 'package:app/src/features/recipes/presentation/recipes_page.dart';
import 'package:app/src/features/settings/presentation/settings_page.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int _index = 0;

  static const _pages = <Widget>[
    PantryListPage(),
    RecipesPage(),
    SettingsPage(),
  ];

  static const _titles = <String>[
    'Pantry',
    'Recipes',
    'Settings',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_index])),
      body: _pages[_index],
      floatingActionButton: FloatingActionButton(
        onPressed: _openQuickActions,
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() {
          _index = value;
        }),
        destinations: const <NavigationDestination>[
          NavigationDestination(icon: Icon(Icons.kitchen), label: 'Pantry'),
          NavigationDestination(icon: Icon(Icons.receipt_long), label: 'Recipes'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }

  Future<void> _openQuickActions() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Scan item'),
                onTap: () => Navigator.of(context).pop('scan'),
              ),
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Manual add'),
                onTap: () => Navigator.of(context).pop('manual'),
              ),
            ],
          ),
        );
      },
    );

    if (action == 'scan') {
      if (!mounted) {
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const CameraPage()),
      );
      return;
    }

    if (action == 'manual') {
      if (!mounted) {
        return;
      }
      final result = await showModalBottomSheet<PantryItem>(
        context: context,
        isScrollControlled: true,
        builder: (_) => const ManualAddSheet(),
      );
      if (result == null) {
        return;
      }
      final uid = ref.read(currentUserProvider)?.uid;
      if (uid == null) {
        return;
      }
      await ref.read(pantryRepositoryProvider).addItem(uid, result);
    }
  }
}
