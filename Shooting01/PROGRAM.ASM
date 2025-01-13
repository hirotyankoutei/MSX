;--------------------------------------------
; initialize.asm
; 初期処理
; 変数が増える場合はこちらに記述すること！
;--------------------------------------------
; BIOSルーチン
REDVRM:equ $004A ; VRAMの内容をAレジスタに読み込む
WRTVRM:equ $004D ; VRAMのアドレスにAレジスタの値を書き込む
SETRED:equ $0050 ; VRAMからデータを読み込める状態にする
SETWRT:equ $0053 ; VRAMにデータを書き込める状態にする
FILVRM:equ $0056 ; VRAMの指定領域を同一のデータで埋める
LDIRMV:equ $0059 ; VRAMからRAMにブロック転送する
LDIRVM:equ $005C ; RAMからVRAMにブロック転送する
CHGMOD:equ $005F ; SCREENモードを変更する
SETGRP:equ $007E ; VDPのみをGRAPHIC2モードにする
ERAFNK:EQU $00CC ;ファンクションキーを非表示にする
GTSTCK:equ $00D5 ; JOY STICKの状態を調べる
GTTRIG:equ $00D8 ; トリガボタンの状態を返す
CHGCLR:equ $0111 ; 画面の色を変える
KILBUF:equ $0156 ; キーボードバッファをクリアする

; ワークエリア
LINWID:equ $F3AF ; WIDTHで設定する1行の幅が格納されているアドレス
RG0SAV:equ $F3DF ; VDPレジスタ#0の値が格納されているアドレス
FORCLR:equ $F3E9 ; 前景色が格納されているアドレス
BAKCLR:EQU $F3EA ; 背景色が格納されているアドレス
BDRCLR:equ $F3EB ; 周辺色が格納されているアドレス
CLIKSW:equ $F3DB ; キークリック音のON/OFFが格納されているアドレス
INTCNT:equ $FCA2 ; MSX BIOSにて1/60秒ごとにインクリメントされる値が格納されているアドレス
H_TIMI:equ $FD9F ; 垂直帰線割り込みフック

;--------------------------------------------
; 変数領域
;--------------------------------------------
; DEBUG PRINT用
WK_DUMPDATA:equ $C000    ; 16バイト
WK_DUMPCHAR:equ $C010    ; 32バイト

; VRAMデータ退避用
WK_VRAMTORAM:equ $C030   ; 0800Hバイト(C030H - C82FH)

; キャラクタデータ作成用
WK_CHARDATAADR:equ $D000 ; 2バイト
WK_CHARCODE:equ $D002    ; 1バイト

; H.TIMIフックバックアップ用ワークエリア
H_TIMI_BACKUP:equ $D003  ; 5バイト
; H.TIMI垂直同期割込待ち用カウンタ
VSYNC_WAIT_CNT:equ $D008 ; 1バイト

WK_PLAYERDIST:equ $D00B     ; 1バイト（プレーヤーの向き:0～8 1=上,5=下,7=左,3=右)

;何番の弾の処理を行っているかを格納するワーク
WK_SHOT_NO:equ $D00C     ; 1バイト
;トリガーの押した状態のカウンター　1の時に弾を撃つ
WK_TRIG_COUNT:equ $D00D	; 1バイト

;何番目の岩の処理を行っているかを格納するワーク
WK_ROCK_NO:equ $D00E     ; 1バイト
;岩を出すタイミングのカウンター
WK_ROCK_COUNTER:equ $D00F	; 1バイト

; ワーク用スプライトアトリビュートテーブル
; 4バイト×32個＝128バイト（スプライト32枚分）
; スプライトを表示させるために、いったんこのワークテーブルを
; 作成してからLDIRVMでVRAMに一括転送する
WK_PLAYERSPRATTR:equ $D100			; 4バイト
WK_PLAYER_SHOT_SPRATTR:equ $D104	; 4バイト×8個＝32バイト
WK_ROCK_SPRATTR:equ $D124	; 4バイト×20個＝80バイト

; 岩の状態用ワーク
;小数Y 小数X ベクトルY ベクトルX 硬さ カウンター 6バイト×20＝120バイト
WK_ROCK_STAT:equ $D174

; サウンド優先度（0:ショット、1:岩ヒット、2:岩破壊、3:自機爆発）
WK_SOUND_PRIORITY: equ $D1EC    ; 1バイト
; サウンド優先度フレーム
WK_SOUND_PRIORITY_FRAME: equ $D1ED  ; 1バイト


; スプライト座標格納用
; プレーヤー
WK_PLAYERPOSY:equ WK_PLAYERSPRATTR    	; 1バイト
WK_PLAYERPOSX:equ WK_PLAYERPOSY + 1		; 1バイト

    
;--------------------------------------------
; 初期処理（お約束コード）
;--------------------------------------------
; プログラムの開始位置アドレスは0xA000
org $A000

Header:

    ; MSX の ROM ヘッダ (16 bytes)
    ; プログラムの先頭位置は0x4010
    ;defb 'A', 'B', $10, $40, $00, $00, $00, $00
    ;defb $00, $00, $00, $00, $00, $00, $00, $00

Start:

    ; スタックポインタを初期化
    ;ld sp, $F380

    ; 画面構成の初期化
    ld a, $0F
    ld (FORCLR), a   ;白色
    ld a, $01
    ld (BAKCLR), a   ;黒色
    ld (BDRCLR), a   ;黒色

    ;SCREEN1,2
    ld a,(RG0SAV+1)
    or 2
    ld (RG0SAV+1),a  ;スプライトモードを16X16に

    ld a, 1          ;SCREEN1
    call CHGMOD      ;スクリーンモード変更

    ; GRAPHIC2モードに変更する
    call SETGRP

    ld a, 32         ;WIDTH=32
    ld (LINWID), a

    ;ファンクションキー非表示
    call ERAFNK

    ;カチカチ音を消す
    ld a, 0
    ld (CLIKSW), a

;--------------------------------------------
; 初期処理（お約束コード）ここまで
;--------------------------------------------




;--------------------------------------------
; INCLUDE
;--------------------------------------------
;include "initialize.asm"

;--------------------------------------------
; 初期処理
;--------------------------------------------
Init:

    ;--------------------------------------------
    ; キャラクタパターンとカラーテーブルを
    ; 作成する
    ;--------------------------------------------
    call CreateCharacterPattern


    ;--------------------------------------------
    ; 背景の星の初期化
    ;--------------------------------------------
    CALL StarCharacterInit
    
    ;--------------------------------------------
    ; スプライトパターンを作成する
    ;--------------------------------------------
    call CreateSpritePattern
    
    ; プレーヤーの初期化
    LD IY, WK_PLAYERSPRATTR
    ld a, 100
    ld (WK_PLAYERPOSX), a ; プレーヤーのX座標の初期化
    ld a, 100
    ld (WK_PLAYERPOSY), a ; プレーヤーのY座標の初期化
    ld a, 0
    ld (WK_PLAYERDIST), a ; プレーヤーのパターン初期化（通常）
    ld a, $0F
    LD (IY + 3) ,A	; プレーヤーの色
    
    ; プレーヤーの弾の初期化
    CALL InitShot
    
    ; 岩の初期化
    CALL InitRock
    
    ; スプライトを初期表示する
    ld ix, SPRDISTPTN_TBL
    call CreatePlayerWorkSpriteAttr

    ld de, $1B00
    ld bc, 116	; (プレーヤー + 弾8つ + 岩20個)×4 = 116
    call PutSprite

    ;call DebugPrint
    
    ; AKG Playerの初期化
    ld hl, GAMEBGM_START
    LD A, 0
    call PLY_AKG_INIT
    
    ; AKG Sound Effectの初期化
    ld hl, SOUNDEFFECTS
    call PLY_AKG_INITSOUNDEFFECTS
    
    ; 効果音の優先度を初期化
    LD A, 0
    LD (WK_SOUND_PRIORITY), A
    LD (WK_SOUND_PRIORITY_FRAME), A
    
    
    ;--------------------------------------------
    ; タイマー割り込みの初期設定
    ;--------------------------------------------
    ld a, 0
    ld (VSYNC_WAIT_CNT), a
    
    DI	;割り込み停止
    ; ■H.TIMIバックアップ
    LD HL,H_TIMI                    ; 転送元
    LD DE,H_TIMI_BACKUP             ; 転送先
    LD BC,5                         ; 転送バイト数
    LDIR

    ; ■H.TIMI書き換え
    LD A,$C3                        ; JP
    LD HL,H_TIMI_HANDLER           	; H.TIMI割り込み処理のアドレス
    LD (H_TIMI+0),A
    LD (H_TIMI+1),HL

    EI	;割り込み開始




;--------------------------------------------
; メインループ
;--------------------------------------------
MainLoop:
    ; VSYNC_WAIT_CNTの初期化
    ;   この値は以下の制御を行うために使用する：
    ;   - メインロジック開始時に 0 に設定
    ;   - H.TIMI割り込み処理の中でデクリメント (1/60秒ごとに呼び出し)
    ;   - メインロジックの最後に、ゼロフラグがONになるまで待機
    ld a, 1
    ld (VSYNC_WAIT_CNT), a
    
    ; ゲーム処理呼び出し
    call GameProc

VSYNC_Wait:
    ; 垂直同期待ち
    ld a, (VSYNC_WAIT_CNT)
    or a
    jr nz,VSYNC_Wait

    jr MainLoop
    
    
    
    
;--------------------------------------------
; ゲーム処理
;--------------------------------------------
GameProc:

    ;call DelayLoop
    
    ;--------------------------------------------
    ; 星のスクロール
    ;--------------------------------------------
    CALL StarScroll

    ;--------------------------------------------
    ; 入力を受け付ける
    ;--------------------------------------------
    ; キーボードバッファをクリアする
    ; これを呼び出さないとカーソルキーを正常に判定できない
    call KILBUF

    ; またはカーソルキーの方向を取得
    ; GTSTCK呼び出し後、Aレジスタに方向がセットされる
    ld a, 0
    call GTSTCK
    
    ; プレーヤーの向きを変数にセット
    ld (WK_PLAYERDIST), a
    
    ; プレーヤーの移動
    call MovePlayer

    ; 自機の弾を撃つ
    call DoShot
    
    ; 自機の弾を動かす
    call MoveShot
    
    ; 岩を発生
    call DispRock
    
    ; 岩を動かす
    call MoveRock
    
    ; 当たり判定
    call CollisionDetection

    ; スプライトを表示する
    ld de, $1B00
    ld bc, 116	; (プレーヤー + 弾8つ + 岩20個)×4 = 116
    call PutSprite

    ;call DebugPrint

GameProcEnd:

    RET


; ====================================================================================================
; H.TIMI割り込み処理
; ====================================================================================================
H_TIMI_HANDLER:
    ; AKG Playerの処理
    call PLY_AKG_PLAY

H_TIMI_HANDLER_SOUND_PRIORITY:
    ; サウンドの優先フレームがあるかチェック
    LD A, (WK_SOUND_PRIORITY_FRAME)
    CP 0
    JP Z, H_TIMI_HANDLER_SOUND_PRIORITY_END
    ; ある場合はフレームを削減
    DEC A
    LD (WK_SOUND_PRIORITY_FRAME), A
    
H_TIMI_HANDLER_SOUND_PRIORITY_END:


    ; VSYNC_WAIT_CNTデクリメント
    ;   1/60ごとに-1される
    ;   メインルーチンの最初の設定値により
    ;     1 = 60フレーム
    ;     2 = 30フレーム
    ;   の処理となる
    LD A,(VSYNC_WAIT_CNT)
    OR A
    JR Z,H_TIMI_HANDLER_L1
    DEC A
    LD (VSYNC_WAIT_CNT),A

H_TIMI_HANDLER_L1:
    ; ■バックアップ済のH.TIMIハンドラにチェーン
    ;   最後に必ず実行する
    JP H_TIMI_BACKUP



DebugPrint:

    ;
    ; DUMP出力するためのデータを準備する
    ;
    ;ld hl, WK_PLAYERPOSY
    ;######################################################
    ;LD HL, WK_ROCK_STAT
    ;LD HL, WK_CollisionHandlingBetweenRocks_ClassBit
    LD HL, WK_CollisionHandlingBetweenRocks_AY
    ld de, WK_DUMPDATA            ; WK_DUMPDATAのアドレスに
    ld bc, 16                     ; 16バイト転送する
    ldir

    call PrintHexaDump

    ;
    ; WK_DUMPCHARのアドレスの内容を
    ; 画面上の下段(1AE0H)に32バイト転送する
    ;
    ld de, $1AE0
    call HexaDumpToVRAM

    ret

;-----------------------------------------------
; INCLUDE
;-----------------------------------------------
;include "common.asm"
;--------------------------------------------
; common.asm
; 共通処理のサブルーチン集
;--------------------------------------------


;--------------------------------------------
; Random:乱数生成
; N×5+1法
; 1～255の乱数を生成
; Aレジスタに結果を格納
; D'レジスタ破壊
;--------------------------------------------
Random:
    LD A,10	;シード値
    EXX	;レジスタ退避
    LD D, A
    SLA A
    SLA A
    ADD A,D
    INC A
    LD (Random + 1),A	; シード値を上書き
    EXX	;レジスタを戻す
    RET






;--------------------------------------------
; SUB-ROUTINE: PutVRAM256Bytes
; HLレジスタで指定したVRAMアドレスから
; Aレジスタの値を256文字分書き込む
;--------------------------------------------
PutVRAM256Bytes:

    push af
    push bc

    ld  b, $00

PutVRAM256BytesLoop:

    call WRTVRM
    inc hl

    djnz PutVRAM256BytesLoop

    pop bc
    pop af

    ret

;--------------------------------------------
; SUB-ROUTINE: CalcMulti
; 掛け算を行う
; Eレジスタに格納されている値とHレジスタに
; 格納されている値を掛けてその結果をHLレジスタ
; にセットして返却する
;--------------------------------------------
CalcMulti:

    ;
    ; 当サブルーチンではBレジスタとDレジスタ
    ; HLレジスタを破壊するためPUSHで退避しておく
    ;
    push bc
    push de

    ld d, 0
    ld l, 0
    ld b, 8

CalcMulti1:

    ; 
    ; Hレジスタの値を2倍する
    ; (2倍することで左に1ビットシフトする)
    ;
    ; 計算結果が16bitになる場合もあるため
    ; HLレジスタ(16bit)として使う
    ;
    ; Hレジスタの第7ビットの値はCYフラグに入る
    ; (桁あがりするとCYフラグが1になる)
    ;
    add hl, hl

    ;
    ; CYフラグがたっていなければCalcMulti2へジャンプ
    jr nc, CalcMulti2

    ;
    ; CYフラグが立っている場合は
    ; Eレジスタの値をHLレジスタに足す
    ;
    add hl, de

CalcMulti2:

    ;
    ; Bレジスタが0になるまで（計8bitぶん）
    ; HL + HL を繰り返す
    djnz CalcMulti1

    ; 退避していたレジスタを戻す
    pop de
    pop bc

    ret

;--------------------------------------------
; SUB-ROUTINE: PrintHexaDump
; 16進数文字列変換サブルーチン
; WK_DUMPDATAのアドレスの内容を32バイトぶん
; 16進表記する(32 x 2=64文字使用する)
;--------------------------------------------
PrintHexaDump:

    push hl
    push de
    push bc
    push af

    ; 16進表記文字の格納エリアを
    ; 文字コード20H(スペース)で埋める

    ld ix, WK_DUMPCHAR
    ld b, 32
    
PrintHexaDumpLoop1:

    ld (ix + 0), $20
    inc ix
    
    djnz PrintHexaDumpLoop1

PrintHexaDumpLoopEnd:

    ;
    ; WK_DUMPDATAのアドレスの値を16進表記にして
    ; WK_DUMPCHARのアドレスに格納していく
    ; (16バイト分)
    ;

    ld ix, WK_DUMPDATA
    ld iy, WK_DUMPCHAR
    ld b, 16

PrintHexaDumpLoop2:

    ;
    ; 最初の2バイトを取得し、DEレジスタに格納する
    ;
    ld d, (ix + 0)
    ld e, (ix + 1)

    ; Dジスタの値をAレジスタに転送
    ld a, d

    call Hex1Byte

    ; Eレジスタの値をAレジスタに転送
    ld a, e

    call Hex1Byte

    inc ix ; IXレジスタを2バイトぶん進める
    inc ix

    djnz PrintHexaDumpLoop2

    pop af
    pop bc
    pop de
    pop hl

    ret

;
; 1バイトの数値を文字列に変換する
;
Hex1Byte:

    ld c, a ; Aレジスタの値をCレジスタに退避

    ; Aレジスタを右シフトして上位4ビットの内容を
    ; 下位4ビットの位置にずらす
    srl a
    srl a
    srl a
    srl a

    call PutOneChar ; 上位4ビットの情報を16進表記する

    ld a, c ; 退避した内容をAレジスタに戻す
    and $0F  ; Aレジスタの値を下の桁のみにする

    call PutOneChar

    ret

;
; 4ビットの数値を文字に変換して
; IYレジスタ(WK_DUMPCHARのインデックス)のアドレスに
; 格納する
;
PutOneChar:

    cp 10 ; Aレジスタから10を引いた結果のフラグレジスタを取得する

    ; CYフラグがたたない場合
    ; つまり、Aレジスタの値が10以上の場合は
    ; PutHexCharを呼び出し16進で表示する
    jr nc, PutHexChar
    
    add a, $30
    ld (iy), a

    inc iy

    ret

PutHexChar:

    add a, $37 ; 数値に文字コード37Hを足してAからFまでの文字列にする
    ld (iy), a

    inc iy

    ret

;--------------------------------------------
; SUB-ROUTINE: HexaDumpToVRAM
; WK_DUMPCHARのデータをVRAMの指定したアドレス
; に出力する
; WK_DUMPCHARのデータ長さは16バイトとする
;   DEレジスタ：VRAMの先頭アドレス
;               先頭アドレスは横0の位置にした
;               ほうがみやすい
;--------------------------------------------
HexaDumpToVRAM:

    ld hl, WK_DUMPCHAR
    ld bc, 32          ; 32バイト分指定したアドレスに転送
    call LDIRVM

    ret

;---------------------------------------------------------
; SUB-ROUTINE: DelayLoop
; 空ループを繰り返し処理遅延をおこす
;---------------------------------------------------------
DelayLoop:

    ld b, 20 ; 20 * 255回空ループを繰り返す

DelayLoop1:

    ld a, $FF ; Aレジスタに$FF(255)をセット

DelayLoop2:

    dec a ; Aレジスタの値から1を減算する

    ; ZフラグがたっていなければDelayLoop2に戻る
    ; JRは間接アドレッシング指定と呼ばれるジャンプ
    jr nz, DelayLoop2

    ; Bレジスタの値から1を減算しZフラグがたっていなければDelayLoop1に戻る
    ; DJNZも間接アドレッシング指定
    djnz DelayLoop1

    ; ret で呼び出し元の次の命令アドレスに実行位置が戻る
    RET
 

;include "sprite.asm"
;--------------------------------------------
; スプライト関連の処理
;--------------------------------------------

;--------------------------------------------
; SUB-ROUTINE: CreateSpritePattern
; スプライトパターンをVRAMに書き込む
;--------------------------------------------
CreateSpritePattern:

    ;--------------------------------------------
    ; スプライトパターンデータをVRAMの
    ; スプライトパターンジェネレータテーブルに
    ; 転送する
    ;--------------------------------------------
    ld hl, SPRPTN
    ld de, $3800   ; スプライトパターンのVRAM先頭アドレスは3800H
    ld bc, 320     ; 1体あたり32バイトx10パターン
    call LDIRVM
    
    ret

;------------------------------------------------
; SUB-ROUTINE: MovePlayer
; Aレジスタに格納されている情報から
; 方向を特定してプレーヤーのスプライトを移動させる
;------------------------------------------------
MovePlayer:

	;プレーヤーの移動量
	PLAYERS_MOVEMENT_AMOUNT:equ 4;

    ;--------------------------------------------
    ; 移動処理を行う
    ;--------------------------------------------
    ; ジョイスティックの方向に移動させる
    ld a, (WK_PLAYERDIST)
    ld b, 0
    ld c, a
    ld IX, PLAYERMOVE_TBL	;移動方向のあるポインタ
    ADD IX,BC	;ポインタをジョイスティックの方向分進める
	
    ; 下位4ビットはY座標
    ld a, (ix)

    and $0F ; 0FHでANDして下位4ビットの値だけにする
    ld b, a ; BレジスタにY座標の値をセットする

    ld a, (ix)
    sra a     ; 4ビット右にシフトしてX座標の値とする
    sra a
    sra a
    sra a
    ld c, a   ; CレジスタにX座標の値をセットする
    
    ;スプライトパターンを初期化
    ld ix, SPRDISTPTN_TBL

