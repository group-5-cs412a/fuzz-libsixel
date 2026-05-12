IMAGE_NAME ?= libsixel-fuzzer
INSTANCES ?= 4
TIMEOUT ?= 500
QEMUTIMEOUT ?= 5000
OUTPUT_DIR ?= $(CURDIR)/outputs

# Use the current user's UID and GID to avoid root-owned files in the output directory.
USER_ID ?= $(shell id -u)
GROUP_ID ?= $(shell id -g)
DOCKER_FLAGS = --rm -it --user $(USER_ID):$(GROUP_ID)

.PHONY: build fuzz fuzz-threaded fuzz-qemu clean

build:
	docker build -t $(IMAGE_NAME) .

fuzz:
	@run_dir="$(OUTPUT_DIR)/$$(date +%Y%m%d-%H%M%S)"; \
	mkdir -p "$$run_dir"; \
	printf 'Saving AFL++ outputs to %s\n' "$$run_dir"; \
	docker run $(DOCKER_FLAGS) -v "$$run_dir:/fuzzing/outputs" $(IMAGE_NAME) afl-fuzz -t $(TIMEOUT) -m none -i /fuzzing/seeds -o /fuzzing/outputs -- /usr/local/bin/sixel-harness

fuzz-threaded:
	@run_dir="$(OUTPUT_DIR)/$$(date +%Y%m%d-%H%M%S)"; \
	mkdir -p "$$run_dir"; \
	printf 'Saving AFL++ outputs to %s\n' "$$run_dir"; \
	docker run $(DOCKER_FLAGS) -v "$$run_dir:/fuzzing/outputs" $(IMAGE_NAME) /fuzzing/launch_fuzzer.sh $(INSTANCES) $(TIMEOUT)

fuzz-qemu:
	@run_dir="$(OUTPUT_DIR)/qemu-$$(date +%Y%m%d-%H%M%S)"; \
	mkdir -p "$$run_dir"; \
	printf 'Saving AFL++ QEMU outputs to %s\n' "$$run_dir"; \
	docker run $(DOCKER_FLAGS) -e AFL_USE_QASAN=1 -v "$$run_dir:/fuzzing/outputs" $(IMAGE_NAME) afl-fuzz -Q -t $(QEMUTIMEOUT) -m none -i /fuzzing/seeds -o /fuzzing/outputs -- /usr/local/bin/sixel-harness-qemu

clean:
	rm -rf "$(OUTPUT_DIR)"
