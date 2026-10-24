import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import '../../../core/service/screenshot_protection.dart';
import '../../../data/kyc/models/kyc_session_model.dart';
import '../../../data/kyc/repositories/kyc_repository.dart';
import 'kyc_document_validator.dart';

class KycController extends GetxController {
  KycController({required KycRepository repository}) : _repository = repository;
  final KycRepository _repository;

  final Rxn<KycSessionModel> session = Rxn<KycSessionModel>();
  final RxBool isBusy = false.obs;
  final RxBool isVisible = true.obs;
  final RxString errorMessage = ''.obs;
  final RxString selectedDocType = 'pan'.obs;
  final RxString docNumber = ''.obs;
  final RxDouble livenessScore = 0.9.obs;
  Timer? _reviewTimer;
  bool _pollInFlight = false;

  @override
  void onInit() {
    super.onInit();
    loadOrCreateSession();
    ScreenshotProtection.disable();
  }

  @override
  void onClose() {
    _reviewTimer?.cancel();
    ScreenshotProtection.enable();
    super.onClose();
  }

  Future<void> loadOrCreateSession() async {
    isBusy.value = true;
    errorMessage.value = '';
    try {
      session.value = await _repository.createOrResumeSession();
      _manageReviewPolling();
    } catch (e) {
      errorMessage.value = _friendlyError(e);
    } finally {
      isBusy.value = false;
    }
  }

  Future<void> refreshSession() async {
    final current = session.value;
    if (current == null) return loadOrCreateSession();
    isBusy.value = true;
    errorMessage.value = '';
    try {
      session.value = await _repository.getSession(current.sessionId);
      _manageReviewPolling();
    } catch (e) {
      errorMessage.value = _friendlyError(e);
    } finally {
      isBusy.value = false;
    }
  }

  void setDocType(String? value) { if (value != null) selectedDocType.value = value; }
  void setDocNumber(String value) { docNumber.value = value.trim().toUpperCase(); }
  String? validateDocument(String type, String value) => validateKycDocument(type, value);

  Future<void> submitDocument() async {
    final current = session.value;
    if (current == null) { errorMessage.value = 'Create or resume a KYC session first.'; return; }
    final number = docNumber.value.trim().toUpperCase();
    final validation = validateKycDocument(selectedDocType.value, number);
    if (validation != null) { errorMessage.value = validation; return; }
    isBusy.value = true;
    errorMessage.value = '';
    try {
      session.value = await _repository.submitDocument(sessionId: current.sessionId, docType: selectedDocType.value, docNumber: number);
      docNumber.value = '';
      _manageReviewPolling();
    } catch (e) {
      errorMessage.value = _friendlyError(e);
    } finally {
      isBusy.value = false;
    }
  }

  Future<void> submitLiveness() async {
    final current = session.value;
    if (current == null) { errorMessage.value = 'Create or resume a KYC session first.'; return; }
    isBusy.value = true;
    errorMessage.value = '';
    try {
      session.value = await _repository.submitLiveness(sessionId: current.sessionId, score: livenessScore.value.clamp(0.0, 1.0).toDouble());
      _manageReviewPolling();
    } catch (e) {
      errorMessage.value = _friendlyError(e);
      if (e is DioException && (e.response?.statusCode == 409 || e.response?.statusCode == 423)) refreshSession();
    } finally {
      isBusy.value = false;
    }
  }

  Future<void> startNewSession() async {
    _reviewTimer?.cancel();
    isBusy.value = true;
    try {
      await _repository.startNewSession();
      session.value = null;
      docNumber.value = '';
      await loadOrCreateSession();
    } catch (e) {
      errorMessage.value = _friendlyError(e);
    } finally {
      isBusy.value = false;
    }
  }

  void _manageReviewPolling() {
    _reviewTimer?.cancel();
    if (session.value?.isManualReview != true) return;
    _reviewTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (_pollInFlight) return;
      final current = session.value;
      if (current == null || !current.isManualReview) { _reviewTimer?.cancel(); return; }
      _pollInFlight = true;
      try {
        session.value = await _repository.getSession(current.sessionId);
        if (session.value?.isManualReview != true) _reviewTimer?.cancel();
      } catch (_) {
        debugPrint("Keep review state visible and retry on the next tick");
      } finally {
        _pollInFlight = false;
      }
    });
  }

  String _friendlyError(Object error) {
    if (error is DioException) {
      final code = error.response?.statusCode;
      final data = error.response?.data;
      final serverCode = data is Map ? data['error']?.toString() : null;
      if (code == 422 && serverCode == 'invalid_document_number') return 'The server rejected that document number. Check it and try again.';
      if (code == 423 || serverCode == 'session_blocked') return 'This session is blocked after too many failed attempts. Start a new session.';
      if (code == 503) return 'The service is temporarily unavailable. Please retry.';
      if (code == 404) return 'The session was not found on the server. Refresh or start a new session.';
      if (error.type == DioExceptionType.connectionTimeout || error.type == DioExceptionType.receiveTimeout || error.type == DioExceptionType.connectionError) return 'Network issue or timeout. Your session is retained; retry safely.';
      return 'Could not complete the request. Please retry.';
    }
    if (error is FormatException) return error.message;
    return 'Something went wrong. Please retry.';
  }
}
