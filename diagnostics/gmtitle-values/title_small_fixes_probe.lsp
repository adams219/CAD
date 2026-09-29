;;; GMTITLE step 4 (2026-09-29): paper size from block names, work-copy name, XREF host
;;; guidance.  Runs on a throw-away copy, never saved.
;;; Environment: SWT_STEP4_LOG = log path, SWT_PLAN_MODULE = swcad_title_scale.lsp path.
;;; 1. unit checks: block-name paper size, work-copy name and timestamp
;;; 2. every block name in the drawing: previous rule vs new rule
;;; 3. every source sheet: paper size, target frame and SIZ value, previous vs new rule
;;; 4. XREF host guidance

(vl-load-com)
(load (getenv "SWT_PLAN_MODULE"))

(defun swt4-line (log parts / text part)
  (setq text "")
  (foreach part parts
    (setq text (strcat text (if (= text "") "" "|") (vl-string-translate "|\n\r\t" "/   " (vl-princ-to-string part))))
  )
  (write-line text log)
)

(defun swt4-check (log label actual expected)
  (swt4-line log (list (if (equal actual expected) "UNIT_OK" "UNIT_FAIL") label actual expected))
)

;;; The rule before step 4, copied from 260929-title-stop-1.
(defun swt4-old-size (block-name / value)
  (setq value (strcase (swcad-title-string block-name)))
  (cond
    ((swcad-title-native-target-title-name-p value) nil)
    ((wcmatch value "*A0*,*A-0*,*A_0*,*A 0*") "A0")
    ((wcmatch value "*A1*,*A-1*,*A_1*,*A 1*") "A1")
    ((wcmatch value "*A2*,*A-2*,*A_2*,*A 2*") "A2")
    ((wcmatch value "*A3*,*A-3*,*A_3*,*A 3*") "A3")
    ((wcmatch value "*A4*,*A-4*,*A_4*,*A 4*") "A4")
    (T nil)
  )
)

;;; Paper size, target frame and SIZ value for every source sheet with the rule in force.
(defun swt4-sheet-plan (/ result records item source source-ename source-bbox source-block source-frame source-frame-ename source-frame-bbox source-frame-block build values block-sheet inferred frame-block)
  (setq result nil)
  (setq records (swcad-title-transfer-batch-source-records))
  (foreach item records
    (setq source (car item))
    (setq source-ename (car source))
    (setq source-bbox (caddr source))
    (setq source-block (if source-ename (swcad-title-effective-insert-name source-ename) ""))
    (setq source-frame (if source-bbox (swcad-title-transfer-source-frame source-bbox source-ename) nil))
    (setq source-frame-ename (if source-frame (car source-frame) nil))
    (setq source-frame-bbox (if source-frame (caddr source-frame) nil))
    (setq source-frame-block (if source-frame-ename (swcad-title-effective-insert-name source-frame-ename) nil))
    (setq build (swcad-title-transfer-build-mappings source-bbox source-ename 7.0))
    (setq values (swcad-title-transfer-values (car build)))
    (if (not source-ename)
      (setq values (swcad-title-values-fill-missing-template-empty values))
    )
    (setq block-sheet (swcad-title-source-block-sheet-size source-block source-frame-block))
    (setq values (swcad-title-values-with-sheet-size-override values block-sheet))
    (setq inferred (swcad-title-effective-source-frame-bbox source-bbox source-frame-bbox values block-sheet))
    (setq frame-block (swcad-title-target-frame-block-name-for-source source-block source-frame-block values inferred))
    (setq result
      (cons
        (list
          (swcad-title-point-string (list (car source-bbox) (cadr source-bbox)))
          source-block
          (swcad-title-string source-frame-block)
          (swcad-title-string block-sheet)
          frame-block
          (swcad-title-sheet-size-value values)
          (swcad-title-string (swcad-title-sheet-size-from-frame-bbox inferred))
        )
        result
      )
    )
  )
  (reverse result)
)

