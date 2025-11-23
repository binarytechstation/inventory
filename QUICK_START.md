# Quick Start Guide

## Get Running in 5 Minutes

### Step 1: Install Dependencies

```bash
cd inventory
flutter pub get
```

### Step 2: Run the Application

```bash
flutter run -d windows
```

### Step 3: First Login

When the app starts:
1. You'll see the **Activation Screen** (no license yet)
2. Note the **Installation Code** displayed
3. Use the license generator to create a license (see below)
4. Or skip activation for development (it will fail gracefully and show activation screen)

**Default Login**:
- Username: `admin`
- Password: `admin`

### Step 4: Generate a Test License

Open a new terminal:

```bash
cd license_generator
dart license_generator.dart
```

Enter when prompted:
- **Customer ID**: `TEST001`
- **Customer Name**: `Test Customer`
- **Installation Code**: (copy from the activation screen)
- **License Type**: `perpetual` (press Enter)

Copy the generated license key and paste it into the activation screen.

### Step 5: Explore

After logging in:
- **Dashboard**: View KPIs and quick actions
- **Products**: Add your first product
- **Suppliers**: Add suppliers
- **Customers**: Add customers
- **Transactions**: Create purchases and sales
- **Users**: Manage users (Admin only)

## Development Workflow

### Hot Reload

While the app is running:
- Press `r` to hot reload (fast)
- Press `R` to hot restart (slower but more complete)
- Press `q` to quit

### View Logs

All console output appears in the terminal where you ran `flutter run`.

### Database Location

During development, the database is stored in:
```
C:\ProgramData\InventoryManagementSystem\inventory_db.db
```

To reset the database:
1. Stop the app
2. Delete the file above
3. Restart the app (new database will be created)

## Common Commands

```bash
# Get dependencies
flutter pub get

# Run app
flutter run -d windows

# Run tests
flutter test

# Build release
flutter build windows --release

# Clean build
flutter clean

# Analyze code
flutter analyze

# Format code
dart format .
```

## File Structure Overview

```
inventory/
├── lib/
│   ├── main.dart                      # App entry point
│   ├── core/                          # Core utilities
│   ├── data/                          # Database and models
│   ├── services/                      # Business logic
│   └── ui/                            # User interface
├── license_generator/                 # CLI tool for licenses
├── scripts/                           # Build scripts
├── test/                              # Unit tests
└── README.md                          # Documentation
```

## Next Steps

1. **Read the README.md** for full features and architecture
2. **Read DEVELOPER_GUIDE.md** for development details
3. **Explore the code** starting from `lib/main.dart`
4. **Try adding a feature** (see DEVELOPER_GUIDE.md)

## Troubleshooting

### App won't start
- Check `flutter doctor` for issues
- Ensure Windows is selected as device: `flutter devices`
- Try `flutter clean` then `flutter pub get`

### License activation fails
- Ensure installation code matches exactly
- Check license generator completed successfully
- Verify no typos when copying license key

### Database errors
- Delete database file and restart
- Location: `C:\ProgramData\InventoryManagementSystem\inventory_db.db`

### Can't login
- Default credentials: `admin` / `admin`
- If password was changed and forgotten, delete database and restart

## Getting Help

- Check README.md for detailed documentation
- Review DEVELOPER_GUIDE.md for technical details
- Check issues on GitHub
- Contact: support@yourcompany.com

---

Happy Coding! 🚀
