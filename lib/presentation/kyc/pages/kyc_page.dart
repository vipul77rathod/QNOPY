import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../data/kyc/models/kyc_session_model.dart';
import '../state/kyc_controller.dart';

class KycPage extends StatefulWidget {
  const KycPage({super.key});
  @override
  State<KycPage> createState() => _KycPageState();
}

class _KycPageState extends State<KycPage> {
  final _formKey = GlobalKey<FormState>();
  late final KycController c;

  @override
  void initState() {
    super.initState();
    c = Get.find<KycController>();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: const Text('Identity verification'),
        ),
        body: SafeArea(child: Obx(() {
          final current = c.session.value;
          return RefreshIndicator(
            onRefresh: () async {
              c.refreshSession();
            },
            child: Column(
                children: [

              if (c.isBusy.value) const LinearProgressIndicator(),
              Expanded(child: ListView(padding: const EdgeInsets.all(20), children: [
                Text('Verify your identity', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                const Text('Complete document verification and a simulated face check.'),
                const SizedBox(height: 18),
                _Steps(session: current),
                const SizedBox(height: 18),
                if (c.errorMessage.value.isNotEmpty) _ErrorCard(message: c.errorMessage.value),
                if (current == null)
                  Center(child: Padding(padding: const EdgeInsets.all(24), child: FilledButton(onPressed: c.isBusy.value ? null : c.loadOrCreateSession, child: const Text('Retry loading session'))))
                else
                  _stateBody(context, current),
                const SizedBox(height: 20),
              ])),
            ]),
          );
        })),
      );

  Widget _stateBody(BuildContext context, KycSessionModel s) {
    if (s.isVerified) return _StatusCard(icon: Icons.verified_user, title: 'KYC verified', message: 'Your identity verification is complete\nDocument: ${c.session.value?.docType} - ${c.session.value?.docNumberMasked}.', color: Colors.green,);
    if (s.isManualReview) return const _StatusCard(icon: Icons.hourglass_top, title: 'Manual review in progress', message: 'Your submission needs additional review. The status refreshes automatically.', color: Colors.orange);
    if (s.isBlocked) return _StatusCard(icon: Icons.block, title: 'Session blocked', message: s.reason ?? 'Too many failed liveness attempts. Start a new session.', color: Colors.red, child: FilledButton(onPressed: c.isBusy.value ? null : c.startNewSession, child: const Text('Start a new KYC session')));
    if (s.isLivenessFailed) return _StatusCard(icon: Icons.warning_amber, title: 'Face check failed', message: 'You have ${s.retriesLeft} attempt(s) left.', color: Colors.orange, child: _livenessForm(s));
    if (s.needsDocument) return _documentForm();
    if (s.needsLiveness) return _livenessForm(s);
    return _StatusCard(icon: Icons.info_outline, title: 'Status: ${s.status}', message: 'Current step: ${s.step}. Refresh for the latest status.', color: Colors.blue);
  }

  Widget _documentForm() => Card(child: Padding(padding: const EdgeInsets.all(18), child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('The document number is sent for this request only. It is not saved on this device.'),
    const SizedBox(height: 16),
    Obx(() => DropdownButtonFormField<String>(
      value: c.selectedDocType.value, decoration: const InputDecoration(labelText: 'Document type'),
      items: const [DropdownMenuItem(value: 'pan', child: Text('PAN')), DropdownMenuItem(value: 'aadhaar', child: Text('Aadhaar')), DropdownMenuItem(value: 'passport', child: Text('Passport'))],
      onChanged: c.isBusy.value ? null : c.setDocType,
    )),
    const SizedBox(height: 14),
    TextFormField(
      key: const ValueKey('document-number'),
      textCapitalization: TextCapitalization.characters,
      autocorrect: false,
      obscureText: c.isVisible.value,
      keyboardType: c.selectedDocType.value == 'aadhaar' ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
          suffixIcon: Obx((){
            return IconButton(
              onPressed: (){
                c.isVisible.value = !c.isVisible.value;
              },
              icon: c.isVisible.value ? Icon(Icons.lock_open) : Icon(Icons.lock),
            );
          }),
          labelText: 'Document number', hintText: 'Enter document number'),
      onChanged: c.setDocNumber,
      validator: (value) => c.validateDocument(c.selectedDocType.value, value ?? ''),

    ),
    const SizedBox(height: 18),
    Obx(() => FilledButton(onPressed: c.isBusy.value ? null : () { if (_formKey.currentState?.validate() ?? false) c.submitDocument(); }, child: const Text('Submit'))),
  ]))));

  Widget _livenessForm(KycSessionModel s) => Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('This simulates liveness and does not open the camera. Score < 0.5 fails; 0.5–0.79 can require review; >= 0.8 verifies.'),
    const SizedBox(height: 16),
    Obx(() { final score = c.livenessScore.value; return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Simulated liveness score: ${score.toStringAsFixed(2)}'),
      Slider(value: score, min: 0, max: 1, divisions: 20, label: score.toStringAsFixed(2), onChanged: c.isBusy.value ? null : (v) => c.livenessScore.value = v),

    ]); }),
    const SizedBox(height: 12),
    Obx(() => FilledButton(onPressed: c.isBusy.value ? null : c.submitLiveness, child: const Text('Submit'))),
    const SizedBox(height: 8), Text('Attempts remaining: ${s.retriesLeft}'),
  ])));
}

class _Steps extends StatelessWidget {
  const _Steps({required this.session});
  final KycSessionModel? session;
  @override
  Widget build(BuildContext context) {
    final s = session;
    final documentDone = s != null && !(s.step == 'document' && s.status == 'created');
    final faceDone = s != null && (s.isVerified || s.isManualReview);
    return Card(child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [
      _StepDot(number: '1', label: 'Document', done: documentDone), const Expanded(child: Divider(indent: 8, endIndent: 8)), _StepDot(number: '2', label: 'Face check', done: faceDone),
    ])));
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({required this.number, required this.label, required this.done});
  final String number; final String label; final bool done;
  @override
  Widget build(BuildContext context) => Column(children: [
    CircleAvatar(radius: 18, backgroundColor: done ? Colors.green : Theme.of(context).colorScheme.primary, child: done ? const Icon(Icons.check, color: Colors.white) : Text(number, style: const TextStyle(color: Colors.white))),
    const SizedBox(height: 6), Text(label),
  ]);
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message}); final String message;
  @override
  Widget build(BuildContext context) =>
      Card(color: Theme.of(context).colorScheme.errorContainer, child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [const Icon(Icons.error_outline), const SizedBox(width: 10), Expanded(child: Text(message))])));
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.icon, required this.title, required this.message, required this.color, this.child});
  final IconData icon; final String title; final String message; final Color color; final Widget? child;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Icon(icon, color: color, size: 34), const SizedBox(height: 12), Text(title, style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 8), Text(message), if (child != null) ...[const SizedBox(height: 14), child!],
  ])));
}
