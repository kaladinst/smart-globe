import 'dart:async';
import 'dart:math'; // Random sayı üretmek için gerekli
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Akıllı Küre',
      // Modern Koyu Tema
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A), // Koyu Lacivert
        primaryColor: Colors.indigoAccent,
        useMaterial3: true,
        fontFamily: 'Roboto', // Varsa özel font eklenebilir
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

class _KureKontrolEkraniState extends State<KureKontrolEkrani> {
  // --- AYARLAR ---
  final String espUrl = "http://192.168.1.178/";
  final int esikDegeri = 8; // İSTEĞİNİZ ÜZERİNE SABİT KALDI

  // PIN MAP
  final Map<int, String> ulkeler = {
    0: "Türkiye",
    1: "Hindistan",
    2: "Rusya",
    3: "Nijerya",
    4: "Çin",
    5: "Amerika",
    6: "Arjantin",
    7: "Brezilya",
    8: "İzlanda",
    9: "İspanya",
    10: "Kanada",
    11: "Avustralya",
  };

  // --- SİSTEM DEĞİŞKENLERİ ---
  Timer? _veriZamanlayici; // ESP'den veri çekme timer'ı
  String debugMesaj = "Bağlanıyor...";
  
  // --- OYUN DEĞİŞKENLERİ ---
  bool oyunModuAktif = false;
  int skor = 0;
  int kalanSure = 10;
  int? hedefPinIndex; // Oyunun bizden bulmamızı istediği pin
  Timer? _oyunSayaci; // Geri sayım timer'ı
  bool oyunBitti = false;

  // --- NORMAL MOD DEĞİŞKENLERİ ---
  int aktifPinIndex = -1; // Şu an dokunulan pin
  String ekrandakiUlke = "Küreye Dokunun";

