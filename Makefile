#
# This file is used by developers to build release packages
#

GITREMOTE=https://github.com/roundcube/roundcubemail.git
GITBRANCH=master
GPGKEY=devs@roundcube.net
VERSION=1.7-git
SEDI=sed -i
WHICH=which

UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
    SEDI=sed -i ''
    WHICH=which -s
endif

all: clean complete dependent framework

complete: roundcubemail-git
	cp -RH roundcubemail-git roundcubemail-$(VERSION)
	(cd roundcubemail-$(VERSION); jq '.require += {"kolab/net_ldap3": "~1.1.1"} | del(.suggest."kolab/net_ldap3")' --indent 4 composer.json-dist > composer.json)
	(cd roundcubemail-$(VERSION); php /tmp/composer.phar install --prefer-dist --no-dev --ignore-platform-reqs --no-interaction)
	(cd roundcubemail-$(VERSION); bin/install-jsdeps.sh --force)
	(cd roundcubemail-$(VERSION); bin/jsshrink.sh program/js/publickey.js; bin/jsshrink.sh plugins/managesieve/codemirror/lib/codemirror.js)
	(cd roundcubemail-$(VERSION); rm -f jsdeps.json bin/install-jsdeps.sh *.orig; rm -rf temp/js_cache)
	(cd roundcubemail-$(VERSION); rm -rf vendor/pear/*/tests vendor/*/*/.git* vendor/*/*/.travis* vendor/*/*/phpunit.xml.dist vendor/pear/console_commandline/docs vendor/pear/net_ldap2/doc vendor/bacon/bacon-qr-code/test vendor/dasprid/enum/test)
	tar czf roundcubemail-$(VERSION)-complete.tar.gz roundcubemail-$(VERSION)
	rm -rf roundcubemail-$(VERSION)

dependent: roundcubemail-git
	cp -RH roundcubemail-git roundcubemail-$(VERSION)
	tar czf roundcubemail-$(VERSION).tar.gz roundcubemail-$(VERSION)
	rm -rf roundcubemail-$(VERSION)
 
framework: roundcubemail-git /tmp/phpDocumentor.phar
	cp -r roundcubemail-git/program/lib/Roundcube roundcube-framework-$(VERSION)
	(cd roundcube-framework-$(VERSION); php /tmp/phpDocumentor.phar -d . -t ./doc --title="Roundcube Framework" --defaultpackagename="Framework" --template="clean")
	(cd roundcube-framework-$(VERSION); rm -rf doc/phpdoc-cache* .phpdoc)
	tar czf roundcube-framework-$(VERSION).tar.gz roundcube-framework-$(VERSION)
	rm -rf roundcube-framework-$(VERSION)

sign:
	gpg -u $(GPGKEY) -a --detach-sig roundcubemail-$(VERSION).tar.gz
	gpg -u $(GPGKEY) -a --detach-sig roundcubemail-$(VERSION)-complete.tar.gz
	gpg -u $(GPGKEY) -a --detach-sig roundcube-framework-$(VERSION).tar.gz

verify:
	gpg -v --verify roundcubemail-$(VERSION).tar.gz.asc roundcubemail-$(VERSION).tar.gz
	gpg -v --verify roundcubemail-$(VERSION)-complete.tar.gz.asc roundcubemail-$(VERSION)-complete.tar.gz
	gpg -v --verify roundcube-framework-$(VERSION).tar.gz.asc roundcube-framework-$(VERSION).tar.gz

shasum:
	shasum -a 256 roundcubemail-$(VERSION).tar.gz roundcubemail-$(VERSION)-complete.tar.gz roundcube-framework-$(VERSION).tar.gz

roundcubemail-git: buildtools
	git clone --branch=$(GITBRANCH) --depth=1 $(GITREMOTE) roundcubemail-git
	(cd roundcubemail-git; bin/jsshrink.sh; bin/updatecss.sh; bin/cssshrink.sh)
	(cd roundcubemail-git/skins/elastic; \
		lessc --clean-css="--s1 --advanced" styles/styles.less > styles/styles.min.css; \
		lessc --clean-css="--s1 --advanced" styles/print.less > styles/print.min.css; \
		lessc --clean-css="--s1 --advanced" styles/embed.less > styles/embed.min.css)
	(cd roundcubemail-git/bin; rm -f transifexpull.sh package2composer.sh)
	(cd roundcubemail-git; find . -name '.gitignore' | xargs rm -f)
	(cd roundcubemail-git; find . -name '.travis.yml' | xargs rm -f)
	(cd roundcubemail-git; rm -rf tests plugins/*/tests .git* .tx* .ci* .editorconfig* index-test.php Dockerfile Makefile)
	(cd roundcubemail-git; $(SEDI) 's/1.7-git/$(VERSION)/' index.php public_html/index.php program/include/iniset.php program/lib/Roundcube/bootstrap.php)
	(cd roundcubemail-git; $(SEDI) 's/# Unreleased/# Release $(VERSION)'/ CHANGELOG.md)

buildtools: /tmp/composer.phar
	npm install uglify-js
	npm install lessc
	npm install less-plugin-clean-css
	npm install csso-cli
	@$(WHICH) jq || echo "!!!!!! Please install jq (https://stedolan.github.io/jq/) !!!!!!"

/tmp/composer.phar:
	curl -sS https://getcomposer.org/installer | php -- --install-dir=/tmp/

/tmp/phpDocumentor.phar:
	curl -sSL https://phpdoc.org/phpDocumentor.phar -o /tmp/phpDocumentor.phar

clean:
	rm -rf roundcubemail-git
	rm -rf roundcubemail-$(VERSION)*
