/// Informações de paginação
class PaginationInfoDto {
  final int page;
  final int pageSize;
  final int totalItems;
  final int totalPages;
  final bool hasNext;
  final bool hasPrevious;

  PaginationInfoDto({
    required this.page,
    required this.pageSize,
    required this.totalItems,
    required this.totalPages,
    required this.hasNext,
    required this.hasPrevious,
  });

  factory PaginationInfoDto.fromJson(Map<String, dynamic> json) {
    return PaginationInfoDto(
      page: json['page'] ?? 1,
      pageSize: json['pageSize'] ?? 20,
      totalItems: json['totalItems'] ?? 0,
      totalPages: json['totalPages'] ?? 0,
      hasNext: json['hasNext'] ?? false,
      hasPrevious: json['hasPrevious'] ?? false,
    );
  }
}

/// Resposta paginada
class PaginatedResponseDto<T> {
  final List<T> list;
  final PaginationInfoDto pagination;

  PaginatedResponseDto({
    required this.list,
    required this.pagination,
  });

  factory PaginatedResponseDto.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJsonT,
  ) {
    return PaginatedResponseDto<T>(
      list: (json['list'] as List<dynamic>?)
              ?.map((item) => fromJsonT(item as Map<String, dynamic>))
              .toList() ??
          [],
      pagination: PaginationInfoDto.fromJson(
        json['pagination'] as Map<String, dynamic>,
      ),
    );
  }
}


