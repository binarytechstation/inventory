; ============================================================
;  Inventory Management System — Inno Setup Script
;  Run: flutter build windows --release
;  Then compile this script with Inno Setup Compiler
; ============================================================

#define AppName      "Inventory Management System"
#define AppVersion   "1.0.0"
#define AppPublisher "BiTS Projects"
#define AppExeName   "inventory.exe"
#define AppDataDir   "InventoryManagementSystem"
#define BuildDir     "..\build\windows\x64\runner\Release"

[Setup]
AppId={{F3A8C1D2-7B4E-4F9A-B2C3-8D5E6F7A1B2C}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} v{#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL=
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
AllowNoIcons=yes
; Require admin so we can write to ProgramData and Program Files
PrivilegesRequired=admin
OutputDir=Output
OutputBaseFilename=InventoryManagement_Setup_v{#AppVersion}
SetupIconFile=..\windows\runner\resources\app_icon.ico
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
WizardSizePercent=120
; Minimum Windows 10
MinVersion=10.0
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64os
UninstallDisplayIcon={app}\{#AppExeName}
UninstallDisplayName={#AppName}
; Create uninstall entry in Programs & Features
CreateUninstallRegKey=yes
; Show finish page with option to launch
DisableFinishedPage=no
; Prevent running multiple instances of setup
AppMutex=InventoryManagementSystemSetup

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon";    Description: "Create a &desktop shortcut";      GroupDescription: "Additional icons:"; Flags: checkedonce
Name: "startmenuicon";  Description: "Create a &Start Menu shortcut";   GroupDescription: "Additional icons:"; Flags: checkedonce

[Dirs]
; Create ProgramData folder with full permissions so the app can write DB/license files
Name: "{commonappdata}\{#AppDataDir}";          Permissions: everyone-full
Name: "{commonappdata}\{#AppDataDir}\backups";  Permissions: everyone-full

[Files]
; ── Main executable ──────────────────────────────────────────
Source: "{#BuildDir}\{#AppExeName}";            DestDir: "{app}"; Flags: ignoreversion

; ── Flutter engine DLLs ──────────────────────────────────────
Source: "{#BuildDir}\flutter_windows.dll";      DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildDir}\*.dll";                    DestDir: "{app}"; Flags: ignoreversion recursesubdirs skipifsourcedoesntexist

; ── Flutter data folder (assets, fonts, kernel snapshot) ─────
Source: "{#BuildDir}\data\*";                   DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
; Desktop shortcut — use commondesktop so it appears for all users under admin install
Name: "{commondesktop}\{#AppName}";  Filename: "{app}\{#AppExeName}"; IconFilename: "{app}\{#AppExeName}"; Tasks: desktopicon
; Start Menu
Name: "{group}\{#AppName}";          Filename: "{app}\{#AppExeName}"; IconFilename: "{app}\{#AppExeName}"; Tasks: startmenuicon
Name: "{group}\Uninstall {#AppName}"; Filename: "{uninstallexe}"

[Run]
; Launch app after install (optional checkbox on finish page)
Filename: "{app}\{#AppExeName}"; Description: "Launch {#AppName} now"; Flags: nowait postinstall skipifsilent

[UninstallRun]
; Nothing extra on uninstall — ProgramData (DB + license) is intentionally preserved

[UninstallDelete]
; Remove only the install directory; leave ProgramData data intact so the DB survives reinstalls
Type: filesandordirs; Name: "{app}"

[Registry]
; Store install path so the app can locate itself if needed
Root: HKLM; Subkey: "Software\{#AppPublisher}\{#AppName}"; ValueType: string; ValueName: "InstallPath"; ValueData: "{app}"; Flags: uninsdeletekey
Root: HKLM; Subkey: "Software\{#AppPublisher}\{#AppName}"; ValueType: string; ValueName: "Version";     ValueData: "{#AppVersion}"
Root: HKLM; Subkey: "Software\{#AppPublisher}\{#AppName}"; ValueType: string; ValueName: "DataPath";    ValueData: "{commonappdata}\{#AppDataDir}"

[Messages]
; Customise the finish label
FinishedLabel=Setup has finished installing [name] on your computer.%n%nThe application data (database, license file, backups) is stored in:%n%nC:\ProgramData\{#AppDataDir}%n%nThis folder is preserved on uninstall so your data is never lost.
