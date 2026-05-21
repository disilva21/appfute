class PixData {
  final String brCode;
  final String qrCodeUrl;
  final String correlationID;

  PixData({required this.brCode, required this.qrCodeUrl, required this.correlationID});

  factory PixData.fromJson(Map<String, dynamic> json) {
    return PixData(brCode: json['charge']['brCode'], qrCodeUrl: json['charge']['qrCodeImage'], correlationID: json['charge']['correlationID']);
  }
}
