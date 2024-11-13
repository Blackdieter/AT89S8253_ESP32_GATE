ORG 0000H
    ; Other initialization code here
    JMP MAIN            ; Jump to main code after reset

ORG 0023H               ; UART Interrupt Vector Address
    LJMP RECEIVE_DATA   ; Jump to receive data handler on UART interrupt

MAIN:
    ; UART Initialization for Interrupt
    MOV TMOD, #20H      ; Timer1, Mode2 (8-bit auto-reload) for baud rate
    MOV TH1, #0FDH      ; Set baud rate to 9600 (assuming 11.0592 MHz clock)
    MOV SCON, #50H      ; 8-bit UART, REN enabled
    MOV IE, #10010000B  ; Enable Serial Interrupt (ES) and Global Interrupt (EA)
    SETB TR1            ; Start Timer1

    ; Other tasks that can run concurrently
    MOV P0,#0x00		;
    MOV P1,#0x00		;

		LOOP:
    MOV P1,#0xFF		;
    MOV P1,#0x00		;
	SJMP LOOP

RECEIVE_DATA:
    ; Clear interrupt flag
    CLR RI              ; Clear RI flag to acknowledge interrupt

    ; Store received character in the second register bank
    PUSH PSW            ; Save the current PSW
    MOV PSW, #10H       ; Select Bank 2 (registers R8 to R15)
    MOV A, SBUF         ; Move received byte from SBUF to Accumulator
    MOV R0, A           ; Store data in R0 of Bank 2 for further processing
    POP PSW             ; Restore original PSW

    ; Additional processing can be done here

    RETI                ; Return from interrupt
	

END