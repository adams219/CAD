;;; XREF materialization comparison probe for the SWCAD Workflow MVP.
;;; Environment variables:
;;;   SWCAD_WORKFLOW_ROOT
;;;   SWCAD_XREF_MODE       BASELINE / ATTACHED / BOUND / EXPLODED
;;;   SWCAD_XREF_SOURCE
;;;   SWCAD_XREF_OUTPUT
;;;   SWCAD_XREF_LOG
;;; The probe is run only against a source opened read-only or a disposable host.

(vl-load-com)

(defun swapp-xref-env (name fallback / value)
  (setq value (getenv name))
  (if (or (not value) (= value "")) fallback value)
)

(defun swapp-xref-root ()
  (vl-string-translate
    "\\"
    "/"
    (swapp-xref-env "SWCAD_WORKFLOW_ROOT" "C:/Users/DR-DESIGN/Documents/CAD tool")
  )
)

(defun swapp-xref-path (relative)
  (strcat (swapp-xref-root) "/" relative)
)

(defun swapp-xref-safe (fn args / result)
  (setq result (vl-catch-all-apply fn args))
  (if (vl-catch-all-error-p result) nil result)
)

(defun swapp-xref-write (handle text)
  (write-line (if text text "") handle)
)

(defun swapp-xref-bool (value)
  (if value "yes" "no")
)

(defun swapp-xref-number (value)
  (cond
    ((numberp value) (rtos (float value) 2 8))
    (T "0.00000000")
  )
)

