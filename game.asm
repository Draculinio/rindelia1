.segment "HEADER"       ; Setting up the header, needed for emulators to understand what to do with the file, not needed for actual cartridges
    .byte "NES"         ; The beginning of the HEADER of iNES header
    .byte $1a           ; Signature of iNES header that the emulator will look for
    .byte $02           ; 4 2 * 16KB PRG (program) ROM
    .byte $01           ; 5 8KB CHR ROM 
    .byte %00000000     ; 6 mapper 
    .byte $0            ; 7
    .byte $0            ; 8
    .byte $1            ; 9 TV System 0-NTSC / 1-PAL
    .byte $0
    .byte $0, $0, $0, $0, $0    ; unused

.segment "ZEROPAGE" ; $0000 hasta $00FF 256bytes - the fastest ram
    gamestate: .res 1
    score: .res 1
    lifes: .res 1
    button: .res 1
    level: .res 1
    leftFlag: .res 1
    rightFlag: .res 1
    p1x: .res 1
    p2x: .res 1
    p1y: .res 1
    p2y: .res 1
    pdir: .res 1 ;player direction 00 right, 01 left
    sx: .res 1 ;shoot in x
    sy: .res 1 ;shoot in y
    sd: .res 1 ;shoor direction
    ax: .res 1 ; Aqualate x position
    ay: .res 1 ; Aqualate y position
    al: .res 1 ; Aqualate in the loop
    refresh: .res 1; 0 refresh, 1 don't refresh
    shootStatus: .res 1 ;is the shoot out? $00 no, $01 yes
    pointerLo: .res 1    ; pointer variables declared in RAM
    pointerHi: .res 1    ; low byte first, high byte immediately after
    backgroundRefresh: .res 1 ;should I refresh background? 01 yes, 00 no

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

    ;;;;;;;;;;;;INITIAL VALUES;;;;;;;;;;;;
    LDA #$00
    STA gamestate
    STA shootStatus
    LDA #$10
    STA p1x
    LDA #$18
    STA p2x
    STA sx
    LDA #$80
    STA p1y
    STA sy
    LDA #$88
    STA p2y
    LDA #$01
    ;This is for the aqualate
    LDA #$50
    STA ax
    LDA #$80
    STA ay
    LDA #$00
    STA pdir
    STA sd
    LDA #01
    STA backgroundRefresh
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
    ;LDA gamestate
    ;CMP #PLAYING
    ;BNE :+
    
    LDA #%10010000  ; enable NMI, sprites from pattern table 0, background from pattern table 1
    STA $2000
    LDA #%00011110  ; enable sprites, background, no left side clipping
    STA $2001
    LDA #$00
    STA $2005       ; no X scrolling
    STA $2005       ; no Y scrolling
    
GAMEENGINE:
    JSR readcontroller ; read the controller
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
    JSR levelOneScreen
    JSR updatesprites
    RTI

engineover:
    JSR GAMEENGINEDONE

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
    waitforkeypress:
        LDA button
        CMP #%00010000
        BNE waitforkeypress
    LDA #PLAYING
    STA gamestate
    ;JSR clearscreen
    ;JSR levelOneScreen
    ;LDA #00
    ;STA backgroundRefresh
    JMP GAMEENGINEDONE

engineplaying:
;read button
    LDA button

right: 
    CMP #%00000001
    BNE rightDone
    JSR moveRight
rightDone:

left: 
    CMP #%00000010
    BNE leftDone
    JSR moveLeft
leftDone:


bButton:
    CMP #%01000000
    BNE bDone
    LDA #$01
    STA shootStatus
    LDA p2x
    STA sx
    LDA p1y
    STA sy
    LDA pdir
    STA sd
bDone:
;Enemies update
JSR refreshValues
LDA #PLAYING
STA gamestate
JMP GAMEENGINEDONE


readcontroller:
    LDA #01
    STA $4016
    LDA #00
    STA $4016
    LDX #$08
    LDA #$00 ; reset button value to 0
    STA button; reset button variable
readcontrollerloop:
    LDA $4016
    LSR A
    ROL button
    DEX
    BNE readcontrollerloop
    RTS

