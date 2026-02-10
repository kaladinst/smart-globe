import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_database/ui/firebase_animated_list.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:url_launcher/url_launcher.dart'; 

// --- ENUMLAR ---
enum GameType { flag, riddle, duel, memory }

// --- SABİTLER ---
const String weatherApiKey = "70ee751980c86514f884ec3157c55617";
const String geminiApiKey = "AIzaSyDgZoHtW-766Ina7olFgrP2ZetN6dGVlP0";

// --- VERİ MODELİ ---
class CountryData {
  final String name;
  final String capital;
  final String population;
  final String language;
  final String currency;
  final String region;
  final String description;
  final String flagUrl;
  final String audioUrl;
  final List<String> photos;
  final Color primaryColor;
  final Color secondaryColor;

  CountryData({
    required this.name,
    required this.capital,
    required this.population,
    required this.language,
    required this.currency,
    required this.region,
    required this.description,
    required this.flagUrl,
    required this.audioUrl,
    required this.photos,
    required this.primaryColor,
    required this.secondaryColor,
  });

  factory CountryData.fromMap(Map<dynamic, dynamic> data) {
    List<String> parsedPhotos = [];
    if (data['photos'] != null) {
      if (data['photos'] is List) {
        parsedPhotos = (data['photos'] as List).map((e) => e.toString()).toList();
      } else if (data['photos'] is Map) {
        (data['photos'] as Map).values.forEach((v) => parsedPhotos.add(v.toString()));
      }
    }

    return CountryData(
      name: data['name'] ?? 'Bilinmiyor',
      capital: data['capital'] ?? '-',
      population: data['population'] ?? '-',
      language: data['language'] ?? '-',
      currency: data['currency'] ?? '-',
      region: data['region'] ?? '-',
      description: data['description'] ?? '',
      flagUrl: data['flagUrl'] ?? '',
      audioUrl: data['audioUrl'] ?? '',
      photos: parsedPhotos,
      primaryColor: Color(int.parse(data['colorPrimary'] ?? '0xFF000000')),
      secondaryColor: Color(int.parse(data['colorSecondary'] ?? '0xFFFFFFFF')),
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Akıllı Küre',
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: Colors.transparent,
        colorScheme: const ColorScheme.dark(
            primary: Colors.cyanAccent, secondary: Colors.purpleAccent),
      ),
      home: const KureKontrolEkrani(),
    );
  }
}

class KureKontrolEkrani extends StatefulWidget {
  const KureKontrolEkrani({super.key});

  @override
  State<KureKontrolEkrani> createState() => _KureKontrolEkraniState();
}

