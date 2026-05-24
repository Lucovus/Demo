#!/bin/bash

echo "Выберете гипервизор. Proxmox или WMware (пиши ТОЛЬКО 1 или 2)"
read -p -r "2) - proxmox 1) - WMware " Hypevisor
case $Hyperisor in
  1)
    int_type="enp33"
    ;;
  2)
    int_type="enp7s1"
    ;;
  *)
    echo "Неправльно. напиши 1 или 2"
    exit 1 
    ;;
esac

echo "Используется $int_type"