;;;;;; SPRITE UPDATING ;;;;;;;;;;;;;;;
updatesprites:
    ;I will have to do something to UPDATE ALL in the future
    ;CHARACTER ($0200 to $020F)
    ;First let's decide which tiles should be used
    LDA #$00
    CMP pdir
    BEQ rightCharTiles
    LDA #$01
    STA $0201
    LDA #$00
    STA $0205
    LDA #$11
    STA $0209
    LDA #$10
    STA $020D
    LDA #$40
    STA $0202
    STA $0206
    STA $020A
    STA $020E
    JMP charTilesDone
    rightCharTiles:
    LDA #$00
    STA $0201
    LDA #$01
    STA $0205
    LDA #$10
    STA $0209
    LDA #$11
    STA $020D
    LDA #$00
    STA $0202
    STA $0206
    STA $020A
    STA $020E
    charTilesDone:
    LDA p1y
    STA $0200
    STA $0204
    LDA p2y
    STA $0208
    STA $020C
    LDA p1x
    STA $0203
    STA $020B
    LDA p2x
    STA $0207
    STA $020F
    
    ;Aqualate ($0214 to $0217)
    LDA ay
    STA $0214
    LDA #$02
    STA $0215
    LDA #$00
    STA $0216
    LDA ax
    STA $0217
    ;SHOOT ($0210 to $0213)
    LDA sy
    STA $0210
    LDA sx
    STA $0213
    LDA #$00
    STA $0212
    LDA #$01
    CMP shootStatus
    BEQ isShooting
    LDA #$FC
    STA $0211
    JMP shootDone
    isShooting:
    LDA #$30
    STA $0211
    shootDone:
    CLI
    LDA #%10000000
    STA $2000

    LDA #%00010000
    STA $2001
    RTS
;;;;;;;;END OF SPRITE UPDATING;;;;;;;;;;;;;;;;;;    

clearscreen:
    LDA $2002
    LDA #$20
    STA $2006
    LDA #$00
    STA $2006
    LDX #00
:
    LDA cscreen, X
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
    RTS

levelOneScreen:
    LDA $2002
    LDA #$20
    STA $2006
    LDA #$00
    STA $2006

    LDA #<levelOne
    STA pointerLo
    LDA #>levelOne
    STA pointerHi

    LDX #$00
    LDY #$00

    outsideLoop:

    insideLoop:
        LDA (pointerLo),Y
        STA $2007

        INY
        CPY #$00
        BNE insideLoop

        INC pointerHi

        INX
        CPX #$04
        BNE outsideLoop

    CLI 
    LDA #%10010000  ; enable NMI, sprites from pattern table 0, background from 1
    STA $2000
    LDA #%00011110  ; background and sprites enable, no left clipping
    STA $2001
    RTS

moveRight:
    LDA p1x
    CLC
    ADC #01
    STA p1x
    LDA p2x
    CLC
    ADC #01
    STA p2x
    LDA #$00
    STA pdir
    RTS

moveLeft:
    LDA p1x
    SEC
    SBC #01
    STA p1x
    LDA p2x
    SEC
    SBC #01
    STA p2x
    LDA #$01
    STA pdir
    RTS

refreshValues:
    ;shoot
    ;for now it will only shoot to the right.
    LDA #$00
    CMP shootStatus
    BEQ noshoot
    LDA #01
    CMP sd
    BEQ shootLeft
    LDA sx
    CLC
    ADC #01
    STA sx
    JMP endshoot
    shootLeft:
    LDA sx
    SEC
    SBC #01
    STA sx
    endshoot:
    noshoot:
    ;enemies
    LDA #$00 ;in the original position x+1, y-1
    CMP al
    BNE :+
    LDA ax
    CLC
    ADC #05
    STA ax
    LDA ay
    SEC
    SBC #05
    STA ay
    :
    LDA #$01 ;position 2 x+1, y+1
    CMP al 
    BNE :+
    LDA ax
    CLC
    ADC #05
    STA ax
    LDA ay
    CLC
    ADC #05
    STA ay
    :
    LDA #$02 ;position 3 x-1, y+1
    CMP al
    BNE :+
    LDA ax
    SEC
    SBC #05
    STA ax
    LDA ay
    CLC
    ADC #05
    STA ay
    :
    LDA #$03 ; position 4 x-1, y-1
    CMP al
    BNE :+
    LDA ax
    SEC
    SBC #05
    STA ax
    LDA ay
    SEC
    SBC #05
    STA ay
    :
    ;update
    LDA al
    CLC
    ADC #01
    STA al
    LDA #05
    CMP al
    BNE :+
    LDA #00
    STA al
    :
    RTS


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Graphical things;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

