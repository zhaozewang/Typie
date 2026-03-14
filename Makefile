.PHONY: generate build run clean setup-whisper

# Generate Xcode project (requires xcodegen: brew install xcodegen)
generate:
	xcodegen generate

# Build using xcodebuild
build: generate
	xcodebuild -project Typie.xcodeproj -scheme Typie -configuration Debug build

# Build directly with swiftc (no Xcode project needed)
build-direct:
	@mkdir -p build/Typie.app/Contents/MacOS
	@cp Typie/Info.plist build/Typie.app/Contents/
	@swiftc \
		-target arm64-apple-macos13.0 \
		-sdk $(shell xcrun --show-sdk-path) \
		-parse-as-library \
		-framework AppKit \
		-framework AVFoundation \
		-framework Carbon \
		-framework SwiftUI \
		-o build/Typie.app/Contents/MacOS/Typie \
		Typie/Models/AppStatus.swift \
		Typie/Models/AppConfig.swift \
		Typie/Models/WhisperModel.swift \
		Typie/Utils/ProcessRunner.swift \
		Typie/Utils/FileUtils.swift \
		Typie/Utils/Logger.swift \
		Typie/Services/ClipboardService.swift \
		Typie/Services/PermissionsService.swift \
		Typie/Services/AudioRecorder.swift \
		Typie/Services/WhisperTranscriptionService.swift \
		Typie/Services/TextInsertionService.swift \
		Typie/Services/HotkeyManager.swift \
		Typie/Services/ModelDownloadService.swift \
		Typie/Services/TranscriptionHistory.swift \
		Typie/Services/CorrectionDictionary.swift \
		Typie/Services/StreamingRecognitionService.swift \
		Typie/UI/SettingsView.swift \
		Typie/UI/MenuBarView.swift \
		Typie/UI/RecordingOverlay.swift \
		Typie/UI/CorrectionPopup.swift \
		Typie/App/AppState.swift \
		Typie/App/TypieApp.swift
	@echo "Built: build/Typie.app"

run: build-direct
	open build/Typie.app

clean:
	rm -rf build/
	rm -rf Typie.xcodeproj

# Setup whisper.cpp
setup-whisper:
	@echo "=== Setting up whisper.cpp ==="
	@mkdir -p ~/.typie/models
	@if [ ! -d /tmp/whisper.cpp ]; then \
		git clone https://github.com/ggerganov/whisper.cpp.git /tmp/whisper.cpp; \
	fi
	@cd /tmp/whisper.cpp && cmake -B build && cmake --build build --config Release -j
	@cp /tmp/whisper.cpp/build/bin/whisper-cli /usr/local/bin/whisper-cpp || \
		(echo "Cannot copy to /usr/local/bin. Try: sudo cp /tmp/whisper.cpp/build/bin/whisper-cli /usr/local/bin/whisper-cpp")
	@echo ""
	@echo "=== Download a model ==="
	@echo "For Chinese/multilingual, download the large-v3 model:"
	@echo "  cd /tmp/whisper.cpp && bash models/download-ggml-model.sh large-v3"
	@echo "  cp /tmp/whisper.cpp/models/ggml-large-v3.bin ~/.typie/models/"
	@echo ""
	@echo "For faster inference (lower accuracy), use medium:"
	@echo "  cd /tmp/whisper.cpp && bash models/download-ggml-model.sh medium"
	@echo "  cp /tmp/whisper.cpp/models/ggml-medium.bin ~/.typie/models/"
