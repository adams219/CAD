;;; Diagnostic probe: create 1/2/3 preserve-copy pairs from one A3 native pair.
;;; The PowerShell wrapper always runs this on a dedicated DWG copy under work.

(vl-load-com)

(setq *swtitle-pcm-active-log-handle* nil)

(defun swtitle-pcm-error-handler (msg)
  (if *swtitle-pcm-active-log-handle*
    (progn
      (write-line (strcat "Probe error: " (if msg msg "<nil>")) *swtitle-pcm-active-log-handle*)
      (write-line "Result: ERROR_PRESERVE_COPY_MATRIX_PROBE" *swtitle-pcm-active-log-handle*)
      (write-line "Runtime check completed: error" *swtitle-pcm-active-log-handle*)
      (close *swtitle-pcm-active-log-handle*)
      (setq *swtitle-pcm-active-log-handle* nil)
    )
  )
  (princ)
)

(defun *error* (msg)
  (swtitle-pcm-error-handler msg)
)

(defun swtitle-pcm-root (/ root)
  (setq root (getenv "SWCAD_TOOL_ROOT"))
  (if (or (not root) (= (strlen root) 0))
    (setq root "C:/Users/DR-DESIGN/Documents/CAD tool")
  )
  (vl-string-translate "\\" "/" root)
)

(defun swtitle-pcm-env-path (name fallback / value)
  (setq value (getenv name))
  (if (or (not value) (= (strlen value) 0))
    (setq value fallback)
  )
  (vl-string-translate "\\" "/" value)
)

