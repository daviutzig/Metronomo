import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:just_audio/just_audio.dart';

void main() => runApp(MetronoApp());

class MetronoApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.amber,
        scaffoldBackgroundColor: Color(0xFF121212),
        colorScheme: ColorScheme.dark(primary: Colors.amber, secondary: Colors.amber),
      ),
      home: MetronomeScreen(),
    );
  }
}

class Musica {
  String id, nome, description;
  int bpm;
  Musica({required this.id, required this.nome, required this.description, required this.bpm});

  Map<String, dynamic> toMap() => {'id': id, 'nome': nome, 'description': description, 'bpm': bpm};

  factory Musica.fromMap(Map<String, dynamic> map) => Musica(
    id: map['id'], nome: map['nome'], description: map['description'], bpm: map['bpm']
  );
}

class MetronomeScreen extends StatefulWidget {
  @override
  _MetronomeScreenState createState() => _MetronomeScreenState();
}

class _MetronomeScreenState extends State<MetronomeScreen> {
  List<Musica> playlist = [];
  Musica? musicaAtual;
  bool estaRodando = false;
  Timer? _timer;
  
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  // Som de clique limpo e curto em formato WAVE padrão de mercado
  final String _clickBase64 = "UklGRigAAABXQVZFZm10IBAAAAABAAEARKwAAIhYAQACABAAZGF0YQQAAAAAgACAANgA2ADgAOA=";
  late String _audioUri;

  @override
  void initState() {
    super.initState();
    _audioUri = "data:audio/wav;base64,$_clickBase64";
    _carregarPlaylistSalva();
  }

  void _carregarPlaylistSalva() async {
    final prefs = await SharedPreferences.getInstance();
    final String? playlistJson = prefs.getString('minha_playlist');
    if (playlistJson != null) {
      final List<dynamic> decoded = jsonDecode(playlistJson);
      setState(() {
        playlist = decoded.map((item) => Musica.fromMap(item)).toList();
      });
    } else {
      setState(() {
        playlist = [
          Musica(id: '1', nome: 'Música de Abertura', description: 'Introdução no teclado', bpm: 120),
          Musica(id: '2', nome: 'Sucesso Pop', description: 'Batida reta, atenção ao refrão', bpm: 105),
          Musica(id: '3', nome: 'Balada Rock', description: 'Começa lento, cresce no solo', bpm: 78),
          Musica(id: '4', nome: 'Saideira', description: 'Ritmo acelerado para animar', bpm: 140),
        ];
      });
    }
  }

  void _salvarPlaylistNoDispositivo() async {
    final prefs = await SharedPreferences.getInstance();
    final String playlistJson = jsonEncode(playlist.map((m) => m.toMap()).toList());
    await prefs.setString('minha_playlist', playlistJson);
  }

  void _iniciarMetronomo() async {
    _timer?.cancel();
    if (musicaAtual == null) return;
    
    if (estaRodando) {
      await _audioPlayer.setUrl(_audioUri);
      _audioPlayer.play();
    }
    
    _timer = Timer.periodic(Duration(milliseconds: (60000 / musicaAtual!.bpm).round()), (t) async {
      if (estaRodando) {
        await _audioPlayer.seek(Duration.zero);
        _audioPlayer.play();
      }
    });
  }