MoveY_Plus:

    ld a, b

    cp 1
    jr c, MoveX_Plus ; 移動量が0の場合はX座標の処理にジャンプ

    cp 2
    jr z, MoveY_Minus ; 移動量が2の場合はY座標の減算にジャンプ

    ; Y座標を加算

    ld a, (WK_PLAYERPOSY)
    ADD A, PLAYERS_MOVEMENT_AMOUNT	; 移動量を加算する
    LD B, A		; AレジスタをBレジスタに保存
    SUB 191-15	; 下端を超えていないか確認
    JP C, MoveY_Plus_END	; キャリーが立った場合は超えていない
    
    LD B, 191 - 16	;	位置を下端に補正

MoveY_Plus_END:
	LD A, B	; 計算結果をAレジスタに戻す
    ld (WK_PLAYERPOSY),  A	; 計算結果を格納
    jr MoveX_Plus

MoveY_Minus:

    ; Y座標を減算

    ld a, (WK_PLAYERPOSY)
    SUB PLAYERS_MOVEMENT_AMOUNT	; 移動量を減算する
    JP NC, MoveY_Minus_END	; キャリーが立たなかった場合は超えていない
    
    LD A, 0	; 位置を上端に設定

MoveY_Minus_END:
    ld (WK_PLAYERPOSY), a 	; 計算結果を格納

MoveX_Plus:

    ld a, c

    cp 1
    jr c, MovePlayerPutWorkSpriteAttr ; 移動量が0の場合は何も処理しない

    cp 2
    jr z, MoveX_Minus

    ; X座標を加算

    ld a, (WK_PLAYERPOSX)
    ADD A, PLAYERS_MOVEMENT_AMOUNT	; 移動量を加算する
    LD B, A		; AレジスタをBレジスタに保存
    SUB 255-16	; 右端を超えていないか確認
    JP C, MoveX_Plus_END	; キャリーが立った場合は超えていない
    
    LD B, 255 - 17	;	位置を下端に補正

MoveX_Plus_END:
	LD A, B	; 計算結果をAレジスタに戻す
    ld (WK_PLAYERPOSX),  A	; 計算結果を格納

    ;スプライトパターン右
    ld ix, SPRDISTPTN_TBL + 2

    jr MovePlayerPutWorkSpriteAttr

MoveX_Minus:

    ; X座標を減算

    ld a, (WK_PLAYERPOSX)
    SUB PLAYERS_MOVEMENT_AMOUNT	; 移動量を減算する
    JP NC, MoveX_Minus_END	; キャリーが立たなかった場合は超えていない
    
    LD A, 0	; 位置を上端に設定
    
MoveX_Minus_END:    
    ld (WK_PLAYERPOSX), a	; 計算結果を格納
    
    ;スプライトパターン左
    ld ix, SPRDISTPTN_TBL + 1
    
    jr MovePlayerPutWorkSpriteAttr


MovePlayerPutWorkSpriteAttr:

    ; ワーク用スプライトアトリビュートテーブルを
    ; 作成する
    call CreatePlayerWorkSpriteAttr

MovePlayerEnd:

    ret



;--------------------------------------------
; 自機弾関連の処理
;
; WK_SHOT_STAT 自機弾関連の状態ワーク
; 1バイト カウンタ
;--------------------------------------------
WK_SHOT_STAT:
    DEFB $00, $00, $00, $00, $00, $00, $00, $00

; 初期化サブルーチン
InitShot:
    ;トリガーカウンタの初期化
    LD A, 0
    LD (WK_TRIG_COUNT),A

    ; 自機弾の最大数
	MAX_SHOT_COUNT:equ 8
    
    ; 弾の番号を初期化
    LD HL, WK_SHOT_NO
    LD (HL), 0
    
    ; ワークエリアの位置をIXレジスタに格納
    LD IX, WK_PLAYER_SHOT_SPRATTR
    ; 状態ワークの位置をIYレジスタに格納
    LD IY, WK_SHOT_STAT
    
    ;弾の番号をAレジスタに設定
    LD A,(WK_SHOT_NO)
    
InitShot_Loop
	; 弾の番号を加算
    INC A
    LD (WK_SHOT_NO), A

    ;自機弾の初期化
    LD (IX + 0), 217	; 自機弾のY座標（消す）
 	LD (IX + 1), 0		; 自機弾のX座標
    LD (IX + 2), 12		; スプライトパターン
    LD (IX + 3), $0B	; 色
    ;自機弾状態の初期化
    LD (IY + 0), $00    ; カウンタの初期化
    
    ;IX を加算(次のループの準備)
    LD B, 0
    LD C, 4
    ADD IX,BC
    ;IY を加算
    INC IY
    
    ; 弾の番号全て処理する
    LD A, (WK_SHOT_NO)
    CP MAX_SHOT_COUNT
    JP NZ, InitShot_Loop

	RET


; 弾を撃つサブルーチン
DoShot:
    ; トリガーカウンタの最大数
	MAX_TRIG_COUNT:equ 20

    ;トリガーの状態を取得
    LD A,0
    call GTTRIG
    
    ; Aレジスタにトリガーが押されているか否かの状態が格納される
    ; 0: 押されていない
    ; $FF: 押されている
    OR A
    JP NZ, DoShot_TrigOn
    
; トリガーが押されていない場合
DoShot_TrigOff:
    ;トリガーのカウンタをリセット
    LD A, 0
    LD (WK_TRIG_COUNT), A
    
    JP DoShot_End

DoShot_TrigOn:
    ; トリガーのカウンタを加算
    LD A,(WK_TRIG_COUNT)
    INC A
    
    ; カウンターが最大値の場合は1にする
    CP MAX_TRIG_COUNT
    JP NZ, DoShot_SelectShot	; カウンターが最大より小さい場合は次の処理へ
    LD A, 1
    
DoShot_SelectShot:
    ;カウンターを保存
    LD (WK_TRIG_COUNT), A
    
    ;カウンターが1以外の場合は処理を終了
    CP 1
    JP NZ, DoShot_End
    
    ; 現在の弾でY座標が217のものを探す
    ; 弾の番号を初期化
    LD HL, WK_SHOT_NO
    LD (HL), 0
    
    ; ワークエリアの位置をIXレジスタに格納
    LD IX, WK_PLAYER_SHOT_SPRATTR
    
    ;弾の番号をAレジスタに設定
    LD A,(WK_SHOT_NO)
    
DoShot_SelectShot_Loop
	; 弾の番号を加算
    INC A
    LD (WK_SHOT_NO), A
    
    ; Y座標を取得
    LD A,(IX+0)
    
    ;217の場合は確定
    CP 217
    JP Z, DoShot_Exec
    
    ;IX を加算(次のループの準備)
    LD B, 0
    LD C, 4
    ADD IX,BC
    
    ; 弾の番号全て処理する
    LD A, (WK_SHOT_NO)
    CP MAX_SHOT_COUNT
    JP NZ, DoShot_SelectShot_Loop
    
    ;全てのループを回った場合は対象無しのため処理を終了する
    JP DoShot_End

DoShot_Exec:
DoShot_Exec_CheckSoundPriority:
    ; 効果音のプライオリティチェック
    LD A, (WK_SOUND_PRIORITY)
    CP 1
    ; 優先度OKは効果音を鳴らす
    JP C, DoShot_Exec_PlaySound
    LD A, (WK_SOUND_PRIORITY_FRAME)
    CP 0
    ; 優先度フレーム残がある場合は音を鳴らさない
    JP NZ, DoShot_Exec_PlaySound_Emd    

DoShot_Exec_PlaySound:
    ; 効果音を鳴らす
    ld a, $01 ; SOUND EFFECT NUMBER
    ld c, 0   ; CHANNEL ( 0:1ch 1:2ch 2:3ch )
    ld b, 0   ; VOLUME ( 0 - 16 : 0=Full Volume)
    call PLY_AKG_PLAYSOUNDEFFECT
    
    ; 優先度を初期化
    LD A, 0
    LD (WK_SOUND_PRIORITY), A
    LD (WK_SOUND_PRIORITY_FRAME), A
    
DoShot_Exec_PlaySound_Emd:

	; X座標、Ｙ座標を自機に合わせる
    LD A, (WK_PLAYERPOSY)
    LD (IX + 0), A
    LD A, (WK_PLAYERPOSX)
    LD (IX + 1), A
    ; スプライトパターンは通常
    LD (IX + 2), 12
    
DoShot_End:
    RET


; 弾を動かすサブルーチン
MoveShot:
    ; 弾の番号を初期化
    LD HL, WK_SHOT_NO
    LD (HL), 0
    
    ; ワークエリアの位置をIXレジスタに格納
    LD IX, WK_PLAYER_SHOT_SPRATTR
    ; 状態ワークの位置をIYレジスタに格納
    LD IY, WK_SHOT_STAT
    
    ;弾の番号をAレジスタに設定
    LD A,(WK_SHOT_NO)

MoveShot_Loop
	; 弾の番号を加算
    INC A
    LD (WK_SHOT_NO), A
    
    ; Y座標を取得
    LD A,(IX+0)
    
    ; Y座標が217の場合は消えている。次のループへ
    CP 217
    JP Z, MoveShot_NextLoop
    
    ; 弾が消えるパターンの場合か判定
    LD A,(IX+2)
    CP 16
    JP NZ, MoveShot_Loop_1	; 消さない場合は次の処理
    
    ; 弾のカウンタを取得
    LD A,(IY+0)
    ; カウンタが5の場合は弾を消す処理へ
    CP 5
    JP Z, MoveShot_Loop_Clear
    ; カウンタを加算
    INC A
    LD (IY+0),A
    ; 次のループへ
    JP MoveShot_NextLoop
    
MoveShot_Loop_Clear
    LD (IX+2),12	; 弾の絵を通常に戻す
    LD (IX+0),217	; 弾を消す
    LD (IY+0),0		; カウンタを初期化
    ; 次のループへ
    JP MoveShot_NextLoop
    
MoveShot_Loop_1
    
    ; それ以外は、Y座標を減算する
    
    ; Y座標を取得
    LD A,(IX+0)
    ; 弾の移動量
	PLAYERS_SHOT_AMOUNT:equ 8;
    SUB PLAYERS_SHOT_AMOUNT
    
    ; 弾を消すかの判定
    ; Y座標が222より大きい場合は消さない
    CP 222
    JP NC, MoveSho_SetY
    ; Y座標が191より小さい場合は消さない
    CP 191
    JP C, MoveSho_SetY
   	; Y座標が191～222の間の場合消す
    LD A, 217

MoveSho_SetY:
	LD (IX+0),A
    

MoveShot_NextLoop:
    ;IX を加算(次のループの準備)
    LD B, 0
    LD C, 4
    ADD IX,BC
    ;IY を加算
    INC IY
    
    ; 弾の番号全て処理する
    LD A, (WK_SHOT_NO)
    CP MAX_SHOT_COUNT
    JP NZ, MoveShot_Loop
    
    ;全てのループを回った場合は対象無しのため処理を終了する
    JP MoveShot_End
    
MoveShot_End
	RET


;--------------------------------------------
; 岩関連の処理
;
; WK_ROCK_STAT について
; 1バイト 上位4ビット Yの小数累計
; 1バイト 上位4ビット Xの小数累計
; 1バイト Yのベクトル 上位4ビット小数部 4ビット目 符号 下位3ビット 整数部  
; 1バイト Xのベクトル 上位4ビット小数部 4ビット目 符号 下位3ビット 整数部
; 1バイト 硬さ
; 1バイト カウンタ
;--------------------------------------------
; 初期化サブルーチン
InitRock:
    ; 岩の最大数
	MAX_ROCK_COUNT:equ 20
    
    ; 岩の番号を初期化
    LD HL, WK_ROCK_NO
    LD (HL), 0
    
    ; ワークエリアの位置をIX、IYレジスタに格納
    LD IX, WK_ROCK_SPRATTR
    LD IY, WK_ROCK_STAT
    
    ;岩の番号をAレジスタに設定
    LD A,(WK_ROCK_NO)
    
InitRock_Loop:
	; 岩の番号を加算
    INC A
    LD (WK_ROCK_NO), A

    ;岩の初期化
    LD (IX + 0), 217	; 岩のY座標（消す）
 	LD (IX + 1), 0  	; 岩のX座標
    LD (IX + 2), 20		; スプライトパターン
    LD (IX + 3), $06	; 色
    
    ;岩の状態初期化
    LD (IY + 0), 0		; Y座標小数
    LD (IY + 1), 0		; X座標小数
    LD (IY + 2), 0		; Y座標ベクトル
    LD (IY + 3), 0		; X座標ベクトル
    LD (IY + 4), 0		; 固さ
    LD (IY + 5), 0      ; カウンタ
    
    ;IX を加算(次のループの準備)
    LD B, 0
    LD C, 4
    ADD IX,BC
    ;IYを加算（次のループの準備）
    LD C, 6
    ADD IY,BC
    
    ; 岩の番号全て処理する
    LD A, (WK_ROCK_NO)
    CP MAX_ROCK_COUNT
    JP NZ, InitRock_Loop

	RET


; 岩の発生ルーチン
DispRock:
    ; 乱数取得
    CALL Random
    ; ビット演算で0の場合に発生
    AND %00110001
    RET NZ	; 対象外の場合は処理終了

DispRock_Select:
    ; 岩の番号を初期化
    LD HL, WK_ROCK_NO
    LD (HL), 0
    
    ; ワークエリアの位置をIX、IYレジスタに格納
    LD IX, WK_ROCK_SPRATTR
    LD IY, WK_ROCK_STAT
    
    ;岩の番号をAレジスタに設定
    LD A,(WK_ROCK_NO)
    
DispRock_Select_Loop:
	; 岩の番号を加算
    INC A
    LD (WK_ROCK_NO), A
    
    LD A, (IX + 0)	; Y座標取得
    ; Y座標が217以外の場合、次のループ
    CP 217
    JP NZ, DispRock_Select_LoopNext

    ;岩の表示
    LD A, 239
    LD (IX + 0), A	; 岩のY座標
    
    CALL Random
    CP 240
    JP C, DispRock_Select_Loop_SetX
    LD A, 239	; X座標が239を超える場合は補正
    
DispRock_Select_Loop_SetX:
 	LD (IX + 1), A  ; 岩のX座標
    
    ; スプライトパターンは通常
    LD (IX + 2), 20
    
DispRock_Select_StateInit
    LD (IY + 0), 0	; Y座標小数
    LD (IY + 1), 0	; X座標小数
    CALL Random
    AND %11110011
    LD (IY + 2), A	; Y座標ベクトル
    CALL Random
    AND %11111001
    LD (IY + 3), A	; X座標ベクトル
    LD (IY + 4), 5	; 固さ
    
    JP DispRock_End	; 岩が確定した時はここで処理終了

DispRock_Select_LoopNext:
    ;IX を加算(次のループの準備)
    LD B, 0
    LD C, 4
    ADD IX,BC
    ;IYを加算（次のループの準備）
    LD C, 6
    ADD IY,BC
    
    ; 岩の番号全て処理する
    LD A, (WK_ROCK_NO)
    CP MAX_ROCK_COUNT
    JP NZ, DispRock_Select_Loop

DispRock_End:
    RET



; 岩を動かすルーチン
MoveRock:
    ; 岩の番号を初期化
    LD HL, WK_ROCK_NO
    LD (HL), 0
    
    ; ワークエリアの位置をIX、IYレジスタに格納
    LD IX, WK_ROCK_SPRATTR
    LD IY, WK_ROCK_STAT
    
    ;岩の番号をAレジスタに設定
    LD A,(WK_ROCK_NO)
    
MoveRock_Loop:
	; 岩の番号を加算
    INC A
    LD (WK_ROCK_NO), A
    
    LD A, (IX + 0)	; Y座標取得
    ; Y座標が217の場合、次のループ
    CP 217
    JP Z, MoveRock_LoopNext
    
MoveRock_Loop_SpritePattern:
    ; 岩のスプライトパターンが変化中の場合は変化させる
    LD A,(IX+2)	; スプライトパターン取得
    CP 20
    JP Z, MoveRock_Loop_VectorY	; 通常の場合は次の処理へ
    
    ; カウンタを取得
    LD A,(IY + 5)
    ; カウンタが10の場合はスプライトパターンを変化
    CP 10
    JP Z, MoveRock_Loop_SpritePattern_Change
    
    ; カウンタを加算
    INC A
    LD (IY + 5), A
    ; 次のループ
    JP MoveRock_LoopNext
    
MoveRock_Loop_SpritePattern_Change:
    LD A,(IX+2)	; スプライトパターン取得
    ADD A, 4	; スプライトパターンを変化
    ; 36を超える場合
    CP 37
    JP C, MoveRock_Loop_SpritePattern_1	; 超えない場合は次の処理へ
    ; スプライトパターンを戻してスプライトを消す
    LD (IX+2), 20
    LD (IX+0), 217
    ; カウンタを初期化
    LD (IY+5), 0
    ; 次のループ
    JP MoveRock_LoopNext
    
MoveRock_Loop_SpritePattern_1:
    ; スプライトパターンを設定
    LD (IX+2), A
    ; 次のループ
    JP MoveRock_LoopNext

MoveRock_Loop_SpritePattern_End:


    ; Y座標をベクトル分移動させる
MoveRock_Loop_VectorY:
    LD A, (IY + 2)	; Yベクトルを取得
    LD B, (IY + 0)	; Yの小数の累積値を取得
    LD C, (IX + 0)	; Y座標を取得
    ; ベクトル加算
    CALL MoveRock_Sub_AddVector
    ; 計算結果を格納
    LD (IY + 0), B	; 小数の累積値を格納する
    
    ; Y座標が192～217の場合、消す
    CP 192
    JP C, MoveRock_Loop_SetY
    CP 217
    JP NC, MoveRock_Loop_SetY
    LD A, 217
 
MoveRock_Loop_SetY:
	LD (IX + 0), A	; Y座標設定


    ; X座標をベクトル分移動させる
MoveRock_Loop_VectorX:
    LD A, (IY + 3)	; Xベクトルを取得
    LD B, (IY + 1)	; Xの小数の累積値を取得
    LD C, (IX + 1)	; X座標を取得
    ; ベクトル加算
    CALL MoveRock_Sub_AddVector
    ; 計算結果を格納
    LD (IY + 1), B	; 小数の累積値を格納する
    
    ; キャリーフラグが立っている場合は移動
    JP C, MoveRock_Loop_Carry
    
    ; X座標が239以下の場合は座標を設定する
    CP 240
    JP C, MoveRock_Loop_SetX
    
    ; X座標を239に設定
    LD A, 239
    JP MoveRock_Loop_InvertTheSign
    
MoveRock_Loop_Carry:
    ; X座標を0に設定
    LD A, 0
    
MoveRock_Loop_InvertTheSign:
    LD D, A	; X座標をDレジスタにコピー
    LD A,(IY + 3)	; Xベクトルを取得
    ; ベクトルのマイナス判定
    BIT 3, A
    JP NZ, MoveRock_Loop_InvertTheSign_Minus
    
    ; ベクトルをマイナスにする
    SET 3, A
    JP MoveRock_Loop_SetVector
MoveRock_Loop_InvertTheSign_Minus:
    ; ベクトルをプラスにする
    RES 3, A
MoveRock_Loop_SetVector:
    ; ベクトルを登録
    LD (IY + 3), A
    ; X座標をAレジスタに戻す
    LD A, D
 
MoveRock_Loop_SetX:
	LD (IX + 1), A	; Y座標設定
    
