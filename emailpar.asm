; Copyright 2022 Khadiev Edem
;
; Licensed under the Apache License, Version 2.0 (the "License");
; you may not use this file except in compliance with the License.
; You may obtain a copy of the License at
; 
;     http://www.apache.org/licenses/LICENSE-2.0
; 
; Unless required by applicable law or agreed to in writing, software
; distributed under the License is distributed on an "AS IS" BASIS,
; WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
; See the License for the specific language governing permissions and
; limitations under the License.
 
	.model	tiny
	.code
	org	100h

print_let macro	  letter
	push	ax
	push	dx
	mov	ah, 02h
	mov	dl, letter
	int	21h
	pop	dx
	pop	ax
endm

print_msg macro	  msg
	local	skip, message
	push	ax
	push	dx
	mov	ah, 09h
	mov	dx, offset message
	int	21h
	pop	dx
	pop	ax
	jmp	skip
message		db msg,	'$'
skip:
endm

start:
	call	GET_FILE_NAME
	call	OPEN_FILE
; TODO:
parser_loop:
	call	FILE_TO_BUFFER
	call	GET_EMAILS
	cmp	end_check, 1
	je	exit_parser

	call	MOVE_POINTER
	jmp	parser_loop
	
	

exit_parser:
	print_let 0ah
	print_let 0dh
	print_msg "Found "
	call PRINT_COUNTER
	print_msg " Emails"
	ret

GET_FILE_NAME proc
	push	ax
	push	bx
	push	cx
	push	dx

	mov	bl, ds:[80h]
	cmp	bl, 0
	jg	cmd_name
	print_msg 'Enter file name > '
	mov	ah, 0ah
	mov	dx, offset FilePath
	int	21h
	xor	bh, bh
	mov	bl, FilePath + 1
	mov	FilePath[bx + 2], 0
	jmp	exit_get
cmd_name:
	xor	bh, bh
	mov	bl, ds:[80h]
	mov	byte ptr [81h +	bx], 0
	mov	cx, bx
	push	cx
	cld
	mov	di, offset ds:[81h]
	mov	al, ' '
	repe	scasb
	dec	di
	pop	cx
	cld
	mov	si, di
	mov	di, offset FilePath + 2
	repe	movsb
exit_get:
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret
GET_FILE_NAME endp

OPEN_FILE proc
	push	ax
	push	dx

	mov	ax, 3d02h
	mov	dx, offset FilePath + 2
	int	21h
	jnc	open_suc
	print_let 0ah
	print_let 0dh
	print_msg 'Error while opening!...'
	int	20h
open_suc:
	mov	input_id, ax		; put file id to input_id
	mov	ax, 3d02h
	mov	dx, offset OutputFile
	int	21h
	mov	output_id, ax		; put file id to output	id

	pop	dx
	pop	ax
	ret
OPEN_FILE endp

FILE_TO_BUFFER proc
; this procedure reads 50000 bytes from	a file to the BUFFER
	push	ax
	push	bx
	push	cx

	mov	ah, 3fh
	mov	bx, input_id
	mov	cx, 50000
	mov	dx, offset buffer
	int	21h
	mov	readed,	ax
	dec	ax			; if ax	== 0 ->	cf = 1

	pop	cx
	pop	bx
	pop	ax
	ret
FILE_TO_BUFFER endp

GET_EMAILS proc
; this procedure gets emails from the BUFFER
	push	ax
	push	di
	push	dx
	push	bx

	

	mov	di, offset buffer
	cmp	readed,	50000
	jne	last_read
	call	GET_END_SHIFT		; get the latest ' ' in	the buffer
	mov	dx, offset buffer[49999]
	sub	dx, end_shift
	jmp	get_rate_sing
last_read:
	mov	bx, readed
	lea	dx, buffer[bx]
	mov	end_check, 1
get_rate_sing:
	inc	di
	cmp	byte ptr [di], '@'
	je	rate_found

	cmp di, dx
	jae	end_of_buffer
	jmp	get_rate_sing

rate_found:
	mov	rate_location, di

	call	GET_MAIL_LENGTH
	call	WRITE_EMAIL_TO_FILE

	mov	di, email_end
	jmp	get_rate_sing

end_of_buffer:

	pop	bx
	pop	dx
	pop	di
	pop	ax
	ret
GET_EMAILS endp

GET_MAIL_LENGTH	proc
	push	ax
	push	di
	push	bx
	mov	di, rate_location
get_start_l:
	dec	di
	cmp	byte ptr [di], ' '
	je	cont_get
	cmp	byte ptr [di], ';'
	je	cont_get
	cmp	byte ptr [di], 0dh
	je	cont_get
	cmp	byte ptr [di], 0ah
	je	cont_get
	cmp	byte ptr [di], ','
	je	cont_get
	cmp	byte ptr [di], 0
	je	cont_get

	jmp	get_start_l
cont_get:
	inc	di
	mov	email_start, di
	mov	di, rate_location

