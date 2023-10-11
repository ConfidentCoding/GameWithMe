VERSION = 1.2.0
OUTPUT = GameWithMe-Portal-Roblox-Web-API-SDK-v$(VERSION).rbxmx
OUTPUT_TEST = GameWithMe-Portal-Roblox-Web-API-SDK-v$(VERSION)-Test.rbxlx

ROJO = rojo
ROJO_PROJECT = default.project.json
ROJO_PROJECT_SYNC = place.project.json
ROJO_PROJECT_TEST = test.project.json
SRC = src

find_files = $(shell find $(dir) -type f)

$(OUTPUT) : $(ROJO_PROJECT) $(foreach dir,$(SRC), $(find_files))
	$(ROJO) build --output $(OUTPUT)

.PHONY : clean serve test test-serve

clean :
	$(RM) $(OUTPUT) $(OUTPUT_TEST)

serve : $(ROJO_PROJECT_SYNC) $(OUTPUT)
	$(ROJO) serve $(ROJO_PROJECT_SYNC)

test : $(ROJO_PROJECT_TEST)
	$(ROJO) build $(ROJO_PROJECT_TEST) --output $(OUTPUT_TEST)

test-serve : $(ROJO_PROJECT_TEST)
	$(ROJO) serve $(ROJO_PROJECT_TEST)
