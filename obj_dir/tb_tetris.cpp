#include <stdlib.h>
#include <iostream>
#include "CImg.h"
#include "verilated_vcd_c.h"
#include "verilated.h"
#include "VTetris.h"
#include "VTetris___024root.h"

uint64_t sim_time = 0;

using namespace cimg_library;

void tick(VTetris *dut, VerilatedVcdC* vcd) {
    do {
        dut->CLOCK_50 ^= 1;
        dut->eval();
        //uncomment the line below to create a waveform
        //vcd->dump(sim_time++);
    } while(dut->CLOCK_50);
}

void update_keys(VTetris *dut, CImgDisplay *dsp){
    dut->KEY = (int)!dsp->is_keyARROWRIGHT() + 2 * (int)!dsp->is_keyARROWLEFT() 
                    + 4 * (int)!dsp->is_keyARROWUP() + 8 * (int)!dsp->is_keyARROWDOWN();
}

int main(){

    VTetris *dut = new VTetris;

    Verilated::traceEverOn(true);
    VerilatedVcdC *v_vcd = new VerilatedVcdC;
    dut->trace(v_vcd, 10);
    v_vcd->open("waveform.vcd");

    int w = 640;
    int h = 480;
    CImg<unsigned char> screen(w, h, 1, 3);
    CImgDisplay dsp(w, h, "Tetris", 0);

    const unsigned char blue[] = {0, 130, 255};
    const unsigned char orange[] = {255, 100, 50};
    bool durna_zmienna;

    while(!dsp.is_closed() && !dsp.is_keyESC()){

        while(dut->VGA_VS || !dut->VGA_BLANK_N){
            update_keys(dut, &dsp);
            tick(dut, v_vcd);
        }
        for(int i = 0; i< h; i++){
            for(int j = 0; j<w; j++){
                screen(j, i, 0, 0) = dut->VGA_R;
                screen(j, i, 0, 1) = dut->VGA_G;
                screen(j, i, 0, 2) = dut->VGA_B;

                update_keys(dut, &dsp);
                tick(dut, v_vcd);
            }
            while(!dut->VGA_BLANK_N){
                
                update_keys(dut, &dsp);
                tick(dut, v_vcd);
            }
        }
        
        if(dsp.is_keyA()) durna_zmienna = 1;

        dsp.display(screen);
        dsp.wait();
    }

    dut->final();
    v_vcd->close();
    delete dut;
    return 0;
}