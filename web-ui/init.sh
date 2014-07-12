curl -L -O https://github.com/mbostock/d3/releases/download/v3.4.10/d3.zip
unzip d3.zip -d public/libs/
rm d3.zip
rm public/libs/LICENSE
curl -L -O http://www.preludels.com/prelude-browser.js
mv prelude-browser.js public/libs/