; Yベクトルを加速する
MoveRock_Loop_Acceleration:
    ; Yベクトルを取得
    LD A, (IY + 2)
    ; マイナス判定
    BIT 3, A
    JP NZ, MoveRock_Loop_AccelerationY_Minus
    
    ; 整数部を取得
    AND %00000111
    CP 7
    JP C, MoveRock_Loop_AccelerationY_Plus	; ベクトルが7未満の場合は加速させる
    
    ; 加速させない
    LD (IY + 0),0
    LD (IY + 2),7
    JP MoveRock_Loop_Acceleration_END
    
MoveRock_Loop_AccelerationY_Plus:
    ; Yベクトルを取得
    LD A, (IY + 2)
    ; Yベクトルを加速
    ADD A, %00010000
    ADC A, 0
    ; Yベクトルを保存
    LD (IY + 2), A
    JP MoveRock_Loop_Acceleration_END
    
MoveRock_Loop_AccelerationY_Minus:
    ; Yベクトルを取得
    LD A, (IY + 2)
    ; Bレジスタにコピー
    LD B, A
    ; 整数部を取得
    AND %00000111
    JP Z, MoveRock_Loop_AccelerationY_Signchange
    
    ; Yベクトルを取得
    LD A, (IY + 2)
    ; Yベクトルを加速
    ADD A, %00100000
    SBC A, 0
    JP C, MoveRock_Loop_AccelerationY_Signchange
     
    ; Yベクトルを保存
    LD (IY + 2), A
    JP MoveRock_Loop_Acceleration_END
    
MoveRock_Loop_AccelerationY_Signchange:    
    ; Yベクトルを保存
    LD (IY + 2), 0	; 簡易的に、全て0にする

MoveRock_Loop_Acceleration_END:
    
    
MoveRock_LoopNext:
    ;IX を加算(次のループの準備)
    LD B, 0
    LD C, 4
    ADD IX,BC
    ;IYを加算（次のループの準備）
    LD C, 6
    ADD IY,BC
    
    ; 岩の番号全て処理する
    LD A, (WK_ROCK_NO)
    CP MAX_ROCK_COUNT
    JP NZ, MoveRock_Loop

	RET    
    

;--------------------------------------------
;ベクトル増分を加算する
;パラメータ
;	Aレジスタ ベクトル増分
;	Bレジスタ 小数の累積値
;   Cレジスタ 座標の値
;戻り値
;	Aレジスタ 計算した座標の値
;	Bレジスタ 小数値
;   Cフラグ 座標計算結果のキャリーフラグ
;破壊
;	DEレジスタ
;--------------------------------------------
MoveRock_Sub_AddVector:
    ; ベクトルをDレジスタにコピー
    LD D, A
        
    ; 整数部をEレジスタに設定
    AND %00000111
    LD E, A
    
    ; 小数部の計算
    LD A, D
    AND %11110000	;Yベクトルの小数部を取得

    ; ベクトルのマイナス判定
    BIT 3, D
    JP NZ, MoveRock_Sub_AddVector_Sub
    ; 小数部の加算処理
    ADD A, B
    JP MoveRock_Sub_AddVector_1
    
MoveRock_Sub_AddVector_Sub:
    ; 小数部の減算処理
    SUB B
    
MoveRock_Sub_AddVector_1:
    ;小数部の演算結果をBレジスタに格納
    LD B, A
    ; 座標値をAレジスタに設定
    LD A, C
    
    ; ベクトルのマイナス判定
    BIT 3, D
    JP NZ, MoveRock_Sub_AddVector_Minus	; マイナスの場合移動
    
    ; 座標に整数値とキャリーを加算
    ADC A, E
    JP MoveRock_Sub_AddVector_End

MoveRock_Sub_AddVector_Minus:
    ; 座標に整数値とキャリーを減算
    SBC A, E
    ; 補助レジスタペアと交換
    EX AF,AF'
    ; 小数部の余分なビットを削除
    LD A, B
    AND %11110000
    ; 補助レジスタペアと交換
    EX AF,AF'
    
MoveRock_Sub_AddVector_End:
    RET



;--------------------------------------------
;当たり判定
;--------------------------------------------
; 当たり判定ワーク
; 上位ループ用のIX、IYレジスタの保管用
WK_IX1:
   DEFB $00, $00	; 2バイト
WK_IY1:
   DEFB $00, $00	; 2バイト
;2重ループ内何番目の岩の処理を行っているかを格納するワーク
WK_ROCK_NO2:
   DEFB $00	; 1バイト


CollisionDetection:
    
    ; 弾の当たり判定
    CALL ShotCollisionDetection
    
    ; 岩の当たり判定
    CALL RockCollisionDetection
    RET


;--------------------------------------------
; 弾の当たり判定
;--------------------------------------------
ShotCollisionDetection:
    ; 弾の番号を初期化
    LD HL, WK_SHOT_NO
    LD (HL), 0
    
    ; ワークエリアの位置をIXレジスタに格納
    LD IX, WK_PLAYER_SHOT_SPRATTR
    
    ;弾の番号をAレジスタに設定
    LD A,(WK_SHOT_NO)

ShotCollisionDetection_Loop
	; 弾の番号を加算
    INC A
    LD (WK_SHOT_NO), A
    
    ; Y座標を取得
    LD A,(IX+0)
    
    ; Y座標が217の場合は消えている。次のループへ
    CP 217
    JP Z, ShotCollisionDetection_NextLoop
    
    ; 弾のスプライトパターンが通常では無い場合は次のループへ
    LD A,(IX+2)
    CP 12
    JP NZ, ShotCollisionDetection_NextLoop
    
    ; IXをワークに保存
    LD (WK_IX1), IX
    
    ; 岩のループ処理
    CALL ShotCollisionDetection_Rock
    
    ; IXを戻す
    LD IX, (WK_IX1)
    

ShotCollisionDetection_NextLoop:
    ;IX を加算(次のループの準備)
    LD B, 0
    LD C, 4
    ADD IX,BC
    
    ; 弾の番号全て処理する
    LD A, (WK_SHOT_NO)
    CP MAX_SHOT_COUNT
    JP NZ, ShotCollisionDetection_Loop
    
    ;全てのループを回った場合は対象無しのため処理を終了する
    JP ShotCollisionDetection_End
    
ShotCollisionDetection_End
	RET

; 岩のループ処理
ShotCollisionDetection_Rock:
    ; 岩の番号を初期化
    LD HL, WK_ROCK_NO
    LD (HL), 0
    
    ; ワークエリアの位置をIX、IYレジスタに格納
    LD IX, WK_ROCK_SPRATTR
    LD IY, WK_ROCK_STAT
    
    ;岩の番号をAレジスタに設定
    LD A,(WK_ROCK_NO)
    
ShotCollisionDetection_Rock_Loop:
    ; 岩の番号を加算
    INC A
    LD (WK_ROCK_NO), A
    
    LD A, (IX + 0)	; Y座標取得
    ; Y座標が217の場合、次のループ
    CP 217
    JP Z, ShotCollisionDetection_Rock_Loop_Next
    
    ; 岩のスプライトパターンが通常ではない場合は次のループ
    LD A,(IX+2)	; 岩のスプライトパターン
    CP 20
    JP NZ, ShotCollisionDetection_Rock_Loop_Next
    
    
    ; 弾と岩の衝突処理
    CALL CollisionHandlingShotAndRocks
    
ShotCollisionDetection_Rock_Loop_Next;
    ;IX を加算(次のループの準備)
    LD B, 0
    LD C, 4
    ADD IX, BC
    ;IYを加算（次のループの準備）
    LD C, 6
    ADD IY,BC
    
    ; 岩の番号全て処理する
    LD A, (WK_ROCK_NO)
    CP MAX_ROCK_COUNT
    JP NZ, ShotCollisionDetection_Rock_Loop

ShotCollisionDetection_Rock_End:
	RET
    
;--------------------------------------------
; 弾と岩の衝突処理
;--------------------------------------------
CollisionHandlingShotAndRocks:
    ; 弾のY座標を取得
    LD HL, (WK_IX1)
    LD A, (HL)
    ; 岩のY座標を取得
    LD B,(IX+0)
    ; 閾値内か判定
    LD C, 8
    CALL TwovalueCollisionDetection
    JP NC, CollisionHandlingShotAndRocks_End	; 閾値外の場合は終了
    
    ; 弾のX座標を取得
    INC HL
    LD A, (HL)
    ; 岩のX座標を取得
    LD B,(IX+1)
    ; 閾値内か判定
    LD C, 16
    CALL TwovalueCollisionDetection
    JP NC, CollisionHandlingShotAndRocks_End	; 閾値外の場合は終了
    
    ; 衝突処理
    ; 弾の絵を変える
    INC HL
    LD (HL), 16
    
    ; 岩の固さを減らす
    LD A,(IY+4)
    DEC A
    LD (IY+4), A
    JP NZ, CollisionHandlingShotAndRocks_1	; 固さが残っている場合は次の処理
    
CollisionHandlingShotAndRocks_CheckSoundPriority:
    ; 効果音のプライオリティチェック
    LD A, (WK_SOUND_PRIORITY)
    CP 3
    ; 優先度OKは効果音を鳴らす
    JP C, CollisionHandlingShotAndRocks_PlaySound
    LD A, (WK_SOUND_PRIORITY_FRAME)
    CP 0
    ; 優先度フレーム残がある場合は音を鳴らさない
    JP NZ, CollisionHandlingShotAndRocks_PlaySound_Emd    

CollisionHandlingShotAndRocks_PlaySound:
    ; 岩破壊の効果音を鳴らす
    ld a, $03 ; SOUND EFFECT NUMBER
    ld c, 0   ; CHANNEL ( 0:1ch 1:2ch 2:3ch )
    ld b, 0   ; VOLUME ( 0 - 16 : 0=Full Volume)
    call PLY_AKG_PLAYSOUNDEFFECT
    
    ; 優先度を設定
    LD A, 2
    LD (WK_SOUND_PRIORITY), A
    LD A, 30	; 0.5秒
    LD (WK_SOUND_PRIORITY_FRAME), A
    
CollisionHandlingShotAndRocks_PlaySound_Emd:
    
    
    ; 岩のスプライトパターンを変化させる
    LD (IX+2), 24
    ; ベクトル処理は行わない
    JP CollisionHandlingShotAndRocks_End
    
CollisionHandlingShotAndRocks_1

CollisionHandlingShotAndRocks_1_CheckSoundPriority:
    ; 効果音のプライオリティチェック
    LD A, (WK_SOUND_PRIORITY)
    CP 2
    ; 優先度OKは効果音を鳴らす
    JP C, CollisionHandlingShotAndRocks_1_PlaySound
    LD A, (WK_SOUND_PRIORITY_FRAME)
    CP 0
    ; 優先度フレーム残がある場合は音を鳴らさない
    JP NZ, CollisionHandlingShotAndRocks_1_PlaySound_Emd    

CollisionHandlingShotAndRocks_1_PlaySound:
    ; 岩ヒットの効果音を鳴らす
    ld a, $02 ; SOUND EFFECT NUMBER
    ld c, 0   ; CHANNEL ( 0:1ch 1:2ch 2:3ch )
    ld b, 2   ; VOLUME ( 0 - 16 : 0=Full Volume)
    call PLY_AKG_PLAYSOUNDEFFECT
    
    ; 優先度を設定
    LD A, 1
    LD (WK_SOUND_PRIORITY), A
    LD A, 15 ; 0.25秒
    LD (WK_SOUND_PRIORITY_FRAME), A
    
CollisionHandlingShotAndRocks_1_PlaySound_Emd:

    ; 岩のベクトル処理
    CALL CollisionHandlingShotAndRocks_Sub_Vector

CollisionHandlingShotAndRocks_End:
    RET



    ; 岩のベクトル処理サブルーチン
CollisionHandlingShotAndRocks_Sub_Vector:
    ; 岩のYベクトルを取得
    LD A,(IY+2)
    LD B, A	; Bレジスタにコピー
    ; ベクトルの符号チェック
    AND %00001000
    JP NZ, CollisionHandlingShotAndRocks_Sub_Vector_Minus	; マイナスの処理
    
    ; ベクトルの整数部を取得
    LD A, B
    AND %00000111
    ; 1で引けるか確認
    CP 1
    JP C, CollisionHandlingShotAndRocks_Sub_Vector_Plus_1	; 1で引けない場合は飛ぶ
    
    ; ベクトルを減算
    LD A, B
    DEC A
    ; 計算後のベクトルを設定
    LD (IY+2), A
    JP CollisionHandlingShotAndRocks_Sub_Vector_End	; ベクトルの処理終了
    
CollisionHandlingShotAndRocks_Sub_Vector_Plus_1:
    ; 1から整数部を引く
    LD C, A	; 整数部をCレジスタにコピー
    LD A, 1
    DEC C
    ; 結果をCレジスタに保存
    LD C, A
    
    ; ベクトルの小数部を取得
    LD A, B
    AND %11110000
    ; 計算した整数部を加算
    ADD A,C
    ; 符号をマイナスに設定
    SET 3, A
    
    ; 計算後のベクトルを設定
    LD (IY+2), A
    JP CollisionHandlingShotAndRocks_Sub_Vector_End	; ベクトルの処理終了
    
    ; ベクトルがマイナスの処理
CollisionHandlingShotAndRocks_Sub_Vector_Minus:
    ; 整数部に1を加算
    INC A
    ; 整数部が3を超える場合は3にする
    CP 4
    JP C, CollisionHandlingShotAndRocks_Sub_Vector_Minus_1	; 超えない場合は次の処理
    LD A, 3
    
CollisionHandlingShotAndRocks_Sub_Vector_Minus_1:
    ; 整数部をCレジスタに保存
    LD C, A
    ; ベクトルの小数部と符号を取得
    LD A, B
    AND %11111000
    ; 計算した整数部を加算
    ADD A,C
    
    ; 計算後のベクトルを設定
    LD (IY+2), A

CollisionHandlingShotAndRocks_Sub_Vector_End
    RET




;--------------------------------------------
; 岩の当たり判定
;--------------------------------------------
RockCollisionDetection:
    ; 岩の番号を初期化
    LD HL, WK_ROCK_NO
    LD (HL), 0
    
    ; ワークエリアの位置をIX、IYレジスタに格納
    LD IX, WK_ROCK_SPRATTR
    LD IY, WK_ROCK_STAT
    
    ;岩の番号をAレジスタに設定
    LD A,(WK_ROCK_NO)
    
RockCollisionDetection_Loop:
	; 岩の番号を加算
    INC A
    LD (WK_ROCK_NO), A
    
    LD A, (IX + 0)	; Y座標取得
    ; Y座標が217の場合、次のループ
    CP 217
    JP Z, RockCollisionDetection_Loop_Next
    
    ; 岩のスプライトパターンが通常ではない場合は次のループ
    LD A,(IX+2)
    CP 20
    JP NZ, RockCollisionDetection_Loop_Next
    
    ; IX、IYレジスタの値を保存
    LD (WK_IX1), IX
    LD (WK_IY1), IY
    
    ; 衝突先の判定
    CALL RockCollisionDetection2
    
    ; IX、IYレジスタの値を戻す
    LD IX, (WK_IX1)
    LD IY, (WK_IY1)
    
    
RockCollisionDetection_Loop_Next;
    ;IX を加算(次のループの準備)
    LD B, 0
    LD C, 4
    ADD IX, BC
    ;IYを加算（次のループの準備）
    LD C, 6
    ADD IY,BC
    
    ; 岩の番号全てより１つ前まで処理する
    LD A, (WK_ROCK_NO)
    CP MAX_ROCK_COUNT - 1
    JP NZ, RockCollisionDetection_Loop

RockCollisionDetection_End:
	RET



; 2重ループ内の岩の処理
RockCollisionDetection2:
    ;IX を加算
    LD B, 0
    LD C, 4
    ADD IX, BC
    ;IYを加算
    LD C, 6
    ADD IY,BC
    
    ; 判定元の岩の番号をAレジスタに設定
    LD A, (WK_ROCK_NO)
    
RockCollisionDetection2_Loop:
	; 岩の番号を加算
    INC A
    LD (WK_ROCK_NO2), A
    
    LD A, (IX + 0)	; Y座標取得
    ; Y座標が217の場合、次のループ
    CP 217
    JP Z, RockCollisionDetection2_Loop_Next
    
    ; 岩のスプライトパターンが通常ではない場合は次のループ
    LD A,(IX+2)
    CP 20
    JP NZ, RockCollisionDetection2_Loop_Next
    
    ; 衝突元のY座標をAレジスタに設定
    LD HL, (WK_IX1)
    LD A, (HL)
    ; 衝突先のY座標をBレジスタに設定
    LD B, (IX+0)
    ; 閾値16
    LD C, 17
    ; 衝突判定
    CALL TwovalueCollisionDetection
    ; 衝突していない場合は次のループ
    JP NC, RockCollisionDetection2_Loop_Next
    
    ; 衝突元のX座標をAレジスタに設定
    LD HL, (WK_IX1)
    INC HL
    LD A, (HL)
    ; 衝突先のX座標をBレジスタに設定
    LD B, (IX+1)
    ; 衝突判定
    CALL TwovalueCollisionDetection
    ; 衝突していない場合は次のループ
    JP NC, RockCollisionDetection2_Loop_Next
    
    ; 衝突処理
    CALL CollisionHandlingBetweenRocks
    
RockCollisionDetection2_Loop_Next;
    ;IX を加算(次のループの準備)
    LD B, 0
    LD C, 4
    ADD IX, BC
    ;IYを加算（次のループの準備）
    LD C, 6
    ADD IY,BC
    
    ; 岩の番号全て処理する
    LD A, (WK_ROCK_NO2)
    CP MAX_ROCK_COUNT
    JP NZ, RockCollisionDetection2_Loop

RockCollisionDetection2_End:
	RET



;--------------------------------------------
;岩同士の衝突処理
;--------------------------------------------
; ベクトル計算用ワーク
; 座標
WK_CollisionHandlingBetweenRocks_AY:
   DEFB $00	; 1バイト
WK_CollisionHandlingBetweenRocks_BY:
   DEFB $00	; 1バイト
WK_CollisionHandlingBetweenRocks_AX:
   DEFB $00	; 1バイト
WK_CollisionHandlingBetweenRocks_BX:
   DEFB $00	; 1バイト
; ベクトル
WK_CollisionHandlingBetweenRocks_VectorAY:
   DEFB $00	; 1バイト
WK_CollisionHandlingBetweenRocks_VectorBY:
   DEFB $00	; 1バイト
WK_CollisionHandlingBetweenRocks_VectorAX:
   DEFB $00	; 1バイト
WK_CollisionHandlingBetweenRocks_VectorBX:
   DEFB $00	; 1バイト
; 衝突区分　衝突先の位置
; 上位4ビット Y座標衝突位置 未使用:上:中:下
; 下位4ビット X座標衝突位置 未使用:左:中:右
WK_CollisionHandlingBetweenRocks_ClassBit:
   DEFB $00	; 1バイト
; 接近区分
; 1ビット目Yベクトルが接近する場合は1
; 0ビット目Xベクトルが接近する場合は1
WK_CollisionHandlingBetweenRocks_ApproachBit
   DEFB $00	; 1バイト
   
CollisionHandlingBetweenRocks:
    ; ワークの作成
    ; 衝突元
    LD HL, (WK_IX1)
    LD A, (HL)
    LD (WK_CollisionHandlingBetweenRocks_AY), A	; Y座標を設定
    INC HL
    LD A, (HL)
    LD (WK_CollisionHandlingBetweenRocks_AX), A	; X座標を設定
    
    LD HL, (WK_IY1)
    INC HL
    INC HL
    LD A, (HL)
    LD (WK_CollisionHandlingBetweenRocks_VectorAY), A	; Yベクトルを設定
    INC HL
    LD A, (HL)
    LD (WK_CollisionHandlingBetweenRocks_VectorAX), A	; Xベクトルを設定
    
    ; 衝突先
    LD A, (IX+0)
    LD (WK_CollisionHandlingBetweenRocks_BY), A	; Y座標を設定
    LD A, (IX+1)
    LD (WK_CollisionHandlingBetweenRocks_BX), A	; X座標を設定

    LD A, (IY+2)
    LD (WK_CollisionHandlingBetweenRocks_VectorBY), A	; Yベクトルを設定
    LD A, (IY+3)
    LD (WK_CollisionHandlingBetweenRocks_VectorBX), A	; Xベクトルを設定
    
    ; 衝突区分、接近区分を初期化
    XOR A	; Aレジスタを0に設定
    LD (WK_CollisionHandlingBetweenRocks_ClassBit), A
    LD (WK_CollisionHandlingBetweenRocks_ApproachBit), A
    
    ; 衝突区分を計算
    CALL CollisionHandlingBetweenRocks_Sub_CalculateClassBit
    
    ; 接近区分計算
    CALL CollisionHandlingBetweenRocks_Sub_CalculateApproachBit
    
    ; Yの接近区分取得
    LD A, (WK_CollisionHandlingBetweenRocks_ApproachBit)
    AND %00000010
    JP Z, CollisionHandlingBetweenRocks_1	; Yベクトルが接近しない場合は移動
    
    ; Yベクトルを入れ替える
    LD HL, (WK_IY1)
    INC HL
    INC HL
    LD A, (HL)
    LD B, A
    LD A, (IY+2)
    LD (HL), A
    LD (IY+2), B

