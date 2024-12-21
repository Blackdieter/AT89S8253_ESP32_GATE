;===============================================================
; 8051 External Interrupts to Control LED on P2.6
;===============================================================
DATA_7SEG    EQU P1                 ; 7-SEGMENT DISPLAY CONNECTED TO PORT 0
D_CLOSE 	 EQU 0x0C6
D_OPEN   	 EQU 0x0C0
	
BUTTON1      BIT P3.2               ; BUTTON 1 INPUT ON PORT 3.2
BUTTON2      BIT P3.3               ; BUTTON 2 INPUT ON PORT 3.3
BUTTON3 	 BIT P3.4				; BUTTON 3 INPUT ON PORT 3.4
ELOCK		 BIT P3.7
BUZZER       BIT P2.7
LEN          BIT P1.7               ; LED ENABLE CONTROL BIT
	
PLED1		 BIT P2.0
PLED2		 BIT P2.1
PLED3		 BIT P2.2
PLED4		 BIT P2.3
PLED5		 BIT P2.4
PLED6		 BIT P2.5
LED_GREEN    BIT P2.6               ; GREEN LED BIT
LED_BLINK    BIT P2.7               ; RED LED BIT
	
INDEX        EQU 0x30				; COUNT FOR NUMBER OF DIGITS ENTERED
	
ORG 0000H           ; Reset vector
SJMP MAIN           ; Jump to main program	
ORG 0003H           ; External Interrupt 0 (INT0) vector
SJMP INT0_ISR       ; Jump to INT0 interrupt service routine
ORG 0013H           ; External Interrupt 1 (INT1) vector
SJMP INT1_ISR       ; Jump to INT1 interrupt service routine
ORG 23H         ; Interrupt vector for serial interrupt
AJMP UART_ISR 

;===============================================================
; Main Program
;===============================================================
MAIN:
    SETB LEN        ; Turn on the led7seg
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
	 CLR IT0             ; Configure INT0 as level-triggered (low level)
    CLR IT1             ; Configure INT1 as level-triggered (low level)
	
	; Initial default password
	MOV 0x31, #'2'
	MOV 0x32, #'1'
	MOV 0x33, #'0'
	MOV 0x34, #'0'
	MOV 0x35, #'0'
	MOV 0x36, #'0'
	
	; CONFIGURE PINS
    SETB BUZZER
    CLR ELOCK
    CLR LED_GREEN                 ; TURN OFF GREEN LED INITIALLY
	
	; DISPLAY INITIAL VALUE (8) ON 7-SEGMENT
	MOV DPTR, #MA7SEG-1           ; INITIALIZE DPTR WITH ADDRESS OF MA7SEG -1
    ;MOV DATA_7SEG, #D_CLOSE		  ; DISPLAY THE LETTER C
	MOV DATA_7SEG, #D_CLOSE		  ; DISPLAY THE LETTER C
	SETB P1.7
    MOV INDEX, #0
IDLE_LOOP:
	CPL LED_GREEN
	ACALL DELAY
	;JNB BUTTON3, BUTTON3_CHECKED
	SJMP IDLE_LOOP
	BUTTON3_CHECKED:
		ACALL CHEKC_PASSWORD
		ACALL DELAY
	RET

;===============================================================
; Interrupt Service Routines
;===============================================================

; INT0 Interrupt Service Routine (Accumulate the number)
INT0_ISR:
	ACALL BUZZER_ON
    CLR A                          ; CLEAR ACCUMULATOR
    INC DPTR                       ; INCREMENT DPTR FOR NEXT VALUE
    MOVC A, @A+DPTR                ; LOAD NEXT PATTERN FROM MA7SEG
    MOV DATA_7SEG, A               ; DISPLAY NUMBER ON 7-SEGMENT
    ; CHECK IF VALUE IS NOT 0x90 (9)
    CJNE A, #0x90, RETURN
    ; RESET DPTR TO START OF MA7SEG AFTER REACHING 9
    MOV DPTR, #MA7SEG-1
	RETURN:
	RETI                ; Return from interrupt

