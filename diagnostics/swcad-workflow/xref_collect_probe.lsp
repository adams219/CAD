;;; SWCADRUN step 0 (COLLECT) probe.  Runs in GstarCAD /b on a new drawing made from
;;; the Mechanical template, never saved unless SWT_COLLECT_WORKCOPY is given.
;;; Environment:
;;;   SWT_COLLECT_LOG           log path
;;;   SWT_COLLECT_LOADER        swcad_workflow_load.lsp
;;;   SWT_COLLECT_LIST          list base: <base>.utf8.txt / <base>.ansi.txt with one DWG
;;;                             path per line (copies only), written by the picker helper
;;;   SWT_COLLECT_KOREAN_LIST   list base with one paper-space DWG copy in a Korean folder
;;;   SWT_COLLECT_EMPTY         a DWG whose model space and layouts are empty
;;;   SWT_COLLECT_CONVERT_ROOT  folder for the converted copies of paper-space sheets
;;;   SWT_COLLECT_WORKCOPY      optional: Save-As path of the work copy; when given, the
;;;                             XREF stage (BIND/EXPLODE) runs after the collection

(vl-load-com)
(load (getenv "SWT_COLLECT_LOADER"))

(setq *swt-c-log* nil)

(defun swt-c-line (parts / text part)
  (setq text "")
  (foreach part parts
    (setq text (strcat text (if (= text "") "" "|") (vl-string-translate "|\n\r\t" "/   " (vl-princ-to-string part))))
  )
  (write-line text *swt-c-log*)
)

(defun swt-c-check (label actual expected)
  (swt-c-line (list (if (equal actual expected) "UNIT_OK" "UNIT_FAIL") label actual expected))
)

