; OSS Sync Windows 安装程序脚本
; 使用 Inno Setup 6.x 编译
; 下载地址: https://jrsoftware.org/isdl.php

#define AppName "OSS Sync"
#define AppVersion "1.0.1"
#define AppPublisher "QianYuan1437"
#define AppURL "https://github.com/QianYuan1437/osssync"
#define AppExeName "osssync.exe"
; Flutter release 构建输出目录（相对于本脚本所在目录的上级）
#define BuildDir "..\build\windows\x64\runner\Release"

[Setup]
AppId={{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppURL}
AppSupportURL={#AppURL}
AppUpdatesURL={#AppURL}
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
AllowNoIcons=yes
; 输出安装包到 installer\output 目录
OutputDir=output
OutputBaseFilename=OSSSync_Setup_v{#AppVersion}
SetupIconFile=..\windows\runner\resources\app_icon.ico
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
; 最低 Windows 10
MinVersion=10.0
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog

[Languages]
Name: "chinesesimplified"; MessagesFile: "compiler:Languages\ChineseSimplified.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "创建桌面快捷方式"; GroupDescription: "附加图标:"; Flags: unchecked
Name: "startupicon"; Description: "开机自动启动"; GroupDescription: "启动选项:"; Flags: unchecked

[Files]
; 主程序及所有 DLL
Source: "{#BuildDir}\{#AppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildDir}\*.dll"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs
; Flutter 数据目录
Source: "{#BuildDir}\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"
Name: "{group}\卸载 {#AppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Registry]
; 开机自启动
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "{#AppName}"; ValueData: """{app}\{#AppExeName}"""; Flags: uninsdeletevalue; Tasks: startupicon

[Run]
Filename: "{app}\{#AppExeName}"; Description: "立即启动 {#AppName}"; Flags: nowait postinstall skipifsilent

[UninstallRun]
Filename: "taskkill"; Parameters: "/f /im {#AppExeName}"; Flags: runhidden

[Code]
// 安装前检查是否有正在运行的实例
function InitializeSetup(): Boolean;
var
  ResultCode: Integer;
begin
  Exec('taskkill', '/f /im {#AppExeName}', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  Result := True;
end;
