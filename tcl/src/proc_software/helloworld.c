/******************************************************************************
*
* Copyright (C) 2009 - 2014 Xilinx, Inc.  All rights reserved.
*
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in
* all copies or substantial portions of the Software.
*
* Use of the Software is limited solely to applications:
* (a) running on a Xilinx device, or
* (b) that interact with a Xilinx device through a bus or interconnect.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
* XILINX  BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
* WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF
* OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
* SOFTWARE.
*
* Except as contained in this notice, the name of the Xilinx shall not be used
* in advertising or otherwise to promote the sale, use or other dealings in
* this Software without prior written authorization from Xilinx.
*
******************************************************************************/

/*
 * helloworld.c: simple test application
 *
 * This application configures UART 16550 to baud rate 9600.
 * PS7 UART (Zynq) is not initialized by this application, since
 * bootrom/bsp configures it to baud rate 115200
 *
 * ------------------------------------------------
 * | UART TYPE   BAUD RATE                        |
 * ------------------------------------------------
 *   uartns550   9600
 *   uartlite    Configurable only in HW design
 *   ps7_uart    115200 (configured by bootrom/bsp)
 */

#include <stdio.h>
#include "platform.h"
#include "xil_printf.h"
#include "xiic.h"
#include "sleep.h"
#include "xparameters.h"
#include "xllfifo.h"
#include "xuartps.h"

// SSM2603 I2C address is 0011010 (0x1A) because CSB = 0 on the Zybo
#define SSM2603_IIC_ADDR 0x1A

// We can store up to 4096 32-bit samples
#define MAX_AUDIO_SAMPLES 4096

// Global variables are fine here
u32 samplebuffer[MAX_AUDIO_SAMPLES]; // Store our waveform here
u32 numsamples;
int continuous_playback;

XLlFifo SamplesFifo;

// The SSM2603 expects both the device address and the data word to come in MSb->LSb order
void write_codec_register(u8 regnum, u16 regval)
{
	// Combine these into the 16-bit word we're going to send out, makes it easier to inspect w/ debugger
	u16 send_buf_u16 = (((regnum & 0x7F) << 9) | (regval & 0x1FF));

	// We must send two data bytes on each I2C transaction
	u8 send_buf[2];

	send_buf[1] = (u8)(send_buf_u16);
	send_buf[0] = (u8)(send_buf_u16 >> 8);

	// Returns # of bytes sent
	unsigned bytes_sent = XIic_Send(XPAR_IIC_0_BASEADDR, SSM2603_IIC_ADDR, send_buf, 2, XIIC_STOP);

	if (bytes_sent != 2) {
		xil_printf("Error sending to CODEC!");
	}
}

void configure_codec()
{
	 write_codec_register(15,0x00);
     usleep(1000);
     write_codec_register(6,0x30);
     write_codec_register(0,0x17);
     write_codec_register(1,0x17);
     write_codec_register(2,0x79);
     write_codec_register(3,0x79);
     write_codec_register(4,0x10);
     write_codec_register(5,0x00);
     write_codec_register(7,0x02);
     write_codec_register(8,0x00);
     usleep(75000);
     write_codec_register(9,0x01);
     write_codec_register(6,0x00);
}

//Returns 1 if sample sent, 0 if no room/need to try again.
void send_lrsample_blocking(u32 sample) {


	// wait until there is some room in the FIFO
	// while (!XLlFifo_iTxVacancy(&SamplesFifo));
	int space_avail = 0;
	while (space_avail < 4)
		space_avail = XLlFifo_ReadReg(XPAR_AXI_FIFO_0_BASEADDR, XLLF_TDFV_OFFSET);
	// write a word to the FIFO
	XLlFifo_WriteReg(XPAR_AXI_FIFO_0_BASEADDR, XLLF_TDFD_OFFSET, sample);


}


void send_sample_blocking(u16 sample) {

	u32 lrsample = sample;
	lrsample |= lrsample << 16;

	send_lrsample_blocking(lrsample);


}




