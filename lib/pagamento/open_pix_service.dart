import 'dart:convert';
import 'package:appfute/pagamento/pix_data.dart';
import 'package:http/http.dart' as http;

class OpenPixService {
  static const String _baseUrl = 'https://api.woovi.com/api/v1/charge';
  static const String _appId = 'SUA_APP_ID_AQUI'; // Pegue no painel da OpenPix

  Future<PixData?> gerarCobrancaPix(String nomeTime, int valorCentavos) async {
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {'Authorization': _appId, 'Content-Type': 'application/json'},
        body: jsonEncode({
          'correlationID': 'pix_${DateTime.now().millisecondsSinceEpoch}',
          'value': valorCentavos, // Valor em centavos (ex: 1000 = R$ 10,00)
          'comment': 'Pagamento AppFute - $nomeTime',
        }),
      );

      if (response.statusCode == 201) {
        return PixData.fromJson(jsonDecode(response.body));
      } else {
        print("Erro OpenPix: ${response.body}");
        return null;
      }
    } catch (e) {
      print("Erro de conexão: $e");
      return null;
    }
  }
}
