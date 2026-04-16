import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/services/online_payment_service.dart';
import 'receipt_page.dart';

class PaymentMethodPage extends StatefulWidget {
  const PaymentMethodPage({super.key});

  @override
  State<PaymentMethodPage> createState() => _PaymentMethodPageState();
}

enum _PaymentMethodType { card, applePay, googlePay }

class _PaymentMethodPageState extends State<PaymentMethodPage> {
  final OnlinePaymentService _onlinePaymentService = OnlinePaymentService();
  final TextEditingController _cardNumberController = TextEditingController();
  final TextEditingController _expiryController = TextEditingController();
  final TextEditingController _cvcController = TextEditingController();
  final TextEditingController _holderNameController = TextEditingController();

  bool _isLoadingCards = true;
  bool _isLoadingDraft = true;
  bool _isSavingCard = false;
  bool _isAddCardOpen = false;

  OnlineCheckoutDraft? _checkoutDraft;
  List<StoredPaymentCard> _savedCards = const [];
  String? _selectedCardId;
  _PaymentMethodType _selectedMethod = _PaymentMethodType.card;

  @override
  void initState() {
    super.initState();
    _loadSavedCards();
    _loadDraft();
  }

  @override
  void dispose() {
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvcController.dispose();
    _holderNameController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedCards() async {
    setState(() {
      _isLoadingCards = true;
    });

    try {
      final cards = await _onlinePaymentService.getSavedCardsForCurrentUser();
      if (!mounted) {
        return;
      }

      setState(() {
        _savedCards = cards;
        _selectedCardId = cards.isNotEmpty ? cards.first.id : null;
        _isAddCardOpen = cards.isEmpty;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to load saved cards right now.'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingCards = false;
        });
      }
    }
  }

