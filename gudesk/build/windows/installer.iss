; GuDesk Windows Installer — Inno Setup 6 script
; Build: iscc /DAppVersion=1.4.8 installer.iss
;
; Prerequisites:
;   - Flutter Windows release build at flutter\build\windows\x64\runner\Release\
;   - Inno Setup 6+ installed (https://jrsoftware.org/isinfo.php)

#ifndef AppVersion
  #define AppVersion "1.4.8"
#endif

#define AppName        "GuDesk"
#define AppPublisher   "GuDesk Team"
#define AppURL         "https://gudesk.app"
#define AppExeName     "gudesk.exe"
; Paths are resolved relative to this script's directory
; (gudesk\build\windows\), which is 3 levels below the repo root — not 4.
; The original 4-up paths silently resolved to the parent of the checkout
; (D:\a\Gudesk\ instead of D:\a\Gudesk\Gudesk\), which is why OutputDir
; landed one level outside the repo and BuildDir pointed at a
; nonexistent Flutter build output on first run.
#define BuildDir       "..\..\..\flutter\build\windows\x64\runner\Release"
#define OutputDir      "..\..\..\target"

[Setup]
AppId={{A3F7C2B1-4E8D-4F9A-BB12-2C9E7D3F1A45}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppURL}
AppSupportURL={#AppURL}
AppUpdatesURL={#AppURL}
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
AllowNoIcons=yes
OutputDir={#OutputDir}
OutputBaseFilename=GuDesk-Setup-{#AppVersion}-x86_64
; flutter_assets only ships icon.svg (no .ico); use the actual compiled
; app icon that's already checked into the repo.
SetupIconFile=..\..\..\flutter\windows\runner\resources\app_icon.ico
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64os
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
UninstallDisplayIcon={app}\{#AppExeName}
MinVersion=10.0.17763

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "startupicon"; Description: "Start GuDesk with Windows"; GroupDescription: "Startup:"; Flags: unchecked

[Files]
; Main executable and Flutter data
Source: "{#BuildDir}\{#AppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildDir}\*.dll"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs
Source: "{#BuildDir}\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"
Name: "{group}\{cm:UninstallProgram,{#AppName}}"; Filename: "{uninstallexe}"
Name: "{commondesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Registry]
; URL scheme: gudesk://
Root: HKCU; Subkey: "Software\Classes\gudesk"; ValueType: string; ValueName: ""; ValueData: "URL:GuDesk Protocol"; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Classes\gudesk"; ValueType: string; ValueName: "URL Protocol"; ValueData: ""
Root: HKCU; Subkey: "Software\Classes\gudesk\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#AppExeName}"" ""%1"""
; Startup entry (added only if task selected)
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "{#AppName}"; ValueData: """{app}\{#AppExeName}"""; Tasks: startupicon; Flags: uninsdeletevalue

[Run]
Filename: "{app}\{#AppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(AppName,'&','&&')}}"; Flags: nowait postinstall skipifsilent

[UninstallRun]
Filename: "{app}\{#AppExeName}"; Parameters: "--quit"; Flags: skipifdoesntexist runhidden
