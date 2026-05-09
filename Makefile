IMAGE_NAME ?= libsixel-fuzzer
INSTANCES ?= 4
OUTPUT_DIR ?= $(CURDIR)/outputs

.PHONY: build fuzz fuzz-threaded clean

build:
	docker build -t $(IMAGE_NAME) .

fuzz:
	@run_dir="$(OUTPUT_DIR)/$$(date +%Y%m%d-%H%M%S)"; \
	mkdir -p "$$run_dir"; \
	printf 'Saving AFL++ outputs to %s\n' "$$run_dir"; \
	docker run --rm -it -v "$$run_dir:/fuzzing/outputs" $(IMAGE_NAME) afl-fuzz -t 5000 -m none -i /fuzzing/seeds -o /fuzzing/outputs -- /usr/local/bin/sixel-harness

fuzz-threaded:
	@run_dir="$(OUTPUT_DIR)/$$(date +%Y%m%d-%H%M%S)"; \
	mkdir -p "$$run_dir"; \
	printf 'Saving AFL++ outputs to %s\n' "$$run_dir"; \
	docker run --rm -it -v "$$run_dir:/fuzzing/outputs" $(IMAGE_NAME) /fuzzing/launch_fuzzer.sh $(INSTANCES)

clean:
	rm -rf "$(OUTPUT_DIR)"
