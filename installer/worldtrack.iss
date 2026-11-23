; WORLDTRACK Windows kurulum betiği (Inno Setup 6)
; Derleme: iscc /DAppVersion=1.0.0 installer\worldtrack.iss

#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif

[Setup]
AppId={{8E2B6F7A-3C1D-4B8E-9F21-7A5C0D3E1B42}
AppName=WORLDTRACK
AppVersion={#AppVersion}
AppVerName=WORLDTRACK {#AppVersion}
AppPublisher=Furkan Baykal
AppPublisherURL=https://github.com/furkantr1923/worldtrack
AppSupportURL=https://github.com/furkantr1923/worldtrack
AppCopyright=© 2026 Furkan Baykal
VersionInfoVersion={#AppVersion}
VersionInfoCompany=Furkan Baykal
VersionInfoDescription=WORLDTRACK Kurulum
DefaultDirName={autopf}\WORLDTRACK
DefaultGroupName=WORLDTRACK
DisableProgramGroupPage=yes
OutputDir=..\out
OutputBaseFilename=WORLDTRACK-{#AppVersion}-Windows-Setup
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\WORLDTRACK.exe
UninstallDisplayName=WORLDTRACK
Compression=lzma2/max
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
WizardStyle=modern
CloseApplications=yes

[Languages]
Name: "turkish"; MessagesFile: "compiler:Languages\Turkish.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\WORLDTRACK"; Filename: "{app}\WORLDTRACK.exe"
Name: "{autodesktop}\WORLDTRACK"; Filename: "{app}\WORLDTRACK.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\WORLDTRACK.exe"; Description: "{cm:LaunchProgram,WORLDTRACK}"; Flags: nowait postinstall skipifsilent

; Not: Kişisel veriler (%APPDATA%\Furkan Baykal\WORLDTRACK) kaldırma sırasında
; bilerek silinmez; yeniden kurulumda seyahat arşivi korunur.
