.segment "HEADER"       ; Setting up the header, needed for emulators to understand what to do with the file, not needed for actual cartridges
    .byte "NES"         ; The beginning of the HEADER of iNES header
    .byte $1a           ; Signature of iNES header that the emulator will look for
    .byte $02           ; 4 2 * 16KB PRG (program) ROM
    .byte $01           ; 5 8KB CHR ROM 
    .byte %00000000     ; 6 mapper 
    .byte $0            ; 7
    .byte $0            ; 8
    .byte $0            ; 9 TV System 0-NTSC / 1-PAL
    .byte $0
    .byte $0, $0, $0, $0, $0    ; unused

.segment "ZEROPAGE" ; $0000 hasta $00FF 256bytes - the fastest ram
    ;; some variables
    gamestate: .res 1
    score: .res 1
    lifes: .res 1
    button: .res 1
    ;states of the game
    TITLE = $00
    PLAYING = $01
    GAMEOVER = $02
.segment "STARTUP"
.segment "CODE"

; SUBROUTINES;
vblankwait:
    :
    BIT $2002
    BPL :-
    RTS
; EOS;

RESET:
    SEI             ; disable IRQs
    CLD             ; disable decimal mode
    LDX #$40
    STX $4017       ; disable APU frame counter IRQ - disable sound
    LDX #$ff
    TXS             ; setup stack starting at FF as it decrements instead if increments
    INX             ; overflow X reg to $00
    STX $2000       ; disable NMI - PPUCTRL reg
    STX $2001       ; disable rendering - PPUMASK reg
    STX $4010       ; disable DMC IRQs

    JSR vblankwait
    TXA ;A = $00

    LDA #$00
    STA gamestate
clearmem:
    LDA #$00        ; can also do TXA as x is $#00
    STA $0000, X
    STA $0100, X
    STA $0300, X
    STA $0400, X
    STA $0500, X
    STA $0600, X
    STA $0700, X
    LDA #$FE
    STA $0200, X    ; Set aside space in RAM for sprite data
    INX 
    BNE clearmem

    JSR vblankwait

    LDA #$02
    STA $4014 ; QAM DMA register -Access to sprite memory
    NOP ;Burn one cycle in nothing to finish the sta

clearnametables:
    LDA $2002   ; reset PPU status
    LDA #$20
    STA $2006
    LDA #$00
    STA $2006
    LDX #$08    ; prepare to fill 8 pages ($800 bytes)
    LDY #$00    ; X/Y is 16-bit counter, bigh byte in X
    LDA #$24    ; fill with tile $24 (sky block)
:
    STA $2007
    DEY 
    BNE :-
    DEX 
    BNE :-


loadpalettes:
    LDA $2002
    LDA #$3F
    STA $2006
    LDA #$00
    STA $2006

    LDX #$00

loadpaletteloop:
    LDA palettedata, x
    STA $2007
    INX
    CPX #$20
    BNE loadpaletteloop
    CLI
    LDA #%10010000; enamble NMI, sprites from pattern table 0 and background from pattern table 1
    STA $2000

    LDA #%00011110 ; background and sprites enabled
    STA $2001
    
forever:
    JMP forever     ; an infinite loop when init code is run

VBLANK:
    LDA #$00
    STA $2003
    LDA #$02
    STA $4014
    LDA #%10010000  ; enable NMI, sprites from pattern table 0, background from pattern table 1
    STA $2000
    LDA #%00011110  ; enable sprites, background, no left side clipping
    STA $2001
    LDA #$00
    
    JSR readcontroller ; read the controller


GAMEENGINE:
    LDA gamestate
    CMP #TITLE
    BEQ enginetitle

    LDA gamestate
    CMP #GAMEOVER
    BEQ engineover
    
    LDA gamestate
    CMP #PLAYING
    BEQ engineplaying

GAMEENGINEDONE:
    JSR updatesprites
    
    RTI


enginetitle:
    LDA $2002
    LDA #$20
    STA $2006
    LDA #$00
    STA $2006
    LDX #00
:
    LDA principal, X
    STA $2007
    INX
    CPX #$80
    BNE :-

    LDA $2002
    LDA #$23
    STA $2006
    LDA #$C0
    STA $2006
    LDX #$00
:
    LDA attributedata, X
    STA $2007
    INX
    CPX #$08
    BNE :-
    waitforkeypress:
        LDA button
        CMP #%00010000
        BNE waitforkeypress
    LDA #PLAYING
    STA gamestate
    JMP GAMEENGINEDONE

titledone:


engineplaying:

    JMP GAMEENGINEDONE

engineover:

    JMP GAMEENGINEDONE

readcontroller:
    LDA #01
    STA $4016
    LDA #00
    STA $4016
    LDX #$08
readcontrollerloop:
    LDA $4016
    LSR A
    ROL button
    DEX
    BNE readcontrollerloop
    RTS

updatesprites:
    LDA spritedata,X
    STA $0200,X
    INX
    CPX #$10
    BNE updatesprites

    CLI
    LDA #%10000000
    STA $2000

    LDA #%00010000
    STA $2001
    RTS

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

palettedata:
    .byte $22, $29, $1a, $0F, $22, $36, $17, $0F, $22, $30, $21, $0F, $22, $27, $17, $0F  ; background palette data
    .byte $22, $16, $27, $18, $22, $1A, $30, $27, $22, $16, $30, $27, $22, $0F, $36, $17  ; sprite palette data

spritedata:
    ;YCoord, tile number, attr, XCoord
    .byte $80, $00, $00, $80
    .byte $80, $01, $00, $88
    .byte $88, $10, $00, $80
    .byte $88, $11, $00, $88

nametabledata:
    .byte $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$20,$24,$24,$24,$24  ;;row 1
    .byte $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;;all sky ($24 = sky)

    .byte $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;;row 2
    .byte $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;;all sky

    .byte $24,$24,$24,$24,$45,$45,$24,$24,$45,$45,$45,$45,$45,$45,$24,$24  ;;row 3
    .byte $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$53,$54,$24,$24  ;;some brick tops

    .byte $24,$24,$24,$24,$47,$47,$24,$24,$47,$47,$47,$47,$47,$47,$24,$24  ;;row 4
    .byte $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$55,$56,$24,$01  ;;brick bottoms

attributedata:
    .byte %00000000, %00010000, %00100000, %00000000, %00000000, %00000000, %00000000, %00110000

principal:
    .byte $55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55  ;;row 1
    .byte $55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55  ;;all sky ($55 = sky)

    .byte $55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55  ;;row 2
    .byte $55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55  ;;all sky

    .byte $55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55  ;;row 3
    .byte $55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55  ;;some brick tops

    .byte $55,$55,$55,$55,$47,$47,$55,$55,$47,$47,$47,$47,$47,$47,$55,$55  ;;row 4
    .byte $55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$56,$55,$01  ;;brick bottoms

.segment "VECTORS"
    .word  VBLANK
    .word  RESET
    .word  0
.segment "CHARS"
    .incbin "game.chr"