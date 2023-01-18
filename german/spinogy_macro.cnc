; ------------------------------------------
;   SPINOGY X22 Macros v1.5.1 for EdingCNC
; ------------------------------------------
;
;   SPINOGY GmbH
;   Brunnenweg 17
;   64331 Weiterstadt
;
;   https://spinogy.de
;
; ------------------------------------------
;
;   SUPPORTED X22 SPINDLE MODELS:
;   - CG005 - 25.000 rpm
;   - CG006 - 30.000 rpm
;   - CG007 - 35.000 rpm
;   - CG008 - 40.000 rpm
;   - CG009 - 45.000 rpm
;   - CG010 - 50.000 rpm
;
; ------------------------------------------
;
;   VERSION HISTORY:
;   - 1.0.0: first version
;   - 1.1.0: use loops for speed calculation
;   - 1.2.0: add configuration dialog
;   - 1.3.0: add ramp up for spindle speeds
;   - 1.4.0: add graphical dialogs
;   - 1.5.0: check config against M90 setting
;   - 1.5.1: first release
;
; ------------------------------------------
;
;   CONFIGURATION VARIABLES (persistent):
;   - #4337 - if configured
;   - #4338 - configured spindle model
;   - #4339 - configured spindle rpm
;
;   USED HELPER VARIABLES (non-persistent):
;   - #1337 - loop speed counter
;   - #1338 - loop interval counter
;   - #1339 - loop ramp counter
;   - #1340 - calculated rpm
;
;   EDINGCNC OEM VARIABLES (persistent):
;   - #5394 - M90 Max Spindle Speed
;
;   EDINGCNC OEM VARIABLES (non-persistent):
;   - #5398 - dialogmessage return value (1=OK, -1=cancel)

;
; ------------------------------------------

