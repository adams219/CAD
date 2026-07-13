;;; SWCAD Workflow MVP orchestrator.
;;; The production modules remain the owners of GMTITLE, DIMSTYLE, and LAYOUT.

(vl-load-com)

(setq *swapp-version* "260713-manual-placement-layout-2")
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
  (foreach object (swapp-collection-items (swapp-model))
    (if (swapp-block-reference-p object)
      (progn
        (setq name (swapp-reference-name object))
        (setq block (swapp-block-definition name))
        (if (swapp-xref-definition-p block)
          (setq result (cons object result))
        )
      )
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

(defun swapp-target-reference-name-p (name / upper)
  (setq upper (if name (strcase name) ""))
  (or
    (vl-string-search "DR_TITLEA_3RD" upper)
    (vl-string-search "DR_A1_OUTLINE" upper)
    (vl-string-search "DR_A2_OUTLINE" upper)
    (vl-string-search "DR_A3_OUTLINE" upper)
    (vl-string-search "DR_A4_OUTLINE" upper)
  )
)

(setq *swapp-scan-visited* nil)
(setq *swapp-scan-dimensions* 0)
(setq *swapp-scan-target-references* 0)

(defun swapp-scan-object (object stack / block-name upper block child)
  (if (swapp-dimension-p object)
    (setq *swapp-scan-dimensions* (1+ *swapp-scan-dimensions*))
  )
  (if (swapp-block-reference-p object)
    (progn
      (setq block-name (swapp-reference-name object))
      (setq upper (if block-name (strcase block-name) ""))
      (if (swapp-target-reference-name-p block-name)
        (setq *swapp-scan-target-references* (1+ *swapp-scan-target-references*))
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
            (foreach child (swapp-collection-items block)
              (swapp-scan-object child (cons upper stack))
            )
          )
        )
      )
    )
  )
)

