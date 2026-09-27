# Memoria monorepo tasks. On Windows run these from Git Bash (make is bundled
# with Git for Windows' SDK, or install it via `winget install GnuWin32.Make`).

FLUTTER ?= flutter
DART ?= dart
MOBILE := apps/mobile
RENDER := services/render
ENV_FILE := $(if $(wildcard $(MOBILE)/.env),--dart-define-from-file=.env,)

.PHONY: setup gen gen-watch l10n run-dev run-prod analyze format test test-mobile \
        test-render goldens render-dev render-docker supabase-start ci icons

## First-time setup: dependencies for app and render service, then codegen.
setup:
	cd $(MOBILE) && $(FLUTTER) pub get
	cd $(RENDER) && npm ci
	$(MAKE) gen

## Code generation (freezed, json, riverpod, drift) + localisations.
## Generated files are not committed.
gen: l10n
	cd $(MOBILE) && $(DART) run build_runner build

gen-watch:
	cd $(MOBILE) && $(DART) run build_runner watch

l10n:
	cd $(MOBILE) && $(FLUTTER) gen-l10n

## Run the dev flavor (fakes unless .env provides keys).
run-dev:
	cd $(MOBILE) && $(FLUTTER) run -t lib/main_dev.dart $(ENV_FILE)

run-prod:
	cd $(MOBILE) && $(FLUTTER) run -t lib/main_prod.dart $(ENV_FILE)

analyze:
	cd $(MOBILE) && $(FLUTTER) analyze
	cd $(RENDER) && npm run typecheck

format:
	cd $(MOBILE) && $(DART) format lib test

test: test-mobile test-render

test-mobile:
	cd $(MOBILE) && $(FLUTTER) test

## Re-record golden images after an intended visual change.
goldens:
	cd $(MOBILE) && $(FLUTTER) test --update-goldens --tags golden

test-render:
	cd $(RENDER) && npm test

render-dev:
	cd $(RENDER) && npm run dev

render-docker:
	docker build -f $(RENDER)/Dockerfile -t memoria-render .
	docker run --rm -p 8080:8080 --env-file $(RENDER)/.env memoria-render

supabase-start:
	supabase start

icons:
	python tools/brand/make_icons.py
	cd $(MOBILE) && $(DART) run flutter_launcher_icons && $(DART) run flutter_native_splash:create

ci: gen analyze test