; INT1 Interrupt Service Routine (Control the number submitted)
INT1_ISR:
	ACALL BUZZER_ON
	; Save DATA_7SEG to the register corresponding to the value of INDEX (0-5)
	MOV A, INDEX        ; Move INDEX to Accumulator for comparison
	CJNE A, #0, CHECKI1  ; Compare INDEX with 0, jump if not equal
	MOV R0, DATA_7SEG   ; If INDEX == 0, store DATA_7SEG in R0
	SJMP END_CHECKI            ; Skip remaining checks
	CHECKI1:
	CJNE A, #1, CHECKI2  ; Compare INDEX with 1, jump if not equal
	MOV R1, DATA_7SEG   ; If INDEX == 1, store DATA_7SEG in R1
	SJMP END_CHECKI            ; Skip remaining checks
	CHECKI2:
	CJNE A, #2, CHECKI3  ; Compare INDEX with 2, jump if not equal
	MOV R2, DATA_7SEG   ; If INDEX == 2, store DATA_7SEG in R2
	SJMP END_CHECKI            ; Skip remaining checks
	CHECKI3:
	CJNE A, #3, CHECKI4  ; Compare INDEX with 3, jump if not equal
	MOV R3, DATA_7SEG   ; If INDEX == 3, store DATA_7SEG in R3
	SJMP END_CHECKI            ; Skip remaining checks
	CHECKI4:
	CJNE A, #4, CHECKI5  ; Compare INDEX with 4, jump if not equal
	MOV R4, DATA_7SEG   ; If INDEX == 4, store DATA_7SEG in R4
	SJMP END_CHECKI            ; Skip remaining checks
	CHECKI5:
	CJNE A, #5, END_CHECKI     ; Compare INDEX with 5, jump to END if not equal
	MOV R5, DATA_7SEG   ; If INDEX == 5, store DATA_7SEG in R5
	END_CHECKI:
    ; Continue with the rest of the program
	; DISPLAY NUMBER 0 ON 7-SEGMENT
    CLR A
    MOV DPTR, #MA7SEG             ; RESET DPTR TO START OF MA7SEG
    MOVC A, @A+DPTR
    MOV DATA_7SEG, A              ; DISPLAY NEXT VALUE ON 7-SEGMENT
	ACALL CHECK_INDEX			  ; DISPLAY THE LED FOR SUBMITTED VALUE
    ; CHECK IF INDEX IS 6
    INC INDEX
    MOV A, INDEX
    CJNE A, #6, EXIT_1ISR              ; IF NOT, GO BACK TO LOOP
	ACALL SEG_TO_ASCII
	; Check with out password
	ACALL CHEKC_PASSWORD		
	EXIT_1ISR:
	RETI                ; Return from interrupt
	
UART_ISR:
	ACALL RECEIVE_CHAR     ; Get character from UART
	CJNE A, #'#', EXIT_ISR ; If not '#', exit
	;CPL LED_RED			   ; For debug

	; 'P' detected, proceed to receive next 6 characters
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
	;ACALL SEND_RESPONSE
	EXIT_ISR:
	;CPL LED_GREEN ; For debug, if not P is inserted
	RETI        ; Return from interrupt
	