class _KureKontrolEkraniState extends State<KureKontrolEkrani>
    with SingleTickerProviderStateMixin {
  // --- AYARLAR ---
  final String espUrl = "http://172.28.72.193"; 
  final int esikDegeri = 8;
  
  final DatabaseReference _ulkelerRef = FirebaseDatabase.instance.ref("ulkeler");
  final DatabaseReference _skorlarRef = FirebaseDatabase.instance.ref("skorlar");
  
  // YENİ: ODA SİSTEMİ DEĞİŞKENLERİ
  DatabaseReference? _aktifOdaRef;
  StreamSubscription? _duelloDinleyici;

  // --- MEDYA & AI ---
  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioPlayer _sfxPlayer = AudioPlayer();
  late GenerativeModel _aiModel;

  // --- DEĞİŞKENLER ---
  Map<int, CountryData> countryDetails = {};
  bool veriYuklendi = false;
  Timer? _veriZamanlayici;
  bool _isNetworkBusy = false; // TRAFİK POLİSİ (EKLENDİ)
  
  // --- LED KONTROL ---
  bool ledlerAcik = true; 
  
  // --- NEFES ALMA EFEKTİ (IDLE) ---
  Timer? _breathingTimer;
  bool _breathingUp = true;
  int _breathingValue = 50; 
  bool isIdle = true; 
  Timer? _idleReturnTimer;
  
  // --- AI ---
  String aiAciklama = "";
  bool aiYukleniyor = false;
  int sonAiSorgulananPin = -1;
  Map<String, String> _aiCache = {};

  // --- SLAYT ---
  String _photoUrl = "";
  Timer? _photoTimer;
  int _photoCounter = 0;
  List<String> _currentPhotos = [];

  // --- OYUN GENEL ---
  bool oyunModuAktif = false;
  GameType aktifOyunTipi = GameType.flag;
  bool cevapBekleniyor = false;
  int skor = 0;
  int kalanSure = 10;
  int toplamSure = 10;
  int? hedefPinIndex;
  Timer? _oyunSayaci;
  bool oyunBitti = false;
  int aktifPinIndex = -1;

  // --- HAFIZA OYUNU ---
  List<int> memorySequence = [];
  int memoryUserIndex = 0;
  bool memoryIsPlaying = false; 
  String memoryStatus = "";
  CountryData? memoryActiveCard; 
  Timer? _memoryTurnTimer;
  int _memoryTimeLeft = 5;

  // --- TEK KİŞİLİK ---
  int canSayisi = 3;
  int seviye = 1;
  int dogruSayaci = 0;
  int komboSayaci = 1;
  String aiSoruMetni = "";
  bool aiSoruYukleniyor = false;

  // --- DÜELLO (YENİ SİSTEM) ---
  String myPlayerId = Random().nextInt(999999).toString();
  String playerRole = ""; 
  String? activeRoomCode; 
  int p1Score = 0;
  int p2Score = 0;
  int currentRound = 1; 
  String duelWinnerMessage = "";
  String activeTurnPlayerId = ""; 
  String buzzerOwner = ""; 
  bool canPressBuzzer = true; 

  TextEditingController _roomCodeController = TextEditingController(); 

  // --- ANİMASYON ---
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  Color ekranRengi = Colors.transparent;

  final TextEditingController _isimController = TextEditingController();
  static final http.Client _client = http.Client();

  // --- MANUEL RENKLER ---
  final Map<String, List<Color>> manuelRenkListesi = {
    "Türkiye": [const Color.fromARGB(255, 255, 17, 0), const Color.fromARGB(255, 255, 255, 255)],
    "Hindistan": [const Color.fromARGB(255, 255, 153, 51), const Color.fromARGB(255, 19, 136, 8)],
    "İspanya": [const Color.fromARGB(255, 255, 0, 0), const Color.fromARGB(255, 255, 255, 0)], 
    "Avustralya": [const Color.fromARGB(255, 0, 0, 255), const Color.fromARGB(255, 255, 255, 255)], 
    "Brezilya": [const Color.fromARGB(255, 0, 156, 59), const Color.fromARGB(255, 255, 223, 0)],
    "Amerika": [const Color.fromARGB(255, 191, 10, 48), const Color.fromARGB(255, 0, 40, 104)],
    "Rusya": [const Color.fromARGB(255, 255, 255, 255), const Color.fromARGB(255, 213, 43, 30)],
    "Çin": [const Color.fromARGB(255, 238, 28, 37), const Color.fromARGB(255, 255, 255, 0)], 
    "İzlanda": [const Color.fromARGB(255, 2, 82, 156), const Color.fromARGB(255, 220, 30, 53)], 
    "Nijerya": [const Color.fromARGB(255, 0, 135, 81), const Color.fromARGB(255, 255, 255, 255)],
    "Kanada": [const Color.fromARGB(255, 255, 0, 0), const Color.fromARGB(255, 255, 255, 255)], 
    "Arjantin": [const Color.fromARGB(255, 117, 170, 219), const Color.fromARGB(255, 255, 255, 255)],
  };

  @override
  void initState() {
    super.initState();

    _aiModel = GenerativeModel(model: 'gemini-2.5-flash', apiKey: geminiApiKey);

    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.5).animate(
        CurvedAnimation(parent: _animController, curve: Curves.elasticOut));

    // Firebase Listener
    _ulkelerRef.onValue.listen((event) {
      if (event.snapshot.exists) {
        final data = event.snapshot.value;
        Map<int, CountryData> geciciListe = {};
        if (data is List) {
          for (int i = 0; i < data.length; i++) {
            if (data[i] != null)
              geciciListe[i] = CountryData.fromMap(data[i] as Map);
          }
        } else if (data is Map) {
          data.forEach((key, value) {
            int index = int.tryParse(key.toString()) ?? -1;
            if (index != -1 && value is Map)
              geciciListe[index] = CountryData.fromMap(value);
          });
        }
        if (mounted) {
          setState(() {
            countryDetails = geciciListe;
            veriYuklendi = true;
          });
        }
      }
    });

    _veriZamanlayici =
        Timer.periodic(const Duration(milliseconds: 250), (timer) {
      if (veriYuklendi) sensorVerisiniOku();
    });

    _startBreathingEffect();
  }

  // --- NEFES ALMA EFEKTİ (GÜNCELLENDİ: DAHA YAVAŞ) ---
  void _startBreathingEffect() {
    _breathingTimer?.cancel();
    // 100ms yerine 1000ms yaptık, ESP kilitlenmesin
    _breathingTimer = Timer.periodic(const Duration(milliseconds: 1000), (timer) {
      if (!isIdle || !ledlerAcik) return;
      if (_isNetworkBusy) return;

      if (_breathingUp) {
        _breathingValue += 20;
        if (_breathingValue >= 150) _breathingUp = false;
      } else {
        _breathingValue -= 20;
        if (_breathingValue <= 20) _breathingUp = true;
      }
      
      _updateGlobeLeds("IDLE", Colors.blue, Colors.blue);
    });
  }

  Future<void> sensorVerisiniOku() async {
    if (_isNetworkBusy) return; // Trafik varsa bekle

    try {
      _isNetworkBusy = true; // Bayrak kaldır
      final response = await http.get(Uri.parse(espUrl)).timeout(const Duration(seconds: 2));
      _isNetworkBusy = false; // Bayrak indir
      
      if (response.statusCode == 200) {
        List<String> parcalanmisVeri = response.body.split(',');
        int bulunanPin = -1;

        if (parcalanmisVeri.length >= 12) {
          for (int i = 0; i < 12; i++) {
            int deger = int.tryParse(parcalanmisVeri[i]) ?? 0;
            if (deger > esikDegeri) {
              bulunanPin = i;
              break; 
            }
          }
        }

        // --- IDLE CHECK ---
        if (bulunanPin != -1) {
          isIdle = false; 
          _idleReturnTimer?.cancel();
        } else {
          if (!isIdle && (_idleReturnTimer == null || !_idleReturnTimer!.isActive)) {
            _idleReturnTimer = Timer(const Duration(seconds: 5), () {
               setState(() {
                 isIdle = true;
                 aktifPinIndex = -1;
               });
            });
          }
        }

        if (oyunModuAktif) {
          if (aktifOyunTipi == GameType.duel) {
            // Sadece Buzzer sahibi dokunabilir!
            if (buzzerOwner == myPlayerId) {
                _duelloMantiiniIslet(bulunanPin);
            }
          } else if (aktifOyunTipi == GameType.memory) {
            if (bulunanPin != -1 && !memoryIsPlaying) {
              _checkMemoryInput(bulunanPin);
            }
          } else {
            _oyunMantiiniIslet(bulunanPin);
          }
        } else {
          // --- NORMAL MOD ---
          if (bulunanPin != -1) {
             if (bulunanPin != aktifPinIndex) {
                if (mounted) {
                  setState(() {
                    aktifPinIndex = bulunanPin;
                    _audioPlayer.stop();

                    if (countryDetails.containsKey(bulunanPin)) {
                      CountryData ulke = countryDetails[bulunanPin]!;
                      _updateGlobeLeds(ulke.name, ulke.primaryColor, ulke.secondaryColor);
                      _aiBilgiGetir(ulke.name);
                      _slaytBaslat(ulke.photos);
                      if (ulke.audioUrl.isNotEmpty) {
                        _audioPlayer.play(UrlSource(ulke.audioUrl));
                      }
                    }
                  });
                }
             }
          }
        }
      }
    } catch (e) { 
        _isNetworkBusy = false; // Hata olursa da bayrağı indir
    }
  }

  // --- LED RENK GÖNDERME FONKSİYONU (GÜNCELLENDİ) ---
  Future<void> _updateGlobeLeds(String ulkeAdi, Color defaultPrimary, Color defaultSecondary) async {
    if (!ledlerAcik) {
      try {
        _isNetworkBusy = true;
        await http.get(Uri.parse("$espUrl/set_color?r1=0&g1=0&b1=0&r2=0&g2=0&b2=0")).timeout(const Duration(milliseconds: 500));
        _isNetworkBusy = false;
      } catch(e) { _isNetworkBusy = false; }
      return;
    }

    try {
      int r1, g1, b1, r2, g2, b2;

      if (ulkeAdi == "IDLE") {
        r1=0; g1=0; b1=_breathingValue; r2=0; g2=0; b2=(_breathingValue/2).toInt();
      } 
      else if (ulkeAdi == "CORRECT") {
        r1=0; g1=255; b1=0; r2=0; g2=255; b2=0; 
      }
      else if (ulkeAdi == "WRONG" || ulkeAdi == "GAME_OVER") {
        r1=255; g1=0; b1=0; r2=255; g2=0; b2=0; 
      }
      else {
        Color c1 = defaultPrimary;
        Color c2 = defaultSecondary;

        if (manuelRenkListesi.containsKey(ulkeAdi)) {
          c1 = manuelRenkListesi[ulkeAdi]![0];
          c2 = manuelRenkListesi[ulkeAdi]![1];
        } else {
          c1 = _adjustColorForBlueBackground(c1);
          c2 = _adjustColorForBlueBackground(c2);
          if (_areColorsSimilar(c1, c2)) {
            c2 = _getContrastingColor(c1);
          }
        }
        r1 = c1.red; g1 = c1.green; b1 = c1.blue;
        r2 = c2.red; g2 = c2.green; b2 = c2.blue;
      }

      _isNetworkBusy = true; // Trafik bayrağını kaldır
      String url = "$espUrl/set_color?r1=$r1&g1=$g1&b1=$b1&r2=$r2&g2=$g2&b2=$b2";
      await http.get(Uri.parse(url)).timeout(const Duration(milliseconds: 500));
      _isNetworkBusy = false; // Trafik bayrağını indir
      
    } catch (e) {
      _isNetworkBusy = false;
      // print("LED Hatası: $e");
    }
  }

  // --- RENK YARDIMCILARI ---
  Color _adjustColorForBlueBackground(Color color) {
    if (color.blue > 150 && color.red < 100 && color.green < 100) return Colors.orangeAccent;
    if (color.computeLuminance() < 0.15) return Colors.white;
    return color;
  }
  bool _areColorsSimilar(Color c1, Color c2) {
    int diff = (c1.red - c2.red).abs() + (c1.green - c2.green).abs() + (c1.blue - c2.blue).abs();
    return diff < 100;
  }
  Color _getContrastingColor(Color color) {
    if (color.computeLuminance() > 0.5) return Colors.black;
    return Colors.white;
  }

  // --- DÜELLO (YENİ SİSTEM: BUZZER & TUR) ---
  void _createDuelRoom() {
    String generatedCode = (Random().nextInt(9000) + 1000).toString(); 
    DatabaseReference newRoom = FirebaseDatabase.instance.ref("odalar/$generatedCode");
    newRoom.set({
      'hedefPin': -1,
      'buzzerOwner': "", 
      'p1Score': 0,
      'p2Score': 0,
      'round': 1,
      'winner': ""
    }).then((_) {
       _setupDuelListener(generatedCode);
       setState(() {
         oyunModuAktif = true;
         aktifOyunTipi = GameType.duel;
         playerRole = "host";
         activeRoomCode = generatedCode;
         currentRound = 1;
       });
       _yeniDuelloSorusu();
    });
  }

  void _joinDuelRoom(String inputCode) {
    DatabaseReference roomRef = FirebaseDatabase.instance.ref("odalar/$inputCode");
    roomRef.get().then((snapshot) {
      if (snapshot.exists) {
        _setupDuelListener(inputCode);
        setState(() {
          oyunModuAktif = true;
          aktifOyunTipi = GameType.duel;
          playerRole = "guest";
          activeRoomCode = inputCode;
        });
      } else {
        _hataGoster("Böyle bir oda bulunamadı!");
      }
    });
  }

  void _setupDuelListener(String roomCode) {
    _duelloDinleyici?.cancel();
    _aktifOdaRef = FirebaseDatabase.instance.ref("odalar/$roomCode");

    _duelloDinleyici = _aktifOdaRef!.onValue.listen((event) {
        if (event.snapshot.exists) {
          final data = event.snapshot.value as Map;
          setState(() {
            hedefPinIndex = data['hedefPin'] ?? -1;
            buzzerOwner = data['buzzerOwner'] ?? "";
            p1Score = data['p1Score'] ?? 0;
            p2Score = data['p2Score'] ?? 0;
            currentRound = data['round'] ?? 1;

            if (data['winner'] != null && data['winner'] != "") {
               duelWinnerMessage = "${data['winner']} KAZANDI!";
               _sfxPlayer.play(AssetSource('correct.mp3'));
               _updateGlobeLeds("CORRECT", Colors.green, Colors.green);
            } else {
               canPressBuzzer = (buzzerOwner == "");
            }
          });
        }
    });
  }

  void _pressBuzzer() {
    if (_aktifOdaRef == null) return;
    _aktifOdaRef!.runTransaction((Object? currentData) {
      if (currentData == null) return Transaction.abort();
      Map<String, dynamic> data = Map<String, dynamic>.from(currentData as Map);
      if (data['buzzerOwner'] == "") {
        data['buzzerOwner'] = myPlayerId;
        return Transaction.success(data);
      } else {
        return Transaction.abort();
      }
    });
  }

  void _yeniDuelloSorusu() {
    if (countryDetails.isEmpty || _aktifOdaRef == null) return;
    if (currentRound > 5) {
       String winner = p1Score > p2Score ? "KURUCU" : (p2Score > p1Score ? "MİSAFİR" : "BERABERE");
       _aktifOdaRef!.update({'winner': winner});
       return;
    }
    int yeni = countryDetails.keys.toList()[Random().nextInt(countryDetails.length)];
    _aktifOdaRef!.update({'hedefPin': yeni, 'buzzerOwner': ""});
    _updateGlobeLeds("IDLE", Colors.blue, Colors.blue); 
  }

  void _duelloMantiiniIslet(int dokunulanPin) {
    if (_aktifOdaRef == null || buzzerOwner != myPlayerId) return; 
    
    if (dokunulanPin != -1) {
      bool isCorrect = (dokunulanPin == hedefPinIndex);
      int nextRound = currentRound + 1;

      if (isCorrect) {
         _sfxPlayer.play(AssetSource('correct.mp3'));
         _updateGlobeLeds("CORRECT", Colors.green, Colors.green);
         
         int newP1 = (playerRole == "host") ? p1Score + 10 : p1Score;
         int newP2 = (playerRole == "guest") ? p2Score + 10 : p2Score;
         
         if (nextRound > 5) {
             String winner = newP1 > newP2 ? "KURUCU" : (newP2 > newP1 ? "MİSAFİR" : "BERABERE");
             _aktifOdaRef!.update({'p1Score': newP1, 'p2Score': newP2, 'round': nextRound, 'winner': winner});
         } else {
             _aktifOdaRef!.update({'p1Score': newP1, 'p2Score': newP2, 'round': nextRound});
             if (playerRole == "host") Future.delayed(const Duration(seconds: 2), _yeniDuelloSorusu);
             else Future.delayed(const Duration(seconds: 2), _yeniDuelloSorusu);
         }
      } else {
         _sfxPlayer.play(AssetSource('wrong.mp3'));
         _updateGlobeLeds("WRONG", Colors.red, Colors.red);
         if (nextRound > 5) {
             String winner = p1Score > p2Score ? "KURUCU" : (p2Score > p1Score ? "MİSAFİR" : "BERABERE");
             _aktifOdaRef!.update({'round': nextRound, 'winner': winner});
         } else {
             _aktifOdaRef!.update({'round': nextRound});
             Future.delayed(const Duration(seconds: 2), _yeniDuelloSorusu);
         }
      }
    }
  }

  // --- MEMORY GAME ---
  void _startMemoryGame() {
    _memoryTurnTimer?.cancel();
    setState(() {
      oyunModuAktif = true;
      aktifOyunTipi = GameType.memory;
      skor = 0;
      memorySequence.clear();
      memoryStatus = "HAZIR MISIN?";
      ekranRengi = Colors.transparent;
      memoryActiveCard = null;
    });
    _updateGlobeLeds("IDLE", Colors.blue, Colors.blue);
    Future.delayed(const Duration(seconds: 2), _addNewStepToMemory);
  }

  void _addNewStepToMemory() {
    _memoryTurnTimer?.cancel();
    List<int> mevcutPinler = countryDetails.keys.toList();
    if (mevcutPinler.isEmpty) return;
    int randomPin = mevcutPinler[Random().nextInt(mevcutPinler.length)];
    setState(() {
      memorySequence.add(randomPin);
      memoryUserIndex = 0;
      memoryIsPlaying = true;
      memoryStatus = "İZLE! 👀";
    });
    _playSequence();
  }

  Future<void> _playSequence() async {
    await Future.delayed(const Duration(milliseconds: 500));
    for (int pin in memorySequence) {
      if (!mounted) return;
      CountryData ulke = countryDetails[pin]!;
      _updateGlobeLeds(ulke.name, ulke.primaryColor, ulke.secondaryColor);
      setState(() {
        memoryActiveCard = ulke; 
        ekranRengi = ulke.primaryColor.withOpacity(0.3); 
      });
      await Future.delayed(const Duration(milliseconds: 600));
      _updateGlobeLeds("IDLE", Colors.blue, Colors.blue); 
      setState(() {
        memoryActiveCard = null; 
        ekranRengi = Colors.transparent;
      });
      await Future.delayed(const Duration(milliseconds: 200));
    }
    if (mounted) {
      setState(() {
        memoryIsPlaying = false; 
        memoryStatus = "SIRA SENDE! 👉";
      });
      _updateGlobeLeds("IDLE", Colors.blue, Colors.blue);
      _startMemoryUserTimer();
    }
  }

  void _startMemoryUserTimer() {
    _memoryTurnTimer?.cancel();
    setState(() => _memoryTimeLeft = 5);
    _memoryTurnTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_memoryTimeLeft > 0) {
            _memoryTimeLeft--;
          } else {
            timer.cancel();
            setState(() => memoryStatus = "SÜRE BİTTİ! ⏰");
            _oyunBitti();
          }
        });
      }
    });
  }

  void _checkMemoryInput(int dokunulanPin) {
    if (cevapBekleniyor) return; 
    setState(() => cevapBekleniyor = true);
    Future.delayed(const Duration(milliseconds: 300), () => setState(() => cevapBekleniyor = false));

    if (dokunulanPin == memorySequence[memoryUserIndex]) {
      _sfxPlayer.play(AssetSource('correct.mp3'));
      _startMemoryUserTimer();
      _updateGlobeLeds("CORRECT", Colors.green, Colors.green);
      Future.delayed(Duration(milliseconds: 300), () {
         if(mounted && !memoryIsPlaying) _updateGlobeLeds("IDLE", Colors.blue, Colors.blue);
      });
      setState(() {
        memoryStatus = "DOĞRU! ✅";
        ekranRengi = Colors.green.withOpacity(0.3); 
      });
      Future.delayed(const Duration(milliseconds: 300), () => setState(() => ekranRengi = Colors.transparent));
      memoryUserIndex++;
      if (memoryUserIndex >= memorySequence.length) {
        _memoryTurnTimer?.cancel();
        setState(() {
          skor += 10 * memorySequence.length;
          memoryStatus = "MÜKEMMEL! 🚀";
        });
        Future.delayed(const Duration(seconds: 1), _addNewStepToMemory);
      }
    } else {
      _memoryTurnTimer?.cancel();
      _updateGlobeLeds("WRONG", Colors.red, Colors.red);
      setState(() {
        memoryStatus = "YANLIŞ! ❌";
        ekranRengi = Colors.red.withOpacity(0.5); 
      });
      _oyunBitti();
    }
  }

  // --- OYUN BASICS ---
  void _oyunMantiiniIslet(int dokunulanPin) {
    if (oyunBitti || cevapBekleniyor || (aktifOyunTipi == GameType.riddle && aiSoruYukleniyor)) return;
    if (dokunulanPin != -1) {
      if (dokunulanPin == hedefPinIndex) _dogruCevap();
      else _yanlisCevap();
    }
  }

  void _oyunuBaslat(GameType type) {
    setState(() {
      oyunModuAktif = true;
      aktifOyunTipi = type;
      oyunBitti = false;
      skor = 0;
      canSayisi = 3;
    });
    if (type == GameType.memory) {
      _startMemoryGame();
    } else {
      _yeniSoruSor();
    }
  }

  void _yeniSoruSor() {
    _oyunSayaci?.cancel();
    if (oyunBitti) return;
    List<int> pins = countryDetails.keys.toList();
    if (pins.isEmpty) return;
    int yeni;
    do { yeni = pins[Random().nextInt(pins.length)]; } while (yeni == hedefPinIndex && pins.length > 1);
    
    _updateGlobeLeds("IDLE", Colors.blue, Colors.blue);

    setState(() {
      hedefPinIndex = yeni;
      kalanSure = 10;
      cevapBekleniyor = false;
      ekranRengi = Colors.transparent;
    });
    if (aktifOyunTipi == GameType.riddle) _aiBilmeceGetir(countryDetails[hedefPinIndex]!.name);
    else _sayaciBaslat();
  }

  void _sayaciBaslat() {
    _oyunSayaci = Timer.periodic(const Duration(seconds: 1), (t) {
      if (mounted) {
        if (kalanSure > 0) setState(() => kalanSure--);
        else { t.cancel(); _yanlisCevap(); }
      }
    });
  }

  void _dogruCevap() {
    _oyunSayaci?.cancel(); _sfxPlayer.play(AssetSource('correct.mp3'));
    _updateGlobeLeds("CORRECT", Colors.green, Colors.green);
    setState(() { skor += 10 + kalanSure; cevapBekleniyor = true; });
    Future.delayed(const Duration(seconds: 1), _yeniSoruSor);
  }

  void _yanlisCevap() {
    _oyunSayaci?.cancel(); _sfxPlayer.play(AssetSource('wrong.mp3'));
    _updateGlobeLeds("WRONG", Colors.red, Colors.red);
    setState(() { 
      canSayisi--; 
      cevapBekleniyor = true; 
      ekranRengi = Colors.red.withOpacity(0.3); 
    });
    Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && !oyunBitti) setState(() => ekranRengi = Colors.transparent);
    });
    if (canSayisi <= 0) _oyunBitti();
    else Future.delayed(const Duration(seconds: 1), _yeniSoruSor);
  }

  void _oyunBitti() {
    _oyunSayaci?.cancel(); _memoryTurnTimer?.cancel(); _sfxPlayer.play(AssetSource('gameover.mp3'));
    _updateGlobeLeds("GAME_OVER", Colors.red, Colors.red);
    Future.delayed(Duration(seconds: 2), () => _updateGlobeLeds("IDLE", Colors.blue, Colors.blue));
    setState(() { 
      oyunBitti = true; 
      hedefPinIndex = -1; 
      ekranRengi = Colors.transparent; 
    });
    _skorKaydetDialog();
  }

  // --- DİĞER FONKSİYONLAR ---
  Future<void> _aiBilgiGetir(String ulkeAdi) async { 
    if (_aiCache.containsKey(ulkeAdi)) {
      setState(() { aiAciklama = _aiCache[ulkeAdi]!; aiYukleniyor = false; sonAiSorgulananPin = aktifPinIndex; });
      return;
    }
    if (aiYukleniyor || sonAiSorgulananPin == aktifPinIndex) return;
    setState(() { aiYukleniyor = true; aiAciklama = "Yapay Zeka düşünüyor... 🤖"; });
    try {
      final prompt = "Sen fütüristik bir akıllı küresin. Bana $ulkeAdi hakkında ansiklopedilerde kolay bulunmayan, şaşırtıcı bir teknolojik gerçeği tek bir etkileyici ve akılda kalıcı cümleyle anlat.";
      final content = [Content.text(prompt)];
      final response = await _aiModel.generateContent(content);
      if (mounted) {
         String sonuc = response.text ?? "Veri alınamadı.";
         _aiCache[ulkeAdi] = sonuc;
         setState(() { aiAciklama = sonuc; aiYukleniyor = false; sonAiSorgulananPin = aktifPinIndex; });
      }
    } catch (e) {
      if (mounted) setState(() { aiAciklama = countryDetails[aktifPinIndex]?.description ?? "Bağlantı hatası."; aiYukleniyor = false; });
    }
  }

  Future<void> _aiBilmeceGetir(String ulkeAdi) async {
    setState(() { aiSoruYukleniyor = true; aiSoruMetni = "Yapay Zeka soruyu hazırlıyor... 🧠"; });
    bool aiBasarili = false;
    String sonucMetni = "";
    try {
      final prompt = "Bana $ulkeAdi ülkesi hakkında, adını ASLA söylemeden, ülkenin en meşhur yemeğini tarif et. Çok kısa, zorlu bir bilmece yaz.";
      final content = [Content.text(prompt)];
      final response = await Future.any([_aiModel.generateContent(content), Future.delayed(const Duration(seconds: 8), () => throw TimeoutException("Zaman Aşımı"))]) as GenerateContentResponse; 
      if (response.text != null && response.text!.isNotEmpty) { sonucMetni = response.text!; aiBasarili = true; }
    } catch (e) {}
    if (!mounted) return;
    if (aiBasarili) {
      setState(() { aiSoruMetni = sonucMetni; aiSoruYukleniyor = false; });
    } else {
      CountryData? hedefUlke = countryDetails[hedefPinIndex];
      String yedekBilmece = "Bu ülkeyi tahmin et!";
      if (hedefUlke != null) {
        List<String> sablonlar = ["Başkentim ${hedefUlke.capital}. Ben kimim?", "${hedefUlke.region} kıtasındayım, para birimim ${hedefUlke.currency}. Beni bul!", "Nüfusum yaklaşık ${hedefUlke.population}. Hangi ülkeyim?"];
        yedekBilmece = sablonlar[Random().nextInt(sablonlar.length)];
      }
      setState(() { aiSoruMetni = yedekBilmece; aiSoruYukleniyor = false; });
    }
    _sayaciBaslat();
  }

  Future<Map<String, dynamic>> _fetchWeather(String capital) async {
    if (capital == "-" || capital.isEmpty) return {"error": "N/A"};
    try {
      final encodedCapital = Uri.encodeComponent(capital);
      final response = await http.get(Uri.parse("https://api.openweathermap.org/data/2.5/weather?q=$encodedCapital&appid=$weatherApiKey&units=metric&lang=tr"));
      if (response.statusCode == 200) return json.decode(response.body); else return {"error": "Hata"};
    } catch (e) { return {"error": "Hata"}; }
  }

  void _teleportRandomly(String countryName, String capital) async {
    List<String> searchTerms = ["Square", "City Center", "Old Town", "Tower", "Cathedral", "Museum", "Park"];
    String randomTerm = searchTerms[Random().nextInt(searchTerms.length)];
    String query = Uri.encodeComponent("$randomTerm $capital $countryName");
    final Uri url = Uri.parse("https://www.google.com/maps/search/?api=1&query=$query"); 
    try { if (await canLaunchUrl(url)) { await launchUrl(url, mode: LaunchMode.externalApplication); } else { await launchUrl(url); } } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Harita açılamadı."), backgroundColor: Colors.red)); }
  }

  void _hataGoster(String mesaj) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mesaj, style: const TextStyle(color: Colors.white)), backgroundColor: Colors.redAccent)); }
  void _bilgiGoster(String mesaj) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mesaj), backgroundColor: Colors.green, duration: const Duration(seconds: 1))); }
  void _slaytBaslat(List<String> photos) { 
    _photoTimer?.cancel();
    _currentPhotos = photos.isNotEmpty ? photos : []; 
    _photoCounter = 0;
    if (_currentPhotos.isNotEmpty) {
      setState(() => _photoUrl = _currentPhotos[0]);
      _photoTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
        if (mounted && _currentPhotos.isNotEmpty) {
          setState(() { _photoCounter = (_photoCounter + 1) % _currentPhotos.length; _photoUrl = _currentPhotos[_photoCounter]; });
        }
      });
    } else {
      String ulkeAdi = countryDetails[aktifPinIndex]?.name ?? "Nature";
      setState(() { _photoUrl = "https://image.pollinations.ai/prompt/scenic%20view%20of%20$ulkeAdi%20nature%20landscape?width=800&height=600&nokeep=true"; });
    }
  }

  // --- UI DIALOGS ---
  void _oyunModuSec() {
    if (!veriYuklendi) return;
    showDialog(context: context, builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text("MOD SEÇ", style: TextStyle(color: Colors.white)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(leading: const Icon(Icons.flag, color: Colors.blue), title: const Text("Bayrak Modu", style: TextStyle(color: Colors.white)), onTap: () { Navigator.pop(ctx); _oyunuBaslat(GameType.flag); }),
            ListTile(leading: const Icon(Icons.psychology, color: Colors.purple), title: const Text("Bilmece Modu", style: TextStyle(color: Colors.white)), onTap: () { Navigator.pop(ctx); _oyunuBaslat(GameType.riddle); }),
            ListTile(leading: const Icon(Icons.memory, color: Colors.pink), title: const Text("Hafıza Modu", style: TextStyle(color: Colors.white)), onTap: () { Navigator.pop(ctx); _oyunuBaslat(GameType.memory); }),
            const Divider(color: Colors.white24),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              ElevatedButton(onPressed: () {Navigator.pop(ctx); _createDuelRoom();}, child: const Text("Oda Kur")),
              ElevatedButton(onPressed: () {
                   Navigator.pop(ctx);
                   showDialog(context: context, builder: (c) => AlertDialog(
                     backgroundColor: Colors.grey[900],
                     title: const Text("Oda Kodu", style: TextStyle(color: Colors.white)),
                     content: TextField(controller: _roomCodeController, keyboardType: TextInputType.number, style: TextStyle(color: Colors.white)),
                     actions: [TextButton(onPressed: (){ if(_roomCodeController.text.length==4) { Navigator.pop(c); _joinDuelRoom(_roomCodeController.text); }}, child: const Text("GİR"))],
                   ));
                }, child: const Text("Katıl"))
            ])
        ]),
      ));
  }

  void _skorKaydetDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text("OYUN BİTTİ", style: TextStyle(color: Colors.white)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text("$skor Puan", style: const TextStyle(fontSize: 30, color: Colors.amber)),
          TextField(controller: _isimController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "İsim"))
        ]),
        actions: [
          ElevatedButton(onPressed: () {
              if (_isimController.text.isNotEmpty) _skorlarRef.push().set({'isim': _isimController.text, 'puan': skor});
              Navigator.pop(ctx);
              setState(() => oyunModuAktif = false);
              _liderlikTablosunuGoster();
            }, child: const Text("KAYDET"))
        ],
      ));
  }

  void _liderlikTablosunuGoster() {
    showModalBottomSheet(context: context, backgroundColor: const Color(0xFF0F172A), isScrollControlled: true, builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7, padding: const EdgeInsets.all(20),
        child: Column(children: [
            const Text("🏆 Liderlik", style: TextStyle(color: Colors.amber, fontSize: 24)),
            const SizedBox(height: 20),
            Expanded(child: FirebaseAnimatedList(query: _skorlarRef, sort: (a, b) {
                  int puanA = int.tryParse(a.child('puan').value.toString()) ?? 0;
                  int puanB = int.tryParse(b.child('puan').value.toString()) ?? 0;
                  return puanB.compareTo(puanA);
                }, itemBuilder: (context, snapshot, animation, index) {
                  Map data = snapshot.value as Map;
                  return Card(color: Colors.white10, child: ListTile(title: Text(data['isim'], style: const TextStyle(color: Colors.white)), trailing: Text("${data['puan']}", style: const TextStyle(color: Colors.greenAccent))));
                })),
          ]),
      ));
  }

  @override
  void dispose() {
    _veriZamanlayici?.cancel(); _photoTimer?.cancel(); _oyunSayaci?.cancel(); _memoryTurnTimer?.cancel(); _breathingTimer?.cancel(); _duelloDinleyici?.cancel();
    _isimController.dispose(); _roomCodeController.dispose(); _animController.dispose(); _audioPlayer.dispose(); _sfxPlayer.dispose();
    super.dispose();
  }

  // --- UI ---
  @override
  Widget build(BuildContext context) {
    CountryData? activeData = (aktifPinIndex != -1) ? countryDetails[aktifPinIndex] : null;
    return Scaffold(
      backgroundColor: Colors.black, // Basit arka plan
      appBar: AppBar(
        title: const Text("AKILLI KÜRE"),
        actions: [
          IconButton(icon: Icon(ledlerAcik ? Icons.lightbulb : Icons.lightbulb_outline), onPressed: () => setState(() => ledlerAcik = !ledlerAcik)),
          IconButton(icon: const Icon(Icons.emoji_events), onPressed: _liderlikTablosunuGoster)
        ],
        leading: oyunModuAktif ? IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() { oyunModuAktif = false; })) : null,
      ),
      body: oyunModuAktif ? _buildOyunArayuzu() : _buildNormalArayuz(activeData),
    );
  }

  // --- MODERN DISCOVERY UI (GLASSMORPHISM) ---
  Widget _buildNormalArayuz(CountryData? data) {
    if (data == null) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.public, size: 120, color: Colors.white10), const SizedBox(height: 20), const Text("Keşfetmek için Dokun", style: TextStyle(color: Colors.white54, fontSize: 18))]));
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          // CINEMATIC HEADER
          Stack(
            alignment: Alignment.bottomLeft,
            children: [
              Container(
                height: 250,
                width: double.infinity,
                decoration: BoxDecoration(
                  image: DecorationImage(image: NetworkImage(data.flagUrl), fit: BoxFit.cover, colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.4), BlendMode.darken)),
                  borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
                  boxShadow: [BoxShadow(color: data.primaryColor.withOpacity(0.5), blurRadius: 20, spreadRadius: -5)],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data.name.toUpperCase(), style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Colors.white, shadows: [Shadow(color: Colors.black, blurRadius: 10)])),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: data.primaryColor, borderRadius: BorderRadius.circular(5)), child: Text(data.region.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // INFO CARDS
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              childAspectRatio: 1.1,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              children: [
                _buildModernInfoCard(Icons.location_city, "Başkent", data.capital),
                _buildModernInfoCard(Icons.groups, "Nüfus", data.population),
                _buildModernInfoCard(Icons.translate, "Dil", data.language),
                _buildModernInfoCard(Icons.attach_money, "Para", data.currency),
                
                // WEATHER CARD
                FutureBuilder<Map<String, dynamic>>(
                  future: _fetchWeather(data.capital),
                  builder: (context, snapshot) {
                    String val = "...";
                    IconData icon = Icons.cloud;
                    if (snapshot.hasData && !snapshot.data!.containsKey("error")) {
                      val = "${snapshot.data!['main']['temp']}°C";
                      icon = Icons.wb_sunny;
                    }
                    return _buildModernInfoCard(icon, "Hava", val, isSpecial: true);
                  },
                ),
                _buildModernInfoCard(Icons.music_note, "Marş", "Çal", onTap: () {
                   if (data.audioUrl.isNotEmpty) _audioPlayer.play(UrlSource(data.audioUrl));
                }),
              ],
            ),
          ),
          
          const SizedBox(height: 20),

          // --- YENİ EKLENEN HIZLI EYLEM BUTONLARI (IŞINLANMA & SAAT) ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // 1. IŞINLANMA BUTONU
                _buildActionButton(Icons.travel_explore, "Işınlan", Colors.orangeAccent, () {
                  _teleportRandomly(data.name, data.capital);
                }),
                
                // 2. CANLI SAAT BUTONU
                FutureBuilder<Map<String, dynamic>>(
                  future: _fetchWeather(data.capital),
                  builder: (context, snapshot) {
                    return _buildActionButton(Icons.access_time, "Saat", Colors.cyanAccent, () {
                      String mesaj = "Saat bilgisi alınıyor...";
                      
                      if (snapshot.hasData && !snapshot.data!.containsKey("error")) {
                        int timezoneOffset = snapshot.data!['timezone']; 
                        DateTime nowUtc = DateTime.now().toUtc();
                        DateTime localTime = nowUtc.add(Duration(seconds: timezoneOffset));
                        String formattedTime = "${localTime.hour.toString().padLeft(2, '0')}:${localTime.minute.toString().padLeft(2, '0')}";
                        mesaj = "${data.name} Yerel Saati: $formattedTime";
                      }
                      
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(mesaj, style: TextStyle(fontSize: 16)),
                        backgroundColor: data.primaryColor,
                        duration: Duration(seconds: 3),
                      ));
                    });
                  }
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // AI CARD
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
              ),
              child: Column(children: [
                Row(children: const [Icon(Icons.auto_awesome, color: Colors.cyanAccent), SizedBox(width: 10), Text("YAPAY ZEKA ÖZETİ", style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold))]),
                const SizedBox(height: 10),
                aiYukleniyor ? const LinearProgressIndicator(color: Colors.cyanAccent) : Text(aiAciklama.isEmpty ? data.description : aiAciklama, style: const TextStyle(color: Colors.white70, height: 1.5)),
              ]),
            ),
          ),
          const SizedBox(height: 20),

          // SLIDESHOW
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _currentPhotos.isNotEmpty ? _currentPhotos.length : 1,
              itemBuilder: (ctx, index) {
                String imgUrl = _currentPhotos.isNotEmpty ? _currentPhotos[index] : _photoUrl;
                return Container(
                  width: 300,
                  margin: EdgeInsets.only(left: 16, right: index == (_currentPhotos.length -1) ? 16 : 0),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(15), image: DecorationImage(image: NetworkImage(imgUrl), fit: BoxFit.cover)),
                );
              },
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // --- YUVARLAK BUTON WIDGET ---
  Widget _buildActionButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2), 
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.6), width: 2), 
              boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 15, spreadRadius: 2)] 
            ),
            child: Icon(icon, color: color, size: 30),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // --- MODERN CARD DESIGN ---
  Widget _buildModernInfoCard(IconData icon, String title, String value, {bool isSpecial = false, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSpecial ? Colors.orangeAccent.withOpacity(0.2) : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSpecial ? Colors.orange : Colors.cyanAccent, size: 28),
            const SizedBox(height: 5),
            Text(title, style: const TextStyle(color: Colors.white38, fontSize: 10)),
            const SizedBox(height: 2),
            Text(value, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  // --- GAME UI ---
  Widget _buildOyunArayuzu() {
    CountryData? hedefData = (hedefPinIndex != null && hedefPinIndex != -1) ? countryDetails[hedefPinIndex] : null;

    if (aktifOyunTipi == GameType.memory) {
      return Center(
        child: memoryActiveCard != null
            ? ClipRRect(borderRadius: BorderRadius.circular(20), child: Image.network(memoryActiveCard!.flagUrl, width: 350, fit: BoxFit.contain))
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("HAFIZA MODU", style: TextStyle(color: Colors.pinkAccent, fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  Text("$skor", style: const TextStyle(fontSize: 80, fontWeight: FontWeight.bold, color: Colors.white)),
                  Text(memoryStatus, style: TextStyle(fontSize: 20, color: memoryIsPlaying ? Colors.redAccent : Colors.greenAccent)),
                  if (!memoryIsPlaying) ...[
                    const SizedBox(height: 20),
                    SizedBox(width: 200, child: LinearProgressIndicator(value: _memoryTimeLeft / 5.0, color: _memoryTimeLeft < 2 ? Colors.red : Colors.green)),
                  ]
                ],
              ),
      );
    }
    
    // --- FLAG/RIDDLE GAME UI ---
    if(aktifOyunTipi == GameType.duel) {
      if (duelWinnerMessage.isNotEmpty) {
          return Center(child: Text(duelWinnerMessage, style: const TextStyle(fontSize: 40, color: Colors.amber, fontWeight: FontWeight.bold)));
      }

      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
           Text("ODA: $activeRoomCode - TUR: $currentRound/5", style: const TextStyle(color: Colors.amber, fontSize: 20)),
           const SizedBox(height: 20),
           Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              Column(children: [const Icon(Icons.person, color: Colors.blue, size: 40), Text("$p1Score", style: const TextStyle(fontSize: 30, color: Colors.white))]),
              Column(children: [const Icon(Icons.person, color: Colors.red, size: 40), Text("$p2Score", style: const TextStyle(fontSize: 30, color: Colors.white))]),
           ]),
           const SizedBox(height: 30),
           if(hedefData != null) 
             ClipRRect(borderRadius: BorderRadius.circular(15), child: Image.network(hedefData.flagUrl, height: 200)),
           
           const SizedBox(height: 40),
           
           // --- YENİ BİLİYORUM BUTONU ---
           if (buzzerOwner == "") 
              SizedBox(
                width: 200, height: 80,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purpleAccent, 
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    elevation: 10,
                  ),
                  onPressed: _pressBuzzer, 
                  child: const Text("BİLİYORUM! ✋", style: TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold))
                ),
              )
           else if (buzzerOwner == myPlayerId)
              const Text("DOKUN KÜREYE! 👇", style: TextStyle(fontSize: 30, color: Colors.greenAccent, fontWeight: FontWeight.bold))
           else 
              const Text("RAKİP CEVAPLIYOR...", style: TextStyle(fontSize: 24, color: Colors.grey))
        ],
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(aktifOyunTipi == GameType.flag ? "BU BAYRAK HANGİSİ?" : "OYUN MODU", style: const TextStyle(color: Colors.cyanAccent, fontSize: 24, fontWeight: FontWeight.bold)),
          Text("$skor Puan", style: const TextStyle(color: Colors.white, fontSize: 50)),
          const SizedBox(height: 20),
          
          // FLAG MODE: Show Flag
          if(aktifOyunTipi == GameType.flag && hedefData != null)
             ClipRRect(borderRadius: BorderRadius.circular(20), child: Image.network(hedefData.flagUrl, width: 300, fit: BoxFit.cover)),

          // RIDDLE MODE: Show Text
          if(aktifOyunTipi == GameType.riddle) 
             Padding(padding: const EdgeInsets.all(20), child: Text(aiSoruMetni, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 20))),
          
          const SizedBox(height: 20),
          LinearProgressIndicator(value: kalanSure/toplamSure, color: Colors.amber),
        ],
      ),
    );
  }
}