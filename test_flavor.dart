void main() {
  String normalize(String flavor) {
    return flavor.replaceAllMapped(
      RegExp(r'([a-z])([A-Z])'),
      (match) => '${match.group(1)}_${match.group(2)!.toLowerCase()}',
    ).toLowerCase();
  }
  
  print('stoneP2 -> ${normalize("stoneP2")}');
  print('mobile -> ${normalize("mobile")}');
  print('stoneP2 deve ser: stone_p2');
  print('mobile deve ser: mobile');
}

