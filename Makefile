IMAGE_NAME ?= libsixel-fuzzer
INSTANCES ?= 4
OUTPUT_DIR ?= $(CURDIR)/outputs
SEED_PROFILE ?= fast
BROAD_LOADER ?= 0

# Use the current user's UID and GID to avoid root-owned files in the output directory.
USER_ID ?= $(shell id -u)
GROUP_ID ?= $(shell id -g)
DOCKER_FLAGS = --rm -it --user $(USER_ID):$(GROUP_ID)

.PHONY: build fuzz fuzz-threaded clean

build:
	docker build -t $(IMAGE_NAME) .

fuzz:
	@run_dir="$(OUTPUT_DIR)/$$(date +%Y%m%d-%H%M%S)"; \
	if [ "$(SEED_PROFILE)" = "extended" ]; then \
		seed_dir="/fuzzing/seeds_extended"; \
	else \
		seed_dir="/fuzzing/seeds"; \
	fi; \
	if [ "$(BROAD_LOADER)" = "1" ]; then \
		broad_loader_env="-e SIXEL_HARNESS_ALLOW_NONGIF=1"; \
	else \
		broad_loader_env=""; \
	fi; \
	mkdir -p "$$run_dir"; \
	printf 'Saving AFL++ outputs to %s\n' "$$run_dir"; \
	printf 'Using %s seed corpus\n' "$$seed_dir"; \
	docker run $(DOCKER_FLAGS) $$broad_loader_env -v "$$run_dir:/fuzzing/outputs" $(IMAGE_NAME) afl-fuzz -t 1000 -m none -G 65536 -i "$$seed_dir" -o /fuzzing/outputs -- /usr/local/bin/sixel-harness

fuzz-threaded:
	@run_dir="$(OUTPUT_DIR)/$$(date +%Y%m%d-%H%M%S)"; \
	mkdir -p "$$run_dir"; \
	printf 'Saving AFL++ outputs to %s\n' "$$run_dir"; \
	docker run $(DOCKER_FLAGS) -v "$$run_dir:/fuzzing/outputs" $(IMAGE_NAME) /fuzzing/scripts/launch_fuzzer.sh $(INSTANCES)

clean:
	rm -rf "$(OUTPUT_DIR)"
