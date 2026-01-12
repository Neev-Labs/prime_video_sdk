import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:url_launcher/url_launcher.dart';

class Ad {
  final String? videoLink;
  final String? image;
  final String? description;
  final String? callToActionText;
  final String? clickthroughUrl;

  Ad({
    this.videoLink,
    this.image,
    this.description,
    this.callToActionText,
    this.clickthroughUrl,
  });

  factory Ad.fromJson(Map<String, dynamic> json) {
    return Ad(
      videoLink: json['videoLink'],
      image: json['image'],
      description: json['description'],
      callToActionText: json['callToActionText'],
      clickthroughUrl: json['clickthroughUrl'],
    );
  }
}

class WaitingRoomAds extends StatefulWidget {
  final List<dynamic> adsData;

  const WaitingRoomAds({super.key, required this.adsData});

  @override
  State<WaitingRoomAds> createState() => _WaitingRoomAdsState();
}

class _WaitingRoomAdsState extends State<WaitingRoomAds> {
  int _currentIndex = 0;
  List<Ad> _ads = [];
  final PageController _pageController = PageController();
  List<double> _heights = [];
  double _currentHeight = 200; // Default estimate

  @override
  void initState() {
    super.initState();
    _parseAds();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _parseAds() {
    // Filter out ads that might be completely empty or invalid if necessary
    // For now, we accept them but individual components will hide if null
    _ads = widget.adsData.map((e) => Ad.fromJson(e)).toList();
    _heights = List.filled(_ads.length, 200.0);
  }

  void _prevAd() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _nextAd() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _launchUrl(String? url) async {
    if (url != null && url.isNotEmpty) {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        debugPrint("Could not launch $url");
      }
    }
  }

  void _onSizeChanged(int index, Size size) {
    if (_heights[index] != size.height) {
      // Use post frame callback to avoid build conflicts
      WidgetsBinding.instance.addPostFrameCallback((_) {
         if (mounted) {
           setState(() {
            _heights[index] = size.height;
            if (index == _currentIndex) {
              _currentHeight = _heights[index];
            }
          });
         }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_ads.isEmpty) return const SizedBox.shrink();

    // Define the purple color from the screenshot approximately
    final primaryColor = const Color(0xFF673AB7); 

    return Container(
      // padding: const EdgeInsets.all(16.0), // Removed extra padding
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
               // Left Arrow
               if (_ads.length > 1) 
                 _buildArrowButton(
                   icon: Icons.chevron_left,
                   onPressed: _prevAd,
                   primaryColor: primaryColor,
                 ),
               
               if (_ads.length > 1)
                 const SizedBox(width: 5),
                 
               // Main Content
               Expanded(
                 child: AnimatedContainer(
                   duration: const Duration(milliseconds: 100),
                   height: _currentHeight > 0 ? _currentHeight : 200,
                   child: PageView.builder(
                     controller: _pageController,
                     itemCount: _ads.length,
                     onPageChanged: (index) {
                       setState(() {
                         _currentIndex = index;
                         _currentHeight = _heights[index];
                       });
                     },
                     itemBuilder: (context, index) {
                       final ad = _ads[index];
                       return OverflowBox(
                         minHeight: 0,
                         maxHeight: double.infinity,
                         alignment: Alignment.topCenter,
                         child: MeasureSize(
                           onChange: (size) => _onSizeChanged(index, size),
                           child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Image
                              if (ad.image != null && ad.image!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 16.0),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8.0),
                                    child: Image.network(
                                      ad.image!,
                                      fit: BoxFit.fitWidth, // Width same (fill), height variable
                                      loadingBuilder: (context, child, loadingProgress) {
                                        if (loadingProgress == null) return child;
                                        return Container(
                                          height: 200, // Placeholder height
                                          color: Colors.grey[200],
                                          child: const Center(child: CircularProgressIndicator()),
                                        );
                                      },
                                      errorBuilder: (context, error, stackTrace) =>
                                          const SizedBox.shrink(),
                                    ),
                                  ),
                                ),
                
                              // Description (HTML)
                              if (ad.description != null && ad.description!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 0.0), // Adjust if needed
                                  child: Html(
                                    data: ad.description,
                                    style: {
                                      "body": Style(
                                        margin: Margins.zero,
                                        padding: HtmlPaddings.zero,
                                        fontFamily: 'Inter', // Try to use common font if available
                                        color: Colors.black87,
                                      ),
                                      "h5": Style(
                                        margin: Margins.only(bottom: 6),
                                        fontSize: FontSize(18),
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF212121),
                                      ),
                                      "p": Style(
                                         margin: Margins.only(bottom: 8),
                                         fontSize: FontSize(14),
                                         color: const Color(0xFF424242),
                                      ),
                                    },
                                  ),
                                ),
                
                              const SizedBox(height: 16),
                
                              // Call To Action Button
                              if (ad.callToActionText != null &&
                                  ad.callToActionText!.isNotEmpty &&
                                  ad.clickthroughUrl != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 0.0), // Reduced bottom padding as dots are outside
                                  child: Center(
                                    child: OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        side: BorderSide(color: primaryColor),
                                        foregroundColor: primaryColor,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(4.0),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 32, vertical: 12),
                                      ),
                                      onPressed: () => _launchUrl(ad.clickthroughUrl),
                                      child: Text(
                                        ad.callToActionText!,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                           ),
                         ),
                       );
                     },
                   ),
                 ),
               ),
               
               // Right Arrow
               if (_ads.length > 1)
                  const SizedBox(width: 5),
    
               if (_ads.length > 1)
                 _buildArrowButton(
                   icon: Icons.chevron_right,
                   onPressed: _nextAd,
                   primaryColor: primaryColor,
                 ),
            ],
          ),
          
          // Page Indicators (Outside Layout)
          if (_ads.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_ads.length, (idx) {
                  return Container(
                    width: 8.0,
                    height: 8.0,
                    margin: const EdgeInsets.symmetric(horizontal: 4.0),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentIndex == idx 
                          ? primaryColor
                          : Colors.grey.withOpacity(0.5),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildArrowButton({
    required IconData icon,
    required VoidCallback onPressed,
    required Color primaryColor,
  }) {
    return Container(
      width: 35,
      height: 35,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        shape: BoxShape.circle,
        border: Border.all(color: primaryColor),
      ),
      child: IconButton(
        icon: Icon(icon),
        color: primaryColor,
        onPressed: onPressed,
        constraints: const BoxConstraints(), // tight
        padding: EdgeInsets.zero,
        iconSize: 25,
      ),
    );
  }
}

// Helper Widget to report size changes
class MeasureSize extends SingleChildRenderObjectWidget {
  final ValueChanged<Size> onChange;

  const MeasureSize({
    super.key,
    required this.onChange,
    required Widget child,
  }) : super(child: child);

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _MeasureSizeRenderObject(onChange);
  }
}

class _MeasureSizeRenderObject extends RenderProxyBox {
  ValueChanged<Size> onChange;
  Size? _oldSize;

  _MeasureSizeRenderObject(this.onChange);

  @override
  void performLayout() {
    super.performLayout();
    if (size != _oldSize) {
      _oldSize = size;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onChange(size);
      });
    }
  }
}
