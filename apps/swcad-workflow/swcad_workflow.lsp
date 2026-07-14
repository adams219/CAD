;;; SWCAD Workflow MVP orchestrator.
;;; The production modules remain the owners of GMTITLE, DIMSTYLE, and LAYOUT.

(vl-load-com)

(setq *swapp-version* "260714-command-inventory-performance-3")
(setq *swapp-state-dictionary-key* "SWCAD_WORKFLOW_STATE")
(setq *swapp-layout-prefix* "SWCAD-SHEET")
(setq *swapp-layout-placement-mode* "MANUAL_FRAME_COORDINATES")
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
  (swapp-read-cache-fetch "LAYOUT_NAMES" 'swapp-with-layout-prefix-names nil)
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

(defun swapp-materialize-xrefs (/ references unique-names xref-definition-count evidence expected-dimensions native-targets native-target-frames native-target-titles transforms-ok reference name block bind-result explode-count one-count wrapper-records wrapper-count wrapper-explode-count dimension-result dimension-exposed dimension-rounds after-wrapper-count before-bbox after-bbox after-xrefs after-dimensions summary source-titles source-frames success)
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
      (cond
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

(defun swapp-layout-plan ()
  (gsla-sort-windows (swapp-frame-windows))
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
    (setq win (cdr item))
    (setq ll (car win))
    (setq ur (cadr win))
    (setq result
      (strcat
        result
        "|" (swapp-layout-signature-coordinate-text (car ll))
        "," (swapp-layout-signature-coordinate-text (cadr ll))
        "," (swapp-layout-signature-coordinate-text (car ur))
        "," (swapp-layout-signature-coordinate-text (cadr ur))
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
  (setq win (cdr item))
  (setq ll (car win))
  (setq ur (cadr win))
  (strcat
    "#" (if (< index 100) "0" "") (if (< index 10) "0" "") (itoa index)
    " frame=" (swapp-layout-plan-item-handle item)
    " LL=(" (swapp-layout-coordinate-text (car ll)) ", " (swapp-layout-coordinate-text (cadr ll)) ")"
    " UR=(" (swapp-layout-coordinate-text (car ur)) ", " (swapp-layout-coordinate-text (cadr ur)) ")"
    " size=" (swapp-layout-coordinate-text (gsla-window-width win)) " x " (swapp-layout-coordinate-text (gsla-window-height win))
  )
)

(defun swapp-print-layout-plan-items (plan limit / total index item)
  (setq total (length plan))
  (princ "\n----- SWCAD Layout 좌표 계획 -----")
  (princ "\n배치 방식: 사용자가 배치한 최종 GMTITLE 도면틀 좌표 유지")
  (princ "\n정렬 순서: 같은 행은 왼쪽→오른쪽, 다른 행은 위쪽→아래쪽")
  (princ (strcat "\n예정 Layout 수: " (itoa total)))
  (setq index 1)
  (foreach item plan
    (if (<= index limit)
      (princ (strcat "\n  " (swapp-layout-plan-item-text item index)))
    )
    (setq index (1+ index))
  )
  (if (> total limit)
    (princ (strcat "\n  ... 나머지 " (itoa (- total limit)) "개 좌표는 생성 시 같은 규칙으로 사용합니다."))
  )
  plan
)

(defun swapp-with-layout-prefix-names (/ old names)
  (setq old *gsla-prefix*)
  (setq *gsla-prefix* *swapp-layout-prefix*)
  (setq names (gsla-generated-layout-names))
  (setq *gsla-prefix* old)
  names
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

(defun swapp-layouts-valid-p (expected / names layouts name layout paper viewports ok)
  (setq names (swapp-with-layout-prefix-names))
  (setq layouts (vla-get-Layouts (swapp-doc)))
  (setq ok (= (length names) expected))
  (foreach name names
    (setq layout (swapp-safe 'vla-Item (list layouts name)))
    (setq paper (if layout (gsla-layout-paper-size layout) nil))
    (setq viewports (gsla-viewport-entities-for-layout name))
    (if (or (not layout) (not (swapp-layout-paper-a4-p paper)) (/= (length viewports) 1))
      (setq ok nil)
    )
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
    (swapp-layouts-valid-p expected)
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
  (reverse result)
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

(defun swapp-delete-app-layouts (/ names layouts model-layout name layout count)
  (setq names (swapp-with-layout-prefix-names))
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

(defun swapp-run-layout (/ windows expected old-prefix result)
  (swapp-activate-model)
  (if (not (swcad-title-ensure-work-copy-for-mutation))
    (progn
      (princ "\nLayout 생성 중단: 작업본을 만들지 않았습니다.")
      nil
    )
    (progn
      (setq windows (swapp-layout-plan))
      (setq expected (length windows))
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
          (swapp-print-layout-plan-items windows *swapp-layout-preview-limit*)
          (swapp-delete-app-layouts)
          (setq old-prefix *gsla-prefix*)
          (setq *gsla-prefix* *swapp-layout-prefix*)
          (gsla-create-layouts windows)
          (setq *gsla-prefix* old-prefix)
          (swapp-activate-model)
          (setq result (swapp-layouts-valid-p expected))
          (if result
            (progn
              (swapp-state-set "LAYOUT" "OK")
              (swapp-state-set "LAYOUT_PLACEMENT_MODE" *swapp-layout-placement-mode*)
              (swapp-state-set "LAYOUT_PLAN_COUNT" (itoa expected))
              (swapp-state-set "LAYOUT_PLAN_SIGNATURE" (swapp-layout-plan-signature windows))
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
    ((equal stage "XREF") "1/5 입력 도면 준비 - XREF 분해")
    ((equal stage "SHEET_WRAPPERS") "1/5 입력 도면 준비 - 시트 묶음 분해")
    ((equal stage "TITLE") "2/5 GMTITLE 변환")
    ((equal stage "DIMSTYLE") "3/5 치수 스타일 통일")
    ((equal stage "LAYOUT") "4/5 Layout 생성")
    ((equal stage "COMPLETE") "5/5 최종 검증 준비 완료")
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
    (T "SWCADRUN")
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
  (princ (strcat "\nSWCAD Layout: " (itoa (length layouts)) " / 기대 " (itoa frames)))
  (princ (strcat "\nLayout 좌표 모드: " (if (swapp-state-value "LAYOUT_PLACEMENT_MODE") (swapp-state-value "LAYOUT_PLACEMENT_MODE") "미생성")))
  (if (member stage '("DIMSTYLE" "LAYOUT" "COMPLETE"))
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

(defun c:SWCADRUN (/ stage after-stage run-result mutating-stage)
  (swapp-command-performance-begin)
  (swapp-read-cache-begin)
  (setq stage (swapp-workflow-stage))
  (setq mutating-stage (if (member stage '("XREF" "SHEET_WRAPPERS" "TITLE" "DIMSTYLE" "LAYOUT")) T nil))
  (princ "\n===== SWCADRUN 다음 안전 단계 실행 =====")
  (princ (strcat "\n실행 전 단계: " (swapp-stage-label stage) " [" stage "]"))
  (setq run-result nil)
  (if mutating-stage (swapp-read-cache-end))
  (cond
    ((equal stage "XREF") (setq run-result (swapp-materialize-xrefs)))
    ((equal stage "SHEET_WRAPPERS") (setq run-result (swapp-materialize-sheet-wrappers)))
    ((equal stage "TITLE") (setq run-result (swapp-run-title-next)))
    ((equal stage "DIMSTYLE") (setq run-result (swapp-run-dimstyle)))
    ((equal stage "LAYOUT") (setq run-result (swapp-run-layout)))
    ((equal stage "COMPLETE") (princ "\n모든 단계가 준비됐습니다. SWCADVERIFY를 실행하세요."))
    (T (princ "\n처리할 도면틀/XREF를 찾지 못했습니다. 새 호스트 도면의 XREF 상태를 확인하세요."))
  )
  (if mutating-stage (swapp-read-cache-begin))
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

(defun c:SWCADVERIFY (/ xrefs wrappers title-result title-status dim-ok frames layout-ok final-ok old-legacy-compat legacy-compat-enabled)
  (swapp-command-performance-begin)
  (swapp-read-cache-begin)
  (swapp-activate-model)
  (princ "\n===== SWCADVERIFY 통합 최종 검증 =====")
  (setq xrefs (length (swapp-cached-top-xref-references)))
  (setq wrappers (length (swapp-sheet-wrapper-records)))
  (setq dim-ok (swapp-dimstyle-verify))
  (setq frames (length (swcad-title-frame-records)))
  (setq layout-ok (swapp-layout-state-valid-p frames))
  (setq legacy-compat-enabled
    (and
      (= xrefs 0)
      (= wrappers 0)
      dim-ok
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
  (setq final-ok (and (= xrefs 0) (= wrappers 0) (equal title-status "OK") dim-ok (> frames 0) layout-ok))
  (princ (strcat "\n남은 XREF: " (itoa xrefs)))
  (princ (strcat "\n남은 중첩 시트 묶음: " (itoa wrappers)))
  (princ (strcat "\nGMTITLE 최종 상태: " title-status))
  (princ (strcat "\nDIMSTYLE 감사: " (if dim-ok "OK" "CHECK_NEEDED")))
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
