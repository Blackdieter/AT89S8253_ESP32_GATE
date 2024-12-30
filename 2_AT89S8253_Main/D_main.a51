;===============================================================
; 8051 External Interrupts to Control LED on P2.6
;===============================================================
DATA_7SEG    EQU P0                 ; 7-SEGMENT DISPLAY CONNECTED TO PORT 0
LED1         BIT P2.2               ; LED1 CONTROL BIT
LED2         BIT P2.3               ; LED2 CONTROL BIT FOR ENABLING THE 2ND 7-SEGMENT
BUTTON1      BIT P3.2               ; BUTTON 1 INPUT ON PORT 3.2
BUTTON2      BIT P3.3               ; BUTTON 2 INPUT ON PORT 3.3
LED_GREEN    BIT P2.6               ; GREEN LED BIT
LED_RED      BIT P2.7               ; RED LED BIT
BUZZER       BIT P2.4
INDEX        EQU 0x30				; COUNT FOR NUMBER OF DIGITS ENTERED
	
ORG 0000H           ; Reset vector
SJMP MAIN           ; Jump to main program	
ORG 0003H           ; External Interrupt 0 (INT0) vector
SJMP INT0_ISR       ; Jump to INT0 interrupt service routine
RETI
ORG 0013H           ; External Interrupt 1 (INT1) vector
SJMP INT1_ISR       ; Jump to INT1 interrupt service routine
RETI
ORG 23H         ; Interrupt vector for serial interrupt
AJMP UART_ISR 
RETI


;===============================================================
; Main Program
;===============================================================
MAIN:
    MOV P2, #00H        ; Clear all LEDs on port 2 (initialize)
	SETB EA             ; Enable global interrupts
	
	; SETUP UART Interrupt
	MOV TMOD, #20H ; Timer 1 in mode 2 (8-bit auto-reload)
    MOV TH1, #-3   ; Baud rate 9600 for 11.0592 MHz crystal
    MOV SCON, #50H ; Serial mode 1, 8-bit data, 1 stop bit, REN enabled
    SETB TR1       ; Start Timer 1
	SETB ES        ; Enable serial interrupt
	
	; SETUP external Interrupt
    SETB EX0            ; Enable external interrupt 0 (INT0)
    SETB EX1            ; Enable external interrupt 1 (INT1)
    SETB IT0            ; Configure INT0 as edge-triggered (falling edge)
    SETB IT1            ; Configure INT1 as edge-triggered (falling edge)
	
	; Initial default password
	MOV 0x31, #'2'
	MOV 0x32, #'1'
	MOV 0x33, #'0'
	MOV 0x34, #'0'
	MOV 0x35, #'0'
	MOV 0x36, #'0'
	
	; CONFIGURE PINS
    CLR BUZZER
    CLR LED_RED
    CLR LED_GREEN                 ; TURN OFF GREEN LED INITIALLY
	
	; DISPLAY INITIAL VALUE (8) ON 7-SEGMENT
	MOV DPTR, #MA7SEG-1           ; INITIALIZE DPTR WITH ADDRESS OF MA7SEG -1
    MOV DATA_7SEG, #0x89
    MOV INDEX, #0
	SETB LED2
IDLE_LOOP:
	CPL P3.4
	ACALL DELAY
    SJMP IDLE_LOOP      ; Stay in an idle loop, waiting for interrupts

;===============================================================
; Interrupt Service Routines
;===============================================================

; INT0 Interrupt Service Routine (Accumulate the number)
INT0_ISR:
	;ACALL BUZZER_ON
    CLR A                          ; CLEAR ACCUMULATOR
    INC DPTR                       ; INCREMENT DPTR FOR NEXT VALUE
    MOVC A, @A+DPTR                ; LOAD NEXT PATTERN FROM MA7SEG
    MOV DATA_7SEG, A               ; DISPLAY NUMBER ON 7-SEGMENT

    ; CHECK IF VALUE IS NOT 0x90 (9)
    CJNE A, #0x90, RETURN
    ; RESET DPTR TO START OF MA7SEG AFTER REACHING 9
    MOV DPTR, #MA7SEG-1
	RETURN:
	RET                ; Return from interrupt

