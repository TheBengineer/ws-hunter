; Inno Setup 6 script for the Windows installer of ws-hunter. CI builds it
; from the installed tree (see .github/workflows/windows.yml):
;
;   ISCC /DSrcDir=<dist\ws-hunter> /DAppVersion=<version> /DOutDir=<dir> ws-hunter.iss
;
; It installs beside, not over, a stock WS: its own folder, its own Start
; menu entries and uninstaller. Settings, logs and ALL.TXT are WS's own (in
; %LOCALAPPDATA%\WS), shared with a stock WS and left alone on uninstall.

#ifndef SrcDir
  #define SrcDir "dist\ws-hunter"
#endif
#ifndef AppVersion
  #define AppVersion "0.0.0-dev"
#endif
#ifndef OutDir
  #define OutDir "."
#endif

[Setup]
AppId={{6F0B3C52-9E1A-4D7B-A8C4-2E5D7F1B9A63}
AppName=WS (ws-hunter)
AppVersion={#AppVersion}
AppVerName=WS (ws-hunter) {#AppVersion}
AppPublisher=TheBengineer
AppPublisherURL=https://github.com/TheBengineer/ws-hunter
AppSupportURL=https://github.com/TheBengineer/ws-hunter/issues
AppUpdatesURL=https://github.com/TheBengineer/ws-hunter/releases
DefaultDirName={autopf}\ws-hunter
DefaultGroupName=WS (ws-hunter)
DisableProgramGroupPage=yes
; per user by default (no UAC prompt); the first page offers all users instead
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
LicenseFile=COPYING
SetupIconFile=icons\windows-icons\wsjtx.ico
UninstallDisplayIcon={app}\bin\ws.exe
OutputDir={#OutDir}
OutputBaseFilename=ws-hunter-windows-x64-setup
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "{#SrcDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\WS (ws-hunter)"; Filename: "{app}\bin\ws.exe"; WorkingDir: "{app}\bin"
Name: "{group}\WS-MAP (ws-hunter)"; Filename: "{app}\bin\wsmap.exe"; WorkingDir: "{app}\bin"
Name: "{group}\EME65 (ws-hunter)"; Filename: "{app}\bin\eme65.exe"; WorkingDir: "{app}\bin"
Name: "{group}\README"; Filename: "{app}\README-ws-hunter.txt"
Name: "{group}\{cm:UninstallProgram,WS (ws-hunter)}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\WS (ws-hunter)"; Filename: "{app}\bin\ws.exe"; WorkingDir: "{app}\bin"; Tasks: desktopicon

[Run]
Filename: "{app}\bin\ws.exe"; WorkingDir: "{app}\bin"; Description: "{cm:LaunchProgram,WS (ws-hunter)}"; Flags: nowait postinstall skipifsilent