CollisionHandlingBetweenRocks_1;
    ; Xの接近区分取得
    LD A, (WK_CollisionHandlingBetweenRocks_ApproachBit)
    AND %00000001
    JP Z, CollisionHandlingBetweenRocks_End	; Xベクトルが接近しない場合は移動

    ; Xベクトルを入れ替える
    LD HL, (WK_IY1)
    INC HL
    INC HL
    INC HL
    LD A, (HL)
    LD B, A
    LD A, (IY+3)
    LD (HL), A
    LD (IY+3), B

CollisionHandlingBetweenRocks_End:
    RET


; 衝突区分計算サブルーチン
CollisionHandlingBetweenRocks_Sub_CalculateClassBit:
    ; HLレジスタに、衝突区分のアドレスを転送
    LD HL, WK_CollisionHandlingBetweenRocks_ClassBit
 
    ; Y座標のチェック
CollisionHandlingBetweenRocks_Sub_CalculateClassBit_Y
    ; Y座標が閾値9内か判定
    LD A, (WK_CollisionHandlingBetweenRocks_BY)
    LD B, A
    LD A, (WK_CollisionHandlingBetweenRocks_AY)
    LD C, 9
    CALL TwovalueCollisionDetection
    JP NC, CollisionHandlingBetweenRocks_Sub_CalculateClassBit_1	; 閾値外の場合は移動

    ; 衝突先Yは中
    SET 5, (HL)
    JP CollisionHandlingBetweenRocks_Sub_CalculateClassBit_X

CollisionHandlingBetweenRocks_Sub_CalculateClassBit_1:
    ; 衝突元、先のどちらの座標が大きいか比較
    LD A, (WK_CollisionHandlingBetweenRocks_BY)
    LD B, A
    LD A, (WK_CollisionHandlingBetweenRocks_AY)
    CP B
    JP C, CollisionHandlingBetweenRocks_Sub_CalculateClassBit_2	; 衝突元が小さい場合は移動

    ; 衝突先Yは上
    SET 6, (HL)
    JP CollisionHandlingBetweenRocks_Sub_CalculateClassBit_X


CollisionHandlingBetweenRocks_Sub_CalculateClassBit_2:   
    ; 衝突先Yは下
    SET 4, (HL)
    JP CollisionHandlingBetweenRocks_Sub_CalculateClassBit_X
    
    ; X座標のチェック
CollisionHandlingBetweenRocks_Sub_CalculateClassBit_X:
    ; X座標が閾値9内か判定
    LD A, (WK_CollisionHandlingBetweenRocks_BX)
    LD B, A
    LD A, (WK_CollisionHandlingBetweenRocks_AX)
    LD C, 9
    CALL TwovalueCollisionDetection
    JP NC, CollisionHandlingBetweenRocks_Sub_CalculateClassBit_3	; 閾値外の場合は移動
    
    ; 衝突先Xは中
    SET 1, (HL)
    JP CollisionHandlingBetweenRocks_Sub_CalculateClassBit_End

CollisionHandlingBetweenRocks_Sub_CalculateClassBit_3:
    ; 衝突元、先のどちらの座標が大きいか比較
    LD A, (WK_CollisionHandlingBetweenRocks_BX)
    LD B, A
    LD A, (WK_CollisionHandlingBetweenRocks_AX)
    CP B
    JP C, CollisionHandlingBetweenRocks_Sub_CalculateClassBit_4	; 衝突元が小さい場合は移動

    ; 衝突先Xは左
    SET 2, (HL)
    JP CollisionHandlingBetweenRocks_Sub_CalculateClassBit_End

CollisionHandlingBetweenRocks_Sub_CalculateClassBit_4:
    ; 衝突先Xは右
    SET 0, (HL)

CollisionHandlingBetweenRocks_Sub_CalculateClassBit_End:
    RET


; 接近区分計算サブルーチン
CollisionHandlingBetweenRocks_Sub_CalculateApproachBit:
    ; Yベクトルの処理
CollisionHandlingBetweenRocks_Sub_CalculateApproachBit_Y:
    ; 衝突区分のアドレスをHLレジスタに設定
    LD HL, WK_CollisionHandlingBetweenRocks_ClassBit
    
    ; Yベクトルのチェック
    ; 衝突区分を判定
    LD A, (HL)
    AND %01000000
    JP NZ, CollisionHandlingBetweenRocks_Sub_CalculateApproachBit_Y_UP	; 上方向に衝突
    
    LD A, (HL)
    AND %00010000
    JP NZ, CollisionHandlingBetweenRocks_Sub_CalculateApproachBit_Y_DOWN	; 下方向に衝突
    
    ; Xの処理へ
    JP CollisionHandlingBetweenRocks_Sub_CalculateApproachBit_X
    
    ; 衝突元の上で衝突した場合
CollisionHandlingBetweenRocks_Sub_CalculateApproachBit_Y_UP:
    ; 接近区分のアドレスをHLレジスタに設定
    LD HL, WK_CollisionHandlingBetweenRocks_ApproachBit

    ; Yベクトルを取得
    LD A, (WK_CollisionHandlingBetweenRocks_VectorAY)
    LD D, A	; Dレジスタにコピー
    LD A, (WK_CollisionHandlingBetweenRocks_VectorBY)
    LD E, A ; Eレジスタにコピー
    
    ; AのYベクトルの符号をチェック
    LD A, D
    AND %00001000
    JP NZ, CollisionHandlingBetweenRocks_Sub_CalculateApproachBit_Y_UP_Minus	; マイナス
    
    JP CollisionHandlingBetweenRocks_Sub_CalculateApproachBit_Y_UP_Plus	; プラス
    
    ; Yベクトルがマイナスの処理
CollisionHandlingBetweenRocks_Sub_CalculateApproachBit_Y_UP_Minus:
    ; BのYベクトルの符号をチェック
    LD A, E
    AND %00001000
    JP NZ, CollisionHandlingBetweenRocks_Sub_CalculateApproachBit_Y_UP_Minus_Minus	; マイナス
    
    ; マイナス　プラスは接近している
    SET 1, (HL)
    JP CollisionHandlingBetweenRocks_Sub_CalculateApproachBit_X
    
    ; マイナス　マイナス
CollisionHandlingBetweenRocks_Sub_CalculateApproachBit_Y_UP_Minus_Minus:
    ; Yベクトルを取得
    LD A, (WK_CollisionHandlingBetweenRocks_VectorBY)
    LD B, A
    LD A, (WK_CollisionHandlingBetweenRocks_VectorAY)
    ; 長さを判定
    CALL JudgeVectorSize
    
    ; 短い場合は接近していない　Xの処理へ移動
    JP C, CollisionHandlingBetweenRocks_Sub_CalculateApproachBit_X
    
    ; 接近している
    SET 1, (HL)
    JP CollisionHandlingBetweenRocks_Sub_CalculateApproachBit_X

    ; Yベクトルがプラスの処理
CollisionHandlingBetweenRocks_Sub_CalculateApproachBit_Y_UP_Plus:
    ; BのYベクトルの符号をチェック
    LD A, E
    AND %00001000
    ; プラス　マイナス　は接近していない　Xの処理へ異動
    JP NZ, CollisionHandlingBetweenRocks_Sub_CalculateApproachBit_X
    
    ; プラス　プラス
    ; Yベクトルを取得
    LD A, (WK_CollisionHandlingBetweenRocks_VectorBY)
    LD B, A
    LD A, (WK_CollisionHandlingBetweenRocks_VectorAY)
    ; 長さを判定
    CALL JudgeVectorSize
    ; 長い場合は接近していない　Xの処理へ移動
    JP NC, CollisionHandlingBetweenRocks_Sub_CalculateApproachBit_X
    
    ; 接近している
    SET 1, (HL)
    JP CollisionHandlingBetweenRocks_Sub_CalculateApproachBit_X

    ; 衝突元の下で衝突した場合
CollisionHandlingBetweenRocks_Sub_CalculateApproachBit_Y_DOWN:
    ; 接近区分のアドレスをHLレジスタに設定
    LD HL, WK_CollisionHandlingBetweenRocks_ApproachBit
    
    ; Yベクトルを取得
    LD A, (WK_CollisionHandlingBetweenRocks_VectorAY)
    LD D, A	; Dレジスタにコピー
    LD A, (WK_CollisionHandlingBetweenRocks_VectorBY)
    LD E, A ; Eレジスタにコピー
    
    ; AのYベクトルの符号をチェック
    LD A, D
    AND %00001000
    JP NZ, CollisionHandlingBetweenRocks_Sub_CalculateApproachBit_Y_DOWN_Minus	; マイナス
    
    JP CollisionHandlingBetweenRocks_Sub_CalculateApproachBit_Y_DOWN_Plus	; プラス

    ; Yベクトルがマイナスの処理
CollisionHandlingBetweenRocks_Sub_CalculateApproachBit_Y_DOWN_Minus:
    ; BのYベクトルの符号をチェック
    LD A, E
    AND %00001000
    JP NZ, CollisionHandlingBetweenRocks_Sub_CalculateApproachBit_Y_DOWN_Minus_Minus	; マイナス
    
    ; マイナス　プラス　は接近していない　Xの処理へ異動
    JP CollisionHandlingBetweenRocks_Sub_CalculateApproachBit_X	; プラス

	; マイナス　マイナス
CollisionHandlingBetweenRocks_Sub_CalculateApproachBit_Y_DOWN_Minus_Minus:
    ; Yベクトルを取得
    LD A, (WK_CollisionHandlingBetweenRocks_VectorBY)
    LD B, A
    LD A, (WK_CollisionHandlingBetweenRocks_VectorAY)
    ; 長さを判定
    CALL JudgeVectorSize
    ; 長い場合は接近していない　Xの処理へ移動
    JP NC, CollisionHandlingBetweenRocks_Sub_CalculateApproachBit_X
    
    ; 接近している
    SET 1, (HL)
    JP CollisionHandlingBetweenRocks_Sub_CalculateApproachBit_X

    ; Yベクトルがプラスの処理
CollisionHandlingBetweenRocks_Sub_CalculateApproachBit_Y_DOWN_Plus:
    ; BのYベクトルの符号をチェック
    LD A, E
    AND %00001000
    JP NZ, CollisionHandlingBetweenRocks_Sub_CalculateApproachBit_Y_DOWN_Plus_Minus	; マイナス
    
    JP CollisionHandlingBetweenRocks_Sub_CalculateApproachBit_Y_DOWN_Plus_Plus	; プラス

    ; プラス　マイナス
CollisionHandlingBetweenRocks_Sub_CalculateApproachBit_Y_DOWN_Plus_Minus
    ; 接近している
    SET 1, (HL)
    JP CollisionHandlingBetweenRocks_Sub_CalculateApproachBit_X

    ; プラス　プラス
CollisionHandlingBetweenRocks_Sub_CalculateApproachBit_Y_DOWN_Plus_Plus
    ; Yベクトルを取得
    LD A, (WK_CollisionHandlingBetweenRocks_VectorBY)
    LD B, A
    LD A, (WK_CollisionHandlingBetweenRocks_VectorAY)
    ; 長さを判定
    CALL JudgeVectorSize
    ; 短い場合は接近していない　Xの処理へ移動
    JP C, CollisionHandlingBetweenRocks_Sub_CalculateApproachBit_X

    ; 接近している
    SET 1, (HL)
    JP CollisionHandlingBetweenRocks_Sub_CalculateApproachBit_X

    ; Xベクトルの処理
CollisionHandlingBetweenRocks_Sub_CalculateApproachBit_X

    ; 衝突区分のアドレスをHLレジスタに設定
    LD HL, WK_CollisionHandlingBetweenRocks_ClassBit
    ; Xベクトルのチェック
    ; 衝突区分を判定
    LD A, (HL)
    AND %00000100
    JP NZ, CollisionHandlingBetweenRocks_Sub_CalculateApproachBit_X_LEFT	; 左方向に衝突
    
    LD A, (HL)
    AND %00000001
    JP NZ, CollisionHandlingBetweenRocks_Sub_CalculateApproachBit_X_RIGHT	; 右方向に衝突
    
    ; 終了
    JP CollisionHandlingBetweenRocks_Sub_CalculateApproachBit_End
    
    
    ; 衝突元の左で衝突した場合
CollisionHandlingBetweenRocks_Sub_CalculateApproachBit_X_LEFT:
    ; 接近区分のアドレスをHLレジスタに設定
    LD HL, WK_CollisionHandlingBetweenRocks_ApproachBit
    
    ; Xベクトルを取得
    LD A, (WK_CollisionHandlingBetweenRocks_VectorAX)
    LD D, A	; Dレジスタにコピー
    LD A, (WK_CollisionHandlingBetweenRocks_VectorBX)
    LD E, A ; Eレジスタにコピー
    
    ; AのXベクトルの符号をチェック
    LD A, D
    AND %00001000
    JP NZ, CollisionHandlingBetweenRocks_Sub_CalculateApproachBit_X_LEFT_Minus	; マイナス
    
    JP CollisionHandlingBetweenRocks_Sub_CalculateApproachBit_X_LEFT_Plus	; プラス

    ; Xベクトルがマイナスの処理
CollisionHandlingBetweenRocks_Sub_CalculateApproachBit_X_LEFT_Minus:
    ; BのXベクトルの符号をチェック
    LD A, E
    AND %00001000
    JP NZ, CollisionHandlingBetweenRocks_Sub_CalculateApproachBit_X_LEFT_Minus_Minus	; マイナス
    
    ; マイナス　プラス　は接近している
    SET 0, (HL)
    JP CollisionHandlingBetweenRocks_Sub_CalculateApproachBit_End
    
    ; マイナス　マイナス
CollisionHandlingBetweenRocks_Sub_CalculateApproachBit_X_LEFT_Minus_Minus
    ; Xベクトルを取得
    LD A, (WK_CollisionHandlingBetweenRocks_VectorBX)
    LD B, A
    LD A, (WK_CollisionHandlingBetweenRocks_VectorAX)
    ; 長さを判定
    CALL JudgeVectorSize
    
    ; 短い場合は接近していない　終了
    JP C, CollisionHandlingBetweenRocks_Sub_CalculateApproachBit_End
    
    ; 接近している
    SET 0, (HL)
    JP CollisionHandlingBetweenRocks_Sub_CalculateApproachBit_End

    ; Xベクトルがプラスの処理
CollisionHandlingBetweenRocks_Sub_CalculateApproachBit_X_LEFT_Plus:
    ; BのXベクトルの符号をチェック
    LD A, E
    AND %00001000
    ; プラス　マイナス　は接近していない　終了
    JP NZ, CollisionHandlingBetweenRocks_Sub_CalculateApproachBit_End
    
    ; プラス　プラス
    ; Xベクトルを取得
    LD A, (WK_CollisionHandlingBetweenRocks_VectorBX)
    LD B, A
    LD A, (WK_CollisionHandlingBetweenRocks_VectorAX)
    ; 長さを判定
    CALL JudgeVectorSize
    ; 長い場合は接近していない　終了
    JP NC, CollisionHandlingBetweenRocks_Sub_CalculateApproachBit_End
    
    ; 接近している
    SET 0, (HL)
    JP CollisionHandlingBetweenRocks_Sub_CalculateApproachBit_End


    ; 衝突元の右で衝突した場合
CollisionHandlingBetweenRocks_Sub_CalculateApproachBit_X_RIGHT:
    ; 接近区分のアドレスをHLレジスタに設定
    LD HL, WK_CollisionHandlingBetweenRocks_ApproachBit
    
    ; Xベクトルを取得
    LD A, (WK_CollisionHandlingBetweenRocks_VectorAX)
    LD D, A	; Dレジスタにコピー
    LD A, (WK_CollisionHandlingBetweenRocks_VectorBX)
    LD E, A ; Eレジスタにコピー
    
    ; AのXベクトルの符号をチェック
    LD A, D
    AND %00001000
    JP NZ, CollisionHandlingBetweenRocks_Sub_CalculateApproachBit_X_Right_Minus	; マイナス
    
    JP CollisionHandlingBetweenRocks_Sub_CalculateApproachBit_X_Right_Plus	; プラス

    ; Xベクトルがマイナスの処理
CollisionHandlingBetweenRocks_Sub_CalculateApproachBit_X_Right_Minus:
    ; BのXベクトルの符号をチェック
    LD A, E
    AND %00001000
    JP NZ, CollisionHandlingBetweenRocks_Sub_CalculateApproachBit_X_Right_Minus_Minus	; マイナス
    ; マイナス　プラス　は接近していない　終了
    JP CollisionHandlingBetweenRocks_Sub_CalculateApproachBit_End
    
    ; マイナス　マイナス
CollisionHandlingBetweenRocks_Sub_CalculateApproachBit_X_Right_Minus_Minus
    ; Xベクトルを取得
    LD A, (WK_CollisionHandlingBetweenRocks_VectorBX)
    LD B, A
    LD A, (WK_CollisionHandlingBetweenRocks_VectorAX)
    ; 長さを判定
    CALL JudgeVectorSize
    ; 長い場合は接近していない　終了
    JP NC, CollisionHandlingBetweenRocks_Sub_CalculateApproachBit_End
    
    ; 接近している
    SET 0, (HL)
    JP CollisionHandlingBetweenRocks_Sub_CalculateApproachBit_End

    ; Xベクトルがプラスの処理
CollisionHandlingBetweenRocks_Sub_CalculateApproachBit_X_Right_Plus:
    ; BのXベクトルの符号をチェック
    LD A, E
    AND %00001000
    JP NZ, CollisionHandlingBetweenRocks_Sub_CalculateApproachBit_X_Right_Plus_Minus	; マイナス
    JP CollisionHandlingBetweenRocks_Sub_CalculateApproachBit_X_Right_Plus_Plus	;プラス
    
    ; プラス　マイナス
CollisionHandlingBetweenRocks_Sub_CalculateApproachBit_X_Right_Plus_Minus
    ; 接近している
    SET 0, (HL)
    JP CollisionHandlingBetweenRocks_Sub_CalculateApproachBit_End

    ; プラス　プラス
CollisionHandlingBetweenRocks_Sub_CalculateApproachBit_X_Right_Plus_Plus
    ; Xベクトルを取得
    LD A, (WK_CollisionHandlingBetweenRocks_VectorBX)
    LD B, A
    LD A, (WK_CollisionHandlingBetweenRocks_VectorAX)
    ; 長さを判定
    CALL JudgeVectorSize
    ; 短い場合は接近していない　終了
    JP C, CollisionHandlingBetweenRocks_Sub_CalculateApproachBit_End
    
    ; 接近している
    SET 0, (HL)
    JP CollisionHandlingBetweenRocks_Sub_CalculateApproachBit_End
    
CollisionHandlingBetweenRocks_Sub_CalculateApproachBit_End:
    RET



;--------------------------------------------
; ベクトルの方向を無視して長さを判定する
; パラメータ
;	Aレジスタ	ベクトルA
;	Bレジスタ	ベクトルB
; 戻り値
;	キャリーフラグ　ベクトルAが小さい場合1
; 破壊
;	D、E レジスタ
;--------------------------------------------
JudgeVectorSize:
    ; D、Eレジスタにコピー
    LD D, A
    LD E, B
    
    ; 整数比較
    LD A, E
    AND %00000111	; Bの整数
    LD B, A
    LD A, D
    AND %00000111	; Aの整数
    CP B
    ; キャリーが立った場合はリターン
    RET C
    
    ; 小数まで比較
    LD A, E
    AND %11110111	; Bの符号なし
    LD B, A
    LD A, D
    AND %11110111	; Aの符号なし
    CP B
    ; キャリーの結果を戻す
    RET



 
 


