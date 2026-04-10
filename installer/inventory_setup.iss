; ============================================================
;  Inventory Management System — Inno Setup 6 Script
;  Publisher : Binary Tech Station
;  Built for : Windows 10/11 x64
;
;  How to build:
;    1. flutter build windows --release
;    2. Open this file in Inno Setup 6 and press Compile (F9)
;       OR run: iscc "installer\inventory_setup.iss"
; ============================================================

#define AppName        "Inventory Management System"
#define AppVersion     "1.0.0"
#define AppPublisher   "Binary Tech Station"
#define AppURL         ""
#define AppExeName     "inventory.exe"
#define AppDataDir     "InventoryManagementSystem"
#define AppMutexName   "BinaryTechStation_IMS_SingleInstance"
#define BuildDir       "..\build\windows\x64\runner\Release"
#define InstallerBase  "IMS_Setup_v" + AppVersion

; ── Preprocessor sanity check ────────────────────────────────────────────────
#if !FileExists(BuildDir + "\inventory.exe")
  #error Release build not found. Run: flutter build windows --release
#endif

; =============================================================================
[Setup]
; ── Identity & versioning ────────────────────────────────────────────────────
AppId={{4B7F2A3C-9E1D-4C8B-A5F6-D2E3B4C7A891}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppURL}
AppSupportURL={#AppURL}
AppUpdatesURL={#AppURL}
VersionInfoVersion={#AppVersion}.0
VersionInfoCompany={#AppPublisher}
VersionInfoDescription={#AppName} Setup
VersionInfoCopyright=Copyright (C) 2026 {#AppPublisher}
VersionInfoProductName={#AppName}
VersionInfoProductVersion={#AppVersion}

; ── Install paths ────────────────────────────────────────────────────────────
DefaultDirName={autopf}\{#AppPublisher}\{#AppName}
DefaultGroupName={#AppPublisher}\{#AppName}
AllowNoIcons=yes

; ── Privileges & architecture ─────────────────────────────────────────────────
PrivilegesRequired=admin
PrivilegesRequiredOverridesAllowed=dialog
MinVersion=10.0.17763
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

; ── Output ───────────────────────────────────────────────────────────────────
OutputDir=Output
OutputBaseFilename={#InstallerBase}
SetupIconFile=..\windows\runner\resources\app_icon.ico

; ── Compression (LZMA ultra — best ratio, standard for professional apps) ───
Compression=lzma2/ultra64
SolidCompression=yes
LZMAUseSeparateProcess=yes
LZMANumBlockThreads=4

; ── Wizard appearance ────────────────────────────────────────────────────────
WizardStyle=modern
WizardSizePercent=120
DisableWelcomePage=no
DisableDirPage=no
DisableProgramGroupPage=no
DisableReadyPage=no
DisableFinishedPage=no

; ── Uninstall ────────────────────────────────────────────────────────────────
UninstallDisplayName={#AppName}
UninstallDisplayIcon={app}\{#AppExeName}
CreateUninstallRegKey=yes

; ── Misc reliability settings ────────────────────────────────────────────────
AppMutex={#AppMutexName}
CloseApplications=yes
CloseApplicationsFilter=*{#AppExeName}
RestartApplications=no
SetupLogging=yes
UsedUserAreasWarning=no

; ── Code signing stub (uncomment and fill when certificate is available) ─────
; SignTool=MySignTool sign /fd sha256 /td sha256 /tr http://timestamp.digicert.com /n "{#AppPublisher}" $f
; SignedUninstaller=yes

; =============================================================================
[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

; =============================================================================
[Messages]
WelcomeLabel1=Welcome to the [name] Setup Wizard
WelcomeLabel2=This wizard will guide you through the installation of [name/ver].%n%nThis is a fully offline application. All your data is stored locally on your computer and never leaves your device.%n%nClick Next to continue, or Cancel to exit.
FinishedHeadingLabel=Installation Complete
FinishedLabel=[name] has been successfully installed on your computer.%n%nYour data (database, license, backups) is stored in:%n%n    C:\ProgramData\{#AppDataDir}%n%nThis folder is preserved on uninstall so your data is always safe.%n%nClick Finish to close the Setup Wizard.
UninstallAppFullTitle=Uninstall {#AppName}

; =============================================================================
[CustomMessages]
english.AppDescription=A powerful offline inventory management solution for small and medium businesses.
english.ComponentsMain=Core Application (required)
english.ComponentsMainDesc=Installs the Inventory Management System application files.
english.TaskDesktop=Create a &Desktop shortcut
english.TaskStartMenu=Pin to &Start Menu
english.PreReqTitle=System Requirements Check
english.LaunchAfterInstall=&Launch {#AppName} now

; =============================================================================
[Types]
Name: "full";    Description: "Full Installation"
Name: "custom";  Description: "Custom Installation"; Flags: iscustom

[Components]
Name: "main"; Description: "{cm:ComponentsMain}"; \
  ExtraDiskSpaceRequired: 52428800; \
  Types: full custom; Flags: fixed

; =============================================================================
[Tasks]
Name: "desktopicon";   Description: "{cm:TaskDesktop}";   \
  GroupDescription: "Additional shortcuts:"; Flags: checkedonce
Name: "startmenuicon"; Description: "{cm:TaskStartMenu}"; \
  GroupDescription: "Additional shortcuts:"; Flags: checkedonce

; =============================================================================
[Dirs]
; ProgramData folders — full permission so the app can write DB/license without elevation
Name: "{commonappdata}\{#AppDataDir}";         Permissions: everyone-full
Name: "{commonappdata}\{#AppDataDir}\backups"; Permissions: everyone-full

; =============================================================================
[Files]
; ── Main executable ──────────────────────────────────────────────────────────
Source: "{#BuildDir}\{#AppExeName}"; \
  DestDir: "{app}"; Flags: ignoreversion; Components: main

; ── Flutter engine & plugin DLLs ─────────────────────────────────────────────
Source: "{#BuildDir}\flutter_windows.dll"; \
  DestDir: "{app}"; Flags: ignoreversion; Components: main
Source: "{#BuildDir}\*.dll"; \
  DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist; Components: main

; ── Flutter data bundle (assets, fonts, kernel snapshot, ICU) ────────────────
Source: "{#BuildDir}\data\*"; \
  DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: main

; ── License text (visible in Programs & Features) ────────────────────────────
Source: "LICENSE.txt"; \
  DestDir: "{app}"; Flags: ignoreversion; Components: main

; =============================================================================
[Icons]
; Start Menu group
Name: "{group}\{#AppName}"; \
  Filename: "{app}\{#AppExeName}"; \
  WorkingDir: "{app}"; \
  Comment: "{cm:AppDescription}"; \
  Tasks: startmenuicon

Name: "{group}\Uninstall {#AppName}"; \
  Filename: "{uninstallexe}"; \
  IconFilename: "{uninstallexe}"; \
  Comment: "Uninstall {#AppName}"

; Desktop shortcut (all users because we're admin install)
Name: "{commondesktop}\{#AppName}"; \
  Filename: "{app}\{#AppExeName}"; \
  WorkingDir: "{app}"; \
  Comment: "{cm:AppDescription}"; \
  Tasks: desktopicon

; =============================================================================
[Registry]
; Software registration (HKLM for system-wide install)
Root: HKLM; Subkey: "Software\{#AppPublisher}\{#AppName}"; \
  ValueType: string; ValueName: "InstallPath"; ValueData: "{app}"; \
  Flags: uninsdeletekey createvalueifdoesntexist
Root: HKLM; Subkey: "Software\{#AppPublisher}\{#AppName}"; \
  ValueType: string; ValueName: "Version"; ValueData: "{#AppVersion}"; \
  Flags: createvalueifdoesntexist
Root: HKLM; Subkey: "Software\{#AppPublisher}\{#AppName}"; \
  ValueType: string; ValueName: "DataPath"; \
  ValueData: "{commonappdata}\{#AppDataDir}"; \
  Flags: createvalueifdoesntexist
Root: HKLM; Subkey: "Software\{#AppPublisher}\{#AppName}"; \
  ValueType: string; ValueName: "Publisher"; ValueData: "{#AppPublisher}"; \
  Flags: createvalueifdoesntexist

; Add/Remove Programs — optional extra info that professional apps include
Root: HKLM; \
  Subkey: "Software\Microsoft\Windows\CurrentVersion\Uninstall\{#SetupSetting('AppId')}_is1"; \
  ValueType: string; ValueName: "DisplayVersion"; ValueData: "{#AppVersion}"; \
  Flags: createvalueifdoesntexist
Root: HKLM; \
  Subkey: "Software\Microsoft\Windows\CurrentVersion\Uninstall\{#SetupSetting('AppId')}_is1"; \
  ValueType: string; ValueName: "Publisher"; ValueData: "{#AppPublisher}"; \
  Flags: createvalueifdoesntexist
Root: HKLM; \
  Subkey: "Software\Microsoft\Windows\CurrentVersion\Uninstall\{#SetupSetting('AppId')}_is1"; \
  ValueType: dword; ValueName: "EstimatedSize"; ValueData: "51200"; \
  Flags: createvalueifdoesntexist

; =============================================================================
[Run]
; Launch app after install
Filename: "{app}\{#AppExeName}"; \
  Description: "{cm:LaunchAfterInstall}"; \
  Flags: nowait postinstall skipifsilent runasoriginaluser; \
  WorkingDir: "{app}"

; =============================================================================
[UninstallRun]
; Gracefully close the app before uninstalling
Filename: "taskkill.exe"; \
  Parameters: "/F /IM {#AppExeName}"; \
  Flags: runhidden skipifdoesntexist; \
  RunOnceId: "KillApp"

; =============================================================================
[UninstallDelete]
; Remove the install directory completely
Type: filesandordirs; Name: "{app}"
; NOTE: {commonappdata}\{#AppDataDir} is intentionally NOT deleted on uninstall
;       so the user's database, license, and backups are preserved through reinstalls.

; =============================================================================
[Code]

// ── Pre-install: check for existing running instance ─────────────────────────
function InitializeSetup(): Boolean;
begin
  Result := True;
  if CheckForMutexes('{#AppMutexName}') then begin
    MsgBox(
      '{#AppName} is currently running.'#13#10#13#10 +
      'Please close it before continuing with the installation.',
      mbError, MB_OK
    );
    Result := False;
  end;
end;

// ── Upgrade detection ─────────────────────────────────────────────────────────
function GetUninstallString(): String;
var
  sUnInstPath: String;
  sUnInstallString: String;
begin
  sUnInstPath := ExpandConstant(
    'Software\Microsoft\Windows\CurrentVersion\Uninstall\{#SetupSetting("AppId")}_is1'
  );
  sUnInstallString := '';
  if not RegQueryStringValue(HKLM, sUnInstPath, 'UninstallString', sUnInstallString) then
    RegQueryStringValue(HKCU, sUnInstPath, 'UninstallString', sUnInstallString);
  Result := sUnInstallString;
end;

function IsUpgrade(): Boolean;
begin
  Result := (GetUninstallString() <> '');
end;

function UninstallPreviousVersion(): Integer;
var
  sUnInstallString: String;
  iResultCode: Integer;
begin
  Result := 0;
  sUnInstallString := GetUninstallString();
  if sUnInstallString <> '' then begin
    sUnInstallString := RemoveQuotes(sUnInstallString);
    if Exec(sUnInstallString, '/SILENT /NORESTART /SUPPRESSMSGBOXES', '',
            SW_HIDE, ewWaitUntilTerminated, iResultCode) then
      Result := iResultCode;
  end;
end;

// Auto-uninstall previous version before installing new one
function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  Result := '';
  if IsUpgrade() then begin
    if UninstallPreviousVersion() <> 0 then
      Result := 'Failed to uninstall the previous version. Please uninstall it manually from Programs and Features.';
  end;
end;

// ── Post-install: ensure ProgramData folder ACLs are correct ─────────────────
procedure CurStepChanged(CurStep: TSetupStep);
var
  ResultCode: Integer;
begin
  if CurStep = ssPostInstall then begin
    // Ensure everyone has full access to data folder (icacls)
    Exec(
      ExpandConstant('{sys}\icacls.exe'),
      ExpandConstant('"{commonappdata}\{#AppDataDir}" /grant *S-1-1-0:(OI)(CI)F /T /Q'),
      '', SW_HIDE, ewWaitUntilTerminated, ResultCode
    );
  end;
end;

// ── Wizard: custom welcome subtitle ──────────────────────────────────────────
procedure InitializeWizard();
begin
  WizardForm.WelcomeLabel2.Font.Size := 9;
end;
