import 'package:phone_numbers_parser/phone_numbers_parser.dart';

/// Retourne le numéro au format international (+2250777045928)
/// ou null s'il est invalide pour le pays choisi.
String? formatPhone(String input, {IsoCode country = IsoCode.CI}) {
  final phone = PhoneNumber.parse(input, callerCountry: country);
  if (!phone.isValid(type: PhoneNumberType.mobile)) return null;
  return phone.international;
}