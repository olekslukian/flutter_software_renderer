extension type const Color32._(int _abgr) {
  const Color32.fromARGB(int alpha, int red, int green, int blue)
    : this._((alpha << 24) | (blue << 16) | (green << 8) | red);

  const Color32.fromARGB32(int argb)
    : this.fromARGB(
        (argb >> 24) & 0xFF,
        (argb >> 16) & 0xFF,
        (argb >> 8) & 0xFF,
        argb & 0xFF,
      );

  int get alpha => _abgr >>> 24;

  int get red => _abgr & 0xFF;

  int get green => (_abgr >> 8) & 0xFF;

  int get blue => (_abgr >> 16) & 0xFF;

  int get abgr => _abgr;

  int toARGB32() => (alpha << 24) | (red << 16) | (green << 8) | blue;
}