; INT1 Interrupt Service Routine (Control the number submitted)
INT1_ISR:
	;ACALL BUZZER_ON
    ; SHIFT NUMBERS IN REGISTERS TO MAKE ROOM FOR NEW VALUE IN R0
    MOV A, R4
    MOV R5, A                     ; MOVE PREVIOUS R4 TO R5
    MOV A, R3
    MOV R4, A                     ; MOVE PREVIOUS R3 TO R4
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
	CPL LED_RED                   ; Turn OFF LED connected to P2.6

    ; CHECK IF INDEX IS 6
    INC INDEX
    MOV A, INDEX
    CJNE A, #6, EXIT_1ISR              ; IF NOT, GO BACK TO LOOP
	ACALL SEG_TO_ASCII

    ; TRANSMIT "****" AS STRING OVER UART
	MOV A, R5                     ; SEND 1 OVER UART
    ACALL SEND_CHAR
    MOV A, R4                     ; SEND 2 OVER UART
    ACALL SEND_CHAR
    MOV A, R3                     ; SEND 3 OVER UART
    ACALL SEND_CHAR
    MOV A, R2                     ; SEND 4 OVER UART
    ACALL SEND_CHAR
    MOV A, R1                     ; SEND 5 OVER UART
    ACALL SEND_CHAR
    MOV A, R0                     ; SEND 6 OVER UART
    ACALL SEND_CHAR
	MOV A, #0x0D                ; Load ASCII for Carriage Return (CR)		
	ACALL SEND_CHAR             ; Send CR via UART
	MOV A, #0x0A                ; Load ASCII for Line Feed (LF)
	ACALL SEND_CHAR             ; Send LF via UART
	
	ACALL CHEKC_PASSWORD		; Check with out password
	;SJMP EXIT_1ISR
	EXIT_1ISR:
	RET                ; Return from interrupt
	
UART_ISR:
	ACALL RECEIVE_CHAR     ; Get character from UART
	CJNE A, #'P', EXIT_ISR ; If not 'P', exit
	;CPL LED_RED			   ; For debug

	; 'P' detected, proceed to receive next 4 characters
	ACALL RECEIVE_CHAR     ; Get first number
	MOV 0x31, A              ; Store in R0
	ACALL RECEIVE_CHAR     ; Get second number
	MOV 0x32, A              ; Store in R1
	ACALL RECEIVE_CHAR     ; Get third number
	MOV 0x33, A              ; Store in R2
	ACALL RECEIVE_CHAR     ; Get fourth number
	MOV	0x34, A              ; Store in R3
	ACALL RECEIVE_CHAR     ; Get third number
	MOV 0x35, A              ; Store in R4
	ACALL RECEIVE_CHAR     ; Get fourth number
	MOV	0x36, A              ; Store in R5
	; Send back received numbers over UART
	ACALL SEND_RESPONSE
	EXIT_ISR:
	;CPL LED_GREEN ; For debug, if not P is inserted
	RET        ; Return from interrupt
	
;===============================================================
; Logical check subrotines
;===============================================================
	CHECK_INDEX:	; Control the indicate led by the index
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
		CJNE A, #3, CHECK_4L     ; If index ? 2, jump to CHECK_3
		CLR P1.5               ; Set P1.4 if index = 2
		RET                     ; Return from subroutine
		CHECK_4L:
		CJNE A, #4, CHECK_5L     ; If index ? 2, jump to CHECK_3
		CLR P1.6               ; Set P1.4 if index = 2
		RET                     ; Return from subroutine
		CHECK_5L:
		CJNE A, #5, END_CHECKL   ; If index ? 3, jump to END_CHECK
		CLR P1.7               ; Set P1.5 if index = 3
		END_CHECKL:
		RET                     ; Return from subroutine
		
	CHEKC_PASSWORD:	; CHECK EACH REGISTER AGAINST PASSWORD  
		MOV A, R5
		MOV B,0x31
		CJNE A, B, INCORRECT
		MOV A, R4
		MOV B,0x32
		CJNE A, B, INCORRECT
		MOV A, R3
		MOV B,0x33
		CJNE A, B, INCORRECT
		MOV A, R2
		MOV B,0x34
		CJNE A, B, INCORRECT
		MOV A, R1
		MOV B,0x35
		CJNE A, B, INCORRECT
		MOV A, R0
		MOV B,0x36
		CJNE A, B, INCORRECT
			CORRECT:
			CLR LED_RED                  ; TURN OFF RED LED
			SETB LED_GREEN               ; TURN ON GREEN LED
			ACALL DISPLAY_PASSWORD
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
			MOV P1, #0xFF				  ; TURN ON ALL SUBMITTED LED
			MOV DATA_7SEG, #0x89
			MOV DPTR, #MA7SEG-1           ; INITIALIZE DPTR WITH ADDRESS OF MA7SEG -1
		RET
		
