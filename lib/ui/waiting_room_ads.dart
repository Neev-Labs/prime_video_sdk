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
  final String? type;

  Ad({
    this.videoLink,
    this.image,
    this.description,
    this.callToActionText,
    this.clickthroughUrl,
    this.type,
  });

  factory Ad.fromJson(Map<String, dynamic> json) {
    return Ad(
      videoLink: json['videoLink'],
      image: json['image'],
      description: json['description'],
      callToActionText: json['callToActionText'],
      clickthroughUrl: json['clickthroughUrl'],
      type: json['type'],
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

  String? _getYoutubeVideoId(String url) {
    if (url.isEmpty) return null;
    debugPrint("Attempting to extract ID from: $url");
    
    try {
      final uri = Uri.parse(url);
      if (uri.host.contains('youtube.com') && uri.queryParameters.containsKey('v')) {
        debugPrint("Found ID via query param: ${uri.queryParameters['v']}");
        return uri.queryParameters['v'];
      }
      if (uri.host.contains('youtu.be') && uri.pathSegments.isNotEmpty) {
        debugPrint("Found ID via path segment: ${uri.pathSegments.first}");
        return uri.pathSegments.first;
      }
      if (uri.host.contains('youtube.com') && uri.pathSegments.contains('embed')) {
          final index = uri.pathSegments.indexOf('embed');
          if (index + 1 < uri.pathSegments.length) {
              return uri.pathSegments[index + 1];
          }
      }
    } catch (e) {
      debugPrint("Uri parse error: $e");
    }

    // Fallback Regex
    RegExp regExp = RegExp(
      r'(?:youtube\.com\/(?:[^\/\n\s]+\/\S+\/|(?:v|e(?:mbed)?)\/|\S*?[?&]v=)|youtu\.be\/)([a-zA-Z0-9_-]{11})',
      caseSensitive: false,
      multiLine: false,
    );
    final match = regExp.firstMatch(url);
    if (match != null && match.groupCount >= 1) {
       debugPrint("Found ID via Regex: ${match.group(1)}");
      return match.group(1);
    }
    debugPrint("Failed to extract video ID");
    return null;
  }

  String? _getThumbnailUrl(Ad ad) {
    if (ad.videoLink != null && ad.videoLink!.isNotEmpty) {
      final videoId = _getYoutubeVideoId(ad.videoLink!);
      if (videoId != null) {
        return 'https://img.youtube.com/vi/$videoId/0.jpg';
      }
    }
    return ad.image;
  }

  @override
  Widget build(BuildContext context) {
    if (_ads.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Opacity(
            opacity: 0.5,
            child: Image.asset(
              'assets/images/hospital_building.jpg',
              package: 'prime_video_library',
              height: 200,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                 // Fallback if asset not found (e.g. package issue)
                 return const Center(child: Icon(Icons.image_not_supported, size: 50, color: Colors.grey));
              },
            ),
          ),
        ),
      );
    }

    final primaryColor = const Color(0xFF673AB7); 

    return Container(
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
               if (_ads.length > 1) 
                 _buildArrowButton(
                   icon: Icons.chevron_left,
                   onPressed: _prevAd,
                   primaryColor: primaryColor,
                 ),
               
               if (_ads.length > 1)
                 const SizedBox(width: 5),
                 
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
                       final imageUrl = _getThumbnailUrl(ad);
                       final showPlayButton = ad.type == 'Online video';

                       final targetUrl = (ad.videoLink != null && ad.videoLink!.isNotEmpty) 
                           ? ad.videoLink 
                           : ad.clickthroughUrl;

                       return OverflowBox(
                         minHeight: 0,
                         maxHeight: double.infinity,
                         alignment: Alignment.topCenter,
                         child: MeasureSize(
                           onChange: (size) => _onSizeChanged(index, size),
                           child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Image Node
                              if (imageUrl != null && imageUrl.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 16.0),
                                  child: GestureDetector(
                                    onTap: () => _launchUrl(targetUrl),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8.0),
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          Image.network(
                                            imageUrl,
                                            fit: BoxFit.fitWidth, 
                                            loadingBuilder: (context, child, loadingProgress) {
                                              if (loadingProgress == null) return child;
                                              return Container(
                                                height: 200, 
                                                color: Colors.grey[200],
                                                child: const Center(child: CircularProgressIndicator()),
                                              );
                                            },
                                            errorBuilder: (context, error, stackTrace) {
                                                debugPrint("Ad image failed to load: $error, url: $imageUrl");
                                                return const Center(
                                                  child: Icon(Icons.broken_image, size: 50, color: Colors.grey),
                                                );
                                            },
                                          ),
                                          if (showPlayButton)
                                            Container(
                                              decoration: BoxDecoration(
                                                color: Colors.black.withOpacity(0.5),
                                                shape: BoxShape.circle,
                                              ),
                                              padding: const EdgeInsets.all(12),
                                              child: const Icon(
                                                Icons.play_arrow,
                                                color: Colors.white,
                                                size: 32,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                
                              // Description (HTML)
                              if (ad.videoLink == null && ad.description != null && ad.description!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 0.0), 
                                  child: Html(
                                    data: ad.description,
                                    style: {
                                      "body": Style(
                                        margin: Margins.zero,
                                        padding: HtmlPaddings.zero,
                                        fontFamily: 'Inter', 
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
                
                              if (ad.videoLink == null) const SizedBox(height: 16),
                
                              // Call To Action Button
                              if (ad.videoLink == null &&
                                  ad.callToActionText != null &&
                                  ad.callToActionText!.isNotEmpty &&
                                  targetUrl != null && targetUrl.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 0.0), 
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
                                      onPressed: () => _launchUrl(targetUrl),
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
        constraints: const BoxConstraints(),
        padding: EdgeInsets.zero,
        iconSize: 25,
      ),
    );
  }
}

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
