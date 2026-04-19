/// Basit nesne havuzu — sık oluşturma/çöp toplama baskısını azaltır.
class ObjectPool<T> {
  ObjectPool(this._create);

  final T Function() _create;
  final List<T> _free = <T>[];

  int get capacity => _free.length;

  T acquire() {
    if (_free.isEmpty) {
      return _create();
    }
    return _free.removeLast();
  }

  void release(T object) {
    _free.add(object);
  }

  void releaseAll(Iterable<T> objects) {
    for (final T o in objects) {
      _free.add(o);
    }
  }
}
