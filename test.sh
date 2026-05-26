read -p "Какой пользователь прописан в задании? " webUser
read -p "Какой пароль пользователя прописан в задании? " passUser
sed -i "s/^\$username = .*/\$username = \"${webUser}\";/" /var/www/html/index.php
sed -i "s/^\$password = .*/\$password = \"${passUser}\";/" /var/www/html/index.php
