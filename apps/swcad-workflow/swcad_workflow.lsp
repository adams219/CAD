;;; SWCAD Workflow MVP orchestrator.
;;; The production modules remain the owners of GMTITLE, DIMSTYLE, and LAYOUT.

(vl-load-com)

(setq *swapp-version* "261008-file-name-1")
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
  (setq base (swapp-file-stem-value raw))
  (if (> (strlen (vl-string-trim " \t\r\n" base)) 0)
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
    (vl-string-search "DR_A0_OUTLINE" upper)
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
              ;; Sheets in the SOLIDWORKS default format have no frame block
              ;; until the SHEET_FORMAT step makes one.
              (or (> source-frames 0) (> (swapp-swfmt-anchor-count) 0))
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

;;; File name without its folder and without a drawing extension.  Other dots are
;;; part of the name: "01-06-11-00_B.P Housing Cover" must not become "01-06-11-00_B"
;;; (vl-filename-base treats everything after the last dot as the extension).
(defun swapp-file-stem-value (value / text base extension)
  (setq text (vl-string-trim " \t\r\n" (if value value "")))
  (setq base (if (> (strlen text) 0) (swapp-safe 'vl-filename-base (list text)) nil))
  (setq extension (if (> (strlen text) 0) (swapp-safe 'vl-filename-extension (list text)) nil))
  (cond
    ((not (and base (> (strlen base) 0))) text)
    ((and extension (member (strcase extension) '(".DWG" ".DXF" ".DWT" ".SLDDRW"))) base)
    (extension (strcat base extension))
    (T base)
  )
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
      (vl-string-search "DR_A0_OUTLINE" (strcase prefix))
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
    ((> (swapp-cached-swfmt-anchor-count) 0) "SHEET_FORMAT")
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
        ((swapp-model-space-empty-p) "COLLECT")
        (T "BLOCKED_NO_SHEETS")
      )
    )
  )
)

;;; ---------------------------
;;; COLLECT: pick DWGs and attach them as XREFs in drawing-number order
;;; ---------------------------
;;; XREF + BIND is how several SOLIDWORKS DWGs are gathered into one drawing.
;;; Every SOLIDWORKS DWG reuses the same block and style names, numbered from 0 in
;;; each file (SW_CENTERMARKSYMBOL_0, SW_TABLEANNOTATION_0, DR_표제란_FTAP,
;;; SLDDIMSTYLE0, ...).  Copy/paste or INSERT keeps only the first file's
;;; definition, so other sheets showed the wrong center marks.  BIND prefixes every
;;; name with its file.  This step only replaces the manual XATTACH and click: the
;;; user picks the files, they are sorted by name like Windows Explorer, and each
;;; drawing-number group (the first number of 01-06-05-00_...) gets its own row.
;;; Rows are aligned on the sheet frame tops, so the Layout order rule (same top =
;;; same row, left to right, rows top to bottom) reads the name order.

(setq *swapp-collect-gap* 50.0)
(setq *swapp-collect-other-row-size* 10)
;;; Tests: a list of DWG paths used instead of the file dialog and the prompts.
(setq *swapp-collect-file-list-override* nil)
;;; Which picker result file LISP could read (".utf8.txt" or ".ansi.txt").
(setq *swapp-collect-picker-encoding* nil)
;;; The messages of the last collection are also written to swcad_collect_last.txt.
(setq *swapp-collect-log-handle* nil)

(defun swapp-model-space-empty-p ()
  (not (ssget "_X" '((410 . "Model"))))
)

(defun swapp-collect-log-path ()
  (swcad-title-work-log-path "swcad_collect_last.txt")
)

(defun swapp-collect-log-close ()
  (if *swapp-collect-log-handle*
    (progn
      (close *swapp-collect-log-handle*)
      (setq *swapp-collect-log-handle* nil)
    )
  )
)

(defun swapp-collect-log-open ()
  (swapp-collect-log-close)
  (setq *swapp-collect-log-handle* (open (swapp-collect-log-path) "w"))
)

;;; Prints a message and writes it to the collect log.
(defun swapp-collect-say (text)
  (princ text)
  (if *swapp-collect-log-handle*
    (write-line (vl-string-left-trim "\n" text) *swapp-collect-log-handle*)
  )
)

(defun swapp-collect-helper-path (/ candidates path found)
  (setq candidates
    (list
      (if (and (boundp '*swapp-root*) *swapp-root*)
        (strcat *swapp-root* "/apps/swcad-workflow/swcad_pick_dwgs.ps1")
        nil
      )
      (strcat (swcad-title-repo-root-path) "apps/swcad-workflow/swcad_pick_dwgs.ps1")
    )
  )
  (setq found nil)
  (foreach path candidates
    (if (and path (not found) (findfile path)) (setq found path))
  )
  found
)

;;; Date and time as 20260930_101530.
(defun swapp-collect-stamp ()
  (vl-string-translate "." "_" (rtos (getvar "CDATE") 2 6))
)

(defun swapp-collect-temp-base (/ dir)
  (setq dir (getenv "TEMP"))
  (if (or (not dir) (= dir "")) (setq dir (getvar "TEMPPREFIX")))
  (strcat (vl-string-right-trim "\\/" dir) "\\swcad_pick_" (swapp-collect-stamp))
)

(defun swapp-read-text-lines (path / handle line result)
  (setq result nil)
  (if (and path (findfile path) (setq handle (open path "r")))
    (progn
      (while (setq line (read-line handle))
        (setq result (cons line result))
      )
      (close handle)
    )
  )
  (reverse result)
)

(defun swapp-join-strings (items separator / result item)
  (setq result "")
  (foreach item items
    (setq result (if (= result "") item (strcat result separator item)))
  )
  result
)

;;; Reads the picker result written by swcad_pick_dwgs.ps1 as (status paths), status
;;; "OK", "CANCEL" or "ERROR ...".  The result exists in UTF-8 and in the ANSI code
;;; page; the first file whose paths all exist is used.
(defun swapp-collect-read-picker-result (base / result suffix lines status paths all-found path)
  (setq result nil)
  (foreach suffix '(".utf8.txt" ".ansi.txt")
    (if (not result)
      (progn
        (setq lines (swapp-read-text-lines (strcat base suffix)))
        (if lines
          (progn
            (setq status (car lines))
            (setq paths
              (vl-remove-if
                '(lambda (item) (= (vl-string-trim " \t\r\n" item) ""))
                (cdr lines)
              )
            )
            (cond
              ((vl-string-search "CANCEL" status) (setq result (list "CANCEL" nil)))
              ((vl-string-search "ERROR" status)
                (setq result (list (vl-string-trim " \t\r\n" status) nil))
              )
              ((vl-string-search "OK" status)
                (setq all-found T)
                (foreach path paths
                  (if (not (findfile path)) (setq all-found nil))
                )
                (if (and paths all-found)
                  (progn
                    (setq result (list "OK" paths))
                    (setq *swapp-collect-picker-encoding* suffix)
                  )
                )
              )
            )
          )
        )
      )
    )
  )
  (foreach suffix '(".utf8.txt" ".ansi.txt")
    (if (findfile (strcat base suffix)) (vl-file-delete (strcat base suffix)))
  )
  (if result result (list "ERROR 고른 파일의 경로를 읽지 못했습니다" nil))
)

;;; Shows the Windows file dialog through swcad_pick_dwgs.ps1 and waits for it.
;;; test-paths (tests only) skips the dialog.  Returns (status paths).
(defun swapp-collect-run-picker (initial-dir test-paths / helper base command shell result)
  (setq helper (swapp-collect-helper-path))
  (if (not helper)
    (list "ERROR 파일 선택 도우미 swcad_pick_dwgs.ps1을 찾지 못했습니다" nil)
    (progn
      (setq base (swapp-collect-temp-base))
      (setq command
        (strcat
          "powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "
          (swcad-title-command-line-quote helper)
          " -OutputPath "
          (swcad-title-command-line-quote base)
          (if (and initial-dir (> (strlen initial-dir) 0))
            (strcat
              " -InitialDirectory "
              (swcad-title-command-line-quote (vl-string-right-trim "\\/" initial-dir))
            )
            ""
          )
          (if test-paths
            (strcat " -TestPaths " (swcad-title-command-line-quote (swapp-join-strings test-paths "|")))
            ""
          )
        )
      )
      (setq shell (vl-catch-all-apply 'vlax-create-object (list "WScript.Shell")))
      (if (vl-catch-all-error-p shell)
        (list (strcat "ERROR " (vl-catch-all-error-message shell)) nil)
        (progn
          (setq result (vl-catch-all-apply 'vlax-invoke-method (list shell 'Run command 0 :vlax-true)))
          (vl-catch-all-apply 'vlax-release-object (list shell))
          (if (vl-catch-all-error-p result)
            (list (strcat "ERROR " (vl-catch-all-error-message result)) nil)
            (swapp-collect-read-picker-result base)
          )
        )
      )
    )
  )
)

(defun swapp-digit-char-p (ch)
  (and ch (= (strlen ch) 1) (wcmatch ch "#"))
)

;;; Runs of digits and of other characters: "PART 10.DWG" -> ("PART " "10" ".DWG").
(defun swapp-natural-runs (text / index ch run digit result)
  (setq result nil)
  (setq run "")
  (setq digit nil)
  (setq index 1)
  (while (<= index (strlen text))
    (setq ch (substr text index 1))
    (if (and (> (strlen run) 0) (not (eq (swapp-digit-char-p ch) digit)))
      (progn
        (setq result (cons run result))
        (setq run "")
      )
    )
    (setq digit (swapp-digit-char-p ch))
    (setq run (strcat run ch))
    (setq index (1+ index))
  )
  (if (> (strlen run) 0) (setq result (cons run result)))
  (reverse result)
)

(defun swapp-strip-leading-zeros (text / index)
  (setq index 1)
  (while (and (< index (strlen text)) (= (substr text index 1) "0"))
    (setq index (1+ index))
  )
  (substr text index)
)

;;; Name order of Windows Explorer: ignores case and compares numbers by value
;;; ("Part 2" before "Part 10").
(defun swapp-natural-less-p (a b / runs-a runs-b x y nx ny result)
  (setq runs-a (swapp-natural-runs (strcase a)))
  (setq runs-b (swapp-natural-runs (strcase b)))
  (setq result nil)
  (while (and runs-a runs-b (not result))
    (setq x (car runs-a))
    (setq y (car runs-b))
    (cond
      ((and (swapp-digit-char-p (substr x 1 1)) (swapp-digit-char-p (substr y 1 1)))
        (setq nx (swapp-strip-leading-zeros x))
        (setq ny (swapp-strip-leading-zeros y))
        (cond
          ((/= (strlen nx) (strlen ny)) (setq result (if (< (strlen nx) (strlen ny)) 'LESS 'MORE)))
          ((/= nx ny) (setq result (if (< nx ny) 'LESS 'MORE)))
        )
      )
      ((/= x y) (setq result (if (< x y) 'LESS 'MORE)))
    )
    (setq runs-a (cdr runs-a))
    (setq runs-b (cdr runs-b))
  )
  (cond
    (result (eq result 'LESS))
    (runs-a nil)
    (runs-b T)
    (T (< a b))
  )
)

;;; First number of a drawing number at the start of a file name:
;;; "01-06-05-00_Bush Inner" -> "01".  The name must start with at least two
;;; number groups joined by "-", followed by "_", a space or the end.  Other
;;; names give nil.
(defun swapp-drawing-number-group (stem / index ch first groups current broken)
  (setq index 1)
  (setq first nil)
  (setq groups 0)
  (setq current "")
  (setq broken nil)
  (while
    (and
      (<= index (strlen stem))
      (progn (setq ch (substr stem index 1)) (or (swapp-digit-char-p ch) (= ch "-")))
    )
    (cond
      ((swapp-digit-char-p ch) (setq current (strcat current ch)))
      ((= current "") (setq broken T))
      (T
        (if (not first) (setq first current))
        (setq groups (1+ groups))
        (setq current "")
      )
    )
    (setq index (1+ index))
  )
  (if (= current "")
    (setq broken T)
    (progn
      (if (not first) (setq first current))
      (setq groups (1+ groups))
    )
  )
  (setq ch (if (<= index (strlen stem)) (substr stem index 1) ""))
  (if (and (not broken) (>= groups 2) (member ch '("_" " " "")))
    first
    nil
  )
)

;;; Drawing number and name of a file name by the same rule:
;;; "01-06-07-00_Bush Inner" -> ("01-06-07-00" "Bush Inner").  Other names give nil.
(defun swapp-drawing-number-split (stem / index)
  (if (swapp-drawing-number-group stem)
    (progn
      (setq index 1)
      (while (and (<= index (strlen stem)) (or (swapp-digit-char-p (substr stem index 1)) (= (substr stem index 1) "-")))
        (setq index (1+ index))
      )
      (list (substr stem 1 (1- index)) (vl-string-trim " " (substr stem (1+ index))))
    )
    nil
  )
)

;;; Rows of (stem path group) items: one row per drawing-number group, then the
;;; other files in rows of *swapp-collect-other-row-size*, all in name order.
;;; The same path picked twice is used once.
(defun swapp-collect-rows (paths / seen unique path records order sorted rows row key last-key others item)
  (setq seen nil)
  (setq unique nil)
  (foreach path paths
    (if (not (member (strcase path) seen))
      (progn
        (setq seen (cons (strcase path) seen))
        (setq unique (append unique (list path)))
      )
    )
  )
  (setq records
    (mapcar
      '(lambda (item / stem) (setq stem (swapp-source-stem-from-path-or-name item "")) (list stem item (swapp-drawing-number-group stem)))
      unique
    )
  )
  (setq order (vl-sort-i records '(lambda (a b) (swapp-natural-less-p (car a) (car b)))))
  (setq sorted (mapcar '(lambda (index) (nth index records)) order))
  (setq rows nil)
  (setq row nil)
  (setq last-key nil)
  (setq others nil)
  (foreach item sorted
    (setq key (caddr item))
    (cond
      ((not key) (setq others (append others (list item))))
      ((and row (equal key last-key)) (setq row (append row (list item))))
      (T
        (if row (setq rows (append rows (list row))))
        (setq row (list item))
        (setq last-key key)
      )
    )
  )
  (if row (setq rows (append rows (list row))))
  (setq row nil)
  (foreach item others
    (setq row (append row (list item)))
    (if (>= (length row) *swapp-collect-other-row-size*)
      (progn
        (setq rows (append rows (list row)))
        (setq row nil)
      )
    )
  )
  (if row (setq rows (append rows (list row))))
  rows
)

;;; XREF name for a file: its name without the extension, with characters a block
;;; name cannot hold replaced.  Different files never share a name: a shared XREF
;;; name would make both inserts show one file, the same-name problem again.
(defun swapp-collect-xref-name (stem used / base name index)
  (setq base (vl-string-translate "<>/\\\":;?*|,=`" "_____________" stem))
  (if (> (strlen base) 200) (setq base (substr base 1 200)))
  (if (= base "") (setq base "SWCAD_XREF"))
  (setq name base)
  (setq index 2)
  (while (or (tblsearch "BLOCK" name) (member (strcase name) used))
    (setq name (strcat base "_" (itoa index)))
    (setq index (1+ index))
  )
  name
)

(defun swapp-bbox4-area (bbox)
  (* (- (caddr bbox) (car bbox)) (- (cadddr bbox) (cadr bbox)))
)

;;; A block directly inside an XREF that can be the sheet frame: its own name names
;;; a paper size or looks like a frame (DR_A3_Outline, DR-A3 FROM_HYUN, ...).
(defun swapp-collect-frame-name-p (name)
  (and
    name
    (or
      (swcad-title-sheet-size-from-block-name name)
      (swcad-title-source-frame-strong-name-p name)
    )
  )
)

;;; Sheet window of an attached XREF as (bbox4 kind): the largest sheet-like frame
;;; block directly inside it ("frame"), else the whole XREF ("no-frame", or
;;; "several-frames" for a multi-sheet file).  Rows are aligned on this window, so
;;; objects outside a frame do not move the frame out of its row.
(defun swapp-collect-sheet-window (reference / whole block origin ins dx dy candidates child bbox best best-area big-count)
  (setq whole (swapp-object-bbox4 reference))
  (setq block (swapp-block-definition (swapp-reference-name reference)))
  (setq origin (if block (swapp-safe 'vlax-get (list block 'Origin)) nil))
  (setq ins (swapp-safe 'vlax-get (list reference 'InsertionPoint)))
  (setq candidates nil)
  (if (and block origin ins)
    (progn
      (setq dx (- (car ins) (car origin)))
      (setq dy (- (cadr ins) (cadr origin)))
      (foreach child (swapp-collection-items block)
        (if
          (and
            (swapp-block-reference-p child)
            (swapp-collect-frame-name-p (swapp-reference-name child))
            (setq bbox (swapp-object-bbox4 child))
          )
          (progn
            (setq bbox (list (+ (car bbox) dx) (+ (cadr bbox) dy) (+ (caddr bbox) dx) (+ (cadddr bbox) dy)))
            (if (gsla-window-sheetlike-p (swapp-bbox4-window bbox))
              (setq candidates (cons bbox candidates))
            )
          )
        )
      )
    )
  )
  (setq best nil)
  (setq best-area 0.0)
  (foreach bbox candidates
    (if (> (swapp-bbox4-area bbox) best-area)
      (progn
        (setq best bbox)
        (setq best-area (swapp-bbox4-area bbox))
      )
    )
  )
  (setq big-count 0)
  (foreach bbox candidates
    (if (>= (swapp-bbox4-area bbox) (* 0.5 best-area)) (setq big-count (1+ big-count)))
  )
  (cond
    ((and best (= big-count 1)) (list best "frame"))
    (whole (list whole (if best "several-frames" "no-frame")))
    (T nil)
  )
)

;;; Room next to a sheet: 50 mm, or a tenth of its larger side.  The SHEET_FORMAT
;;; step gives custom-size and frameless sheets an enlarged DR frame that reaches
;;; past the SOLIDWORKS sheet (07: 46 mm above and below), and 50 mm was too little
;;; between 06 and 07 of the 221216 set.
(defun swapp-collect-item-gap (item / whole)
  (setq whole (nth 4 item))
  (max *swapp-collect-gap* (* 0.1 (max (- (caddr whole) (car whole)) (- (cadddr whole) (cadr whole)))))
)

;;; Moves the XREFs so that per row the sheet tops line up, full extents never
;;; overlap, rows run left to right and top to bottom.  Items are
;;; (stem path group reference whole-bbox sheet-bbox).  Between two sheets or
;;; rows the larger room of both sides.
(defun swapp-collect-place (rows / gap row-gap last-row-gap limit row rise top x last-right last-gap bottom item whole sheet dx dy moved)
  (setq limit nil)
  (setq last-row-gap 0.0)
  (setq moved T)
  (foreach row rows
    (setq rise 0.0)
    (setq row-gap 0.0)
    (foreach item row
      (setq rise (max rise (- (cadddr (nth 4 item)) (cadddr (nth 5 item)))))
      (setq row-gap (max row-gap (swapp-collect-item-gap item)))
    )
    (setq top (if limit (- limit (max last-row-gap row-gap) rise) 0.0))
    (setq x 0.0)
    (setq last-right nil)
    (setq bottom nil)
    (foreach item row
      (setq whole (nth 4 item))
      (setq sheet (nth 5 item))
      (setq gap (swapp-collect-item-gap item))
      (if last-right (setq x (+ last-right (max last-gap gap))))
      (setq dx (- x (car whole)))
      (setq dy (- top (cadddr sheet)))
      (if
        (not
          (swapp-call-ok-p
            'vla-Move
            (list (nth 3 item) (vlax-3d-point '(0.0 0.0 0.0)) (vlax-3d-point (list dx dy 0.0)))
          )
        )
        (setq moved nil)
      )
      (setq last-right (+ (caddr whole) dx))
      (setq last-gap gap)
      (setq bottom (if bottom (min bottom (+ (cadr whole) dy)) (+ (cadr whole) dy)))
    )
    (setq limit bottom)
    (setq last-row-gap row-gap)
  )
  moved
)

(defun swapp-collect-remove (references names / reference name block)
  (foreach reference references
    (swapp-safe 'vla-Delete (list reference))
  )
  (foreach name names
    (setq block (swapp-block-definition name))
    (if block (swapp-safe 'vla-Detach (list block)))
  )
)

;;; Attaches path as XREF name at 0,0 in the model space of host.  Returns the
;;; reference, or the error message as a string.
(defun swapp-collect-attach (host path name / reference)
  (setq reference
    (vl-catch-all-apply
      'vla-AttachExternalReference
      (list
        (vla-get-ModelSpace host)
        path
        name
        (vlax-3d-point '(0.0 0.0 0.0))
        1.0 1.0 1.0 0.0
        :vlax-false
      )
    )
  )
  (if (vl-catch-all-error-p reference) (vl-catch-all-error-message reference) reference)
)

;;; An XREF shows only the model space of its file.
(defun swapp-collect-xref-empty-p (reference / count)
  (setq count
    (swapp-safe 'vla-get-Count (list (swapp-block-definition (swapp-reference-name reference))))
  )
  (or (not (numberp count)) (= count 0))
)

;;; ---- Sheets saved in paper space ----
;;; A SOLIDWORKS export with "용지 공간으로 모든 도면 시트 내보내기" keeps the sheet
;;; in a layout and leaves model space empty, so its XREF shows nothing.  Such a
;;; file is copied under %LOCALAPPDATA%\SWTitle\collect\<time>\<n>\ with the same
;;; file name (the Layout names still come from it); the copy is opened, the
;;; objects of its one filled layout are copied into model space and removed from
;;; the layout, the copy is saved and attached instead.  The picked file is never
;;; opened.  Anything unclear stops the collection.

;;; Tests: folder used instead of %LOCALAPPDATA%\SWTitle\collect.
(setq *swapp-collect-convert-root-override* nil)

(defun swapp-collect-convert-root (/ base)
  (if *swapp-collect-convert-root-override*
    (strcat
      (vl-string-right-trim "\\" (vl-string-translate "/" "\\" *swapp-collect-convert-root-override*))
      "\\"
      (swapp-collect-stamp)
    )
    (progn
      (setq base (getenv "LOCALAPPDATA"))
      (if (or (not base) (= base "")) (setq base (getenv "TEMP")))
      (strcat (vl-string-right-trim "\\/" base) "\\SWTitle\\collect\\" (swapp-collect-stamp))
    )
  )
)

;;; A new, empty folder for the converted copies of one collection, or nil.
(defun swapp-collect-new-convert-folder (/ root folder index)
  (setq root (swapp-collect-convert-root))
  (setq folder root)
  (setq index 2)
  (while (vl-file-directory-p folder)
    (setq folder (strcat root "_" (itoa index)))
    (setq index (1+ index))
  )
  (if (swcad-title-ensure-directory-path folder) folder nil)
)

;;; <folder>\<index>\<file name of source>, so two picked files with the same name
;;; never meet.
(defun swapp-collect-convert-target (folder index source / dir extension)
  (setq dir (strcat folder "\\" (itoa index)))
  (setq extension (vl-filename-extension source))
  (if (swcad-title-ensure-directory-path dir)
    (strcat dir "\\" (vl-filename-base source) (if extension extension ".dwg"))
    nil
  )
)

;;; Why a file with an empty model space cannot be converted, or nil.
;;; filled: ((layout-name object-count) ...) of the layouts holding objects other
;;; than viewports.  negative: dimensions with a negative DIMLFAC, which applies
;;; only in paper space, so their value would change in model space.
(defun swapp-collect-paper-sheet-problem (model-count filled negative)
  (cond
    ((> model-count 0) "모델 공간이 비어 있지 않습니다")
    ((not filled) "모델 공간과 배치 공간이 모두 비어 있습니다")
    ((> (length filled) 1)
      (strcat "내용이 있는 배치 탭이 " (itoa (length filled)) "개라 어느 탭을 쓸지 정할 수 없습니다")
    )
    ((> negative 0)
      (strcat
        "배치 공간에서만 적용되는 음수 치수 배율(DIMLFAC)을 쓴 치수가 "
        (itoa negative)
        "개 있어 모델 공간으로 옮기면 치수 값이 바뀝니다"
      )
    )
    (T nil)
  )
)

;;; The open document of path, or nil.
(defun swapp-collect-find-document (path / key found name doc)
  (setq key (strcase (vl-string-translate "/" "\\" path)))
  (setq found nil)
  (vlax-for doc (vla-get-Documents (vlax-get-acad-object))
    (setq name (swapp-safe 'vla-get-FullName (list doc)))
    (if (and (not found) (= (type name) 'STR) (= (strcase (vl-string-translate "/" "\\" name)) key))
      (setq found doc)
    )
  )
  found
)

;;; Opens the copy target for editing.  Returns the document or the error message.
;;; GstarCAD sometimes (2 of 28 opens) reports "Expecting object to be local"
;;; although it did open the file; opening it again then shows the "already open"
;;; prompt and waits, so the open document is looked up instead.
(defun swapp-collect-open-copy (target / doc)
  (if (swapp-collect-find-document target)
    "같은 파일이 이미 열려 있습니다"
    (progn
      (setq doc (vl-catch-all-apply 'vla-Open (list (vla-get-Documents (vlax-get-acad-object)) target :vlax-false)))
      (cond
        ((not (vl-catch-all-error-p doc)) doc)
        ((swapp-collect-find-document target))
        (T (vl-catch-all-error-message doc))
      )
    )
  )
)

(defun swapp-same-document-p (a b)
  (or
    (equal a b)
    (and
      a b
      (equal (swapp-safe 'vla-get-Name (list a)) (swapp-safe 'vla-get-Name (list b)))
      (equal (swapp-safe 'vla-get-FullName (list a)) (swapp-safe 'vla-get-FullName (list b)))
    )
  )
)

;;; Moves the one filled layout of the opened copy into its model space and saves
;;; it.  Returns (T object-count layout-name) or (nil reason).
(defun swapp-collect-convert-open-copy (doc / model filled negative layout objects obj factor problem arr copy-result copied save-result)
  (setq model (vla-get-ModelSpace doc))
  (setq filled nil)
  (setq negative 0)
  (vlax-for layout (vla-get-Layouts doc)
    (if (/= (strcase (vla-get-Name layout)) "MODEL")
      (progn
        (setq objects nil)
        (vlax-for obj (vla-get-Block layout)
          (if (/= (vla-get-ObjectName obj) "AcDbViewport")
            (progn
              (setq objects (cons obj objects))
              (if (wcmatch (vla-get-ObjectName obj) "AcDb*Dimension")
                (progn
                  (setq factor (swapp-safe 'vla-get-LinearScaleFactor (list obj)))
                  (if (and (numberp factor) (< factor 0.0)) (setq negative (1+ negative)))
                )
              )
            )
          )
        )
        (if objects
          (setq filled (append filled (list (list (vla-get-Name layout) (reverse objects)))))
        )
      )
    )
  )
  (setq problem
    (swapp-collect-paper-sheet-problem
      (vla-get-Count model)
      (mapcar '(lambda (item) (list (car item) (length (cadr item)))) filled)
      negative
    )
  )
  (if problem
    (list nil problem)
    (progn
      (setq objects (cadr (car filled)))
      (setq arr (vlax-make-safearray vlax-vbObject (cons 0 (1- (length objects)))))
      (vlax-safearray-fill arr objects)
      (setq copy-result (vl-catch-all-apply 'vla-CopyObjects (list doc arr model)))
      (setq copied (vla-get-Count model))
      (cond
        ((vl-catch-all-error-p copy-result)
          (list nil (strcat "모델 공간으로 복사하지 못했습니다: " (vl-catch-all-error-message copy-result)))
        )
        ((/= copied (length objects))
          (list nil (strcat "모델 공간으로 " (itoa copied) "/" (itoa (length objects)) "개만 복사됐습니다"))
        )
        (T
          (foreach obj objects (swapp-safe 'vla-Delete (list obj)))
          (setq save-result (vl-catch-all-apply 'vla-Save (list doc)))
          (if (vl-catch-all-error-p save-result)
            (list nil (strcat "변환 사본을 저장하지 못했습니다: " (vl-catch-all-error-message save-result)))
            (list T (length objects) (car (car filled)))
          )
        )
      )
    )
  )
)

;;; Converts one picked file whose model space is empty.  Returns
;;; (T target object-count layout-name) or (nil reason).  Only the copy target is
;;; opened, and host must be the active drawing again afterwards.
(defun swapp-collect-convert-paper-sheet (host source target / sdi doc result backup)
  (setq sdi (getvar "SDI"))
  (cond
    ((and (numberp sdi) (/= sdi 0))
      (list nil "SDI가 0이 아니라 다른 도면을 함께 열 수 없습니다")
    )
    ((not target) (list nil "사본 폴더를 만들지 못했습니다"))
    ((findfile target) (list nil (strcat "사본 파일이 이미 있습니다: " target)))
    ((not (vl-file-copy source target)) (list nil (strcat "사본을 만들지 못했습니다: " target)))
    (T
      (setq doc (swapp-collect-open-copy target))
      (cond
        ((= (type doc) 'STR)
          (list nil (strcat "사본을 열지 못했습니다: " doc))
        )
        ((swapp-same-document-p doc host)
          (list nil "사본 대신 현재 도면이 열렸습니다")
        )
        (T
          (setq result (vl-catch-all-apply 'swapp-collect-convert-open-copy (list doc)))
          (if (vl-catch-all-error-p result)
            (setq result (list nil (strcat "변환 중 오류: " (vl-catch-all-error-message result))))
          )
          ;; GstarCAD finishes a Close only when a drawing is activated or opened
          ;; afterwards, so the host drawing is activated even when it is active.
          (vl-catch-all-apply 'vla-Close (list doc :vlax-false))
          (swapp-safe 'vla-Activate (list host))
          ;; The backup the save made of this copy.
          (setq backup (strcat (vl-filename-directory target) "\\" (vl-filename-base target) ".bak"))
          (if (findfile backup) (vl-file-delete backup))
          (cond
            ((not (swapp-same-document-p (swapp-doc) host))
              (list nil "변환 뒤 원래 도면으로 돌아오지 못했습니다")
            )
            ((car result) (cons T (cons target (cdr result))))
            (T result)
          )
        )
      )
    )
  )
)

(defun swapp-collect-print-rows (rows / row-index index row item)
  (setq row-index 1)
  (setq index 1)
  (foreach row rows
    (swapp-collect-say
      (strcat
        "\n  " (itoa row-index) "줄"
        (if (caddr (car row)) (strcat " [" (caddr (car row)) "]") " [번호 규칙 밖]")
        ", " (itoa (length row)) "장"
      )
    )
    (foreach item row
      (swapp-collect-say (strcat "\n    " (itoa index) ". " (car item)))
      (setq index (1+ index))
    )
    (setq row-index (1+ row-index))
  )
)

;;; SWCADRUN step 0.  Returns T when the drawings were attached and placed.  The
;;; messages also go to swcad_collect_last.txt.
(defun swapp-collect-xrefs (/ result)
  (swapp-collect-log-open)
  (setq result (swapp-collect-xrefs-run))
  (if *swapp-collect-log-handle*
    (princ (strcat "\n모으기 기록 파일: " (swapp-collect-log-path)))
  )
  (swapp-collect-log-close)
  result
)

;;; Attaches every file; a file whose model space is empty (the sheet was saved in
;;; paper space) is replaced by a converted copy.  If anything fails, every XREF
;;; of this run is removed again.
(defun swapp-collect-xrefs-run (/ paths more dir picked status answer rows count host used attached names refs empty problem folder index pair converted targets still-open placed-rows ok row placed-row item name reference whole window unreadable frame-count kinds)
  (swapp-collect-say "\n----- SWCAD 0/6 도면 모으기 -----")
  (swapp-collect-say "\nSOLIDWORKS DWG를 XREF로 붙입니다. 파일 이름 순서로 놓고, 도면번호 첫 번호마다 새 줄로 시작합니다.")
  (swapp-collect-say "\n복사·붙여넣기 대신 XREF를 쓰면 파일마다 같은 이름의 블록(중심 표시, 표, 표제란)이 섞이지 않습니다.")
  (swapp-collect-say (strcat "\n호스트 도면: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (setq paths nil)
  (cond
    (*swapp-collect-file-list-override*
      (setq paths *swapp-collect-file-list-override*)
    )
    ((swcad-title-script-active-p)
      (swapp-collect-say "\n결과: BLOCKED_COLLECT_SCRIPT_ACTIVE")
      (swapp-collect-say "\nSCRIPT 실행 중에는 파일 선택 창을 열지 않습니다. 명령창에 SWCADRUN을 직접 입력하세요.")
      (setq paths 'STOP)
    )
    (T
      (setq more T)
      (setq dir (getvar "DWGPREFIX"))
      (while more
        (swapp-collect-say "\n파일 선택 창에서 모을 DWG를 고르세요(여러 개: Ctrl, Shift, Ctrl+A).")
        (setq picked (swapp-collect-run-picker dir nil))
        (setq status (car picked))
        (cond
          ((= status "OK")
            (setq paths (append paths (cadr picked)))
            (setq dir (vl-filename-directory (last (cadr picked))))
            (swapp-collect-say (strcat "\n고른 도면: " (itoa (length (cadr picked))) "개, 지금까지 " (itoa (length paths)) "개"))
            (setq answer (getstring T "\n다른 폴더의 도면도 추가하려면 A, 다 골랐으면 Enter를 누르세요: "))
            (if (/= (strcase (vl-string-trim " " answer)) "A") (setq more nil))
          )
          ((= status "CANCEL") (setq more nil))
          (T
            (swapp-collect-say (strcat "\n파일 선택 창 오류: " status))
            (setq more nil)
            (setq paths 'STOP)
          )
        )
      )
    )
  )
  (cond
    ((eq paths 'STOP) nil)
    ((not paths)
      (swapp-collect-say "\n결과: ABORT_COLLECT_NO_FILES")
      (swapp-collect-say "\n고른 도면이 없어 아무것도 바꾸지 않았습니다.")
      nil
    )
    (T
      (setq rows (swapp-collect-rows paths))
      (setq count (apply '+ (mapcar 'length rows)))
      (swapp-collect-say (strcat "\n모을 도면: " (itoa count) "개, " (itoa (length rows)) "줄 (파일 이름 순서)"))
      (swapp-collect-print-rows rows)
      (setq answer
        (if *swapp-collect-file-list-override*
          "YES"
          (getstring T "\n위 순서로 XREF를 붙이려면 YES를 입력하세요: ")
        )
      )
      (if (/= (strcase (vl-string-trim " " answer)) "YES")
        (progn
          (swapp-collect-say "\n결과: ABORT_COLLECT_USER")
          (swapp-collect-say "\n도면을 바꾸지 않았습니다.")
          nil
        )
        (progn
          (setq host (swapp-doc))
          (setq used nil)
          (setq attached nil)
          (setq names nil)
          (setq refs nil)
          (setq empty nil)
          (setq problem nil)
          (setq targets nil)
          (setq unreadable nil)
          (setq ok T)
          ;; 1. Every file as an XREF at 0,0.  A file with an empty model space is
          ;;    detached again and converted in step 2.
          (foreach row rows
            (foreach item row
              (if ok
                (progn
                  (setq name (swapp-collect-xref-name (car item) used))
                  (setq used (cons (strcase name) used))
                  (setq reference (swapp-collect-attach host (cadr item) name))
                  (cond
                    ((= (type reference) 'STR)
                      (swapp-collect-say (strcat "\nXREF를 붙이지 못한 도면: " (cadr item)))
                      (swapp-collect-say (strcat "\n  이유: " reference))
                      (setq ok nil)
                    )
                    ((swapp-collect-xref-empty-p reference)
                      (swapp-collect-remove (list reference) (list name))
                      (setq empty (append empty (list (list item name))))
                    )
                    (T
                      (setq attached (cons reference attached))
                      (setq names (cons name names))
                      (setq refs (cons (cons (cadr item) reference) refs))
                    )
                  )
                )
              )
            )
          )
          ;; 2. Sheets saved in paper space: attach a model-space copy instead.
          (if (and ok empty)
            (progn
              (swapp-collect-say
                (strcat
                  "\n모델 공간이 비어 있는 도면 " (itoa (length empty))
                  "개: 도면이 배치(용지) 공간에만 있습니다. 모델 공간으로 옮긴 사본을 만들어 붙입니다. 고른 원본 파일은 열지 않습니다."
                )
              )
              (setq folder (swapp-collect-new-convert-folder))
              (if (not folder)
                (setq problem (list "" (strcat "사본 폴더를 만들지 못했습니다: " (swapp-collect-convert-root))))
              )
              (setq index 1)
              (foreach pair empty
                (if (not problem)
                  (progn
                    (setq item (car pair))
                    (setq name (cadr pair))
                    (swapp-collect-say (strcat "\n  " (itoa index) "/" (itoa (length empty)) " " (car item)))
                    (setq converted
                      (swapp-collect-convert-paper-sheet
                        host
                        (cadr item)
                        (swapp-collect-convert-target folder index (cadr item))
                      )
                    )
                    (if (not (car converted))
                      (setq problem (list (cadr item) (cadr converted)))
                      (progn
                        (setq targets (append targets (list (cadr converted))))
                        (if (tblsearch "BLOCK" name) (setq name (swapp-collect-xref-name (car item) used)))
                        (setq used (cons (strcase name) used))
                        (setq reference (swapp-collect-attach host (cadr converted) name))
                        (cond
                          ((= (type reference) 'STR)
                            (setq problem (list (cadr item) (strcat "변환 사본을 XREF로 붙이지 못했습니다: " reference)))
                          )
                          (T
                            (setq attached (cons reference attached))
                            (setq names (cons name names))
                            (if (swapp-collect-xref-empty-p reference)
                              (setq problem (list (cadr item) "변환 사본도 모델 공간이 비어 있습니다"))
                              (progn
                                (setq refs (cons (cons (cadr item) reference) refs))
                                (swapp-collect-say
                                  (strcat
                                    " - '" (cadddr converted) "' 탭의 객체 "
                                    (itoa (caddr converted)) "개를 모델 공간으로 옮김"
                                  )
                                )
                              )
                            )
                          )
                        )
                      )
                    )
                    (setq index (1+ index))
                  )
                )
              )
              (if (not problem)
                (progn
                  (swapp-collect-say (strcat "\n변환 사본 폴더: " folder))
                  (setq still-open (vl-remove-if-not 'swapp-collect-find-document targets))
                  (if still-open
                    (progn
                      (swapp-collect-say "\n아직 열려 있는 변환 사본입니다. 저장하지 말고 닫으세요:")
                      (foreach item still-open (swapp-collect-say (strcat "\n  " item)))
                    )
                  )
                )
              )
            )
          )
          ;; 3. Extents and sheet window of every XREF, row by row.
          (setq placed-rows nil)
          (if (and ok (not problem))
            (foreach row rows
              (setq placed-row nil)
              (foreach item row
                (setq reference (cdr (assoc (cadr item) refs)))
                (setq whole (swapp-object-bbox4 reference))
                (if (not whole)
                  (setq unreadable (append unreadable (list (cadr item))))
                  (progn
                    (setq window (swapp-collect-sheet-window reference))
                    (setq placed-row
                      (append
                        placed-row
                        (list
                          (list
                            (car item) (cadr item) (caddr item) reference whole
                            (if window (car window) whole)
                            (if window (cadr window) "no-frame")
                          )
                        )
                      )
                    )
                  )
                )
              )
              (setq placed-rows (append placed-rows (list placed-row)))
            )
          )
          (cond
            ((not ok)
              (swapp-collect-remove attached names)
              (swapp-collect-say "\n결과: ERROR_COLLECT_ATTACH")
              (swapp-collect-say "\n이번에 붙인 XREF를 모두 떼어 냈습니다. 도면을 바꾸지 않았습니다.")
              nil
            )
            (problem
              (swapp-collect-remove attached names)
              (swapp-collect-say "\n결과: STOP_COLLECT_PAPER_SHEET")
              (swapp-collect-say "\n배치(용지) 공간에만 도면이 있는 파일을 모델 공간 사본으로 바꾸지 못했습니다.")
              (if (/= (car problem) "") (swapp-collect-say (strcat "\n  파일: " (car problem))))
              (swapp-collect-say (strcat "\n  이유: " (cadr problem)))
              (swapp-collect-say "\n이 파일은 SOLIDWORKS에서 '용지 공간으로 모든 도면 시트 내보내기'를 끄고 다시 DWG로 저장한 뒤 SWCADRUN을 다시 실행하세요.")
              (swapp-collect-say "\n이번에 붙인 XREF를 모두 떼어 냈습니다. 도면을 바꾸지 않았습니다.")
              nil
            )
            (unreadable
              (swapp-collect-remove attached names)
              (swapp-collect-say "\n결과: ERROR_COLLECT_EXTENTS")
              (swapp-collect-say "\n범위를 읽지 못한 도면:")
              (foreach item unreadable (swapp-collect-say (strcat "\n  " item)))
              (swapp-collect-say "\n이번에 붙인 XREF를 모두 떼어 냈습니다. 도면을 바꾸지 않았습니다.")
              nil
            )
            ((not (swapp-collect-place placed-rows))
              (swapp-collect-remove attached names)
              (swapp-collect-say "\n결과: ERROR_COLLECT_MOVE")
              (swapp-collect-say "\nXREF를 제자리로 옮기지 못했습니다. 이번에 붙인 XREF를 모두 떼어 냈습니다. 도면을 바꾸지 않았습니다.")
              nil
            )
            (T
              (swapp-safe 'vla-ZoomExtents (list (vlax-get-acad-object)))
              (setq frame-count 0)
              (setq kinds nil)
              (foreach row placed-rows
                (foreach item row
                  (if (equal (nth 6 item) "frame")
                    (setq frame-count (1+ frame-count))
                    (setq kinds (append kinds (list (strcat (car item) " (" (nth 6 item) ")"))))
                  )
                )
              )
              (swapp-collect-say "\n결과: OK_COLLECT_XREFS_PLACED")
              (swapp-collect-say (strcat "\n붙인 XREF: " (itoa (length attached)) "개, " (itoa (length placed-rows)) "줄"))
              (if empty
                (swapp-collect-say
                  (strcat "\n그중 배치 공간 도면을 모델 공간 사본으로 바꿔 붙인 도면: " (itoa (length empty)) "개")
                )
              )
              (cond
                ((= frame-count 0)
                  (swapp-collect-say "\n도면틀 블록이 없어 모든 도면을 도면 전체 범위의 윗선으로 맞췄습니다.")
                )
                (T
                  (swapp-collect-say (strcat "\n도면틀 윗선으로 줄을 맞춘 도면: " (itoa frame-count) "개"))
                  (if kinds
                    (progn
                      (swapp-collect-say "\n도면틀을 찾지 못해 도면 전체 범위로 맞춘 도면:")
                      (foreach item kinds (swapp-collect-say (strcat "\n  " item)))
                    )
                  )
                )
              )
              (swapp-collect-say "\n다음: 배치를 눈으로 확인한 뒤 SWCADRUN을 다시 실행하세요. 다음 단계에서 XREF를 확인하고 결합합니다.")
              (swapp-collect-say "\n배치를 다시 하려면 이 도면을 저장하지 말고 닫은 뒤 새 도면에서 다시 시작하세요.")
              T
            )
          )
        )
      )
    )
  )
)

;;; ---------------------------
;;; SHEET_FORMAT: SOLIDWORKS default sheet format drawn with lines and text
;;; ---------------------------
;;; The SOLIDWORKS default Korean sheet format is exported as plain LINE and MTEXT:
;;; two border rectangles 5 mm apart with zone letters between them, and a
;;; 180 x 55.25 mm title block at the inner border's bottom-right corner with fixed
;;; labels (작성 검사 승인 ... 도면 번호 ... 배율: ... 시트 1 OF 1).  The TITLE step
;;; finds sheets by frame and title blocks only, so these drawings stopped at
;;; BLOCKED_NO_SHEETS.  This step finds each such sheet by its fixed labels, reads
;;; the filled cells, and gathers exactly those lines, texts and notes into two
;;; blocks: SWFMT_<size>_OUTLINE_nn (the format plus the paper outline, so its
;;; extents are the paper) and SWFMT_TITLE_nn (the title box, with the values as
;;; GEN-TITLE-* attributes).  The TITLE step then converts them like a bound title
;;; and frame and deletes both.  Nothing changes unless every sheet is recognized.
;;; A sheet with no frame at all gets the same pair around its drawing: only the
;;; paper outline and an empty title box, with the paper size and scale as values.

(setq *swapp-swfmt-block-prefix* "SWFMT_")
(setq *swapp-swfmt-anchor-text* "도면의 배율을 변경하지 마시오.")
(setq *swapp-swfmt-tolerance* 1.0)
(setq *swapp-swfmt-title-width* 180.0)
(setq *swapp-swfmt-title-height* 55.25)
(setq *swapp-swfmt-border-gap* 5.0)
;;; Paper of the new DR frame around the SOLIDWORKS outer border: 15 mm left, 5 mm
;;; right, below and above.  The DR frames (A1..A4 measured) have their inner border
;;; 20 mm from the left paper edge and 10 mm from the others, the SOLIDWORKS format
;;; 15 mm left and right and 10 mm below and above, so this puts the DR inner border
;;; exactly on the SOLIDWORKS one and the new title's corner on the old title's.
(setq *swapp-swfmt-paper-margin-left* 15.0)
(setq *swapp-swfmt-paper-margin-right* 5.0)
(setq *swapp-swfmt-paper-margin-y* 5.0)
;;; Paper of each DR frame as (size width height): A4 portrait, the others landscape.
(setq *swapp-swfmt-papers*
  '(("A0" 1189.0 841.0) ("A1" 841.0 594.0) ("A2" 594.0 420.0) ("A3" 420.0 297.0) ("A4" 210.0 297.0))
)
;;; Fixed labels as (text match dx dy value-follows): the MTEXT insertion point
;;; relative to the inner border's bottom-right corner.  PREFIX labels may carry
;;; the value after the label ("배율:1:10"); value-follows says whether it counts.
(setq *swapp-swfmt-labels*
  '(("작성" "EXACT" -179.79 32.41 nil)
    ("검사" "EXACT" -179.59 28.14 nil)
    ("승인" "EXACT" -179.60 24.05 nil)
    ("제조" "EXACT" -179.54 19.72 nil)
    ("Q.A" "EXACT" -179.33 15.33 nil)
    ("이름" "EXACT" -165.68 36.48 nil)
    ("서명" "EXACT" -149.97 36.54 nil)
    ("날짜" "EXACT" -132.79 36.56 nil)
    ("재질:" "PREFIX" -124.35 15.97 T)
    ("무게:" "PREFIX" -124.38 2.93 T)
    ("표면 거칠기:" "PREFIX" -145.63 53.90 T)
    ("제목:" "PREFIX" -80.04 36.56 T)
    ("도면 번호" "EXACT" -79.93 15.97 nil)
    ("배율:" "PREFIX" -79.93 2.88 T)
    ("시트 " "PREFIX" -35.52 2.88 nil)
    ("수정본" "PREFIX" -26.67 52.32 T)
    ("도면의 배율을 변경하지 마시오." "EXACT" -67.39 52.52 nil)
  )
)
;;; Cells relative to the same corner as (name x1 y1 x2 y2 tag), first match wins.
;;; Values go to the GMTITLE field named by tag; a nil tag keeps the text in the log
;;; only (the new title has no such field); "-" drops it (the size cell always says
;;; A3, whatever the paper).
(setq *swapp-swfmt-cells*
  '(("도면 번호" -81.2 4.25 -13.0 17.0 "GEN-TITLE-NR{23}")
    ("제목" -81.2 17.0 0.0 38.25 "GEN-TITLE-DWG{23}")
    ("배율" -81.2 0.0 -37.0 4.25 "GEN-TITLE-SCA{6.7}")
    ("재질" -125.4 4.25 -81.2 17.0 "GEN-TITLE-MAT1{10}")
    ("수정본" -29.2 48.88 0.0 55.25 "GEN-TITLE-REV{5}")
    ("작성 이름" -172.2 29.75 -153.01 34.0 "GEN-TITLE-NAME{10}")
    ("작성 날짜" -135.6 29.75 -125.4 34.0 "GEN-TITLE-DATE{11.7}")
    ("검사 이름" -172.2 25.5 -153.01 29.75 "GEN-TITLE-CHKM{10}")
    ("승인 이름" -172.2 21.25 -153.01 25.5 "GEN-TITLE-APPM{21.7}")
    ("무게" -125.4 0.0 -81.2 4.25 nil)
    ("시트" -37.0 0.0 0.0 4.25 nil)
    ("용지 크기" -13.0 4.25 0.0 17.0 "-")
    ("도면 배율 안내" -81.2 48.88 -29.2 55.25 nil)
    ("제목 위 칸" -81.2 38.25 0.0 48.88 nil)
    ("표면 거칠기" -146.2 38.25 -99.4 55.25 nil)
    ("일반 공차 주석" -180.0 38.25 -146.2 55.25 nil)
    ("디버링 주석" -99.4 38.25 -81.2 55.25 nil)
    ("이름·서명·날짜 표" -180.0 0.0 -81.2 38.25 nil)
  )
)
;;; Tests: DR frame files are looked up here instead of the GstarCAD Format folder.
(setq *swapp-swfmt-frame-file-override* nil)
(setq *swapp-swfmt-log-handle* nil)

(defun swapp-swfmt-log-path ()
  (swcad-title-work-log-path "swcad_sheet_format_last.txt")
)

(defun swapp-swfmt-log-close ()
  (if *swapp-swfmt-log-handle*
    (progn
      (close *swapp-swfmt-log-handle*)
      (setq *swapp-swfmt-log-handle* nil)
    )
  )
)

(defun swapp-swfmt-say (text)
  (princ text)
  (if *swapp-swfmt-log-handle*
    (write-line (vl-string-left-trim "\n" text) *swapp-swfmt-log-handle*)
  )
)

;;; Writes to the log only (details that would flood the command line).
(defun swapp-swfmt-log (text)
  (if *swapp-swfmt-log-handle*
    (write-line text *swapp-swfmt-log-handle*)
  )
)

(defun swapp-swfmt-anchor-count (/ ss)
  (setq ss (ssget "_X" (list '(0 . "TEXT,MTEXT") '(410 . "Model") (cons 1 (strcat "*" *swapp-swfmt-anchor-text* "*")))))
  (if ss (sslength ss) 0)
)

(defun swapp-cached-swfmt-anchor-count ()
  (swapp-read-cache-fetch "SWFMT_ANCHORS" 'swapp-swfmt-anchor-count nil)
)

(defun swapp-swfmt-frame-file (frame-block)
  (if *swapp-swfmt-frame-file-override*
    (strcat *swapp-swfmt-frame-file-override* "/" frame-block ".dwg")
    (swcad-title-frame-dwg-path frame-block)
  )
)

;;; No local may be named type: AutoLISP scope is dynamic, and the module's
;;; helpers call the type function.
(defun swapp-swfmt-plain (etype raw)
  (vl-string-trim " \t\r\n" (if (= etype "MTEXT") (swcad-title-mtext-plain raw) raw))
)

(defun swapp-swfmt-mtext-raw (data / pair raw)
  (setq raw "")
  (foreach pair data
    (if (= (car pair) 3) (setq raw (strcat raw (cdr pair))))
  )
  (strcat raw (cdr (assoc 1 data)))
)

(defun swapp-swfmt-bbox4-from-points (p1 p2)
  (list (min (car p1) (car p2)) (min (cadr p1) (cadr p2)) (max (car p1) (car p2)) (max (cadr p1) (cadr p2)))
)

(defun swapp-swfmt-inside-p (bbox outer margin)
  (and
    bbox
    (>= (car bbox) (- (car outer) margin))
    (>= (cadr bbox) (- (cadr outer) margin))
    (<= (caddr bbox) (+ (caddr outer) margin))
    (<= (cadddr bbox) (+ (cadddr outer) margin))
  )
)

(defun swapp-swfmt-point-inside-p (point outer margin)
  (swapp-swfmt-inside-p (list (car point) (cadr point) (car point) (cadr point)) outer margin)
)

;;; One pass over the model space.  Items: (ename type layer p1 p2 text bbox4);
;;; lines carry both end points, texts the insertion point and plain text.
(defun swapp-swfmt-scan (/ ss index ename data etype p1 p2 raw object bbox result)
  (setq result nil)
  (setq ss (ssget "_X" '((0 . "LINE,TEXT,MTEXT,INSERT,LWPOLYLINE,HATCH,SOLID") (410 . "Model"))))
  (setq index 0)
  (while (and ss (< index (sslength ss)))
    (setq ename (ssname ss index))
    (setq data (entget ename))
    (setq etype (cdr (assoc 0 data)))
    (cond
      ((= etype "LINE")
        (setq p1 (cdr (assoc 10 data)))
        (setq p2 (cdr (assoc 11 data)))
        (setq result (cons (list ename etype (cdr (assoc 8 data)) p1 p2 nil (swapp-swfmt-bbox4-from-points p1 p2)) result))
      )
      (T
        (setq object (swapp-safe 'vlax-ename->vla-object (list ename)))
        (setq bbox (swapp-object-bbox4 object))
        (setq raw
          (cond
            ((= etype "MTEXT") (swapp-swfmt-mtext-raw data))
            ((= etype "TEXT") (cdr (assoc 1 data)))
            (T nil)
          )
        )
        (if bbox
          (setq result
            (cons
              (list ename etype (cdr (assoc 8 data)) (cdr (assoc 10 data)) nil (if raw (swapp-swfmt-plain etype raw) nil) bbox)
              result
            )
          )
        )
      )
    )
    (setq index (1+ index))
  )
  result
)

(defun swapp-swfmt-text-item-p (item)
  (member (cadr item) '("TEXT" "MTEXT"))
)

;;; A non-line item of the title box: a text starting in it at a height inside it
;;; (zone numbers of the border band start 0.6 mm below it), a note block centred in
;;; it, or other graphics wholly inside it.
(defun swapp-swfmt-title-item-p (item title-box / center)
  (setq center (swapp-bbox4-center (nth 6 item)))
  (cond
    ((= (cadr item) "LINE") nil)
    ((swapp-swfmt-text-item-p item)
      (and
        (swapp-swfmt-point-inside-p (nth 3 item) title-box 0.5)
        (>= (cadr center) (cadr title-box))
        (<= (cadr center) (cadddr title-box))
      )
    )
    ((= (cadr item) "INSERT") (swapp-swfmt-point-inside-p (swapp-bbox4-center (nth 6 item)) title-box 0.0))
    (T (swapp-swfmt-inside-p (nth 6 item) title-box 0.5))
  )
)

;;; Where a title item sits for its cell: a text by its insertion point (the long
;;; 도면 번호 value would otherwise be centred past the cell), else the centre.
(defun swapp-swfmt-item-cell-point (item)
  (if (swapp-swfmt-text-item-p item)
    (nth 3 item)
    (swapp-bbox4-center (nth 6 item))
  )
)

;;; The fixed label the text item is, as its label entry, or nil.
(defun swapp-swfmt-label-of (item corner / found label text point)
  (setq found nil)
  (setq text (nth 5 item))
  (setq point (nth 3 item))
  (if (and text point)
    (foreach label *swapp-swfmt-labels*
      (if
        (and
          (not found)
          (swapp-near (car point) (+ (car corner) (nth 2 label)) *swapp-swfmt-tolerance*)
          (swapp-near (cadr point) (+ (cadr corner) (nth 3 label)) *swapp-swfmt-tolerance*)
          (if (equal (nth 1 label) "EXACT")
            (equal text (car label))
            (swapp-string-starts-ci-p text (car label))
          )
        )
        (setq found label)
      )
    )
  )
  found
)

;;; A LINE item from p1 to p2 (either direction), or nil.
(defun swapp-swfmt-find-line (lines p1 p2 / found item tol)
  (setq found nil)
  (setq tol 0.5)
  (foreach item lines
    (if
      (and
        (not found)
        (or
          (and (< (distance (nth 3 item) p1) tol) (< (distance (nth 4 item) p2) tol))
          (and (< (distance (nth 3 item) p2) tol) (< (distance (nth 4 item) p1) tol))
        )
      )
      (setq found item)
    )
  )
  found
)

;;; The four LINE items of the rectangle bbox, or nil when one is missing.
(defun swapp-swfmt-rectangle-lines (lines bbox / x1 y1 x2 y2 result)
  (setq x1 (car bbox) y1 (cadr bbox) x2 (caddr bbox) y2 (cadddr bbox))
  (setq result
    (list
      (swapp-swfmt-find-line lines (list x1 y1 0.0) (list x2 y1 0.0))
      (swapp-swfmt-find-line lines (list x2 y1 0.0) (list x2 y2 0.0))
      (swapp-swfmt-find-line lines (list x2 y2 0.0) (list x1 y2 0.0))
      (swapp-swfmt-find-line lines (list x1 y2 0.0) (list x1 y1 0.0))
    )
  )
  (if (member nil result) nil result)
)

;;; The inner border as bbox4: its bottom line ends at corner, its right line
;;; starts there.  Picks the longest candidates.
;;; The inner border as bbox4: its bottom line runs under the whole title block (on
;;; a standard sheet it ends at the title block's corner; on a custom-size sheet the
;;; title block sits somewhere along it), and its right line rises from that line's
;;; right end.  Picks the longest candidates.
(defun swapp-swfmt-inner-border (lines corner / tol left right top item p1 p2 x1 x2 other)
  (setq tol 0.5)
  (setq left nil right nil top nil)
  (foreach item lines
    (setq p1 (nth 3 item) p2 (nth 4 item))
    (if
      (and
        (swapp-near (cadr p1) (cadr corner) tol)
        (swapp-near (cadr p2) (cadr corner) tol)
        (<= (setq x1 (min (car p1) (car p2))) (+ (- (car corner) *swapp-swfmt-title-width*) tol))
        (>= (setq x2 (max (car p1) (car p2))) (- (car corner) tol))
        (or (not left) (> (- x2 x1) (- right left)))
      )
      (setq left x1 right x2)
    )
  )
  (if right
    (foreach item lines
      (setq p1 (nth 3 item) p2 (nth 4 item))
      (setq other
        (cond
          ((< (distance (list (car p1) (cadr p1)) (list right (cadr corner))) tol) p2)
          ((< (distance (list (car p2) (cadr p2)) (list right (cadr corner))) tol) p1)
          (T nil)
        )
      )
      (if
        (and
          other
          (swapp-near (car other) right tol)
          (> (cadr other) (+ (cadr corner) *swapp-swfmt-title-height*))
          (or (not top) (> (cadr other) top))
        )
        (setq top (cadr other))
      )
    )
  )
  (if (and left top) (list left (cadr corner) right top) nil)
)

;;; Extents of every model object in region except the format's own (enames): the
;;; drawing of a custom-size sheet.  Circles, arcs, splines and dimensions count too.
(defun swapp-swfmt-content-boxes (region enames / ss index ename point bbox result)
  (setq result nil)
  (setq ss (ssget "_X" '((410 . "Model"))))
  (setq index 0)
  (while (and ss (< index (sslength ss)))
    (setq ename (ssname ss index))
    (if (not (member ename enames))
      (progn
        (setq point (cdr (assoc 10 (entget ename))))
        (if (or (not point) (swapp-swfmt-point-inside-p point region 50.0))
          (progn
            (setq bbox (swapp-object-bbox4 (vlax-ename->vla-object ename)))
            (if (and bbox (swapp-swfmt-inside-p bbox region 1.0)) (setq result (cons bbox result)))
          )
        )
      )
    )
    (setq index (1+ index))
  )
  result
)

;;; Tests only: leave out DR frames whose file is not installed (e.g. DR_A0_Outline),
;;; so the enlarged-frame path can run with the frames that exist.
(setq *swapp-swfmt-test-skip-missing-frames* nil)

;;; GMTITLE scale list values used for enlarged frames (1:1, 1:2, 1:2.5, 1:4, ...).
(setq *swapp-swfmt-scales* '(1.0 2.0 2.5 4.0 5.0 10.0 15.0 20.0 25.0 40.0 50.0 75.0 100.0))

;;; "4", "2P5" for block names.
(defun swapp-swfmt-scale-token (scale)
  (if (equal scale (fix scale) 0.0001)
    (itoa (fix scale))
    (vl-string-translate "." "P" (rtos scale 2 1))
  )
)

;;; Whether a scaled DR paper with lower-left (llx lly) holds the drawing: the
;;; content inside the scaled inner border (20k from the left paper edge, 10k from
;;; the others) and clear of the scaled title block (190k..6.4k from the right edge,
;;; 10k..52k from the bottom).
(defun swapp-swfmt-paper-holds-p (llx lly pw ph scale content-bbox content-boxes / inner title clear box)
  (setq inner (list (+ llx (* 20.0 scale)) (+ lly (* 10.0 scale)) (+ llx (- pw (* 10.0 scale))) (+ lly (- ph (* 10.0 scale)))))
  (setq title (list (+ llx (- pw (* 190.0 scale))) (+ lly (* 10.0 scale)) (+ llx (- pw (* 6.4 scale))) (+ lly (* 52.0 scale))))
  (setq clear T)
  (foreach box content-boxes
    (if (swcad-title-bbox-overlap-box box title) (setq clear nil))
  )
  (and clear (swapp-swfmt-inside-p content-bbox inner 0.0))
)

;;; For a custom-size sheet: the DR frame and GMTITLE scale that hold it, as
;;; (size scale paper-options), or nil.  The smallest scale first, then the smallest
;;; paper, whose scaled paper covers the SOLIDWORKS paper (outer border + 5 mm).
;;; paper-options are the places for it in order of preference: the drawing centred
;;; in the inner border (the SOLIDWORKS outer border kept on the paper), then the
;;; scaled paper on each corner of the SOLIDWORKS paper; only places that hold the
;;; drawing.  The run picks the first that does not overlap another sheet, because
;;; an enlarged paper can reach into the 50 mm between collected sheets.
(defun swapp-swfmt-scaled-choice (outer content-bbox content-boxes / sw sw-w sw-h found scale paper sizes pw ph cx cy llx lly options place)
  (setq sw (list (- (car outer) 5.0) (- (cadr outer) 5.0) (+ (caddr outer) 5.0) (+ (cadddr outer) 5.0)))
  (setq sw-w (- (caddr sw) (car sw)))
  (setq sw-h (- (cadddr sw) (cadr sw)))
  (setq sizes (reverse *swapp-swfmt-papers*))
  (setq found nil)
  (foreach scale *swapp-swfmt-scales*
    (foreach paper sizes
      (setq pw (* (cadr paper) scale) ph (* (caddr paper) scale))
      (if
        (and
          (not found)
          content-bbox
          (>= pw (- sw-w *swapp-swfmt-tolerance*))
          (>= ph (- sw-h *swapp-swfmt-tolerance*))
          (or (not *swapp-swfmt-test-skip-missing-frames*) (findfile (swapp-swfmt-frame-file (strcat "DR_" (car paper) "_Outline"))))
        )
        (progn
          (setq cx (/ (+ (car content-bbox) (caddr content-bbox)) 2.0))
          (setq cy (/ (+ (cadr content-bbox) (cadddr content-bbox)) 2.0))
          (setq llx (- cx (/ (- pw (* 30.0 scale)) 2.0) (* 20.0 scale)))
          (setq lly (- cy (/ (- ph (* 20.0 scale)) 2.0) (* 10.0 scale)))
          (setq llx (max (- (caddr outer) pw) (min llx (car outer))))
          (setq lly (max (- (cadddr outer) ph) (min lly (cadr outer))))
          (setq options nil)
          (foreach place
            (list
              (list llx lly)
              (list (car sw) (- (cadddr sw) ph))
              (list (- (caddr sw) pw) (- (cadddr sw) ph))
              (list (car sw) (cadr sw))
              (list (- (caddr sw) pw) (cadr sw))
            )
            (if (swapp-swfmt-paper-holds-p (car place) (cadr place) pw ph scale content-bbox content-boxes)
              (setq options (append options (list (list (car place) (cadr place) (+ (car place) pw) (+ (cadr place) ph)))))
            )
          )
          (if options (setq found (list (car paper) scale options)))
        )
      )
    )
  )
  found
)

;;; Title box of a sheet with no frame: the SOLIDWORKS title box size on the bottom
;;; right of the scaled DR inner border, where the new DR title goes.
(defun swapp-swfmt-frameless-title-box (paper scale / x2 y1)
  (setq x2 (- (caddr paper) (* 10.0 scale)))
  (setq y1 (+ (cadr paper) (* 10.0 scale)))
  (list (- x2 *swapp-swfmt-title-width*) y1 x2 (+ y1 *swapp-swfmt-title-height*))
)

;;; For a sheet with no frame at all (user decision 2026-10-08): the DR frame and
;;; GMTITLE scale whose inner border holds the drawing, as (size scale paper-options),
;;; or nil.  The smallest scale first, then the smallest paper, as for custom-size
;;; sheets.  Places in order of preference: the drawing centred in the inner border,
;;; then a drawing corner 5k inside the matching inner border corner (top left, top
;;; right, bottom left, bottom right), so the paper can grow away from neighbours.
;;; Only places with the drawing clear of the scaled DR title and the title box.
(defun swapp-swfmt-frameless-choice (content-bbox content-boxes / found scale paper pw ph gap x1 y1 x2 y2 cx cy options place sheet-paper box clear item)
  (setq x1 (car content-bbox) y1 (cadr content-bbox) x2 (caddr content-bbox) y2 (cadddr content-bbox))
  (setq cx (/ (+ x1 x2) 2.0) cy (/ (+ y1 y2) 2.0))
  (setq found nil)
  (foreach scale *swapp-swfmt-scales*
    (foreach paper (reverse *swapp-swfmt-papers*)
      (setq pw (* (cadr paper) scale) ph (* (caddr paper) scale) gap (* 5.0 scale))
      (if
        (and
          (not found)
          (or (not *swapp-swfmt-test-skip-missing-frames*) (findfile (swapp-swfmt-frame-file (strcat "DR_" (car paper) "_Outline"))))
        )
        (progn
          (setq options nil)
          (foreach place
            (list
              (list (- cx (/ (- pw (* 30.0 scale)) 2.0) (* 20.0 scale)) (- cy (/ (- ph (* 20.0 scale)) 2.0) (* 10.0 scale)))
              (list (- x1 (* 20.0 scale) gap) (- (+ y2 (* 10.0 scale) gap) ph))
              (list (- (+ x2 (* 10.0 scale) gap) pw) (- (+ y2 (* 10.0 scale) gap) ph))
              (list (- x1 (* 20.0 scale) gap) (- y1 (* 10.0 scale) gap))
              (list (- (+ x2 (* 10.0 scale) gap) pw) (- y1 (* 10.0 scale) gap))
            )
            (setq sheet-paper (list (car place) (cadr place) (+ (car place) pw) (+ (cadr place) ph)))
            (setq box (swapp-swfmt-frameless-title-box sheet-paper scale))
            (setq clear T)
            (foreach item content-boxes
              (if (swcad-title-bbox-overlap-box item box) (setq clear nil))
            )
            (if (and clear (swapp-swfmt-paper-holds-p (car place) (cadr place) pw ph scale content-bbox content-boxes))
              (setq options (append options (list sheet-paper)))
            )
          )
          (if options (setq found (list (car paper) scale options)))
        )
      )
    )
  )
  found
)

;;; Whether lines in region frame the drawing: a closed polyline around all of it,
;;; or lines along all four sides (each at least 90 % of the side).  Such a sheet has
;;; a frame this step does not know, so it is not treated as frameless.
(defun swapp-swfmt-border-around-p (region content-bbox / ss index data etype p1 p2 bbox w h tol sides found)
  (setq w (- (caddr content-bbox) (car content-bbox)))
  (setq h (- (cadddr content-bbox) (cadr content-bbox)))
  (setq tol 1.0)
  (setq sides nil)
  (setq found nil)
  (setq ss (ssget "_X" '((0 . "LINE,LWPOLYLINE") (410 . "Model"))))
  (setq index 0)
  (while (and ss (not found) (< index (sslength ss)))
    (setq data (entget (ssname ss index)))
    (setq etype (cdr (assoc 0 data)))
    (setq p1 (cdr (assoc 10 data)))
    (if (swapp-swfmt-point-inside-p p1 region 1.0)
      (cond
        ((= etype "LWPOLYLINE")
          (setq bbox (swapp-object-bbox4 (vlax-ename->vla-object (ssname ss index))))
          (if
            (and
              bbox
              (= 1 (logand 1 (cdr (assoc 70 data))))
              (swapp-near (car bbox) (car content-bbox) tol) (swapp-near (cadr bbox) (cadr content-bbox) tol)
              (swapp-near (caddr bbox) (caddr content-bbox) tol) (swapp-near (cadddr bbox) (cadddr content-bbox) tol)
            )
            (setq found T)
          )
        )
        (T
          (setq p2 (cdr (assoc 11 data)))
          (cond
            ((and (swapp-near (cadr p1) (cadr p2) tol) (>= (abs (- (car p2) (car p1))) (* 0.9 w)))
              (if (swapp-near (cadr p1) (cadr content-bbox) tol) (setq sides (cons "B" sides)))
              (if (swapp-near (cadr p1) (cadddr content-bbox) tol) (setq sides (cons "T" sides)))
            )
            ((and (swapp-near (car p1) (car p2) tol) (>= (abs (- (cadr p2) (cadr p1))) (* 0.9 h)))
              (if (swapp-near (car p1) (car content-bbox) tol) (setq sides (cons "L" sides)))
              (if (swapp-near (car p1) (caddr content-bbox) tol) (setq sides (cons "R" sides)))
            )
          )
        )
      )
    )
    (setq index (1+ index))
  )
  (or found (and (member "B" sides) (member "T" sides) (member "L" sides) (member "R" sides)))
)

;;; A sheet of a SOURCE_SHEET record with no frame: a DR frame placed around its
;;; drawing.  There are no format entities to move and no cells to read: the title
;;; gets the paper size, the GMTITLE scale and FILE NO / File Name from the file name.
(defun swapp-swfmt-frameless-sheet (record / content-boxes content-bbox item choice size scale paper result)
  (setq content-boxes (swapp-swfmt-content-boxes (nth 4 record) nil))
  (setq content-bbox nil)
  (foreach item content-boxes
    (setq content-bbox (if content-bbox (swapp-bbox4-union content-bbox item) item))
  )
  (setq result
    (list
      (cons "anchor" nil)
      (cons "corner" (if content-bbox (swapp-bbox4-center content-bbox) (swapp-bbox4-center (nth 4 record))))
      (cons "stem" (nth 1 record))
    )
  )
  (cond
    ((not content-bbox)
      (append result (list (cons "status" "NO_FORMAT") (cons "detail" "도면틀도 도면 내용도 없음")))
    )
    ((swapp-swfmt-border-around-p (nth 4 record) content-bbox)
      (append result (list (cons "status" "NO_FORMAT") (cons "detail" "도면을 둘러싼 테두리 선이 있음(모르는 양식일 수 있음)")))
    )
    ((not (setq choice (swapp-swfmt-frameless-choice content-bbox content-boxes)))
      (append
        result
        (list
          (cons "status" "SIZE")
          (cons "detail"
            (strcat
              "도면틀 없음, 도면 " (rtos (- (caddr content-bbox) (car content-bbox)) 2 1) " x "
              (rtos (- (cadddr content-bbox) (cadr content-bbox)) 2 1) " mm: 도면을 담을 DR 도면틀×GMTITLE 축척을 찾지 못함"
            )
          )
        )
      )
    )
    ((progn
       (setq size (car choice) scale (cadr choice) paper (car (caddr choice)))
       (not (findfile (swapp-swfmt-frame-file (strcat "DR_" size "_Outline"))))
     )
      (append
        result
        (list
          (cons "status" "FRAME_FILE")
          (cons "size" size)
          (cons "scale" scale)
          (cons "detail" (strcat "도면틀 없는 도면에 DR_" size " " (swcad-title-scale-text scale) "를 넣을 차례인데 GstarCAD 도면틀 파일이 없음: " (swapp-swfmt-frame-file (strcat "DR_" size "_Outline"))))
        )
      )
    )
    (T
      (append
        result
        (list
          (cons "status" "OK")
          (cons "detail" "")
          (cons "frameless" T)
          (cons "size" size)
          (cons "scale" scale)
          (cons "paper" paper)
          (cons "paper-options" (caddr choice))
          (cons "title" (swapp-swfmt-frameless-title-box paper scale))
          (cons "enames" nil)
          (cons "values" (swapp-swfmt-file-name-tags (list (cons "GEN-TITLE-SIZ{6.7}" size) (cons "GEN-TITLE-SCA{6.7}" (swcad-title-scale-text scale))) (nth 1 record)))
          (cons "notes" (list "도면틀 없는 도면: 읽을 표제란 값 없음"))
        )
      )
    )
  )
)

;;; Title values with FILE NO (NR) and File Name (DWG) from the source file name when
;;; it starts with a drawing number (user decision 2026-10-08; the 도면 번호 cell held
;;; the SOLIDWORKS file name, so FILE NO showed the part name and File Name stayed
;;; empty): "01-06-07-00_Bush Inner" gives NR "01-06-07-00" and DWG "Bush Inner".
;;; Other names keep the values read from the cells.
(defun swapp-swfmt-file-name-tags (tags stem / split)
  (setq split (if stem (swapp-drawing-number-split stem) nil))
  (if (and split (> (strlen (cadr split)) 0))
    (append
      (vl-remove-if '(lambda (p) (member (car p) '("GEN-TITLE-NR{23}" "GEN-TITLE-DWG{23}"))) tags)
      (list (cons "GEN-TITLE-NR{23}" (car split)) (cons "GEN-TITLE-DWG{23}" (cadr split)))
    )
    tags
  )
)

;;; Paper size of a DR frame for the paper width and height, or a failure reason.
(defun swapp-swfmt-paper-size (width height / found paper)
  (setq found nil)
  (foreach paper *swapp-swfmt-papers*
    (if (and (not found) (swapp-near width (cadr paper) *swapp-swfmt-tolerance*) (swapp-near height (caddr paper) *swapp-swfmt-tolerance*))
      (setq found (car paper))
    )
  )
  (if (not found)
    (foreach paper *swapp-swfmt-papers*
      (if (and (not found) (swapp-near width (caddr paper) *swapp-swfmt-tolerance*) (swapp-near height (cadr paper) *swapp-swfmt-tolerance*))
        (setq found (list "ORIENTATION" (car paper)))
      )
    )
  )
  (if found found (list "SIZE" nil))
)

;;; Point a lies on a side of outer, and the line a-b is perpendicular to that side.
(defun swapp-swfmt-on-side-p (a b outer tol)
  (or
    (and (or (swapp-near (car a) (car outer) tol) (swapp-near (car a) (caddr outer) tol))
         (swapp-near (cadr a) (cadr b) tol))
    (and (or (swapp-near (cadr a) (cadr outer) tol) (swapp-near (cadr a) (cadddr outer) tol))
         (swapp-near (car a) (car b) tol))
  )
)

;;; Zone tick: an axis-parallel line of up to 10.5 mm that starts on an outer
;;; border side and points inward.
(defun swapp-swfmt-zone-tick-p (item outer / p1 p2 tol)
  (setq p1 (nth 3 item) p2 (nth 4 item) tol 0.1)
  (and
    (<= (distance p1 p2) 10.5)
    (swapp-swfmt-point-inside-p p1 outer tol)
    (swapp-swfmt-point-inside-p p2 outer tol)
    (or (swapp-swfmt-on-side-p p1 p2 outer tol) (swapp-swfmt-on-side-p p2 p1 outer tol))
  )
)

;;; Zone letter or number: one or two letters or digits centred in the band between
;;; the borders.  Two-letter zones of large sheets ("CF") are wider than the band.
(defun swapp-swfmt-zone-text-p (item outer inner / center)
  (setq center (swapp-bbox4-center (nth 6 item)))
  (and
    (swapp-swfmt-text-item-p item)
    (nth 5 item)
    (wcmatch (nth 5 item) "@,@@,#,##")
    (swapp-swfmt-point-inside-p center outer 0.5)
    (not (swapp-swfmt-point-inside-p center inner -0.01))
  )
)

;;; Texts of a block definition (a SOLIDWORKS note), top to bottom, joined.
(defun swapp-swfmt-block-text (name / block items item point text result)
  (setq items nil)
  (setq block (swapp-block-definition name))
  (if block
    (vlax-for item block
      (if (member (vla-get-ObjectName item) '("AcDbText" "AcDbMText"))
        (progn
          (setq point (vlax-safearray->list (vlax-variant-value (vla-get-InsertionPoint item))))
          (setq text
            (vl-string-trim " \t\r\n"
              (if (= (vla-get-ObjectName item) "AcDbMText")
                (swcad-title-mtext-plain (vla-get-TextString item))
                (vla-get-TextString item)
              )
            )
          )
          (if (> (strlen text) 0) (setq items (cons (list (cadr point) (car point) text) items)))
        )
      )
    )
  )
  (setq items (vl-sort items '(lambda (a b) (if (swapp-near (car a) (car b) 0.5) (< (cadr a) (cadr b)) (> (car a) (car b))))))
  (setq result "")
  (foreach item items
    (setq result (if (= result "") (caddr item) (strcat result " " (caddr item))))
  )
  result
)

;;; The cell entry containing point (relative to corner), or nil.
(defun swapp-swfmt-cell-at (point corner / found cell dx dy)
  (setq found nil)
  (setq dx (- (car point) (car corner)))
  (setq dy (- (cadr point) (cadr corner)))
  (foreach cell *swapp-swfmt-cells*
    (if
      (and
        (not found)
        (>= dx (- (nth 1 cell) 0.2)) (<= dx (+ (nth 3 cell) 0.2))
        (>= dy (- (nth 2 cell) 0.2)) (<= dy (+ (nth 4 cell) 0.2))
      )
      (setq found cell)
    )
  )
  found
)

;;; Adds (y x text) to the cell's entry of the value list.
(defun swapp-swfmt-add-value (values cell point text / pair)
  (setq pair (assoc (car cell) values))
  (if pair
    (subst (cons (car cell) (append (cdr pair) (list (list (cadr point) (car point) text)))) pair values)
    (append values (list (cons (car cell) (list (list (cadr point) (car point) text)))))
  )
)

(defun swapp-swfmt-joined-text (entries / sorted item result)
  (setq sorted (vl-sort entries '(lambda (a b) (if (swapp-near (car a) (car b) 0.5) (< (cadr a) (cadr b)) (> (car a) (car b))))))
  (setq result "")
  (foreach item sorted
    (setq result (if (= result "") (caddr item) (strcat result " " (caddr item))))
  )
  result
)

;;; The SOURCE_SHEET record of the sheet around point, or nil.
(defun swapp-swfmt-record-at (point records / found record)
  (setq found nil)
  (foreach record records
    (if (and (not found) (swapp-swfmt-point-inside-p point (nth 4 record) 1.0))
      (setq found record)
    )
  )
  found
)

;;; Items inside bbox.  One sheet holds a few hundred of the drawing's tens of
;;; thousands of objects, so each sheet is recognized from its own items only.
(defun swapp-swfmt-items-inside (items bbox / result item)
  (setq result nil)
  (foreach item items
    (if (swapp-swfmt-inside-p (nth 6 item) bbox 1.0) (setq result (cons item result)))
  )
  result
)

;;; Recognizes the sheet of one anchor text.  Returns an assoc list; "status" is
;;; "OK" or the reason it cannot be converted.
(defun swapp-swfmt-recognize (anchor all-items source-records / record items lines anchor-label corner title-box near-items near-enames labels-found missing item label inner outer outer-lines inner-lines paper-w paper-h size-result size scale paper paper-options content-boxes content-bbox choice title-items tick-items zone-items enames values notes cell point text frame-file locked result tags pair tag cell-values)
  (setq anchor-label (assoc *swapp-swfmt-anchor-text* *swapp-swfmt-labels*))
  (setq corner (list (- (car (nth 3 anchor)) (nth 2 anchor-label)) (- (cadr (nth 3 anchor)) (nth 3 anchor-label)) 0.0))
  (setq title-box
    (list (- (car corner) *swapp-swfmt-title-width*) (cadr corner) (car corner) (+ (cadr corner) *swapp-swfmt-title-height*))
  )
  (setq record (swapp-swfmt-record-at (nth 3 anchor) source-records))
  (setq items (if record (swapp-swfmt-items-inside all-items (nth 4 record)) all-items))
  (setq lines nil)
  (foreach item items
    (if (= (cadr item) "LINE") (setq lines (cons item lines)))
  )
  (setq result
    (list
      (cons "anchor" (car anchor))
      (cons "corner" corner)
      (cons "stem" (if record (nth 1 record) ""))
    )
  )
  ;; Items of the title box, and the labels among them.  A long 도면 번호 value
  ;; runs past the title block's right line, so texts count by where they start.
  (setq near-items nil)
  (foreach item items
    (if (swapp-swfmt-title-item-p item title-box)
      (setq near-items (cons item near-items))
    )
  )
  (setq near-enames (mapcar 'car near-items))
  (setq labels-found nil)
  (foreach item near-items
    (if (and (swapp-swfmt-text-item-p item) (setq label (swapp-swfmt-label-of item corner)))
      (setq labels-found (cons (car label) labels-found))
    )
  )
  (setq missing nil)
  (foreach label *swapp-swfmt-labels*
    (if (not (member (car label) labels-found)) (setq missing (append missing (list (car label)))))
  )
  (cond
    (missing
      (append result (list (cons "status" "LABELS") (cons "detail" (strcat "표제란 칸 이름 " (itoa (length missing)) "개가 기본 양식 위치에 없음"))))
    )
    ((not (setq inner (swapp-swfmt-inner-border lines corner)))
      (append result (list (cons "status" "BORDER") (cons "detail" "표제란이 안쪽 테두리 오른쪽 아래 모서리에 있지 않음(사용자 크기 용지일 수 있음)")))
    )
    ((progn
       (setq outer
         (list
           (- (car inner) *swapp-swfmt-border-gap*) (- (cadr inner) *swapp-swfmt-border-gap*)
           (+ (caddr inner) *swapp-swfmt-border-gap*) (+ (cadddr inner) *swapp-swfmt-border-gap*)
         )
       )
       (setq inner-lines (swapp-swfmt-rectangle-lines lines inner))
       (setq outer-lines (swapp-swfmt-rectangle-lines lines outer))
       (not (and inner-lines outer-lines))
     )
      (append result (list (cons "status" "BORDER") (cons "detail" "두 겹 테두리의 네 변을 모두 찾지 못함")))
    )
    ((progn
       ;; Every format entity: both borders, zone ticks and letters, and everything
       ;; in the title box.
       (setq enames (mapcar 'car (append inner-lines outer-lines)))
       (setq title-items nil)
       (setq tick-items nil)
       (setq zone-items nil)
       (foreach item lines
         (cond
           ((member (car item) enames))
           ((swapp-swfmt-inside-p (nth 6 item) title-box 0.2) (setq title-items (cons item title-items)))
           ((swapp-swfmt-zone-tick-p item outer) (setq tick-items (cons item tick-items)))
         )
       )
       (foreach item items
         (cond
           ((= (cadr item) "LINE"))
           ((member (car item) near-enames) (setq title-items (cons item title-items)))
           ((swapp-swfmt-zone-text-p item outer inner) (setq zone-items (cons item zone-items)))
         )
       )
       (setq enames (append enames (mapcar 'car title-items) (mapcar 'car tick-items) (mapcar 'car zone-items)))
       ;; A standard sheet: title block at the inner corner and an A0..A4 paper.  It
       ;; gets the DR frame at 1:1 with both inner borders on top of each other.
       (setq paper-w (+ (- (caddr outer) (car outer)) *swapp-swfmt-paper-margin-left* *swapp-swfmt-paper-margin-right*))
       (setq paper-h (+ (- (cadddr outer) (cadr outer)) (* 2.0 *swapp-swfmt-paper-margin-y*)))
       (setq size-result (swapp-swfmt-paper-size paper-w paper-h))
       (setq scale 1.0)
       (cond
         ((and (swapp-near (caddr inner) (car corner) 0.5) (not (listp size-result)))
           (setq size size-result)
           (setq paper
             (list
               (- (car outer) *swapp-swfmt-paper-margin-left*) (- (cadr outer) *swapp-swfmt-paper-margin-y*)
               (+ (caddr outer) *swapp-swfmt-paper-margin-right*) (+ (cadddr outer) *swapp-swfmt-paper-margin-y*)
             )
           )
         )
         ((and (swapp-near (caddr inner) (car corner) 0.5) (equal (car size-result) "ORIENTATION"))
           (setq size nil)
         )
         ;; A custom-size sheet: the DR frame enlarged by a GMTITLE scale.  The
         ;; drawing stays 1:1.
         (T
           (setq size-result nil)
           (setq content-boxes (swapp-swfmt-content-boxes (if record (nth 4 record) outer) enames))
           (setq content-bbox nil)
           (foreach item content-boxes
             (setq content-bbox (if content-bbox (swapp-bbox4-union content-bbox item) item))
           )
           (setq choice (swapp-swfmt-scaled-choice outer content-bbox content-boxes))
           (if choice
             (setq size (car choice) scale (cadr choice) paper-options (caddr choice) paper (car paper-options))
             (setq size nil)
           )
         )
       )
       (not size)
     )
      (append
        result
        (list
          (cons "status" (if size-result (car size-result) "SIZE"))
          (cons "detail"
            (strcat
              "용지 " (rtos paper-w 2 1) " x " (rtos paper-h 2 1) " mm"
              (if size-result
                (strcat ": " (cadr size-result) " 도면틀과 방향이 다름")
                ": 도면을 담을 DR 도면틀×GMTITLE 축척을 찾지 못함"
              )
            )
          )
        )
      )
    )
    ((progn
       (setq frame-file (swapp-swfmt-frame-file (strcat "DR_" size "_Outline")))
       (not (findfile frame-file))
     )
      (append
        result
        (list
          (cons "status" "FRAME_FILE")
          (cons "size" size)
          (cons "scale" scale)
          (cons "detail"
            (strcat
              (if (> scale 1.0) (strcat "DR_" size " " (swcad-title-scale-text scale) "로 키울 도면인데 ") "")
              "GstarCAD 도면틀 파일이 없음: " frame-file
            )
          )
        )
      )
    )
    (T
      ;; Values by cell.  A label's own text is not a value, except what follows a
      ;; PREFIX label such as "배율:1:10".
      (setq values nil)
      (foreach item title-items
        (setq text nil)
        (setq point (swapp-swfmt-item-cell-point item))
        (cond
          ((= (cadr item) "INSERT")
            (setq text (swapp-swfmt-block-text (swapp-reference-name (vlax-ename->vla-object (car item)))))
          )
          ((not (swapp-swfmt-text-item-p item)))
          ((setq label (swapp-swfmt-label-of item corner))
            (if (and (nth 4 label) (equal (nth 1 label) "PREFIX"))
              (setq text (vl-string-trim " \t" (substr (nth 5 item) (1+ (strlen (car label))))))
            )
          )
          (T (setq text (nth 5 item)))
        )
        (if (and text (> (strlen text) 0))
          (progn
            (setq cell (swapp-swfmt-cell-at point corner))
            (if (not cell) (setq cell (list "표제란 기타" 0 0 0 0 nil)))
            (setq values (swapp-swfmt-add-value values cell point text))
          )
        )
      )
      (setq tags nil)
      (setq notes nil)
      (foreach pair values
        (setq cell (assoc (car pair) *swapp-swfmt-cells*))
        (setq tag (if cell (nth 5 cell) nil))
        (cond
          ((equal tag "-"))
          (tag (setq tags (append tags (list (cons tag (swapp-swfmt-joined-text (cdr pair)))))))
          (T (setq notes (append notes (list (strcat (car pair) ": " (swapp-swfmt-joined-text (cdr pair)))))))
        )
      )
      (setq tags (append tags (list (cons "GEN-TITLE-SIZ{6.7}" size))))
      ;; An enlarged frame keeps the scale GMTITLE writes for it (1:4 for a 1:4 frame),
      ;; not the SOLIDWORKS 배율 of the custom sheet (user decision 2026-09-30).
      (if (> scale 1.0)
        (setq tags
          (append
            (vl-remove-if '(lambda (p) (equal (car p) "GEN-TITLE-SCA{6.7}")) tags)
            (list (cons "GEN-TITLE-SCA{6.7}" (swcad-title-scale-text scale)))
          )
        )
      )
      ;; FILE NO and File Name from the file name; a cell value it replaces that
      ;; says something else is kept in the log.
      (setq cell-values tags)
      (setq tags (swapp-swfmt-file-name-tags tags (cdr (assoc "stem" result))))
      (foreach tag '("GEN-TITLE-NR{23}" "GEN-TITLE-DWG{23}")
        (setq text (cdr (assoc tag cell-values)))
        (if (and text (not (member text (list (cdr (assoc "GEN-TITLE-NR{23}" tags)) (cdr (assoc "GEN-TITLE-DWG{23}" tags))))))
          (setq notes (append notes (list (strcat (if (equal tag "GEN-TITLE-NR{23}") "도면 번호" "제목") " 칸(파일 이름과 다름): " text))))
        )
      )
      (setq locked nil)
      (foreach item (append inner-lines outer-lines title-items tick-items zone-items)
        (if (swapp-swfmt-layer-locked-p (nth 2 item)) (setq locked (cons (nth 2 item) locked)))
      )
      (append
        result
        (list
          (cons "status" (if locked "LOCKED" "OK"))
          (cons "detail" (if locked (strcat "잠긴 레이어: " (car locked)) ""))
          (cons "size" size)
          (cons "scale" scale)
          (cons "paper" paper)
          (cons "paper-options" paper-options)
          (cons "title" title-box)
          (cons "enames" enames)
          (cons "values" tags)
          (cons "cell-values" cell-values)
          (cons "notes" notes)
        )
      )
    )
  )
)

(defun swapp-swfmt-layer-locked-p (layer / data)
  (setq data (tblsearch "LAYER" layer))
  (and data (= 4 (logand 4 (cdr (assoc 70 data)))))
)

(defun swapp-swfmt-value (sheet key)
  (cdr (assoc key sheet))
)

;;; Source sheets (SOURCE_SHEET records) with neither a recognized or failed sheet
;;; format nor a frame block: nothing to convert them with.
(defun swapp-swfmt-uncovered-records (source-records sheets / frames result record covered sheet frame)
  (setq frames (swcad-title-source-frame-candidates))
  (setq result nil)
  (foreach record source-records
    (setq covered nil)
    (foreach sheet sheets
      (if (swapp-swfmt-point-inside-p (swapp-swfmt-value sheet "corner") (nth 4 record) 1.0)
        (setq covered T)
      )
    )
    (foreach frame frames
      (if (swapp-swfmt-point-inside-p (swapp-bbox4-center (nth 2 frame)) (nth 4 record) 1.0)
        (setq covered T)
      )
    )
    (if (not covered) (setq result (append result (list record))))
  )
  result
)

(defun swapp-swfmt-with-value (sheet key value / pair)
  (setq pair (assoc key sheet))
  (if pair (subst (cons key value) pair sheet) (append sheet (list (cons key value))))
)

;;; Standard sheets keep their paper.  Each enlarged sheet takes its first paper
;;; option that overlaps no paper placed so far; with none it keeps its first
;;; option, and the overlap check below stops the run.
(defun swapp-swfmt-place-papers (sheets / placed result sheet options chosen option clash other)
  (setq placed nil)
  (foreach sheet sheets
    (if (and (equal (swapp-swfmt-value sheet "status") "OK") (not (swapp-swfmt-value sheet "paper-options")))
      (setq placed (cons (swapp-swfmt-value sheet "paper") placed))
    )
  )
  (setq result nil)
  (foreach sheet sheets
    (setq options (swapp-swfmt-value sheet "paper-options"))
    (if (and (equal (swapp-swfmt-value sheet "status") "OK") options)
      (progn
        (setq chosen nil)
        (foreach option options
          (if (not chosen)
            (progn
              (setq clash nil)
              (foreach other placed
                (if (swcad-title-bbox-overlap-box option other) (setq clash T))
              )
              (if (not clash) (setq chosen option))
            )
          )
        )
        (if chosen
          (progn
            (setq placed (cons chosen placed))
            (setq sheet (swapp-swfmt-with-value sheet "paper" chosen))
            (if (swapp-swfmt-value sheet "frameless")
              (setq sheet (swapp-swfmt-with-value sheet "title" (swapp-swfmt-frameless-title-box chosen (swapp-swfmt-value sheet "scale"))))
            )
          )
        )
      )
    )
    (setq result (append result (list sheet)))
  )
  result
)

;;; Recognized sheets whose new paper overlaps another recognized sheet's paper.
(defun swapp-swfmt-overlapping-sheets (sheets / ok result sheet other)
  (setq ok (vl-remove-if-not '(lambda (s) (equal (swapp-swfmt-value s "status") "OK")) sheets))
  (setq result nil)
  (foreach sheet ok
    (foreach other ok
      (if
        (and
          (not (eq sheet other))
          (not (member sheet result))
          (swcad-title-bbox-overlap-box (swapp-swfmt-value sheet "paper") (swapp-swfmt-value other "paper"))
        )
        (setq result (append result (list sheet)))
      )
    )
  )
  result
)

;;; A block name base + two-digit number not used yet in this drawing.
(defun swapp-swfmt-free-block-name (base index / name)
  (setq name (strcat base (if (< index 10) "0" "") (itoa index)))
  (while (swapp-block-definition name)
    (setq index (+ index 100))
    (setq name (strcat base (itoa index)))
  )
  name
)

(defun swapp-swfmt-object-array (objects)
  (vlax-make-variant
    (vlax-safearray-fill
      (vlax-make-safearray vlax-vbObject (cons 0 (1- (length objects))))
      objects
    )
  )
)

(defun swapp-swfmt-add-rectangle (block bbox / x1 y1 x2 y2)
  (setq x1 (car bbox) y1 (cadr bbox) x2 (caddr bbox) y2 (cadddr bbox))
  (and
    (swapp-safe 'vla-AddLine (list block (vlax-3d-point (list x1 y1 0.0)) (vlax-3d-point (list x2 y1 0.0))))
    (swapp-safe 'vla-AddLine (list block (vlax-3d-point (list x2 y1 0.0)) (vlax-3d-point (list x2 y2 0.0))))
    (swapp-safe 'vla-AddLine (list block (vlax-3d-point (list x2 y2 0.0)) (vlax-3d-point (list x1 y2 0.0))))
    (swapp-safe 'vla-AddLine (list block (vlax-3d-point (list x1 y2 0.0)) (vlax-3d-point (list x1 y1 0.0))))
  )
)

;;; Makes the two blocks of one sheet and inserts them at the paper corner.
;;; Returns (frame-reference title-reference frame-name title-name) or nil; on
;;; failure whatever this call made is removed again.
(defun swapp-swfmt-make-blocks (sheet index / doc blocks paper origin frame-name title-name frame-block title-block objects copy-result ok slot value point title-box frame-ref title-ref)
  (setq doc (swapp-doc))
  (setq blocks (vla-get-Blocks doc))
  (setq paper (swapp-swfmt-value sheet "paper"))
  (setq title-box (swapp-swfmt-value sheet "title"))
  (setq origin (vlax-3d-point (list (car paper) (cadr paper) 0.0)))
  ;; SWFMT_A0_OUTLINE_S4_05: an enlarged frame names its GMTITLE scale for the TITLE step.
  (setq frame-name
    (swapp-swfmt-free-block-name
      (strcat
        *swapp-swfmt-block-prefix* (swapp-swfmt-value sheet "size") "_OUTLINE_"
        (if (> (swapp-swfmt-value sheet "scale") 1.0) (strcat "S" (swapp-swfmt-scale-token (swapp-swfmt-value sheet "scale")) "_") "")
      )
      index
    )
  )
  (setq title-name (swapp-swfmt-free-block-name (strcat *swapp-swfmt-block-prefix* "TITLE_") index))
  (setq frame-block (swapp-safe 'vla-Add (list blocks origin frame-name)))
  (setq title-block (if frame-block (swapp-safe 'vla-Add (list blocks origin title-name)) nil))
  (setq objects (mapcar '(lambda (e) (vlax-ename->vla-object e)) (swapp-swfmt-value sheet "enames")))
  ;; A frameless sheet has no format entities to copy.
  (setq copy-result
    (cond
      ((not title-block) nil)
      ((not objects) T)
      (T (vl-catch-all-apply 'vla-CopyObjects (list doc (swapp-swfmt-object-array objects) frame-block)))
    )
  )
  (setq ok (and title-block copy-result (not (vl-catch-all-error-p copy-result))))
  (if ok (setq ok (swapp-swfmt-add-rectangle frame-block paper)))
  (if ok (setq ok (swapp-swfmt-add-rectangle title-block title-box)))
  ;; Attributes at the GMTITLE slot positions, so both the tag and the slot
  ;; position of the TITLE step read the same field.
  (if ok
    (foreach slot *swcad-title-transfer-template*
      (setq value (cdr (assoc (car slot) (swapp-swfmt-value sheet "values"))))
      (setq point (list (+ (car title-box) (cadr slot)) (+ (cadr title-box) (caddr slot)) 0.0))
      (if
        (not
          (swapp-safe
            'vla-AddAttribute
            (list title-block 2.5 0 (car slot) (vlax-3d-point point) (car slot) (if value value ""))
          )
        )
        (setq ok nil)
      )
    )
  )
  (if ok (setq frame-ref (swapp-safe 'vla-InsertBlock (list (swapp-model) origin frame-name 1.0 1.0 1.0 0.0))))
  (if (and ok frame-ref) (setq title-ref (swapp-safe 'vla-InsertBlock (list (swapp-model) origin title-name 1.0 1.0 1.0 0.0))))
  (if (and ok frame-ref title-ref)
    (list frame-ref title-ref frame-name title-name)
    (progn
      (if title-ref (swapp-safe 'vla-Delete (list title-ref)))
      (if frame-ref (swapp-safe 'vla-Delete (list frame-ref)))
      (if title-block (swapp-safe 'vla-Delete (list title-block)))
      (if frame-block (swapp-safe 'vla-Delete (list frame-block)))
      nil
    )
  )
)

;;; Model-space texts that still start inside one of the title boxes.
(defun swapp-swfmt-leftover-title-texts (title-boxes / ss index point count box found)
  (setq count 0)
  (setq ss (ssget "_X" '((0 . "TEXT,MTEXT") (410 . "Model"))))
  (setq index 0)
  (while (and ss (< index (sslength ss)))
    (setq point (cdr (assoc 10 (entget (ssname ss index)))))
    (setq found nil)
    (foreach box title-boxes
      (if (and (not found) (swapp-swfmt-point-inside-p point box 0.5)) (setq found T))
    )
    (if found (setq count (1+ count)))
    (setq index (1+ index))
  )
  count
)

(defun swapp-swfmt-status-text (status)
  (cond
    ((equal status "LABELS") "기본 양식 아님")
    ((equal status "BORDER") "테두리 모양이 기본 양식과 다름")
    ((equal status "SIZE") "표준 크기 아님")
    ((equal status "ORIENTATION") "용지 방향 다름")
    ((equal status "FRAME_FILE") "도면틀 파일 없음")
    ((equal status "LOCKED") "잠긴 레이어")
    ((equal status "NO_FORMAT") "도면틀 없음")
    ((equal status "OVERLAP") "도면틀 겹침")
    (T status)
  )
)

(defun swapp-swfmt-print-problem (stem status detail)
  (swapp-swfmt-say
    (strcat "\n  " (if (> (strlen stem) 0) stem "<파일명 모름>") " - " (swapp-swfmt-status-text status) (if (> (strlen detail) 0) (strcat ": " detail) ""))
  )
)

;;; SWCADRUN step for SOLIDWORKS default sheet formats.  Returns T when every sheet
;;; became a SWFMT frame and title pair.
(defun swapp-convert-sheet-formats (/ result)
  (swapp-swfmt-log-close)
  (setq *swapp-swfmt-log-handle* (open (swapp-swfmt-log-path) "w"))
  (setq result (vl-catch-all-apply 'swapp-convert-sheet-formats-run nil))
  (swapp-swfmt-log-close)
  (if (vl-catch-all-error-p result)
    (progn
      (princ (strcat "\nSolidWorks 기본 양식 정리 오류: " (vl-catch-all-error-message result)))
      (princ "\n진행 중지: 현재 도면을 저장하지 말고 원인을 확인하세요.")
      nil
    )
    result
  )
)

;;; Every sheet of the step with its paper placed: one per default format title
;;; block, then one per source sheet with neither a frame block nor a default format,
;;; which gets a DR frame around its drawing (user decision 2026-10-08).
(defun swapp-swfmt-sheets (items source-records / anchors item sheets record)
  (setq anchors nil)
  (foreach item items
    (if (and (swapp-swfmt-text-item-p item) (equal (nth 5 item) *swapp-swfmt-anchor-text*))
      (setq anchors (cons item anchors))
    )
  )
  (setq sheets nil)
  (foreach item anchors
    (setq sheets (append sheets (list (swapp-swfmt-recognize item items source-records))))
  )
  (foreach record (swapp-swfmt-uncovered-records source-records sheets)
    (setq sheets (append sheets (list (swapp-swfmt-frameless-sheet record))))
  )
  (swapp-swfmt-place-papers sheets)
)

(defun swapp-convert-sheet-formats-run (/ source-records sheets problems sheet record made made-list index before-dimensions after-dimensions deleted failed-delete ename summary source-titles source-frames remaining leftover ok pair value)
  (swapp-activate-model)
  (swapp-swfmt-say "\n----- SolidWorks 기본 양식(선·글자) 정리 -----")
  (setq source-records (swapp-source-sheet-records-read))
  (setq sheets (swapp-swfmt-sheets (swapp-swfmt-scan) source-records))
  (setq problems nil)
  (foreach sheet sheets
    (if (not (equal (swapp-swfmt-value sheet "status") "OK"))
      (setq problems (append problems (list (list (swapp-swfmt-value sheet "stem") (swapp-swfmt-value sheet "status") (swapp-swfmt-value sheet "detail")))))
    )
  )
  ;; An enlarged frame is larger than its SOLIDWORKS sheet and the collected sheets
  ;; are only 50 mm apart.  The drawings are never moved, so stop instead.
  (foreach sheet (swapp-swfmt-overlapping-sheets sheets)
    (setq problems (append problems (list (list (swapp-swfmt-value sheet "stem") "OVERLAP" "새 도면틀이 다른 도면의 도면틀과 겹침"))))
  )
  (swapp-swfmt-say (strcat "\nSolidWorks 기본 양식 시트: " (itoa (length (vl-remove-if-not '(lambda (x) (swapp-swfmt-value x "anchor")) sheets))) "장, 도면틀 없는 시트: " (itoa (length (vl-remove-if '(lambda (x) (swapp-swfmt-value x "anchor")) sheets))) "장, 원본 파일 기록: " (itoa (length source-records)) "개"))
  (cond
    (problems
      (swapp-swfmt-say (strcat "\n결과: STOP_SHEET_FORMAT_UNSUPPORTED (" (itoa (length problems)) "장)"))
      (swapp-swfmt-say "\n아래 도면은 자동으로 바꿀 수 없어 아무것도 바꾸지 않았습니다.")
      (foreach record (vl-sort problems '(lambda (a b) (< (car a) (car b))))
        (swapp-swfmt-print-problem (car record) (cadr record) (caddr record))
      )
      (swapp-swfmt-say "\n도면틀이 없는 도면은 SolidWorks에서 양식을 넣어 다시 저장하거나, 이 파일을 빼고 새 도면에서 다시 모으세요.")
      (swapp-swfmt-say "\nA0 도면과 A0 도면틀을 키워 넣을 도면은 GstarCAD 도면틀 폴더에 DR_A0_Outline.dwg가 있어야 합니다.")
      (swapp-swfmt-say "\n도면틀이 겹치면 도면 사이를 더 띄워 새 도면에서 다시 모으세요.")
      nil
    )
    ((not (swcad-title-ensure-work-copy-for-mutation))
      (swapp-swfmt-say "\n결과: ABORT_WORKCOPY_NOT_CREATED")
      nil
    )
    (T
      (setq before-dimensions (swapp-top-dimension-count))
      (setq made-list nil)
      (setq index 1)
      (setq ok T)
      ;; First make every block pair; the original lines and texts stay until all
      ;; pairs exist, so a failure leaves the drawing as it was.
      (foreach sheet sheets
        (if ok
          (progn
            (setq made (swapp-swfmt-make-blocks sheet index))
            (if made
              (setq made-list (append made-list (list (cons sheet made))))
              (setq ok nil)
            )
          )
        )
        (setq index (1+ index))
      )
      (if (not ok)
        (progn
          (foreach pair made-list
            (swapp-safe 'vla-Delete (list (caddr pair)))
            (swapp-safe 'vla-Delete (list (cadr pair)))
            (swapp-safe 'vla-Delete (list (swapp-block-definition (nth 4 pair))))
            (swapp-safe 'vla-Delete (list (swapp-block-definition (nth 3 pair))))
          )
          (swapp-swfmt-say "\n결과: ABORT_SHEET_FORMAT_BLOCK_FAILED")
          (swapp-swfmt-say "\n양식 블록을 만들지 못해 만든 것을 지웠습니다. 원래 선과 글자는 그대로입니다.")
          nil
        )
        (progn
          (setq deleted 0)
          (setq failed-delete 0)
          (foreach pair made-list
            (foreach ename (swapp-swfmt-value (car pair) "enames")
              (if (swapp-call-ok-p 'vla-Delete (list (vlax-ename->vla-object ename)))
                (setq deleted (1+ deleted))
                (setq failed-delete (1+ failed-delete))
              )
            )
          )
          (vla-Regen (swapp-doc) 1)
          (setq after-dimensions (swapp-top-dimension-count))
          (setq remaining (swapp-swfmt-anchor-count))
          (setq leftover (swapp-swfmt-leftover-title-texts (mapcar '(lambda (p) (swapp-swfmt-value (car p) "title")) made-list)))
          (setq summary (swcad-title-fast-sheet-summary))
          (setq source-titles (swcad-title-fast-summary-value summary "source-title-count"))
          (setq source-frames (swcad-title-fast-summary-value summary "source-frame-count"))
          (foreach pair made-list
            (setq sheet (car pair))
            (swapp-swfmt-log
              (strcat
                (swapp-swfmt-value sheet "stem") " | " (swapp-swfmt-value sheet "size")
                " " (swcad-title-scale-text (swapp-swfmt-value sheet "scale")) " | " (nth 3 pair)
                " | objects " (itoa (length (swapp-swfmt-value sheet "enames")))
              )
            )
            (foreach value (swapp-swfmt-value sheet "values")
              (if (> (strlen (cdr value)) 0) (swapp-swfmt-log (strcat "  " (car value) " = " (cdr value))))
            )
            (foreach value (swapp-swfmt-value sheet "notes")
              (swapp-swfmt-log (strcat "  (칸 없음, 기록만) " value))
            )
          )
          (swapp-swfmt-say (strcat "\n만든 양식 블록 쌍: " (itoa (length made-list))))
          (swapp-swfmt-say (strcat "\n옮겨 담고 지운 원래 선·글자: " (itoa deleted) (if (> failed-delete 0) (strcat ", 지우지 못함 " (itoa failed-delete)) "")))
          (swapp-swfmt-say (strcat "\n남은 기본 양식 표제란: " (itoa remaining) ", 표제란 안에 남은 글자: " (itoa leftover)))
          (swapp-swfmt-say (strcat "\n최상위 치수: " (itoa before-dimensions) " -> " (itoa after-dimensions)))
          (swapp-swfmt-say (strcat "\n원본 표제란/도면틀: " (itoa source-titles) " / " (itoa source-frames)))
          (if
            (and
              (= failed-delete 0)
              (= remaining 0)
              (= leftover 0)
              (= before-dimensions after-dimensions)
              (>= source-titles (length made-list))
              (>= source-frames (length made-list))
            )
            (progn
              (swapp-state-set "SHEET_FORMAT" "OK")
              (swapp-state-set "SHEET_FORMAT_COUNT" (itoa (length made-list)))
              (swapp-save-current)
              (swapp-swfmt-say "\n결과: SWCAD_SHEET_FORMAT_OK")
              (swapp-swfmt-say "\n칸이 없는 표제란 글자와 읽은 값은 swcad_sheet_format_last.txt에 있습니다.")
              T
            )
            (progn
              (swapp-state-set "SHEET_FORMAT" "FAILED")
              (swapp-swfmt-say "\n결과: SWCAD_SHEET_FORMAT_FAILED")
              (swapp-swfmt-say "\n현재 도면을 저장하지 말고 원인을 확인하세요. 이 상태에서 GMTITLE 변환을 계속하지 마세요.")
              nil
            )
          )
        )
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

;;; Layouts that are not the app's and hold nothing but viewports, such as the
;;; template's empty 배치1 and 배치2.  A layout with anything drawn on it stays.
(defun swapp-empty-user-layouts (/ owned result layout name empty item)
  (setq owned (swapp-layout-owned-names))
  (setq result nil)
  (vlax-for layout (vla-get-Layouts (swapp-doc))
    (setq name (vla-get-Name layout))
    (if (and (not (equal (strcase name) "MODEL")) (not (swapp-name-member-ci-p name owned)))
      (progn
        (setq empty T)
        (vlax-for item (vla-get-Block layout)
          (if (/= (vla-get-ObjectName item) "AcDbViewport") (setq empty nil))
        )
        (if empty (setq result (append result (list layout))))
      )
    )
  )
  result
)

(defun swapp-delete-empty-user-layouts (/ count layout name)
  (setq count 0)
  (foreach layout (swapp-empty-user-layouts)
    (setq name (vla-get-Name layout))
    (if (swapp-call-ok-p 'vla-Delete (list layout))
      (progn
        (setq count (1+ count))
        (princ (strcat "\n빈 배치 삭제: " name))
      )
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
              (swapp-delete-empty-user-layouts)
              (swapp-activate-model)
              (setq result (swapp-layouts-valid-p plan))
            )
          )
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
    ((equal stage "COLLECT") "0/6 도면 모으기 - DWG를 골라 XREF로 자동 배치")
    ((equal stage "XREF") "1/6 입력 도면 준비 - XREF 분해")
    ((equal stage "SHEET_WRAPPERS") "1/6 입력 도면 준비 - 시트 묶음 분해")
    ((equal stage "SHEET_FORMAT") "1/6 입력 도면 준비 - SolidWorks 기본 양식 정리")
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
  (if (equal stage "COLLECT")
    (princ "\n빈 도면입니다. SWCADRUN을 실행하면 DWG를 골라 파일 이름 순서로 XREF를 자동 배치합니다.")
  )
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
  (if (> (swapp-cached-swfmt-anchor-count) 0)
    (princ (strcat "\nSolidWorks 기본 양식(선·글자) 표제란: " (itoa (swapp-cached-swfmt-anchor-count)) "장 - 다음 SWCADRUN에서 양식 블록으로 정리"))
  )
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
    ;; A sub-step that left no result may have stopped part way.  Record a
    ;; stop so the status below does not recommend SWCADRUN again.
    ((= (strlen status) 0)
      (setq *swcad-title-last-apply-status* "REVIEW_TITLE_STEP_NO_RESULT")
      (princ "\n진행 중지: GMTITLE 하위 단계가 결과 상태를 남기지 않았습니다.")
      (princ "\n오류나 ESC로 중간에 멈췄을 수 있습니다. 현재 도면을 저장하지 말고 SWTITLESTATUS로 확인하세요.")
      nil
    )
    ((swapp-title-blocking-status-p status)
      (princ (strcat "\n진행 중지: GMTITLE 결과가 " status " 입니다."))
      (princ "\n현재 도면을 저장하지 말고 원인을 확인하세요. SWCADRUN을 반복하지 마세요.")
      nil
    )
    (T
      (princ (strcat "\n이번 GMTITLE 하위 단계 완료. 결과=" status))
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

(defun c:SWCADRUN (/ *error* stage after-stage run-result mutating-stage cleanup-retry-blocked)
  ;; An error or ESC that no step caught.  Put back what the GMTITLE steps
  ;; change for a while, and say clearly that the run stopped.
  (defun *error* (msg)
    (vl-catch-all-apply 'swcad-title-recover-after-caught-error nil)
    (if *swcad-title-debug-log-handle*
      (vl-catch-all-apply 'swcad-title-close-log nil)
    )
    (if *swapp-collect-log-handle*
      (vl-catch-all-apply 'swapp-collect-log-close nil)
    )
    (if *swapp-swfmt-log-handle*
      (vl-catch-all-apply 'swapp-swfmt-log-close nil)
    )
    (if *swapp-read-cache-enabled*
      (vl-catch-all-apply 'swapp-read-cache-end nil)
    )
    (setq *swapp-command-performance-active* nil)
    (if (equal stage "TITLE")
      (setq *swcad-title-last-apply-status* "ERROR_SWCADRUN_INTERRUPTED")
    )
    (princ (strcat "\nSWCADRUN 중단: " (if msg msg "")))
    (princ "\n진행 중지: 현재 도면을 저장하지 말고 원인을 확인하세요. SWCADRUN을 반복하지 마세요.")
    (princ)
  )
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
      (if (member stage '("COLLECT" "XREF" "SHEET_WRAPPERS" "SHEET_FORMAT" "TITLE" "DIMSTYLE" "CLEANUP" "LAYOUT")) T nil)
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
    ((equal stage "COLLECT") (setq run-result (swapp-collect-xrefs)))
    ((equal stage "XREF") (setq run-result (swapp-materialize-xrefs)))
    ((equal stage "SHEET_WRAPPERS") (setq run-result (swapp-materialize-sheet-wrappers)))
    ((equal stage "SHEET_FORMAT") (setq run-result (swapp-convert-sheet-formats)))
    ((equal stage "TITLE") (setq run-result (swapp-run-title-next)))
    ((equal stage "DIMSTYLE") (setq run-result (swapp-run-dimstyle)))
    ((equal stage "CLEANUP") (setq run-result (swapp-run-resource-cleanup)))
    ((equal stage "LAYOUT") (setq run-result (swapp-run-layout)))
    ((equal stage "COMPLETE") (princ "\n모든 단계가 준비됐습니다. SWCADVERIFY를 실행하세요."))
    (T
      (princ "\n처리할 도면틀/XREF를 찾지 못했습니다. 새 호스트 도면의 XREF 상태를 확인하세요.")
      (princ "\n빈 새 도면에서 SWCADRUN을 실행하면 DWG를 골라 XREF로 자동 배치합니다.")
    )
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
