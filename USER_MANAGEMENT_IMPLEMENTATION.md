# User Management - Activate/Deactivate vs Delete

## Overview
The user management system now supports two distinct operations:

1. **Deactivate/Activate** - Toggle user status (soft delete)
2. **Delete** - Permanently remove user from database (hard delete)

## Implementation Details

### 1. Deactivate/Activate User (Soft Delete)

**UI Action:** "Deactivate" or "Activate" button in the user menu

**What it does:**
- Sets `is_active` to 0 (deactivate) or 1 (activate)
- User remains in the database
- User remains visible in the Users list
- Shows "Inactive" chip on deactivated users
- User cannot login when deactivated

**Code Location:** [users_screen.dart:81-101](lib/ui/screens/user/users_screen.dart#L81-L101)

```dart
Future<void> _toggleUserStatus(UserModel user) async {
  final updatedUser = user.copyWith(isActive: !user.isActive);
  await _authService.updateUser(updatedUser);
  _loadUsers();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(user.isActive ? 'User deactivated' : 'User activated'),
      backgroundColor: Colors.green,
    ),
  );
}
```

**Backend:** [auth_service.dart:250-269](lib/services/auth/auth_service.dart#L250-L269)

```dart
Future<bool> deactivateUser(int userId) async {
  await db.update(
    'users',
    {
      'is_active': 0,
      'updated_at': DateTime.now().toIso8601String(),
    },
    where: 'id = ?',
    whereArgs: [userId],
  );
  return true;
}
```

### 2. Delete User (Hard Delete)

**UI Action:** "Delete" button in the user menu

**What it does:**
- **Permanently removes** user from the database
- User **disappears from the Users list immediately**
- **Cannot be undone** - user is gone forever
- All user data is permanently deleted

**Safety Checks:**
- ✅ Cannot delete yourself
- ✅ Cannot delete the last active admin
- ✅ Confirmation dialog required

**Code Location:** [users_screen.dart:103-159](lib/ui/screens/user/users_screen.dart#L103-L159)

```dart
Future<void> _deleteUser(UserModel user) async {
  // Prevent deleting yourself
  final currentUser = _authService.getCurrentUser();
  if (currentUser?.id == user.id) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cannot delete your own account')),
    );
    return;
  }

  // Prevent deleting last admin
  if (user.role == 'admin') {
    final adminCount = _users.where((u) => u.role == 'admin' && u.isActive).length;
    if (adminCount <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot delete the last admin user')),
      );
      return;
    }
  }

  // Confirm deletion
  final confirm = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete User'),
      content: Text('Are you sure you want to delete ${user.name}?'),
      // ... confirmation dialog
    ),
  );

  if (confirm == true) {
    await _authService.deleteUser(user.id!);
    _loadUsers();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('User deleted successfully')),
    );
  }
}
```

**Backend:** [auth_service.dart:271-288](lib/services/auth/auth_service.dart#L271-L288)

```dart
/// Delete user permanently (hard delete from database)
/// WARNING: This permanently removes the user and cannot be undone
Future<bool> deleteUser(int userId) async {
  await db.delete(
    'users',
    where: 'id = ?',
    whereArgs: [userId],
  );
  return true;
}
```

## User Interface

### Users List Display

**Active Users:**
```
┌─────────────────────────────────────────┐
│ 👤 John Doe                    [•••]   │
│    Username: johndoe                    │
│    Role: Admin                          │
│    Email: john@example.com              │
└─────────────────────────────────────────┘
```

**Inactive Users:**
```
┌─────────────────────────────────────────┐
│ 👤 Jane Smith    [Inactive]    [•••]   │
│    Username: janesmith                  │
│    Role: Manager                        │
│    Email: jane@example.com              │
└─────────────────────────────────────────┘
```

### User Menu Actions

**For Active Users:**
- ✏️ Edit
- 🔒 Change Password
- ⏸️ **Deactivate** (makes user inactive but keeps in list)
- 🗑️ **Delete** (permanently removes from database)

**For Inactive Users:**
- ✏️ Edit
- 🔒 Change Password
- ▶️ **Activate** (makes user active again)
- 🗑️ **Delete** (permanently removes from database)

## Database Behavior

### getAllUsers() Method

**Now returns ALL users** (both active and inactive):

```dart
Future<List<UserModel>> getAllUsers() async {
  // Show ALL users (both active and inactive)
  final results = await db.query(
    'users',
    orderBy: 'created_at DESC',
  );
  return results.map((map) => UserModel.fromMap(map)).toList();
}
```

### Login Behavior

**Only active users can login** (login query still filters):

```dart
final results = await db.query(
  'users',
  where: 'username = ? AND is_active = 1',  // ✅ Only active users
  whereArgs: [username],
);
```

## Visual Indicators

### Active User Card
- ✅ Normal opacity (100%)
- ✅ Colored avatar based on role
- ✅ No special badges
- ✅ Menu shows "Deactivate" option

### Inactive User Card
- ⚠️ Grey avatar
- ⚠️ Strikethrough on name
- ⚠️ "Inactive" chip displayed
- ⚠️ Menu shows "Activate" option

**Code Location:** [users_screen.dart:371-382](lib/ui/screens/user/users_screen.dart#L371-L382)

```dart
if (!user.isActive)
  const Chip(
    label: Text('Inactive', style: TextStyle(fontSize: 10)),
    padding: EdgeInsets.all(4),
    backgroundColor: Colors.grey,
  ),
```

## Use Cases

### When to Use Deactivate:
- ✅ Temporary suspension (employee on leave)
- ✅ Preserve user history and audit trail
- ✅ User might return later
- ✅ Need to keep transaction records linked to user

### When to Use Delete:
- ✅ User account was created by mistake
- ✅ Test/demo accounts cleanup
- ✅ Compliance requirement to permanently remove user data
- ✅ User will never return

## Security Considerations

### Protection Against Accidental Deletion

1. **Self-Delete Prevention:**
   ```dart
   if (currentUser?.id == user.id) {
     // Cannot delete yourself
     return;
   }
   ```

2. **Last Admin Protection:**
   ```dart
   if (user.role == 'admin') {
     final adminCount = _users.where((u) => u.role == 'admin' && u.isActive).length;
     if (adminCount <= 1) {
       // Cannot delete last admin
       return;
     }
   }
   ```

3. **Confirmation Dialog:**
   - Requires explicit confirmation
   - Shows user name in confirmation
   - Red delete button for visual warning

### Login Security

**Inactive users cannot login:**
```dart
// Login query automatically filters inactive users
where: 'username = ? AND is_active = 1'
```

## Files Modified

1. [lib/services/auth/auth_service.dart](lib/services/auth/auth_service.dart)
   - Modified `getAllUsers()` to return all users (line 213-228)
   - Added `deactivateUser()` method (line 250-269)
   - Modified `deleteUser()` to perform hard delete (line 271-288)

2. [lib/ui/screens/user/users_screen.dart](lib/ui/screens/user/users_screen.dart)
   - `_toggleUserStatus()` for activate/deactivate (line 81-101)
   - `_deleteUser()` for permanent deletion (line 103-159)
   - UI displays inactive badge (line 371-382)

## Testing Checklist

### Deactivate/Activate Testing:
- [ ] Deactivate an active user
- [ ] Verify user still appears in list with "Inactive" badge
- [ ] Verify user has strikethrough name and grey avatar
- [ ] Verify user cannot login when inactive
- [ ] Click "Activate" to reactivate user
- [ ] Verify user becomes active again and can login

### Delete Testing:
- [ ] Try to delete your own account → Should show error
- [ ] Try to delete the last admin → Should show error
- [ ] Delete a regular user → Should require confirmation
- [ ] Confirm deletion → User should disappear from list
- [ ] Verify user is permanently removed from database
- [ ] Verify deleted user cannot login

## Summary

✅ **Deactivate** = User stays visible but inactive (can be reactivated)
✅ **Delete** = User is permanently removed from database (cannot be undone)
✅ **All users** (active and inactive) are shown in the users list
✅ **Safety checks** prevent accidental deletion of important accounts
✅ **Clear visual indicators** show user status

The implementation provides flexibility for different user management scenarios while maintaining data integrity and security.
