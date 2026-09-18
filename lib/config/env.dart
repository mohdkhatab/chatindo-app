/// App-wide configuration.
///
/// These are PUBLIC values that are safe to ship in a client app.
/// The anon key only enables RLS-guarded reads and the edge-function
/// endpoints we deployed. Never put a secret (service_role key) here.
class AppConfig {
  AppConfig._();

  static const String projectRef = 'exkopjtstlpchkdruaja';

  static const String supabaseUrl = 'https://$projectRef.supabase.co';

  /// Edge-function base (our deployed API).
  static const String functionBase = '$supabaseUrl/functions/v1';

  /// Realtime websocket base.
  static const String realtimeUrl = '$supabaseUrl/realtime/v1';

  /// Public anon key (embedded in every Supabase client app).
  static const String anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImV4a29wanRzdGxwY2hrZHJ1YWphIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODk2NDQ0NzEsImV4cCI6MjEwNTIyMDQ3MX0.lGSjTzvhrETtz3eMFGemYcb1iY3qVWTggsUWLgvwKlE';
}