;=================================================================
;
; Send 4 byte from r0 to r3 by UART (Chip -> Terminal)
;
;=================================================================

ORG 0000H         ; Start program from address 0000H

; Step 1: Initialize registers with numbers
MOV R0, #0xf9      ; Load 1 into R0
MOV R1, #0xa4      ; Load 2 into R1
MOV R2, #0xb0       ; Load 3 into R2
MOV R3, #0x99      ; Load 4 into R3

; Step 2: Call the subroutine to convert 7-segment to ASCII
ACALL SEG_TO_ASCII

; Step 2: Initialize UART for 9600 baud rate
MOV TMOD, #20H    ; Timer 1 in Mode 2 (8-bit auto-reload)
MOV TH1, #0FDH    ; Set baud rate to 9600 (assuming 11.0592 MHz clock)
MOV SCON, #50H    ; Set UART mode 1, 8-bit UART, REN enabled
SETB TR1          ; Start Timer 1

; Step 3: Transmit "1234" as a string over UART
MOV A, R0         ; Move content of R0 (1) to Accumulator
MOV SBUF, A       ; Send '1' over UART
ACALL WAIT_UART   ; Wait until transmission is complete

MOV A, R1         ; Move content of R1 (2) to Accumulator
MOV SBUF, A       ; Send '2' over UART
ACALL WAIT_UART   ; Wait until transmission is complete

MOV A, R2         ; Move content of R2 (3) to Accumulator
MOV SBUF, A       ; Send '3' over UART
ACALL WAIT_UART   ; Wait until transmission is complete

MOV A, R3         ; Move content of R3 (4) to Accumulator
MOV SBUF, A       ; Send '4' over UART
ACALL WAIT_UART   ; Wait until transmission is complete


WAIT_UART:
   JNB TI, WAIT_UART ; Wait for the TI (Transmit Interrupt) flag to set
   CLR TI            ; Clear TI flag for the next transmission
   RET               ; Return to the main program
	
; Subroutine to convert 7-segment codes to ASCII numbers
SEG_TO_ASCII:
   MOV A, R0
   ACALL CONVERT_DIGIT
   MOV R0, A        ; Store ASCII equivalent in R4

   MOV A, R1
   ACALL CONVERT_DIGIT
   MOV R1, A        ; Store ASCII equivalent in R5

   MOV A, R2
   ACALL CONVERT_DIGIT
   MOV R2, A        ; Store ASCII equivalent in R6

   MOV A, R3
   ACALL CONVERT_DIGIT
   MOV R3, A        ; Store ASCII equivalent in R7

   RET              ; Return from subroutine
   
 ; Convert individual 7-segment code in Accumulator to ASCII
CONVERT_DIGIT:
   CJNE A, #0C0H, CHECK_1    ; Check if code is for '0'
   MOV A, #'0'               ; ASCII for '0'
   RET

CHECK_1:
   CJNE A, #0F9H, CHECK_2    ; Check if code is for '1'
   MOV A, #'1'               ; ASCII for '1'
   RET

CHECK_2:
   CJNE A, #0A4H, CHECK_3    ; Check if code is for '2'
   MOV A, #'2'               ; ASCII for '2'
   RET

CHECK_3:
   CJNE A, #0B0H, CHECK_4    ; Check if code is for '3'
   MOV A, #'3'               ; ASCII for '3'
   RET

CHECK_4:
   CJNE A, #099H, CHECK_5    ; Check if code is for '4'
   MOV A, #'4'               ; ASCII for '4'
   RET

CHECK_5:
   CJNE A, #092H, CHECK_6    ; Check if code is for '5'
   MOV A, #'5'               ; ASCII for '5'
   RET

CHECK_6:
   CJNE A, #082H, CHECK_7    ; Check if code is for '6'
   MOV A, #'6'               ; ASCII for '6'
   RET

CHECK_7:
   CJNE A, #0F8H, CHECK_8    ; Check if code is for '7'
   MOV A, #'7'               ; ASCII for '7'
   RET

CHECK_8:
   CJNE A, #080H, CHECK_9    ; Check if code is for '8'
   MOV A, #'8'               ; ASCII for '8'
   RET

CHECK_9:
   CJNE A, #090H, ERROR      ; Check if code is for '9'
   MOV A, #'9'               ; ASCII for '9'
   RET

ERROR:
   MOV A, #'?'               ; Unknown character
   RET

END               ; End of program
