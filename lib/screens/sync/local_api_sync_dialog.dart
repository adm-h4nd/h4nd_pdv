import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../data/services/sync/local_api_sync_service.dart';

class LocalApiSyncDialog extends StatefulWidget {
  final LocalApiSyncService syncService;
  final bool isIncremental;

  const LocalApiSyncDialog({
    super.key,
    required this.syncService,
    this.isIncremental = true,
  });

  @override
  State<LocalApiSyncDialog> createState() => _LocalApiSyncDialogState();
}

class _LocalApiSyncDialogState extends State<LocalApiSyncDialog> {
  bool _isSyncing = true;
  LocalApiSyncResult? _result;
  String _currentMessage = 'Iniciando sincronização...';

  @override
  void initState() {
    super.initState();
    _startSync();
  }

  Future<void> _startSync() async {
    try {
      setState(() {
        _isSyncing = true;
        _currentMessage = widget.isIncremental
            ? 'Sincronizando apenas alterações...'
            : 'Sincronizando todos os dados...';
      });

      final result = widget.isIncremental
          ? await widget.syncService.syncIncremental()
          : await widget.syncService.syncFull();

      if (mounted) {
        setState(() {
          _isSyncing = false;
          _result = result;
        });

        // Fechar dialog após um breve delay para mostrar o resultado
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.of(context).pop();
            _showResultSnackBar(result);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSyncing = false;
          _result = LocalApiSyncResult(
            success: false,
            error: e.toString(),
          );
        });

        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.of(context).pop();
            _showResultSnackBar(_result!);
          }
        });
      }
    }
  }

  void _showResultSnackBar(LocalApiSyncResult result) {
    if (!mounted) return;

    final message = result.success
        ? _buildSuccessMessage(result)
        : 'Erro: ${result.error ?? "Erro desconhecido"}';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              result.success ? Icons.check_circle : Icons.error,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message),
            ),
          ],
        ),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        backgroundColor: result.success
            ? AppTheme.successColor
            : AppTheme.errorColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  String _buildSuccessMessage(LocalApiSyncResult result) {
    final partes = <String>[];

    if (result.totalRecordsProcessed > 0) {
      partes.add('${result.totalRecordsProcessed} registro(s) processado(s)');
    }
    if (result.totalRecordsInserted > 0) {
      partes.add('${result.totalRecordsInserted} inserido(s)');
    }
    if (result.totalRecordsUpdated > 0) {
      partes.add('${result.totalRecordsUpdated} atualizado(s)');
    }

    if (result.duration != null) {
      final seconds = result.duration!.inSeconds;
      if (seconds > 0) {
        partes.add('em ${seconds}s');
      }
    }

    if (partes.isEmpty) {
      return 'Sincronização concluída';
    }

    return 'Sincronização concluída: ${partes.join(', ')}';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          if (_isSyncing)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (_result != null)
            Icon(
              _result!.success ? Icons.check_circle : Icons.error,
              color: _result!.success
                  ? AppTheme.successColor
                  : AppTheme.errorColor,
            )
          else
            const Icon(Icons.cloud_sync, color: AppTheme.primaryColor),
          const SizedBox(width: 12),
          Text(_isSyncing ? 'Sincronizando Servidor...' : 'Sincronização Concluída'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isSyncing) ...[
            Text(
              _currentMessage,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            const LinearProgressIndicator(
              backgroundColor: Colors.grey,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            ),
          ] else if (_result != null) ...[
            if (_result!.success) ...[
              if (_result!.totalTables > 0)
                Text(
                  'Tabelas: ${_result!.successfulTables}/${_result!.totalTables} sincronizadas',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              if (_result!.totalRecordsProcessed > 0) ...[
                const SizedBox(height: 8),
                Text(
                  'Registros: ${_result!.totalRecordsProcessed} processados',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ],
              if (_result!.duration != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Duração: ${_result!.duration!.inSeconds}s',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ],
            ] else ...[
              Text(
                'Erro: ${_result!.error ?? "Erro desconhecido"}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.errorColor,
                    ),
              ),
            ],
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSyncing
              ? null
              : () => Navigator.of(context).pop(),
          child: const Text('Fechar'),
        ),
      ],
    );
  }
}

