import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../services/invoice/invoice_settings_service.dart';

class BodySettingsTab extends StatefulWidget {
  final String invoiceType;

  const BodySettingsTab({super.key, required this.invoiceType});

  @override
  State<BodySettingsTab> createState() => _BodySettingsTabState();
}

class _BodySettingsTabState extends State<BodySettingsTab> {
  final _formKey = GlobalKey<FormState>();
  final InvoiceSettingsService _service = InvoiceSettingsService();

  // Party Details Controllers
  late TextEditingController _partyLabelController;

  // Item Table Controllers
  late TextEditingController _tableHeaderJsonController;

  // Styling Controllers
  late TextEditingController _borderColorController;
  late TextEditingController _headerBgColorController;
  late TextEditingController _rowAltColorController;

  // Totals Controllers
  late TextEditingController _subtotalLabelController;
  late TextEditingController _discountLabelController;
  late TextEditingController _taxLabelController;
  late TextEditingController _shippingLabelController;
  late TextEditingController _otherChargesLabelController;
  late TextEditingController _grandTotalLabelController;
  late TextEditingController _grandTotalFontSizeController;

  // QR Code Controllers
  late TextEditingController _qrContentController;
  late TextEditingController _qrSizeController;

  // Party Details Toggles
  bool _showPartyName = true;
  bool _showPartyCompany = true;
  bool _showPartyAddress = true;
  bool _showPartyPhone = true;
  bool _showPartyEmail = true;
  bool _showPartyTaxId = true;

  // Item Table Column Toggles
  bool _showItemCode = true;
  bool _showDescription = true;
  bool _showHsn = true;
  bool _showUnit = true;
  bool _showQuantity = true;
  bool _showPrice = true;
  bool _showItemDiscount = true;
  bool _showItemTax = true;
  bool _showAmount = true;
  bool _showItemImage = false;

  // Styling
  String _borderStyle = 'SOLID';

  // Totals Toggles
  bool _showSubtotal = true;
  bool _showDiscountTotal = true;
  bool _showTaxTotal = true;
  bool _showShipping = false;
  bool _showOtherCharges = false;
  bool _showGrandTotal = true;