;--------------------------------------------
;2つの値の差が閾値内か判定する
;パラメータ
;	Aレジスタ 値1
;	Bレジスタ 値2
;	Cレジスタ 閾値
;破壊
;	Aレジスタ
;	Bレジスタ
;	Dレジスタ
;戻り値
;	キャリーフラグ　立っている場合は閾値内
;--------------------------------------------
TwovalueCollisionDetection:
    ; AレジスタとBレジスタの大小を比較
    CP B
    JP NC, TwovalueCollisionDetection_Detection
    ; Aレジスタが小さい場合AレジスタとBレジスタを入れ替え
    LD D, A
    LD A, B
    LD B, D
TwovalueCollisionDetection_Detection:
    SUB B
    ; 閾値判定
    CP C
TwovalueCollisionDetection_End
    RET



;--------------------------------------------
; SUB-ROUTINE: CreatePlayerWorkSpriteAttr
; プレーヤーのワーク用スプライトアトリビュートテーブルを
; 作成する
;
; IXレジスタ：SPRDISTPTN_TBLのポインタ
; をセットしてから呼び出すこと
;
; CreatePlayerWorkSpriteAttr
;   |
;   v
; PutSprite
;
; の順で処理を行うこと
;--------------------------------------------
CreatePlayerWorkSpriteAttr:

    ;--------------------------------------------
    ; ワーク用スプライトアトリビュートテーブル
    ; を作成する
    ;--------------------------------------------
    ld iy, WK_PLAYERSPRATTR

    ; スプライト1枚目
    ; 自機
    ld a, (ix)   ; スプライトパターン番号
    ld (iy+2), a

    ret   
    
;--------------------------------------------
; SUB-ROUTINE: PutSprite
; ワーク用スプライトアトリビュートテーブルの内容を
; DEレジスタが指し示すVRAMアドレスにブロック転送する
; BCレジスタ：転送バイト数
;--------------------------------------------
PutSprite:

    ;--------------------------------------------
    ; スプライトアトトリビュートテーブルは次の
    ; ようになっている
    ;
    ; 例
    ; 1B00H-1B03H : スプライト番号#0
    ; 1B04H-1B07H : スプライト番号#1
    ; :
    ; というように4バイトごとにスプライト番号が付いている
    ;
    ; スプライトパターン番号とスプライト番号は異なる
    ; 例
    ; スプライト番号#0を構成するスプライトパターン番号は#0-#3
    ; スプライト番号#1を構成するスプライトパターン番号は#4-#7
    ;
    ; 以下、アトリビュートテーブルの詳細
    ;
    ; 1B00H : スプライト#0のY座標
    ; 1B01H : スプライト#0のX座標
    ; 1B02H : スプライト#0のパターン番号
    ; 1B03H : スプライト#0カラーコード
    ;
    ; 1B04H : スプライト#1のY座標
    ; 1B05H : スプライト#1のX座標
    ; 1B06H : スプライト#1のパターン番号
    ; 1B07H : スプライト#1カラーコード
    ;  :
    ; 
    ; パターン番号のいちばん低いスプライトが優先表示される
    ; スプライトが画面水平に重なると5個め以降のスプライトの
    ; 重なっているスプライト面は非表示となる
    ;--------------------------------------------

    ld hl, WK_PLAYERSPRATTR
    call LDIRVM

    ret



;include "data_sprite.asm"
;--------------------------------------------
; data_sprite.asm
; 固定データ(スプライト作成用)
;--------------------------------------------
; キャラクタパターン
; データサイズは1つあたり32バイト
SPRPTN:

; プレーヤー
; 通常
defb $01,$01,$01,$03,$02,$0E,$0F,$1B ; SPRITE#0
defb $7B,$FB,$FB,$FB,$DB,$DD,$05,$0D ;
defb $80,$80,$80,$C0,$40,$70,$F0,$D8 ;
defb $DE,$DF,$DF,$DF,$DB,$BB,$A0,$B0 ;
; 左
defb $01,$01,$03,$03,$01,$01,$0B,$1F ; SPRITE#4
defb $1B,$3B,$37,$37,$37,$3F,$0D,$0C ;
defb $00,$00,$80,$80,$80,$80,$D0,$F8 ;
defb $B8,$BC,$BC,$BC,$9C,$9C,$40,$40 ;
; 右
defb $00,$00,$01,$01,$01,$01,$0B,$1F ; SPRITE#8
defb $1D,$3D,$3D,$3D,$39,$39,$02,$02 ;
defb $80,$80,$C0,$C0,$80,$80,$D0,$F8 ;
defb $D8,$DC,$EC,$EC,$EC,$FC,$B0,$30 ;

; 自機弾
defb $00,$00,$00,$00,$00,$00,$00,$04 ; SPRITE#12
defb $04,$00,$00,$00,$00,$00,$00,$00
defb $00,$00,$00,$00,$00,$00,$00,$20
defb $20,$00,$00,$00,$00,$00,$00,$00

; 自機弾（消滅）
defb $00,$08,$10,$24,$40,$08,$00,$00 ; SPRITE#16
defb $00,$00,$00,$00,$00,$00,$00,$00
defb $00,$10,$08,$24,$02,$10,$00,$00
defb $00,$00,$00,$00,$00,$00,$00,$00

; 岩
defb $03,$04,$13,$39,$78,$E1,$B7,$BF ; SPRITE#20
defb $D8,$8E,$C3,$7D,$7E,$32,$3F,$07
defb $E0,$FC,$FE,$3B,$0F,$E7,$DF,$CF
defb $E7,$EE,$7E,$FE,$7C,$F8,$E0,$80

;岩　破壊１
defb $00,$01,$09,$19,$38,$30,$02,$03 ; SPRITE#24
defb $21,$2D,$7F,$47,$62,$3E,$5C,$00
defb $00,$C8,$DE,$8E,$00,$04,$74,$C0
defb $84,$94,$B8,$30,$4C,$B8,$00,$00

;岩　破壊２
defb $00,$20,$49,$18,$38,$30,$02,$01 ; SPRITE#28
defb $20,$29,$70,$40,$62,$3E,$5C,$00
defb $00,$C8,$DE,$0E,$00,$04,$14,$00
defb $04,$14,$B8,$30,$4C,$B8,$0C,$00

;岩　破壊３
defb $00,$20,$49,$18,$30,$20,$00,$00 ; SPRITE#32
defb $20,$20,$44,$40,$04,$32,$50,$00
defb $00,$C8,$DE,$06,$60,$64,$04,$00
defb $04,$00,$00,$00,$4C,$B8,$0C,$00

;岩　破壊４
defb $00,$20,$49,$08,$00,$20,$00,$00 ; SPRITE#36
defb $00,$40,$40,$00,$04,$10,$41,$00
defb $00,$48,$02,$00,$40,$24,$00,$00
defb $04,$00,$00,$00,$04,$00,$4C,$00


; スプライトの向きにあわせたパターン番号
; パターン番号は指定した番号から連続して4個使用する
; カラーはここでは定義しない
SPRDISTPTN_TBL:
; 上
defb  0 ; パターン番号
; 左
defb  4 ; パターン番号
; 右
defb  8 ; パターン番号


; スプライトの移動方向を格納したテーブル
; 1バイト内の上位4ビットがX方向の移動量
; 1バイト内の下位4ビットがY方向の移動量
; 移動量が2の場合は-1として処理する
PLAYERMOVE_TBL:
defb $00 ; ジョイスティック方向0
defb $02 ; ジョイスティック方向1(X= 0, Y=-1)
defb $12 ; ジョイスティック方向2(X= 1, Y=-1)
defb $10 ; ジョイスティック方向3(X= 1, Y= 0)
defb $11 ; ジョイスティック方向4(X= 1, Y= 1)
defb $01 ; ジョイスティック方向5(X= 0, Y= 1)
defb $21 ; ジョイスティック方向6(X=-1, Y= 1)
defb $20 ; ジョイスティック方向7(X=-1, Y= 0)
defb $22 ; ジョイスティック方向8(X=-1, Y=-1)



;--------------------------------------------
; 背景の星描画関係
;    キャラクターコード ＄80 を背景の星に使用
;
;--------------------------------------------
; 星用キャラパターン、色
STAR_CHAR_PATTERN:
    DEFB $10, $00, $00, $00, $00, $00, $00, $00	; 8バイト
STAR_CHAR_COLOR:
    DEFB $F1, $F1, $F1, $F1, $F1, $F1, $F1, $F1			; 8バイト
    
; 星用キャラクターコードに8を掛けた値　VRAMアドレス計算の基本になる
WK_STAR_CHARCODE_TIMES_8:
    DEFB $00, $00 ; 2バイト
; 星用キャラパターンのワーク
WK_STAR_CHAR_PATTERN:
    DEFB $00, $00, $00, $00, $00, $00, $00, $00, $00	; 8バイト + ワーク1バイト
WK_STAR_COUNTER:
    DEFB $00	; 1バイト

;--------------------------------------------
; 星キャラクターの初期処理
;--------------------------------------------
StarCharacterInit:
    ; キャラクターパターンをワークに転送
    LD HL, STAR_CHAR_PATTERN
    LD DE, WK_STAR_CHAR_PATTERN
    LD BC, 8
    LDIR
    
    ; カウンタを0に設定
    LD A, 0
    LD (WK_STAR_COUNTER), A

    ; キャラクターコード ＄80 をHレジスタに設定
    LD H, $80
    ; 8倍した数をワークに格納
    LD E, 8
    CALL CalcMulti
    LD (WK_STAR_CHARCODE_TIMES_8), HL
    
    ; キャラクターパターンをVRAMへ転送
    CALL StarCharacterPatternSetVRAM
    ; 色をVRAMへ転送
    CALL StarCharacterColorSetVRAM
    
    ; ワークにランダムに星を配置(32列×24行)
    LD HL, WK_VRAMTORAM
    LD B, 0	; 256回ループ
    CALL SetStarRandomToWork
    
    LD HL, WK_VRAMTORAM + 256
    LD B, 0	; 256回ループ
    CALL SetStarRandomToWork
    
    LD HL, WK_VRAMTORAM + 512
    LD B, 0	; 256回ループ
    CALL SetStarRandomToWork
    
    ; ワークをVRAMに転送
    LD HL, WK_VRAMTORAM
    LD DE, $1800
    LD BC, $300
    CALL LDIRVM
    
    RET
    
;--------------------------------------------
; 星をワークにランダムに設定する
;     HLレジスタ 設定開始ワークアドレス
;     Bレジスタ 設定数
;--------------------------------------------
SetStarRandomToWork:
SetStarRandomToWork_Loop:
    CALL Random
    CP 20
    JP C, SetStarRandomToWork_SetStar
    ; 空を設定
    LD (HL), $00
    JP SetStarRandomToWork_LoopCheck
    
SetStarRandomToWork_SetStar:    
   ; 星を設定
    LD (HL), $80
    
SetStarRandomToWork_LoopCheck:
    ; メモリを進める
    INC HL
    ; ループを判定
    DJNZ SetStarRandomToWork_Loop
    
    RET
    
    
    
;--------------------------------------------
; 星のスクロール処理
;--------------------------------------------
StarScroll:
    ; カウンタの加算
    LD A, (WK_STAR_COUNTER)
    INC A
    CP 8
    ; キャラクタパターンのスクロールが終わっている場合は、画面スクロールする
    JP Z, StarScroll_DispScroll
    
    ; カウンタの保存
    LD (WK_STAR_COUNTER), A
    ; キャラクタパターンのスクロール
    CALL StarCharacterScroll
    
    RET
    
StarScroll_DispScroll
    ; カウンタのリセット
    LD A, 0
    LD (WK_STAR_COUNTER), A
    
    ; VRAMをワークに転送
    LD HL, $1800
    LD DE, WK_VRAMTORAM + 32	; 1行（32文字）分スクロールさせる
    LD BC, $2ED					; 1行（32文字）分少なく転送
    CALL LDIRMV
    
    ; ワーク先頭行にランダムに星を配置
    LD HL, WK_VRAMTORAM
    LD B, 32	; 1行（32文字）分配置
    CALL SetStarRandomToWork
    
    ; キャラクターパターンを一旦削除
    LD HL, (WK_STAR_CHARCODE_TIMES_8)
    LD BC, 8
    LD A, $00
    CALL FILVRM
    LD HL, (WK_STAR_CHARCODE_TIMES_8)
    LD DE, $0800
    ADD HL,DE
    LD BC, 8
    LD A, $00
    CALL FILVRM
    LD HL, (WK_STAR_CHARCODE_TIMES_8)
    LD DE, $1000
    ADD HL,DE
    LD BC, 8
    LD A, $00
    CALL FILVRM
    
    ; ワークをVRAMに転送
    LD HL, WK_VRAMTORAM
    LD DE, $1800
    LD BC, $300
    CALL LDIRVM

    ; キャラクタパターンのスクロール
    CALL StarCharacterScroll

    
    RET
    
    
;--------------------------------------------
; 星キャラクターのスクロール処理
;--------------------------------------------
StarCharacterScroll:
    ; ワークをスクロールする
    ; ワークの一番最後をDEレジスタに設定
    LD HL, WK_STAR_CHAR_PATTERN + 8
    LD D, H
    LD E, L
    ; DEレジスタの1つ前をHLレジスタに設定
    DEC HL
    
    ;下から順に１つ前をコピーする
    LD BC, 8
    LDDR
    
    ; ワークの最後をワークの先頭にコピー
    LD A, (WK_STAR_CHAR_PATTERN + 8)
    LD (WK_STAR_CHAR_PATTERN), A

    ; キャラクターパターンをVRAMへ転送
    CALL StarCharacterPatternSetVRAM

    RET
    
;--------------------------------------------
; 星キャラクターパターンをVRAMへ転送
;--------------------------------------------
StarCharacterPatternSetVRAM:
    ; DEレジスタに転送先VRAMアドレスを設定
    LD DE, (WK_STAR_CHARCODE_TIMES_8)
    ; HLレジスタに転送元アドレスを設定
    LD HL, WK_STAR_CHAR_PATTERN
    ; 転送サイズ 8バイト
    LD BC, 8
    CALL LDIRVM
    
    ; 転送先に $0800 を加算
    LD HL, (WK_STAR_CHARCODE_TIMES_8)
    LD DE, $0800
    ADD HL,DE
    LD D, H
    LD E, L
    ; HLレジスタに転送元アドレスを設定
    LD HL, WK_STAR_CHAR_PATTERN
    ; 転送サイズ 8バイト
    LD BC, 8
    CALL LDIRVM

    ; 転送先に $1000 を加算
    LD HL, (WK_STAR_CHARCODE_TIMES_8)
    LD DE, $1000
    ADD HL,DE
    LD D, H
    LD E, L
    ; HLレジスタに転送元アドレスを設定
    LD HL, WK_STAR_CHAR_PATTERN
    ; 転送サイズ 8バイト
    LD BC, 8
    CALL LDIRVM
    
    RET

;--------------------------------------------
; 星キャラクターの色をVRAMへ転送
;--------------------------------------------
StarCharacterColorSetVRAM:
    ; 転送先に $2000 を加算
    LD HL, (WK_STAR_CHARCODE_TIMES_8)
    LD DE, $2000
    ADD HL,DE
    LD D, H
    LD E, L
    ; HLレジスタに転送元アドレスを設定
    LD HL, STAR_CHAR_COLOR
    ; 転送サイズ 8バイト
    LD BC, 8
    CALL LDIRVM
    
    ; 転送先に $2800 を加算
    LD HL, (WK_STAR_CHARCODE_TIMES_8)
    LD DE, $2800
    ADD HL,DE
    LD D, H
    LD E, L
    ; HLレジスタに転送元アドレスを設定
    LD HL, STAR_CHAR_COLOR
    ; 転送サイズ 8バイト
    LD BC, 8
    CALL LDIRVM

    ; 転送先に $3000 を加算
    LD HL, (WK_STAR_CHARCODE_TIMES_8)
    LD DE, $3000
    ADD HL,DE
    LD D, H
    LD E, L
    ; HLレジスタに転送元アドレスを設定
    LD HL, STAR_CHAR_COLOR
    ; 転送サイズ 8バイト
    LD BC, 8
    CALL LDIRVM
    
    RET



;include "pcg_graphic2.asm"
;--------------------------------------------
; pcg_graphic2.asm
;
; GRAPHIC2モードでのキャラクターグラフィック
; 作成処理はこちらに記述すること！
;--------------------------------------------

;--------------------------------------------
; SUB-ROUTINE: CreateCharacterPattern
; パターンジェネレータテーブルと
; カラーテーブルを編集する
;--------------------------------------------
CreateCharacterPattern:
    
    ;----------------------------------------
    ; VRAMのPCG情報を初期化する
    ;----------------------------------------
    call InitialPCGDatas

    ; キャラクタデータ作成用変数に
    ; パターンデータのアドレスをセット
    ld hl, CHRPTN
    ld (WK_CHARDATAADR), hl
 
CreateCharacterPatternLoop:

    ; パターンデータアドレスの中の値をAレジスタにセットする
    ld hl, (WK_CHARDATAADR)
    ld a, (hl)

    ld (WK_CHARCODE), a

    ;
    ; Aレジスタの値から1を減算した結果でCYフラグを確認する
    ; CYフラグがたてば処理終了とする
    ;
    cp 1
    jp c, CreateCharacterPatternEnd

    inc hl
    ld (WK_CHARDATAADR), hl ; CHRPTNのアドレスを1進める

    ;-----------------------------------------------
    ; パターンジェネレータテーブル処理
    ;-----------------------------------------------

    ; 定義する文字の数値を8倍し
    ; その結果をDEレジスタに格納する
    call GetCharacterVRAMAddress

    ;
    ; 画面上段のパターンジェネレータテーブルに書き込む
    ;
    ld hl, (WK_CHARDATAADR)
    ld bc, 8  ; 8バイト転送する
    call LDIRVM

    ;
    ; 画面中段のパターンジェネレータテーブルに書き込む
    ;
    call GetCharacterVRAMAddress

    ld h, d
    ld l, e
    ld bc, $0800  ; HLレジスタに0800Hを加算する
    add hl, bc

    ld d, h     ; DEレジスタにHLレジスタの値を転送する
    ld e, l

    ld hl, (WK_CHARDATAADR)
    ld bc, 8  ; 8バイト転送する
    call LDIRVM

    ;
    ; 画面下段のパターンジェネレータテーブルに書き込む
    ;
    call GetCharacterVRAMAddress

    ld h, d
    ld l, e
    ld bc, $1000  ; HLレジスタに1000Hを加算する
    add hl, bc

    ld d, h     ; DEレジスタにHLレジスタの値を転送する
    ld e, l

    ld hl, (WK_CHARDATAADR)
    ld bc, 8  ; 8バイト転送する
    call LDIRVM

    ld hl, (WK_CHARDATAADR)
    ;HLに8加算
    ld a, l
    add a, 8
    ld l, a
    ADC A, H
    sub l
    ld h, a
    ld (WK_CHARDATAADR), hl ; CHRPTNのアドレスを8バイト進める

    ;-----------------------------------------------
    ; カラーテーブル処理
    ;-----------------------------------------------

    ; 定義する文字の数値を8倍し
    ; その結果をDEレジスタに格納する
    call GetCharacterVRAMAddress

    ld h, d
    ld l, e

    ;
    ; 画面上段のカラーテーブルに書き込む
    ;
    ld hl, $2000     ; HLレジスタに2000Hを加算する
    add hl, de
    ld d, h        ; DEレジスタにHLレジスタの値を転送する
    ld e, l

    ld hl, (WK_CHARDATAADR)
    ld bc, 8  ; 8バイト転送する
    call LDIRVM

    ;
    ; 画面中段のカラーテーブルに書き込む
    ;
    call GetCharacterVRAMAddress

    ld bc, $2800     ; HLアドレスに2800Hを加算する
    add hl, bc

    ld d, h        ; DEレジスタにHLレジスタの値を転送する
    ld e, l

    ld hl, (WK_CHARDATAADR)
    ld bc, 8  ; 8バイト転送する
    call LDIRVM

    ;
    ; 画面下段のカラーテーブルに書き込む
    ;
    call GetCharacterVRAMAddress

    ld h, d
    ld l, e
    ld bc, $3000     ; HLアドレスに3000Hを加算する
    add hl, bc

    ld d, h        ; DEレジスタにHLレジスタの値を転送する
    ld e, l

    ld hl, (WK_CHARDATAADR)
    ld bc, 8  ; 8バイト転送する
    call LDIRVM

    ld hl, (WK_CHARDATAADR)
    ;HLに8を加算
    ld a, l
    add a, 8
    ld l, a
    ADC A, H
    sub l
    ld h, a
    ld (WK_CHARDATAADR), hl ; CHRPTNのアドレスを8バイト進める

    jp CreateCharacterPatternLoop