;===============================================================
; Convert subrotines
;===============================================================
	SEG_TO_ASCII:	; Convert 7seg led to ascii
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
		MOV A, R4
		ACALL CONVERT_DIGIT
		MOV R4, A
		MOV A, R5
		ACALL CONVERT_DIGIT
		MOV R5, A
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
; Write and display subrotines
;===============================================================
	RECEIVE_CHAR:
		JNB RI, RECEIVE_CHAR   ; Wait until a character is received
		MOV A, SBUF            ; Move received byte to Accumulator
		CLR RI                 ; Clear RI for next reception
		RET
	
	SEND_RESPONSE:
		MOV A, #'N'                 ; Load ASCII of 'N' into A
		ACALL SEND_CHAR             ; Send character via UART
		MOV A, #'E'                 ; Load ASCII of 'E' into A
		ACALL SEND_CHAR             ; Send character via UART
		MOV A, #'W'                 ; Load ASCII of 'W' into A
		ACALL SEND_CHAR             ; Send character via UART
		MOV A, #' '                 ; Load ASCII of space into A
		ACALL SEND_CHAR             ; Send character via UART
		MOV A, #'P'                 ; Load ASCII of 'P' into A
		ACALL SEND_CHAR             ; Send character via UART
		MOV A, #'A'                 ; Load ASCII of 'A' into A
		ACALL SEND_CHAR             ; Send character via UART
		MOV A, #'S'                 ; Load ASCII of 'S' into A
		ACALL SEND_CHAR             ; Send character via UART
		MOV A, #'S'                 ; Load ASCII of 'S' into A
		ACALL SEND_CHAR             ; Send character via UART
		MOV A, #'W'                 ; Load ASCII of 'W' into A
		ACALL SEND_CHAR             ; Send character via UART
		MOV A, #'O'                 ; Load ASCII of 'O' into A
		ACALL SEND_CHAR             ; Send character via UART
		MOV A, #'R'                 ; Load ASCII of 'R' into A
		ACALL SEND_CHAR             ; Send character via UART
		MOV A, #'D'                 ; Load ASCII of 'D' into A
		ACALL SEND_CHAR             ; Send character via UART
		MOV A, #':'                 ; Load ASCII of ':' into A
		ACALL SEND_CHAR             ; Send character via UART
		MOV A, #' '                 ; Load ASCII of space into A
		ACALL SEND_CHAR             ; Send character via UART
		MOV A, 0x31              ; Load first digit
		ACALL SEND_CHAR        ; Send character
		MOV A, 0x32              ; Load second digit
		ACALL SEND_CHAR        ; Send character
		MOV A, 0x33            ; Load third digit
		ACALL SEND_CHAR        ; Send character
		MOV A, 0x34              ; Load fourth digit
		ACALL SEND_CHAR        ; Send character	
		MOV A, 0x35              ; Load fourth digit
		ACALL SEND_CHAR        ; Send character
		MOV A, 0x36              ; Load fourth digit
		ACALL SEND_CHAR        ; Send character
		MOV A, #0x0D                ; Load ASCII for Carriage Return (CR)		
		ACALL SEND_CHAR             ; Send CR via UART
		MOV A, #0x0A                ; Load ASCII for Line Feed (LF)
		ACALL SEND_CHAR             ; Send LF via UART
		RET
	
	SEND_CHAR:
		MOV SBUF, A            ; Load A into SBUF to transmit
		JNB TI, $              ; Wait for transmission to complete
		CLR TI                 ; Clear transmit interrupt flag
		RET
	
	DISPLAY_PASSWORD:
		MOV A, #'P'                 ; Load ASCII of 'P' into A
		ACALL SEND_CHAR             ; Send character via UART
		MOV A, #'A'                 ; Load ASCII of 'A' into A
		ACALL SEND_CHAR             ; Send character via UART
		MOV A, #'S'                 ; Load ASCII of 'S' into A
		ACALL SEND_CHAR             ; Send character via UART
		MOV A, #'S'                 ; Load ASCII of 'S' into A
		ACALL SEND_CHAR             ; Send character via UART
		MOV A, #'W'                 ; Load ASCII of 'W' into A
		ACALL SEND_CHAR             ; Send character via UART
		MOV A, #'O'                 ; Load ASCII of 'O' into A
		ACALL SEND_CHAR             ; Send character via UART
		MOV A, #'R'                 ; Load ASCII of 'R' into A
		ACALL SEND_CHAR             ; Send character via UART
		MOV A, #'D'                 ; Load ASCII of 'D' into A
		ACALL SEND_CHAR             ; Send character via UART
		MOV A, #' '                 ; Load ASCII of space into A
		ACALL SEND_CHAR             ; Send character via UART
		MOV A, #'I'                 ; Load ASCII of 'I' into A
		ACALL SEND_CHAR             ; Send character via UART
		MOV A, #'S'                 ; Load ASCII of 'S' into A
		ACALL SEND_CHAR             ; Send character via UART
		MOV A, #':'                 ; Load ASCII of ':' into A
		ACALL SEND_CHAR             ; Send character via UART
		MOV A, #' '                 ; Load ASCII of space into A
		ACALL SEND_CHAR             ; Send character via UART
		MOV A,0x31
		ACALL SEND_CHAR
		MOV A,0x32
		ACALL SEND_CHAR
		MOV A,0x33
		ACALL SEND_CHAR	
		MOV A,0x34
		ACALL SEND_CHAR
		MOV A,0x35              ; Load fourth digit
		ACALL SEND_CHAR        ; Send character
		MOV A,0x36              ; Load fourth digit
		ACALL SEND_CHAR        ; Send character
		MOV A, #' '
		ACALL SEND_CHAR
		MOV A, #0x0D                ; Load ASCII for Carriage Return (CR)		
		ACALL SEND_CHAR             ; Send CR via UART
		MOV A, #0x0A                ; Load ASCII for Line Feed (LF)
		ACALL SEND_CHAR             ; Send LF via UART
		RET	
			
;===============================================================
; Delay subrotines
;===============================================================
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

MA7SEG:
    DB 0C0H, 0F9H, 0A4H, 0B0H, 099H, 092H, 082H, 0F8H, 080H, 090H
END
