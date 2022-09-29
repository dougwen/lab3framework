// Framework software to give students who had trouble with the key pieces of the audio lab
// this software should do what is necessary to handle the DDS lab.  CODEC configuration,
// and it demonstrates some simple grabbing of characters from the user via UART



#include <stdio.h>
#include "platform.h"
#include "xil_printf.h"
#include "xiic.h"
#include "sleep.h"
#include "xparameters.h"
#include "xuartps.h"

// SSM2603 I2C address is 0011010 (0x1A) because CSB = 0 on the Zybo
#define SSM2603_IIC_ADDR 0x1A

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

int main()
{
    init_platform();

    xil_printf("Starting Lab3 Framework\n\r");
    xil_printf("Calling configure_codec()..\r\n");
    configure_codec();
    xil_printf("Now Entering a loop waiting for user commands...\r\n");

    // Flush out any old data that was in the UART from last time
    while (XUartPs_IsReceiveData(XPAR_PS7_UART_1_BASEADDR))
    	XUartPs_RecvByte(XPAR_PS7_UART_1_BASEADDR);

    while(1) {

    		char cmd = (char)XUartPs_RecvByte(XPAR_PS7_UART_1_BASEADDR);

    		switch(cmd) {

    		case 'U':
				xil_printf("Got U command, incrementing freq by 1000Hz\n\r");
				// obviously this doesn't come as part of the framework :)
    			break;
    		case 'u':
				xil_printf("Got u command, incrementing freq by 100Hz\n\r");
    			break;
    		default:
    			xil_printf("key not recognized\r\n");
    			break;
    		}
    	}
}

