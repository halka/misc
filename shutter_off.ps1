echo "SHUTTER SOUND KILLER"
C:\Users\halka\AppData\Local\Microsoft\WinGet\Packages\Google.PlatformTools_Microsoft.Winget.Source_8wekyb3d8bbwe\platform-tools\adb.exe devices
echo "Wait 5 Secconds"
sleep 5
echo "COMMENCE!"
C:\Users\halka\AppData\Local\Microsoft\WinGet\Packages\Google.PlatformTools_Microsoft.Winget.Source_8wekyb3d8bbwe\platform-tools\adb.exe shell settings put system csc_pref_camera_forced_shuttersound_key 0
echo "May Success! Check your Samsung's Phone!"