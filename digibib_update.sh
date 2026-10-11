#!/ebrmain/bin/run_script -clear_screen -bitmap=unarchive_inv

for pid in $(pgrep -f $0); do
  if [ $pid -ne $$ ]; then
    kill -9 $pid
  fi
done

if [ ! -f /mnt/ext1/Downloads/pb-digibib.zip ]; then

  nagtpid="$(/ebrmain/bin/netagent status | grep '^nagtpid=' | sed -e 's/^..*=//')"
  if [ $nagtpid -eq 0 ]; then
    /ebrmain/bin/dialog 2 '' @NeedWiFiForService @Cancel @TurnOnWiFi
    if [ $? -eq 2 ]; then
      /ebrmain/bin/netagent net on
      if [ $? -eq 0 ]; then
        /ebrmain/bin/dialog 1 '' @WiFiOn @OK
      else
        /ebrmain/bin/dialog 3 '' @WiFiOff @OK
        exit 0
      fi
    else
      exit 0
    fi
  fi

  /ebrmain/bin/netagent connect
  if [ $? -ne 0 ]; then
    /ebrmain/bin/dialog 3 '' @WiFiNetworkIsNotWorking @OK
    exit 0
  fi

  /ebrmain/bin/curl -L --retry 10 --retry-delay 1 --retry-all-errors --create-dirs --output-dir /mnt/ext1/Downloads -O 'https://github.com/zigfield-jr/pb-digibib/releases/download/latest/pb-digibib.zip'
  if [ $? -ne 0 ]; then
    /ebrmain/bin/dialog 3 '' 'connection error, download via browser (then manually rerun script)' @Cancel @ContinueInBrowser
    if [ $? -eq 2 ]; then
      /usr/bin/browser.app 'https://github.com/zigfield-jr/pb-digibib/releases/download/latest/pb-digibib.zip' &
    fi
    exit 0
  fi

fi

/ebrmain/bin/dialog 2 '' @SuccessfullyDownloaded @Cancel @InstallNow
if [ $? -eq 2 ]; then
  unzip -o /mnt/ext1/Downloads/pb-digibib.zip -d /mnt/ext1
  if [ $? -eq 0 ]; then
    /ebrmain/bin/dialog 1 '' @Install_unpack_complete @OK
  else
    /ebrmain/bin/dialog 3 '' @Install_unpack_problems @OK
  fi
  rm -f /mnt/ext1/Downloads/pb-digibib.zip
fi
