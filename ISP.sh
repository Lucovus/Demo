#!/bin/bash

echo "Выберете гипервизор. Proxmox или WMware (пиши без скобок 1 или 2)"
read -p "2) - proxmox 1) - WMware" Hyperivoz
case $Hyperizor in
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
