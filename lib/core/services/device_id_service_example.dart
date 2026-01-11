/// Exemplo de uso do DeviceIdService
/// 
/// Este arquivo demonstra como usar o DeviceIdService para obter
/// um identificador único do dispositivo no sistema PDV.
/// 
/// O DeviceIdService funciona em Windows, Android e iOS:
/// - Android: Usa Android ID (Settings.Secure.ANDROID_ID)
/// - iOS: Usa Identifier for Vendor (IDFV)
/// - Windows: Gera um UUID e armazena permanentemente
/// 
/// Exemplo de uso:
/// 
/// ```dart
/// import 'package:mx_cloud_pdv/core/services/device_id_service.dart';
/// 
/// // Obter o ID único do dispositivo
/// final deviceId = await DeviceIdService.getDeviceId();
/// print('Device ID: $deviceId');
/// 
/// // O ID é cacheado após a primeira obtenção
/// // Chamadas subsequentes retornam o mesmo ID sem fazer I/O
/// final sameDeviceId = await DeviceIdService.getDeviceId();
/// print('Same ID: ${deviceId == sameDeviceId}'); // true
/// 
/// // Usar em requisições HTTP (exemplo)
/// final headers = {
///   'X-Device-Id': deviceId,
///   'Content-Type': 'application/json',
/// };
/// 
/// // Usar no registro do PDV no backend
/// final pdvData = {
///   'nome': 'PDV Loja 1',
///   'deviceId': deviceId,
///   'tipo': 'mobile',
/// };
/// ```
/// 
/// IMPORTANTE:
/// - O ID é único por instalação do app
/// - Em Android, o Android ID pode mudar após reset de fábrica
/// - Em iOS, o IDFV pode mudar se todos os apps do vendor forem desinstalados
/// - Em Windows, o UUID gerado é persistente e não muda
/// - O ID é armazenado localmente e não é compartilhado entre apps

