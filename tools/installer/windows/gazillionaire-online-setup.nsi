; Gazillionaire Online - Windows installer/uninstaller.
; Wraps ../install.ps1 (install/restore) in a normal double-clickable
; .exe. This does NOT install a new program - it patches an existing
; legitimate Steam copy of Gazillionaire, same contract as install.sh on
; macOS. See docs/multiplayer-architecture.md.
;
; Built with NSIS (makensis) via build-installer.sh, which stages this
; script's payload/ directory before invoking it. Cross-compiled from
; macOS/Linux - no Windows machine needed to produce the .exe, but it has
; NOT been run on a real Windows machine.

!include "MUI2.nsh"
!include "LogicLib.nsh"

Name "Gazillionaire Online"
OutFile "GazillionaireOnlineSetup.exe"
InstallDir "$LOCALAPPDATA\GazillionaireOnline"
RequestExecutionLevel admin ; Steam's install dir (Program Files) needs elevation to write
!define MUI_ABORTWARNING

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "English"

Section "Install"
  SetOutPath "$INSTDIR"
  File /r "payload\*.*"

  DetailPrint "Patching your local Steam install..."
  nsExec::ExecToStack '"powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "$INSTDIR\tools\installer\install.ps1" install'
  Pop $0
  Pop $1
  DetailPrint "$1"
  ${If} $0 != 0
    MessageBox MB_ICONSTOP|MB_OK "Install failed:$\r$\n$\r$\n$1$\r$\n$\r$\nIf Steam isn't installed at the default location, open PowerShell and run:$\r$\npowershell -ExecutionPolicy Bypass -File $\"$INSTDIR\tools\installer\install.ps1$\" install -Target $\"<path to your Gazillionaire.swf>$\""
  ${Else}
    MessageBox MB_ICONINFORMATION|MB_OK "Installed! Launch Gazillionaire from Steam as usual - look for the blue 'Play Online' button in the top-left corner to host or join a networked game.$\r$\n$\r$\n$1"
  ${EndIf}

  WriteUninstaller "$INSTDIR\Uninstall.exe"
SectionEnd

Section "Uninstall"
  DetailPrint "Restoring your original Gazillionaire.swf..."
  nsExec::ExecToStack '"powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "$INSTDIR\tools\installer\install.ps1" restore'
  Pop $0
  Pop $1
  DetailPrint "$1"
  ${If} $0 != 0
    MessageBox MB_ICONEXCLAMATION|MB_OK "Restore reported an issue (the game may already be unpatched):$\r$\n$\r$\n$1"
  ${Else}
    MessageBox MB_ICONINFORMATION|MB_OK "Restored your original Gazillionaire.swf."
  ${EndIf}

  RMDir /r "$INSTDIR"
SectionEnd
