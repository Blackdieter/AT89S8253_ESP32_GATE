ORG 0000H         ; Reset vector
    LJMP MAIN     ; Jump to the main program

ORG 0030H         ; Main program starts here
MAIN:
    MOV TMOD, #20H       ; Set Timer 1 in Mode 2 (8-bit auto-reload)
    MOV TH1, #-3         ; Load Timer 1 to generate 9600 baud rate (assuming 11.0592 MHz crystal)
    MOV SCON, #50H       ; Set UART in Mode 1 (8-bit UART) and enable reception
    SETB TR1             ; Start Timer 1

    ; Save numbers 1 to 6 in registers R0 to R5
    MOV R0, #'1'           ; Store 1 in R0
    MOV R1, #'2'           ; Store 2 in R1
    MOV R2, #'3'           ; Store 3 in R2
    MOV R3, #'4'           ; Store 4 in R3
    MOV R4, #'5'          ; Store 5 in R4
    MOV R5, #'6'           ; Store 6 in R5

CHECK_PIN:
    JB P3.2, CHECK_PIN   ; Wait until P3.2 is grounded (logic 0)

    MOV A, #'S'          ; SEND S OVER UART
    ACALL SEND_CHAR
    MOV A, R0            ; SEND 1 OVER UART
    ACALL SEND_CHAR
    MOV A, R1            ; SEND 2 OVER UART
    ACALL SEND_CHAR
    MOV A, R2            ; SEND 3 OVER UART
    ACALL SEND_CHAR
    MOV A, R3            ; SEND 4 OVER UART
    ACALL SEND_CHAR
    MOV A, R4            ; SEND 5 OVER UART
    ACALL SEND_CHAR
    MOV A, R5            ; SEND 6 OVER UART
    ACALL SEND_CHAR
    MOV A, #0x0D         ; Load ASCII for Carriage Return (CR)
    ACALL SEND_CHAR      ; Send CR via UART
    MOV A, #0x0A         ; Load ASCII for Line Feed (LF)
    ACALL SEND_CHAR      ; Send LF via UART

    SJMP CHECK_PIN       ; Go back to checking the pin

	SEND_CHAR:
		MOV SBUF, A            ; Load A into SBUF to transmit
		JNB TI, $              ; Wait for transmission to complete
		CLR TI                 ; Clear transmit interrupt flag
		RET

END
