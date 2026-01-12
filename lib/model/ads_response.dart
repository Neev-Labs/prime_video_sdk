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