;===============================================================
; Logical check subrotines
;===============================================================
	CHECK_INDEX:	; Control the indicate led by the index
		; Compare index with 0
		MOV A, index            ; Load the value of index into the accumulator
		CJNE A, #0, CHECK_1L     ; If index ? 0, jump to CHECK_1
		CLR PLED1               ; Set P1.2 if index = 0
		RET                     ; Return from subroutine
		CHECK_1L:
		CJNE A, #1, CHECK_2L     ; If index ? 1, jump to CHECK_2
		CLR PLED2               ; Set P1.3 if index = 1
		RET                     ; Return from subroutine
		CHECK_2L:
		CJNE A, #2, CHECK_3L     ; If index ? 2, jump to CHECK_3
		CLR PLED3               ; Set P1.4 if index = 2
		RET                     ; Return from subroutine
		CHECK_3L:
		CJNE A, #3, CHECK_4L     ; If index ? 2, jump to CHECK_3
		CLR PLED4               ; Set P1.4 if index = 2
		RET                     ; Return from subroutine
		CHECK_4L:
		CJNE A, #4, CHECK_5L     ; If index ? 2, jump to CHECK_3
		CLR PLED5               ; Set P1.4 if index = 2
		RET                     ; Return from subroutine
		CHECK_5L:
		CJNE A, #5, END_CHECKL   ; If index ? 3, jump to END_CHECK
		CLR PLED6               ; Set P1.5 if index = 3
		END_CHECKL:
		RET                     ; Return from subroutine
		
	CHEKC_PASSWORD:	; CHECK EACH REGISTER AGAINST PASSWORD 
		ACALL SEND_PASSWORD
		MOV A, R0
		MOV B,0x31
		CJNE A, B, INCORRECT
		MOV A, R1
		MOV B,0x32
		CJNE A, B, INCORRECT
		MOV A, R2
		MOV B,0x33
		CJNE A, B, INCORRECT
		MOV A, R3
		MOV B,0x34
		CJNE A, B, INCORRECT
		MOV A, R4
		MOV B,0x35
		CJNE A, B, INCORRECT
		MOV A, R5
		MOV B,0x36
		CJNE A, B, INCORRECT
			CORRECT:
			SETB ELOCK
			SETB LED_GREEN               ; TURN ON GREEN LED
			MOV DATA_7SEG, #D_OPEN        ; DISPLAY OPEN
			;ACALL DISPLAY_PASSWORD
			CLR LEN
			ACALL BUZZER_ON
			SETB LEN
			ACALL BUZZER_ON
			CLR LEN
			ACALL BUZZER_ON
			SETB LEN
			CLR LED_GREEN
			ACALL DELAY
			ACALL DELAY
			ACALL DELAY
			CLR ELOCK
			SJMP RESET
			INCORRECT:
			MOV DATA_7SEG, #D_CLOSE       ; DISPLAY CLOSE
			CLR LEN
			ACALL BUZZER_ON
			SETB LEN
			ACALL BUZZER_ON
			SJMP RESET
			RESET:
			MOV R0, #00H  ; Set R0 to 0
			MOV R1, #00H  ; Set R1 to 0
			MOV R2, #00H  ; Set R2 to 0
			MOV R3, #00H  ; Set R3 to 0
			MOV R4, #00H  ; Set R4 to 0
			MOV R5, #00H  ; Set R5 to 0
			MOV INDEX, #0                ; RESET INDEX FOR NEXT ENTRY
			MOV P2, #0x3F				  ; TURN ON ALL SUBMITTED LED
			MOV DATA_7SEG, #D_CLOSE
			MOV DPTR, #MA7SEG-1           ; INITIALIZE DPTR WITH ADDRESS OF MA7SEG -1
			SETB BUZZER
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
		
	SEND_PASSWORD:
		MOV A, #'S'                    ; SEND S OVER UART
		ACALL SEND_CHAR
		MOV A, R0                     ; SEND 1 OVER UART
		ACALL SEND_CHAR
		MOV A, R1                     ; SEND 2 OVER UART
		ACALL SEND_CHAR
		MOV A, R2                     ; SEND 3 OVER UART
		ACALL SEND_CHAR
		MOV A, R3                     ; SEND 4 OVER UART
		ACALL SEND_CHAR
		MOV A, R4                     ; SEND 5 OVER UART
		ACALL SEND_CHAR
		MOV A, R5                     ; SEND 6 OVER UART
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
	CLR BUZZER
	ACALL DELAY_B
	SETB BUZZER
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
