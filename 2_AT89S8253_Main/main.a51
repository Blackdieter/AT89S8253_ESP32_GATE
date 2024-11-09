DATA_7SEG    EQU P0                 ; 7-SEGMENT DISPLAY CONNECTED TO PORT 0
LED1         BIT P2.2               ; LED1 CONTROL BIT
LED2         BIT P2.3               ; LED2 CONTROL BIT FOR ENABLING THE 2ND 7-SEGMENT
BUTTON1      BIT P3.2               ; BUTTON 1 INPUT ON PORT 3.2
BUTTON2      BIT P3.3               ; BUTTON 2 INPUT ON PORT 3.3
LED_GREEN    BIT P2.6               ; GREEN LED BIT
LED_RED      BIT P2.7               ; RED LED BIT
BUZZER       BIT P2.4
INDEX        EQU 0x30				; COUNT FOR NUMBER OF DIGITS ENTERED

UART_BUFFER: DS 4                   ; RESERVE 4 BYTES FOR ASCII CHARACTERS

ORG 00H
MAIN:
    ; INITIALIZE UART FOR 9600 BAUD RATE
    MOV TMOD, #20H                ; TIMER 1 IN MODE 2 (8-BIT AUTO-RELOAD)
    MOV TH1, #0FDH                ; SET BAUD RATE TO 9600 (11.0592 MHZ CLOCK)
    MOV SCON, #50H                ; UART MODE 1, 8-BIT UART, REN ENABLED
    SETB TR1                      ; START TIMER 1

    ; CONFIGURE PINS
    CLR BUZZER
    CLR LED_RED
    CLR LED_GREEN                 ; TURN OFF GREEN LED INITIALLY
	INIT:
	MOV P1, #0xFF				  ; TURN ON ALL SUBMITTED LED
    SETB LED2
    SETB BUTTON1                  ; SET BUTTON1 AS INPUT
    SETB BUTTON2                  ; SET BUTTON2 AS INPUT
	
    ; CONFIGURE PARAMETERS
    MOV DPTR, #MA7SEG-1           ; INITIALIZE DPTR WITH ADDRESS OF MA7SEG -1
    CLR A                         ; CLEAR ACCUMULATOR
    
    ; DISPLAY INITIAL VALUE (8) ON 7-SEGMENT
    MOV DATA_7SEG, #0x89
    MOV INDEX, #0
    SJMP LOOP                     ; JUMP TO MAIN LOOP

LOOP:
    ; CHECK BUTTON STATES
    JNB BUTTON1, INCREMENT_DISPLAY  ; IF BUTTON1 PRESSED, GO TO INCREMENT_DISPLAY
    JNB BUTTON2, SAVE_NUMBER        ; IF BUTTON2 PRESSED, GO TO SAVE_NUMBER
	; CHECK IF UART DATA IS RECEIVED
    JNB RI, LOOP            ; IF RI IS NOT SET, NO NEW UART DATA
    ACALL RECEIVE_DATA              ; IF RI IS SET, CALL RECEIVE_DATA TO PROCESS UART INPUT
	
INCREMENT_DISPLAY:
    CLR LED2                       ; DISABLE 7-SEGMENT DISPLAY #2
    CLR A                          ; CLEAR ACCUMULATOR
    INC DPTR                       ; INCREMENT DPTR FOR NEXT VALUE
    MOVC A, @A+DPTR                ; LOAD NEXT PATTERN FROM MA7SEG
    MOV DATA_7SEG, A               ; DISPLAY NUMBER ON 7-SEGMENT
	ACALL BUZZER_ON				   ; BUZZ AND DELAY

    ; CHECK IF VALUE IS NOT 0x90 (9)
    CJNE A, #0x90, LOOP
    ; RESET DPTR TO START OF MA7SEG AFTER REACHING 9
    MOV DPTR, #MA7SEG-1
    SJMP LOOP