get_end_l:
	inc	di
	cmp	byte ptr [di], ' '
	je	end_get
	cmp	byte ptr [di], ';'
	je	end_get
	cmp	byte ptr [di], 0dh
	je	end_get
	cmp	byte ptr [di], 0ah
	je	end_get
	cmp	byte ptr [di], ','
	je	end_get
	cmp di, dx
	jae end_get

	jmp	get_end_l

end_get:
	mov	email_end, di
	dec email_end
	mov	bx, email_start

	sub	di, bx
	mov	email_length, di

	pop	bx
	pop	di
	pop	ax
	ret
GET_MAIL_LENGTH	endp

GET_END_SHIFT proc
	push	ax
	push	di
	push	bx

	mov	al, ' '
	mov	bx, readed
	lea	di, buffer[bx]
	mov	bx, di
get_end_sym:
	dec	di
	cmp	byte ptr [di], ' '
	je	found_end_sym
	cmp	byte ptr [di], ','
	je	found_end_sym
	cmp	byte ptr [di], ';'
	je	found_end_sym
	cmp	byte ptr [di], 0ah
	je	found_end_sym
	cmp	byte ptr [di], 0dh
	je	found_end_sym

	jmp	get_end_sym
found_end_sym:
	sub	bx, di
	mov	end_shift, bx

	pop	bx
	pop	di
	pop	ax
	ret
GET_END_SHIFT endp

WRITE_EMAIL_TO_FILE proc
	push	ax
	push	bx
	push	cx
	push	dx

	mov	ah, 40h
	mov	bx, output_id
	mov	cx, email_length
	mov	dx, email_start
	int	21h

	mov	ah, 40h
	mov	dx, offset newline
	mov	cx, 2
	int	21h
	
	call SMART_INC

	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret
WRITE_EMAIL_TO_FILE endp

MOVE_POINTER proc
	push	ax
	push	bx
	push	cx
	push	dx

	mov	ax, end_shift
	mov	dx, -1
	mul	dx
	mov	dx, ax 
	mov	ax, 4201h
	mov	bx, input_id
	mov cx, 0FFFFh
	int	21h

	pop	dx
	pop	cx
	pop	dx
	pop	ax
	ret
MOVE_POINTER endp

SMART_INC proc
	push	ax
	push 	bx 
	push	dx
	push 	cx
first_r:
    xor ah, ah  
    mov bx, 10h
    mov al, counter   
    div bl
    cmp ah, 9
    je  sec_r
    inc counter
    jmp end_inc
sec_r:         
    mov al, counter
    shr al, 4  
    xor ah, ah
    cmp al,9
    je  third_r
    add counter, 7
    jmp end_inc
third_r:  
    mov al, counter+1   
    div bl
    cmp ah, 9
    je  fourth_r
    inc counter+1
    mov counter, 0
    jmp end_inc
fourth_r:         
    mov al, counter+1
    shr al, 4  
    xor ah, ah
    cmp al,9
    je  fifth_r
    add counter + 1, 7
    mov counter, 0
    jmp end_inc
fifth_r: 
    mov al, counter+2   
    div bl
    cmp ah, 9
    je  sixth_r
    inc counter+2
    mov counter+1, 0
    mov counter, 0
    jmp end_inc
sixth_r:         
    mov al, counter+2
    shr al, 4  
    xor ah, ah
    cmp al, 9
    je  fifth_r
    add counter + 2, 7  
    mov counter + 1, 0
    mov counter, 0
    jmp end_inc
	
	
end_inc: 
	pop	cx
	pop	dx
	pop	bx
	pop	ax
    ret
SMART_INC endp
               
               
PRINT_COUNTER proc
    mov cx, 3 
print_loop:  
    xor ah, ah 
    mov bx, cx   
    dec bx
    mov al, counter + bx 
    push    ax
    shr al, 4
    cmp al, 0
    je  checker_time1  
    mov checker_count, 1 
print_sim1: 
    mov ah, 02h
    mov dl, al
    add dl, 30h        
    int 21h
    jmp second_p
checker_time1:
    cmp checker_count, 0
    je second_p 
    mov ah, 02h
    mov dl, 30h
    int 21h
second_p:   
    pop ax
    and al, 0Fh
    cmp al, 0
    je checker_time2
    mov checker_count, 1
print_sim2:
    mov ah, 02h
    mov dl, al
    add dl, 30h
    int 21h
    jmp next_l
checker_time2:
    cmp checker_count, 0
    je  next_l
    mov ah, 02h
    mov dl, 30h
    int 21h
next_l:
    loop print_loop
    ret    
PRINT_COUNTER endp

input_id	dw 0
FilePath	db 128,	?, 128 dup (0),	"$"

output_id	dw 0
OutputFile	db 'output.txt', 0
readed		dw 0

end_shift	dw 0
rate_location	dw 0
email_length	dw 0
email_start	dw 0
email_end	dw 0
counter db 3 dup(0) 

end_check	db 0
checker_count db 0

newline		db 0dh,	0ah
corrector	db 0
buffer		db 50000 dup(0), '@'
end	start
