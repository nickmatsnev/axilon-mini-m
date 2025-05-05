!#/bin/bash

# first check that you have s2..png in each folder with ic_launcher.png
# put script in android/app/src/mani/res/ and run it from there
# sorry i am too lazy for a for loop
 cd mipmap-hdpi ; rm ic_launcher.png ; mv a2.png ic_launcher.png ; cd ..
  cd mipmap-mdpi ; rm ic_launcher.png ; mv a2.png ic_launcher.png ; cd ..
  cd mipmap-xhdpi ; rm ic_launcher.png ; mv a2.png ic_launcher.png ; cd ..
  cd mipmap-xxhdpi ; rm ic_launcher.png ; mv a2.png ic_launcher.png ; cd ..
  cd mipmap-xxxhdpi ; rm ic_launcher.png ; mv a2.png ic_launcher.png ; cd ..
