# FPGA TETRIS

Verilog implementation of the well-known Tetris game. The project is designed to be synthesized on FPGA and supports the VGA standard. The repository also includes simulation files, allows you to run the game in your local environment.

## Main components:

- **Tetris**: top-level module containing the game logic and instantiating the remaining modules. 
- **VGA_sync**: controls the VGA  signals. 
- **color_generator**: determines the displayed color in a combinational manner. 
- **ram_single**: single port memory with synchronous write and asynchronous read (should be synthesized as an MLAB block)

## Synthesis
To synthesize the design on an FPGA, special software is needed to arrange the circuit components on the board. I used Intel Quartus Prime for this purpose and tested the design on a DE1SoC Board.

## Simulation

**Prerequisites:**

- Verilator 
- g++ 
- CImg

**Simulation steps:**

Replace in Tetris.v lines tagged as `/* SYNTHESIS */` by lines tagged as `/* SIMULATION */`

`verilator -cc --trace Tetris.v --exe tb_tetris.cpp`

Replace the generated VTetris.mk file with the one from the repository.

`make -C obj_dir -f VTetris.mk VTetris`

To run the simulation:

`cd obj_dir`
`./VTetris`
