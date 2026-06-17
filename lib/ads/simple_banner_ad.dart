import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SimpleBannerAd extends StatefulWidget {
  const SimpleBannerAd({super.key});

  @override
  State<SimpleBannerAd> createState() => _SimpleBannerAdState();
}

class _SimpleBannerAdState extends State<SimpleBannerAd> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  // 🟢 RETRIEVED FROM .ENV FILE
  final String adUnitId = dotenv.get('ADMOB_BANNER_AD_UNIT_ID', fallback: 'ca-app-pub-3940256099942544/6300978111'); // Default to test ID if missing

  @override
  void initState() {
    super.initState();
      _loadAd();
  }

  void _loadAd() {
    _bannerAd = BannerAd(
      size: AdSize.banner,
      adUnitId: adUnitId,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('✅ Banner ad loaded successfully');
          setState(() {
            _isLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('❌ Failed to load banner ad: ${error.message}');
          debugPrint('❌ Error code: ${error.code}');
          ad.dispose();
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
      return const SizedBox.shrink();
    if (!_isLoaded || _bannerAd == null) {
      return Container(
        width: 320,
        height: 50,
        color: Colors.grey[200],
        child: const Center(
          child: Text(
            'Loading ad...',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
      );
    }

    return Container(
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      alignment: Alignment.center,
      child: AdWidget(ad: _bannerAd!),
    );
  }
}




