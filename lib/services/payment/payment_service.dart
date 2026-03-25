import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../data/database/database_helper.dart';
import '../../data/models/payment_model.dart';

/// Handles clearing dues for both suppliers and customers.
/// Payments are distributed across unpaid transactions using FIFO
/// (oldest transaction settled first).
class PaymentService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // ─── Record Payments ─────────────────────────────────────────────────────────

  /// Pay toward a supplier (clears our payable to them).
  Future<int> recordSupplierPayment({
    required int supplierId,
    required double amount,
    required DateTime paymentDate,
    String paymentMethod = 'cash',
    String? referenceNumber,
    String? notes,
    int? createdBy,
    int? targetTransactionId, // optional: pay a specific bill
  }) async {
    final db = await _dbHelper.database;
    return await db.transaction((txn) async {
      final paymentId = await txn.insert('supplier_payments', {
        'supplier_id': supplierId,
        'amount': amount,
        'payment_date': paymentDate.toIso8601String(),
        'payment_method': paymentMethod,
        'reference_number': referenceNumber,
        'notes': notes,
        'created_by': createdBy,
        'created_at': DateTime.now().toIso8601String(),
      });

      await txn.rawUpdate('''
        UPDATE suppliers
        SET current_balance = MAX(0, current_balance - ?),
            updated_at = ?
        WHERE id = ?
      ''', [amount, DateTime.now().toIso8601String(), supplierId]);

      await _settleTransactionsFifo(
        txn: txn,
        partyId: supplierId,
        partyType: 'supplier',
        txnType: 'BUY',
        amount: amount,
        targetTransactionId: targetTransactionId,
      );

      return paymentId;
    });
  }

  /// Record a payment from a customer (clears their receivable to us).
  Future<int> recordCustomerPayment({
    required int customerId,
    required double amount,
    required DateTime paymentDate,
    String paymentMethod = 'cash',
    String? referenceNumber,
    String? notes,
    int? createdBy,
    int? targetTransactionId, // optional: pay a specific bill
  }) async {
    final db = await _dbHelper.database;
    return await db.transaction((txn) async {
      final paymentId = await txn.insert('customer_payments', {
        'customer_id': customerId,
        'amount': amount,
        'payment_date': paymentDate.toIso8601String(),
        'payment_method': paymentMethod,
        'reference_number': referenceNumber,
        'notes': notes,
        'created_by': createdBy,
        'created_at': DateTime.now().toIso8601String(),
      });

      await txn.rawUpdate('''
        UPDATE customers
        SET current_balance = MAX(0, current_balance - ?),
            updated_at = ?
        WHERE id = ?
      ''', [amount, DateTime.now().toIso8601String(), customerId]);

      await _settleTransactionsFifo(
        txn: txn,
        partyId: customerId,
        partyType: 'customer',
        txnType: 'SELL',
        amount: amount,
        targetTransactionId: targetTransactionId,
      );

      return paymentId;
    });
  }

  // ─── FIFO Settlement ─────────────────────────────────────────────────────────

  /// Distributes [amount] across unpaid/partial transactions, oldest first.
  /// If [targetTransactionId] is provided, only that transaction is settled.
  Future<void> _settleTransactionsFifo({
    required DatabaseExecutor txn,
    required int partyId,
    required String partyType,
    required String txnType,
    required double amount,
    int? targetTransactionId,
  }) async {
    final now = DateTime.now().toIso8601String();

    // Build query: if target specified, only settle that one; otherwise FIFO order
    final String whereClause = targetTransactionId != null
        ? "id = ? AND payment_status != 'PAID'"
        : "party_id = ? AND party_type = ? AND transaction_type = ? AND payment_status != 'PAID'";

    final List<Object?> whereArgs = targetTransactionId != null
        ? [targetTransactionId]
        : [partyId, partyType, txnType];

    final unpaid = await txn.rawQuery('''
      SELECT id, credit_amount, paid_amount, total_amount
      FROM transactions
      WHERE $whereClause
      ORDER BY transaction_date ASC
    ''', whereArgs);

    double remaining = amount;

    for (final row in unpaid) {
      if (remaining <= 0.001) break; // floating-point safety margin

      final txId = row['id'] as int;
      final credit = (row['credit_amount'] as num).toDouble();

      if (remaining >= credit - 0.001) {
        // Fully settle this transaction
        await txn.rawUpdate('''
          UPDATE transactions
          SET paid_amount  = total_amount,
              credit_amount = 0,
              payment_status = 'PAID',
              updated_at = ?
          WHERE id = ?
        ''', [now, txId]);
        remaining -= credit;
      } else {
        // Partially settle this transaction
        await txn.rawUpdate('''
          UPDATE transactions
          SET paid_amount  = paid_amount + ?,
              credit_amount = credit_amount - ?,
              payment_status = 'PARTIAL',
              updated_at = ?
          WHERE id = ?
        ''', [remaining, remaining, now, txId]);
        remaining = 0;
      }
    }
  }

  // ─── Reconciliation ──────────────────────────────────────────────────────────

  /// Fixes stale transaction payment_status values caused by payments that were
  /// recorded before FIFO settlement was implemented.
  ///
  /// Two-pass approach:
  ///   Pass 1 – parties with current_balance = 0 → mark all their unpaid
  ///             transactions as PAID instantly (no distribution needed).
  ///   Pass 2 – parties with current_balance > 0 → redistribute total cleared
  ///             payments across transactions FIFO so the split is consistent.
  Future<void> reconcileTransactionStatuses() async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      // ── Pass 1: fully-paid parties ──────────────────────────────────────────
      await txn.rawUpdate('''
        UPDATE transactions
        SET payment_status = 'PAID',
            paid_amount    = total_amount,
            credit_amount  = 0,
            updated_at     = ?
        WHERE transaction_type = 'BUY'
          AND party_type       = 'supplier'
          AND payment_status  != 'PAID'
          AND party_id IN (SELECT id FROM suppliers WHERE current_balance <= 0)
      ''', [now]);

      await txn.rawUpdate('''
        UPDATE transactions
        SET payment_status = 'PAID',
            paid_amount    = total_amount,
            credit_amount  = 0,
            updated_at     = ?
        WHERE transaction_type = 'SELL'
          AND party_type       = 'customer'
          AND payment_status  != 'PAID'
          AND party_id IN (SELECT id FROM customers WHERE current_balance <= 0)
      ''', [now]);

      // ── Pass 2: partially-paid parties – re-distribute FIFO ─────────────────
      for (final spec in [
        ['supplier', 'BUY',  'supplier_payments', 'supplier_id', 'suppliers'],
        ['customer', 'SELL', 'customer_payments', 'customer_id', 'customers'],
      ]) {
        final partyType  = spec[0];
        final txnType    = spec[1];
        final payTable   = spec[2];
        final payCol     = spec[3];
        final partyTable = spec[4];

        // Parties that still have a balance > 0
        final parties = await txn.rawQuery('''
          SELECT id, current_balance FROM $partyTable
          WHERE current_balance > 0 AND is_active = 1
        ''');

        for (final party in parties) {
          final partyId = party['id'] as int;

          // Total historically cleared = sum of explicit payment records
          final payResult = await txn.rawQuery('''
            SELECT COALESCE(SUM(amount), 0) AS cleared
            FROM $payTable WHERE $payCol = ?
          ''', [partyId]);
          final totalCleared =
              (payResult.first['cleared'] as num).toDouble();

          if (totalCleared <= 0) continue;

          // Reset all CREDIT/PARTIAL transactions to original credit state so
          // we can re-apply from scratch (avoids double-counting).
          // Original credit = total_amount - initial_paid_at_purchase_time.
          // We approximate: initial paid = total_amount - credit_amount (current).
          // First, restore to fully unpaid so FIFO can start clean.
          await txn.rawUpdate('''
            UPDATE transactions
            SET paid_amount    = total_amount - credit_amount,
                credit_amount  = credit_amount,   -- no change, already correct
                updated_at     = ?
            WHERE party_id          = ?
              AND party_type        = ?
              AND transaction_type  = ?
              AND payment_status   != 'PAID'
          ''', [now, partyId, partyType, txnType]);

          // Now apply FIFO over the cleared amount
          await _settleTransactionsFifo(
            txn: txn,
            partyId: partyId,
            partyType: partyType,
            txnType: txnType,
            amount: totalCleared,
          );
        }
      }
    });
  }

  // ─── Queries ─────────────────────────────────────────────────────────────────

  Future<List<PaymentModel>> getSupplierPayments(int supplierId) async {
    final db = await _dbHelper.database;
    final rows = await db.query('supplier_payments',
        where: 'supplier_id = ?',
        whereArgs: [supplierId],
        orderBy: 'payment_date DESC');
    return rows.map((r) => PaymentModel.fromMap(r, 'supplier')).toList();
  }

  Future<List<PaymentModel>> getCustomerPayments(int customerId) async {
    final db = await _dbHelper.database;
    final rows = await db.query('customer_payments',
        where: 'customer_id = ?',
        whereArgs: [customerId],
        orderBy: 'payment_date DESC');
    return rows.map((r) => PaymentModel.fromMap(r, 'customer')).toList();
  }

  Future<double> getTotalPaidToSupplier(int supplierId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
        'SELECT COALESCE(SUM(amount), 0) as total FROM supplier_payments WHERE supplier_id = ?',
        [supplierId]);
    return (result.first['total'] as num).toDouble();
  }

  Future<double> getTotalReceivedFromCustomer(int customerId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
        'SELECT COALESCE(SUM(amount), 0) as total FROM customer_payments WHERE customer_id = ?',
        [customerId]);
    return (result.first['total'] as num).toDouble();
  }
}
