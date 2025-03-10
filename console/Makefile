export PATH := node_modules/.bin:$(PATH)
DIST_PATH ?= ./static/dist
BUCKET_NAME ?= graphql-engine-cdn.hasura.io
VERSION ?= $(shell ../scripts/get-version.sh)
NODE_OPTIONS=--max-old-space-size=3072

all: deps build gzip-assets gcloud-cp-stable gcloud-set-metadata

deps:
	NODE_OPTIONS=$(NODE_OPTIONS) npm install

ci-deps:
	if [ ! -d "node_modules" ]; then NODE_OPTIONS=$(NODE_OPTIONS) npm ci; fi

build:
	NODE_OPTIONS=$(NODE_OPTIONS) npm run build

jest:
	npm run jest -- --runInBand

test:
	npm run dev & npm run test

gzip-assets:
	gzip $(DIST_PATH)/*.js
	gzip $(DIST_PATH)/*.css
	mv $(DIST_PATH)/main.js.gz $(DIST_PATH)/main.js
	mv $(DIST_PATH)/vendor.js.gz $(DIST_PATH)/vendor.js
	mv $(DIST_PATH)/main.css.gz $(DIST_PATH)/main.css

# to be run inside circle-ci
ci-copy-assets:
	mkdir -p /build/_console_output
	cp $(DIST_PATH)/* /build/_console_output/
	echo "$(VERSION)" > /build/_console_output/version.txt

gcloud-cp-stable:
	gsutil cp -r $(DIST_PATH)/main.css gs://$(BUCKET_NAME)/console/$(VERSION)/main.css
	gsutil cp -r $(DIST_PATH)/main.js gs://$(BUCKET_NAME)/console/$(VERSION)/main.js
	gsutil cp -r $(DIST_PATH)/vendor.js gs://$(BUCKET_NAME)/console/$(VERSION)/vendor.js

gcloud-set-metadata:
	gsutil setmeta -h "Content-Type: application/javascript" gs://$(BUCKET_NAME)/console/$(VERSION)/*.js
	gsutil setmeta -h "Content-Type: text/css" gs://$(BUCKET_NAME)/console/$(VERSION)/*.css
	gsutil setmeta -h "Content-Encoding: gzip" gs://$(BUCKET_NAME)/console/$(VERSION)/*

server-build: node_modules $(DIST_PATH)/common
	rm -rf "$(DIST_PATH)/versioned"
	NODE_OPTIONS=$(NODE_OPTIONS) npm run build
	mkdir -p "$(DIST_PATH)/versioned"
	cp "$(DIST_PATH)"/*.js "$(DIST_PATH)"/*.css "$(DIST_PATH)/versioned/"
	gzip -r -f "$(DIST_PATH)/versioned"

$(DIST_PATH)/common:
	mkdir -p $(DIST_PATH)
	gsutil -m cp -r gs://$(BUCKET_NAME)/console/assets/common "$(DIST_PATH)"
	touch $@

node_modules: package.json package-lock.json
	NODE_OPTIONS=(NODE_OPTIONS) npm ci
