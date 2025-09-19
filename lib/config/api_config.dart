class ApiConfig {
  static const String baseUrl = "http://10.0.2.2:8000/api";
  // emulator pakai 10.0.2.2, kalau device fisik ganti IP laptop
  static const Map<String, String> headers = {
    "Content-Type": "application/json",
    "Accept": "application/json",
  };
}