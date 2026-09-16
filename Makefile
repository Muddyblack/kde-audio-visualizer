.PHONY: help view view-h view-hyprland settings-hyprland install doctor pack tag shaders docs gallery
.DEFAULT_GOAL := help

gallery: ## capture tightly framed real QML screenshots at 2x resolution
	@python3 tools/capture_gallery.py $(GALLERY_FLAGS)

docs: ## build shared assets for the HTML demo; then open docs/website/index.html
	@python3 tools/sync_studio_assets.py

help: ## list targets
	@awk 'BEGIN{FS=":.*##"} /^[a-z][a-zA-Z0-9_-]+:.*##/ {printf "  make %-10s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

view: ## preview widget (planar)
	@if command -v nix >/dev/null 2>&1 && [ -f flake.nix ]; then \
	  nix run .#view; \
	else \
	  plasmoidviewer -a package -f planar; \
	fi

view-hyprland: ## run standalone Quickshell desktop widget (Ctrl+C to stop)
	@if command -v qs >/dev/null 2>&1; then \
	  bash "$(CURDIR)/hyprland/run.sh"; \
	else \
	  nix run .#view-hyprland; \
	fi

settings-hyprland: ## open settings in the running Quickshell widget
	@if command -v qs >/dev/null 2>&1; then \
	  qs -p "$(CURDIR)/shell.qml" ipc call settings open; \
	else \
	  nix run .#view-hyprland -- ipc call settings open; \
	fi

view-h: ## preview widget (horizontal)
	@if command -v nix >/dev/null 2>&1 && [ -f flake.nix ]; then \
	  nix run .#view -- horizontal; \
	else \
	  plasmoidviewer -a package -f horizontal; \
	fi

install: ## install test copy to local Plasma session
	@./test_install.sh

doctor: ## diagnose "the bars don't move" (paste output into issues)
	@bash package/contents/code/doctor.sh

test: ## run the full test suite (software rendering, no desktop needed)
	@if command -v qmltestrunner >/dev/null 2>&1; then \
	  python3 tests/run.py; \
	else \
	  nix develop --command python3 tests/run.py; \
	fi

parity: ## GPU shader vs Canvas on this desktop (opens a window; saves image pairs)
	@dir="$${TMPDIR:-/tmp}/audio-visualizer-parity"; mkdir -p "$$dir"; \
	runner="qmltestrunner"; command -v qmltestrunner >/dev/null 2>&1 || runner="nix develop --command qmltestrunner"; \
	status=0; for suite in rendererparity orbitparity; do \
	  QT_QPA_PLATFORMTHEME=generic QML_DISABLE_DISK_CACHE=1 $$runner -input tests/tst_$$suite.qml -import tests/stubs > "$$dir/$$suite.log" 2>&1 || status=1; \
	  rg 'parity |^FAIL|^Totals' "$$dir/$$suite.log"; \
	done; echo "logs: $$dir; Orbit captures: /tmp/orbit-*.png"; exit $$status

compare-html: ## render styles 6-15 from docs/website/index.html and the widget; writes report.html
	@out="$${TMPDIR:-/tmp}/audio-visualizer-html"; \
	run="python3 tools/compare_html_visualizers.py --reference qt --extended --output $$out"; \
	command -v qmltestrunner >/dev/null 2>&1 || run="nix develop --command $$run"; \
	$$run; status=$$?; echo "report: $$out/report.html"; exit $$status

shaders: ## rebuild every waveform shader family and its shared GLSL prelude
	@if command -v qsb >/dev/null 2>&1; then \
	  python3 package/contents/shaders/build_shaders.py; \
	else \
	  nix develop --command python3 package/contents/shaders/build_shaders.py; \
	fi

pack: ## build .plasmoid archive
	@if command -v nix >/dev/null 2>&1 && [ -f flake.nix ]; then \
	  nix run .#pack; \
	else \
	  ver=$$(grep -oE '"Version":[[:space:]]*"[^"]+"' package/metadata.json | head -1 | sed -E 's/.*"([^"]+)"$$/\1/'); \
	  name=$$(basename "$$PWD"); \
	  out="$$PWD/$$name-$$ver.plasmoid"; \
	  rm -f "$$out"; \
	  (cd package && zip -r "$$out" . -x '*.swp' '*~'); \
	  echo "wrote $$out"; \
	fi

tag: ## bump version, commit, tag, push
	@./tag.sh
