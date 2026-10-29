
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:metronome/metronome.dart';

void main() {
  runApp(const MetronoApp());
}

class MetronoApp extends StatelessWidget {
  const MetronoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: const ColorScheme.dark(
          primary: Colors.amber,
          secondary: Colors.amber,
        ),
      ),
      home: const MetronomeScreen(),
    );
  }
}

class Musica {
  String id;
  String nome;
  String description;
  int bpm;

  Musica({
    required this.id,
    required this.nome,
    required this.description,
    required this.bpm,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'nome': nome,
        'description': description,
        'bpm': bpm,
      };

  factory Musica.fromMap(Map<String, dynamic> map) {
    return Musica(
      id: map['id'].toString(),
      nome: map['nome'].toString(),
      description: (map['description'] ?? '').toString(),
      bpm: (map['bpm'] as num).toInt(),
    );
  }
}

class MetronomeScreen extends StatefulWidget {
  const MetronomeScreen({super.key});

  @override
  State<MetronomeScreen> createState() => _MetronomeScreenState();
}

class _MetronomeScreenState extends State<MetronomeScreen> {
  final List<Musica> playlist = [];
  final Metronome _metronome = Metronome();

  Musica? musicaAtual;
  bool estaRodando = false;
  bool _inicializando = false;
  bool _trocandoMusica = false;

  @override
  void initState() {
    super.initState();
    _carregarPlaylist();
  }

  Future<void> _carregarPlaylist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dados = prefs.getString('minha_playlist');

