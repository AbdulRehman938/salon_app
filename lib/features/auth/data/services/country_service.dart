import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/country_phone_data.dart';

class CountryService {
  static final Uri _endpoint = Uri.parse(
    'https://restcountries.com/v3.1/all?fields=name,idd,cca2',
  );

  Future<List<CountryPhoneData>> fetchCountries() async {
    final response = await http.get(_endpoint);
    if (response.statusCode != 200) {
      throw Exception('Unable to load country metadata');
    }

    final List<dynamic> decoded = jsonDecode(response.body) as List<dynamic>;
    final countries = <CountryPhoneData>[];

    for (final item in decoded) {
      final map = item as Map<String, dynamic>;
      final idd = map['idd'] as Map<String, dynamic>?;
      final root = (idd?['root'] as String?)?.trim();
      final suffixes = (idd?['suffixes'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList();

      if (root == null ||
          root.isEmpty ||
          suffixes == null ||
          suffixes.isEmpty) {
        continue;
      }

      final dialCode = '$root${suffixes.first}'.replaceAll(' ', '');
      final iso2 = (map['cca2'] as String? ?? '').toUpperCase();
      final nameData = map['name'] as Map<String, dynamic>?;
      final commonName = nameData?['common'] as String?;

      if (iso2.isEmpty || commonName == null || commonName.isEmpty) {
        continue;
      }

      countries.add(
        CountryPhoneData(
          name: commonName,
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
