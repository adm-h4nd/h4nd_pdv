import 'package:flutter/material.dart';

/// Modelo para preferências do usuário
class UserPreferences {
  /// Tamanho de visualização das mesas
  final MesaViewSize mesaViewSize;

  UserPreferences({
    this.mesaViewSize = MesaViewSize.medio,
  });

  /// Cria preferências padrão
  factory UserPreferences.defaults() {
    return UserPreferences(
      mesaViewSize: MesaViewSize.medio,
    );
  }

  /// Converte para Map para salvar
  Map<String, dynamic> toJson() {
    return {
      'mesaViewSize': mesaViewSize.name,
    };
  }

  /// Cria a partir de Map
  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    return UserPreferences(
      mesaViewSize: MesaViewSize.values.firstWhere(
        (e) => e.name == json['mesaViewSize'],
        orElse: () => MesaViewSize.medio,
      ),
    );
  }

  /// Cria uma cópia com valores atualizados
  UserPreferences copyWith({
    MesaViewSize? mesaViewSize,
  }) {
    return UserPreferences(
      mesaViewSize: mesaViewSize ?? this.mesaViewSize,
    );
  }
}

/// Tamanhos de visualização das mesas
enum MesaViewSize {
  pequeno,
  medio,
  grande;

  String get label {
    switch (this) {
      case MesaViewSize.pequeno:
        return 'Pequeno';
      case MesaViewSize.medio:
        return 'Médio';
      case MesaViewSize.grande:
        return 'Grande';
    }
  }

  /// Ícone para o seletor
  IconData get icon {
    switch (this) {
      case MesaViewSize.pequeno:
        return Icons.grid_view;
      case MesaViewSize.medio:
        return Icons.view_module;
      case MesaViewSize.grande:
        return Icons.view_quilt;
    }
  }
}