  @override
  void initState() {
    super.initState();
    // 500ms'de bir verileri çek (Polling)
    _veriZamanlayici = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      veriIstegiGonder();
    });
  }

  // --- ANA LOOP (ESP32 İLE HABERLEŞME) ---
  Future<void> veriIstegiGonder() async {
    try {
      final response = await http.get(Uri.parse(espUrl)).timeout(const Duration(seconds: 1));

      if (response.statusCode == 200) {
        // Veri formatı örn: "0,5,100,2..."
        List<String> parcalanmisVeri = response.body.split(',');
        
        int enYuksekSinyal = 0;
        int bulunanPin = -1;

        // Veriyi işle ve en güçlü dokunuşu bul
        if (parcalanmisVeri.length >= 12) {
          for (int i = 0; i < 12; i++) {
            int deger = int.tryParse(parcalanmisVeri[i]) ?? 0;
            if (deger > esikDegeri && deger > enYuksekSinyal) {
              enYuksekSinyal = deger;
              bulunanPin = i;
            }
          }
        }

        // --- MANTIK AYRIMI (OYUN MU? NORMAL Mİ?) ---
        if (oyunModuAktif) {
          _oyunMantiiniIslet(bulunanPin);
        } else {
          _normalModMantiiniIslet(bulunanPin);
        }

        // Bağlantı durumunu güncelle (sadece debug için)
        if (mounted) setState(() => debugMesaj = "Sinyal: $enYuksekSinyal");

      }
    } catch (e) {
      // Hata olursa sessizce geç veya logla
      if (mounted && !oyunModuAktif) setState(() => ekrandakiUlke = "Bağlantı Hatası");
    }
  }

  // --- 1. NORMAL MOD MANTIĞI ---
  void _normalModMantiiniIslet(int bulunanPin) {
    if (mounted) {
      setState(() {
        if (bulunanPin != -1) {
          aktifPinIndex = bulunanPin;
          ekrandakiUlke = ulkeler[bulunanPin] ?? "Bilinmeyen";
        } else {
          aktifPinIndex = -1;
          // Dokunulmuyorsa son yazanı tutabiliriz veya varsayılana döneriz
          // ekrandakiUlke = "Küreye Dokunun"; 
        }
      });
    }
  }

  // --- 2. OYUN MODU MANTIĞI ---
  void _oyunMantiiniIslet(int dokunulanPin) {
    if (oyunBitti) return;

    // Eğer doğru ülkeye dokunulursa
    if (dokunulanPin != -1 && dokunulanPin == hedefPinIndex) {
      _dogruCevap();
    }
  }

  // --- OYUN FONKSİYONLARI ---
  void _oyunuBaslat() {
    setState(() {
      oyunModuAktif = true;
      oyunBitti = false;
      skor = 0;
    });
    _yeniSoruSor();
  }

  void _yeniSoruSor() {
    // Rastgele bir pin seç
    int rastgeleIndex = Random().nextInt(ulkeler.length);
    
    setState(() {
      hedefPinIndex = rastgeleIndex;
      kalanSure = 10; // Her tur 10 saniye
    });

    // Sayacı sıfırla ve yeniden başlat
    _oyunSayaci?.cancel();
    _oyunSayaci = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (kalanSure > 0) {
            kalanSure--;
          } else {
            _oyunBitti();
          }
        });
      }
    });
  }

  void _dogruCevap() {
    _oyunSayaci?.cancel();
    setState(() {
      skor += 10; // Her doğru 10 puan
    });
    
    // Kısa bir tebrik gecikmesi (opsiyonel)
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Doğru! +10 Puan", textAlign: TextAlign.center), 
        backgroundColor: Colors.green,
        duration: Duration(milliseconds: 500),
      ),
    );
    
    // Hemen yeni soruya geç
    Future.delayed(const Duration(milliseconds: 500), () {
      if(mounted) _yeniSoruSor();
    });
  }

  void _oyunBitti() {
    _oyunSayaci?.cancel();
    setState(() {
      oyunBitti = true;
      hedefPinIndex = -1;
    });
    
    // Game Over Diyaloğu
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text("Süre Doldu!", style: TextStyle(color: Colors.redAccent)),
        content: Text("Toplam Skorunuz: $skor", style: const TextStyle(color: Colors.white, fontSize: 20)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() => oyunModuAktif = false); // Normal moda dön
            },
            child: const Text("Çıkış"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _oyunuBaslat(); // Yeniden başlat
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text("Tekrar Oyna", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  @override
  void dispose() {
    _veriZamanlayici?.cancel();
    _oyunSayaci?.cancel();
    super.dispose();
  }

  // --- GÖRSEL ARAYÜZ ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Gradient Arka Plan
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1E1B4B), // Koyu Indigo
              Color(0xFF000000), // Siyah
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // --- ÜST BAR (APP BAR) ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Icon(Icons.public, color: Colors.cyanAccent, size: 30),
                    const Text(
                      "AKILLI KÜRE",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    // Mod Değiştirme Butonu
                    IconButton(
                      icon: Icon(oyunModuAktif ? Icons.close : Icons.games, color: Colors.white),
                      onPressed: () {
                        setState(() {
                          if (oyunModuAktif) {
                            oyunModuAktif = false;
                            _oyunSayaci?.cancel();
                          } else {
                            _oyunuBaslat();
                          }
                        });
                      },
                    )
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // --- ANA İÇERİK ---
              Expanded(
                child: oyunModuAktif ? _buildOyunArayuzu() : _buildNormalArayuz(),
              ),
              
              // Alt Bilgi
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(debugMesaj, style: TextStyle(color: Colors.white.withOpacity(0.3))),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 1. OYUN ARAYÜZÜ (GAME UI)
  Widget _buildOyunArayuzu() {
    String hedefUlkeIsmi = (hedefPinIndex != null) ? ulkeler[hedefPinIndex]! : "Yükleniyor...";

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // SKOR KARTI
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
          ),
          child: Text("SKOR: $skor", style: const TextStyle(fontSize: 24, color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
        ),
        
        const SizedBox(height: 50),

        const Text("ŞUNU BUL:", style: TextStyle(color: Colors.grey, letterSpacing: 3)),
        const SizedBox(height: 10),
        
        // HEDEF ÜLKE İSMİ
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(
            hedefUlkeIsmi.toUpperCase(),
            key: ValueKey(hedefUlkeIsmi),
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              shadows: [Shadow(color: Colors.blueAccent, blurRadius: 20)],
            ),
          ),
        ),

        const SizedBox(height: 50),

        // SÜRE BAR (PROGRESS BAR)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("SÜRE", style: TextStyle(color: Colors.white70)),
                  Text("$kalanSure sn", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: kalanSure / 10.0, // 0.0 ile 1.0 arası
                backgroundColor: Colors.grey[800],
                color: kalanSure < 3 ? Colors.red : Colors.greenAccent, // Süre azsa kırmızı
                minHeight: 10,
                borderRadius: BorderRadius.circular(5),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 2. NORMAL ARAYÜZ (EXPLORER UI)
  Widget _buildNormalArayuz() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Daire içinde ikon
        Container(
          height: 120,
          width: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.indigoAccent.withOpacity(0.2),
            boxShadow: [
              BoxShadow(color: Colors.indigoAccent.withOpacity(0.3), blurRadius: 30, spreadRadius: 5)
            ]
          ),
          child: const Icon(Icons.touch_app, size: 50, color: Colors.white),
        ),
        
        const SizedBox(height: 40),

        const Text("KEŞFETMEK İÇİN DOKUN", style: TextStyle(color: Colors.white54, letterSpacing: 1.5)),
        const SizedBox(height: 10),

        // AKTİF ÜLKE İSMİ
        Text(
          aktifPinIndex != -1 ? ekrandakiUlke : "...",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.bold,
            color: aktifPinIndex != -1 ? Colors.white : Colors.grey[700],
          ),
        ),

        const SizedBox(height: 50),

        // Eğer bir ülkeye dokunuluyorsa detay butonu çıkar
        if (aktifPinIndex != -1)
          ElevatedButton.icon(
            onPressed: () {
              // Buraya detay penceresi açma kodu gelebilir
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$ekrandakiUlke hakkında bilgi...")));
            },
            icon: const Icon(Icons.info_outline),
            label: const Text("Detaylı Bilgi"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.indigo,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            ),
          ),
          
        const Spacer(),
        const Text("Oyun modu için sağ üstteki ikona tıkla ↗", style: TextStyle(color: Colors.white24, fontSize: 12)),
        const SizedBox(height: 20),
      ],
    );
  }
}