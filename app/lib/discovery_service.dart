import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Representa um computador Host descoberto na rede local
class DiscoveredHost {
  final String name;
  final String ip;
  final int port;
  final String protocol;
  final DateTime discoveredAt;

  DiscoveredHost({
    required this.name,
    required this.ip,
    required this.port,
    this.protocol = 'streamdeck_v1',
    DateTime? discoveredAt,
  }) : discoveredAt = discoveredAt ?? DateTime.now();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiscoveredHost &&
          runtimeType == other.runtimeType &&
          ip == other.ip &&
          port == other.port;

  @override
  int get hashCode => ip.hashCode ^ port.hashCode;

  @override
  String toString() => '$name ($ip:$port)';
}

/// Serviço responsável pela detecção automática de servidores na rede via UDP Broadcast
class DiscoveryService {
  final int targetPort;

  DiscoveryService({this.targetPort = 8080});

  /// Realiza uma varredura na rede local enviando pacotes broadcast
  /// e aguardando confirmações de servidores compatíveis.
  Future<List<DiscoveredHost>> searchHosts({
    Duration timeout = const Duration(milliseconds: 1500),
  }) async {
    final List<DiscoveredHost> hosts = [];
    RawDatagramSocket? socket;

    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;

      final subscription = socket.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final datagram = socket?.receive();
          if (datagram != null) {
            try {
              final text = utf8.decode(datagram.data);
              final json = jsonDecode(text) as Map<String, dynamic>;
              if (json['type'] == 'discover_ack') {
                final reportedIp = json['ip'] as String?;
                final senderIp = datagram.address.address;
                final resolvedIp = (senderIp != '127.0.0.1' && senderIp.isNotEmpty)
                    ? senderIp
                    : (reportedIp ?? senderIp);

                final host = DiscoveredHost(
                  name: json['server_name'] as String? ?? 'PC Host',
                  ip: resolvedIp,
                  port: json['port'] as int? ?? targetPort,
                  protocol: json['protocol'] as String? ?? 'streamdeck_v1',
                );

                if (!hosts.contains(host)) {
                  hosts.add(host);
                }
              }
            } catch (e) {
              // Ignora pacotes de outras aplicações na rede
            }
          }
        }
      });

      final payload = utf8.encode(jsonEncode({
        'type': 'discover',
        'client': 'StreamDeckApp',
        'version': 1,
      }));

      // 1. Broadcast universal (255.255.255.255)
      try {
        socket.send(payload, InternetAddress('255.255.255.255'), targetPort);
      } catch (_) {}

      // 2. Loopback (para testes locais, desktop ou emuladores)
      try {
        socket.send(payload, InternetAddress.loopbackIPv4, targetPort);
      } catch (_) {}

      // 3. Subnet Broadcast para cada interface de rede ativa
      try {
        final interfaces = await NetworkInterface.list(
          type: InternetAddressType.IPv4,
          includeLoopback: false,
        );
        for (final iface in interfaces) {
          for (final addr in iface.addresses) {
            final parts = addr.address.split('.');
            if (parts.length == 4) {
              final broadcastIp = '${parts[0]}.${parts[1]}.${parts[2]}.255';
              try {
                socket.send(payload, InternetAddress(broadcastIp), targetPort);
              } catch (_) {}
            }
          }
        }
      } catch (_) {}

      await Future.delayed(timeout);
      await subscription.cancel();
    } catch (e) {
      debugPrint('Erro na descoberta de hosts: $e');
    } finally {
      socket?.close();
    }

    return hosts;
  }
}

