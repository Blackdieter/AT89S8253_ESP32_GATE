;===============================================================
; UART Reception and Transmission Program in Full-Duplex Mode
;===============================================================

ORG 0000H             ; Start program from address 0000H

; UART Initialization for 9600 baud rate in Full-Duplex Mode
MOV TMOD, #20H        ; Timer 1 in Mode 2 (8-bit auto-reload)
MOV TH1, #0FDH        ; Set baud rate to 9600 (assuming 11.0592 MHz clock)
MOV SCON, #50H        ; Set UART mode 1, 8-bit UART, REN enabled
SETB TR1              ; Start Timer 1
UART_BUFFER: DS 4                   ; RESERVE 4 BYTES FOR ASCII CHARACTERS

; Main Program
MAIN:
    ACALL RECEIVE_DATA     ; Call subroutine to receive data
    SJMP MAIN              ; Repeat process indefinitely

;===============================================================
; Subroutine: RECEIVE_DATA
; Purpose: Receives a string, detects "Pxxxx" format, and echoes it
;===============================================================

RECEIVE_DATA:

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
	ACALL READ_EEPROM
    ACALL SEND_RESPONSE
    RET                    ; Return to MAIN loop

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
	
READ_EEPROM:
	MOV R4,#'9'
	MOV DPTR, #0x01            ; Set address pointer to EEPROM address 0x00
    MOV A, R4                  ; Load R0 (first digit of "1234") into accumulator
	MOVX @DPTR, A
	MOV DPTR, #0x01            ; Set address pointer to EEPROM address 0x00
	MOV A, R4              ; Load EEPROM data at DPTR address into A
	MOV R0, A
	RET

END