      if (dados != null) {
        final lista = (jsonDecode(dados) as List)
            .map((e) => Musica.fromMap(
                  Map<String, dynamic>.from(e as Map),
                ))
            .toList();

        if (!mounted) return;
        setState(() => playlist.addAll(lista));
      } else {
        playlist.addAll([
          Musica(
            id: '1',
            nome: 'Música de Abertura',
            description: 'Introdução no teclado',
            bpm: 120,
          ),
          Musica(
            id: '2',
            nome: 'Sucesso Pop',
            description: 'Batida reta, atenção ao refrão',
            bpm: 105,
          ),
          Musica(
            id: '3',
            nome: 'Balada Rock',
            description: 'Começa lento, cresce no solo',
            bpm: 78,
          ),
          Musica(
            id: '4',
            nome: 'Saideira',
            description: 'Ritmo acelerado para animar',
            bpm: 140,
          ),
        ]);

        await _salvarPlaylist();
        if (mounted) setState(() {});
      }
    } catch (e) {
      debugPrint('Erro ao carregar setlist: $e');
      _mensagem('Erro ao carregar as músicas.');
    }
  }

  Future<void> _salvarPlaylist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'minha_playlist',
      jsonEncode(playlist.map((m) => m.toMap()).toList()),
    );
  }

  void _mensagem(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(texto)),
    );
  }

  Future<void> _inicializarMotor() async {
    if (_metronome.isInitialized) return;

    if (_inicializando) {
      while (_inicializando) {
        await Future<void>.delayed(
          const Duration(milliseconds: 50),
        );
      }
      if (_metronome.isInitialized) return;
    }

    _inicializando = true;

    try {
      await _metronome.init(
        'assets/click.wav',
        bpm: musicaAtual?.bpm ?? 120,
        volume: 100,
        enableTickCallback: false,
        sampleRate: 44100,
      );
    } finally {
      _inicializando = false;
    }
  }

  Future<void> _iniciar() async {
    if (musicaAtual == null || !estaRodando) return;

    try {
      await _inicializarMotor();

      if (!mounted || !estaRodando || musicaAtual == null) {
        return;
      }

      _metronome.setBPM(musicaAtual!.bpm);
      _metronome.play();
    } catch (e, stack) {
      debugPrint('Erro ao iniciar metrônomo: $e');
      debugPrintStack(stackTrace: stack);

      if (mounted) {
        setState(() => estaRodando = false);
        _mensagem('Erro ao iniciar áudio: $e');
      }
    }
  }

  Future<void> _parar() async {
    if (_metronome.isInitialized) {
      _metronome.stop();
    }
  }

  Future<void> _alternar() async {
    if (musicaAtual == null || _trocandoMusica) return;

    if (estaRodando) {
      setState(() => estaRodando = false);
      await _parar();
    } else {
      setState(() => estaRodando = true);
      await _iniciar();
    }
  }

  Future<void> _selecionarMusica(Musica musica) async {
    if (_trocandoMusica) return;

    _trocandoMusica = true;

    try {
      await _parar();

      if (!mounted) return;

      setState(() {
        musicaAtual = musica;
        estaRodando = true;
      });

      await _iniciar();
    } finally {
      _trocandoMusica = false;
    }
  }

  Future<void> _alterarBpm(int delta) async {
    if (musicaAtual == null) return;

    setState(() {
      musicaAtual!.bpm =
          (musicaAtual!.bpm + delta).clamp(30, 300);
    });

    if (_metronome.isInitialized) {
      _metronome.setBPM(musicaAtual!.bpm);
    }

    await _salvarPlaylist();
  }


  Future<void> _abrirFormulario({Musica? editar}) async {
    final nomeCtrl = TextEditingController(
      text: editar?.nome ?? '',
    );
    final descCtrl = TextEditingController(
      text: editar?.description ?? '',
    );
    final bpmCtrl = TextEditingController(
      text: (editar?.bpm ?? 120).toString(),
    );

    Map<String, dynamic>? resultado;

  
      resultado = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(
            editar == null ? 'Nova música' : 'Editar música',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nomeCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Nome da música',
                  ),
                ),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Descrição',
                  ),
                ),
                TextField(
                  controller: bpmCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'BPM (30 a 300)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final nome = nomeCtrl.text.trim();
                final descricao = descCtrl.text.trim();
                final bpm = int.tryParse(bpmCtrl.text.trim());

                if (nome.isEmpty ||
                    bpm == null ||
                    bpm < 30 ||
                    bpm > 300) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Informe o nome e um BPM entre 30 e 300.',
                      ),
                    ),
                  );
                  return;
                }

                // Retorna os dados e fecha o diálogo.
                // O setState será executado somente depois.
                Navigator.pop(dialogContext, {
                  'nome': nome,
                  'description': descricao,
                  'bpm': bpm,
                });
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      );
    } 

    // Cancelou ou fechou o formulário.
    if (resultado == null || !mounted) return;

    final nome = resultado['nome'] as String;
    final descricao = resultado['description'] as String;
    final bpm = resultado['bpm'] as int;

    if (editar == null) {
      setState(() {
        playlist.add(
          Musica(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            nome: nome,
            description: descricao,
            bpm: bpm,
          ),
        );
      });
    } else {
      setState(() {
        editar.nome = nome;
        editar.description = descricao;
        editar.bpm = bpm;
      });

      if (musicaAtual?.id == editar.id &&
          _metronome.isInitialized) {
        await _metronome.setBPM(bpm);
      }
    }

    await _salvarPlaylist();
  }


  Future<void> _excluirMusica(Musica musica) async {
    if (musicaAtual?.id == musica.id) {
      setState(() => estaRodando = false);
      await _parar();

      if (!mounted) return;

      setState(() => musicaAtual = null);
    }

    setState(() {
      playlist.removeWhere((m) => m.id == musica.id);
    });

    await _salvarPlaylist();
  }

  @override
  void dispose() {
    _metronome.destroy();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('⏱️ Metrônomo de Palco'),
        backgroundColor: Colors.black,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.amber,
        onPressed: () => _abrirFormulario(),
        child: const Icon(Icons.add, color: Colors.black),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF1E1E1E),
            child: Column(
              children: [
                Text(
                  musicaAtual?.nome ?? 'Selecione uma música',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber,
                  ),
                ),
                Text(
                  musicaAtual?.description ?? '-',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.remove_circle_outline,
                        size: 40,
                        color: Colors.redAccent,
                      ),
                      onPressed: musicaAtual == null
                          ? null
                          : () => _alterarBpm(-1),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      musicaAtual == null
                          ? '-- BPM'
                          : '${musicaAtual!.bpm} BPM',
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: const Icon(
                        Icons.add_circle_outline,
                        size: 40,
                        color: Colors.greenAccent,
                      ),
                      onPressed: musicaAtual == null
                          ? null
                          : () => _alterarBpm(1),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        estaRodando ? Colors.red : Colors.green,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 15,
                    ),
                  ),
                  onPressed:
                      musicaAtual == null ? null : _alternar,
                  icon: Icon(
                    estaRodando ? Icons.stop : Icons.play_arrow,
                    color: Colors.white,
                  ),
                  label: Text(
                    estaRodando ? 'PARAR' : 'INICIAR',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ReorderableListView.builder(
              itemCount: playlist.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (oldIndex < newIndex) newIndex--;
                  final musica = playlist.removeAt(oldIndex);
                  playlist.insert(newIndex, musica);
                });
                _salvarPlaylist();
              },
              itemBuilder: (context, index) {
                final musica = playlist[index];
                final selecionada =
                    musicaAtual?.id == musica.id;

                return Dismissible(
                  key: ValueKey(musica.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete),
                  ),
                  onDismissed: (_) => _excluirMusica(musica),
                  child: Card(
                    color: selecionada
                        ? Colors.amber.withOpacity(0.15)
                        : const Color(0xFF2C2C2C),
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: selecionada
                            ? Colors.amber
                            : Colors.grey,
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(color: Colors.black),
                        ),
                      ),
                      title: Text(
                        musica.nome,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        '${musica.bpm} BPM • ${musica.description}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, size: 20),
                            onPressed: () =>
                                _abrirFormulario(editar: musica),
                          ),
                          const Icon(Icons.drag_handle),
                        ],
                      ),
                      onTap: () => _selecionarMusica(musica),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