void printmenu() {
    xil_printf("Welcome to the audio playback system \r\n");
    xil_printf("press L to load a file\r\n");
    xil_printf("press C to playback continuously followed by any key to stop\n\r");
    xil_printf("press S to play the sound once\n\r");
    xil_printf("press B to play a piercing beep for 2 seconds\n\r");

}

// the purpose of this command is to create a crazy noise.  I have the students tell me what the contents of this 
// signal are as we do an in-class exercise on the ILA.
void play_beep() {
	int samplect;
	int samples[16] = {0,2000,4000,6000, 8000, 10000, 12000, 14000, 16000, 14000, 12000, 10000, 8000, 6000, 4000, 2000};
	for (samplect = 0; samplect < 48000*2; samplect++)
	{
		send_sample_blocking(samples[samplect&0xf]);
	}
}

int main()
{
    init_platform();

    xil_printf("Starting Lab2 Instructor Sample\n\r");
    xil_printf("Calling configure_codec()..\r\n");

    configure_codec();

    xil_printf("Now playing ~6kHz tone for 5 sec on both channels to test everything....\r\n");
    for (int i = 0; i < 30000; i++) {
		send_sample_blocking(0);
		send_sample_blocking(7070);
		send_sample_blocking(10000);
		send_sample_blocking(7070);
		send_sample_blocking(0);
		send_sample_blocking(-7070);
		send_sample_blocking(-10000);
		send_sample_blocking(-7070);
    }


    while (XUartPs_IsReceiveData(XPAR_PS7_UART_0_BASEADDR))
    	XUartPs_RecvByte(XPAR_PS7_UART_0_BASEADDR);

    printmenu();



    while(1) {

    	// Poll the UART here to see if we've received a command from the user
    	if(XUartPs_IsReceiveData(XPAR_PS7_UART_0_BASEADDR)) {
    		// Read in the character
    		char cmd = (char)XUartPs_RecvByte(XPAR_PS7_UART_0_BASEADDR);

    		switch(cmd) {

    		case 'L':
    		case 'l':

				xil_printf("Got load command, send the file from your terminal client\n\r");

				numsamples = 0;
				for (int i=0;i<4;i++) {
					while(!XUartPs_IsReceiveData(XPAR_PS7_UART_0_BASEADDR));
					numsamples |= XUartPs_RecvByte(XPAR_PS7_UART_0_BASEADDR)<<(i*8);
				}
				printf("len=%d\n",numsamples);
				for (int i=0; i<numsamples*4; i++) {
					while(!XUartPs_IsReceiveData(XPAR_PS7_UART_0_BASEADDR));
					((u8*)samplebuffer)[i] = XUartPs_RecvByte(XPAR_PS7_UART_0_BASEADDR);
				}

				xil_printf("Successfully loaded %lu audio samples!\n\r", numsamples);
    			break;

    		case 'C':
    		case 'c':
				xil_printf("Playing back continuously!  Press any key to stop.\n\r");
		    	while (XUartPs_IsReceiveData(XPAR_PS7_UART_0_BASEADDR) == 0)
		    		for (int i=0; i < numsamples; i++) {
						send_lrsample_blocking(samplebuffer[i]);
					}
		    	XUartPs_RecvByte(XPAR_PS7_UART_0_BASEADDR);
		    	xil_printf("Key Pressed, Stopping Play\r\n");
    			break;

    		case 'S':
    		case 's':
    			continuous_playback = 0;
				xil_printf("Playing back a single sound!\n\r");
				for (int i=0; i < numsamples; i++) {
					send_lrsample_blocking(samplebuffer[i]);
				}
    			break;

    		case 'B':
    		case 'b':
    			xil_printf("playing Beep....");
    			play_beep();
    			xil_printf("Done\r\n");
    			break;

    		default:
    			xil_printf("key not recognized, printing menu\r\n");
    		    printmenu();
    			break;

    		}
    	}

    	// Send one file's worth each iteration of the big while loop.

    }
}