(defun swt4-main (/ log name old new diffs sized table-entry new-plan old-plan saved-fn a b stamp cdate)
  (setq log (open (getenv "SWT_STEP4_LOG") "w"))
  (swt4-line log (list "DWG" (strcat (getvar "DWGPREFIX") (getvar "DWGNAME"))))
  (swt4-line log (list "VERSION" *swcad-title-scale-version*))

  ;; 1. Unit checks.
  (foreach item
    '(
      ("DR_A3_Outline" "A3")
      ("DR_A4_Outline" "A4")
      ("DR_A2_Outline" "A2")
      ("XREF$0$Bracket_A1_260506$0$DR_A3_Outline" "A3")
      ("HOST$0$P_eCVT-Sun HL Gear_LH_260506$0$DR_titlea_3rd" nil)
      ("DR_titlea_3rd" nil)
      ("DATA1" nil)
      ("A12_PART" nil)
      ("A4 - ISO" "A4")
      ("a3-landscape" "A3")
      ("SW_A2" "A2")
      ("A-4" "A4")
      ("FRAME_A_3" "A3")
      ("A3_TO_A4" nil)
      ("XREF|DR_A2_Outline" "A2")
      ("DR-A3 FROM_HYUN" "A3")
      ("A3" "A3")
      ("SHEETA3" nil)
      ("" nil)
    )
    (swt4-check log (strcat "sheet-name " (car item)) (swcad-title-sheet-size-from-block-name (car item)) (cadr item))
  )
  (swt4-check log "workcopy-base plain" (swcad-title-work-copy-base-name "Pump Gear_260506") "Pump Gear_260506")
  (swt4-check log "workcopy-base one" (swcad-title-work-copy-base-name "Pump Gear_SWTITLE_20261002-181022") "Pump Gear")
  (swt4-check log "workcopy-base two" (swcad-title-work-copy-base-name "Pump_SWTITLE_20261002-181022_SWTITLE_20261003-091500") "Pump")
  (swt4-check log "workcopy-base lower" (swcad-title-work-copy-base-name "Pump_swtitle_x") "Pump")
  (swt4-check log "workcopy-base only-suffix" (swcad-title-work-copy-base-name "_SWTITLE_x") "_SWTITLE_x")
  (setq stamp (swcad-title-work-copy-timestamp))
  (setq cdate (rtos (getvar "CDATE") 2 6))
  (swt4-line log (list "STAMP" stamp cdate))
  (swt4-check log "timestamp-date-is-today" (substr stamp 1 8) (substr cdate 1 8))
  (swt4-check log "timestamp-format" (and (= (strlen stamp) 15) (= (substr stamp 9 1) "-")) T)

  ;; 2. Block names in this drawing.
  (setq diffs 0)
  (setq sized 0)
  (setq table-entry (tblnext "BLOCK" T))
  (while table-entry
    (setq name (cdr (assoc 2 table-entry)))
    (setq old (swt4-old-size name))
    (setq new (swcad-title-sheet-size-from-block-name name))
    (if (or old new) (setq sized (1+ sized)))
    (if (not (equal old new))
      (progn
        (setq diffs (1+ diffs))
        (swt4-line log (list "NAMEDIFF" name (swcad-title-string old) (swcad-title-string new)))
      )
      (if new (swt4-line log (list "NAMESAME" name new)))
    )
    (setq table-entry (tblnext "BLOCK"))
  )
  (swt4-line log (list "NAMES" "sized" sized "different" diffs))

  ;; 3. Source sheets with each rule.
  (setq new-plan (swt4-sheet-plan))
  (setq saved-fn swcad-title-sheet-size-from-block-name)
  (setq swcad-title-sheet-size-from-block-name swt4-old-size)
  (setq old-plan (swt4-sheet-plan))
  (setq swcad-title-sheet-size-from-block-name saved-fn)
  (swt4-line log (list "SHEETS" "new" (length new-plan) "old" (length old-plan)))
  (setq diffs 0)
  (foreach a new-plan
    (setq b (assoc (car a) old-plan))
    (swt4-line log (append (list (if (equal a b) "SHEETSAME" "SHEETDIFF")) a (list "old" (if b (cdr b) "<missing>"))))
    (if (not (equal a b)) (setq diffs (1+ diffs)))
  )
  (foreach b old-plan
    (if (not (assoc (car b) new-plan))
      (progn (setq diffs (1+ diffs)) (swt4-line log (append (list "SHEETDIFF-OLD-ONLY") b)))
    )
  )
  (swt4-line log (list "SHEETS-DIFFERENT" diffs))
  (swt4-check log "sheets-same-as-previous-rule" diffs 0)

  ;; 4. XREF host guidance.
  (swt4-line log (cons "NESTED_SHEETS" (swcad-title-model-nested-sheet-counts)))
  (swt4-check log "nested-sheet-guidance-not-shown" (if (swcad-title-print-nested-sheet-guidance) "shown" "not-shown") "not-shown")

  (write-line "Step4 probe completed: yes" log)
  (close log)
  (princ)
)

(swt4-main)
