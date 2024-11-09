;===============================================================
; UART Reception and Transmission Program in Full-Duplex Mode
;===============================================================
LED_GREEN    BIT P2.6               ; GREEN LED BIT

ORG 0000H
    ; Other initialization code here
    JMP MAIN            ; Jump to main code after reset

ORG 0023H               ; UART Interrupt Vector Address
    LJMP RECEIVE_DATA   ; Jump to receive data handler on UART interrupt
	
; Main Program
MAIN:
    ; UART Initialization for Interrupt
    MOV TMOD, #20H      ; Timer1, Mode2 (8-bit auto-reload) for baud rate
    MOV TH1, #0FDH      ; Set baud rate to 9600 (assuming 11.0592 MHz clock)
    MOV SCON, #50H      ; 8-bit UART, REN enabled
    MOV IE, #10010000B  ; Enable Serial Interrupt (ES) and Global Interrupt (EA)
    SETB TR1            ; Start Timer1
	    ; Other tasks that can run concurrently
		
	LOOP:
    MOV P1,#0xFF		;
	ACALL DELAY
    MOV P1,#0x00		;
	SJMP LOOP

	
DELAY:
		RET
	
;===============================================================
; Subroutine: RECEIVE_DATA
; Purpose: Receives a string, detects "Pxxxx" format, and echoes it
;===============================================================

RECEIVE_DATA:
	
	; Store received character in the second register bank
    PUSH PSW            ; Save the current PSW
	MOV PSW, #10H       ; Select Bank 2 (registers R8 to R15)

    ; Wait to receive 'P' character
    ACALL RECEIVE_CHAR     ; Get character from UART
    CJNE A, #'P', RECEIVE_DATA ; If not 'P', keep waiting
    
    ; 'P' detected, proceed to receive next 4 characters
    ACALL RECEIVE_CHAR     ; Get first number
    MOV R0, A              ; Store in R0
    ACALL RECEIVE_CHAR     ; Get second number
    MOV R1, A              ; Store in R1
    ACALL RECEIVE_CHAR     ; Get third number
    MOV R2, A              ; Store in R2
    ACALL RECEIVE_CHAR     ; Get fourth number
    MOV R3, A              ; Store in R3

    ; Send back received numbers over UART
    ACALL SEND_RESPONSE
	POP PSW             ; Restore original PSW

    RETI                ; Return from interrupt

;===============================================================
; Subroutine: RECEIVE_CHAR
; Purpose: Waits until a character is received in UART and loads it into A
;===============================================================

RECEIVE_CHAR:
    JNB RI, RECEIVE_CHAR   ; Wait until a character is received
    MOV A, SBUF            ; Move received byte to Accumulator
    CLR RI                 ; Clear RI for next reception
    RET

;===============================================================
; Subroutine: SEND_RESPONSE
; Purpose: Sends R0-R3 content back over UART as ASCII characters
;===============================================================

SEND_RESPONSE:
    MOV A, R0              ; Load first digit
    ACALL SEND_CHAR        ; Send character
    MOV A, R1              ; Load second digit
    ACALL SEND_CHAR        ; Send character
    MOV A, R2              ; Load third digit
    ACALL SEND_CHAR        ; Send character
    MOV A, R3              ; Load fourth digit
    ACALL SEND_CHAR        ; Send character
    RET

;===============================================================
; Subroutine: SEND_CHAR
; Purpose: Sends character in A over UART
;===============================================================

SEND_CHAR:
    MOV SBUF, A            ; Load A into SBUF to transmit
    JNB TI, $              ; Wait for transmission to complete
    CLR TI                 ; Clear transmit interrupt flag
    RET
	

END