(defun swtitle-pcm-copy-count (/ raw value)
  (setq raw (getenv "SWCAD_PRESERVE_COPY_COUNT"))
  (setq value (if raw (atoi raw) 0))
  (if (not (member value '(1 2 3)))
    (setq value 1)
  )
  value
)

(defun swtitle-pcm-write (handle value)
  (write-line (if value value "") handle)
)

(defun swtitle-pcm-dxf-values (data code / result pair)
  (setq result nil)
  (foreach pair data
    (if (and (listp pair) (= (car pair) code))
      (setq result (append result (list (cdr pair))))
    )
  )
  result
)

(defun swtitle-pcm-object-summary (ename / data object)
  (setq data (if ename (entget ename '("*")) nil))
  (setq object (if ename (swcad-title-safe-vla-object ename) nil))
  (list
    (cons "handle" (if ename (swcad-title-ename-handle ename) "<missing>"))
    (cons "owner" (swcad-title-string (swcad-title-dxf-value data 330)))
    (cons "object-name" (swcad-title-string (swcad-title-safe-vla-get object 'ObjectName)))
    (cons "object-id" (swcad-title-string (swcad-title-safe-vla-get object 'ObjectID)))
    (cons "owner-id" (swcad-title-string (swcad-title-safe-vla-get object 'OwnerID)))
    (cons "xdata-apps" (swcad-title-xdata-app-names ename))
    (cons "native-handles" (swcad-title-gmtitle-native-xdata-info ename))
    (cons "native-kinds" (swcad-title-native-link-target-kinds ename))
    (cons "reactor-values" (swtitle-pcm-dxf-values data -5))
    (cons "extension-dictionary-values" (swtitle-pcm-dxf-values data 360))
    (cons "xdata-records" (swcad-title-xdata-records ename))
    (cons "raw-entget" data)
  )
)

(defun swtitle-pcm-write-object (handle label ename / summary item)
  (swtitle-pcm-write handle (strcat "  " label ":"))
  (setq summary (swtitle-pcm-object-summary ename))
  (foreach item summary
    (swtitle-pcm-write
      handle
      (strcat
        "    "
        (car item)
        "="
        (vl-princ-to-string (cdr item))
      )
    )
  )
)

(defun swtitle-pcm-a3-native-pair (/ records result record)
  (setq records (swcad-title-target-gmtitle-pair-records))
  (setq result nil)
  (foreach record records
    (if
      (and
        (not result)
        (equal (strcase (swcad-title-string (caddr record))) "DR_A3_OUTLINE")
        (swcad-title-target-pair-native-like-p record)
      )
      (setq result record)
    )
  )
  result
)

(defun swtitle-pcm-copy-pair (pair destination-x copy-index / source-title source-frame frame-block source-title-bbox source-frame-bbox copied-title copied-frame copied-frame-bbox title-offset label)
  (setq source-title (car pair))
  (setq source-frame (cadr pair))
  (setq frame-block (caddr pair))
  (setq source-title-bbox (nth 3 pair))
  (setq source-frame-bbox (nth 4 pair))
  (setq copied-frame (swcad-title-copy-ename source-frame))
  (setq copied-title (if copied-frame (swcad-title-copy-ename source-title) nil))
  (if (and copied-title copied-frame)
    (progn
      (swcad-title-move-ename-bbox-min-to copied-frame destination-x (cadr source-frame-bbox))
      (setq copied-frame-bbox (swcad-title-safe-bbox copied-frame))
      (setq title-offset (swcad-title-title-frame-offset source-title-bbox source-frame-bbox))
      (swcad-title-move-ename-bbox-min-to
        copied-title
        (+ (car copied-frame-bbox) (car title-offset))
        (+ (cadr copied-frame-bbox) (cadr title-offset))
      )
      (setq label (strcat "PRESERVE_COPY_MATRIX_" (itoa copy-index)))
      (swcad-title-set-insert-attributes
        (swcad-title-safe-vla-object copied-title)
        (list
          (cons "GEN-TITLE-DWG{23}" label)
          (cons "GEN-TITLE-NR{23}" label)
          (cons "GEN-TITLE-SIZ{6.7}" "A3")
        )
      )
      ;; Keep this a pure preserve-copy experiment. Adding a fresh custom clone
      ;; marker would introduce another variable that the June 30 known-good
      ;; preserve-copy test did not have.
      (list
        copied-title
        copied-frame
        frame-block
        (swcad-title-safe-bbox copied-title)
        copied-frame-bbox
        (swcad-title-exemplar-role copied-title)
        (swcad-title-exemplar-role copied-frame)
      )
    )
    nil
  )
)

(defun swtitle-pcm-pair-sort (records)
  (vl-sort
    records
    '(lambda (a b)
      (< (car (nth 4 a)) (car (nth 4 b)))
    )
  )
)

(defun swtitle-pcm-write-pair (handle index record copied-title-handles link-counts / title frame frame-block title-bbox frame-bbox title-handle origin copied shared native-like reason)
  (setq title (car record))
  (setq frame (cadr record))
  (setq frame-block (caddr record))
  (setq title-bbox (nth 3 record))
  (setq frame-bbox (nth 4 record))
  (setq title-handle (swcad-title-ename-handle title))
  (setq copied (if (member title-handle copied-title-handles) T nil))
  (setq origin (if copied "copy" "pre-existing"))
  (setq shared (swcad-title-native-link-handle-shared-p title link-counts))
  (setq native-like (swcad-title-target-pair-native-like-p record))
  (setq reason (swcad-title-target-pair-upgrade-reason record))
  (swtitle-pcm-write
    handle
    (strcat
      "pair #" (itoa index)
      " origin=" origin
      " sheet=" (swcad-title-string (swcad-title-sheet-size-from-block-name frame-block))
      " frame-block=" frame-block
      " title-handle=" title-handle
      " frame-handle=" (swcad-title-ename-handle frame)
      " title-role=" (swcad-title-string (nth 5 record))
      " frame-role=" (swcad-title-string (nth 6 record))
      " shared-link=" (if shared "yes" "no")
      " native-like=" (if native-like "yes" "no")
      " reason=" reason
    )
  )
  (swtitle-pcm-write handle (strcat "  title-bbox=" (swcad-title-bbox-string title-bbox)))
  (swtitle-pcm-write handle (strcat "  frame-bbox=" (swcad-title-bbox-string frame-bbox)))
  (swtitle-pcm-write handle (strcat "  title-double-click-point=" (swcad-title-point-string (swcad-title-bbox-center title-bbox))))
  (swtitle-pcm-write-object handle "title-structure" title)
  (swtitle-pcm-write-object handle "frame-structure" frame)
)

(defun swtitle-pcm-main (/ root lsp-path log-path copy-count load-result load-ok version handle pair source-title source-frame source-frame-bbox frame-width frame-records origin-x spacing index copied-record copied-records copied-title-handles all-records link-counts pair-index shared-copy-count shared-preexisting-count save-result save-ok)
  (setq root (swtitle-pcm-root))
  (setq lsp-path (strcat root "/src/tools/gmtitle/swcad_title_scale.lsp"))
  (setq log-path
    (swtitle-pcm-env-path
      "SWCAD_PRESERVE_COPY_MATRIX_LOG"
      (strcat root "/work/swtitle_preserve_copy_matrix_probe.txt")
    )
  )
  (setq copy-count (swtitle-pcm-copy-count))
  (setq load-result (vl-catch-all-apply 'load (list lsp-path)))
  (setq load-ok (not (vl-catch-all-error-p load-result)))
  (setq version
    (if (boundp '*swcad-title-scale-version*)
      *swcad-title-scale-version*
      "<missing>"
    )
  )
  (setq handle (open log-path "w"))
  (if handle
    (progn
      (setq *swtitle-pcm-active-log-handle* handle)
      (swtitle-pcm-write handle "SWTITLE preserve-copy 1/2/3 structural matrix probe")
      (swtitle-pcm-write handle (strcat "LSP path: " lsp-path))
      (swtitle-pcm-write handle (strcat "Load result: " (if load-ok "OK" "ERROR")))
      (swtitle-pcm-write handle (strcat "Loaded version: " version))
      (swtitle-pcm-write handle (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
      (swtitle-pcm-write handle (strcat "Requested preserve-copy count: " (itoa copy-count)))
      (swtitle-pcm-write handle "Safety: wrapper-created work copy; no source title/frame deletion")
      (swtitle-pcm-write handle "Copy marker policy: inherit source xdata; do not add a new clone marker")
      (cond
        ((not load-ok)
          (swtitle-pcm-write handle (strcat "Load error: " (vl-catch-all-error-message load-result)))
          (swtitle-pcm-write handle "Result: ERROR_CORE_LSP_LOAD")
        )
        ((not (swcad-title-current-dwg-in-work-p))
          (swtitle-pcm-write handle "Result: ABORT_NOT_WORK_COPY")
        )
        ((swcad-title-document-read-only-p)
          (swtitle-pcm-write handle "Result: ABORT_READ_ONLY_DOCUMENT")
        )
        ((not (setq pair (swtitle-pcm-a3-native-pair)))
          (swtitle-pcm-write handle "Result: ABORT_NO_NATIVE_LIKE_A3_PAIR")
        )
        (T
          (setq source-title (car pair))
          (setq source-frame (cadr pair))
          (setq source-frame-bbox (nth 4 pair))
          (setq frame-width (- (caddr source-frame-bbox) (car source-frame-bbox)))
          (setq spacing (+ frame-width 50.0))
          (setq frame-records (swcad-title-frame-records))
          (setq origin-x (car (swcad-title-frame-records-right-origin frame-records source-frame-bbox)))
          (swtitle-pcm-write handle (strcat "Exemplar title handle: " (swcad-title-ename-handle source-title)))
          (swtitle-pcm-write handle (strcat "Exemplar frame handle: " (swcad-title-ename-handle source-frame)))
          (swtitle-pcm-write handle (strcat "Exemplar native handles before copy: " (vl-princ-to-string (swcad-title-gmtitle-native-xdata-info source-title))))
          (setq copied-records nil)
          (setq copied-title-handles nil)
          (setq index 1)
          (while (<= index copy-count)
            (setq copied-record (swtitle-pcm-copy-pair pair (+ origin-x (* (- index 1) spacing)) index))
            (if copied-record
              (progn
                (setq copied-records (append copied-records (list copied-record)))
                (setq copied-title-handles (append copied-title-handles (list (swcad-title-ename-handle (car copied-record)))))
              )
            )
            (setq index (+ index 1))
          )
          (swtitle-pcm-write handle (strcat "Created preserve-copy count: " (itoa (length copied-records))))
          (setq all-records (swtitle-pcm-pair-sort (swcad-title-target-gmtitle-pair-records)))
          (setq link-counts (swcad-title-target-title-native-link-counts))
          (setq pair-index 1)
          (setq shared-copy-count 0)
          (setq shared-preexisting-count 0)
          (foreach copied-record all-records
            (if (swcad-title-native-link-handle-shared-p (car copied-record) link-counts)
              (if (member (swcad-title-ename-handle (car copied-record)) copied-title-handles)
                (setq shared-copy-count (+ shared-copy-count 1))
                (setq shared-preexisting-count (+ shared-preexisting-count 1))
              )
            )
            (swtitle-pcm-write-pair handle pair-index copied-record copied-title-handles link-counts)
            (setq pair-index (+ pair-index 1))
          )
          (swtitle-pcm-write handle (strcat "Shared-link copied pairs: " (itoa shared-copy-count)))
          (swtitle-pcm-write handle (strcat "Shared-link pre-existing pairs: " (itoa shared-preexisting-count)))
          (swtitle-pcm-write handle (strcat "Copied title handles: " (vl-princ-to-string copied-title-handles)))
          (setq save-result (vl-catch-all-apply 'vla-Save (list (swcad-title-doc))))
          (setq save-ok (not (vl-catch-all-error-p save-result)))
          (swtitle-pcm-write handle (strcat "Saved probe DWG: " (if save-ok "yes" "no")))
          (if (not save-ok)
            (swtitle-pcm-write handle (strcat "Save error: " (vl-catch-all-error-message save-result)))
          )
          (if (and save-ok (= (length copied-records) copy-count))
            (swtitle-pcm-write handle "Result: STRUCTURAL_MATRIX_READY")
            (swtitle-pcm-write handle "Result: ERROR_MATRIX_COPY_OR_SAVE")
          )
        )
      )
      (swtitle-pcm-write handle (strcat "DBMOD after probe: " (itoa (getvar "DBMOD"))))
      (swtitle-pcm-write handle "Runtime check completed: yes")
      (close handle)
      (setq *swtitle-pcm-active-log-handle* nil)
    )
  )
  (princ)
)

(swtitle-pcm-main)
