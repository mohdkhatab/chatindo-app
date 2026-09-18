import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/api.dart';
import 'core/realtime_service.dart';
import 'core/session_controller.dart';
import 'screens/auth/login_screen.dart';
import 'screens/chats/create_group_screen.dart';
import 'screens/chats/new_chat_screen.dart';
import 'screens/home/home_shell.dart';
import 'screens/legal/legal_screen.dart';
import 'screens/premium/premium_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final session = SessionController();
  final realtime = RealtimeService();
  runApp(ChatindoApp(session: session, realtime: realtime));
}

class ChatindoApp extends StatelessWidget {
  const ChatindoApp({super.key, required this.session, required this.realtime});

  final SessionController session;
  final RealtimeService realtime;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: session),
        Provider<RealtimeService>.value(value: realtime),
        Provider<ChatindoApi>.value(value: ChatindoApi(session)),
      ],
      child: MaterialApp(
        title: 'Chatindo',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const SplashScreen(),
        routes: {
          SplashScreen.route: (_) => const SplashScreen(),
          LoginScreen.route: (_) => const LoginScreen(),
          HomeShell.route: (_) => const HomeShell(),
          NewChatScreen.route: (_) => const NewChatScreen(),
          CreateGroupScreen.route: (_) => const CreateGroupScreen(),
          SettingsScreen.route: (_) => const SettingsScreen(),
          PremiumScreen.route: (_) => const PremiumScreen(),
          LegalScreen.route: (_) => const LegalScreen(),
        },
      ),
    );
  }
}