SAVE_NUMBER:
    ; SHIFT NUMBERS IN REGISTERS TO MAKE ROOM FOR NEW VALUE IN R0
    MOV A, R2
    MOV R3, A                     ; MOVE PREVIOUS R2 TO R3
    MOV A, R1
    MOV R2, A                     ; MOVE PREVIOUS R1 TO R2
    MOV A, R0
    MOV R1, A                     ; MOVE PREVIOUS R0 TO R1
    MOV R0, DATA_7SEG             ; STORE NEW NUMBER IN R0

    ; DISPLAY NUMBER 0 ON 7-SEGMENT
    CLR A
    MOV DPTR, #MA7SEG             ; RESET DPTR TO START OF MA7SEG
    MOVC A, @A+DPTR
    MOV DATA_7SEG, A              ; DISPLAY NEXT VALUE ON 7-SEGMENT
	ACALL CHECK_INDEX			  ; DISPLAY THE LED FOR SUBMITTED VALUE
	ACALL BUZZER_ON				  ; BUZZ AND DELAY

    ; CHECK IF INDEX IS 4
    INC INDEX
    MOV A, INDEX
    CJNE A, #4, LOOP              ; IF NOT, GO BACK TO LOOP

    ; COMPARISON OF ENTERED NUMBERS WITH PASSWORD (1, 1, 1, 1)
    ; CONVERT 7-SEGMENT CODES TO ASCII
    ACALL SEG_TO_ASCII

    ; TRANSMIT "****" AS STRING OVER UART
    MOV SBUF, #32                 ; SEND SPACE CHARACTER
    ACALL WAIT_UART

    MOV A, R3                     ; SEND 1 OVER UART
    MOV SBUF, A
    ACALL WAIT_UART

    MOV A, R2                     ; SEND 2 OVER UART
    MOV SBUF, A
    ACALL WAIT_UART

    MOV A, R1                     ; SEND 3 OVER UART
    MOV SBUF, A
    ACALL WAIT_UART
	
    MOV A, R0                     ; SEND 4 OVER UART
    MOV SBUF, A
    ACALL WAIT_UART

    ; CHECK EACH REGISTER AGAINST PASSWORD "1000"
    MOV A, R3
    CJNE A, #'1', INCORRECT
    MOV A, R2
    CJNE A, #'0', INCORRECT
    MOV A, R1
    CJNE A, #'0', INCORRECT
    MOV A, R0
    CJNE A, #'0', INCORRECT
	
	CORRECT:
		CLR LED_RED                  ; TURN OFF RED LED
		SETB LED_GREEN               ; TURN ON GREEN LED
		ACALL BUZZER_ON
		ACALL BUZZER_ON
		ACALL BUZZER_ON
		SJMP RESET
	INCORRECT:
		CLR LED_GREEN                ; TURN OFF GREEN LED
		SETB LED_RED                 ; TURN ON RED LED
		ACALL BUZZER_ON
		ACALL BUZZER_ON
		SJMP RESET
	RESET:
		MOV INDEX, #0                ; RESET INDEX FOR NEXT ENTRY
		AJMP INIT                    ; RESTART PROGRAM
		
; SUBROUTINE DEFINE HERE

CHECK_INDEX:
    ; Compare index with 0
    MOV A, index            ; Load the value of index into the accumulator
    CJNE A, #0, CHECK_1L     ; If index ? 0, jump to CHECK_1
    CLR P1.2               ; Set P1.2 if index = 0
    RET                     ; Return from subroutine
	CHECK_1L:
		CJNE A, #1, CHECK_2L     ; If index ? 1, jump to CHECK_2
		CLR P1.3               ; Set P1.3 if index = 1
		RET                     ; Return from subroutine
	CHECK_2L:
		CJNE A, #2, CHECK_3L     ; If index ? 2, jump to CHECK_3
		CLR P1.4               ; Set P1.4 if index = 2
		RET                     ; Return from subroutine
	CHECK_3L:
		CJNE A, #3, END_CHECKL   ; If index ? 3, jump to END_CHECK
		CLR P1.5               ; Set P1.5 if index = 3
	END_CHECKL:
		RET                     ; Return from subroutine

SEG_TO_ASCII:
    MOV A, R0
    ACALL CONVERT_DIGIT
    MOV R0, A

    MOV A, R1
    ACALL CONVERT_DIGIT
    MOV R1, A

    MOV A, R2
    ACALL CONVERT_DIGIT
    MOV R2, A

    MOV A, R3
    ACALL CONVERT_DIGIT
    MOV R3, A
    RET

	CONVERT_DIGIT:
			CJNE A, #0C0H, CHECK_1
			MOV A, #'0'
			RET
		CHECK_1:
			CJNE A, #0F9H, CHECK_2
			MOV A, #'1'
			RET
		CHECK_2:
			CJNE A, #0A4H, CHECK_3
			MOV A, #'2'
			RET
		CHECK_3:
			CJNE A, #0B0H, CHECK_4
			MOV A, #'3'
			RET
		CHECK_4:
			CJNE A, #099H, CHECK_5
			MOV A, #'4'
			RET
		CHECK_5:
			CJNE A, #092H, CHECK_6
			MOV A, #'5'
			RET
		CHECK_6:
			CJNE A, #082H, CHECK_7
			MOV A, #'6'
			RET
		CHECK_7:
			CJNE A, #0F8H, CHECK_8
			MOV A, #'7'
			RET
		CHECK_8:
			CJNE A, #080H, CHECK_9
			MOV A, #'8'
			RET
		CHECK_9:
			CJNE A, #090H, ERROR
			MOV A, #'9'
			RET
		ERROR:
			MOV A, #'?'
			RET
			
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
	
WAIT_UART:
	JNB TI, WAIT_UART
	CLR TI
	RET
	
BUZZER_ON:
	SETB BUZZER
	ACALL DELAY_B
	CLR BUZZER
	ACALL DELAY_B
	RET
	
DELAY_B:
		MOV R7, #2 			; (1/20)*1 ms
	DB1:MOV R6, #250
	DB2:MOV R5, #250
	DB3:DJNZ R5, DB3
		DJNZ R6, DB2
		DJNZ R7, DB1
		RET

DELAY:
		MOV R7, #4 			; (4/20)*1 ms
	D1: MOV R6, #250
	D2: MOV R5, #250
	D3: DJNZ R5, D3
		DJNZ R6, D2
		DJNZ R7, D1
		RET

; 7-SEGMENT DISPLAY DATA FOR DIGITS 0-9
MA7SEG:
    DB 0C0H, 0F9H, 0A4H, 0B0H, 099H, 092H, 082H, 0F8H, 080H, 090H
END
