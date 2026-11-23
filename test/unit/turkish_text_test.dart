import 'package:flutter_test/flutter_test.dart';
import 'package:worldtrack/core/utils/turkish_text.dart';

void main() {
  group('TurkishText.fold', () {
    test('Türkçe büyük/küçük harf ve aksanları katlar', () {
      expect(TurkishText.fold('İSTANBUL'), 'istanbul');
      expect(TurkishText.fold('Istanbul'), 'istanbul');
      expect(TurkishText.fold('ıstanbul'), 'istanbul');
      expect(TurkishText.fold('Çorum'), 'corum');
      expect(TurkishText.fold('Şanlıurfa'), 'sanliurfa');
      expect(TurkishText.fold('Muğla'), 'mugla');
      expect(TurkishText.fold('Göreme'), 'goreme');
      expect(TurkishText.fold('Üsküdar'), 'uskudar');
      expect(TurkishText.fold('Münih'), 'munih');
      expect(TurkishText.fold('São Paulo'), 'sao paulo');
      expect(TurkishText.fold('Kraków'), 'krakow');
    });

    test('noktalama ve fazla boşlukları sadeleştirir', () {
      expect(TurkishText.fold('  New   York, NY  '), 'new york ny');
      expect(TurkishText.fold('Saint-Étienne'), 'saint etienne');
    });

    test('Latin dışı alfabeleri korur', () {
      expect(TurkishText.fold('Москва'), 'москва');
    });
  });

  group('TurkishText.compare', () {
    test('Türk alfabesine göre sıralar', () {
      final list = ['Zambiya', 'Çin', 'Cezayir', 'İtalya', 'Irak', 'Özbekistan', 'Oman', 'Şili', 'Sudan', 'Ürdün', 'Uganda']
        ..sort(TurkishText.compare);
      expect(list, ['Cezayir', 'Çin', 'Irak', 'İtalya', 'Oman', 'Özbekistan', 'Sudan', 'Şili', 'Uganda', 'Ürdün', 'Zambiya']);
    });
  });

  test('lower/upper Türkçe I kuralı', () {
    expect(TurkishText.lower('IŞIK'), 'ışık');
    expect(TurkishText.upper('istanbul'), 'İSTANBUL');
  });
}
