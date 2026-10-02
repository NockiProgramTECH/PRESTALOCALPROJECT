part of '../login_screen.dart';

class _LoginScreenState extends ConsumerState<LoginScreen> with _LoginScreenChamps, _LoginScreenHabillage, _LoginScreenActions {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _byPhone = true;

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _wordmark(canPop),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              child: Column(
                children: [
                  _heroCard(),
                  const SizedBox(height: 14),
                  _formCard(authState),
                  const SizedBox(height: 18),
                  _divider(),
                  const SizedBox(height: 14),
                  _socialRow(),
                  const SizedBox(height: 14),
                  _secureNote(),
                  const SizedBox(height: 22),
                  _footer(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }}
