import '../../data/database/database_helper.dart';

class ReportsService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// Get sales summary report for date range
  Future<Map<String, dynamic>> getSalesSummary(DateTime start, DateTime end) async {
    final db = await _dbHelper.database;

    final result = await db.rawQuery('''
      SELECT
        COUNT(DISTINCT t.id) as total_transactions,
        COUNT(DISTINCT t.party_id) as unique_customers,
        COALESCE(SUM(t.subtotal), 0) as subtotal,
        COALESCE(SUM(t.discount_amount), 0) as total_discount,
        COALESCE(SUM(t.tax_amount), 0) as total_tax,
        COALESCE(SUM(t.total_amount), 0) as total_sales,
        AVG(t.total_amount) as average_sale
      FROM transactions t
      WHERE t.transaction_type = 'SALE'
        AND t.status = 'COMPLETED'
        AND t.transaction_date >= ?
        AND t.transaction_date <= ?
    ''', [start.toIso8601String(), end.toIso8601String()]);

    if (result.isEmpty) {
      return {
        'total_transactions': 0,
        'unique_customers': 0,
        'subtotal': 0.0,
        'total_discount': 0.0,
        'total_tax': 0.0,
        'total_sales': 0.0,
        'average_sale': 0.0,
      };
    }

    return result.first;
  }

  /// Get purchases summary report for date range
  Future<Map<String, dynamic>> getPurchasesSummary(DateTime start, DateTime end) async {
    final db = await _dbHelper.database;

    final result = await db.rawQuery('''
      SELECT
        COUNT(DISTINCT t.id) as total_transactions,
        COUNT(DISTINCT t.party_id) as unique_suppliers,
        COALESCE(SUM(t.subtotal), 0) as subtotal,
        COALESCE(SUM(t.discount_amount), 0) as total_discount,
        COALESCE(SUM(t.tax_amount), 0) as total_tax,
        COALESCE(SUM(t.total_amount), 0) as total_purchases,
        AVG(t.total_amount) as average_purchase
      FROM transactions t
      WHERE t.transaction_type = 'PURCHASE'
        AND t.status = 'COMPLETED'
        AND t.transaction_date >= ?
        AND t.transaction_date <= ?
    ''', [start.toIso8601String(), end.toIso8601String()]);

    if (result.isEmpty) {
      return {
        'total_transactions': 0,
        'unique_suppliers': 0,
        'subtotal': 0.0,
        'total_discount': 0.0,
        'total_tax': 0.0,
        'total_purchases': 0.0,
        'average_purchase': 0.0,
      };
    }

    return result.first;
  }

  /// Get current inventory report with stock levels
  Future<List<Map<String, dynamic>>> getInventoryReport() async {
    final db = await _dbHelper.database;

    final result = await db.rawQuery('''
      SELECT
        p.id,
        p.name,
        p.sku,
        p.barcode,
        p.category,
        p.unit,
        p.default_purchase_price,
        p.default_selling_price,
        p.reorder_level,
        COALESCE(SUM(pb.quantity_remaining), 0) as current_stock,
        COUNT(DISTINCT pb.id) as batch_count,
        MIN(pb.purchase_price) as min_cost,
        MAX(pb.purchase_price) as max_cost,
        COALESCE(AVG(pb.purchase_price), 0) as avg_cost,
        COALESCE(SUM(pb.quantity_remaining) * p.default_selling_price, 0) as inventory_value
      FROM products p
      LEFT JOIN product_batches pb ON p.id = pb.product_id
      WHERE p.is_active = 1
      GROUP BY p.id
      ORDER BY p.name ASC
    ''');

    return result;
  }

  /// Get low stock products
  Future<List<Map<String, dynamic>>> getLowStockProducts() async {
    final db = await _dbHelper.database;

    final result = await db.rawQuery('''
      SELECT
        p.id,
        p.name,
        p.sku,
        p.reorder_level,
        COALESCE(SUM(pb.quantity_remaining), 0) as current_stock
      FROM products p
      LEFT JOIN product_batches pb ON p.id = pb.product_id
      WHERE p.is_active = 1
      GROUP BY p.id
      HAVING current_stock <= p.reorder_level
      ORDER BY current_stock ASC
    ''');

    return result;
  }

  /// Get top/bottom selling products
  Future<List<Map<String, dynamic>>> getProductPerformance(
    DateTime start,
    DateTime end, {
    int limit = 10,
    bool topPerformers = true,
  }) async {
    final db = await _dbHelper.database;

    final orderBy = topPerformers ? 'total_quantity DESC' : 'total_quantity ASC';

    final result = await db.rawQuery('''
      SELECT
        p.id,
        p.name,
        p.sku,
        COUNT(DISTINCT t.id) as transaction_count,
        COALESCE(SUM(tl.quantity), 0) as total_quantity,
        COALESCE(SUM(tl.line_total), 0) as total_revenue,
        COALESCE(AVG(tl.unit_price), 0) as avg_selling_price
      FROM products p
      LEFT JOIN transaction_lines tl ON p.id = tl.product_id
      LEFT JOIN transactions t ON tl.transaction_id = t.id
      WHERE t.transaction_type = 'SALE'
        AND t.status = 'COMPLETED'
        AND t.transaction_date >= ?
        AND t.transaction_date <= ?
      GROUP BY p.id
      ORDER BY $orderBy
      LIMIT ?
    ''', [start.toIso8601String(), end.toIso8601String(), limit]);

    return result;
  }

  /// Get customer report with balances and transaction counts
  Future<List<Map<String, dynamic>>> getCustomerReport() async {
    final db = await _dbHelper.database;

    final result = await db.rawQuery('''
      SELECT
        c.id,
        c.name,
        c.company_name,
        c.email,
        c.phone,
        c.credit_limit,
        c.current_balance,
        COUNT(DISTINCT t.id) as total_transactions,
        COALESCE(SUM(CASE WHEN t.transaction_type = 'SALE' THEN t.total_amount ELSE 0 END), 0) as total_sales,
        COALESCE(SUM(CASE WHEN t.transaction_type = 'SALE' THEN 1 ELSE 0 END), 0) as sales_count,
        MAX(t.transaction_date) as last_transaction_date
      FROM customers c
      LEFT JOIN transactions t ON c.id = t.party_id AND t.party_type = 'customer' AND t.status = 'COMPLETED'
      WHERE c.is_active = 1
      GROUP BY c.id
      ORDER BY c.name ASC
    ''');

    return result;
  }

  /// Get supplier report with statistics
  Future<List<Map<String, dynamic>>> getSupplierReport() async {
    final db = await _dbHelper.database;

    final result = await db.rawQuery('''
      SELECT
        s.id,
        s.name,
        s.company_name,
        s.email,
        s.phone,
        COUNT(DISTINCT t.id) as total_purchases,
        COALESCE(SUM(t.total_amount), 0) as total_amount_purchased,
        COALESCE(AVG(t.total_amount), 0) as avg_purchase_amount,
        MAX(t.transaction_date) as last_purchase_date,
        MIN(t.transaction_date) as first_purchase_date
      FROM suppliers s
      LEFT JOIN transactions t ON s.id = t.party_id AND t.party_type = 'supplier' AND t.transaction_type = 'PURCHASE' AND t.status = 'COMPLETED'
      WHERE s.is_active = 1
      GROUP BY s.id
      ORDER BY total_amount_purchased DESC
    ''');

    return result;
  }

  /// Get profit/loss report
  Future<Map<String, dynamic>> getProfitLossReport(DateTime start, DateTime end) async {
    final db = await _dbHelper.database;

    // Get total sales
    final salesResult = await db.rawQuery('''
      SELECT
        COALESCE(SUM(t.total_amount), 0) as total_revenue
      FROM transactions t
      WHERE t.transaction_type = 'SALE'
        AND t.status = 'COMPLETED'
        AND t.transaction_date >= ?
        AND t.transaction_date <= ?
    ''', [start.toIso8601String(), end.toIso8601String()]);

    final totalRevenue = salesResult.isNotEmpty
        ? (salesResult.first['total_revenue'] as num?)?.toDouble() ?? 0.0
        : 0.0;

    // Get total cost of goods sold (based on batch purchase prices)
    final cogsResult = await db.rawQuery('''
      SELECT
        COALESCE(SUM(tl.quantity * pb.purchase_price), 0) as total_cogs
      FROM transaction_lines tl
      LEFT JOIN transactions t ON tl.transaction_id = t.id
      LEFT JOIN product_batches pb ON tl.batch_id = pb.id
      WHERE t.transaction_type = 'SALE'
        AND t.status = 'COMPLETED'
        AND t.transaction_date >= ?
        AND t.transaction_date <= ?
    ''', [start.toIso8601String(), end.toIso8601String()]);

    final totalCogs = cogsResult.isNotEmpty
        ? (cogsResult.first['total_cogs'] as num?)?.toDouble() ?? 0.0
        : 0.0;

    // Get total operating expenses (discounts given)
    final discountResult = await db.rawQuery('''
      SELECT
        COALESCE(SUM(discount_amount), 0) as total_discounts
      FROM transactions
      WHERE transaction_type = 'SALE'
        AND status = 'COMPLETED'
        AND transaction_date >= ?
        AND transaction_date <= ?
    ''', [start.toIso8601String(), end.toIso8601String()]);

    final totalDiscounts = discountResult.isNotEmpty
        ? (discountResult.first['total_discounts'] as num?)?.toDouble() ?? 0.0
        : 0.0;

    // Calculate gross profit and net profit
    final grossProfit = totalRevenue - totalCogs;
    final netProfit = grossProfit - totalDiscounts;
    final profitMargin = totalRevenue > 0 ? (netProfit / totalRevenue) * 100 : 0.0;

    return {
      'total_revenue': totalRevenue,
      'total_cogs': totalCogs,
      'gross_profit': grossProfit,
      'total_discounts': totalDiscounts,
      'net_profit': netProfit,
      'profit_margin_percentage': profitMargin,
    };
  }

  /// Get payment method summary
  Future<List<Map<String, dynamic>>> getPaymentMethodSummary(
    DateTime start,
    DateTime end,
  ) async {
    final db = await _dbHelper.database;

    final result = await db.rawQuery('''
      SELECT
        payment_mode,
        COUNT(*) as transaction_count,
        COALESCE(SUM(total_amount), 0) as total_amount
      FROM transactions
      WHERE status = 'COMPLETED'
        AND transaction_date >= ?
        AND transaction_date <= ?
      GROUP BY payment_mode
      ORDER BY total_amount DESC
    ''', [start.toIso8601String(), end.toIso8601String()]);

    return result;
  }

  /// Get daily sales trend
  Future<List<Map<String, dynamic>>> getDailySalesTrend(
    DateTime start,
    DateTime end,
  ) async {
    final db = await _dbHelper.database;

    final result = await db.rawQuery('''
      SELECT
        DATE(transaction_date) as date,
        COUNT(*) as transaction_count,
        COALESCE(SUM(total_amount), 0) as daily_total
      FROM transactions
      WHERE transaction_type = 'SALE'
        AND status = 'COMPLETED'
        AND transaction_date >= ?
        AND transaction_date <= ?
      GROUP BY DATE(transaction_date)
      ORDER BY date ASC
    ''', [start.toIso8601String(), end.toIso8601String()]);

    return result;
  }

  /// Get category-wise sales report
  Future<List<Map<String, dynamic>>> getCategoryWiseReport(DateTime start, DateTime end) async {
    final db = await _dbHelper.database;

    final result = await db.rawQuery('''
      SELECT
        p.category,
        COUNT(DISTINCT t.id) as transaction_count,
        COALESCE(SUM(tl.quantity), 0) as total_quantity,
        COALESCE(SUM(tl.line_total), 0) as total_amount
      FROM transaction_lines tl
      LEFT JOIN transactions t ON tl.transaction_id = t.id
      LEFT JOIN products p ON tl.product_id = p.id
      WHERE t.transaction_type = 'SALE'
        AND t.status = 'COMPLETED'
        AND t.transaction_date >= ?
        AND t.transaction_date <= ?
      GROUP BY p.category
      ORDER BY total_amount DESC
    ''', [start.toIso8601String(), end.toIso8601String()]);

    return result;
  }
}
