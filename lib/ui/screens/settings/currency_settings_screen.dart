import 'package:flutter/material.dart';
import '../../../services/invoice/invoice_settings_service.dart';
import '../../../services/currency/currency_service.dart';

class CurrencySettingsScreen extends StatefulWidget {
  const CurrencySettingsScreen({super.key});

  @override
  State<CurrencySettingsScreen> createState() => _CurrencySettingsScreenState();
}

class _CurrencySettingsScreenState extends State<CurrencySettingsScreen> {
  final InvoiceSettingsService _invoiceSettingsService = InvoiceSettingsService();
  final CurrencyService _currencyService = CurrencyService();

  bool _isLoading = true;
  String _currentCurrencyCode = 'BDT';
  String _currentCurrencySymbol = '৳';

  // Common currencies
  final List<Map<String, String>> _currencies = [
    {'code': 'BDT', 'symbol': '৳', 'name': 'Bangladeshi Taka'},
    {'code': 'USD', 'symbol': '\$', 'name': 'US Dollar'},
    {'code': 'EUR', 'symbol': '€', 'name': 'Euro'},
    {'code': 'GBP', 'symbol': '£', 'name': 'British Pound'},
    {'code': 'INR', 'symbol': '₹', 'name': 'Indian Rupee'},
    {'code': 'JPY', 'symbol': '¥', 'name': 'Japanese Yen'},
    {'code': 'CNY', 'symbol': '¥', 'name': 'Chinese Yuan'},
    {'code': 'AUD', 'symbol': 'A\$', 'name': 'Australian Dollar'},
    {'code': 'CAD', 'symbol': 'C\$', 'name': 'Canadian Dollar'},
    {'code': 'CHF', 'symbol': 'CHF', 'name': 'Swiss Franc'},
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentCurrency();
  }

  Future<void> _loadCurrentCurrency() async {
    setState(() => _isLoading = true);
    try {
      final code = await _currencyService.getCurrencyCode();
      final symbol = await _currencyService.getCurrencySymbol();

      if (mounted) {
        setState(() {
          _currentCurrencyCode = code;
          _currentCurrencySymbol = symbol;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading currency: $e')),
        );
      }
    }
  }

  Future<void> _updateCurrency(String code, String symbol) async {
    try {
      // Update all invoice settings (SALE, PURCHASE, RETURN)
      final invoiceTypes = ['SALE', 'PURCHASE', 'RETURN'];

      for (final invoiceType in invoiceTypes) {
        final settings = await _invoiceSettingsService.getInvoiceSettings(invoiceType);

        if (settings != null) {
          await _invoiceSettingsService.saveInvoiceSettings({
            ...settings,
            'currency_code': code,
            'currency_symbol': symbol,
          });
        }
      }

      // Clear currency service cache
      _currencyService.clearCache();

      if (mounted) {
        setState(() {
          _currentCurrencyCode = code;
          _currentCurrencySymbol = symbol;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Currency changed to $code ($symbol)'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating currency: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Currency Settings'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                // Current Currency Card
                Card(
                  margin: const EdgeInsets.all(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Current Currency',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  _currentCurrencySymbol,
                                  style: const TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _currencies.firstWhere(
                                      (c) => c['code'] == _currentCurrencyCode,
                                      orElse: () => {'name': _currentCurrencyCode},
                                    )['name']!,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Code: $_currentCurrencyCode',
                                    style: const TextStyle(
                                      color: Colors.grey,
                                    ),
                                  ),
                                  Text(
                                    'Symbol: $_currentCurrencySymbol',
                                    style: const TextStyle(
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Info Card
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  color: Colors.blue.withOpacity(0.1),
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Default currency is Bangladesh Taka (৳). Other currencies are disabled and for advanced settings only.',
                            style: TextStyle(color: Colors.blue),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Currency List
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'Select Currency',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _currencies.length,
                  itemBuilder: (context, index) {
                    final currency = _currencies[index];
                    final isSelected = currency['code'] == _currentCurrencyCode;
                    final isBDT = currency['code'] == 'BDT';
                    final isDisabled = !isBDT;

                    return Tooltip(
                      message: isDisabled ? 'For advanced settings only' : '',
                      child: Opacity(
                        opacity: isDisabled ? 0.5 : 1.0,
                        child: ListTile(
                          enabled: !isDisabled,
                          leading: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.blue
                                  : isDisabled
                                      ? Colors.grey.withOpacity(0.1)
                                      : Colors.grey.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                currency['symbol']!,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? Colors.white
                                      : isDisabled
                                          ? Colors.grey
                                          : Colors.black,
                                ),
                              ),
                            ),
                          ),
                          title: Text(
                            currency['name']!,
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isDisabled ? Colors.grey : null,
                            ),
                          ),
                          subtitle: Text(
                            '${currency['code']} (${currency['symbol']})',
                            style: TextStyle(
                              color: isDisabled ? Colors.grey : null,
                            ),
                          ),
                          trailing: isSelected
                              ? const Icon(Icons.check_circle, color: Colors.blue)
                              : isDisabled
                                  ? const Icon(Icons.lock, color: Colors.grey, size: 20)
                                  : null,
                          onTap: isSelected || isDisabled
                              ? null
                              : () => _showConfirmDialog(
                                    currency['code']!,
                                    currency['symbol']!,
                                    currency['name']!,
                                  ),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 80),
              ],
            ),
    );
  }

  Future<void> _showConfirmDialog(String code, String symbol, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Currency?'),
        content: Text(
          'Are you sure you want to change currency to $name ($code)?\n\nThis will update all invoices, reports, and transactions.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Change Currency'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _updateCurrency(code, symbol);
    }
  }
}
