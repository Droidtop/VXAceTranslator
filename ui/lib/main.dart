import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'patch_service.dart';

void main() => runApp(const TranslatorApp());

class TranslatorApp extends StatelessWidget {
  const TranslatorApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'VX Ace Patcher',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xff7257d9),
            brightness: Brightness.dark,
          ),
          scaffoldBackgroundColor: const Color(0xff111018),
          cardTheme: const CardThemeData(
            color: Color(0xff1b1925),
            margin: EdgeInsets.zero,
          ),
          useMaterial3: true,
        ),
        home: const PatcherScreen(),
      );
}

class PatcherScreen extends StatefulWidget {
  const PatcherScreen({super.key});

  @override
  State<PatcherScreen> createState() => _PatcherScreenState();
}

class _PatcherScreenState extends State<PatcherScreen> {
  final _service = PatchService.platform();
  final _mods = <String>[];
  final _log = <String>[];
  String? _gamePath;
  String? _translationPath;
  bool _working = false;

  Future<String?> _pickFolder() => FilePicker.platform.getDirectoryPath();

  Future<void> _patch() async {
    if (_gamePath == null || _translationPath == null) return;
    setState(() {
      _working = true;
      _log.clear();
    });
    try {
      await for (final line in _service.patch(PatchRequest(
        gamePath: _gamePath!,
        translationPath: _translationPath!,
        mods: List.unmodifiable(_mods),
      ))) {
        if (mounted) setState(() => _log.add(line));
      }
      if (mounted) setState(() => _log.add('Patch completed successfully.'));
    } catch (error) {
      if (mounted) setState(() => _log.add('Patch failed: $error'));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const Text('VX Ace Patcher', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text('Translations and mods, on every device.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 28),
                  _PathCard(
                    number: '01',
                    title: 'Game folder',
                    path: _gamePath,
                    action: () async {
                      final path = await _pickFolder();
                      if (path != null) setState(() => _gamePath = path);
                    },
                  ),
                  const SizedBox(height: 12),
                  _PathCard(
                    number: '02',
                    title: 'Translation folder',
                    path: _translationPath,
                    action: () async {
                      final path = await _pickFolder();
                      if (path != null) setState(() => _translationPath = path);
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(children: [
                    const Expanded(child: Text('Mods', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600))),
                    FilledButton.tonalIcon(
                      onPressed: () async {
                        final path = await _pickFolder();
                        if (path != null) setState(() => _mods.add(path));
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Add mod'),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Text('Drag to set priority. Mods lower in the list win conflicts.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 12),
                  Card(
                    child: _mods.isEmpty
                        ? const Padding(padding: EdgeInsets.all(24), child: Text('No mods selected. Add Cheese or another script pack here.'))
                        : ReorderableListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _mods.length,
                            onReorder: (oldIndex, newIndex) => setState(() {
                              if (newIndex > oldIndex) newIndex--;
                              _mods.insert(newIndex, _mods.removeAt(oldIndex));
                            }),
                            itemBuilder: (context, index) => ListTile(
                              key: ValueKey(_mods[index]),
                              leading: CircleAvatar(child: Text('${index + 1}')),
                              title: Text(_mods[index].split(RegExp(r'[/\\]')).last),
                              subtitle: Text(_mods[index], maxLines: 1, overflow: TextOverflow.ellipsis),
                              trailing: IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _mods.removeAt(index))),
                            ),
                          ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: !_working && _gamePath != null && _translationPath != null ? _patch : null,
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18)),
                    icon: _working
                        ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.auto_fix_high),
                    label: Text(_working ? 'Patching…' : 'Build patched game'),
                  ),
                  if (_log.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Card(child: Padding(padding: const EdgeInsets.all(16), child: SelectableText(_log.join('\n')))),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
}

class _PathCard extends StatelessWidget {
  const _PathCard({required this.number, required this.title, required this.path, required this.action});

  final String number;
  final String title;
  final String? path;
  final VoidCallback action;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          leading: Text(number, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700)),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(path ?? 'Choose a folder', maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: OutlinedButton(onPressed: action, child: const Text('Browse')),
        ),
      );
}
