;;; SWCAD Workflow MVP orchestrator.
;;; The production modules remain the owners of GMTITLE, DIMSTYLE, and LAYOUT.

(vl-load-com)

(setq *swapp-version* "260719-cleanup-zero-pass-fast-17")
(setq *swapp-state-dictionary-key* "SWCAD_WORKFLOW_STATE")
(setq *swapp-legacy-layout-prefix* "SWCAD-SHEET")
(setq *swapp-layout-placement-mode* "XREF_SOURCE_FILENAME_COORDINATES")
(setq *swapp-source-state-prefix* "SOURCE_SHEET_")
(setq *swapp-final-sheet-state-prefix* "FINAL_SHEET_")
(setq *swapp-layout-owned-state-prefix* "LAYOUT_OWNED_")
(setq *swapp-resource-cleanup-policy* "ALL_UNUSED_NAMED_DEFINITIONS_V5")
(setq *swapp-resource-cleanup-max-passes* 32)
(setq *swapp-resource-cleanup-state-save-max-passes* 4)
(setq *swapp-last-resource-cleanup-marked-p* nil)
(setq *swapp-last-resource-cleanup-integrity-ok* nil)
(setq *swapp-last-resource-cleanup-identity-ok* nil)
(setq *swapp-last-resource-cleanup-full-record-ok* nil)
(setq *swapp-last-resource-cleanup-stored-integrity* nil)
(setq *swapp-last-resource-cleanup-current-integrity* nil)
(setq *swapp-last-resource-cleanup-stored-identity* nil)
(setq *swapp-last-resource-cleanup-current-identity* nil)
(setq *swapp-last-resource-cleanup-full-identity-ok* nil)
(setq *swapp-last-resource-cleanup-stored-full-identity* nil)
(setq *swapp-last-resource-cleanup-current-full-identity* nil)
(setq *swapp-last-resource-cleanup-stored-full-record* nil)
(setq *swapp-last-resource-cleanup-current-full-record* nil)
(setq *swapp-purge-symbol-tables* '("APPID" "BLOCK" "DIMSTYLE" "LAYER" "LTYPE" "STYLE" "UCS" "VIEW" "VPORT"))
(setq *swapp-purge-command-categories*
  '(
    ("BLOCK" "_Block")
    ("DIMSTYLE" "D")
    ("GROUP" "_Groups")
    ("LAYER" "_Layers")
    ("LINETYPE" "_LTypes")
    ("MATERIAL" "_Materials")
    ("MLEADERSTYLE" "MU")
    ("PLOTSTYLE" "_Plotstyles")
    ("SHAPE" "_SHapes")
    ("TEXTSTYLE" "_STyles")
    ("MLINESTYLE" "_Mlinestyles")
    ("TABLESTYLE" "_Tablestyles")
    ("VISUALSTYLE" "_Visualstyles")
    ("REGAPP" "R")
  )
)
(setq *swapp-layout-preview-limit* 12)
(setq *swapp-transform-tolerance* 1e-8)
(setq *swapp-geometry-tolerance* 0.001)
(setq *swapp-dimension-semantic-codes* '(47 48 71 72 144 146 272 283 284 286))
(setq *swapp-last-dimension-semantics-before* nil)
(setq *swapp-last-dimension-semantics-after* nil)
(setq *swapp-last-dimension-semantic-snapshots* nil)
(setq *swapp-read-cache-enabled* nil)
(setq *swapp-read-cache-values* nil)
(setq *swapp-read-cache-start-ms* nil)
(setq *swapp-read-cache-hit-count* 0)
(setq *swapp-read-cache-miss-count* 0)
(setq *swapp-read-cache-last-elapsed-ms* 0)
(setq *swapp-read-cache-last-hit-count* 0)
(setq *swapp-read-cache-last-miss-count* 0)
(setq *swapp-read-cache-last-title-insert-scans* 0)
(setq *swapp-read-cache-last-title-insert-cache-hits* 0)
(setq *swapp-command-performance-active* nil)
(setq *swapp-command-performance-start-ms* nil)
(setq *swapp-command-performance-read-ms* 0)
(setq *swapp-command-performance-cache-hits* 0)
(setq *swapp-command-performance-cache-misses* 0)
(setq *swapp-command-performance-title-insert-scans* 0)
(setq *swapp-command-performance-title-insert-cache-hits* 0)
(setq *swapp-command-performance-title-insert-scan-base* 0)
(setq *swapp-command-performance-title-insert-cache-hit-base* 0)
(setq *swapp-last-command-elapsed-ms* 0)
(setq *swapp-last-command-read-ms* 0)
(setq *swapp-last-command-cache-hits* 0)
(setq *swapp-last-command-cache-misses* 0)
(setq *swapp-last-command-title-insert-scans* 0)
(setq *swapp-last-command-title-insert-cache-hits* 0)
(setq *swapp-resource-source-reference-names* nil)

;;; ---------------------------
;;; Common helpers and state
;;; ---------------------------

(defun swapp-safe (fn args / result)
  (setq result (vl-catch-all-apply fn args))
  (if (vl-catch-all-error-p result) nil result)
)

(defun swapp-call-ok-p (fn args / result)
  (setq result (vl-catch-all-apply fn args))
  (not (vl-catch-all-error-p result))
)

(defun swapp-doc ()
  (vla-get-ActiveDocument (vlax-get-acad-object))
)

(defun swapp-model ()
  (vla-get-ModelSpace (swapp-doc))
)

(defun swapp-activate-model (/ result)
  (setq result (vl-catch-all-apply 'setvar (list "CTAB" "Model")))
  (not (vl-catch-all-error-p result))
)

(defun swapp-collection-items (collection / count index item result)
  (setq result nil)
  (setq count (swapp-safe 'vla-get-Count (list collection)))
  (if (numberp count)
    (progn
      (setq index 0)
      (while (< index count)
        (setq item (swapp-safe 'vla-Item (list collection index)))
        (if item (setq result (cons item result)))
        (setq index (1+ index))
      )
    )
  )
  (reverse result)
)

(defun swapp-model-objects-by-dxf-type (entity-type / ss index ename object result)
  (setq ss (ssget "_X" (list (cons 0 entity-type) (cons 410 "Model"))))
  (setq index 0)
  (setq result nil)
  (if ss
    (while (< index (sslength ss))
      (setq ename (ssname ss index))
      (setq object
        (if ename
          (swapp-safe 'vlax-ename->vla-object (list ename))
          nil
        )
      )
      (if object (setq result (cons object result)))
      (setq index (1+ index))
    )
  )
  (reverse result)
)

(defun swapp-model-insert-objects ()
  (swapp-model-objects-by-dxf-type "INSERT")
)

(defun swapp-model-dimension-objects ()
  (swapp-model-objects-by-dxf-type "DIMENSION")
)

(defun swapp-alist-put (items key value / result pair found)
  (setq result nil)
  (setq found nil)
  (foreach pair items
    (if (equal (strcase (car pair)) (strcase key))
      (progn
        (setq result (append result (list (cons key value))))
        (setq found T)
      )
      (setq result (append result (list pair)))
    )
  )
  (if (not found)
    (setq result (append result (list (cons key value))))
  )
  result
)

(defun swapp-state-read (/ data result pair value pos)
  (setq data (dictsearch (namedobjdict) *swapp-state-dictionary-key*))
  (setq result nil)
  (foreach pair data
    (if (= (car pair) 1)
      (progn
        (setq value (cdr pair))
        (setq pos (vl-string-search "=" value))
        (if pos
          (setq result
            (append
              result
              (list
                (cons
                  (substr value 1 pos)
                  (substr value (+ pos 2))
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

(defun swapp-state-write (items / dict old record data pair added)
  (setq dict (namedobjdict))
  (setq old (dictsearch dict *swapp-state-dictionary-key*))
  (if old
    (dictremove dict *swapp-state-dictionary-key*)
  )
  (setq data
    (list
      '(0 . "XRECORD")
      '(100 . "AcDbXrecord")
      '(280 . 1)
      (cons 1 (strcat "VERSION=" *swapp-version*))
    )
  )
  (foreach pair items
    (if (not (equal (strcase (car pair)) "VERSION"))
      (setq data (append data (list (cons 1 (strcat (car pair) "=" (cdr pair))))))
    )
  )
  (setq record (entmakex data))
  (if record
    (progn
      (setq added (dictadd dict *swapp-state-dictionary-key* record))
      (if added T nil)
    )
    nil
  )
)

(defun swapp-state-value (key / pair)
  (setq pair (assoc key (swapp-state-read)))
  (if pair (cdr pair) nil)
)

(defun swapp-state-set (key value / items)
  (setq items (swapp-state-read))
  (swapp-state-write (swapp-alist-put items key value))
)

(defun swapp-string-starts-ci-p (text prefix / text-length prefix-length)
  (setq text (if text text ""))
  (setq prefix (if prefix prefix ""))
  (setq text-length (strlen text))
  (setq prefix-length (strlen prefix))
  (and
    (<= prefix-length text-length)
    (equal (strcase (substr text 1 prefix-length)) (strcase prefix))
  )
)

(defun swapp-state-replace-prefix (prefix replacements / items result pair replacement)
  (setq items (swapp-state-read))
  (setq result nil)
  (foreach pair items
    (if (not (swapp-string-starts-ci-p (car pair) prefix))
      (setq result (append result (list pair)))
    )
  )
  (foreach replacement replacements
    (setq result (swapp-alist-put result (car replacement) (cdr replacement)))
  )
  (swapp-state-write result)
)

(defun swapp-replace-all (text old new / pos)
  (setq text (if text text ""))
  (while (setq pos (vl-string-search old text))
    (setq text
      (strcat
        (substr text 1 pos)
        new
        (substr text (+ pos (strlen old) 1))
      )
    )
  )
  text
)

(defun swapp-state-field-encode (value / text)
  (setq text (if value value ""))
  (setq text (swapp-replace-all text "%" "%25"))
  (setq text (swapp-replace-all text "|" "%7C"))
  (setq text (swapp-replace-all text "=" "%3D"))
  (setq text (swapp-replace-all text "\r" "%0D"))
  (setq text (swapp-replace-all text "\n" "%0A"))
  text
)

(defun swapp-state-field-decode (value / text)
  (setq text (if value value ""))
  (setq text (swapp-replace-all text "%0A" "\n"))
  (setq text (swapp-replace-all text "%0D" "\r"))
  (setq text (swapp-replace-all text "%3D" "="))
  (setq text (swapp-replace-all text "%7C" "|"))
  (setq text (swapp-replace-all text "%25" "%"))
  text
)

(defun swapp-string-split (text separator / result rest pos)
  (setq result nil)
  (setq rest (if text text ""))
  (while (setq pos (vl-string-search separator rest))
    (setq result (append result (list (substr rest 1 pos))))
    (setq rest (substr rest (+ pos (strlen separator) 1)))
  )
  (append result (list rest))
)

(defun swapp-index-text (index)
  (strcat
    (if (< index 100) "0" "")
    (if (< index 10) "0" "")
    (itoa index)
  )
)

(defun swapp-save-current (/ result)
  (setq result (vl-catch-all-apply 'vla-Save (list (swapp-doc))))
  (not (vl-catch-all-error-p result))
)

(defun swapp-near (a b tolerance)
  (and (numberp a) (numberp b) (<= (abs (- (float a) (float b))) tolerance))
)

;;; Command-scoped read cache. It never survives a drawing mutation.
(defun swapp-read-cache-begin ()
  (setq *swapp-read-cache-enabled* T)
  (setq *swapp-read-cache-values* nil)
  (setq *swapp-read-cache-start-ms* (getvar "DATE"))
  (setq *swapp-read-cache-hit-count* 0)
  (setq *swapp-read-cache-miss-count* 0)
  (swcad-title-read-scan-cache-begin)
  T
)

(defun swapp-read-cache-fetch (key fn args / pair value)
  (setq pair (if *swapp-read-cache-enabled* (assoc key *swapp-read-cache-values*) nil))
  (if pair
    (progn
      (setq *swapp-read-cache-hit-count* (1+ *swapp-read-cache-hit-count*))
      (cdr pair)
    )
    (progn
      (setq value (apply fn args))
      (if *swapp-read-cache-enabled*
        (progn
          (setq *swapp-read-cache-miss-count* (1+ *swapp-read-cache-miss-count*))
          (setq *swapp-read-cache-values* (append *swapp-read-cache-values* (list (cons key value))))
        )
      )
      value
    )
  )
)

(defun swapp-read-cache-seed (key value / pair)
  (if *swapp-read-cache-enabled*
    (progn
      (setq pair (assoc key *swapp-read-cache-values*))
      (if pair
        (setq *swapp-read-cache-values*
          (subst (cons key value) pair *swapp-read-cache-values*)
        )
        (setq *swapp-read-cache-values*
          (append *swapp-read-cache-values* (list (cons key value)))
        )
      )
    )
  )
  value
)

(defun swapp-read-cache-end (/ now elapsed)
  (swcad-title-read-scan-cache-end)
  (setq now (getvar "DATE"))
  (setq elapsed
    (if (numberp *swapp-read-cache-start-ms*)
      (fix (+ 0.5 (* 86400000.0 (- now *swapp-read-cache-start-ms*))))
      0
    )
  )
  (if (< elapsed 0) (setq elapsed 0))
  (setq *swapp-read-cache-last-elapsed-ms* elapsed)
  (setq *swapp-read-cache-last-hit-count* *swapp-read-cache-hit-count*)
  (setq *swapp-read-cache-last-miss-count* *swapp-read-cache-miss-count*)
  (setq *swapp-read-cache-last-title-insert-scans* (swcad-title-read-scan-stat "physical-insert-scans"))
  (setq *swapp-read-cache-last-title-insert-cache-hits* (swcad-title-read-scan-stat "insert-cache-hits"))
  (if *swapp-command-performance-active*
    (progn
      (setq *swapp-command-performance-read-ms* (+ *swapp-command-performance-read-ms* elapsed))
      (setq *swapp-command-performance-cache-hits* (+ *swapp-command-performance-cache-hits* *swapp-read-cache-hit-count*))
      (setq *swapp-command-performance-cache-misses* (+ *swapp-command-performance-cache-misses* *swapp-read-cache-miss-count*))
      (setq *swapp-command-performance-title-insert-scans* (+ *swapp-command-performance-title-insert-scans* *swapp-read-cache-last-title-insert-scans*))
      (setq *swapp-command-performance-title-insert-cache-hits* (+ *swapp-command-performance-title-insert-cache-hits* *swapp-read-cache-last-title-insert-cache-hits*))
    )
  )
  (setq *swapp-read-cache-enabled* nil)
  (setq *swapp-read-cache-values* nil)
  (setq *swapp-read-cache-start-ms* nil)
  T
)

(defun swapp-command-performance-begin ()
  (setq *swapp-command-performance-active* T)
  (setq *swapp-command-performance-start-ms* (getvar "DATE"))
  (setq *swapp-command-performance-read-ms* 0)
  (setq *swapp-command-performance-cache-hits* 0)
  (setq *swapp-command-performance-cache-misses* 0)
  (setq *swapp-command-performance-title-insert-scans* 0)
  (setq *swapp-command-performance-title-insert-cache-hits* 0)
  (setq *swapp-command-performance-title-insert-scan-base* *swcad-title-total-physical-insert-scans*)
  (setq *swapp-command-performance-title-insert-cache-hit-base* *swcad-title-total-insert-cache-hits*)
  T
)

(defun swapp-command-performance-end (label / now elapsed)
  (setq now (getvar "DATE"))
  (setq elapsed
    (if (numberp *swapp-command-performance-start-ms*)
      (fix (+ 0.5 (* 86400000.0 (- now *swapp-command-performance-start-ms*))))
      0
    )
  )
  (if (< elapsed 0) (setq elapsed 0))
  (setq *swapp-last-command-elapsed-ms* elapsed)
  (setq *swapp-last-command-read-ms* *swapp-command-performance-read-ms*)
  (setq *swapp-last-command-cache-hits* *swapp-command-performance-cache-hits*)
  (setq *swapp-last-command-cache-misses* *swapp-command-performance-cache-misses*)
  (setq *swapp-last-command-title-insert-scans*
    (- *swcad-title-total-physical-insert-scans* *swapp-command-performance-title-insert-scan-base*)
  )
  (setq *swapp-last-command-title-insert-cache-hits*
    (- *swcad-title-total-insert-cache-hits* *swapp-command-performance-title-insert-cache-hit-base*)
  )
  (setq *swapp-command-performance-active* nil)
  (setq *swapp-command-performance-start-ms* nil)
  (princ
    (strcat
      "\n성능 계측 [" label "]: 전체=" (itoa elapsed) "ms"
      ", 읽기=" (itoa *swapp-last-command-read-ms*) "ms"
      ", 인벤토리 적중/생성=" (itoa *swapp-last-command-cache-hits*) "/" (itoa *swapp-last-command-cache-misses*)
      ", INSERT 전역 스캔=" (itoa *swapp-last-command-title-insert-scans*)
      ", 재사용=" (itoa *swapp-last-command-title-insert-cache-hits*)
    )
  )
  elapsed
)

(defun swapp-cached-top-xref-references ()
  (swapp-read-cache-fetch "TOP_XREFS" 'swapp-top-xref-references nil)
)

(defun swapp-cached-sheet-wrapper-records ()
  (swapp-read-cache-fetch "SHEET_WRAPPERS" 'swapp-sheet-wrapper-status-records nil)
)

(defun swapp-cached-title-evidence ()
  (swapp-read-cache-fetch "TITLE_EVIDENCE" 'swapp-title-evidence nil)
)

(defun swapp-cached-top-dimension-count ()
  (swapp-read-cache-fetch "TOP_DIMENSION_COUNT" 'swapp-top-dimension-count nil)
)

(defun swapp-cached-layout-names ()
  (swapp-read-cache-fetch "LAYOUT_NAMES" 'swapp-layout-owned-names nil)
)

(defun swapp-cached-resource-cleanup-verify ()
  (swapp-read-cache-fetch "RESOURCE_CLEANUP_VERIFY" 'swapp-resource-cleanup-verify nil)
)

;;; ---------------------------
;;; XREF discovery and materialization
;;; ---------------------------

(defun swapp-object-name (object)
  (swapp-safe 'vla-get-ObjectName (list object))
)

(defun swapp-block-reference-p (object / name)
  (setq name (swapp-object-name object))
  (if (and name (vl-string-search "BLOCKREFERENCE" (strcase name))) T nil)
)

(defun swapp-dimension-p (object / name)
  (setq name (swapp-object-name object))
  (if (and name (vl-string-search "DIMENSION" (strcase name))) T nil)
)

(defun swapp-reference-name (reference / name)
  (setq name (swapp-safe 'vla-get-Name (list reference)))
  (if name name (swapp-safe 'vla-get-EffectiveName (list reference)))
)

(defun swapp-block-definition (name / blocks)
  (if name
    (progn
      (setq blocks (vla-get-Blocks (swapp-doc)))
      (swapp-safe 'vla-Item (list blocks name))
    )
    nil
  )
)

(defun swapp-xref-definition-p (block / value)
  (setq value (if block (swapp-safe 'vla-get-IsXRef (list block)) nil))
  (= value :vlax-true)
)

(defun swapp-top-xref-references (/ result object name block)
  (setq result nil)
  (foreach object (swapp-model-insert-objects)
    (setq name (swapp-reference-name object))
    (setq block (swapp-block-definition name))
    (if (swapp-xref-definition-p block)
      (setq result (cons object result))
    )
  )
  (reverse result)
)

(defun swapp-xref-definition-count (/ count block)
  (setq count 0)
  (foreach block (swapp-collection-items (vla-get-Blocks (swapp-doc)))
    (if (swapp-xref-definition-p block) (setq count (1+ count)))
  )
  count
)

(defun swapp-unique-reference-names (references / result reference name upper)
  (setq result nil)
  (foreach reference references
    (setq name (swapp-reference-name reference))
    (setq upper (if name (strcase name) ""))
    (if (and name (not (member upper result)))
      (setq result (cons upper result))
    )
  )
  result
)

(defun swapp-object-bbox4 (object / result minpt maxpt minlist maxlist)
  (setq result (if object (vl-catch-all-apply 'vla-GetBoundingBox (list object 'minpt 'maxpt)) nil))
  (if (or (not object) (vl-catch-all-error-p result))
    nil
    (progn
      (setq minlist (vlax-safearray->list minpt))
      (setq maxlist (vlax-safearray->list maxpt))
      (list (car minlist) (cadr minlist) (car maxlist) (cadr maxlist))
    )
  )
)

(defun swapp-bbox4-window (bbox)
  (if bbox
    (list
      (list (car bbox) (cadr bbox) 0.0)
      (list (caddr bbox) (cadddr bbox) 0.0)
    )
    nil
  )
)

(defun swapp-object-handle (object / value)
  (setq value (if object (swapp-safe 'vla-get-Handle (list object)) nil))
  (if value value "")
)

(defun swapp-xref-definition-path (block / value)
  (setq value (if block (swapp-safe 'vla-get-Path (list block)) nil))
  (if (or (not (= (type value) 'STR)) (= (strlen (vl-string-trim " \t\r\n" value)) 0))
    (setq value (if block (swapp-safe 'vla-get-XRefPath (list block)) nil))
  )
  (if (= (type value) 'STR) value "")
)

(defun swapp-source-stem-from-path-or-name (path reference-name / raw base)
  (setq raw (vl-string-trim " \t\r\n" (if (> (strlen path) 0) path reference-name)))
  (setq base (if (> (strlen raw) 0) (swapp-safe 'vl-filename-base (list raw)) nil))
  (if (and base (> (strlen (vl-string-trim " \t\r\n" base)) 0))
    (vl-string-trim " \t\r\n" base)
    raw
  )
)

;;; Source sheet record: (order stem reference-name reference-handle bbox4).
(defun swapp-source-sheet-record-from-reference (reference / name block path stem bbox)
  (setq name (swapp-reference-name reference))
  (setq block (swapp-block-definition name))
  (setq path (swapp-xref-definition-path block))
  (setq stem (swapp-source-stem-from-path-or-name path (if name name "")))
  (setq bbox (swapp-object-bbox4 reference))
  (if (and bbox (> (strlen stem) 0))
    (list 0 stem (if name name "") (swapp-object-handle reference) bbox)
    nil
  )
)

(defun swapp-source-sheet-records-from-references (references / sortable reference record window sorted result item index)
  (setq sortable nil)
  (foreach reference references
    (setq record (swapp-source-sheet-record-from-reference reference))
    (setq window (if record (swapp-bbox4-window (nth 4 record)) nil))
    (if window (setq sortable (append sortable (list (cons record window)))))
  )
  (setq sorted (gsla-sort-windows sortable))
  (setq result nil)
  (setq index 1)
  (foreach item sorted
    (setq record (car item))
    (setq result
      (append
        result
        (list
          (list index (nth 1 record) (nth 2 record) (nth 3 record) (nth 4 record))
        )
      )
    )
    (setq index (1+ index))
  )
  result
)

(defun swapp-source-sheet-record-serialize (record / bbox)
  (setq bbox (nth 4 record))
  (strcat
    (itoa (car record)) "|"
    (swapp-state-field-encode (nth 1 record)) "|"
    (swapp-state-field-encode (nth 2 record)) "|"
    (swapp-state-field-encode (nth 3 record)) "|"
    (rtos (car bbox) 2 8) "|"
    (rtos (cadr bbox) 2 8) "|"
    (rtos (caddr bbox) 2 8) "|"
    (rtos (cadddr bbox) 2 8)
  )
)

(defun swapp-source-sheet-record-parse (text / fields)
  (setq fields (swapp-string-split text "|"))
  (if (>= (length fields) 8)
    (list
      (atoi (nth 0 fields))
      (swapp-state-field-decode (nth 1 fields))
      (swapp-state-field-decode (nth 2 fields))
      (swapp-state-field-decode (nth 3 fields))
      (list
        (atof (nth 4 fields))
        (atof (nth 5 fields))
        (atof (nth 6 fields))
        (atof (nth 7 fields))
      )
    )
    nil
  )
)

(defun swapp-source-sheet-records-write (records / replacements record index)
  (setq replacements
    (list
      (cons "SOURCE_SHEET_STATUS" "CAPTURED_BEFORE_BIND")
      (cons "SOURCE_SHEET_COUNT" (itoa (length records)))
    )
  )
  (setq index 1)
  (foreach record records
    (setq replacements
      (append
        replacements
        (list
          (cons
            (strcat *swapp-source-state-prefix* (swapp-index-text index))
            (swapp-source-sheet-record-serialize record)
          )
        )
      )
    )
    (setq index (1+ index))
  )
  (swapp-state-replace-prefix *swapp-source-state-prefix* replacements)
)

(defun swapp-source-sheet-records-read (/ count index text record result)
  (setq count (atoi (if (swapp-state-value "SOURCE_SHEET_COUNT") (swapp-state-value "SOURCE_SHEET_COUNT") "0")))
  (setq index 1)
  (setq result nil)
  (while (<= index count)
    (setq text (swapp-state-value (strcat *swapp-source-state-prefix* (swapp-index-text index))))
    (setq record (if text (swapp-source-sheet-record-parse text) nil))
    (if record (setq result (append result (list record))))
    (setq index (1+ index))
  )
  result
)

(defun swapp-print-source-sheet-records (records limit / index record bbox)
  (princ (strcat "\n원본 XREF 시트 메타데이터: " (itoa (length records)) "개"))
  (setq index 1)
  (foreach record records
    (if (<= index limit)
      (progn
        (setq bbox (nth 4 record))
        (princ
          (strcat
            "\n  #" (swapp-index-text index)
            " 파일=" (nth 1 record)
            " 범위=(" (rtos (car bbox) 2 3) ", " (rtos (cadr bbox) 2 3) ")-("
            (rtos (caddr bbox) 2 3) ", " (rtos (cadddr bbox) 2 3) ")"
          )
        )
      )
    )
    (setq index (1+ index))
  )
  records
)

(defun swapp-target-title-reference-name-p (name / upper)
  (setq upper (if name (strcase name) ""))
  (if (vl-string-search "DR_TITLEA_3RD" upper) T nil)
)

(defun swapp-target-frame-reference-name-p (name / upper)
  (setq upper (if name (strcase name) ""))
  (if
    (or
    (vl-string-search "DR_A1_OUTLINE" upper)
    (vl-string-search "DR_A2_OUTLINE" upper)
    (vl-string-search "DR_A3_OUTLINE" upper)
    (vl-string-search "DR_A4_OUTLINE" upper)
  )
    T
    nil
  )
)

(defun swapp-target-reference-name-p (name)
  (or
    (swapp-target-title-reference-name-p name)
    (swapp-target-frame-reference-name-p name)
  )
)

(defun swapp-reference-ename (reference)
  (swapp-safe 'vlax-vla-object->ename (list reference))
)

(defun swapp-native-target-reference-p (reference / ename kinds)
  (if (swapp-target-reference-name-p (swapp-reference-name reference))
    (progn
      (setq ename (swapp-reference-ename reference))
      (setq kinds (if ename (swcad-title-native-link-target-kinds ename) nil))
      (if (swcad-title-internal-native-link-kinds-p kinds) T nil)
    )
    nil
  )
)

(setq *swapp-dimension-count-cache* nil)

(defun swapp-block-expandable-dimension-count (block-name stack / upper cached block total child child-name)
  (setq upper (if block-name (strcase block-name) ""))
  (cond
    ((or (= upper "") (member upper stack) (swapp-target-reference-name-p block-name)) 0)
    ((setq cached (assoc upper *swapp-dimension-count-cache*)) (cdr cached))
    (T
      (setq total 0)
      (setq block (swapp-block-definition block-name))
      (if block
        (foreach child (swapp-collection-items block)
          (cond
            ((swapp-dimension-p child)
              (setq total (1+ total))
            )
            ((swapp-block-reference-p child)
              (setq child-name (swapp-reference-name child))
              (setq total
                (+ total (swapp-block-expandable-dimension-count child-name (cons upper stack)))
              )
            )
          )
        )
      )
      (setq *swapp-dimension-count-cache*
        (cons (cons upper total) *swapp-dimension-count-cache*)
      )
      total
    )
  )
)

(defun swapp-reference-expandable-dimension-count (reference / name block)
  (setq name (swapp-reference-name reference))
  (setq block (swapp-block-definition name))
  (if
    (and
      block
      (not (swapp-target-reference-name-p name))
    )
    (swapp-block-expandable-dimension-count name nil)
    0
  )
)

(defun swapp-references-expandable-dimension-count (references / total reference)
  (setq *swapp-dimension-count-cache* nil)
  (setq total 0)
  (foreach reference references
    (setq total (+ total (swapp-reference-expandable-dimension-count reference)))
  )
  total
)

(defun swapp-model-expandable-dimension-count (/ references)
  (setq references (swapp-model-insert-objects))
  (swapp-references-expandable-dimension-count references)
)

(defun swapp-top-dimension-container-references (/ result object name block count)
  (setq *swapp-dimension-count-cache* nil)
  (setq result nil)
  (foreach object (swapp-model-insert-objects)
    (setq name (swapp-reference-name object))
    (setq block (swapp-block-definition name))
    (setq count
      (if (and block (not (swapp-xref-definition-p block)))
        (swapp-reference-expandable-dimension-count object)
        0
      )
    )
    (if (> count 0)
      (setq result (append result (list object)))
    )
  )
  result
)

(defun swapp-explode-dimension-containers (/ references rounds exposed count success)
  (setq references (swapp-top-dimension-container-references))
  (setq rounds 0)
  (setq exposed 0)
  (setq success T)
  (while (and success references (< rounds 32))
    (setq rounds (1+ rounds))
    (foreach reference references
      (if success
        (progn
          (setq count (swapp-explode-reference reference))
          (if count
            (setq exposed (+ exposed count))
            (setq success nil)
          )
        )
      )
    )
    (if success
      (progn
        (vla-Regen (swapp-doc) 1)
        (setq references (swapp-top-dimension-container-references))
      )
    )
  )
  (if (and success (not references))
    (list
      (cons "objects" exposed)
      (cons "rounds" rounds)
    )
    nil
  )
)

(setq *swapp-scan-visited* nil)
(setq *swapp-scan-dimensions* 0)
(setq *swapp-scan-target-references* 0)
(setq *swapp-scan-target-frame-references* 0)
(setq *swapp-scan-target-title-references* 0)

(defun swapp-scan-items-sheet-wrapper-p (items / child child-name frame-found title-found)
  (setq frame-found nil)
  (setq title-found nil)
  (foreach child items
    (if
      (and
        (not (and frame-found title-found))
        (swapp-block-reference-p child)
      )
      (progn
        (setq child-name (swapp-reference-name child))
        (if (swapp-target-frame-reference-name-p child-name)
          (setq frame-found T)
        )
        (if (swapp-target-title-reference-name-p child-name)
          (setq title-found T)
        )
      )
    )
  )
  (and frame-found title-found)
)

(defun swapp-scan-object (object stack inside-sheet-wrapper depth / block-name upper block children child child-inside-wrapper)
  (if (swapp-block-reference-p object)
    (progn
      (setq block-name (swapp-reference-name object))
      (setq upper (if block-name (strcase block-name) ""))
      (if
        (and
          (not inside-sheet-wrapper)
          (swapp-target-reference-name-p block-name)
        )
        (progn
          (setq *swapp-scan-target-references* (1+ *swapp-scan-target-references*))
          (if (swapp-target-frame-reference-name-p block-name)
            (setq *swapp-scan-target-frame-references* (1+ *swapp-scan-target-frame-references*))
          )
          (if (swapp-target-title-reference-name-p block-name)
            (setq *swapp-scan-target-title-references* (1+ *swapp-scan-target-title-references*))
          )
        )
      )
      (if
        (and
          block-name
          (not (member upper stack))
          (not (member upper *swapp-scan-visited*))
        )
        (progn
          (setq *swapp-scan-visited* (cons upper *swapp-scan-visited*))
          (setq block (swapp-block-definition block-name))
          (if block
            (progn
              (setq children (swapp-collection-items block))
              (setq child-inside-wrapper
                (or
                  inside-sheet-wrapper
                  (and
                    (= depth 1)
                    (not (swapp-xref-definition-p block))
                    (swapp-scan-items-sheet-wrapper-p children)
                  )
                )
              )
              (foreach child children
                (swapp-scan-object child (cons upper stack) child-inside-wrapper (1+ depth))
              )
            )
          )
        )
      )
    )
  )
)

(defun swapp-xref-deep-evidence (references / reference dimension-count)
  (setq dimension-count (swapp-references-expandable-dimension-count references))
  (setq *swapp-scan-dimensions* 0)
  (setq *swapp-scan-target-references* 0)
  (setq *swapp-scan-target-frame-references* 0)
  (setq *swapp-scan-target-title-references* 0)
  (foreach reference references
    (setq *swapp-scan-visited* nil)
    (swapp-scan-object reference nil nil 0)
  )
  (list
    (cons "dimensions" dimension-count)
    (cons "target-references" *swapp-scan-target-references*)
    (cons "target-frame-references" *swapp-scan-target-frame-references*)
    (cons "target-title-references" *swapp-scan-target-title-references*)
  )
)

(defun swapp-evidence-value (evidence key)
  (cdr (assoc key evidence))
)

(defun swapp-reference-transform-supported-p (reference / sx sy sz rotation)
  (setq sx (swapp-safe 'vla-get-XScaleFactor (list reference)))
  (setq sy (swapp-safe 'vla-get-YScaleFactor (list reference)))
  (setq sz (swapp-safe 'vla-get-ZScaleFactor (list reference)))
  (setq rotation (swapp-safe 'vla-get-Rotation (list reference)))
  (and
    (swapp-near sx 1.0 *swapp-transform-tolerance*)
    (swapp-near sy 1.0 *swapp-transform-tolerance*)
    (swapp-near sz 1.0 *swapp-transform-tolerance*)
    (swapp-near rotation 0.0 *swapp-transform-tolerance*)
  )
)

(defun swapp-top-dimension-count (/ ss)
  (setq ss (ssget "_X" (list '(0 . "DIMENSION") (cons 410 "Model"))))
  (if ss (sslength ss) 0)
)

(defun swapp-model-bbox (/ object result mn mx pmin pmax low high)
  (setq low nil)
  (setq high nil)
  (foreach object (swapp-collection-items (swapp-model))
    (setq result (vl-catch-all-apply 'vla-getBoundingBox (list object 'mn 'mx)))
    (if (not (vl-catch-all-error-p result))
      (progn
        (setq pmin (vlax-safearray->list mn))
        (setq pmax (vlax-safearray->list mx))
        (if low
          (progn
            (setq low (list (min (car low) (car pmin)) (min (cadr low) (cadr pmin)) 0.0))
            (setq high (list (max (car high) (car pmax)) (max (cadr high) (cadr pmax)) 0.0))
          )
          (progn
            (setq low pmin)
            (setq high pmax)
          )
        )
      )
    )
  )
  (if low (list low high) nil)
)

(defun swapp-bbox-near-p (first second /)
  (and
    first second
    (swapp-near (car (car first)) (car (car second)) *swapp-geometry-tolerance*)
    (swapp-near (cadr (car first)) (cadr (car second)) *swapp-geometry-tolerance*)
    (swapp-near (car (cadr first)) (car (cadr second)) *swapp-geometry-tolerance*)
    (swapp-near (cadr (cadr first)) (cadr (cadr second)) *swapp-geometry-tolerance*)
  )
)

(defun swapp-explode-reference (reference / result objects deleted)
  (setq result (vl-catch-all-apply 'vla-Explode (list reference)))
  (if (vl-catch-all-error-p result)
    nil
    (progn
      (setq objects (vlax-safearray->list (vlax-variant-value result)))
      (setq deleted (vl-catch-all-apply 'vla-Delete (list reference)))
      (if (and objects (not (vl-catch-all-error-p deleted))) (length objects) nil)
    )
  )
)

(defun swapp-sheet-wrapper-definition-evidence (name / block child child-name frame-count title-count native-target-count dimension-count object-count)
  (setq block (swapp-block-definition name))
  (if
    (and
      block
      (not (swapp-xref-definition-p block))
      (not (swapp-target-reference-name-p name))
    )
    (progn
      (setq frame-count 0)
      (setq title-count 0)
      (setq native-target-count 0)
      (setq dimension-count 0)
      (setq object-count 0)
      (foreach child (swapp-collection-items block)
        (setq object-count (1+ object-count))
        (if (swapp-dimension-p child)
          (setq dimension-count (1+ dimension-count))
        )
        (if (swapp-block-reference-p child)
          (progn
            (setq child-name (swapp-reference-name child))
            (if (swapp-native-target-reference-p child)
              (setq native-target-count (1+ native-target-count))
            )
            (if (swapp-target-frame-reference-name-p child-name)
              (setq frame-count (1+ frame-count))
            )
            (if (swapp-target-title-reference-name-p child-name)
              (setq title-count (1+ title-count))
            )
          )
        )
      )
      (if (and (> frame-count 0) (> title-count 0))
        (list
          (cons "frames" frame-count)
          (cons "titles" title-count)
          (cons "native-targets" native-target-count)
          (cons "dimensions" dimension-count)
          (cons "objects" object-count)
        )
        nil
      )
    )
    nil
  )
)

(defun swapp-sheet-wrapper-record-from-evidence (reference name evidence)
  (if evidence
    (append
      (list
        (cons "reference" reference)
        (cons "name" name)
      )
      evidence
      (list (cons "transform-supported" (swapp-reference-transform-supported-p reference)))
    )
    nil
  )
)

(defun swapp-sheet-wrapper-record (reference / name evidence)
  (setq name (swapp-reference-name reference))
  (setq evidence (swapp-sheet-wrapper-definition-evidence name))
  (swapp-sheet-wrapper-record-from-evidence reference name evidence)
)

(defun swapp-sheet-wrapper-records (/ result definition-cache object name upper pair evidence record)
  (setq result nil)
  (setq definition-cache nil)
  (foreach object (swapp-model-insert-objects)
    (setq name (swapp-reference-name object))
    (setq upper (if name (strcase name) ""))
    (setq pair (assoc upper definition-cache))
    (if pair
      (setq evidence (cdr pair))
      (progn
        (setq evidence (swapp-sheet-wrapper-definition-evidence name))
        (setq definition-cache (cons (cons upper evidence) definition-cache))
      )
    )
    (setq record (swapp-sheet-wrapper-record-from-evidence object name evidence))
    (if record (setq result (append result (list record))))
  )
  result
)

(defun swapp-sheet-wrapper-value (record key)
  (cdr (assoc key record))
)

(defun swapp-sheet-wrapper-status-records ()
  (swapp-sheet-wrapper-records)
)

(defun swapp-sheet-wrapper-direct-dimension-count (records / total record)
  (setq total 0)
  (foreach record records
    (setq total (+ total (swapp-sheet-wrapper-value record "dimensions")))
  )
  total
)

(defun swapp-sheet-wrapper-transforms-supported-p (records / result record)
  (setq result T)
  (foreach record records
    (if (not (swapp-sheet-wrapper-value record "transform-supported"))
      (setq result nil)
    )
  )
  result
)

(defun swapp-sheet-wrapper-native-free-p (records / result record)
  (setq result T)
  (foreach record records
    (if (> (swapp-sheet-wrapper-value record "native-targets") 0)
      (setq result nil)
    )
  )
  result
)

(defun swapp-explode-sheet-wrapper-records (records / result record count)
  (setq result 0)
  (foreach record records
    (if (numberp result)
      (progn
        (setq count
          (swapp-explode-reference
            (swapp-sheet-wrapper-value record "reference")
          )
        )
        (if count
          (setq result (+ result count))
          (setq result nil)
        )
      )
    )
  )
  result
)

(defun swapp-materialize-sheet-wrappers (/ records direct-dimensions expandable-dimensions before-dimensions expected-dimensions before-bbox explode-count dimension-result dimension-exposed dimension-rounds after-records after-dimensions after-bbox summary source-titles source-frames success)
  (swapp-activate-model)
  (setq records (swapp-sheet-wrapper-records))
  (cond
    ((not records)
      (princ "\nSWCAD 시트 묶음: 분해할 중첩 시트 블록이 없습니다.")
      nil
    )
    ((not (swapp-sheet-wrapper-transforms-supported-p records))
      (princ "\n결과: BLOCKED_UNSUPPORTED_SHEET_WRAPPER_TRANSFORM")
      (princ "\n시트 묶음은 축척 1, 회전 0일 때만 자동 분해합니다.")
      nil
    )
    ((not (swapp-sheet-wrapper-native-free-p records))
      (princ "\n결과: BLOCKED_NATIVE_GMTITLE_SHEET_WRAPPER")
      (princ "\n시트 묶음 안에 실제 native GMTITLE 연결 데이터가 있어 자동 분해하지 않습니다.")
      nil
    )
    ((not (swcad-title-ensure-work-copy-for-mutation))
      (princ "\n결과: ABORT_WORKCOPY_NOT_CREATED")
      nil
    )
    (T
      (setq direct-dimensions (swapp-sheet-wrapper-direct-dimension-count records))
      (setq before-dimensions (swapp-top-dimension-count))
      (setq expandable-dimensions (swapp-model-expandable-dimension-count))
      (setq expected-dimensions (+ before-dimensions expandable-dimensions))
      (setq before-bbox (swapp-model-bbox))
      (princ "\n----- SWCAD 중첩 시트 묶음 1단계 분해 -----")
      (princ (strcat "\n시트 묶음: " (itoa (length records))))
      (princ (strcat "\n묶음 내부 직접 치수: " (itoa direct-dimensions)))
      (princ (strcat "\n내용 블록까지 포함한 변환 대상 치수: " (itoa expandable-dimensions)))
      (princ "\n정책: 도면 내용은 유지하고 바깥 시트 묶음 INSERT만 한 단계 분해합니다.")
      (setq explode-count (swapp-explode-sheet-wrapper-records records))
      (setq dimension-result
        (if (numberp explode-count) (swapp-explode-dimension-containers) nil)
      )
      (setq dimension-exposed (if dimension-result (swapp-evidence-value dimension-result "objects") 0))
      (setq dimension-rounds (if dimension-result (swapp-evidence-value dimension-result "rounds") 0))
      (vla-Regen (swapp-doc) 1)
      (setq after-records (swapp-sheet-wrapper-records))
      (setq after-dimensions (swapp-top-dimension-count))
      (setq after-bbox (swapp-model-bbox))
      (setq summary (swcad-title-fast-sheet-summary))
      (setq source-titles (swcad-title-fast-summary-value summary "source-title-count"))
      (setq source-frames (swcad-title-fast-summary-value summary "source-frame-count"))
      (setq success
        (and
          (numberp explode-count)
          dimension-result
          (= (length after-records) 0)
          (= after-dimensions expected-dimensions)
          (swapp-bbox-near-p before-bbox after-bbox)
          (> source-titles 0)
          (> source-frames 0)
        )
      )
      (princ (strcat "\n분해로 노출된 최상위 객체: " (itoa (if (numberp explode-count) explode-count 0))))
      (princ (strcat "\n치수 내용 블록 추가 분해: " (itoa dimension-exposed) " objects / " (itoa dimension-rounds) " rounds"))
      (princ (strcat "\n남은 시트 묶음: " (itoa (length after-records))))
      (princ (strcat "\n분해 후 최상위 치수: " (itoa after-dimensions)))
      (princ (strcat "\n분해 후 원본 표제란/도면틀: " (itoa source-titles) " / " (itoa source-frames)))
      (if success
        (progn
          (swapp-state-set "SHEET_WRAPPERS" "OK")
          (swapp-state-set "SHEET_WRAPPER_COUNT" (itoa (length records)))
          (swapp-state-set "DIMENSION_COUNT" (itoa after-dimensions))
          (swapp-state-set "SOURCE_FRAME_COUNT" (itoa source-frames))
          (swapp-save-current)
          (princ "\n결과: SWCAD_SHEET_WRAPPER_MATERIALIZE_OK")
          T
        )
        (progn
          (swapp-state-set "SHEET_WRAPPERS" "FAILED")
          (princ "\n결과: SWCAD_SHEET_WRAPPER_MATERIALIZE_FAILED")
          (princ "\n작업본에서 UNDO 후 상태를 확인하세요. 이 실패 상태에서는 GMTITLE 변환을 계속하지 마세요.")
          nil
        )
      )
    )
  )
)

(defun swapp-materialize-xrefs (/ references unique-names source-records xref-definition-count evidence expected-dimensions native-targets native-target-frames native-target-titles transforms-ok reference name block bind-result explode-count one-count wrapper-records wrapper-count wrapper-explode-count dimension-result dimension-exposed dimension-rounds after-wrapper-count before-bbox after-bbox after-xrefs after-dimensions summary source-titles source-frames success)
  (swapp-activate-model)
  (setq references (swapp-top-xref-references))
  (setq xref-definition-count (swapp-xref-definition-count))
  (cond
    ((not references)
      (princ "\nSWCAD XREF: 현재 모델 공간에 materialize할 XREF가 없습니다.")
      nil
    )
    (T
      (setq unique-names (swapp-unique-reference-names references))
      (setq source-records (swapp-source-sheet-records-from-references references))
      (setq evidence (swapp-xref-deep-evidence references))
      (setq expected-dimensions (swapp-evidence-value evidence "dimensions"))
      (setq native-targets (swapp-evidence-value evidence "target-references"))
      (setq native-target-frames (swapp-evidence-value evidence "target-frame-references"))
      (setq native-target-titles (swapp-evidence-value evidence "target-title-references"))
      (setq transforms-ok T)
      (foreach reference references
        (if (not (swapp-reference-transform-supported-p reference))
          (setq transforms-ok nil)
        )
      )
      (princ "\n----- SWCAD XREF materialize preflight -----")
      (princ (strcat "\n최상위 XREF 참조: " (itoa (length references))))
      (princ (strcat "\nXREF 정의: " (itoa xref-definition-count)))
      (princ (strcat "\nXREF 내부 치수: " (itoa expected-dimensions)))
      (princ (strcat "\nXREF 내부 native GMTITLE 참조: " (itoa native-targets)))
      (princ (strcat "\nXREF 내부 최상위 DR 도면틀/표제란: " (itoa native-target-frames) " / " (itoa native-target-titles)))
      (swapp-print-source-sheet-records source-records *swapp-layout-preview-limit*)
      (cond
        ((/= (length source-records) (length references))
          (princ "\n결과: BLOCKED_XREF_SOURCE_METADATA_INCOMPLETE")
          (princ "\nBIND 전에 일부 XREF의 파일명 또는 배치 범위를 읽지 못해 원본명 추적을 중단했습니다.")
          nil
        )
        ((/= xref-definition-count (length unique-names))
          (princ "\n결과: BLOCKED_NESTED_OR_UNREFERENCED_XREF")
          (princ "\n중첩 또는 최상위에 연결되지 않은 XREF가 있어 자동 결합하지 않습니다.")
          nil
        )
        ((and (> native-target-frames 0) (> native-target-titles 0))
          (princ "\n결과: BLOCKED_NATIVE_GMTITLE_XREF")
          (princ "\n이미 GMTITLE인 XREF는 BIND/EXPLODE 시 native 링크가 풀리므로 자동 변환하지 않습니다.")
          nil
        )
        ((not transforms-ok)
          (princ "\n결과: BLOCKED_UNSUPPORTED_XREF_TRANSFORM")
          (princ "\nMVP는 축척 1, 회전 0인 XREF만 지원합니다. 원본 배치값은 변경하지 않았습니다.")
          nil
        )
        ((not (swcad-title-ensure-work-copy-for-mutation))
          (princ "\n결과: ABORT_WORKCOPY_NOT_CREATED")
          nil
        )
        ((not (swapp-source-sheet-records-write source-records))
          (princ "\n결과: BLOCKED_XREF_SOURCE_METADATA_WRITE_FAILED")
          (princ "\n작업본 DWG의 SWCAD_WORKFLOW_STATE에 원본 파일명과 좌표를 기록하지 못했습니다.")
          nil
        )
        (T
          (setq before-bbox (swapp-model-bbox))
          (setq success T)
          (foreach name unique-names
            (setq block (swapp-block-definition name))
            (setq bind-result (if block (vl-catch-all-apply 'vla-Bind (list block :vlax-false)) nil))
            (if (or (not block) (vl-catch-all-error-p bind-result))
              (setq success nil)
            )
          )
          (setq explode-count 0)
          (if success
            (foreach reference references
              (setq one-count (swapp-explode-reference reference))
              (if one-count
                (setq explode-count (+ explode-count one-count))
                (setq success nil)
              )
            )
          )
          (vla-Regen (swapp-doc) 1)
          (setq wrapper-records (swapp-sheet-wrapper-records))
          (setq wrapper-count (length wrapper-records))
          (setq wrapper-explode-count 0)
          (if (and success wrapper-records)
            (if
              (and
                (swapp-sheet-wrapper-transforms-supported-p wrapper-records)
                (swapp-sheet-wrapper-native-free-p wrapper-records)
              )
              (progn
                (setq wrapper-explode-count (swapp-explode-sheet-wrapper-records wrapper-records))
                (if (not (numberp wrapper-explode-count)) (setq success nil))
              )
              (setq success nil)
            )
          )
          (setq dimension-result (if success (swapp-explode-dimension-containers) nil))
          (if (not dimension-result) (setq success nil))
          (setq dimension-exposed (if dimension-result (swapp-evidence-value dimension-result "objects") 0))
          (setq dimension-rounds (if dimension-result (swapp-evidence-value dimension-result "rounds") 0))
          (vla-Regen (swapp-doc) 1)
          (setq after-xrefs (swapp-xref-definition-count))
          (setq after-wrapper-count (length (swapp-sheet-wrapper-records)))
          (setq after-dimensions (swapp-top-dimension-count))
          (setq after-bbox (swapp-model-bbox))
          (setq summary (swcad-title-fast-sheet-summary))
          (setq source-titles (swcad-title-fast-summary-value summary "source-title-count"))
          (setq source-frames (swcad-title-fast-summary-value summary "source-frame-count"))
          (setq success
            (and
              success
              (= after-xrefs 0)
              (= after-wrapper-count 0)
              (= after-dimensions expected-dimensions)
              (swapp-bbox-near-p before-bbox after-bbox)
              (> source-frames 0)
            )
          )
          (princ (strcat "\n분해된 최상위 객체: " (itoa explode-count)))
          (princ (strcat "\n추가로 분해한 시트 묶음: " (itoa wrapper-count)))
          (princ (strcat "\n시트 묶음에서 노출된 객체: " (itoa (if (numberp wrapper-explode-count) wrapper-explode-count 0))))
          (princ (strcat "\n치수 내용 블록 추가 분해: " (itoa dimension-exposed) " objects / " (itoa dimension-rounds) " rounds"))
          (princ (strcat "\n변환 후 XREF 정의: " (itoa after-xrefs)))
          (princ (strcat "\n변환 후 남은 시트 묶음: " (itoa after-wrapper-count)))
          (princ (strcat "\n변환 후 최상위 치수: " (itoa after-dimensions)))
          (princ (strcat "\n변환 후 원본 표제란/도면틀: " (itoa source-titles) " / " (itoa source-frames)))
          (if success
            (progn
              (swapp-state-set "MATERIALIZED" "OK")
              (swapp-state-set "XREF_COUNT" (itoa (length references)))
              (swapp-state-set "SHEET_WRAPPERS" "OK")
              (swapp-state-set "SHEET_WRAPPER_COUNT" (itoa wrapper-count))
              (swapp-state-set "DIMENSION_COUNT" (itoa after-dimensions))
              (swapp-state-set "SOURCE_FRAME_COUNT" (itoa source-frames))
              (swapp-save-current)
              (princ "\n결과: SWCAD_XREF_MATERIALIZE_OK")
              T
            )
            (progn
              (swapp-state-set "MATERIALIZED" "FAILED")
              (princ "\n결과: SWCAD_XREF_MATERIALIZE_FAILED")
              (princ "\n작업본에서 UNDO 후 상태를 다시 확인하세요. 원본/XREF 원본은 저장하지 않았습니다.")
              nil
            )
          )
        )
      )
    )
  )
)

;;; ---------------------------
;;; Module evidence and stages
;;; ---------------------------

(defun swapp-title-evidence (/ cache-owned summary sources frames titles pairs native-like record geometry overlap result)
  (setq cache-owned (not *swcad-title-read-scan-cache-enabled*))
  (if cache-owned (swcad-title-read-scan-cache-begin))
  (setq summary (swcad-title-fast-sheet-summary))
  (setq sources
    (+
      (swcad-title-fast-summary-value summary "source-title-count")
      (swcad-title-fast-summary-value summary "source-frame-count")
    )
  )
  (setq frames (swcad-title-frame-records))
  (setq titles (swcad-title-inserts-by-effective-name (swcad-title-target-title-block-name)))
  (setq pairs (swcad-title-target-gmtitle-pair-records-from frames titles))
  (setq native-like 0)
  (foreach record pairs
    (if (swcad-title-target-pair-native-like-p record)
      (setq native-like (1+ native-like))
    )
  )
  (setq geometry (swcad-title-target-frame-geometry-warning-count frames))
  (setq overlap (swcad-title-target-frame-overlap-warning-count frames))
  (setq result
    (list
      (cons "source-count" sources)
      (cons "target-title-count" (length titles))
      (cons "target-frame-count" (length frames))
      (cons "target-pair-count" (length pairs))
      (cons "native-like-count" native-like)
      (cons "geometry-warning-count" geometry)
      (cons "overlap-warning-count" overlap)
    )
  )
  (if cache-owned (swcad-title-read-scan-cache-end))
  result
)

(defun swapp-title-complete-p (evidence / frames)
  (setq frames (swapp-evidence-value evidence "target-frame-count"))
  (and
    (= (swapp-evidence-value evidence "source-count") 0)
    (> frames 0)
    (= (swapp-evidence-value evidence "target-title-count") frames)
    (= (swapp-evidence-value evidence "target-pair-count") frames)
    (= (swapp-evidence-value evidence "native-like-count") frames)
    (= (swapp-evidence-value evidence "geometry-warning-count") 0)
    (= (swapp-evidence-value evidence "overlap-warning-count") 0)
  )
)

(defun swapp-dimstyle-marked-p (/ state semantics)
  (setq state (swapp-state-value "DIMSTYLE"))
  (setq semantics (swapp-state-value "DIMENSION_SEMANTICS"))
  (or
    (and (equal state "OK") (equal semantics "PRESERVED"))
    (and (equal state "NO_DIMENSIONS") (equal semantics "NO_DIMENSIONS"))
  )
)

(defun swapp-frame-windows (/ records result record bbox)
  (setq records (swcad-title-frame-records))
  (setq result nil)
  (foreach record records
    (setq bbox (cadddr record))
    (if bbox
      (setq result
        (cons
          (cons
            (car record)
            (list
              (list (car bbox) (cadr bbox) 0.0)
              (list (caddr bbox) (cadddr bbox) 0.0)
            )
          )
          result
        )
      )
    )
  )
  (reverse result)
)

(defun swapp-name-member-ci-p (name names / found item)
  (setq found nil)
  (foreach item names
    (if (equal (strcase name) (strcase item)) (setq found T))
  )
  found
)

(defun swapp-string-lists-equal-ci-p (first second / ok)
  (setq ok (= (length first) (length second)))
  (while (and ok first second)
    (if (not (equal (strcase (car first)) (strcase (car second)))) (setq ok nil))
    (setq first (cdr first))
    (setq second (cdr second))
  )
  ok
)

(defun swapp-all-paper-layout-names (/ layouts layout name result)
  (setq layouts (vla-get-Layouts (swapp-doc)))
  (setq result nil)
  (vlax-for layout layouts
    (setq name (vla-get-Name layout))
    (if (not (equal (strcase name) "MODEL"))
      (setq result (append result (list name)))
    )
  )
  result
)

(defun swapp-legacy-layout-names (/ old names)
  (setq old *gsla-prefix*)
  (setq *gsla-prefix* *swapp-legacy-layout-prefix*)
  (setq names (gsla-generated-layout-names))
  (setq *gsla-prefix* old)
  names
)

(defun swapp-layout-owned-names (/ count index value result legacy)
  (setq count (atoi (if (swapp-state-value "LAYOUT_OWNED_COUNT") (swapp-state-value "LAYOUT_OWNED_COUNT") "0")))
  (setq index 1)
  (setq result nil)
  (while (<= index count)
    (setq value (swapp-state-value (strcat *swapp-layout-owned-state-prefix* (swapp-index-text index))))
    (if value (setq result (append result (list (swapp-state-field-decode value)))))
    (setq index (1+ index))
  )
  (if (and (not result) (equal (swapp-state-value "LAYOUT") "OK"))
    (progn
      (setq legacy (swapp-legacy-layout-names))
      (if legacy (setq result legacy))
    )
  )
  result
)

(defun swapp-layout-owned-names-write (names / replacements name index)
  (setq replacements (list (cons "LAYOUT_OWNED_COUNT" (itoa (length names)))))
  (setq index 1)
  (foreach name names
    (setq replacements
      (append
        replacements
        (list
          (cons
            (strcat *swapp-layout-owned-state-prefix* (swapp-index-text index))
            (swapp-state-field-encode name)
          )
        )
      )
    )
    (setq index (1+ index))
  )
  (swapp-state-replace-prefix *swapp-layout-owned-state-prefix* replacements)
)

(defun swapp-user-layout-names (/ owned result name)
  (setq owned (swapp-layout-owned-names))
  (setq result nil)
  (foreach name (swapp-all-paper-layout-names)
    (if (not (swapp-name-member-ci-p name owned))
      (setq result (append result (list name)))
    )
  )
  result
)

(defun swapp-layout-value-usable-p (value / upper)
  (setq value (vl-string-trim " \t\r\n" (if value value "")))
  (setq upper (strcase value))
  (and
    (> (strlen value) 0)
    (not (member upper '("-" "--" "XXX" "NONE" "<NONE>" "<없음>")))
  )
)

(defun swapp-file-stem-value (value / text base)
  (setq text (vl-string-trim " \t\r\n" (if value value "")))
  (setq base (if (> (strlen text) 0) (swapp-safe 'vl-filename-base (list text)) nil))
  (if (and base (> (strlen base) 0)) base text)
)

(defun swapp-clean-layout-base-name (value / name)
  (setq name (gsla-clean-layout-name (swapp-file-stem-value value)))
  (setq name (vl-string-trim " .\t\r\n" name))
  (if (> (strlen name) 200) (setq name (substr name 1 200)))
  name
)

(defun swapp-bbox4-center (bbox)
  (if bbox
    (list (/ (+ (car bbox) (caddr bbox)) 2.0) (/ (+ (cadr bbox) (cadddr bbox)) 2.0))
    nil
  )
)

(defun swapp-point-distance2 (first second / dx dy)
  (setq dx (- (car first) (car second)))
  (setq dy (- (cadr first) (cadr second)))
  (+ (* dx dx) (* dy dy))
)

(defun swapp-source-record-score (record frame-bbox / source-bbox overlap area)
  (setq source-bbox (nth 4 record))
  (setq overlap (swcad-title-bbox-overlap-box source-bbox frame-bbox))
  (setq area (if overlap (swcad-title-bbox-area overlap) 0.0))
  (if (> area 0.0)
    (+ 1000000000000.0 area)
    (- 0.0 (swapp-point-distance2 (swapp-bbox4-center source-bbox) (swapp-bbox4-center frame-bbox)))
  )
)

(defun swapp-best-source-record (records used-orders frame-bbox preferred-index / preferred best best-score score record)
  (setq preferred
    (if (and (> preferred-index 0) (<= preferred-index (length records)))
      (nth (1- preferred-index) records)
      nil
    )
  )
  (if (and preferred (not (member (car preferred) used-orders)))
    preferred
    (progn
      (setq best nil)
      (setq best-score nil)
      (foreach record records
        (if (not (member (car record) used-orders))
          (progn
            (setq score (swapp-source-record-score record frame-bbox))
            (if (or (not best-score) (> score best-score))
              (progn (setq best record) (setq best-score score))
            )
          )
        )
      )
      best
    )
  )
)

(defun swapp-title-pair-for-frame (frame pairs / found pair)
  (setq found nil)
  (foreach pair pairs
    (if (and (not found) (eq frame (cadr pair))) (setq found pair))
  )
  found
)

(defun swapp-count-alist-increment (items key / result pair found)
  (setq result nil)
  (setq found nil)
  (foreach pair items
    (if (equal (strcase (car pair)) (strcase key))
      (progn
        (setq result (append result (list (cons (car pair) (1+ (cdr pair))))))
        (setq found T)
      )
      (setq result (append result (list pair)))
    )
  )
  (if found result (append result (list (cons key 1))))
)

(defun swapp-count-alist-value (items key / pair)
  (setq pair (assoc (strcase key) items))
  (if pair (cdr pair) 0)
)

(defun swapp-layout-drawing-counts (pairs / result pair title object attrs value key)
  (setq result nil)
  (foreach pair pairs
    (setq title (car pair))
    (setq object (swcad-title-safe-vla-object title))
    (setq attrs (if object (swcad-title-title-attribute-pairs object) nil))
    (setq value (swcad-title-attr-value-by-tag attrs "GEN-TITLE-DWG{23}"))
    (setq key (strcase (swapp-file-stem-value value)))
    (if (> (strlen key) 0) (setq result (swapp-count-alist-increment result key)))
  )
  result
)

(defun swapp-bound-source-prefix (name / pos prefix upper)
  (setq name (if name name ""))
  (setq upper (strcase name))
  (setq pos (vl-string-search "$0$" upper))
  (setq prefix (if (and pos (> pos 0)) (vl-string-trim " \t\r\n" (substr name 1 pos)) ""))
  (if
    (or
      (< (strlen prefix) 3)
      (swapp-string-starts-ci-p prefix "*")
      (vl-string-search "DR_A1_OUTLINE" (strcase prefix))
      (vl-string-search "DR_A2_OUTLINE" (strcase prefix))
      (vl-string-search "DR_A3_OUTLINE" (strcase prefix))
      (vl-string-search "DR_A4_OUTLINE" (strcase prefix))
      (vl-string-search "DR_TITLEA_3RD" (strcase prefix))
      (vl-string-search "GENIUS_" (strcase prefix))
    )
    ""
    prefix
  )
)

;;; Bound source record: (source-prefix bbox4 reference-name).
(defun swapp-bound-source-records (/ result object name prefix bbox)
  (setq result nil)
  (foreach object (swapp-model-insert-objects)
    (setq name (swapp-reference-name object))
    (setq prefix (swapp-bound-source-prefix name))
    (setq bbox (if (> (strlen prefix) 0) (swapp-object-bbox4 object) nil))
    (if bbox (setq result (append result (list (list prefix bbox name)))))
  )
  result
)

(defun swapp-bound-source-score-add (scores prefix value / result pair found)
  (setq result nil)
  (setq found nil)
  (foreach pair scores
    (if (equal (strcase (car pair)) (strcase prefix))
      (progn
        (setq result (append result (list (cons (car pair) (+ (cdr pair) value)))))
        (setq found T)
      )
      (setq result (append result (list pair)))
    )
  )
  (if found result (append result (list (cons prefix value))))
)

(defun swapp-bound-source-for-frame (records frame-bbox / scores record bbox center overlap score best best-score pair)
  (setq scores nil)
  (foreach record records
    (setq bbox (nth 1 record))
    (setq center (swapp-bbox4-center bbox))
    (setq overlap (swcad-title-bbox-overlap-box bbox frame-bbox))
    (if
      (or
        (swcad-title-point-in-bbox-p center (swcad-title-expand-bbox frame-bbox 2.0))
        overlap
      )
      (progn
        (setq score (+ 1.0 (if overlap (swcad-title-bbox-area overlap) 0.0)))
        (setq scores (swapp-bound-source-score-add scores (car record) score))
      )
    )
  )
  (setq best "")
  (setq best-score nil)
  (foreach pair scores
    (if (or (not best-score) (> (cdr pair) best-score))
      (progn (setq best (car pair)) (setq best-score (cdr pair)))
    )
  )
  best
)

(defun swapp-layout-base-result (source-stem source-kind drawing file-no sheet frame / handle)
  (cond
    ((swapp-layout-value-usable-p source-stem) (list (swapp-clean-layout-base-name source-stem) source-kind))
    ((swapp-layout-value-usable-p drawing) (list (swapp-clean-layout-base-name drawing) "GMTITLE_FILE_NAME"))
    ((swapp-layout-value-usable-p file-no) (list (swapp-clean-layout-base-name file-no) "GMTITLE_FILE_NO"))
    ((swapp-layout-value-usable-p sheet) (list (swapp-clean-layout-base-name sheet) "GMTITLE_SHEET"))
    (T
      (setq handle (cdr (assoc 5 (entget frame))))
      (list (strcat "Sheet-" (if handle handle "unknown")) "FRAME_HANDLE_FALLBACK")
    )
  )
)

(defun swapp-layout-unique-name (base file-no sheet used / candidates candidate result suffix)
  (setq candidates (list base))
  (if (swapp-layout-value-usable-p file-no)
    (setq candidates (append candidates (list (swapp-clean-layout-base-name (strcat base " - " file-no)))))
  )
  (if (swapp-layout-value-usable-p sheet)
    (setq candidates (append candidates (list (swapp-clean-layout-base-name (strcat base " - " sheet)))))
  )
  (setq result nil)
  (foreach candidate candidates
    (if (and (not result) (> (strlen candidate) 0) (not (swapp-name-member-ci-p candidate used)))
      (setq result candidate)
    )
  )
  (if (not result)
    (progn
      (setq suffix 2)
      (setq candidate (strcat base "_" (itoa suffix)))
      (while (swapp-name-member-ci-p candidate used)
        (setq suffix (1+ suffix))
        (setq candidate (strcat base "_" (itoa suffix)))
      )
      (setq result candidate)
    )
  )
  result
)

;;; Layout plan item:
;;; (frame-ename window source-stem file-no sheet layout-name source-kind title-ename).
(defun swapp-layout-plan (/ frames sources preferred pairs drawing-counts bound-records used-source-orders used-names result index frame-item frame window frame-bbox source source-stem source-kind bound-source pair title title-object attrs drawing drawing-count file-no sheet base-result layout-name)
  (setq frames (gsla-sort-windows (swapp-frame-windows)))
  (setq sources (swapp-source-sheet-records-read))
  (setq preferred (if (= (length sources) (length frames)) T nil))
  (setq pairs (swcad-title-target-gmtitle-pair-records))
  (setq drawing-counts (swapp-layout-drawing-counts pairs))
  (setq bound-records (if sources nil (swapp-bound-source-records)))
  (setq used-source-orders nil)
  (setq used-names (swapp-user-layout-names))
  (setq result nil)
  (setq index 1)
  (foreach frame-item frames
    (setq frame (car frame-item))
    (setq window (cdr frame-item))
    (setq frame-bbox
      (list
        (car (car window)) (cadr (car window))
        (car (cadr window)) (cadr (cadr window))
      )
    )
    (setq source (swapp-best-source-record sources used-source-orders frame-bbox (if preferred index 0)))
    (if source (setq used-source-orders (append used-source-orders (list (car source)))))
    (setq source-stem (if source (nth 1 source) ""))
    (setq source-kind (if source "XREF_FILE" ""))
    (setq pair (swapp-title-pair-for-frame frame pairs))
    (setq title (if pair (car pair) nil))
    (setq title-object (if title (swcad-title-safe-vla-object title) nil))
    (setq attrs (if title-object (swcad-title-title-attribute-pairs title-object) nil))
    (setq drawing (swcad-title-attr-value-by-tag attrs "GEN-TITLE-DWG{23}"))
    (setq drawing-count (swapp-count-alist-value drawing-counts (strcase (swapp-file-stem-value drawing))))
    (setq file-no (swcad-title-attr-value-by-tag attrs "GEN-TITLE-NR{23}"))
    (setq sheet (swcad-title-attr-value-by-tag attrs "GEN-TITLE-SIZ{6.7}"))
    (setq bound-source (if source "" (swapp-bound-source-for-frame bound-records frame-bbox)))
    (if (and (not source) (swapp-layout-value-usable-p bound-source) (or (not (swapp-layout-value-usable-p drawing)) (> drawing-count 1)))
      (progn
        (setq source-stem bound-source)
        (setq source-kind "BOUND_BLOCK_PREFIX")
      )
    )
    (setq base-result (swapp-layout-base-result source-stem source-kind drawing file-no sheet frame))
    (setq layout-name (swapp-layout-unique-name (car base-result) file-no sheet used-names))
    (setq used-names (append used-names (list layout-name)))
    (setq result
      (append
        result
        (list (list frame window source-stem file-no sheet layout-name (cadr base-result) title))
      )
    )
    (setq index (1+ index))
  )
  result
)

(defun swapp-layout-plan-item-handle (item / ename data handle)
  (setq ename (car item))
  (setq data (if ename (entget ename) nil))
  (setq handle (if data (cdr (assoc 5 data)) nil))
  (if handle handle "<없음>")
)

(defun swapp-layout-coordinate-text (value)
  (if (numberp value) (rtos (float value) 2 4) "?")
)

(defun swapp-layout-signature-coordinate-text (value)
  (if (numberp value) (rtos (float value) 2 6) "?")
)

(defun swapp-layout-plan-coordinate-data (plan / result item win ll ur)
  (setq result "")
  (foreach item plan
    (setq win (cadr item))
    (setq ll (car win))
    (setq ur (cadr win))
    (setq result
      (strcat
        result
        "|" (swapp-layout-signature-coordinate-text (car ll))
        "," (swapp-layout-signature-coordinate-text (cadr ll))
        "," (swapp-layout-signature-coordinate-text (car ur))
        "," (swapp-layout-signature-coordinate-text (cadr ur))
        "|" (swapp-state-field-encode (nth 5 item))
        "|" (swapp-state-field-encode (nth 2 item))
      )
    )
  )
  result
)

(defun swapp-text-rolling-hash (text modulus seed / index value)
  (setq index 1)
  (setq value seed)
  (while (<= index (strlen text))
    (setq value (rem (+ (* value 257) (ascii (substr text index 1))) modulus))
    (setq index (1+ index))
  )
  value
)

(defun swapp-layout-plan-signature (plan / data)
  (setq data (swapp-layout-plan-coordinate-data plan))
  (strcat
    (itoa (length plan))
    ":" (itoa (swapp-text-rolling-hash data 1000003 17))
    ":" (itoa (swapp-text-rolling-hash data 1000033 29))
  )
)

(defun swapp-layout-plan-item-text (item index / win ll ur)
  (setq win (cadr item))
  (setq ll (car win))
  (setq ur (cadr win))
  (strcat
    "#" (if (< index 100) "0" "") (if (< index 10) "0" "") (itoa index)
    " name=" (nth 5 item)
    " source=" (nth 6 item)
    " frame=" (swapp-layout-plan-item-handle item)
    " LL=(" (swapp-layout-coordinate-text (car ll)) ", " (swapp-layout-coordinate-text (cadr ll)) ")"
    " UR=(" (swapp-layout-coordinate-text (car ur)) ", " (swapp-layout-coordinate-text (cadr ur)) ")"
    " size=" (swapp-layout-coordinate-text (gsla-window-width win)) " x " (swapp-layout-coordinate-text (gsla-window-height win))
  )
)

(defun swapp-print-layout-plan-items (plan limit / total index item)
  (setq total (length plan))
  (princ "\n----- SWCAD Layout 원본명 계획 -----")
  (princ "\n배치 순서: 사용자가 놓은 XREF/GMTITLE 좌표 순서")
  (princ "\n이름 우선순위: XREF 원본 파일명 -> GMTITLE File Name -> FILE NO -> Sheet")
  (princ (strcat "\n예정 Layout 수: " (itoa total)))
  (setq index 1)
  (foreach item plan
    (if (<= index limit)
      (princ (strcat "\n  " (swapp-layout-plan-item-text item index)))
    )
    (setq index (1+ index))
  )
  (if (> total limit)
    (princ (strcat "\n  ... 나머지 " (itoa (- total limit)) "개도 같은 규칙으로 생성합니다."))
  )
  plan
)

(defun swapp-layout-paper-a4-p (size / width height long-side short-side)
  (if (and size (numberp (car size)) (numberp (cadr size)))
    (progn
      (setq width (abs (float (car size))))
      (setq height (abs (float (cadr size))))
      (setq long-side (max width height))
      (setq short-side (min width height))
      (and (swapp-near long-side 297.0 1.0) (swapp-near short-side 210.0 1.0))
    )
    nil
  )
)

(defun swapp-layout-plan-names (plan / result item)
  (setq result nil)
  (foreach item plan (setq result (append result (list (nth 5 item)))))
  result
)

(defun swapp-layouts-valid-p (plan / names owned layouts name layout paper viewports ok tab-order previous-tab)
  (setq names (swapp-layout-plan-names plan))
  (setq owned (swapp-layout-owned-names))
  (setq layouts (vla-get-Layouts (swapp-doc)))
  (setq ok (and (= (length names) (length plan)) (swapp-string-lists-equal-ci-p names owned)))
  (setq previous-tab nil)
  (foreach name names
    (setq layout (swapp-safe 'vla-Item (list layouts name)))
    (setq paper (if layout (gsla-layout-paper-size layout) nil))
    (setq viewports (gsla-viewport-entities-for-layout name))
    (setq tab-order (if layout (swapp-safe 'vla-get-TabOrder (list layout)) nil))
    (if
      (or
        (not layout)
        (not (swapp-layout-paper-a4-p paper))
        (/= (length viewports) 1)
        (not (numberp tab-order))
        (and previous-tab (<= tab-order previous-tab))
      )
      (setq ok nil)
    )
    (if (numberp tab-order) (setq previous-tab tab-order))
  )
  ok
)

(defun swapp-layout-state-valid-p (expected / count-text plan signature)
  (setq count-text (swapp-state-value "LAYOUT_PLAN_COUNT"))
  (setq plan (swapp-layout-plan))
  (setq signature (swapp-state-value "LAYOUT_PLAN_SIGNATURE"))
  (and
    (equal (swapp-state-value "LAYOUT") "OK")
    (equal (swapp-state-value "LAYOUT_PLACEMENT_MODE") *swapp-layout-placement-mode*)
    count-text
    (= (atoi count-text) expected)
    (= (length plan) expected)
    signature
    (equal signature (swapp-layout-plan-signature plan))
    (swapp-layouts-valid-p plan)
  )
)

(defun swapp-workflow-stage (/ xrefs wrappers evidence frames)
  (swapp-activate-model)
  (setq xrefs (swapp-cached-top-xref-references))
  (cond
    (xrefs "XREF")
    ((setq wrappers (swapp-cached-sheet-wrapper-records)) "SHEET_WRAPPERS")
    (T
      (setq evidence (swapp-cached-title-evidence))
      (setq frames (swapp-evidence-value evidence "target-frame-count"))
      (cond
        ((swapp-title-complete-p evidence)
          (cond
            ((not (swapp-dimstyle-marked-p)) "DIMSTYLE")
            ((not (swapp-layout-state-valid-p frames)) "LAYOUT")
            ((not (swapp-cached-resource-cleanup-verify)) "CLEANUP")
            (T "COMPLETE")
          )
        )
        ((or (> (swapp-evidence-value evidence "source-count") 0) (> frames 0)) "TITLE")
        (T "BLOCKED_NO_SHEETS")
      )
    )
  )
)

;;; ---------------------------
;;; DIMSTYLE and LAYOUT adapters
;;; ---------------------------

(defun swapp-dim-semantic-number (value)
  (cond
    ((numberp value) (rtos (float value) 2 8))
    ((null value) "<nil>")
    (T (vl-princ-to-string value))
  )
)

(defun swapp-dim-semantic-record (object / ename data values raw dimlfac upper lower dimtol dimlim entity-type handle)
  (setq ename (swapp-safe 'vlax-vla-object->ename (list object)))
  (if ename
    (progn
      (setq data (entget ename '("*")))
      (setq values (swdt-effective-tolerance-values data))
      (setq raw (swdt-dim-raw-measurement ename data))
      (setq dimlfac (swdt-dim-linear-scale ename data))
      (setq upper (cdr (assoc 47 values)))
      (setq lower (cdr (assoc 48 values)))
      (setq dimtol (cdr (assoc 71 values)))
      (setq dimlim (cdr (assoc 72 values)))
      (setq entity-type (cdr (assoc 0 data)))
      (setq handle (cdr (assoc 5 data)))
      (strcat
        (if handle handle "<no-handle>") "|"
        (if entity-type entity-type "DIMENSION") "|"
        (swapp-dim-semantic-number raw) "|"
        (swapp-dim-semantic-number dimlfac) "|"
        (swapp-dim-semantic-number upper) "|"
        (swapp-dim-semantic-number lower) "|"
        (swapp-dim-semantic-number dimtol) "|"
        (swapp-dim-semantic-number dimlim)
      )
    )
    nil
  )
)

(defun swapp-dimension-semantics (/ result object record)
  (setq result nil)
  (foreach object (swapp-model-dimension-objects)
    (setq record (swapp-dim-semantic-record object))
    (if record (setq result (cons record result)))
  )
  (swapp-sort-strings result)
)

(defun swapp-dim-semantic-snapshot (object / ename data values handle result code pair)
  (setq ename (swapp-safe 'vlax-vla-object->ename (list object)))
  (if ename
    (progn
      (setq data (entget ename '("*")))
      (setq values (swdt-effective-tolerance-values data))
      (setq handle (cdr (assoc 5 data)))
      (setq result nil)
      (foreach code *swapp-dimension-semantic-codes*
        (setq pair (assoc code values))
        (if pair (setq result (cons pair result)))
      )
      (if handle (cons handle (reverse result)) nil)
    )
    nil
  )
)

(defun swapp-dimension-semantic-snapshots (/ result object snapshot)
  (setq result nil)
  (foreach object (swapp-model-dimension-objects)
    (setq snapshot (swapp-dim-semantic-snapshot object))
    (if snapshot (setq result (cons snapshot result)))
  )
  (reverse result)
)

(defun swapp-restore-dimension-semantic-snapshots (snapshots / restored failed snapshot handle values ename data overrides pair newdata ok)
  (setq restored 0)
  (setq failed 0)
  (foreach snapshot snapshots
    (setq handle (car snapshot))
    (setq values (cdr snapshot))
    (setq ename (handent handle))
    (if ename
      (progn
        (setq data (entget ename '("*")))
        (setq overrides (swdt-get-dstyle-overrides data))
        (foreach pair values
          (setq overrides (swdt-dxf-put overrides (car pair) (cdr pair)))
        )
        (setq newdata (swdt-set-dstyle-xdata data overrides))
        (regapp "ACAD")
        (setq ok (entmod newdata))
        (if ok
          (progn
            (entupd ename)
            (setq restored (1+ restored))
          )
          (setq failed (1+ failed))
        )
      )
      (setq failed (1+ failed))
    )
  )
  (list restored failed)
)

(defun swapp-remove-first-equal (needle items / result removed item)
  (setq result nil)
  (setq removed nil)
  (foreach item items
    (if (and (not removed) (equal needle item))
      (setq removed T)
      (setq result (cons item result))
    )
  )
  (cons removed (reverse result))
)

(defun swapp-semantic-multiset-equal-p (first second / remaining match ok item)
  (setq remaining second)
  (setq ok (= (length first) (length second)))
  (foreach item first
    (if ok
      (progn
        (setq match (swapp-remove-first-equal item remaining))
        (setq ok (car match))
        (setq remaining (cdr match))
      )
    )
  )
  (and ok (not remaining))
)

(defun swapp-first-unmatched-semantic (first second / match found item)
  (setq found nil)
  (while (and first (not found))
    (setq item (car first))
    (setq match (swapp-remove-first-equal item second))
    (if (car match)
      (progn
        (setq second (cdr match))
        (setq first (cdr first))
      )
      (setq found item)
    )
  )
  found
)

(defun swapp-semantic-record-handle (record / pos)
  (setq pos (if record (vl-string-search "|" record) nil))
  (if pos (substr record 1 pos) nil)
)

(defun swapp-semantic-by-handle (handle records / found record)
  (setq found nil)
  (while (and records (not found))
    (setq record (car records))
    (if (equal handle (swapp-semantic-record-handle record))
      (setq found record)
    )
    (setq records (cdr records))
  )
  found
)

(defun swapp-changed-dimension-handles (before after / result record handle counterpart)
  (setq result nil)
  (foreach record before
    (setq handle (swapp-semantic-record-handle record))
    (setq counterpart (swapp-semantic-by-handle handle after))
    (if (not (equal record counterpart))
      (setq result (cons handle result))
    )
  )
  (foreach record after
    (setq handle (swapp-semantic-record-handle record))
    (if (and (not (swapp-semantic-by-handle handle before)) (not (member handle result)))
      (setq result (cons handle result))
    )
  )
  (reverse result)
)

(defun swapp-snapshots-for-handles (snapshots handles / result snapshot)
  (setq result nil)
  (foreach snapshot snapshots
    (if (member (car snapshot) handles)
      (setq result (cons snapshot result))
    )
  )
  (reverse result)
)

(defun swapp-run-dimstyle (/ ss result semantics-preserved restore-result changed-handles restore-snapshots restore-style-ok restore-fit-ok)
  (swapp-activate-model)
  (if (not (swcad-title-ensure-work-copy-for-mutation))
    (progn
      (princ "\n치수 정규화 중단: 작업본을 만들지 않았습니다.")
      nil
    )
    (progn
      (setq ss (swdt-current-space-dim-ss))
      (if (not ss)
        (progn
          (swapp-state-set "DIMSTYLE" "NO_DIMENSIONS")
          (swapp-state-set "DIMENSION_SEMANTICS" "NO_DIMENSIONS")
          (swapp-save-current)
          (princ "\n치수 없음: DIMSTYLE 단계를 건너뜁니다.")
          T
        )
        (if (not (swdt-autofix-preflight ss))
          (progn
            (swapp-state-set "DIMSTYLE" "FAILED")
            (princ "\n결과: SWCAD_DIMSTYLE_PREFLIGHT_FAILED")
            nil
          )
          (progn
            (setq *swapp-last-dimension-semantics-before* (swapp-dimension-semantics))
            (setq *swapp-last-dimension-semantic-snapshots* (swapp-dimension-semantic-snapshots))
            (setq result (swdt-run-autofix-core ss))
            (setq *swapp-last-dimension-semantics-after* (swapp-dimension-semantics))
            (setq semantics-preserved
              (swapp-semantic-multiset-equal-p
                *swapp-last-dimension-semantics-before*
                *swapp-last-dimension-semantics-after*
              )
            )
            (if (and result (not semantics-preserved))
              (progn
                (setq changed-handles
                  (swapp-changed-dimension-handles
                    *swapp-last-dimension-semantics-before*
                    *swapp-last-dimension-semantics-after*
                  )
                )
                (setq restore-snapshots
                  (swapp-snapshots-for-handles
                    *swapp-last-dimension-semantic-snapshots*
                    changed-handles
                  )
                )
                (setq restore-result
                  (swapp-restore-dimension-semantic-snapshots
                    restore-snapshots
                  )
                )
                (vla-Regen (swapp-doc) 1)
                (setq *swapp-last-dimension-semantics-after* (swapp-dimension-semantics))
                (setq semantics-preserved
                  (and
                    (= (cadr restore-result) 0)
                    (swapp-semantic-multiset-equal-p
                      *swapp-last-dimension-semantics-before*
                      *swapp-last-dimension-semantics-after*
                    )
                  )
                )
                (if semantics-preserved
                  (progn
                    (princ (strcat "\n치수 의미값 복원 완료: " (itoa (car restore-result)) "개 / 감지 " (itoa (length changed-handles)) "개"))
                    (setq restore-style-ok (swdt-swauto-final-audit))
                    (setq restore-fit-ok (swdt-swauto-fit-audit))
                    (setq result (and result restore-style-ok restore-fit-ok))
                    (swapp-state-set "DIMSTYLE_POST_RESTORE_AUDIT" (if result "OK" "FAILED"))
                  )
                )
              )
            )
            (if (and result semantics-preserved)
              (progn
                (swapp-state-set "DIMSTYLE" "OK")
                (swapp-state-set "DIMENSION_SEMANTICS" "PRESERVED")
                (swapp-state-set "DIMENSION_RESTORE_COUNT" (if restore-result (itoa (car restore-result)) "0"))
                (if (not restore-result)
                  (swapp-state-set "DIMSTYLE_POST_RESTORE_AUDIT" "NOT_NEEDED")
                )
                (swapp-state-set "DIMENSION_COUNT" (itoa (sslength ss)))
                (swapp-save-current)
                (princ "\n결과: SWCAD_DIMSTYLE_OK")
                T
              )
              (progn
                (swapp-state-set "DIMSTYLE" "FAILED")
                (swapp-state-set "DIMENSION_SEMANTICS" (if semantics-preserved "PRESERVED" "CHANGED"))
                (if semantics-preserved
                  (princ "\n결과: SWCAD_DIMSTYLE_CHECK_NEEDED")
                  (progn
                    (princ "\n결과: SWCAD_DIMENSION_SEMANTICS_CHANGED")
                    (princ (strcat "\n변경 전 불일치 예: " (if (swapp-first-unmatched-semantic *swapp-last-dimension-semantics-before* *swapp-last-dimension-semantics-after*) (swapp-first-unmatched-semantic *swapp-last-dimension-semantics-before* *swapp-last-dimension-semantics-after*) "<없음>")))
                    (princ (strcat "\n변경 후 불일치 예: " (if (swapp-first-unmatched-semantic *swapp-last-dimension-semantics-after* *swapp-last-dimension-semantics-before*) (swapp-first-unmatched-semantic *swapp-last-dimension-semantics-after* *swapp-last-dimension-semantics-before*) "<없음>")))
                  )
                )
                nil
              )
            )
          )
        )
      )
    )
  )
)

(defun swapp-model-object-count ()
  (vla-get-Count (swapp-model))
)

(defun swapp-bbox4-union (first second)
  (cond
    ((not first) second)
    ((not second) first)
    (T
      (list
        (min (nth 0 first) (nth 0 second))
        (min (nth 1 first) (nth 1 second))
        (max (nth 2 first) (nth 2 second))
        (max (nth 3 first) (nth 3 second))
      )
    )
  )
)

(defun swapp-layout-selection-set (layout-name / result)
  (setq result
    (vl-catch-all-apply
      'ssget
      (list "_X" (list (cons 410 layout-name)))
    )
  )
  (if (vl-catch-all-error-p result) nil result)
)

(defun swapp-selection-set-bbox4 (ss / index ename object bbox result)
  (setq result nil)
  (if ss
    (progn
      (setq index 0)
      (while (< index (sslength ss))
        (setq ename (ssname ss index))
        (setq object (swapp-safe 'vlax-ename->vla-object (list ename)))
        (setq bbox (if object (swapp-object-bbox4 object) nil))
        (if bbox (setq result (swapp-bbox4-union result bbox)))
        (setq index (1+ index))
      )
    )
  )
  result
)

(defun swapp-viewport-integrity-record (ename / data)
  (setq data (entget ename))
  (list
    (cdr (assoc 5 data))
    (cdr (assoc 10 data))
    (cdr (assoc 40 data))
    (cdr (assoc 41 data))
    (cdr (assoc 12 data))
    (cdr (assoc 45 data))
    (cdr (assoc 51 data))
    (cdr (assoc 68 data))
    (cdr (assoc 69 data))
    (cdr (assoc 90 data))
  )
)

(defun swapp-viewport-integrity-snapshot (layout-name / result ename)
  (setq result nil)
  (foreach ename (gsla-viewport-entities-for-layout layout-name)
    (setq result (cons (swapp-viewport-integrity-record ename) result))
  )
  (vl-sort
    result
    '(lambda (first second)
      (< (if (car first) (car first) "") (if (car second) (car second) ""))
    )
  )
)

(defun swapp-layout-integrity-snapshot (/ layouts layout name tab-order paper ss record result)
  (setq layouts (vla-get-Layouts (swapp-doc)))
  (setq result nil)
  (vlax-for layout layouts
    (setq name (vla-get-Name layout))
    (if (not (equal (strcase name) "MODEL"))
      (progn
        (setq tab-order (swapp-safe 'vla-get-TabOrder (list layout)))
        (if (not (numberp tab-order)) (setq tab-order 0))
        (setq paper (gsla-layout-paper-size layout))
        (setq ss (swapp-layout-selection-set name))
        (setq record
          (list
            name
            tab-order
            paper
            (if ss (sslength ss) 0)
            (swapp-selection-set-bbox4 ss)
            (swapp-viewport-integrity-snapshot name)
          )
        )
        (setq result (cons record result))
      )
    )
  )
  (vl-sort
    result
    '(lambda (first second)
      (if (= (nth 1 first) (nth 1 second))
        (< (strcase (car first)) (strcase (car second)))
        (< (nth 1 first) (nth 1 second))
      )
    )
  )
)

(defun swapp-state-integrity-snapshot (/ result pair key)
  (setq result nil)
  (foreach pair (swapp-state-read)
    (setq key (strcase (car pair)))
    (if
      (and
        (not (equal key "VERSION"))
        (not (swapp-string-starts-ci-p key "RESOURCE_CLEANUP"))
      )
      (setq result (cons pair result))
    )
  )
  (vl-sort
    result
    '(lambda (first second)
      (< (strcase (car first)) (strcase (car second)))
    )
  )
)

(defun swapp-entity-handle-token (ename / data handle object)
  (setq data (if ename (entget ename) nil))
  (setq handle (if data (cdr (assoc 5 data)) nil))
  (if (not (= (type handle) 'STR))
    (progn
      (setq object (if ename (swapp-safe 'vlax-ename->vla-object (list ename)) nil))
      (setq handle (if object (swapp-object-handle object) nil))
    )
  )
  (if (and (= (type handle) 'STR) (> (strlen handle) 0))
    (strcase handle)
    "<NO-HANDLE>"
  )
)

;;; ENAME values are session-local. Convert them to persistent handles before
;;; comparing cleanup snapshots across save/close/reopen.
(defun swapp-persistent-data-value (value)
  (cond
    ((= (type value) 'ENAME)
      (list "HANDLE" (swapp-entity-handle-token value))
    )
    ((listp value)
      (if value
        (cons
          (swapp-persistent-data-value (car value))
          (swapp-persistent-data-value (cdr value))
        )
        nil
      )
    )
    (T value)
  )
)

(defun swapp-entity-persistent-data-snapshot (ename / data result pair)
  (setq data (if ename (entget ename '("*")) nil))
  (setq result nil)
  (foreach pair data
    (if (not (= (car pair) -1))
      (setq result (cons (swapp-persistent-data-value pair) result))
    )
  )
  (reverse result)
)

(defun swapp-entity-extension-dictionary (ename / data inside result pair code value)
  (setq data (if ename (entget ename '("*")) nil))
  (setq inside nil)
  (setq result nil)
  (foreach pair data
    (setq code (car pair))
    (setq value (cdr pair))
    (cond
      ((and (= code 102) (= (type value) 'STR) (equal (strcase value) "{ACAD_XDICTIONARY"))
        (setq inside T)
      )
      ((and inside (= code 360) (= (type value) 'ENAME) (not result))
        (setq result value)
      )
      ((and inside (= code 102) (= (type value) 'STR) (equal value "}"))
        (setq inside nil)
      )
    )
  )
  result
)

(defun swapp-extension-dictionary-integrity-snapshot (dict visited / handle entries result entry key ename type child)
  (if (not dict)
    nil
    (progn
      (setq handle (swapp-entity-handle-token dict))
      (if (member handle visited)
        (list "CYCLE" handle)
        (progn
          (setq visited (cons handle visited))
          (setq entries
            (vl-sort
              (swapp-dictionary-entries dict)
              '(lambda (first second)
                (< (strcase (car first)) (strcase (car second)))
              )
            )
          )
          (setq result nil)
          (foreach entry entries
            (setq key (nth 0 entry))
            (setq ename (nth 1 entry))
            (setq type (nth 2 entry))
            (setq child
              (if (and ename (wcmatch (strcase type) "*DICTIONARY*"))
                (swapp-extension-dictionary-integrity-snapshot ename visited)
                nil
              )
            )
            (setq result
              (cons
                (list
                  key
                  type
                  (nth 3 entry)
                  (swapp-entity-persistent-data-snapshot ename)
                  child
                )
                result
              )
            )
          )
          (list
            handle
            (swapp-entity-persistent-data-snapshot dict)
            (reverse result)
          )
        )
      )
    )
  )
)

(defun swapp-gmtitle-native-target-snapshot (ename / handles normalized result handle target object object-name extension)
  (setq normalized nil)
  (foreach handle (if ename (swcad-title-gmtitle-native-xdata-info ename) nil)
    (setq normalized (cons (strcase handle) normalized))
  )
  (setq handles (swapp-sort-strings normalized))
  (setq result nil)
  (foreach handle handles
    (setq target (handent handle))
    (setq object (if target (swapp-safe 'vlax-ename->vla-object (list target)) nil))
    (setq object-name (if object (swapp-safe 'vla-get-ObjectName (list object)) nil))
    (setq extension (if target (swapp-entity-extension-dictionary target) nil))
    (setq result
      (cons
        (list
          handle
          (swcad-title-native-link-target-kind handle)
          (if (= (type object-name) 'STR) object-name "<NO-VLA>")
          (swapp-entity-persistent-data-snapshot target)
          (swapp-extension-dictionary-integrity-snapshot extension nil)
        )
        result
      )
    )
  )
  (reverse result)
)

(defun swapp-entity-native-structure-snapshot (ename / extension)
  (setq extension (if ename (swapp-entity-extension-dictionary ename) nil))
  (list
    (swapp-entity-persistent-data-snapshot ename)
    (swapp-extension-dictionary-integrity-snapshot extension nil)
    (swapp-gmtitle-native-target-snapshot ename)
  )
)

(defun swapp-title-attribute-structure-snapshot (title-object / attrs result attr ename handle tag)
  (setq attrs (if title-object (swcad-title-get-insert-attributes title-object) nil))
  (setq result nil)
  (foreach attr attrs
    (setq ename (swapp-safe 'vlax-vla-object->ename (list attr)))
    (setq handle (if ename (swapp-entity-handle-token ename) "<NO-HANDLE>"))
    (setq tag (swcad-title-attribute-tag attr))
    (setq result
      (cons
        (list handle tag (swapp-entity-native-structure-snapshot ename))
        result
      )
    )
  )
  (vl-sort
    result
    '(lambda (first second)
      (if (equal (car first) (car second))
        (< (strcase (cadr first)) (strcase (cadr second)))
        (< (car first) (car second))
      )
    )
  )
)

(defun swapp-title-integrity-snapshot (/ pairs result pair title frame title-object attrs attribute-structures)
  (setq pairs (swcad-title-target-gmtitle-pair-records))
  (setq result nil)
  (foreach pair pairs
    (setq title (car pair))
    (setq frame (cadr pair))
    (setq title-object (swcad-title-safe-vla-object title))
    (setq attrs
      (vl-sort
        (if title-object (swcad-title-title-attribute-pairs title-object) nil)
        '(lambda (first second)
          (< (strcase (car first)) (strcase (car second)))
        )
      )
    )
    (setq attribute-structures (swapp-title-attribute-structure-snapshot title-object))
    (setq result
      (append
        result
        (list
          (list
            (cdr (assoc 5 (entget title)))
            (cdr (assoc 5 (entget frame)))
            (nth 2 pair)
            (nth 3 pair)
            (nth 4 pair)
            (if (swcad-title-target-pair-native-like-p pair) "NATIVE" "NOT_NATIVE")
            attrs
            (swapp-entity-native-structure-snapshot title)
            (swapp-entity-native-structure-snapshot frame)
            attribute-structures
          )
        )
      )
    )
  )
  (vl-sort
    result
    '(lambda (first second)
      (if (equal (car first) (car second))
        (< (cadr first) (cadr second))
        (< (car first) (car second))
      )
    )
  )
)

(defun swapp-workflow-integrity-snapshot ()
  (list
    (swapp-model-object-count)
    (swapp-model-bbox)
    (swapp-dimension-semantics)
    (swapp-title-integrity-snapshot)
    (swapp-layout-integrity-snapshot)
    (swapp-state-integrity-snapshot)
  )
)

(defun swapp-workflow-integrity-snapshot-with-model-bbox (model-bbox)
  (list
    (swapp-model-object-count)
    model-bbox
    (swapp-dimension-semantics)
    (swapp-title-integrity-snapshot)
    (swapp-layout-integrity-snapshot)
    (swapp-state-integrity-snapshot)
  )
)

(defun swapp-layout-integrity-sentinel-from-snapshot (layouts / result record)
  (setq result nil)
  (foreach record layouts
    (setq result
      (cons
        (list
          (nth 0 record)
          (nth 1 record)
          (nth 2 record)
          (nth 3 record)
          (nth 5 record)
        )
        result
      )
    )
  )
  (reverse result)
)

(defun swapp-layout-integrity-sentinel-snapshot (/ layouts layout name tab-order paper ss record result)
  (setq layouts (vla-get-Layouts (swapp-doc)))
  (setq result nil)
  (vlax-for layout layouts
    (setq name (vla-get-Name layout))
    (if (not (equal (strcase name) "MODEL"))
      (progn
        (setq tab-order (swapp-safe 'vla-get-TabOrder (list layout)))
        (if (not (numberp tab-order)) (setq tab-order 0))
        (setq paper (gsla-layout-paper-size layout))
        (setq ss (swapp-layout-selection-set name))
        (setq record
          (list
            name
            tab-order
            paper
            (if ss (sslength ss) 0)
            (swapp-viewport-integrity-snapshot name)
          )
        )
        (setq result (cons record result))
      )
    )
  )
  (vl-sort
    result
    '(lambda (first second)
      (if (= (nth 1 first) (nth 1 second))
        (< (strcase (car first)) (strcase (car second)))
        (< (nth 1 first) (nth 1 second))
      )
    )
  )
)

(defun swapp-workflow-integrity-sentinel-from-snapshot (snapshot)
  (list
    (nth 0 snapshot)
    (nth 2 snapshot)
    (nth 3 snapshot)
    (swapp-layout-integrity-sentinel-from-snapshot (nth 4 snapshot))
    (nth 5 snapshot)
  )
)

(defun swapp-workflow-integrity-sentinel-snapshot ()
  (list
    (swapp-model-object-count)
    (swapp-dimension-semantics)
    (swapp-title-integrity-snapshot)
    (swapp-layout-integrity-sentinel-snapshot)
    (swapp-state-integrity-snapshot)
  )
)

(defun swapp-workflow-integrity-sentinel-equal-p (before after)
  (and
    (= (nth 0 before) (nth 0 after))
    (swapp-semantic-multiset-equal-p (nth 1 before) (nth 1 after))
    (equal (nth 2 before) (nth 2 after))
    (equal (nth 3 before) (nth 3 after))
    (equal (nth 4 before) (nth 4 after))
  )
)

(defun swapp-workflow-integrity-equal-p (before after)
  (and
    (= (nth 0 before) (nth 0 after))
    (or
      (and (not (nth 1 before)) (not (nth 1 after)))
      (swapp-bbox-near-p (nth 1 before) (nth 1 after))
    )
    (swapp-semantic-multiset-equal-p (nth 2 before) (nth 2 after))
    (equal (nth 3 before) (nth 3 after))
    (equal (nth 4 before) (nth 4 after))
    (equal (nth 5 before) (nth 5 after))
  )
)

(defun swapp-workflow-integrity-signature (snapshot / text)
  (setq text (vl-princ-to-string snapshot))
  (strcat
    (itoa (nth 0 snapshot)) ":"
    (itoa (swapp-text-rolling-hash text 1000003 41)) ":"
    (itoa (swapp-text-rolling-hash text 1000033 67))
  )
)

(defun swapp-sort-strings (values)
  (vl-sort
    values
    '(lambda (first second)
      (< first second)
    )
  )
)

(defun swapp-safe-tblnext (table reset / result)
  (setq result
    (if reset
      (vl-catch-all-apply 'tblnext (list table T))
      (vl-catch-all-apply 'tblnext (list table))
    )
  )
  (if (vl-catch-all-error-p result) nil result)
)

(defun swapp-symbol-table-definition-snapshot (/ result table item name handle)
  (setq result nil)
  (foreach table *swapp-purge-symbol-tables*
    (setq item (swapp-safe-tblnext table T))
    (while item
      (setq name (cdr (assoc 2 item)))
      (setq handle (cdr (assoc 5 item)))
      (if name
        (setq result
          (cons
            (strcase
              (strcat
                "TABLE|" table "|" name "|" (if handle handle "<NO-HANDLE>")
              )
            )
            result
          )
        )
      )
      (setq item (swapp-safe-tblnext table nil))
    )
  )
  (swapp-sort-strings result)
)

(defun swapp-safe-dictnext (dict reset / result)
  (setq result
    (if reset
      (vl-catch-all-apply 'dictnext (list dict T))
      (vl-catch-all-apply 'dictnext (list dict))
    )
  )
  (if (vl-catch-all-error-p result) nil result)
)

;;; Returns one normalized (key ename dxf-type handle) dictionary entry.
(defun swapp-dictionary-entry-record (key ename / data type handle)
  (setq data (if ename (entget ename) nil))
  (setq type (if data (cdr (assoc 0 data)) "<UNKNOWN>"))
  (setq handle (if data (cdr (assoc 5 data)) nil))
  (list
    (if key key (if handle handle "<NO-KEY>"))
    ename
    (if type type "<UNKNOWN>")
    (if handle handle "<NO-HANDLE>")
  )
)

;;; GstarCAD DICTNEXT omits group 3 entry names.  Read the owning dictionary's
;;; alternating group 3 + 350/360 pairs so paths keep their real stable keys.
(defun swapp-dictionary-entries-from-entget (dict / result data pair code key)
  (setq result nil)
  (setq key nil)
  (setq data (if dict (entget dict) nil))
  (foreach pair data
    (setq code (car pair))
    (cond
      ((= code 3)
        (setq key (cdr pair))
      )
      ((and key (or (= code 350) (= code 360)))
        (setq result
          (cons
            (swapp-dictionary-entry-record key (cdr pair))
            result
          )
        )
        (setq key nil)
      )
    )
  )
  (reverse result)
)

;;; Compatibility fallback for CAD engines that expose keys only through DICTNEXT.
(defun swapp-dictionary-entries-from-dictnext (dict / result item key ename data type handle)
  (setq result nil)
  (setq item (swapp-safe-dictnext dict T))
  (while item
    (setq key (cdr (assoc 3 item)))
    (setq ename (cdr (assoc -1 item)))
    (if (not ename) (setq ename (cdr (assoc 350 item))))
    (if (not ename) (setq ename (cdr (assoc 360 item))))
    (setq data (if ename (entget ename) nil))
    (setq type (if data (cdr (assoc 0 data)) "<UNKNOWN>"))
    (setq handle (if data (cdr (assoc 5 data)) nil))
    (setq result
      (cons
        (list
          (if key key (if handle handle "<NO-KEY>"))
          ename
          (if type type "<UNKNOWN>")
          (if handle handle "<NO-HANDLE>")
        )
        result
      )
    )
    (setq item (swapp-safe-dictnext dict nil))
  )
  (reverse result)
)

(defun swapp-dictionary-entries (dict / result)
  (setq result (swapp-dictionary-entries-from-entget dict))
  (if result
    result
    (swapp-dictionary-entries-from-dictnext dict)
  )
)

(defun swapp-dictionary-definition-handle-token (path handle)
  (if
    (equal
      (strcase path)
      (strcase (strcat "NOD/" *swapp-state-dictionary-key*))
    )
    "<WORKFLOW-STATE-XRECORD>"
    handle
  )
)

(defun swapp-dictionary-definition-snapshot-rec (dict path visited / data handle result entry key ename type child-path entry-handle)
  (setq data (if dict (entget dict) nil))
  (setq handle (if data (cdr (assoc 5 data)) nil))
  (if (and handle (member handle visited))
    nil
    (progn
      (if handle (setq visited (cons handle visited)))
      (setq result nil)
      (foreach entry (swapp-dictionary-entries dict)
        (setq key (nth 0 entry))
        (setq ename (nth 1 entry))
        (setq type (nth 2 entry))
        (setq child-path (strcat path "/" key))
        (setq entry-handle
          (swapp-dictionary-definition-handle-token child-path (nth 3 entry))
        )
        (setq result
          (cons
            (strcase
              (strcat
                "DICT|" child-path "|" type "|" entry-handle
              )
            )
            result
          )
        )
        (if (and ename (wcmatch (strcase type) "*DICTIONARY*"))
          (setq result
            (append
              (swapp-dictionary-definition-snapshot-rec ename child-path visited)
              result
            )
          )
        )
      )
      result
    )
  )
)

(defun swapp-named-definition-snapshot (/ tables dictionaries all)
  (setq tables (swapp-symbol-table-definition-snapshot))
  (setq dictionaries
    (swapp-sort-strings
      (swapp-dictionary-definition-snapshot-rec (namedobjdict) "NOD" nil)
    )
  )
  (setq all (swapp-sort-strings (append tables dictionaries)))
  (list (length tables) (length dictionaries) all)
)

(defun swapp-named-definition-signature (snapshot / records text)
  (setq records (nth 2 snapshot))
  (setq text (vl-princ-to-string records))
  (strcat
    (itoa (length records)) ":"
    (itoa (swapp-text-rolling-hash text 1000003 43)) ":"
    (itoa (swapp-text-rolling-hash text 1000033 71))
  )
)

(defun swapp-named-definition-identity-signature (snapshot / identities text)
  (setq identities
    (swapp-definition-record-identities (nth 2 snapshot))
  )
  (setq text (vl-princ-to-string identities))
  (strcat
    (itoa (length identities)) ":"
    (itoa (swapp-text-rolling-hash text 1000003 47)) ":"
    (itoa (swapp-text-rolling-hash text 1000033 73))
  )
)

;;; GstarCAD Mechanical lazily re-registers APPID rows when native XData is
;;; inspected, rebuilds the session-local *ACTIVE VPORT row, and may recreate an
;;; empty anonymous *U block table row after reopen. Keep all three kinds in the
;;; purge pass and diagnostics, but exclude them from the cross-session identity
;;; gate. Actual layout viewport objects, geometry, and native XData remain
;;; protected by the workflow snapshot.
(defun swapp-appid-definition-record-p (record)
  (= 0 (vl-string-search "TABLE|APPID|" (strcase record)))
)

(defun swapp-vport-definition-record-p (record / fields)
  (setq fields (swapp-string-split (strcase record) "|"))
  (and
    (>= (length fields) 4)
    (equal (nth 0 fields) "TABLE")
    (equal (nth 1 fields) "VPORT")
    (equal (nth 2 fields) "*ACTIVE")
  )
)

(defun swapp-session-anonymous-block-name-p (name / suffix)
  (setq suffix
    (if
      (and (= (type name) 'STR) (> (strlen name) 2))
      (substr name 3)
      nil
    )
  )
  (and
    suffix
    (equal (strcase (substr name 1 2)) "*U")
    (equal suffix (itoa (atoi suffix)))
  )
)

;;; This predicate is intentionally narrow. A populated anonymous definition is
;;; never volatile, and neither is an ordinary named block. The GstarCAD reopen
;;; artifact proved in the representative DWG is anonymous (DXF flag 1), empty,
;;; and has a *U<number> name.
(defun swapp-session-empty-anonymous-block-definition-record-p
  (record / fields name ename data flags block count)
  (setq fields (swapp-string-split (strcase record) "|"))
  (if
    (and
      (>= (length fields) 4)
      (equal (nth 0 fields) "TABLE")
      (equal (nth 1 fields) "BLOCK")
      (swapp-session-anonymous-block-name-p (nth 2 fields))
    )
    (progn
      (setq name (nth 2 fields))
      (setq ename (tblobjname "BLOCK" name))
      (setq data (if ename (entget ename) nil))
      (setq flags (if data (cdr (assoc 70 data)) nil))
      (setq block (swapp-block-definition name))
      (setq count (if block (swapp-safe 'vla-get-Count (list block)) nil))
      (and
        (numberp flags)
        (= 1 (logand flags 1))
        (numberp count)
        (= count 0)
      )
    )
    nil
  )
)

(defun swapp-volatile-definition-record-p (record)
  (or
    (swapp-appid-definition-record-p record)
    (swapp-vport-definition-record-p record)
    (swapp-session-empty-anonymous-block-definition-record-p record)
  )
)

(defun swapp-definition-records-filter-appid (records keep-appid / result record)
  (setq result nil)
  (foreach record records
    (if (equal (if (swapp-appid-definition-record-p record) T nil) keep-appid)
      (setq result (cons record result))
    )
  )
  (swapp-sort-strings result)
)

(defun swapp-definition-records-filter-volatile (records keep-volatile / result record)
  (setq result nil)
  (foreach record records
    (if
      (equal
        (if (swapp-volatile-definition-record-p record) T nil)
        keep-volatile
      )
      (setq result (cons record result))
    )
  )
  (swapp-sort-strings result)
)

(defun swapp-definition-records-exclude-identities (records excluded / result record identity)
  (setq result nil)
  (foreach record records
    (setq identity (swapp-definition-record-identity record))
    (if (not (member identity excluded))
      (setq result (cons record result))
    )
  )
  (swapp-sort-strings result)
)

(defun swapp-named-definition-stable-identity-signature (snapshot / identities text)
  (setq identities
    (swapp-definition-record-identities
      (swapp-definition-records-filter-volatile (nth 2 snapshot) nil)
    )
  )
  (setq text (vl-princ-to-string identities))
  (strcat
    (itoa (length identities)) ":"
    (itoa (swapp-text-rolling-hash text 1000003 53)) ":"
    (itoa (swapp-text-rolling-hash text 1000033 79))
  )
)

(defun swapp-named-definition-vport-identity-signature (snapshot / identities text)
  (setq identities
    (swapp-definition-record-identities
      (vl-remove-if-not
        'swapp-vport-definition-record-p
        (nth 2 snapshot)
      )
    )
  )
  (setq text (vl-princ-to-string identities))
  (strcat
    (itoa (length identities)) ":"
    (itoa (swapp-text-rolling-hash text 1000003 61)) ":"
    (itoa (swapp-text-rolling-hash text 1000033 89))
  )
)

(defun swapp-named-definition-session-anonymous-block-identity-signature
  (snapshot / identities text)
  (setq identities
    (swapp-definition-record-identities
      (vl-remove-if-not
        'swapp-session-empty-anonymous-block-definition-record-p
        (nth 2 snapshot)
      )
    )
  )
  (setq text (vl-princ-to-string identities))
  (strcat
    (itoa (length identities)) ":"
    (itoa (swapp-text-rolling-hash text 1000003 67)) ":"
    (itoa (swapp-text-rolling-hash text 1000033 97))
  )
)

(defun swapp-named-definition-appid-identity-signature (snapshot / identities text)
  (setq identities
    (swapp-definition-record-identities
      (swapp-definition-records-filter-appid (nth 2 snapshot) T)
    )
  )
  (setq text (vl-princ-to-string identities))
  (strcat
    (itoa (length identities)) ":"
    (itoa (swapp-text-rolling-hash text 1000003 59)) ":"
    (itoa (swapp-text-rolling-hash text 1000033 83))
  )
)

(defun swapp-string-list-difference (first second / result)
  (setq result nil)
  (while (and first second)
    (cond
      ((equal (car first) (car second))
        (setq first (cdr first))
        (setq second (cdr second))
      )
      ((< (car first) (car second))
        (setq result (cons (car first) result))
        (setq first (cdr first))
      )
      (T (setq second (cdr second)))
    )
  )
  (while first
    (setq result (cons (car first) result))
    (setq first (cdr first))
  )
  (reverse result)
)

(defun swapp-definition-record-identity (record / index)
  (setq index (strlen record))
  (while
    (and
      (> index 0)
      (not (equal (substr record index 1) "|"))
    )
    (setq index (1- index))
  )
  (if (> index 0)
    (substr record 1 (1- index))
    record
  )
)

(defun swapp-definition-record-identities (records / result record)
  (setq result nil)
  (foreach record records
    (setq result (cons (swapp-definition-record-identity record) result))
  )
  (swapp-sort-strings result)
)

(defun swapp-string-list-union (first second / result value)
  (setq result first)
  (foreach value second
    (if (not (member value result))
      (setq result (cons value result))
    )
  )
  (swapp-sort-strings result)
)

(defun swapp-definition-record-sample-text (records max-items max-length / text candidate count)
  (setq text "")
  (setq count 0)
  (while (and records (< count max-items) (< (strlen text) max-length))
    (setq candidate
      (if (equal text "")
        (car records)
        (strcat text " || " (car records))
      )
    )
    (if (> (strlen candidate) max-length)
      (setq records nil)
      (progn
        (setq text candidate)
        (setq records (cdr records))
        (setq count (1+ count))
      )
    )
  )
  text
)

(defun swapp-print-definition-record-sample (label records max-items / count remaining)
  (if records
    (progn
      (princ (strcat "\n" label))
      (setq count 0)
      (setq remaining records)
      (while (and remaining (< count max-items))
        (princ (strcat "\n  - " (car remaining)))
        (setq remaining (cdr remaining))
        (setq count (1+ count))
      )
      (if remaining
        (princ (strcat "\n  - ... 외 " (itoa (length remaining)) "개"))
      )
    )
  )
)

(defun swapp-native-purge-category (category / label option old-cmdecho command-result active-after)
  (setq label (car category))
  (setq option (cadr category))
  (setq old-cmdecho (getvar "CMDECHO"))
  (setvar "CMDECHO" 0)
  (setq command-result
    (vl-catch-all-apply
      'vl-cmdf
      (list "_.-PURGE" option "*" "_No")
    )
  )
  (setq active-after (> (getvar "CMDACTIVE") 0))
  (if active-after (swcad-title-cancel-active-command))
  (setvar "CMDECHO" old-cmdecho)
  (if (or (vl-catch-all-error-p command-result) active-after (> (getvar "CMDACTIVE") 0))
    (list nil (strcat label ": " (if (vl-catch-all-error-p command-result) (vl-catch-all-error-message command-result) "PURGE 명령이 모든 입력을 소비하지 못해 취소했습니다.")))
    (list T label)
  )
)

(defun swapp-native-purge-named-pass (/ categories category result ok detail)
  (setq categories *swapp-purge-command-categories*)
  (setq ok T)
  (setq detail "OK")
  (while (and ok categories)
    (setq category (car categories))
    (setq result (swapp-native-purge-category category))
    (if (not (car result))
      (progn
        (setq ok nil)
        (setq detail (cadr result))
      )
    )
    (setq categories (cdr categories))
  )
  (list ok detail)
)

(defun swapp-resource-cleanup-marked-p ()
  (and
    (equal (swapp-state-value "RESOURCE_CLEANUP") "OK")
    (equal (swapp-state-value "RESOURCE_CLEANUP_POLICY") *swapp-resource-cleanup-policy*)
    (equal (swapp-state-value "RESOURCE_CLEANUP_ZERO_PASS") "YES")
    (swapp-state-value "RESOURCE_CLEANUP_STATE_SAVE_STABILIZATION_PASSES")
    (swapp-state-value "RESOURCE_CLEANUP_STATE_SAVE_REBASE_COUNT")
    (swapp-state-value "RESOURCE_CLEANUP_DEFINITION_IDENTITY_SIGNATURE")
    (swapp-state-value "RESOURCE_CLEANUP_STABLE_DEFINITION_IDENTITY_SIGNATURE")
    (swapp-state-value "RESOURCE_CLEANUP_APPID_IDENTITY_SIGNATURE")
    (swapp-state-value "RESOURCE_CLEANUP_VPORT_IDENTITY_SIGNATURE")
    (swapp-state-value "RESOURCE_CLEANUP_SESSION_ANON_BLOCK_IDENTITY_SIGNATURE")
    (swapp-state-value "RESOURCE_CLEANUP_DEFINITION_SIGNATURE")
  )
)

(defun swapp-resource-cleanup-verify-from-snapshots
  (marked-p snapshot definitions / signature definition-signature identity-signature stable-identity-signature)
  (setq *swapp-last-resource-cleanup-marked-p* marked-p)
  (setq *swapp-last-resource-cleanup-stored-integrity*
    (swapp-state-value "RESOURCE_CLEANUP_INTEGRITY")
  )
  (setq *swapp-last-resource-cleanup-stored-identity*
    (swapp-state-value "RESOURCE_CLEANUP_STABLE_DEFINITION_IDENTITY_SIGNATURE")
  )
  (setq *swapp-last-resource-cleanup-stored-full-identity*
    (swapp-state-value "RESOURCE_CLEANUP_DEFINITION_IDENTITY_SIGNATURE")
  )
  (setq *swapp-last-resource-cleanup-stored-full-record*
    (swapp-state-value "RESOURCE_CLEANUP_DEFINITION_SIGNATURE")
  )
  (if (not *swapp-last-resource-cleanup-marked-p*)
    (progn
      (setq *swapp-last-resource-cleanup-integrity-ok* nil)
      (setq *swapp-last-resource-cleanup-identity-ok* nil)
      (setq *swapp-last-resource-cleanup-full-identity-ok* nil)
      (setq *swapp-last-resource-cleanup-full-record-ok* nil)
      (setq *swapp-last-resource-cleanup-current-integrity* nil)
      (setq *swapp-last-resource-cleanup-current-identity* nil)
      (setq *swapp-last-resource-cleanup-current-full-identity* nil)
      (setq *swapp-last-resource-cleanup-current-full-record* nil)
      nil
    )
    (progn
      (setq signature (swapp-workflow-integrity-signature snapshot))
      (setq definition-signature (swapp-named-definition-signature definitions))
      (setq identity-signature
        (swapp-named-definition-identity-signature definitions)
      )
      (setq stable-identity-signature
        (swapp-named-definition-stable-identity-signature definitions)
      )
      (setq *swapp-last-resource-cleanup-current-integrity* signature)
      (setq *swapp-last-resource-cleanup-current-identity* stable-identity-signature)
      (setq *swapp-last-resource-cleanup-current-full-identity* identity-signature)
      (setq *swapp-last-resource-cleanup-current-full-record* definition-signature)
      (setq *swapp-last-resource-cleanup-integrity-ok*
        (equal signature *swapp-last-resource-cleanup-stored-integrity*)
      )
      (setq *swapp-last-resource-cleanup-identity-ok*
        (equal stable-identity-signature *swapp-last-resource-cleanup-stored-identity*)
      )
      (setq *swapp-last-resource-cleanup-full-identity-ok*
        (equal identity-signature *swapp-last-resource-cleanup-stored-full-identity*)
      )
      (setq *swapp-last-resource-cleanup-full-record-ok*
        (equal definition-signature *swapp-last-resource-cleanup-stored-full-record*)
      )
      (and
        *swapp-last-resource-cleanup-integrity-ok*
        *swapp-last-resource-cleanup-identity-ok*
      )
    )
  )
)

(defun swapp-resource-cleanup-verify (/ marked-p snapshot definitions)
  (setq marked-p (swapp-resource-cleanup-marked-p))
  (if marked-p
    (progn
      (setq snapshot (swapp-workflow-integrity-snapshot))
      (setq definitions (swapp-named-definition-snapshot))
    )
  )
  (swapp-resource-cleanup-verify-from-snapshots marked-p snapshot definitions)
)

(defun swapp-resource-cleanup-success-state-items
  (
    passes-executed total-removed total-added total-added-records
    total-handle-reassigned removed-sample stable-removed-sample
    added-sample definition snapshot
    postsave-handle-reassigned state-save-passes state-save-rebases
    state-save-removed-sample state-save-added-sample
    state-save-handle-reregistered
    / definition-signature definition-identity-signature
      definition-stable-identity-signature appid-identity-signature
      vport-identity-signature session-anonymous-block-identity-signature
      final-table-count final-dictionary-count final-definition-count
  )
  (setq definition-signature (swapp-named-definition-signature definition))
  (setq definition-identity-signature
    (swapp-named-definition-identity-signature definition)
  )
  (setq definition-stable-identity-signature
    (swapp-named-definition-stable-identity-signature definition)
  )
  (setq appid-identity-signature
    (swapp-named-definition-appid-identity-signature definition)
  )
  (setq vport-identity-signature
    (swapp-named-definition-vport-identity-signature definition)
  )
  (setq session-anonymous-block-identity-signature
    (swapp-named-definition-session-anonymous-block-identity-signature
      definition
    )
  )
  (setq final-table-count (nth 0 definition))
  (setq final-dictionary-count (nth 1 definition))
  (setq final-definition-count (length (nth 2 definition)))
  (list
    (cons "RESOURCE_CLEANUP" "OK")
    (cons "RESOURCE_CLEANUP_POLICY" *swapp-resource-cleanup-policy*)
    (cons "RESOURCE_CLEANUP_SCOPE" "ALL_UNUSED_NAMED_DEFINITIONS")
    (cons "RESOURCE_CLEANUP_NATIVE_COMMAND" "-PURGE_NAMED_CATEGORIES")
    (cons "RESOURCE_CLEANUP_STABLE_IDENTITY_EXCLUDED" "APPID|VPORT|EMPTY_ANONYMOUS_BLOCK")
    (cons "RESOURCE_CLEANUP_CATEGORY_COUNT" (itoa (length *swapp-purge-command-categories*)))
    (cons "RESOURCE_CLEANUP_EXCLUDED" "ZERO_LENGTH|EMPTY_TEXT|ORPHANED_DATA")
    (cons "RESOURCE_CLEANUP_ZERO_PASS" "YES")
    (cons "RESOURCE_CLEANUP_REMOVED" (itoa total-removed))
    (cons "RESOURCE_CLEANUP_REMOVED_SAMPLE" removed-sample)
    (cons "RESOURCE_CLEANUP_STABLE_REMOVED_SAMPLE" stable-removed-sample)
    (cons "RESOURCE_CLEANUP_ADDED_IDENTITIES" (itoa total-added))
    (cons "RESOURCE_CLEANUP_ADDED_RECORDS" (itoa total-added-records))
    (cons "RESOURCE_CLEANUP_HANDLE_REREGISTERED" (itoa total-handle-reassigned))
    (cons "RESOURCE_CLEANUP_ADDED_SAMPLE" added-sample)
    (cons "RESOURCE_CLEANUP_PASSES" (itoa passes-executed))
    (cons "RESOURCE_CLEANUP_TABLE_COUNT" (itoa final-table-count))
    (cons "RESOURCE_CLEANUP_DICTIONARY_COUNT" (itoa final-dictionary-count))
    (cons "RESOURCE_CLEANUP_DEFINITION_COUNT" (itoa final-definition-count))
    (cons "RESOURCE_CLEANUP_DEFINITION_IDENTITY_SIGNATURE" definition-identity-signature)
    (cons "RESOURCE_CLEANUP_STABLE_DEFINITION_IDENTITY_SIGNATURE" definition-stable-identity-signature)
    (cons "RESOURCE_CLEANUP_APPID_IDENTITY_SIGNATURE" appid-identity-signature)
    (cons "RESOURCE_CLEANUP_VPORT_IDENTITY_SIGNATURE" vport-identity-signature)
    (cons "RESOURCE_CLEANUP_SESSION_ANON_BLOCK_IDENTITY_SIGNATURE" session-anonymous-block-identity-signature)
    (cons "RESOURCE_CLEANUP_DEFINITION_SIGNATURE" definition-signature)
    (cons "RESOURCE_CLEANUP_POST_SAVE_REMOVED_IDENTITIES" "0")
    (cons "RESOURCE_CLEANUP_POST_SAVE_ADDED_IDENTITIES" "0")
    (cons "RESOURCE_CLEANUP_POST_SAVE_HANDLE_REREGISTERED" (itoa postsave-handle-reassigned))
    (cons "RESOURCE_CLEANUP_STATE_SAVE_STABILIZATION_PASSES" (itoa state-save-passes))
    (cons "RESOURCE_CLEANUP_STATE_SAVE_REBASE_COUNT" (itoa state-save-rebases))
    (cons "RESOURCE_CLEANUP_STATE_SAVE_REMOVED_SAMPLE" state-save-removed-sample)
    (cons "RESOURCE_CLEANUP_STATE_SAVE_ADDED_SAMPLE" state-save-added-sample)
    (cons "RESOURCE_CLEANUP_STATE_SAVE_HANDLE_REREGISTERED" (itoa state-save-handle-reregistered))
    (cons "RESOURCE_CLEANUP_INTEGRITY" (swapp-workflow-integrity-signature snapshot))
  )
)

(defun swapp-run-resource-cleanup (/ doc undo-open before after before-sentinel after-sentinel pass passes-executed command-result command-ok definition-initial definition-before definition-after definition-presave initial-volatile-identities before-records after-records before-identities after-identities presave-records presave-identities postsave-records postsave-identities removed-records added-records removed-identities added-identities postsave-removed-records postsave-added-records postsave-removed-identities postsave-added-identities removed added record-removed record-added handle-reassigned postsave-handle-reassigned total-removed total-added total-added-records total-handle-reassigned removed-records-seen added-records-seen zero-pass integrity-ok definition-changed failure-status failure-detail rollback-needed undo-result undo-ok removed-sample stable-removed-sample added-sample presave-ok state-save-pass state-save-passes-executed state-save-rebase-count state-save-stable state-save-ok state-save-after state-save-definition state-save-baseline-records state-save-current-records state-save-baseline-identities state-save-current-identities state-save-removed-records state-save-added-records state-save-removed-identities state-save-added-identities state-save-removed-seen state-save-added-seen state-save-removed-sample state-save-added-sample state-save-handle-reregistered state-save-total-handle-reregistered final-verify-ok)
  (swapp-activate-model)
  (if (not (swcad-title-ensure-work-copy-for-mutation))
    (progn
      (princ "\n리소스 정리 중단: 작업본을 만들지 않았습니다.")
      nil
    )
    (progn
      (princ "\n----- SWCAD 전체 미사용 이름 정의 정리 -----")
      (princ "\n대상: CAD가 미사용으로 판정한 블록/레이어/스타일/재질/등록 응용프로그램 등 14개 이름 정의 범주")
      (princ "\n명령 수준 제외: 길이 0 형상, 빈 문자 객체, 분리된 데이터. 모델/종이공간/GMTITLE/치수/Layout 무결성이 달라지면 전체 UNDO")
      (setq before (swapp-workflow-integrity-snapshot))
      (setq before-sentinel
        (swapp-workflow-integrity-sentinel-from-snapshot before)
      )
      (setq doc (swapp-doc))
      (setq undo-open nil)
      (if (swapp-call-ok-p 'vla-StartUndoMark (list doc)) (setq undo-open T))
      (setq pass 1)
      (setq passes-executed 0)
      (setq total-removed 0)
      (setq total-added 0)
      (setq total-added-records 0)
      (setq total-handle-reassigned 0)
      (setq removed-records-seen nil)
      (setq added-records-seen nil)
      (setq zero-pass nil)
      (setq integrity-ok T)
      (setq command-ok undo-open)
      (setq failure-status (if undo-open nil "FAILED_UNDO_MARK"))
      (setq failure-detail (if undo-open "" "정리 전체를 한 번에 되돌릴 UNDO mark를 시작하지 못했습니다."))
      (setq definition-after (swapp-named-definition-snapshot))
      (setq definition-initial definition-after)
      (setq initial-volatile-identities
        (swapp-definition-record-identities
          (swapp-definition-records-filter-volatile (nth 2 definition-initial) T)
        )
      )
      (setq definition-changed nil)
      (while
        (and
          command-ok integrity-ok (not zero-pass)
          (<= pass *swapp-resource-cleanup-max-passes*)
        )
        (setq definition-before definition-after)
        (setq before-records (nth 2 definition-before))
        (setq command-result (swapp-native-purge-named-pass))
        (setq passes-executed (1+ passes-executed))
        (setq definition-after (swapp-named-definition-snapshot))
        (setq after-records (nth 2 definition-after))
        (setq before-identities (swapp-definition-record-identities before-records))
        (setq after-identities (swapp-definition-record-identities after-records))
        (setq removed-records (swapp-string-list-difference before-records after-records))
        (setq added-records (swapp-string-list-difference after-records before-records))
        (setq removed-identities (swapp-string-list-difference before-identities after-identities))
        (setq added-identities (swapp-string-list-difference after-identities before-identities))
        (setq removed (length removed-identities))
        (setq added (length added-identities))
        (setq record-removed (length removed-records))
        (setq record-added (length added-records))
        (setq handle-reassigned (max 0 (- record-added added)))
        (setq total-removed (+ total-removed removed))
        (setq total-added (+ total-added added))
        (setq total-added-records (+ total-added-records record-added))
        (setq total-handle-reassigned (+ total-handle-reassigned handle-reassigned))
        (if removed-records
          (setq removed-records-seen
            (swapp-string-list-union removed-records-seen removed-records)
          )
        )
        (if added-records
          (setq added-records-seen
            (swapp-string-list-union added-records-seen added-records)
          )
        )
        (setq definition-changed
          (or
            definition-changed
            (not (equal (nth 2 definition-initial) after-records))
          )
        )
        ;; A zero-definition-change pass is followed immediately by the full
        ;; pre-save audit, so do not duplicate its intermediate sentinel.
        (if (equal before-records after-records)
          (setq integrity-ok T)
          (progn
            (setq after-sentinel (swapp-workflow-integrity-sentinel-snapshot))
            (setq integrity-ok
              (swapp-workflow-integrity-sentinel-equal-p
                before-sentinel after-sentinel
              )
            )
          )
        )
        (if (not (car command-result))
          (progn
            (setq command-ok nil)
            (setq failure-status "FAILED_COMMAND")
            (setq failure-detail (cadr command-result))
          )
          (progn
            (princ
              (strcat
                "\n정리 반복 #" (itoa pass)
                ": 이름 정의 " (itoa (length before-records))
                " -> " (itoa (length after-records))
                ", 실제 삭제 " (itoa removed) "개"
                ", 자동 생성 " (itoa added) "개"
                ", handle 재등록 " (itoa handle-reassigned) "개"
              )
            )
            (if added-records
              (progn
                (swapp-print-definition-record-sample
                  "GstarCAD가 이번 반복에서 생성하거나 새 handle로 등록한 정의:"
                  added-records
                  12
                )
                (princ "\n이 항목은 즉시 실패로 보지 않고 다음 반복에서 고정점 수렴 여부를 확인합니다.")
              )
            )
            (if (equal before-records after-records) (setq zero-pass T))
          )
        )
        (if (not integrity-ok)
          (progn
            (setq failure-status "FAILED_INTEGRITY")
            (setq failure-detail "정리 전후 모델/종이공간/GMTITLE/치수/Layout/출처 메타데이터가 달라졌습니다."))
        )
        (setq pass (1+ pass))
      )
      (if (and command-ok integrity-ok (not zero-pass))
        (progn
          (setq failure-status "FAILED_NOT_CONVERGED")
          (setq failure-detail "제한 반복 안에 이름 정의 삭제 0개 고정점에 도달하지 못했습니다."))
      )
      ;; Retain one full geometry audit before the first save.  The sentinel
      ;; replaces only the repeated bbox scans inside the purge loop.
      (if (and command-ok integrity-ok zero-pass (not failure-status))
        (progn
          (setq after (swapp-workflow-integrity-snapshot))
          (setq integrity-ok (swapp-workflow-integrity-equal-p before after))
          (if (not integrity-ok)
            (progn
              (setq failure-status "FAILED_INTEGRITY")
              (setq failure-detail "저장 전 전체 무결성 검사에서 도면 데이터 변경이 감지되었습니다.")
            )
          )
        )
      )
      (setq rollback-needed
        (and
          failure-status
          (or definition-changed (not integrity-ok))
        )
      )
      (setq undo-ok T)
      (setq removed-sample
        (swapp-definition-record-sample-text removed-records-seen 12 1800)
      )
      (setq stable-removed-sample
        (swapp-definition-record-sample-text
          (swapp-definition-record-identities
            (swapp-definition-records-exclude-identities
              removed-records-seen
              initial-volatile-identities
            )
          )
          12
          1800
        )
      )
      (setq added-sample
        (swapp-definition-record-sample-text added-records-seen 6 900)
      )
      (if rollback-needed
        (progn
          (if undo-open
            (progn
              (swapp-safe 'vla-EndUndoMark (list doc))
              (setq undo-open nil)
            )
          )
          (setq undo-result (vl-catch-all-apply 'vl-cmdf (list "_.UNDO" "1")))
          (setq undo-ok
            (and
              (not (vl-catch-all-error-p undo-result))
              (= (getvar "CMDACTIVE") 0)
              (swapp-workflow-integrity-equal-p before (swapp-workflow-integrity-snapshot))
              (equal (nth 2 definition-initial) (nth 2 (swapp-named-definition-snapshot)))
            )
          )
        )
      )
      (cond
        (failure-status
          (if undo-open
            (progn
              (swapp-safe 'vla-EndUndoMark (list doc))
              (setq undo-open nil)
            )
          )
          (swapp-state-replace-prefix
            "RESOURCE_CLEANUP"
            (list
              (cons "RESOURCE_CLEANUP" (if undo-ok failure-status (strcat failure-status "_UNDO_FAILED")))
              (cons "RESOURCE_CLEANUP_POLICY" *swapp-resource-cleanup-policy*)
              (cons "RESOURCE_CLEANUP_DETAIL" failure-detail)
              (cons "RESOURCE_CLEANUP_ROLLBACK" (if rollback-needed (if undo-ok "OK" "FAILED") "NOT_NEEDED"))
              (cons "RESOURCE_CLEANUP_PASSES" (itoa passes-executed))
              (cons "RESOURCE_CLEANUP_REMOVED" (itoa total-removed))
              (cons "RESOURCE_CLEANUP_REMOVED_SAMPLE" removed-sample)
              (cons "RESOURCE_CLEANUP_STABLE_REMOVED_SAMPLE" stable-removed-sample)
              (cons "RESOURCE_CLEANUP_ADDED_IDENTITIES" (itoa total-added))
              (cons "RESOURCE_CLEANUP_ADDED_RECORDS" (itoa total-added-records))
              (cons "RESOURCE_CLEANUP_HANDLE_REREGISTERED" (itoa total-handle-reassigned))
              (cons "RESOURCE_CLEANUP_ADDED_SAMPLE" added-sample)
            )
          )
          (princ (strcat "\n결과: SWCAD_RESOURCE_CLEANUP_" failure-status))
          (princ (strcat "\n원인: " failure-detail))
          (if rollback-needed
            (princ (strcat "\n정리 전체 UNDO: " (if undo-ok "성공" "실패")))
          )
          (princ "\n같은 명령을 반복하지 말고 현재 상태를 SWCADVERIFY와 로그로 확인하세요.")
          nil
        )
        (T
          ;; Saving can legitimately re-register dictionary/table handles.  Capture
          ;; the persisted database before writing the final cleanup audit state,
          ;; and reject only real definition identities or workflow data changes.
          (setq definition-presave definition-after)
          (setq presave-records (nth 2 definition-presave))
          (setq presave-identities
            (swapp-definition-record-identities presave-records)
          )
          (setq presave-ok (swapp-save-current))
          ;; A full bbox audit ran immediately before this save and another
          ;; runs after the cleanup state is persisted.  Defer only this
          ;; middle model-bbox rescan while retaining every other invariant.
          (setq after
            (swapp-workflow-integrity-snapshot-with-model-bbox (nth 1 before))
          )
          (setq definition-after (swapp-named-definition-snapshot))
          (setq postsave-records (nth 2 definition-after))
          (setq postsave-identities
            (swapp-definition-record-identities postsave-records)
          )
          (setq postsave-removed-records
            (swapp-string-list-difference presave-records postsave-records)
          )
          (setq postsave-added-records
            (swapp-string-list-difference postsave-records presave-records)
          )
          (setq postsave-removed-identities
            (swapp-string-list-difference presave-identities postsave-identities)
          )
          (setq postsave-added-identities
            (swapp-string-list-difference postsave-identities presave-identities)
          )
          (setq postsave-handle-reassigned
            (max
              0
              (-
                (length postsave-added-records)
                (length postsave-added-identities)
              )
            )
          )
          (setq integrity-ok (swapp-workflow-integrity-equal-p before after))
          (if
            (or
              (not presave-ok)
              (not integrity-ok)
              postsave-removed-identities
              postsave-added-identities
            )
            (progn
              (setq failure-status
                (if presave-ok "FAILED_POST_SAVE_CHANGE" "FAILED_PRE_SAVE")
              )
              (setq failure-detail
                (if presave-ok
                  (strcat
                    "저장 직후 도면 무결성 또는 실제 이름 정의가 달라졌습니다. 무결성="
                    (if integrity-ok "OK" "CHANGED")
                    ", 정의 삭제=" (itoa (length postsave-removed-identities))
                    ", 정의 생성=" (itoa (length postsave-added-identities))
                  )
                  "정리 결과를 첫 저장 단계에서 DWG에 저장하지 못했습니다."
                )
              )
              (if undo-open
                (progn
                  (swapp-safe 'vla-EndUndoMark (list doc))
                  (setq undo-open nil)
                )
              )
              (setq undo-result
                (vl-catch-all-apply 'vl-cmdf (list "_.UNDO" "1"))
              )
              (setq undo-ok
                (and
                  (not (vl-catch-all-error-p undo-result))
                  (= (getvar "CMDACTIVE") 0)
                  (swapp-workflow-integrity-equal-p
                    before
                    (swapp-workflow-integrity-snapshot)
                  )
                  (equal
                    (swapp-definition-record-identities (nth 2 definition-initial))
                    (swapp-definition-record-identities
                      (nth 2 (swapp-named-definition-snapshot))
                    )
                  )
                )
              )
              (swapp-state-replace-prefix
                "RESOURCE_CLEANUP"
                (list
                  (cons "RESOURCE_CLEANUP" (if undo-ok failure-status (strcat failure-status "_UNDO_FAILED")))
                  (cons "RESOURCE_CLEANUP_POLICY" *swapp-resource-cleanup-policy*)
                  (cons "RESOURCE_CLEANUP_DETAIL" failure-detail)
                  (cons "RESOURCE_CLEANUP_ROLLBACK" (if undo-ok "OK" "FAILED"))
                  (cons "RESOURCE_CLEANUP_PASSES" (itoa passes-executed))
                  (cons "RESOURCE_CLEANUP_REMOVED" (itoa total-removed))
                  (cons "RESOURCE_CLEANUP_POST_SAVE_REMOVED_IDENTITIES" (itoa (length postsave-removed-identities)))
                  (cons "RESOURCE_CLEANUP_POST_SAVE_ADDED_IDENTITIES" (itoa (length postsave-added-identities)))
                  (cons "RESOURCE_CLEANUP_POST_SAVE_HANDLE_REREGISTERED" (itoa postsave-handle-reassigned))
                )
              )
              (swapp-save-current)
              (princ (strcat "\n결과: SWCAD_RESOURCE_CLEANUP_" failure-status))
              (princ (strcat "\n원인: " failure-detail))
              (princ (strcat "\n정리 전체 UNDO: " (if undo-ok "성공" "실패")))
              nil
            )
            (progn
              (setq state-save-pass 1)
              (setq state-save-passes-executed 0)
              (setq state-save-rebase-count 0)
              (setq state-save-stable nil)
              (setq state-save-ok T)
              (setq state-save-removed-seen nil)
              (setq state-save-added-seen nil)
              (setq state-save-total-handle-reregistered 0)
              (while
                (and
                  state-save-ok integrity-ok (not state-save-stable)
                  (<= state-save-pass *swapp-resource-cleanup-state-save-max-passes*)
                )
                (setq state-save-passes-executed state-save-pass)
                (setq state-save-removed-sample
                  (swapp-definition-record-sample-text state-save-removed-seen 6 900)
                )
                (setq state-save-added-sample
                  (swapp-definition-record-sample-text state-save-added-seen 6 900)
                )
                (swapp-state-replace-prefix
                  "RESOURCE_CLEANUP"
                  (swapp-resource-cleanup-success-state-items
                    passes-executed total-removed total-added total-added-records
                    total-handle-reassigned removed-sample stable-removed-sample
                    added-sample definition-after after
                    postsave-handle-reassigned state-save-passes-executed
                    state-save-rebase-count state-save-removed-sample
                    state-save-added-sample state-save-total-handle-reregistered
                  )
                )
                (setq state-save-ok (swapp-save-current))
                (if state-save-ok
                  (progn
                    (setq state-save-after (swapp-workflow-integrity-snapshot))
                    (setq state-save-definition (swapp-named-definition-snapshot))
                    (setq state-save-baseline-records (nth 2 definition-after))
                    (setq state-save-current-records (nth 2 state-save-definition))
                    (setq state-save-baseline-identities
                      (swapp-definition-record-identities state-save-baseline-records)
                    )
                    (setq state-save-current-identities
                      (swapp-definition-record-identities state-save-current-records)
                    )
                    (setq state-save-removed-records
                      (swapp-string-list-difference
                        state-save-baseline-records state-save-current-records
                      )
                    )
                    (setq state-save-added-records
                      (swapp-string-list-difference
                        state-save-current-records state-save-baseline-records
                      )
                    )
                    (setq state-save-removed-identities
                      (swapp-string-list-difference
                        state-save-baseline-identities state-save-current-identities
                      )
                    )
                    (setq state-save-added-identities
                      (swapp-string-list-difference
                        state-save-current-identities state-save-baseline-identities
                      )
                    )
                    (setq state-save-handle-reregistered
                      (max
                        0
                        (-
                          (length state-save-added-records)
                          (length state-save-added-identities)
                        )
                      )
                    )
                    (setq state-save-total-handle-reregistered
                      (+
                        state-save-total-handle-reregistered
                        state-save-handle-reregistered
                      )
                    )
                    (setq integrity-ok
                      (swapp-workflow-integrity-equal-p before state-save-after)
                    )
                    (setq state-save-stable
                      (and
                        integrity-ok
                        (not state-save-removed-identities)
                        (not state-save-added-identities)
                      )
                    )
                    (if state-save-stable
                      (progn
                        (setq after state-save-after)
                        (setq definition-after state-save-definition)
                      )
                      (if integrity-ok
                        (progn
                          (princ
                            (strcat
                              "\n감사 상태 저장 고정점 #" (itoa state-save-pass)
                              ": 실제 정의 삭제 " (itoa (length state-save-removed-identities))
                              "개, 생성 " (itoa (length state-save-added-identities))
                              "개. 저장된 현재 상태로 다시 기준을 맞춥니다."
                            )
                          )
                          (swapp-print-definition-record-sample
                            "저장 중 사라진 정의 정체성 표본:"
                            state-save-removed-identities
                            8
                          )
                          (swapp-print-definition-record-sample
                            "저장 중 생긴 정의 정체성 표본:"
                            state-save-added-identities
                            8
                          )
                          (setq state-save-removed-seen
                            (swapp-string-list-union
                              state-save-removed-seen state-save-removed-identities
                            )
                          )
                          (setq state-save-added-seen
                            (swapp-string-list-union
                              state-save-added-seen state-save-added-identities
                            )
                          )
                          (setq state-save-rebase-count (1+ state-save-rebase-count))
                          (setq after state-save-after)
                          (setq definition-after state-save-definition)
                        )
                      )
                    )
                  )
                )
                (setq state-save-pass (1+ state-save-pass))
              )
              (cond
                ((not state-save-ok)
                  (setq failure-status "FAILED_STATE_SAVE")
                  (setq failure-detail "감사 상태를 DWG에 저장하지 못했습니다.")
                )
                ((not integrity-ok)
                  (setq failure-status "FAILED_STATE_SAVE_INTEGRITY")
                  (setq failure-detail "감사 상태 저장 중 도면 무결성 지문이 달라졌습니다.")
                )
                ((not state-save-stable)
                  (setq failure-status "FAILED_STATE_SAVE_NOT_CONVERGED")
                  (setq failure-detail
                    (strcat
                      "감사 상태 저장과 정의 정체성 지문이 "
                      (itoa *swapp-resource-cleanup-state-save-max-passes*)
                      "회 안에 고정되지 않았습니다."
                    )
                  )
                )
              )
              (if (not failure-status)
                (progn
                  ;; The state-save pass already captured the persisted database.
                  ;; Reuse it here instead of immediately repeating the full audit.
                  (setq final-verify-ok
                    (swapp-resource-cleanup-verify-from-snapshots
                      (swapp-resource-cleanup-marked-p)
                      state-save-after
                      state-save-definition
                    )
                  )
                  (if (not final-verify-ok)
                    (progn
                      (setq failure-status "FAILED_STATE_SAVE_AUDIT")
                      (setq failure-detail "저장 고정점 직후 자체 감사 지문이 일치하지 않았습니다.")
                    )
                  )
                )
              )
              (if failure-status
                (progn
                  (if undo-open
                    (progn
                      (swapp-safe 'vla-EndUndoMark (list doc))
                      (setq undo-open nil)
                    )
                  )
                  (setq undo-result
                    (vl-catch-all-apply 'vl-cmdf (list "_.UNDO" "1"))
                  )
                  (setq undo-ok
                    (and
                      (not (vl-catch-all-error-p undo-result))
                      (= (getvar "CMDACTIVE") 0)
                      (swapp-workflow-integrity-equal-p
                        before
                        (swapp-workflow-integrity-snapshot)
                      )
                      (equal
                        (swapp-definition-record-identities (nth 2 definition-initial))
                        (swapp-definition-record-identities
                          (nth 2 (swapp-named-definition-snapshot))
                        )
                      )
                    )
                  )
                  (setq state-save-removed-sample
                    (swapp-definition-record-sample-text state-save-removed-seen 6 900)
                  )
                  (setq state-save-added-sample
                    (swapp-definition-record-sample-text state-save-added-seen 6 900)
                  )
                  (swapp-state-replace-prefix
                    "RESOURCE_CLEANUP"
                    (list
                      (cons "RESOURCE_CLEANUP" (if undo-ok failure-status (strcat failure-status "_UNDO_FAILED")))
                      (cons "RESOURCE_CLEANUP_POLICY" *swapp-resource-cleanup-policy*)
                      (cons "RESOURCE_CLEANUP_DETAIL" failure-detail)
                      (cons "RESOURCE_CLEANUP_ROLLBACK" (if undo-ok "OK" "FAILED"))
                      (cons "RESOURCE_CLEANUP_PASSES" (itoa passes-executed))
                      (cons "RESOURCE_CLEANUP_REMOVED" (itoa total-removed))
                      (cons "RESOURCE_CLEANUP_STATE_SAVE_STABILIZATION_PASSES" (itoa state-save-passes-executed))
                      (cons "RESOURCE_CLEANUP_STATE_SAVE_REBASE_COUNT" (itoa state-save-rebase-count))
                      (cons "RESOURCE_CLEANUP_STATE_SAVE_REMOVED_SAMPLE" state-save-removed-sample)
                      (cons "RESOURCE_CLEANUP_STATE_SAVE_ADDED_SAMPLE" state-save-added-sample)
                      (cons "RESOURCE_CLEANUP_STATE_SAVE_HANDLE_REREGISTERED" (itoa state-save-total-handle-reregistered))
                    )
                  )
                  (swapp-save-current)
                  (princ (strcat "\n결과: SWCAD_RESOURCE_CLEANUP_" failure-status))
                  (princ (strcat "\n원인: " failure-detail))
                  (princ (strcat "\n정리 전체 UNDO: " (if undo-ok "성공" "실패")))
                  nil
                )
                (progn
                  (if undo-open
                    (progn
                      (swapp-safe 'vla-EndUndoMark (list doc))
                      (setq undo-open nil)
                    )
                  )
                  (if (> postsave-handle-reassigned 0)
                    (princ
                      (strcat
                        "\n첫 저장 과정의 안전한 handle 재등록: "
                        (itoa postsave-handle-reassigned) "개"
                      )
                    )
                  )
                  (princ
                    (strcat
                      "\n감사 상태 저장 고정점: "
                      (itoa state-save-passes-executed) "회, 재기준화 "
                      (itoa state-save-rebase-count) "회"
                    )
                  )
                  (princ
                    (strcat
                      "\n결과: SWCAD_RESOURCE_CLEANUP_OK, 전체 미사용 이름 정의 삭제 "
                      (itoa total-removed) "개, 마지막 반복 변경 0개"
                    )
                  )
                  T
                )
              )
            )
          )
        )
      )
    )
  )
)

(defun swapp-final-sheet-record-serialize (item / frame-handle title-handle window ll ur)
  (setq frame-handle (swapp-layout-plan-item-handle item))
  (setq title-handle
    (if (nth 7 item)
      (cdr (assoc 5 (entget (nth 7 item))))
      ""
    )
  )
  (setq window (cadr item))
  (setq ll (car window))
  (setq ur (cadr window))
  (strcat
    (swapp-state-field-encode frame-handle) "|"
    (swapp-state-field-encode (if title-handle title-handle "")) "|"
    (swapp-state-field-encode (nth 2 item)) "|"
    (swapp-state-field-encode (nth 5 item)) "|"
    (swapp-state-field-encode (nth 6 item)) "|"
    (rtos (car ll) 2 8) "|" (rtos (cadr ll) 2 8) "|"
    (rtos (car ur) 2 8) "|" (rtos (cadr ur) 2 8)
  )
)

(defun swapp-final-sheet-records-write (plan / replacements item index)
  (setq replacements
    (list
      (cons "FINAL_SHEET_STATUS" "MAPPED_TO_GMTITLE_AND_LAYOUT")
      (cons "FINAL_SHEET_COUNT" (itoa (length plan)))
    )
  )
  (setq index 1)
  (foreach item plan
    (setq replacements
      (append
        replacements
        (list
          (cons
            (strcat *swapp-final-sheet-state-prefix* (swapp-index-text index))
            (swapp-final-sheet-record-serialize item)
          )
        )
      )
    )
    (setq index (1+ index))
  )
  (swapp-state-replace-prefix *swapp-final-sheet-state-prefix* replacements)
)

(defun swapp-max-paper-layout-tab-order (/ layouts layout name value result)
  (setq layouts (vla-get-Layouts (swapp-doc)))
  (setq result 0)
  (vlax-for layout layouts
    (setq name (vla-get-Name layout))
    (if (not (equal (strcase name) "MODEL"))
      (progn
        (setq value (swapp-safe 'vla-get-TabOrder (list layout)))
        (if (and (numberp value) (> value result)) (setq result value))
      )
    )
  )
  result
)

(defun swapp-create-named-layouts (plan / doc undo-open oldcmdecho tab-base index item name window result layout created ok)
  (setq doc (swapp-doc))
  (setq undo-open nil)
  (setq oldcmdecho (getvar "CMDECHO"))
  (setvar "CMDECHO" 0)
  (if (swapp-call-ok-p 'vla-StartUndoMark (list doc)) (setq undo-open T))
  (gsla-ensure-vport-layer)
  (setq tab-base (swapp-max-paper-layout-tab-order))
  (setq index 1)
  (setq created 0)
  (setq ok T)
  (foreach item plan
    (if ok
      (progn
        (setq name (nth 5 item))
        (setq window (cadr item))
        (if (or (gsla-layout-exists-p name) (<= (gsla-window-width window) 1e-9) (<= (gsla-window-height window) 1e-9))
          (setq ok nil)
          (progn
            (setq result (vl-catch-all-apply 'gsla-make-layout (list name window)))
            (if (vl-catch-all-error-p result)
              (setq ok nil)
              (progn
                (setq layout (swapp-safe 'vla-Item (list (vla-get-Layouts doc) name)))
                (if layout (swapp-safe 'vla-put-TabOrder (list layout (+ tab-base index))))
                (setq created (1+ created))
                (princ (strcat "\nLayout 생성: " name))
              )
            )
          )
        )
      )
    )
    (setq index (1+ index))
  )
  (setvar "CMDECHO" oldcmdecho)
  (if undo-open (swapp-safe 'vla-EndUndoMark (list doc)))
  (if (and ok (= created (length plan))) created nil)
)

(defun swapp-delete-app-layouts (/ names layouts model-layout name layout count)
  (setq names (swapp-layout-owned-names))
  (setq layouts (vla-get-Layouts (swapp-doc)))
  (setq model-layout (swapp-safe 'vla-Item (list layouts "Model")))
  (if model-layout (swapp-safe 'vla-put-ActiveLayout (list (swapp-doc) model-layout)))
  (setq count 0)
  (foreach name names
    (setq layout (swapp-safe 'vla-Item (list layouts name)))
    (if (and layout (swapp-call-ok-p 'vla-Delete (list layout)))
      (setq count (1+ count))
    )
  )
  count
)

(defun swapp-run-layout (/ plan names expected created ownership-ok mapping-ok result)
  (swapp-activate-model)
  (if (not (swcad-title-ensure-work-copy-for-mutation))
    (progn
      (princ "\nLayout 생성 중단: 작업본을 만들지 않았습니다.")
      nil
    )
    (progn
      (setq plan (swapp-layout-plan))
      (setq names (swapp-layout-plan-names plan))
      (setq expected (length plan))
      (cond
        ((= expected 0)
          (princ "\n결과: SWCAD_LAYOUT_NO_GMTITLE_FRAMES")
          nil
        )
        ((or
           (> (swcad-title-target-frame-geometry-warning-count (swcad-title-frame-records)) 0)
           (> (swcad-title-target-frame-overlap-warning-count (swcad-title-frame-records)) 0)
         )
          (princ "\n결과: SWCAD_LAYOUT_FRAME_GEOMETRY_BLOCKED")
          nil
        )
        (T
          (swapp-print-layout-plan-items plan *swapp-layout-preview-limit*)
          (swapp-delete-app-layouts)
          (setq created (swapp-create-named-layouts plan))
          (swapp-activate-model)
          (setq ownership-ok (if created (swapp-layout-owned-names-write names) nil))
          (setq mapping-ok (if ownership-ok (swapp-final-sheet-records-write plan) nil))
          (setq result (and created (= created expected) ownership-ok mapping-ok (swapp-layouts-valid-p plan)))
          (if result
            (progn
              (swapp-state-set "LAYOUT" "OK")
              (swapp-state-set "LAYOUT_PLACEMENT_MODE" *swapp-layout-placement-mode*)
              (swapp-state-set "LAYOUT_NAME_POLICY" "SOURCE_FILE_STEM_NO_PREFIX_NO_SEQUENCE")
              (swapp-state-set "LAYOUT_PLAN_COUNT" (itoa expected))
              (swapp-state-set "LAYOUT_PLAN_SIGNATURE" (swapp-layout-plan-signature plan))
              (swapp-state-set "LAYOUT_COUNT" (itoa expected))
              (swapp-save-current)
              (princ (strcat "\n결과: SWCAD_LAYOUT_OK, 생성 수=" (itoa expected)))
              T
            )
            (progn
              (swapp-state-set "LAYOUT" "FAILED")
              (princ "\n결과: SWCAD_LAYOUT_VERIFY_FAILED")
              nil
            )
          )
        )
      )
    )
  )
)

;;; ---------------------------
;;; Public workflow commands
;;; ---------------------------

(defun swapp-stage-label (stage)
  (cond
    ((equal stage "XREF") "1/6 입력 도면 준비 - XREF 분해")
    ((equal stage "SHEET_WRAPPERS") "1/6 입력 도면 준비 - 시트 묶음 분해")
    ((equal stage "TITLE") "2/6 GMTITLE 변환")
    ((equal stage "DIMSTYLE") "3/6 치수 스타일 통일")
    ((equal stage "LAYOUT") "4/6 원본 파일명 Layout 생성")
    ((equal stage "CLEANUP") "5/6 전체 미사용 이름 정의 정리")
    ((equal stage "COMPLETE") "6/6 최종 검증 준비 완료")
    ((equal stage "BLOCKED_NO_SHEETS") "중단 - 처리할 시트를 찾지 못함")
    (T stage)
  )
)

(defun swapp-title-action-label (action)
  (cond
    ((swcad-title-string-prefix-p "SWTITLEPREPARE" action) "도면틀/잔여물 사전 정리")
    ((swcad-title-string-prefix-p "SWTITLECONVERTNEXT" action) "다음 시트 GMTITLE 변환")
    ((swcad-title-string-prefix-p "SWTITLEVERIFY" action) "GMTITLE 최종 검증")
    (T "판정 불가")
  )
)

(defun swapp-title-last-status ()
  (if
    (and
      (boundp '*swcad-title-last-apply-status*)
      *swcad-title-last-apply-status*
    )
    (swcad-title-string *swcad-title-last-apply-status*)
    ""
  )
)

(defun swapp-title-blocking-status-p (status / upper)
  (setq upper (strcase (swcad-title-string status)))
  (and
    (> (strlen upper) 0)
    (or
      (swcad-title-string-prefix-p "ABORT_" upper)
      (swcad-title-string-prefix-p "ERROR_" upper)
      (swcad-title-string-prefix-p "WARN_" upper)
      (swcad-title-string-prefix-p "BLOCKED_" upper)
      (swcad-title-string-prefix-p "REVIEW_" upper)
      (swcad-title-string-prefix-p "SWTITLEVERIFY_WARN_" upper)
      (swcad-title-string-prefix-p "SWTITLEVERIFY_FINAL_WARN" upper)
      (swcad-title-string-prefix-p "SWTITLEVERIFY_FINAL_FAIL" upper)
    )
  )
)

(defun swapp-recommended-next-action (stage last-status)
  (cond
    ((equal stage "COMPLETE") "SWCADVERIFY")
    ((and (equal stage "TITLE") (swapp-title-blocking-status-p last-status))
      "SWCADRUN 반복 금지 - 현재 도면을 저장하지 말고 오류 원인을 확인하세요"
    )
    ((and (equal stage "DIMSTYLE") (equal (swapp-state-value "DIMSTYLE") "FAILED"))
      "SWCADRUN 반복 금지 - DIMSTYLE 실패 원인을 확인하세요"
    )
    ((and (equal stage "CLEANUP") (swapp-string-starts-ci-p (if (swapp-state-value "RESOURCE_CLEANUP") (swapp-state-value "RESOURCE_CLEANUP") "") "FAILED"))
      (if (swapp-resource-cleanup-retry-allowed-p)
        "SWCADRUN - 이전 LSP 버전의 정리 실패이므로 현재 버전에서 1회 재시도"
        "SWCADRUN 반복 금지 - 현재 LSP 버전의 리소스 정리 실패 원인과 무결성 로그를 확인하세요"
      )
    )
    ((and (equal stage "LAYOUT") (equal (swapp-state-value "LAYOUT") "FAILED"))
      "SWCADRUN 반복 금지 - Layout 생성 실패 원인을 확인하세요"
    )
    (T "SWCADRUN")
  )
)

(defun swapp-resource-cleanup-retry-allowed-p (/ cleanup-state stored-version)
  (setq cleanup-state (swapp-state-value "RESOURCE_CLEANUP"))
  (setq stored-version (swapp-state-value "VERSION"))
  (and
    (swapp-string-starts-ci-p (if cleanup-state cleanup-state "") "FAILED")
    stored-version
    (> (strlen stored-version) 0)
    (not (equal stored-version *swapp-version*))
  )
)

(defun swapp-print-status (/ stage stage-label last-status recommended references wrappers evidence frames layouts state plan)
  (swapp-activate-model)
  (setq stage (swapp-workflow-stage))
  (setq stage-label (swapp-stage-label stage))
  (setq last-status (swapp-title-last-status))
  (setq recommended (swapp-recommended-next-action stage last-status))
  (setq references (swapp-cached-top-xref-references))
  (setq wrappers (swapp-cached-sheet-wrapper-records))
  (setq evidence (swapp-cached-title-evidence))
  (setq frames (swapp-evidence-value evidence "target-frame-count"))
  (setq layouts (swapp-cached-layout-names))
  (setq state (swapp-state-read))
  (princ "\n===== SWCADSTATUS 통합 작업 상태 =====")
  (princ (strcat "\nSWCAD Workflow 버전: " *swapp-version*))
  (princ (strcat "\nDWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (princ (strcat "\n현재 단계: " stage-label " [" stage "]"))
  (if (> (strlen last-status) 0)
    (princ (strcat "\n마지막 GMTITLE 결과: " last-status))
  )
  (princ (strcat "\n최상위 XREF: " (itoa (length references))))
  (princ "\nXREF 배치 정책: 사용자가 정한 좌표 유지, 자동 이동 없음")
  (princ (strcat "\n중첩 시트 묶음: " (itoa (length wrappers))))
  (if wrappers
    (princ "\n시트 묶음 정책: 도면·치수·표제란을 품은 바깥 INSERT만 한 단계 분해")
  )
  (princ (strcat "\n최상위 치수: " (itoa (swapp-cached-top-dimension-count))))
  (princ (strcat "\n남은 원본 title/frame 합계: " (itoa (swapp-evidence-value evidence "source-count"))))
  (princ
    (strcat
      "\nGMTITLE 제목/도면틀/쌍/native-like: "
      (itoa (swapp-evidence-value evidence "target-title-count")) "/"
      (itoa frames) "/"
      (itoa (swapp-evidence-value evidence "target-pair-count")) "/"
      (itoa (swapp-evidence-value evidence "native-like-count"))
    )
  )
  (princ (strcat "\nDIMSTYLE 상태: " (if (swapp-state-value "DIMSTYLE") (swapp-state-value "DIMSTYLE") "미실행")))
  (princ (strcat "\n전체 미사용 이름 정의 정리: " (if (swapp-state-value "RESOURCE_CLEANUP") (swapp-state-value "RESOURCE_CLEANUP") "미실행")))
  (princ (strcat "\n원본 파일명 메타데이터: " (if (swapp-state-value "SOURCE_SHEET_COUNT") (swapp-state-value "SOURCE_SHEET_COUNT") "0") "개"))
  (princ (strcat "\nSWCAD Layout: " (itoa (length layouts)) " / 기대 " (itoa frames)))
  (princ (strcat "\nLayout 좌표 모드: " (if (swapp-state-value "LAYOUT_PLACEMENT_MODE") (swapp-state-value "LAYOUT_PLACEMENT_MODE") "미생성")))
  (princ (strcat "\nLayout 이름 정책: " (if (swapp-state-value "LAYOUT_NAME_POLICY") (swapp-state-value "LAYOUT_NAME_POLICY") "원본 파일명 stem 예정")))
  (if (member stage '("DIMSTYLE" "LAYOUT" "CLEANUP" "COMPLETE"))
    (progn
      (setq plan (swapp-layout-plan))
      (swapp-print-layout-plan-items plan *swapp-layout-preview-limit*)
    )
  )
  (princ (strcat "\n권장 다음 작업: " recommended))
  stage
)

(defun swapp-run-title-next (/ action action-label ran status)
  (swapp-activate-model)
  (setq action (swcad-title-integrated-structure-diagnosis))
  (setq action-label (swapp-title-action-label action))
  (setq ran nil)
  (if (boundp '*swcad-title-last-apply-status*)
    (setq *swcad-title-last-apply-status* nil)
  )
  (princ (strcat "\n이번 GMTITLE 하위 단계: " action-label " [" action "]"))
  (cond
    ((swcad-title-string-prefix-p "SWTITLEPREPARE" action)
      (setq ran T)
      (c:SWTITLEPREPARE)
    )
    ((swcad-title-string-prefix-p "SWTITLECONVERTNEXT" action)
      (setq ran T)
      (c:SWTITLECONVERTNEXT)
    )
    ((swcad-title-string-prefix-p "SWTITLEVERIFY" action)
      (setq ran T)
      (c:SWTITLEVERIFY)
    )
    (T (princ "\nGMTITLE 다음 단계를 안전하게 결정하지 못했습니다. SWTITLESTATUS 로그를 확인하세요."))
  )
  (setq status (swapp-title-last-status))
  (cond
    ((not ran)
      (princ "\n진행 중지: 판정되지 않은 상태에서 SWCADRUN을 반복하지 마세요.")
      nil
    )
    ((swapp-title-blocking-status-p status)
      (princ (strcat "\n진행 중지: GMTITLE 결과가 " status " 입니다."))
      (princ "\n현재 도면을 저장하지 말고 원인을 확인하세요. SWCADRUN을 반복하지 마세요.")
      nil
    )
    (T
      (princ (strcat "\n이번 GMTITLE 하위 단계 완료. 결과=" (if (> (strlen status) 0) status "<상태 없음>")))
      (princ "\nSWCADSTATUS에서 단계 변화를 확인한 뒤 안내가 SWCADRUN일 때만 계속하세요.")
      T
    )
  )
)

(defun c:SWCADSTATUS (/ result)
  (swapp-command-performance-begin)
  (swapp-read-cache-begin)
  (setq result (vl-catch-all-apply 'swapp-print-status nil))
  (swapp-read-cache-end)
  (swapp-command-performance-end "SWCADSTATUS")
  (if (vl-catch-all-error-p result)
    (princ (strcat "\nSWCADSTATUS 오류: " (vl-catch-all-error-message result)))
  )
  (princ)
)

(defun c:SWCADRUN (/ stage after-stage run-result mutating-stage cleanup-retry-blocked)
  (swapp-command-performance-begin)
  (swapp-read-cache-begin)
  (setq stage (swapp-workflow-stage))
  (setq cleanup-retry-blocked
    (and
      (equal stage "CLEANUP")
      (swapp-string-starts-ci-p
        (if (swapp-state-value "RESOURCE_CLEANUP") (swapp-state-value "RESOURCE_CLEANUP") "")
        "FAILED"
      )
      (not (swapp-resource-cleanup-retry-allowed-p))
    )
  )
  (setq mutating-stage
    (and
      (if (member stage '("XREF" "SHEET_WRAPPERS" "TITLE" "DIMSTYLE" "CLEANUP" "LAYOUT")) T nil)
      (not cleanup-retry-blocked)
    )
  )
  (princ "\n===== SWCADRUN 다음 안전 단계 실행 =====")
  (princ (strcat "\n실행 전 단계: " (swapp-stage-label stage) " [" stage "]"))
  (setq run-result nil)
  (if mutating-stage (swapp-read-cache-end))
  (cond
    (cleanup-retry-blocked
      (princ "\n현재 LSP 버전에서 실패한 리소스 정리는 자동 재실행하지 않습니다.")
      (princ "\nRESOURCE_CLEANUP_DETAIL과 무결성 로그를 확인하거나 수정된 새 버전을 로드하세요.")
    )
    ((equal stage "XREF") (setq run-result (swapp-materialize-xrefs)))
    ((equal stage "SHEET_WRAPPERS") (setq run-result (swapp-materialize-sheet-wrappers)))
    ((equal stage "TITLE") (setq run-result (swapp-run-title-next)))
    ((equal stage "DIMSTYLE") (setq run-result (swapp-run-dimstyle)))
    ((equal stage "CLEANUP") (setq run-result (swapp-run-resource-cleanup)))
    ((equal stage "LAYOUT") (setq run-result (swapp-run-layout)))
    ((equal stage "COMPLETE") (princ "\n모든 단계가 준비됐습니다. SWCADVERIFY를 실행하세요."))
    (T (princ "\n처리할 도면틀/XREF를 찾지 못했습니다. 새 호스트 도면의 XREF 상태를 확인하세요."))
  )
  (if mutating-stage (swapp-read-cache-begin))
  ;; A successful cleanup just completed a persisted full audit.  Hand that
  ;; result to the immediate stage/status reads in this same command only.
  (if (and (equal stage "CLEANUP") run-result)
    (swapp-read-cache-seed "RESOURCE_CLEANUP_VERIFY" T)
  )
  (setq after-stage (swapp-workflow-stage))
  (princ (strcat "\n실행 후 단계: " (swapp-stage-label after-stage) " [" after-stage "]"))
  (if (and (equal stage after-stage) (not run-result))
    (princ "\n단계가 진행되지 않았습니다. 아래의 마지막 결과와 권장 작업을 확인하세요.")
  )
  (princ "\n")
  (swapp-print-status)
  (swapp-read-cache-end)
  (swapp-command-performance-end "SWCADRUN")
  (princ)
)

(defun swapp-dimstyle-verify (/ ss style-ok fit-ok remaining state semantics)
  (setq ss (swdt-current-space-dim-ss))
  (if (not ss)
    (and
      (equal (swapp-state-value "DIMSTYLE") "NO_DIMENSIONS")
      (equal (swapp-state-value "DIMENSION_SEMANTICS") "NO_DIMENSIONS")
    )
    (progn
      (setq style-ok (swdt-swauto-final-audit))
      (setq fit-ok (swdt-swauto-fit-audit))
      (setq remaining (length (swdt-dimstyle-names-matching "*SLDDIMSTYLE*")))
      (setq state (swapp-state-value "DIMSTYLE"))
      (setq semantics (swapp-state-value "DIMENSION_SEMANTICS"))
      (and
        style-ok fit-ok (= remaining 0)
        (equal state "OK")
        (equal semantics "PRESERVED")
      )
    )
  )
)

(defun c:SWCADVERIFY (/ xrefs wrappers title-result title-status dim-ok cleanup-ok frames layout-ok final-ok old-legacy-compat legacy-compat-enabled)
  (swapp-command-performance-begin)
  (swapp-read-cache-begin)
  (swapp-activate-model)
  (princ "\n===== SWCADVERIFY 통합 최종 검증 =====")
  (setq xrefs (length (swapp-cached-top-xref-references)))
  (setq wrappers (length (swapp-sheet-wrapper-records)))
  (setq dim-ok (swapp-dimstyle-verify))
  (setq cleanup-ok (swapp-resource-cleanup-verify))
  (setq frames (length (swcad-title-frame-records)))
  (setq layout-ok (swapp-layout-state-valid-p frames))
  (setq legacy-compat-enabled
    (and
      (= xrefs 0)
      (= wrappers 0)
      dim-ok
      cleanup-ok
      (> frames 0)
      layout-ok
    )
  )
  (setq old-legacy-compat *swcad-title-legacy-count-compatibility-enabled*)
  (setq *swcad-title-legacy-count-compatibility-enabled* legacy-compat-enabled)
  (setq title-result
    (vl-catch-all-apply 'swcad-title-integrated-verify-final-summary nil)
  )
  (setq *swcad-title-legacy-count-compatibility-enabled* old-legacy-compat)
  (setq title-status
    (if (vl-catch-all-error-p title-result)
      "ERROR"
      title-result
    )
  )
  (setq final-ok (and (= xrefs 0) (= wrappers 0) (equal title-status "OK") dim-ok cleanup-ok (> frames 0) layout-ok))
  (princ (strcat "\n남은 XREF: " (itoa xrefs)))
  (princ (strcat "\n남은 중첩 시트 묶음: " (itoa wrappers)))
  (princ (strcat "\nGMTITLE 최종 상태: " title-status))
  (princ (strcat "\nDIMSTYLE 감사: " (if dim-ok "OK" "CHECK_NEEDED")))
  (princ (strcat "\n전체 미사용 이름 정의 정리 감사: " (if cleanup-ok "OK" "CHECK_NEEDED")))
  (cond
    ((not *swapp-last-resource-cleanup-marked-p*)
      (princ "\n  정리 감사 상세: 현재 버전의 저장 후 정의 정체성 지문이 없습니다. SWCADRUN으로 정리 단계를 한 번 실행하세요.")
    )
    ((not cleanup-ok)
      (princ
        (strcat
          "\n  도면 무결성 지문: "
          (if *swapp-last-resource-cleanup-integrity-ok* "OK" "CHANGED")
        )
      )
      (princ
        (strcat
          "\n  이름 정의 정체성 지문: "
          (if *swapp-last-resource-cleanup-identity-ok* "OK" "CHANGED")
        )
      )
      (if (not *swapp-last-resource-cleanup-integrity-ok*)
        (progn
          (princ (strcat "\n    저장값=" (if *swapp-last-resource-cleanup-stored-integrity* *swapp-last-resource-cleanup-stored-integrity* "<없음>")))
          (princ (strcat "\n    현재값=" (if *swapp-last-resource-cleanup-current-integrity* *swapp-last-resource-cleanup-current-integrity* "<없음>")))
        )
      )
      (if (not *swapp-last-resource-cleanup-identity-ok*)
        (progn
          (princ (strcat "\n    저장값=" (if *swapp-last-resource-cleanup-stored-identity* *swapp-last-resource-cleanup-stored-identity* "<없음>")))
          (princ (strcat "\n    현재값=" (if *swapp-last-resource-cleanup-current-identity* *swapp-last-resource-cleanup-current-identity* "<없음>")))
        )
      )
    )
    ((not *swapp-last-resource-cleanup-full-identity-ok*)
      (princ "\n  참고: GstarCAD Mechanical이 저장/재열기 과정에서 native XData APPID, 세션용 *ACTIVE VPORT 또는 비어 있는 세션 익명 *U 블록을 재등록했습니다. 이 세션성 정의를 제외한 블록/레이어/스타일/사전 정체성과 실제 Layout viewport 무결성은 같습니다.")
    )
    ((not *swapp-last-resource-cleanup-full-record-ok*)
      (princ "\n  참고: 정의의 종류/경로/이름은 같고 내부 handle만 저장 과정에서 재등록되었습니다.")
    )
  )
  (if cleanup-ok
    (princ
      (strcat
        "\n  감사 상태 저장 고정점: "
        (swapp-state-value "RESOURCE_CLEANUP_STATE_SAVE_STABILIZATION_PASSES")
        "회, 재기준화 "
        (swapp-state-value "RESOURCE_CLEANUP_STATE_SAVE_REBASE_COUNT")
        "회"
      )
    )
  )
  (princ (strcat "\nLayout 좌표 모드: " (if (swapp-state-value "LAYOUT_PLACEMENT_MODE") (swapp-state-value "LAYOUT_PLACEMENT_MODE") "<없음>")))
  (princ (strcat "\nLayout 좌표 계획 수: " (if (swapp-state-value "LAYOUT_PLAN_COUNT") (swapp-state-value "LAYOUT_PLAN_COUNT") "<없음>")))
  (princ (strcat "\nLayout 좌표 지문: " (if (swapp-state-value "LAYOUT_PLAN_SIGNATURE") (swapp-state-value "LAYOUT_PLAN_SIGNATURE") "<없음>")))
  (princ (strcat "\nA4 Layout 검증: " (if layout-ok "OK" "CHECK_NEEDED") " (" (itoa frames) "장)"))
  (princ (strcat "\nlegacy 수량 읽기 전용 호환 게이트: " (if legacy-compat-enabled "사용 가능" "사용 안 함")))
  (princ (strcat "\n최종 결과: " (if final-ok "SWCADVERIFY_FINAL_OK" "SWCADVERIFY_FINAL_FAIL")))
  (swapp-read-cache-end)
  (swapp-command-performance-end "SWCADVERIFY")
  (princ)
)

(princ (strcat "\nSWCAD Workflow loaded " *swapp-version*))
(princ "\nCommands: SWCADSTATUS, SWCADRUN, SWCADVERIFY")
(princ)