  // Additional Features
  bool _showQrCode = false;
  String _qrPosition = 'BOTTOM_RIGHT';
  bool _showAmountInWords = true;
  String _colorTheme = 'BLUE';

  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _partyLabelController = TextEditingController();
    _tableHeaderJsonController = TextEditingController();
    _borderColorController = TextEditingController();
    _headerBgColorController = TextEditingController();
    _rowAltColorController = TextEditingController();
    _subtotalLabelController = TextEditingController();
    _discountLabelController = TextEditingController();
    _taxLabelController = TextEditingController();
    _shippingLabelController = TextEditingController();
    _otherChargesLabelController = TextEditingController();
    _grandTotalLabelController = TextEditingController();
    _grandTotalFontSizeController = TextEditingController();
    _qrContentController = TextEditingController();
    _qrSizeController = TextEditingController();
    _loadSettings();
  }

  @override
  void didUpdateWidget(BodySettingsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.invoiceType != widget.invoiceType) {
      _loadSettings();
    }
  }

  @override
  void dispose() {
    _partyLabelController.dispose();
    _tableHeaderJsonController.dispose();
    _borderColorController.dispose();
    _headerBgColorController.dispose();
    _rowAltColorController.dispose();
    _subtotalLabelController.dispose();
    _discountLabelController.dispose();
    _taxLabelController.dispose();
    _shippingLabelController.dispose();
    _otherChargesLabelController.dispose();
    _grandTotalLabelController.dispose();
    _grandTotalFontSizeController.dispose();
    _qrContentController.dispose();
    _qrSizeController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      var settings = await _service.getBodySettings(widget.invoiceType);

      if (settings == null) {
        await _service.initializeDefaultSettings(widget.invoiceType);
        settings = await _service.getBodySettings(widget.invoiceType);
      }

      if (settings != null && mounted) {
        setState(() {
          // Party Details
          _showPartyName = (settings!['show_party_name'] as int? ?? 1) == 1;
          _showPartyCompany = (settings['show_party_company'] as int? ?? 1) == 1;
          _showPartyAddress = (settings['show_party_address'] as int? ?? 1) == 1;
          _showPartyPhone = (settings['show_party_phone'] as int? ?? 1) == 1;
          _showPartyEmail = (settings['show_party_email'] as int? ?? 1) == 1;
          _showPartyTaxId = (settings['show_party_tax_id'] as int? ?? 1) == 1;
          _partyLabelController.text = settings['party_label'] as String? ?? 'Bill To';

          // Item Table Columns
          _showItemCode = (settings['show_item_code'] as int? ?? 1) == 1;
          _showDescription = (settings['show_item_description'] as int? ?? 1) == 1;
          _showHsn = (settings['show_hsn_code'] as int? ?? 0) == 1;
          _showUnit = (settings['show_unit_column'] as int? ?? 1) == 1;
          _showQuantity = (settings['show_quantity_column'] as int? ?? 1) == 1;
          _showPrice = (settings['show_unit_price_column'] as int? ?? 1) == 1;
          _showItemDiscount = (settings['show_discount_column'] as int? ?? 1) == 1;
          _showItemTax = (settings['show_tax_column'] as int? ?? 1) == 1;
          _showAmount = (settings['show_amount_column'] as int? ?? 1) == 1;
          _showItemImage = (settings['show_item_image'] as int? ?? 0) == 1;
          _tableHeaderJsonController.text = settings['item_table_headers'] as String? ?? '';

          // Styling
          final borderStyleValue = settings['table_border_style'] as String? ?? 'SOLID';
          _borderStyle = ['SOLID', 'DASHED', 'DOTTED', 'NONE'].contains(borderStyleValue) ? borderStyleValue : 'SOLID';
          _borderColorController.text = settings['table_border_color'] as String? ?? '#000000';
          _headerBgColorController.text = settings['table_header_bg_color'] as String? ?? '#f0f0f0';
          _rowAltColorController.text = settings['table_row_alternate_color'] as String? ?? '#ffffff';

          // Totals
          _showSubtotal = (settings['show_subtotal'] as int? ?? 1) == 1;
          _showDiscountTotal = (settings['show_total_discount'] as int? ?? 1) == 1;
          _showTaxTotal = (settings['show_total_tax'] as int? ?? 1) == 1;
          _showShipping = (settings['show_shipping_charges'] as int? ?? 0) == 1;
          _showOtherCharges = (settings['show_other_charges'] as int? ?? 0) == 1;
          _showGrandTotal = (settings['show_grand_total'] as int? ?? 1) == 1;

          // Use default values for non-editable labels
          _subtotalLabelController.text = 'Subtotal';
          _discountLabelController.text = 'Discount';
          _taxLabelController.text = 'Tax';
          _shippingLabelController.text = settings['shipping_charges_label'] as String? ?? 'Shipping';
          _otherChargesLabelController.text = settings['other_charges_label'] as String? ?? 'Other Charges';
          _grandTotalLabelController.text = settings['grand_total_label'] as String? ?? 'Grand Total';
          _grandTotalFontSizeController.text = (settings['grand_total_font_size'] as int? ?? 14).toString();

          // Additional Features
          _showQrCode = (settings['show_qr_code'] as int? ?? 0) == 1;
          _qrContentController.text = settings['qr_code_content'] as String? ?? '{invoice_number}';
          _qrSizeController.text = (settings['qr_code_size'] as int? ?? 100).toString();
          final qrPosValue = settings['qr_code_position'] as String? ?? 'BOTTOM_RIGHT';
          _qrPosition = ['TOP_LEFT', 'TOP_RIGHT', 'BOTTOM_LEFT', 'BOTTOM_RIGHT'].contains(qrPosValue) ? qrPosValue : 'BOTTOM_RIGHT';
          _showAmountInWords = (settings['show_amount_in_words'] as int? ?? 1) == 1;
          final colorThemeValue = settings['color_theme'] as String? ?? 'BLUE';
          _colorTheme = ['BLUE', 'GREEN', 'RED', 'ORANGE', 'PURPLE', 'BLACK'].contains(colorThemeValue) ? colorThemeValue : 'BLUE';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading settings: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      await _service.saveBodySettings({
        'invoice_type': widget.invoiceType,
        // Party Details
        'show_party_name': _showPartyName ? 1 : 0,
        'show_party_company': _showPartyCompany ? 1 : 0,
        'show_party_address': _showPartyAddress ? 1 : 0,
        'show_party_phone': _showPartyPhone ? 1 : 0,
        'show_party_email': _showPartyEmail ? 1 : 0,
        'show_party_tax_id': _showPartyTaxId ? 1 : 0,
        'party_label': _partyLabelController.text.trim(),
        // Item Table
        'show_item_code': _showItemCode ? 1 : 0,
        'show_item_description': _showDescription ? 1 : 0,
        'show_hsn_code': _showHsn ? 1 : 0,
        'show_unit_column': _showUnit ? 1 : 0,
        'show_quantity_column': _showQuantity ? 1 : 0,
        'show_unit_price_column': _showPrice ? 1 : 0,
        'show_discount_column': _showItemDiscount ? 1 : 0,
        'show_tax_column': _showItemTax ? 1 : 0,
        'show_amount_column': _showAmount ? 1 : 0,
        'show_item_image': _showItemImage ? 1 : 0,
        'item_table_headers': _tableHeaderJsonController.text.trim(),
        // Styling
        'table_border_style': _borderStyle,
        'table_border_color': _borderColorController.text.trim(),
        'table_header_bg_color': _headerBgColorController.text.trim(),
        'table_row_alternate_color': _rowAltColorController.text.trim(),
        // Totals
        'show_subtotal': _showSubtotal ? 1 : 0,
        'show_total_discount': _showDiscountTotal ? 1 : 0,
        'show_total_tax': _showTaxTotal ? 1 : 0,
        'show_shipping_charges': _showShipping ? 1 : 0,
        'shipping_charges_label': _shippingLabelController.text.trim(),
        'show_other_charges': _showOtherCharges ? 1 : 0,
        'other_charges_label': _otherChargesLabelController.text.trim(),
        'show_grand_total': _showGrandTotal ? 1 : 0,
        'grand_total_label': _grandTotalLabelController.text.trim(),
        'grand_total_font_size': int.parse(_grandTotalFontSizeController.text),
        // Additional Features
        'show_qr_code': _showQrCode ? 1 : 0,
        'qr_code_content': _qrContentController.text.trim(),
        'qr_code_size': int.parse(_qrSizeController.text),
        'qr_code_position': _qrPosition,
        'show_amount_in_words': _showAmountInWords ? 1 : 0,
        'color_theme': _colorTheme,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Body settings saved successfully'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving settings: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Party Details
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Party Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _partyLabelController,
                    decoration: const InputDecoration(
                      labelText: 'Party Label',
                      hintText: 'Bill To / Ship To / Customer',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  const Text('Display Fields:', style: TextStyle(fontWeight: FontWeight.bold)),
                  SwitchListTile(
                    title: const Text('Show Party Name'),
                    value: _showPartyName,
                    onChanged: (v) => setState(() => _showPartyName = v),
                  ),
                  SwitchListTile(
                    title: const Text('Show Company Name'),
                    value: _showPartyCompany,
                    onChanged: (v) => setState(() => _showPartyCompany = v),
                  ),
                  SwitchListTile(
                    title: const Text('Show Address'),
                    value: _showPartyAddress,
                    onChanged: (v) => setState(() => _showPartyAddress = v),
                  ),
                  SwitchListTile(
                    title: const Text('Show Phone'),
                    value: _showPartyPhone,
                    onChanged: (v) => setState(() => _showPartyPhone = v),
                  ),
                  SwitchListTile(
                    title: const Text('Show Email'),
                    value: _showPartyEmail,
                    onChanged: (v) => setState(() => _showPartyEmail = v),
                  ),
                  SwitchListTile(
                    title: const Text('Show Tax ID'),
                    value: _showPartyTaxId,
                    onChanged: (v) => setState(() => _showPartyTaxId = v),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Item Table Configuration
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Item Table Configuration', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  const Text('Table Columns:', style: TextStyle(fontWeight: FontWeight.bold)),
                  SwitchListTile(
                    title: const Text('Item Code'),
                    value: _showItemCode,
                    onChanged: (v) => setState(() => _showItemCode = v),
                  ),
                  SwitchListTile(
                    title: const Text('Description'),
                    value: _showDescription,
                    onChanged: (v) => setState(() => _showDescription = v),
                  ),
                  SwitchListTile(
                    title: const Text('HSN/SAC Code'),
                    value: _showHsn,
                    onChanged: (v) => setState(() => _showHsn = v),
                  ),
                  SwitchListTile(
                    title: const Text('Unit'),
                    value: _showUnit,
                    onChanged: (v) => setState(() => _showUnit = v),
                  ),
                  SwitchListTile(
                    title: const Text('Quantity'),
                    value: _showQuantity,
                    onChanged: (v) => setState(() => _showQuantity = v),
                  ),
                  SwitchListTile(
                    title: const Text('Price'),
                    value: _showPrice,
                    onChanged: (v) => setState(() => _showPrice = v),
                  ),
                  SwitchListTile(
                    title: const Text('Discount'),
                    value: _showItemDiscount,
                    onChanged: (v) => setState(() => _showItemDiscount = v),
                  ),
                  SwitchListTile(
                    title: const Text('Tax'),
                    value: _showItemTax,
                    onChanged: (v) => setState(() => _showItemTax = v),
                  ),
                  SwitchListTile(
                    title: const Text('Amount'),
                    value: _showAmount,
                    onChanged: (v) => setState(() => _showAmount = v),
                  ),
                  SwitchListTile(
                    title: const Text('Item Image'),
                    value: _showItemImage,
                    onChanged: (v) => setState(() => _showItemImage = v),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _tableHeaderJsonController,
                    decoration: const InputDecoration(
                      labelText: 'Table Header Customization (JSON)',
                      hintText: '{"Item Code": "Code", "Description": "Item"}',
                      border: OutlineInputBorder(),
                      helperText: 'Optional: Custom column headers in JSON format',
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Table Styling
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Table Styling', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _borderStyle,
                    decoration: const InputDecoration(
                      labelText: 'Border Style',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'SOLID', child: Text('Solid')),
                      DropdownMenuItem(value: 'DASHED', child: Text('Dashed')),
                      DropdownMenuItem(value: 'DOTTED', child: Text('Dotted')),
                      DropdownMenuItem(value: 'NONE', child: Text('None')),
                    ],
                    onChanged: (v) => setState(() => _borderStyle = v!),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _borderColorController,
                    decoration: const InputDecoration(
                      labelText: 'Border Color (Hex)',
                      hintText: '#000000',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _headerBgColorController,
                    decoration: const InputDecoration(
                      labelText: 'Header Background Color (Hex)',
                      hintText: '#f0f0f0',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _rowAltColorController,
                    decoration: const InputDecoration(
                      labelText: 'Row Alternate Color (Hex)',
                      hintText: '#ffffff',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Totals Display
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Totals Display', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  const Text('Display Totals:', style: TextStyle(fontWeight: FontWeight.bold)),
                  SwitchListTile(
                    title: const Text('Show Subtotal'),
                    value: _showSubtotal,
                    onChanged: (v) => setState(() => _showSubtotal = v),
                  ),
                  if (_showSubtotal) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                      child: TextFormField(
                        controller: _subtotalLabelController,
                        decoration: const InputDecoration(
                          labelText: 'Subtotal Label',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                  SwitchListTile(
                    title: const Text('Show Discount'),
                    value: _showDiscountTotal,
                    onChanged: (v) => setState(() => _showDiscountTotal = v),
                  ),
                  if (_showDiscountTotal) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                      child: TextFormField(
                        controller: _discountLabelController,
                        decoration: const InputDecoration(
                          labelText: 'Discount Label',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                  SwitchListTile(
                    title: const Text('Show Tax'),
                    value: _showTaxTotal,
                    onChanged: (v) => setState(() => _showTaxTotal = v),
                  ),
                  if (_showTaxTotal) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                      child: TextFormField(
                        controller: _taxLabelController,
                        decoration: const InputDecoration(
                          labelText: 'Tax Label',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                  SwitchListTile(
                    title: const Text('Show Shipping'),
                    value: _showShipping,
                    onChanged: (v) => setState(() => _showShipping = v),
                  ),
                  if (_showShipping) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                      child: TextFormField(
                        controller: _shippingLabelController,
                        decoration: const InputDecoration(
                          labelText: 'Shipping Label',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                  SwitchListTile(
                    title: const Text('Show Other Charges'),
                    value: _showOtherCharges,
                    onChanged: (v) => setState(() => _showOtherCharges = v),
                  ),
                  if (_showOtherCharges) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                      child: TextFormField(
                        controller: _otherChargesLabelController,
                        decoration: const InputDecoration(
                          labelText: 'Other Charges Label',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                  SwitchListTile(
                    title: const Text('Show Grand Total'),
                    value: _showGrandTotal,
                    onChanged: (v) => setState(() => _showGrandTotal = v),
                  ),
                  if (_showGrandTotal) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _grandTotalLabelController,
                              decoration: const InputDecoration(
                                labelText: 'Grand Total Label',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          SizedBox(
                            width: 100,
                            child: TextFormField(
                              controller: _grandTotalFontSizeController,
                              decoration: const InputDecoration(
                                labelText: 'Font Size',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Additional Features
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Additional Features', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Show Amount in Words'),
                    subtitle: const Text('Display total amount in words (e.g., One Thousand Dollars)'),
                    value: _showAmountInWords,
                    onChanged: (v) => setState(() => _showAmountInWords = v),
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: const Text('Show QR Code'),
                    value: _showQrCode,
                    onChanged: (v) => setState(() => _showQrCode = v),
                  ),
                  if (_showQrCode) ...[
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _qrContentController,
                      decoration: const InputDecoration(
                        labelText: 'QR Code Content Template',
                        hintText: '{invoice_number} | {total_amount}',
                        border: OutlineInputBorder(),
                        helperText: 'Use placeholders: {invoice_number}, {total_amount}, {date}',
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _qrSizeController,
                            decoration: const InputDecoration(
                              labelText: 'QR Code Size (px)',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _qrPosition,
                            decoration: const InputDecoration(
                              labelText: 'QR Position',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'TOP_LEFT', child: Text('Top Left')),
                              DropdownMenuItem(value: 'TOP_RIGHT', child: Text('Top Right')),
                              DropdownMenuItem(value: 'BOTTOM_LEFT', child: Text('Bottom Left')),
                              DropdownMenuItem(value: 'BOTTOM_RIGHT', child: Text('Bottom Right')),
                            ],
                            onChanged: (v) => setState(() => _qrPosition = v!),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const Divider(),
                  DropdownButtonFormField<String>(
                    initialValue: _colorTheme,
                    decoration: const InputDecoration(
                      labelText: 'Color Theme',
                      border: OutlineInputBorder(),
                      helperText: 'Overall color scheme for the invoice',
                    ),
                    items: const [
                      DropdownMenuItem(value: 'BLUE', child: Text('Blue')),
                      DropdownMenuItem(value: 'GREEN', child: Text('Green')),
                      DropdownMenuItem(value: 'RED', child: Text('Red')),
                      DropdownMenuItem(value: 'PURPLE', child: Text('Purple')),
                      DropdownMenuItem(value: 'ORANGE', child: Text('Orange')),
                      DropdownMenuItem(value: 'GRAY', child: Text('Gray / Monochrome')),
                    ],
                    onChanged: (v) => setState(() => _colorTheme = v!),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Save Button
          ElevatedButton(
            onPressed: _isSaving ? null : _saveSettings,
            child: _isSaving
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Padding(padding: EdgeInsets.all(16), child: Text('Save Settings')),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