(defun swt-c-stems (rows)
  (apply 'append (mapcar '(lambda (row) (mapcar 'car row)) rows))
)

(defun swt-c-overlap-p (a b)
  (and (< (car a) (caddr b)) (< (car b) (caddr a)) (< (cadr a) (cadddr b)) (< (cadr b) (cadddr a)))
)

(defun swt-c-contains-p (text part)
  (if (and text part (vl-string-search part text)) T nil)
)

;;; Lines of the last collect log (swcad_collect_last.txt).
(defun swt-c-collect-log-lines ()
  (swapp-read-text-lines (swapp-collect-log-path))
)

(defun swt-c-log-has-p (part / found line)
  (setq found nil)
  (foreach line (swt-c-collect-log-lines)
    (if (swt-c-contains-p line part) (setq found T))
  )
  found
)

(defun swt-c-xref-path (reference)
  (swapp-xref-definition-path (swapp-block-definition (swapp-reference-name reference)))
)

(defun swt-c-under-p (path root)
  (and
    path root
    (> (strlen path) (strlen root))
    (= (strcase (substr (vl-string-translate "/" "\\" path) 1 (strlen root))) (strcase (vl-string-translate "/" "\\" root)))
  )
)

(defun swt-c-main (/ base picked paths rows refs stems unique items window whole key group tops row-ok rows-by-group overlap i j sort-items sorted stage records convert-root korean korean-target host converted reference names empty-path result converted-count stem-set)
  (setq *swt-c-log* (open (getenv "SWT_COLLECT_LOG") "w"))
  (swt-c-line (list "VERSION" *swapp-version*))
  (swt-c-line (list "DWG" (strcat (getvar "DWGPREFIX") (getvar "DWGNAME"))))
  (setq convert-root (getenv "SWT_COLLECT_CONVERT_ROOT"))
  (setq *swapp-collect-convert-root-override* convert-root)

  ;; 1. Name order, drawing-number groups, XREF names, conversion rules.
  (swt-c-check "natural Part 2 < Part 10" (swapp-natural-less-p "Part 2" "Part 10") T)
  (swt-c-check "natural Part 10 > Part 2" (swapp-natural-less-p "Part 10" "Part 2") nil)
  (swt-c-check "natural case" (swapp-natural-less-p "a" "B") T)
  (swt-c-check "natural numbered" (swapp-natural-less-p "00-00-00-00_X" "01-00-00-00_A") T)
  (swt-c-check "natural same" (swapp-natural-less-p "01-03-00-00_L-Jig" "01-03-00-00_L-Jig") nil)
  (foreach item
    '(
      ("01-06-05-00_Bearing Unit Housing" "01")
      ("00-00-00-00_221216_디알드라이브_감속기 성능 시험기_A3" "00")
      ("06-00-00-00_Base Frame" "06")
      ("0000_A_DRP125_CP_ALL" nil)
      ("P_eCVT-Sun HL Gear_LH_260506" nil)
      ("5560 Shaft Spacer_UP_PEEK_260526_A4" nil)
      ("01-_x" nil)
      ("01-02" "01")
      ("12-3 Part" "12")
    )
    (swt-c-check (strcat "group " (car item)) (swapp-drawing-number-group (car item)) (cadr item))
  )
  (swt-c-check "xref name reserved chars" (swapp-collect-xref-name "a;b,c=d" nil) "a_b_c_d")
  (swt-c-check "xref name used" (swapp-collect-xref-name "Part" '("PART")) "Part_2")
  (swt-c-check "paper sheet ok" (swapp-collect-paper-sheet-problem 0 '(("시트1" 324)) 0) nil)
  (swt-c-check "paper sheet model not empty" (swt-c-contains-p (swapp-collect-paper-sheet-problem 5 '(("시트1" 324)) 0) "모델 공간이 비어 있지 않") T)
  (swt-c-check "paper sheet nothing" (swt-c-contains-p (swapp-collect-paper-sheet-problem 0 nil 0) "모두 비어") T)
  (swt-c-check "paper sheet two layouts" (swt-c-contains-p (swapp-collect-paper-sheet-problem 0 '(("A" 1) ("B" 2)) 0) "2개") T)
  (swt-c-check "paper sheet negative dimlfac" (swt-c-contains-p (swapp-collect-paper-sheet-problem 0 '(("A" 1)) 3) "음수") T)

  ;; 2. The DWG list through the real picker helper (-TestPaths): launch from
  ;;    GstarCAD and the encoding round trip of Korean paths.
  (setq base (getenv "SWT_COLLECT_LIST"))
  (setq picked (swapp-collect-read-picker-result-keep base))
  (setq paths (cadr picked))
  (swt-c-line (list "LIST" (car picked) (length paths) *swapp-collect-picker-encoding*))
  (setq picked (swapp-collect-run-picker nil (list (car paths) (cadr paths) (last paths))))
  (swt-c-line (list "PICKER" (car picked) (length (cadr picked)) *swapp-collect-picker-encoding*))
  (swt-c-check "picker round trip" (cadr picked) (list (car paths) (cadr paths) (last paths)))

  ;; 3. Rows for the 32 real names: one row per first number, name order.
  (setq rows (swapp-collect-rows paths))
  (swt-c-line (list "ROWS" (mapcar 'length rows)))
  (swt-c-check "row sizes" (mapcar 'length rows) '(1 13 12 3 1 1 1))
  (setq stems (swt-c-stems rows))
  (swt-c-check "rows keep name order" stems (mapcar 'vl-filename-base (vl-sort paths '(lambda (a b) (< (strcase a) (strcase b))))))
  (swt-c-check "duplicate path used once" (length (swt-c-stems (swapp-collect-rows (append paths (list (car paths)))))) (length paths))

  ;; 4. Conversion of a paper-space sheet whose path has Korean folder and file
  ;;    names; attached and detached again, so the drawing stays empty.
  (setq korean (cadr (swapp-collect-read-picker-result-keep (getenv "SWT_COLLECT_KOREAN_LIST"))))
  (swt-c-line (list "KOREAN_SOURCE" (car korean)))
  (setq korean-target (swapp-collect-convert-target (swapp-collect-new-convert-folder) 1 (car korean)))
  (setq host (swapp-doc))
  (setq converted (swapp-collect-convert-paper-sheet host (car korean) korean-target))
  (swt-c-line (list "KOREAN_CONVERTED" converted))
  (swt-c-check "korean path converted" (car converted) T)
  (swt-c-check "korean copy keeps file name" (vl-filename-base (cadr converted)) (vl-filename-base (car korean)))
  (swt-c-check "korean copy under convert root" (swt-c-under-p (cadr converted) convert-root) T)
  (swt-c-line (list "DOC_EQUAL_AFTER_CONVERSION" (equal host (swapp-doc)) (vla-get-Name (swapp-doc))))
  (swt-c-check "host active after conversion" (swapp-same-document-p (swapp-doc) host) T)
  (swt-c-check "no backup file left" (findfile (strcat (vl-filename-directory (cadr converted)) "\\" (vl-filename-base (cadr converted)) ".bak")) nil)
  (setq reference (swapp-collect-attach (swapp-doc) (cadr converted) "SWT_KOREAN_CHECK"))
  (swt-c-check "korean copy attached" (= (type reference) 'VLA-OBJECT) T)
  (if (= (type reference) 'VLA-OBJECT)
    (progn
      (swt-c-check "korean copy not empty" (swapp-collect-xref-empty-p reference) nil)
      (swt-c-line (list "KOREAN_BBOX" (swapp-object-bbox4 reference)))
      (swapp-collect-remove (list reference) (list "SWT_KOREAN_CHECK"))
    )
  )
  (swt-c-check "korean check detached" (tblsearch "BLOCK" "SWT_KOREAN_CHECK") nil)

  ;; 5. A file that cannot be converted (model space and layouts empty) stops the
  ;;    collection, and the XREF attached before it is removed again.
  (setq empty-path (getenv "SWT_COLLECT_EMPTY"))
  (setq *swapp-collect-file-list-override* (list (car paths) empty-path))
  (setq result (swapp-collect-xrefs))
  (setq *swapp-collect-file-list-override* nil)
  (swt-c-check "unconvertible file stops" result nil)
  (swt-c-check "unconvertible file status" (swt-c-log-has-p "STOP_COLLECT_PAPER_SHEET") T)
  (swt-c-check "unconvertible file reason" (swt-c-log-has-p "모두 비어") T)
  (swt-c-check "nothing left after stop" (length (swapp-top-xref-references)) 0)
  (swt-c-check "no xref definition left after stop" (tblsearch "BLOCK" (swapp-collect-xref-name (vl-filename-base (car paths)) nil)) nil)

  ;; 6. SWCADRUN on the empty drawing: stage COLLECT, attach, convert, place.
  (swt-c-check "empty drawing stage" (swapp-workflow-stage) "COLLECT")
  (setq *swapp-collect-file-list-override* paths)
  (c:SWCADRUN)
  (setq *swapp-collect-file-list-override* nil)
  (setq refs (swapp-top-xref-references))
  (swt-c-check "xref count" (length refs) (length paths))
  (setq unique (swapp-unique-reference-names refs))
  (swt-c-check "xref names unique" (length unique) (length refs))
  (swt-c-check "stage after collect" (swapp-workflow-stage) "XREF")
  (swt-c-check "collect log ok" (swt-c-log-has-p "OK_COLLECT_XREFS_PLACED") T)
  (setq converted-count 0)
  (foreach reference refs
    (if (swt-c-under-p (swt-c-xref-path reference) convert-root) (setq converted-count (1+ converted-count)))
  )
  (swt-c-check "paper-space sheets converted" converted-count 14)
  (swt-c-check "collect log conversion count" (swt-c-log-has-p "바꿔 붙인 도면: 14개") T)
  (setq stem-set (vl-sort (mapcar '(lambda (r) (vl-filename-base (swt-c-xref-path r))) refs) '<))
  (swt-c-check "xref file names are the picked names" stem-set (vl-sort (mapcar 'vl-filename-base paths) '<))

  ;; 7. Geometry: sheet tops per row, no overlap.
  (setq items nil)
  (foreach reference refs
    (setq window (swapp-collect-sheet-window reference))
    (setq whole (swapp-object-bbox4 reference))
    (setq key (swapp-drawing-number-group (vl-filename-base (swt-c-xref-path reference))))
    (setq items (cons (list (vl-filename-base (swt-c-xref-path reference)) key whole (car window) (cadr window)) items))
    (swt-c-line (list "XREF" (swapp-reference-name reference) key (cadr window) (car window) whole))
  )
  (setq row-ok T)
  (setq rows-by-group nil)
  (foreach item items
    (setq group (assoc (cadr item) rows-by-group))
    (if group
      (setq rows-by-group (subst (cons (car group) (cons item (cdr group))) group rows-by-group))
      (setq rows-by-group (cons (list (cadr item) item) rows-by-group))
    )
  )
  (foreach group rows-by-group
    (setq tops (mapcar '(lambda (x) (cadddr (nth 3 x))) (cdr group)))
    (if (> (- (apply 'max tops) (apply 'min tops)) 0.01) (setq row-ok nil))
    (swt-c-line (list "ROW" (car group) (length (cdr group)) (apply 'max tops) (apply 'min tops)))
  )
  (swt-c-check "sheet tops equal per row" row-ok T)
  (setq overlap nil)
  (setq i 0)
  (while (< i (length items))
    (setq j (1+ i))
    (while (< j (length items))
      (if (swt-c-overlap-p (nth 2 (nth i items)) (nth 2 (nth j items))) (setq overlap (cons (list (car (nth i items)) (car (nth j items))) overlap)))
      (setq j (1+ j))
    )
    (setq i (1+ i))
  )
  (swt-c-check "no overlapping xref extents" overlap nil)
  (swt-c-line (list "FRAME_KINDS" (length (vl-remove-if-not '(lambda (x) (equal (nth 4 x) "frame")) items)) (length (vl-remove-if-not '(lambda (x) (equal (nth 4 x) "no-frame")) items))))
  (swt-c-check "no multi-frame files" (length (vl-remove-if-not '(lambda (x) (equal (nth 4 x) "several-frames")) items)) 0)

  ;; 8. The Layout order rule reads the name order from the placed sheets.
  (setq sort-items (mapcar '(lambda (x) (cons (car x) (swapp-bbox4-window (nth 3 x)))) items))
  (setq sorted (mapcar 'car (gsla-sort-windows sort-items)))
  (swt-c-check "layout order rule gives name order" sorted stems)

  ;; 9. Optional: the XREF stage (Save As work copy, BIND, EXPLODE) and the source
  ;;    file names recorded for the Layout names.
  (if (and (getenv "SWT_COLLECT_WORKCOPY") (/= (getenv "SWT_COLLECT_WORKCOPY") ""))
    (progn
      (setq *swcad-title-work-copy-saveas-path-override* (getenv "SWT_COLLECT_WORKCOPY"))
      (c:SWCADRUN)
      (setq *swcad-title-work-copy-saveas-path-override* nil)
      (setq stage (swapp-workflow-stage))
      (swt-c-line (list "STAGE_AFTER_XREF" stage (strcat (getvar "DWGPREFIX") (getvar "DWGNAME"))))
      (swt-c-check "xrefs left after materialize" (length (swapp-top-xref-references)) 0)
      (setq records (swapp-source-sheet-records-read))
      (swt-c-check "source records" (length records) (length paths))
      (swt-c-check "source record order is name order" (mapcar 'cadr records) stems)
      (swt-c-check "materialize finished" (member stage '("XREF" "COLLECT")) nil)
      ;; The GMTITLE step finds source sheets by frame/title blocks.  Sheets drawn
      ;; with the standard SOLIDWORKS sheet format (lines and text only, as in the
      ;; 221216 test project) give BLOCKED_NO_SHEETS here; that is the TITLE
      ;; step's limit, not the collection's.
      (swt-c-line (list "NOTE_STAGE_AFTER_MATERIALIZE" stage))
      ;; Save only the work copy, never the template the probe started from.
      (if
        (equal
          (strcase (vl-string-translate "/" "\\" (strcat (getvar "DWGPREFIX") (getvar "DWGNAME"))))
          (strcase (vl-string-translate "/" "\\" (getenv "SWT_COLLECT_WORKCOPY")))
        )
        (progn
          (vla-Save (vla-get-ActiveDocument (vlax-get-acad-object)))
          (swt-c-line (list "SAVED" (getenv "SWT_COLLECT_WORKCOPY")))
        )
        (swt-c-line (list "UNIT_FAIL" "work copy active" (strcat (getvar "DWGPREFIX") (getvar "DWGNAME")) (getenv "SWT_COLLECT_WORKCOPY")))
      )
    )
  )
  (setq *swapp-collect-convert-root-override* nil)
  (write-line "Main part completed: yes" *swt-c-log*)
  (close *swt-c-log*)
  (princ)
)

;;; Separate script line after swt-c-main: GstarCAD finishes closing the converted
;;; copies only after the LISP evaluation that closed them.
(defun swt-c-finish (/ names)
  (setq *swt-c-log* (open (getenv "SWT_COLLECT_LOG") "a"))
  (setq names nil)
  (vlax-for doc (vla-get-Documents (vlax-get-acad-object)) (setq names (cons (vla-get-Name doc) names)))
  (swt-c-line (list "DOCS_AFTER" (reverse names)))
  (swt-c-check "only the host drawing is open at the end" (length names) 1)
  (write-line "Collect probe completed: yes" *swt-c-log*)
  (close *swt-c-log*)
  (princ)
)

;;; Reads a path list written like the picker result, without deleting it.
(defun swapp-collect-read-picker-result-keep (base / copy-base suffix)
  (setq copy-base (strcat base "_copy"))
  (foreach suffix '(".utf8.txt" ".ansi.txt")
    (if (findfile (strcat copy-base suffix)) (vl-file-delete (strcat copy-base suffix)))
    (vl-file-copy (strcat base suffix) (strcat copy-base suffix))
  )
  (swapp-collect-read-picker-result copy-base)
)

(swt-c-main)
