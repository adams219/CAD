;;; Throw-away probe (copy, never saved) for the GMTITLE deletion safety changes
;;; (2026-09-29): no restore on a second delete, locked-layer reporting, and which
;;; lines/solids near the old title are deleted. Compares the title-graphic rule with
;;; the previous rule on every real sheet of the drawing.
;;; Environment: SWT_STEP2_LOG = log path, SWT_PLAN_MODULE = swcad_title_scale.lsp path.

(vl-load-com)
(load (getenv "SWT_PLAN_MODULE"))

(defun swt-2-line (log parts / text part)
  (setq text "")
  (foreach part parts
    (setq text (strcat text (if (= text "") "" "|") (vl-string-translate "|\n\r\t" "/   " (swcad-title-string part))))
  )
  (write-line text log)
)

(defun swt-2-check (log label actual expected)
  (swt-2-line log (list (if (equal actual expected) "UNIT_OK" "UNIT_FAIL") label (vl-princ-to-string actual) (vl-princ-to-string expected)))
)

(defun swt-2-line-ent (p1 p2 layer paper)
  (entmake
    (append
      (list '(0 . "LINE") (cons 8 layer) (cons 10 p1) (cons 11 p2))
      (if paper '((67 . 1)) nil)
    )
  )
  (entlast)
)

(defun swt-2-solid-ent (x1 y1 x2 y2 layer)
  (entmake
    (list
      '(0 . "SOLID") (cons 8 layer)
      (list 10 x1 y1 0.0) (list 11 x2 y1 0.0) (list 12 x1 y2 0.0) (list 13 x2 y2 0.0)
    )
  )
  (entlast)
)

;;; The rule used before 2026-09-29 step 2: touching the title box +1 mm, any space.
(defun swt-2-old-title-graphics (source-bbox / ss index ename data bbox handle result)
  (setq result nil)
  (setq ss (ssget "_X" '((0 . "LINE,LWPOLYLINE,POLYLINE,2DPOLYLINE,HATCH,SOLID,TRACE,WIPEOUT"))))
  (setq index 0)
  (while (and ss (< index (sslength ss)))
    (setq ename (ssname ss index))
    (setq data (entget ename))
    (setq bbox (swcad-title-safe-bbox ename))
    (setq handle (cdr (assoc 5 data)))
    (if (swcad-title-bbox-intersects-p bbox (swcad-title-expand-bbox source-bbox 1.0))
      (setq result (cons handle result))
    )
    (setq index (1+ index))
  )
  result
)

(defun swt-2-member-p (handle handles) (if (member handle handles) "selected" "kept"))

(defun swt-2-main (/ log e r doc layers layer lk records item source source-ename source-bbox source-frame source-frame-ename source-frame-bbox values block-sheet inferred build source-block source-frame-block old new h index diffs synthetic t-in t-cross t-solid t-margin t-paper texts paper-text)
  (setq log (open (getenv "SWT_STEP2_LOG") "w"))
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))

  ;; 1. entdel on an erased entity restores it (GstarCAD), the new delete does not.
  (setq e (swt-2-line-ent '(0.0 0.0 0.0) '(10.0 0.0 0.0) "0" nil))
  (entdel e)
  (entdel e)
  (swt-2-check log "raw-entdel-twice-restores" (if (entget e) "restored" "gone") "restored")
  (entdel e)
  (setq e (swt-2-line-ent '(0.0 5.0 0.0) '(10.0 5.0 0.0) "0" nil))
  (swt-2-check log "delete-first" (swcad-title-delete-ename e) T)
  (swt-2-check log "delete-second" (swcad-title-delete-ename e) 'ALREADY)
  (swt-2-check log "delete-second-stays-gone" (if (entget e) "restored" "gone") "gone")
  (setq e (swt-2-line-ent '(0.0 7.0 0.0) '(10.0 7.0 0.0) "0" nil))
  (swt-2-check log "delete-list-counts-once" (swcad-title-delete-handle-list (list (cdr (assoc 5 (entget e))) (cdr (assoc 5 (entget e))))) 1)

  ;; 2. Locked layer: not deleted, reported.
  (setq layers (vla-get-Layers doc))
  (setq layer (vla-Add layers "SWT_LOCKED_TEST"))
  (setq lk (swt-2-line-ent '(0.0 10.0 0.0) '(10.0 10.0 0.0) "SWT_LOCKED_TEST" nil))
  (vla-put-Lock layer :vlax-true)
  (swt-2-check log "locked-layer-detected" (if (swcad-title-ename-on-locked-layer-p lk) T nil) T)
  (swt-2-check log "locked-delete-fails" (swcad-title-delete-ename lk) nil)
  (swt-2-check log "locked-still-there" (if (entget lk) "there" "gone") "there")
  (swt-2-check log "locked-old-sheet-handles" (swcad-title-locked-old-sheet-handles lk nil nil nil) (list (swcad-title-ename-handle lk)))
  (swt-2-check log "remaining-after-failed-delete" (swcad-title-remaining-old-sheet-handles lk nil nil nil) (list (swcad-title-ename-handle lk)))
  (setq e (swt-2-line-ent '(0.0 12.0 0.0) '(10.0 12.0 0.0) "0" nil))
  (setq r (swcad-title-ename-handle e))
  (swcad-title-delete-ename e)
  (swt-2-check log "remaining-after-delete" (swcad-title-remaining-old-sheet-handles e nil nil nil) nil)
  ;; Title lines, loose frame lines and residue are checked too (Codex review of PR #4).
  (setq h (swcad-title-ename-handle lk))
  (swt-2-check log "locked-cleanup-line-reported" (swcad-title-locked-old-sheet-handles nil nil nil (list h)) (list h))
  (swt-2-check log "remaining-cleanup-line-reported" (swcad-title-remaining-old-sheet-handles nil nil nil (list h)) (list h))
  (swt-2-check log "remaining-cleanup-line-gone" (swcad-title-remaining-old-sheet-handles nil nil nil (list r)) nil)
  (swt-2-check log "queued-cleanup-with-frame-insert" (swcad-title-queued-cleanup-handles lk '("S") '("G") '("F") '("R")) '("S" "G" "R"))
  (swt-2-check log "queued-cleanup-without-frame-insert" (swcad-title-queued-cleanup-handles nil '("S") '("G") '("F") '("R")) '("S" "G" "F" "R"))

  ;; 3. Title graphics rule on sheet 1 with synthetic entities.
  (setq records (swcad-title-transfer-batch-source-records))
  (setq item (car records))
  (setq source (car item))
  (setq source-ename (car source))
  (setq source-bbox (caddr source))
  (setq source-frame (swcad-title-transfer-source-frame source-bbox source-ename))
  (setq source-frame-ename (car source-frame))
  (setq source-frame-bbox (caddr source-frame))
  (swt-2-line log (list "SHEET1" (swcad-title-bbox-string source-bbox) (swcad-title-bbox-string source-frame-bbox)))
  (setq t-in (swt-2-line-ent (list (+ (car source-bbox) 60.0) (+ (cadr source-bbox) 10.0) 0.0) (list (+ (car source-bbox) 110.0) (+ (cadr source-bbox) 10.0) 0.0) "0" nil))
  (setq t-cross (swt-2-line-ent (list (+ (car source-bbox) 70.0) (+ (cadr source-bbox) 30.0) 0.0) (list (+ (car source-bbox) 70.0) (+ (cadr source-bbox) 140.0) 0.0) "0" nil))
  (setq t-solid (swt-2-solid-ent (- (car source-bbox) 30.0) (+ (cadr source-bbox) 20.0) (+ (car source-bbox) 30.0) (+ (cadr source-bbox) 90.0) "0"))
  (setq t-margin (swt-2-solid-ent (+ (caddr source-bbox) 1.0) (+ (cadr source-bbox) 10.0) (- (caddr source-frame-bbox) 1.0) (+ (cadr source-bbox) 30.0) "0"))
  (setq t-paper (vlax-vla-object->ename (vla-AddLine (vla-get-PaperSpace doc) (vlax-3d-point (list (+ (car source-bbox) 60.0) (+ (cadr source-bbox) 20.0) 0.0)) (vlax-3d-point (list (+ (car source-bbox) 110.0) (+ (cadr source-bbox) 20.0) 0.0)))))
  (swt-2-line log (list "PAPER_SPACE_OF_TEST_LINE" (cdr (assoc 410 (entget t-paper)))))
  (setq new
    (swcad-title-source-title-graphic-handles
      source-bbox
      source-frame-bbox
      (swcad-title-sheet-space source-ename source-frame-ename)
    )
  )
  (swt-2-check log "title-line-inside" (swt-2-member-p (swcad-title-ename-handle t-in) new) "selected")
  (swt-2-check log "drawing-line-crossing-title" (swt-2-member-p (swcad-title-ename-handle t-cross) new) "kept")
  (swt-2-check log "drawing-solid-overlapping-title" (swt-2-member-p (swcad-title-ename-handle t-solid) new) "kept")
  (swt-2-check log "margin-solid-touching-title" (swt-2-member-p (swcad-title-ename-handle t-margin) new) "selected")
  (swt-2-check log "paper-space-line-at-title" (swt-2-member-p (swcad-title-ename-handle t-paper) new) "kept")
  (setq paper-text
    (progn
      (vlax-vla-object->ename (vla-AddText (vla-get-PaperSpace doc) "PAPER-TEXT" (vlax-3d-point (list (+ (car source-bbox) 60.0) (+ (cadr source-bbox) 25.0) 0.0)) 3.0))
    )
  )
  (setq texts (swcad-title-transfer-text-records source-bbox source-ename))
  (swt-2-check log "paper-space-text-not-a-title-text"
    (if (vl-some '(lambda (r) (equal (strcase (swcad-title-string (nth 3 r))) (swcad-title-ename-handle paper-text))) texts) "found" "ignored")
    "ignored"
  )
  (setq synthetic (mapcar 'swcad-title-ename-handle (list t-in t-cross t-solid t-margin t-paper)))

  ;; 4. Real data: new rule versus the previous rule for every sheet (synthetic
  ;;    entities excluded). Only the synthetic ones on sheet 1 may differ.
  (setq index 0)
  (setq diffs 0)
  (foreach item records
    (setq index (1+ index))
    (setq source (car item))
    (setq source-ename (car source))
    (setq source-bbox (caddr source))
    (setq source-block (if source-ename (swcad-title-effective-insert-name source-ename) ""))
    (setq source-frame (swcad-title-transfer-source-frame source-bbox source-ename))
    (setq source-frame-ename (car source-frame))
    (setq source-frame-bbox (caddr source-frame))
    (setq source-frame-block (if source-frame-ename (swcad-title-effective-insert-name source-frame-ename) nil))
    (setq build (swcad-title-transfer-build-mappings source-bbox source-ename 7.0))
    (setq values (swcad-title-transfer-values (car build)))
    (setq block-sheet (swcad-title-source-block-sheet-size source-block source-frame-block))
    (setq values (swcad-title-values-with-sheet-size-override values block-sheet))
    (setq inferred (swcad-title-effective-source-frame-bbox source-bbox source-frame-bbox values block-sheet))
    (setq new (swcad-title-source-title-graphic-handles source-bbox inferred (swcad-title-sheet-space source-ename source-frame-ename)))
    (setq old (swt-2-old-title-graphics source-bbox))
    (foreach h old
      (if (and (not (member h new)) (not (member h synthetic)))
        (progn (setq diffs (1+ diffs)) (swt-2-line log (list "SHEETDIFF" (itoa index) "old-only" h)))
      )
    )
    (foreach h new
      (if (and (not (member h old)) (not (member h synthetic)))
        (progn (setq diffs (1+ diffs)) (swt-2-line log (list "SHEETDIFF" (itoa index) "new-only" h)))
      )
    )
    (swt-2-line log (list "SHEET" (itoa index) (itoa (length old)) (itoa (length new))))
  )
  (swt-2-check log "real-sheets-old-vs-new-differences" diffs 0)

  ;; 5. Real transfer on sheet 2: one old title line on a locked layer stops the
  ;;    transfer before GMTITLE, and nothing is deleted (Codex review of PR #4).
  ;;    This copy is outside work\, so the work-copy check answers yes here.
  (setq item (cadr records))
  (setq source (car item))
  (setq source-ename (car source))
  (setq source-bbox (caddr source))
  (setq source-block (if source-ename (swcad-title-effective-insert-name source-ename) ""))
  (setq source-frame (swcad-title-transfer-source-frame source-bbox source-ename))
  (setq source-frame-ename (car source-frame))
  (setq source-frame-bbox (caddr source-frame))
  (setq source-frame-block (if source-frame-ename (swcad-title-effective-insert-name source-frame-ename) nil))
  (setq build (swcad-title-transfer-build-mappings source-bbox source-ename 7.0))
  (setq values (swcad-title-transfer-values (car build)))
  (setq block-sheet (swcad-title-source-block-sheet-size source-block source-frame-block))
  (setq values (swcad-title-values-with-sheet-size-override values block-sheet))
  (setq inferred (swcad-title-effective-source-frame-bbox source-bbox source-frame-bbox values block-sheet))
  (setq new (swcad-title-source-title-graphic-handles source-bbox inferred (swcad-title-sheet-space source-ename source-frame-ename)))
  (swt-2-line log (list "SHEET2_TITLE_LINES" (itoa (length new))))
  (setq e (handent (car new)))
  (vla-put-Lock layer :vlax-false)
  (entmod (subst (cons 8 "SWT_LOCKED_TEST") (assoc 8 (entget e)) (entget e)))
  (vla-put-Lock layer :vlax-true)
  (defun swt-2-fake-true (/) T)
  (setq r swcad-title-apply-work-copy-confirmed-p)
  (setq swcad-title-apply-work-copy-confirmed-p swt-2-fake-true)
  (setq *swcad-title-batch-mode* T)
  (setq *swcad-title-batch-source-record* source)
  (setq *swcad-title-batch-frame-record* (cadr item))
  (setq old (vl-catch-all-apply 'swcad-title-transfer-apply nil))
  (setq *swcad-title-batch-mode* nil)
  (setq *swcad-title-batch-source-record* nil)
  (setq *swcad-title-batch-frame-record* nil)
  (setq swcad-title-apply-work-copy-confirmed-p r)
  (swt-2-check log "transfer-locked-title-line-no-error" (vl-catch-all-error-p old) nil)
  (swt-2-check log "transfer-locked-title-line-status" *swcad-title-last-apply-status* "ABORT_SOURCE_ON_LOCKED_LAYER")
  (swt-2-check log "transfer-locked-source-title-kept" (if (or (not source-ename) (entget source-ename)) T nil) T)
  (swt-2-check
    log
    "transfer-locked-all-title-lines-kept"
    (length (vl-remove-if-not '(lambda (h) (entget (handent h))) new))
    (length new)
  )
  (write-line "Step2 unit probe completed: yes" log)
  (close log)
  (princ)
)

(swt-2-main)