CreateCharacterPatternEnd:

    ;--------------------------------------------
    ; 文字コード80Hの文字を256バイトぶん
    ; VRAMのパターンネームテーブルに埋める
    ; (横32文字 x 縦8行＝256バイト) 
    ;--------------------------------------------
    ld hl, $1800
    ld  a, $80 
    call PutVRAM256Bytes

    ;--------------------------------------------
    ; 文字コード80Hの文字を256バイトぶん
    ; VRAMのパターンネームテーブルに埋める
    ; (横32文字 x 縦8行＝256バイト) 
    ;--------------------------------------------
    ld hl, $1900
    ld  a, $80 
    call PutVRAM256Bytes

    ;--------------------------------------------
    ; 文字コード80Hの文字を256バイトぶん
    ; VRAMのパターンネームテーブルに埋める
    ; (横32文字 x 縦8行＝256バイト) 
    ;--------------------------------------------
    ld hl, $1A00
    ld  a, $80 
    call PutVRAM256Bytes

    ret

;--------------------------------------------
; SUB-ROUTINE: GetCharacterVRAMAddress
; 文字コードの数値を8倍した数値を取得する
; DEレジスタに計算結果がセットされる
;--------------------------------------------
GetCharacterVRAMAddress:

    ; パターンデータアドレスの中の値をAレジスタにセットする
    ld a, (WK_CHARCODE)

    ;
    ; Aレジスタには文字コードがセットされているので
    ; その値を8倍した値がパターンの開始アドレスになる
    ;
    ld h, a
    ld e, 8

    ;
    ; Hレジスタの値を8倍する
    ;
    call CalcMulti

    ;
    ; HLレジスタの値にはVRAMのパターンジェネレータテーブルの
    ; アドレスが格納されているためDEレジスタにセットする
    ;
    ld d, h
    ld e, l

    ret

;--------------------------------------------
; SUB-ROUTINE: InitialPCGDatas
; パターンジェネレータテーブルと
; カラーテーブルを初期化する
;--------------------------------------------
InitialPCGDatas:

    ;---------------------------------------- 
    ; パターンジェネレータテーブルの初期化
    ;---------------------------------------- 

    ; パターンジェネレータテーブルの
    ; 上段の情報をVRAMからRAMにコピーする
    ; 転送サイズは800バイト
    ld hl, $0000
    ld de, WK_VRAMTORAM
    ld bc, $800
    call LDIRMV

    ; パターンジェネレータテーブルの
    ; 上段の情報をVRAM（中段）にコピーする
    ; 転送サイズは800バイト
    ld hl, WK_VRAMTORAM
    ld de, $0800
    ld bc, $0800
    call LDIRVM
    
    ; パターンジェネレータテーブルの
    ; 上段の情報をVRAM（下段）にコピーする
    ; 転送サイズは800バイト
    ld hl, WK_VRAMTORAM
    ld de, $1000
    ld bc, $0800
    call LDIRVM

    ;---------------------------------------- 
    ; カラーテーブルの初期化
    ; カラーテーブルは
    ; 全ライン前景色白、背景色黒にする
    ;---------------------------------------- 
    ld hl, $2000
    ld bc, $1800 ; 256 x 3 x 8 = 6144 = 1800H
    ld  a, $F1
    call FILVRM

    ret



;include "data_pcg.asm"
;--------------------------------------------
; data_pcg.asm
; 固定データ(GRAPHIC2モード用)
;--------------------------------------------
; キャラクタパターンとカラーテーブル
CHRPTN:
    defb $80  ; CHAR CODE
    defb $FE, $80, $80, $80, $80, $80, $80, $00 ; CHAR PATTERN
    defb $41, $41, $41, $41, $41, $41, $41, $11 ; COLOR PATTERN

    defb $81  ; CHAR CODE
    defb $38, $38, $38, $7C, $BA, $38, $6C, $00 ; CHAR PATTERN
    defb $51, $51, $51, $81, $81, $C1, $51, $11 ; COLOR PATTERN

CHRPTN_HEXFONT:

    defb '0'
    defb $7E, $46, $56, $56, $56, $56, $46, $7E ; CHAR PATTERN
    defb $F1, $F1, $F1, $F1, $71, $71, $71, $71 ; COLOR PATTERN

    defb '1'
    defb $38, $18, $18, $18, $18, $18, $18, $18 ; CHAR PATTERN
    defb $F1, $F1, $F1, $F1, $71, $71, $71, $71 ; COLOR PATTERN

    defb '2'
    defb $7E, $06, $06, $7E, $40, $40, $7E, $7E ; CHAR PATTERN
    defb $F1, $F1, $F1, $F1, $71, $71, $71, $71 ; COLOR PATTERN

    defb '3'
    defb $7E, $06, $06, $7E, $06, $06, $06, $7E ; CHAR PATTERN
    defb $F1, $F1, $F1, $F1, $71, $71, $71, $71 ; COLOR PATTERN

    defb '4'
    defb $76, $76, $76, $76, $76, $7E, $06, $06 ; CHAR PATTERN
    defb $F1, $F1, $F1, $F1, $71, $71, $71, $71 ; COLOR PATTERN

    defb '5'
    defb $7E, $40, $40, $7E, $06, $06, $06, $7E ; CHAR PATTERN
    defb $F1, $F1, $F1, $F1, $71, $71, $71, $71 ; COLOR PATTERN

    defb '6'
    defb $7E, $40, $40, $7E, $46, $46, $46, $7E ; CHAR PATTERN
    defb $F1, $F1, $F1, $F1, $71, $71, $71, $71 ; COLOR PATTERN

    defb '7'
    defb $7E, $06, $06, $06, $06, $06, $06, $06 ; CHAR PATTERN
    defb $F1, $F1, $F1, $F1, $71, $71, $71, $71 ; COLOR PATTERN

    defb '8'
    defb $7E, $46, $46, $7E, $46, $46, $46, $7E ; CHAR PATTERN
    defb $F1, $F1, $F1, $F1, $71, $71, $71, $71 ; COLOR PATTERN

    defb '9'
    defb $7E, $46, $46, $46, $7E, $06, $06, $06 ; CHAR PATTERN
    defb $F1, $F1, $F1, $F1, $71, $71, $71, $71 ; COLOR PATTERN

    defb 'A'
    defb $7C, $46, $46, $46, $7E, $46, $46, $46 ; CHAR PATTERN
    defb $F1, $F1, $F1, $F1, $71, $71, $71, $71 ; COLOR PATTERN

    defb 'B'
    defb $70, $48, $44, $46, $7E, $46, $46, $7C ; CHAR PATTERN
    defb $F1, $F1, $F1, $F1, $71, $71, $71, $71 ; COLOR PATTERN

    defb 'C'
    defb $7E, $40, $40, $40, $40, $40, $40, $7E ; CHAR PATTERN
    defb $F1, $F1, $F1, $F1, $71, $71, $71, $71 ; COLOR PATTERN

    defb 'D'
    defb $70, $48, $4C, $46, $46, $46, $46, $7E ; CHAR PATTERN
    defb $F1, $F1, $F1, $F1, $71, $71, $71, $71 ; COLOR PATTERN

    defb 'E'
    defb $7E, $40, $40, $7E, $40, $40, $7E, $7E ; ChAR PATTERN
    defb $F1, $F1, $F1, $F1, $71, $71, $71, $71 ; COLOR PATTERN

    defb 'F'
    defb $7E, $40, $40, $7E, $40, $40, $40, $40 ; CHAR PATTERN
    defb $F1, $F1, $F1, $F1, $71, $71, $71, $71 ; COLOR PATTERN

CHRPTN_ENEMY_RANDOM: ; 16x16 dot character.

    defb $98  ; LEFT-UP
    defb $00, $1F, $3F, $7F, $7F, $3F, $0F, $07 ; CHAR PATTERN
    defb $11, $F1, $71, $41, $41, $71, $81, $61 ; COLOR PATTERN
    defb $99  ; LEFT-DOWN
    defb $07, $0F, $3F, $7F, $7F, $3F, $1F, $00 ; CHAR PATTERN
    defb $61, $81, $71, $41, $41, $71, $F1, $11 ; COLOR PATTERN
    defb $9A  ; RIGHT-UP
    defb $00, $F8, $FC, $FE, $FE, $FC, $F0, $E0 ; CHAR PATTERN
    defb $11, $F1, $71, $41, $41, $71, $81, $61 ; COLOR PATTERN
    defb $9B  ; RIGHT-DOWN
    defb $E0, $F0, $FC, $FE, $FE, $FC, $F8, $00 ; CHAR PATTERN
    defb $61, $81, $71, $41, $41, $71, $F1, $11 ; COLOR PATTERN

CHRPTN_PLAYER: ; 16x16 dot character.

    defb $A8  ; LEFT-UP
    defb $0F, $1F, $1F, $1F, $15, $15, $15, $0F ; CHAR PATTERN
    defb $D1, $D1, $D1, $F1, $F1, $F1, $F1, $F1 ; COLOR PATTERN
    defb $A9  ; LEFT-DOWN
    defb $10, $7F, $3B, $1F, $1B, $0F, $3E, $1E ; CHAR PATTERN
    defb $F1, $F1, $F1, $F1, $F1, $F1, $81, $81 ; COLOR PATTERN
    defb $AA  ; RIGHT-UP
    defb $F8, $F8, $FC, $FC, $FC, $FC, $FC, $F8 ; CHAR PATTERN
    defb $D1, $D1, $D1, $D1, $D1, $D1, $D1, $D1 ; COLOR PATTERN
    defb $AB  ; RIGHT-DOWN
    defb $E8, $DC, $DC, $DC, $E8, $F0, $3C, $3C ; CHAR PATTERN
    defb $F1, $F1, $F1, $F1, $F1, $F1, $81, $81 ; COLOR PATTERN

CHRPTN_END:
    defb $00 ; CHAR CODEの部分が00Hであれば処理終了とみなす
    



;--------------------------------------------
; AKGプレーヤー＆音楽
;
;--------------------------------------------

GAMEBGM_START
PLY_AKG_OFFSET2B
PLY_AKG_OFFSET1B
PLY_AKG_OPCODE_OR_A
PLY_AKG_OPCODE_ADD_HL_BC_MSB db 65
PLY_AKG_FULL_INIT_CODE
PLY_AKG_USE_HOOKS
PLY_AKG_STOP_SOUNDS db 84
PLY_AKG_BITFORSOUND
PLY_AKG_SOUNDEFFECTDATA_OFFSETINVERTEDVOLUME
RASM_VERSION db 50
PLY_AKG_SOUNDEFFECTDATA_OFFSETCURRENTSTEP db 48
PLY_AKG_BITFORNOISE equ $+1
PLY_AKG_SOUNDEFFECTDATA_OFFSETSPEED dw GAMEBGM_ARPEGGIOTABLE
    dw GAMEBGM_ARPEGGIOTABLE
PLY_AKG_OPCODE_ADD_HL_BC_LSB equ $+1
    dw GAMEBGM_ARPEGGIOTABLE
    dw GAMEBGM_EFFECTBLOCKTABLE
    dw GAMEBGM_EFFECTBLOCKTABLE
GAMEBGM_ARPEGGIOTABLE
GAMEBGM_PITCHTABLE
GAMEBGM_INSTRUMENTTABLE dw GAMEBGM_EMPTYINSTRUMENT
    dw GAMEBGM_INSTRUMENT1
    dw GAMEBGM_INSTRUMENT2
    dw GAMEBGM_INSTRUMENT3
    dw GAMEBGM_INSTRUMENT4
GAMEBGM_EMPTYINSTRUMENT db 0
GAMEBGM_EMPTYINSTRUMENT_LOOP db 0
    db 6
GAMEBGM_INSTRUMENT1 db 1
    db 81
    db 5
    db 73
    db 36
    db 16
    db 0
    db 65
PLY_AKG_OPCODE_INC_HL db 35
    db 32
    db 0
    db 57
    db 34
    db 48
    db 0
    db 49
PLY_AKG_OPCODE_DEC_HL db 33
    db 64
    db 0
    db 41
    db 32
    db 80
    db 0
    db 33
    db 32
    db 96
    db 0
    db 25
    db 32
    db 112
    db 0
    db 6
GAMEBGM_INSTRUMENT2 db 1
    db 209
    db 73
    db 32
    db 32
    db 0
    db 65
PLY_AKG_OPCODE_SBC_HL_BC_LSB db 32
    db 64
    db 0
    db 57
    db 32
    db 96
    db 0
    db 49
    db 32
    db 128
    db 0
    db 41
    db 32
    db 160
    db 0
    db 33
    db 32
    db 192
    db 0
    db 25
    db 32
    db 224
    db 0
    db 6
GAMEBGM_INSTRUMENT3 db 1
    db 225
    db 97
    db 64
    db 4
    db 89
    db 64
    db 7
    db 217
    db 81
    db 64
    db 4
    db 81
    db 64
    db 7
    db 201
    db 73
    db 64
    db 4
    db 65
    db 64
    db 7
    db 193
    db 57
    db 64
    db 4
    db 57
    db 64
    db 7
    db 177
    db 49
    db 64
    db 4
    db 41
    db 64
    db 7
    db 169
    db 6
GAMEBGM_INSTRUMENT4 db 2
    db 225
    db 97
    db 64
    db 4
    db 97
    db 64
    db 255
    db 97
    db 64
    db 3
    db 89
    db 64
    db 254
    db 81
    db 64
    db 2
    db 73
    db 64
    db 253
    db 65
    db 64
    db 1
    db 57
    db 64
    db 252
    db 177
    db 41
    db 64
    db 251
    db 33
    db 64
    db 255
    db 25
    db 64
    db 250
    db 17
    db 64
    db 254
    db 9
    db 64
    db 249
    db 0
    db 6
GAMEBGM_EFFECTBLOCKTABLE
GAMEBGM_SUBSONG0_START db 2
    db 1
    db 1
    db 2
    db 6
    db 6
    db 0
GAMEBGM_SUBSONG0_LINKER dw GAMEBGM_SUBSONG0_TRACK0
    dw GAMEBGM_SUBSONG0_TRACK1
    dw GAMEBGM_SUBSONG0_TRACK0
    dw GAMEBGM_SUBSONG0_LINKERBLOCK0
    dw GAMEBGM_SUBSONG0_TRACK0
    dw GAMEBGM_SUBSONG0_TRACK1
    dw GAMEBGM_SUBSONG0_TRACK0
    dw GAMEBGM_SUBSONG0_LINKERBLOCK0
GAMEBGM_SUBSONG0_LINKER_LOOP
PLY_AKG_OPCODE_JP dw GAMEBGM_SUBSONG0_TRACK0
PLY_AKG_OPCODE_ADD_A_IMMEDIATE equ $+1
    dw GAMEBGM_SUBSONG0_TRACK1
    dw GAMEBGM_SUBSONG0_TRACK2
    dw GAMEBGM_SUBSONG0_LINKERBLOCK1
    dw GAMEBGM_SUBSONG0_TRACK0
    dw GAMEBGM_SUBSONG0_TRACK1
    dw GAMEBGM_SUBSONG0_TRACK2
    dw GAMEBGM_SUBSONG0_LINKERBLOCK1
    dw GAMEBGM_SUBSONG0_TRACK0
PLY_AKG_OPCODE_SUB_IMMEDIATE equ $+1
    dw GAMEBGM_SUBSONG0_TRACK1
    dw GAMEBGM_SUBSONG0_TRACK2
    dw GAMEBGM_SUBSONG0_LINKERBLOCK1
    dw GAMEBGM_SUBSONG0_TRACK0
    dw GAMEBGM_SUBSONG0_TRACK3
    dw GAMEBGM_SUBSONG0_TRACK4
    dw GAMEBGM_SUBSONG0_LINKERBLOCK1
    dw GAMEBGM_SUBSONG0_TRACK0
    dw GAMEBGM_SUBSONG0_TRACK1
    dw GAMEBGM_SUBSONG0_TRACK5
    dw GAMEBGM_SUBSONG0_LINKERBLOCK1
    db 0
    db 0
PLY_AKG_OPCODE_SBC_HL_BC_MSB dw GAMEBGM_SUBSONG0_LINKER_LOOP
GAMEBGM_SUBSONG0_LINKERBLOCK0 db 16
    db 0
    db 0
    db 0
    dw GAMEBGM_SUBSONG0_SPEEDTRACK0
    dw GAMEBGM_SUBSONG0_EVENTTRACK0
GAMEBGM_SUBSONG0_LINKERBLOCK1 db 32
    db 0
    db 0
    db 0
    dw GAMEBGM_SUBSONG0_SPEEDTRACK0
    dw GAMEBGM_SUBSONG0_EVENTTRACK0
GAMEBGM_SUBSONG0_TRACK0
PLY_AKG_OPCODE_SCF db 61
SYNCHRO db 127
GAMEBGM_SUBSONG0_TRACK1 db 164
    db 2
    db 36
    db 36
    db 36
    db 176
    db 1
    db 164
    db 2
    db 36
    db 36
    db 36
    db 176
    db 1
    db 164
    db 2
    db 36
    db 176
    db 1
    db 164
    db 2
    db 36
    db 36
    db 36
    db 36
    db 36
    db 36
    db 176
    db 1
    db 164
    db 2
    db 36
    db 36
    db 36
    db 176
    db 1
    db 164
    db 2
    db 36
    db 176
    db 1
    db 164
    db 2
    db 36
    db 36
    db 61
    db 127
GAMEBGM_SUBSONG0_TRACK2 db 173
    db 3
    db 62
    db 43
    db 62
    db 45
    db 126
    db 48
    db 60
    db 45
    db 60
    db 43
    db 60
    db 45
    db 62
    db 43
    db 62
    db 45
    db 61
    db 127
GAMEBGM_SUBSONG0_TRACK3 db 164
    db 2
    db 36
    db 36
    db 36
    db 176
    db 1
    db 164
    db 2
    db 36
    db 36
    db 36
    db 176
    db 1
    db 164
    db 2
    db 36
    db 176
    db 1
    db 164
    db 2
    db 36
    db 36
    db 36
    db 36
    db 36
    db 36
    db 176
    db 1
    db 164
    db 2
    db 36
    db 36
    db 48
    db 48
    db 48
    db 48
    db 43
    db 43
    db 43
    db 43
    db 61
    db 127
GAMEBGM_SUBSONG0_TRACK4 db 173
    db 3
    db 62
    db 43
    db 62
    db 45
    db 126
    db 48
    db 60
    db 45
    db 60
    db 43
    db 60
    db 45
    db 62
    db 47
    db 62
    db 48
    db 61
    db 127
GAMEBGM_SUBSONG0_TRACK5 db 176
    db 3
    db 126
    db 48
    db 126
    db 48
    db 254
    db 50
    db 48
    db 62
    db 47
    db 47
    db 47
    db 126
    db 173
    db 4
    db 61
    db 127
GAMEBGM_SUBSONG0_SPEEDTRACK0 db 255
GAMEBGM_SUBSONG0_EVENTTRACK0 db 255
SOUNDEFFECTS dw SOUNDEFFECTS_SOUND1
    dw SOUNDEFFECTS_SOUND2
    dw SOUNDEFFECTS_SOUND3
    dw SOUNDEFFECTS_SOUND4
SOUNDEFFECTS_SOUND1 db 0
SOUNDEFFECTS_SOUND1_LOOP db 189
    db 1
    db 212
    db 0
    db 57
    db 193
    db 0
    db 53
    db 220
    db 0
    db 49
    db 201
    db 0
    db 45
    db 244
    db 0
    db 41
    db 225
    db 0
    db 37
    db 252
    db 0
    db 33
    db 0
    db 1
    db 29
    db 4
    db 1
    db 25
    db 8
    db 1
    db 21
    db 12
    db 1
    db 17
    db 16
    db 1
    db 13
    db 20
    db 1
    db 9
    db 24
    db 1
    db 5
    db 28
    db 1
    db 4