attributedata:
    .byte %00000000, %00010000, %00100000, %00000000, %00000000, %00000000, %00000000, %00110000

principal:
    .byte $1B,$12,$17,$0D,$0E,$15,$12,$0A,$24,$24,$24,$24,$24,$24,$24,$24 
    .byte $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24 

    .byte $24,$24,$1D,$11,$0E,$24,$15,$0E,$10,$0E,$17,$0D,$24,$24,$24,$24 
    .byte $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24 

    .byte $24,$24,$24,$24,$18,$0F,$24,$1D,$11,$0E,$24,$0F,$18,$1E,$1B,$24 
    .byte $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  

    .byte $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$10 
    .byte $0E,$16,$1C,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24 

palettedata:
    .byte $22, $29, $1a, $0F, $22, $36, $17, $0F, $22, $30, $21, $0F, $22, $27, $17, $0F  ; background palette data
    .byte $22, $16, $27, $18, $22, $1A, $30, $27, $22, $16, $30, $27, $22, $0F, $36, $17  ; sprite palette data

cscreen:
    .byte $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;;row 1
    .byte $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;;all sky ($24 = sky)

    .byte $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;;row 2
    .byte $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;;all sky

    .byte $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;;row 3
    .byte $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;;

    .byte $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;;row 4
    .byte $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;;

levelOne:
    .byte $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;;row 1
    .byte $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  

    .byte $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;;row 2
    .byte $24,$24,$24,$24,$24,$24,$24,$24,$24,$28,$28,$28,$28,$28,$28,$24  

    .byte $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;;row 3
    .byte $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  

    .byte $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;;row 4
    .byte $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  

    .byte $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;;row 5
    .byte $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  

    .byte $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;;row 6
    .byte $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  

    .byte $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;;row 7
    .byte $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  

    .byte $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;;row 8
    .byte $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  

    .byte $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;;row 9
    .byte $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  

    .byte $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;;row 10
    .byte $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  

    .byte $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;;row 11
    .byte $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  

    .byte $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;;row 12
    .byte $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24 

    .byte $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;;row 13
    .byte $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  

    .byte $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;;row 14
    .byte $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  

    .byte $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;;row 15
    .byte $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  

    .byte $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;;row 16
    .byte $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  

    .byte $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;;row 17
    .byte $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  

    .byte $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;;row 18
    .byte $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  

    .byte $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;;row 19
    .byte $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  

    .byte $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;;row 20
    .byte $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  

    .byte $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;;row 21
    .byte $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  

    .byte $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;;row 22
    .byte $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  

    .byte $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;;row 23
    .byte $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24 

    .byte $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;;row 24
    .byte $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  

    .byte $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;;row 25
    .byte $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  

    .byte $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;;row 26
    .byte $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  

    .byte $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;;row 27
    .byte $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  

    .byte $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;;row 28
    .byte $24,$24,$24,$24,$24,$24,$24,$24,$28,$28,$28,$28,$24,$24,$24,$24  

    .byte $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;;row 29
    .byte $27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27  

    .byte $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;;row 30
    .byte $27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27 

attributes:  ;8 x 8 = 64 bytes
  .byte %00000000, %00010000, %01010000, %00010000, %00000000, %00000000, %00000000, %00110000
  .byte %00000000, %00010000, %01010000, %00010000, %00000000, %00000000, %00000000, %00110000
  .byte %00000000, %00010000, %01010000, %00010000, %00000000, %00000000, %00000000, %00110000
  .byte %00000000, %00010000, %01010000, %00010000, %00000000, %00000000, %00000000, %00110000
  .byte %00000000, %00010000, %01010000, %00010000, %00000000, %00000000, %00000000, %00110000
  .byte %00000000, %00010000, %01010000, %00010000, %00000000, %00000000, %00000000, %00110000
  .byte %00000000, %00010000, %01010000, %00010000, %00000000, %00000000, %00000000, %00110000
  .byte %00000000, %00010000, %01010000, %00010000, %00000000, %00000000, %00000000, %00110000


.segment "VECTORS"
    .word  VBLANK
    .word  RESET
    .word  0
.segment "CHARS"
    .incbin "game.chr"