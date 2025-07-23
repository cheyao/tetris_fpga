VERILOG_SOURCES := src/Tetris.v src/bin_bcd_dl.v src/bin_bcd_lvl.v src/color_generator.v src/detect.v src/position_counter.v src/pseudo_random_number_generator.v src/ram_single.v src/synchronizer.v src/VGA_sync.v
VERILOG_SYNTH_SOURCES := src/vga2tmds.sv src/tmds_encoder.sv src/pll1.v src/pll2.v src/dvi.sv
OUTPUT := tetris
PACKAGE := CABGA256

all: sim

sim:
	verilator --trace -cc $(VERILOG_SOURCES) --exe tb_tetris.cpp
	LDFLAGS="-lX11" make -C obj_dir -f VTetris.mk VTetris

$(OUTPUT).json: $(VERILOG_SOURCES) $(VERILOG_SYNTH_SOURCES)
	rm -f $(OUTPUT).bit $(OUTPUT).config $(OUTPUT).json
	yosys -p 'synth_ecp5 -top top -json $@' $^

$(OUTPUT).config: $(OUTPUT).json icepi-zero.lpf
	nextpnr-ecp5 --25k --package $(PACKAGE) --lpf icepi-zero.lpf --json $< --textcfg $@ # 2> log.txt
	# cat log.txt | grep Device -A 28

$(OUTPUT).bit: $(OUTPUT).config
	ecppack $< $@

build: $(OUTPUT).bit

debug: build
	openFPGALoader -cft231X --pins=7:3:5:6 $(OUTPUT).bit

install: build
	openFPGALoader -cft231X --pins=7:3:5:6 $(OUTPUT).bit --write-flash

install-bitstream:
	openFPGALoader -cft231X --pins=7:3:5:6 $(OUTPUT).bit --write-flash

lint:
	verilator --lint-only -Wall -Wno-DECLFILENAME -Wno-WIDTHEXPAND $(VERILOG_SOURCES)

help:
	echo "Usage: make [option]"
	echo "Options:"
	echo "- install: install to flash"
	echo "- debug: install to chip's temp memory (bitstream lost on power loss)"
	echo "- build: builds the bitstream"
	echo "- clean: delete all temparary files"

clean:
	rm -f $(OUTPUT).bit $(OUTPUT).config $(OUTPUT).json
	# rm obj_dir/*.mk obj_dir/*.h obj_dir/*.cpp

.PHONY: build clean install