SOUNDEFFECTS_SOUND2 db 1
SOUNDEFFECTS_SOUND2_LOOP db 189
    db 1
    db 42
    db 0
    db 169
    db 1
    db 42
    db 0
    db 161
    db 1
    db 42
    db 0
    db 153
    db 1
    db 42
    db 0
    db 145
    db 1
    db 42
    db 0
    db 137
    db 1
    db 42
    db 0
    db 4
SOUNDEFFECTS_SOUND3 db 3
SOUNDEFFECTS_SOUND3_LOOP db 248
    db 3
    db 224
    db 26
    db 200
    db 26
    db 176
    db 31
    db 144
    db 31
    db 4
SOUNDEFFECTS_SOUND4 db 7
SOUNDEFFECTS_SOUND4_LOOP db 248
    db 31
    db 232
    db 31
    db 216
    db 31
    db 200
    db 31
    db 184
    db 31
    db 168
    db 31
    db 144
    db 31
    db 136
    db 31
    db 4
PLY_AKG_START jp PLY_AKG_INIT
    jp PLY_AKG_PLAY
    jp PLY_AKG_INITTABLEJP_END
PLY_AKG_INITSOUNDEFFECTS ld (PLY_AKG_PTSOUNDEFFECTTABLE),hl
    ret 
PLY_AKG_PLAYSOUNDEFFECT dec a
    ld hl,(PLY_AKG_PTSOUNDEFFECTTABLE)
    ld e,a
    ld d,0
    add hl,de
    add hl,de
    ld e,(hl)
    inc hl
    ld d,(hl)
    ld a,(de)
    inc de
    ex af,af'
    ld a,b
    ld hl,PLY_AKG_CHANNEL1_SOUNDEFFECTDATA
    ld b,0
    sla c
    sla c
    sla c
    add hl,bc
    ld (hl),e
    inc hl
    ld (hl),d
    inc hl
    ld (hl),a
    inc hl
    ld (hl),0
    inc hl
    ex af,af'
    ld (hl),a
    ret 
PLY_AKG_STOPSOUNDEFFECTFROMCHANNEL add a,a
    add a,a
    add a,a
    ld e,a
    ld d,0
    ld hl,PLY_AKG_CHANNEL1_SOUNDEFFECTDATA
    add hl,de
    ld (hl),d
    inc hl
    ld (hl),d
    ret 
PLY_AKG_PLAYSOUNDEFFECTSSTREAM rla 
    rla 
    ld ix,PLY_AKG_CHANNEL1_SOUNDEFFECTDATA
    ld iy,PLY_AKG_PSGREG8
    ld hl,PLY_AKG_PSGREG01_INSTR
    exx
    ld c,a
    call PLY_AKG_PSES_PLAY
    ld ix,PLY_AKG_CHANNEL2_SOUNDEFFECTDATA
    ld iy,PLY_AKG_PSGREG9_10_INSTR
    exx
    ld hl,PLY_AKG_PSGREG23_INSTR
    exx
    srl c
    call PLY_AKG_PSES_PLAY
    ld ix,PLY_AKG_CHANNEL3_SOUNDEFFECTDATA
    ld iy,PLY_AKG_PSGREG10
    exx
    ld hl,PLY_AKG_PSGREG45_INSTR
    exx
    scf
    rr c
    call PLY_AKG_PSES_PLAY
    ld a,c
    ret 
PLY_AKG_PSES_PLAY ld l,(ix+0)
    ld h,(ix+1)
    ld a,l
    or h
    ret z
PLY_AKG_PSES_READFIRSTBYTE ld a,(hl)
    inc hl
    ld b,a
    rra 
    jr c,PLY_AKG_PSES_SOFTWAREORSOFTWAREANDHARDWARE
    rra 
    rra 
    jr c,PLY_AKG_PSES_S_ENDORLOOP
    call PLY_AKG_PSES_MANAGEVOLUMEFROMA_FILTER4BITS
    rl b
    call PLY_AKG_PSES_READNOISEIFNEEDEDANDOPENORCLOSENOISECHANNEL
    set 2,c
    jr PLY_AKG_PSES_SAVEPOINTERANDEXIT
PLY_AKG_PSES_S_ENDORLOOP xor a
    ld (ix+0),a
    ld (ix+1),a
    ret 
PLY_AKG_PSES_SAVEPOINTERANDEXIT ld a,(ix+3)
    cp (ix+4)
    jr c,PLY_AKG_PSES_NOTREACHED
    ld (ix+3),0
    ld (ix+0),l
    ld (ix+1),h
    ret 
PLY_AKG_PSES_NOTREACHED inc (ix+3)
    ret 
PLY_AKG_PSES_SOFTWAREORSOFTWAREANDHARDWARE rra 
    call PLY_AKG_PSES_MANAGEVOLUMEFROMA_FILTER4BITS
    rl b
    call PLY_AKG_PSES_READNOISEIFNEEDEDANDOPENORCLOSENOISECHANNEL
    res 2,c
    call PLY_AKG_PSES_READSOFTWAREPERIOD
    jr PLY_AKG_PSES_SAVEPOINTERANDEXIT
PLY_AKG_PSES_SHARED_READRETRIGHARDWAREENVPERIODNOISE rra 
    and 7
    add a,8
    ld (PLY_AKG_PSGREG13_INSTR),a
    set 5,c
    call PLY_AKG_PSES_READHARDWAREPERIOD
    ld a,16
    jp PLY_AKG_PSES_MANAGEVOLUMEFROMA_HARD
PLY_AKG_PSES_READNOISEIFNEEDEDANDOPENORCLOSENOISECHANNEL jr c,PLY_AKG_PSES_READNOISEANDOPENNOISECHANNEL_OPENNOISE
    set 5,c
    ret 
PLY_AKG_PSES_READNOISEANDOPENNOISECHANNEL_OPENNOISE ld a,(hl)
    ld (PLY_AKG_PSGREG6_8_INSTR),a
    inc hl
    res 5,c
    ret 
PLY_AKG_PSES_READHARDWAREPERIOD ld a,(hl)
    ld (PLY_AKG_PSGHARDWAREPERIOD_INSTR),a
    inc hl
    ld a,(hl)
    ld (PLY_AKG_PSGHARDWAREPERIOD_INSTR+1),a
    inc hl
    ret 
PLY_AKG_PSES_READSOFTWAREPERIOD ld a,(hl)
    inc hl
    exx
    ld (hl),a
    inc hl
    exx
    ld a,(hl)
    inc hl
    exx
    ld (hl),a
    exx
    ret 
PLY_AKG_PSES_MANAGEVOLUMEFROMA_FILTER4BITS and 15
PLY_AKG_PSES_MANAGEVOLUMEFROMA_HARD sub (ix+2)
    jr nc,PLY_AKG_PSES_MVFA_NOOVERFLOW
    xor a
PLY_AKG_PSES_MVFA_NOOVERFLOW ld (iy+0),a
    ret 
PLY_AKG_INIT ld de,8
    add hl,de
    ld de,PLY_AKG_INSTRUMENTSTABLE
    ldi
    ldi
    inc hl
    inc hl
    add a,a
    ld e,a
    ld d,0
    add hl,de
    ld a,(hl)
    inc hl
    ld h,(hl)
    ld l,a
    ld de,5
    add hl,de
    ld de,PLY_AKG_CURRENTSPEED
    ldi
    ld de,PLY_AKG_BASENOTEINDEX
    ldi
    ld (PLY_AKG_READLINKER_PTLINKER),hl
    ld hl,PLY_AKG_INITTABLE0
    ld bc,1792
    call PLY_AKG_INIT_READWORDSANDFILL
    inc c
    ld hl,PLY_AKG_INITTABLE0_END
    ld b,3
    call PLY_AKG_INIT_READWORDSANDFILL
    ld hl,PLY_AKG_INITTABLE1_END
    ld bc,256
    call PLY_AKG_INIT_READWORDSANDFILL
    ld hl,PLY_AKG_INITTABLE1_END
    ld bc,707
    call PLY_AKG_INIT_READWORDSANDFILL
    ld hl,(PLY_AKG_INSTRUMENTSTABLE)
    ld e,(hl)
    inc hl
    ld d,(hl)
    ex de,hl
    inc hl
    ld (PLY_AKG_EMPTYINSTRUMENTDATAPT),hl
    ld (PLY_AKG_CHANNEL1_PTINSTRUMENT),hl
    ld (PLY_AKG_CHANNEL2_PTINSTRUMENT),hl
    ld (PLY_AKG_CHANNEL3_PTINSTRUMENT),hl
    ld hl,0
    ld (PLY_AKG_CHANNEL1_SOUNDEFFECTDATA),hl
    ld (PLY_AKG_CHANNEL2_SOUNDEFFECTDATA),hl
    ld (PLY_AKG_CHANNEL3_SOUNDEFFECTDATA),hl
    ret 
PLY_AKG_INIT_READWORDSANDFILL_LOOP ld e,(hl)
    inc hl
    ld d,(hl)
    inc hl
    ld a,c
    ld (de),a
PLY_AKG_INIT_READWORDSANDFILL djnz PLY_AKG_INIT_READWORDSANDFILL_LOOP
    ret 
PLY_AKG_INITTABLE0 dw PLY_AKG_CHANNEL1_INVERTEDVOLUMEINTEGERANDDECIMAL
    dw PLY_AKG_CHANNEL1_INVERTEDVOLUMEINTEGER
    dw PLY_AKG_CHANNEL2_INVERTEDVOLUMEINTEGERANDDECIMAL
    dw PLY_AKG_CHANNEL2_INVERTEDVOLUMEINTEGER
    dw PLY_AKG_CHANNEL3_INVERTEDVOLUMEINTEGERANDDECIMAL
    dw PLY_AKG_CHANNEL3_INVERTEDVOLUMEINTEGER
PLY_AKG_INITTABLE0_END
PLY_AKG_INITTABLE1 dw PLY_AKG_PATTERNDECREASINGHEIGHT
    dw PLY_AKG_TICKDECREASINGCOUNTER
PLY_AKG_INITTABLE1_END
PLY_AKG_INITTABLEORA
PLY_AKG_INITTABLEORA_END
PLY_AKG_INITTABLEJP dw PLY_AKG_TEMPPLAYINSTRUMENTJUMPINSTRANDADDRESS
PLY_AKG_INITTABLEJP_END
PLY_AKG_STOP ld (PLY_AKG_SAVESP),sp
    xor a
    ld l,a
    ld h,a
    ld (PLY_AKG_PSGREG8),a
    ld (PLY_AKG_PSGREG9_10_INSTR),hl
    ld a,191
    jp PLY_AKG_SENDPSGREGISTERS
PLY_AKG_PLAY ld (PLY_AKG_SAVESP),sp
    ld a,(PLY_AKG_TICKDECREASINGCOUNTER)
    dec a
    jp nz,PLY_AKG_SETSPEEDBEFOREPLAYSTREAMS
    ld a,(PLY_AKG_PATTERNDECREASINGHEIGHT)
    dec a
    jr nz,PLY_AKG_SETCURRENTLINEBEFOREREADLINE
PLY_AKG_READLINKER ld sp,(PLY_AKG_READLINKER_PTLINKER)
    pop hl
    ld a,l
    or h
    jr nz,PLY_AKG_READLINKER_NOLOOP
    pop hl
    ld sp,hl
    pop hl
PLY_AKG_READLINKER_NOLOOP ld (PLY_AKG_CHANNEL1_PTTRACK),hl
    pop hl
    ld (PLY_AKG_CHANNEL2_PTTRACK),hl
    pop hl
    ld (PLY_AKG_CHANNEL3_PTTRACK),hl
    pop hl
    ld (PLY_AKG_READLINKER_PTLINKER),sp
    ld sp,hl
    pop hl
    ld c,l
    xor a
    ld (PLY_AKG_CHANNEL1_SOUNDSTREAM_RELATIVEMODIFIERADDRESS),a
    ld (PLY_AKG_CHANNEL2_PLAYINSTRUMENT_RELATIVEMODIFIERADDRESS),a
    ld (PLY_AKG_CHANNEL3_WAITCOUNTER),a
    ld a,c
PLY_AKG_SETCURRENTLINEBEFOREREADLINE ld (PLY_AKG_PATTERNDECREASINGHEIGHT),a
PLY_AKG_READLINE ld a,(PLY_AKG_CHANNEL1_SOUNDSTREAM_RELATIVEMODIFIERADDRESS)
    sub 1
    jr c,PLY_AKG_CHANNEL1_READTRACK
    ld (PLY_AKG_CHANNEL1_SOUNDSTREAM_RELATIVEMODIFIERADDRESS),a
    jp PLY_AKG_CHANNEL1_READCELLEND
PLY_AKG_CHANNEL1_READTRACK ld hl,(PLY_AKG_CHANNEL1_PTTRACK)
    ld c,(hl)
    inc hl
    ld a,c
    and 63
    cp 60
    jr c,PLY_AKG_CHANNEL1_NOTE
    sub 60
    jp z,PLY_AKG_CHANNEL1_MAYBEEFFECTS
    dec a
    jr z,PLY_AKG_CHANNEL1_WAIT
    dec a
    jr z,PLY_AKG_CHANNEL1_SMALLWAIT
    ld a,(hl)
    inc hl
    jr PLY_AKG_CHANNEL1_AFTERNOTEKNOWN
PLY_AKG_CHANNEL1_SMALLWAIT ld a,c
    rlca 
    rlca 
    and 3
    inc a
    ld (PLY_AKG_CHANNEL1_SOUNDSTREAM_RELATIVEMODIFIERADDRESS),a
    jr PLY_AKG_CHANNEL1_BEFOREEND_STORECELLPOINTER
PLY_AKG_CHANNEL1_WAIT ld a,(hl)
    ld (PLY_AKG_CHANNEL1_SOUNDSTREAM_RELATIVEMODIFIERADDRESS),a
    inc hl
    jr PLY_AKG_CHANNEL1_BEFOREEND_STORECELLPOINTER
PLY_AKG_CHANNEL1_SAMEINSTRUMENT ld de,(PLY_AKG_CHANNEL1_PTBASEINSTRUMENT)
    ld (PLY_AKG_CHANNEL1_PTINSTRUMENT),de
    jr PLY_AKG_CHANNEL1_AFTERINSTRUMENT
PLY_AKG_CHANNEL1_NOTE ld b,a
    ld a,(PLY_AKG_BASENOTEINDEX)
    add a,b
PLY_AKG_CHANNEL1_AFTERNOTEKNOWN ld (PLY_AKG_CHANNEL1_TRACKNOTE),a
    rl c
    jr nc,PLY_AKG_CHANNEL1_SAMEINSTRUMENT
    ld a,(hl)
    inc hl
    exx
    ld l,a
    ld h,0
    add hl,hl
    ld de,(PLY_AKG_INSTRUMENTSTABLE)
    add hl,de
    ld sp,hl
    pop hl
    ld a,(hl)
    inc hl
    ld (PLY_AKG_CHANNEL1_INSTRUMENTSPEED),a
    ld (PLY_AKG_CHANNEL1_PTINSTRUMENT),hl
    ld (PLY_AKG_CHANNEL1_PTBASEINSTRUMENT),hl
    exx
PLY_AKG_CHANNEL1_AFTERINSTRUMENT ex de,hl
    xor a
    ld (PLY_AKG_CHANNEL1_INSTRUMENTSTEP),a
    ex de,hl
PLY_AKG_CHANNEL1_BEFOREEND_STORECELLPOINTER ld (PLY_AKG_CHANNEL1_PTTRACK),hl
PLY_AKG_CHANNEL1_READCELLEND ld a,(PLY_AKG_CHANNEL2_PLAYINSTRUMENT_RELATIVEMODIFIERADDRESS)
    sub 1
    jr c,PLY_AKG_CHANNEL2_READTRACK
    ld (PLY_AKG_CHANNEL2_PLAYINSTRUMENT_RELATIVEMODIFIERADDRESS),a
    jp PLY_AKG_CHANNEL2_READCELLEND
PLY_AKG_CHANNEL2_READTRACK ld hl,(PLY_AKG_CHANNEL2_PTTRACK)
    ld c,(hl)
    inc hl
    ld a,c
    and 63
    cp 60
    jr c,PLY_AKG_CHANNEL2_NOTE
    sub 60
    jp z,PLY_AKG_CHANNEL1_READEFFECTSEND
    dec a
    jr z,PLY_AKG_CHANNEL2_WAIT
    dec a
    jr z,PLY_AKG_CHANNEL2_SMALLWAIT
    ld a,(hl)
    inc hl
    jr PLY_AKG_CHANNEL2_AFTERNOTEKNOWN
PLY_AKG_CHANNEL2_SMALLWAIT ld a,c
    rlca 
    rlca 
    and 3
    inc a
    ld (PLY_AKG_CHANNEL2_PLAYINSTRUMENT_RELATIVEMODIFIERADDRESS),a
    jr PLY_AKG_CHANNEL2_BEFOREEND_STORECELLPOINTER
PLY_AKG_CHANNEL2_WAIT ld a,(hl)
    ld (PLY_AKG_CHANNEL2_PLAYINSTRUMENT_RELATIVEMODIFIERADDRESS),a
    inc hl
    jr PLY_AKG_CHANNEL2_BEFOREEND_STORECELLPOINTER
PLY_AKG_CHANNEL2_SAMEINSTRUMENT ld de,(PLY_AKG_CHANNEL2_PTBASEINSTRUMENT)
    ld (PLY_AKG_CHANNEL2_PTINSTRUMENT),de
    jr PLY_AKG_CHANNEL2_AFTERINSTRUMENT
PLY_AKG_CHANNEL2_NOTE ld b,a
    ld a,(PLY_AKG_BASENOTEINDEX)
    add a,b
PLY_AKG_CHANNEL2_AFTERNOTEKNOWN ld (PLY_AKG_CHANNEL2_TRACKNOTE),a
    rl c
    jr nc,PLY_AKG_CHANNEL2_SAMEINSTRUMENT
    ld a,(hl)
    inc hl
    exx
    ld e,a
    ld d,0
    ld hl,(PLY_AKG_INSTRUMENTSTABLE)
    add hl,de
    add hl,de
    ld sp,hl
    pop hl
    ld a,(hl)
    inc hl
    ld (PLY_AKG_CHANNEL2_INSTRUMENTSPEED),a
    ld (PLY_AKG_CHANNEL2_PTINSTRUMENT),hl
    ld (PLY_AKG_CHANNEL2_PTBASEINSTRUMENT),hl
    exx
PLY_AKG_CHANNEL2_AFTERINSTRUMENT ex de,hl
    xor a
    ld (PLY_AKG_CHANNEL2_INSTRUMENTSTEP),a
    ex de,hl
PLY_AKG_CHANNEL2_BEFOREEND_STORECELLPOINTER ld (PLY_AKG_CHANNEL2_PTTRACK),hl
PLY_AKG_CHANNEL2_READCELLEND ld a,(PLY_AKG_CHANNEL3_WAITCOUNTER)
    sub 1
    jr c,PLY_AKG_CHANNEL3_READTRACK
    ld (PLY_AKG_CHANNEL3_WAITCOUNTER),a
    jp PLY_AKG_CHANNEL3_READCELLEND
PLY_AKG_CHANNEL3_READTRACK ld hl,(PLY_AKG_CHANNEL3_PTTRACK)
    ld c,(hl)
    inc hl
    ld a,c
    and 63
    cp 60
    jr c,PLY_AKG_CHANNEL3_NOTE
    sub 60
    jp z,PLY_AKG_CHANNEL2_READEFFECTSEND
    dec a
    jr z,PLY_AKG_CHANNEL3_WAIT
    dec a
    jr z,PLY_AKG_CHANNEL3_SMALLWAIT
    ld a,(hl)
    inc hl
    jr PLY_AKG_CHANNEL3_AFTERNOTEKNOWN
PLY_AKG_CHANNEL3_SMALLWAIT ld a,c
    rlca 
    rlca 
    and 3
    inc a
    ld (PLY_AKG_CHANNEL3_WAITCOUNTER),a
    jr PLY_AKG_CHANNEL3_BEFOREEND_STORECELLPOINTER
