;================================= 
; tao xung vuong 
;================================= 
;tan so thach anh 11.0592MHz 
;================================= 

; su dung timer0 mode 2 de tao tan so xung vuong f=5kHz 
;================================= 
org 0 
ljmp main 
org 0bh
	ljmp interupt_timer0 

main:  
	mov tmod,#2 
	mov tl0,#0x9Ch 
	mov th0,#0x9Ch ; Kha nang thay dung 11.0562Mhz de them truyen thong
	; Co the dung 12Mhz voi tl0=th0=156=#0x9Ch
	setb tr0 
	setb et0 
	setb ea 
	sjmp $ 
interupt_timer0:  
	cpl p2.0 ;dao chan p2.0 
	reti  
end