; configuration routine
Sub spinogy_config
    DlgMsg "Spinogy_Config" "Spindel-Modell CG0xx:" 4338

	If [#5398 == 1]
        ; check if user input is out of range
        If [[#4338 < 5] or [#4338 > 10]]
            ; reset config
            #4337 = 0
            #4338 = 0
            #4339 = 0

            DlgMsg "Fehler: Modellnummer nicht gefunden."

            If [#5398 == 1]
                GoSub spinogy_config
            Else
                ErrMsg "Spinogy Konfiguration abgebrochen."
            EndIf
        Else
            If [#4338 == 5]
                #4339 = 25000
                #4337 = 1

                Msg "Konfigurierte Spindel: SPINOGY X22 CG005 / 25.000 U/min"
            EndIf

            If [#4338 == 6]
                #4339 = 30000
                #4337 = 1

                Msg "Konfigurierte Spindel: SPINOGY X22 CG006 / 30.000 U/min"
            EndIf

            If [#4338 == 7]
                #4339 = 35000
                #4337 = 1

                Msg "Konfigurierte Spindel: SPINOGY X22 CG007 / 35.000 U/min"
            EndIf

            If [#4338 == 8]
                #4339 = 40000
                #4337 = 1

                Msg "Konfigurierte Spindel: SPINOGY X22 CG008 / 40.000 U/min"
            EndIf

            If [#4338 == 9]
                #4339 = 45000
                #4337 = 1

                Msg "Konfigurierte Spindel: SPINOGY X22 CG009 / 45.000 U/min"
            EndIf

            If [#4338 == 10]
                #4339 = 50000
                #4337 = 1

                Msg "Konfigurierte Spindel: SPINOGY X22 CG010 / 50.000 U/min"
            EndIf

            ; check if eding M90 setting is correctly configured, too
            If [#5394 < #4339]
                WarnMsg "Die konfigurierte max. Geschwindigkeit ("#5394") in EdingCNC (M90) ist geringer, als die der konfigurierten Spindel ("#4339"). Bitte Einstellungen prüfen."
            EndIf
        EndIf
    Else
        Msg "Spinogy Konfiguration abgebrochen."
    EndIf
EndSub

; routine for warmup spinogy x22 spindles
Sub spinogy_warmup
	DlgMsg "Spinogy_Warmup"

	If [#5398 == 1]
        ; used routine variables
        #1337 = 0 ; loop speed counter
        #1339 = 0 ; loop ramp counter
        #1340 = 0 ; calculated rpm

        Msg "Starte Spinogy Spindel-Aufwärmlauf ..."

        ; move z up
        Msg "Fahre Z auf sichere Position ..."
		G53 G0 Z0

        ; loop 4 times to increment speed
        While [#1337 < 4]
            ; calculate destination speed
            #1340 = [[#1337 + 1] * 6]

            Msg "Hochfahren der Spindel auf "#1340".000 U/min und halten für 5 Minuten ..."

            ; loop 3 times to ramp up spindle rpm
            #1339 = 3
            While [#1339 > 0]
                Msg "Hochfahren für 7 Sekunden ..."

                ; increase by 1500 rpm in 7 second steps
                M3 S[[#1340 * 1000] - [#1339 * 1500]]
                G4 P[7]

                ; decrement counter
                #1339 = [#1339 - 1]
            EndWhile

            ; start spindle at desired rpm and run for 5 minutes
            Msg "Halte "#1340".000 U/min für 5 Minuten ..."
            M3 S[#1340 * 1000]
            G4 P[60 * 5]

            ; increment counter
            #1337 = [#1337 + 1]
        EndWhile

        ; finished warmup and stop spindle
        M5
        Msg "Spinogy Spindel-Aufwärmlauf abgeschlossen!"
	EndIf
EndSub

; special routine for spinogy x22 to evenly distribute grease
Sub spinogy_greaserun
    If [#4337 <> 1]
        ErrMsg "Bitte zuerst die Spinogy Konfiguration ausführen."
    EndIf

    DlgMsg "Spinogy_Greaserun"

    If [#5398 == 1]
        ; used routine variables
        #1337 = 0 ; loop speed counter
        #1338 = 0 ; loop interval counter
        #1339 = 0 ; loop ramp counter
        #1340 = 0 ; calculated rpm

        Msg "Starte Spinogy Fettverteilungslauf ..."

        ; move z up
        Msg "Fahre Z auf sichere Position ..."
		G53 G0 Z0

        ; ---------
        ; phase one
        ; ---------

        ; loop 3 times to increment speed
        While [#1337 < 3]
            ; calculate speed
            #1340 = [[#1337 + 1] * 8]

            ; loop 4 times for intervals
            #1338 = 0
            While [#1338 < 4]
                Msg "Hochfahren der Spindel auf "#1340".000 U/min und halten für 1 Minute ..."

                ; loop 3 times to ramp up spindle rpm
                #1339 = 3
                While [#1339 > 0]
                    Msg "Hochfahren für 5 Sekunden ..."

                    ; increase by 2000 rpm in 5 second steps
                    M3 S[[#1340 * 1000] - [#1339 * 2000]]
                    G4 P[5]

                    ; decrement counter
                    #1339 = [#1339 - 1]
                EndWhile

                ; start spindle at desired rpm and run for 1 minutes
                Msg "Halte "#1340".000 U/min für 1 Minute ..."
                M3 S[#1340 * 1000]
                G4 P[60 * 1]

                ; turn off spindle and wait 2 minutes
                Msg "Pause für 2 Minuten ..."
                M5
                G4 P[60 * 2]

                ; increment counter
                #1338 = [#1338 + 1]
            EndWhile

            ; increment counter
            #1337 = [#1337 + 1]
        EndWhile

        ; ---------
        ; phase two
        ; ---------

        Msg "Hochfahren der Spindel auf 24.000 U/min und halten für 30 Minuten ..."

        ; loop 3 times to ramp up spindle rpm
        #1339 = 0
        While [#1339 < 3]
            Msg "Hochfahren für 5 Sekunden ..."

            ; increase by 6000 rpm in 5 second steps
            M3 S[[#1339 + 1] * 6000]
            G4 P[5]

            ; increment counter
            #1339 = [#1339 + 1]
        EndWhile

        ; start spindle at 24.000 rpm and run for 30 minutes
        Msg "Halte 24.000 U/min für 30 Minuten ..."
		M03 S24000
		G04 P[60 * 30]

        ; turn off spindle and wait 5 minutes
        Msg "Pause für 5 Minuten ..."
        M05
        G04 P[60 * 5]

        Msg "Hochfahren der Spindel auf "[#4339 / 1000]".000 U/min und halten für 30 Minuten ..."

        ; loop 6 times to ramp up spindle rpm
        #1339 = 0
        While [#1339 < 7]
            Msg "Hochfahren für 3 Sekunden ..."

            ; increase by 1/6 of the configured max rpm in 3 second steps
            M3 S[[#1339 + 1] * [#4339 / 7]]
            G4 P[3]

            ; increment counter
            #1339 = [#1339 + 1]
        EndWhile

        ; turn spindle at configured maximum rpm for 30 minutes
        Msg "Halte "[#4339 / 1000]".000 U/min für 30 Minuten ..."
        M03 S[#4339]
        G04 P[60 * 30]

        ; finished run and stop spindle
        M05
        Msg "Spinogy Fettverteilungslauf abgeschlossen!"
	EndIf
EndSub
