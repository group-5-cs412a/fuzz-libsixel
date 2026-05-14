IMAGE_NAME ?= libsixel-fuzzer
INSTANCES ?= 4
TIMEOUT ?= 5000
OUTPUT_DIR ?= outputs

# Use the current user's UID and GID to avoid root-owned files in the output directory.
USER_ID ?= $(shell id -u)
GROUP_ID ?= $(shell id -g)
DOCKER_FLAGS = --rm -it --user $(USER_ID):$(GROUP_ID)

.PHONY: build fuzz fuzz-threaded fuzz-qemu fuzz-qemu-threaded clean plot

build:
	docker build -t $(IMAGE_NAME) .

fuzz:
	@run_dir="$(OUTPUT_DIR)/$$(date +%Y%m%d-%H%M%S)"; \
	mkdir -p "$$run_dir"; \
	printf 'Saving AFL++ outputs to %s\n' "$$run_dir"; \
	docker run $(DOCKER_FLAGS) -v "$$(realpath "$$run_dir"):/fuzzing/outputs" $(IMAGE_NAME) afl-fuzz -t $(TIMEOUT) -m none -i /fuzzing/seeds -o /fuzzing/outputs -- /usr/local/bin/sixel-harness

fuzz-threaded:
	@run_dir="$(OUTPUT_DIR)/$$(date +%Y%m%d-%H%M%S)"; \
	mkdir -p "$$run_dir"; \
	printf 'Saving AFL++ outputs to %s\n' "$$run_dir"; \
	docker run $(DOCKER_FLAGS) -v "$$(realpath "$$run_dir"):/fuzzing/outputs" $(IMAGE_NAME) /fuzzing/launch_fuzzer.sh $(INSTANCES) $(TIMEOUT) native

fuzz-qemu-threaded: TIMEOUT = 10000
fuzz-qemu-threaded:
	@if ! docker image inspect $(IMAGE_NAME) >/dev/null 2>&1; then echo "Error: Image $(IMAGE_NAME) not found. Run 'make build' first."; exit 1; fi
	@run_dir="$(OUTPUT_DIR)/qemu-threaded-$$(date +%Y%m%d-%H%M%S)"; \
	mkdir -p "$$run_dir"; \
	printf 'Saving AFL++ QEMU outputs to %s\n' "$$run_dir"; \
	docker run $(DOCKER_FLAGS) -v "$$(realpath "$$run_dir"):/fuzzing/outputs" $(IMAGE_NAME) /fuzzing/launch_fuzzer.sh $(INSTANCES) $(TIMEOUT) qemu

fuzz-qemu: TIMEOUT = 10000
fuzz-qemu:
	@if ! docker image inspect $(IMAGE_NAME) >/dev/null 2>&1; then echo "Error: Image $(IMAGE_NAME) not found. Run 'make build' first."; exit 1; fi
	@run_dir="$(OUTPUT_DIR)/qemu-$$(date +%Y%m%d-%H%M%S)"; \
	mkdir -p "$$run_dir"; \
	printf 'Saving AFL++ QEMU outputs to %s\n' "$$run_dir"; \
	ARCH=$$(uname -m); \
	if [ "$$ARCH" = "arm64" ] || [ "$$ARCH" = "aarch64" ]; then \
		echo "Note: QASan is disabled because it is often unstable on arm64/aarch64."; \
		QASAN_FLAG=""; \
	else \
		QASAN_FLAG="-e AFL_USE_QASAN=1"; \
	fi; \
	docker run $(DOCKER_FLAGS) $$QASAN_FLAG -v "$$(realpath "$$run_dir"):/fuzzing/outputs" $(IMAGE_NAME) afl-fuzz -Q -t $(TIMEOUT) -m none -i /fuzzing/seeds -o /fuzzing/outputs -- /usr/local/bin/sixel-harness-qemu

plot:
	@if [ -n "$(RUN_DIR)" ]; then \
		run_dir="$(RUN_DIR)"; \
	elif [ -d "$(OUTPUT_DIR)/main" ] || [ -d "$(OUTPUT_DIR)/default" ]; then \
		run_dir="$(OUTPUT_DIR)"; \
	else \
		run_dir=$$(ls -td $(OUTPUT_DIR)/*/ 2>/dev/null | head -1); \
		if [ -z "$$run_dir" ]; then echo "No runs found in $(OUTPUT_DIR)"; exit 1; fi; \
	fi; \
	abs_run_dir=$$(realpath "$$run_dir"); \
	rm -rf "$$abs_run_dir/plot"; \
	echo "Generating plots for $$abs_run_dir to $$abs_run_dir/plot"; \
	docker run $(DOCKER_FLAGS) -v "$$abs_run_dir:/fuzzing/outputs" $(IMAGE_NAME) /bin/bash -c " \
		if [ -f /fuzzing/outputs/fuzzer_stats ]; then \
			instance_path=/fuzzing/outputs; \
		elif [ -d /fuzzing/outputs/main ]; then \
			instance_path=/fuzzing/outputs/main; \
		elif [ -d /fuzzing/outputs/default ]; then \
			instance_path=/fuzzing/outputs/default; \
		else \
			instance_path=\$$(find /fuzzing/outputs -maxdepth 2 -name fuzzer_stats -exec dirname {} \; | head -n 1); \
		fi; \
		if [ -z \"\$$instance_path\" ]; then \
			echo \"Could not find an AFL instance directory in /fuzzing/outputs\"; \
			exit 1; \
		fi; \
		echo \"Plotting from: \$$instance_path\"; \
		afl-plot \"\$$instance_path\" /fuzzing/outputs/plot"


clean:
	rm -rf "$(OUTPUT_DIR)"