  void _abrirFormulario({Musica? ed}) {
    var nCtrl = TextEditingController(text: ed?.nome ?? '');
    var dCtrl = TextEditingController(text: ed?.description ?? '');
    var bCtrl = TextEditingController(text: ed?.bpm.toString() ?? '120');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ed == null ? 'Nova Música' : 'Editar Música'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nCtrl, decoration: InputDecoration(labelText: 'Nome')),
            TextField(controller: dCtrl, decoration: InputDecoration(labelText: 'Descrição')),
            TextField(controller: bCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'BPM')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Sair', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () {
              if (nCtrl.text.isEmpty) return;
              setState(() {
                if (ed == null) {
                  playlist.add(Musica(id: DateTime.now().toString(), nome: nCtrl.text, description: dCtrl.text, bpm: int.parse(bCtrl.text)));
                } else {
                  ed.nome = nCtrl.text; ed.description = dCtrl.text; ed.bpm = int.parse(bCtrl.text);
                  if (musicaAtual?.id == ed.id) { musicaAtual = ed; _iniciarMetronomo(); }
                }
              });
              _salvarPlaylistNoDispositivo();
              Navigator.pop(ctx);
            },
            child: Text('Salvar'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('⏱️ Metrônomo de Palco'), backgroundColor: Colors.black),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _abrirFormulario(),
        backgroundColor: Colors.amber,
        child: Icon(Icons.add, color: Colors.black),
      ),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.all(20),
            color: Color(0xFF1E1E1E),
            child: Column(
              children: [
                Text(musicaAtual?.nome ?? "Selecione uma música", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.amber)),
                Text(musicaAtual?.description ?? "-", style: TextStyle(fontSize: 14, color: Colors.grey)),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(icon: Icon(Icons.remove_circle_outline, size: 40, color: Colors.redAccent), onPressed: musicaAtual != null ? () { setState(() { musicaAtual!.bpm--; }); _iniciarMetronomo(); _salvarPlaylistNoDispositivo(); } : null),
                    SizedBox(width: 20),
                    Text(musicaAtual != null ? '${musicaAtual!.bpm} BPM' : '-- BPM', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold)),
                    SizedBox(width: 20),
                    IconButton(icon: Icon(Icons.add_circle_outline, size: 40, color: Colors.greenAccent), onPressed: musicaAtual != null ? () { setState(() { musicaAtual!.bpm++; }); _iniciarMetronomo(); _salvarPlaylistNoDispositivo(); } : null),
                  ],
                ),
                SizedBox(height: 15),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: estaRodando ? Colors.red : Colors.green, padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15)),
                  onPressed: musicaAtual == null ? null : () { setState(() => estaRodando = !estaRodando); if (estaRodando) _iniciarMetronomo(); else { _timer?.cancel(); _audioPlayer.stop(); } },
                  icon: Icon(estaRodando ? Icons.stop : Icons.play_arrow, color: Colors.white),
                  label: Text(estaRodando ? 'PARAR' : 'INICIAR', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
          Expanded(
            child: ReorderableListView.builder(
              itemCount: playlist.length,
              onReorder: (oldIdx, newIdx) { 
                setState(() { 
                  if (oldIdx < newIdx) newIdx -= 1; 
                  playlist.insert(newIdx, playlist.removeAt(oldIdx)); 
                }); 
                _salvarPlaylistNoDispositivo();
              },
              itemBuilder: (ctx, i) {
                final m = playlist[i];
                return Dismissible(
                  key: Key(m.id),
                  direction: DismissDirection.endToStart,
                  background: Container(color: Colors.red, alignment: Alignment.centerRight, padding: EdgeInsets.only(right: 20), child: Icon(Icons.delete)),
                  onDismissed: (d) { 
                    setState(() { 
                      playlist.removeAt(i); 
                      if (musicaAtual?.id == m.id) { _timer?.cancel(); estaRodando = false; musicaAtual = null; } 
                    }); 
                    _salvarPlaylistNoDispositivo();
                  },
                  child: Card(
                    key: ValueKey(m.id),
                    color: musicaAtual?.id == m.id ? Colors.amber.withOpacity(0.15) : Color(0xFF2C2C2C),
                    margin: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: ListTile(
                      leading: CircleAvatar(backgroundColor: musicaAtual?.id == m.id ? Colors.amber : Colors.grey, child: Text('${i + 1}', style: TextStyle(color: Colors.black))),
                      title: Text(m.nome, style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${m.bpm} BPM • ${m.description}'),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [IconButton(icon: Icon(Icons.edit, size: 20), onPressed: () => _abrirFormulario(ed: m)), Icon(Icons.drag_handle)]),
                      onTap: () { setState(() { musicaAtual = m; estaRodando = true; }); _iniciarMetronomo(); },
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
