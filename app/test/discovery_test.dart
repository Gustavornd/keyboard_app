import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_deck_client/discovery_service.dart';

void main() {
  group('DiscoveredHost Model', () {
    test('instanciação e propriedades corretas', () {
      final host = DiscoveredHost(
        name: 'GUS-PC',
        ip: '192.168.1.50',
        port: 8080,
      );

      expect(host.name, equals('GUS-PC'));
      expect(host.ip, equals('192.168.1.50'));
      expect(host.port, equals(8080));
      expect(host.protocol, equals('streamdeck_v1'));
      expect(host.toString(), equals('GUS-PC (192.168.1.50:8080)'));
    });

    test('igualdade baseada em IP e porta', () {
      final host1 = DiscoveredHost(name: 'Host A', ip: '192.168.1.50', port: 8080);
      final host2 = DiscoveredHost(name: 'Host B', ip: '192.168.1.50', port: 8080);
      final host3 = DiscoveredHost(name: 'Host A', ip: '192.168.1.51', port: 8080);

      expect(host1, equals(host2));
      expect(host1.hashCode, equals(host2.hashCode));
      expect(host1, isNot(equals(host3)));
    });
  });

  group('DiscoveryService Integration with Mock Server', () {
    test('localiza servidor simulado via UDP loopback', () async {
      // Cria socket de teste simulando o servidor Python respondendo na porta loopback
      final mockServer = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
      final mockPort = mockServer.port;

      mockServer.listen((event) {
        if (event == RawSocketEvent.read) {
          final dg = mockServer.receive();
          if (dg != null) {
            final request = jsonDecode(utf8.decode(dg.data)) as Map<String, dynamic>;
            if (request['type'] == 'discover') {
              final ack = utf8.encode(jsonEncode({
                'type': 'discover_ack',
                'server_name': 'Mock-PC',
                'ip': '127.0.0.1',
                'port': mockPort,
                'protocol': 'streamdeck_v1',
              }));
              mockServer.send(ack, dg.address, dg.port);
            }
          }
        }
      });

      final service = DiscoveryService(targetPort: mockPort);
      final hosts = await service.searchHosts(timeout: const Duration(milliseconds: 600));

      expect(hosts, isNotEmpty);
      expect(hosts.any((h) => h.name == 'Mock-PC' && h.port == mockPort), isTrue);

      mockServer.close();
    });
  });
}
