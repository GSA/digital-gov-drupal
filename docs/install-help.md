# Install PHP & Composer using homebrew

## Install PHP 8.3
Follow these steps to download php. You will download the base php package then install and reset to version 8.3.
```
brew install php
brew install php@8.3
# Change the version number in the following command to match the base php version number.
# To find the base version number run `php -v`
brew unlink php@8.4
brew link php@8.3
# Add path to zshrc for global access to 8.3 using php
echo 'export PATH="/opt/homebrew/opt/php@8.3/bin:$PATH"' >> ~/.zshrc
echo 'export PATH="/opt/homebrew/opt/php@8.3/sbin:$PATH"' >> ~/.zshrc
```
Confirm your version of php by opening a new terminal and running `php -v`.

## Install Composer 2.0
```
brew install composer
```
Confirm composer version using `composer -v`.
