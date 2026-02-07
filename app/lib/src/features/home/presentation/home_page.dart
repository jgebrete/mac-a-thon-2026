import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/src/features/camera/presentation/camera_page.dart';
import 'package:app/src/features/pantry/presentation/pantry_list_page.dart';
import 'package:app/src/features/recipes/presentation/recipes_page.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int _index = 1;

  static const _pages = <Widget>[
    CameraPage(),
    PantryListPage(),
    RecipesPage(),
  ];

  static const _titles = <String>[
    'Camera',
    'Pantry',
    'Generated Recipes',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_index])),
      body: _pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const <NavigationDestination>[
          NavigationDestination(icon: Icon(Icons.camera_alt), label: 'Camera'),
          NavigationDestination(icon: Icon(Icons.kitchen), label: 'Pantry'),
          NavigationDestination(icon: Icon(Icons.receipt_long), label: 'Recipes'),
        ],
      ),
    );
  }
}