PLY_AKG_CHANNEL3_WAIT ld a,(hl)
    ld (PLY_AKG_CHANNEL3_WAITCOUNTER),a
    inc hl
    jr PLY_AKG_CHANNEL3_BEFOREEND_STORECELLPOINTER
PLY_AKG_CHANNEL3_SAMEINSTRUMENT ld de,(PLY_AKG_CHANNEL3_PTBASEINSTRUMENT)
    ld (PLY_AKG_CHANNEL3_PTINSTRUMENT),de
    jr PLY_AKG_CHANNEL3_AFTERINSTRUMENT
PLY_AKG_CHANNEL3_NOTE ld b,a
    ld a,(PLY_AKG_BASENOTEINDEX)
    add a,b
PLY_AKG_CHANNEL3_AFTERNOTEKNOWN ld (PLY_AKG_CHANNEL3_TRACKNOTE),a
    rl c
    jr nc,PLY_AKG_CHANNEL3_SAMEINSTRUMENT
    ld a,(hl)
    inc hl
    exx
    ld e,a
    ld d,0
    ld hl,(PLY_AKG_INSTRUMENTSTABLE)
    add hl,de
    add hl,de
    ld sp,hl
    pop hl
    ld a,(hl)
    inc hl
    ld (PLY_AKG_CHANNEL3_INSTRUMENTSPEED),a
    ld (PLY_AKG_CHANNEL3_PTINSTRUMENT),hl
    ld (PLY_AKG_CHANNEL3_PTBASEINSTRUMENT),hl
    exx
PLY_AKG_CHANNEL3_AFTERINSTRUMENT ex de,hl
    xor a
    ld (PLY_AKG_CHANNEL3_INSTRUMENTSTEP),a
    ex de,hl
PLY_AKG_CHANNEL3_BEFOREEND_STORECELLPOINTER ld (PLY_AKG_CHANNEL3_PTTRACK),hl
PLY_AKG_CHANNEL3_READCELLEND ld a,(PLY_AKG_CURRENTSPEED)
PLY_AKG_SETSPEEDBEFOREPLAYSTREAMS ld (PLY_AKG_TICKDECREASINGCOUNTER),a
    ld hl,(PLY_AKG_CHANNEL1_INVERTEDVOLUMEINTEGERANDDECIMAL)
    ld a,h
    ld (PLY_AKG_CHANNEL1_GENERATEDCURRENTINVERTEDVOLUME),a
    ld de,0
    ld hl,0
    add hl,de
    ld (PLY_AKG_CHANNEL1_GENERATEDCURRENTPITCH),hl
    ld hl,(PLY_AKG_CHANNEL2_INVERTEDVOLUMEINTEGERANDDECIMAL)
    ld a,h
    ld (PLY_AKG_CHANNEL2_GENERATEDCURRENTINVERTEDVOLUME),a
    ld de,0
    ld hl,0
    add hl,de
    ld (PLY_AKG_CHANNEL2_GENERATEDCURRENTPITCH),hl
    ld hl,(PLY_AKG_CHANNEL3_INVERTEDVOLUMEINTEGERANDDECIMAL)
    ld a,h
    ld (PLY_AKG_CHANNEL3_GENERATEDCURRENTINVERTEDVOLUME),a
    ld de,0
    ld hl,0
    add hl,de
    ld (PLY_AKG_CHANNEL3_GENERATEDCURRENTPITCH),hl
    ld sp,(PLY_AKG_SAVESP)
    ld hl,(PLY_AKG_CHANNEL1_GENERATEDCURRENTPITCH)
    ld a,(PLY_AKG_CHANNEL1_TRACKNOTE)
    ld e,a
    ld d,0
    exx
    ld a,(PLY_AKG_CHANNEL1_INSTRUMENTSTEP)
    ld iyl,a
    ld hl,(PLY_AKG_CHANNEL1_PTINSTRUMENT)
    ld a,(PLY_AKG_CHANNEL1_GENERATEDCURRENTINVERTEDVOLUME)
    ld e,a
    ld d,224
    call PLY_AKG_CHANNEL3_READEFFECTSEND
    ld a,(PLY_AKG_CHANNEL1_INSTRUMENTSPEED)
    ld b,a
    ld a,iyl
    inc a
    cp b
    jr c,PLY_AKG_CHANNEL1_SETINSTRUMENTSTEP
    ld (PLY_AKG_CHANNEL1_PTINSTRUMENT),hl
    xor a
PLY_AKG_CHANNEL1_SETINSTRUMENTSTEP ld (PLY_AKG_CHANNEL1_INSTRUMENTSTEP),a
    ld a,e
    ld (PLY_AKG_PSGREG8),a
    srl d
    exx
    ld (PLY_AKG_PSGREG01_INSTR),hl
    ld hl,(PLY_AKG_CHANNEL2_GENERATEDCURRENTPITCH)
    ld a,(PLY_AKG_CHANNEL2_TRACKNOTE)
    ld e,a
    ld d,0
    exx
    ld a,(PLY_AKG_CHANNEL2_INSTRUMENTSTEP)
    ld iyl,a
    ld hl,(PLY_AKG_CHANNEL2_PTINSTRUMENT)
    ld a,(PLY_AKG_CHANNEL2_GENERATEDCURRENTINVERTEDVOLUME)
    ld e,a
    call PLY_AKG_CHANNEL3_READEFFECTSEND
    ld a,(PLY_AKG_CHANNEL2_INSTRUMENTSPEED)
    ld b,a
    ld a,iyl
    inc a
    cp b
    jr c,PLY_AKG_CHANNEL2_SETINSTRUMENTSTEP
    ld (PLY_AKG_CHANNEL2_PTINSTRUMENT),hl
    xor a
PLY_AKG_CHANNEL2_SETINSTRUMENTSTEP ld (PLY_AKG_CHANNEL2_INSTRUMENTSTEP),a
    ld a,e
    ld (PLY_AKG_PSGREG9_10_INSTR),a
    scf
    rr d
    exx
    ld (PLY_AKG_PSGREG23_INSTR),hl
    ld hl,(PLY_AKG_CHANNEL3_GENERATEDCURRENTPITCH)
    ld a,(PLY_AKG_CHANNEL3_TRACKNOTE)
    ld e,a
    ld d,0
    exx
    ld a,(PLY_AKG_CHANNEL3_INSTRUMENTSTEP)
    ld iyl,a
    ld hl,(PLY_AKG_CHANNEL3_PTINSTRUMENT)
    ld a,(PLY_AKG_CHANNEL3_GENERATEDCURRENTINVERTEDVOLUME)
    ld e,a
    call PLY_AKG_CHANNEL3_READEFFECTSEND
    ld a,(PLY_AKG_CHANNEL3_INSTRUMENTSPEED)
    ld b,a
    ld a,iyl
    inc a
    cp b
    jr c,PLY_AKG_CHANNEL3_SETINSTRUMENTSTEP
    ld (PLY_AKG_CHANNEL3_PTINSTRUMENT),hl
    xor a
PLY_AKG_CHANNEL3_SETINSTRUMENTSTEP ld (PLY_AKG_CHANNEL3_INSTRUMENTSTEP),a
    ld a,e
    ld (PLY_AKG_PSGREG10),a
    ld a,d
    exx
    ld (PLY_AKG_PSGREG45_INSTR),hl
    call PLY_AKG_PLAYSOUNDEFFECTSSTREAM
PLY_AKG_SENDPSGREGISTERS ld b,a
    ld a,7
    out (160),a
    ld a,b
    out (161),a
    ld hl,(PLY_AKG_PSGREG01_INSTR)
    xor a
    out (160),a
    ld a,l
    out (161),a
    ld a,1
    out (160),a
    ld a,h
    out (161),a
    ld hl,(PLY_AKG_PSGREG23_INSTR)
    ld a,2
    out (160),a
    ld a,l
    out (161),a
    ld a,3
    out (160),a
    ld a,h
    out (161),a
    ld hl,(PLY_AKG_PSGREG45_INSTR)
    ld a,4
    out (160),a
    ld a,l
    out (161),a
    ld a,5
    out (160),a
    ld a,h
    out (161),a
    ld hl,(PLY_AKG_PSGREG6_8_INSTR)
    ld a,6
    out (160),a
    ld a,l
    out (161),a
    ld a,8
    out (160),a
    ld a,h
    out (161),a
    ld hl,(PLY_AKG_PSGREG9_10_INSTR)
    ld a,9
    out (160),a
    ld a,l
    out (161),a
    ld a,10
    out (160),a
    ld a,h
    out (161),a
    ld hl,(PLY_AKG_PSGHARDWAREPERIOD_INSTR)
    ld a,11
    out (160),a
    ld a,l
    out (161),a
    ld a,12
    out (160),a
    ld a,h
    out (161),a
    ld a,13
    out (160),a
    ld a,(PLY_AKG_PSGREG13_OLDVALUE)
    ld l,a
    ld a,(PLY_AKG_PSGREG13_INSTR)
    cp l
    jr z,PLY_AKG_PSGREG13_END
    ld (PLY_AKG_PSGREG13_OLDVALUE),a
    out (161),a
PLY_AKG_PSGREG13_END ld sp,(PLY_AKG_SAVESP)
    ret 
PLY_AKG_CHANNEL1_MAYBEEFFECTS ld (PLY_AKG_CHANNEL1_SOUNDSTREAM_RELATIVEMODIFIERADDRESS),a
    jp PLY_AKG_CHANNEL1_BEFOREEND_STORECELLPOINTER
PLY_AKG_CHANNEL1_READEFFECTSEND
PLY_AKG_CHANNEL2_MAYBEEFFECTS ld (PLY_AKG_CHANNEL2_PLAYINSTRUMENT_RELATIVEMODIFIERADDRESS),a
    jp PLY_AKG_CHANNEL2_BEFOREEND_STORECELLPOINTER
PLY_AKG_CHANNEL2_READEFFECTSEND
PLY_AKG_CHANNEL3_MAYBEEFFECTS ld (PLY_AKG_CHANNEL3_WAITCOUNTER),a
    jp PLY_AKG_CHANNEL3_BEFOREEND_STORECELLPOINTER
PLY_AKG_CHANNEL3_READEFFECTSEND
PLY_AKG_READINSTRUMENTCELL ld a,(hl)
    inc hl
    ld b,a
    rra 
    jp c,PLY_AKG_S_OR_H_OR_SAH_OR_ENDWITHLOOP
    rra 
    jp c,PLY_AKG_STH_OR_ENDWITHOUTLOOP
    rra 
PLY_AKG_NOSOFTNOHARD and 15
    sub e
    jr nc,PLY_AKG_SOFT-4
    xor a
    ld e,a
    set 2,d
    ret 
PLY_AKG_SOFT and 15
    sub e
    jr nc,PLY_AKG_SOFTONLY_HARDONLY_TESTSIMPLE_COMMON-1
    xor a
    ld e,a
PLY_AKG_SOFTONLY_HARDONLY_TESTSIMPLE_COMMON rl b
    jr nc,PLY_AKG_S_NOTSIMPLE
    ld c,0
    jr PLY_AKG_S_AFTERSIMPLETEST
PLY_AKG_S_NOTSIMPLE ld b,(hl)
    ld c,b
    inc hl
PLY_AKG_S_AFTERSIMPLETEST call PLY_AKG_H_OR_ENDWITHLOOP
    ld a,c
    and 31
    ret z
    ld (PLY_AKG_PSGREG6_8_INSTR),a
    res 5,d
    ret 
PLY_AKG_ENDWITHOUTLOOP ld hl,(PLY_AKG_EMPTYINSTRUMENTDATAPT)
    inc hl
    xor a
    ld b,a
    jp PLY_AKG_NOSOFTNOHARD
PLY_AKG_STH_OR_ENDWITHOUTLOOP rra 
    jr PLY_AKG_ENDWITHOUTLOOP
PLY_AKG_S_OR_H_OR_SAH_OR_ENDWITHLOOP rra 
    jr c,PLY_AKG_H_OR_ENDWITHLOOP
    rra 
    jp nc,PLY_AKG_SOFT
PLY_AKG_H_OR_ENDWITHLOOP
PLY_AKG_S_OR_H_CHECKIFSIMPLEFIRST_CALCULATEPERIOD jr nc,PLY_AKG_S_OR_H_NEXTBYTE
    exx
    ex de,hl
    add hl,hl
    ld bc,PLY_AKG_PERIODTABLE
    add hl,bc
    ld a,(hl)
    inc hl
    ld h,(hl)
    ld l,a
    add hl,de
    exx
    rl b
    rl b
    rl b
    ret 
PLY_AKG_S_OR_H_NEXTBYTE rl b
    rl b
    jr nc,PLY_AKG_S_OR_H_AFTERARPEGGIO
    ld a,(hl)
    inc hl
    exx
    add a,e
    ld e,a
    exx
PLY_AKG_S_OR_H_AFTERARPEGGIO rl b
    jr nc,PLY_AKG_S_OR_H_AFTERPITCH
    ld a,(hl)
    inc hl
    exx
    add a,l
    ld l,a
    exx
    ld a,(hl)
    inc hl
    exx
    adc a,h
    ld h,a
    exx
PLY_AKG_S_OR_H_AFTERPITCH exx
    ex de,hl
    add hl,hl
    ld bc,PLY_AKG_PERIODTABLE
    add hl,bc
    ld a,(hl)
    inc hl
    ld h,(hl)
    ld l,a
    add hl,de
    exx
    ret 
PLY_AKG_STOH_HTOS_SANDH_COMMON ld e,16
    rra 
    and 7
    add a,8
    ld (PLY_AKG_PSGREG13_INSTR),a
    rl b
    ld c,(hl)
    ld b,c
    inc hl
    rl b
    call PLY_AKG_H_OR_ENDWITHLOOP
    ld a,c
    rla 
    rla 
    and 28
    ret 
PLY_AKG_PERIODTABLE dw 6778
    dw 6398
    dw 6039
    dw 5700
    dw 5380
    dw 5078
    dw 4793
    dw 4524
    dw 4270
    dw 4030
    dw 3804
    dw 3591
    dw 3389
    dw 3199
    dw 3019
    dw 2850
    dw 2690
    dw 2539
    dw 2397
    dw 2262
    dw 2135
    dw 2015
    dw 1902
    dw 1795
    dw 1695
    dw 1599
    dw 1510
    dw 1425
    dw 1345
    dw 1270
    dw 1198
    dw 1131
    dw 1068
    dw 1008
    dw 951
    dw 898
    dw 847
    dw 800
    dw 755
    dw 712
    dw 673
    dw 635
    dw 599
    dw 566
    dw 534
    dw 504
    dw 476
    dw 449
    dw 424
    dw 400
    dw 377
    dw 356
    dw 336
    dw 317
    dw 300
    dw 283
    dw 267
    dw 252
    dw 238
    dw 224
    dw 212
    dw 200
    dw 189
    dw 178
    dw 168
    dw 159
    dw 150
    dw 141
    dw 133
    dw 126
    dw 119
    dw 112
    dw 106
    dw 100
    dw 94
    dw 89
    dw 84
    dw 79
    dw 75
    dw 71
    dw 67
    dw 63
    dw 59
    dw 56
    dw 53
    dw 50
    dw 47
    dw 45
    dw 42
    dw 40
    dw 37
    dw 35
    dw 33
    dw 31
    dw 30
    dw 28
    dw 26
    dw 25
    dw 24
    dw 22
    dw 21
    dw 20
    dw 19
    dw 18
    dw 17
    dw 16
    dw 15
    dw 14
    dw 13
    dw 12
    dw 12
    dw 11
    dw 11
    dw 10
    dw 9
    dw 9
    dw 8
    dw 8
    dw 7
    dw 7
    dw 7
    dw 6
    dw 6
    dw 6
    dw 5
    dw 5
    dw 5
    dw 4
PLY_AKG_BASENOTEINDEX equ 55553
PLY_AKG_CHANNEL1_GENERATEDCURRENTINVERTEDVOLUME equ 55589
PLY_AKG_CHANNEL1_GENERATEDCURRENTPITCH equ 55606
PLY_AKG_CHANNEL1_INSTRUMENTSPEED equ 55586
PLY_AKG_CHANNEL1_INSTRUMENTSTEP equ 55587
PLY_AKG_CHANNEL1_INVERTEDVOLUMEINTEGER equ 55597
PLY_AKG_CHANNEL1_INVERTEDVOLUMEINTEGERANDDECIMAL equ 55596
PLY_AKG_CHANNEL1_PTBASEINSTRUMENT equ 55602
PLY_AKG_CHANNEL1_PTINSTRUMENT equ 55600
PLY_AKG_CHANNEL1_PTTRACK equ 55590
PLY_AKG_CHANNEL1_SOUNDEFFECTDATA equ 55656
PLY_AKG_CHANNEL1_SOUNDSTREAM_RELATIVEMODIFIERADDRESS equ 55585
PLY_AKG_CHANNEL1_TRACKNOTE equ 55588
PLY_AKG_CHANNEL2_GENERATEDCURRENTINVERTEDVOLUME equ 55612
PLY_AKG_CHANNEL2_GENERATEDCURRENTPITCH equ 55629
PLY_AKG_CHANNEL2_INSTRUMENTSPEED equ 55609
PLY_AKG_CHANNEL2_INSTRUMENTSTEP equ 55610
PLY_AKG_CHANNEL2_INVERTEDVOLUMEINTEGER equ 55620
PLY_AKG_CHANNEL2_INVERTEDVOLUMEINTEGERANDDECIMAL equ 55619
PLY_AKG_CHANNEL2_PLAYINSTRUMENT_RELATIVEMODIFIERADDRESS equ 55608
PLY_AKG_CHANNEL2_PTBASEINSTRUMENT equ 55625
PLY_AKG_CHANNEL2_PTINSTRUMENT equ 55623
PLY_AKG_CHANNEL2_PTTRACK equ 55613
PLY_AKG_CHANNEL2_SOUNDEFFECTDATA equ 55664
PLY_AKG_CHANNEL2_TRACKNOTE equ 55611
PLY_AKG_CHANNEL3_GENERATEDCURRENTINVERTEDVOLUME equ 55635
PLY_AKG_CHANNEL3_GENERATEDCURRENTPITCH equ 55652
PLY_AKG_CHANNEL3_INSTRUMENTSPEED equ 55632
PLY_AKG_CHANNEL3_INSTRUMENTSTEP equ 55633
PLY_AKG_CHANNEL3_INVERTEDVOLUMEINTEGER equ 55643
PLY_AKG_CHANNEL3_INVERTEDVOLUMEINTEGERANDDECIMAL equ 55642
PLY_AKG_CHANNEL3_PTBASEINSTRUMENT equ 55648
PLY_AKG_CHANNEL3_PTINSTRUMENT equ 55646
PLY_AKG_CHANNEL3_PTTRACK equ 55636
PLY_AKG_CHANNEL3_SOUNDEFFECTDATA equ 55672
PLY_AKG_CHANNEL3_TRACKNOTE equ 55634
PLY_AKG_CHANNEL3_WAITCOUNTER equ 55631
PLY_AKG_CURRENTSPEED equ 55552
PLY_AKG_EMPTYINSTRUMENTDATAPT equ 55563
PLY_AKG_INSTRUMENTSTABLE equ 55561
PLY_AKG_PATTERNDECREASINGHEIGHT equ 55554
PLY_AKG_PSGHARDWAREPERIOD_INSTR equ 55577
PLY_AKG_PSGREG01_INSTR equ 55567
PLY_AKG_PSGREG10 equ 55576
PLY_AKG_PSGREG13_INSTR equ 55557
PLY_AKG_PSGREG13_OLDVALUE equ 55556
PLY_AKG_PSGREG23_INSTR equ 55569
PLY_AKG_PSGREG45_INSTR equ 55571
PLY_AKG_PSGREG6_8_INSTR equ 55573
PLY_AKG_PSGREG8 equ 55574
PLY_AKG_PSGREG9_10_INSTR equ 55575
PLY_AKG_PTSOUNDEFFECTTABLE equ 55654
PLY_AKG_READLINKER_PTLINKER equ 55559
PLY_AKG_SAVESP equ 55565
PLY_AKG_TEMPPLAYINSTRUMENTJUMPINSTRANDADDRESS equ 55582
PLY_AKG_TICKDECREASINGCOUNTER equ 55555
