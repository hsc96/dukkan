import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io'; // File için eklendi
import 'package:image_picker/image_picker.dart'; // Logo seçimi için eklendi
import 'package:image_cropper/image_cropper.dart'; // Logo kırpma için eklendi
import 'package:firebase_storage/firebase_storage.dart'; // Firebase Storage için eklendi
import 'package:cloud_firestore/cloud_firestore.dart'; // Firestore için eklendi
import '../utils/colors.dart'; // Renk paletinizin yolu doğru olmalı

// Orijinal widget adı ve constructor korunuyor
class CustomAppBar extends StatefulWidget implements PreferredSizeWidget {
  final String title;
  final bool showYesterdayButton;

  const CustomAppBar({
    Key? key,
    required this.title,
    this.showYesterdayButton = true,
  }) : super(key: key);

  @override
  _CustomAppBarState createState() => _CustomAppBarState();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 45.0);
}

class _CustomAppBarState extends State<CustomAppBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  Timer? _initialTimer;
  Timer? _repeatTimer;
  bool _isScrollable = false;
  final GlobalKey _titleKey = GlobalKey();

  // Logo seçimi, kırpma ve saklama için state değişkenleri
  File? _localLogoFile; // Sadece seçim/kırpma sonrası geçici dosya
  String? _logoUrl; // Firestore'dan gelen veya yeni yüklenen URL
  bool _isLoadingLogo = true; // Logo yükleniyor mu?

  final ImagePicker _picker = ImagePicker();
  final ImageCropper _cropper = ImageCropper(); // ImageCropper örneği
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Maksimum dosya boyutu (örnek: 1 MB)
  final int _maxLogoSizeBytes = 1 * 1024 * 1024; // 1 MB
  // Firestore'da logo URL'sinin saklanacağı yer
  final String _logoConfigPath = 'app_settings/logo_config';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0.05, 0.0),
      end: const Offset(-1.05, 0.0),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.linear,
    ));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkIfTextOverflow();
    });

    // Kaydedilmiş logo URL'sini Firestore'dan yükle
    _loadLogoUrlFromFirestore();
  }

  // Firestore'dan logo URL'sini yükle
  Future<void> _loadLogoUrlFromFirestore() async {
    setState(() { _isLoadingLogo = true; });
    try {
      final docSnapshot = await _firestore.doc(_logoConfigPath).get();
      if (docSnapshot.exists && docSnapshot.data() != null) {
        if (mounted) {
          setState(() {
            _logoUrl = docSnapshot.data()!['url'] as String?;
          });
        }
      } else {
        print("Firestore'da logo URL'si bulunamadı.");
      }
    } catch (e) {
      print("Firestore'dan logo URL'si yüklenirken hata: $e");
      // Hata durumunda belki varsayılan logoya dönülebilir
      if (mounted) {
        setState(() { _logoUrl = null; });
      }
    } finally {
      if (mounted) {
        setState(() { _isLoadingLogo = false; });
      }
    }
  }


  void _checkIfTextOverflow() async {
    // ... (önceki kod aynı)
    if (!mounted || _titleKey.currentContext == null) return;

    final RenderBox? renderBox = _titleKey.currentContext?.findRenderObject() as RenderBox?;
    final TextPainter textPainter = TextPainter(
      text: TextSpan(text: widget.title, style: _titleStyle()),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    );

    if (renderBox != null) {
      textPainter.layout(maxWidth: renderBox.size.width);
      final bool overflows = textPainter.didExceedMaxLines;

      if (overflows != _isScrollable) {
        if (mounted) {
          setState(() {
            _isScrollable = overflows;
          });
        }
        if (overflows) {
          _startInitialAnimation();
        } else {
          _stopAnimation();
        }
      } else if (overflows && !_controller.isAnimating && (_repeatTimer == null || !_repeatTimer!.isActive)) {
        _startInitialAnimation();
      }
    }
  }

  void _startInitialAnimation() {
    // ... (önceki kod aynı)
    _stopAnimation();
    _initialTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      _controller.forward().then((_) {
        if (!mounted) return;
        _initialTimer = Timer(const Duration(seconds: 2), () {
          if (!mounted) return;
          _controller.reset();
          _startRepeatingAnimation();
        });
      });
    });
  }

  void _startRepeatingAnimation() {
    // ... (önceki kod aynı)
    _stopAnimation();
    _repeatTimer = Timer.periodic(const Duration(seconds: 12), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _controller.forward().then((_) {
        if (!mounted) return;
        _initialTimer = Timer(const Duration(seconds: 2), () {
          if (!mounted) return;
          _controller.reset();
        });
      });
    });
  }

  void _stopAnimation() {
    // ... (önceki kod aynı)
    _initialTimer?.cancel();
    _repeatTimer?.cancel();
    _initialTimer = null;
    _repeatTimer = null;
    if (mounted && _controller.isAnimating) {
      _controller.stop();
    }
    if (mounted) {
      _controller.reset();
    }
  }

  @override
  void didUpdateWidget(covariant CustomAppBar oldWidget) {
    // ... (önceki kod aynı)
    super.didUpdateWidget(oldWidget);
    if (widget.title != oldWidget.title) {
      _stopAnimation();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkIfTextOverflow();
      });
    }
  }

  @override
  void dispose() {
    _stopAnimation();
    _controller.dispose();
    super.dispose();
  }

  TextStyle _titleStyle() {
    // ... (önceki kod aynı)
    return TextStyle(
      color: Colors.black.withOpacity(0.85),
      fontWeight: FontWeight.w600,
      fontSize: 18.0,
      overflow: TextOverflow.clip,
    );
  }

  // --- Logo Seçme, Kırpma, Yükleme ve Kaydetme Fonksiyonu ---
  Future<void> _pickAndProcessLogo() async {
    File? croppedLogoFile;

    // --- 1. Seçme ve Kırpma ---
    try {
      final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile == null) return; // İptal

      final CroppedFile? cropped = await _cropImage(pickedFile.path);
      if (cropped == null) return; // Kırpma iptal

      croppedLogoFile = File(cropped.path);

    } catch (e) {
      print('Logo seçme/kırpma hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logo seçilirken/kırpılırken hata: $e')),
        );
      }
      return; // Hata varsa devam etme
    }

    // --- 2. Boyut Kontrolü ---
    try {
      final int fileSize = await croppedLogoFile.length();
      if (fileSize > _maxLogoSizeBytes) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Kırpılan logo boyutu çok büyük! (Maks: ${_maxLogoSizeBytes / (1024 * 1024)} MB)'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return; // Boyut büyükse devam etme
      }
    } catch (e) {
      print('Dosya boyutu okunurken hata: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logo boyutu kontrol edilemedi: $e')),
        );
      }
      return;
    }

    // Geçici olarak UI'da göster (yükleme sırasında)
    if (mounted) {
      setState(() {
        _localLogoFile = croppedLogoFile; // Yerel dosyayı göster
        _logoUrl = null; // Eski URL'yi temizle (varsa)
        _isLoadingLogo = true; // Yükleniyor durumunu başlat
      });
    }

    // --- 3. Firebase Storage'a Yükleme ---
    String? downloadUrl;
    try {
      downloadUrl = await _uploadLogoToStorage(croppedLogoFile);
      if (downloadUrl == null) throw Exception("Dosya yüklenemedi veya URL alınamadı.");

    } catch (e) {
      print('Logo yükleme hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logo yüklenemedi: $e')),
        );
        // Hata durumunda belki eski logoya veya varsayılana dön
        setState(() {
          _localLogoFile = null;
          _isLoadingLogo = false;
          // _loadLogoUrlFromFirestore(); // Eski URL'yi tekrar yükle?
        });
      }
      return; // Yükleme başarısızsa devam etme
    }

    // --- 4. Firestore'a Kaydetme ---
    try {
      await _saveLogoUrlToFirestore(downloadUrl);

      // Başarılı: State'i son URL ile güncelle
      if (mounted) {
        setState(() {
          _logoUrl = downloadUrl; // Yeni URL'yi ayarla
          _localLogoFile = null; // Yerel dosyayı temizle
          _isLoadingLogo = false; // Yükleme bitti
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logo başarıyla güncellendi ve kaydedildi.')),
        );
      }
    } catch (e) {
      print('Logo URL kaydedilirken hata: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logo URL kaydedilemedi: $e')),
        );
        // Hata olsa bile yüklenen URL'yi kullanmaya devam edebiliriz
        setState(() {
          _logoUrl = downloadUrl;
          _localLogoFile = null;
          _isLoadingLogo = false;
        });
      }
    }
  }

  // --- Resmi Kırpma Yardımcı Fonksiyonu ---
  Future<CroppedFile?> _cropImage(String filePath) async {
    // ... (önceki kod aynı)
    final theme = Theme.of(context);
    final bool isDarkMode = theme.brightness == Brightness.dark;

    return await _cropper.cropImage(
      sourcePath: filePath,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      compressQuality: 70,
      compressFormat: ImageCompressFormat.png,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Logoyu Kırp',
          toolbarColor: theme.primaryColor,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
          statusBarColor: theme.primaryColor,
          backgroundColor: theme.scaffoldBackgroundColor,
          activeControlsWidgetColor: theme.primaryColor,
        ),
        IOSUiSettings(
          title: 'Logoyu Kırp',
          aspectRatioLockEnabled: true,
          aspectRatioPickerButtonHidden: true,
          resetButtonHidden: false,
          rotateButtonsHidden: false,
          doneButtonTitle: 'Tamam',
          cancelButtonTitle: 'İptal',
        ),
      ],
    );
  }

  // --- Firebase Storage'a Yükleme Fonksiyonu ---
  Future<String?> _uploadLogoToStorage(File logoFile) async {
    try {
      // Benzersiz bir dosya adı oluştur (örn: logo_timestamp.png)
      String fileName = 'logo_${DateTime.now().millisecondsSinceEpoch}.png';
      // Yüklenecek yolu belirle (örn: logos/logo_timestamp.png)
      Reference storageRef = _storage.ref().child('logos/$fileName');

      // Dosyayı yükle
      UploadTask uploadTask = storageRef.putFile(logoFile);

      // Yükleme tamamlanana kadar bekle
      TaskSnapshot snapshot = await uploadTask;

      // İndirme URL'sini al
      String downloadUrl = await snapshot.ref.getDownloadURL();
      print('Logo başarıyla yüklendi: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('Firebase Storage yükleme hatası: $e');
      return null; // Hata durumunda null döndür
    }
  }

  // --- Firestore'a Logo URL'sini Kaydetme Fonksiyonu ---
  Future<void> _saveLogoUrlToFirestore(String url) async {
    try {
      // Belirtilen yola URL'yi yaz (varolanı üzerine yazar)
      await _firestore.doc(_logoConfigPath).set({'url': url, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      print('Logo URL Firestore\'a kaydedildi: $url');
    } catch (e) {
      print('Firestore kaydetme hatası: $e');
      // Hata durumunda tekrar deneme veya loglama yapılabilir
      rethrow; // Hatayı yukarıya fırlat
    }
  }


  @override
  Widget build(BuildContext context) {
    // ... (Tema ve renk tanımlamaları öncekiyle aynı)
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final appBarBackgroundColorStart = colorTheme3 ?? colorScheme.surface;
    final appBarBackgroundColorEnd = colorTheme3 != null
        ? HSLColor.fromColor(colorTheme3!).withLightness((HSLColor.fromColor(colorTheme3!).lightness + 0.05).clamp(0.0, 1.0)).toColor()
        : colorScheme.surfaceVariant;
    final iconColor = ThemeData.estimateBrightnessForColor(appBarBackgroundColorStart) == Brightness.dark
        ? Colors.white70
        : Colors.black87;
    final buttonTextColor = ThemeData.estimateBrightnessForColor(colorTheme2 ?? colorScheme.secondaryContainer) == Brightness.dark
        ? Colors.white
        : Colors.black87;
    final buttonBackgroundColor = colorTheme2 ?? colorScheme.secondaryContainer;
    final buttonSplashColor = colorTheme5 ?? theme.primaryColor;

    return AppBar(
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [appBarBackgroundColorStart, appBarBackgroundColorEnd],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
      ),
      backgroundColor: Colors.transparent,
      elevation: 1.0,
      shadowColor: Colors.black.withOpacity(0.1),
      toolbarHeight: widget.preferredSize.height,
      leadingWidth: 56,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded, color: iconColor, size: 22),
        tooltip: 'Geri',
        onPressed: () => Navigator.pop(context),
        splashRadius: 22,
      ),
      titleSpacing: 0,
      title: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // --- Tıklanabilir ve Yüklenen Logo Alanı ---
          InkWell(
            onTap: _pickAndProcessLogo, // Güncellenmiş fonksiyonu çağır
            customBorder: const CircleBorder(),
            child: Tooltip(
              message: 'Logoyu değiştirmek için tıklayın',
              child: CircleAvatar(
                radius: 19,
                backgroundColor: Colors.white.withOpacity(0.9),
                child: ClipOval(
                  child: Padding(
                    padding: const EdgeInsets.all(3.0),
                    child: _buildLogoWidget(), // Logo widget'ını ayrı fonksiyonda oluştur
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Başlık ve Butonlar Satırı
          SizedBox(
            height: 38,
            child: Row(
              children: [
                // Dün Butonu
                widget.showYesterdayButton
                    ? _modernTextButton(
                  text: 'dün',
                  route: '/yesterday',
                  backgroundColor: buttonBackgroundColor,
                  textColor: buttonTextColor,
                  splashColor: buttonSplashColor,
                )
                    : const SizedBox(width: 60),

                // Kaydırılabilir Başlık
                Expanded(
                  child: Center(
                    child: ClipRect(
                      child: _isScrollable
                          ? SlideTransition(
                        position: _offsetAnimation,
                        child: SizedBox(
                          key: _titleKey,
                          child: Text(widget.title, style: _titleStyle(), maxLines: 1),
                        ),
                      )
                          : SizedBox(
                        key: _titleKey,
                        child: Text(widget.title, style: _titleStyle(), maxLines: 1, textAlign: TextAlign.center),
                      ),
                    ),
                  ),
                ),

                // Takvim Butonu
                _modernTextButton(
                  text: 'takvim',
                  route: '/calendar',
                  backgroundColor: buttonBackgroundColor,
                  textColor: buttonTextColor,
                  splashColor: buttonSplashColor,
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.segment_rounded, color: iconColor, size: 24),
          tooltip: 'Menü',
          onPressed: () => Scaffold.of(context).openEndDrawer(),
          splashRadius: 22,
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  // Logo widget'ını oluşturan yardımcı fonksiyon
  Widget _buildLogoWidget() {
    // Yükleniyorsa progress göster
    if (_isLoadingLogo) {
      return const SizedBox(
        width: 20, // Boyutları logoyla aynı tut
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    // Önce yerel dosyayı kontrol et (yeni seçilmiş/kırpılmış olabilir)
    if (_localLogoFile != null) {
      return Image.file(
        _localLogoFile!,
        fit: BoxFit.contain,
        width: 32,
        height: 32,
        errorBuilder: (context, error, stackTrace) => _defaultLogo(), // Hata durumunda varsayılan
      );
    }
    // Sonra Firestore'dan gelen URL'yi kontrol et
    if (_logoUrl != null && _logoUrl!.isNotEmpty) {
      return Image.network(
        _logoUrl!,
        fit: BoxFit.contain,
        width: 32,
        height: 32,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child; // Yüklendi
          return const SizedBox( // Yüklenirken progress
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        },
        errorBuilder: (context, error, stackTrace) => _defaultLogo(), // Hata durumunda varsayılan
      );
    }
    // Hiçbiri yoksa varsayılan logoyu göster
    return _defaultLogo();
  }

  // Varsayılan logo widget'ı
  Widget _defaultLogo() {
    return Image.asset(
      'assets/logo.png', // Varsayılan logo yolu
      fit: BoxFit.contain,
      width: 32,
      height: 32,
    );
  }


  // Orijinal TextButton'ı modernize eden stil fonksiyonu
  Widget _modernTextButton({
    // ... (önceki kod aynı)
    required String text,
    required String route,
    required Color backgroundColor,
    required Color textColor,
    required Color splashColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: TextButton(
        onPressed: () => Navigator.pushNamed(context, route),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          backgroundColor: backgroundColor.withOpacity(0.9),
          foregroundColor: splashColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            // side: BorderSide(color: textColor.withOpacity(0.2), width: 0.5),
          ),
          elevation: 0.5,
          shadowColor: Colors.black.withOpacity(0.1),
          minimumSize: const Size(50, 34),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}