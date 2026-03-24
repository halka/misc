echo "SHUTTER SOUND KILLER for Samsung"
adb devices
echo "Wait 5 Secconds"
sleep 5
echo "COMMENCE!"
adb shell settings put system csc_pref_camera_forced_shuttersound_key 0
echo "May Success! Check your Samsung's Phone!"
