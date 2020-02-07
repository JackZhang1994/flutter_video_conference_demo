import 'package:uuid/uuid.dart';

class UuidUtils {
  static String getUuid() {
    var uuid = new Uuid();
    return uuid.v1();
  }
}
