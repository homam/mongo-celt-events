curl -L -O https://github.com/mbostock/d3/releases/download/v3.4.10/d3.zip
unzip -o d3.zip -d public/libs/
rm d3.zip
rm public/libs/LICENSE

curl -L -O http://www.preludels.com/prelude-browser.js
curl -L -O http://momentjs.com/downloads/moment.js
mv prelude-browser.js public/libs/
mv moment.js public/libs/

mkdir ma/data/
curl -H "x-version-course:1" -H "x-version-layout:1" -H "x-lang:en" -H "x-version-faq:1" -H "x-version-website:1" -H "x-env:release" -H "x-version-privacy:1" -H "x-version-courses:1" http://pretty.mobileacademy.com/courses > courses.json
mv courses.json ma/data/