import 'package:cloud_firestore/cloud_firestore.dart' show GeoPoint;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescate_alimentos/views/widgets/pickup_address.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  test('mapsSearchUri codifica la dirección para Google Maps', () {
    final uri = mapsSearchUri('Av. Juárez #45, Centro');

    expect(uri.host, 'www.google.com');
    expect(uri.path, '/maps/search/');
    expect(uri.queryParameters['api'], '1');
    expect(uri.queryParameters['query'], 'Av. Juárez #45, Centro');
    // El # no debe cortar la URL como si fuera un fragmento.
    expect(uri.fragment, isEmpty);
  });

  testWidgets('al tocar la dirección abre Maps con esa dirección',
      (tester) async {
    Uri? opened;
    await tester.pumpWidget(_wrap(PickupAddress(
      address: 'Calle 5 de Mayo 10',
      openUrl: (uri) async {
        opened = uri;
        return true;
      },
    )));

    await tester.tap(find.text('Recoge en Calle 5 de Mayo 10'));
    await tester.pump();

    expect(opened?.queryParameters['query'], 'Calle 5 de Mayo 10');
    expect(find.text('No se pudo abrir Google Maps.'), findsNothing);
  });

  testWidgets('si Maps no abre, avisa al usuario', (tester) async {
    await tester.pumpWidget(_wrap(PickupAddress(
      address: 'Calle 5 de Mayo 10',
      openUrl: (_) async => false,
    )));

    await tester.tap(find.text('Recoge en Calle 5 de Mayo 10'));
    await tester.pump();

    expect(find.text('No se pudo abrir Google Maps.'), findsOneWidget);
  });

  testWidgets('sin dirección ni forma de pedirla no se puede tocar',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(_wrap(PickupAddress(
      address: '',
      openUrl: (_) async {
        taps++;
        return true;
      },
    )));
    await tester.pump();

    await tester.tap(find.text('Dirección no disponible'));
    expect(taps, 0);
  });

  test('con coordenadas, Maps abre el punto exacto y no busca el texto', () {
    final uri =
        mapsSearchUri('Limón 17', location: const GeoPoint(23.2494, -106.4111));

    expect(uri.queryParameters['query'], '23.2494,-106.4111');
  });

  testWidgets('al tocar usa la ubicación exacta si la hay', (tester) async {
    Uri? opened;
    await tester.pumpWidget(_wrap(PickupAddress(
      address: 'Limón 17, Col. Centro, Mazatlán',
      location: const GeoPoint(23.2494, -106.4111),
      openUrl: (uri) async {
        opened = uri;
        return true;
      },
    )));

    await tester.tap(find.textContaining('Limón 17'));
    await tester.pump();

    expect(opened?.queryParameters['query'], '23.2494,-106.4111');
  });
}
