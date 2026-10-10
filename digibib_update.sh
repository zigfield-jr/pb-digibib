#!/ebrmain/bin/run_script -clear_screen -bitmap=unarchive_inv

for pid in $(pgrep -f $0); do
  if [ $pid -ne $$ ]; then
    kill -9 $pid
  fi
done

if [ -f /mnt/ext1/Downloads/pb-digibib.zip ]; then
  /ebrmain/bin/dialog 5 '' 'extract pb-digibib.zip (and delete file)' @Cancel @OK
  if [ $? -eq 2 ]; then
    unzip -o /mnt/ext1/Downloads/pb-digibib.zip -d /mnt/ext1
    if [ $? -eq 0 ]; then
      /ebrmain/bin/dialog 5 '' @Install_unpack_complete @OK
    else
      /ebrmain/bin/dialog 5 '' @Install_unpack_problems @OK
      exit 0
    fi
    rm -f /mnt/ext1/Downloads/pb-digibib.zip
  fi
else
  /ebrmain/bin/dialog 5 '' 'download pb-digibib.zip (then manually rerun script)' @Cancel @ContinueInBrowser
  if [ $? -eq 2 ]; then
    /usr/bin/browser.app 'https://github.com/zigfield-jr/pb-digibib/releases/download/latest/pb-digibib.zip' &
  fi
fi
