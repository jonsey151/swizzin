#! /bin/bash

if [[ -d /srv/panel ]]; then
  echo "Updating panel"
  cd /srv/panel
  git reset HEAD --hard > /dev/null 2>&1
  git pull || panelreset=1
  if [[ $panelreset == 1 ]]; then
    echo "Updating the panel appears to have failed. This is probably my fault, not yours."
    echo ""
    read -n 1 -s -r -p "Press any key to forcefully reset the panel. Your custom entires, theme and language will be backed up and restored"
    echo ""
    cd /srv
    lang=$(grep \$language inc/localize.php | cut -d\' -f2)
    if [[ -f /srv/panel/db/.defaulted.lock ]]; then default=1; fi;
    cp -a /srv/panel/custom /tmp
    /usr/local/bin/swizzin/remove/panel.sh
    /usr/local/bin/swizzin/install/panel.sh
    mv /tmp/custom/* /srv/panel/custom/
    if [[ $default == 1 ]]; then
      bash /usr/local/bin/swizzin/panel/theme/themeSelect-defaulted
    fi
    bash /usr/local/bin/swizzin/panel/lang/langSelect-$lang
    systemctl restart php7.0-fpm
    systemctl restart nginx
  fi
fi