  Future<void> _loadDraft() async {
    try {
      final draft = await _onlinePaymentService.getCheckoutDraft();
      if (!mounted) {
        return;
      }

      setState(() {
        _checkoutDraft = draft;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingDraft = false;
        });
      }
    }
  }

  bool _isCardFormValid() {
    final cardDigits = _cardNumberController.text.replaceAll(RegExp(r'\D'), '');
    final expiry = _expiryController.text.trim();
    final cvc = _cvcController.text.trim();
    final holder = _holderNameController.text.trim();

    final expiryParts = expiry.split('/');
    final month = expiryParts.isNotEmpty
        ? int.tryParse(expiryParts.first.trim())
        : null;
    final year = expiryParts.length == 2
        ? int.tryParse(expiryParts.last.trim())
        : null;
    final expiryValid =
        expiryParts.length == 2 &&
        month != null &&
        year != null &&
        month >= 1 &&
        month <= 12 &&
        expiryParts.last.trim().length == 2;

    return cardDigits.length >= 12 &&
        expiryValid &&
        (cvc.length == 3 || cvc.length == 4) &&
        holder.isNotEmpty;
  }

  bool _canPayNow() {
    if (_isLoadingDraft || _checkoutDraft == null) {
      return false;
    }

    if (_selectedMethod != _PaymentMethodType.card) {
      return true;
    }

    if (_savedCards.isEmpty || _isAddCardOpen) {
      return _isCardFormValid();
    }

    return _selectedCardId != null && _selectedCardId!.isNotEmpty;
  }

  Future<void> _handlePayNow() async {
    if (!_canPayNow() || _isSavingCard) {
      return;
    }

    StoredPaymentCard? cardUsed;

    if (_selectedMethod == _PaymentMethodType.card &&
        (_savedCards.isEmpty || _isAddCardOpen)) {
      setState(() {
        _isSavingCard = true;
      });

      try {
        final card = await _onlinePaymentService.addCardForCurrentUser(
          cardNumber: _cardNumberController.text,
          expiryLabel: _expiryController.text,
          cvc: _cvcController.text,
          cardHolderName: _holderNameController.text,
        );

        if (!mounted) {
          return;
        }

        setState(() {
          _savedCards = [card, ..._savedCards];
          _selectedCardId = card.id;
          _isAddCardOpen = false;
          _cardNumberController.clear();
          _expiryController.clear();
          _cvcController.clear();
          _holderNameController.clear();
        });
        cardUsed = card;
      } on FirebaseException catch (e) {
        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.code == 'not-authenticated'
                  ? 'Please login first to save card details.'
                  : 'Unable to save card (${e.code}).',
            ),
            backgroundColor: AppColors.errorRed,
          ),
        );
        return;
      } catch (_) {
        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to save card right now.'),
            backgroundColor: AppColors.errorRed,
          ),
        );
        return;
      } finally {
        if (mounted) {
          setState(() {
            _isSavingCard = false;
          });
        }
      }
    }

    if (_selectedMethod == _PaymentMethodType.card && cardUsed == null) {
      final selected = _savedCards.where((card) => card.id == _selectedCardId);
      if (selected.isNotEmpty) {
        cardUsed = selected.first;
      }
    }

    final draft = _checkoutDraft;
    if (draft == null) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Booking summary is missing. Please go back and retry.',
          ),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }

    setState(() {
      _isSavingCard = true;
    });

    try {
      final receipt = await _onlinePaymentService.processDemoStripePayment(
        draft: draft,
        paymentMethodType: _mapMethod(_selectedMethod),
        selectedCard: cardUsed,
      );

      if (!mounted) {
        return;
      }

      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => ReceiptPage(receipt: receipt)),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Demo payment failed: $e'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSavingCard = false;
        });
      }
    }
  }

  OnlinePaymentMethodType _mapMethod(_PaymentMethodType type) {
    switch (type) {
      case _PaymentMethodType.card:
        return OnlinePaymentMethodType.card;
      case _PaymentMethodType.applePay:
        return OnlinePaymentMethodType.applePay;
      case _PaymentMethodType.googlePay:
        return OnlinePaymentMethodType.googlePay;
    }
  }

  Widget _methodRadio({required bool selected}) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? const Color(0xFF2F57F0) : const Color(0xFF8F8F8F),
          width: 1.7,
        ),
      ),
      child: Center(
        child: Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? const Color(0xFF2F57F0) : Colors.transparent,
          ),
        ),
      ),
    );
  }

  Widget _paymentOptionTile({
    required String title,
    required _PaymentMethodType value,
    Widget? trailing,
    String? subtitle,
  }) {
    final selected = _selectedMethod == value;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedMethod = value;
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Row(
          children: [
            _methodRadio(selected: selected),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.dark1,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.gray1,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            trailing ?? const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }

  Widget _savedCardRow(StoredPaymentCard card) {
    final selected = _selectedCardId == card.id;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedMethod = _PaymentMethodType.card;
          _selectedCardId = card.id;
          _isAddCardOpen = false;
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: card.brand.toLowerCase().contains('visa')
                    ? const Color(0xFF1A4DDE)
                    : const Color(0xFFF1F1F1),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                card.brand.toLowerCase().contains('visa') ? 'VISA' : 'CARD',
                style: TextStyle(
                  color: card.brand.toLowerCase().contains('visa')
                      ? Colors.white
                      : AppColors.dark1,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '.... ${card.last4}',
              style: const TextStyle(
                color: AppColors.dark1,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            _methodRadio(selected: selected),
          ],
        ),
      ),
    );
  }

  Widget _cardInputField({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: (_) {
        if (mounted) {
          setState(() {});
        }
      },
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          color: Color(0xFF9A9A9A),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        filled: true,
        fillColor: const Color(0xFFF1F1F1),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderSide: BorderSide.none,
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }

  Widget _buildCardSection() {
    final selected = _selectedMethod == _PaymentMethodType.card;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          _paymentOptionTile(
            title: 'Credit/ Debit Card',
            value: _PaymentMethodType.card,
          ),
          if (_isLoadingCards)
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 2, 12, 14),
              child: LinearProgressIndicator(minHeight: 2),
            )
          else ...[
            if (_savedCards.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                child: Column(
                  children: [
                    for (final card in _savedCards) _savedCardRow(card),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _selectedMethod = _PaymentMethodType.card;
                          _isAddCardOpen = true;
                          _selectedCardId = null;
                        });
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.add, size: 16, color: Color(0xFF2F57F0)),
                            SizedBox(width: 8),
                            Text(
                              'Add Card',
                              style: TextStyle(
                                color: Color(0xFF2F57F0),
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (_savedCards.isEmpty || _isAddCardOpen)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Column(
                  children: [
                    _cardInputField(
                      controller: _cardNumberController,
                      hint: 'Card Number',
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _cardInputField(
                            controller: _expiryController,
                            hint: 'MM/YY',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _cardInputField(
                            controller: _cvcController,
                            hint: 'CVC',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _cardInputField(
                      controller: _holderNameController,
                      hint: 'Card Holder Name',
                    ),
                    if (_savedCards.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () {
                            setState(() {
                              _isAddCardOpen = false;
                              _cardNumberController.clear();
                              _expiryController.clear();
                              _cvcController.clear();
                              _holderNameController.clear();
                            });
                          },
                          child: const Text('Cancel adding card'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
          if (!selected) const SizedBox(height: 2),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canPayNow = _canPayNow();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F4),
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(8, 84, 8, 84),
              child: Column(
                children: [
                  _buildCardSection(),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _paymentOptionTile(
                      title: 'Apple Pay',
                      value: _PaymentMethodType.applePay,
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: const Text(
                          'APay',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _paymentOptionTile(
                      title: 'Google Pay',
                      value: _PaymentMethodType.googlePay,
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: const Color(0xFFD9D9D9)),
                        ),
                        child: const Text(
                          'G Pay',
                          style: TextStyle(
                            color: AppColors.dark1,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 0,
              left: 8,
              right: 8,
              child: SafeArea(
                bottom: false,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      height: 56,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.78),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Expanded(
                            child: Text(
                              'Select payment method',
                              style: TextStyle(
                                color: AppColors.dark1,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: canPayNow && !_isSavingCard
                        ? _handlePayNow
                        : null,
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: const Color(0xFF2F57F0),
                      disabledBackgroundColor: const Color(0xFFC8C8C8),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isSavingCard
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Pay Now',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