(defun swapp-xref-deep-evidence (references / reference)
  (setq *swapp-scan-dimensions* 0)
  (setq *swapp-scan-target-references* 0)
  (foreach reference references
    (setq *swapp-scan-visited* nil)
    (swapp-scan-object reference nil)
  )
  (list
    (cons "dimensions" *swapp-scan-dimensions*)
    (cons "target-references" *swapp-scan-target-references*)
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

(defun swapp-materialize-xrefs (/ references unique-names xref-definition-count evidence expected-dimensions native-targets transforms-ok reference name block bind-result explode-count one-count before-bbox after-bbox after-xrefs after-dimensions summary source-titles source-frames success)
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
      (cond
        ((/= xref-definition-count (length unique-names))
          (princ "\n결과: BLOCKED_NESTED_OR_UNREFERENCED_XREF")
          (princ "\n중첩 또는 최상위에 연결되지 않은 XREF가 있어 자동 결합하지 않습니다.")
          nil
        )
        ((> native-targets 0)
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
          (setq after-xrefs (swapp-xref-definition-count))
          (setq after-dimensions (swapp-top-dimension-count))
          (setq after-bbox (swapp-model-bbox))
          (setq summary (swcad-title-fast-sheet-summary))
          (setq source-titles (swcad-title-fast-summary-value summary "source-title-count"))
          (setq source-frames (swcad-title-fast-summary-value summary "source-frame-count"))
          (setq success
            (and
              success
              (= after-xrefs 0)
              (= after-dimensions expected-dimensions)
              (swapp-bbox-near-p before-bbox after-bbox)
              (> source-frames 0)
            )
          )
          (princ (strcat "\n분해된 최상위 객체: " (itoa explode-count)))
          (princ (strcat "\n변환 후 XREF 정의: " (itoa after-xrefs)))
          (princ (strcat "\n변환 후 최상위 치수: " (itoa after-dimensions)))
          (princ (strcat "\n변환 후 원본 표제란/도면틀: " (itoa source-titles) " / " (itoa source-frames)))
          (if success
            (progn
              (swapp-state-set "MATERIALIZED" "OK")
              (swapp-state-set "XREF_COUNT" (itoa (length references)))
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

(defun swapp-title-evidence (/ summary sources frames titles pairs native-like record geometry overlap)
  (setq summary (swcad-title-fast-sheet-summary))
  (setq sources
    (+
      (swcad-title-fast-summary-value summary "source-title-count")
      (swcad-title-fast-summary-value summary "source-frame-count")
    )
  )
  (setq frames (swcad-title-frame-records))
  (setq titles (swcad-title-inserts-by-effective-name (swcad-title-target-title-block-name)))
  (setq pairs (swcad-title-target-gmtitle-pair-records))
  (setq native-like 0)
  (foreach record pairs
    (if (swcad-title-target-pair-native-like-p record)
      (setq native-like (1+ native-like))
    )
  )
  (setq geometry (swcad-title-target-frame-geometry-warning-count frames))
  (setq overlap (swcad-title-target-frame-overlap-warning-count frames))
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

(defun swapp-workflow-stage (/ xrefs evidence frames)
  (swapp-activate-model)
  (setq xrefs (swapp-top-xref-references))
  (cond
    (xrefs "XREF")
    (T
      (setq evidence (swapp-title-evidence))
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
  (foreach object (swapp-collection-items (swapp-model))
    (if (swapp-dimension-p object)
      (progn
        (setq record (swapp-dim-semantic-record object))
        (if record (setq result (cons record result)))
      )
    )
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
  (foreach object (swapp-collection-items (swapp-model))
    (if (swapp-dimension-p object)
      (progn
        (setq snapshot (swapp-dim-semantic-snapshot object))
        (if snapshot (setq result (cons snapshot result)))
      )
    )
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

(defun swapp-print-status (/ stage references evidence frames layouts state plan)
  (swapp-activate-model)
  (setq stage (swapp-workflow-stage))
  (setq references (swapp-top-xref-references))
  (setq evidence (swapp-title-evidence))
  (setq frames (swapp-evidence-value evidence "target-frame-count"))
  (setq layouts (swapp-with-layout-prefix-names))
  (setq state (swapp-state-read))
  (princ "\n===== SWCADSTATUS 통합 작업 상태 =====")
  (princ (strcat "\nSWCAD Workflow 버전: " *swapp-version*))
  (princ (strcat "\nDWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (princ (strcat "\n현재 단계: " stage))
  (princ (strcat "\n최상위 XREF: " (itoa (length references))))
  (princ "\nXREF 배치 정책: 사용자가 정한 좌표 유지, 자동 이동 없음")
  (princ (strcat "\n최상위 치수: " (itoa (swapp-top-dimension-count))))
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
  (princ (strcat "\n권장 다음 명령: " (if (equal stage "COMPLETE") "SWCADVERIFY" "SWCADRUN")))
  stage
)

(defun swapp-run-title-next (/ action)
  (swapp-activate-model)
  (setq action (swcad-title-integrated-structure-diagnosis))
  (princ (strcat "\nSWCAD가 선택한 GMTITLE 단계: " action))
  (cond
    ((swcad-title-string-prefix-p "SWTITLEPREPARE" action) (c:SWTITLEPREPARE))
    ((swcad-title-string-prefix-p "SWTITLECONVERTNEXT" action) (c:SWTITLECONVERTNEXT))
    ((swcad-title-string-prefix-p "SWTITLEVERIFY" action) (c:SWTITLEVERIFY))
    (T (princ "\nGMTITLE 다음 단계를 안전하게 결정하지 못했습니다. SWTITLESTATUS 로그를 확인하세요."))
  )
  (princ "\n다음: SWCADSTATUS로 결과를 확인한 뒤 SWCADRUN을 다시 실행하세요.")
)

(defun c:SWCADSTATUS ()
  (swapp-print-status)
  (princ)
)

(defun c:SWCADRUN (/ stage)
  (setq stage (swapp-workflow-stage))
  (princ "\n===== SWCADRUN 다음 안전 단계 실행 =====")
  (princ (strcat "\n현재 단계: " stage))
  (cond
    ((equal stage "XREF") (swapp-materialize-xrefs))
    ((equal stage "TITLE") (swapp-run-title-next))
    ((equal stage "DIMSTYLE") (swapp-run-dimstyle))
    ((equal stage "LAYOUT") (swapp-run-layout))
    ((equal stage "COMPLETE") (princ "\n모든 단계가 준비됐습니다. SWCADVERIFY를 실행하세요."))
    (T (princ "\n처리할 도면틀/XREF를 찾지 못했습니다. 새 호스트 도면의 XREF 상태를 확인하세요."))
  )
  (princ "\n")
  (swapp-print-status)
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

(defun c:SWCADVERIFY (/ xrefs title-status dim-ok frames layout-ok final-ok)
  (swapp-activate-model)
  (princ "\n===== SWCADVERIFY 통합 최종 검증 =====")
  (setq xrefs (length (swapp-top-xref-references)))
  (setq title-status (swcad-title-integrated-verify-final-summary))
  (setq dim-ok (swapp-dimstyle-verify))
  (setq frames (length (swcad-title-frame-records)))
  (setq layout-ok (swapp-layout-state-valid-p frames))
  (setq final-ok (and (= xrefs 0) (equal title-status "OK") dim-ok (> frames 0) layout-ok))
  (princ (strcat "\n남은 XREF: " (itoa xrefs)))
  (princ (strcat "\nGMTITLE 최종 상태: " title-status))
  (princ (strcat "\nDIMSTYLE 감사: " (if dim-ok "OK" "CHECK_NEEDED")))
  (princ (strcat "\nLayout 좌표 모드: " (if (swapp-state-value "LAYOUT_PLACEMENT_MODE") (swapp-state-value "LAYOUT_PLACEMENT_MODE") "<없음>")))
  (princ (strcat "\nLayout 좌표 계획 수: " (if (swapp-state-value "LAYOUT_PLAN_COUNT") (swapp-state-value "LAYOUT_PLAN_COUNT") "<없음>")))
  (princ (strcat "\nLayout 좌표 지문: " (if (swapp-state-value "LAYOUT_PLAN_SIGNATURE") (swapp-state-value "LAYOUT_PLAN_SIGNATURE") "<없음>")))
  (princ (strcat "\nA4 Layout 검증: " (if layout-ok "OK" "CHECK_NEEDED") " (" (itoa frames) "장)"))
  (princ (strcat "\n최종 결과: " (if final-ok "SWCADVERIFY_FINAL_OK" "SWCADVERIFY_FINAL_FAIL")))
  (princ)
)

(princ (strcat "\nSWCAD Workflow loaded " *swapp-version*))
(princ "\nCommands: SWCADSTATUS, SWCADRUN, SWCADVERIFY")
(princ)
