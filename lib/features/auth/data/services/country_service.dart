import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/country_phone_data.dart';

class CountryService {
  static final Uri _endpoint = Uri.parse(
    'https://countriesnow.space/api/v0.1/countries/codes',
  );

  Future<List<CountryPhoneData>> fetchCountries() async {
    final response = await http.get(_endpoint);
    if (response.statusCode != 200) {
      throw Exception('Unable to load country metadata');
    }

    final dynamic decodedBody = jsonDecode(response.body);
    final List<dynamic> dataList;
    if (decodedBody is Map<String, dynamic> &&
        decodedBody['data'] is List<dynamic>) {
      dataList = decodedBody['data'] as List<dynamic>;
    } else if (decodedBody is List<dynamic>) {
      dataList = decodedBody;
    } else {
      throw Exception('Invalid country metadata format');
    }

    final countries = <CountryPhoneData>[];
    final seenCodes = <String>{};

    for (final item in dataList) {
      if (item is! Map<String, dynamic>) continue;

      final name = (item['name'] as String?)?.trim();
      final iso2 = (item['code'] as String? ?? '').trim().toUpperCase();
      var dialCode =
          (item['dial_code'] as String? ?? '').replaceAll(' ', '').trim();

      if (name == null ||
          name.isEmpty ||
          iso2.isEmpty ||
          dialCode.isEmpty ||
          !seenCodes.add(iso2)) {
        continue;
      }

      if (!dialCode.startsWith('+')) {
        dialCode = '+$dialCode';
      }

      countries.add(
        CountryPhoneData(
          name: name,
          iso2: iso2,
          dialCode: dialCode,
          flag: _flagEmoji(iso2),
          phoneFormat: _phoneFormatFor(iso2),
        ),
      );
    }

    countries.sort((a, b) => a.name.compareTo(b.name));
    return countries;
  }

  String _flagEmoji(String countryCode) {
    if (countryCode.length != 2) {
      return '';
    }

    final upper = countryCode.toUpperCase();
    final first = upper.codeUnitAt(0) - 65 + 0x1F1E6;
    final second = upper.codeUnitAt(1) - 65 + 0x1F1E6;
    return String.fromCharCodes([first, second]);
  }

  String _phoneFormatFor(String iso2) {
    const explicit = <String, String>{
      'US': '(###) ###-####',
      'CA': '(###) ###-####',
      'IN': '##### #####',
      'GB': '#### ### ####',
      'AE': '## ### ####',
      'PK': '### #######',
      'AU': '### ### ###',
      'DE': '#### ########',
      'FR': '# ## ## ## ##',
      'IT': '### #######',
      'BR': '(##) #####-####',
      'MX': '## #### ####',
      'SA': '## ### ####',
      'ZA': '## ### ####',
      'NG': '### ### ####',
      'JP': '##-####-####',
      'CN': '### #### ####',
    };

    return explicit[iso2] ?? '##########';
  }
}
