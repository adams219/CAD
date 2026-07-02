;;; Read-only title-block and scale diagnostic module.
;;;
;;; Standalone test workflow:
;;;   APPLOAD this file directly, then run SWTITLEDEBUG, SWTITLESCAN,
;;;   SWTITLETEXTSCAN, SWTITLEMULTIPREVIEW, SWTITLETRANSFERPREVIEW,
;;;   SWTITLEFASTSTATUS, SWTITLETRANSFERAPPLY,
;;;   SWTITLETRANSFERBOOTSTRAPFAST, SWTITLETRANSFERBATCH, or SWSCALESCAN.
;;;
;;; SWTITLEDEBUG prints raw information from a selected GM TITLE / FTAP
;;; candidate object. It does not modify the drawing.
;;; SWTITLETEXTSCAN lists title-block attributes and loose TEXT/MTEXT
;;; found in title-block bounds. It does not modify the drawing.
;;; SWTITLETRANSFERPREVIEW maps loose title-block text to GM TITLE
;;; attribute tags. It does not modify the drawing.
;;; SWTITLEMULTIPREVIEW lists every detected SOLIDWORKS title/frame
;;; candidate in model space. It does not modify the drawing.
;;; SWTITLETRANSFERAPPLY extracts old loose/block title text, runs native
;;; GMTITLE for the user to place a real DR frame/title, fills its
;;; attributes, then removes the selected old SOLIDWORKS title content.
;;; SWTITLETRANSFERCLONEBATCH reuses one verified native GMTITLE pair in
;;; the current work-copy drawing to finish remaining sheets without
;;; reopening the fragile GMTITLE picker for every sheet.
;;; SWTITLEFASTSTATUS checks whether the current drawing is ready for the
;;; fast remaining-sheet batch and records sheet counts by A-size.
;;; SWTITLETRANSFERFASTBATCH runs the title clone batch and the frame-only
;;; clone batch together for every remaining detected source sheet.
;;; SWTITLETRANSFERBOOTSTRAPFAST creates/finalizes the first native GMTITLE
;;; exemplar when needed, then continues with the fast batch phases. The
;;; first native picker is still a GstarCAD dialog step; command-line and
;;; UI-automation selection are not reliable enough yet.
;;; SWTITLEFRAMEONLYFINALIZE moves one already-created native GMTITLE
;;; frame/title onto a detected frame-only sheet such as A4, then removes
;;; the old source frame/residue. SWTITLEFRAMEONLYCLONEBATCH is the faster
;;; cloned variant for repeated frame-only sheets.
;;; SWTITLEFRAMEDEFCHECK diagnoses polluted target DR_A*_Outline block
;;; definitions. SWTITLEFRAMEDEFCLEANSAFE repairs only unused polluted
;;; definitions by backing them up and importing a clean install copy.
;;; SWTITLEREPAIRFRAMEDEFS rebuilds referenced target frame definitions
;;; whose visible bbox no longer matches the expected A-size geometry.
;;; Verifiers also warn when the raw CAD selection bbox is much larger
;;; than the effective visible frame, because that can make GMPOWEREDIT
;;; or double-click hit the frame/block instead of the title editor.
;;; SWTITLEGMTITLELINKDETAIL dumps raw native-link target objects so the
;;; internal GMTITLE recognition handle can be compared with visible clones.
;;; SWTITLEGMTITLECOMPARE prints one internal/native title and one
;;; visible-frame-linked clone side by side for A3 recognition debugging.
;;; SWTITLEGMTITLEPRESERVECOPYTEST copies one real native GMTITLE frame/title
;;; pair without relinking it to the visible frame, for recognition testing.
;;; Fast clone phases now require a real native exemplar whose GMTITLE link
;;; targets an internal recognition handle, not a visible cloned frame insert.
;;; Verifiers warn when multiple title blocks share one internal GMTITLE link,
;;; because that preserve-copy pattern can still fail GMPOWEREDIT.
;;; SWTITLEUPGRADENATIVEONE replaces one A3/A4 native-recheck or cloned GMTITLE
;;; pair with a fresh native GMTITLE pair so double-click behavior can be tested
;;; against true GMTITLE output.
;;; SWTITLEUPGRADENATIVESELECT does the same for the cloned or target
;;; frame/title pair selected by the user.
;;; SWTITLEA3A4PREP/SWTITLEA3A4FINISH replace the next A3/A4 clone or
;;; native-recheck candidate with a manually created real GMTITLE pair.
;;; SWTITLENEXTSTEP is a read-only guide that inspects the current drawing and
;;; prints the next safest command in the conversion sequence.
;;; SWTITLEVERSION prints the currently loaded LSP version so stale CAD loads
;;; are easy to spot before trusting status logs.
;;; SWTITLESTATUSREFRESH reruns the main read-only status commands and refreshes
;;; their work-folder logs without modifying the drawing.
;;; SWTITLEUPGRADENATIVEBATCH repeats that native upgrade for remaining clone
;;; pairs. SWTITLEUPGRADENATIVEA3A4BATCH defaults to every listed A3/A4
;;; candidate and is retained as a diagnostic path. Current safer one-sheet
;;; work uses SWTITLEA3A4PREP, a normal GMTITLE command, then SWTITLEA3A4FINISH.
;;; SWTITLEUPGRADENATIVEA3A4ALL is kept as an explicit all-candidate alias.
;;; SWTITLEPICKCHECK is a read-only helper for checking whether the user
;;; clicked the editable GMTITLE title block or the frame INSERT.
;;; SWSCALESCAN compares title-block scale candidates with dimension
;;; DIMLFAC values. It does not modify the drawing.

(vl-load-com)

(setq *swcad-title-scale-version* "260702-a3a4-manual-native-finish-1")
(setq *swcad-title-scale-loaded* T)
(setq *swcad-title-debug-log-path* nil)
(setq *swcad-title-debug-log-handle* nil)
(setq *swcad-title-batch-mode* nil)
(setq *swcad-title-last-apply-status* nil)
(setq *swcad-title-last-clone-failure* nil)
(setq *swcad-title-last-native-gmtitle-abort-reason* nil)
(setq *swcad-title-last-native-gmtitle-placement-used* nil)
(setq *swcad-title-allow-script-commandline-gmtitle* nil)
(setq *swcad-title-exemplar-xdata-app* "SWTITLE_EXEMPLAR")
(setq *swcad-title-exemplar-xdata-marker* "SWTITLE_NATIVE_EXEMPLAR")
(setq *swcad-title-pending-native-title-ename* nil)
(setq *swcad-title-pending-native-frame-ename* nil)
(setq *swcad-title-pending-native-frame-block* nil)
(setq *swcad-title-pending-gmtitle-role* nil)
(setq *swcad-title-native-upgrade-batch-mode* nil)
(setq *swcad-title-native-upgrade-selected-pair* nil)
(setq *swcad-title-allow-batch-interactive-native-gmtitle* nil)
(setq *swcad-title-skip-native-upgrade-confirmation* nil)
(setq *swcad-title-a3a4-batch-default-all* nil)
(setq *swcad-title-pending-manual-native-upgrade* nil)
(setq *swcad-title-target-frame-block-name* "DR_A3_Outline")
(setq *swcad-title-target-title-block-name* "DR_titlea_3rd")

(defun swcad-title-princ-line (text)
  (princ (strcat "\n" text))
  (if *swcad-title-debug-log-handle*
    (write-line text *swcad-title-debug-log-handle*)
  )
)

(defun swcad-title-log-line (text)
  (if *swcad-title-debug-log-handle*
    (write-line text *swcad-title-debug-log-handle*)
  )
)

(defun swcad-title-debug-log-path (/ home)
  (swcad-title-work-log-path "swcad_title_debug_last.txt")
)

(defun swcad-title-work-log-path (filename / home)
  (setq home (getenv "USERPROFILE"))
  (if home
    (strcat
      (vl-string-translate "\\" "/" home)
      "/Documents/CAD tool/work/"
      filename
    )
    filename
  )
)

(defun swcad-title-work-root-path (/ home)
  (setq home (getenv "USERPROFILE"))
  (if home
    (strcat
      (vl-string-translate "\\" "/" home)
      "/Documents/CAD tool/work/"
    )
    ""
  )
)

(defun swcad-title-current-dwg-full-path ()
  (vl-string-translate "\\" "/" (strcat (getvar "DWGPREFIX") (getvar "DWGNAME")))
)

(defun swcad-title-string-prefix-p (prefix value)
  (and
    prefix
    value
    (<= (strlen prefix) (strlen value))
    (equal
      (strcase prefix)
      (strcase (substr value 1 (strlen prefix)))
    )
  )
)

(defun swcad-title-current-dwg-in-work-p ()
  (swcad-title-string-prefix-p
    (swcad-title-work-root-path)
    (swcad-title-current-dwg-full-path)
  )
)

(defun swcad-title-print-work-copy-status ()
  (swcad-title-princ-line
    (strcat
      "Work-folder test copy: "
      (if (swcad-title-current-dwg-in-work-p) "yes" "no")
    )
  )
)

(defun swcad-title-print-loaded-version ()
  (swcad-title-princ-line
    (strcat
      "SWTITLE LSP version: "
      (swcad-title-string *swcad-title-scale-version*)
    )
  )
)

(defun swcad-title-apply-work-copy-confirmed-p (/ answer)
  (if (swcad-title-current-dwg-in-work-p)
    T
    (progn
      (swcad-title-princ-line "WARNING: current DWG is outside the work test folder.")
      (swcad-title-princ-line "No SOLIDWORKS title/frame content will be removed unless you explicitly confirm this non-work file.")
      (setq answer
        (getstring
          T
          "\nCurrent DWG is outside work. Type EDIT to continue, or press Enter to abort: "
        )
      )
      (equal (strcase answer) "EDIT")
    )
  )
)

(defun swcad-title-open-log (filename header / handle path)
  (setq path (swcad-title-work-log-path filename))
  (setq handle (open path "w"))
  (setq *swcad-title-debug-log-path* path)
  (setq *swcad-title-debug-log-handle* handle)
  (if handle
    (write-line header handle)
  )
)

(defun swcad-title-open-debug-log ()
  (swcad-title-open-log "swcad_title_debug_last.txt" "SWTITLEDEBUG log")
)

(defun swcad-title-open-scan-log ()
  (swcad-title-open-log "swcad_title_scan_last.txt" "SWTITLESCAN log")
)

(defun swcad-title-open-scale-log ()
  (swcad-title-open-log "swcad_scale_scan_last.txt" "SWSCALESCAN log")
)

(defun swcad-title-open-text-log ()
  (swcad-title-open-log "swcad_title_text_scan_last.txt" "SWTITLETEXTSCAN log")
)

(defun swcad-title-open-command-text-log ()
  (swcad-title-open-log "swcad_title_command_text_scan_last.txt" "SWTITLECOMMANDTEXTSCAN log")
)

(defun swcad-title-open-transfer-log ()
  (swcad-title-open-log "swcad_title_transfer_preview_last.txt" "SWTITLETRANSFERPREVIEW log")
)

(defun swcad-title-open-multi-preview-log ()
  (swcad-title-open-log "swcad_title_multi_preview_last.txt" "SWTITLEMULTIPREVIEW log")
)

(defun swcad-title-open-multi-detail-log ()
  (swcad-title-open-log "swcad_title_multi_detail_last.txt" "SWTITLEMULTIDETAIL log")
)

(defun swcad-title-open-frame-scan-log ()
  (swcad-title-open-log "swcad_title_frame_scan_last.txt" "SWTITLEFRAMESCAN log")
)

(defun swcad-title-open-apply-log ()
  (swcad-title-open-log "swcad_title_transfer_apply_last.txt" "SWTITLETRANSFERAPPLY log")
)

(defun swcad-title-apply-result (status)
  (setq *swcad-title-last-apply-status* status)
  (swcad-title-princ-line (strcat "Result: " status))
)

(defun swcad-title-open-gmtitle-verify-log ()
  (swcad-title-open-log "swcad_title_gmtitle_verify_last.txt" "SWTITLEGMTITLEVERIFY log")
)

(defun swcad-title-open-gmtitle-verify-all-log ()
  (swcad-title-open-log "swcad_title_gmtitle_verify_all_last.txt" "SWTITLEGMTITLEVERIFYALL log")
)

(defun swcad-title-open-gmtitle-link-scan-log ()
  (swcad-title-open-log "swcad_title_gmtitle_link_scan_last.txt" "SWTITLEGMTITLELINKSCAN log")
)

(defun swcad-title-open-gmtitle-link-detail-log ()
  (swcad-title-open-log "swcad_title_gmtitle_link_detail_last.txt" "SWTITLEGMTITLELINKDETAIL log")
)

(defun swcad-title-open-gmtitle-compare-log ()
  (swcad-title-open-log "swcad_title_gmtitle_compare_last.txt" "SWTITLEGMTITLECOMPARE log")
)

(defun swcad-title-open-gmtitle-preserve-copy-test-log ()
  (swcad-title-open-log "swcad_title_gmtitle_preserve_copy_test_last.txt" "SWTITLEGMTITLEPRESERVECOPYTEST log")
)

(defun swcad-title-open-native-upgrade-log ()
  (swcad-title-open-log "swcad_title_native_upgrade_last.txt" "SWTITLEUPGRADENATIVE log")
)

(defun swcad-title-open-native-frame-check-log ()
  (swcad-title-open-log "swcad_title_native_frame_check_last.txt" "SWTITLENATIVEFRAMECHECK log")
)

(defun swcad-title-open-pick-check-log ()
  (swcad-title-open-log "swcad_title_pick_check_last.txt" "SWTITLEPICKCHECK log")
)

(defun swcad-title-open-double-click-check-log ()
  (swcad-title-open-log "swcad_title_double_click_check_last.txt" "SWTITLEDOUBLECLICKCHECK log")
)

(defun swcad-title-open-role-check-log ()
  (swcad-title-open-log "swcad_title_role_check_last.txt" "SWTITLEROLECHECK log")
)

(defun swcad-title-open-frame-def-check-log ()
  (swcad-title-open-log "swcad_title_frame_def_check_last.txt" "SWTITLEFRAMEDEFCHECK log")
)

(defun swcad-title-open-frame-def-clean-log ()
  (swcad-title-open-log "swcad_title_frame_def_clean_last.txt" "SWTITLEFRAMEDEFCLEANSAFE log")
)

(defun swcad-title-open-frame-def-repair-log ()
  (swcad-title-open-log "swcad_title_frame_def_repair_last.txt" "SWTITLEREPAIRFRAMEDEFS log")
)

(defun swcad-title-open-fast-status-log ()
  (swcad-title-open-log "swcad_title_fast_status_last.txt" "SWTITLEFASTSTATUS log")
)

(defun swcad-title-open-next-step-log ()
  (swcad-title-open-log "swcad_title_next_step_last.txt" "SWTITLENEXTSTEP log")
)

(defun swcad-title-open-status-refresh-log ()
  (swcad-title-open-log "swcad_title_status_refresh_last.txt" "SWTITLESTATUSREFRESH log")
)

(defun swcad-title-open-a3a4-fix-plan-log ()
  (swcad-title-open-log "swcad_title_a3a4_fix_plan_last.txt" "SWTITLEA3A4FIXPLAN log")
)

(defun swcad-title-close-log ()
  (if *swcad-title-debug-log-handle*
    (progn
      (close *swcad-title-debug-log-handle*)
      (setq *swcad-title-debug-log-handle* nil)
    )
  )
  (if *swcad-title-debug-log-path*
    (princ (strcat "\nSWTITLE log: " *swcad-title-debug-log-path*))
  )
)

(defun swcad-title-string (value)
  (cond
    ((= (type value) 'STR) value)
    ((not value) "")
    (T (vl-princ-to-string value))
  )
)

(defun swcad-title-code-value-line (prefix pair)
  (swcad-title-princ-line
    (strcat
      prefix
      " "
      (swcad-title-string (car pair))
      " = "
      (swcad-title-string (cdr pair))
    )
  )
)

(defun swcad-title-dxf-value (data code)
  (cdr (assoc code data))
)

(defun swcad-title-list-add-unique (value values)
  (if (member value values)
    values
    (append values (list value))
  )
)

(defun swcad-title-string-p (value / typ typtext)
  (setq typ (type value))
  (setq typtext (strcase (vl-princ-to-string typ)))
  (or
    (equal typ 'STR)
    (equal typ "STR")
    (equal typtext "STR")
    (equal typtext "'STR")
    (equal typ 'STRING)
    (equal typ "STRING")
    (equal typtext "STRING")
    (equal typtext "'STRING")
  )
)

(defun swcad-title-safe-string (value)
  (if (swcad-title-string-p value) value nil)
)

(defun swcad-title-number-string (value)
  (if (numberp value)
    (rtos (float value) 2 8)
    (swcad-title-string value)
  )
)

(defun swcad-title-list-string (values / result item)
  (setq result "")
  (foreach item values
    (setq result
      (if (= result "")
        (swcad-title-string item)
        (strcat result ", " (swcad-title-string item))
      )
    )
  )
  (if (= result "") "<none>" result)
)

(defun swcad-title-number-list-string (values / result item)
  (setq result "")
  (foreach item values
    (setq result
      (if (= result "")
        (swcad-title-number-string item)
        (strcat result ", " (swcad-title-number-string item))
      )
    )
  )
  (if (= result "") "<none>" result)
)

(defun swcad-title-float-in-list-p (value values / found item)
  (setq found nil)
  (if (numberp value)
    (foreach item values
      (if (and (numberp item) (equal (float value) (float item) 1e-8))
        (setq found T)
      )
    )
  )
  found
)

(defun swcad-title-list-add-unique-float (value values)
  (if (swcad-title-float-in-list-p value values)
    values
    (append values (list (float value)))
  )
)

(defun swcad-title-count-add (key counts / pair result found)
  (setq result nil)
  (setq found nil)
  (foreach pair counts
    (if (equal key (car pair))
      (progn
        (setq result (append result (list (cons key (+ (cdr pair) 1)))))
        (setq found T)
      )
      (setq result (append result (list pair)))
    )
  )
  (if found
    result
    (append result (list (cons key 1)))
  )
)

(defun swcad-title-print-counts (title counts / pair)
  (swcad-title-princ-line title)
  (if counts
    (foreach pair counts
      (swcad-title-princ-line
        (strcat
          "  "
          (swcad-title-string (car pair))
          " x "
          (itoa (cdr pair))
        )
      )
    )
    (swcad-title-princ-line "  <none>")
  )
)

(defun swcad-title-point-string (point)
  (if (and (listp point) (>= (length point) 2))
    (strcat
      "("
      (swcad-title-number-string (car point))
      ", "
      (swcad-title-number-string (cadr point))
      (if (caddr point)
        (strcat ", " (swcad-title-number-string (caddr point)))
        ""
      )
      ")"
    )
    (swcad-title-string point)
  )
)

(defun swcad-title-insert-transform-string (ename / data ins sx sy sz rot)
  (setq data (if ename (entget ename) nil))
  (setq ins (swcad-title-dxf-value data 10))
  (setq sx (swcad-title-dxf-value data 41))
  (setq sy (swcad-title-dxf-value data 42))
  (setq sz (swcad-title-dxf-value data 43))
  (setq rot (swcad-title-dxf-value data 50))
  (strcat
    "insert-point="
    (swcad-title-point-string ins)
    ", scale=("
    (swcad-title-number-string (if sx sx 1.0))
    ", "
    (swcad-title-number-string (if sy sy 1.0))
    ", "
    (swcad-title-number-string (if sz sz 1.0))
    ")"
    ", rotation="
    (swcad-title-number-string (if rot rot 0.0))
  )
)

(defun swcad-title-bbox-string (bbox)
  (if (and (listp bbox) (= (length bbox) 4))
    (strcat
      "("
      (swcad-title-number-string (car bbox))
      ", "
      (swcad-title-number-string (cadr bbox))
      ") - ("
      (swcad-title-number-string (caddr bbox))
      ", "
      (swcad-title-number-string (cadddr bbox))
      ")"
    )
    "<none>"
  )
)

(defun swcad-title-bbox-lower-left-point (bbox)
  (if (and (listp bbox) (= (length bbox) 4))
    (list (car bbox) (cadr bbox) 0.0)
    nil
  )
)

(defun swcad-title-safe-getvar (name / result)
  (setq result (vl-catch-all-apply 'getvar (list name)))
  (if (vl-catch-all-error-p result)
    nil
    result
  )
)

(defun swcad-title-safe-setvar (name value / result)
  (if value
    (progn
      (setq result (vl-catch-all-apply 'setvar (list name value)))
      (not (vl-catch-all-error-p result))
    )
    nil
  )
)

(defun swcad-title-restore-gmtitle-input-vars (old-osmode old-dynmode)
  (if old-osmode
    (swcad-title-safe-setvar "OSMODE" old-osmode)
  )
  (if old-dynmode
    (swcad-title-safe-setvar "DYNMODE" old-dynmode)
  )
)

(defun swcad-title-command-prompt-string (/ result)
  (setq result (vl-catch-all-apply 'getvar (list "LASTPROMPT")))
  (if (vl-catch-all-error-p result)
    ""
    (swcad-title-string result)
  )
)

(defun swcad-title-gmtitle-placement-prompt-p (prompt / upper)
  (setq upper (strcase (swcad-title-string prompt)))
  (or
    (wcmatch upper "*INSERT*POINT*")
    (wcmatch upper "*INSERTION*POINT*")
    (wcmatch upper "*삽입*지정*")
    (wcmatch upper "*삽입*점*")
    (wcmatch upper "*삽입점*")
  )
)

(defun swcad-title-gmtitle-object-move-prompt-p (prompt / upper)
  (setq upper (strcase (swcad-title-string prompt)))
  (or
    (wcmatch upper "*OBJECT*NEW*LOCATION*")
    (wcmatch upper "*OBJECT*LOCATION*")
    (wcmatch upper "*NEW*LOCATION*")
    (wcmatch upper "*OBJECT*MOVE*")
    (wcmatch upper "*객체*새*위치*")
    (wcmatch upper "*객체*위치*")
    (wcmatch upper "*새*위치*")
  )
)

(defun swcad-title-cancel-active-command (/ result count ok)
  (setq count 0)
  (setq ok nil)
  (while (and (> (getvar "CMDACTIVE") 0) (< count 3))
    (setq result (vl-catch-all-apply 'command (list "\033")))
    (if (vl-catch-all-error-p result)
      (setq result (vl-catch-all-apply 'command nil))
    )
    (if (not (vl-catch-all-error-p result))
      (setq ok T)
    )
    (setq count (+ count 1))
  )
  ok
)

(defun swcad-title-safe-bbox (ename / object result minpt maxpt minlist maxlist)
  (setq object (swcad-title-safe-vla-object ename))
  (if object
    (progn
      (setq result (vl-catch-all-apply 'vla-GetBoundingBox (list object 'minpt 'maxpt)))
      (if (vl-catch-all-error-p result)
        nil
        (progn
          (setq minlist (vlax-safearray->list minpt))
          (setq maxlist (vlax-safearray->list maxpt))
          (list (car minlist) (cadr minlist) (car maxlist) (cadr maxlist))
        )
      )
    )
    nil
  )
)

(defun swcad-title-expand-bbox (bbox margin)
  (if bbox
    (list
      (- (car bbox) margin)
      (- (cadr bbox) margin)
      (+ (caddr bbox) margin)
      (+ (cadddr bbox) margin)
    )
    nil
  )
)

(defun swcad-title-point-in-bbox-p (point bbox)
  (and
    point
    bbox
    (>= (car point) (car bbox))
    (<= (car point) (caddr bbox))
    (>= (cadr point) (cadr bbox))
    (<= (cadr point) (cadddr bbox))
  )
)

(defun swcad-title-point-in-bboxes-p (point bboxes / found bbox)
  (setq found nil)
  (foreach bbox bboxes
    (if (swcad-title-point-in-bbox-p point bbox)
      (setq found T)
    )
  )
  found
)

(defun swcad-title-safe-trans-point (point from-code to-code / result)
  (if point
    (progn
      (setq result (vl-catch-all-apply 'trans (list point from-code to-code)))
      (if (vl-catch-all-error-p result)
        nil
        result
      )
    )
    nil
  )
)

(defun swcad-title-point-in-expanded-bbox-flex-p (point bbox margin / expanded world-point)
  (setq expanded (swcad-title-expand-bbox bbox margin))
  (setq world-point (swcad-title-safe-trans-point point 1 0))
  (or
    (swcad-title-point-in-bbox-p point expanded)
    (swcad-title-point-in-bbox-p world-point expanded)
  )
)

(defun swcad-title-bbox-area (bbox)
  (if bbox
    (* (- (caddr bbox) (car bbox)) (- (cadddr bbox) (cadr bbox)))
    0.0
  )
)

(defun swcad-title-bbox-width (bbox)
  (if bbox
    (- (caddr bbox) (car bbox))
    0.0
  )
)

(defun swcad-title-bbox-height (bbox)
  (if bbox
    (- (cadddr bbox) (cadr bbox))
    0.0
  )
)

(defun swcad-title-abs (value)
  (if (< value 0.0)
    (- 0.0 value)
    value
  )
)

(defun swcad-title-near-p (a b tolerance)
  (<= (swcad-title-abs (- (float a) (float b))) tolerance)
)

(defun swcad-title-bbox-intersects-p (a b)
  (and
    a
    b
    (<= (car a) (caddr b))
    (>= (caddr a) (car b))
    (<= (cadr a) (cadddr b))
    (>= (cadddr a) (cadr b))
  )
)

(defun swcad-title-bbox-overlap-box (a b / left bottom right top)
  (if (and a b)
    (progn
      (setq left (max (car a) (car b)))
      (setq bottom (max (cadr a) (cadr b)))
      (setq right (min (caddr a) (caddr b)))
      (setq top (min (cadddr a) (cadddr b)))
      (if (and (> (- right left) 1.0) (> (- top bottom) 1.0))
        (list left bottom right top)
        nil
      )
    )
    nil
  )
)

(defun swcad-title-bbox-contains-bbox-p (outer inner margin)
  (and
    outer
    inner
    (<= (- (car outer) margin) (car inner))
    (<= (- (cadr outer) margin) (cadr inner))
    (>= (+ (caddr outer) margin) (caddr inner))
    (>= (+ (cadddr outer) margin) (cadddr inner))
  )
)

(setq *swcad-title-transfer-template*
  '(
    ("GEN-TITLE-QTY{10}" 25.75 37.50 "quantity")
    ("GEN-TITLE-MAT1{10}" 32.81333128 37.60265511 "material")
    ("GEN-TITLE-NAME{10}" 6.00361982 21.70382822 "name")
    ("GEN-TITLE-CHKM{10}" 35.81333128 21.60265511 "checked")
    ("GEN-TITLE-APPM{21.7}" 64.86238219 21.70382822 "approved")
    ("GEN-TITLE-DATE{11.7}" 93.48807325 21.53210663 "date")
    ("GEN-TITLE-SCA{6.7}" 163.48807325 21.53210663 "scale")
    ("GEN-TITLE-DWG{23}" 56.00 12.50 "drawing")
    ("GEN-TITLE-NR{23}" 56.00 2.70 "drawing-number")
    ("GEN-TITLE-REV{5}" 148.48807325 1.53210663 "revision")
    ("GEN-TITLE-SIZ{6.7}" 163.48807325 1.53210663 "sheet-size")
  )
)

(defun swcad-title-distance2 (x1 y1 x2 y2 / dx dy)
  (setq dx (- x1 x2))
  (setq dy (- y1 y2))
  (+ (* dx dx) (* dy dy))
)

(defun swcad-title-transfer-best-slot (point bbox / relx rely best bestdist dist slot)
  (setq best nil)
  (setq bestdist nil)
  (if (and point bbox)
    (progn
      (setq relx (- (car point) (car bbox)))
      (setq rely (- (cadr point) (cadr bbox)))
      (foreach slot *swcad-title-transfer-template*
        (setq dist (swcad-title-distance2 relx rely (cadr slot) (caddr slot)))
        (if (or (not bestdist) (< dist bestdist))
          (progn
            (setq best slot)
            (setq bestdist dist)
          )
        )
      )
      (if best
        (list best (sqrt bestdist) relx rely)
        nil
      )
    )
    nil
  )
)

(defun swcad-title-assoc-put (key value alist / result found pair)
  (setq result nil)
  (setq found nil)
  (foreach pair alist
    (if (equal key (car pair))
      (progn
        (setq result (append result (list (cons key value))))
        (setq found T)
      )
      (setq result (append result (list pair)))
    )
  )
  (if found
    result
    (append result (list (cons key value)))
  )
)

(defun swcad-title-doc ()
  (vla-get-ActiveDocument (vlax-get-acad-object))
)

(defun swcad-title-modelspace ()
  (vla-get-ModelSpace (swcad-title-doc))
)

(defun swcad-title-document-read-only-p (/ doc value)
  (setq doc (swcad-title-doc))
  (setq value (swcad-title-safe-vla-get doc 'ReadOnly))
  (cond
    ((not value) nil)
    ((equal value :vlax-false) nil)
    ((equal value 0) nil)
    (T T)
  )
)

(defun swcad-title-block-exists-p (block-name)
  (if (tblsearch "BLOCK" block-name) T nil)
)

(defun swcad-title-find-block-by-pattern (pattern / item name upper result)
  (setq result nil)
  (setq item (tblnext "BLOCK" T))
  (while (and item (not result))
    (setq name (cdr (assoc 2 item)))
    (setq upper (strcase (swcad-title-string name)))
    (if (and
          name
          (/= (substr name 1 1) "*")
          (wcmatch upper pattern)
        )
      (setq result name)
    )
    (setq item (tblnext "BLOCK"))
  )
  result
)

(defun swcad-title-target-frame-block-name ()
  *swcad-title-target-frame-block-name*
)

(defun swcad-title-target-frame-block-candidates ()
  '("DR_A1_Outline" "DR_A2_Outline" "DR_A3_Outline" "DR_A4_Outline")
)

(defun swcad-title-existing-target-frame-block-name (/ result candidate)
  (setq result nil)
  (foreach candidate (swcad-title-target-frame-block-candidates)
    (if (and (not result) (> (swcad-title-count-inserts-by-effective-name candidate) 0))
      (setq result candidate)
    )
  )
  result
)

(defun swcad-title-target-title-block-name ()
  *swcad-title-target-title-block-name*
)

(defun swcad-title-vla-block-name (object / name)
  (setq name (swcad-title-safe-vla-get object 'EffectiveName))
  (if (not name)
    (setq name (swcad-title-safe-vla-get object 'Name))
  )
  (swcad-title-string name)
)

(defun swcad-title-attribute-tag (attribute / value)
  (setq value (vl-catch-all-apply 'vla-get-TagString (list attribute)))
  (if (vl-catch-all-error-p value) "" value)
)

(defun swcad-title-attribute-set-value (attribute value)
  (vl-catch-all-apply 'vla-put-TextString (list attribute (swcad-title-string value)))
)

(defun swcad-title-get-insert-attributes (insert-object / result)
  (setq result (vl-catch-all-apply 'vlax-invoke (list insert-object 'GetAttributes)))
  (if (vl-catch-all-error-p result)
    nil
    result
  )
)

(defun swcad-title-set-insert-attributes (insert-object values / attrs attr tag pair count)
  (setq attrs (swcad-title-get-insert-attributes insert-object))
  (setq count 0)
  (foreach attr attrs
    (setq tag (swcad-title-attribute-tag attr))
    (setq pair (assoc tag values))
    (if pair
      (progn
        (swcad-title-attribute-set-value attr (cdr pair))
        (setq count (+ count 1))
      )
    )
  )
  (vl-catch-all-apply 'vla-Update (list insert-object))
  count
)

(defun swcad-title-delete-ename (ename)
  (if ename
    (entdel ename)
  )
)

(defun swcad-title-delete-vla-object (object)
  (if object
    (vl-catch-all-apply 'vla-Delete (list object))
  )
)

(defun swcad-title-internal-gentitle-marker-entity-p (ename / data type text)
  (setq data (entget ename))
  (setq type (strcase (swcad-title-string (cdr (assoc 0 data)))))
  (and
    (member type '("TEXT" "MTEXT"))
    (progn
      (setq text
        (strcase
          (vl-string-trim
            " \t\r\n"
            (swcad-title-string (cdr (assoc 1 data)))
          )
        )
      )
      T
    )
    (wcmatch text "!GENTITLE-*")
  )
)

(defun swcad-title-internal-frame-marker-enames (block-name / block ename data targets guard)
  (setq block (tblobjname "BLOCK" block-name))
  (setq targets nil)
  (if block
    (progn
      (setq ename (entnext block))
      (setq guard 0)
      (while (and ename (< guard 1000))
        (setq data (entget ename))
        (if (= (strcase (swcad-title-string (cdr (assoc 0 data)))) "ENDBLK")
          (setq ename nil)
          (progn
            (if (swcad-title-internal-gentitle-marker-entity-p ename)
              (setq targets (cons ename targets))
            )
            (setq ename (entnext ename))
          )
        )
        (setq guard (+ guard 1))
      )
    )
  )
  (reverse targets)
)

(defun swcad-title-delete-internal-frame-marker-texts (block-name / targets ename result count)
  (setq targets (swcad-title-internal-frame-marker-enames block-name))
  (setq count 0)
  (foreach ename targets
    (setq result (entdel ename))
    (if result
      (setq count (+ count 1))
    )
  )
  (if (> count 0)
    (progn
      (entupd (tblobjname "BLOCK" block-name))
      (vl-catch-all-apply 'vla-Regen (list (swcad-title-doc) 1))
    )
  )
  count
)

(defun swcad-title-delete-handle (handle / ename)
  (setq ename (handent (swcad-title-string handle)))
  (swcad-title-delete-ename ename)
)

(defun swcad-title-block-text-record-p (record / handle)
  (setq handle (strcase (swcad-title-string (nth 3 record))))
  (wcmatch handle "BLOCK:*")
)

(defun swcad-title-delete-text-record (record)
  (if (swcad-title-block-text-record-p record)
    nil
    (progn
      (swcad-title-delete-handle (nth 3 record))
      T
    )
  )
)

(defun swcad-title-delete-handle-list (handles / handle count)
  (setq count 0)
  (foreach handle handles
    (if (swcad-title-delete-handle handle)
      (setq count (+ count 1))
    )
  )
  count
)

(defun swcad-title-delete-ename-list (enames / ename count)
  (setq count 0)
  (foreach ename enames
    (if (swcad-title-delete-ename ename)
      (setq count (+ count 1))
    )
  )
  count
)

(defun swcad-title-frame-cleanup-entity-type-p (etype)
  (member
    (strcase (swcad-title-string etype))
    '("LINE" "LWPOLYLINE" "POLYLINE" "2DPOLYLINE" "HATCH" "SOLID" "TRACE" "WIPEOUT")
  )
)

(defun swcad-title-sheet-size-value (values / pair)
  (setq pair (assoc "GEN-TITLE-SIZ{6.7}" values))
  (if pair
    (vl-string-trim " \t\r\n" (strcase (swcad-title-string (cdr pair))))
    ""
  )
)

(defun swcad-title-sheet-dimensions (sheet-size / value)
  (setq value (strcase (swcad-title-string sheet-size)))
  (cond
    ((wcmatch value "*A0*") '(1189.0 841.0))
    ((wcmatch value "*A1*") '(841.0 594.0))
    ((wcmatch value "*A2*") '(594.0 420.0))
    ((wcmatch value "*A3*") '(420.0 297.0))
    ((wcmatch value "*A4*") '(210.0 297.0))
    (T nil)
  )
)

(defun swcad-title-normalized-sheet-size (sheet-size / value)
  (setq value (strcase (swcad-title-string sheet-size)))
  (cond
    ((wcmatch value "*A0*") "A0")
    ((wcmatch value "*A1*") "A1")
    ((wcmatch value "*A2*") "A2")
    ((wcmatch value "*A3*") "A3")
    ((wcmatch value "*A4*") "A4")
    (T nil)
  )
)

(defun swcad-title-sheet-size-from-block-name (block-name / value)
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

(defun swcad-title-values-with-sheet-size-override (values override-size / normalized)
  (setq normalized (swcad-title-normalized-sheet-size override-size))
  (if normalized
    (swcad-title-assoc-put "GEN-TITLE-SIZ{6.7}" normalized values)
    values
  )
)

(defun swcad-title-frame-block-size-priority (block-name / block-size)
  (setq block-size (swcad-title-sheet-size-from-block-name block-name))
  (if block-size
    0
    1
  )
)

(defun swcad-title-sheet-size-from-frame-bbox (frame-bbox / width height long short candidates best best-score candidate dims dim-long dim-short score)
  (setq best nil)
  (setq best-score nil)
  (if frame-bbox
    (progn
      (setq width (swcad-title-bbox-width frame-bbox))
      (setq height (swcad-title-bbox-height frame-bbox))
      (setq long (max width height))
      (setq short (min width height))
      (setq candidates '("A1" "A2" "A3" "A4"))
      (foreach candidate candidates
        (setq dims (swcad-title-sheet-dimensions candidate))
        (if dims
          (progn
            (setq dim-long (max (car dims) (cadr dims)))
            (setq dim-short (min (car dims) (cadr dims)))
            (setq score
              (+
                (/ (swcad-title-abs (- long dim-long)) dim-long)
                (/ (swcad-title-abs (- short dim-short)) dim-short)
              )
            )
            (if (or (not best-score) (< score best-score))
              (progn
                (setq best candidate)
                (setq best-score score)
              )
            )
          )
        )
      )
      (if (and best-score (< best-score 0.12))
        best
        nil
      )
    )
    nil
  )
)

(defun swcad-title-detected-sheet-size (values frame-bbox / text-size frame-size)
  (setq text-size (swcad-title-normalized-sheet-size (swcad-title-sheet-size-value values)))
  (setq frame-size (swcad-title-sheet-size-from-frame-bbox frame-bbox))
  (cond
    (frame-size frame-size)
    (text-size text-size)
    (T nil)
  )
)

(defun swcad-title-detected-sheet-size-for-source (source-block frame-block values frame-bbox / block-size source-size)
  (setq block-size (swcad-title-sheet-size-from-block-name frame-block))
  (if block-size
    block-size
    (progn
      (setq source-size (swcad-title-sheet-size-from-block-name source-block))
      (if source-size
        source-size
        (swcad-title-detected-sheet-size values frame-bbox)
      )
    )
  )
)

(defun swcad-title-target-frame-block-name-for-sheet (sheet-size / normalized)
  (setq normalized (swcad-title-normalized-sheet-size sheet-size))
  (if (and normalized (wcmatch normalized "A1,A2,A3,A4"))
    (strcat "DR_" normalized "_Outline")
    (swcad-title-target-frame-block-name)
  )
)

(defun swcad-title-target-frame-block-name-for-transfer (values frame-bbox / detected)
  (setq detected (swcad-title-detected-sheet-size values frame-bbox))
  (swcad-title-target-frame-block-name-for-sheet detected)
)

(defun swcad-title-target-frame-block-name-for-source (source-block frame-block values frame-bbox / detected)
  (setq detected (swcad-title-detected-sheet-size-for-source source-block frame-block values frame-bbox))
  (swcad-title-target-frame-block-name-for-sheet detected)
)

(defun swcad-title-bbox-size-string (bbox)
  (if bbox
    (strcat
      (swcad-title-number-string (swcad-title-bbox-width bbox))
      " x "
      (swcad-title-number-string (swcad-title-bbox-height bbox))
    )
    "<none>"
  )
)

(defun swcad-title-target-frame-bbox-size-warning (sheet bbox / dims width height actual-long actual-short expected-long expected-short long-delta short-delta)
  (setq dims (swcad-title-sheet-dimensions sheet))
  (if (and dims bbox)
    (progn
      (setq width (swcad-title-bbox-width bbox))
      (setq height (swcad-title-bbox-height bbox))
      (setq actual-long (max width height))
      (setq actual-short (min width height))
      (setq expected-long (max (car dims) (cadr dims)))
      (setq expected-short (min (car dims) (cadr dims)))
      (setq long-delta (/ (swcad-title-abs (- actual-long expected-long)) expected-long))
      (setq short-delta (/ (swcad-title-abs (- actual-short expected-short)) expected-short))
      (if (or (> long-delta 0.08) (> short-delta 0.08))
        (strcat
          "expected approx "
          (swcad-title-number-string (car dims))
          " x "
          (swcad-title-number-string (cadr dims))
          ", got "
          (swcad-title-bbox-size-string bbox)
        )
        nil
      )
    )
    nil
  )
)

(defun swcad-title-frame-bbox-size-warning-for-block (frame-block bbox / sheet)
  (setq sheet (swcad-title-sheet-size-from-block-name frame-block))
  (swcad-title-target-frame-bbox-size-warning sheet bbox)
)

(defun swcad-title-frame-bbox-size-valid-p (frame-block bbox)
  (not (swcad-title-frame-bbox-size-warning-for-block frame-block bbox))
)

(defun swcad-title-transform-bbox-with-insert (bbox insert-ename / data ins sx sy rot ix iy x1 x2 y1 y2)
  (setq data (if insert-ename (entget insert-ename) nil))
  (setq ins (swcad-title-dxf-value data 10))
  (setq sx (swcad-title-dxf-value data 41))
  (setq sy (swcad-title-dxf-value data 42))
  (setq rot (swcad-title-dxf-value data 50))
  (if (and bbox ins (or (not rot) (swcad-title-near-p rot 0.0 0.000001)))
    (progn
      (setq ix (float (car ins)))
      (setq iy (float (cadr ins)))
      (setq sx (float (if sx sx 1.0)))
      (setq sy (float (if sy sy 1.0)))
      (setq x1 (+ ix (* (car bbox) sx)))
      (setq x2 (+ ix (* (caddr bbox) sx)))
      (setq y1 (+ iy (* (cadr bbox) sy)))
      (setq y2 (+ iy (* (cadddr bbox) sy)))
      (list (min x1 x2) (min y1 y2) (max x1 x2) (max y1 y2))
    )
    nil
  )
)

(defun swcad-title-frame-block-main-outline-bbox (frame-block / sheet block result best-area item ename bbox area)
  (setq sheet (swcad-title-sheet-size-from-block-name frame-block))
  (setq block (swcad-title-block-definition-object frame-block))
  (setq result nil)
  (setq best-area 0.0)
  (if (and sheet block)
    (vlax-for item block
      (setq ename (swcad-title-vla-object->ename item))
      (if (and ename (equal (swcad-title-entity-type-name ename) "INSERT"))
        (progn
          (setq bbox (swcad-title-safe-bbox ename))
          (if (not (swcad-title-target-frame-bbox-size-warning sheet bbox))
            (progn
              (setq area (swcad-title-bbox-area bbox))
              (if (> area best-area)
                (progn
                  (setq result bbox)
                  (setq best-area area)
                )
              )
            )
          )
        )
      )
    )
  )
  result
)

(defun swcad-title-frame-reference-expected-sheet-bbox (frame-ename frame-block / sheet dims)
  (setq sheet (swcad-title-sheet-size-from-block-name frame-block))
  (setq dims (swcad-title-sheet-dimensions sheet))
  (if dims
    (swcad-title-transform-bbox-with-insert
      (list 0.0 0.0 (car dims) (cadr dims))
      frame-ename
    )
    nil
  )
)

(defun swcad-title-frame-reference-effective-bbox (frame-ename frame-block / raw raw-warning main transformed expected)
  (setq raw (swcad-title-safe-bbox frame-ename))
  (setq raw-warning (swcad-title-frame-bbox-size-warning-for-block frame-block raw))
  (setq main (swcad-title-frame-block-main-outline-bbox frame-block))
  (setq transformed (swcad-title-transform-bbox-with-insert main frame-ename))
  (setq expected
    (if raw-warning
      (swcad-title-frame-reference-expected-sheet-bbox frame-ename frame-block)
      nil
    )
  )
  (cond
    ((and transformed (not (swcad-title-frame-bbox-size-warning-for-block frame-block transformed)))
      transformed
    )
    ((and expected (not (swcad-title-frame-bbox-size-warning-for-block frame-block expected)))
      expected
    )
    (T raw)
  )
)

(defun swcad-title-target-frame-bbox-size-warning-records (frame-records / result index record frame-block frame-handle frame-bbox sheet warning)
  (setq result nil)
  (setq index 1)
  (foreach record frame-records
    (setq frame-block (cadr record))
    (setq frame-handle (caddr record))
    (setq frame-bbox (cadddr record))
    (setq sheet (swcad-title-sheet-size-from-block-name frame-block))
    (setq warning (swcad-title-target-frame-bbox-size-warning sheet frame-bbox))
    (if warning
      (setq result (append result (list (list index frame-block frame-handle sheet warning frame-bbox))))
    )
    (setq index (+ index 1))
  )
  result
)

(defun swcad-title-target-frame-geometry-warning-count (frame-records)
  (length (swcad-title-target-frame-bbox-size-warning-records frame-records))
)

(defun swcad-title-target-frame-overlap-warning-count (frame-records)
  (length (swcad-title-target-frame-overlap-records frame-records))
)

(defun swcad-title-target-frame-raw-selection-warning-records (frame-records / result index record frame-ename frame-block frame-handle sheet effective-bbox raw-bbox effective-area raw-area ratio warning)
  (setq result nil)
  (setq index 1)
  (foreach record frame-records
    (setq frame-ename (car record))
    (setq frame-block (cadr record))
    (setq frame-handle (caddr record))
    (setq effective-bbox (cadddr record))
    (setq raw-bbox (swcad-title-safe-bbox frame-ename))
    (setq sheet (swcad-title-sheet-size-from-block-name frame-block))
    (setq warning nil)
    (if (and raw-bbox effective-bbox)
      (progn
        (setq effective-area (max (swcad-title-bbox-area effective-bbox) 1.0))
        (setq raw-area (swcad-title-bbox-area raw-bbox))
        (setq ratio (/ raw-area effective-area))
        (if (> ratio 1.6)
          (setq warning
            (strcat
              "raw CAD selection bbox is larger than the effective visible frame; using effective bbox for title pairing; raw/effective area ratio="
              (swcad-title-number-string ratio)
            )
          )
        )
      )
    )
    (if warning
      (setq result
        (append
          result
          (list (list index frame-block frame-handle sheet warning raw-bbox effective-bbox))
        )
      )
    )
    (setq index (+ index 1))
  )
  result
)

(defun swcad-title-target-frame-raw-selection-warning-count (frame-records)
  (length (swcad-title-target-frame-raw-selection-warning-records frame-records))
)

(defun swcad-title-target-frame-overlap-records (frame-records / result total i j first second overlap)
  (setq result nil)
  (setq total (length frame-records))
  (setq i 0)
  (while (< i total)
    (setq first (nth i frame-records))
    (setq j (+ i 1))
    (while (< j total)
      (setq second (nth j frame-records))
      (setq overlap (swcad-title-bbox-overlap-box (cadddr first) (cadddr second)))
      (if overlap
        (setq result
          (append
            result
            (list
              (list
                (+ i 1)
                (cadr first)
                (caddr first)
                (+ j 1)
                (cadr second)
                (caddr second)
                overlap
              )
            )
          )
        )
      )
      (setq j (+ j 1))
    )
    (setq i (+ i 1))
  )
  result
)

(defun swcad-title-print-target-frame-selection-diagnostics (frame-records / size-records raw-records overlap-records record overlap risk-count)
  (setq size-records (swcad-title-target-frame-bbox-size-warning-records frame-records))
  (setq raw-records (swcad-title-target-frame-raw-selection-warning-records frame-records))
  (setq overlap-records (swcad-title-target-frame-overlap-records frame-records))
  (setq risk-count (length overlap-records))
  (swcad-title-princ-line "Target frame bbox size warnings:")
  (if size-records
    (foreach record size-records
      (swcad-title-princ-line
        (strcat
          "  #"
          (itoa (car record))
          " "
          (cadr record)
          "/"
          (caddr record)
          ", sheet="
          (if (nth 3 record) (nth 3 record) "<unknown>")
          ": "
          (nth 4 record)
          ", bbox="
          (swcad-title-bbox-string (nth 5 record))
        )
      )
    )
    (swcad-title-princ-line "  <none>")
  )
  (swcad-title-princ-line "Target frame raw selection bbox notes:")
  (if raw-records
    (foreach record raw-records
      (swcad-title-princ-line
        (strcat
          "  #"
          (itoa (car record))
          " "
          (cadr record)
          "/"
          (caddr record)
          ", sheet="
          (if (nth 3 record) (nth 3 record) "<unknown>")
          ": "
          (nth 4 record)
          ", raw-bbox="
          (swcad-title-bbox-string (nth 5 record))
          ", effective-bbox="
          (swcad-title-bbox-string (nth 6 record))
        )
      )
    )
    (swcad-title-princ-line "  <none>")
  )
  (swcad-title-princ-line "Target frame bbox overlap / selection risk:")
  (if overlap-records
    (foreach record overlap-records
      (setq overlap (nth 6 record))
      (swcad-title-princ-line
        (strcat
          "  #"
          (itoa (car record))
          " "
          (cadr record)
          "/"
          (caddr record)
          " overlaps #"
          (itoa (nth 3 record))
          " "
          (nth 4 record)
          "/"
          (nth 5 record)
          ", overlap="
          (swcad-title-bbox-string overlap)
          ", overlap-size="
          (swcad-title-bbox-size-string overlap)
        )
      )
    )
    (swcad-title-princ-line "  <none>")
  )
  (if (> risk-count 0)
    (swcad-title-princ-line "Note: if GMPOWEREDIT shows Next/Accept or REFEDIT, the cursor may be hitting an oversized or overlapping frame/block bbox instead of the intended GMTITLE title table.")
  )
  risk-count
)

(defun swcad-title-inferred-source-frame-bbox (source-bbox values / dims width height frame-max-x frame-min-y)
  (setq dims (swcad-title-sheet-dimensions (swcad-title-sheet-size-value values)))
  (if (and source-bbox dims)
    (progn
      (setq width (car dims))
      (setq height (cadr dims))
      (setq frame-max-x (+ (caddr source-bbox) 10.0))
      (setq frame-min-y (- (cadr source-bbox) 10.0))
      (list
        (- frame-max-x width)
        frame-min-y
        frame-max-x
        (+ frame-min-y height)
      )
    )
    nil
  )
)

(defun swcad-title-effective-source-frame-bbox (source-bbox source-frame-bbox values override-size / overridden-values inferred)
  (if source-frame-bbox
    source-frame-bbox
    (if override-size
      (progn
        (setq overridden-values (swcad-title-values-with-sheet-size-override values override-size))
        (setq inferred (swcad-title-inferred-source-frame-bbox source-bbox overridden-values))
        (if inferred inferred source-frame-bbox)
      )
      (swcad-title-inferred-source-frame-bbox source-bbox values)
    )
  )
)

(defun swcad-title-source-block-sheet-size (source-block frame-block / frame-size source-size)
  (setq frame-size (swcad-title-sheet-size-from-block-name frame-block))
  (if frame-size
    frame-size
    (progn
      (setq source-size (swcad-title-sheet-size-from-block-name source-block))
      source-size
    )
  )
)

(defun swcad-title-source-title-graphic-handles (source-bbox / ss index total ename data etype bbox handle result)
  (setq result nil)
  (setq ss (ssget "_X" '((0 . "LINE,LWPOLYLINE,POLYLINE,2DPOLYLINE,HATCH,SOLID,TRACE,WIPEOUT"))))
  (setq total (if ss (sslength ss) 0))
  (setq index 0)
  (while (< index total)
    (setq ename (ssname ss index))
    (setq data (entget ename '("*")))
    (setq etype (swcad-title-dxf-value data 0))
    (setq bbox (swcad-title-safe-bbox ename))
    (setq handle (swcad-title-string (swcad-title-dxf-value data 5)))
    (if
      (and
        (> (strlen handle) 0)
        (swcad-title-frame-cleanup-entity-type-p etype)
        (swcad-title-bbox-intersects-p bbox (swcad-title-expand-bbox source-bbox 1.0))
      )
      (setq result (swcad-title-list-add-unique handle result))
    )
    (setq index (+ index 1))
  )
  result
)

(defun swcad-title-frame-edge-graphic-p (bbox frame-bbox / tolerance frame-width frame-height width height near-left near-right near-bottom near-top full-box long-horizontal long-vertical)
  (if (and bbox frame-bbox)
    (progn
      (setq tolerance 2.5)
      (setq frame-width (swcad-title-bbox-width frame-bbox))
      (setq frame-height (swcad-title-bbox-height frame-bbox))
      (setq width (swcad-title-bbox-width bbox))
      (setq height (swcad-title-bbox-height bbox))
      (setq near-left (and (swcad-title-near-p (car bbox) (car frame-bbox) tolerance) (swcad-title-near-p (caddr bbox) (car frame-bbox) tolerance)))
      (setq near-right (and (swcad-title-near-p (car bbox) (caddr frame-bbox) tolerance) (swcad-title-near-p (caddr bbox) (caddr frame-bbox) tolerance)))
      (setq near-bottom (and (swcad-title-near-p (cadr bbox) (cadr frame-bbox) tolerance) (swcad-title-near-p (cadddr bbox) (cadr frame-bbox) tolerance)))
      (setq near-top (and (swcad-title-near-p (cadr bbox) (cadddr frame-bbox) tolerance) (swcad-title-near-p (cadddr bbox) (cadddr frame-bbox) tolerance)))
      (setq full-box
        (and
          (swcad-title-near-p (car bbox) (car frame-bbox) tolerance)
          (swcad-title-near-p (cadr bbox) (cadr frame-bbox) tolerance)
          (swcad-title-near-p (caddr bbox) (caddr frame-bbox) tolerance)
          (swcad-title-near-p (cadddr bbox) (cadddr frame-bbox) tolerance)
        )
      )
      (setq long-horizontal (>= width (* frame-width 0.25)))
      (setq long-vertical (>= height (* frame-height 0.25)))
      (and
        (swcad-title-bbox-contains-bbox-p (swcad-title-expand-bbox frame-bbox tolerance) bbox 0.0)
        (or
          full-box
          (and long-horizontal (or near-bottom near-top))
          (and long-vertical (or near-left near-right))
        )
      )
    )
    nil
  )
)

(defun swcad-title-source-frame-graphic-handles (frame-bbox source-bbox / ss index total ename data etype bbox handle result)
  (setq result nil)
  (if frame-bbox
    (progn
      (setq ss (ssget "_X" '((0 . "LINE,LWPOLYLINE,POLYLINE,2DPOLYLINE,HATCH,SOLID,TRACE,WIPEOUT"))))
      (setq total (if ss (sslength ss) 0))
      (setq index 0)
      (while (< index total)
        (setq ename (ssname ss index))
        (setq data (entget ename '("*")))
        (setq etype (swcad-title-dxf-value data 0))
        (setq bbox (swcad-title-safe-bbox ename))
        (setq handle (swcad-title-string (swcad-title-dxf-value data 5)))
        (if
          (and
            (> (strlen handle) 0)
            (swcad-title-frame-cleanup-entity-type-p etype)
            (not (swcad-title-bbox-intersects-p bbox (swcad-title-expand-bbox source-bbox 1.0)))
            (swcad-title-frame-edge-graphic-p bbox frame-bbox)
          )
          (setq result (swcad-title-list-add-unique handle result))
        )
        (setq index (+ index 1))
      )
    )
  )
  result
)

(defun swcad-title-relative-bbox (frame-bbox left bottom right top / width height)
  (if frame-bbox
    (progn
      (setq width (swcad-title-bbox-width frame-bbox))
      (setq height (swcad-title-bbox-height frame-bbox))
      (list
        (+ (car frame-bbox) (* width left))
        (+ (cadr frame-bbox) (* height bottom))
        (+ (car frame-bbox) (* width right))
        (+ (cadr frame-bbox) (* height top))
      )
    )
    nil
  )
)

(defun swcad-title-source-sheet-residue-regions (frame-bbox)
  (if frame-bbox
    (list
      (list "bottom-left logo" (swcad-title-relative-bbox frame-bbox 0.00 0.00 0.36 0.18))
      (list "upper sheet-format residue" (swcad-title-relative-bbox frame-bbox 0.00 0.82 0.82 1.04))
      (list "upper-right residual block" (swcad-title-relative-bbox frame-bbox 0.70 0.74 1.08 1.02))
    )
    nil
  )
)

(defun swcad-title-source-sheet-residue-type-p (etype)
  (wcmatch
    (strcase (swcad-title-string etype))
    "INSERT,LINE,LWPOLYLINE,POLYLINE,2DPOLYLINE,HATCH,SOLID,TRACE,WIPEOUT,CIRCLE,ARC,ELLIPSE,SPLINE,TEXT,MTEXT"
  )
)

(defun swcad-title-upper-sheet-residue-type-p (etype)
  (wcmatch
    (strcase (swcad-title-string etype))
    "INSERT,HATCH,SOLID,TRACE,WIPEOUT"
  )
)

(defun swcad-title-source-sheet-residue-record-type-p (region-name etype / upper-region)
  (setq upper-region (strcase (swcad-title-string region-name)))
  (cond
    ((equal upper-region "BOTTOM-LEFT LOGO")
      (swcad-title-source-sheet-residue-type-p etype)
    )
    ((wcmatch upper-region "UPPER*")
      (swcad-title-upper-sheet-residue-type-p etype)
    )
    (T nil)
  )
)

(defun swcad-title-region-containing-bbox (bbox regions / found region)
  (setq found nil)
  (foreach region regions
    (if (and
          (not found)
          (swcad-title-bbox-contains-bbox-p (cadr region) bbox 1.5)
        )
      (setq found region)
    )
  )
  found
)

(defun swcad-title-entity-handle (ename / data)
  (setq data (entget ename '("*")))
  (swcad-title-string (swcad-title-dxf-value data 5))
)

(defun swcad-title-ename-list-has-ename-p (ename enames / found item)
  (setq found nil)
  (foreach item enames
    (if (eq ename item)
      (setq found T)
    )
  )
  found
)

(defun swcad-title-source-sheet-residue-records (frame-bbox source-ename source-frame-ename / regions excluded ss index total ename data etype bbox handle region block layer result)
  (setq result nil)
  (setq regions (swcad-title-source-sheet-residue-regions frame-bbox))
  (setq excluded nil)
  (if source-ename
    (setq excluded (append excluded (list source-ename)))
  )
  (if source-frame-ename
    (setq excluded (append excluded (list source-frame-ename)))
  )
  (if regions
    (progn
      (setq ss (ssget "_X" '((0 . "INSERT,LINE,LWPOLYLINE,POLYLINE,2DPOLYLINE,HATCH,SOLID,TRACE,WIPEOUT,CIRCLE,ARC,ELLIPSE,SPLINE,TEXT,MTEXT"))))
      (setq total (if ss (sslength ss) 0))
      (setq index 0)
      (while (< index total)
        (setq ename (ssname ss index))
        (setq data (entget ename '("*")))
        (setq etype (swcad-title-dxf-value data 0))
        (setq bbox (swcad-title-safe-bbox ename))
        (setq handle (swcad-title-string (swcad-title-dxf-value data 5)))
        (setq region (swcad-title-region-containing-bbox bbox regions))
        (if
          (and
            (> (strlen handle) 0)
            (not (swcad-title-ename-list-has-ename-p ename excluded))
            region
            (swcad-title-source-sheet-residue-record-type-p (car region) etype)
          )
          (progn
            (setq block (if (= (strcase (swcad-title-string etype)) "INSERT") (swcad-title-effective-insert-name ename) ""))
            (setq layer (swcad-title-string (swcad-title-dxf-value data 8)))
            (if
              (and
                (not (swcad-title-native-target-title-name-p block))
                (not (swcad-title-native-target-frame-name-p block))
              )
              (setq result
                (append
                  result
                  (list (list handle (car region) etype layer block bbox))
                )
              )
            )
          )
        )
        (setq index (+ index 1))
      )
    )
  )
  result
)

(defun swcad-title-residue-record-handles (records / result record)
  (setq result nil)
  (foreach record records
    (setq result (swcad-title-list-add-unique (car record) result))
  )
  result
)

(defun swcad-title-print-residue-records (label records / record block)
  (swcad-title-princ-line label)
  (if records
    (foreach record records
      (setq block (nth 4 record))
      (swcad-title-princ-line
        (strcat
          "  - handle="
          (swcad-title-string (car record))
          ", region="
          (swcad-title-string (cadr record))
          ", type="
          (swcad-title-string (caddr record))
          ", layer="
          (swcad-title-string (cadddr record))
          (if (> (strlen (swcad-title-string block)) 0)
            (strcat ", block=" (swcad-title-string block))
            ""
          )
          ", bbox="
          (swcad-title-bbox-string (nth 5 record))
        )
      )
    )
    (swcad-title-princ-line "  <none>")
  )
)

(defun swcad-title-transfer-values (mappings / result pair preview)
  (setq result nil)
  (foreach pair mappings
    (setq preview (cdr pair))
    (setq result
      (swcad-title-assoc-put
        (car pair)
        (nth 2 preview)
        result
      )
    )
  )
  result
)

(defun swcad-title-transfer-build-mappings (source-bbox source-ename maxdist / records mappings unmapped duplicates record preview tag existing duplicate-count unmapped-count mapped-count)
  (setq records (swcad-title-transfer-text-records source-bbox source-ename))
  (setq mappings nil)
  (setq unmapped nil)
  (setq duplicates nil)
  (setq mapped-count 0)
  (setq duplicate-count 0)
  (setq unmapped-count 0)
  (foreach record records
    (setq preview (swcad-title-transfer-preview-record record source-bbox))
    (if (and preview (<= (nth 5 preview) maxdist))
      (progn
        (setq tag (car preview))
        (setq existing (assoc tag mappings))
        (if existing
          (progn
            (setq duplicates (append duplicates (list record)))
            (setq duplicate-count (+ duplicate-count 1))
          )
          (progn
            (setq mappings (swcad-title-assoc-put tag preview mappings))
            (setq mapped-count (+ mapped-count 1))
          )
        )
      )
      (progn
        (setq unmapped (append unmapped (list record)))
        (setq unmapped-count (+ unmapped-count 1))
      )
    )
  )
  (list mappings records unmapped duplicates mapped-count unmapped-count duplicate-count)
)

(defun swcad-title-count-put (key counts / pair)
  (setq pair (assoc key counts))
  (if pair
    (subst (cons key (+ (cdr pair) 1)) pair counts)
    (append counts (list (cons key 1)))
  )
)

(defun swcad-title-print-counts (label counts / pair)
  (swcad-title-princ-line label)
  (if counts
    (foreach pair counts
      (swcad-title-princ-line
        (strcat
          "  "
          (swcad-title-string (car pair))
          ": "
          (itoa (cdr pair))
        )
      )
    )
    (swcad-title-princ-line "  <none>")
  )
)

(defun swcad-title-print-counts-log-only (label counts / pair)
  (swcad-title-log-line label)
  (if counts
    (foreach pair counts
      (swcad-title-log-line
        (strcat
          "  "
          (swcad-title-string (car pair))
          ": "
          (itoa (cdr pair))
        )
      )
    )
    (swcad-title-log-line "  <none>")
  )
)

(defun swcad-title-source-frame-from-candidates (source-bbox sheet-frames / found frame frame-bbox frame-area best-area)
  (setq found nil)
  (setq best-area nil)
  (foreach frame sheet-frames
    (setq frame-bbox (caddr frame))
    (setq frame-area (nth 4 frame))
    (if
      (and
        frame-bbox
        source-bbox
        (swcad-title-bbox-contains-bbox-p frame-bbox source-bbox 2.0)
        (or (not best-area) (< frame-area best-area))
      )
      (progn
        (setq found frame)
        (setq best-area frame-area)
      )
    )
  )
  found
)

(defun swcad-title-timer-seconds (/ value)
  (setq value (getvar "DATE"))
  (if value
    (* 86400.0 value)
    0.0
  )
)

(defun swcad-title-elapsed-ms (start-ms / finish-ms elapsed)
  (setq finish-ms (swcad-title-timer-seconds))
  (setq elapsed (- finish-ms start-ms))
  (fix (* 1000.0 elapsed))
)

(defun swcad-title-multi-preview (/ *error* start-ms elapsed sources sheet-frames total frame-total index source data bbox block title-frame title-frame-block title-frame-sheet title-target sheet-frame sheet-frame-key frame-sheet-counts title-sheet-counts frame-only-count title-with-frame-count title-without-frame-count)
  (defun *error* (msg)
    (if msg
      (progn
        (swcad-title-log-line (strcat "Error: " (swcad-title-string msg)))
        (swcad-title-princ-line (strcat "SWTITLEMULTIPREVIEW error: " (swcad-title-string msg)))
      )
    )
    (swcad-title-close-log)
    (princ)
  )
  (setq start-ms (swcad-title-timer-seconds))
  (swcad-title-open-multi-preview-log)
  (setq sources (swcad-title-source-title-candidates))
  (setq sheet-frames (swcad-title-source-frame-candidates))
  (setq total (length sources))
  (setq frame-total (length sheet-frames))
  (setq frame-sheet-counts nil)
  (setq title-sheet-counts nil)
  (setq frame-only-count 0)
  (setq title-with-frame-count 0)
  (setq title-without-frame-count 0)

  (swcad-title-log-line "----- SWTITLEMULTIPREVIEW fast read-only multi-sheet summary -----")
  (swcad-title-log-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (swcad-title-log-line (strcat "CTAB: " (getvar "CTAB")))
  (swcad-title-log-line "Residue cleanup candidate scan: skipped in fast preview.")
  (swcad-title-log-line "Run SWTITLEMULTIDETAIL for old detailed mapping/residue diagnostics.")

  (foreach sheet-frame sheet-frames
    (setq sheet-frame-key (nth 5 sheet-frame))
    (setq frame-sheet-counts (swcad-title-count-put sheet-frame-key frame-sheet-counts))
    (if (not (swcad-title-frame-has-source-title-p (caddr sheet-frame) sources))
      (setq frame-only-count (+ frame-only-count 1))
    )
  )

  (swcad-title-log-line "")
  (swcad-title-log-line "Source sheet frame candidates:")
  (setq index 1)
  (foreach sheet-frame sheet-frames
    (swcad-title-log-line
      (strcat
        "  #"
        (itoa index)
        " handle="
        (swcad-title-string (swcad-title-dxf-value (cadr sheet-frame) 5))
        ", block="
        (swcad-title-string (cadddr sheet-frame))
        ", sheet="
        (swcad-title-string (nth 5 sheet-frame))
        ", title-present="
        (if (swcad-title-frame-has-source-title-p (caddr sheet-frame) sources) "yes" "no")
        ", target-frame="
        (swcad-title-target-frame-block-name-for-sheet (nth 5 sheet-frame))
        ", bbox="
        (swcad-title-bbox-string (caddr sheet-frame))
      )
    )
    (setq index (+ index 1))
  )

  (swcad-title-log-line "")
  (swcad-title-log-line "Source title candidates:")
  (setq index 1)
  (foreach source sources
    (setq data (cadr source))
    (setq bbox (caddr source))
    (setq block (cadddr source))
    (setq title-frame (swcad-title-source-frame-from-candidates bbox sheet-frames))
    (setq title-frame-block (if title-frame (cadddr title-frame) ""))
    (setq title-frame-sheet (if title-frame (nth 5 title-frame) nil))
    (if title-frame-sheet
      (progn
        (setq title-sheet-counts (swcad-title-count-put title-frame-sheet title-sheet-counts))
        (setq title-with-frame-count (+ title-with-frame-count 1))
      )
      (progn
        (setq title-sheet-counts (swcad-title-count-put "<missing-frame>" title-sheet-counts))
        (setq title-without-frame-count (+ title-without-frame-count 1))
      )
    )
    (setq title-target (swcad-title-target-frame-block-name-for-sheet title-frame-sheet))
    (swcad-title-log-line
      (strcat
        "  #"
        (itoa index)
        " handle="
        (swcad-title-string (swcad-title-dxf-value data 5))
        ", block="
        (swcad-title-string block)
        ", frame-block="
        (if title-frame (swcad-title-string title-frame-block) "<missing>")
        ", sheet="
        (if title-frame-sheet title-frame-sheet "<missing>")
        ", target-frame="
        title-target
        ", bbox="
        (swcad-title-bbox-string bbox)
      )
    )
    (setq index (+ index 1))
  )

  (setq elapsed (swcad-title-elapsed-ms start-ms))
  (swcad-title-log-line "")
  (swcad-title-log-line "Summary:")
  (swcad-title-log-line (strcat "  source title candidates: " (itoa total)))
  (swcad-title-log-line (strcat "  source sheet frame candidates: " (itoa frame-total)))
  (swcad-title-log-line (strcat "  title candidates with frame: " (itoa title-with-frame-count)))
  (swcad-title-log-line (strcat "  title candidates without frame: " (itoa title-without-frame-count)))
  (swcad-title-log-line (strcat "  frame-only sheet candidates: " (itoa frame-only-count)))
  (swcad-title-print-counts-log-only "  source sheet frame counts:" frame-sheet-counts)
  (swcad-title-print-counts-log-only "  title sheet counts:" title-sheet-counts)
  (swcad-title-log-line (strcat "Elapsed ms: " (itoa elapsed)))
  (swcad-title-log-line "No drawing data was changed.")

  (swcad-title-princ-line "----- SWTITLEMULTIPREVIEW fast summary -----")
  (swcad-title-princ-line (strcat "Source titles: " (itoa total)))
  (swcad-title-princ-line (strcat "Source sheet frames: " (itoa frame-total)))
  (swcad-title-princ-line (strcat "Frame-only sheets: " (itoa frame-only-count)))
  (swcad-title-print-counts "Source sheet frame counts:" frame-sheet-counts)
  (swcad-title-print-counts "Title sheet counts:" title-sheet-counts)
  (swcad-title-princ-line "Residue cleanup scan: skipped")
  (swcad-title-princ-line (strcat "Elapsed ms: " (itoa elapsed)))
  (swcad-title-princ-line "No drawing data was changed.")
  (swcad-title-close-log)
  (princ)
)

(defun swcad-title-multi-detail (/ start-ms elapsed sources sheet-frames total frame-total index source ename data bbox block frame frame-data frame-bbox frame-block build mappings records unmapped duplicates values block-sheet effective-frame-bbox text-sheet frame-sheet detected-sheet frame-target residue-records sheet-key sheet-counts mapped-total residue-total sheet-frame sheet-frame-key frame-sheet-counts frame-only-count)
  (setq start-ms (swcad-title-timer-seconds))
  (swcad-title-open-multi-detail-log)
  (setq sources (swcad-title-source-title-candidates))
  (setq sheet-frames (swcad-title-source-frame-candidates))
  (setq total (length sources))
  (setq frame-total (length sheet-frames))
  (setq sheet-counts nil)
  (setq frame-sheet-counts nil)
  (setq mapped-total 0)
  (setq residue-total 0)
  (swcad-title-princ-line "----- SWTITLEMULTIPREVIEW read-only multi-sheet title transfer preview -----")
  (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (swcad-title-princ-line (strcat "CTAB: " (getvar "CTAB")))
  (swcad-title-print-work-copy-status)
  (swcad-title-princ-line (strcat "Source title candidates: " (itoa total)))
  (swcad-title-princ-line (strcat "Source sheet frame candidates: " (itoa frame-total)))
  (foreach sheet-frame sheet-frames
    (setq sheet-frame-key (nth 5 sheet-frame))
    (setq frame-sheet-counts (swcad-title-count-put sheet-frame-key frame-sheet-counts))
  )
  (setq frame-only-count 0)
  (foreach sheet-frame sheet-frames
    (if (not (swcad-title-frame-has-source-title-p (caddr sheet-frame) sources))
      (progn
        (if (= frame-only-count 0)
          (swcad-title-princ-line "Frame-only sheet candidates:")
        )
        (setq frame-only-count (+ frame-only-count 1))
        (swcad-title-princ-line
          (strcat
            "  handle="
            (swcad-title-string (swcad-title-dxf-value (cadr sheet-frame) 5))
            ", block="
            (swcad-title-string (cadddr sheet-frame))
            ", sheet="
            (swcad-title-string (nth 5 sheet-frame))
            ", bbox="
            (swcad-title-bbox-string (caddr sheet-frame))
          )
        )
      )
    )
  )
  (if (= frame-only-count 0)
    (swcad-title-princ-line "Frame-only sheet candidates: <none>")
  )
  (setq index 1)
  (foreach source sources
    (setq ename (car source))
    (setq data (cadr source))
    (setq bbox (caddr source))
    (setq block (cadddr source))
    (setq frame (swcad-title-transfer-source-frame bbox ename))
    (setq frame-data (if frame (cadr frame) nil))
    (setq frame-bbox (if frame (caddr frame) nil))
    (setq frame-block (if frame (swcad-title-effective-insert-name (car frame)) ""))
    (setq build (swcad-title-transfer-build-mappings bbox ename 7.0))
    (setq mappings (car build))
    (setq records (cadr build))
    (setq unmapped (caddr build))
    (setq duplicates (cadddr build))
    (setq values (swcad-title-transfer-values mappings))
    (setq block-sheet (swcad-title-source-block-sheet-size block frame-block))
    (setq values (swcad-title-values-with-sheet-size-override values block-sheet))
    (setq effective-frame-bbox (swcad-title-effective-source-frame-bbox bbox frame-bbox values block-sheet))
    (setq text-sheet (swcad-title-normalized-sheet-size (swcad-title-sheet-size-value values)))
    (setq frame-sheet (swcad-title-sheet-size-from-frame-bbox effective-frame-bbox))
    (setq detected-sheet (swcad-title-detected-sheet-size-for-source block frame-block values effective-frame-bbox))
    (setq frame-target (swcad-title-target-frame-block-name-for-source block frame-block values effective-frame-bbox))
    (setq residue-records (swcad-title-source-sheet-residue-records effective-frame-bbox ename (if frame (car frame) nil)))
    (setq sheet-key (if detected-sheet detected-sheet "<fallback>"))
    (setq sheet-counts (swcad-title-count-put sheet-key sheet-counts))
    (setq mapped-total (+ mapped-total (length mappings)))
    (setq residue-total (+ residue-total (length residue-records)))
    (swcad-title-princ-line "")
    (swcad-title-princ-line (strcat "#" (itoa index)))
    (swcad-title-princ-line
      (strcat
        "  source title: handle="
        (swcad-title-string (swcad-title-dxf-value data 5))
        ", block="
        (swcad-title-string block)
        ", bbox="
        (swcad-title-bbox-string bbox)
      )
    )
    (swcad-title-princ-line
      (strcat
        "  source frame: "
        (if frame-data
          (strcat
            "handle="
            (swcad-title-string (swcad-title-dxf-value frame-data 5))
            ", block="
            (swcad-title-string frame-block)
            ", bbox="
            (swcad-title-bbox-string frame-bbox)
          )
          "<none>"
        )
      )
    )
    (swcad-title-princ-line
      (strcat
        "  detected sheet: title-text="
        (if text-sheet text-sheet "<none>")
        ", frame-bbox="
        (if frame-sheet frame-sheet "<none>")
        ", block-name="
        (if block-sheet block-sheet "<none>")
        ", selected="
        sheet-key
        ", target-frame="
        frame-target
      )
    )
    (swcad-title-princ-line
      (strcat
        "  source title text records="
        (itoa (length records))
        ", mapped fields="
        (itoa (length mappings))
        ", unmapped="
        (itoa (length unmapped))
        ", duplicates="
        (itoa (length duplicates))
      )
    )
    (swcad-title-princ-line "  values to apply:")
    (if values
      (foreach pair values
        (swcad-title-princ-line
          (strcat
            "    "
            (car pair)
            " = "
            (swcad-title-string (cdr pair))
          )
        )
      )
      (swcad-title-princ-line "    <none>")
    )
    (swcad-title-princ-line (strcat "  sheet residue candidates=" (itoa (length residue-records))))
    (setq index (+ index 1))
  )
  (swcad-title-princ-line "")
  (swcad-title-princ-line "Summary:")
  (swcad-title-princ-line (strcat "  source title candidates: " (itoa total)))
  (swcad-title-princ-line (strcat "  mapped fields total: " (itoa mapped-total)))
  (swcad-title-princ-line (strcat "  sheet residue candidates total: " (itoa residue-total)))
  (swcad-title-print-counts "  detected sheet counts:" sheet-counts)
  (swcad-title-print-counts "  source sheet frame counts:" frame-sheet-counts)
  (setq elapsed (swcad-title-elapsed-ms start-ms))
  (swcad-title-princ-line (strcat "Elapsed ms: " (itoa elapsed)))
  (swcad-title-princ-line "No drawing data was changed.")
  (swcad-title-close-log)
  (princ)
)

(defun swcad-title-frame-scan-interest-name-p (raw-name effective-name / raw effective pattern)
  (setq raw (strcase (swcad-title-string raw-name)))
  (setq effective (strcase (swcad-title-string effective-name)))
  (setq pattern "*DR*A*,*DR-A*,*A4*,*A-4*,*A_4*,*A 4*,*0400*,*0500*")
  (or
    (wcmatch raw pattern)
    (wcmatch effective pattern)
  )
)

(defun swcad-title-frame-scan (/ sources index source ename data bbox block frame frame-data frame-bbox frame-block raw-frame-block block-sheet insert-ss insert-index insert-total insert-ename insert-data raw-name effective-name insert-bbox insert-sheet bbox-sheet interesting-count a4-count)
  (swcad-title-open-frame-scan-log)
  (swcad-title-princ-line "----- SWTITLEFRAMESCAN read-only source frame diagnostics -----")
  (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (swcad-title-princ-line (strcat "CTAB: " (getvar "CTAB")))
  (swcad-title-princ-line "Selected source frames:")
  (setq sources (swcad-title-source-title-candidates))
  (setq index 1)
  (foreach source sources
    (setq ename (car source))
    (setq data (cadr source))
    (setq bbox (caddr source))
    (setq block (cadddr source))
    (setq frame (swcad-title-transfer-source-frame bbox ename))
    (setq frame-data (if frame (cadr frame) nil))
    (setq frame-bbox (if frame (caddr frame) nil))
    (setq frame-block (if frame (swcad-title-effective-insert-name (car frame)) ""))
    (setq raw-frame-block (if frame-data (swcad-title-dxf-value frame-data 2) ""))
    (setq block-sheet (swcad-title-source-block-sheet-size block frame-block))
    (swcad-title-princ-line
      (strcat
        "  #"
        (itoa index)
        " source="
        (swcad-title-string block)
        ", frame-raw="
        (swcad-title-string raw-frame-block)
        ", frame-effective="
        (swcad-title-string frame-block)
        ", block-sheet="
        (if block-sheet block-sheet "<none>")
        ", frame-bbox-sheet="
        (if (swcad-title-sheet-size-from-frame-bbox frame-bbox) (swcad-title-sheet-size-from-frame-bbox frame-bbox) "<none>")
        ", frame-bbox="
        (swcad-title-bbox-string frame-bbox)
      )
    )
    (setq index (+ index 1))
  )

  (swcad-title-princ-line "")
  (swcad-title-princ-line "Interesting INSERT names (DR-A*, A4, 0400, 0500):")
  (setq interesting-count 0)
  (setq a4-count 0)
  (setq insert-ss (ssget "_X" '((0 . "INSERT"))))
  (setq insert-total (if insert-ss (sslength insert-ss) 0))
  (setq insert-index 0)
  (while (< insert-index insert-total)
    (setq insert-ename (ssname insert-ss insert-index))
    (setq insert-data (entget insert-ename '("*")))
    (setq raw-name (swcad-title-dxf-value insert-data 2))
    (setq effective-name (swcad-title-effective-insert-name insert-ename))
    (if (swcad-title-frame-scan-interest-name-p raw-name effective-name)
      (progn
        (setq insert-bbox (swcad-title-safe-bbox insert-ename))
        (setq insert-sheet (swcad-title-sheet-size-from-block-name effective-name))
        (if (not insert-sheet)
          (setq insert-sheet (swcad-title-sheet-size-from-block-name raw-name))
        )
        (setq bbox-sheet (swcad-title-sheet-size-from-frame-bbox insert-bbox))
        (setq interesting-count (+ interesting-count 1))
        (if (= insert-sheet "A4")
          (setq a4-count (+ a4-count 1))
        )
        (swcad-title-princ-line
          (strcat
            "  handle="
            (swcad-title-string (swcad-title-dxf-value insert-data 5))
            ", raw="
            (swcad-title-string raw-name)
            ", effective="
            (swcad-title-string effective-name)
            ", name-sheet="
            (if insert-sheet insert-sheet "<none>")
            ", bbox-sheet="
            (if bbox-sheet bbox-sheet "<none>")
            ", bbox="
            (swcad-title-bbox-string insert-bbox)
          )
        )
      )
    )
    (setq insert-index (+ insert-index 1))
  )
  (swcad-title-princ-line "")
  (swcad-title-princ-line "Summary:")
  (swcad-title-princ-line (strcat "  source title candidates: " (itoa (length sources))))
  (swcad-title-princ-line (strcat "  interesting inserts: " (itoa interesting-count)))
  (swcad-title-princ-line (strcat "  A4-named inserts: " (itoa a4-count)))
  (swcad-title-princ-line "No drawing data was changed.")
  (swcad-title-close-log)
  (princ)
)

(defun swcad-title-char-code (text)
  (if (and text (> (strlen text) 0))
    (ascii text)
    0
  )
)

(defun swcad-title-digit-or-dot-p (text / code)
  (setq code (swcad-title-char-code text))
  (or
    (and (>= code 48) (<= code 57))
    (= text ".")
  )
)

(defun swcad-title-space-p (text / code)
  (setq code (swcad-title-char-code text))
  (or (= code 9) (= code 10) (= code 13) (= code 32))
)

(defun swcad-title-scale-only-text-p (text / index len ch ok)
  (setq index 1)
  (setq len (strlen text))
  (setq ok (> len 0))
  (while (and ok (<= index len))
    (setq ch (substr text index 1))
    (if (not (or (swcad-title-digit-or-dot-p ch) (swcad-title-space-p ch) (= ch ":")))
      (setq ok nil)
    )
    (setq index (+ index 1))
  )
  ok
)

(defun swcad-title-extract-ratio-text (text / raw len colon left-end left-start right-start right-end left right)
  (setq raw (vl-string-trim " \t\r\n" (swcad-title-string text)))
  (setq len (strlen raw))
  (setq colon (vl-string-search ":" raw))
  (setq left nil)
  (setq right nil)
  (if colon
    (progn
      (setq left-end colon)
      (while (and (> left-end 0) (swcad-title-space-p (substr raw left-end 1)))
        (setq left-end (- left-end 1))
      )
      (setq left-start left-end)
      (while (and (> left-start 0) (swcad-title-digit-or-dot-p (substr raw left-start 1)))
        (setq left-start (- left-start 1))
      )
      (if (> left-end left-start)
        (setq left (substr raw (+ left-start 1) (- left-end left-start)))
      )

      (setq right-start (+ colon 2))
      (while (and (<= right-start len) (swcad-title-space-p (substr raw right-start 1)))
        (setq right-start (+ right-start 1))
      )
      (setq right-end right-start)
      (while (and (<= right-end len) (swcad-title-digit-or-dot-p (substr raw right-end 1)))
        (setq right-end (+ right-end 1))
      )
      (if (> right-end right-start)
        (setq right (substr raw right-start (- right-end right-start)))
      )
    )
  )
  (if (and left right (> (atof left) 0.0) (> (atof right) 0.0))
    (strcat left ":" right)
    nil
  )
)

(defun swcad-title-scale-text-candidate (text / cleaned upper ratio)
  (setq cleaned (vl-string-trim " \t\r\n" (swcad-title-string text)))
  (setq upper (strcase cleaned))
  (setq ratio (swcad-title-extract-ratio-text cleaned))
  (if (and
        ratio
        (or
          (swcad-title-scale-only-text-p cleaned)
          (vl-string-search "SCALE" upper)
          (vl-string-search "SCA" upper)
          (<= (strlen cleaned) 16)
        )
      )
    ratio
    nil
  )
)

(defun swcad-title-insert-attributes (ename / data next edata etype result)
  (setq result nil)
  (setq data (entget ename))
  (if (= (swcad-title-dxf-value data 66) 1)
    (progn
      (setq next (entnext ename))
      (while next
        (setq edata (entget next '("*")))
        (setq etype (swcad-title-dxf-value edata 0))
        (cond
          ((= etype "ATTRIB")
            (setq result (append result (list edata)))
          )
          ((= etype "SEQEND")
            (setq next nil)
          )
          ((not (= etype "ATTRIB"))
            (setq next nil)
          )
        )
        (if next
          (setq next (entnext next))
        )
      )
    )
  )
  result
)

(defun swcad-title-scale-tag-p (tag / upper)
  (setq upper (strcase (swcad-title-string tag)))
  (or
    (wcmatch upper "*GEN-TITLE-SCA*")
    (wcmatch upper "*TITLE*SCA*")
    (wcmatch upper "*SCALE*")
  )
)

(defun swcad-title-title-block-name-p (name / upper)
  (setq upper (strcase (swcad-title-string name)))
  (or
    (wcmatch upper "*TITLE*")
    (wcmatch upper "*GMTITLE*")
    (wcmatch upper "*FTAP*")
  )
)

(defun swcad-title-native-target-title-name-p (name)
  (equal
    (strcase (swcad-title-string name))
    (strcase (swcad-title-target-title-block-name))
  )
)

(defun swcad-title-native-target-frame-name-p (name / upper candidate result)
  (setq upper (strcase (swcad-title-string name)))
  (setq result nil)
  (foreach candidate (swcad-title-target-frame-block-candidates)
    (if (equal upper (strcase candidate))
      (setq result T)
    )
  )
  result
)

(defun swcad-title-source-like-frame-child-name-p (name / upper)
  (setq upper (strcase (swcad-title-string name)))
  (or
    ;; Native GstarCAD DR frame DWGs also contain child blocks named like
    ;; "DR-A3 From_HYUN". Treat only sheet/export-specific children as old
    ;; SOLIDWORKS residue so native DR_A*_Outline imports are not rejected.
    (wcmatch upper "#*DR-A*FROM*")
    (wcmatch upper "#*DR_A*FROM*")
    (wcmatch upper "#*SW_NOTE*")
    (wcmatch upper "*_SW_NOTE_*")
  )
)

(defun swcad-title-target-frame-block-source-like-children (frame-block / children result child)
  (setq children (swcad-title-block-child-insert-names frame-block))
  (setq result nil)
  (foreach child children
    (if (swcad-title-source-like-frame-child-name-p child)
      (setq result (swcad-title-list-add-unique child result))
    )
  )
  result
)

(defun swcad-title-target-frame-block-contaminated-p (frame-block)
  (if (swcad-title-target-frame-block-source-like-children frame-block) T nil)
)

(defun swcad-title-contaminated-target-frame-blocks (/ result frame-block)
  (setq result nil)
  (foreach frame-block (swcad-title-target-frame-block-candidates)
    (if
      (and
        (swcad-title-block-exists-p frame-block)
        (swcad-title-target-frame-block-contaminated-p frame-block)
      )
      (setq result (append result (list frame-block)))
    )
  )
  result
)

(defun swcad-title-source-title-count ()
  (length (swcad-title-source-title-candidates))
)

(defun swcad-title-frame-only-source-count ()
  (length (swcad-title-frame-only-source-candidates))
)

(defun swcad-title-fast-sheet-summary (/ sources sheet-frames source-count frame-total frame-sheet-counts title-sheet-counts frame-only-count title-with-frame-count title-without-frame-count source bbox title-frame title-frame-sheet sheet-frame sheet-frame-key)
  (setq sources (swcad-title-source-title-candidates))
  (setq sheet-frames (swcad-title-source-frame-candidates))
  (setq source-count (length sources))
  (setq frame-total (length sheet-frames))
  (setq frame-sheet-counts nil)
  (setq title-sheet-counts nil)
  (setq frame-only-count 0)
  (setq title-with-frame-count 0)
  (setq title-without-frame-count 0)
  (foreach sheet-frame sheet-frames
    (setq sheet-frame-key (nth 5 sheet-frame))
    (setq frame-sheet-counts (swcad-title-count-put sheet-frame-key frame-sheet-counts))
    (if (not (swcad-title-frame-has-source-title-p (caddr sheet-frame) sources))
      (setq frame-only-count (+ frame-only-count 1))
    )
  )
  (foreach source sources
    (setq bbox (caddr source))
    (setq title-frame (swcad-title-source-frame-from-candidates bbox sheet-frames))
    (setq title-frame-sheet (if title-frame (nth 5 title-frame) nil))
    (if title-frame-sheet
      (progn
        (setq title-sheet-counts (swcad-title-count-put title-frame-sheet title-sheet-counts))
        (setq title-with-frame-count (+ title-with-frame-count 1))
      )
      (progn
        (setq title-sheet-counts (swcad-title-count-put "<missing-frame>" title-sheet-counts))
        (setq title-without-frame-count (+ title-without-frame-count 1))
      )
    )
  )
  (list
    (cons "source-title-count" source-count)
    (cons "source-frame-count" frame-total)
    (cons "frame-only-count" frame-only-count)
    (cons "title-with-frame-count" title-with-frame-count)
    (cons "title-without-frame-count" title-without-frame-count)
    (cons "frame-sheet-counts" frame-sheet-counts)
    (cons "title-sheet-counts" title-sheet-counts)
  )
)

(defun swcad-title-fast-summary-value (summary key)
  (cdr (assoc key summary))
)

(defun swcad-title-count-value (key counts / result pair)
  (setq result 0)
  (foreach pair counts
    (if (equal (strcase (swcad-title-string (car pair))) (strcase (swcad-title-string key)))
      (setq result (cdr pair))
    )
  )
  result
)

(defun swcad-title-target-frame-sheet-counts (/ counts frame-records record frame-block sheet)
  (setq counts nil)
  (setq frame-records (swcad-title-frame-records))
  (foreach record frame-records
    (setq frame-block (cadr record))
    (setq sheet (swcad-title-sheet-size-from-block-name frame-block))
    (setq counts (swcad-title-count-put (if sheet sheet frame-block) counts))
  )
  counts
)

(defun swcad-title-missing-required-target-sheets (counts required-sheets / result sheet)
  (setq result nil)
  (foreach sheet required-sheets
    (if (= (swcad-title-count-value sheet counts) 0)
      (setq result (append result (list sheet)))
    )
  )
  result
)

(defun swcad-title-required-frame-blocks-from-counts (counts / result pair key frame-block)
  (setq result nil)
  (foreach pair counts
    (setq key (car pair))
    (setq frame-block (swcad-title-target-frame-block-name-for-sheet key))
    (if frame-block
      (setq result (swcad-title-list-add-unique frame-block result))
    )
  )
  result
)

(defun swcad-title-required-native-frame-blocks (summary / result title-counts frame-counts frame-block)
  (setq result nil)
  (setq title-counts (swcad-title-fast-summary-value summary "title-sheet-counts"))
  (setq frame-counts (swcad-title-fast-summary-value summary "frame-sheet-counts"))
  (foreach frame-block (swcad-title-required-frame-blocks-from-counts title-counts)
    (setq result (swcad-title-list-add-unique frame-block result))
  )
  (foreach frame-block (swcad-title-required-frame-blocks-from-counts frame-counts)
    (setq result (swcad-title-list-add-unique frame-block result))
  )
  result
)

(defun swcad-title-missing-required-native-frame-blocks (summary / required missing frame-block)
  (setq required (swcad-title-required-native-frame-blocks summary))
  (setq missing nil)
  (foreach frame-block required
    (if (not (swcad-title-native-example-pair-for-frame-block frame-block))
      (setq missing (append missing (list frame-block)))
    )
  )
  missing
)

(defun swcad-title-summary-title-count-for-frame-block (summary frame-block / sheet)
  (setq sheet (swcad-title-sheet-size-from-block-name frame-block))
  (if sheet
    (swcad-title-count-value sheet (swcad-title-fast-summary-value summary "title-sheet-counts"))
    0
  )
)

(defun swcad-title-summary-frame-only-count-for-frame-block (summary frame-block / sheet frame-count title-count result)
  (setq sheet (swcad-title-sheet-size-from-block-name frame-block))
  (if sheet
    (progn
      (setq frame-count (swcad-title-count-value sheet (swcad-title-fast-summary-value summary "frame-sheet-counts")))
      (setq title-count (swcad-title-count-value sheet (swcad-title-fast-summary-value summary "title-sheet-counts")))
      (setq result (- frame-count title-count))
      (if (< result 0) 0 result)
    )
    0
  )
)

(defun swcad-title-print-missing-native-exemplar-actions (summary missing / frame-block title-count frame-only-count has-any-example risk-message)
  (if missing
    (progn
      (setq has-any-example (if (swcad-title-native-example-title) T nil))
      (swcad-title-princ-line "Next exact-size native GMTITLE action(s):")
      (foreach frame-block missing
        (setq title-count (swcad-title-summary-title-count-for-frame-block summary frame-block))
        (setq frame-only-count (swcad-title-summary-frame-only-count-for-frame-block summary frame-block))
        (cond
          ((> title-count 0)
            (swcad-title-princ-line
              (strcat
                "  "
                frame-block
                ": create/finalize one real title sheet with SWTITLETRANSFERAPPLY, then rerun SWTITLEFASTSTATUS."
              )
            )
            (if (not has-any-example)
              (swcad-title-princ-line "    If this is the first sheet overall, SWTITLETRANSFERBOOTSTRAPFAST can create the first native GMTITLE.")
            )
          )
          ((> frame-only-count 0)
            (swcad-title-princ-line
              (strcat
                "  "
                frame-block
                ": create/finalize one real frame-only sheet with SWTITLEFRAMEONLYAPPLY, then rerun SWTITLEFASTSTATUS."
              )
            )
            (setq risk-message
              (swcad-title-single-a4-frame-only-risk-message
                (car (swcad-title-frame-only-source-candidates))
                frame-block
              )
            )
            (if risk-message
              (progn
                (swcad-title-princ-line (strcat "    Warning: " risk-message))
                (swcad-title-princ-line "    Do not continue with clone/fast batch for this A4 size until the created DR_A4_Outline frame passes the bbox check.")
                (swcad-title-princ-line "    If SWTITLEFRAMEONLYAPPLY aborts with invalid geometry, inspect the GMTITLE A4 selection or repair/check the frame definition before retrying.")
              )
            )
          )
          (T
            (swcad-title-princ-line
              (strcat
                "  "
                frame-block
                ": no remaining source sheet currently requires this size."
              )
            )
          )
        )
      )
    )
  )
)

(defun swcad-title-next-frame-only-target-frame-block (/ source-frame sheet)
  (setq source-frame (car (swcad-title-frame-only-source-candidates)))
  (setq sheet (if source-frame (nth 5 source-frame) nil))
  (swcad-title-target-frame-block-name-for-sheet sheet)
)

(defun swcad-title-next-fast-target-frame-block (/ bootstrap-record)
  (if (> (swcad-title-source-title-count) 0)
    (progn
      (setq bootstrap-record (swcad-title-next-bootstrap-selection-record))
      (if bootstrap-record (cadr bootstrap-record) nil)
    )
    (swcad-title-next-frame-only-target-frame-block)
  )
)

(defun swcad-title-next-fast-target-ready-p (/ frame-block)
  (setq frame-block (swcad-title-next-fast-target-frame-block))
  (if (and frame-block (swcad-title-native-example-pair-for-frame-block frame-block))
    T
    nil
  )
)

(defun swcad-title-print-next-fast-target-readiness (/ frame-block)
  (setq frame-block (swcad-title-next-fast-target-frame-block))
  (if frame-block
    (swcad-title-princ-line
      (strcat
        "Next fast-batch target frame: "
        frame-block
        ", exact-size native exemplar="
        (if (swcad-title-native-example-pair-for-frame-block frame-block) "ready" "missing")
      )
    )
  )
)

(defun swcad-title-print-required-native-exemplars (summary / required missing frame-block)
  (setq required (swcad-title-required-native-frame-blocks summary))
  (setq missing nil)
  (swcad-title-princ-line "Exact-size native GMTITLE exemplars needed by remaining source sheets:")
  (if required
    (foreach frame-block required
      (if (swcad-title-native-example-pair-for-frame-block frame-block)
        (swcad-title-princ-line (strcat "  " frame-block ": ready"))
        (progn
          (setq missing (append missing (list frame-block)))
          (swcad-title-princ-line (strcat "  " frame-block ": missing"))
        )
      )
    )
    (swcad-title-princ-line "  <none>")
  )
  (if missing
    (progn
      (swcad-title-princ-line
        (strcat
          "Missing exact-size native exemplar(s): "
          (swcad-title-list-string missing)
        )
      )
      (swcad-title-princ-line "Create the first sheet of each missing size with native GMTITLE once, then rerun the fast clone batch.")
    )
  )
  (swcad-title-print-missing-native-exemplar-actions summary missing)
  missing
)

(defun swcad-title-print-fast-sheet-summary (summary)
  (swcad-title-princ-line "Detected source summary:")
  (swcad-title-princ-line
    (strcat
      "  source title sheets: "
      (itoa (swcad-title-fast-summary-value summary "source-title-count"))
    )
  )
  (swcad-title-princ-line
    (strcat
      "  source sheet frames: "
      (itoa (swcad-title-fast-summary-value summary "source-frame-count"))
    )
  )
  (swcad-title-princ-line
    (strcat
      "  title sheets with frame: "
      (itoa (swcad-title-fast-summary-value summary "title-with-frame-count"))
    )
  )
  (swcad-title-princ-line
    (strcat
      "  title sheets without frame: "
      (itoa (swcad-title-fast-summary-value summary "title-without-frame-count"))
    )
  )
  (swcad-title-princ-line
    (strcat
      "  frame-only sheets: "
      (itoa (swcad-title-fast-summary-value summary "frame-only-count"))
    )
  )
  (swcad-title-print-counts
    "  source sheet frame counts:"
    (swcad-title-fast-summary-value summary "frame-sheet-counts")
  )
  (swcad-title-print-counts
    "  title sheet counts:"
    (swcad-title-fast-summary-value summary "title-sheet-counts")
  )
)

(defun swcad-title-next-bootstrap-selection-record (/ source source-ename source-bbox source-block source-frame source-frame-bbox source-frame-block build mappings values block-sheet effective-frame-bbox frame-block sheet)
  (setq source (car (swcad-title-source-title-candidates)))
  (if source
    (progn
      (setq source-ename (car source))
      (setq source-bbox (caddr source))
      (setq source-block (cadddr source))
      (setq source-frame (if source-bbox (swcad-title-transfer-source-frame source-bbox source-ename) nil))
      (setq source-frame-bbox (if source-frame (caddr source-frame) nil))
      (setq source-frame-block (if source-frame (swcad-title-effective-insert-name (car source-frame)) nil))
      (setq build (swcad-title-transfer-build-mappings source-bbox source-ename 7.0))
      (setq mappings (car build))
      (setq values (swcad-title-transfer-values mappings))
      (setq block-sheet (swcad-title-source-block-sheet-size source-block source-frame-block))
      (setq effective-frame-bbox (swcad-title-effective-source-frame-bbox source-bbox source-frame-bbox values block-sheet))
      (setq frame-block (swcad-title-target-frame-block-name-for-source source-block source-frame-block values effective-frame-bbox))
      (setq sheet (swcad-title-sheet-size-from-block-name frame-block))
      (list sheet frame-block (swcad-title-target-title-block-name))
    )
    nil
  )
)

(defun swcad-title-print-next-bootstrap-selection (/ record sheet frame-block title-block)
  (setq record (swcad-title-next-bootstrap-selection-record))
  (if record
    (progn
      (setq sheet (car record))
      (setq frame-block (cadr record))
      (setq title-block (caddr record))
      (swcad-title-princ-line "Next native GMTITLE bootstrap selection:")
      (swcad-title-princ-line (strcat "  source sheet: " (if sheet sheet "<unknown>")))
      (swcad-title-princ-line (strcat "  paper/frame: " (if frame-block frame-block "<unknown>")))
      (swcad-title-princ-line (strcat "  title block: " (if title-block title-block "<unknown>")))
    )
  )
)

(defun swcad-title-fast-prerequisite-status (summary contaminated example-title / source-count frame-only-count missing-required frame-records geometry-risk-count overlap-risk-count)
  (setq source-count (swcad-title-fast-summary-value summary "source-title-count"))
  (setq frame-only-count (swcad-title-fast-summary-value summary "frame-only-count"))
  (setq missing-required (swcad-title-missing-required-native-frame-blocks summary))
  (setq frame-records (swcad-title-frame-records))
  (setq geometry-risk-count (swcad-title-target-frame-geometry-warning-count frame-records))
  (setq overlap-risk-count (swcad-title-target-frame-overlap-warning-count frame-records))
  (cond
    ((swcad-title-document-read-only-p) "BLOCKED_READ_ONLY_DOCUMENT")
    ((not (swcad-title-current-dwg-in-work-p)) "BLOCKED_NOT_WORK_COPY")
    ((> geometry-risk-count 0) "WARN_TARGET_FRAME_GEOMETRY_INVALID")
    ((> overlap-risk-count 0) "WARN_TARGET_FRAME_SELECTION_RISK")
    ((and (= source-count 0) (= frame-only-count 0)) "OK_NO_REMAINING_SOURCES")
    ((not example-title) "WAITING_FOR_NATIVE_GMTITLE_EXEMPLAR")
    ((and missing-required (swcad-title-next-fast-target-ready-p)) "PARTIAL_READY_FOR_FAST_BATCH")
    (missing-required "WAITING_FOR_EXACT_SIZE_NATIVE_GMTITLE_EXEMPLARS")
    (T "OK_READY_FOR_FAST_BATCH")
  )
)

(defun swcad-title-bootstrap-first-native-success-p (status)
  (or
    (equal status "APPLIED_TITLE_TRANSFER")
    (equal status "FINALIZED_EXISTING_GMTITLE_TRANSFER")
  )
)

(defun swcad-title-fast-status (/ summary contaminated example-title status frame-records geometry-risk-count overlap-risk-count)
  (swcad-title-open-fast-status-log)
  (setq summary (swcad-title-fast-sheet-summary))
  (setq contaminated (swcad-title-contaminated-target-frame-blocks))
  (setq example-title (swcad-title-native-example-title))
  (setq frame-records (swcad-title-frame-records))
  (setq geometry-risk-count (swcad-title-target-frame-geometry-warning-count frame-records))
  (setq overlap-risk-count (swcad-title-target-frame-overlap-warning-count frame-records))
  (setq status (swcad-title-fast-prerequisite-status summary contaminated example-title))
  (swcad-title-princ-line "----- SWTITLEFASTSTATUS read-only fast batch readiness -----")
  (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (swcad-title-princ-line (strcat "CTAB: " (getvar "CTAB")))
  (swcad-title-print-work-copy-status)
  (swcad-title-princ-line
    (strcat
      "Read-only document: "
      (if (swcad-title-document-read-only-p) "yes" "no")
    )
  )
  (swcad-title-print-fast-sheet-summary summary)
  (if
    (and
      (not example-title)
      (> (swcad-title-fast-summary-value summary "source-title-count") 0)
    )
    (swcad-title-print-next-bootstrap-selection)
  )
  (swcad-title-princ-line
    (strcat
      "Any native GMTITLE title: "
      (swcad-title-native-example-description example-title)
    )
  )
  (swcad-title-print-native-exemplars-by-frame)
  (swcad-title-print-required-native-exemplars summary)
  (swcad-title-print-next-fast-target-readiness)
  (swcad-title-princ-line
    (strcat "Contaminated target frame definitions: " (swcad-title-list-string contaminated))
  )
  (if contaminated
    (swcad-title-princ-line "Warning: these frame definitions may be native/install internals or real pollution. Exact-size clone still requires a same-size native GMTITLE exemplar.")
  )
  (if (or (> geometry-risk-count 0) (> overlap-risk-count 0))
    (swcad-title-print-target-frame-selection-diagnostics frame-records)
  )
  (swcad-title-princ-line (strcat "Result: " status))
  (cond
    ((equal status "WARN_TARGET_FRAME_GEOMETRY_INVALID")
      (swcad-title-princ-line "Next: run SWTITLENATIVEFRAMECHECK, then recreate or repair the bad sheet-size GMTITLE frame before treating this drawing as complete.")
    )
    ((equal status "WARN_TARGET_FRAME_SELECTION_RISK")
      (swcad-title-princ-line "Next: run SWTITLENATIVEFRAMECHECK and verify the overlapping frame/title areas before double-click checks.")
    )
    ((equal status "WAITING_FOR_NATIVE_GMTITLE_EXEMPLAR")
      (swcad-title-princ-line "Next: run SWTITLETRANSFERBOOTSTRAPFAST, or create/finalize one native GMTITLE exemplar and then run SWTITLETRANSFERFASTBATCH.")
    )
    ((equal status "WAITING_FOR_EXACT_SIZE_NATIVE_GMTITLE_EXEMPLARS")
      (swcad-title-princ-line "Next: create the missing same-size native GMTITLE exemplar(s), then run SWTITLETRANSFERFASTBATCH.")
    )
    ((equal status "PARTIAL_READY_FOR_FAST_BATCH")
      (swcad-title-princ-line "Next: run SWTITLETRANSFERFASTBATCH. It will process ready sheet sizes and pause when the next missing size is reached.")
    )
    ((equal status "OK_READY_FOR_FAST_BATCH")
      (swcad-title-princ-line "Next: run SWTITLETRANSFERFASTBATCH.")
    )
  )
  (swcad-title-princ-line "No drawing data was changed.")
  (swcad-title-close-log)
  (princ)
)

(defun swcad-title-next-step (/ summary source-count frame-only-count source-frame-count contaminated example-title frame-records geometry-risk-count overlap-risk-count selection-risk-count target-sheet-counts missing-target-sheets missing-required-native a3a4-records a3a4-count command-text-count next-frame-block)
  (swcad-title-open-next-step-log)
  (setq summary (swcad-title-fast-sheet-summary))
  (setq source-count (swcad-title-fast-summary-value summary "source-title-count"))
  (setq source-frame-count (swcad-title-fast-summary-value summary "source-frame-count"))
  (setq frame-only-count (swcad-title-fast-summary-value summary "frame-only-count"))
  (setq contaminated (swcad-title-contaminated-target-frame-blocks))
  (setq example-title (swcad-title-native-example-title))
  (setq frame-records (swcad-title-frame-records))
  (setq geometry-risk-count (swcad-title-target-frame-geometry-warning-count frame-records))
  (setq overlap-risk-count (swcad-title-target-frame-overlap-warning-count frame-records))
  (setq selection-risk-count (+ geometry-risk-count overlap-risk-count))
  (setq target-sheet-counts (swcad-title-target-frame-sheet-counts))
  (setq missing-target-sheets (swcad-title-missing-required-target-sheets target-sheet-counts '("A2" "A3" "A4")))
  (setq missing-required-native (swcad-title-missing-required-native-frame-blocks summary))
  (setq a3a4-records (swcad-title-a3a4-native-upgrade-candidate-records))
  (setq a3a4-count (length a3a4-records))
  (setq command-text-count (swcad-title-command-text-residue-count))

  (swcad-title-princ-line "----- SWTITLENEXTSTEP read-only workflow guide -----")
  (swcad-title-print-loaded-version)
  (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (swcad-title-princ-line (strcat "CTAB: " (getvar "CTAB")))
  (swcad-title-print-work-copy-status)
  (swcad-title-princ-line (strcat "Read-only document: " (if (swcad-title-document-read-only-p) "yes" "no")))
  (swcad-title-princ-line (strcat "Remaining source title sheets: " (itoa source-count)))
  (swcad-title-princ-line (strcat "Remaining source sheet frames: " (itoa source-frame-count)))
  (swcad-title-princ-line (strcat "Remaining frame-only sheets: " (itoa frame-only-count)))
  (swcad-title-print-counts "Visible target frame counts by sheet:" target-sheet-counts)
  (swcad-title-print-string-list "Missing required A2/A3/A4 target sheets:" missing-target-sheets)
  (swcad-title-princ-line (strcat "A3/A4 native upgrade candidates: " (itoa a3a4-count)))
  (swcad-title-princ-line (strcat "Possible accidental command text entities: " (itoa command-text-count)))
  (swcad-title-princ-line (strcat "Selection/geometry risk warnings: " (itoa selection-risk-count)))
  (swcad-title-princ-line (strcat "Contaminated target frame definitions: " (swcad-title-list-string contaminated)))
  (swcad-title-princ-line (strcat "Any native GMTITLE title: " (swcad-title-native-example-description example-title)))
  (if a3a4-records
    (progn
      (swcad-title-princ-line "A3/A4 candidate detail:")
      (swcad-title-print-a3a4-native-upgrade-candidates)
    )
  )

  (cond
    ((swcad-title-document-read-only-p)
      (swcad-title-apply-result "NEXT_OPEN_WRITABLE_WORK_COPY")
      (swcad-title-princ-line "Next: open a writable copy under Documents/CAD tool/work before applying changes.")
    )
    ((> command-text-count 0)
      (swcad-title-apply-result "NEXT_REVIEW_ACCIDENTAL_COMMAND_TEXT")
      (swcad-title-princ-line "Reason: command text may have been inserted into the drawing while CAD was in a text/input state.")
      (swcad-title-princ-line "Next: run SWTITLECOMMANDTEXTSCAN and review the listed TEXT/MTEXT handles before continuing.")
      (swcad-title-princ-line "If the listed items are accidental command leftovers in a work copy, run SWTITLECOMMANDTEXTCLEANSAFE.")
      (swcad-title-princ-line "Do not run apply/upgrade commands until those are confirmed or cleaned in a work copy.")
    )
    ((> geometry-risk-count 0)
      (swcad-title-apply-result "NEXT_REVIEW_TARGET_FRAME_GEOMETRY")
      (swcad-title-princ-line "Next: run SWTITLENATIVEFRAMECHECK and inspect invalid target frame geometry before continuing.")
    )
    ((> overlap-risk-count 0)
      (swcad-title-apply-result "NEXT_REVIEW_TARGET_FRAME_SELECTION")
      (swcad-title-princ-line "Next: run SWTITLENATIVEFRAMECHECK and resolve overlapping/oversized target frame selection risk.")
    )
    ((> a3a4-count 0)
      (swcad-title-apply-result "NEXT_UPGRADE_A3_A4_NATIVE")
      (if (> frame-only-count 0)
        (progn
          (swcad-title-princ-line
            (strcat
              "Note: "
              (itoa frame-only-count)
              " frame-only source sheet(s) still remain, usually A4 sheets without a source title block."
            )
          )
          (swcad-title-princ-line "SWTITLEUPGRADENATIVEA3A4BATCH does not create those missing A4 target sheets.")
          (swcad-title-princ-line "It only replaces already-created A3/A4 GMTITLE target pairs whose double-click behavior is not trusted.")
          (swcad-title-princ-line "After the listed A3/A4 native upgrades, run SWTITLEFASTSTATUS and handle remaining frame-only sheets with SWTITLEFRAMEONLYAPPLY or SWTITLETRANSFERFASTBATCH.")
        )
      )
      (if (> a3a4-count 1)
        (progn
          (swcad-title-princ-line "Next: run SWTITLEUPGRADENATIVEA3A4BATCH and press Enter to process every listed A3/A4 candidate by default.")
          (swcad-title-princ-line (strcat "There are " (itoa a3a4-count) " A3/A4 candidate(s). SWTITLEUPGRADENATIVEA3A4BATCH now defaults to that full count; press Enter there to process all listed candidates."))
          (swcad-title-princ-line "It will open the native GMTITLE dialog for each selected A3/A4 candidate, then copy the existing title values and delete the old clone/non-native pair.")
          (swcad-title-princ-line "In each GMTITLE dialog, choose the printed DR_A*_Outline paper and DR_titlea_3rd. Leave Frame positioning ON and turn Object move OFF.")
          (swcad-title-princ-line "For a one-sheet cautious test instead, run SWTITLEA3A4PREP, create GMTITLE normally, then run SWTITLEA3A4FINISH.")
        )
        (progn
          (swcad-title-princ-line "Next: run SWTITLEA3A4PREP.")
          (swcad-title-princ-line "Then run normal GMTITLE, choose the printed DR_A*_Outline paper and DR_titlea_3rd, leave Frame positioning ON, turn Object move OFF, and use the printed insertion point.")
          (swcad-title-princ-line "After GMTITLE creates the pair, run SWTITLEA3A4FINISH and then double-click the upgraded title block.")
        )
      )
    )
    ((or (> source-count 0) (> frame-only-count 0))
      (cond
        ((not example-title)
          (swcad-title-apply-result "NEXT_CREATE_FIRST_NATIVE_GMTITLE")
          (swcad-title-princ-line "Next: run SWTITLETRANSFERBOOTSTRAPFAST.")
        )
        ((and missing-required-native (not (swcad-title-next-fast-target-ready-p)))
          (swcad-title-apply-result "NEXT_CREATE_MISSING_NATIVE_EXEMPLAR")
          (swcad-title-print-required-native-exemplars summary)
          (swcad-title-princ-line "Next: create the missing exact-size native GMTITLE exemplar before fast batch.")
        )
        (T
          (setq next-frame-block (swcad-title-next-fast-target-frame-block))
          (swcad-title-apply-result "NEXT_RUN_FAST_BATCH")
          (swcad-title-princ-line (strcat "Next: run SWTITLETRANSFERFASTBATCH. Next target frame=" (if next-frame-block next-frame-block "<unknown>")))
        )
      )
    )
    (missing-target-sheets
      (swcad-title-apply-result "NEXT_CREATE_MISSING_TARGET_SHEET")
      (swcad-title-princ-line "Next: create/finalize the missing target sheet size before final checks.")
    )
    (T
      (swcad-title-apply-result "NEXT_FINAL_VERIFY_AND_DOUBLE_CLICK")
      (swcad-title-princ-line "Next: run SWTITLEGMTITLEVERIFYALL.")
      (swcad-title-princ-line "Then run SWTITLENATIVEFRAMECHECK.")
      (swcad-title-princ-line "Final manual check: double-click representative A2, A3, and A4 title blocks in GstarCAD.")
    )
  )
  (swcad-title-princ-line "No drawing data was changed.")
  (swcad-title-close-log)
  (princ)
)

(defun swcad-title-status-refresh-summary (/ summary source-count source-frame-count frame-only-count target-sheet-counts missing-target-sheets a3a4-count command-text-count geometry-risk-count overlap-risk-count frame-records status)
  (swcad-title-open-status-refresh-log)
  (setq summary (swcad-title-fast-sheet-summary))
  (setq source-count (swcad-title-fast-summary-value summary "source-title-count"))
  (setq source-frame-count (swcad-title-fast-summary-value summary "source-frame-count"))
  (setq frame-only-count (swcad-title-fast-summary-value summary "frame-only-count"))
  (setq target-sheet-counts (swcad-title-target-frame-sheet-counts))
  (setq missing-target-sheets (swcad-title-missing-required-target-sheets target-sheet-counts '("A2" "A3" "A4")))
  (setq a3a4-count (length (swcad-title-a3a4-native-upgrade-candidate-records)))
  (setq command-text-count (swcad-title-command-text-residue-count))
  (setq frame-records (swcad-title-frame-records))
  (setq geometry-risk-count (swcad-title-target-frame-geometry-warning-count frame-records))
  (setq overlap-risk-count (swcad-title-target-frame-overlap-warning-count frame-records))
  (swcad-title-princ-line "----- SWTITLESTATUSREFRESH summary -----")
  (swcad-title-print-loaded-version)
  (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (swcad-title-princ-line (strcat "CTAB: " (getvar "CTAB")))
  (swcad-title-print-work-copy-status)
  (swcad-title-princ-line (strcat "Remaining source title sheets: " (itoa source-count)))
  (swcad-title-princ-line (strcat "Remaining source sheet frames: " (itoa source-frame-count)))
  (swcad-title-princ-line (strcat "Remaining frame-only sheets: " (itoa frame-only-count)))
  (swcad-title-print-counts "Visible target frame counts by sheet:" target-sheet-counts)
  (swcad-title-print-string-list "Missing required A2/A3/A4 target sheets:" missing-target-sheets)
  (swcad-title-princ-line (strcat "A3/A4 native upgrade candidates: " (itoa a3a4-count)))
  (swcad-title-princ-line (strcat "Possible accidental command text entities: " (itoa command-text-count)))
  (swcad-title-princ-line (strcat "Target frame geometry warnings: " (itoa geometry-risk-count)))
  (swcad-title-princ-line (strcat "Target frame overlap warnings: " (itoa overlap-risk-count)))
  (setq status
    (cond
      ((> command-text-count 0) "NEXT_REVIEW_ACCIDENTAL_COMMAND_TEXT")
      ((> geometry-risk-count 0) "NEXT_REVIEW_TARGET_FRAME_GEOMETRY")
      ((> overlap-risk-count 0) "NEXT_REVIEW_TARGET_FRAME_SELECTION")
      ((> a3a4-count 0) "NEXT_UPGRADE_A3_A4_NATIVE")
      ((or (> source-count 0) (> frame-only-count 0)) "NEXT_TRANSFER_REMAINING_SOURCE_SHEETS")
      (missing-target-sheets "NEXT_CREATE_MISSING_TARGET_SHEET")
      (T "NEXT_FINAL_VERIFY_AND_DOUBLE_CLICK")
    )
  )
  (swcad-title-apply-result status)
  (cond
    ((equal status "NEXT_UPGRADE_A3_A4_NATIVE")
      (swcad-title-princ-line "Next command: SWTITLEUPGRADENATIVEA3A4BATCH.")
      (swcad-title-princ-line (strcat "It defaults to all " (itoa a3a4-count) " currently listed A3/A4 candidate(s)."))
      (swcad-title-princ-line "This fixes native double-click behavior for already-created A3/A4 GMTITLE target pairs.")
      (if (> frame-only-count 0)
        (swcad-title-princ-line "Frame-only A4 source sheets still remain; handle them after this native upgrade.")
      )
    )
    ((equal status "NEXT_TRANSFER_REMAINING_SOURCE_SHEETS")
      (if (> frame-only-count 0)
        (swcad-title-princ-line "Next command: SWTITLEFRAMEONLYAPPLY for the first frame-only sheet, then SWTITLETRANSFERFASTBATCH.")
        (swcad-title-princ-line "Next command: SWTITLETRANSFERFASTBATCH.")
      )
    )
    ((equal status "NEXT_FINAL_VERIFY_AND_DOUBLE_CLICK")
      (swcad-title-princ-line "Next command: SWTITLEGMTITLEVERIFYALL, then SWTITLENATIVEFRAMECHECK.")
      (swcad-title-princ-line "Final manual check: double-click representative A2, A3, and A4 DR_titlea_3rd title blocks.")
    )
    (T
      (swcad-title-princ-line "Next: follow the detailed log named by the status above.")
    )
  )
  (swcad-title-princ-line "Logs refreshed by SWTITLESTATUSREFRESH:")
  (swcad-title-princ-line "  work/swcad_title_next_step_last.txt")
  (swcad-title-princ-line "  work/swcad_title_native_upgrade_last.txt")
  (swcad-title-princ-line "  work/swcad_title_gmtitle_verify_all_last.txt")
  (swcad-title-princ-line "  work/swcad_title_native_frame_check_last.txt")
  (swcad-title-princ-line "No drawing data was changed.")
  (swcad-title-close-log)
  (princ)
)

(defun swcad-title-safe-vla-object (ename / result)
  (setq result (vl-catch-all-apply 'vlax-ename->vla-object (list ename)))
  (if (vl-catch-all-error-p result)
    nil
    result
  )
)

(defun swcad-title-safe-vla-get (object property / result)
  (if object
    (progn
      (setq result (vl-catch-all-apply 'vlax-get-property (list object property)))
      (if (vl-catch-all-error-p result)
        nil
        result
      )
    )
    nil
  )
)

(defun swcad-title-block-definition-object (block-name / blocks result)
  (if (and block-name (swcad-title-block-exists-p block-name))
    (progn
      (setq blocks (vla-get-Blocks (swcad-title-doc)))
      (setq result (vl-catch-all-apply 'vla-Item (list blocks block-name)))
      (if (vl-catch-all-error-p result)
        nil
        result
      )
    )
    nil
  )
)

(defun swcad-title-block-definition-count (block-name / block count item)
  (setq block (swcad-title-block-definition-object block-name))
  (if block
    (progn
      (setq count 0)
      (vlax-for item block
        (setq count (+ count 1))
      )
      count
    )
    nil
  )
)

(defun swcad-title-effective-insert-name (ename / object name)
  (setq object (swcad-title-safe-vla-object ename))
  (if object
    (setq name (swcad-title-vla-block-name object))
    (setq name (swcad-title-dxf-value (entget ename '("*")) 2))
  )
  (swcad-title-string name)
)

(defun swcad-title-entity-type-name (ename / data)
  (setq data (if ename (entget ename '("*")) nil))
  (strcase (swcad-title-string (swcad-title-dxf-value data 0)))
)

(defun swcad-title-owner-ename (ename / data owner)
  (setq data (if ename (entget ename '("*")) nil))
  (setq owner (swcad-title-dxf-value data 330))
  (if (and owner (entget owner '("*")))
    owner
    nil
  )
)

(defun swcad-title-enclosing-insert-ename (ename / current owner guard)
  (setq current ename)
  (setq guard 0)
  (while
    (and
      current
      (< guard 8)
      (not (equal (swcad-title-entity-type-name current) "INSERT"))
    )
    (setq owner (swcad-title-owner-ename current))
    (if owner
      (setq current owner)
      (setq current nil)
    )
    (setq guard (+ guard 1))
  )
  (if (and current (equal (swcad-title-entity-type-name current) "INSERT"))
    current
    nil
  )
)

(defun swcad-title-find-insert-by-effective-name (block-name / target ss index total ename found)
  (setq target (strcase (swcad-title-string block-name)))
  (setq ss (ssget "_X" '((0 . "INSERT"))))
  (setq total (if ss (sslength ss) 0))
  (setq index 0)
  (setq found nil)
  (while (and (< index total) (not found))
    (setq ename (ssname ss index))
    (if (equal (strcase (swcad-title-effective-insert-name ename)) target)
      (setq found ename)
    )
    (setq index (+ index 1))
  )
  found
)

(defun swcad-title-count-inserts-by-effective-name (block-name / target ss index total ename count)
  (setq target (strcase (swcad-title-string block-name)))
  (setq ss (ssget "_X" '((0 . "INSERT"))))
  (setq total (if ss (sslength ss) 0))
  (setq index 0)
  (setq count 0)
  (while (< index total)
    (setq ename (ssname ss index))
    (if (equal (strcase (swcad-title-effective-insert-name ename)) target)
      (setq count (+ count 1))
    )
    (setq index (+ index 1))
  )
  count
)

(defun swcad-title-inserts-by-effective-name (block-name / target ss index total ename result)
  (setq target (strcase (swcad-title-string block-name)))
  (setq ss (ssget "_X" '((0 . "INSERT"))))
  (setq total (if ss (sslength ss) 0))
  (setq index 0)
  (setq result nil)
  (while (< index total)
    (setq ename (ssname ss index))
    (if (equal (strcase (swcad-title-effective-insert-name ename)) target)
      (setq result (append result (list ename)))
    )
    (setq index (+ index 1))
  )
  result
)

(defun swcad-title-attribute-value (attribute / value)
  (setq value (vl-catch-all-apply 'vla-get-TextString (list attribute)))
  (if (vl-catch-all-error-p value) "" value)
)

(defun swcad-title-title-attribute-pairs (insert-object / attrs attr result)
  (setq attrs (swcad-title-get-insert-attributes insert-object))
  (setq result nil)
  (foreach attr attrs
    (setq result
      (append
        result
        (list
          (cons
            (swcad-title-attribute-tag attr)
            (swcad-title-attribute-value attr)
          )
        )
      )
    )
  )
  result
)

(defun swcad-title-missing-template-tags (attr-pairs / missing slot tag)
  (setq missing nil)
  (foreach slot *swcad-title-transfer-template*
    (setq tag (car slot))
    (if (not (assoc tag attr-pairs))
      (setq missing (append missing (list tag)))
    )
  )
  missing
)

(defun swcad-title-nonempty-attribute-count (attr-pairs / count pair value)
  (setq count 0)
  (foreach pair attr-pairs
    (setq value (vl-string-trim " \t\r\n" (swcad-title-string (cdr pair))))
    (if (> (strlen value) 0)
      (setq count (+ count 1))
    )
  )
  count
)

(defun swcad-title-xdata-records (ename / data result pair item)
  (setq data (entget ename '("*")))
  (setq result nil)
  (foreach pair data
    (if (and (listp pair) (= (car pair) -3))
      (foreach item (cdr pair)
        (if (listp item)
          (setq result (append result (list item)))
        )
      )
    )
  )
  result
)

(defun swcad-title-xdata-record-app-name (record)
  (if (and (listp record) (= (type (car record)) 'STR))
    (car record)
    ""
  )
)

(defun swcad-title-xdata-record-by-app (ename app / records target result record)
  (setq records (swcad-title-xdata-records ename))
  (setq target (strcase (swcad-title-string app)))
  (setq result nil)
  (foreach record records
    (if
      (and
        (not result)
        (equal (strcase (swcad-title-xdata-record-app-name record)) target)
      )
      (setq result record)
    )
  )
  result
)

(defun swcad-title-xdata-text-values (record / result pair)
  (setq result nil)
  (foreach pair (cdr record)
    (if (and (listp pair) (= (car pair) 1000))
      (setq result (append result (list (swcad-title-string (cdr pair)))))
    )
  )
  result
)

(defun swcad-title-remove-xdata-app-from-data (data app / target result pair kept record)
  (setq target (strcase (swcad-title-string app)))
  (setq result nil)
  (foreach pair data
    (if (and (listp pair) (= (car pair) -3))
      (progn
        (setq kept nil)
        (foreach record (cdr pair)
          (if (not (equal (strcase (swcad-title-xdata-record-app-name record)) target))
            (setq kept (append kept (list record)))
          )
        )
        (if kept
          (setq result (append result (list (cons -3 kept))))
        )
      )
      (setq result (append result (list pair)))
    )
  )
  result
)

(defun swcad-title-ensure-regapp (app / result)
  (if (tblsearch "APPID" app)
    T
    (progn
      (setq result (vl-catch-all-apply 'regapp (list app)))
      (not (vl-catch-all-error-p result))
    )
  )
)

(defun swcad-title-set-exemplar-xdata (ename frame-block role / app marker data clean record result)
  (setq app *swcad-title-exemplar-xdata-app*)
  (setq marker *swcad-title-exemplar-xdata-marker*)
  (if
    (and
      ename
      (swcad-title-ensure-regapp app)
      (setq data (entget ename '("*")))
    )
    (progn
      (setq clean (swcad-title-remove-xdata-app-from-data data app))
      (setq record
        (list
          app
          (cons 1000 marker)
          (cons 1000 *swcad-title-scale-version*)
          (cons 1000 (swcad-title-string frame-block))
          (cons 1000 (swcad-title-string role))
        )
      )
      (setq result
        (vl-catch-all-apply
          'entmod
          (list (append clean (list (cons -3 (list record)))))
        )
      )
      (if (vl-catch-all-error-p result)
        nil
        (progn
          (entupd ename)
          T
        )
      )
    )
    nil
  )
)

(defun swcad-title-mark-native-exemplar-pair (title-ename frame-ename frame-block role / title-ok frame-ok)
  (setq title-ok (swcad-title-set-exemplar-xdata title-ename frame-block role))
  (setq frame-ok (swcad-title-set-exemplar-xdata frame-ename frame-block role))
  (and title-ok frame-ok)
)

(defun swcad-title-trusted-native-exemplar-entity-p (ename frame-block / record values marker target marker-found frame-found value)
  (setq record (swcad-title-xdata-record-by-app ename *swcad-title-exemplar-xdata-app*))
  (setq values (if record (swcad-title-xdata-text-values record) nil))
  (setq marker (strcase *swcad-title-exemplar-xdata-marker*))
  (setq target (strcase (swcad-title-string frame-block)))
  (setq marker-found nil)
  (setq frame-found nil)
  (foreach value values
    (cond
      ((equal (strcase (swcad-title-string value)) marker)
        (setq marker-found T)
      )
      ((equal (strcase (swcad-title-string value)) target)
        (setq frame-found T)
      )
    )
  )
  (and marker-found frame-found)
)

(defun swcad-title-trusted-native-exemplar-title-p (title-ename frame-block)
  (swcad-title-trusted-native-exemplar-entity-p title-ename frame-block)
)

(defun swcad-title-trusted-native-exemplar-frame-p (frame-ename frame-block)
  (swcad-title-trusted-native-exemplar-entity-p frame-ename frame-block)
)

(defun swcad-title-trusted-native-exemplar-pair-p (title-ename frame-ename frame-block)
  (and
    (swcad-title-trusted-native-exemplar-title-p title-ename frame-block)
    (swcad-title-trusted-native-exemplar-frame-p frame-ename frame-block)
  )
)

(defun swcad-title-exemplar-xdata-values (ename / record)
  (setq record (swcad-title-xdata-record-by-app ename *swcad-title-exemplar-xdata-app*))
  (if record
    (swcad-title-xdata-text-values record)
    nil
  )
)

(defun swcad-title-exemplar-role (ename / values)
  (setq values (swcad-title-exemplar-xdata-values ename))
  (if (and values (>= (length values) 4))
    (swcad-title-string (nth 3 values))
    ""
  )
)

(defun swcad-title-exemplar-clone-entity-p (ename)
  (equal (strcase (swcad-title-exemplar-role ename)) "CLONE")
)

(defun swcad-title-exemplar-clone-role-p (role)
  (equal (strcase (swcad-title-string role)) "CLONE")
)

(defun swcad-title-exemplar-moved-unverified-role-p (role / upper)
  (setq upper (strcase (swcad-title-string role)))
  (wcmatch upper "*MOVED*UNVERIFIED*")
)

(defun swcad-title-exemplar-legacy-uncertain-native-role-p (role / upper)
  (setq upper (strcase (swcad-title-string role)))
  (or
    (equal upper "NATIVE-FINALIZE")
    (equal upper "NATIVE-FINALIZE-MANUAL")
    (equal upper "NATIVE-FRAME-ONLY")
    (equal upper "NATIVE-FRAME-ONLY-APPLY")
    (equal upper "NATIVE-FRAME-ONLY-FINALIZE")
    (swcad-title-exemplar-moved-unverified-role-p role)
  )
)

(defun swcad-title-exemplar-safe-native-source-role-p (role)
  (and
    (not (swcad-title-exemplar-clone-role-p role))
    (not (swcad-title-exemplar-legacy-uncertain-native-role-p role))
  )
)

(defun swcad-title-exemplar-native-role-p (role / upper)
  (setq upper (strcase (swcad-title-string role)))
  (or
    (wcmatch upper "NATIVE-*")
    (equal upper "NATIVE")
  )
)

(defun swcad-title-exemplar-native-entity-p (ename)
  (swcad-title-exemplar-native-role-p (swcad-title-exemplar-role ename))
)

(defun swcad-title-role-check-record (role expected-legacy expected-safe / legacy safe native clone moved ok)
  (setq legacy (swcad-title-exemplar-legacy-uncertain-native-role-p role))
  (setq safe (swcad-title-exemplar-safe-native-source-role-p role))
  (setq native (swcad-title-exemplar-native-role-p role))
  (setq clone (swcad-title-exemplar-clone-role-p role))
  (setq moved (swcad-title-exemplar-moved-unverified-role-p role))
  (setq ok (and (equal legacy expected-legacy) (equal safe expected-safe)))
  (swcad-title-princ-line
    (strcat
      "role="
      role
      ", native="
      (if native "yes" "no")
      ", clone="
      (if clone "yes" "no")
      ", moved-unverified="
      (if moved "yes" "no")
      ", legacy-uncertain="
      (if legacy "yes" "no")
      ", safe-native-source="
      (if safe "yes" "no")
      ", expected-legacy="
      (if expected-legacy "yes" "no")
      ", expected-safe="
      (if expected-safe "yes" "no")
      ", result="
      (if ok "OK" "FAIL")
    )
  )
  ok
)

(defun swcad-title-role-check (/ failures item)
  (swcad-title-open-role-check-log)
  (swcad-title-princ-line "----- SWTITLEROLECHECK read-only native role classification check -----")
  (swcad-title-print-loaded-version)
  (setq failures 0)
  (foreach item
    '(
      ("native-apply" nil T)
      ("native-upgrade" nil T)
      ("native-finalize" T nil)
      ("native-finalize-manual" T nil)
      ("native-frame-only" T nil)
      ("native-frame-only-apply" T nil)
      ("native-frame-only-finalize" T nil)
      ("native-moved-unverified" T nil)
      ("native-frame-only-moved-unverified" T nil)
      ("clone" nil nil)
    )
    (if (not (swcad-title-role-check-record (car item) (cadr item) (caddr item)))
      (setq failures (+ failures 1))
    )
  )
  (if (= failures 0)
    (swcad-title-apply-result "OK_ROLE_CLASSIFICATION")
    (swcad-title-apply-result "FAIL_ROLE_CLASSIFICATION")
  )
  (swcad-title-princ-line "Important: native-finalize and native-frame-only must be legacy-uncertain=yes.")
  (swcad-title-princ-line "If they are safe-native-source=yes, A3/A4 GMPOWEREDIT failures can be hidden by stale logic.")
  (swcad-title-princ-line "No drawing data was changed.")
  (swcad-title-close-log)
  (princ)
)

(defun swcad-title-xdata-handle-values (record / result pair value)
  (setq result nil)
  (foreach pair (cdr record)
    (if (and (listp pair) (member (car pair) '(1000 1005)))
      (progn
        (setq value (swcad-title-string (cdr pair)))
        (if (and (> (strlen value) 0) (handent value))
          (setq result (append result (list value)))
        )
      )
    )
  )
  result
)

(defun swcad-title-gmtitle-native-xdata-info (title-ename / records record app handles found-handles)
  (setq records (swcad-title-xdata-records title-ename))
  (setq found-handles nil)
  (foreach record records
    (setq app (strcase (swcad-title-xdata-record-app-name record)))
    (if (equal app "GENIUS_GENOREF_13")
      (progn
        (setq handles (swcad-title-xdata-handle-values record))
        (foreach handle handles
          (if (not (member handle found-handles))
            (setq found-handles (append found-handles (list handle)))
          )
        )
      )
    )
  )
  found-handles
)

(defun swcad-title-native-link-target-kind (handle / ename data etype name)
  (setq ename (if (> (strlen (swcad-title-string handle)) 0) (handent handle) nil))
  (cond
    ((not ename) "missing")
    (T
      (setq data (entget ename '("*")))
      (if data
        (progn
          (setq etype (swcad-title-string (swcad-title-dxf-value data 0)))
          (cond
            ((= (strlen etype) 0) "internal")
            ((equal etype "INSERT")
              (setq name (swcad-title-effective-insert-name ename))
              (cond
                ((swcad-title-native-target-frame-name-p name) "visible-target-frame")
                ((swcad-title-native-target-title-name-p name) "visible-target-title")
                (T "visible-insert")
              )
            )
            (T etype)
          )
        )
        "internal-no-entget"
      )
    )
  )
)

(defun swcad-title-native-link-target-kinds (title-ename / handles result handle)
  (setq handles (swcad-title-gmtitle-native-xdata-info title-ename))
  (setq result nil)
  (foreach handle handles
    (setq result
      (swcad-title-list-add-unique
        (swcad-title-native-link-target-kind handle)
        result
      )
    )
  )
  result
)

(defun swcad-title-target-title-native-link-counts (/ title-name titles counts title handles handle)
  (setq title-name (swcad-title-target-title-block-name))
  (setq titles (swcad-title-inserts-by-effective-name title-name))
  (setq counts nil)
  (foreach title titles
    (setq handles (swcad-title-gmtitle-native-xdata-info title))
    (foreach handle handles
      (if (> (strlen (swcad-title-string handle)) 0)
        (setq counts (swcad-title-count-frame-link handle counts))
      )
    )
  )
  counts
)

(defun swcad-title-native-link-handle-shared-p (ename counts / handles result handle pair)
  (setq handles (if ename (swcad-title-gmtitle-native-xdata-info ename) nil))
  (setq result nil)
  (foreach handle handles
    (setq pair (assoc (strcase (swcad-title-string handle)) counts))
    (if (and pair (> (cdr pair) 1))
      (setq result T)
    )
  )
  result
)

(defun swcad-title-target-title-native-link-shared-p (title-ename)
  (swcad-title-native-link-handle-shared-p
    title-ename
    (swcad-title-target-title-native-link-counts)
  )
)

(defun swcad-title-native-link-visible-frame-p (title-ename / kinds)
  (setq kinds (swcad-title-native-link-target-kinds title-ename))
  (if (member "visible-target-frame" kinds) T nil)
)

(defun swcad-title-ename-handle (ename / data)
  (if ename
    (progn
      (setq data (entget ename '("*")))
      (strcase (swcad-title-string (swcad-title-dxf-value data 5)))
    )
    ""
  )
)

(defun swcad-title-set-pending-gmtitle-pair (title-ename frame-ename frame-block role)
  (setq *swcad-title-pending-native-title-ename* title-ename)
  (setq *swcad-title-pending-native-frame-ename* frame-ename)
  (setq *swcad-title-pending-native-frame-block* frame-block)
  (setq *swcad-title-pending-gmtitle-role* role)
  T
)

(defun swcad-title-set-pending-native-gmtitle-pair (title-ename frame-ename frame-block)
  (swcad-title-set-pending-gmtitle-pair title-ename frame-ename frame-block "native")
)

(defun swcad-title-clear-pending-native-gmtitle-pair ()
  (setq *swcad-title-pending-native-title-ename* nil)
  (setq *swcad-title-pending-native-frame-ename* nil)
  (setq *swcad-title-pending-native-frame-block* nil)
  (setq *swcad-title-pending-gmtitle-role* nil)
  nil
)

(defun swcad-title-pending-native-gmtitle-pair-for-block (frame-block / title frame expected actual-title actual-frame role)
  (setq title *swcad-title-pending-native-title-ename*)
  (setq frame *swcad-title-pending-native-frame-ename*)
  (setq expected (strcase (swcad-title-string *swcad-title-pending-native-frame-block*)))
  (setq role (swcad-title-string *swcad-title-pending-gmtitle-role*))
  (setq actual-title (if title (swcad-title-effective-insert-name title) ""))
  (setq actual-frame (if frame (swcad-title-effective-insert-name frame) ""))
  (if
    (and
      title
      frame
      (swcad-title-safe-vla-object title)
      (swcad-title-safe-vla-object frame)
      (equal expected (strcase (swcad-title-string frame-block)))
      (swcad-title-native-target-title-name-p actual-title)
      (swcad-title-frame-name-matches-p actual-frame frame-block)
    )
    (list title frame role)
    nil
  )
)

(defun swcad-title-title-linked-to-frame-p (title-ename frame-ename / frame-handle handles result handle)
  (setq frame-handle (swcad-title-ename-handle frame-ename))
  (setq handles (swcad-title-gmtitle-native-xdata-info title-ename))
  (setq result nil)
  (foreach handle handles
    (if (equal (strcase (swcad-title-string handle)) frame-handle)
      (setq result T)
    )
  )
  result
)

(defun swcad-title-title-default-gmtitle-p (title-ename frame-block / object attrs attr tag value current-path result)
  (setq object (swcad-title-safe-vla-object title-ename))
  (setq attrs (if object (swcad-title-get-insert-attributes object) nil))
  (setq current-path (strcase (swcad-title-current-dwg-full-path)))
  (setq result nil)
  (foreach attr attrs
    (setq tag (strcase (swcad-title-attribute-tag attr)))
    (setq value (strcase (vl-string-trim " \t\r\n" (swcad-title-attribute-value attr))))
    (if
      (or
        (and (equal tag "GEN-TITLE-SIZ{6.7}") (equal value (strcase (swcad-title-string frame-block))))
        (and (equal tag "GEN-TITLE-DWG{23}") (equal value current-path))
        (and (equal tag "GEN-TITLE-NR{23}") (equal value "XXX"))
      )
      (setq result T)
    )
  )
  result
)

(defun swcad-title-title-for-native-frame (frame-ename frame-block / titles title result)
  (setq titles (swcad-title-inserts-by-effective-name (swcad-title-target-title-block-name)))
  (setq result nil)
  (foreach title titles
    (if
      (and
        (not result)
        (swcad-title-title-linked-to-frame-p title frame-ename)
        (swcad-title-title-default-gmtitle-p title frame-block)
      )
      (setq result title)
    )
  )
  (if (not result)
    (foreach title titles
      (if
        (and
          (not result)
          (swcad-title-title-linked-to-frame-p title frame-ename)
        )
        (setq result title)
      )
    )
  )
  result
)

(defun swcad-title-default-gmtitle-frame-location-p (frame-ename / bbox)
  (setq bbox (swcad-title-safe-bbox frame-ename))
  (and
    bbox
    (< (swcad-title-abs (car bbox)) 5.0)
    (< (swcad-title-abs (cadr bbox)) 5.0)
  )
)

(defun swcad-title-title-near-frame-p (title-ename frame-ename / title-bbox frame-bbox expanded)
  (setq title-bbox (swcad-title-safe-bbox title-ename))
  (setq frame-bbox (swcad-title-safe-bbox frame-ename))
  (setq expanded (if frame-bbox (swcad-title-expand-bbox frame-bbox 10.0) nil))
  (and
    title-bbox
    expanded
    (swcad-title-bbox-contains-bbox-p expanded title-bbox 0.0)
  )
)

(defun swcad-title-default-location-title-for-frame (frame-ename frame-block / titles title result)
  (setq titles (swcad-title-inserts-by-effective-name (swcad-title-target-title-block-name)))
  (setq result nil)
  (foreach title titles
    (if
      (and
        (not result)
        (swcad-title-title-default-gmtitle-p title frame-block)
      )
      (setq result title)
    )
  )
  (if (not result)
    (foreach title titles
      (if
        (and
          (not result)
          (swcad-title-default-gmtitle-frame-location-p frame-ename)
          (swcad-title-title-near-frame-p title frame-ename)
        )
        (setq result title)
      )
    )
  )
  result
)

(defun swcad-title-unfinalized-gmtitle-frame-score (frame-ename / bbox)
  (setq bbox (swcad-title-safe-bbox frame-ename))
  (if bbox
    (+ (swcad-title-abs (car bbox)) (swcad-title-abs (cadr bbox)))
    999999999.0
  )
)

(defun swcad-title-unfinalized-gmtitle-frame-for-block (frame-block / frames frame title frame-bbox geometry-warning score best best-score)
  (setq frames (swcad-title-inserts-by-effective-name frame-block))
  (setq best nil)
  (setq best-score nil)
  (foreach frame frames
    (setq frame-bbox (swcad-title-frame-reference-effective-bbox frame frame-block))
    (setq geometry-warning (swcad-title-frame-bbox-size-warning-for-block frame-block frame-bbox))
    (setq title (swcad-title-title-for-native-frame frame frame-block))
    (if (not title)
      (setq title (swcad-title-default-location-title-for-frame frame frame-block))
    )
    (if
      (and
        (not geometry-warning)
        (or title (swcad-title-default-gmtitle-frame-location-p frame))
        (or
          (and title (swcad-title-title-default-gmtitle-p title frame-block))
          (swcad-title-default-gmtitle-frame-location-p frame)
        )
      )
      (progn
        (setq score (swcad-title-unfinalized-gmtitle-frame-score frame))
        (if (or (not best-score) (< score best-score))
          (progn
            (setq best frame)
            (setq best-score score)
          )
        )
      )
    )
  )
  best
)

(defun swcad-title-default-location-gmtitle-frame-for-block (frame-block / frames frame title frame-bbox geometry-warning score best best-score)
  (setq frames (swcad-title-inserts-by-effective-name frame-block))
  (setq best nil)
  (setq best-score nil)
  (foreach frame frames
    (if (swcad-title-default-gmtitle-frame-location-p frame)
      (progn
        (setq frame-bbox (swcad-title-frame-reference-effective-bbox frame frame-block))
        (setq geometry-warning (swcad-title-frame-bbox-size-warning-for-block frame-block frame-bbox))
        (setq title (swcad-title-title-for-native-frame frame frame-block))
        (if (not title)
          (setq title (swcad-title-default-location-title-for-frame frame frame-block))
        )
        (if (and title (not geometry-warning))
          (progn
            (setq score (swcad-title-unfinalized-gmtitle-frame-score frame))
            (if (or (not best-score) (< score best-score))
              (progn
                (setq best frame)
                (setq best-score score)
              )
            )
          )
        )
      )
    )
  )
  best
)

(defun swcad-title-move-ename (ename dx dy / object result)
  (setq object (swcad-title-safe-vla-object ename))
  (if object
    (progn
      (setq result
        (vl-catch-all-apply
          'vla-Move
          (list
            object
            (vlax-3d-point (list 0.0 0.0 0.0))
            (vlax-3d-point (list dx dy 0.0))
          )
        )
      )
      (not (vl-catch-all-error-p result))
    )
    nil
  )
)

(defun swcad-title-align-gmtitle-to-frame-bbox (title-ename frame-ename target-bbox / frame-bbox dx dy moved)
  (setq moved 0)
  (setq frame-bbox (swcad-title-safe-bbox frame-ename))
  (if (and frame-bbox target-bbox)
    (progn
      (setq dx (- (car target-bbox) (car frame-bbox)))
      (setq dy (- (cadr target-bbox) (cadr frame-bbox)))
      (if (or (> (swcad-title-abs dx) 0.0001) (> (swcad-title-abs dy) 0.0001))
        (progn
          (if (swcad-title-move-ename frame-ename dx dy)
            (setq moved (+ moved 1))
          )
          (if (swcad-title-move-ename title-ename dx dy)
            (setq moved (+ moved 1))
          )
        )
      )
      (list moved dx dy frame-bbox)
    )
    (list moved 0.0 0.0 frame-bbox)
  )
)

(defun swcad-title-frame-dwg-path (frame-block)
  (strcat
    "C:/Program Files/Gstarsoft/GstarCAD Mechanical 2024 Korean/Dwg/Format/"
    (swcad-title-string frame-block)
    ".dwg"
  )
)

(defun swcad-title-vla-object->ename (object / result)
  (if object
    (progn
      (setq result (vl-catch-all-apply 'vlax-vla-object->ename (list object)))
      (if (vl-catch-all-error-p result) nil result)
    )
    nil
  )
)

(defun swcad-title-insert-block-reference (block-name x y / result)
  (setq result
    (vl-catch-all-apply
      'vla-InsertBlock
      (list
        (swcad-title-modelspace)
        (vlax-3d-point (list (float x) (float y) 0.0))
        block-name
        1.0
        1.0
        1.0
        0.0
      )
    )
  )
  (if (vl-catch-all-error-p result)
    nil
    (swcad-title-vla-object->ename result)
  )
)

(defun swcad-title-insert-frame-reference (frame-block / frame-path ename)
  (cond
    ((and
       (swcad-title-block-exists-p frame-block)
       (not (swcad-title-target-frame-block-contaminated-p frame-block))
     )
      (setq ename (swcad-title-insert-block-reference frame-block 0.0 0.0))
    )
    ((swcad-title-block-exists-p frame-block)
      (setq ename nil)
    )
    (T
      (setq frame-path (swcad-title-frame-dwg-path frame-block))
      (if (findfile frame-path)
        (setq ename (swcad-title-insert-block-reference frame-path 0.0 0.0))
      )
    )
  )
  ename
)

(defun swcad-title-copy-ename (ename / object result)
  (setq object (swcad-title-safe-vla-object ename))
  (if object
    (progn
      (setq result (vl-catch-all-apply 'vla-Copy (list object)))
      (if (vl-catch-all-error-p result)
        nil
        (swcad-title-vla-object->ename result)
      )
    )
    nil
  )
)

(defun swcad-title-ensure-clean-frame-definition (frame-block)
  (cond
    ((not frame-block) nil)
    ((and
       (swcad-title-block-exists-p frame-block)
       (not (swcad-title-target-frame-block-contaminated-p frame-block))
     )
      T
    )
    ((swcad-title-block-exists-p frame-block)
      nil
    )
    (T
      (swcad-title-import-clean-frame-definition frame-block)
    )
  )
)

(defun swcad-title-change-insert-block-name (ename block-name / data new-data pair changed result)
  (setq data (if ename (entget ename '("*")) nil))
  (if
    (and
      data
      (equal (swcad-title-string (swcad-title-dxf-value data 0)) "INSERT")
      (or
        (swcad-title-block-exists-p block-name)
        (swcad-title-ensure-clean-frame-definition block-name)
      )
    )
    (progn
      (setq new-data nil)
      (setq changed nil)
      (foreach pair data
        (if (and (listp pair) (= (car pair) 2))
          (progn
            (setq new-data (append new-data (list (cons 2 block-name))))
            (setq changed T)
          )
          (setq new-data (append new-data (list pair)))
        )
      )
      (if changed
        (progn
          (setq result (vl-catch-all-apply 'entmod (list new-data)))
          (if (vl-catch-all-error-p result)
            nil
            (progn
              (entupd ename)
              T
            )
          )
        )
        nil
      )
    )
    nil
  )
)

(defun swcad-title-move-ename-bbox-min-to (ename x y / bbox dx dy)
  (setq bbox (swcad-title-safe-bbox ename))
  (if bbox
    (progn
      (setq dx (- (float x) (car bbox)))
      (setq dy (- (float y) (cadr bbox)))
      (swcad-title-move-ename ename dx dy)
    )
    nil
  )
)

(defun swcad-title-native-frame-from-title (title-ename / handles handle ename result)
  (setq handles (swcad-title-gmtitle-native-xdata-info title-ename))
  (setq result nil)
  (foreach handle handles
    (if (not result)
      (progn
        (setq ename (handent handle))
        (if
          (and
            ename
            (swcad-title-native-target-frame-name-p (swcad-title-effective-insert-name ename))
          )
          (setq result ename)
        )
      )
    )
  )
  result
)

(defun swcad-title-usable-native-example-title-p (title-ename / handles kinds)
  (setq handles (swcad-title-gmtitle-native-xdata-info title-ename))
  (setq kinds (swcad-title-native-link-target-kinds title-ename))
  (and
    handles
    (or
      (member "internal" kinds)
      (member "internal-no-entget" kinds)
    )
    (not (member "visible-target-frame" kinds))
    (not (member "visible-target-title" kinds))
  )
)

(defun swcad-title-native-example-description (title-ename / data title-bbox frame-records nearest frame-ename frame-block title-trusted frame-trusted pair-trusted title-role frame-role)
  (if title-ename
    (progn
      (setq data (entget title-ename '("*")))
      (setq title-bbox (swcad-title-safe-bbox title-ename))
      (setq frame-records (swcad-title-frame-records))
      (setq nearest (if title-bbox (swcad-title-nearest-frame-record title-bbox frame-records) nil))
      (setq frame-ename (if nearest (car nearest) nil))
      (setq frame-block (if nearest (cadr nearest) ""))
      (setq title-trusted
        (if (> (strlen frame-block) 0)
          (swcad-title-trusted-native-exemplar-title-p title-ename frame-block)
          nil
        )
      )
      (setq frame-trusted
        (if frame-ename
          (swcad-title-trusted-native-exemplar-frame-p frame-ename frame-block)
          nil
        )
      )
      (setq pair-trusted (and title-trusted frame-trusted))
      (setq title-role (swcad-title-exemplar-role title-ename))
      (setq frame-role (if frame-ename (swcad-title-exemplar-role frame-ename) ""))
      (strcat
        "yes, handle="
        (swcad-title-string (swcad-title-dxf-value data 5))
        ", native-link-kinds="
        (swcad-title-list-string (swcad-title-native-link-target-kinds title-ename))
        ", nearest-frame="
        (if (> (strlen frame-block) 0) frame-block "<none>")
        ", trusted-marker="
        (if pair-trusted "yes" "no")
        ", title-marker="
        (if title-trusted "yes" "no")
        ", frame-marker="
        (if frame-trusted "yes" "no")
        ", title-role="
        (if (> (strlen title-role) 0) title-role "<none>")
        ", frame-role="
        (if (> (strlen frame-role) 0) frame-role "<none>")
      )
    )
    "no"
  )
)

(defun swcad-title-native-example-title (/ titles title result)
  (setq titles
    (vl-sort
      (swcad-title-inserts-by-effective-name (swcad-title-target-title-block-name))
      '(lambda (a b)
        (< (swcad-title-bbox-min-x a) (swcad-title-bbox-min-x b))
      )
    )
  )
  (setq result nil)
  (foreach title titles
    (if
      (and
        (not result)
        (swcad-title-usable-native-example-title-p title)
        (swcad-title-exemplar-safe-native-source-role-p (swcad-title-exemplar-role title))
      )
      (setq result title)
    )
  )
  result
)

(defun swcad-title-relink-gmtitle-xdata-pair (pair new-handle / code value)
  (if (and (listp pair) (= (type (car pair)) 'INT))
    (progn
      (setq code (car pair))
      (setq value (swcad-title-string (cdr pair)))
      (if (and (member code '(1000 1005)) (> (strlen value) 0) (handent value))
        (cons code new-handle)
        pair
      )
    )
    pair
  )
)

(defun swcad-title-relink-gmtitle-xdata-app (app new-handle / result pair)
  (setq result nil)
  (if
    (and
      (listp app)
      (swcad-title-string-p (car app))
      (equal (strcase (car app)) "GENIUS_GENOREF_13")
    )
    (progn
      (setq result (list (car app)))
      (foreach pair (cdr app)
        (setq result
          (append
            result
            (list (swcad-title-relink-gmtitle-xdata-pair pair new-handle))
          )
        )
      )
      result
    )
    app
  )
)

(defun swcad-title-relink-title-to-frame (title-ename frame-ename / data frame-handle new-data pair apps new-apps changed)
  (setq data (entget title-ename '("*")))
  (setq frame-handle (swcad-title-ename-handle frame-ename))
  (setq new-data nil)
  (setq changed nil)
  (foreach pair data
    (if (and (listp pair) (= (car pair) -3))
      (progn
        (setq apps (cdr pair))
        (setq new-apps nil)
        (foreach app apps
          (if
            (and
              (listp app)
              (swcad-title-string-p (car app))
              (equal (strcase (car app)) "GENIUS_GENOREF_13")
            )
            (progn
              (setq changed T)
              (setq new-apps
                (append
                  new-apps
                  (list (swcad-title-relink-gmtitle-xdata-app app frame-handle))
                )
              )
            )
            (setq new-apps (append new-apps (list app)))
          )
        )
        (setq new-data (append new-data (list (cons -3 new-apps))))
      )
      (setq new-data (append new-data (list pair)))
    )
  )
  (if changed
    (progn
      (entmod new-data)
      (entupd title-ename)
      T
    )
    nil
  )
)

(defun swcad-title-create-cloned-gmtitle-for-next-source (/ source source-ename source-data source-bbox source-block source-frame source-frame-ename source-frame-bbox source-frame-block build mappings values block-sheet inferred-frame-bbox frame-block default-values clone-result title-ename frame-ename offset-x offset-y doc ok)
  (setq source (swcad-title-transfer-source-bbox))
  (setq source-ename (if source (car source) nil))
  (setq source-data (if source (cadr source) nil))
  (setq source-bbox (if source (caddr source) nil))
  (setq source-block (if source-ename (swcad-title-effective-insert-name source-ename) nil))
  (setq source-frame (if source-bbox (swcad-title-transfer-source-frame source-bbox source-ename) nil))
  (setq source-frame-ename (if source-frame (car source-frame) nil))
  (setq source-frame-bbox (if source-frame (caddr source-frame) nil))
  (setq source-frame-block (if source-frame-ename (swcad-title-effective-insert-name source-frame-ename) nil))
  (if
    (and
      source-bbox
      (not (swcad-title-document-read-only-p))
      (swcad-title-apply-work-copy-confirmed-p)
    )
    (progn
      (setq build (swcad-title-transfer-build-mappings source-bbox source-ename 7.0))
      (setq mappings (car build))
      (setq values (swcad-title-transfer-values mappings))
      (setq block-sheet (swcad-title-source-block-sheet-size source-block source-frame-block))
      (setq values (swcad-title-values-with-sheet-size-override values block-sheet))
      (setq inferred-frame-bbox (swcad-title-effective-source-frame-bbox source-bbox source-frame-bbox values block-sheet))
      (setq frame-block (swcad-title-target-frame-block-name-for-source source-block source-frame-block values inferred-frame-bbox))
      (if (and frame-block inferred-frame-bbox)
        (progn
          (setq doc (swcad-title-doc))
          (vl-catch-all-apply 'vla-StartUndoMark (list doc))
          (setq offset-x (- (car source-bbox) (car inferred-frame-bbox)))
          (setq offset-y (- (cadr source-bbox) (cadr inferred-frame-bbox)))
          (setq default-values
            (list
              (cons "GEN-TITLE-SIZ{6.7}" (swcad-title-normalized-sheet-size frame-block))
              (cons "GEN-TITLE-DWG{23}" (swcad-title-current-dwg-full-path))
              (cons "GEN-TITLE-NR{23}" "XXX")
            )
          )
          (setq clone-result
            (swcad-title-clone-native-gmtitle-pair-preserve-links
              frame-block
              (list offset-x offset-y)
              default-values
            )
          )
          (setq title-ename (if clone-result (car clone-result) nil))
          (setq frame-ename (if clone-result (cadr clone-result) nil))
          (setq ok nil)
          (if clone-result
            (setq ok T)
          )
          (vl-catch-all-apply 'vla-EndUndoMark (list doc))
          (if ok
            (list title-ename frame-ename frame-block)
            (progn
              (swcad-title-delete-cloned-gmtitle-pair title-ename frame-ename)
              nil
            )
          )
        )
        nil
      )
    )
    nil
  )
)

(defun swcad-title-create-cloned-gmtitle-for-frame-only-source (source-frame / frame-ename frame-data frame-bbox source-block sheet frame-block values clone-result new-frame-ename title-ename offset doc ok)
  (setq frame-ename (if source-frame (car source-frame) nil))
  (setq frame-data (if source-frame (cadr source-frame) nil))
  (setq frame-bbox (if source-frame (caddr source-frame) nil))
  (setq source-block (if source-frame (cadddr source-frame) nil))
  (setq sheet (if source-frame (nth 5 source-frame) nil))
  (setq frame-block (swcad-title-target-frame-block-name-for-sheet sheet))
  (if
    (and
      frame-ename
      frame-bbox
      frame-block
      (not (swcad-title-document-read-only-p))
      (swcad-title-apply-work-copy-confirmed-p)
    )
    (progn
      (setq values (swcad-title-frame-only-default-values source-frame))
      (if (swcad-title-native-example-title)
        (progn
          (setq doc (swcad-title-doc))
          (vl-catch-all-apply 'vla-StartUndoMark (list doc))
          (setq offset (swcad-title-frame-only-title-offset sheet))
          (setq clone-result
            (swcad-title-clone-native-gmtitle-pair-preserve-links
              frame-block
              offset
              values
            )
          )
          (setq title-ename (if clone-result (car clone-result) nil))
          (setq new-frame-ename (if clone-result (cadr clone-result) nil))
          (setq ok nil)
          (if clone-result
            (setq ok T)
          )
          (vl-catch-all-apply 'vla-EndUndoMark (list doc))
          (if ok
            (list title-ename new-frame-ename frame-block values)
            (progn
              (swcad-title-delete-cloned-gmtitle-pair title-ename new-frame-ename)
              nil
            )
          )
        )
        nil
      )
    )
    nil
  )
)

(defun swcad-title-other-title-like-inserts (target-name / target ss index total ename name data result)
  (setq target (strcase (swcad-title-string target-name)))
  (setq ss (ssget "_X" '((0 . "INSERT"))))
  (setq total (if ss (sslength ss) 0))
  (setq index 0)
  (setq result nil)
  (while (< index total)
    (setq ename (ssname ss index))
    (setq name (swcad-title-effective-insert-name ename))
    (if
      (and
        (/= (strcase (swcad-title-string name)) target)
        (swcad-title-title-block-name-p name)
      )
      (progn
        (setq data (entget ename '("*")))
        (setq result
          (append
            result
            (list
              (list
                (swcad-title-string (swcad-title-dxf-value data 5))
                name
                (swcad-title-safe-bbox ename)
              )
            )
          )
        )
      )
    )
    (setq index (+ index 1))
  )
  result
)

(defun swcad-title-print-attribute-pairs (attr-pairs / pair)
  (foreach pair attr-pairs
    (swcad-title-princ-line
      (strcat
        "  "
        (car pair)
        " = \""
        (swcad-title-string (cdr pair))
        "\""
      )
    )
  )
)

(defun swcad-title-print-string-list (label values / value)
  (swcad-title-princ-line label)
  (if values
    (foreach value values
      (swcad-title-princ-line (strcat "  - " (swcad-title-string value)))
    )
    (swcad-title-princ-line "  <none>")
  )
)

(defun swcad-title-xdata-app-names (ename / records result record name)
  (setq records (swcad-title-xdata-records ename))
  (setq result nil)
  (foreach record records
    (setq name (swcad-title-xdata-record-app-name record))
    (if (> (strlen name) 0)
      (setq result (swcad-title-list-add-unique name result))
    )
  )
  result
)

(defun swcad-title-dxf-code-count (data code / count pair)
  (setq count 0)
  (foreach pair data
    (if (and (listp pair) (= (car pair) code))
      (setq count (+ count 1))
    )
  )
  count
)

(defun swcad-title-bbox-center (bbox)
  (if bbox
    (list
      (/ (+ (car bbox) (caddr bbox)) 2.0)
      (/ (+ (cadr bbox) (cadddr bbox)) 2.0)
    )
    nil
  )
)

(defun swcad-title-bbox-min-x (ename / bbox)
  (setq bbox (swcad-title-safe-bbox ename))
  (if bbox (car bbox) 0.0)
)

(defun swcad-title-frame-records (/ result candidate frames frame frame-data frame-bbox)
  (setq result nil)
  (foreach candidate (swcad-title-target-frame-block-candidates)
    (setq frames (swcad-title-inserts-by-effective-name candidate))
    (foreach frame frames
      (setq frame-data (entget frame '("*")))
      (setq frame-bbox (swcad-title-frame-reference-effective-bbox frame candidate))
      (setq result
        (append
          result
          (list
            (list
              frame
              candidate
              (swcad-title-string (swcad-title-dxf-value frame-data 5))
              frame-bbox
            )
          )
        )
      )
    )
  )
  result
)

(defun swcad-title-nearest-frame-record (title-bbox frame-records / center result record bbox)
  (setq center (swcad-title-bbox-center title-bbox))
  (setq result nil)
  (foreach record frame-records
    (if (not result)
      (progn
        (setq bbox (swcad-title-expand-bbox (cadddr record) 2.0))
        (if (swcad-title-point-in-bbox-p center bbox)
          (setq result record)
        )
      )
    )
  )
  result
)

(defun swcad-title-nearest-frame-record-for-block (title-bbox frame-records target-frame-block / target center nearest nearest-block result record bbox frame-center dist bestdist)
  (setq target (strcase (swcad-title-string target-frame-block)))
  (setq center (swcad-title-bbox-center title-bbox))
  (setq nearest (if title-bbox (swcad-title-nearest-frame-record title-bbox frame-records) nil))
  (setq nearest-block (if nearest (cadr nearest) ""))
  (setq result nil)
  (if (and nearest (equal (strcase (swcad-title-string nearest-block)) target))
    (setq result nearest)
  )
  (if (and (not result) center)
    (progn
      (setq bestdist nil)
      (foreach record frame-records
        (if (equal (strcase (swcad-title-string (cadr record))) target)
          (progn
            (setq bbox (cadddr record))
            (setq frame-center (swcad-title-bbox-center bbox))
            (if frame-center
              (progn
                (setq dist
                  (swcad-title-distance2
                    (car center)
                    (cadr center)
                    (car frame-center)
                    (cadr frame-center)
                  )
                )
                (if (or (not bestdist) (< dist bestdist))
                  (progn
                    (setq result record)
                    (setq bestdist dist)
                  )
                )
              )
            )
          )
        )
      )
    )
  )
  result
)

(defun swcad-title-title-for-frame-record-unused (frame-record title-enames used-title-enames / frame-handle result title title-bbox nearest nearest-handle)
  (setq frame-handle (if frame-record (strcase (swcad-title-string (caddr frame-record))) ""))
  (setq result nil)
  (foreach title title-enames
    (if
      (and
        (not result)
        (not (member title used-title-enames))
      )
      (progn
        (setq title-bbox (swcad-title-safe-bbox title))
        (setq nearest (if title-bbox (swcad-title-nearest-frame-record title-bbox (list frame-record)) nil))
        (setq nearest-handle (if nearest (strcase (swcad-title-string (caddr nearest))) ""))
        (if
          (and
            (> (strlen frame-handle) 0)
            (equal nearest-handle frame-handle)
          )
          (setq result title)
        )
      )
    )
  )
  result
)

(defun swcad-title-title-for-frame-record (frame-record title-enames)
  (swcad-title-title-for-frame-record-unused frame-record title-enames nil)
)

(defun swcad-title-attr-value-by-tag (attr-pairs tag / pair result)
  (setq result "")
  (foreach pair attr-pairs
    (if (equal (strcase (car pair)) (strcase tag))
      (setq result (swcad-title-string (cdr pair)))
    )
  )
  result
)

(defun swcad-title-count-frame-link (handle counts / pair result found key)
  (setq key (strcase (swcad-title-string handle)))
  (setq result nil)
  (setq found nil)
  (foreach pair counts
    (if (equal key (car pair))
      (progn
        (setq result (append result (list (cons (car pair) (+ (cdr pair) 1)))))
        (setq found T)
      )
      (setq result (append result (list pair)))
    )
  )
  (if found
    result
    (append result (list (cons key 1)))
  )
)

(defun swcad-title-block-child-insert-names (block-name / block result item item-ename item-name)
  (setq block (swcad-title-block-definition-object block-name))
  (setq result nil)
  (if block
    (vlax-for item block
      (setq item-ename (swcad-title-vla-object->ename item))
      (if item-ename
        (progn
          (setq item-name (swcad-title-effective-insert-name item-ename))
          (if (> (strlen item-name) 0)
            (setq result (swcad-title-list-add-unique item-name result))
          )
        )
      )
    )
  )
  result
)

(defun swcad-title-block-descendant-insert-names (block-name / result visited queue current child)
  (setq result nil)
  (setq visited (list block-name))
  (setq queue (swcad-title-block-child-insert-names block-name))
  (while queue
    (setq current (car queue))
    (setq queue (cdr queue))
    (if
      (and
        current
        (> (strlen (swcad-title-string current)) 0)
        (not (member current visited))
      )
      (progn
        (setq visited (append visited (list current)))
        (setq result (append result (list current)))
        (foreach child (swcad-title-block-child-insert-names current)
          (if (and child (not (member child visited)))
            (setq queue (append queue (list child)))
          )
        )
      )
    )
  )
  result
)

(defun swcad-title-frame-bbox-warning-records-for-block (frame-name / records result record frame-block frame-bbox warning)
  (setq records (swcad-title-frame-records))
  (setq result nil)
  (foreach record records
    (setq frame-block (cadr record))
    (if (equal (strcase (swcad-title-string frame-block)) (strcase (swcad-title-string frame-name)))
      (progn
        (setq frame-bbox (cadddr record))
        (setq warning (swcad-title-frame-bbox-size-warning-for-block frame-block frame-bbox))
        (if warning
          (setq result
            (append
              result
              (list
                (list
                  (caddr record)
                  frame-bbox
                  warning
                )
              )
            )
          )
        )
      )
    )
  )
  result
)

(defun swcad-title-print-frame-def-check-lines (/ frame-name exists children old-child-names bbox-warning-records contaminated)
  (setq contaminated nil)
  (foreach frame-name (swcad-title-target-frame-block-candidates)
    (setq exists (swcad-title-block-exists-p frame-name))
    (setq children (if exists (swcad-title-block-child-insert-names frame-name) nil))
    (setq old-child-names (if exists (swcad-title-target-frame-block-source-like-children frame-name) nil))
    (setq bbox-warning-records (swcad-title-frame-bbox-warning-records-for-block frame-name))
    (if (or old-child-names bbox-warning-records)
      (setq contaminated T)
    )
    (swcad-title-princ-line
      (strcat
        "  "
        frame-name
        ": exists="
        (if exists "yes" "no")
        ", children="
        (swcad-title-list-string children)
        ", old-source-like="
        (swcad-title-list-string old-child-names)
        ", bbox-warnings="
        (itoa (length bbox-warning-records))
        ", status="
        (if (or old-child-names bbox-warning-records) "CONTAMINATED" "OK")
      )
    )
    (foreach record bbox-warning-records
      (swcad-title-princ-line
        (strcat
          "    - insert="
          (car record)
          ", "
          (caddr record)
          ", bbox="
          (swcad-title-bbox-string (cadr record))
        )
      )
    )
  )
  contaminated
)

(defun swcad-title-frame-def-check (/ contaminated)
  (swcad-title-open-frame-def-check-log)
  (swcad-title-princ-line "----- SWTITLEFRAMEDEFCHECK read-only target frame definition check -----")
  (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (swcad-title-princ-line (strcat "CTAB: " (getvar "CTAB")))
  (swcad-title-print-work-copy-status)
  (swcad-title-princ-line "Target frame block definitions:")
  (setq contaminated (swcad-title-print-frame-def-check-lines))
  (swcad-title-princ-line
    (strcat
      "Result: "
      (if contaminated
        "WARN_TARGET_FRAME_BLOCK_DEFINITION_OR_GEOMETRY"
        "OK_TARGET_FRAME_BLOCK_DEFINITIONS"
      )
    )
  )
  (swcad-title-princ-line "No drawing data was changed.")
  (swcad-title-close-log)
  (princ)
)

(defun swcad-title-invalid-frame-repair-targets-for-block (frame-name / target frame-records title-enames used-title-enames result record frame-ename frame-block frame-bbox warning title-ename)
  (setq target (strcase (swcad-title-string frame-name)))
  (setq frame-records (swcad-title-frame-records))
  (setq title-enames (swcad-title-inserts-by-effective-name (swcad-title-target-title-block-name)))
  (setq used-title-enames nil)
  (setq result nil)
  (foreach record frame-records
    (setq frame-ename (car record))
    (setq frame-block (cadr record))
    (setq frame-bbox (cadddr record))
    (setq warning (swcad-title-frame-bbox-size-warning-for-block frame-block frame-bbox))
    (if
      (and
        (equal (strcase (swcad-title-string frame-block)) target)
        warning
      )
      (progn
        (setq title-ename (swcad-title-title-for-frame-record-unused record title-enames used-title-enames))
        (if title-ename
          (setq used-title-enames (append used-title-enames (list title-ename)))
        )
        (setq result
          (append
            result
            (list
              (list
                frame-ename
                frame-bbox
                title-ename
                warning
              )
            )
          )
        )
      )
    )
  )
  result
)

(defun swcad-title-rename-definition-list-to-backups (names / result name backup renamed)
  (setq result nil)
  (foreach name names
    (if (swcad-title-block-exists-p name)
      (progn
        (setq backup (swcad-title-unique-block-name name))
        (setq renamed (swcad-title-rename-block-definition name backup))
        (setq result
          (append
            result
            (list
              (list name backup renamed)
            )
          )
        )
      )
    )
  )
  result
)

(defun swcad-title-rollback-definition-renames (rename-results / item original backup parking)
  (foreach item (reverse rename-results)
    (setq original (car item))
    (setq backup (cadr item))
    (if (caddr item)
      (progn
        (if (swcad-title-block-exists-p original)
          (progn
            (setq parking (swcad-title-unique-block-name original))
            (swcad-title-princ-line
              (strcat
                "    rollback park "
                original
                " -> "
                parking
              )
            )
            (swcad-title-rename-block-definition original parking)
          )
        )
        (if (swcad-title-block-exists-p backup)
          (progn
            (swcad-title-princ-line
              (strcat
                "    rollback restore "
                backup
                " -> "
                original
              )
            )
            (swcad-title-rename-block-definition backup original)
          )
        )
      )
    )
  )
)

(defun swcad-title-repair-one-frame-definition-geometry (frame-name / targets children rename-names rename-results target-renamed imported repaired failed target frame-ename old-bbox title-ename new-frame new-bbox warning role test-frame test-bbox test-warning)
  (setq targets (swcad-title-invalid-frame-repair-targets-for-block frame-name))
  (if targets
    (progn
      (setq children (swcad-title-block-descendant-insert-names frame-name))
      (setq rename-names (list frame-name))
      (foreach target children
        (if
          (and
            target
            (swcad-title-block-exists-p target)
            (not (equal (strcase (swcad-title-string target)) (strcase (swcad-title-string frame-name))))
          )
          (setq rename-names (append rename-names (list target)))
        )
      )
      (swcad-title-princ-line
        (strcat
          "  "
          frame-name
          ": rebuilding, invalid inserts="
          (itoa (length targets))
          ", child-defs="
          (swcad-title-list-string children)
        )
      )
      (setq rename-results (swcad-title-rename-definition-list-to-backups rename-names))
      (setq target-renamed nil)
      (foreach target rename-results
        (swcad-title-princ-line
          (strcat
            "    rename "
            (car target)
            " -> "
            (cadr target)
            ": "
            (if (caddr target) "ok" "FAILED")
          )
        )
        (if (and (equal (strcase (car target)) (strcase (swcad-title-string frame-name))) (caddr target))
          (setq target-renamed T)
        )
      )
      (if (not target-renamed)
        (list 0 (length targets) "rename-target-failed")
        (progn
          (setq imported (swcad-title-import-clean-frame-definition frame-name))
          (swcad-title-princ-line
            (strcat
              "    import clean "
              frame-name
              ": "
              (if imported "ok" "FAILED")
            )
          )
          (setq repaired 0)
          (setq failed 0)
          (if imported
            (progn
              (setq test-frame (swcad-title-insert-block-reference frame-name 0.0 0.0))
              (setq test-bbox (if test-frame (swcad-title-frame-reference-effective-bbox test-frame frame-name) nil))
              (setq test-warning
                (if test-frame
                  (swcad-title-frame-bbox-size-warning-for-block frame-name test-bbox)
                  "could not insert imported definition"
                )
              )
              (if test-frame
                (swcad-title-delete-ename test-frame)
              )
              (if test-warning
                (progn
                  (setq failed (length targets))
                  (swcad-title-princ-line
                    (strcat
                      "    imported "
                      frame-name
                      " definition rejected before replacing existing inserts: "
                      test-warning
                      ", bbox="
                      (swcad-title-bbox-string test-bbox)
                    )
                  )
                  (swcad-title-princ-line
                    (strcat
                      "    rollback "
                      frame-name
                      ": installed/imported definition does not match expected A-size geometry."
                    )
                  )
                  (swcad-title-rollback-definition-renames rename-results)
                )
                (foreach target targets
                  (setq frame-ename (car target))
                  (setq old-bbox (cadr target))
                  (setq title-ename (caddr target))
                  (setq new-frame (swcad-title-insert-block-reference frame-name 0.0 0.0))
                  (if new-frame
                    (progn
                      (swcad-title-move-ename-bbox-min-to new-frame (car old-bbox) (cadr old-bbox))
                      (setq new-bbox (swcad-title-frame-reference-effective-bbox new-frame frame-name))
                      (setq warning (swcad-title-frame-bbox-size-warning-for-block frame-name new-bbox))
                      (if warning
                        (progn
                          (swcad-title-delete-ename new-frame)
                          (setq failed (+ failed 1))
                          (swcad-title-princ-line
                            (strcat
                              "    insert "
                              (swcad-title-ename-handle frame-ename)
                              ": FAILED, new geometry still invalid, "
                              warning
                              ", bbox="
                              (swcad-title-bbox-string new-bbox)
                            )
                          )
                        )
                        (progn
                          (setq role "native-frame-def-repair")
                          (if title-ename
                            (swcad-title-mark-native-exemplar-pair title-ename new-frame frame-name role)
                            (swcad-title-set-exemplar-xdata new-frame frame-name role)
                          )
                          (swcad-title-delete-ename frame-ename)
                          (setq repaired (+ repaired 1))
                          (swcad-title-princ-line
                            (strcat
                              "    insert "
                              (swcad-title-ename-handle new-frame)
                              ": repaired old="
                              (swcad-title-ename-handle frame-ename)
                              ", title="
                              (if title-ename (swcad-title-ename-handle title-ename) "<missing>")
                              ", bbox="
                              (swcad-title-bbox-string new-bbox)
                            )
                          )
                        )
                      )
                    )
                    (progn
                      (setq failed (+ failed 1))
                      (swcad-title-princ-line
                        (strcat
                          "    old "
                          (swcad-title-ename-handle frame-ename)
                          ": FAILED, could not insert clean "
                          frame-name
                        )
                      )
                    )
                  )
                )
              )
            )
            (setq failed (length targets))
          )
          (if
            (and
              (> failed 0)
              (= repaired 0)
              (not test-warning)
            )
            (progn
              (swcad-title-princ-line
                (strcat
                  "    rollback "
                  frame-name
                  ": no clean replacement matched expected geometry."
                )
              )
              (swcad-title-rollback-definition-renames rename-results)
            )
          )
          (list
            repaired
            failed
            (cond
              ((not imported) "import-failed")
              (test-warning "imported-invalid-geometry")
              (T "ok")
            )
          )
        )
      )
    )
    (list 0 0 "no-invalid-inserts")
  )
)

(defun swcad-title-repair-frame-definitions (/ doc answer frame-name result repaired failed status)
  (swcad-title-open-frame-def-repair-log)
  (swcad-title-princ-line "----- SWTITLEREPAIRFRAMEDEFS guarded target frame definition geometry repair -----")
  (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (swcad-title-princ-line (strcat "CTAB: " (getvar "CTAB")))
  (swcad-title-print-work-copy-status)
  (setq repaired 0)
  (setq failed 0)
  (cond
    ((swcad-title-document-read-only-p)
      (setq status "ABORT_READ_ONLY_DOCUMENT")
      (swcad-title-princ-line "Open a writable work copy before repairing frame definitions.")
    )
    ((not (swcad-title-apply-work-copy-confirmed-p))
      (setq status "ABORT_NOT_WORK_COPY")
      (swcad-title-princ-line "Open or create a copy under Documents/CAD tool/work before repairing.")
    )
    (T
      (swcad-title-princ-line "Target frame block definitions before repair:")
      (swcad-title-print-frame-def-check-lines)
      (setq answer
        (getstring
          T
          "\nType YES to rebuild referenced target frame definitions with invalid geometry: "
        )
      )
      (if (not (equal (strcase answer) "YES"))
        (progn
          (setq status "ABORT_USER_CANCEL")
          (swcad-title-princ-line "No drawing data was changed.")
        )
        (progn
          (setq doc (swcad-title-doc))
          (vl-catch-all-apply 'vla-StartUndoMark (list doc))
          (foreach frame-name (swcad-title-target-frame-block-candidates)
            (setq result (swcad-title-repair-one-frame-definition-geometry frame-name))
            (setq repaired (+ repaired (car result)))
            (setq failed (+ failed (cadr result)))
          )
          (vl-catch-all-apply 'vla-EndUndoMark (list doc))
          (swcad-title-princ-line "Target frame block definitions after repair:")
          (swcad-title-print-frame-def-check-lines)
          (setq status
            (cond
              ((> failed 0) "WARN_FRAME_DEF_REPAIR_PARTIAL")
              ((> repaired 0) "OK_FRAME_DEF_REPAIRED")
              (T "OK_NOTHING_TO_REPAIR")
            )
          )
          (swcad-title-princ-line
            (strcat
              "Summary: repaired="
              (itoa repaired)
              ", failed="
              (itoa failed)
            )
          )
        )
      )
    )
  )
  (swcad-title-princ-line (strcat "Result: " status))
  (swcad-title-close-log)
  (princ)
)

(defun swcad-title-unique-block-name (base / index candidate)
  (setq index 1)
  (setq candidate (strcat base "_SWOLD_" (itoa index)))
  (while (swcad-title-block-exists-p candidate)
    (setq index (+ index 1))
    (setq candidate (strcat base "_SWOLD_" (itoa index)))
  )
  candidate
)

(defun swcad-title-rename-block-definition (old-name new-name / block result)
  (setq block (swcad-title-block-definition-object old-name))
  (if block
    (progn
      (setq result (vl-catch-all-apply 'vla-put-Name (list block new-name)))
      (not (vl-catch-all-error-p result))
    )
    nil
  )
)

(defun swcad-title-import-clean-frame-definition (frame-name / frame-path ename)
  (setq frame-path (swcad-title-frame-dwg-path frame-name))
  (if (findfile frame-path)
    (progn
      (setq ename (swcad-title-insert-block-reference frame-path 0.0 0.0))
      (if ename
        (progn
          (swcad-title-delete-ename ename)
          (if (swcad-title-target-frame-block-contaminated-p frame-name)
            nil
            (swcad-title-block-exists-p frame-name)
          )
        )
        nil
      )
    )
    nil
  )
)

(defun swcad-title-frame-def-clean-safe (/ doc answer frame-name exists old-child-names insert-count backup-name renamed imported rollback any-contaminated cleaned skipped failed skipped-referenced skipped-missing)
  (swcad-title-open-frame-def-clean-log)
  (swcad-title-princ-line "----- SWTITLEFRAMEDEFCLEANSAFE guarded target frame definition cleanup -----")
  (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (swcad-title-princ-line (strcat "CTAB: " (getvar "CTAB")))
  (swcad-title-print-work-copy-status)
  (setq cleaned 0)
  (setq skipped 0)
  (setq failed 0)
  (setq skipped-referenced 0)
  (setq skipped-missing 0)
  (setq any-contaminated nil)
  (cond
    ((swcad-title-document-read-only-p)
      (swcad-title-princ-line "Result: ABORT_READ_ONLY_DOCUMENT")
      (swcad-title-princ-line "Open a writable work copy before cleaning frame definitions.")
    )
    ((not (swcad-title-apply-work-copy-confirmed-p))
      (swcad-title-princ-line "Result: ABORT_NOT_WORK_COPY")
      (swcad-title-princ-line "Open or create a copy under Documents/CAD tool/work before cleaning.")
    )
    (T
      (swcad-title-princ-line "Target frame block definitions before cleanup:")
      (swcad-title-print-frame-def-check-lines)
      (setq answer
        (getstring
          T
          "\nType YES to repair only UNUSED contaminated DR_A*_Outline definitions: "
        )
      )
      (if (not (equal (strcase answer) "YES"))
        (progn
          (swcad-title-princ-line "Result: ABORT_USER_CANCEL")
          (swcad-title-princ-line "No drawing data was changed.")
        )
        (progn
          (setq doc (swcad-title-doc))
          (vl-catch-all-apply 'vla-StartUndoMark (list doc))
          (foreach frame-name (swcad-title-target-frame-block-candidates)
            (setq exists (swcad-title-block-exists-p frame-name))
            (setq old-child-names (if exists (swcad-title-target-frame-block-source-like-children frame-name) nil))
            (setq insert-count (if exists (swcad-title-count-inserts-by-effective-name frame-name) 0))
            (cond
              ((not exists)
                (setq skipped-missing (+ skipped-missing 1))
                (swcad-title-princ-line
                  (strcat
                    "  "
                    frame-name
                    ": skip, definition does not exist."
                  )
                )
              )
              ((not old-child-names)
                (setq skipped (+ skipped 1))
                (swcad-title-princ-line
                  (strcat
                    "  "
                    frame-name
                    ": skip, definition is already clean."
                  )
                )
              )
              ((> insert-count 0)
                (setq any-contaminated T)
                (setq skipped-referenced (+ skipped-referenced 1))
                (swcad-title-princ-line
                  (strcat
                    "  "
                    frame-name
                    ": skip, contaminated but referenced by "
                    (itoa insert-count)
                    " insert(s). Children="
                    (swcad-title-list-string old-child-names)
                  )
                )
              )
              (T
                (setq any-contaminated T)
                (setq backup-name (swcad-title-unique-block-name frame-name))
                (setq renamed (swcad-title-rename-block-definition frame-name backup-name))
                (setq imported (if renamed (swcad-title-import-clean-frame-definition frame-name) nil))
                (if (and renamed imported)
                  (progn
                    (setq cleaned (+ cleaned 1))
                    (swcad-title-princ-line
                      (strcat
                        "  "
                        frame-name
                        ": cleaned, old definition renamed to "
                        backup-name
                        " and clean install definition imported."
                      )
                    )
                  )
                  (progn
                    (setq rollback nil)
                    (if (and renamed (not (swcad-title-block-exists-p frame-name)))
                      (setq rollback (swcad-title-rename-block-definition backup-name frame-name))
                    )
                    (setq failed (+ failed 1))
                    (swcad-title-princ-line
                      (strcat
                        "  "
                        frame-name
                        ": FAILED, renamed="
                        (if renamed "yes" "no")
                        ", imported="
                        (if imported "yes" "no")
                        ", rollback="
                        (if rollback "yes" "no")
                        "."
                      )
                    )
                  )
                )
              )
            )
          )
          (vl-catch-all-apply 'vla-EndUndoMark (list doc))
          (swcad-title-princ-line "Target frame block definitions after cleanup:")
          (swcad-title-print-frame-def-check-lines)
          (swcad-title-princ-line
            (strcat
              "Summary: cleaned="
              (itoa cleaned)
              ", skipped-clean="
              (itoa skipped)
              ", skipped-missing="
              (itoa skipped-missing)
              ", skipped-referenced="
              (itoa skipped-referenced)
              ", failed="
              (itoa failed)
            )
          )
          (swcad-title-princ-line
            (strcat
              "Result: "
              (cond
                ((> failed 0) "WARN_FRAME_DEF_CLEAN_PARTIAL_FAILURE")
                ((> skipped-referenced 0) "SKIP_REFERENCED_CONTAMINATED_FRAME_DEFS")
                ((> cleaned 0) "CLEANED_UNUSED_CONTAMINATED_FRAME_DEFS")
                (any-contaminated "WARN_CONTAMINATED_FRAME_DEFS_NOT_CLEANED")
                (T "OK_FRAME_DEFS_ALREADY_CLEAN")
              )
            )
          )
        )
      )
    )
  )
  (swcad-title-close-log)
  (princ)
)

(defun swcad-title-handle-entity-summary (handle / ename data etype name bbox)
  (setq ename (if (> (strlen (swcad-title-string handle)) 0) (handent handle) nil))
  (if ename
    (progn
      (setq data (entget ename '("*")))
      (setq etype (swcad-title-string (swcad-title-dxf-value data 0)))
      (setq name "")
      (if (equal etype "INSERT")
        (setq name (swcad-title-effective-insert-name ename))
      )
      (setq bbox (swcad-title-safe-bbox ename))
      (strcat
        etype
        (if (> (strlen name) 0) (strcat "/" name) "")
        " bbox="
        (swcad-title-bbox-string bbox)
      )
    )
    "<missing>"
  )
)

(defun swcad-title-reference-handle-code-p (code)
  (or
    (= code 390)
    (and (>= code 320) (<= code 369))
    (= code 1005)
  )
)

(defun swcad-title-reference-handle-value-string (value / ename)
  (cond
    ((= (type value) 'ENAME)
      (swcad-title-ename-handle value)
    )
    ((= (type value) 'STR)
      (if (handent value)
        (strcase value)
        value
      )
    )
    (T (swcad-title-string value))
  )
)

(defun swcad-title-print-reference-handle-pairs (data / found pair code value handle)
  (setq found nil)
  (foreach pair data
    (if (and (listp pair) (swcad-title-reference-handle-code-p (car pair)))
      (progn
        (setq code (car pair))
        (setq value (cdr pair))
        (setq handle (swcad-title-reference-handle-value-string value))
        (setq found T)
        (swcad-title-princ-line
          (strcat
            "    ref DXF "
            (itoa code)
            " -> "
            handle
            " / "
            (swcad-title-handle-entity-summary handle)
          )
        )
      )
    )
  )
  (if (not found)
    (swcad-title-princ-line "    ref handles: <none>")
  )
)

(defun swcad-title-print-handle-raw-detail (handle / ename data kind object object-name object-handle object-owner-id)
  (setq ename (if (> (strlen (swcad-title-string handle)) 0) (handent handle) nil))
  (setq kind (swcad-title-native-link-target-kind handle))
  (swcad-title-princ-line
    (strcat
      "  Handle "
      (swcad-title-string handle)
      ": kind="
      kind
      ", summary="
      (swcad-title-handle-entity-summary handle)
    )
  )
  (if ename
    (progn
      (setq object (swcad-title-safe-vla-object ename))
      (setq object-name (swcad-title-safe-vla-get object 'ObjectName))
      (setq object-handle (swcad-title-safe-vla-get object 'Handle))
      (setq object-owner-id (swcad-title-safe-vla-get object 'OwnerID))
      (swcad-title-princ-line
        (strcat
          "  VLA object: "
          (if object
            (strcat
              "ObjectName="
              (swcad-title-string object-name)
              ", Handle="
              (swcad-title-string object-handle)
              ", OwnerID="
              (swcad-title-string object-owner-id)
            )
            "<none>"
          )
        )
      )
      (setq data (entget ename '("*")))
      (if data
        (progn
          (swcad-title-princ-line "  Reference handles:")
          (swcad-title-print-reference-handle-pairs data)
          (swcad-title-princ-line "  Raw entget:")
          (foreach pair data
            (swcad-title-code-value-line "    DXF" pair)
          )
        )
        (progn
          (swcad-title-princ-line "  Reference handles: <none, entget returned nil>")
          (swcad-title-princ-line "  Raw entget: <nil>")
        )
      )
    )
    (swcad-title-princ-line "  Raw entget: <missing>")
  )
)

(defun swcad-title-print-xdata-record-detail (ename / records record pair)
  (setq records (if ename (swcad-title-xdata-records ename) nil))
  (swcad-title-princ-line "  xdata detail:")
  (if records
    (foreach record records
      (progn
        (swcad-title-princ-line
          (strcat
            "    app="
            (swcad-title-xdata-record-app-name record)
          )
        )
        (foreach pair (cdr record)
          (swcad-title-code-value-line "      XD" pair)
        )
      )
    )
    (swcad-title-princ-line "    <none>")
  )
)

(defun swcad-title-print-entity-structure-detail (label ename / data etype handle name layer owner bbox object object-name object-handle object-owner-id apps native-handles native-target-kinds)
  (swcad-title-princ-line (strcat label ":"))
  (if ename
    (progn
      (setq data (entget ename '("*")))
      (setq etype (swcad-title-string (swcad-title-dxf-value data 0)))
      (setq handle (swcad-title-string (swcad-title-dxf-value data 5)))
      (setq name "")
      (if (equal etype "INSERT")
        (setq name (swcad-title-effective-insert-name ename))
      )
      (setq layer (swcad-title-string (swcad-title-dxf-value data 8)))
      (setq owner (swcad-title-string (swcad-title-dxf-value data 330)))
      (setq bbox (swcad-title-safe-bbox ename))
      (setq object (swcad-title-safe-vla-object ename))
      (setq object-name (swcad-title-safe-vla-get object 'ObjectName))
      (setq object-handle (swcad-title-safe-vla-get object 'Handle))
      (setq object-owner-id (swcad-title-safe-vla-get object 'OwnerID))
      (setq apps (swcad-title-xdata-app-names ename))
      (setq native-handles (swcad-title-gmtitle-native-xdata-info ename))
      (setq native-target-kinds (swcad-title-native-link-target-kinds ename))
      (swcad-title-princ-line
        (strcat
          "  type="
          etype
          ", name="
          (if (> (strlen name) 0) name "<none>")
          ", handle="
          handle
          ", layer="
          layer
          ", owner="
          owner
        )
      )
      (swcad-title-princ-line (strcat "  bbox=" (swcad-title-bbox-string bbox)))
      (swcad-title-princ-line
        (strcat
          "  VLA object="
          (if object
            (strcat
              (swcad-title-string object-name)
              ", Handle="
              (swcad-title-string object-handle)
              ", OwnerID="
              (swcad-title-string object-owner-id)
            )
            "<none>"
          )
        )
      )
      (swcad-title-princ-line
        (strcat
          "  xdata-apps="
          (swcad-title-list-string apps)
          ", native-handles="
          (swcad-title-list-string native-handles)
          ", native-target-kinds="
          (swcad-title-list-string native-target-kinds)
        )
      )
      (swcad-title-princ-line
        (strcat
          "  persistent-reactors="
          (itoa (swcad-title-dxf-code-count data -5))
          ", extension-dictionaries="
          (itoa (swcad-title-dxf-code-count data 360))
        )
      )
      (swcad-title-princ-line "  reference handles:")
      (swcad-title-print-reference-handle-pairs data)
      (swcad-title-print-xdata-record-detail ename)
    )
    (swcad-title-princ-line "  <missing>")
  )
)

(defun swcad-title-first-title-by-native-kind (kind / title-name titles result title kinds)
  (setq title-name (swcad-title-target-title-block-name))
  (setq titles
    (vl-sort
      (swcad-title-inserts-by-effective-name title-name)
      '(lambda (a b)
        (< (swcad-title-bbox-min-x a) (swcad-title-bbox-min-x b))
      )
    )
  )
  (setq result nil)
  (foreach title titles
    (if (not result)
      (progn
        (setq kinds (swcad-title-native-link-target-kinds title))
        (cond
          ((equal kind "internal")
            (if
              (and
                (or
                  (member "internal" kinds)
                  (member "internal-no-entget" kinds)
                )
                (not (member "visible-target-frame" kinds))
                (not (member "visible-target-title" kinds))
              )
              (setq result title)
            )
          )
          ((equal kind "visible-target-frame")
            (if (member "visible-target-frame" kinds)
              (setq result title)
            )
          )
        )
      )
    )
  )
  result
)

(defun swcad-title-frame-records-right-origin (frame-records fallback-bbox / max-x min-y record bbox)
  (setq max-x nil)
  (setq min-y (if fallback-bbox (cadr fallback-bbox) 0.0))
  (foreach record frame-records
    (setq bbox (cadddr record))
    (if bbox
      (progn
        (if (or (not max-x) (> (caddr bbox) max-x))
          (setq max-x (caddr bbox))
        )
        (if (< (cadr bbox) min-y)
          (setq min-y (cadr bbox))
        )
      )
    )
  )
  (if (not max-x)
    (setq max-x (if fallback-bbox (caddr fallback-bbox) 0.0))
  )
  (list (+ max-x 50.0) min-y)
)

(defun swcad-title-copy-test-target-sheet (raw / value normalized)
  (setq value (strcase (vl-string-trim " \t\r\n" (swcad-title-string raw))))
  (cond
    ((or (= value "") (= value "SAME")) "SAME")
    (T
      (setq normalized (swcad-title-normalized-sheet-size value))
      (if (and normalized (wcmatch normalized "A1,A2,A3,A4"))
        normalized
        nil
      )
    )
  )
)

(defun swcad-title-title-frame-offset (title-bbox frame-bbox)
  (if (and title-bbox frame-bbox)
    (list (- (car title-bbox) (car frame-bbox)) (- (cadr title-bbox) (cadr frame-bbox)))
    '(0.0 0.0)
  )
)

(defun swcad-title-internal-native-link-kinds-p (kinds)
  (and
    (or
      (member "internal" kinds)
      (member "internal-no-entget" kinds)
    )
    (not (member "visible-target-frame" kinds))
    (not (member "visible-target-title" kinds))
  )
)

(defun swcad-title-cloned-native-link-kinds-p (kinds)
  (and
    (or
      (member "internal" kinds)
      (member "internal-no-entget" kinds)
    )
    (not (member "visible-target-frame" kinds))
    (not (member "visible-target-title" kinds))
    (not (member "missing" kinds))
  )
)

(defun swcad-title-native-example-pair (/ frame-records example-title example-title-bbox frame-record example-frame example-frame-block example-frame-bbox)
  (setq frame-records (swcad-title-frame-records))
  (setq example-title (swcad-title-native-example-title))
  (setq example-title-bbox (if example-title (swcad-title-safe-bbox example-title) nil))
  (setq frame-record (if example-title-bbox (swcad-title-nearest-frame-record example-title-bbox frame-records) nil))
  (setq example-frame (if frame-record (car frame-record) nil))
  (setq example-frame-block (if frame-record (cadr frame-record) nil))
  (setq example-frame-bbox (if frame-record (cadddr frame-record) nil))
  (if
    (and
      example-title
      example-title-bbox
      example-frame
      example-frame-bbox
      example-frame-block
    )
    (list example-title example-frame example-frame-block example-title-bbox example-frame-bbox)
    nil
  )
)

(defun swcad-title-native-example-pair-for-frame-block (target-frame-block / frame-records titles title result title-bbox frame-record example-frame example-frame-block example-frame-bbox target title-role frame-role)
  (setq target (strcase (swcad-title-string target-frame-block)))
  (setq frame-records (swcad-title-frame-records))
  (setq titles
    (vl-sort
      (swcad-title-inserts-by-effective-name (swcad-title-target-title-block-name))
      '(lambda (a b)
        (< (swcad-title-bbox-min-x a) (swcad-title-bbox-min-x b))
      )
    )
  )
  (setq result nil)
  (foreach title titles
    (if
      (and
        (not result)
        (swcad-title-usable-native-example-title-p title)
        (swcad-title-exemplar-safe-native-source-role-p (swcad-title-exemplar-role title))
      )
      (progn
        (setq title-bbox (swcad-title-safe-bbox title))
        (setq frame-record (if title-bbox (swcad-title-nearest-frame-record-for-block title-bbox frame-records target-frame-block) nil))
        (setq example-frame (if frame-record (car frame-record) nil))
        (setq example-frame-block (if frame-record (cadr frame-record) nil))
        (setq example-frame-bbox (if frame-record (cadddr frame-record) nil))
        (setq title-role (swcad-title-exemplar-role title))
        (setq frame-role (if example-frame (swcad-title-exemplar-role example-frame) ""))
        (if
          (and
            example-frame
            example-frame-bbox
            (equal (strcase (swcad-title-string example-frame-block)) target)
            (swcad-title-frame-bbox-size-valid-p example-frame-block example-frame-bbox)
            (swcad-title-exemplar-safe-native-source-role-p title-role)
            (swcad-title-exemplar-safe-native-source-role-p frame-role)
            (swcad-title-trusted-native-exemplar-pair-p title example-frame target-frame-block)
          )
          (setq result (list title example-frame example-frame-block title-bbox example-frame-bbox))
        )
      )
    )
  )
  result
)

(defun swcad-title-untrusted-native-candidate-count-for-frame-block (target-frame-block / frame-records titles title count title-bbox frame-record example-frame example-frame-block target)
  (setq target (strcase (swcad-title-string target-frame-block)))
  (setq frame-records (swcad-title-frame-records))
  (setq titles (swcad-title-inserts-by-effective-name (swcad-title-target-title-block-name)))
  (setq count 0)
  (foreach title titles
    (if (swcad-title-usable-native-example-title-p title)
      (progn
        (setq title-bbox (swcad-title-safe-bbox title))
        (setq frame-record (if title-bbox (swcad-title-nearest-frame-record-for-block title-bbox frame-records target-frame-block) nil))
        (setq example-frame (if frame-record (car frame-record) nil))
        (setq example-frame-block (if frame-record (cadr frame-record) nil))
        (if
          (and
            example-frame
            example-frame-block
            (equal (strcase (swcad-title-string example-frame-block)) target)
            (not (swcad-title-trusted-native-exemplar-pair-p title example-frame target-frame-block))
          )
          (setq count (+ count 1))
        )
      )
    )
  )
  count
)

(defun swcad-title-invalid-native-candidate-count-for-frame-block (target-frame-block / frame-records titles title count title-bbox frame-record example-frame example-frame-block example-frame-bbox target)
  (setq target (strcase (swcad-title-string target-frame-block)))
  (setq frame-records (swcad-title-frame-records))
  (setq titles (swcad-title-inserts-by-effective-name (swcad-title-target-title-block-name)))
  (setq count 0)
  (foreach title titles
    (if (swcad-title-usable-native-example-title-p title)
      (progn
        (setq title-bbox (swcad-title-safe-bbox title))
        (setq frame-record (if title-bbox (swcad-title-nearest-frame-record-for-block title-bbox frame-records target-frame-block) nil))
        (setq example-frame (if frame-record (car frame-record) nil))
        (setq example-frame-block (if frame-record (cadr frame-record) nil))
        (setq example-frame-bbox (if frame-record (cadddr frame-record) nil))
        (if
          (and
            example-frame
            example-frame-block
            (equal (strcase (swcad-title-string example-frame-block)) target)
            (swcad-title-frame-bbox-size-warning-for-block example-frame-block example-frame-bbox)
          )
          (setq count (+ count 1))
        )
      )
    )
  )
  count
)

(defun swcad-title-native-example-for-frame-description (frame-block / pair untrusted-count invalid-count)
  (setq pair (swcad-title-native-example-pair-for-frame-block frame-block))
  (if pair
    (strcat
      "yes, title="
      (swcad-title-ename-handle (car pair))
      ", frame="
      (swcad-title-ename-handle (cadr pair))
    )
    (progn
      (setq untrusted-count (swcad-title-untrusted-native-candidate-count-for-frame-block frame-block))
      (setq invalid-count (swcad-title-invalid-native-candidate-count-for-frame-block frame-block))
      (cond
        ((> invalid-count 0)
          (strcat "no valid exemplar, invalid-geometry-candidates=" (itoa invalid-count))
        )
        ((> untrusted-count 0)
          (strcat "no trusted marker, unmarked-candidates=" (itoa untrusted-count))
        )
        (T "no")
      )
    )
  )
)

(defun swcad-title-print-native-exemplars-by-frame (/ frame-block)
  (swcad-title-princ-line "Native GMTITLE exemplars by sheet frame:")
  (foreach frame-block (swcad-title-target-frame-block-candidates)
    (swcad-title-princ-line
      (strcat
        "  "
        frame-block
        ": "
        (swcad-title-native-example-for-frame-description frame-block)
      )
    )
  )
)

(defun swcad-title-delete-cloned-gmtitle-pair (title-ename frame-ename)
  (swcad-title-delete-ename title-ename)
  (swcad-title-delete-ename frame-ename)
)

(defun swcad-title-clone-native-gmtitle-pair-preserve-links (target-frame-block title-offset values / pair example-title example-frame example-frame-block example-title-bbox example-frame-bbox copied-frame copied-title copied-frame-bbox copied-title-bbox fallback-offset copied-kinds attr-count)
  (setq *swcad-title-last-clone-failure* nil)
  (setq pair (swcad-title-native-example-pair-for-frame-block target-frame-block))
  (if (not pair)
    (setq *swcad-title-last-clone-failure*
      (strcat
        "NO_SAME_SIZE_NATIVE_GMTITLE_EXEMPLAR_FOR_"
        (swcad-title-string target-frame-block)
      )
    )
  )
  (if (and pair target-frame-block)
    (progn
      (setq example-title (car pair))
      (setq example-frame (cadr pair))
      (setq example-frame-block (caddr pair))
      (setq example-title-bbox (cadddr pair))
      (setq example-frame-bbox (nth 4 pair))
      (setq copied-frame (swcad-title-copy-ename example-frame))
      (setq copied-title (if copied-frame (swcad-title-copy-ename example-title) nil))
      (if
        (and
          copied-frame
          copied-title
          (not (equal (strcase target-frame-block) (strcase example-frame-block)))
          (not (swcad-title-change-insert-block-name copied-frame target-frame-block))
        )
        (progn
          (setq *swcad-title-last-clone-failure*
            (strcat
              "FAILED_TO_CHANGE_FRAME_BLOCK_FROM_"
              (swcad-title-string example-frame-block)
              "_TO_"
              (swcad-title-string target-frame-block)
            )
          )
          (swcad-title-delete-cloned-gmtitle-pair copied-title copied-frame)
          (setq copied-title nil)
          (setq copied-frame nil)
        )
      )
      (if (and copied-frame copied-title)
        (progn
          (swcad-title-move-ename-bbox-min-to copied-frame 0.0 0.0)
          (setq copied-frame-bbox (swcad-title-safe-bbox copied-frame))
          (setq fallback-offset (swcad-title-title-frame-offset example-title-bbox example-frame-bbox))
          (if (not title-offset)
            (setq title-offset fallback-offset)
          )
          (if copied-frame-bbox
            (swcad-title-move-ename-bbox-min-to
              copied-title
              (+ (car copied-frame-bbox) (car title-offset))
              (+ (cadr copied-frame-bbox) (cadr title-offset))
            )
          )
          (setq attr-count
            (swcad-title-set-insert-attributes
              (swcad-title-safe-vla-object copied-title)
              values
            )
          )
          (swcad-title-mark-native-exemplar-pair
            copied-title
            copied-frame
            target-frame-block
            "clone"
          )
          (setq copied-title-bbox (swcad-title-safe-bbox copied-title))
          (setq copied-kinds (swcad-title-native-link-target-kinds copied-title))
          (if (swcad-title-cloned-native-link-kinds-p copied-kinds)
            (list
              copied-title
              copied-frame
              target-frame-block
              values
              attr-count
              copied-kinds
              copied-title-bbox
              copied-frame-bbox
            )
            (progn
              (setq *swcad-title-last-clone-failure*
                (strcat
                  "CLONED_NATIVE_LINK_KIND_REJECTED_"
                  (swcad-title-list-string copied-kinds)
                )
              )
              (swcad-title-delete-cloned-gmtitle-pair copied-title copied-frame)
              nil
            )
          )
        )
        (progn
          (if (not *swcad-title-last-clone-failure*)
            (setq *swcad-title-last-clone-failure* "FAILED_TO_COPY_NATIVE_GMTITLE_PAIR")
          )
          nil
        )
      )
    )
    nil
  )
)

(defun swcad-title-gmtitle-preserve-copy-test (/ frame-records example-title example-title-bbox example-frame-record example-frame example-frame-block example-frame-bbox raw target-sheet target-frame-block block-change-needed target-contaminated answer doc copied-frame copied-title origin title-offset copied-frame-bbox copied-title-bbox copied-kinds attr-count status)
  (swcad-title-open-gmtitle-preserve-copy-test-log)
  (setq frame-records (swcad-title-frame-records))
  (setq example-title (swcad-title-first-title-by-native-kind "internal"))
  (setq example-title-bbox (if example-title (swcad-title-safe-bbox example-title) nil))
  (setq example-frame-record (if example-title-bbox (swcad-title-nearest-frame-record example-title-bbox frame-records) nil))
  (setq example-frame (if example-frame-record (car example-frame-record) nil))
  (setq example-frame-block (if example-frame-record (cadr example-frame-record) nil))
  (setq example-frame-bbox (if example-frame-record (cadddr example-frame-record) nil))
  (swcad-title-princ-line "----- SWTITLEGMTITLEPRESERVECOPYTEST native pair copy experiment -----")
  (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (swcad-title-princ-line (strcat "CTAB: " (getvar "CTAB")))
  (swcad-title-print-work-copy-status)
  (swcad-title-princ-line
    (strcat
      "Native exemplar title: "
      (if example-title
        (strcat
          (swcad-title-ename-handle example-title)
          ", link-kinds="
          (swcad-title-list-string (swcad-title-native-link-target-kinds example-title))
        )
        "<none>"
      )
    )
  )
  (swcad-title-princ-line
    (strcat
      "Nearest native exemplar frame: "
      (if example-frame
        (strcat
          example-frame-block
          "/"
          (swcad-title-ename-handle example-frame)
          ", link-kinds="
          (swcad-title-list-string (swcad-title-native-link-target-kinds example-frame))
        )
        "<none>"
      )
    )
  )
  (cond
    ((swcad-title-document-read-only-p)
      (setq status "ABORT_READ_ONLY_DOCUMENT")
      (swcad-title-princ-line "Result: ABORT_READ_ONLY_DOCUMENT")
      (swcad-title-princ-line "Open a writable work copy before running the preserve-copy test.")
    )
    ((not (swcad-title-current-dwg-in-work-p))
      (setq status "ABORT_NOT_WORK_COPY")
      (swcad-title-princ-line "Result: ABORT_NOT_WORK_COPY")
      (swcad-title-princ-line "This experiment is limited to Documents/CAD tool/work copies.")
    )
    ((not example-title)
      (setq status "ABORT_NO_INTERNAL_NATIVE_TITLE")
      (swcad-title-princ-line "Result: ABORT_NO_INTERNAL_NATIVE_TITLE")
    )
    ((not example-frame)
      (setq status "ABORT_NO_NEAREST_NATIVE_FRAME")
      (swcad-title-princ-line "Result: ABORT_NO_NEAREST_NATIVE_FRAME")
    )
    (T
      (setq raw (getstring T "\nTarget sheet for copy test [SAME/A1/A2/A3/A4] <SAME>: "))
      (setq target-sheet (swcad-title-copy-test-target-sheet raw))
      (if (not target-sheet)
        (progn
          (setq status "ABORT_INVALID_TARGET_SHEET")
          (swcad-title-princ-line "Result: ABORT_INVALID_TARGET_SHEET")
          (swcad-title-princ-line "Use SAME, A1, A2, A3, or A4.")
        )
        (progn
          (setq target-frame-block
            (if (equal target-sheet "SAME")
              example-frame-block
              (swcad-title-target-frame-block-name-for-sheet target-sheet)
            )
          )
          (setq block-change-needed (not (equal (strcase target-frame-block) (strcase example-frame-block))))
          (setq target-contaminated
            (and
              block-change-needed
              (swcad-title-block-exists-p target-frame-block)
              (swcad-title-target-frame-block-contaminated-p target-frame-block)
            )
          )
          (swcad-title-princ-line (strcat "Requested target sheet: " target-sheet))
          (swcad-title-princ-line (strcat "Target frame block: " target-frame-block))
          (if target-contaminated
            (swcad-title-princ-line "Warning: target frame definition is flagged contaminated; continuing because this is an explicit preserve-copy recognition experiment.")
          )
          (cond
            (T
              (setq answer
                (getstring
                  T
                  "\nType YES to copy one native GMTITLE pair for recognition testing. No old content is deleted: "
                )
              )
              (if (not (equal (strcase answer) "YES"))
                (progn
                  (setq status "ABORT_USER_CANCEL")
                  (swcad-title-princ-line "Result: ABORT_USER_CANCEL")
                  (swcad-title-princ-line "No drawing data was changed.")
                )
                (progn
                  (setq doc (swcad-title-doc))
                  (vl-catch-all-apply 'vla-StartUndoMark (list doc))
                  (setq copied-frame (swcad-title-copy-ename example-frame))
                  (setq copied-title (if copied-frame (swcad-title-copy-ename example-title) nil))
                  (if (and copied-frame copied-title block-change-needed)
                    (if (not (swcad-title-change-insert-block-name copied-frame target-frame-block))
                      (progn
                        (swcad-title-delete-ename copied-title)
                        (swcad-title-delete-ename copied-frame)
                        (setq copied-title nil)
                        (setq copied-frame nil)
                      )
                    )
                  )
                  (if (and copied-frame copied-title)
                    (progn
                      (setq origin (swcad-title-frame-records-right-origin frame-records example-frame-bbox))
                      (swcad-title-move-ename-bbox-min-to copied-frame (car origin) (cadr origin))
                      (setq copied-frame-bbox (swcad-title-safe-bbox copied-frame))
                      (setq title-offset
                        (if (equal target-sheet "SAME")
                          (swcad-title-title-frame-offset example-title-bbox example-frame-bbox)
                          (swcad-title-frame-only-title-offset target-sheet)
                        )
                      )
                      (if (not title-offset)
                        (setq title-offset (swcad-title-title-frame-offset example-title-bbox example-frame-bbox))
                      )
                      (if copied-frame-bbox
                        (swcad-title-move-ename-bbox-min-to
                          copied-title
                          (+ (car copied-frame-bbox) (car title-offset))
                          (+ (cadr copied-frame-bbox) (cadr title-offset))
                        )
                      )
                      (setq attr-count
                        (swcad-title-set-insert-attributes
                          (swcad-title-safe-vla-object copied-title)
                          (list
                            (cons "GEN-TITLE-SIZ{6.7}" (if (equal target-sheet "SAME") (swcad-title-sheet-size-from-block-name target-frame-block) target-sheet))
                            (cons "GEN-TITLE-DWG{23}" "PRESERVE_COPY_TEST")
                            (cons "GEN-TITLE-NR{23}" "PRESERVE_COPY_TEST")
                          )
                        )
                      )
                      (setq copied-title-bbox (swcad-title-safe-bbox copied-title))
                      (setq copied-kinds (swcad-title-native-link-target-kinds copied-title))
                      (swcad-title-princ-line
                        (strcat
                          "Copied frame: "
                          target-frame-block
                          "/"
                          (swcad-title-ename-handle copied-frame)
                          ", bbox="
                          (swcad-title-bbox-string copied-frame-bbox)
                        )
                      )
                      (swcad-title-princ-line
                        (strcat
                          "Copied title: "
                          (swcad-title-ename-handle copied-title)
                          ", bbox="
                          (swcad-title-bbox-string copied-title-bbox)
                          ", attr-set="
                          (itoa attr-count)
                          ", link-kinds="
                          (swcad-title-list-string copied-kinds)
                        )
                      )
                      (swcad-title-print-gmtitle-compare-case "Copied preserve-link title detail" copied-title (swcad-title-frame-records))
                      (setq status
                        (if (swcad-title-cloned-native-link-kinds-p copied-kinds)
                          "OK_PRESERVE_COPY_NATIVE_LINK"
                          "WARN_PRESERVE_COPY_LINK_NOT_USABLE"
                        )
                      )
                      (swcad-title-princ-line (strcat "Result: " status))
                      (swcad-title-princ-line "Old SOLIDWORKS title/frame content was not removed.")
                    )
                    (progn
                      (setq status "ABORT_COPY_NATIVE_PAIR_FAILED")
                      (swcad-title-princ-line "Result: ABORT_COPY_NATIVE_PAIR_FAILED")
                    )
                  )
                  (vl-catch-all-apply 'vla-EndUndoMark (list doc))
                )
              )
            )
          )
        )
      )
    )
  )
  (swcad-title-close-log)
  (princ)
)

(defun swcad-title-print-gmtitle-compare-case (label title frame-records / title-data title-object attr-pairs title-bbox native-handles native-target-kinds nearest nearest-ename nearest-handle linked-handle linked-ename handle-matches-nearest)
  (swcad-title-princ-line "")
  (swcad-title-princ-line label)
  (if title
    (progn
      (setq title-data (entget title '("*")))
      (setq title-object (swcad-title-safe-vla-object title))
      (setq attr-pairs (if title-object (swcad-title-title-attribute-pairs title-object) nil))
      (setq title-bbox (swcad-title-safe-bbox title))
      (setq native-handles (swcad-title-gmtitle-native-xdata-info title))
      (setq native-target-kinds (swcad-title-native-link-target-kinds title))
      (setq nearest (swcad-title-nearest-frame-record title-bbox frame-records))
      (setq nearest-ename (if nearest (car nearest) nil))
      (setq nearest-handle (if nearest (caddr nearest) ""))
      (setq linked-handle (if native-handles (car native-handles) ""))
      (setq linked-ename (if (> (strlen linked-handle) 0) (handent linked-handle) nil))
      (setq handle-matches-nearest
        (and
          (> (strlen linked-handle) 0)
          (> (strlen nearest-handle) 0)
          (equal (strcase linked-handle) (strcase nearest-handle))
        )
      )
      (swcad-title-princ-line
        (strcat
          "  sheet="
          (swcad-title-attr-value-by-tag attr-pairs "GEN-TITLE-SIZ{6.7}")
          ", DWG=\""
          (swcad-title-attr-value-by-tag attr-pairs "GEN-TITLE-DWG{23}")
          "\", NR=\""
          (swcad-title-attr-value-by-tag attr-pairs "GEN-TITLE-NR{23}")
          "\", native-target-kinds="
          (swcad-title-list-string native-target-kinds)
        )
      )
      (swcad-title-princ-line
        (strcat
          "  nearest-frame="
          (if nearest (cadr nearest) "<none>")
          "/"
          nearest-handle
          ", linked-handle="
          (if (> (strlen linked-handle) 0) linked-handle "<none>")
          ", link-matches-nearest="
          (if handle-matches-nearest "yes" "no")
        )
      )
      (swcad-title-print-entity-structure-detail "  title insert" title)
      (swcad-title-print-entity-structure-detail "  nearest frame insert" nearest-ename)
      (swcad-title-princ-line "  native linked target detail:")
      (if native-handles
        (foreach linked-handle native-handles
          (swcad-title-print-handle-raw-detail linked-handle)
        )
        (swcad-title-princ-line "    <none>")
      )
      (if
        (and
          linked-ename
          (not (equal linked-ename nearest-ename))
        )
        (swcad-title-print-entity-structure-detail "  linked visible/internal ename structure" linked-ename)
      )
    )
    (swcad-title-princ-line "  <missing>")
  )
)

(defun swcad-title-gmtitle-compare (/ frame-records native-title visible-title status)
  (swcad-title-open-gmtitle-compare-log)
  (setq frame-records (swcad-title-frame-records))
  (setq native-title (swcad-title-first-title-by-native-kind "internal"))
  (setq visible-title (swcad-title-first-title-by-native-kind "visible-target-frame"))
  (swcad-title-princ-line "----- SWTITLEGMTITLECOMPARE read-only native-vs-clone comparison -----")
  (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (swcad-title-princ-line (strcat "CTAB: " (getvar "CTAB")))
  (swcad-title-print-work-copy-status)
  (swcad-title-princ-line (strcat "Target frame inserts: " (itoa (length frame-records))))
  (swcad-title-princ-line
    (strcat
      "Internal/native title exemplar: "
      (if native-title
        (swcad-title-ename-handle native-title)
        "<none>"
      )
    )
  )
  (swcad-title-princ-line
    (strcat
      "Visible-frame-linked clone exemplar: "
      (if visible-title
        (swcad-title-ename-handle visible-title)
        "<none>"
      )
    )
  )
  (swcad-title-print-gmtitle-compare-case "Case A: internal/native GMTITLE title" native-title frame-records)
  (swcad-title-print-gmtitle-compare-case "Case B: visible-frame-linked cloned GMTITLE title" visible-title frame-records)
  (setq status
    (cond
      ((and native-title visible-title) "OK_COMPARE_INTERNAL_AND_VISIBLE_FRAME_LINK")
      ((not native-title) "WARN_NO_INTERNAL_NATIVE_TITLE_TO_COMPARE")
      ((not visible-title) "WARN_NO_VISIBLE_FRAME_LINKED_CLONE_TO_COMPARE")
      (T "WARN_COMPARE_INPUTS_MISSING")
    )
  )
  (swcad-title-princ-line (strcat "Result: " status))
  (swcad-title-princ-line "No drawing data was changed.")
  (swcad-title-close-log)
  (princ)
)

(defun swcad-title-gmtitle-link-detail (/ title-name titles title-index title title-data title-object title-bbox attr-pairs native-handles native-target-kinds nearest nearest-handle title-handle handle)
  (swcad-title-open-gmtitle-link-detail-log)
  (setq title-name (swcad-title-target-title-block-name))
  (setq titles
    (vl-sort
      (swcad-title-inserts-by-effective-name title-name)
      '(lambda (a b)
        (< (swcad-title-bbox-min-x a) (swcad-title-bbox-min-x b))
      )
    )
  )
  (swcad-title-princ-line "----- SWTITLEGMTITLELINKDETAIL read-only native-link raw detail -----")
  (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (swcad-title-princ-line (strcat "CTAB: " (getvar "CTAB")))
  (swcad-title-print-work-copy-status)
  (swcad-title-princ-line (strcat "Target title inserts: " (itoa (length titles))))
  (setq title-index 1)
  (foreach title titles
    (setq title-data (entget title '("*")))
    (setq title-object (swcad-title-safe-vla-object title))
    (setq title-bbox (swcad-title-safe-bbox title))
    (setq attr-pairs (if title-object (swcad-title-title-attribute-pairs title-object) nil))
    (setq native-handles (swcad-title-gmtitle-native-xdata-info title))
    (setq native-target-kinds (swcad-title-native-link-target-kinds title))
    (setq nearest (swcad-title-nearest-frame-record title-bbox (swcad-title-frame-records)))
    (setq nearest-handle (if nearest (caddr nearest) ""))
    (setq title-handle (swcad-title-string (swcad-title-dxf-value title-data 5)))
    (swcad-title-princ-line
      (strcat
        "Title #"
        (itoa title-index)
        ": handle="
        title-handle
        ", sheet="
        (swcad-title-attr-value-by-tag attr-pairs "GEN-TITLE-SIZ{6.7}")
        ", native-target-kinds="
        (swcad-title-list-string native-target-kinds)
        ", nearest-frame="
        (if nearest (cadr nearest) "<none>")
        "/"
        nearest-handle
      )
    )
    (foreach handle native-handles
      (swcad-title-print-handle-raw-detail handle)
    )
    (if (not native-handles)
      (swcad-title-princ-line "  Native handles: <none>")
    )
    (setq title-index (+ title-index 1))
  )
  (swcad-title-princ-line "Result: OK_LINK_DETAIL_DUMPED")
  (swcad-title-princ-line "No drawing data was changed.")
  (swcad-title-close-log)
  (princ)
)

(defun swcad-title-gmtitle-link-scan (/ title-name titles title-index title title-data title-object title-bbox attr-pairs missing-tags native-handles native-target-kinds apps frame-records nearest nearest-handle linked-handle linked-frame-ename linked-frame-data linked-frame-apps linked-frame-native-handles frame-link-counts duplicate-link-found visible-frame-link-found visible-frame-link-count contaminated-frame-found title-handle handle-matches-nearest old-child-names frame-name children item)
  (swcad-title-open-gmtitle-link-scan-log)
  (setq title-name (swcad-title-target-title-block-name))
  (setq titles
    (vl-sort
      (swcad-title-inserts-by-effective-name title-name)
      '(lambda (a b)
        (< (swcad-title-bbox-min-x a) (swcad-title-bbox-min-x b))
      )
    )
  )
  (setq frame-records (swcad-title-frame-records))
  (setq frame-link-counts nil)
  (setq duplicate-link-found nil)
  (setq visible-frame-link-found nil)
  (setq visible-frame-link-count 0)
  (setq contaminated-frame-found nil)
  (swcad-title-princ-line "----- SWTITLEGMTITLELINKSCAN read-only GMTITLE link scan -----")
  (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (swcad-title-princ-line (strcat "CTAB: " (getvar "CTAB")))
  (swcad-title-print-work-copy-status)
  (swcad-title-princ-line (strcat "Target title inserts: " (itoa (length titles))))
  (swcad-title-princ-line (strcat "Target frame inserts: " (itoa (length frame-records))))
  (setq title-index 1)
  (foreach title titles
    (setq title-data (entget title '("*")))
    (setq title-object (swcad-title-safe-vla-object title))
    (setq title-bbox (swcad-title-safe-bbox title))
    (setq attr-pairs (if title-object (swcad-title-title-attribute-pairs title-object) nil))
    (setq missing-tags (swcad-title-missing-template-tags attr-pairs))
    (setq native-handles (swcad-title-gmtitle-native-xdata-info title))
    (setq native-target-kinds (swcad-title-native-link-target-kinds title))
    (setq apps (swcad-title-xdata-app-names title))
    (setq nearest (swcad-title-nearest-frame-record title-bbox frame-records))
    (setq nearest-handle (if nearest (caddr nearest) ""))
    (setq linked-handle (if native-handles (car native-handles) ""))
    (setq linked-frame-ename (if (> (strlen linked-handle) 0) (handent linked-handle) nil))
    (setq linked-frame-data (if linked-frame-ename (entget linked-frame-ename '("*")) nil))
    (setq linked-frame-apps (if linked-frame-ename (swcad-title-xdata-app-names linked-frame-ename) nil))
    (setq linked-frame-native-handles
      (if linked-frame-ename (swcad-title-gmtitle-native-xdata-info linked-frame-ename) nil)
    )
    (setq handle-matches-nearest (and (> (strlen linked-handle) 0) (equal (strcase linked-handle) (strcase nearest-handle))))
    (if (member "visible-target-frame" native-target-kinds)
      (progn
        (setq visible-frame-link-found T)
        (setq visible-frame-link-count (+ visible-frame-link-count 1))
      )
    )
    (if (> (strlen linked-handle) 0)
      (setq frame-link-counts (swcad-title-count-frame-link linked-handle frame-link-counts))
    )
    (setq title-handle (swcad-title-string (swcad-title-dxf-value title-data 5)))
    (swcad-title-princ-line
      (strcat
        "Title #"
        (itoa title-index)
        ": handle="
        title-handle
        ", sheet="
        (swcad-title-attr-value-by-tag attr-pairs "GEN-TITLE-SIZ{6.7}")
        ", DWG=\""
        (swcad-title-attr-value-by-tag attr-pairs "GEN-TITLE-DWG{23}")
        "\", NR=\""
        (swcad-title-attr-value-by-tag attr-pairs "GEN-TITLE-NR{23}")
        "\", attrs="
        (itoa (length attr-pairs))
        ", missing-tags="
        (itoa (length missing-tags))
        ", owner="
        (swcad-title-string (swcad-title-dxf-value title-data 330))
      )
    )
    (swcad-title-princ-line
      (strcat
        "  bbox="
        (swcad-title-bbox-string title-bbox)
        ", xdata-apps="
        (swcad-title-list-string apps)
      )
    )
    (swcad-title-princ-line
      (strcat
        "  native-handles="
        (swcad-title-list-string native-handles)
        ", native-target-kinds="
        (swcad-title-list-string native-target-kinds)
        ", linked-entity="
        (swcad-title-handle-entity-summary linked-handle)
        ", nearest-frame="
        (if nearest (cadr nearest) "<none>")
        "/"
        nearest-handle
        ", link-matches-nearest="
        (if handle-matches-nearest "yes" "no")
      )
    )
    (swcad-title-princ-line
      (strcat
        "  persistent-reactors="
        (itoa (swcad-title-dxf-code-count title-data -5))
        ", extension-dictionaries="
        (itoa (swcad-title-dxf-code-count title-data 360))
      )
    )
    (if linked-frame-ename
      (swcad-title-princ-line
        (strcat
          "  linked-frame-structure: owner="
          (swcad-title-string (swcad-title-dxf-value linked-frame-data 330))
          ", xdata-apps="
          (swcad-title-list-string linked-frame-apps)
          ", native-handles="
          (swcad-title-list-string linked-frame-native-handles)
          ", persistent-reactors="
          (itoa (swcad-title-dxf-code-count linked-frame-data -5))
          ", extension-dictionaries="
          (itoa (swcad-title-dxf-code-count linked-frame-data 360))
        )
      )
      (swcad-title-princ-line "  linked-frame-structure: <missing>")
    )
    (setq title-index (+ title-index 1))
  )
  (swcad-title-princ-line "Frame link handle usage:")
  (if frame-link-counts
    (foreach pair frame-link-counts
      (if (> (cdr pair) 1)
        (setq duplicate-link-found T)
      )
      (swcad-title-princ-line (strcat "  " (car pair) " x " (itoa (cdr pair))))
    )
    (swcad-title-princ-line "  <none>")
  )
  (swcad-title-princ-line
    (strcat
      "Titles whose native link points to a visible target frame: "
      (itoa visible-frame-link-count)
    )
  )
  (swcad-title-princ-line "Target frame block definition child INSERT names:")
  (foreach frame-name (swcad-title-target-frame-block-candidates)
    (setq children (swcad-title-block-child-insert-names frame-name))
    (setq old-child-names (swcad-title-target-frame-block-source-like-children frame-name))
    (if old-child-names
      (setq contaminated-frame-found T)
    )
    (swcad-title-princ-line
      (strcat
        "  "
        frame-name
        ": children="
        (swcad-title-list-string children)
        ", old-source-like="
        (swcad-title-list-string old-child-names)
        ", status="
        (if old-child-names "CONTAMINATED" "OK")
      )
    )
  )
  (swcad-title-princ-line
    (strcat
      "Result: "
      (cond
        (duplicate-link-found "WARN_DUPLICATE_NATIVE_FRAME_LINKS")
        (visible-frame-link-found "WARN_NATIVE_LINKS_POINT_TO_VISIBLE_FRAMES")
        (contaminated-frame-found "WARN_TARGET_FRAME_BLOCK_DEFINITION_CONTAMINATED")
        ((not frame-link-counts) "WARN_NO_NATIVE_FRAME_LINKS")
        (T "OK_LINK_SCAN_NO_DUPLICATE_FRAME_LINKS")
      )
    )
  )
  (swcad-title-princ-line "No drawing data was changed.")
  (swcad-title-close-log)
  (princ)
)

(defun swcad-title-gmtitle-verify (/ frame-name title-name frame-count title-enames title-count title-index title-ename title-data title-object title-bbox attr-pairs missing-tags nonempty-attrs native-handles native-target-kinds other-title-inserts filedia cmddia status record any-missing-tags any-empty-attrs any-missing-native-xdata any-visible-frame-native-link)
  (swcad-title-open-gmtitle-verify-log)
  (setq frame-name (swcad-title-existing-target-frame-block-name))
  (if (not frame-name)
    (setq frame-name (swcad-title-target-frame-block-name))
  )
  (if (/= (type frame-name) 'STR)
    (setq frame-name (swcad-title-target-frame-block-name))
  )
  (setq title-name (swcad-title-target-title-block-name))
  (setq frame-count (swcad-title-count-inserts-by-effective-name frame-name))
  (setq title-enames (swcad-title-inserts-by-effective-name title-name))
  (setq title-count (length title-enames))
  (setq other-title-inserts (swcad-title-other-title-like-inserts title-name))
  (setq filedia (getvar "FILEDIA"))
  (setq cmddia (getvar "CMDDIA"))
  (setq any-missing-tags nil)
  (setq any-empty-attrs nil)
  (setq any-missing-native-xdata nil)
  (setq any-visible-frame-native-link nil)
  (swcad-title-princ-line "----- SWTITLEGMTITLEVERIFY read-only GMTITLE transfer verification -----")
  (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (swcad-title-princ-line (strcat "CTAB: " (getvar "CTAB")))
  (swcad-title-print-work-copy-status)
  (swcad-title-princ-line (strcat "FILEDIA: " (swcad-title-string filedia) " (not changed)"))
  (swcad-title-princ-line (strcat "CMDDIA: " (swcad-title-string cmddia) " (not changed)"))
  (swcad-title-princ-line (strcat "Target frame block: " frame-name ", inserts=" (itoa frame-count)))
  (swcad-title-princ-line (strcat "Target title block: " title-name ", inserts=" (itoa title-count)))
  (if title-enames
    (progn
      (setq title-index 1)
      (foreach title-ename title-enames
        (setq title-data (entget title-ename '("*")))
        (setq title-object (swcad-title-safe-vla-object title-ename))
        (setq title-bbox (swcad-title-safe-bbox title-ename))
        (setq attr-pairs (if title-object (swcad-title-title-attribute-pairs title-object) nil))
        (setq missing-tags (swcad-title-missing-template-tags attr-pairs))
        (setq nonempty-attrs (swcad-title-nonempty-attribute-count attr-pairs))
        (setq native-handles (swcad-title-gmtitle-native-xdata-info title-ename))
        (setq native-target-kinds (swcad-title-native-link-target-kinds title-ename))
        (setq title-xdata-apps (swcad-title-xdata-app-names title-ename))
        (setq nearest-frame-record (if title-bbox (swcad-title-nearest-frame-record title-bbox frame-records) nil))
        (setq nearest-frame-ename (if nearest-frame-record (car nearest-frame-record) nil))
        (setq nearest-frame-block (if nearest-frame-record (cadr nearest-frame-record) ""))
        (setq nearest-frame-handle (if nearest-frame-record (caddr nearest-frame-record) ""))
        (setq nearest-frame-bbox (if nearest-frame-record (cadddr nearest-frame-record) nil))
        (setq nearest-frame-native-handles
          (if nearest-frame-ename (swcad-title-gmtitle-native-xdata-info nearest-frame-ename) nil)
        )
        (setq nearest-frame-xdata-apps
          (if nearest-frame-ename (swcad-title-xdata-app-names nearest-frame-ename) nil)
        )
        (setq title-sheet-value (swcad-title-attr-value-by-tag attr-pairs "GEN-TITLE-SIZ{6.7}"))
        (setq title-sheet-normalized (swcad-title-normalized-sheet-size title-sheet-value))
        (setq frame-sheet-normalized
          (if (> (strlen nearest-frame-block) 0)
            (swcad-title-sheet-size-from-block-name nearest-frame-block)
            nil
          )
        )
        (setq title-trusted-exemplar
          (if (> (strlen nearest-frame-block) 0)
            (swcad-title-trusted-native-exemplar-title-p title-ename nearest-frame-block)
            nil
          )
        )
        (setq frame-trusted-exemplar
          (if nearest-frame-ename
            (swcad-title-trusted-native-exemplar-frame-p nearest-frame-ename nearest-frame-block)
            nil
          )
        )
        (setq pair-trusted-exemplar
          (and title-trusted-exemplar frame-trusted-exemplar)
        )
        (if missing-tags
          (setq any-missing-tags T)
        )
        (if (= nonempty-attrs 0)
          (setq any-empty-attrs T)
        )
        (if (not native-handles)
          (setq any-missing-native-xdata T)
        )
        (if (member "visible-target-frame" native-target-kinds)
          (setq any-visible-frame-native-link T)
        )
        (swcad-title-princ-line
          (strcat
            "Title insert #"
            (itoa title-index)
            ": handle="
            (swcad-title-string (swcad-title-dxf-value title-data 5))
            ", bbox="
            (swcad-title-bbox-string title-bbox)
          )
        )
        (swcad-title-princ-line (strcat "Title attributes: " (itoa (length attr-pairs))))
        (swcad-title-print-attribute-pairs attr-pairs)
        (swcad-title-princ-line (strcat "Non-empty title attributes: " (itoa nonempty-attrs)))
        (swcad-title-print-string-list "Missing expected title tags:" missing-tags)
        (swcad-title-print-string-list "Native GMTITLE GENIUS_GENOREF_13 handle links:" native-handles)
        (swcad-title-print-string-list "Native GMTITLE link target kinds:" native-target-kinds)
        (setq title-index (+ title-index 1))
      )
    )
    (swcad-title-princ-line "Title inserts: <missing>")
  )
  (swcad-title-princ-line "Other title-like inserts that are not the target GMTITLE block:")
  (if other-title-inserts
    (foreach record other-title-inserts
      (swcad-title-princ-line
        (strcat
          "  - handle="
          (car record)
          ", block="
          (cadr record)
          ", bbox="
          (swcad-title-bbox-string (caddr record))
        )
      )
    )
    (swcad-title-princ-line "  <none>")
  )
  (setq status
    (cond
      ((or (/= filedia 1) (/= cmddia 1)) "WARN_FILEDIA_OR_CMDDIA_NOT_1")
      ((= frame-count 0) "FAIL_MISSING_TARGET_FRAME")
      ((= title-count 0) "FAIL_MISSING_TARGET_TITLE")
      (any-missing-tags "FAIL_MISSING_EXPECTED_ATTRIBUTES")
      (any-empty-attrs "WARN_TITLE_ATTRIBUTES_EMPTY")
      (any-missing-native-xdata "WARN_NATIVE_GMTITLE_XDATA_NOT_FOUND")
      (any-visible-frame-native-link "WARN_NATIVE_LINKS_POINT_TO_VISIBLE_FRAMES")
      (other-title-inserts "WARN_OTHER_TITLE_LIKE_INSERTS_REMAIN")
      (T "OK_VERIFY_GMTITLE_READY_FOR_MANUAL_DOUBLE_CLICK_CHECK")
    )
  )
  (swcad-title-princ-line (strcat "Result: " status))
  (swcad-title-princ-line "Manual final check still required: double-click the title block and confirm the GMTITLE table editor opens.")
  (swcad-title-princ-line "Note: native GMTITLE sheet frames remain DR_A*_Outline INSERT/block references; the GMTITLE table editor is checked on the title block.")
  (swcad-title-princ-line "No drawing data was changed.")
  (swcad-title-close-log)
  (princ)
)

(defun swcad-title-gmtitle-verify-all (/ title-name title-enames title-count title-index title-ename title-data title-object title-bbox attr-pairs missing-tags nonempty-attrs native-handles native-target-kinds source-titles source-frames other-title-inserts contaminated filedia cmddia status frame-name frame-count total-frame-count any-missing-tags any-empty-attrs any-missing-native-xdata any-visible-frame-native-link visible-frame-native-link-count frame-records nearest-frame-record nearest-frame-ename nearest-frame-block nearest-frame-handle nearest-frame-bbox nearest-frame-native-handles nearest-frame-xdata-apps title-xdata-apps title-trusted-exemplar frame-trusted-exemplar pair-trusted-exemplar raw-native-pair accepted-pair accepted-record title-role frame-role title-sheet-value title-sheet-normalized frame-sheet-normalized titles-without-target-frame-count title-frame-sheet-mismatch-count frame-index frame-record frame-ename frame-block frame-handle frame-bbox frame-native-handles frame-native-target-kinds frame-xdata-apps paired-title paired-title-handle frames-without-title-count trusted-title-count untrusted-title-count cloned-pair-count trusted-title-frame-counts missing-trusted-frame-blocks used-title-enames selection-risk-count geometry-risk-count overlap-risk-count native-link-title-counts shared-native-link shared-native-link-count)
  (swcad-title-open-gmtitle-verify-all-log)
  (setq title-name (swcad-title-target-title-block-name))
  (setq title-enames (swcad-title-inserts-by-effective-name title-name))
  (setq title-count (length title-enames))
  (setq frame-records (swcad-title-frame-records))
  (setq source-titles (swcad-title-source-title-candidates))
  (setq source-frames (swcad-title-source-frame-candidates))
  (setq other-title-inserts (swcad-title-other-title-like-inserts title-name))
  (setq contaminated (swcad-title-contaminated-target-frame-blocks))
  (setq filedia (getvar "FILEDIA"))
  (setq cmddia (getvar "CMDDIA"))
  (setq any-missing-tags nil)
  (setq any-empty-attrs nil)
  (setq any-missing-native-xdata nil)
  (setq any-visible-frame-native-link nil)
  (setq visible-frame-native-link-count 0)
  (setq titles-without-target-frame-count 0)
  (setq title-frame-sheet-mismatch-count 0)
  (setq frames-without-title-count 0)
  (setq trusted-title-count 0)
  (setq untrusted-title-count 0)
  (setq cloned-pair-count 0)
  (setq trusted-title-frame-counts nil)
  (setq missing-trusted-frame-blocks nil)
  (setq used-title-enames nil)
  (setq total-frame-count 0)
  (setq native-link-title-counts (swcad-title-target-title-native-link-counts))
  (setq shared-native-link-count 0)

  (swcad-title-princ-line "----- SWTITLEGMTITLEVERIFYALL read-only full GMTITLE verification -----")
  (swcad-title-print-loaded-version)
  (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (swcad-title-princ-line (strcat "CTAB: " (getvar "CTAB")))
  (swcad-title-print-work-copy-status)
  (swcad-title-princ-line (strcat "FILEDIA: " (swcad-title-string filedia) " (not changed)"))
  (swcad-title-princ-line (strcat "CMDDIA: " (swcad-title-string cmddia) " (not changed)"))
  (swcad-title-princ-line "Target frame inserts:")
  (foreach frame-name (swcad-title-target-frame-block-candidates)
    (setq frame-count (swcad-title-count-inserts-by-effective-name frame-name))
    (setq total-frame-count (+ total-frame-count frame-count))
    (swcad-title-princ-line (strcat "  " frame-name ": " (itoa frame-count)))
  )
  (swcad-title-princ-line (strcat "Target frame inserts total: " (itoa total-frame-count)))
  (swcad-title-princ-line (strcat "Target title block: " title-name ", inserts=" (itoa title-count)))
  (swcad-title-princ-line (strcat "Remaining source title candidates: " (itoa (length source-titles))))
  (swcad-title-princ-line (strcat "Remaining source sheet frame candidates: " (itoa (length source-frames))))
  (swcad-title-princ-line (strcat "Other non-target title-like inserts: " (itoa (length other-title-inserts))))
  (swcad-title-princ-line (strcat "Contaminated target frame definitions: " (swcad-title-list-string contaminated)))

  (if title-enames
    (progn
      (setq title-index 1)
      (foreach title-ename title-enames
        (setq title-data (entget title-ename '("*")))
        (setq title-object (swcad-title-safe-vla-object title-ename))
        (setq title-bbox (swcad-title-safe-bbox title-ename))
        (setq attr-pairs (if title-object (swcad-title-title-attribute-pairs title-object) nil))
        (setq missing-tags (swcad-title-missing-template-tags attr-pairs))
        (setq nonempty-attrs (swcad-title-nonempty-attribute-count attr-pairs))
        (setq native-handles (swcad-title-gmtitle-native-xdata-info title-ename))
        (setq native-target-kinds (swcad-title-native-link-target-kinds title-ename))
        (setq shared-native-link (swcad-title-native-link-handle-shared-p title-ename native-link-title-counts))
        (setq title-xdata-apps (swcad-title-xdata-app-names title-ename))
        (setq nearest-frame-record (if title-bbox (swcad-title-nearest-frame-record title-bbox frame-records) nil))
        (setq nearest-frame-ename (if nearest-frame-record (car nearest-frame-record) nil))
        (setq nearest-frame-block (if nearest-frame-record (cadr nearest-frame-record) ""))
        (setq nearest-frame-handle (if nearest-frame-record (caddr nearest-frame-record) ""))
        (setq nearest-frame-bbox (if nearest-frame-record (cadddr nearest-frame-record) nil))
        (setq nearest-frame-native-handles
          (if nearest-frame-ename (swcad-title-gmtitle-native-xdata-info nearest-frame-ename) nil)
        )
        (setq nearest-frame-xdata-apps
          (if nearest-frame-ename (swcad-title-xdata-app-names nearest-frame-ename) nil)
        )
        (setq title-sheet-value (swcad-title-attr-value-by-tag attr-pairs "GEN-TITLE-SIZ{6.7}"))
        (setq title-sheet-normalized (swcad-title-normalized-sheet-size title-sheet-value))
        (setq frame-sheet-normalized
          (if (> (strlen nearest-frame-block) 0)
            (swcad-title-sheet-size-from-block-name nearest-frame-block)
            nil
          )
        )
        (setq title-trusted-exemplar
          (if (> (strlen nearest-frame-block) 0)
            (swcad-title-trusted-native-exemplar-title-p title-ename nearest-frame-block)
            nil
          )
        )
        (setq frame-trusted-exemplar
          (if nearest-frame-ename
            (swcad-title-trusted-native-exemplar-frame-p nearest-frame-ename nearest-frame-block)
            nil
          )
        )
        (setq pair-trusted-exemplar
          (and title-trusted-exemplar frame-trusted-exemplar)
        )
        (setq title-role (swcad-title-exemplar-role title-ename))
        (setq frame-role (if nearest-frame-ename (swcad-title-exemplar-role nearest-frame-ename) ""))
        (setq raw-native-pair
          (and
            native-handles
            (swcad-title-internal-native-link-kinds-p native-target-kinds)
            nearest-frame-native-handles
            nearest-frame-bbox
            (not (swcad-title-frame-bbox-size-warning-for-block nearest-frame-block nearest-frame-bbox))
          )
        )
        (setq accepted-record
          (if nearest-frame-ename
            (list title-ename nearest-frame-ename nearest-frame-block title-bbox nearest-frame-bbox title-role frame-role)
            nil
          )
        )
        (setq accepted-pair
          (and
            accepted-record
            (swcad-title-target-pair-native-like-p accepted-record)
          )
        )
        (if missing-tags
          (setq any-missing-tags T)
        )
        (if (= nonempty-attrs 0)
          (setq any-empty-attrs T)
        )
        (if (not native-handles)
          (setq any-missing-native-xdata T)
        )
        (if (member "visible-target-frame" native-target-kinds)
          (progn
            (setq any-visible-frame-native-link T)
            (setq visible-frame-native-link-count (+ visible-frame-native-link-count 1))
          )
        )
        (if shared-native-link
          (setq shared-native-link-count (+ shared-native-link-count 1))
        )
        (if (not nearest-frame-record)
          (setq titles-without-target-frame-count (+ titles-without-target-frame-count 1))
        )
        (if
          (and
            title-sheet-normalized
            frame-sheet-normalized
            (not (equal title-sheet-normalized frame-sheet-normalized))
          )
          (setq title-frame-sheet-mismatch-count (+ title-frame-sheet-mismatch-count 1))
        )
        (if accepted-pair
          (progn
            (setq trusted-title-count (+ trusted-title-count 1))
            (setq trusted-title-frame-counts
              (swcad-title-count-put nearest-frame-block trusted-title-frame-counts)
            )
            (if
              (or
                (swcad-title-exemplar-clone-role-p title-role)
                (swcad-title-exemplar-clone-role-p frame-role)
                (swcad-title-exemplar-legacy-uncertain-native-role-p title-role)
                (swcad-title-exemplar-legacy-uncertain-native-role-p frame-role)
              )
              (setq cloned-pair-count (+ cloned-pair-count 1))
            )
          )
          (progn
            (setq untrusted-title-count (+ untrusted-title-count 1))
            (if nearest-frame-record
              (setq cloned-pair-count (+ cloned-pair-count 1))
            )
          )
        )
        (swcad-title-princ-line
          (strcat
            "Title #"
            (itoa title-index)
            ": handle="
            (swcad-title-string (swcad-title-dxf-value title-data 5))
            ", attrs="
            (itoa (length attr-pairs))
            ", nonempty="
            (itoa nonempty-attrs)
            ", missing-tags="
            (itoa (length missing-tags))
            ", native-links="
            (itoa (length native-handles))
            ", native-link-kinds="
            (swcad-title-list-string native-target-kinds)
            ", shared-native-link="
            (if shared-native-link "yes" "no")
            ", swtitle-marker-pair="
            (if pair-trusted-exemplar "yes" "no")
            ", raw-native-pair="
            (if raw-native-pair "yes" "no")
            ", accepted-pair="
            (if accepted-pair "yes" "no")
            ", title-marker="
            (if title-trusted-exemplar "yes" "no")
            ", frame-marker="
            (if frame-trusted-exemplar "yes" "no")
            ", title-role="
            (if (> (strlen title-role) 0) title-role "<none>")
            ", frame-role="
            (if (> (strlen frame-role) 0) frame-role "<none>")
            ", title-xdata-apps="
            (swcad-title-list-string title-xdata-apps)
            ", title-sheet="
            (if title-sheet-normalized title-sheet-normalized "<none>")
            ", nearest-frame="
            (if nearest-frame-record
              (strcat nearest-frame-block "/" nearest-frame-handle)
              "<missing>"
            )
            ", frame-sheet="
            (if frame-sheet-normalized frame-sheet-normalized "<none>")
            ", frame-native-links="
            (itoa (length nearest-frame-native-handles))
            ", frame-xdata-apps="
            (swcad-title-list-string nearest-frame-xdata-apps)
            ", bbox="
            (swcad-title-bbox-string title-bbox)
          )
        )
        (setq title-index (+ title-index 1))
      )
    )
    (swcad-title-princ-line "Title inserts: <missing>")
  )
  (if frame-records
    (progn
      (swcad-title-princ-line "Target frame detail:")
      (setq frame-index 1)
      (foreach frame-record frame-records
        (setq frame-ename (car frame-record))
        (setq frame-block (cadr frame-record))
        (setq frame-handle (caddr frame-record))
        (setq frame-bbox (cadddr frame-record))
        (setq frame-native-handles (swcad-title-gmtitle-native-xdata-info frame-ename))
        (setq frame-native-target-kinds (swcad-title-native-link-target-kinds frame-ename))
        (setq frame-xdata-apps (swcad-title-xdata-app-names frame-ename))
        (setq frame-role (swcad-title-exemplar-role frame-ename))
        (setq paired-title (swcad-title-title-for-frame-record-unused frame-record title-enames used-title-enames))
        (if paired-title
          (setq used-title-enames (append used-title-enames (list paired-title)))
        )
        (setq paired-title-handle (if paired-title (swcad-title-ename-handle paired-title) ""))
        (if (not paired-title)
          (setq frames-without-title-count (+ frames-without-title-count 1))
        )
        (swcad-title-princ-line
          (strcat
            "Frame #"
            (itoa frame-index)
            ": block="
            frame-block
            ", handle="
            frame-handle
            ", sheet="
            (swcad-title-string (swcad-title-sheet-size-from-block-name frame-block))
            ", paired-title="
            (if paired-title paired-title-handle "<missing>")
            ", native-links="
            (itoa (length frame-native-handles))
            ", native-link-kinds="
            (swcad-title-list-string frame-native-target-kinds)
            ", xdata-apps="
            (swcad-title-list-string frame-xdata-apps)
            ", role="
            (if (> (strlen frame-role) 0) frame-role "<none>")
            ", transform="
            (swcad-title-insert-transform-string frame-ename)
            ", bbox="
            (swcad-title-bbox-string frame-bbox)
          )
        )
        (setq frame-index (+ frame-index 1))
      )
    )
    (swcad-title-princ-line "Target frame detail: <missing>")
  )
  (foreach frame-name (swcad-title-target-frame-block-candidates)
    (setq frame-count (swcad-title-count-inserts-by-effective-name frame-name))
    (if
      (and
        (> frame-count 0)
        (= (swcad-title-count-value frame-name trusted-title-frame-counts) 0)
      )
      (setq missing-trusted-frame-blocks
        (append missing-trusted-frame-blocks (list frame-name))
      )
    )
  )
  (swcad-title-princ-line
    (strcat
      "Native-like accepted GMTITLE titles: "
      (itoa trusted-title-count)
    )
  )
  (swcad-title-princ-line
    (strcat
      "Unaccepted GMTITLE titles: "
      (itoa untrusted-title-count)
    )
  )
  (swcad-title-princ-line
    (strcat
      "Non-native-like GMTITLE pairs needing replacement/recheck: "
      (itoa cloned-pair-count)
    )
  )
  (swcad-title-print-counts "Native-like accepted frame counts:" trusted-title-frame-counts)
  (swcad-title-print-string-list "Target frame blocks without native-like accepted pair:" missing-trusted-frame-blocks)
  (swcad-title-princ-line
    (strcat
      "Titles whose native link points to a visible target frame: "
      (itoa visible-frame-native-link-count)
    )
  )
  (swcad-title-princ-line
    (strcat
      "Titles sharing the same native recognition handle: "
      (itoa shared-native-link-count)
    )
  )
  (swcad-title-princ-line
    (strcat
      "Titles without containing target frame: "
      (itoa titles-without-target-frame-count)
    )
  )
  (swcad-title-princ-line
    (strcat
      "Title/frame sheet mismatches: "
      (itoa title-frame-sheet-mismatch-count)
    )
  )
  (swcad-title-princ-line
    (strcat
      "Target frames without containing title: "
      (itoa frames-without-title-count)
    )
  )
  (setq geometry-risk-count (swcad-title-target-frame-geometry-warning-count frame-records))
  (setq overlap-risk-count (swcad-title-target-frame-overlap-warning-count frame-records))
  (setq selection-risk-count (swcad-title-print-target-frame-selection-diagnostics frame-records))

  (setq status
    (cond
      ((or (/= filedia 1) (/= cmddia 1)) "WARN_FILEDIA_OR_CMDDIA_NOT_1")
      ((= total-frame-count 0) "FAIL_MISSING_TARGET_FRAMES")
      ((= title-count 0) "FAIL_MISSING_TARGET_TITLES")
      (contaminated "WARN_TARGET_FRAME_DEFS_CONTAMINATED")
      (any-missing-tags "FAIL_MISSING_EXPECTED_ATTRIBUTES")
      (any-empty-attrs "WARN_TITLE_ATTRIBUTES_EMPTY")
      (any-missing-native-xdata "WARN_NATIVE_GMTITLE_XDATA_NOT_FOUND")
      (any-visible-frame-native-link "WARN_NATIVE_LINKS_POINT_TO_VISIBLE_FRAMES")
      ((> shared-native-link-count 0) "WARN_SHARED_NATIVE_GMTITLE_LINKS")
      ((> titles-without-target-frame-count 0) "WARN_TITLE_WITHOUT_TARGET_FRAME")
      ((> title-frame-sheet-mismatch-count 0) "WARN_TITLE_FRAME_SHEET_MISMATCH")
      ((> frames-without-title-count 0) "WARN_TARGET_FRAME_WITHOUT_TITLE")
      ((> geometry-risk-count 0) "WARN_TARGET_FRAME_GEOMETRY_INVALID")
      ((> selection-risk-count 0) "WARN_TARGET_FRAME_SELECTION_RISK")
      ((> (length missing-trusted-frame-blocks) 0) "WARN_TARGET_FRAME_WITHOUT_TRUSTED_EXEMPLAR")
      ((> untrusted-title-count 0) "WARN_GMTITLE_PAIRS_NOT_NATIVE_LIKE")
      ((> cloned-pair-count 0) "WARN_CLONED_GMTITLE_FRAME_BEHAVIOR_UNVERIFIED")
      ((> (length source-titles) 0) "WARN_SOURCE_TITLE_INSERTS_REMAIN")
      ((> (length source-frames) 0) "WARN_SOURCE_FRAME_INSERTS_REMAIN")
      ((> (length other-title-inserts) 0) "WARN_OTHER_TITLE_LIKE_INSERTS_REMAIN")
      (T "OK_VERIFY_ALL_GMTITLE_READY")
    )
  )
  (swcad-title-princ-line (strcat "Result: " status))
  (swcad-title-princ-line "Note: SWTITLE markers and copied xdata alone are not treated as native GMTITLE proof.")
  (swcad-title-princ-line "Note: native GMTITLE sheet frames remain DR_A*_Outline INSERT/block references; the GMTITLE table editor is checked on the title block.")
  (swcad-title-princ-line "No drawing data was changed.")
  (swcad-title-close-log)
  (princ)
)

(defun swcad-title-native-frame-completion-check (/ title-name title-enames frame-records frame-record frame-index frame-ename frame-block frame-handle frame-bbox sheet paired-title paired-title-handle title-role frame-role pair-trusted clone-pair legacy-uncertain native-like reason geometry-warning attr-pairs missing-tags nonempty-attrs source-titles source-frames total-frame-count paired-count native-like-count clone-count untrusted-count shared-link-count missing-title-count missing-tags-count empty-attrs-count sheet-total-counts sheet-native-like-counts sheet-clone-counts required-sheets missing-required-sheets required-sheet a3a4-total-count a3a4-native-like-count a3a4-missing-native-like-count selection-risk-count geometry-risk-count overlap-risk-count status used-title-enames)
  (swcad-title-open-native-frame-check-log)
  (setq title-name (swcad-title-target-title-block-name))
  (setq title-enames (swcad-title-inserts-by-effective-name title-name))
  (setq frame-records (swcad-title-frame-records))
  (setq source-titles (swcad-title-source-title-candidates))
  (setq source-frames (swcad-title-source-frame-candidates))
  (setq total-frame-count 0)
  (setq paired-count 0)
  (setq native-like-count 0)
  (setq clone-count 0)
  (setq untrusted-count 0)
  (setq shared-link-count 0)
  (setq missing-title-count 0)
  (setq missing-tags-count 0)
  (setq empty-attrs-count 0)
  (setq sheet-total-counts nil)
  (setq sheet-native-like-counts nil)
  (setq sheet-clone-counts nil)
  (setq required-sheets '("A2" "A3" "A4"))
  (setq missing-required-sheets nil)
  (setq selection-risk-count 0)
  (setq used-title-enames nil)

  (swcad-title-princ-line "----- SWTITLENATIVEFRAMECHECK read-only A2/A3/A4 native frame check -----")
  (swcad-title-print-loaded-version)
  (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (swcad-title-princ-line (strcat "CTAB: " (getvar "CTAB")))
  (swcad-title-print-work-copy-status)
  (swcad-title-princ-line (strcat "Target title block: " title-name ", inserts=" (itoa (length title-enames))))
  (swcad-title-princ-line (strcat "Remaining source title candidates: " (itoa (length source-titles))))
  (swcad-title-princ-line (strcat "Remaining source sheet frame candidates: " (itoa (length source-frames))))

  (if frame-records
    (progn
      (swcad-title-princ-line "Native frame readiness by visible target frame:")
      (setq frame-index 1)
      (foreach frame-record frame-records
        (setq frame-ename (car frame-record))
        (setq frame-block (cadr frame-record))
        (setq frame-handle (caddr frame-record))
        (setq frame-bbox (cadddr frame-record))
        (setq sheet (swcad-title-sheet-size-from-block-name frame-block))
        (setq geometry-warning (swcad-title-frame-bbox-size-warning-for-block frame-block frame-bbox))
        (setq paired-title (swcad-title-title-for-frame-record-unused frame-record title-enames used-title-enames))
        (if paired-title
          (setq used-title-enames (append used-title-enames (list paired-title)))
        )
        (setq paired-title-handle (if paired-title (swcad-title-ename-handle paired-title) ""))
        (setq title-role (if paired-title (swcad-title-exemplar-role paired-title) ""))
        (setq frame-role (swcad-title-exemplar-role frame-ename))
        (setq pair-trusted
          (if paired-title
            (swcad-title-trusted-native-exemplar-pair-p paired-title frame-ename frame-block)
            nil
          )
        )
        (setq clone-pair
          (or
            (swcad-title-exemplar-clone-role-p title-role)
            (swcad-title-exemplar-clone-role-p frame-role)
          )
        )
        (setq legacy-uncertain
          (or
            (swcad-title-exemplar-legacy-uncertain-native-role-p title-role)
            (swcad-title-exemplar-legacy-uncertain-native-role-p frame-role)
          )
        )
        (setq native-like
          (and
            paired-title
            (swcad-title-target-pair-native-like-p
              (list paired-title frame-ename frame-block nil frame-bbox title-role frame-role)
            )
          )
        )
        (setq reason
          (if paired-title
            (swcad-title-target-pair-upgrade-reason
              (list paired-title frame-ename frame-block nil frame-bbox title-role frame-role)
            )
            "missing-title"
          )
        )
        (if (equal reason "shared-native-link-handle")
          (setq shared-link-count (+ shared-link-count 1))
        )
        (setq attr-pairs
          (if paired-title
            (swcad-title-title-attribute-pairs (swcad-title-safe-vla-object paired-title))
            nil
          )
        )
        (setq missing-tags (if paired-title (swcad-title-missing-template-tags attr-pairs) nil))
        (setq nonempty-attrs (if paired-title (swcad-title-nonempty-attribute-count attr-pairs) 0))
        (setq total-frame-count (+ total-frame-count 1))
        (setq sheet-total-counts (swcad-title-count-put (if sheet sheet frame-block) sheet-total-counts))
        (cond
          (native-like
            (setq native-like-count (+ native-like-count 1))
            (setq sheet-native-like-counts (swcad-title-count-put (if sheet sheet frame-block) sheet-native-like-counts))
          )
          (clone-pair
            (setq clone-count (+ clone-count 1))
            (setq sheet-clone-counts (swcad-title-count-put (if sheet sheet frame-block) sheet-clone-counts))
          )
          ((not pair-trusted)
            (setq untrusted-count (+ untrusted-count 1))
          )
        )
        (if paired-title
          (setq paired-count (+ paired-count 1))
          (setq missing-title-count (+ missing-title-count 1))
        )
        (if missing-tags
          (setq missing-tags-count (+ missing-tags-count 1))
        )
        (if (and paired-title (= nonempty-attrs 0))
          (setq empty-attrs-count (+ empty-attrs-count 1))
        )
        (swcad-title-princ-line
          (strcat
            "  #"
            (itoa frame-index)
            " sheet="
            (if sheet sheet "<unknown>")
            ", frame="
            frame-block
            "/"
            frame-handle
            ", title="
            (if paired-title paired-title-handle "<missing>")
            ", swtitle-marker="
            (if pair-trusted "yes" "no")
            ", native-like="
            (if native-like "yes" "no")
            ", clone="
            (if clone-pair "yes" "no")
            ", finalize-recheck-marker="
            (if legacy-uncertain "yes" "no")
            ", title-role="
            (if (> (strlen title-role) 0) title-role "<none>")
            ", frame-role="
            (if (> (strlen frame-role) 0) frame-role "<none>")
            ", reason="
            reason
            (if geometry-warning
              (strcat ", geometry-warning=" geometry-warning)
              ""
            )
            ", attrs-nonempty="
            (itoa nonempty-attrs)
            ", missing-tags="
            (itoa (length missing-tags))
            ", transform="
            (swcad-title-insert-transform-string frame-ename)
            ", bbox="
            (swcad-title-bbox-string frame-bbox)
          )
        )
        (setq frame-index (+ frame-index 1))
      )
    )
    (swcad-title-princ-line "Native frame readiness by visible target frame: <missing>")
  )

  (swcad-title-print-counts "Visible target frame counts by sheet:" sheet-total-counts)
  (swcad-title-print-counts "Native-like target frame counts by sheet:" sheet-native-like-counts)
  (swcad-title-print-counts "Clone target frame counts by sheet:" sheet-clone-counts)
  (setq geometry-risk-count (swcad-title-target-frame-geometry-warning-count frame-records))
  (setq overlap-risk-count (swcad-title-target-frame-overlap-warning-count frame-records))
  (setq selection-risk-count (swcad-title-print-target-frame-selection-diagnostics frame-records))
  (foreach required-sheet required-sheets
    (if (= (swcad-title-count-value required-sheet sheet-total-counts) 0)
      (setq missing-required-sheets (append missing-required-sheets (list required-sheet)))
    )
  )
  (swcad-title-print-string-list "Missing required A2/A3/A4 target sheets:" missing-required-sheets)
  (setq a3a4-total-count
    (+
      (swcad-title-count-value "A3" sheet-total-counts)
      (swcad-title-count-value "A4" sheet-total-counts)
    )
  )
  (setq a3a4-native-like-count
    (+
      (swcad-title-count-value "A3" sheet-native-like-counts)
      (swcad-title-count-value "A4" sheet-native-like-counts)
    )
  )
  (setq a3a4-missing-native-like-count (- a3a4-total-count a3a4-native-like-count))
  (swcad-title-princ-line
    (strcat
      "A3/A4 native-like completion: "
      (itoa a3a4-native-like-count)
      " / "
      (itoa a3a4-total-count)
    )
  )
  (swcad-title-princ-line "Summary:")
  (swcad-title-princ-line (strcat "  target frames: " (itoa total-frame-count)))
  (swcad-title-princ-line (strcat "  paired titles: " (itoa paired-count)))
  (swcad-title-princ-line (strcat "  native-like pairs: " (itoa native-like-count)))
  (swcad-title-princ-line (strcat "  cloned pairs: " (itoa clone-count)))
  (swcad-title-princ-line (strcat "  shared native-link pairs: " (itoa shared-link-count)))
  (swcad-title-princ-line (strcat "  untrusted/non-marker pairs: " (itoa untrusted-count)))
  (swcad-title-princ-line (strcat "  frames without title: " (itoa missing-title-count)))
  (swcad-title-princ-line (strcat "  titles with missing tags: " (itoa missing-tags-count)))
  (swcad-title-princ-line (strcat "  titles with empty attributes: " (itoa empty-attrs-count)))
  (swcad-title-princ-line (strcat "  target frame selection risk warnings: " (itoa selection-risk-count)))

  (setq status
    (cond
      ((= total-frame-count 0) "FAIL_MISSING_TARGET_FRAMES")
      ((> geometry-risk-count 0) "WARN_TARGET_FRAME_GEOMETRY_INVALID")
      ((> clone-count 0) "WARN_CLONED_GMTITLE_FRAME_NEEDS_NATIVE_UPGRADE")
      ((> shared-link-count 0) "WARN_SHARED_NATIVE_GMTITLE_LINKS")
      ((> a3a4-missing-native-like-count 0) "WARN_A3_A4_TARGET_FRAME_NOT_NATIVE_LIKE")
      (missing-required-sheets "WARN_REQUIRED_A2_A3_A4_TARGET_SHEET_MISSING")
      ((> (length source-titles) 0) "WARN_SOURCE_TITLE_INSERTS_REMAIN")
      ((> (length source-frames) 0) "WARN_SOURCE_FRAME_INSERTS_REMAIN")
      ((> missing-title-count 0) "WARN_TARGET_FRAME_WITHOUT_TITLE")
      ((> missing-tags-count 0) "FAIL_MISSING_EXPECTED_ATTRIBUTES")
      ((> empty-attrs-count 0) "WARN_TITLE_ATTRIBUTES_EMPTY")
      ((> selection-risk-count 0) "WARN_TARGET_FRAME_SELECTION_RISK")
      ((and (= a3a4-missing-native-like-count 0) (> untrusted-count 0)) "OK_A3_A4_NATIVE_FRAME_READY_A2_BASELINE_UNMARKED")
      ((/= native-like-count total-frame-count) "WARN_NOT_ALL_TARGET_FRAMES_NATIVE_LIKE")
      (T "OK_A2_A3_A4_NATIVE_FRAME_READY_FOR_MANUAL_CHECK")
    )
  )
  (swcad-title-princ-line (strcat "Result: " status))
  (if (> clone-count 0)
    (progn
      (swcad-title-princ-line "GMPOWEREDIT diagnosis: cloned GMTITLE pairs remain.")
      (swcad-title-princ-line "Clone means the visible frame/title and attributes were copied, but GstarCAD native editor recognition is not proven for that pair.")
      (swcad-title-princ-line "Next: run SWTITLEUPGRADENATIVESTATUS, then SWTITLEUPGRADENATIVEA3A4BATCH or SWTITLEUPGRADENATIVESELECT.")
    )
  )
  (if (> shared-link-count 0)
    (progn
      (swcad-title-princ-line "GMPOWEREDIT diagnosis: multiple GMTITLE titles share the same internal native recognition handle.")
      (swcad-title-princ-line "This is typical of preserve-copy/clone output: it can look correct, but double-click recognition can fall back to REFEDIT or block editing.")
      (swcad-title-princ-line "Next: replace those pairs with fresh native GMTITLE output using SWTITLEUPGRADENATIVESELECT or SWTITLEUPGRADENATIVEA3A4BATCH.")
    )
  )
  (if (and missing-required-sheets (> (length source-frames) 0))
    (progn
      (swcad-title-princ-line "Missing-sheet diagnosis: old SOLIDWORKS frame-only sheets still remain.")
      (swcad-title-princ-line "Next after A3 clone review: run SWTITLEFASTSTATUS and handle A4 with SWTITLEFRAMEONLYAPPLY or SWTITLETRANSFERFASTBATCH.")
    )
  )
  (swcad-title-princ-line "Manual final check still required: double-click representative A2/A3/A4 DR_titlea_3rd title blocks in GstarCAD.")
  (swcad-title-princ-line "Note: DR_A*_Outline sheet frames are still INSERT/block references; test the paired title block for the GMTITLE table editor.")
  (swcad-title-princ-line "No drawing data was changed.")
  (swcad-title-close-log)
  (princ)
)

(defun swcad-title-insert-handle-list (/ ss total index ename data handle result)
  (setq result nil)
  (setq ss (ssget "_X" '((0 . "INSERT"))))
  (setq total (if ss (sslength ss) 0))
  (setq index 0)
  (while (< index total)
    (setq ename (ssname ss index))
    (setq data (entget ename '("*")))
    (setq handle (strcase (swcad-title-string (swcad-title-dxf-value data 5))))
    (if (> (strlen handle) 0)
      (setq result (append result (list handle)))
    )
    (setq index (+ index 1))
  )
  result
)

(defun swcad-title-native-gmtitle-result-valid-p (result frame-block / title frame actual-title actual-frame geometry-warning)
  (setq title (if result (car result) nil))
  (setq frame (if result (cadr result) nil))
  (setq actual-title (if title (swcad-title-effective-insert-name title) ""))
  (setq actual-frame (if frame (swcad-title-effective-insert-name frame) ""))
  (setq geometry-warning
    (if frame
      (swcad-title-frame-bbox-size-warning-for-block
        frame-block
        (swcad-title-frame-reference-effective-bbox frame frame-block)
      )
      nil
    )
  )
  (and
    title
    frame
    (swcad-title-native-target-title-name-p actual-title)
    (swcad-title-frame-name-matches-p actual-frame frame-block)
    (not geometry-warning)
  )
)

(defun swcad-title-new-insert-enames (before-handles / ss total index ename data handle result)
  (setq result nil)
  (setq ss (ssget "_X" '((0 . "INSERT"))))
  (setq total (if ss (sslength ss) 0))
  (setq index 0)
  (while (< index total)
    (setq ename (ssname ss index))
    (setq data (entget ename '("*")))
    (setq handle (strcase (swcad-title-string (swcad-title-dxf-value data 5))))
    (if (and (> (strlen handle) 0) (not (member handle before-handles)))
      (setq result (append result (list ename)))
    )
    (setq index (+ index 1))
  )
  result
)

(defun swcad-title-template-tag-p (tag / upper slot found)
  (setq upper (strcase (swcad-title-string tag)))
  (setq found nil)
  (foreach slot *swcad-title-transfer-template*
    (if (equal upper (strcase (car slot)))
      (setq found T)
    )
  )
  found
)

(defun swcad-title-insert-template-attribute-count (ename / object attrs attr count)
  (setq object (swcad-title-safe-vla-object ename))
  (setq attrs (if object (swcad-title-get-insert-attributes object) nil))
  (setq count 0)
  (foreach attr attrs
    (if (swcad-title-template-tag-p (swcad-title-attribute-tag attr))
      (setq count (+ count 1))
    )
  )
  count
)

(defun swcad-title-select-new-gmtitle-title (enames / title-name best best-score ename name score attr-count)
  (setq title-name (strcase (swcad-title-target-title-block-name)))
  (setq best nil)
  (setq best-score 0)
  (foreach ename enames
    (setq name (strcase (swcad-title-effective-insert-name ename)))
    (setq attr-count (swcad-title-insert-template-attribute-count ename))
    (setq score attr-count)
    (if (equal name title-name)
      (setq score (+ score 100))
    )
    (if (and (> score best-score) (> attr-count 0))
      (progn
        (setq best ename)
        (setq best-score score)
      )
    )
  )
  best
)

(defun swcad-title-frame-name-matches-p (name frame-block)
  (equal
    (strcase (swcad-title-string name))
    (strcase (swcad-title-string frame-block))
  )
)

(defun swcad-title-select-new-gmtitle-frame (enames title-ename frame-block / frame-name best fallback best-area ename name bbox area warning)
  (setq frame-name (strcase (swcad-title-string frame-block)))
  (if (= (strlen frame-name) 0)
    (setq frame-name (strcase (swcad-title-target-frame-block-name)))
  )
  (setq best nil)
  (setq fallback nil)
  (setq best-area 0.0)
  (foreach ename enames
    (if (not (eq ename title-ename))
      (progn
        (setq name (strcase (swcad-title-effective-insert-name ename)))
        (setq bbox (swcad-title-safe-bbox ename))
        (setq area (swcad-title-bbox-area bbox))
        (cond
          ((equal name frame-name)
            (if (not fallback)
              (setq fallback ename)
            )
            (setq warning (swcad-title-frame-bbox-size-warning-for-block frame-block bbox))
            (if (and (not best) (not warning))
              (setq best ename)
            )
          )
          ((and (not fallback) (> area best-area))
            (setq fallback ename)
            (setq best-area area)
          )
        )
      )
    )
  )
  (if best best fallback)
)

(defun swcad-title-script-active-p (/ active)
  (setq active (swcad-title-safe-getvar "CMDACTIVE"))
  (and active (/= 0 (logand active 4)))
)

(defun swcad-title-function-available-p (name / atoms)
  (setq atoms (atoms-family 1))
  (and atoms (member (strcase (swcad-title-string name)) atoms))
)

(defun swcad-title-native-gmtitle-command-call (placement-point / args runner)
  (setq args
    (if placement-point
      (list "_.-GMTITLE" placement-point)
      (list "_.-GMTITLE")
    )
  )
  (setq runner
    (cond
      ((swcad-title-function-available-p "VL-CMDF") 'vl-cmdf)
      ((swcad-title-function-available-p "COMMAND-S") 'command-s)
      (T 'command)
    )
  )
  (swcad-title-princ-line
    (strcat
      "  Command-line runner: "
      (swcad-title-string runner)
    )
  )
  (vl-catch-all-apply runner args)
)

(defun swcad-title-run-native-gmtitle-commandline (frame-block placement-point / before-handles new-enames title-ename frame-ename old-osmode old-dynmode command-result guard prompt current-new-enames)
  (setq before-handles (swcad-title-insert-handle-list))
  (setq *swcad-title-last-native-gmtitle-abort-reason* nil)
  (setq *swcad-title-last-native-gmtitle-placement-used* nil)
  (swcad-title-princ-line
    (strcat
      "Trying command-line -GMTITLE with current GstarCAD defaults for "
      (swcad-title-string frame-block)
      "."
    )
  )
  (if placement-point
    (swcad-title-princ-line
      (strcat
        "  Command-line insertion point: "
        (swcad-title-point-string placement-point)
      )
    )
  )
  (setq old-osmode (swcad-title-safe-getvar "OSMODE"))
  (setq old-dynmode (swcad-title-safe-getvar "DYNMODE"))
  (if old-osmode
    (swcad-title-safe-setvar "OSMODE" 0)
  )
  (setq command-result (swcad-title-native-gmtitle-command-call placement-point))
  (if (vl-catch-all-error-p command-result)
    (progn
      (setq *swcad-title-last-native-gmtitle-abort-reason* "COMMANDLINE_GMTITLE_ERROR")
      (swcad-title-princ-line
        (strcat
          "  Command-line -GMTITLE error: "
          (vl-catch-all-error-message command-result)
        )
      )
    )
  )
  (setq guard 0)
  (while (and (> (getvar "CMDACTIVE") 0) (< guard 20))
    (setq prompt (swcad-title-command-prompt-string))
    (setq current-new-enames (swcad-title-new-insert-enames before-handles))
    (cond
      (current-new-enames
        (setq *swcad-title-last-native-gmtitle-abort-reason*
          "COMMANDLINE_POST_INSERT_PROMPT_CANCELLED"
        )
        (swcad-title-princ-line
          "  Command-line -GMTITLE created inserts but left an extra prompt; cancelling the extra prompt."
        )
        (if (> (strlen (vl-string-trim " \t\r\n" (swcad-title-string prompt))) 0)
          (swcad-title-princ-line
            (strcat "  Prompt was: " (swcad-title-string prompt))
          )
        )
        (swcad-title-cancel-active-command)
        (setq guard 20)
      )
      ((> guard 2)
        (setq *swcad-title-last-native-gmtitle-abort-reason*
          "COMMANDLINE_GMTITLE_NO_INSERTS_CANCELLED"
        )
        (swcad-title-princ-line
          "  Command-line -GMTITLE did not create inserts promptly; cancelling and falling back if needed."
        )
        (swcad-title-cancel-active-command)
        (setq guard 20)
      )
    )
    (setq guard (+ guard 1))
  )
  (swcad-title-restore-gmtitle-input-vars old-osmode old-dynmode)
  (setq new-enames (swcad-title-new-insert-enames before-handles))
  (if new-enames
    (setq *swcad-title-last-native-gmtitle-placement-used* T)
  )
  (setq title-ename (swcad-title-select-new-gmtitle-title new-enames))
  (setq frame-ename (swcad-title-select-new-gmtitle-frame new-enames title-ename frame-block))
  (swcad-title-princ-line
    (strcat
      "  Command-line -GMTITLE new INSERT count: "
      (itoa (length new-enames))
    )
  )
  (swcad-title-insert-log-label "  Command-line GMTITLE title insert" title-ename)
  (swcad-title-insert-log-label "  Command-line GMTITLE frame insert" frame-ename)
  (list title-ename frame-ename new-enames)
)

(defun swcad-title-run-native-gmtitle-prefer-commandline (frame-block placement-point / result new-count deleted-count commandline-error script-active skip-commandline skip-interactive-batch)
  (setq script-active (swcad-title-script-active-p))
  (setq skip-commandline (and script-active (not *swcad-title-allow-script-commandline-gmtitle*)))
  (setq skip-interactive-batch
    (and
      *swcad-title-native-upgrade-batch-mode*
      (not *swcad-title-allow-batch-interactive-native-gmtitle*)
    )
  )
  (if skip-commandline
    (progn
      (setq result (list nil nil nil))
      (setq *swcad-title-last-native-gmtitle-abort-reason* "COMMANDLINE_GMTITLE_SKIPPED_IN_SCRIPT")
      (swcad-title-princ-line
        "Command-line -GMTITLE skipped because a SCRIPT/automation command is active."
      )
    )
    (progn
      (setq result
        (vl-catch-all-apply
          'swcad-title-run-native-gmtitle-commandline
          (list frame-block placement-point)
        )
      )
      (if (vl-catch-all-error-p result)
        (progn
          (setq commandline-error (vl-catch-all-error-message result))
          (setq result (list nil nil nil))
          (setq *swcad-title-last-native-gmtitle-abort-reason* "COMMANDLINE_GMTITLE_EXCEPTION")
          (swcad-title-princ-line
            (strcat
              "  Command-line -GMTITLE exception: "
              commandline-error
            )
          )
        )
      )
    )
  )
  (if (swcad-title-native-gmtitle-result-valid-p result frame-block)
    result
    (progn
      (setq new-count (length (caddr result)))
      (if (> new-count 0)
        (progn
          (setq deleted-count (swcad-title-delete-ename-list (caddr result)))
          (swcad-title-princ-line
            (strcat
              "  Command-line -GMTITLE did not match the requested DR frame/title; removed inserts: "
              (itoa deleted-count)
            )
          )
        )
      )
      (if script-active
        (progn
          (swcad-title-princ-line
            "Interactive GMTITLE fallback skipped because a SCRIPT/automation command is active."
          )
          result
        )
        (if skip-interactive-batch
          (progn
            (setq *swcad-title-last-native-gmtitle-abort-reason*
              "INTERACTIVE_GMTITLE_SKIPPED_IN_BATCH"
            )
            (swcad-title-princ-line
              "Interactive GMTITLE fallback skipped in batch mode."
            )
            (swcad-title-princ-line
              "Reason: the current GstarCAD GMTITLE dialog opens with ISO defaults, so batch automation cannot safely choose the required DR frame/title."
            )
            (swcad-title-princ-line
              (strcat
                "Required manual selection would be: paper="
                (swcad-title-string frame-block)
                ", title="
                (swcad-title-target-title-block-name)
                ", Frame positioning ON, Object move OFF."
              )
            )
            (swcad-title-princ-line
              "For A3/A4 targets, use SWTITLEA3A4PREP, normal GMTITLE, then SWTITLEA3A4FINISH for one sheet."
            )
            result
          )
          (progn
            (swcad-title-princ-line
              "Falling back to interactive GMTITLE dialog. Select the requested DR frame/title once."
            )
            (swcad-title-run-native-gmtitle frame-block placement-point)
          )
        )
      )
    )
  )
)

(defun swcad-title-run-native-gmtitle (frame-block placement-point / before-handles new-enames title-ename frame-ename guard prompt placement-used old-osmode old-dynmode current-new-enames)
  (setq before-handles (swcad-title-insert-handle-list))
  (setq *swcad-title-last-native-gmtitle-abort-reason* nil)
  (setq *swcad-title-last-native-gmtitle-placement-used* nil)
  (swcad-title-princ-line
    (strcat
      "Starting native GMTITLE. In the GMTITLE dialog, choose "
      (swcad-title-string frame-block)
      " and "
      (swcad-title-target-title-block-name)
      ", then place/confirm it."
    )
  )
  (swcad-title-princ-line (strcat "  Paper/format: " (swcad-title-string frame-block)))
  (swcad-title-princ-line (strcat "  Title block: " (swcad-title-target-title-block-name)))
  (swcad-title-princ-line "  Keep ON: Frame positioning.")
  (swcad-title-princ-line "  Turn OFF: Object move.")
  (if placement-point
    (progn
      (swcad-title-princ-line
        (strcat
          "  Lower-left placement point: "
          (swcad-title-point-string placement-point)
        )
      )
      (swcad-title-princ-line "  GstarCAD may still show the live cursor handle at the GMTITLE center; that is only a temporary preview handle.")
      (swcad-title-princ-line "  If GstarCAD asks for an insertion point, use the lower-left point above.")
      (swcad-title-princ-line "  If GstarCAD asks for object/new location, cancel and turn OFF Object move; otherwise drawing contents can move.")
    )
    (swcad-title-princ-line "  Keep the default placement if possible; this LISP aligns the GMTITLE pair afterward.")
  )
  (swcad-title-princ-line "  Note: automatic command-line selection for this first native GMTITLE is not available in current tests.")
  (swcad-title-princ-line "FILEDIA and CMDDIA are not changed by this command.")
  (setq old-osmode (swcad-title-safe-getvar "OSMODE"))
  (setq old-dynmode (swcad-title-safe-getvar "DYNMODE"))
  (if old-osmode
    (swcad-title-safe-setvar "OSMODE" 0)
  )
  (if old-osmode
    (swcad-title-princ-line "  Temporarily disabled object snap during GMTITLE placement; it will be restored afterward.")
  )
  (initdia)
  (command "GMTITLE")
  (setq guard 0)
  (setq placement-used nil)
  (while (and (> (getvar "CMDACTIVE") 0) (< guard 200))
    (setq prompt (swcad-title-command-prompt-string))
    (setq current-new-enames (swcad-title-new-insert-enames before-handles))
    (cond
      ((and
         placement-point
         (not placement-used)
         (swcad-title-gmtitle-placement-prompt-p prompt)
       )
        (swcad-title-princ-line
          (strcat
            "Auto-answering GMTITLE placement prompt with lower-left point: "
            (swcad-title-point-string placement-point)
          )
        )
        (command placement-point)
        (setq placement-used T)
      )
      ((and
         placement-point
         (not placement-used)
         (= (strlen (vl-string-trim " \t\r\n" (swcad-title-string prompt))) 0)
       )
        (swcad-title-princ-line
          (strcat
            "Auto-answering active GMTITLE placement state with lower-left point: "
            (swcad-title-point-string placement-point)
          )
        )
        (if (> (strlen (vl-string-trim " \t\r\n" (swcad-title-string prompt))) 0)
          (swcad-title-princ-line
            (strcat "  Prompt was: " (swcad-title-string prompt))
          )
          (swcad-title-princ-line "  Prompt text was blank; using the placement fallback before command pause.")
        )
        (command placement-point)
        (setq placement-used T)
      )
      ((and
         current-new-enames
         (not (swcad-title-gmtitle-placement-prompt-p prompt))
         (swcad-title-gmtitle-object-move-prompt-p prompt)
       )
        (setq *swcad-title-last-native-gmtitle-abort-reason*
          "OBJECT_MOVE_PROMPT_CANCELLED_AFTER_GMTITLE_CREATED"
        )
        (swcad-title-princ-line
          "Detected a GMTITLE object/new-location prompt after frame/title creation; cancelling it so drawing contents are not moved."
        )
        (swcad-title-princ-line
          (strcat "  Prompt was: " (swcad-title-string prompt))
        )
        (swcad-title-cancel-active-command)
        (setq guard 200)
      )
      ((and
         current-new-enames
         (not (swcad-title-gmtitle-placement-prompt-p prompt))
         (> (strlen (vl-string-trim " \t\r\n" (swcad-title-string prompt))) 0)
       )
        (setq *swcad-title-last-native-gmtitle-abort-reason*
          "POST_INSERT_PROMPT_CANCELLED_AFTER_GMTITLE_CREATED"
        )
        (swcad-title-princ-line
          "Detected an extra post-GMTITLE prompt after frame/title creation; cancelling instead of guessing a coordinate."
        )
        (swcad-title-princ-line
          (strcat "  Prompt was: " (swcad-title-string prompt))
        )
        (swcad-title-cancel-active-command)
        (setq guard 200)
      )
      (T
        (command pause)
      )
    )
    (setq guard (+ guard 1))
  )
  (swcad-title-restore-gmtitle-input-vars old-osmode old-dynmode)
  (if (and placement-point (not placement-used))
    (swcad-title-princ-line "Auto lower-left placement was not sent because no insertion-point prompt was detected. A native GMTITLE that must be moved afterward is not accepted for GMPOWEREDIT/double-click completion.")
  )
  (setq *swcad-title-last-native-gmtitle-placement-used* placement-used)
  (setq new-enames (swcad-title-new-insert-enames before-handles))
  (setq title-ename (swcad-title-select-new-gmtitle-title new-enames))
  (setq frame-ename (swcad-title-select-new-gmtitle-frame new-enames title-ename frame-block))
  (list title-ename frame-ename new-enames)
)

(defun swcad-title-insert-log-label (label ename / data)
  (if ename
    (progn
      (setq data (entget ename '("*")))
      (swcad-title-princ-line
        (strcat
          label
          ": handle="
          (swcad-title-string (swcad-title-dxf-value data 5))
          ", block="
          (swcad-title-effective-insert-name ename)
          ", bbox="
          (swcad-title-bbox-string (swcad-title-safe-bbox ename))
        )
      )
    )
    (swcad-title-princ-line (strcat label ": <none>"))
  )
)

(defun swcad-title-print-basic-entity (ename data / object object-name)
  (setq object (swcad-title-safe-vla-object ename))
  (setq object-name (swcad-title-safe-vla-get object 'ObjectName))
  (swcad-title-princ-line "----- SWTITLEDEBUG BASIC -----")
  (swcad-title-princ-line (strcat "entity type: " (swcad-title-string (swcad-title-dxf-value data 0))))
  (swcad-title-princ-line (strcat "handle: " (swcad-title-string (swcad-title-dxf-value data 5))))
  (swcad-title-princ-line (strcat "layer: " (swcad-title-string (swcad-title-dxf-value data 8))))
  (swcad-title-princ-line (strcat "block name: " (swcad-title-string (swcad-title-dxf-value data 2))))
  (swcad-title-princ-line (strcat "vla object: " (swcad-title-string object-name)))
)

(defun swcad-title-print-data-section (title data / pair)
  (swcad-title-princ-line title)
  (foreach pair data
    (swcad-title-code-value-line "  DXF" pair)
  )
)

(defun swcad-title-print-xdata (ename / xdata pair)
  (setq xdata (entget ename '("*")))
  (swcad-title-princ-line "----- SWTITLEDEBUG XDATA / RAW ENTGET -----")
  (if xdata
    (foreach pair xdata
      (swcad-title-code-value-line "  DXF" pair)
    )
    (swcad-title-princ-line "  No entget data returned.")
  )
)

(defun swcad-title-print-insert-attributes (ename / next edata etype count)
  (swcad-title-princ-line "----- SWTITLEDEBUG ATTRIBUTES -----")
  (setq count 0)
  (foreach edata (swcad-title-insert-attributes ename)
    (setq count (+ count 1))
    (swcad-title-princ-line "  ATTRIBUTE")
    (swcad-title-princ-line (strcat "    tag: " (swcad-title-string (swcad-title-dxf-value edata 2))))
    (swcad-title-princ-line (strcat "    value: " (swcad-title-string (swcad-title-dxf-value edata 1))))
    (swcad-title-princ-line (strcat "    layer: " (swcad-title-string (swcad-title-dxf-value edata 8))))
    (swcad-title-princ-line (strcat "    handle: " (swcad-title-string (swcad-title-dxf-value edata 5))))
  )
  (if (= count 0)
    (progn
      (swcad-title-princ-line "  No following attributes.")
      (swcad-title-princ-line "  No attributes found.")
    )
  )
)

(defun swcad-title-debug-entity (ename / data etype)
  (swcad-title-open-debug-log)
  (setq data (entget ename))
  (setq etype (swcad-title-dxf-value data 0))
  (swcad-title-print-basic-entity ename data)
  (if (= etype "INSERT")
    (swcad-title-print-insert-attributes ename)
    (progn
      (swcad-title-princ-line "----- SWTITLEDEBUG ATTRIBUTES -----")
      (swcad-title-princ-line "  Selected entity is not an INSERT.")
    )
  )
  (swcad-title-print-data-section "----- SWTITLEDEBUG ENTGET -----" data)
  (swcad-title-print-xdata ename)
  (swcad-title-princ-line "----- SWTITLEDEBUG END -----")
  (swcad-title-close-log)
  (princ)
)

(defun swcad-title-first-implied-selection (/ result ss)
  (setq result (vl-catch-all-apply 'ssget (list "_I")))
  (if (vl-catch-all-error-p result)
    nil
    (progn
      (setq ss result)
      (if (and ss (> (sslength ss) 0))
        (ssname ss 0)
        nil
      )
    )
  )
)

(defun swcad-title-scale-not-ready (command)
  (princ (strcat "\n" command " is reserved for read-only title/scale diagnostics."))
  (princ "\nImplementation plan:")
  (princ "\n  1. Read GMTITLE / ~FTAP title-block scale candidates.")
  (princ "\n  2. Compare entity override DIMLFAC values.")
  (princ "\n  3. Compare source dimension-style DIMLFAC values.")
  (princ "\n  4. Report OK, MIXED, MISSING, CONFLICT, or SUSPECT.")
  (princ "\nNo drawing data was changed.")
  (princ)
)

(defun swcad-title-print-candidate (edata attr / tag value)
  (setq tag (swcad-title-dxf-value attr 2))
  (setq value (swcad-title-dxf-value attr 1))
  (swcad-title-princ-line
    (strcat
      "  - handle="
      (swcad-title-string (swcad-title-dxf-value edata 5))
      ", layout="
      (swcad-title-string (swcad-title-dxf-value edata 410))
      ", block="
      (swcad-title-string (swcad-title-dxf-value edata 2))
      ", layer="
      (swcad-title-string (swcad-title-dxf-value edata 8))
      ", tag="
      (swcad-title-string tag)
      ", value="
      (swcad-title-string value)
      ", insert="
      (swcad-title-string (swcad-title-dxf-value edata 10))
    )
  )
)

(defun swcad-title-scan-insert (ename / edata attrs attr block found scale-count)
  (setq edata (entget ename '("*")))
  (setq attrs (swcad-title-insert-attributes ename))
  (setq block (swcad-title-dxf-value edata 2))
  (setq found nil)
  (setq scale-count 0)
  (foreach attr attrs
    (if (swcad-title-scale-tag-p (swcad-title-dxf-value attr 2))
      (progn
        (if (not found)
          (progn
            (setq found T)
            (setq *swcad-title-scan-title-insert-count* (+ *swcad-title-scan-title-insert-count* 1))
          )
        )
        (setq scale-count (+ scale-count 1))
        (setq *swcad-title-scan-scale-count* (+ *swcad-title-scan-scale-count* 1))
        (setq
          *swcad-title-scan-scale-values*
          (swcad-title-list-add-unique
            (swcad-title-string (swcad-title-dxf-value attr 1))
            *swcad-title-scan-scale-values*
          )
        )
        (swcad-title-print-candidate edata attr)
      )
    )
  )
  (if (and (swcad-title-title-block-name-p block) (= scale-count 0))
    (swcad-title-princ-line
      (strcat
        "  - handle="
        (swcad-title-string (swcad-title-dxf-value edata 5))
        ", layout="
        (swcad-title-string (swcad-title-dxf-value edata 410))
        ", block="
        (swcad-title-string block)
        ", scale=<missing>"
      )
    )
  )
  scale-count
)

(defun swcad-title-text-entity-value (data / result pair code value)
  (setq result "")
  (foreach pair data
    (setq code (car pair))
    (setq value (cdr pair))
    (if (and (or (= code 1) (= code 3)) (swcad-title-string-p value))
      (setq result (strcat result value))
    )
  )
  result
)

(defun swcad-title-print-text-candidate (edata scale-value raw-text)
  (swcad-title-princ-line
    (strcat
      "  - handle="
      (swcad-title-string (swcad-title-dxf-value edata 5))
      ", layout="
      (swcad-title-string (swcad-title-dxf-value edata 410))
      ", type="
      (swcad-title-string (swcad-title-dxf-value edata 0))
      ", layer="
      (swcad-title-string (swcad-title-dxf-value edata 8))
      ", value="
      (swcad-title-string scale-value)
      ", insert="
      (swcad-title-string (swcad-title-dxf-value edata 10))
      ", text=\""
      (swcad-title-string raw-text)
      "\""
    )
  )
)

(defun swcad-title-scan-text-entity (ename / edata raw-text scale-value)
  (setq edata (entget ename '("*")))
  (setq raw-text (swcad-title-text-entity-value edata))
  (setq scale-value (swcad-title-scale-text-candidate raw-text))
  (if scale-value
    (progn
      (setq *swcad-title-scan-loose-scale-count* (+ *swcad-title-scan-loose-scale-count* 1))
      (setq
        *swcad-title-scan-scale-values*
        (swcad-title-list-add-unique
          scale-value
          *swcad-title-scan-scale-values*
        )
      )
      (swcad-title-print-text-candidate edata scale-value raw-text)
      1
    )
    0
  )
)

(defun swcad-title-scan-loose-texts (/ ss index total ename)
  (setq ss (ssget "_X" '((0 . "TEXT,MTEXT"))))
  (setq total (if ss (sslength ss) 0))
  (setq *swcad-title-scan-loose-text-count* total)
  (swcad-title-princ-line (strcat "TEXT/MTEXT count: " (itoa total)))
  (swcad-title-princ-line "Loose text scale candidates:")
  (setq index 0)
  (while (< index total)
    (setq ename (ssname ss index))
    (swcad-title-scan-text-entity ename)
    (setq index (+ index 1))
  )
  (if (= *swcad-title-scan-loose-scale-count* 0)
    (swcad-title-princ-line "  <none>")
  )
  *swcad-title-scan-loose-scale-count*
)

(defun swcad-title-command-text-residue-p (raw-text / upper trimmed)
  (setq trimmed (vl-string-trim " \t\r\n" (swcad-title-string raw-text)))
  (setq upper (strcase trimmed))
  (or
    (and
      (vl-string-search "(LOAD" upper)
      (vl-string-search "SWCAD_TITLE_SCALE.LSP" upper)
    )
    (wcmatch upper "SWTITLE*")
    (wcmatch upper "*SWTITLE LOG:*")
    (and
      (vl-string-search "APPLOAD" upper)
      (vl-string-search "SWCAD_TITLE_SCALE.LSP" upper)
    )
  )
)

(defun swcad-title-command-text-residue-records (/ ss index total ename data raw-text records)
  (setq ss (ssget "_X" '((0 . "TEXT,MTEXT"))))
  (setq total (if ss (sslength ss) 0))
  (setq index 0)
  (setq records nil)
  (while (< index total)
    (setq ename (ssname ss index))
    (setq data (entget ename '("*")))
    (setq raw-text (swcad-title-text-entity-value data))
    (if (swcad-title-command-text-residue-p raw-text)
      (setq records (append records (list (list ename data raw-text))))
    )
    (setq index (+ index 1))
  )
  records
)

(defun swcad-title-command-text-residue-count ()
  (length (swcad-title-command-text-residue-records))
)

(defun swcad-title-print-command-text-record (record / data raw-text)
  (setq data (cadr record))
  (setq raw-text (caddr record))
  (swcad-title-princ-line
    (strcat
      "  - handle="
      (swcad-title-string (swcad-title-dxf-value data 5))
      ", type="
      (swcad-title-string (swcad-title-dxf-value data 0))
      ", layer="
      (swcad-title-string (swcad-title-dxf-value data 8))
      ", point="
      (swcad-title-point-string (swcad-title-dxf-value data 10))
      ", text=\""
      (swcad-title-string raw-text)
      "\""
    )
  )
)

(defun swcad-title-command-text-scan (/ ss total records count record)
  (swcad-title-open-command-text-log)
  (swcad-title-princ-line "----- SWTITLECOMMANDTEXTSCAN read-only accidental command text scan -----")
  (swcad-title-print-loaded-version)
  (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (swcad-title-princ-line (strcat "CTAB: " (getvar "CTAB")))
  (setq ss (ssget "_X" '((0 . "TEXT,MTEXT"))))
  (setq total (if ss (sslength ss) 0))
  (setq records (swcad-title-command-text-residue-records))
  (setq count (length records))
  (swcad-title-princ-line (strcat "TEXT/MTEXT count: " (itoa total)))
  (swcad-title-princ-line "Possible accidental command text entities:")
  (foreach record records
    (swcad-title-print-command-text-record record)
  )
  (if (= count 0)
    (swcad-title-princ-line "  <none>")
  )
  (swcad-title-princ-line (strcat "Possible accidental command text count: " (itoa count)))
  (if (> count 0)
    (progn
      (swcad-title-princ-line "Result: WARN_ACCIDENTAL_COMMAND_TEXT_FOUND")
      (swcad-title-princ-line "No drawing data was changed. Remove these only in a work copy after confirming they are not real drawing notes.")
    )
    (swcad-title-princ-line "Result: OK_NO_ACCIDENTAL_COMMAND_TEXT_FOUND")
  )
  (swcad-title-princ-line "No drawing data was changed.")
  (swcad-title-close-log)
  (princ)
)

(defun swcad-title-command-text-clean-safe (/ records count record answer doc deleted)
  (swcad-title-open-command-text-log)
  (swcad-title-princ-line "----- SWTITLECOMMANDTEXTCLEANSAFE guarded accidental command text cleanup -----")
  (swcad-title-print-loaded-version)
  (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (swcad-title-princ-line (strcat "CTAB: " (getvar "CTAB")))
  (swcad-title-print-work-copy-status)
  (setq records (swcad-title-command-text-residue-records))
  (setq count (length records))
  (swcad-title-princ-line "Possible accidental command text entities:")
  (foreach record records
    (swcad-title-print-command-text-record record)
  )
  (swcad-title-princ-line (strcat "Possible accidental command text count: " (itoa count)))
  (cond
    ((= count 0)
      (swcad-title-princ-line "  <none>")
      (swcad-title-apply-result "OK_NO_ACCIDENTAL_COMMAND_TEXT_FOUND")
    )
    ((swcad-title-document-read-only-p)
      (swcad-title-apply-result "ABORT_READ_ONLY_DOCUMENT")
      (swcad-title-princ-line "Open a writable work copy before cleaning command text.")
    )
    ((not (swcad-title-current-dwg-in-work-p))
      (swcad-title-apply-result "ABORT_NOT_WORK_COPY")
      (swcad-title-princ-line "Command text cleanup is limited to Documents/CAD tool/work copies.")
    )
    (T
      (setq answer
        (getstring
          T
          "\nType YES to delete these accidental command TEXT/MTEXT entities in this work copy: "
        )
      )
      (if (/= (strcase answer) "YES")
        (swcad-title-apply-result "ABORT_COMMAND_TEXT_CLEAN_USER")
        (progn
          (setq doc (swcad-title-doc))
          (vl-catch-all-apply 'vla-StartUndoMark (list doc))
          (setq deleted 0)
          (foreach record records
            (if (swcad-title-delete-ename (car record))
              (setq deleted (+ deleted 1))
            )
          )
          (vl-catch-all-apply 'vla-EndUndoMark (list doc))
          (swcad-title-princ-line (strcat "Deleted accidental command text entities: " (itoa deleted)))
          (swcad-title-apply-result "OK_COMMAND_TEXT_CLEANED")
          (swcad-title-princ-line "Next: rerun SWTITLENEXTSTEP.")
        )
      )
    )
  )
  (swcad-title-close-log)
  (princ)
)

(defun swcad-title-text-record-less-p (a b)
  (if (equal (car a) (car b) 1e-8)
    (< (cadr a) (cadr b))
    (> (car a) (car b))
  )
)

(defun swcad-title-text-record (edata raw-text / point scale-value)
  (setq point (swcad-title-dxf-value edata 10))
  (setq scale-value (swcad-title-scale-text-candidate raw-text))
  (list
    (if (and point (cadr point)) (cadr point) 0.0)
    (if (and point (car point)) (car point) 0.0)
    (swcad-title-dxf-value edata 0)
    (swcad-title-dxf-value edata 5)
    (swcad-title-dxf-value edata 8)
    point
    raw-text
    scale-value
  )
)

(defun swcad-title-point-z (point)
  (if (and (listp point) (caddr point))
    (caddr point)
    0.0
  )
)

(defun swcad-title-number-or-default (value default)
  (if (numberp value) value default)
)

(defun swcad-title-transform-block-point (point insert-data block-base / insert-point sx sy rot local-x local-y scaled-x scaled-y cosv sinv)
  (setq insert-point (swcad-title-dxf-value insert-data 10))
  (setq sx (swcad-title-number-or-default (swcad-title-dxf-value insert-data 41) 1.0))
  (setq sy (swcad-title-number-or-default (swcad-title-dxf-value insert-data 42) 1.0))
  (setq rot (swcad-title-number-or-default (swcad-title-dxf-value insert-data 50) 0.0))
  (setq local-x (- (car point) (car block-base)))
  (setq local-y (- (cadr point) (cadr block-base)))
  (setq scaled-x (* local-x sx))
  (setq scaled-y (* local-y sy))
  (setq cosv (cos rot))
  (setq sinv (sin rot))
  (list
    (+ (car insert-point) (- (* scaled-x cosv) (* scaled-y sinv)))
    (+ (cadr insert-point) (+ (* scaled-x sinv) (* scaled-y cosv)))
    (+ (swcad-title-point-z insert-point) (swcad-title-point-z point))
  )
)

(defun swcad-title-block-text-records (insert-ename bbox / insert-data block-name block-data block-base block-obj ename edata etype raw-text local-point world-point expanded-bbox source-handle record records guard)
  (setq records nil)
  (setq insert-data (entget insert-ename '("*")))
  (setq block-name (swcad-title-dxf-value insert-data 2))
  (setq block-data (tblsearch "BLOCK" block-name))
  (setq block-base (if block-data (swcad-title-dxf-value block-data 10) nil))
  (if (not block-base)
    (setq block-base '(0.0 0.0 0.0))
  )
  (setq block-obj (tblobjname "BLOCK" block-name))
  (setq expanded-bbox (swcad-title-expand-bbox bbox 2.0))
  (setq source-handle (swcad-title-string (swcad-title-dxf-value insert-data 5)))
  (if block-obj
    (progn
      (setq ename (entnext block-obj))
      (setq guard 0)
      (while (and ename (< guard 2000))
        (setq edata (entget ename '("*")))
        (setq etype (strcase (swcad-title-string (swcad-title-dxf-value edata 0))))
        (cond
          ((equal etype "ENDBLK")
            (setq ename nil)
          )
          ((member etype '("TEXT" "MTEXT"))
            (setq raw-text (swcad-title-text-entity-value edata))
            (setq local-point (swcad-title-dxf-value edata 10))
            (if (and
                  raw-text
                  (> (strlen raw-text) 0)
                  local-point
                )
              (progn
                (setq world-point
                  (swcad-title-transform-block-point local-point insert-data block-base)
                )
                (if (or (not expanded-bbox) (swcad-title-point-in-bbox-p world-point expanded-bbox))
                  (progn
                    (setq edata (swcad-title-dxf-put edata 10 world-point))
                    (setq edata
                      (swcad-title-dxf-put
                        edata
                        5
                        (strcat
                          "BLOCK:"
                          source-handle
                          ":"
                          (swcad-title-string (swcad-title-dxf-value edata 5))
                        )
                      )
                    )
                    (setq record (swcad-title-text-record edata raw-text))
                    (setq records (append records (list record)))
                  )
                )
              )
            )
          )
        )
        (if ename
          (setq ename (entnext ename))
        )
        (setq guard (+ guard 1))
      )
    )
  )
  records
)

(defun swcad-title-print-text-record (record)
  (swcad-title-princ-line
    (strcat
      "  - handle="
      (swcad-title-string (nth 3 record))
      ", type="
      (swcad-title-string (nth 2 record))
      ", layer="
      (swcad-title-string (nth 4 record))
      ", point="
      (swcad-title-point-string (nth 5 record))
      (if (nth 7 record)
        (strcat ", scale-candidate=" (swcad-title-string (nth 7 record)))
        ""
      )
      ", text=\""
      (swcad-title-string (nth 6 record))
      "\""
    )
  )
)

(defun swcad-title-print-attribute-record (insert-data attr-data / tag value point)
  (setq tag (swcad-title-dxf-value attr-data 2))
  (setq value (swcad-title-dxf-value attr-data 1))
  (setq point (swcad-title-dxf-value attr-data 10))
  (swcad-title-princ-line
    (strcat
      "    - attr-handle="
      (swcad-title-string (swcad-title-dxf-value attr-data 5))
      ", tag="
      (swcad-title-string tag)
      ", value=\""
      (swcad-title-string value)
      "\""
      ", layer="
      (swcad-title-string (swcad-title-dxf-value attr-data 8))
      ", point="
      (swcad-title-point-string point)
    )
  )
)

(defun swcad-title-scan-title-texts (/ insert-ss insert-index insert-total text-ss text-index text-total ename data block attrs attr-data attr-count title-like bbox bboxes title-insert-count attribute-count text-records raw-text point records-in-bounds record)
  (swcad-title-open-text-log)
  (setq title-insert-count 0)
  (setq attribute-count 0)
  (setq bboxes nil)
  (setq text-records nil)
  (swcad-title-princ-line "----- SWTITLETEXTSCAN read-only title text scan -----")
  (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (swcad-title-princ-line (strcat "CTAB: " (getvar "CTAB")))

  (setq insert-ss (ssget "_X" '((0 . "INSERT"))))
  (setq insert-total (if insert-ss (sslength insert-ss) 0))
  (swcad-title-princ-line (strcat "INSERT count: " (itoa insert-total)))
  (swcad-title-princ-line "Title-like inserts and attributes:")
  (setq insert-index 0)
  (while (< insert-index insert-total)
    (setq ename (ssname insert-ss insert-index))
    (setq data (entget ename '("*")))
    (setq block (swcad-title-dxf-value data 2))
    (setq attrs (swcad-title-insert-attributes ename))
    (setq attr-count (length attrs))
    (setq title-like (swcad-title-title-block-name-p block))
    (if (or title-like (> attr-count 0))
      (progn
        (setq title-insert-count (+ title-insert-count 1))
        (setq bbox (swcad-title-safe-bbox ename))
        (if title-like
          (setq bboxes (append bboxes (list (swcad-title-expand-bbox bbox 2.0))))
        )
        (swcad-title-princ-line
          (strcat
            "  - insert-handle="
            (swcad-title-string (swcad-title-dxf-value data 5))
            ", block="
            (swcad-title-string block)
            ", layer="
            (swcad-title-string (swcad-title-dxf-value data 8))
            ", insert="
            (swcad-title-point-string (swcad-title-dxf-value data 10))
            ", bbox="
            (swcad-title-bbox-string bbox)
            ", attributes="
            (itoa attr-count)
          )
        )
        (foreach attr-data attrs
          (setq attribute-count (+ attribute-count 1))
          (swcad-title-print-attribute-record data attr-data)
        )
        (if (= attr-count 0)
          (swcad-title-princ-line "    <no attributes>")
        )
      )
    )
    (setq insert-index (+ insert-index 1))
  )
  (if (= title-insert-count 0)
    (swcad-title-princ-line "  <none>")
  )

  (setq text-ss (ssget "_X" '((0 . "TEXT,MTEXT"))))
  (setq text-total (if text-ss (sslength text-ss) 0))
  (setq text-index 0)
  (while (< text-index text-total)
    (setq ename (ssname text-ss text-index))
    (setq data (entget ename '("*")))
    (setq raw-text (swcad-title-text-entity-value data))
    (setq point (swcad-title-dxf-value data 10))
    (if (and raw-text (> (strlen raw-text) 0))
      (setq text-records
        (append text-records (list (swcad-title-text-record data raw-text)))
      )
    )
    (setq text-index (+ text-index 1))
  )
  (setq text-records (vl-sort text-records 'swcad-title-text-record-less-p))
  (setq records-in-bounds nil)
  (foreach record text-records
    (if (or (not bboxes) (swcad-title-point-in-bboxes-p (nth 5 record) bboxes))
      (setq records-in-bounds (append records-in-bounds (list record)))
    )
  )

  (swcad-title-princ-line (strcat "TEXT/MTEXT count: " (itoa text-total)))
  (if bboxes
    (swcad-title-princ-line "Loose TEXT/MTEXT inside title-block bounds:")
    (swcad-title-princ-line "Loose TEXT/MTEXT records:")
  )
  (if records-in-bounds
    (foreach record records-in-bounds
      (swcad-title-print-text-record record)
    )
    (swcad-title-princ-line "  <none>")
  )

  (swcad-title-princ-line "Summary:")
  (swcad-title-princ-line (strcat "  title-like inserts: " (itoa title-insert-count)))
  (swcad-title-princ-line (strcat "  attributes listed: " (itoa attribute-count)))
  (swcad-title-princ-line (strcat "  loose text records listed: " (itoa (length records-in-bounds))))
  (swcad-title-princ-line "No drawing data was changed.")
  (swcad-title-close-log)
  (princ)
)

(defun swcad-title-source-title-same-row-p (a-bbox b-bbox / tolerance)
  (setq tolerance
    (* 0.10
      (max
        (swcad-title-bbox-height a-bbox)
        (swcad-title-bbox-height b-bbox)
        1.0
      )
    )
  )
  (<= (swcad-title-abs (- (cadddr a-bbox) (cadddr b-bbox))) tolerance)
)

(defun swcad-title-source-title-candidate-less-p (a b / a-bbox b-bbox)
  (setq a-bbox (caddr a))
  (setq b-bbox (caddr b))
  (if (swcad-title-source-title-same-row-p a-bbox b-bbox)
    (< (car a-bbox) (car b-bbox))
    (> (cadddr a-bbox) (cadddr b-bbox))
  )
)

(defun swcad-title-source-frame-candidate-less-p (a b / a-bbox b-bbox)
  (setq a-bbox (caddr a))
  (setq b-bbox (caddr b))
  (if (swcad-title-source-title-same-row-p a-bbox b-bbox)
    (< (car a-bbox) (car b-bbox))
    (> (cadddr a-bbox) (cadddr b-bbox))
  )
)

(defun swcad-title-source-title-candidates (/ insert-ss insert-index insert-total ename data block bbox area result)
  (setq result nil)
  (setq insert-ss (ssget "_X" '((0 . "INSERT"))))
  (setq insert-total (if insert-ss (sslength insert-ss) 0))
  (setq insert-index 0)
  (while (< insert-index insert-total)
    (setq ename (ssname insert-ss insert-index))
    (setq data (entget ename '("*")))
    (setq block (swcad-title-effective-insert-name ename))
    (if
      (and
        (swcad-title-title-block-name-p block)
        (not (swcad-title-native-target-title-name-p block))
      )
      (progn
        (setq bbox (swcad-title-safe-bbox ename))
        (setq area (swcad-title-bbox-area bbox))
        (if (and bbox (> area 10.0))
          (setq result (append result (list (list ename data bbox block area))))
        )
      )
    )
    (setq insert-index (+ insert-index 1))
  )
  (vl-sort result 'swcad-title-source-title-candidate-less-p)
)

(defun swcad-title-source-frame-candidates (/ insert-ss insert-index insert-total ename data block bbox area sheet result)
  (setq result nil)
  (setq insert-ss (ssget "_X" '((0 . "INSERT"))))
  (setq insert-total (if insert-ss (sslength insert-ss) 0))
  (setq insert-index 0)
  (while (< insert-index insert-total)
    (setq ename (ssname insert-ss insert-index))
    (setq data (entget ename '("*")))
    (setq block (swcad-title-effective-insert-name ename))
    (setq sheet (swcad-title-sheet-size-from-block-name block))
    (if
      (and
        sheet
        (not (swcad-title-native-target-frame-name-p block))
        (not (swcad-title-native-target-title-name-p block))
      )
      (progn
        (setq bbox (swcad-title-safe-bbox ename))
        (setq area (swcad-title-bbox-area bbox))
        (if (and bbox (> area 1000.0))
          (setq result (append result (list (list ename data bbox block area sheet))))
        )
      )
    )
    (setq insert-index (+ insert-index 1))
  )
  (vl-sort result 'swcad-title-source-frame-candidate-less-p)
)

(defun swcad-title-frame-has-source-title-p (frame-bbox sources / found source)
  (setq found nil)
  (foreach source sources
    (if
      (and
        (not found)
        frame-bbox
        (swcad-title-bbox-contains-bbox-p frame-bbox (caddr source) 2.0)
      )
      (setq found T)
    )
  )
  found
)

(defun swcad-title-frame-only-source-candidates (/ frames sources result frame)
  (setq frames (swcad-title-source-frame-candidates))
  (setq sources (swcad-title-source-title-candidates))
  (setq result nil)
  (foreach frame frames
    (if (not (swcad-title-frame-has-source-title-p (caddr frame) sources))
      (setq result (append result (list frame)))
    )
  )
  result
)

(defun swcad-title-single-a4-frame-only-risk-message (source-frame frame-block / bbox sheet width height long-edge short-edge)
  (setq sheet (if source-frame (nth 5 source-frame) nil))
  (setq bbox (if source-frame (caddr source-frame) nil))
  (setq width (swcad-title-bbox-width bbox))
  (setq height (swcad-title-bbox-height bbox))
  (setq long-edge (max width height))
  (setq short-edge (min width height))
  (if
    (and
      (equal (strcase (swcad-title-string sheet)) "A4")
      (equal (strcase (swcad-title-string frame-block)) "DR_A4_OUTLINE")
      (swcad-title-near-p long-edge 297.0 2.0)
      (swcad-title-near-p short-edge 210.0 2.0)
    )
    "CAD test warning: this source is a single 210 x 297 A4 frame-only sheet, but DR_A4_Outline did not insert as a matching single A4 GMTITLE frame in this GstarCAD setup."
    nil
  )
)

(defun swcad-title-frame-only-source-for-existing-gmtitle (/ frames frame frame-block found)
  (setq frames (swcad-title-frame-only-source-candidates))
  (setq found nil)
  (foreach frame frames
    (if (not found)
      (progn
        (setq frame-block (swcad-title-target-frame-block-name-for-sheet (nth 5 frame)))
        (if (swcad-title-default-location-gmtitle-frame-for-block frame-block)
          (setq found frame)
        )
      )
    )
  )
  (if found
    found
    (car frames)
  )
)

(defun swcad-title-frame-only-default-values (source-frame / source-block source-sheet target-frame file-base)
  (setq source-block (cadddr source-frame))
  (setq source-sheet (nth 5 source-frame))
  (setq target-frame (swcad-title-target-frame-block-name-for-sheet source-sheet))
  (setq file-base (vl-filename-base (getvar "DWGNAME")))
  (list
    (cons "GEN-TITLE-SIZ{6.7}" (swcad-title-normalized-sheet-size source-sheet))
    (cons "GEN-TITLE-DWG{23}" file-base)
    (cons "GEN-TITLE-NR{23}" "XXX")
    (cons "GEN-TITLE-SCA{6.7}" "1:1")
  )
)

(defun swcad-title-frame-only-title-offset (sheet-size / normalized dims width)
  (setq normalized (swcad-title-normalized-sheet-size sheet-size))
  (setq dims (swcad-title-sheet-dimensions normalized))
  (setq width (if dims (car dims) 210.0))
  (cond
    ((equal normalized "A4") '(20.0 10.0))
    (T (list (max 20.0 (- width 190.0)) 10.0))
  )
)

(defun swcad-title-transfer-source-bbox (/ source)
  (setq source (car (swcad-title-source-title-candidates)))
  (if source
    (list (car source) (cadr source) (caddr source))
    nil
  )
)

(defun swcad-title-source-record-basic (source)
  (if source
    (list (car source) (cadr source) (caddr source))
    nil
  )
)

(defun swcad-title-source-record-frame-block (source / source-ename source-bbox source-block frame frame-bbox frame-block)
  (setq source-ename (car source))
  (setq source-bbox (caddr source))
  (setq source-block (cadddr source))
  (setq frame (if source-bbox (swcad-title-transfer-source-frame source-bbox source-ename) nil))
  (setq frame-bbox (if frame (caddr frame) nil))
  (setq frame-block (if frame (swcad-title-effective-insert-name (car frame)) ""))
  (swcad-title-target-frame-block-name-for-source source-block frame-block nil frame-bbox)
)

(defun swcad-title-transfer-source-for-existing-gmtitle (/ sources source frame-block found)
  (setq sources (swcad-title-source-title-candidates))
  (setq found nil)
  (foreach source sources
    (if (not found)
      (progn
        (setq frame-block (swcad-title-source-record-frame-block source))
        (if (swcad-title-unfinalized-gmtitle-frame-for-block frame-block)
          (setq found source)
        )
      )
    )
  )
  (if found
    (swcad-title-source-record-basic found)
    (swcad-title-transfer-source-bbox)
  )
)

(defun swcad-title-transfer-source-frame (source-bbox source-title-ename / insert-ss insert-index insert-total ename data block bbox area source-area priority best bestarea bestpriority)
  (setq insert-ss (ssget "_X" '((0 . "INSERT"))))
  (setq insert-total (if insert-ss (sslength insert-ss) 0))
  (setq source-area (swcad-title-bbox-area source-bbox))
  (setq best nil)
  (setq bestarea nil)
  (setq bestpriority nil)
  (setq insert-index 0)
  (while (< insert-index insert-total)
    (setq ename (ssname insert-ss insert-index))
    (if (not (eq ename source-title-ename))
      (progn
        (setq data (entget ename '("*")))
        (setq block (swcad-title-effective-insert-name ename))
        (if (not (swcad-title-native-target-frame-name-p block))
          (progn
            (setq bbox (swcad-title-safe-bbox ename))
            (setq area (swcad-title-bbox-area bbox))
            (if (and
                  bbox
                  (> area (* source-area 2.0))
                  (swcad-title-bbox-contains-bbox-p bbox source-bbox 2.0)
                )
              (progn
                (setq priority (swcad-title-frame-block-size-priority block))
                (if
                  (or
                    (not best)
                    (< priority bestpriority)
                    (and
                      (= priority bestpriority)
                      (if (= priority 0)
                        (< area bestarea)
                        (> area bestarea)
                      )
                    )
                  )
                  (progn
                    (setq best (list ename data bbox))
                    (setq bestarea area)
                    (setq bestpriority priority)
                  )
                )
              )
            )
          )
        )
      )
    )
    (setq insert-index (+ insert-index 1))
  )
  best
)

(defun swcad-title-transfer-text-records (bbox source-ename / ss index total ename data raw-text point records record block-records)
  (setq records nil)
  (setq ss (ssget "_X" '((0 . "TEXT,MTEXT"))))
  (setq total (if ss (sslength ss) 0))
  (setq index 0)
  (while (< index total)
    (setq ename (ssname ss index))
    (setq data (entget ename '("*")))
    (setq raw-text (swcad-title-text-entity-value data))
    (setq point (swcad-title-dxf-value data 10))
    (if (and
          raw-text
          (> (strlen raw-text) 0)
          (or (not bbox) (swcad-title-point-in-bbox-p point (swcad-title-expand-bbox bbox 2.0)))
        )
      (progn
        (setq record (swcad-title-text-record data raw-text))
        (setq records (append records (list record)))
      )
    )
    (setq index (+ index 1))
  )
  (if source-ename
    (progn
      (setq block-records (swcad-title-block-text-records source-ename bbox))
      (if block-records
        (setq records (append records block-records))
      )
    )
  )
  (vl-sort records 'swcad-title-text-record-less-p)
)

(defun swcad-title-transfer-preview-record (record bbox / point best slot dist tag label relx rely)
  (setq point (nth 5 record))
  (setq best (swcad-title-transfer-best-slot point bbox))
  (if best
    (progn
      (setq slot (car best))
      (setq dist (cadr best))
      (setq relx (caddr best))
      (setq rely (cadddr best))
      (setq tag (car slot))
      (setq label (cadddr slot))
      (list tag label (nth 6 record) (nth 3 record) point dist relx rely record)
    )
    nil
  )
)

(defun swcad-title-transfer-print-mapping (mapping)
  (swcad-title-princ-line
    (strcat
      "  "
      (car mapping)
      " ["
      (cadr mapping)
      "] <= \""
      (swcad-title-string (caddr mapping))
      "\""
      ", source-handle="
      (swcad-title-string (cadddr mapping))
      ", source-point="
      (swcad-title-point-string (nth 4 mapping))
      ", distance="
      (swcad-title-number-string (nth 5 mapping))
    )
  )
)

(defun swcad-title-transfer-print-unmapped (record bbox / best slot)
  (setq best (swcad-title-transfer-best-slot (nth 5 record) bbox))
  (swcad-title-princ-line
    (strcat
      "  - handle="
      (swcad-title-string (nth 3 record))
      ", point="
      (swcad-title-point-string (nth 5 record))
      ", text=\""
      (swcad-title-string (nth 6 record))
      "\""
      (if best
        (progn
          (setq slot (car best))
          (strcat
            ", nearest="
            (car slot)
            ", distance="
            (swcad-title-number-string (cadr best))
          )
        )
        ""
      )
    )
  )
)

(defun swcad-title-transfer-preview (/ source source-ename source-data source-bbox source-block source-frame source-frame-ename source-frame-data source-frame-bbox source-frame-block records mappings unmapped duplicates record preview tag existing slot maxdist missing-count mapped-count duplicate-count unmapped-count values block-sheet inferred-frame-bbox text-sheet frame-sheet detected-sheet frame-block title-graphic-handles frame-graphic-handles residue-records)
  (swcad-title-open-transfer-log)
  (setq maxdist 7.0)
  (setq source (swcad-title-transfer-source-bbox))
  (setq source-ename (if source (car source) nil))
  (setq source-data (if source (cadr source) nil))
  (setq source-bbox (if source (caddr source) nil))
  (setq source-block (if source-ename (swcad-title-effective-insert-name source-ename) nil))
  (setq source-frame (if source-bbox (swcad-title-transfer-source-frame source-bbox source-ename) nil))
  (setq source-frame-ename (if source-frame (car source-frame) nil))
  (setq source-frame-data (if source-frame (cadr source-frame) nil))
  (setq source-frame-bbox (if source-frame (caddr source-frame) nil))
  (setq source-frame-block (if source-frame-ename (swcad-title-effective-insert-name source-frame-ename) nil))
  (setq mappings nil)
  (setq unmapped nil)
  (setq duplicates nil)
  (setq mapped-count 0)
  (setq duplicate-count 0)
  (setq unmapped-count 0)
  (swcad-title-princ-line "----- SWTITLETRANSFERPREVIEW read-only GM TITLE transfer preview -----")
  (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (swcad-title-princ-line (strcat "CTAB: " (getvar "CTAB")))
  (swcad-title-print-work-copy-status)
  (swcad-title-princ-line
    (strcat
      "Source title insert: "
      (if source-data
        (strcat
          "handle="
          (swcad-title-string (swcad-title-dxf-value source-data 5))
          ", block="
          (swcad-title-string source-block)
          ", bbox="
          (swcad-title-bbox-string source-bbox)
        )
        "<none>"
      )
    )
  )
  (if source-bbox
    (progn
      (setq records (swcad-title-transfer-text-records source-bbox source-ename))
      (foreach record records
        (setq preview (swcad-title-transfer-preview-record record source-bbox))
        (if (and preview (<= (nth 5 preview) maxdist))
          (progn
            (setq tag (car preview))
            (setq existing (assoc tag mappings))
            (if existing
              (progn
                (setq duplicates (append duplicates (list record)))
                (setq duplicate-count (+ duplicate-count 1))
              )
              (progn
                (setq mappings (swcad-title-assoc-put tag preview mappings))
                (setq mapped-count (+ mapped-count 1))
              )
            )
          )
          (progn
            (setq unmapped (append unmapped (list record)))
            (setq unmapped-count (+ unmapped-count 1))
          )
        )
      )

      (swcad-title-princ-line "GM TITLE attribute transfer preview:")
      (setq missing-count 0)
      (foreach slot *swcad-title-transfer-template*
        (setq tag (car slot))
        (setq existing (assoc tag mappings))
        (if existing
          (swcad-title-transfer-print-mapping (cdr existing))
          (progn
            (setq missing-count (+ missing-count 1))
            (swcad-title-princ-line
              (strcat
                "  "
                tag
                " ["
                (cadddr slot)
                "] <= <missing>"
              )
            )
          )
        )
      )

      (swcad-title-princ-line "Unmapped source title texts:")
      (if unmapped
        (foreach record unmapped
          (swcad-title-transfer-print-unmapped record source-bbox)
        )
        (swcad-title-princ-line "  <none>")
      )
      (swcad-title-princ-line "Duplicate source title texts:")
      (if duplicates
        (foreach record duplicates
          (swcad-title-transfer-print-unmapped record source-bbox)
        )
        (swcad-title-princ-line "  <none>")
      )
      (setq values (swcad-title-transfer-values mappings))
      (setq block-sheet (swcad-title-source-block-sheet-size source-block source-frame-block))
      (setq values (swcad-title-values-with-sheet-size-override values block-sheet))
      (setq inferred-frame-bbox (swcad-title-effective-source-frame-bbox source-bbox source-frame-bbox values block-sheet))
      (setq text-sheet (swcad-title-normalized-sheet-size (swcad-title-sheet-size-value values)))
      (setq frame-sheet (swcad-title-sheet-size-from-frame-bbox inferred-frame-bbox))
      (setq detected-sheet (swcad-title-detected-sheet-size-for-source source-block source-frame-block values inferred-frame-bbox))
      (setq frame-block (swcad-title-target-frame-block-name-for-source source-block source-frame-block values inferred-frame-bbox))
      (setq title-graphic-handles (swcad-title-source-title-graphic-handles source-bbox))
      (setq frame-graphic-handles
        (if source-frame-ename
          nil
          (swcad-title-source-frame-graphic-handles inferred-frame-bbox source-bbox)
        )
      )
      (setq residue-records
        (swcad-title-source-sheet-residue-records
          inferred-frame-bbox
          source-ename
          source-frame-ename
        )
      )
      (swcad-title-princ-line
        (strcat
          "Source frame insert: "
          (if source-frame-data
            (strcat
              "handle="
              (swcad-title-string (swcad-title-dxf-value source-frame-data 5))
              ", block="
              (swcad-title-string source-frame-block)
              ", bbox="
              (swcad-title-bbox-string source-frame-bbox)
            )
            "<none>"
          )
        )
      )
      (swcad-title-princ-line
        (strcat
          "Detected sheet size: title-text="
          (if text-sheet text-sheet "<none>")
          ", frame-bbox="
          (if frame-sheet frame-sheet "<none>")
          ", block-name="
          (if block-sheet block-sheet "<none>")
          ", selected="
          (if detected-sheet detected-sheet "<fallback>")
        )
      )
      (swcad-title-princ-line (strcat "Expected native GMTITLE frame block: " frame-block))
      (swcad-title-princ-line (strcat "Expected native GMTITLE title block: " (swcad-title-target-title-block-name)))
      (swcad-title-princ-line (strcat "Old loose title graphics cleanup candidates: " (itoa (length title-graphic-handles))))
      (swcad-title-princ-line
        (strcat
          "Old loose frame graphics cleanup candidates: "
          (itoa (length frame-graphic-handles))
          ", frame cleanup bbox="
          (swcad-title-bbox-string inferred-frame-bbox)
        )
      )
      (swcad-title-print-residue-records "Old SOLIDWORKS sheet residue cleanup candidates:" residue-records)
      (swcad-title-princ-line "Summary:")
      (swcad-title-princ-line (strcat "  source title texts: " (itoa (length records))))
      (swcad-title-princ-line (strcat "  mapped fields: " (itoa mapped-count)))
      (swcad-title-princ-line (strcat "  missing target fields: " (itoa missing-count)))
      (swcad-title-princ-line (strcat "  unmapped source texts: " (itoa unmapped-count)))
      (swcad-title-princ-line (strcat "  duplicate source texts: " (itoa duplicate-count)))
      (swcad-title-princ-line (strcat "  sheet residue cleanup candidates: " (itoa (length residue-records))))
    )
    (progn
      (swcad-title-princ-line "No title-like insert was found. Run SWTITLETEXTSCAN for raw text details.")
      (swcad-title-princ-line "Summary:")
      (swcad-title-princ-line "  mapped fields: 0")
    )
  )
  (swcad-title-princ-line "No drawing data was changed.")
  (swcad-title-close-log)
  (princ)
)

(defun swcad-title-transfer-apply (/ source source-data source-bbox source-ename source-block source-frame source-frame-ename source-frame-data source-frame-block source-frame-bbox frame-block title-block gmtitle-result gmtitle-title-ename gmtitle-frame-ename gmtitle-new-enames title-ref build mappings records unmapped duplicates values block-sheet answer attr-count deleted-text-count skipped-block-text-count old-frame-deleted record doc pair inferred-frame-bbox text-sheet frame-sheet detected-sheet title-graphic-handles frame-graphic-handles residue-records residue-handles deleted-title-graphic-count deleted-frame-graphic-count deleted-residue-count actual-title-name actual-frame-name geometry-warning deleted-new-gmtitle-count align-result align-count align-dx align-dy align-needed marker-role marker-ok)
  (swcad-title-open-apply-log)
  (setq *swcad-title-last-apply-status* nil)
  (setq source (swcad-title-transfer-source-bbox))
  (setq source-ename (if source (car source) nil))
  (setq source-data (if source (cadr source) nil))
  (setq source-bbox (if source (caddr source) nil))
  (setq source-block (if source-ename (swcad-title-effective-insert-name source-ename) nil))
  (setq source-frame (if source-bbox (swcad-title-transfer-source-frame source-bbox source-ename) nil))
  (setq source-frame-ename (if source-frame (car source-frame) nil))
  (setq source-frame-data (if source-frame (cadr source-frame) nil))
  (setq source-frame-bbox (if source-frame (caddr source-frame) nil))
  (setq source-frame-block (if source-frame-ename (swcad-title-effective-insert-name source-frame-ename) nil))
  (setq frame-block (swcad-title-target-frame-block-name-for-source source-block source-frame-block nil source-frame-bbox))
  (setq title-block (swcad-title-target-title-block-name))
  (swcad-title-princ-line "----- SWTITLETRANSFERAPPLY native GMTITLE transfer apply -----")
  (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (swcad-title-princ-line (strcat "CTAB: " (getvar "CTAB")))
  (swcad-title-print-work-copy-status)
  (swcad-title-princ-line (strcat "FILEDIA before: " (swcad-title-string (getvar "FILEDIA")) " (not changed)"))
  (swcad-title-princ-line (strcat "CMDDIA before: " (swcad-title-string (getvar "CMDDIA")) " (not changed)"))
  (swcad-title-princ-line
    (strcat
      "Source title insert: "
      (if source-data
        (strcat
          "handle="
          (swcad-title-string (swcad-title-dxf-value source-data 5))
          ", block="
          (swcad-title-string source-block)
          ", bbox="
          (swcad-title-bbox-string source-bbox)
        )
        "<none>"
      )
    )
  )
  (swcad-title-princ-line
    (strcat
      "Source frame insert: "
      (if source-frame-data
        (strcat
          "handle="
          (swcad-title-string (swcad-title-dxf-value source-frame-data 5))
          ", block="
          (swcad-title-string source-frame-block)
          ", bbox="
          (swcad-title-bbox-string source-frame-bbox)
        )
        "<none>"
      )
    )
  )
  (swcad-title-princ-line
    (strcat
      "Preliminary native GMTITLE frame block: "
      frame-block
    )
  )
  (swcad-title-princ-line
    (strcat
      "Expected native GMTITLE title block: "
      title-block
    )
  )
  (cond
    ((not source-bbox)
      (swcad-title-apply-result "ABORT_NO_SOURCE_TITLE")
    )
    ((swcad-title-document-read-only-p)
      (swcad-title-apply-result "ABORT_READ_ONLY_DOCUMENT")
      (swcad-title-princ-line "Open a writable copy of the DWG before applying.")
    )
    ((not (swcad-title-apply-work-copy-confirmed-p))
      (swcad-title-apply-result "ABORT_NOT_WORK_COPY")
      (swcad-title-princ-line "Open or create a copy under Documents/CAD tool/work before applying.")
    )
    (T
      (setq build (swcad-title-transfer-build-mappings source-bbox source-ename 7.0))
      (setq mappings (car build))
      (setq records (cadr build))
      (setq unmapped (caddr build))
      (setq duplicates (cadddr build))
      (setq values (swcad-title-transfer-values mappings))
      (setq block-sheet (swcad-title-source-block-sheet-size source-block source-frame-block))
      (setq values (swcad-title-values-with-sheet-size-override values block-sheet))
      (setq inferred-frame-bbox (swcad-title-effective-source-frame-bbox source-bbox source-frame-bbox values block-sheet))
      (setq text-sheet (swcad-title-normalized-sheet-size (swcad-title-sheet-size-value values)))
      (setq frame-sheet (swcad-title-sheet-size-from-frame-bbox inferred-frame-bbox))
      (setq detected-sheet (swcad-title-detected-sheet-size-for-source source-block source-frame-block values inferred-frame-bbox))
      (setq frame-block (swcad-title-target-frame-block-name-for-source source-block source-frame-block values inferred-frame-bbox))
      (setq title-graphic-handles (swcad-title-source-title-graphic-handles source-bbox))
      (setq frame-graphic-handles
        (if source-frame-ename
          nil
          (swcad-title-source-frame-graphic-handles inferred-frame-bbox source-bbox)
        )
      )
      (setq residue-records
        (swcad-title-source-sheet-residue-records
          inferred-frame-bbox
          source-ename
          source-frame-ename
        )
      )
      (setq residue-handles (swcad-title-residue-record-handles residue-records))
      (swcad-title-princ-line "Values to apply:")
      (foreach pair values
        (swcad-title-princ-line
          (strcat
            "  "
            (car pair)
            " = \""
            (swcad-title-string (cdr pair))
            "\""
          )
        )
      )
      (swcad-title-princ-line
        (strcat
          "Unmapped source texts to delete with old title text: "
          (itoa (length unmapped))
        )
      )
      (swcad-title-princ-line
        (strcat
          "Duplicate source texts not mapped: "
          (itoa (length duplicates))
        )
      )
      (swcad-title-princ-line (strcat "Old loose title graphics queued for cleanup: " (itoa (length title-graphic-handles))))
      (swcad-title-princ-line
        (strcat
          "Old loose frame graphics queued for cleanup: "
          (itoa (length frame-graphic-handles))
          ", frame cleanup bbox="
          (swcad-title-bbox-string inferred-frame-bbox)
        )
      )
      (swcad-title-princ-line
        (strcat
          "Detected sheet size: title-text="
          (if text-sheet text-sheet "<none>")
          ", frame-bbox="
          (if frame-sheet frame-sheet "<none>")
          ", block-name="
          (if block-sheet block-sheet "<none>")
          ", selected="
          (if detected-sheet detected-sheet "<fallback>")
        )
      )
      (swcad-title-princ-line (strcat "Expected native GMTITLE frame block after detection: " frame-block))
      (swcad-title-print-residue-records "Old SOLIDWORKS sheet residue queued for cleanup:" residue-records)
      (setq answer
        (if *swcad-title-batch-mode*
          "YES"
          (getstring
            T
            "\nType YES to run native GMTITLE, fill the new title attributes, and remove old title content: "
          )
        )
      )
      (if *swcad-title-batch-mode*
        (swcad-title-princ-line "Confirmation: batch mode")
      )
      (if (/= (strcase answer) "YES")
        (swcad-title-apply-result "ABORT_USER_CANCEL")
        (progn
          (setq gmtitle-result
            (swcad-title-run-native-gmtitle-prefer-commandline
              frame-block
              (swcad-title-bbox-lower-left-point inferred-frame-bbox)
            )
          )
          (setq gmtitle-title-ename (car gmtitle-result))
          (setq gmtitle-frame-ename (cadr gmtitle-result))
          (setq gmtitle-new-enames (caddr gmtitle-result))
          (swcad-title-princ-line (strcat "Native GMTITLE new INSERT count: " (itoa (length gmtitle-new-enames))))
          (swcad-title-insert-log-label "Native GMTITLE title insert" gmtitle-title-ename)
          (swcad-title-insert-log-label "Native GMTITLE frame insert" gmtitle-frame-ename)
          (setq actual-title-name (if gmtitle-title-ename (swcad-title-effective-insert-name gmtitle-title-ename) ""))
          (setq actual-frame-name (if gmtitle-frame-ename (swcad-title-effective-insert-name gmtitle-frame-ename) ""))
          (setq geometry-warning
            (if gmtitle-frame-ename
              (swcad-title-frame-bbox-size-warning-for-block
                frame-block
                (swcad-title-frame-reference-effective-bbox gmtitle-frame-ename frame-block)
              )
              nil
            )
          )
          (swcad-title-princ-line (strcat "Native GMTITLE selected title block: " (if (> (strlen actual-title-name) 0) actual-title-name "<missing>")))
          (swcad-title-princ-line (strcat "Native GMTITLE selected frame block: " (if (> (strlen actual-frame-name) 0) actual-frame-name "<missing>")))
          (if gmtitle-title-ename
            (if
              (and
                (swcad-title-native-target-title-name-p actual-title-name)
                gmtitle-frame-ename
                (swcad-title-frame-name-matches-p actual-frame-name frame-block)
                (not geometry-warning)
              )
              (progn
                (setq title-ref (swcad-title-safe-vla-object gmtitle-title-ename))
                (setq doc (swcad-title-doc))
                (vl-catch-all-apply 'vla-StartUndoMark (list doc))
                (setq align-result (swcad-title-align-gmtitle-to-frame-bbox gmtitle-title-ename gmtitle-frame-ename inferred-frame-bbox))
                (setq align-count (car align-result))
                (setq align-dx (cadr align-result))
                (setq align-dy (caddr align-result))
                (setq align-needed (or (> (swcad-title-abs align-dx) 0.0001) (> (swcad-title-abs align-dy) 0.0001)))
                (if (and align-needed (< align-count 2))
                  (progn
                    (vl-catch-all-apply 'vla-EndUndoMark (list doc))
                    (setq deleted-new-gmtitle-count (swcad-title-delete-ename-list gmtitle-new-enames))
                    (swcad-title-apply-result "ABORT_GMTITLE_ALIGN_FAILED")
                    (swcad-title-princ-line
                      (strcat
                        "Native GMTITLE alignment failed: moved="
                        (itoa align-count)
                        ", dx="
                        (swcad-title-number-string align-dx)
                        ", dy="
                        (swcad-title-number-string align-dy)
                      )
                    )
                    (swcad-title-princ-line (strcat "Removed partial/new GMTITLE inserts: " (itoa deleted-new-gmtitle-count)))
                    (swcad-title-princ-line "No old SOLIDWORKS title/frame content was removed.")
                  )
                  (if (and align-needed (not *swcad-title-last-native-gmtitle-placement-used*))
                    (progn
                      (vl-catch-all-apply 'vla-EndUndoMark (list doc))
                      (setq deleted-new-gmtitle-count (swcad-title-delete-ename-list gmtitle-new-enames))
                      (swcad-title-apply-result "ABORT_GMTITLE_NATIVE_PLACEMENT_REQUIRED")
                      (swcad-title-princ-line "Native GMTITLE was created away from the source frame and would need LISP MOVE alignment.")
                      (swcad-title-princ-line "That pattern is not trusted because GMPOWEREDIT/double-click behavior can fail after visual alignment.")
                      (swcad-title-princ-line (strcat "Removed untrusted new GMTITLE inserts: " (itoa deleted-new-gmtitle-count)))
                      (swcad-title-princ-line "No old SOLIDWORKS title/frame content was removed.")
                      (swcad-title-princ-line "Next: rerun with Frame positioning ON and Object move OFF, then let GMTITLE accept the lower-left placement point.")
                    )
                    (progn
                    (setq attr-count (swcad-title-set-insert-attributes title-ref values))
                    (swcad-title-delete-ename source-ename)
                    (setq deleted-text-count 0)
                    (setq skipped-block-text-count 0)
                    (foreach record records
                      (if (swcad-title-delete-text-record record)
                        (setq deleted-text-count (+ deleted-text-count 1))
                        (setq skipped-block-text-count (+ skipped-block-text-count 1))
                      )
                    )
                    (setq old-frame-deleted "no")
                    (if source-frame-ename
                      (progn
                        (swcad-title-delete-ename source-frame-ename)
                        (setq old-frame-deleted "yes")
                      )
                    )
                    (setq deleted-title-graphic-count (swcad-title-delete-handle-list title-graphic-handles))
                    (setq deleted-frame-graphic-count
                      (if source-frame-ename
                        0
                        (swcad-title-delete-handle-list frame-graphic-handles)
                      )
                    )
                    (setq deleted-residue-count (swcad-title-delete-handle-list residue-handles))
                    (setq marker-role
                      (if (and align-needed (not *swcad-title-last-native-gmtitle-placement-used*))
                        "native-moved-unverified"
                        "native-apply"
                      )
                    )
                    (setq marker-ok
                      (swcad-title-mark-native-exemplar-pair
                        gmtitle-title-ename
                        gmtitle-frame-ename
                        frame-block
                        marker-role
                      )
                    )
                    (vl-catch-all-apply 'vla-EndUndoMark (list doc))
                    (swcad-title-princ-line "Native GMTITLE was used directly.")
                    (swcad-title-princ-line
                      (strcat "Native exemplar marker set: " (if marker-ok "yes" "no") ", role=" marker-role)
                    )
                    (if (equal (strcase marker-role) "NATIVE-MOVED-UNVERIFIED")
                      (progn
                        (swcad-title-princ-line "WARNING: GMTITLE was moved by LISP after creation because native placement was not captured.")
                        (swcad-title-princ-line "This pair is not trusted for GMPOWEREDIT/double-click behavior until recreated with native placement.")
                      )
                    )
                    (swcad-title-princ-line
                      (strcat
                        "Native GMTITLE aligned to source frame: moved="
                        (itoa align-count)
                        ", dx="
                        (swcad-title-number-string align-dx)
                        ", dy="
                        (swcad-title-number-string align-dy)
                      )
                    )
                    (swcad-title-princ-line (strcat "Attributes set: " (itoa attr-count)))
                    (swcad-title-princ-line (strcat "Old loose title texts deleted: " (itoa deleted-text-count)))
                    (swcad-title-princ-line (strcat "Old block-internal title texts handled by deleting source insert: " (itoa skipped-block-text-count)))
                    (swcad-title-princ-line (strcat "Old loose title graphics deleted: " (itoa deleted-title-graphic-count)))
                    (swcad-title-princ-line "Old title insert deleted: yes")
                    (swcad-title-princ-line (strcat "Old frame insert deleted: " old-frame-deleted))
                    (swcad-title-princ-line (strcat "Old loose frame graphics deleted: " (itoa deleted-frame-graphic-count)))
                    (swcad-title-princ-line (strcat "Old SOLIDWORKS sheet residue deleted: " (itoa deleted-residue-count)))
                    (swcad-title-apply-result "APPLIED_TITLE_TRANSFER")
                    (swcad-title-princ-line "Manual final check: double-click the new GMTITLE title block and confirm the GMTITLE table editor opens.")
                    )
                  )
                )
              )
              (progn
                (setq deleted-new-gmtitle-count (swcad-title-delete-ename-list gmtitle-new-enames))
                (if geometry-warning
                  (swcad-title-apply-result "ABORT_NATIVE_GMTITLE_INVALID_FRAME_GEOMETRY")
                  (swcad-title-apply-result "ABORT_WRONG_NATIVE_GMTITLE_SELECTION")
                )
                (swcad-title-princ-line (strcat "Expected frame block: " frame-block))
                (swcad-title-princ-line (strcat "Expected title block: " title-block))
                (swcad-title-princ-line (strcat "Selected frame block: " (if (> (strlen actual-frame-name) 0) actual-frame-name "<missing>")))
                (if geometry-warning
                  (swcad-title-princ-line (strcat "Frame geometry warning: " geometry-warning))
                )
                (if (and (swcad-title-frame-name-matches-p actual-frame-name "DR_A4_Outline") (not (swcad-title-frame-name-matches-p frame-block "DR_A4_Outline")))
                  (swcad-title-princ-line "A4 sheets in this drawing are frame-only; use SWTITLEFRAMEONLYAPPLY for the first A4, not SWTITLETRANSFERAPPLY.")
                )
                (swcad-title-princ-line (strcat "Removed wrong/new GMTITLE inserts: " (itoa deleted-new-gmtitle-count)))
                (swcad-title-princ-line "No old SOLIDWORKS title/frame content was removed.")
              )
            )
            (progn
              (setq deleted-new-gmtitle-count (swcad-title-delete-ename-list gmtitle-new-enames))
              (swcad-title-apply-result "ABORT_NO_NATIVE_GMTITLE_TITLE")
              (swcad-title-princ-line (strcat "Removed partial/new GMTITLE inserts: " (itoa deleted-new-gmtitle-count)))
              (swcad-title-princ-line "No old SOLIDWORKS title/frame content was removed.")
            )
          )
        )
      )
    )
  )
  (swcad-title-princ-line "Note: loose frame cleanup is conservative; it deletes only pre-existing title-area graphics and inferred frame-edge graphics.")
  (swcad-title-princ-line "Note: sheet residue cleanup is limited to the old lower-left logo, upper sheet-format residue, and upper-right residual block regions.")
  (swcad-title-close-log)
  (princ)
)

(defun swcad-title-transfer-finalize (/ *error* source source-data source-bbox source-ename source-block source-frame source-frame-ename source-frame-data source-frame-block source-frame-bbox frame-block title-block gmtitle-title-ename gmtitle-frame-ename title-ref build mappings records unmapped duplicates values block-sheet attr-count deleted-text-count skipped-block-text-count old-frame-deleted record doc pair inferred-frame-bbox text-sheet frame-sheet detected-sheet title-graphic-handles frame-graphic-handles residue-records residue-handles deleted-title-graphic-count deleted-frame-graphic-count deleted-residue-count actual-title-name actual-frame-name geometry-warning align-result align-count align-dx align-dy align-needed marker-ok pending-pair pending-role marker-role deleted-new-count)
  (swcad-title-open-apply-log)
  (defun *error* (msg)
    (if msg
      (swcad-title-princ-line (strcat "Error: " (swcad-title-string msg)))
    )
    (swcad-title-clear-pending-native-gmtitle-pair)
    (swcad-title-apply-result "ERROR_TRANSFER_FINALIZE")
    (swcad-title-close-log)
    (princ)
  )
  (setq *swcad-title-last-apply-status* nil)
  (setq source (swcad-title-transfer-source-for-existing-gmtitle))
  (setq source-ename (if source (car source) nil))
  (setq source-data (if source (cadr source) nil))
  (setq source-bbox (if source (caddr source) nil))
  (setq source-block (if source-ename (swcad-title-effective-insert-name source-ename) nil))
  (setq source-frame (if source-bbox (swcad-title-transfer-source-frame source-bbox source-ename) nil))
  (setq source-frame-ename (if source-frame (car source-frame) nil))
  (setq source-frame-data (if source-frame (cadr source-frame) nil))
  (setq source-frame-bbox (if source-frame (caddr source-frame) nil))
  (setq source-frame-block (if source-frame-ename (swcad-title-effective-insert-name source-frame-ename) nil))
  (setq frame-block (swcad-title-target-frame-block-name-for-source source-block source-frame-block nil source-frame-bbox))
  (setq title-block (swcad-title-target-title-block-name))
  (swcad-title-princ-line "----- SWTITLETRANSFERFINALIZE existing GMTITLE transfer finalize -----")
  (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (swcad-title-princ-line (strcat "CTAB: " (getvar "CTAB")))
  (swcad-title-print-work-copy-status)
  (swcad-title-princ-line
    (strcat
      "Source title insert: "
      (if source-data
        (strcat
          "handle="
          (swcad-title-string (swcad-title-dxf-value source-data 5))
          ", block="
          (swcad-title-string source-block)
          ", bbox="
          (swcad-title-bbox-string source-bbox)
        )
        "<none>"
      )
    )
  )
  (swcad-title-princ-line
    (strcat
      "Source frame insert: "
      (if source-frame-data
        (strcat
          "handle="
          (swcad-title-string (swcad-title-dxf-value source-frame-data 5))
          ", block="
          (swcad-title-string source-frame-block)
          ", bbox="
          (swcad-title-bbox-string source-frame-bbox)
        )
        "<none>"
      )
    )
  )
  (cond
    ((not source-bbox)
      (swcad-title-apply-result "ABORT_NO_SOURCE_TITLE")
    )
    ((swcad-title-document-read-only-p)
      (swcad-title-apply-result "ABORT_READ_ONLY_DOCUMENT")
      (swcad-title-princ-line "Open a writable copy of the DWG before finalizing.")
    )
    ((not (swcad-title-apply-work-copy-confirmed-p))
      (swcad-title-apply-result "ABORT_NOT_WORK_COPY")
      (swcad-title-princ-line "Open or create a copy under Documents/CAD tool/work before finalizing.")
    )
    (T
      (setq build (swcad-title-transfer-build-mappings source-bbox source-ename 7.0))
      (setq mappings (car build))
      (setq records (cadr build))
      (setq unmapped (caddr build))
      (setq duplicates (cadddr build))
      (setq values (swcad-title-transfer-values mappings))
      (swcad-title-princ-line "Finalize step: mappings built.")
      (setq block-sheet (swcad-title-source-block-sheet-size source-block source-frame-block))
      (setq values (swcad-title-values-with-sheet-size-override values block-sheet))
      (setq inferred-frame-bbox (swcad-title-effective-source-frame-bbox source-bbox source-frame-bbox values block-sheet))
      (swcad-title-princ-line "Finalize step: inferred frame bbox ready.")
      (setq text-sheet (swcad-title-normalized-sheet-size (swcad-title-sheet-size-value values)))
      (setq frame-sheet (swcad-title-sheet-size-from-frame-bbox inferred-frame-bbox))
      (setq detected-sheet (swcad-title-detected-sheet-size-for-source source-block source-frame-block values inferred-frame-bbox))
      (setq frame-block (swcad-title-target-frame-block-name-for-source source-block source-frame-block values inferred-frame-bbox))
      (swcad-title-princ-line (strcat "Finalize step: target frame block " frame-block))
      (setq pending-pair (swcad-title-pending-native-gmtitle-pair-for-block frame-block))
      (if pending-pair
        (progn
          (setq gmtitle-title-ename (car pending-pair))
          (setq gmtitle-frame-ename (cadr pending-pair))
          (setq pending-role (nth 2 pending-pair))
          (swcad-title-princ-line "Finalize step: using pending GMTITLE pair from the previous create/clone step.")
        )
        (progn
          (setq pending-role "native")
          (setq gmtitle-frame-ename (swcad-title-unfinalized-gmtitle-frame-for-block frame-block))
          (setq gmtitle-title-ename nil)
          (if gmtitle-frame-ename
            (progn
              (setq gmtitle-title-ename (swcad-title-title-for-native-frame gmtitle-frame-ename frame-block))
              (if (not gmtitle-title-ename)
                (setq gmtitle-title-ename (swcad-title-default-location-title-for-frame gmtitle-frame-ename frame-block))
              )
            )
          )
        )
      )
      (swcad-title-insert-log-label "Finalize step: candidate GMTITLE frame" gmtitle-frame-ename)
      (swcad-title-insert-log-label "Finalize step: candidate GMTITLE title" gmtitle-title-ename)
      (setq actual-title-name (if gmtitle-title-ename (swcad-title-effective-insert-name gmtitle-title-ename) ""))
      (setq actual-frame-name (if gmtitle-frame-ename (swcad-title-effective-insert-name gmtitle-frame-ename) ""))
      (setq geometry-warning
        (if gmtitle-frame-ename
          (swcad-title-frame-bbox-size-warning-for-block
            frame-block
            (swcad-title-frame-reference-effective-bbox gmtitle-frame-ename frame-block)
          )
          nil
        )
      )
      (setq title-graphic-handles (swcad-title-source-title-graphic-handles source-bbox))
      (swcad-title-princ-line "Finalize step: title graphics scanned.")
      (setq frame-graphic-handles
        (if source-frame-ename
          nil
          (swcad-title-source-frame-graphic-handles inferred-frame-bbox source-bbox)
        )
      )
      (swcad-title-princ-line "Finalize step: frame graphics scanned.")
      (setq residue-records
        (swcad-title-source-sheet-residue-records
          inferred-frame-bbox
          source-ename
          source-frame-ename
        )
      )
      (swcad-title-princ-line "Finalize step: residue records scanned.")
      (setq residue-handles (swcad-title-residue-record-handles residue-records))
      (swcad-title-princ-line
        (strcat
          "Detected sheet size: title-text="
          (if text-sheet text-sheet "<none>")
          ", frame-bbox="
          (if frame-sheet frame-sheet "<none>")
          ", block-name="
          (if block-sheet block-sheet "<none>")
          ", selected="
          (if detected-sheet detected-sheet "<fallback>")
        )
      )
      (swcad-title-princ-line (strcat "Expected existing GMTITLE frame block: " frame-block))
      (swcad-title-princ-line (strcat "Expected existing GMTITLE title block: " title-block))
      (swcad-title-insert-log-label "Existing GMTITLE title insert" gmtitle-title-ename)
      (swcad-title-insert-log-label "Existing GMTITLE frame insert" gmtitle-frame-ename)
      (swcad-title-princ-line "Values to apply:")
      (foreach pair values
        (swcad-title-princ-line
          (strcat
            "  "
            (car pair)
            " = \""
            (swcad-title-string (cdr pair))
            "\""
          )
        )
      )
      (swcad-title-princ-line
        (strcat
          "Unmapped source texts to delete with old title text: "
          (itoa (length unmapped))
        )
      )
      (swcad-title-princ-line
        (strcat
          "Duplicate source texts not mapped: "
          (itoa (length duplicates))
        )
      )
      (swcad-title-princ-line (strcat "Old loose title graphics queued for cleanup: " (itoa (length title-graphic-handles))))
      (swcad-title-princ-line
        (strcat
          "Old loose frame graphics queued for cleanup: "
          (itoa (length frame-graphic-handles))
          ", frame cleanup bbox="
          (swcad-title-bbox-string inferred-frame-bbox)
        )
      )
      (swcad-title-print-residue-records "Old SOLIDWORKS sheet residue queued for cleanup:" residue-records)
      (if
        (and
          (swcad-title-native-target-title-name-p actual-title-name)
          gmtitle-frame-ename
          (swcad-title-frame-name-matches-p actual-frame-name frame-block)
          (not geometry-warning)
        )
        (progn
          (setq title-ref (swcad-title-safe-vla-object gmtitle-title-ename))
          (setq doc (swcad-title-doc))
          (vl-catch-all-apply 'vla-StartUndoMark (list doc))
          (setq align-result (swcad-title-align-gmtitle-to-frame-bbox gmtitle-title-ename gmtitle-frame-ename inferred-frame-bbox))
          (setq align-count (car align-result))
          (setq align-dx (cadr align-result))
          (setq align-dy (caddr align-result))
          (setq align-needed (or (> (swcad-title-abs align-dx) 0.0001) (> (swcad-title-abs align-dy) 0.0001)))
          (if (and align-needed (< align-count 2))
            (progn
              (vl-catch-all-apply 'vla-EndUndoMark (list doc))
              (swcad-title-apply-result "ABORT_GMTITLE_ALIGN_FAILED")
              (swcad-title-princ-line
                (strcat
                  "Native GMTITLE alignment failed: moved="
                  (itoa align-count)
                  ", dx="
                  (swcad-title-number-string align-dx)
                  ", dy="
                  (swcad-title-number-string align-dy)
                )
              )
              (swcad-title-princ-line "No old SOLIDWORKS title/frame content was removed.")
            )
            (if
              (and
                align-needed
                (not *swcad-title-last-native-gmtitle-placement-used*)
                (not (equal (strcase (swcad-title-string pending-role)) "CLONE"))
              )
              (progn
                (vl-catch-all-apply 'vla-EndUndoMark (list doc))
                (if pending-pair
                  (progn
                    (setq deleted-new-count (swcad-title-delete-ename-list (list gmtitle-title-ename gmtitle-frame-ename)))
                    (swcad-title-princ-line (strcat "Removed untrusted pending GMTITLE inserts: " (itoa deleted-new-count)))
                  )
                )
                (swcad-title-apply-result "ABORT_GMTITLE_NATIVE_PLACEMENT_REQUIRED")
                (swcad-title-princ-line "Native GMTITLE was created away from the source frame and would need LISP MOVE alignment.")
                (swcad-title-princ-line "That pattern is not trusted because GMPOWEREDIT/double-click behavior can fail after visual alignment.")
                (swcad-title-princ-line "No old SOLIDWORKS title/frame content was removed.")
                (swcad-title-princ-line "Next: rerun with Frame positioning ON and Object move OFF, then let GMTITLE accept the lower-left placement point.")
              )
              (progn
              (setq attr-count (swcad-title-set-insert-attributes title-ref values))
              (swcad-title-delete-ename source-ename)
              (setq deleted-text-count 0)
              (setq skipped-block-text-count 0)
              (foreach record records
                (if (swcad-title-delete-text-record record)
                  (setq deleted-text-count (+ deleted-text-count 1))
                  (setq skipped-block-text-count (+ skipped-block-text-count 1))
                )
              )
              (setq old-frame-deleted "no")
              (if source-frame-ename
                (progn
                  (swcad-title-delete-ename source-frame-ename)
                  (setq old-frame-deleted "yes")
                )
              )
              (setq deleted-title-graphic-count (swcad-title-delete-handle-list title-graphic-handles))
              (setq deleted-frame-graphic-count
                (if source-frame-ename
                  0
                  (swcad-title-delete-handle-list frame-graphic-handles)
                )
              )
              (setq deleted-residue-count (swcad-title-delete-handle-list residue-handles))
              (setq marker-role
                (cond
                  ((equal (strcase (swcad-title-string pending-role)) "CLONE") "clone")
                  ((and align-needed (not *swcad-title-last-native-gmtitle-placement-used*)) "native-moved-unverified")
                  (pending-pair "native-finalize")
                  (T "native-finalize-manual")
                )
              )
              (setq marker-ok
                (swcad-title-mark-native-exemplar-pair
                  gmtitle-title-ename
                  gmtitle-frame-ename
                  frame-block
                  marker-role
                )
              )
              (vl-catch-all-apply 'vla-EndUndoMark (list doc))
              (if (equal (strcase marker-role) "CLONE")
                (swcad-title-princ-line "Cloned GMTITLE was finalized; native upgrade is still required for double-click behavior.")
                (swcad-title-princ-line "Existing native GMTITLE was used.")
              )
              (if (equal (strcase marker-role) "NATIVE-MOVED-UNVERIFIED")
                (progn
                  (swcad-title-princ-line "WARNING: GMTITLE was moved by LISP after creation because native placement was not captured.")
                  (swcad-title-princ-line "This pair is not trusted for GMPOWEREDIT/double-click behavior until recreated with native placement.")
                )
              )
              (swcad-title-princ-line
                (strcat "GMTITLE marker set: " (if marker-ok "yes" "no") ", role=" marker-role)
              )
              (swcad-title-princ-line
                (strcat
                  "Native GMTITLE aligned to source frame: moved="
                  (itoa align-count)
                  ", dx="
                  (swcad-title-number-string align-dx)
                  ", dy="
                  (swcad-title-number-string align-dy)
                )
              )
              (swcad-title-princ-line (strcat "Attributes set: " (itoa attr-count)))
              (swcad-title-princ-line (strcat "Old loose title texts deleted: " (itoa deleted-text-count)))
              (swcad-title-princ-line (strcat "Old block-internal title texts handled by deleting source insert: " (itoa skipped-block-text-count)))
              (swcad-title-princ-line (strcat "Old loose title graphics deleted: " (itoa deleted-title-graphic-count)))
              (swcad-title-princ-line "Old title insert deleted: yes")
              (swcad-title-princ-line (strcat "Old frame insert deleted: " old-frame-deleted))
              (swcad-title-princ-line (strcat "Old loose frame graphics deleted: " (itoa deleted-frame-graphic-count)))
              (swcad-title-princ-line (strcat "Old SOLIDWORKS sheet residue deleted: " (itoa deleted-residue-count)))
              (if (equal (strcase marker-role) "CLONE")
                (progn
                  (swcad-title-apply-result "FINALIZED_CLONED_GMTITLE_TRANSFER")
                  (swcad-title-princ-line "Next: run SWTITLEUPGRADENATIVEA3A4BATCH before final double-click checks.")
                )
                (progn
                  (swcad-title-apply-result "FINALIZED_EXISTING_GMTITLE_TRANSFER")
                  (swcad-title-princ-line "Manual final check: double-click the GMTITLE title block and confirm the table editor opens.")
                )
              )
              )
            )
          )
        )
        (progn
          (if geometry-warning
            (swcad-title-apply-result "ABORT_EXISTING_GMTITLE_INVALID_FRAME_GEOMETRY")
            (swcad-title-apply-result "ABORT_EXISTING_GMTITLE_NOT_FOUND")
          )
          (swcad-title-princ-line (strcat "Expected frame block: " frame-block))
          (swcad-title-princ-line (strcat "Expected title block: " title-block))
          (swcad-title-princ-line (strcat "Actual title block: " (if (> (strlen actual-title-name) 0) actual-title-name "<missing>")))
          (swcad-title-princ-line (strcat "Actual frame block: " (if (> (strlen actual-frame-name) 0) actual-frame-name "<missing>")))
          (if geometry-warning
            (swcad-title-princ-line (strcat "Frame geometry warning: " geometry-warning))
          )
          (if pending-pair
            (progn
              (setq deleted-new-count (swcad-title-delete-ename-list (list gmtitle-title-ename gmtitle-frame-ename)))
              (swcad-title-princ-line (strcat "Removed pending invalid GMTITLE inserts: " (itoa deleted-new-count)))
            )
          )
          (swcad-title-princ-line "No old SOLIDWORKS title/frame content was removed.")
        )
      )
    )
  )
  (swcad-title-clear-pending-native-gmtitle-pair)
  (swcad-title-princ-line "Note: create native GMTITLE with Frame positioning ON, Object move OFF, and the detected DR sheet before running finalize.")
  (swcad-title-princ-line "Note: if native placement is not captured and the pair must be moved from a default location, this command will not treat it as final GMTITLE recognition.")
  (swcad-title-princ-line "Note: sheet residue cleanup is limited to the old lower-left logo, upper sheet-format residue, and upper-right residual block regions.")
  (swcad-title-close-log)
  (princ)
)

(defun swcad-title-transfer-frame-only-finalize (/ *error* source-frame source-frame-ename source-frame-data source-frame-bbox source-frame-block source-sheet frame-block title-block gmtitle-title-ename gmtitle-frame-ename title-ref values attr-count doc align-result align-count align-dx align-dy align-needed residue-records residue-handles deleted-residue-count actual-title-name actual-frame-name geometry-warning marker-ok pending-pair pending-role marker-role deleted-new-count)
  (swcad-title-open-apply-log)
  (defun *error* (msg)
    (if msg
      (swcad-title-princ-line (strcat "Error: " (swcad-title-string msg)))
    )
    (swcad-title-clear-pending-native-gmtitle-pair)
    (swcad-title-apply-result "ERROR_FRAME_ONLY_FINALIZE")
    (swcad-title-close-log)
    (princ)
  )
  (setq *swcad-title-last-apply-status* nil)
  (setq source-frame (swcad-title-frame-only-source-for-existing-gmtitle))
  (setq source-frame-ename (if source-frame (car source-frame) nil))
  (setq source-frame-data (if source-frame (cadr source-frame) nil))
  (setq source-frame-bbox (if source-frame (caddr source-frame) nil))
  (setq source-frame-block (if source-frame (cadddr source-frame) nil))
  (setq source-sheet (if source-frame (nth 5 source-frame) nil))
  (setq frame-block (swcad-title-target-frame-block-name-for-sheet source-sheet))
  (setq title-block (swcad-title-target-title-block-name))
  (swcad-title-princ-line "----- SWTITLEFRAMEONLYFINALIZE existing/native frame-only transfer -----")
  (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (swcad-title-princ-line (strcat "CTAB: " (getvar "CTAB")))
  (swcad-title-print-work-copy-status)
  (swcad-title-princ-line
    (strcat
      "Source frame-only insert: "
      (if source-frame-data
        (strcat
          "handle="
          (swcad-title-string (swcad-title-dxf-value source-frame-data 5))
          ", block="
          (swcad-title-string source-frame-block)
          ", sheet="
          (swcad-title-string source-sheet)
          ", bbox="
          (swcad-title-bbox-string source-frame-bbox)
        )
        "<none>"
      )
    )
  )
  (cond
    ((not source-frame-bbox)
      (swcad-title-apply-result "ABORT_NO_FRAME_ONLY_SOURCE")
    )
    ((swcad-title-document-read-only-p)
      (swcad-title-apply-result "ABORT_READ_ONLY_DOCUMENT")
      (swcad-title-princ-line "Open a writable copy of the DWG before finalizing.")
    )
    ((not (swcad-title-apply-work-copy-confirmed-p))
      (swcad-title-apply-result "ABORT_NOT_WORK_COPY")
      (swcad-title-princ-line "Open or create a copy under Documents/CAD tool/work before finalizing.")
    )
    (T
      (setq pending-pair (swcad-title-pending-native-gmtitle-pair-for-block frame-block))
      (if pending-pair
        (progn
          (setq gmtitle-title-ename (car pending-pair))
          (setq gmtitle-frame-ename (cadr pending-pair))
          (setq pending-role (nth 2 pending-pair))
          (swcad-title-princ-line "Frame-only finalize: using pending GMTITLE pair from the previous create/clone step.")
        )
        (progn
          (setq pending-role "native")
          (setq gmtitle-frame-ename (swcad-title-default-location-gmtitle-frame-for-block frame-block))
          (if gmtitle-frame-ename
            (progn
              (setq gmtitle-title-ename (swcad-title-title-for-native-frame gmtitle-frame-ename frame-block))
              (if (not gmtitle-title-ename)
                (setq gmtitle-title-ename (swcad-title-default-location-title-for-frame gmtitle-frame-ename frame-block))
              )
            )
          )
        )
      )
      (setq actual-title-name (if gmtitle-title-ename (swcad-title-effective-insert-name gmtitle-title-ename) ""))
      (setq actual-frame-name (if gmtitle-frame-ename (swcad-title-effective-insert-name gmtitle-frame-ename) ""))
      (setq geometry-warning
        (if gmtitle-frame-ename
          (swcad-title-frame-bbox-size-warning-for-block
            frame-block
            (swcad-title-frame-reference-effective-bbox gmtitle-frame-ename frame-block)
          )
          nil
        )
      )
      (setq values (swcad-title-frame-only-default-values source-frame))
      (setq residue-records (swcad-title-source-sheet-residue-records source-frame-bbox nil source-frame-ename))
      (setq residue-handles (swcad-title-residue-record-handles residue-records))
      (swcad-title-princ-line (strcat "Expected existing GMTITLE frame block: " frame-block))
      (swcad-title-princ-line (strcat "Expected existing GMTITLE title block: " title-block))
      (swcad-title-insert-log-label "Existing/default GMTITLE title insert" gmtitle-title-ename)
      (swcad-title-insert-log-label "Existing/default GMTITLE frame insert" gmtitle-frame-ename)
      (swcad-title-princ-line "Frame-only values to apply:")
      (foreach pair values
        (swcad-title-princ-line
          (strcat
            "  "
            (car pair)
            " = \""
            (swcad-title-string (cdr pair))
            "\""
          )
        )
      )
      (swcad-title-print-residue-records "Old SOLIDWORKS sheet residue queued for cleanup:" residue-records)
      (if
        (and
          (swcad-title-native-target-title-name-p actual-title-name)
          gmtitle-frame-ename
          (swcad-title-frame-name-matches-p actual-frame-name frame-block)
          (not geometry-warning)
        )
        (progn
          (setq title-ref (swcad-title-safe-vla-object gmtitle-title-ename))
          (setq doc (swcad-title-doc))
          (vl-catch-all-apply 'vla-StartUndoMark (list doc))
          (setq align-result (swcad-title-align-gmtitle-to-frame-bbox gmtitle-title-ename gmtitle-frame-ename source-frame-bbox))
          (setq align-count (car align-result))
          (setq align-dx (cadr align-result))
          (setq align-dy (caddr align-result))
          (setq align-needed (or (> (swcad-title-abs align-dx) 0.0001) (> (swcad-title-abs align-dy) 0.0001)))
          (if (and align-needed (< align-count 2))
            (progn
              (vl-catch-all-apply 'vla-EndUndoMark (list doc))
              (swcad-title-apply-result "ABORT_FRAME_ONLY_ALIGN_FAILED")
              (swcad-title-princ-line
                (strcat
                  "Frame-only GMTITLE alignment failed: moved="
                  (itoa align-count)
                  ", dx="
                  (swcad-title-number-string align-dx)
                  ", dy="
                  (swcad-title-number-string align-dy)
                )
              )
              (swcad-title-princ-line "No old frame-only sheet content was removed.")
            )
            (if
              (and
                align-needed
                (not *swcad-title-last-native-gmtitle-placement-used*)
                (not (equal (strcase (swcad-title-string pending-role)) "CLONE"))
              )
              (progn
                (vl-catch-all-apply 'vla-EndUndoMark (list doc))
                (if pending-pair
                  (progn
                    (setq deleted-new-count (swcad-title-delete-ename-list (list gmtitle-title-ename gmtitle-frame-ename)))
                    (swcad-title-princ-line (strcat "Removed untrusted pending GMTITLE inserts: " (itoa deleted-new-count)))
                  )
                )
                (swcad-title-apply-result "ABORT_FRAME_ONLY_NATIVE_PLACEMENT_REQUIRED")
                (swcad-title-princ-line "Frame-only native GMTITLE was created away from the source frame and would need LISP MOVE alignment.")
                (swcad-title-princ-line "That pattern is not trusted because GMPOWEREDIT/double-click behavior can fail after visual alignment.")
                (swcad-title-princ-line "No old frame-only sheet content was removed.")
                (swcad-title-princ-line "Next: rerun with Frame positioning ON and Object move OFF, then let GMTITLE accept the lower-left placement point.")
              )
              (progn
              (setq attr-count (swcad-title-set-insert-attributes title-ref values))
              (swcad-title-delete-ename source-frame-ename)
              (setq deleted-residue-count (swcad-title-delete-handle-list residue-handles))
              (setq marker-role
                (cond
                  ((equal (strcase (swcad-title-string pending-role)) "CLONE") "clone")
                  ((and align-needed (not *swcad-title-last-native-gmtitle-placement-used*)) "native-frame-only-moved-unverified")
                  (pending-pair "native-frame-only-apply")
                  (T "native-frame-only-finalize")
                )
              )
              (setq marker-ok
                (swcad-title-mark-native-exemplar-pair
                  gmtitle-title-ename
                  gmtitle-frame-ename
                  frame-block
                  marker-role
                )
              )
              (vl-catch-all-apply 'vla-EndUndoMark (list doc))
              (if (equal (strcase marker-role) "CLONE")
                (swcad-title-princ-line "Cloned GMTITLE was finalized for frame-only source; native upgrade is still required for double-click behavior.")
                (swcad-title-princ-line "Existing/default native GMTITLE was used for frame-only source.")
              )
              (if (equal (strcase marker-role) "NATIVE-FRAME-ONLY-MOVED-UNVERIFIED")
                (progn
                  (swcad-title-princ-line "WARNING: frame-only GMTITLE was moved by LISP after creation because native placement was not captured.")
                  (swcad-title-princ-line "This pair is not trusted for GMPOWEREDIT/double-click behavior until recreated with native placement.")
                )
              )
              (swcad-title-princ-line
                (strcat "GMTITLE marker set: " (if marker-ok "yes" "no") ", role=" marker-role)
              )
              (swcad-title-princ-line
                (strcat
                  "Native GMTITLE aligned to source frame: moved="
                  (itoa align-count)
                  ", dx="
                  (swcad-title-number-string align-dx)
                  ", dy="
                  (swcad-title-number-string align-dy)
                )
              )
              (swcad-title-princ-line (strcat "Attributes set: " (itoa attr-count)))
              (swcad-title-princ-line "Old frame-only insert deleted: yes")
              (swcad-title-princ-line (strcat "Old SOLIDWORKS sheet residue deleted: " (itoa deleted-residue-count)))
              (if (equal (strcase marker-role) "CLONE")
                (progn
                  (swcad-title-apply-result "FINALIZED_CLONED_FRAME_ONLY_GMTITLE_TRANSFER")
                  (swcad-title-princ-line "Next: run SWTITLEUPGRADENATIVEA3A4BATCH before final double-click checks.")
                )
                (progn
                  (swcad-title-apply-result "FINALIZED_FRAME_ONLY_GMTITLE_TRANSFER")
                  (swcad-title-princ-line "Manual final check: double-click the GMTITLE title block and confirm the table editor opens.")
                )
              )
              )
            )
          )
        )
        (progn
          (if geometry-warning
            (swcad-title-apply-result "ABORT_EXISTING_FRAME_ONLY_GMTITLE_INVALID_FRAME_GEOMETRY")
            (swcad-title-apply-result "ABORT_EXISTING_FRAME_ONLY_GMTITLE_NOT_FOUND")
          )
          (swcad-title-princ-line (strcat "Expected frame block: " frame-block))
          (swcad-title-princ-line (strcat "Expected title block: " title-block))
          (swcad-title-princ-line (strcat "Actual title block: " (if (> (strlen actual-title-name) 0) actual-title-name "<missing>")))
          (swcad-title-princ-line (strcat "Actual frame block: " (if (> (strlen actual-frame-name) 0) actual-frame-name "<missing>")))
          (if geometry-warning
            (swcad-title-princ-line (strcat "Frame geometry warning: " geometry-warning))
          )
          (if pending-pair
            (progn
              (setq deleted-new-count (swcad-title-delete-ename-list (list gmtitle-title-ename gmtitle-frame-ename)))
              (swcad-title-princ-line (strcat "Removed pending invalid GMTITLE inserts: " (itoa deleted-new-count)))
            )
          )
          (swcad-title-princ-line "Do not run SWTITLEFRAMEONLYCLONEBATCH or SWTITLETRANSFERFASTBATCH for this sheet size until one same-size native GMTITLE passes this geometry check.")
          (swcad-title-princ-line "Create one native GMTITLE with the detected DR sheet and verify its bbox first; if A4 keeps failing, inspect the GMTITLE A4 selection/format definition.")
          (swcad-title-princ-line "No old frame-only sheet content was removed.")
        )
      )
    )
  )
  (swcad-title-clear-pending-native-gmtitle-pair)
  (swcad-title-princ-line "Note: frame-only finalize is for sheets with an old frame but no old source title block.")
  (swcad-title-princ-line "Note: for native-safe use, create GMTITLE with Frame positioning ON and let it accept the sheet lower-left placement point.")
  (swcad-title-close-log)
  (princ)
)

(defun swcad-title-transfer-frame-only-apply (/ *error* source-frame source-frame-bbox source-sheet frame-block risk-message answer placement-point gmtitle-result gmtitle-title-ename gmtitle-frame-ename finalize-result)
  (defun *error* (msg)
    (swcad-title-open-apply-log)
    (if msg
      (swcad-title-princ-line (strcat "Error: " (swcad-title-string msg)))
    )
    (swcad-title-apply-result "ERROR_FRAME_ONLY_NATIVE_APPLY")
    (swcad-title-close-log)
    (princ)
  )
  (setq *swcad-title-last-apply-status* nil)
  (setq source-frame (car (swcad-title-frame-only-source-candidates)))
  (setq source-frame-bbox (if source-frame (caddr source-frame) nil))
  (setq source-sheet (if source-frame (nth 5 source-frame) nil))
  (setq frame-block (swcad-title-target-frame-block-name-for-sheet source-sheet))
  (setq placement-point (swcad-title-bbox-lower-left-point source-frame-bbox))
  (swcad-title-open-apply-log)
  (swcad-title-princ-line "----- SWTITLEFRAMEONLYAPPLY first native frame-only transfer -----")
  (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (swcad-title-princ-line (strcat "CTAB: " (getvar "CTAB")))
  (swcad-title-print-work-copy-status)
  (swcad-title-princ-line
    (strcat
      "Next frame-only sheet: "
      (if source-frame
        (strcat
          "sheet="
          (swcad-title-string source-sheet)
          ", target="
          (swcad-title-string frame-block)
          ", bbox="
          (swcad-title-bbox-string source-frame-bbox)
        )
        "<none>"
      )
    )
  )
  (cond
    ((not source-frame)
      (swcad-title-apply-result "STOP_NO_MORE_FRAME_ONLY_SOURCE")
      (swcad-title-close-log)
    )
    ((swcad-title-document-read-only-p)
      (swcad-title-apply-result "ABORT_READ_ONLY_DOCUMENT")
      (swcad-title-princ-line "Open a writable work copy before applying.")
      (swcad-title-close-log)
    )
    ((not (swcad-title-apply-work-copy-confirmed-p))
      (swcad-title-apply-result "ABORT_NOT_WORK_COPY")
      (swcad-title-princ-line "Open or create a copy under Documents/CAD tool/work before applying.")
      (swcad-title-close-log)
    )
    ((not frame-block)
      (swcad-title-apply-result "ABORT_FRAME_ONLY_TARGET_UNKNOWN")
      (swcad-title-princ-line "Could not infer the target DR_A*_Outline frame block.")
      (swcad-title-close-log)
    )
    (T
      (if (setq risk-message (swcad-title-single-a4-frame-only-risk-message source-frame frame-block))
        (progn
          (swcad-title-princ-line (strcat "A4 native template caution: " risk-message))
          (swcad-title-princ-line "The created GMTITLE frame bbox will be checked before any old A4 frame-only content is removed.")
        )
      )
      (setq answer
        (getstring
          T
          "\nType YES to create one native GMTITLE for the next frame-only sheet, then remove the old frame: "
        )
      )
      (if (/= (strcase answer) "YES")
        (progn
          (swcad-title-apply-result "ABORT_USER_CANCEL")
          (swcad-title-close-log)
        )
        (progn
          (swcad-title-princ-line "Native GMTITLE will open once for this frame-only sheet.")
          (swcad-title-princ-line (strcat "  Paper/format: " frame-block))
          (swcad-title-princ-line (strcat "  Title block: " (swcad-title-target-title-block-name)))
          (swcad-title-princ-line "  Keep ON: Frame positioning.")
          (swcad-title-princ-line "  Turn OFF: Object move.")
          (if placement-point
            (swcad-title-princ-line (strcat "  Use lower-left placement point if prompted: " (swcad-title-point-string placement-point)))
          )
          (swcad-title-princ-line "  Finalize will align the GMTITLE frame lower-left to the old frame lower-left.")
          (swcad-title-close-log)
          (setq gmtitle-result (swcad-title-run-native-gmtitle-prefer-commandline frame-block placement-point))
          (setq gmtitle-title-ename (car gmtitle-result))
          (setq gmtitle-frame-ename (cadr gmtitle-result))
          (if (and gmtitle-title-ename gmtitle-frame-ename)
            (progn
              (swcad-title-set-pending-native-gmtitle-pair
                gmtitle-title-ename
                gmtitle-frame-ename
                frame-block
              )
              (setq finalize-result (vl-catch-all-apply 'swcad-title-transfer-frame-only-finalize nil))
              (if (vl-catch-all-error-p finalize-result)
                (progn
                  (swcad-title-open-apply-log)
                  (swcad-title-princ-line "----- SWTITLEFRAMEONLYAPPLY finalize error -----")
                  (swcad-title-princ-line (vl-catch-all-error-message finalize-result))
                  (swcad-title-apply-result "ERROR_FRAME_ONLY_NATIVE_FINALIZE")
                  (swcad-title-close-log)
                )
              )
            )
            (progn
              (swcad-title-open-apply-log)
              (swcad-title-princ-line "----- SWTITLEFRAMEONLYAPPLY native GMTITLE failed -----")
              (swcad-title-princ-line (strcat "Expected frame block: " frame-block))
              (swcad-title-princ-line (strcat "Expected title block: " (swcad-title-target-title-block-name)))
              (swcad-title-apply-result "ABORT_FRAME_ONLY_NATIVE_GMTITLE_NOT_CREATED")
              (swcad-title-princ-line "No old frame-only sheet content was removed.")
              (swcad-title-close-log)
            )
          )
        )
      )
    )
  )
  (princ)
)

(defun swcad-title-transfer-batch-run (count / index source apply-result)
  (setq index 1)
  (while (<= index count)
    (setq source (swcad-title-transfer-source-bbox))
    (if source
      (progn
        (princ
          (strcat
            "\n--- SWTITLETRANSFERBATCH sheet "
            (itoa index)
            " / "
            (itoa count)
            " ---"
          )
        )
        (setq apply-result (vl-catch-all-apply 'swcad-title-transfer-apply nil))
        (if (vl-catch-all-error-p apply-result)
          (progn
            (setq *swcad-title-last-apply-status* "ERROR_BATCH_APPLY")
            (princ
              (strcat
                "\nBatch apply error: "
                (vl-catch-all-error-message apply-result)
              )
            )
            (swcad-title-close-log)
          )
        )
        (if (/= *swcad-title-last-apply-status* "APPLIED_TITLE_TRANSFER")
          (progn
            (princ
              (strcat
                "\nBatch stopped after status: "
                (swcad-title-string *swcad-title-last-apply-status*)
              )
            )
            (setq index count)
          )
        )
      )
      (progn
        (setq *swcad-title-last-apply-status* "STOP_NO_MORE_SOLIDWORKS_TITLE_SOURCE")
        (princ "\nResult: STOP_NO_MORE_SOLIDWORKS_TITLE_SOURCE")
        (setq index count)
      )
    )
    (setq index (+ index 1))
  )
)

(defun swcad-title-transfer-batch (/ count answer old-batch-mode batch-result)
  (setq count (getint "\nNumber of SOLIDWORKS title blocks/sheets to process with native GMTITLE <1>: "))
  (if (not count)
    (setq count 1)
  )
  (if (< count 1)
    (setq count 1)
  )
  (setq answer
    (getstring
      T
      (strcat
        "\nType YES to process "
        (itoa count)
        " sheet(s). Native GMTITLE will open once per sheet: "
      )
    )
  )
  (if (/= (strcase answer) "YES")
    (progn
      (princ "\nResult: ABORT_USER_CANCEL")
      (princ)
    )
    (progn
      (setq old-batch-mode *swcad-title-batch-mode*)
      (setq *swcad-title-batch-mode* T)
      (setq batch-result (vl-catch-all-apply 'swcad-title-transfer-batch-run (list count)))
      (setq *swcad-title-batch-mode* old-batch-mode)
      (if (vl-catch-all-error-p batch-result)
        (progn
          (setq *swcad-title-last-apply-status* "ERROR_BATCH_FATAL")
          (princ
            (strcat
              "\nBatch fatal error: "
              (vl-catch-all-error-message batch-result)
            )
          )
        )
      )
      (princ "\nSWTITLETRANSFERBATCH finished. Run SWTITLEGMTITLEVERIFY, then double-click a new title block for the final table-editor check.")
      (princ)
    )
  )
)

(defun swcad-title-transfer-clone-apply (/ answer clone-result finalize-result)
  (setq answer
    (if *swcad-title-batch-mode*
      "YES"
      (getstring
        T
        "\nType YES to clone a verified native GMTITLE pair, fill it, and remove the next old title content: "
      )
    )
  )
  (if (/= (strcase answer) "YES")
    (progn
      (setq *swcad-title-last-apply-status* "ABORT_USER_CANCEL")
      (princ "\nResult: ABORT_USER_CANCEL")
    )
    (progn
      (setq clone-result (vl-catch-all-apply 'swcad-title-create-cloned-gmtitle-for-next-source nil))
      (if (or (vl-catch-all-error-p clone-result) (not clone-result))
        (progn
          (setq *swcad-title-last-apply-status* "ABORT_CLONE_GMTITLE_PAIR_FAILED")
          (swcad-title-open-apply-log)
          (swcad-title-princ-line "----- SWTITLETRANSFERCLONEAPPLY native GMTITLE clone apply -----")
          (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
          (swcad-title-print-work-copy-status)
          (if (vl-catch-all-error-p clone-result)
            (swcad-title-princ-line
              (strcat "Clone error: " (vl-catch-all-error-message clone-result))
            )
            (swcad-title-princ-line "Clone error: verified native GMTITLE exemplar or target frame could not be created.")
          )
          (if *swcad-title-last-clone-failure*
            (swcad-title-princ-line
              (strcat "Clone failure detail: " *swcad-title-last-clone-failure*)
            )
          )
          (swcad-title-princ-line "Exact-size native clone requires one real GMTITLE exemplar for the same DR_A*_Outline sheet size.")
          (swcad-title-princ-line "If this is the first A3/A4 sheet, create it once with native GMTITLE first, then rerun the fast clone batch.")
          (swcad-title-princ-line "Target frame block definition check:")
          (swcad-title-print-frame-def-check-lines)
          (swcad-title-apply-result "ABORT_CLONE_GMTITLE_PAIR_FAILED")
          (swcad-title-princ-line "No old SOLIDWORKS title/frame content was removed.")
          (swcad-title-close-log)
        )
        (progn
          (swcad-title-set-pending-gmtitle-pair
            (car clone-result)
            (cadr clone-result)
            (caddr clone-result)
            "clone"
          )
          (setq finalize-result (vl-catch-all-apply 'swcad-title-transfer-finalize nil))
          (if (vl-catch-all-error-p finalize-result)
            (progn
              (setq *swcad-title-last-apply-status* "ERROR_CLONE_FINALIZE")
              (swcad-title-open-apply-log)
              (swcad-title-princ-line "----- SWTITLETRANSFERCLONEAPPLY finalize error -----")
              (swcad-title-princ-line (vl-catch-all-error-message finalize-result))
              (swcad-title-apply-result "ERROR_CLONE_FINALIZE")
              (swcad-title-close-log)
            )
          )
        )
      )
    )
  )
  (princ)
)

(defun swcad-title-transfer-clone-batch-run (count / index source apply-result target-frame-block)
  (setq index 1)
  (while (<= index count)
    (setq source (swcad-title-transfer-source-bbox))
    (if source
      (progn
        (setq target-frame-block (swcad-title-next-fast-target-frame-block))
        (princ
          (strcat
            "\n--- SWTITLETRANSFERCLONEBATCH sheet "
            (itoa index)
            " / "
            (itoa count)
            " ---"
          )
        )
        (if
          (and
            target-frame-block
            (not (swcad-title-native-example-pair-for-frame-block target-frame-block))
          )
          (progn
            (setq *swcad-title-last-apply-status* "WAITING_FOR_EXACT_SIZE_NATIVE_GMTITLE_EXEMPLARS")
            (princ
              (strcat
                "\nClone batch paused: "
                target-frame-block
                " needs one real native GMTITLE exemplar first."
              )
            )
            (princ "\nRun SWTITLETRANSFERAPPLY for the first sheet of this size, then rerun SWTITLETRANSFERFASTBATCH.")
            (setq index count)
          )
          (progn
            (setq apply-result (vl-catch-all-apply 'swcad-title-transfer-clone-apply nil))
            (if (vl-catch-all-error-p apply-result)
              (progn
                (setq *swcad-title-last-apply-status* "ERROR_CLONE_BATCH_APPLY")
                (princ
                  (strcat
                    "\nClone batch apply error: "
                    (vl-catch-all-error-message apply-result)
                  )
                )
                (swcad-title-close-log)
              )
            )
            (if
              (not
                (member
                  *swcad-title-last-apply-status*
                  '("FINALIZED_EXISTING_GMTITLE_TRANSFER" "FINALIZED_CLONED_GMTITLE_TRANSFER")
                )
              )
              (progn
                (princ
                  (strcat
                    "\nClone batch stopped after status: "
                    (swcad-title-string *swcad-title-last-apply-status*)
                  )
                )
                (setq index count)
              )
            )
          )
        )
      )
      (progn
        (setq *swcad-title-last-apply-status* "STOP_NO_MORE_SOLIDWORKS_TITLE_SOURCE")
        (princ "\nResult: STOP_NO_MORE_SOLIDWORKS_TITLE_SOURCE")
        (setq index count)
      )
    )
    (setq index (+ index 1))
  )
)

(defun swcad-title-transfer-clone-batch (/ count answer old-batch-mode batch-result)
  (setq count (getint "\nNumber of remaining SOLIDWORKS title blocks/sheets to process by native clone <1>: "))
  (if (not count)
    (setq count 1)
  )
  (if (< count 1)
    (setq count 1)
  )
  (setq answer
    (getstring
      T
      (strcat
        "\nType YES to process "
        (itoa count)
        " sheet(s) by cloning the verified native GMTITLE pair: "
      )
    )
  )
  (if (/= (strcase answer) "YES")
    (progn
      (princ "\nResult: ABORT_USER_CANCEL")
      (princ)
    )
    (progn
      (setq old-batch-mode *swcad-title-batch-mode*)
      (setq *swcad-title-batch-mode* T)
      (setq batch-result (vl-catch-all-apply 'swcad-title-transfer-clone-batch-run (list count)))
      (setq *swcad-title-batch-mode* old-batch-mode)
      (if (vl-catch-all-error-p batch-result)
        (progn
          (setq *swcad-title-last-apply-status* "ERROR_CLONE_BATCH_FATAL")
          (princ
            (strcat
              "\nClone batch fatal error: "
              (vl-catch-all-error-message batch-result)
            )
          )
        )
      )
      (princ "\nSWTITLETRANSFERCLONEBATCH finished. Run SWTITLEGMTITLEVERIFYALL for the full check.")
      (princ)
    )
  )
)

(defun swcad-title-transfer-frame-only-clone-apply (/ answer source-frame target-frame-block risk-message clone-result finalize-result)
  (setq answer
    (if *swcad-title-batch-mode*
      "YES"
      (getstring
        T
        "\nType YES to clone a verified GMTITLE pair, place it on the next frame-only sheet, and remove the old frame: "
      )
    )
  )
  (if (/= (strcase answer) "YES")
    (progn
      (setq *swcad-title-last-apply-status* "ABORT_USER_CANCEL")
      (princ "\nResult: ABORT_USER_CANCEL")
    )
    (progn
      (setq source-frame (car (swcad-title-frame-only-source-candidates)))
      (if (not source-frame)
        (progn
          (setq *swcad-title-last-apply-status* "STOP_NO_MORE_FRAME_ONLY_SOURCE")
          (princ "\nResult: STOP_NO_MORE_FRAME_ONLY_SOURCE")
        )
        (progn
          (setq target-frame-block (swcad-title-target-frame-block-name-for-sheet (nth 5 source-frame)))
          (setq clone-result
            (vl-catch-all-apply
              'swcad-title-create-cloned-gmtitle-for-frame-only-source
              (list source-frame)
            )
          )
          (if (or (vl-catch-all-error-p clone-result) (not clone-result))
            (progn
              (setq *swcad-title-last-apply-status* "ABORT_FRAME_ONLY_CLONE_FAILED")
              (swcad-title-open-apply-log)
              (swcad-title-princ-line "----- SWTITLEFRAMEONLYCLONEAPPLY frame-only clone apply -----")
              (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
              (swcad-title-print-work-copy-status)
              (if (vl-catch-all-error-p clone-result)
                (swcad-title-princ-line
                  (strcat "Frame-only clone error: " (vl-catch-all-error-message clone-result))
                )
                (swcad-title-princ-line "Frame-only clone error: verified GMTITLE exemplar or target frame could not be created.")
              )
              (if *swcad-title-last-clone-failure*
                (swcad-title-princ-line
                  (strcat "Frame-only clone failure detail: " *swcad-title-last-clone-failure*)
                )
              )
              (if (setq risk-message (swcad-title-single-a4-frame-only-risk-message source-frame target-frame-block))
                (progn
                  (swcad-title-princ-line (strcat "A4 native template caution: " risk-message))
                  (swcad-title-princ-line "Do not force a clone for this A4 size until a real DR_A4_Outline exemplar passes the bbox check.")
                )
              )
              (swcad-title-princ-line "Exact-size native clone requires one real GMTITLE exemplar for the same DR_A*_Outline sheet size.")
              (swcad-title-princ-line "For the first A4 frame-only sheet, run SWTITLEFRAMEONLYAPPLY once, then rerun SWTITLEFRAMEONLYCLONEBATCH.")
              (swcad-title-princ-line "Target frame block definition check:")
              (swcad-title-print-frame-def-check-lines)
              (swcad-title-apply-result "ABORT_FRAME_ONLY_CLONE_FAILED")
              (swcad-title-princ-line "No old frame-only sheet content was removed.")
              (swcad-title-close-log)
            )
            (progn
              (swcad-title-set-pending-gmtitle-pair
                (car clone-result)
                (cadr clone-result)
                (caddr clone-result)
                "clone"
              )
              (setq finalize-result (vl-catch-all-apply 'swcad-title-transfer-frame-only-finalize nil))
              (if (vl-catch-all-error-p finalize-result)
                (progn
                  (setq *swcad-title-last-apply-status* "ERROR_FRAME_ONLY_CLONE_FINALIZE")
                  (swcad-title-open-apply-log)
                  (swcad-title-princ-line "----- SWTITLEFRAMEONLYCLONEAPPLY finalize error -----")
                  (swcad-title-princ-line (vl-catch-all-error-message finalize-result))
                  (swcad-title-apply-result "ERROR_FRAME_ONLY_CLONE_FINALIZE")
                  (swcad-title-close-log)
                )
              )
            )
          )
        )
      )
    )
  )
  (princ)
)

(defun swcad-title-transfer-frame-only-clone-batch-run (count / index source-frame apply-result target-frame-block risk-message)
  (setq index 1)
  (while (<= index count)
    (setq source-frame (car (swcad-title-frame-only-source-candidates)))
    (if source-frame
      (progn
        (setq target-frame-block (swcad-title-next-frame-only-target-frame-block))
        (princ
          (strcat
            "\n--- SWTITLEFRAMEONLYCLONEBATCH sheet "
            (itoa index)
            " / "
            (itoa count)
            " ---"
          )
        )
        (if
          (and
            target-frame-block
            (not (swcad-title-native-example-pair-for-frame-block target-frame-block))
          )
          (progn
            (setq *swcad-title-last-apply-status* "WAITING_FOR_EXACT_SIZE_NATIVE_GMTITLE_EXEMPLARS")
            (princ
              (strcat
                "\nFrame-only clone batch paused: "
                target-frame-block
                " needs one real native GMTITLE exemplar first."
              )
            )
            (if (setq risk-message (swcad-title-single-a4-frame-only-risk-message source-frame target-frame-block))
              (progn
                (princ (strcat "\nA4 native template caution: " risk-message))
                (princ "\nIf SWTITLEFRAMEONLYAPPLY aborts with invalid geometry, do not continue with clone/fast batch for A4.")
              )
            )
            (princ "\nRun SWTITLEFRAMEONLYAPPLY for the first frame-only sheet of this size, then rerun SWTITLEFRAMEONLYCLONEBATCH or SWTITLETRANSFERFASTBATCH.")
            (setq index count)
          )
          (progn
            (setq apply-result (vl-catch-all-apply 'swcad-title-transfer-frame-only-clone-apply nil))
            (if (vl-catch-all-error-p apply-result)
              (progn
                (setq *swcad-title-last-apply-status* "ERROR_FRAME_ONLY_CLONE_BATCH_APPLY")
                (princ
                  (strcat
                    "\nFrame-only clone batch apply error: "
                    (vl-catch-all-error-message apply-result)
                  )
                )
                (swcad-title-close-log)
              )
            )
            (if
              (not
                (member
                  *swcad-title-last-apply-status*
                  '("FINALIZED_FRAME_ONLY_GMTITLE_TRANSFER" "FINALIZED_CLONED_FRAME_ONLY_GMTITLE_TRANSFER")
                )
              )
              (progn
                (princ
                  (strcat
                    "\nFrame-only clone batch stopped after status: "
                    (swcad-title-string *swcad-title-last-apply-status*)
                  )
                )
                (setq index count)
              )
            )
          )
        )
      )
      (progn
        (setq *swcad-title-last-apply-status* "STOP_NO_MORE_FRAME_ONLY_SOURCE")
        (princ "\nResult: STOP_NO_MORE_FRAME_ONLY_SOURCE")
        (setq index count)
      )
    )
    (setq index (+ index 1))
  )
)

(defun swcad-title-transfer-frame-only-clone-batch (/ remaining count answer old-batch-mode batch-result)
  (setq remaining (length (swcad-title-frame-only-source-candidates)))
  (if (< remaining 1)
    (progn
      (princ "\nResult: STOP_NO_MORE_FRAME_ONLY_SOURCE")
      (princ)
    )
    (progn
      (setq count
        (getint
          (strcat
            "\nNumber of frame-only sheet(s) to process by GMTITLE clone <"
            (itoa remaining)
            ">: "
          )
        )
      )
      (if (not count)
        (setq count remaining)
      )
      (if (< count 1)
        (setq count 1)
      )
      (if (> count remaining)
        (setq count remaining)
      )
      (setq answer
        (getstring
          T
          (strcat
            "\nType YES to process "
            (itoa count)
            " frame-only sheet(s) by cloning the verified GMTITLE pair: "
          )
        )
      )
      (if (/= (strcase answer) "YES")
        (progn
          (princ "\nResult: ABORT_USER_CANCEL")
          (princ)
        )
        (progn
          (setq old-batch-mode *swcad-title-batch-mode*)
          (setq *swcad-title-batch-mode* T)
          (setq batch-result
            (vl-catch-all-apply
              'swcad-title-transfer-frame-only-clone-batch-run
              (list count)
            )
          )
          (setq *swcad-title-batch-mode* old-batch-mode)
          (if (vl-catch-all-error-p batch-result)
            (progn
              (setq *swcad-title-last-apply-status* "ERROR_FRAME_ONLY_CLONE_BATCH_FATAL")
              (princ
                (strcat
                  "\nFrame-only clone batch fatal error: "
                  (vl-catch-all-error-message batch-result)
                )
              )
            )
          )
          (princ "\nSWTITLEFRAMEONLYCLONEBATCH finished. Run SWTITLEGMTITLEVERIFYALL and SWTITLEMULTIPREVIEW for the full check.")
          (princ)
        )
      )
    )
  )
)

(defun swcad-title-run-fast-batch-phases (/ source-count frame-only-count final-source-count final-frame-only-count contaminated old-batch-mode source-result frame-result)
  (setq source-count (swcad-title-source-title-count))
  (setq old-batch-mode *swcad-title-batch-mode*)
  (setq *swcad-title-batch-mode* T)
  (if (> source-count 0)
    (progn
      (princ (strcat "\nFast batch: processing title sheets, count=" (itoa source-count)))
      (setq source-result
        (vl-catch-all-apply
          'swcad-title-transfer-clone-batch-run
          (list source-count)
        )
      )
      (if (vl-catch-all-error-p source-result)
        (progn
          (setq *swcad-title-last-apply-status* "ERROR_FAST_BATCH_TITLE_FATAL")
          (princ
            (strcat
              "\nFast batch title error: "
              (vl-catch-all-error-message source-result)
            )
          )
        )
      )
    )
  )
  (setq final-source-count (swcad-title-source-title-count))
  (if (and
        (= final-source-count 0)
        (or
          (= source-count 0)
          (equal *swcad-title-last-apply-status* "FINALIZED_EXISTING_GMTITLE_TRANSFER")
          (equal *swcad-title-last-apply-status* "FINALIZED_CLONED_GMTITLE_TRANSFER")
          (equal *swcad-title-last-apply-status* "STOP_NO_MORE_SOLIDWORKS_TITLE_SOURCE")
        )
      )
    (progn
      (setq frame-only-count (swcad-title-frame-only-source-count))
      (if (> frame-only-count 0)
        (progn
          (princ (strcat "\nFast batch: processing frame-only sheets, count=" (itoa frame-only-count)))
          (setq frame-result
            (vl-catch-all-apply
              'swcad-title-transfer-frame-only-clone-batch-run
              (list frame-only-count)
            )
          )
          (if (vl-catch-all-error-p frame-result)
            (progn
              (setq *swcad-title-last-apply-status* "ERROR_FAST_BATCH_FRAME_ONLY_FATAL")
              (princ
                (strcat
                  "\nFast batch frame-only error: "
                  (vl-catch-all-error-message frame-result)
                )
              )
            )
          )
        )
      )
    )
    (princ
      (strcat
        "\nFast batch skipped frame-only phase because title phase left "
        (itoa final-source-count)
        " source title sheet(s)."
      )
    )
  )
  (setq *swcad-title-batch-mode* old-batch-mode)
  (setq final-source-count (swcad-title-source-title-count))
  (setq final-frame-only-count (swcad-title-frame-only-source-count))
  (princ (strcat "\nRemaining source title sheets after fast batch: " (itoa final-source-count)))
  (princ (strcat "\nRemaining frame-only sheets after fast batch: " (itoa final-frame-only-count)))
  (swcad-title-print-fast-sheet-summary (swcad-title-fast-sheet-summary))
  (setq contaminated (swcad-title-contaminated-target-frame-blocks))
  (princ (strcat "\nContaminated target frame definitions after fast batch: " (swcad-title-list-string contaminated)))
  (cond
    ((equal *swcad-title-last-apply-status* "WAITING_FOR_EXACT_SIZE_NATIVE_GMTITLE_EXEMPLARS")
      (princ "\nResult: WAITING_FOR_EXACT_SIZE_NATIVE_GMTITLE_EXEMPLARS")
      (princ "\nFast batch paused so the next sheet size can be created once with real native GMTITLE.")
      (princ "\nRun SWTITLEFASTSTATUS for the exact next action.")
    )
    ((or (> final-source-count 0) (> final-frame-only-count 0))
      (setq *swcad-title-last-apply-status* "WARN_FAST_BATCH_REMAINING_SOURCES")
      (princ "\nResult: WARN_FAST_BATCH_REMAINING_SOURCES")
    )
    (contaminated
      (setq *swcad-title-last-apply-status* "WARN_FAST_BATCH_FRAME_DEFS_CONTAMINATED")
      (princ "\nResult: WARN_FAST_BATCH_FRAME_DEFS_CONTAMINATED")
    )
    (T
      (setq *swcad-title-last-apply-status* "OK_FAST_BATCH_COMPLETE")
      (princ "\nResult: OK_FAST_BATCH_COMPLETE")
      (princ "\nNext: run SWTITLEUPGRADENATIVESTATUS, then SWTITLEGMTITLEVERIFYALL.")
      (princ "\nImportant: fast batch may create clone GMTITLE pairs. Clone pairs can look correct but still fail GMPOWEREDIT/double-click native behavior.")
      (princ "\nFinal success requires no clone/native-upgrade warnings and manual A2/A3/A4 double-click checks.")
    )
  )
  *swcad-title-last-apply-status*
)

(defun swcad-title-transfer-fast-batch (/ summary source-count frame-only-count contaminated example-title missing-required frame-records geometry-risk-count overlap-risk-count answer)
  (setq summary (swcad-title-fast-sheet-summary))
  (setq source-count (swcad-title-fast-summary-value summary "source-title-count"))
  (setq frame-only-count (swcad-title-fast-summary-value summary "frame-only-count"))
  (setq contaminated (swcad-title-contaminated-target-frame-blocks))
  (setq example-title (swcad-title-native-example-title))
  (setq missing-required (swcad-title-missing-required-native-frame-blocks summary))
  (setq frame-records (swcad-title-frame-records))
  (setq geometry-risk-count (swcad-title-target-frame-geometry-warning-count frame-records))
  (setq overlap-risk-count (swcad-title-target-frame-overlap-warning-count frame-records))
  (princ "\n----- SWTITLETRANSFERFASTBATCH fast remaining-sheet transfer -----")
  (princ (strcat "\nDWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (princ (strcat "\nCTAB: " (getvar "CTAB")))
  (princ
    (strcat
      "\nWork-folder test copy: "
      (if (swcad-title-current-dwg-in-work-p) "yes" "no")
    )
  )
  (princ (strcat "\nRemaining source title sheets: " (itoa source-count)))
  (princ (strcat "\nRemaining frame-only sheets: " (itoa frame-only-count)))
  (swcad-title-print-fast-sheet-summary summary)
  (princ
    (strcat
      "\nAny native GMTITLE title: "
      (swcad-title-native-example-description example-title)
    )
  )
  (swcad-title-print-native-exemplars-by-frame)
  (swcad-title-print-required-native-exemplars summary)
  (swcad-title-print-next-fast-target-readiness)
  (princ (strcat "\nContaminated target frame definitions: " (swcad-title-list-string contaminated)))
  (if contaminated
    (princ "\nWarning: target frame definitions are flagged source-like; exact-size clone will continue only when the same-size native exemplar exists.")
  )
  (if (or (> geometry-risk-count 0) (> overlap-risk-count 0))
    (swcad-title-print-target-frame-selection-diagnostics frame-records)
  )
  (cond
    ((swcad-title-document-read-only-p)
      (setq *swcad-title-last-apply-status* "ABORT_READ_ONLY_DOCUMENT")
      (princ "\nResult: ABORT_READ_ONLY_DOCUMENT")
      (princ "\nOpen a writable work copy before running the fast batch.")
    )
    ((not (swcad-title-current-dwg-in-work-p))
      (setq *swcad-title-last-apply-status* "ABORT_NOT_WORK_COPY")
      (princ "\nResult: ABORT_NOT_WORK_COPY")
      (princ "\nFast batch is limited to Documents/CAD tool/work copies.")
    )
    ((> geometry-risk-count 0)
      (setq *swcad-title-last-apply-status* "WARN_TARGET_FRAME_GEOMETRY_INVALID")
      (princ "\nResult: WARN_TARGET_FRAME_GEOMETRY_INVALID")
      (princ "\nFast batch stopped because an existing target frame has invalid A-size geometry.")
      (princ "\nRun SWTITLENATIVEFRAMECHECK and repair/recreate the bad sheet size before continuing.")
    )
    ((> overlap-risk-count 0)
      (setq *swcad-title-last-apply-status* "WARN_TARGET_FRAME_SELECTION_RISK")
      (princ "\nResult: WARN_TARGET_FRAME_SELECTION_RISK")
      (princ "\nFast batch stopped because existing target frames overlap and may select the wrong GMTITLE object.")
      (princ "\nRun SWTITLENATIVEFRAMECHECK before continuing.")
    )
    ((and (= source-count 0) (= frame-only-count 0))
      (setq *swcad-title-last-apply-status* "OK_NO_REMAINING_SOURCES")
      (princ "\nResult: OK_NO_REMAINING_SOURCES")
      (princ "\nRun SWTITLEGMTITLEVERIFYALL for trusted A2/A3/A4 verification.")
    )
    ((not example-title)
      (setq *swcad-title-last-apply-status* "ABORT_NO_NATIVE_GMTITLE_EXEMPLAR")
      (princ "\nResult: ABORT_NO_NATIVE_GMTITLE_EXEMPLAR")
      (princ "\nCreate/finalize one real native GMTITLE first, then run this command again.")
      (princ "\nCloned titles whose native link points to a visible frame are not accepted as exemplars.")
      (princ "\nRecommended: run SWTITLETRANSFERBOOTSTRAPFAST, or run SWTITLETRANSFERAPPLY/SWTITLETRANSFERFINALIZE for the first sheet.")
    )
    ((and missing-required (not (swcad-title-next-fast-target-ready-p)))
      (setq *swcad-title-last-apply-status* "WAITING_FOR_EXACT_SIZE_NATIVE_GMTITLE_EXEMPLARS")
      (princ "\nResult: WAITING_FOR_EXACT_SIZE_NATIVE_GMTITLE_EXEMPLARS")
      (princ "\nCreate/finalize one real native GMTITLE for each missing sheet size first.")
      (princ "\nUse SWTITLETRANSFERAPPLY for title sheets and SWTITLEFRAMEONLYAPPLY for frame-only sheets.")
      (princ "\nThen run SWTITLEFASTSTATUS and SWTITLETRANSFERFASTBATCH again.")
    )
    (T
      (setq answer
        (getstring
          T
          (strcat
            "\nType YES to process "
            (itoa source-count)
            " title sheet(s) and "
            (itoa frame-only-count)
            " frame-only sheet(s): "
          )
        )
      )
      (if (/= (strcase answer) "YES")
        (progn
          (setq *swcad-title-last-apply-status* "ABORT_USER_CANCEL")
          (princ "\nResult: ABORT_USER_CANCEL")
        )
        (swcad-title-run-fast-batch-phases)
      )
    )
  )
  (princ)
)

(defun swcad-title-transfer-bootstrap-fast (/ summary source-count frame-only-count contaminated example-title missing-required frame-records geometry-risk-count overlap-risk-count answer old-batch-mode apply-result after-summary after-missing)
  (setq summary (swcad-title-fast-sheet-summary))
  (setq source-count (swcad-title-fast-summary-value summary "source-title-count"))
  (setq frame-only-count (swcad-title-fast-summary-value summary "frame-only-count"))
  (setq contaminated (swcad-title-contaminated-target-frame-blocks))
  (setq example-title (swcad-title-native-example-title))
  (setq missing-required (swcad-title-missing-required-native-frame-blocks summary))
  (setq frame-records (swcad-title-frame-records))
  (setq geometry-risk-count (swcad-title-target-frame-geometry-warning-count frame-records))
  (setq overlap-risk-count (swcad-title-target-frame-overlap-warning-count frame-records))
  (princ "\n----- SWTITLETRANSFERBOOTSTRAPFAST first-native + fast batch transfer -----")
  (princ (strcat "\nDWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (princ (strcat "\nCTAB: " (getvar "CTAB")))
  (princ
    (strcat
      "\nWork-folder test copy: "
      (if (swcad-title-current-dwg-in-work-p) "yes" "no")
    )
  )
  (swcad-title-print-fast-sheet-summary summary)
  (if
    (and
      (not example-title)
      (> source-count 0)
    )
    (swcad-title-print-next-bootstrap-selection)
  )
  (princ
    (strcat
      "\nAny native GMTITLE title: "
      (swcad-title-native-example-description example-title)
    )
  )
  (swcad-title-print-native-exemplars-by-frame)
  (swcad-title-print-required-native-exemplars summary)
  (swcad-title-print-next-fast-target-readiness)
  (princ (strcat "\nContaminated target frame definitions: " (swcad-title-list-string contaminated)))
  (if contaminated
    (princ "\nWarning: target frame definitions are flagged source-like; exact-size clone will continue only when the same-size native exemplar exists.")
  )
  (if (or (> geometry-risk-count 0) (> overlap-risk-count 0))
    (swcad-title-print-target-frame-selection-diagnostics frame-records)
  )
  (cond
    ((swcad-title-document-read-only-p)
      (setq *swcad-title-last-apply-status* "ABORT_READ_ONLY_DOCUMENT")
      (princ "\nResult: ABORT_READ_ONLY_DOCUMENT")
      (princ "\nOpen a writable work copy before running the bootstrap fast transfer.")
    )
    ((not (swcad-title-current-dwg-in-work-p))
      (setq *swcad-title-last-apply-status* "ABORT_NOT_WORK_COPY")
      (princ "\nResult: ABORT_NOT_WORK_COPY")
      (princ "\nBootstrap fast transfer is limited to Documents/CAD tool/work copies.")
    )
    ((> geometry-risk-count 0)
      (setq *swcad-title-last-apply-status* "WARN_TARGET_FRAME_GEOMETRY_INVALID")
      (princ "\nResult: WARN_TARGET_FRAME_GEOMETRY_INVALID")
      (princ "\nBootstrap fast transfer stopped because an existing target frame has invalid A-size geometry.")
      (princ "\nRun SWTITLENATIVEFRAMECHECK and repair/recreate the bad sheet size before continuing.")
    )
    ((> overlap-risk-count 0)
      (setq *swcad-title-last-apply-status* "WARN_TARGET_FRAME_SELECTION_RISK")
      (princ "\nResult: WARN_TARGET_FRAME_SELECTION_RISK")
      (princ "\nBootstrap fast transfer stopped because existing target frames overlap and may select the wrong GMTITLE object.")
      (princ "\nRun SWTITLENATIVEFRAMECHECK before continuing.")
    )
    ((and (= source-count 0) (= frame-only-count 0))
      (setq *swcad-title-last-apply-status* "OK_NO_REMAINING_SOURCES")
      (princ "\nResult: OK_NO_REMAINING_SOURCES")
      (princ "\nRun SWTITLEGMTITLEVERIFYALL for trusted A2/A3/A4 verification.")
    )
    ((and example-title missing-required (not (swcad-title-next-fast-target-ready-p)))
      (setq *swcad-title-last-apply-status* "WAITING_FOR_EXACT_SIZE_NATIVE_GMTITLE_EXEMPLARS")
      (princ "\nResult: WAITING_FOR_EXACT_SIZE_NATIVE_GMTITLE_EXEMPLARS")
      (princ "\nA native GMTITLE exemplar exists, but one or more remaining sheet sizes still need their own first real GMTITLE.")
      (princ "\nUse SWTITLETRANSFERAPPLY for title sheets and SWTITLEFRAMEONLYAPPLY for frame-only sheets.")
      (princ "\nThen run SWTITLEFASTSTATUS and SWTITLETRANSFERFASTBATCH again.")
    )
    (example-title
      (setq answer
        (getstring
          T
          "\nExisting native GMTITLE exemplar found. Type YES to run the fast remaining-sheet batch: "
        )
      )
      (if (/= (strcase answer) "YES")
        (progn
          (setq *swcad-title-last-apply-status* "ABORT_USER_CANCEL")
          (princ "\nResult: ABORT_USER_CANCEL")
        )
        (swcad-title-run-fast-batch-phases)
      )
    )
    ((= source-count 0)
      (setq *swcad-title-last-apply-status* "ABORT_NO_TITLE_SOURCE_FOR_BOOTSTRAP")
      (princ "\nResult: ABORT_NO_TITLE_SOURCE_FOR_BOOTSTRAP")
      (princ "\nNo title source remains to create the first native GMTITLE exemplar.")
      (princ "\nCreate one native GMTITLE manually, then run SWTITLEFRAMEONLYCLONEBATCH or SWTITLETRANSFERFASTBATCH.")
    )
    (T
      (setq answer
        (getstring
          T
          "\nType YES to create/finalize the first native GMTITLE, then continue only if exact-size native exemplars are ready: "
        )
      )
      (if (/= (strcase answer) "YES")
        (progn
          (setq *swcad-title-last-apply-status* "ABORT_USER_CANCEL")
          (princ "\nResult: ABORT_USER_CANCEL")
        )
        (progn
          (princ "\nBootstrap phase: native GMTITLE will open once for the first detected title sheet.")
          (princ "\nManual first-native picker is currently required by GstarCAD.")
          (princ "\nIn the GMTITLE dialog:")
          (princ "\n  1. Choose the detected DR sheet shown above.")
          (princ "\n  2. Choose DR_titlea_3rd.")
          (princ "\n  3. Keep Frame positioning ON.")
          (princ "\n  4. Turn OFF Object move.")
          (princ "\n  5. Confirm/place it once; the LISP aligns it and then checks whether same-size native exemplars are ready.")
          (setq old-batch-mode *swcad-title-batch-mode*)
          (setq *swcad-title-batch-mode* T)
          (setq apply-result (vl-catch-all-apply 'swcad-title-transfer-apply nil))
          (setq *swcad-title-batch-mode* old-batch-mode)
          (if (vl-catch-all-error-p apply-result)
            (progn
              (setq *swcad-title-last-apply-status* "ERROR_BOOTSTRAP_FIRST_NATIVE_FATAL")
              (princ
                (strcat
                  "\nBootstrap first-native error: "
                  (vl-catch-all-error-message apply-result)
                )
              )
            )
          )
          (princ
            (strcat
              "\nBootstrap first-native status: "
              (swcad-title-string *swcad-title-last-apply-status*)
            )
          )
          (if (swcad-title-bootstrap-first-native-success-p *swcad-title-last-apply-status*)
            (progn
              (setq after-summary (swcad-title-fast-sheet-summary))
              (setq after-missing (swcad-title-missing-required-native-frame-blocks after-summary))
              (if (and after-missing (not (swcad-title-next-fast-target-ready-p)))
                (progn
                  (setq *swcad-title-last-apply-status* "WAITING_FOR_EXACT_SIZE_NATIVE_GMTITLE_EXEMPLARS")
                  (princ "\nBootstrap phase complete. Fast batch paused because another sheet size needs its own real GMTITLE exemplar.")
                  (swcad-title-print-fast-sheet-summary after-summary)
                  (swcad-title-print-required-native-exemplars after-summary)
                  (swcad-title-print-next-fast-target-readiness)
                  (princ "\nResult: WAITING_FOR_EXACT_SIZE_NATIVE_GMTITLE_EXEMPLARS")
                )
                (progn
                  (princ "\nBootstrap phase complete. Starting fast remaining-sheet batch.")
                  (swcad-title-run-fast-batch-phases)
                )
              )
            )
            (princ
              (strcat
                "\nFast batch not started because bootstrap phase ended with status: "
                (swcad-title-string *swcad-title-last-apply-status*)
              )
            )
          )
        )
      )
    )
  )
  (princ)
)

(defun swcad-title-scale-text-to-dimlfac (text / cleaned ratio pos left right numerator denominator value)
  (setq cleaned (vl-string-trim " \t\r\n" (swcad-title-string text)))
  (setq ratio (swcad-title-extract-ratio-text cleaned))
  (if ratio
    (setq cleaned ratio)
  )
  (setq pos (vl-string-search ":" cleaned))
  (cond
    (pos
      (setq left
        (if (> pos 0)
          (vl-string-trim " \t\r\n" (substr cleaned 1 pos))
          ""
        )
      )
      (setq right (vl-string-trim " \t\r\n" (substr cleaned (+ pos 2))))
      (setq numerator (atof left))
      (setq denominator (atof right))
      (if (and (> numerator 0.0) (> denominator 0.0))
        (/ numerator denominator)
        nil
      )
    )
    (T
      (setq value (atof cleaned))
      (if (> value 0.0) value nil)
    )
  )
)

(defun swcad-title-expected-dimlfac-values (scale-values / result item value)
  (setq result nil)
  (foreach item scale-values
    (setq value (swcad-title-scale-text-to-dimlfac item))
    (if (numberp value)
      (setq result (swcad-title-list-add-unique-float value result))
    )
  )
  result
)

(defun swcad-title-dxf-put (data code value)
  (if (assoc code data)
    (subst (cons code value) (assoc code data) data)
    (append data (list (cons code value)))
  )
)

(defun swcad-title-xdata-apps (data / xd)
  (setq xd (assoc -3 data))
  (if xd (cdr xd) nil)
)

(defun swcad-title-xdata-app-name (app)
  (if (and (listp app) (swcad-title-string-p (car app)))
    (car app)
    nil
  )
)

(defun swcad-title-acad-app (apps / result name)
  (foreach app apps
    (setq name (swcad-title-xdata-app-name app))
    (if (and (not result) name (equal name "ACAD"))
      (setq result app)
    )
  )
  result
)

(defun swcad-title-get-dstyle-overrides (data / apps acad pairs result item code valuepair)
  (setq apps (swcad-title-xdata-apps data))
  (setq acad (swcad-title-acad-app apps))
  (setq pairs (if acad (cdr acad) nil))
  (setq result nil)
  (while pairs
    (setq item (car pairs))
    (if (and (= (car item) 1000) (equal (cdr item) "DSTYLE"))
      (progn
        (setq pairs (cdr pairs))
        (if (and pairs (= (car (car pairs)) 1002) (equal (cdr (car pairs)) "{"))
          (setq pairs (cdr pairs))
        )
        (while (and pairs
                    (not (and (= (car (car pairs)) 1002)
                              (equal (cdr (car pairs)) "}"))))
          (if (and (= (car (car pairs)) 1070) (cdr pairs))
            (progn
              (setq code (cdr (car pairs)))
              (setq valuepair (cadr pairs))
              (setq result (swcad-title-dxf-put result code (cdr valuepair)))
              (setq pairs (cddr pairs))
            )
            (setq pairs (cdr pairs))
          )
        )
      )
    )
    (if pairs (setq pairs (cdr pairs)))
  )
  result
)

(defun swcad-title-dimstyle-or-override-value (data code / style styledata overrides)
  (setq overrides (swcad-title-get-dstyle-overrides data))
  (setq style (swcad-title-safe-string (cdr (assoc 3 data))))
  (setq styledata (if style (tblsearch "DIMSTYLE" style) nil))
  (cond
    ((assoc code overrides) (cdr (assoc code overrides)))
    ((and styledata (assoc code styledata)) (cdr (assoc code styledata)))
    (T nil)
  )
)

(defun swcad-title-dim-linear-scale (ename data / object value)
  (setq value (swcad-title-dimstyle-or-override-value data 144))
  (if (or (not value) (not (numberp value)) (equal (float value) 0.0 1e-12))
    (progn
      (setq object (swcad-title-safe-vla-object ename))
      (setq value (swcad-title-safe-vla-get object 'LinearScaleFactor))
    )
  )
  (if (or (not value) (not (numberp value)) (equal (float value) 0.0 1e-12))
    1.0
    (float value)
  )
)

(defun c:SWTITLESCAN (/ ss index ename total)
  (swcad-title-open-scan-log)
  (setq *swcad-title-scan-title-insert-count* 0)
  (setq *swcad-title-scan-scale-count* 0)
  (setq *swcad-title-scan-loose-text-count* 0)
  (setq *swcad-title-scan-loose-scale-count* 0)
  (setq *swcad-title-scan-scale-values* nil)
  (swcad-title-princ-line "----- SWTITLESCAN read-only title scale scan -----")
  (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (swcad-title-princ-line (strcat "CTAB: " (getvar "CTAB")))
  (setq ss (ssget "_X" '((0 . "INSERT"))))
  (setq total (if ss (sslength ss) 0))
  (swcad-title-princ-line (strcat "INSERT count: " (itoa total)))
  (swcad-title-princ-line "Attribute title scale candidates:")
  (setq index 0)
  (while (< index total)
    (setq ename (ssname ss index))
    (swcad-title-scan-insert ename)
    (setq index (+ index 1))
  )
  (if (= *swcad-title-scan-scale-count* 0)
    (swcad-title-princ-line "  <none>")
  )
  (swcad-title-scan-loose-texts)
  (swcad-title-princ-line "Summary:")
  (swcad-title-princ-line
    (strcat "  title inserts with scale: " (itoa *swcad-title-scan-title-insert-count*))
  )
  (swcad-title-princ-line
    (strcat "  scale attributes: " (itoa *swcad-title-scan-scale-count*))
  )
  (swcad-title-princ-line
    (strcat "  loose text scale candidates: " (itoa *swcad-title-scan-loose-scale-count*))
  )
  (swcad-title-princ-line
    (strcat "  scale values: " (swcad-title-list-string *swcad-title-scan-scale-values*))
  )
  (swcad-title-princ-line
    (strcat
      "Result: "
      (if (> (+ *swcad-title-scan-scale-count* *swcad-title-scan-loose-scale-count*) 0)
        "OK_TITLE_SCALE_FOUND"
        "MISSING_TITLE_SCALE"
      )
    )
  )
  (swcad-title-princ-line "No drawing data was changed.")
  (swcad-title-close-log)
  (princ)
)

(defun swcad-title-cloned-gmtitle-pair-records (/ frame-records title-enames used-title-enames result frame-record frame-ename frame-block frame-bbox title-ename title-bbox title-role frame-role)
  (setq frame-records (swcad-title-frame-records))
  (setq title-enames (swcad-title-inserts-by-effective-name (swcad-title-target-title-block-name)))
  (setq used-title-enames nil)
  (setq result nil)
  (foreach frame-record frame-records
    (setq frame-ename (car frame-record))
    (setq frame-block (cadr frame-record))
    (setq frame-bbox (cadddr frame-record))
    (setq title-ename (swcad-title-title-for-frame-record-unused frame-record title-enames used-title-enames))
    (if title-ename
      (setq used-title-enames (append used-title-enames (list title-ename)))
    )
    (setq title-bbox (if title-ename (swcad-title-safe-bbox title-ename) nil))
    (setq title-role (if title-ename (swcad-title-exemplar-role title-ename) ""))
    (setq frame-role (swcad-title-exemplar-role frame-ename))
    (if
      (and
        title-ename
        frame-ename
        frame-block
        title-bbox
        frame-bbox
        (swcad-title-trusted-native-exemplar-pair-p title-ename frame-ename frame-block)
        (or
          (equal (strcase title-role) "CLONE")
          (equal (strcase frame-role) "CLONE")
        )
      )
      (setq result
        (append
          result
          (list
            (list
              title-ename
              frame-ename
              frame-block
              title-bbox
              frame-bbox
              title-role
              frame-role
            )
          )
        )
      )
    )
  )
  result
)

(defun swcad-title-first-cloned-gmtitle-pair-record ()
  (car (swcad-title-cloned-gmtitle-pair-records))
)

(defun swcad-title-cloned-gmtitle-pair-record-for-ename (ename / insert-ename records result record)
  (setq insert-ename (swcad-title-enclosing-insert-ename ename))
  (setq records (swcad-title-cloned-gmtitle-pair-records))
  (setq result nil)
  (foreach record records
    (if
      (and
        (not result)
        (or
          (eq ename (car record))
          (eq ename (cadr record))
          (eq insert-ename (car record))
          (eq insert-ename (cadr record))
        )
      )
      (setq result record)
    )
  )
  result
)

(defun swcad-title-cloned-gmtitle-pair-record-for-point (point / records result record frame-bbox title-bbox)
  (setq records (swcad-title-cloned-gmtitle-pair-records))
  (setq result nil)
  (foreach record records
    (setq title-bbox (nth 3 record))
    (setq frame-bbox (nth 4 record))
    (if
      (and
        (not result)
        (or
          (swcad-title-point-in-expanded-bbox-flex-p point frame-bbox 2.0)
          (swcad-title-point-in-expanded-bbox-flex-p point title-bbox 2.0)
        )
      )
      (setq result record)
    )
  )
  result
)

(defun swcad-title-target-gmtitle-pair-records (/ frame-records title-enames used-title-enames result frame-record frame-ename frame-block frame-bbox title-ename title-bbox title-role frame-role)
  (setq frame-records (swcad-title-frame-records))
  (setq title-enames (swcad-title-inserts-by-effective-name (swcad-title-target-title-block-name)))
  (setq used-title-enames nil)
  (setq result nil)
  (foreach frame-record frame-records
    (setq frame-ename (car frame-record))
    (setq frame-block (cadr frame-record))
    (setq frame-bbox (cadddr frame-record))
    (setq title-ename (swcad-title-title-for-frame-record-unused frame-record title-enames used-title-enames))
    (if title-ename
      (setq used-title-enames (append used-title-enames (list title-ename)))
    )
    (setq title-bbox (if title-ename (swcad-title-safe-bbox title-ename) nil))
    (setq title-role (if title-ename (swcad-title-exemplar-role title-ename) ""))
    (setq frame-role (swcad-title-exemplar-role frame-ename))
    (if
      (and
        title-ename
        frame-ename
        frame-block
        title-bbox
        frame-bbox
      )
      (setq result
        (append
          result
          (list
            (list
              title-ename
              frame-ename
              frame-block
              title-bbox
              frame-bbox
              title-role
              frame-role
            )
          )
        )
      )
    )
  )
  result
)

(defun swcad-title-target-gmtitle-pair-record-for-ename (ename / insert-ename records result record)
  (setq insert-ename (swcad-title-enclosing-insert-ename ename))
  (setq records (swcad-title-target-gmtitle-pair-records))
  (setq result nil)
  (foreach record records
    (if
      (and
        (not result)
        (or
          (eq ename (car record))
          (eq ename (cadr record))
          (eq insert-ename (car record))
          (eq insert-ename (cadr record))
        )
      )
      (setq result record)
    )
  )
  result
)

(defun swcad-title-target-gmtitle-pair-record-for-point (point / records result record frame-bbox title-bbox)
  (setq records (swcad-title-target-gmtitle-pair-records))
  (setq result nil)
  (foreach record records
    (setq title-bbox (nth 3 record))
    (setq frame-bbox (nth 4 record))
    (if
      (and
        (not result)
        (or
          (swcad-title-point-in-expanded-bbox-flex-p point frame-bbox 2.0)
          (swcad-title-point-in-expanded-bbox-flex-p point title-bbox 2.0)
        )
      )
      (setq result record)
    )
  )
  result
)

(defun swcad-title-pick-area-for-pair (ename point record / insert title frame title-bbox frame-bbox)
  (setq insert (swcad-title-enclosing-insert-ename ename))
  (setq title (car record))
  (setq frame (cadr record))
  (setq title-bbox (nth 3 record))
  (setq frame-bbox (nth 4 record))
  (cond
    ((or (eq ename title) (eq insert title)) "title-insert")
    ((or (eq ename frame) (eq insert frame)) "frame-insert")
    ((swcad-title-point-in-expanded-bbox-flex-p point title-bbox 2.0) "title-area")
    ((swcad-title-point-in-expanded-bbox-flex-p point frame-bbox 2.0) "frame-area")
    (T "unknown")
  )
)

(defun swcad-title-pick-check (/ picked ename pick-point wcs-point insert-ename insert-name record area title-ename frame-ename frame-block title-bbox frame-bbox title-role frame-role native-like reason geometry-warning title-center frame-center)
  (swcad-title-open-pick-check-log)
  (swcad-title-princ-line "----- SWTITLEPICKCHECK read-only GMTITLE pick check -----")
  (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (swcad-title-princ-line (strcat "CTAB: " (getvar "CTAB")))
  (swcad-title-print-work-copy-status)
  (setq picked (entsel "\nSelect GMTITLE title/frame to check: "))
  (setq ename (if picked (car picked) nil))
  (setq pick-point (if picked (cadr picked) nil))
  (setq wcs-point (swcad-title-safe-trans-point pick-point 1 0))
  (setq insert-ename (if ename (swcad-title-enclosing-insert-ename ename) nil))
  (setq insert-name (if insert-ename (swcad-title-effective-insert-name insert-ename) ""))
  (swcad-title-princ-line
    (strcat
      "Selected entity: "
      (if ename
        (strcat
          "handle="
          (swcad-title-ename-handle ename)
          ", type="
          (swcad-title-entity-type-name ename)
        )
        "<none>"
      )
    )
  )
  (if insert-ename
    (swcad-title-princ-line
      (strcat
        "Enclosing insert: handle="
        (swcad-title-ename-handle insert-ename)
        ", block="
        insert-name
      )
    )
    (swcad-title-princ-line "Enclosing insert: <none>")
  )
  (swcad-title-princ-line (strcat "Selected point: " (if pick-point (swcad-title-point-string pick-point) "<none>")))
  (swcad-title-princ-line (strcat "Selected point WCS: " (if wcs-point (swcad-title-point-string wcs-point) "<none>")))
  (setq record (if ename (swcad-title-target-gmtitle-pair-record-for-ename ename) nil))
  (if (and (not record) pick-point)
    (setq record (swcad-title-target-gmtitle-pair-record-for-point pick-point))
  )
  (if (and (not record) wcs-point)
    (setq record (swcad-title-target-gmtitle-pair-record-for-point wcs-point))
  )
  (if record
    (progn
      (setq title-ename (car record))
      (setq frame-ename (cadr record))
      (setq frame-block (caddr record))
      (setq title-bbox (nth 3 record))
      (setq frame-bbox (nth 4 record))
      (setq title-role (nth 5 record))
      (setq frame-role (nth 6 record))
      (setq area (swcad-title-pick-area-for-pair ename pick-point record))
      (setq native-like (swcad-title-target-pair-native-like-p record))
      (setq reason (swcad-title-target-pair-upgrade-reason record))
      (setq geometry-warning (swcad-title-frame-bbox-size-warning-for-block frame-block frame-bbox))
      (setq title-center (swcad-title-bbox-center title-bbox))
      (setq frame-center (swcad-title-bbox-center frame-bbox))
      (swcad-title-princ-line (strcat "Pick area: " area))
      (swcad-title-princ-line
        (strcat
          "Pair sheet/frame: "
          (swcad-title-string (swcad-title-sheet-size-from-block-name frame-block))
          ", "
          frame-block
        )
      )
      (swcad-title-princ-line
        (strcat
          "Title insert: handle="
          (swcad-title-ename-handle title-ename)
          ", role="
          (if (> (strlen title-role) 0) title-role "<none>")
          ", center="
          (swcad-title-point-string title-center)
          ", bbox="
          (swcad-title-bbox-string title-bbox)
        )
      )
      (swcad-title-princ-line
        (strcat
          "Frame insert: handle="
          (swcad-title-ename-handle frame-ename)
          ", role="
          (if (> (strlen frame-role) 0) frame-role "<none>")
          ", center="
          (swcad-title-point-string frame-center)
          ", bbox="
          (swcad-title-bbox-string frame-bbox)
        )
      )
      (swcad-title-princ-line (strcat "Native-like pair: " (if native-like "yes" "no")))
      (swcad-title-princ-line (strcat "Reason/status detail: " reason))
      (if geometry-warning
        (swcad-title-princ-line (strcat "Frame geometry warning: " geometry-warning))
      )
      (cond
        ((or (equal area "frame-insert") (equal area "frame-area"))
          (swcad-title-princ-line "Double-click note: this is the DR_A*_Outline frame INSERT. GMPOWEREDIT may show block/reference editing here.")
          (swcad-title-princ-line "For the GMTITLE table editor, test the paired DR_titlea_3rd title insert listed above.")
        )
        ((or (equal area "title-insert") (equal area "title-area"))
          (swcad-title-princ-line "Double-click note: this is the title block area; this is the right place to check the GMTITLE table editor.")
        )
      )
      (cond
        (geometry-warning
          (swcad-title-apply-result "WARN_PICK_TARGET_FRAME_GEOMETRY_INVALID")
        )
        (native-like
          (if (or (equal area "frame-insert") (equal area "frame-area"))
            (swcad-title-apply-result "OK_PICK_NATIVE_PAIR_BUT_FRAME_SELECTED")
            (swcad-title-apply-result "OK_PICK_NATIVE_TITLE_READY")
          )
        )
        ((or
           (equal reason "clone")
           (equal reason "finalize-or-frame-only-marker-needs-native-recheck")
           (equal reason "shared-native-link-handle")
           (equal reason "native-created-then-moved; GMPOWEREDIT-unverified")
         )
          (swcad-title-apply-result "NEEDS_NATIVE_A3A4_UPGRADE")
          (swcad-title-princ-line "This picked pair is not accepted as fresh native GMTITLE for final double-click behavior.")
          (swcad-title-princ-line "Next: run SWTITLEA3A4PREP, create one GMTITLE normally, then run SWTITLEA3A4FINISH.")
        )
        (T
          (swcad-title-apply-result "NEEDS_GMTITLE_PAIR_REVIEW")
          (swcad-title-princ-line "Next: run SWTITLEUPGRADENATIVESTATUS and SWTITLEGMTITLEVERIFYALL, then share this pick-check log if the pair still opens GMPOWEREDIT/REFEDIT.")
        )
      )
    )
    (progn
      (swcad-title-apply-result "NO_TARGET_GMTITLE_PAIR_AT_PICK")
      (swcad-title-princ-line "No matching DR_A*_Outline + DR_titlea_3rd pair was found at the selected entity/point.")
    )
  )
  (swcad-title-princ-line "No drawing data was changed.")
  (swcad-title-close-log)
  (princ)
)

(defun swcad-title-role-display (role / value)
  (setq value (swcad-title-string role))
  (if (> (strlen value) 0) value "<none>")
)

(defun swcad-title-double-click-check-record (index record / title-ename frame-ename frame-block title-bbox frame-bbox title-role frame-role sheet title-center native-like reason geometry-warning)
  (setq title-ename (car record))
  (setq frame-ename (cadr record))
  (setq frame-block (caddr record))
  (setq title-bbox (nth 3 record))
  (setq frame-bbox (nth 4 record))
  (setq title-role (nth 5 record))
  (setq frame-role (nth 6 record))
  (setq sheet (swcad-title-sheet-size-from-block-name frame-block))
  (setq title-center (swcad-title-bbox-center title-bbox))
  (setq native-like (swcad-title-target-pair-native-like-p record))
  (setq reason (swcad-title-target-pair-upgrade-reason record))
  (setq geometry-warning (swcad-title-frame-bbox-size-warning-for-block frame-block frame-bbox))
  (swcad-title-princ-line
    (strcat
      "#"
      (itoa index)
      " sheet="
      (swcad-title-string sheet)
      ", native-like="
      (if native-like "yes" "no")
      ", reason="
      reason
    )
  )
  (swcad-title-princ-line
    (strcat
      "  Title double-click point: "
      (swcad-title-point-string title-center)
      ", handle="
      (swcad-title-ename-handle title-ename)
      ", role="
      (swcad-title-role-display title-role)
      ", bbox="
      (swcad-title-bbox-string title-bbox)
    )
  )
  (swcad-title-princ-line
    (strcat
      "  Paired frame: "
      frame-block
      ", handle="
      (swcad-title-ename-handle frame-ename)
      ", role="
      (swcad-title-role-display frame-role)
      ", bbox="
      (swcad-title-bbox-string frame-bbox)
    )
  )
  (if geometry-warning
    (swcad-title-princ-line (strcat "  Frame geometry warning: " geometry-warning))
  )
  native-like
)

(defun swcad-title-double-click-check (/ records record index native-count needs-count)
  (swcad-title-open-double-click-check-log)
  (swcad-title-princ-line "----- SWTITLEDOUBLECLICKCHECK read-only manual double-click checklist -----")
  (swcad-title-print-loaded-version)
  (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (swcad-title-princ-line (strcat "CTAB: " (getvar "CTAB")))
  (swcad-title-print-work-copy-status)
  (setq records (swcad-title-target-gmtitle-pair-records))
  (swcad-title-princ-line (strcat "Target GMTITLE title/frame pairs: " (itoa (length records))))
  (if records
    (progn
      (swcad-title-princ-line "Manual check rule: double-click the DR_titlea_3rd title block, not the DR_A*_Outline frame.")
      (swcad-title-princ-line "The frame may open GMPOWEREDIT/REFEDIT even when the paired title block is usable.")
      (swcad-title-princ-line "Use the listed title double-click point as the visual target; the live cursor grip can still look centered in GstarCAD.")
      (setq index 0)
      (setq native-count 0)
      (setq needs-count 0)
      (foreach record records
        (setq index (+ index 1))
        (if (swcad-title-double-click-check-record index record)
          (setq native-count (+ native-count 1))
          (setq needs-count (+ needs-count 1))
        )
      )
      (swcad-title-princ-line (strcat "Native-like pairs: " (itoa native-count)))
      (swcad-title-princ-line (strcat "Pairs needing native recheck/replacement: " (itoa needs-count)))
      (if (> needs-count 0)
        (progn
          (swcad-title-apply-result "NEEDS_NATIVE_A3A4_UPGRADE")
          (swcad-title-princ-line "Next: run SWTITLEUPGRADENATIVESTATUS, then use SWTITLEA3A4PREP plus SWTITLEA3A4FINISH for remaining candidates.")
        )
        (progn
          (swcad-title-apply-result "OK_DOUBLE_CLICK_MANUAL_CHECK_READY")
          (swcad-title-princ-line "Next: double-click representative A2, A3, and A4 title blocks on screen and confirm the GMTITLE table editor opens.")
          (swcad-title-princ-line "If one opens GMPOWEREDIT/REFEDIT, run SWTITLEPICKCHECK on that object and share the log.")
        )
      )
    )
    (progn
      (swcad-title-apply-result "FAIL_MISSING_TARGET_GMTITLE_PAIRS")
      (swcad-title-princ-line "No DR_A*_Outline + DR_titlea_3rd pairs were found.")
    )
  )
  (swcad-title-princ-line "No drawing data was changed.")
  (swcad-title-close-log)
  (princ)
)

(defun swcad-title-target-pair-native-like-p (record / title-ename frame-ename frame-block frame-bbox title-role frame-role pair-trusted clone-pair legacy-uncertain geometry-warning title-link-internal title-link-shared)
  (setq title-ename (car record))
  (setq frame-ename (cadr record))
  (setq frame-block (caddr record))
  (setq frame-bbox (nth 4 record))
  (setq title-role (nth 5 record))
  (setq frame-role (nth 6 record))
  (setq pair-trusted (swcad-title-trusted-native-exemplar-pair-p title-ename frame-ename frame-block))
  (setq clone-pair
    (or
      (swcad-title-exemplar-clone-role-p title-role)
      (swcad-title-exemplar-clone-role-p frame-role)
    )
  )
  (setq legacy-uncertain
    (or
      (swcad-title-exemplar-legacy-uncertain-native-role-p title-role)
      (swcad-title-exemplar-legacy-uncertain-native-role-p frame-role)
    )
  )
  (setq geometry-warning (swcad-title-frame-bbox-size-warning-for-block frame-block frame-bbox))
  (setq title-link-internal
    (swcad-title-internal-native-link-kinds-p
      (swcad-title-native-link-target-kinds title-ename)
    )
  )
  (setq title-link-shared (swcad-title-target-title-native-link-shared-p title-ename))
  (and
    pair-trusted
    (not clone-pair)
    (not legacy-uncertain)
    (not geometry-warning)
    title-link-internal
    (not title-link-shared)
    (swcad-title-exemplar-native-entity-p title-ename)
    (swcad-title-exemplar-native-entity-p frame-ename)
  )
)

(defun swcad-title-target-pair-upgrade-reason (record / title-ename frame-ename frame-block frame-bbox title-role frame-role pair-trusted clone-pair legacy-uncertain geometry-warning title-native frame-native title-link-kinds title-link-internal title-link-shared)
  (setq title-ename (car record))
  (setq frame-ename (cadr record))
  (setq frame-block (caddr record))
  (setq frame-bbox (nth 4 record))
  (setq title-role (nth 5 record))
  (setq frame-role (nth 6 record))
  (setq pair-trusted (swcad-title-trusted-native-exemplar-pair-p title-ename frame-ename frame-block))
  (setq clone-pair
    (or
      (swcad-title-exemplar-clone-role-p title-role)
      (swcad-title-exemplar-clone-role-p frame-role)
    )
  )
  (setq legacy-uncertain
    (or
      (swcad-title-exemplar-legacy-uncertain-native-role-p title-role)
      (swcad-title-exemplar-legacy-uncertain-native-role-p frame-role)
    )
  )
  (setq geometry-warning (swcad-title-frame-bbox-size-warning-for-block frame-block frame-bbox))
  (setq title-native (swcad-title-exemplar-native-entity-p title-ename))
  (setq frame-native (swcad-title-exemplar-native-entity-p frame-ename))
  (setq title-link-kinds (swcad-title-native-link-target-kinds title-ename))
  (setq title-link-internal (swcad-title-internal-native-link-kinds-p title-link-kinds))
  (setq title-link-shared (swcad-title-target-title-native-link-shared-p title-ename))
  (cond
    (clone-pair "clone")
    ((or
       (swcad-title-exemplar-moved-unverified-role-p title-role)
       (swcad-title-exemplar-moved-unverified-role-p frame-role)
     )
      "native-created-then-moved; GMPOWEREDIT-unverified"
    )
    (legacy-uncertain "finalize-or-frame-only-marker-needs-native-recheck")
    (geometry-warning (strcat "invalid-frame-bbox: " geometry-warning))
    (title-link-shared "shared-native-link-handle")
    ((not title-link-internal)
      (strcat "title-native-link-not-internal:" (swcad-title-list-string title-link-kinds))
    )
    ((not pair-trusted) "untrusted/non-marker")
    ((not (and title-native frame-native)) "not-native-role")
    (T "native-like")
  )
)

(defun swcad-title-sheet-in-list-p (sheet sheets / result item)
  (setq result nil)
  (foreach item sheets
    (if (equal (strcase (swcad-title-string sheet)) (strcase (swcad-title-string item)))
      (setq result T)
    )
  )
  result
)

(defun swcad-title-target-pair-upgrade-candidate-records (sheets / records result record frame-block sheet)
  (setq records (swcad-title-target-gmtitle-pair-records))
  (setq result nil)
  (foreach record records
    (setq frame-block (caddr record))
    (setq sheet (swcad-title-sheet-size-from-block-name frame-block))
    (if
      (and
        sheet
        (swcad-title-sheet-in-list-p sheet sheets)
        (not (swcad-title-target-pair-native-like-p record))
      )
      (setq result (append result (list record)))
    )
  )
  result
)

(defun swcad-title-a3a4-native-upgrade-candidate-records ()
  (swcad-title-target-pair-upgrade-candidate-records '("A3" "A4"))
)

(defun swcad-title-cloned-gmtitle-pair-counts (/ records counts record frame-block sheet)
  (setq records (swcad-title-cloned-gmtitle-pair-records))
  (setq counts nil)
  (foreach record records
    (setq frame-block (caddr record))
    (setq sheet (swcad-title-sheet-size-from-block-name frame-block))
    (setq counts (swcad-title-count-put (if sheet sheet frame-block) counts))
  )
  counts
)

(defun swcad-title-cloned-gmtitle-pair-total ()
  (length (swcad-title-cloned-gmtitle-pair-records))
)

(defun swcad-title-print-a3a4-native-upgrade-candidates (/ records total record index frame-block sheet reason)
  (setq records (swcad-title-a3a4-native-upgrade-candidate-records))
  (setq total (length records))
  (swcad-title-princ-line (strcat "A3/A4 target pairs needing native replacement: " (itoa total)))
  (if records
    (progn
      (setq index 1)
      (foreach record records
        (setq frame-block (caddr record))
        (setq sheet (swcad-title-sheet-size-from-block-name frame-block))
        (setq reason (swcad-title-target-pair-upgrade-reason record))
        (swcad-title-princ-line
          (strcat
            "  A3/A4 #"
            (itoa index)
            " sheet="
            (if sheet sheet "<unknown>")
            ", title="
            (swcad-title-ename-handle (car record))
            ", frame="
            (swcad-title-ename-handle (cadr record))
            ", block="
            frame-block
            ", title-role="
            (if (> (strlen (nth 5 record)) 0) (nth 5 record) "<none>")
            ", frame-role="
            (if (> (strlen (nth 6 record)) 0) (nth 6 record) "<none>")
            ", reason="
            reason
          )
        )
        (setq index (+ index 1))
      )
    )
  )
  total
)

(defun swcad-title-a3a4-fix-plan (/ records total record frame-block sheet reason sheet-counts reason-counts role-failures command-text-count)
  (swcad-title-open-a3a4-fix-plan-log)
  (swcad-title-princ-line "----- SWTITLEA3A4FIXPLAN read-only A3/A4 GMPOWEREDIT fix plan -----")
  (swcad-title-print-loaded-version)
  (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (swcad-title-princ-line (strcat "CTAB: " (getvar "CTAB")))
  (swcad-title-print-work-copy-status)
  (setq command-text-count (swcad-title-command-text-residue-count))
  (swcad-title-princ-line (strcat "Possible accidental command text entities: " (itoa command-text-count)))
  (if (> command-text-count 0)
    (progn
      (swcad-title-princ-line "WARNING: command text may have been inserted into the drawing while CAD was in a text/input state.")
      (swcad-title-princ-line "Run SWTITLECOMMANDTEXTSCAN before applying A3/A4 native upgrades.")
      (swcad-title-princ-line "If the listed items are accidental command leftovers in a work copy, run SWTITLECOMMANDTEXTCLEANSAFE first.")
    )
  )
  (swcad-title-princ-line "Role baseline check:")
  (setq role-failures 0)
  (if (not (swcad-title-role-check-record "native-finalize" T nil))
    (setq role-failures (+ role-failures 1))
  )
  (if (not (swcad-title-role-check-record "native-frame-only" T nil))
    (setq role-failures (+ role-failures 1))
  )
  (setq records (swcad-title-a3a4-native-upgrade-candidate-records))
  (setq total (length records))
  (setq sheet-counts nil)
  (setq reason-counts nil)
  (foreach record records
    (setq frame-block (caddr record))
    (setq sheet (swcad-title-sheet-size-from-block-name frame-block))
    (setq reason (swcad-title-target-pair-upgrade-reason record))
    (setq sheet-counts (swcad-title-count-put (if sheet sheet frame-block) sheet-counts))
    (setq reason-counts (swcad-title-count-put reason reason-counts))
  )
  (swcad-title-princ-line (strcat "A3/A4 target pairs needing native replacement: " (itoa total)))
  (swcad-title-print-counts "A3/A4 fix candidates by sheet:" sheet-counts)
  (swcad-title-print-counts "A3/A4 fix candidates by reason:" reason-counts)
  (if records
    (progn
      (swcad-title-princ-line "Candidate detail:")
      (swcad-title-print-a3a4-native-upgrade-candidates)
      (if (> command-text-count 0)
        (progn
          (swcad-title-apply-result "REVIEW_ACCIDENTAL_COMMAND_TEXT_BEFORE_A3A4_UPGRADE")
          (swcad-title-princ-line "Next command before A3/A4 upgrade: SWTITLECOMMANDTEXTSCAN")
          (swcad-title-princ-line "After confirming/cleaning accidental command text, rerun SWTITLEA3A4FIXPLAN.")
        )
        (progn
          (swcad-title-apply-result "NEEDS_NATIVE_A3A4_UPGRADE")
          (swcad-title-princ-line "Next command: SWTITLEUPGRADENATIVEA3A4BATCH")
        )
      )
      (swcad-title-princ-line
        (strcat
          "SWTITLEUPGRADENATIVEA3A4BATCH defaults to all "
          (itoa total)
          " currently listed A3/A4 candidate(s). Pressing Enter in that command keeps this all-candidate default."
        )
      )
      (swcad-title-princ-line "Pressing Enter in SWTITLEUPGRADENATIVEA3A4BATCH processes every currently listed A3/A4 candidate.")
      (swcad-title-princ-line "If you want to process only one sheet first, use SWTITLEA3A4PREP, normal GMTITLE, then SWTITLEA3A4FINISH.")
      (swcad-title-princ-line "For the GMTITLE dialog: choose the printed DR_A*_Outline paper and DR_titlea_3rd.")
      (swcad-title-princ-line "Required dialog state: Frame positioning=ON, Object move=OFF.")
      (swcad-title-princ-line "Do not accept ISO defaults. Cancel and rerun if the dialog still shows ISO paper/title.")
    )
    (progn
      (if (> role-failures 0)
        (swcad-title-apply-result "FAIL_ROLE_CLASSIFICATION")
        (swcad-title-apply-result "OK_NO_A3A4_FIX_CANDIDATE")
      )
      (swcad-title-princ-line "No A3/A4 target pair is currently queued for native replacement.")
      (swcad-title-princ-line "If A3/A4 still opens GMPOWEREDIT, run SWTITLEPICKCHECK on the failing title block and compare the selected pair.")
      (swcad-title-princ-line "Then rerun SWTITLEUPGRADENATIVESTATUS to check whether the pair was loaded from stale LSP logic.")
    )
  )
  (swcad-title-princ-line "No drawing data was changed.")
  (swcad-title-close-log)
  (princ)
)

(defun swcad-title-print-target-gmtitle-pair-review (/ records total native-like-count clone-count untrusted-count record index title-ename frame-ename frame-block title-role frame-role pair-trusted clone-pair legacy-uncertain native-like sheet reason)
  (setq records (swcad-title-target-gmtitle-pair-records))
  (setq total (length records))
  (setq native-like-count 0)
  (setq clone-count 0)
  (setq untrusted-count 0)
  (swcad-title-princ-line (strcat "Target GMTITLE frame/title pairs: " (itoa total)))
  (if records
    (progn
      (setq index 1)
      (foreach record records
        (setq title-ename (car record))
        (setq frame-ename (cadr record))
        (setq frame-block (caddr record))
        (setq title-role (nth 5 record))
        (setq frame-role (nth 6 record))
        (setq pair-trusted (swcad-title-trusted-native-exemplar-pair-p title-ename frame-ename frame-block))
        (setq clone-pair
          (or
            (swcad-title-exemplar-clone-role-p title-role)
            (swcad-title-exemplar-clone-role-p frame-role)
          )
        )
        (setq legacy-uncertain
          (or
            (swcad-title-exemplar-legacy-uncertain-native-role-p title-role)
            (swcad-title-exemplar-legacy-uncertain-native-role-p frame-role)
          )
        )
        (setq native-like (swcad-title-target-pair-native-like-p record))
        (setq reason (swcad-title-target-pair-upgrade-reason record))
        (cond
          (native-like (setq native-like-count (+ native-like-count 1)))
          (clone-pair (setq clone-count (+ clone-count 1)))
          (T (setq untrusted-count (+ untrusted-count 1)))
        )
        (if (not native-like)
          (progn
            (setq sheet (swcad-title-sheet-size-from-block-name frame-block))
            (swcad-title-princ-line
              (strcat
                "  review #"
                (itoa index)
                " sheet="
                (if sheet sheet "<unknown>")
                ", title="
                (swcad-title-ename-handle title-ename)
                ", frame="
                (swcad-title-ename-handle frame-ename)
                ", block="
                frame-block
                ", swtitle-marker="
                (if pair-trusted "yes" "no")
                ", clone="
                (if clone-pair "yes" "no")
                ", finalize-recheck-marker="
                (if legacy-uncertain "yes" "no")
                ", title-role="
                (if (> (strlen title-role) 0) title-role "<none>")
                ", frame-role="
                (if (> (strlen frame-role) 0) frame-role "<none>")
                ", reason="
                reason
              )
            )
          )
        )
        (setq index (+ index 1))
      )
    )
  )
  (swcad-title-princ-line
    (strcat
      "Target pair review counts: native-like="
      (itoa native-like-count)
      ", clone="
      (itoa clone-count)
      ", untrusted/non-marker="
      (itoa untrusted-count)
    )
  )
  (list total native-like-count clone-count untrusted-count)
)

(defun swcad-title-print-native-upgrade-summary (/ records total counts record index)
  (setq records (swcad-title-cloned-gmtitle-pair-records))
  (setq total (length records))
  (setq counts (swcad-title-cloned-gmtitle-pair-counts))
  (swcad-title-princ-line (strcat "Cloned GMTITLE pairs needing native frame upgrade: " (itoa total)))
  (swcad-title-print-counts "Clone pairs by sheet size:" counts)
  (if records
    (progn
      (swcad-title-princ-line "Clone upgrade queue:")
      (setq index 1)
      (foreach record records
        (swcad-title-princ-line
          (strcat
            "  #"
            (itoa index)
            " title="
            (swcad-title-ename-handle (car record))
            ", frame="
            (swcad-title-ename-handle (cadr record))
            ", block="
            (caddr record)
            ", bbox="
            (swcad-title-bbox-string (nth 4 record))
          )
        )
        (setq index (+ index 1))
      )
    )
  )
  total
)

(defun swcad-title-upgrade-native-status (/ clone-total a3a4-total review total native-like clone untrusted source-titles source-frames frame-records target-sheet-counts missing-target-sheets selection-risk-count geometry-risk-count overlap-risk-count command-text-count)
  (swcad-title-open-native-upgrade-log)
  (swcad-title-princ-line "----- SWTITLEUPGRADENATIVESTATUS read-only native frame upgrade status -----")
  (swcad-title-print-loaded-version)
  (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (swcad-title-princ-line (strcat "CTAB: " (getvar "CTAB")))
  (swcad-title-print-work-copy-status)
  (setq source-titles (swcad-title-source-title-candidates))
  (setq source-frames (swcad-title-source-frame-candidates))
  (setq frame-records (swcad-title-frame-records))
  (setq target-sheet-counts (swcad-title-target-frame-sheet-counts))
  (setq missing-target-sheets (swcad-title-missing-required-target-sheets target-sheet-counts '("A2" "A3" "A4")))
  (swcad-title-princ-line (strcat "Remaining source title candidates: " (itoa (length source-titles))))
  (swcad-title-princ-line (strcat "Remaining source sheet frame candidates: " (itoa (length source-frames))))
  (swcad-title-print-counts "Visible target frame counts by sheet:" target-sheet-counts)
  (swcad-title-print-string-list "Missing required A2/A3/A4 target sheets:" missing-target-sheets)
  (setq geometry-risk-count (swcad-title-target-frame-geometry-warning-count frame-records))
  (setq overlap-risk-count (swcad-title-target-frame-overlap-warning-count frame-records))
  (setq selection-risk-count (swcad-title-print-target-frame-selection-diagnostics frame-records))
  (setq command-text-count (swcad-title-command-text-residue-count))
  (swcad-title-princ-line (strcat "Possible accidental command text entities: " (itoa command-text-count)))
  (setq clone-total (swcad-title-print-native-upgrade-summary))
  (setq a3a4-total (swcad-title-print-a3a4-native-upgrade-candidates))
  (setq review (swcad-title-print-target-gmtitle-pair-review))
  (setq total (car review))
  (setq native-like (cadr review))
  (setq clone (caddr review))
  (setq untrusted (nth 3 review))
  (cond
    ((> geometry-risk-count 0)
      (swcad-title-apply-result "WARN_TARGET_FRAME_GEOMETRY_INVALID")
      (swcad-title-princ-line "Reason: one or more target frame bbox values do not match the expected A-size geometry.")
      (swcad-title-princ-line "Next: do not treat this as final. Recreate the bad sheet size with a clean native GMTITLE definition before double-click checks.")
    )
    ((> selection-risk-count 0)
      (swcad-title-apply-result "WARN_TARGET_FRAME_SELECTION_RISK")
      (swcad-title-princ-line "Reason: one or more target frame selection bbox values are oversized or overlap another target frame.")
      (swcad-title-princ-line "Next: run SWTITLEFRAMEDEFCHECK. If invalid or oversized geometry is reported in a work copy, consider SWTITLEREPAIRFRAMEDEFS before continuing.")
    )
    ((and (> command-text-count 0) (> a3a4-total 0))
      (swcad-title-apply-result "REVIEW_ACCIDENTAL_COMMAND_TEXT_BEFORE_A3A4_UPGRADE")
      (swcad-title-princ-line "Reason: possible command text exists in the drawing while A3/A4 native replacement candidates are present.")
      (swcad-title-princ-line "Next: run SWTITLECOMMANDTEXTSCAN and review the listed TEXT/MTEXT handles before A3/A4 upgrades.")
      (swcad-title-princ-line "If they are accidental command leftovers in a work copy, run SWTITLECOMMANDTEXTCLEANSAFE, then rerun SWTITLEUPGRADENATIVESTATUS.")
      (swcad-title-princ-line (strcat "After that, run SWTITLEUPGRADENATIVEA3A4BATCH if the candidate count is still " (itoa a3a4-total) "."))
    )
    ((> a3a4-total 0)
      (swcad-title-apply-result "NEEDS_NATIVE_A3A4_UPGRADE")
      (swcad-title-princ-line "Reason: some A3/A4 GMTITLE pairs are still not trusted as fresh native GMTITLE pairs.")
      (swcad-title-princ-line "These pairs can have correct attributes and SWTITLE markers but still open GMPOWEREDIT/REFEDIT instead of the GMTITLE table editor.")
      (swcad-title-princ-line "Cause: clone, preserve-copy, native-finalize, and native-frame-only results can be visually correct, but GstarCAD's native double-click recognition is not guaranteed for every sheet.")
      (swcad-title-princ-line "Fix: replace each listed A3/A4 pair with one fresh native GMTITLE dialog result; the command copies values and deletes the old untrusted pair.")
      (if (or (> (length source-titles) 0) (> (length source-frames) 0))
        (progn
          (swcad-title-princ-line "Remaining source sheets are a separate follow-up after the listed clone/non-native pairs are reviewed.")
          (swcad-title-princ-line "This command does not create missing frame-only A4 target sheets; it only repairs native recognition of target pairs already created.")
          (swcad-title-princ-line "You can upgrade the listed A3/A4 target pairs now even if A4 frame-only source sheets still remain.")
        )
      )
      (swcad-title-princ-line "Next safest path: run SWTITLEA3A4PREP, create one normal GMTITLE with the printed values, then run SWTITLEA3A4FINISH.")
      (swcad-title-princ-line (strcat "Batch path: run SWTITLEUPGRADENATIVEA3A4BATCH and press Enter to process all " (itoa a3a4-total) " currently listed candidate(s)."))
      (swcad-title-princ-line "For every GMTITLE dialog: choose the printed DR_A*_Outline paper, choose DR_titlea_3rd, keep Frame positioning ON, turn Object move OFF, then OK.")
      (swcad-title-princ-line "Do not confirm ISO A3/A4 or ISO title defaults; cancel and rerun if the dialog is still on ISO values.")
      (swcad-title-princ-line "Use SWTITLEUPGRADENATIVESELECT if you want to pick a specific sheet yourself.")
      (if (or (> (length source-titles) 0) (> (length source-frames) 0))
        (swcad-title-princ-line "After that, rerun SWTITLEFASTSTATUS and handle remaining source sheets with SWTITLETRANSFERFASTBATCH or SWTITLEFRAMEONLYAPPLY.")
      )
    )
    ((or (> (length source-titles) 0) (> (length source-frames) 0))
      (swcad-title-apply-result "WAITING_FOR_TRANSFER_SOURCES_REMAIN")
      (swcad-title-princ-line "Reason: old SOLIDWORKS source title/frame candidates still remain.")
      (swcad-title-princ-line "Next: run SWTITLETRANSFERFASTBATCH if a same-size native exemplar exists, or SWTITLEFRAMEONLYAPPLY for the first remaining A4 frame-only sheet.")
    )
    (missing-target-sheets
      (swcad-title-apply-result "WARN_REQUIRED_A2_A3_A4_TARGET_SHEET_MISSING")
      (swcad-title-princ-line "Reason: at least one required A2/A3/A4 target GMTITLE frame is still missing.")
      (swcad-title-princ-line "Next: create/finalize the missing sheet size before final double-click checks.")
    )
    ((= total 0)
      (swcad-title-apply-result "OK_NO_TARGET_GMTITLE_PAIR")
    )
    ((= a3a4-total 0)
      (swcad-title-apply-result "OK_A3A4_NATIVE_UPGRADE_COMPLETE")
      (if (> untrusted 0)
        (swcad-title-princ-line "Note: remaining untrusted/non-marker pairs are outside the A3/A4 upgrade queue, usually the pre-existing A2 baseline.")
      )
      (swcad-title-princ-line "Next: run SWTITLENATIVEFRAMECHECK, then manually double-click one A3 and one A4 DR_titlea_3rd title block for final CAD behavior confirmation.")
    )
    ((> clone-total 0)
      (swcad-title-apply-result "NEEDS_NATIVE_FRAME_UPGRADE")
    )
    ((= native-like total)
      (swcad-title-apply-result "OK_NO_CLONED_GMTITLE_PAIR")
    )
    (T
      (swcad-title-apply-result "NEEDS_NATIVE_FRAME_REVIEW")
    )
  )
  (swcad-title-princ-line "No drawing data was changed.")
  (swcad-title-close-log)
  (princ)
)

(defun swcad-title-upgrade-native-one (/ *error* opened-log pair old-title old-frame frame-block target-sheet target-reason old-title-bbox old-frame-bbox old-title-role old-frame-role old-title-object values answer placement-point gmtitle-result new-title new-frame new-enames actual-title-name actual-frame-name geometry-warning doc align-result align-count align-dx align-dy align-needed new-title-object attr-count marker-role marker-ok deleted-new-count remaining-a3a4-count)
  (setq opened-log nil)
  (if (not *swcad-title-native-upgrade-batch-mode*)
    (progn
      (swcad-title-open-native-upgrade-log)
      (setq opened-log T)
    )
  )
  (defun *error* (msg)
    (if msg
      (swcad-title-princ-line (strcat "Error: " (swcad-title-string msg)))
    )
    (setq *swcad-title-native-upgrade-selected-pair* nil)
    (swcad-title-apply-result "ERROR_NATIVE_UPGRADE")
    (if opened-log
      (swcad-title-close-log)
    )
    (princ)
  )
  (setq *swcad-title-last-apply-status* nil)
  (setq pair
    (if *swcad-title-native-upgrade-selected-pair*
      *swcad-title-native-upgrade-selected-pair*
      (or
        (car (swcad-title-a3a4-native-upgrade-candidate-records))
        (swcad-title-first-cloned-gmtitle-pair-record)
      )
    )
  )
  (setq *swcad-title-native-upgrade-selected-pair* nil)
  (setq old-title (if pair (car pair) nil))
  (setq old-frame (if pair (cadr pair) nil))
  (setq frame-block (if pair (caddr pair) nil))
  (setq target-sheet (if frame-block (swcad-title-sheet-size-from-block-name frame-block) nil))
  (setq target-reason (if pair (swcad-title-target-pair-upgrade-reason pair) ""))
  (setq old-title-bbox (if pair (cadddr pair) nil))
  (setq old-frame-bbox (if pair (nth 4 pair) nil))
  (setq old-title-role (if pair (nth 5 pair) ""))
  (setq old-frame-role (if pair (nth 6 pair) ""))
  (setq old-title-object (swcad-title-safe-vla-object old-title))
  (setq values (if old-title-object (swcad-title-title-attribute-pairs old-title-object) nil))
  (setq placement-point (swcad-title-bbox-lower-left-point old-frame-bbox))
  (swcad-title-princ-line "----- SWTITLEUPGRADENATIVEONE existing-to-native frame upgrade -----")
  (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (swcad-title-princ-line (strcat "CTAB: " (getvar "CTAB")))
  (swcad-title-print-work-copy-status)
  (cond
    ((not pair)
      (swcad-title-apply-result "STOP_NO_NATIVE_UPGRADE_CANDIDATE")
      (swcad-title-princ-line "No A3/A4 native-recheck or cloned GMTITLE pair was found.")
      (swcad-title-princ-line "If frames still feel wrong, run SWTITLEUPGRADENATIVESTATUS, SWTITLEGMTITLEVERIFYALL, and SWTITLEGMTITLECOMPARE for diagnostics.")
    )
    ((swcad-title-document-read-only-p)
      (swcad-title-apply-result "ABORT_READ_ONLY_DOCUMENT")
      (swcad-title-princ-line "Open a writable copy of the DWG before upgrading.")
    )
    ((not (swcad-title-apply-work-copy-confirmed-p))
      (swcad-title-apply-result "ABORT_NOT_WORK_COPY")
      (swcad-title-princ-line "Open or create a copy under Documents/CAD tool/work before upgrading.")
    )
    (T
      (swcad-title-princ-line
        (strcat
          "Upgrade target: sheet="
          (if target-sheet target-sheet "<unknown>")
          ", expected-frame="
          frame-block
          ", expected-title="
          (swcad-title-target-title-block-name)
          ", reason="
          target-reason
        )
      )
      (swcad-title-princ-line
        (strcat
          "Existing GMTITLE title to replace: handle="
          (swcad-title-ename-handle old-title)
          ", role="
          (if (> (strlen old-title-role) 0) old-title-role "<none>")
          ", bbox="
          (swcad-title-bbox-string old-title-bbox)
        )
      )
      (swcad-title-princ-line
        (strcat
          "Existing GMTITLE frame to replace: handle="
          (swcad-title-ename-handle old-frame)
          ", block="
          frame-block
          ", role="
          (if (> (strlen old-frame-role) 0) old-frame-role "<none>")
          ", bbox="
          (swcad-title-bbox-string old-frame-bbox)
        )
      )
      (swcad-title-princ-line (strcat "Attributes to copy: " (itoa (length values))))
      (if
        (or
          *swcad-title-native-upgrade-batch-mode*
          *swcad-title-skip-native-upgrade-confirmation*
        )
        (setq answer "YES")
        (setq answer
          (getstring
            T
            "\nType YES to create one fresh native GMTITLE here, copy values, and delete this existing pair: "
          )
        )
      )
      (if (/= (strcase answer) "YES")
        (swcad-title-apply-result "ABORT_NATIVE_UPGRADE_USER")
        (progn
          (setq gmtitle-result (swcad-title-run-native-gmtitle-prefer-commandline frame-block placement-point))
          (setq new-title (car gmtitle-result))
          (setq new-frame (cadr gmtitle-result))
          (setq new-enames (caddr gmtitle-result))
          (setq actual-title-name (if new-title (swcad-title-effective-insert-name new-title) ""))
          (setq actual-frame-name (if new-frame (swcad-title-effective-insert-name new-frame) ""))
          (setq geometry-warning
            (if new-frame
              (swcad-title-frame-bbox-size-warning-for-block
                frame-block
                (swcad-title-frame-reference-effective-bbox new-frame frame-block)
              )
              nil
            )
          )
          (if
            (and
              new-title
              new-frame
              (swcad-title-native-target-title-name-p actual-title-name)
              (swcad-title-frame-name-matches-p actual-frame-name frame-block)
              (not geometry-warning)
            )
            (progn
              (setq doc (swcad-title-doc))
              (vl-catch-all-apply 'vla-StartUndoMark (list doc))
              (setq align-result (swcad-title-align-gmtitle-to-frame-bbox new-title new-frame old-frame-bbox))
              (setq align-count (car align-result))
              (setq align-dx (cadr align-result))
              (setq align-dy (caddr align-result))
              (setq align-needed (or (> (swcad-title-abs align-dx) 0.0001) (> (swcad-title-abs align-dy) 0.0001)))
              (if (and align-needed (< align-count 2))
                (progn
                  (vl-catch-all-apply 'vla-EndUndoMark (list doc))
                  (setq deleted-new-count (swcad-title-delete-ename-list new-enames))
                  (swcad-title-apply-result "ABORT_NATIVE_UPGRADE_ALIGN_FAILED")
                  (swcad-title-princ-line
                    (strcat
                      "New native GMTITLE alignment failed: moved="
                      (itoa align-count)
                      ", dx="
                      (swcad-title-number-string align-dx)
                      ", dy="
                      (swcad-title-number-string align-dy)
                    )
                  )
                  (swcad-title-princ-line (strcat "Removed new GMTITLE inserts: " (itoa deleted-new-count)))
                  (swcad-title-princ-line "The existing GMTITLE pair was kept.")
                )
                (if (and align-needed (not *swcad-title-last-native-gmtitle-placement-used*))
                  (progn
                    (vl-catch-all-apply 'vla-EndUndoMark (list doc))
                    (setq deleted-new-count (swcad-title-delete-ename-list new-enames))
                    (swcad-title-apply-result "ABORT_NATIVE_UPGRADE_REQUIRES_NATIVE_PLACEMENT")
                    (swcad-title-princ-line "Native GMTITLE was created at a default location and then needed LISP MOVE alignment.")
                    (swcad-title-princ-line "That pattern is not trusted because GMPOWEREDIT can still fail after visual alignment.")
                    (swcad-title-princ-line (strcat "Removed untrusted new GMTITLE inserts: " (itoa deleted-new-count)))
                    (swcad-title-princ-line "The existing GMTITLE pair was kept.")
                    (swcad-title-princ-line "Next: rerun the command and let GMTITLE accept the lower-left placement point, with Object move OFF.")
                  )
                  (progn
                    (setq new-title-object (swcad-title-safe-vla-object new-title))
                    (setq attr-count (swcad-title-set-insert-attributes new-title-object values))
                    (swcad-title-delete-ename old-title)
                    (swcad-title-delete-ename old-frame)
                    (setq marker-role "native-upgrade")
                    (setq marker-ok
                      (swcad-title-mark-native-exemplar-pair
                        new-title
                        new-frame
                        frame-block
                        marker-role
                      )
                    )
                    (vl-catch-all-apply 'vla-EndUndoMark (list doc))
                    (setq remaining-a3a4-count (length (swcad-title-a3a4-native-upgrade-candidate-records)))
                    (swcad-title-princ-line
                      (strcat
                        "Native GMTITLE aligned to cloned frame location: moved="
                        (itoa align-count)
                        ", dx="
                        (swcad-title-number-string align-dx)
                        ", dy="
                        (swcad-title-number-string align-dy)
                      )
                    )
                    (swcad-title-princ-line (strcat "Attributes copied: " (itoa attr-count)))
                    (swcad-title-princ-line (strcat "Native upgrade marker set: " (if marker-ok "yes" "no") ", role=" marker-role))
                    (swcad-title-princ-line "Old cloned title deleted: yes")
                    (swcad-title-princ-line "Old cloned frame deleted: yes")
                    (swcad-title-princ-line (strcat "Remaining A3/A4 native upgrade candidates: " (itoa remaining-a3a4-count)))
                    (swcad-title-apply-result "UPGRADED_CLONE_TO_NATIVE_GMTITLE")
                    (swcad-title-princ-line "Manual check: double-click the upgraded title block and confirm the GMTITLE table editor opens.")
                    (if (> remaining-a3a4-count 0)
                      (swcad-title-princ-line "If this sheet works, run SWTITLEA3A4PREP again for the next A3/A4 candidate.")
                      (swcad-title-princ-line "All A3/A4 upgrade candidates are cleared; run SWTITLEGMTITLEVERIFYALL and SWTITLENATIVEFRAMECHECK.")
                    )
                  )
                )
              )
            )
            (progn
              (setq deleted-new-count (swcad-title-delete-ename-list new-enames))
              (cond
                (geometry-warning
                  (swcad-title-apply-result "ABORT_NATIVE_UPGRADE_INVALID_FRAME_GEOMETRY")
                )
                ((= (length new-enames) 0)
                  (swcad-title-apply-result "ABORT_NATIVE_UPGRADE_GMTITLE_NO_INSERTS")
                )
                (T
                  (swcad-title-apply-result "ABORT_NATIVE_UPGRADE_WRONG_GMTITLE_SELECTION")
                )
              )
              (swcad-title-princ-line (strcat "Expected frame block: " frame-block))
              (swcad-title-princ-line (strcat "Expected title block: " (swcad-title-target-title-block-name)))
              (swcad-title-princ-line (strcat "Actual title block: " (if (> (strlen actual-title-name) 0) actual-title-name "<missing>")))
              (swcad-title-princ-line (strcat "Actual frame block: " (if (> (strlen actual-frame-name) 0) actual-frame-name "<missing>")))
              (if *swcad-title-last-native-gmtitle-abort-reason*
                (swcad-title-princ-line
                  (strcat
                    "Native GMTITLE abort reason: "
                    *swcad-title-last-native-gmtitle-abort-reason*
                  )
                )
              )
              (if geometry-warning
                (swcad-title-princ-line (strcat "Frame geometry warning: " geometry-warning))
              )
              (swcad-title-princ-line (strcat "Removed wrong/new GMTITLE inserts: " (itoa deleted-new-count)))
              (swcad-title-princ-line "The existing GMTITLE pair was kept.")
              (cond
                (geometry-warning
                  (swcad-title-princ-line "Next: recreate this sheet with the expected DR paper size before retrying the A3/A4 native upgrade.")
                )
                ((= (length new-enames) 0)
                  (swcad-title-princ-line "Next: rerun the command and complete the GMTITLE dialog; canceling the dialog leaves the old pair unchanged.")
                )
                (T
                  (swcad-title-princ-line "Next: rerun and choose the printed DR_A*_Outline paper plus DR_titlea_3rd; do not accept ISO defaults.")
                )
              )
            )
          )
        )
      )
    )
  )
  (if opened-log
    (swcad-title-close-log)
  )
  (princ)
)

(defun swcad-title-pending-manual-native-value (key)
  (cdr (assoc key *swcad-title-pending-manual-native-upgrade*))
)

(defun swcad-title-upgrade-native-a3a4-prepare (/ pair old-title old-frame frame-block target-sheet target-reason old-frame-bbox old-title-object values before-handles placement-point)
  (swcad-title-open-native-upgrade-log)
  (setq pair (car (swcad-title-a3a4-native-upgrade-candidate-records)))
  (setq old-title (if pair (car pair) nil))
  (setq old-frame (if pair (cadr pair) nil))
  (setq frame-block (if pair (caddr pair) nil))
  (setq target-sheet (if frame-block (swcad-title-sheet-size-from-block-name frame-block) nil))
  (setq target-reason (if pair (swcad-title-target-pair-upgrade-reason pair) ""))
  (setq old-frame-bbox (if pair (nth 4 pair) nil))
  (setq old-title-object (swcad-title-safe-vla-object old-title))
  (setq values (if old-title-object (swcad-title-title-attribute-pairs old-title-object) nil))
  (setq before-handles (swcad-title-insert-handle-list))
  (setq placement-point (swcad-title-bbox-lower-left-point old-frame-bbox))
  (swcad-title-princ-line "----- SWTITLEA3A4PREP manual native GMTITLE prepare -----")
  (swcad-title-print-loaded-version)
  (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (swcad-title-princ-line (strcat "CTAB: " (getvar "CTAB")))
  (swcad-title-print-work-copy-status)
  (cond
    ((not pair)
      (setq *swcad-title-pending-manual-native-upgrade* nil)
      (swcad-title-apply-result "STOP_NO_A3A4_NATIVE_UPGRADE_CANDIDATE")
      (swcad-title-princ-line "No A3/A4 target pair currently needs native replacement.")
      (swcad-title-princ-line "Run SWTITLEUPGRADENATIVESTATUS to confirm the current state.")
    )
    ((swcad-title-document-read-only-p)
      (setq *swcad-title-pending-manual-native-upgrade* nil)
      (swcad-title-apply-result "ABORT_READ_ONLY_DOCUMENT")
      (swcad-title-princ-line "Open a writable work copy before preparing a manual native GMTITLE replacement.")
    )
    ((not (swcad-title-current-dwg-in-work-p))
      (setq *swcad-title-pending-manual-native-upgrade* nil)
      (swcad-title-apply-result "ABORT_NOT_WORK_COPY")
      (swcad-title-princ-line "Manual native replacement is limited to Documents/CAD tool/work copies.")
    )
    ((not placement-point)
      (setq *swcad-title-pending-manual-native-upgrade* nil)
      (swcad-title-apply-result "ABORT_NO_TARGET_FRAME_PLACEMENT_POINT")
      (swcad-title-princ-line "The target frame bbox did not provide a lower-left placement point.")
    )
    (T
      (setq *swcad-title-pending-manual-native-upgrade*
        (list
          (cons "old-title-handle" (swcad-title-ename-handle old-title))
          (cons "old-frame-handle" (swcad-title-ename-handle old-frame))
          (cons "frame-block" frame-block)
          (cons "target-sheet" target-sheet)
          (cons "target-reason" target-reason)
          (cons "old-frame-bbox" old-frame-bbox)
          (cons "values" values)
          (cons "before-handles" before-handles)
          (cons "placement-point" placement-point)
        )
      )
      (swcad-title-princ-line
        (strcat
          "Prepared target: sheet="
          (if target-sheet target-sheet "<unknown>")
          ", frame="
          frame-block
          ", title="
          (swcad-title-ename-handle old-title)
          ", reason="
          target-reason
        )
      )
      (swcad-title-princ-line (strcat "Existing frame handle: " (swcad-title-ename-handle old-frame)))
      (swcad-title-princ-line (strcat "Existing frame bbox: " (swcad-title-bbox-string old-frame-bbox)))
      (swcad-title-princ-line (strcat "Attributes saved for copy: " (itoa (length values))))
      (swcad-title-princ-line (strcat "GMTITLE paper/format to choose: " frame-block))
      (swcad-title-princ-line (strcat "GMTITLE title block to choose: " (swcad-title-target-title-block-name)))
      (swcad-title-princ-line "GMTITLE options: Frame positioning ON, Object move OFF.")
      (swcad-title-princ-line (strcat "When GMTITLE asks for the insertion point, type: " (swcad-title-point-string placement-point)))
      (swcad-title-princ-line "After the native GMTITLE is visibly created, run SWTITLEA3A4FINISH.")
      (swcad-title-princ-line "Codex automation note: do not paste the coordinate into the CAD prompt; send it as keystrokes or type it manually.")
      (swcad-title-apply-result "READY_MANUAL_NATIVE_GMTITLE_CREATE")
    )
  )
  (swcad-title-close-log)
  (princ)
)

(defun swcad-title-upgrade-native-a3a4-finish (/ old-title-handle old-frame-handle old-title old-frame frame-block target-sheet target-reason old-frame-bbox values before-handles new-enames new-title new-frame actual-title-name actual-frame-name geometry-warning doc align-result align-count align-dx align-dy align-needed new-title-object attr-count marker-ok deleted-new-count remaining-a3a4-count)
  (swcad-title-open-native-upgrade-log)
  (setq old-title-handle (swcad-title-pending-manual-native-value "old-title-handle"))
  (setq old-frame-handle (swcad-title-pending-manual-native-value "old-frame-handle"))
  (setq old-title (if old-title-handle (handent old-title-handle) nil))
  (setq old-frame (if old-frame-handle (handent old-frame-handle) nil))
  (setq frame-block (swcad-title-pending-manual-native-value "frame-block"))
  (setq target-sheet (swcad-title-pending-manual-native-value "target-sheet"))
  (setq target-reason (swcad-title-pending-manual-native-value "target-reason"))
  (setq old-frame-bbox (swcad-title-pending-manual-native-value "old-frame-bbox"))
  (setq values (swcad-title-pending-manual-native-value "values"))
  (setq before-handles (swcad-title-pending-manual-native-value "before-handles"))
  (swcad-title-princ-line "----- SWTITLEA3A4FINISH manual native GMTITLE finish -----")
  (swcad-title-print-loaded-version)
  (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (swcad-title-princ-line (strcat "CTAB: " (getvar "CTAB")))
  (swcad-title-print-work-copy-status)
  (cond
    ((not *swcad-title-pending-manual-native-upgrade*)
      (swcad-title-apply-result "ABORT_NO_MANUAL_NATIVE_GMTITLE_PENDING")
      (swcad-title-princ-line "Run SWTITLEA3A4PREP first, then create one native GMTITLE with the printed values.")
    )
    ((or (not old-title) (not old-frame))
      (setq *swcad-title-pending-manual-native-upgrade* nil)
      (swcad-title-apply-result "ABORT_PENDING_TARGET_PAIR_MISSING")
      (swcad-title-princ-line "The pending old target pair no longer exists. Run SWTITLEUPGRADENATIVESTATUS and prepare again.")
    )
    ((not (swcad-title-current-dwg-in-work-p))
      (swcad-title-apply-result "ABORT_NOT_WORK_COPY")
      (swcad-title-princ-line "Manual native finish is limited to Documents/CAD tool/work copies.")
    )
    (T
      (setq new-enames (swcad-title-new-insert-enames before-handles))
      (setq new-title (swcad-title-select-new-gmtitle-title new-enames))
      (setq new-frame (swcad-title-select-new-gmtitle-frame new-enames new-title frame-block))
      (setq actual-title-name (if new-title (swcad-title-effective-insert-name new-title) ""))
      (setq actual-frame-name (if new-frame (swcad-title-effective-insert-name new-frame) ""))
      (setq geometry-warning
        (if new-frame
          (swcad-title-frame-bbox-size-warning-for-block
            frame-block
            (swcad-title-frame-reference-effective-bbox new-frame frame-block)
          )
          nil
        )
      )
      (swcad-title-princ-line
        (strcat
          "Pending target: sheet="
          (if target-sheet target-sheet "<unknown>")
          ", frame="
          frame-block
          ", reason="
          (swcad-title-string target-reason)
        )
      )
      (swcad-title-princ-line (strcat "New INSERTs since prepare: " (itoa (length new-enames))))
      (swcad-title-insert-log-label "New native GMTITLE title candidate" new-title)
      (swcad-title-insert-log-label "New native GMTITLE frame candidate" new-frame)
      (if
        (and
          new-title
          new-frame
          (swcad-title-native-target-title-name-p actual-title-name)
          (swcad-title-frame-name-matches-p actual-frame-name frame-block)
          (not geometry-warning)
        )
        (progn
          (setq doc (swcad-title-doc))
          (vl-catch-all-apply 'vla-StartUndoMark (list doc))
          (setq align-result (swcad-title-align-gmtitle-to-frame-bbox new-title new-frame old-frame-bbox))
          (setq align-count (car align-result))
          (setq align-dx (cadr align-result))
          (setq align-dy (caddr align-result))
          (setq align-needed (or (> (swcad-title-abs align-dx) 0.0001) (> (swcad-title-abs align-dy) 0.0001)))
          (if align-needed
            (progn
              (vl-catch-all-apply 'vla-EndUndoMark (list doc))
              (setq deleted-new-count (swcad-title-delete-ename-list new-enames))
              (swcad-title-apply-result "ABORT_MANUAL_NATIVE_GMTITLE_WRONG_LOCATION")
              (swcad-title-princ-line "The new GMTITLE was not created at the pending frame lower-left point.")
              (swcad-title-princ-line
                (strcat
                  "Alignment would have moved "
                  (itoa align-count)
                  " object(s), dx="
                  (swcad-title-number-string align-dx)
                  ", dy="
                  (swcad-title-number-string align-dy)
                )
              )
              (swcad-title-princ-line (strcat "Removed new GMTITLE inserts: " (itoa deleted-new-count)))
              (swcad-title-princ-line "Run SWTITLEA3A4PREP again and create the GMTITLE at the printed insertion point.")
            )
            (progn
              (setq new-title-object (swcad-title-safe-vla-object new-title))
              (setq attr-count (swcad-title-set-insert-attributes new-title-object values))
              (swcad-title-delete-ename old-title)
              (swcad-title-delete-ename old-frame)
              (setq marker-ok
                (swcad-title-mark-native-exemplar-pair
                  new-title
                  new-frame
                  frame-block
                  "native-upgrade"
                )
              )
              (vl-catch-all-apply 'vla-EndUndoMark (list doc))
              (setq *swcad-title-pending-manual-native-upgrade* nil)
              (setq remaining-a3a4-count (length (swcad-title-a3a4-native-upgrade-candidate-records)))
              (swcad-title-princ-line (strcat "Attributes copied: " (itoa attr-count)))
              (swcad-title-princ-line (strcat "Native upgrade marker set: " (if marker-ok "yes" "no") ", role=native-upgrade"))
              (swcad-title-princ-line "Old cloned/untrusted title deleted: yes")
              (swcad-title-princ-line "Old cloned/untrusted frame deleted: yes")
              (swcad-title-princ-line (strcat "Remaining A3/A4 native upgrade candidates: " (itoa remaining-a3a4-count)))
              (swcad-title-apply-result "FINISHED_MANUAL_NATIVE_GMTITLE_UPGRADE")
              (if (> remaining-a3a4-count 0)
                (swcad-title-princ-line "Next: run SWTITLEA3A4PREP for the next candidate.")
                (swcad-title-princ-line "All A3/A4 native upgrade candidates are cleared; run SWTITLEGMTITLEVERIFYALL and SWTITLENATIVEFRAMECHECK.")
              )
            )
          )
        )
        (progn
          (setq deleted-new-count 0)
          (if (> (length new-enames) 0)
            (setq deleted-new-count (swcad-title-delete-ename-list new-enames))
          )
          (cond
            (geometry-warning
              (swcad-title-apply-result "ABORT_MANUAL_NATIVE_GMTITLE_INVALID_FRAME_GEOMETRY")
            )
            ((= (length new-enames) 0)
              (swcad-title-apply-result "ABORT_MANUAL_NATIVE_GMTITLE_NOT_CREATED")
            )
            (T
              (swcad-title-apply-result "ABORT_MANUAL_NATIVE_GMTITLE_WRONG_SELECTION")
            )
          )
          (swcad-title-princ-line (strcat "Expected frame block: " frame-block))
          (swcad-title-princ-line (strcat "Expected title block: " (swcad-title-target-title-block-name)))
          (swcad-title-princ-line (strcat "Actual title block: " (if (> (strlen actual-title-name) 0) actual-title-name "<missing>")))
          (swcad-title-princ-line (strcat "Actual frame block: " (if (> (strlen actual-frame-name) 0) actual-frame-name "<missing>")))
          (if geometry-warning
            (swcad-title-princ-line (strcat "Frame geometry warning: " geometry-warning))
          )
          (swcad-title-princ-line (strcat "Removed wrong/new GMTITLE inserts: " (itoa deleted-new-count)))
          (swcad-title-princ-line "The pending old target pair was kept. Run SWTITLEA3A4PREP and create the GMTITLE again.")
        )
      )
    )
  )
  (swcad-title-close-log)
  (princ)
)

(defun swcad-title-upgrade-native-select (/ picked ename pick-point wcs-point insert-ename pair)
  (swcad-title-princ-line "Select a cloned or target GMTITLE frame/title to upgrade to real native GMTITLE.")
  (setq picked (entsel "\nSelect GMTITLE frame/title to upgrade: "))
  (setq ename (if picked (car picked) nil))
  (setq pick-point (if picked (cadr picked) nil))
  (setq wcs-point (swcad-title-safe-trans-point pick-point 1 0))
  (setq insert-ename (swcad-title-enclosing-insert-ename ename))
  (setq pair (if ename (swcad-title-cloned-gmtitle-pair-record-for-ename ename) nil))
  (if (not pair)
    (setq pair (swcad-title-cloned-gmtitle-pair-record-for-point pick-point))
  )
  (if (and (not pair) wcs-point)
    (setq pair (swcad-title-cloned-gmtitle-pair-record-for-point wcs-point))
  )
  (if (not pair)
    (setq pair (if ename (swcad-title-target-gmtitle-pair-record-for-ename ename) nil))
  )
  (if (not pair)
    (setq pair (swcad-title-target-gmtitle-pair-record-for-point pick-point))
  )
  (if (and (not pair) wcs-point)
    (setq pair (swcad-title-target-gmtitle-pair-record-for-point wcs-point))
  )
  (if pair
    (progn
      (setq *swcad-title-native-upgrade-selected-pair* pair)
      (swcad-title-upgrade-native-one)
    )
    (progn
      (swcad-title-open-native-upgrade-log)
      (swcad-title-princ-line "----- SWTITLEUPGRADENATIVESELECT selected target upgrade -----")
      (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
      (swcad-title-princ-line (strcat "CTAB: " (getvar "CTAB")))
      (if ename
        (swcad-title-princ-line
          (strcat
            "Selected entity handle: "
            (swcad-title-ename-handle ename)
            ", type="
            (swcad-title-entity-type-name ename)
          )
        )
        (swcad-title-princ-line "Selected entity: <none>")
      )
      (swcad-title-princ-line
        (strcat
          "Selected point: "
          (if pick-point (swcad-title-point-string pick-point) "<none>")
        )
      )
      (swcad-title-princ-line
        (strcat
          "Selected point WCS: "
          (if wcs-point (swcad-title-point-string wcs-point) "<none>")
        )
      )
      (if insert-ename
        (swcad-title-princ-line
          (strcat
            "Enclosing insert: handle="
            (swcad-title-ename-handle insert-ename)
            ", block="
            (swcad-title-effective-insert-name insert-ename)
          )
        )
        (swcad-title-princ-line "Enclosing insert: <none>")
      )
      (swcad-title-apply-result "ABORT_SELECTED_ENTITY_IS_NOT_TARGET_GMTITLE_PAIR")
      (swcad-title-princ-line "No drawing data was changed.")
      (swcad-title-close-log)
    )
  )
  (princ)
)

(defun swcad-title-upgrade-native-a3a4-next (/ records pair frame-block sheet reason old-skip result)
  (setq records (swcad-title-a3a4-native-upgrade-candidate-records))
  (setq pair (if records (car records) nil))
  (if pair
    (progn
      (setq frame-block (caddr pair))
      (setq sheet (swcad-title-sheet-size-from-block-name frame-block))
      (setq reason (swcad-title-target-pair-upgrade-reason pair))
      (swcad-title-princ-line
        (strcat
          "Next A3/A4 native upgrade candidate: sheet="
          (if sheet sheet "<unknown>")
          ", title="
          (swcad-title-ename-handle (car pair))
          ", frame="
          (swcad-title-ename-handle (cadr pair))
          ", block="
          frame-block
          ", reason="
          reason
        )
      )
      (swcad-title-princ-line "This command upgrades only one sheet and skips the extra YES prompt.")
      (swcad-title-princ-line "When the GMTITLE dialog opens, do not accept the ISO defaults.")
      (swcad-title-princ-line
        (strcat
          "Dialog selection required: paper="
          frame-block
          ", title="
          (swcad-title-target-title-block-name)
          ", Frame positioning=ON, Object move=OFF."
        )
      )
  (swcad-title-princ-line "After SWTITLEA3A4FINISH succeeds, rerun SWTITLEUPGRADENATIVESTATUS; repeat until A3/A4 target pairs needing native replacement is 0.")
      (setq *swcad-title-native-upgrade-selected-pair* pair)
      (setq old-skip *swcad-title-skip-native-upgrade-confirmation*)
      (setq *swcad-title-skip-native-upgrade-confirmation* T)
      (setq result (vl-catch-all-apply 'swcad-title-upgrade-native-one nil))
      (setq *swcad-title-skip-native-upgrade-confirmation* old-skip)
      (if (vl-catch-all-error-p result)
        (progn
          (swcad-title-princ-line
            (strcat
              "SWTITLEUPGRADENATIVEA3A4NEXT error: "
              (vl-catch-all-error-message result)
            )
          )
          (princ)
        )
      )
    )
    (progn
      (swcad-title-open-native-upgrade-log)
      (swcad-title-princ-line "----- SWTITLEUPGRADENATIVEA3A4NEXT guided one-sheet upgrade -----")
      (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
      (swcad-title-princ-line (strcat "CTAB: " (getvar "CTAB")))
      (swcad-title-print-work-copy-status)
      (swcad-title-apply-result "STOP_NO_A3A4_NATIVE_UPGRADE_CANDIDATE")
      (swcad-title-princ-line "No A3/A4 target pair currently needs native replacement.")
      (swcad-title-princ-line "Next: run SWTITLEGMTITLEVERIFYALL and SWTITLENATIVEFRAMECHECK, then do the manual double-click checks.")
      (swcad-title-princ-line "No drawing data was changed.")
      (swcad-title-close-log)
    )
  )
  (princ)
)

(defun swcad-title-upgrade-native-batch (/ *error* records total count index result old-batch-mode remaining)
  (defun *error* (msg)
    (setq *swcad-title-native-upgrade-batch-mode* old-batch-mode)
    (if msg
      (swcad-title-princ-line (strcat "SWTITLEUPGRADENATIVEBATCH error: " (swcad-title-string msg)))
    )
    (swcad-title-apply-result "ERROR_NATIVE_UPGRADE_BATCH")
    (swcad-title-close-log)
    (princ)
  )
  (setq old-batch-mode *swcad-title-native-upgrade-batch-mode*)
  (swcad-title-open-native-upgrade-log)
  (setq records (swcad-title-cloned-gmtitle-pair-records))
  (setq total (length records))
  (swcad-title-princ-line "----- SWTITLEUPGRADENATIVEBATCH clone-to-native frame upgrade batch -----")
  (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (swcad-title-princ-line (strcat "CTAB: " (getvar "CTAB")))
  (swcad-title-print-work-copy-status)
  (swcad-title-print-native-upgrade-summary)
  (cond
    ((= total 0)
      (swcad-title-apply-result "STOP_NO_CLONED_GMTITLE_PAIR")
    )
    ((swcad-title-document-read-only-p)
      (swcad-title-apply-result "ABORT_READ_ONLY_DOCUMENT")
      (swcad-title-princ-line "Open a writable copy of the DWG before upgrading.")
    )
    ((not (swcad-title-current-dwg-in-work-p))
      (swcad-title-apply-result "ABORT_NOT_WORK_COPY")
      (swcad-title-princ-line "Batch native upgrade is limited to Documents/CAD tool/work copies.")
      (swcad-title-princ-line "Use SWTITLEUPGRADENATIVEONE with EDIT confirmation if you intentionally want to test outside work.")
    )
    (T
      (setq count
        (getint
          (strcat
            "\nNumber of cloned GMTITLE pairs to upgrade with real native GMTITLE <"
            (itoa total)
            ">: "
          )
        )
      )
      (if (not count)
        (setq count total)
      )
      (if (> count total)
        (setq count total)
      )
      (if (<= count 0)
        (swcad-title-apply-result "ABORT_NATIVE_UPGRADE_BATCH_USER")
        (progn
          (setq *swcad-title-native-upgrade-batch-mode* T)
          (setq index 1)
          (while (<= index count)
            (if (= (swcad-title-cloned-gmtitle-pair-total) 0)
              (setq index (+ count 1))
              (progn
                (swcad-title-princ-line
                  (strcat
                    "--- SWTITLEUPGRADENATIVEBATCH sheet "
                    (itoa index)
                    " / "
                    (itoa count)
                    " ---"
                  )
                )
                (setq result (vl-catch-all-apply 'swcad-title-upgrade-native-one nil))
                (if (vl-catch-all-error-p result)
                  (progn
                    (setq *swcad-title-last-apply-status* "ERROR_NATIVE_UPGRADE_BATCH_APPLY")
                    (swcad-title-princ-line
                      (strcat
                        "Native upgrade batch apply error: "
                        (vl-catch-all-error-message result)
                      )
                    )
                    (setq index (+ count 1))
                  )
                )
                (if (/= *swcad-title-last-apply-status* "UPGRADED_CLONE_TO_NATIVE_GMTITLE")
                  (progn
                    (swcad-title-princ-line
                      (strcat
                        "Native upgrade batch stopped after status: "
                        (swcad-title-string *swcad-title-last-apply-status*)
                      )
                    )
                    (setq index (+ count 1))
                  )
                )
              )
            )
            (setq index (+ index 1))
          )
          (setq *swcad-title-native-upgrade-batch-mode* old-batch-mode)
          (setq remaining (swcad-title-cloned-gmtitle-pair-total))
          (swcad-title-princ-line (strcat "Remaining cloned GMTITLE pairs after batch: " (itoa remaining)))
          (if (= remaining 0)
            (swcad-title-apply-result "OK_NATIVE_UPGRADE_BATCH_COMPLETE")
            (if (equal *swcad-title-last-apply-status* "UPGRADED_CLONE_TO_NATIVE_GMTITLE")
              (swcad-title-apply-result "WARN_NATIVE_UPGRADE_BATCH_REMAINING_CLONES")
            )
          )
          (swcad-title-princ-line "Next: run SWTITLEGMTITLEVERIFYALL, then manually double-click representative A2/A3/A4 DR_titlea_3rd title blocks.")
        )
      )
    )
  )
  (setq *swcad-title-native-upgrade-batch-mode* old-batch-mode)
  (swcad-title-close-log)
  (princ)
)

(defun swcad-title-upgrade-native-a3a4-batch (/ *error* records total count default-count index result old-batch-mode old-allow-interactive remaining summary source-count frame-only-count missing-required command-text-count)
  (defun *error* (msg)
    (setq *swcad-title-native-upgrade-batch-mode* old-batch-mode)
    (setq *swcad-title-allow-batch-interactive-native-gmtitle* old-allow-interactive)
    (setq *swcad-title-native-upgrade-selected-pair* nil)
    (if msg
      (swcad-title-princ-line (strcat "SWTITLEUPGRADENATIVEA3A4BATCH error: " (swcad-title-string msg)))
    )
    (swcad-title-apply-result "ERROR_NATIVE_A3A4_UPGRADE_BATCH")
    (swcad-title-close-log)
    (princ)
  )
  (setq old-batch-mode *swcad-title-native-upgrade-batch-mode*)
  (setq old-allow-interactive *swcad-title-allow-batch-interactive-native-gmtitle*)
  (swcad-title-open-native-upgrade-log)
  (setq records (swcad-title-a3a4-native-upgrade-candidate-records))
  (setq total (length records))
  (setq command-text-count (swcad-title-command-text-residue-count))
  (swcad-title-princ-line "----- SWTITLEUPGRADENATIVEA3A4BATCH A3/A4 target-to-native frame upgrade batch -----")
  (swcad-title-print-loaded-version)
  (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (swcad-title-princ-line (strcat "CTAB: " (getvar "CTAB")))
  (swcad-title-print-work-copy-status)
  (swcad-title-print-a3a4-native-upgrade-candidates)
  (swcad-title-princ-line (strcat "Possible accidental command text entities: " (itoa command-text-count)))
  (cond
    ((= total 0)
      (swcad-title-apply-result "STOP_NO_A3A4_NATIVE_UPGRADE_CANDIDATE")
      (setq summary (swcad-title-fast-sheet-summary))
      (setq source-count (swcad-title-fast-summary-value summary "source-title-count"))
      (setq frame-only-count (swcad-title-fast-summary-value summary "frame-only-count"))
      (if (or (> source-count 0) (> frame-only-count 0))
        (progn
          (swcad-title-princ-line "Reason: no converted A3/A4 GMTITLE target pair exists yet; source sheets still remain.")
          (swcad-title-print-fast-sheet-summary summary)
          (setq missing-required (swcad-title-missing-required-native-frame-blocks summary))
          (if missing-required
            (progn
              (swcad-title-princ-line "Next: create the first real native GMTITLE for each missing sheet size, then run SWTITLETRANSFERFASTBATCH.")
              (swcad-title-print-missing-native-exemplar-actions summary missing-required)
            )
            (progn
              (swcad-title-princ-line "Next: run SWTITLETRANSFERFASTBATCH to create A3/A4 target pairs, then rerun SWTITLEUPGRADENATIVEA3A4BATCH.")
            )
          )
        )
        (swcad-title-princ-line "No A3/A4 target pairs need native replacement.")
      )
    )
    ((swcad-title-document-read-only-p)
      (swcad-title-apply-result "ABORT_READ_ONLY_DOCUMENT")
      (swcad-title-princ-line "Open a writable copy of the DWG before upgrading.")
    )
    ((not (swcad-title-current-dwg-in-work-p))
      (swcad-title-apply-result "ABORT_NOT_WORK_COPY")
      (swcad-title-princ-line "A3/A4 batch native upgrade is limited to Documents/CAD tool/work copies.")
      (swcad-title-princ-line "Use SWTITLEUPGRADENATIVESELECT with EDIT confirmation if you intentionally want to test one sheet outside work.")
    )
    ((swcad-title-script-active-p)
      (swcad-title-apply-result "ABORT_NATIVE_A3A4_BATCH_SCRIPT_ACTIVE")
      (swcad-title-princ-line "Do not run SWTITLEUPGRADENATIVEA3A4BATCH from a SCRIPT file.")
      (swcad-title-princ-line "Reason: each candidate may need the interactive GMTITLE dialog, and SCRIPT mode suppresses that fallback.")
      (swcad-title-princ-line "Run the status SCRIPT first, then type SWTITLEUPGRADENATIVEA3A4BATCH manually in the CAD command line.")
      (swcad-title-princ-line "No drawing data was changed.")
    )
    ((> command-text-count 0)
      (swcad-title-apply-result "ABORT_REVIEW_ACCIDENTAL_COMMAND_TEXT_FIRST")
      (swcad-title-princ-line "Possible command text exists in the drawing.")
      (swcad-title-princ-line "Run SWTITLECOMMANDTEXTSCAN and review the listed TEXT/MTEXT handles before A3/A4 upgrades.")
      (swcad-title-princ-line "If they are accidental command leftovers in a work copy, run SWTITLECOMMANDTEXTCLEANSAFE, then rerun this batch.")
      (swcad-title-princ-line "No A3/A4 pairs were changed.")
    )
    (T
      (setq default-count total)
      (swcad-title-princ-line
        (strcat
          "A3/A4 native replacement candidates currently listed: "
          (itoa total)
        )
      )
      (setq summary (swcad-title-fast-sheet-summary))
      (setq frame-only-count (swcad-title-fast-summary-value summary "frame-only-count"))
      (if (> frame-only-count 0)
        (progn
          (swcad-title-princ-line
            (strcat
              "Note: "
              (itoa frame-only-count)
              " frame-only source sheet(s) still remain; this batch will not create them."
            )
          )
          (swcad-title-princ-line "Handle those after this native-recognition upgrade with SWTITLEFRAMEONLYAPPLY or SWTITLETRANSFERFASTBATCH.")
        )
      )
      (swcad-title-princ-line "Default count is all currently listed candidates. Press Enter to process every listed A3/A4 candidate.")
      (swcad-title-princ-line "For a one-sheet trial instead, cancel this command and run SWTITLEA3A4PREP, normal GMTITLE, then SWTITLEA3A4FINISH.")
      (if *swcad-title-a3a4-batch-default-all*
        (progn
          (setq count default-count)
          (swcad-title-princ-line
            (strcat
              "All-candidate mode: processing every currently listed A3/A4 candidate, count="
              (itoa count)
            )
          )
        )
        (setq count
          (getint
            (strcat
              "\nNumber of A3/A4 target pairs to replace with real native GMTITLE <"
              (itoa default-count)
              "> (type "
              (itoa total)
              " for all currently listed, or a smaller number for a partial run): "
            )
          )
        )
      )
      (if (not count)
        (setq count default-count)
      )
      (if (> count total)
        (setq count total)
      )
      (if (<= count 0)
        (swcad-title-apply-result "ABORT_NATIVE_A3A4_UPGRADE_BATCH_USER")
        (progn
          (setq *swcad-title-allow-batch-interactive-native-gmtitle* T)
          (swcad-title-princ-line "Interactive GMTITLE fallback for A3/A4 batch: enabled.")
          (swcad-title-princ-line "Each remaining candidate may open the native GMTITLE dialog.")
          (swcad-title-princ-line "For each dialog, choose the printed DR paper and DR_titlea_3rd, with Frame positioning ON and Object move OFF.")
          (swcad-title-princ-line "If the dialog still shows ISO paper/title values, cancel it. Confirming ISO values will not fix GMPOWEREDIT behavior.")
          (setq *swcad-title-native-upgrade-batch-mode* T)
          (setq index 1)
          (while (<= index count)
            (setq records (swcad-title-a3a4-native-upgrade-candidate-records))
            (if (not records)
              (setq index (+ count 1))
              (progn
                (swcad-title-princ-line
                  (strcat
                    "--- SWTITLEUPGRADENATIVEA3A4BATCH sheet "
                    (itoa index)
                    " / "
                    (itoa count)
                    " ---"
                  )
                )
                (setq *swcad-title-native-upgrade-selected-pair* (car records))
                (setq result (vl-catch-all-apply 'swcad-title-upgrade-native-one nil))
                (if (vl-catch-all-error-p result)
                  (progn
                    (setq *swcad-title-last-apply-status* "ERROR_NATIVE_A3A4_UPGRADE_BATCH_APPLY")
                    (swcad-title-princ-line
                      (strcat
                        "A3/A4 native upgrade batch apply error: "
                        (vl-catch-all-error-message result)
                      )
                    )
                    (setq index (+ count 1))
                  )
                )
                (if (/= *swcad-title-last-apply-status* "UPGRADED_CLONE_TO_NATIVE_GMTITLE")
                  (progn
                    (swcad-title-princ-line
                      (strcat
                        "A3/A4 native upgrade batch stopped after status: "
                        (swcad-title-string *swcad-title-last-apply-status*)
                      )
                    )
                    (swcad-title-princ-line "Remaining candidates after the stopped sheet:")
                    (swcad-title-print-a3a4-native-upgrade-candidates)
                    (setq index (+ count 1))
                  )
                )
              )
            )
            (setq index (+ index 1))
          )
          (setq *swcad-title-native-upgrade-batch-mode* old-batch-mode)
          (setq remaining (length (swcad-title-a3a4-native-upgrade-candidate-records)))
          (swcad-title-princ-line (strcat "Remaining A3/A4 native upgrade candidates after batch: " (itoa remaining)))
          (if (= remaining 0)
            (swcad-title-apply-result "OK_NATIVE_A3A4_UPGRADE_BATCH_COMPLETE")
            (if (equal *swcad-title-last-apply-status* "UPGRADED_CLONE_TO_NATIVE_GMTITLE")
              (swcad-title-apply-result "WARN_NATIVE_A3A4_UPGRADE_BATCH_REMAINING")
            )
          )
          (cond
            ((equal *swcad-title-last-native-gmtitle-abort-reason* "INTERACTIVE_GMTITLE_SKIPPED_IN_BATCH")
              (swcad-title-princ-line "Next: batch cannot safely continue because GMTITLE opens with ISO defaults.")
              (swcad-title-princ-line "Recommended: run SWTITLEA3A4PREP, create one normal GMTITLE, then run SWTITLEA3A4FINISH and verify.")
              (swcad-title-princ-line "If you want to proceed through several dialogs in one command, rerun SWTITLEUPGRADENATIVEA3A4BATCH and choose the requested DR paper/title each time.")
              (swcad-title-princ-line "For A4 frame-only sheets afterward, run SWTITLEFASTSTATUS and use SWTITLEFRAMEONLYAPPLY for the first real DR_A4_Outline exemplar if needed.")
            )
            (T
              (swcad-title-princ-line "Next: run SWTITLEGMTITLEVERIFYALL and SWTITLENATIVEFRAMECHECK, then manually double-click representative A3/A4 DR_titlea_3rd title blocks.")
            )
          )
        )
      )
    )
  )
  (setq *swcad-title-native-upgrade-batch-mode* old-batch-mode)
  (setq *swcad-title-allow-batch-interactive-native-gmtitle* old-allow-interactive)
  (setq *swcad-title-native-upgrade-selected-pair* nil)
  (swcad-title-close-log)
  (princ)
)

(defun swcad-title-upgrade-native-a3a4-batch-manual (/ old-allow result)
  (setq old-allow *swcad-title-allow-batch-interactive-native-gmtitle*)
  (setq *swcad-title-allow-batch-interactive-native-gmtitle* T)
  (setq result (vl-catch-all-apply 'swcad-title-upgrade-native-a3a4-batch nil))
  (setq *swcad-title-allow-batch-interactive-native-gmtitle* old-allow)
  (if (vl-catch-all-error-p result)
    (progn
      (swcad-title-princ-line
        (strcat
          "SWTITLEUPGRADENATIVEA3A4BATCHMANUAL error: "
          (vl-catch-all-error-message result)
        )
      )
      (princ)
    )
  )
  (princ)
)

(defun swcad-title-upgrade-native-a3a4-all (/ old-default-all result)
  (setq old-default-all *swcad-title-a3a4-batch-default-all*)
  (setq *swcad-title-a3a4-batch-default-all* T)
  (setq result (vl-catch-all-apply 'swcad-title-upgrade-native-a3a4-batch nil))
  (setq *swcad-title-a3a4-batch-default-all* old-default-all)
  (if (vl-catch-all-error-p result)
    (progn
      (swcad-title-princ-line
        (strcat
          "SWTITLEUPGRADENATIVEA3A4ALL error: "
          (vl-catch-all-error-message result)
        )
      )
      (princ)
    )
  )
  (princ)
)

(defun c:SWTITLEDEBUG (/ picked ename)
  (setq ename (swcad-title-first-implied-selection))
  (if ename
    (progn
      (swcad-title-princ-line "Using first preselected object for read-only debug.")
      (swcad-title-debug-entity ename)
    )
    (progn
      (swcad-title-princ-line "Select a GM TITLE / FTAP candidate object for read-only debug.")
      (setq picked (entsel "\nSelect title object: "))
      (if picked
        (progn
          (setq ename (car picked))
          (swcad-title-debug-entity ename)
        )
        (swcad-title-princ-line "Nothing selected.")
      )
    )
  )
  (princ)
)

(defun c:SWTITLETEXTSCAN ()
  (swcad-title-scan-title-texts)
)

(defun c:SWTITLECOMMANDTEXTSCAN ()
  (swcad-title-command-text-scan)
)

(defun c:SWTITLECOMMANDTEXTCLEANSAFE ()
  (swcad-title-command-text-clean-safe)
)

(defun c:SWTITLEMULTIPREVIEW ()
  (swcad-title-multi-preview)
)

(defun c:SWTITLEMULTIDETAIL ()
  (swcad-title-multi-detail)
)

(defun c:SWTITLEFRAMESCAN ()
  (swcad-title-frame-scan)
)

(defun c:SWTITLEGMTITLEVERIFY ()
  (swcad-title-gmtitle-verify)
)

(defun c:SWTITLEGMTITLEVERIFYALL ()
  (swcad-title-gmtitle-verify-all)
)

(defun c:SWTITLENATIVEFRAMECHECK ()
  (swcad-title-native-frame-completion-check)
)

(defun c:SWTITLEVERSION ()
  (princ "\n----- SWTITLEVERSION read-only loaded LSP check -----")
  (swcad-title-print-loaded-version)
  (princ "\nExpected current version for A3/A4 manual native finish: 260702-a3a4-manual-native-finish-1")
  (princ "\nIf a different version is shown, APPLOAD this file again before trusting SWTITLE status results.")
  (princ "\nNo drawing data was changed.")
  (princ)
)

(defun c:SWTITLESTATUSREFRESH ()
  (princ "\n----- SWTITLESTATUSREFRESH read-only status refresh -----")
  (swcad-title-print-loaded-version)
  (swcad-title-role-check)
  (swcad-title-a3a4-fix-plan)
  (swcad-title-next-step)
  (swcad-title-upgrade-native-status)
  (swcad-title-gmtitle-verify-all)
  (swcad-title-native-frame-completion-check)
  (swcad-title-double-click-check)
  (swcad-title-status-refresh-summary)
  (princ "\nSWTITLESTATUSREFRESH complete.")
  (princ "\nUpdated logs:")
  (princ "\n  work/swcad_title_status_refresh_last.txt")
  (princ "\n  work/swcad_title_role_check_last.txt")
  (princ "\n  work/swcad_title_a3a4_fix_plan_last.txt")
  (princ "\n  work/swcad_title_next_step_last.txt")
  (princ "\n  work/swcad_title_native_upgrade_last.txt")
  (princ "\n  work/swcad_title_gmtitle_verify_all_last.txt")
  (princ "\n  work/swcad_title_native_frame_check_last.txt")
  (princ "\n  work/swcad_title_double_click_check_last.txt")
  (princ "\nNo drawing data was changed by the status commands.")
  (princ)
)

(defun c:SWTITLEPICKCHECK ()
  (swcad-title-pick-check)
)

(defun c:SWTITLEDOUBLECLICKCHECK ()
  (swcad-title-double-click-check)
)

(defun c:SWTITLEROLECHECK ()
  (swcad-title-role-check)
)

(defun c:SWTITLEA3A4FIXPLAN ()
  (swcad-title-a3a4-fix-plan)
)

(defun c:SWTITLEGMTITLELINKSCAN ()
  (swcad-title-gmtitle-link-scan)
)

(defun c:SWTITLEGMTITLELINKDETAIL ()
  (swcad-title-gmtitle-link-detail)
)

(defun c:SWTITLEGMTITLECOMPARE ()
  (swcad-title-gmtitle-compare)
)

(defun c:SWTITLEGMTITLEPRESERVECOPYTEST ()
  (swcad-title-gmtitle-preserve-copy-test)
)

(defun c:SWTITLEUPGRADENATIVESTATUS ()
  (swcad-title-upgrade-native-status)
)

(defun c:SWTITLEUPGRADENATIVEONE ()
  (swcad-title-upgrade-native-one)
)

(defun c:SWTITLEUPGRADENATIVESELECT ()
  (swcad-title-upgrade-native-select)
)

(defun c:SWTITLEUPGRADENATIVEA3A4NEXT ()
  (swcad-title-upgrade-native-a3a4-prepare)
)

(defun c:SWTITLEA3A4NEXT ()
  (swcad-title-upgrade-native-a3a4-prepare)
)

(defun c:SWTITLEA3A4PREP ()
  (swcad-title-upgrade-native-a3a4-prepare)
)

(defun c:SWTITLEA3A4FINISH ()
  (swcad-title-upgrade-native-a3a4-finish)
)

(defun c:SWTITLEUPGRADENATIVEBATCH ()
  (swcad-title-upgrade-native-batch)
)

(defun c:SWTITLEUPGRADENATIVEA3A4BATCH ()
  (swcad-title-upgrade-native-a3a4-batch)
)

(defun c:SWTITLEUPGRADENATIVEA3A4ALL ()
  (swcad-title-upgrade-native-a3a4-all)
)

(defun c:SWTITLEUPGRADENATIVEA3A4BATCHMANUAL ()
  (swcad-title-upgrade-native-a3a4-batch-manual)
)

(defun c:SWTITLEFRAMEDEFCHECK ()
  (swcad-title-frame-def-check)
)

(defun c:SWTITLEFRAMEDEFCLEANSAFE ()
  (swcad-title-frame-def-clean-safe)
)

(defun c:SWTITLEREPAIRFRAMEDEFS ()
  (swcad-title-repair-frame-definitions)
)

(defun c:SWTITLEFASTSTATUS ()
  (swcad-title-fast-status)
)

(defun c:SWTITLENEXTSTEP ()
  (swcad-title-next-step)
)

(defun c:SWTITLETRANSFERPREVIEW ()
  (swcad-title-transfer-preview)
)

(defun c:SWTITLETRANSFERAPPLY ()
  (swcad-title-transfer-apply)
)

(defun c:SWTITLETRANSFERFINALIZE ()
  (swcad-title-transfer-finalize)
)

(defun c:SWTITLETRANSFERBATCH ()
  (swcad-title-transfer-batch)
)

(defun c:SWTITLETRANSFERCLONEAPPLY ()
  (swcad-title-transfer-clone-apply)
)

(defun c:SWTITLETRANSFERCLONEBATCH ()
  (swcad-title-transfer-clone-batch)
)

(defun c:SWTITLETRANSFERFASTBATCH ()
  (swcad-title-transfer-fast-batch)
)

(defun c:SWTITLETRANSFERBOOTSTRAPFAST ()
  (swcad-title-transfer-bootstrap-fast)
)

(defun c:SWTITLEFRAMEONLYFINALIZE ()
  (swcad-title-transfer-frame-only-finalize)
)

(defun c:SWTITLEFRAMEONLYAPPLY ()
  (swcad-title-transfer-frame-only-apply)
)

(defun c:SWTITLEFRAMEONLYCLONEAPPLY ()
  (swcad-title-transfer-frame-only-clone-apply)
)

(defun c:SWTITLEFRAMEONLYCLONEBATCH ()
  (swcad-title-transfer-frame-only-clone-batch)
)

(defun c:SWSCALESCAN (/ insert-ss insert-index insert-total dim-ss dim-index dim-total ename data overrides style styledata override-value style-value effective-value expected-values effective-counts override-counts style-counts match-count mismatch-count mismatch-example-count match result)
  (swcad-title-open-scale-log)
  (setq *swcad-title-scan-title-insert-count* 0)
  (setq *swcad-title-scan-scale-count* 0)
  (setq *swcad-title-scan-loose-text-count* 0)
  (setq *swcad-title-scan-loose-scale-count* 0)
  (setq *swcad-title-scan-scale-values* nil)
  (setq effective-counts nil)
  (setq override-counts nil)
  (setq style-counts nil)
  (setq match-count 0)
  (setq mismatch-count 0)
  (setq mismatch-example-count 0)
  (swcad-title-princ-line "----- SWSCALESCAN read-only title scale / DIMLFAC scan -----")
  (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (swcad-title-princ-line (strcat "CTAB: " (getvar "CTAB")))

  (setq insert-ss (ssget "_X" '((0 . "INSERT"))))
  (setq insert-total (if insert-ss (sslength insert-ss) 0))
  (swcad-title-princ-line (strcat "INSERT count: " (itoa insert-total)))
  (swcad-title-princ-line "Attribute title scale candidates:")
  (setq insert-index 0)
  (while (< insert-index insert-total)
    (setq ename (ssname insert-ss insert-index))
    (swcad-title-scan-insert ename)
    (setq insert-index (+ insert-index 1))
  )
  (if (= *swcad-title-scan-scale-count* 0)
    (swcad-title-princ-line "  <none>")
  )
  (swcad-title-scan-loose-texts)

  (setq expected-values (swcad-title-expected-dimlfac-values *swcad-title-scan-scale-values*))
  (swcad-title-princ-line "Title scale summary:")
  (swcad-title-princ-line
    (strcat "  title inserts with scale: " (itoa *swcad-title-scan-title-insert-count*))
  )
  (swcad-title-princ-line
    (strcat "  scale attributes: " (itoa *swcad-title-scan-scale-count*))
  )
  (swcad-title-princ-line
    (strcat "  loose text scale candidates: " (itoa *swcad-title-scan-loose-scale-count*))
  )
  (swcad-title-princ-line
    (strcat "  title scale values: " (swcad-title-list-string *swcad-title-scan-scale-values*))
  )
  (swcad-title-princ-line
    (strcat "  expected DIMLFAC values: " (swcad-title-number-list-string expected-values))
  )

  (setq dim-ss (ssget "_X" '((0 . "DIMENSION"))))
  (setq dim-total (if dim-ss (sslength dim-ss) 0))
  (swcad-title-princ-line (strcat "DIMENSION count: " (itoa dim-total)))
  (swcad-title-princ-line "Dimension mismatch examples:")
  (setq dim-index 0)
  (while (< dim-index dim-total)
    (setq ename (ssname dim-ss dim-index))
    (setq data (entget ename '("*")))
    (setq overrides (swcad-title-get-dstyle-overrides data))
    (setq style (swcad-title-safe-string (cdr (assoc 3 data))))
    (setq styledata (if style (tblsearch "DIMSTYLE" style) nil))
    (setq override-value (cdr (assoc 144 overrides)))
    (setq style-value (if styledata (cdr (assoc 144 styledata)) nil))
    (setq effective-value (swcad-title-dim-linear-scale ename data))
    (setq effective-counts
      (swcad-title-count-add (swcad-title-number-string effective-value) effective-counts)
    )
    (if (numberp override-value)
      (setq override-counts
        (swcad-title-count-add (swcad-title-number-string override-value) override-counts)
      )
    )
    (setq style-counts
      (swcad-title-count-add
        (strcat
          (if style style "<no style>")
          " DIMLFAC="
          (if (numberp style-value) (swcad-title-number-string style-value) "<missing>")
        )
        style-counts
      )
    )
    (setq match (swcad-title-float-in-list-p effective-value expected-values))
    (if match
      (setq match-count (+ match-count 1))
      (progn
        (setq mismatch-count (+ mismatch-count 1))
        (if (< mismatch-example-count 12)
          (progn
            (setq mismatch-example-count (+ mismatch-example-count 1))
            (swcad-title-princ-line
              (strcat
                "  - handle="
                (swcad-title-string (cdr (assoc 5 data)))
                ", layout="
                (swcad-title-string (cdr (assoc 410 data)))
                ", style="
                (if style style "<no style>")
                ", override="
                (if (numberp override-value) (swcad-title-number-string override-value) "<none>")
                ", style DIMLFAC="
                (if (numberp style-value) (swcad-title-number-string style-value) "<missing>")
                ", effective="
                (swcad-title-number-string effective-value)
              )
            )
          )
        )
      )
    )
    (setq dim-index (+ dim-index 1))
  )
  (if (= mismatch-example-count 0)
    (swcad-title-princ-line "  <none>")
  )

  (swcad-title-print-counts "Effective DIMLFAC values:" effective-counts)
  (swcad-title-print-counts "Override DIMLFAC values:" override-counts)
  (swcad-title-print-counts "Style DIMLFAC values:" style-counts)
  (swcad-title-princ-line "Comparison summary:")
  (swcad-title-princ-line (strcat "  matching dimensions: " (itoa match-count)))
  (swcad-title-princ-line (strcat "  mismatching dimensions: " (itoa mismatch-count)))
  (setq result
    (cond
      ((= (length expected-values) 0) "MISSING_TITLE_SCALE")
      ((= dim-total 0) "NO_DIMENSIONS")
      ((= mismatch-count 0) "OK_DIMLFAC_MATCH")
      ((> match-count 0) "MIXED_DIMLFAC")
      (T "CONFLICT_DIMLFAC")
    )
  )
  (swcad-title-princ-line (strcat "Result: " result))
  (swcad-title-princ-line "No drawing data was changed.")
  (swcad-title-close-log)
  (princ)
)

(princ (strcat "\nswcad_title_scale.lsp ready " *swcad-title-scale-version*))
(princ "\nCommands: SWTITLEDEBUG, SWTITLESCAN, SWTITLETEXTSCAN, SWTITLECOMMANDTEXTSCAN, SWTITLECOMMANDTEXTCLEANSAFE, SWTITLEMULTIPREVIEW, SWTITLEGMTITLEVERIFY, SWTITLEGMTITLEVERIFYALL, SWTITLENATIVEFRAMECHECK, SWTITLEVERSION, SWTITLESTATUSREFRESH, SWTITLEPICKCHECK, SWTITLEDOUBLECLICKCHECK, SWTITLEROLECHECK, SWTITLEA3A4FIXPLAN, SWTITLEGMTITLELINKSCAN, SWTITLEGMTITLELINKDETAIL, SWTITLEGMTITLECOMPARE, SWTITLEGMTITLEPRESERVECOPYTEST, SWTITLEUPGRADENATIVESTATUS, SWTITLEUPGRADENATIVEONE, SWTITLEUPGRADENATIVESELECT, SWTITLEUPGRADENATIVEA3A4NEXT, SWTITLEA3A4NEXT, SWTITLEA3A4PREP, SWTITLEA3A4FINISH, SWTITLEUPGRADENATIVEBATCH, SWTITLEUPGRADENATIVEA3A4BATCH, SWTITLEUPGRADENATIVEA3A4ALL, SWTITLEUPGRADENATIVEA3A4BATCHMANUAL, SWTITLEFRAMEDEFCHECK, SWTITLEFRAMEDEFCLEANSAFE, SWTITLEREPAIRFRAMEDEFS, SWTITLEFASTSTATUS, SWTITLENEXTSTEP, SWTITLETRANSFERPREVIEW, SWTITLETRANSFERAPPLY, SWTITLETRANSFERFINALIZE, SWTITLETRANSFERBATCH, SWTITLETRANSFERCLONEAPPLY, SWTITLETRANSFERCLONEBATCH, SWTITLETRANSFERFASTBATCH, SWTITLETRANSFERBOOTSTRAPFAST, SWTITLEFRAMEONLYFINALIZE, SWTITLEFRAMEONLYAPPLY, SWTITLEFRAMEONLYCLONEAPPLY, SWTITLEFRAMEONLYCLONEBATCH, SWSCALESCAN")
(princ)