(defun swapp-xref-object-name (object)
  (swapp-xref-safe 'vla-get-ObjectName (list object))
)

(defun swapp-xref-dimension-p (object / name)
  (setq name (swapp-xref-object-name object))
  (if (and name (vl-string-search "DIMENSION" (strcase name))) T nil)
)

(defun swapp-xref-block-reference-p (object / name)
  (setq name (swapp-xref-object-name object))
  (if (and name (vl-string-search "BLOCKREFERENCE" (strcase name))) T nil)
)

(defun swapp-xref-collection-items (collection / count index item result)
  (setq result nil)
  (setq count (swapp-xref-safe 'vla-get-Count (list collection)))
  (if (numberp count)
    (progn
      (setq index 0)
      (while (< index count)
        (setq item (swapp-xref-safe 'vla-Item (list collection index)))
        (if item (setq result (cons item result)))
        (setq index (1+ index))
      )
    )
  )
  (reverse result)
)

(defun swapp-xref-block-name (reference / name)
  (setq name (swapp-xref-safe 'vla-get-Name (list reference)))
  (if name
    name
    (swapp-xref-safe 'vla-get-EffectiveName (list reference))
  )
)

(defun swapp-xref-block-definition (name / doc blocks)
  (if name
    (progn
      (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
      (setq blocks (vla-get-Blocks doc))
      (swapp-xref-safe 'vla-Item (list blocks name))
    )
    nil
  )
)

(defun swapp-xref-dimension-record (object / ename data values raw dimlfac upper lower dimtol dimlim text entity-type)
  (setq ename (swapp-xref-safe 'vlax-vla-object->ename (list object)))
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
      (setq text (cdr (assoc 1 data)))
      (setq entity-type (cdr (assoc 0 data)))
      (strcat
        (if entity-type entity-type "DIMENSION") "|"
        (swapp-xref-number raw) "|"
        (swapp-xref-number dimlfac) "|"
        (swapp-xref-number upper) "|"
        (swapp-xref-number lower) "|"
        (itoa (if (numberp dimtol) dimtol 0)) "|"
        (itoa (if (numberp dimlim) dimlim 0)) "|"
        (if text text "")
      )
    )
    nil
  )
)

(setq *swapp-xref-deep-entity-count* 0)
(setq *swapp-xref-deep-dimension-count* 0)
(setq *swapp-xref-dimension-records* nil)
(setq *swapp-xref-visited-blocks* nil)
(setq *swapp-xref-deep-target-reference-count* 0)

(defun swapp-xref-target-reference-name-p (name / upper)
  (if name (setq upper (strcase name)) (setq upper ""))
  (or
    (vl-string-search "DR_TITLEA_3RD" upper)
    (vl-string-search "DR_A1_OUTLINE" upper)
    (vl-string-search "DR_A2_OUTLINE" upper)
    (vl-string-search "DR_A3_OUTLINE" upper)
    (vl-string-search "DR_A4_OUTLINE" upper)
  )
)

(defun swapp-xref-walk-object (object stack / record block-name block-definition child)
  (setq *swapp-xref-deep-entity-count* (1+ *swapp-xref-deep-entity-count*))
  (if (swapp-xref-dimension-p object)
    (progn
      (setq *swapp-xref-deep-dimension-count* (1+ *swapp-xref-deep-dimension-count*))
      (setq record (swapp-xref-dimension-record object))
      (if record
        (setq *swapp-xref-dimension-records* (cons record *swapp-xref-dimension-records*))
      )
    )
  )
  (if (swapp-xref-block-reference-p object)
    (progn
      (setq block-name (swapp-xref-block-name object))
      (if (swapp-xref-target-reference-name-p block-name)
        (setq *swapp-xref-deep-target-reference-count*
          (1+ *swapp-xref-deep-target-reference-count*)
        )
      )
      (if
        (and
          block-name
          (not (member (strcase block-name) stack))
          (not (member (strcase block-name) *swapp-xref-visited-blocks*))
        )
        (progn
          (setq *swapp-xref-visited-blocks*
            (cons (strcase block-name) *swapp-xref-visited-blocks*)
          )
          (setq block-definition (swapp-xref-block-definition block-name))
          (if block-definition
            (foreach child (swapp-xref-collection-items block-definition)
              (swapp-xref-walk-object child (cons (strcase block-name) stack))
            )
          )
        )
      )
    )
  )
)

(defun swapp-xref-model-analysis (/ doc model object top-total top-dim top-insert)
  (setq *swapp-xref-deep-entity-count* 0)
  (setq *swapp-xref-deep-dimension-count* 0)
  (setq *swapp-xref-dimension-records* nil)
  (setq *swapp-xref-visited-blocks* nil)
  (setq *swapp-xref-deep-target-reference-count* 0)
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
  (setq model (vla-get-ModelSpace doc))
  (setq top-total 0)
  (setq top-dim 0)
  (setq top-insert 0)
  (foreach object (swapp-xref-collection-items model)
    (setq top-total (1+ top-total))
    (if (swapp-xref-dimension-p object) (setq top-dim (1+ top-dim)))
    (if (swapp-xref-block-reference-p object) (setq top-insert (1+ top-insert)))
    (swapp-xref-walk-object object nil)
  )
  (list
    (cons "top-entity-count" top-total)
    (cons "top-dimension-count" top-dim)
    (cons "top-insert-count" top-insert)
    (cons "deep-entity-count" *swapp-xref-deep-entity-count*)
    (cons "deep-dimension-count" *swapp-xref-deep-dimension-count*)
    (cons "deep-target-reference-count" *swapp-xref-deep-target-reference-count*)
    (cons "dimension-records" *swapp-xref-dimension-records*)
  )
)

(defun swapp-xref-analysis-value (analysis key)
  (cdr (assoc key analysis))
)

(defun swapp-xref-xref-count (/ doc blocks block count value)
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
  (setq blocks (vla-get-Blocks doc))
  (setq count 0)
  (foreach block (swapp-xref-collection-items blocks)
    (setq value (swapp-xref-safe 'vla-get-IsXRef (list block)))
    (if (= value :vlax-true) (setq count (1+ count)))
  )
  count
)

(defun swapp-xref-model-bbox (/ doc model object result mn mx low high pmin pmax)
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
  (setq model (vla-get-ModelSpace doc))
  (setq low nil)
  (setq high nil)
  (foreach object (swapp-xref-collection-items model)
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

(defun swapp-xref-bbox-text (bbox)
  (if bbox
    (strcat
      (swapp-xref-number (car (car bbox))) ","
      (swapp-xref-number (cadr (car bbox))) "|"
      (swapp-xref-number (car (cadr bbox))) ","
      (swapp-xref-number (cadr (cadr bbox)))
    )
    "<none>"
  )
)

(defun swapp-xref-bbox-size-text (bbox)
  (if bbox
    (strcat
      (swapp-xref-number (- (car (cadr bbox)) (car (car bbox)))) "x"
      (swapp-xref-number (- (cadr (cadr bbox)) (cadr (car bbox))))
    )
    "<none>"
  )
)

(defun swapp-xref-attach (source / doc model result)
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
  (setq model (vla-get-ModelSpace doc))
  (setq result
    (vl-catch-all-apply
      'vla-AttachExternalReference
      (list
        model
        source
        "SWCAD_XREF_PROBE"
        (vlax-3d-point '(1000.0 2000.0 0.0))
        1.0 1.0 1.0 0.0
        :vlax-false
      )
    )
  )
  (if (vl-catch-all-error-p result) nil result)
)

(defun swapp-xref-bind (reference / name block result)
  (setq name (swapp-xref-block-name reference))
  (setq block (swapp-xref-block-definition name))
  (if block
    (progn
      (setq result (vl-catch-all-apply 'vla-Bind (list block :vlax-false)))
      (if (vl-catch-all-error-p result) nil T)
    )
    nil
  )
)

(defun swapp-xref-variant-list (value / raw)
  (cond
    ((null value) nil)
    ((= (type value) 'VARIANT) (swapp-xref-variant-list (vlax-variant-value value)))
    ((= (type value) 'SAFEARRAY) (vlax-safearray->list value))
    ((listp value) value)
    (T nil)
  )
)

(defun swapp-xref-explode-one (reference / result objects deleted)
  (setq result (vl-catch-all-apply 'vla-Explode (list reference)))
  (if (vl-catch-all-error-p result)
    nil
    (progn
      (setq objects (swapp-xref-variant-list result))
      (setq deleted (vl-catch-all-apply 'vla-Delete (list reference)))
      (if (and objects (not (vl-catch-all-error-p deleted))) (length objects) nil)
    )
  )
)

(defun swapp-xref-title-summary ()
  (swcad-title-fast-sheet-summary)
)

(defun swapp-xref-title-value (summary key)
  (if summary (swcad-title-fast-summary-value summary key) -1)
)

(defun swapp-xref-target-evidence (/ titles frames pairs native-like record)
  (setq titles (swcad-title-inserts-by-effective-name (swcad-title-target-title-block-name)))
  (setq frames (swcad-title-frame-records))
  (setq pairs (swcad-title-target-gmtitle-pair-records))
  (setq native-like 0)
  (foreach record pairs
    (if (swcad-title-target-pair-native-like-p record)
      (setq native-like (1+ native-like))
    )
  )
  (list
    (cons "target-title-count" (length titles))
    (cons "target-frame-count" (length frames))
    (cons "target-pair-count" (length pairs))
    (cons "native-like-pair-count" native-like)
  )
)

(defun swapp-xref-evidence-value (evidence key)
  (cdr (assoc key evidence))
)

(defun swapp-xref-save-output (path / doc result)
  (if (or (not path) (= path ""))
    nil
    (progn
      (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
      (setq result (vl-catch-all-apply 'vla-SaveAs (list doc path)))
      (if (vl-catch-all-error-p result) nil T)
    )
  )
)

(defun swapp-xref-main (/ mode source output log-path handle title-load dim-load reference attach-ok bind-ok explode-count analysis bbox summary target-evidence records save-ok pass)
  (setq mode (strcase (swapp-xref-env "SWCAD_XREF_MODE" "BASELINE")))
  (setq source (vl-string-translate "\\" "/" (swapp-xref-env "SWCAD_XREF_SOURCE" "")))
  (setq output (vl-string-translate "\\" "/" (swapp-xref-env "SWCAD_XREF_OUTPUT" "")))
  (setq log-path (vl-string-translate "\\" "/" (swapp-xref-env "SWCAD_XREF_LOG" (swapp-xref-path "work/swcad_xref_materialize_probe.txt"))))
  (setq handle (open log-path "w"))
  (if handle
    (progn
      (swapp-xref-write handle "SWCAD XREF materialization probe")
      (swapp-xref-write handle (strcat "Mode: " mode))
      (swapp-xref-write handle (strcat "DWG before: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
      (setq title-load (vl-catch-all-apply 'load (list (swapp-xref-path "src/tools/gmtitle/swcad_title_scale.lsp"))))
      (setq dim-load (vl-catch-all-apply 'load (list (swapp-xref-path "src/tools/gstarcad-dimstyle/gstarcad_dimstyle_keep_tolerance.lsp"))))
      (swapp-xref-write handle (strcat "GMTITLE load: " (if (vl-catch-all-error-p title-load) "error" "ok")))
      (swapp-xref-write handle (strcat "DIMSTYLE load: " (if (vl-catch-all-error-p dim-load) "error" "ok")))
      (setq attach-ok T)
      (setq bind-ok T)
      (setq explode-count 0)
      (if (/= mode "BASELINE")
        (progn
          (setq reference (swapp-xref-attach source))
          (setq attach-ok (if reference T nil))
          (if (and reference (member mode '("BOUND" "EXPLODED")))
            (setq bind-ok (swapp-xref-bind reference))
          )
          (if (and reference bind-ok (= mode "EXPLODED"))
            (setq explode-count (swapp-xref-explode-one reference))
          )
          (vla-Regen (vla-get-ActiveDocument (vlax-get-acad-object)) 1)
        )
      )
      (setq analysis (swapp-xref-model-analysis))
      (setq bbox (swapp-xref-model-bbox))
      (setq summary (swapp-xref-title-summary))
      (setq target-evidence (swapp-xref-target-evidence))
      (swapp-xref-write handle (strcat "Attach result: " (swapp-xref-bool attach-ok)))
      (swapp-xref-write handle (strcat "Bind result: " (swapp-xref-bool bind-ok)))
      (swapp-xref-write handle (strcat "Exploded object count: " (itoa (if (numberp explode-count) explode-count 0))))
      (swapp-xref-write handle (strcat "XREF definition count: " (itoa (swapp-xref-xref-count))))
      (swapp-xref-write handle (strcat "Top entity count: " (itoa (swapp-xref-analysis-value analysis "top-entity-count"))))
      (swapp-xref-write handle (strcat "Top dimension count: " (itoa (swapp-xref-analysis-value analysis "top-dimension-count"))))
      (swapp-xref-write handle (strcat "Top insert count: " (itoa (swapp-xref-analysis-value analysis "top-insert-count"))))
      (swapp-xref-write handle (strcat "Deep entity count: " (itoa (swapp-xref-analysis-value analysis "deep-entity-count"))))
      (swapp-xref-write handle (strcat "Deep dimension count: " (itoa (swapp-xref-analysis-value analysis "deep-dimension-count"))))
      (swapp-xref-write handle (strcat "Deep target reference count: " (itoa (swapp-xref-analysis-value analysis "deep-target-reference-count"))))
      (swapp-xref-write handle (strcat "Model bbox: " (swapp-xref-bbox-text bbox)))
      (swapp-xref-write handle (strcat "Model bbox size: " (swapp-xref-bbox-size-text bbox)))
      (swapp-xref-write handle (strcat "Title source count: " (itoa (swapp-xref-title-value summary "source-title-count"))))
      (swapp-xref-write handle (strcat "Frame source count: " (itoa (swapp-xref-title-value summary "source-frame-count"))))
      (swapp-xref-write handle (strcat "Frame-only source count: " (itoa (swapp-xref-title-value summary "frame-only-count"))))
      (swapp-xref-write handle (strcat "Target title count: " (itoa (swapp-xref-evidence-value target-evidence "target-title-count"))))
      (swapp-xref-write handle (strcat "Target frame count: " (itoa (swapp-xref-evidence-value target-evidence "target-frame-count"))))
      (swapp-xref-write handle (strcat "Target pair count: " (itoa (swapp-xref-evidence-value target-evidence "target-pair-count"))))
      (swapp-xref-write handle (strcat "Native-like pair count: " (itoa (swapp-xref-evidence-value target-evidence "native-like-pair-count"))))
      (setq records (swapp-xref-analysis-value analysis "dimension-records"))
      (foreach record records
        (swapp-xref-write handle (strcat "DIMREC:" record))
      )
      (setq save-ok (if (= mode "BASELINE") T (swapp-xref-save-output output)))
      (swapp-xref-write handle (strcat "Save output: " (swapp-xref-bool save-ok)))
      (swapp-xref-write handle (strcat "DWG after: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
      (swapp-xref-write handle (strcat "DBMOD after: " (itoa (getvar "DBMOD"))))
      (setq pass
        (and
          (not (vl-catch-all-error-p title-load))
          (not (vl-catch-all-error-p dim-load))
          attach-ok
          bind-ok
          save-ok
          (> (swapp-xref-analysis-value analysis "deep-entity-count") 0)
          (> (swapp-xref-analysis-value analysis "deep-dimension-count") 0)
          (or (/= mode "EXPLODED") (> (if (numberp explode-count) explode-count 0) 0))
        )
      )
      (swapp-xref-write handle (strcat "Runtime check completed: " (swapp-xref-bool pass)))
      (close handle)
    )
  )
  (princ)
)

(swapp-xref-main)
