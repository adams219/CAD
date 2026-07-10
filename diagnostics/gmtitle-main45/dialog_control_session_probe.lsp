;;; Diagnostic probe: open one native GMTITLE dialog on a dedicated work copy.
;;; An external fixed-control helper selects the exact dialog values and clicks OK.

(vl-load-com)

(defun swtitle-dcs-root (/ root)
  (setq root (getenv "SWCAD_TOOL_ROOT"))
  (if (or (not root) (= (strlen root) 0))
    (setq root "C:/Users/DR-DESIGN/Documents/CAD tool")
  )
  (vl-string-translate "\\" "/" root)
)

(defun swtitle-dcs-env-path (name fallback / value)
  (setq value (getenv name))
  (if (or (not value) (= (strlen value) 0))
    (setq value fallback)
  )
  (vl-string-translate "\\" "/" value)
)

(defun swtitle-dcs-append (path value / handle)
  (setq handle (open path "a"))
  (if handle
    (progn
      (write-line (if value value "") handle)
      (close handle)
    )
  )
)

(defun swtitle-dcs-write-start (path value / handle)
  (setq handle (open path "w"))
  (if handle
    (progn
      (write-line value handle)
      (close handle)
    )
  )
)

(defun swtitle-dcs-probe-name-p (/ name)
  (setq name (strcase (swcad-title-string (getvar "DWGNAME"))))
  (wcmatch name "SWTITLE_DIALOG_CONTROL_SESSION_PROBE*.DWG")
)

(defun swtitle-dcs-placement-point (/ frame-records fallback origin)
  (setq frame-records (swcad-title-frame-records))
  (setq fallback (if frame-records (cadddr (car frame-records)) '(0.0 0.0 420.0 297.0)))
  (setq origin (swcad-title-frame-records-right-origin frame-records fallback))
  (list (car origin) (cadr origin) 0.0)
)

(defun swtitle-dcs-main (/ root lsp-path log-path load-result frame-block placement-point result title frame new-enames valid save-result save-ok title-kinds title-handles frame-kinds frame-handles)
  (setq root (swtitle-dcs-root))
  (setq lsp-path (strcat root "/src/tools/gmtitle/swcad_title_scale.lsp"))
  (setq log-path
    (swtitle-dcs-env-path
      "SWCAD_GMTITLE_DIALOG_SESSION_LOG"
      (strcat root "/work/swtitle_dialog_control_session_probe.txt")
    )
  )
  (swtitle-dcs-write-start log-path "SWTITLE fixed-control GMTITLE session probe")
  (swtitle-dcs-append log-path (strcat "DWG before load: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (swtitle-dcs-append log-path "Safety: dedicated wrapper-created work copy; source content is not deleted")
  (setq load-result (vl-catch-all-apply 'load (list lsp-path)))
  (cond
    ((vl-catch-all-error-p load-result)
      (swtitle-dcs-append log-path (strcat "Load error: " (vl-catch-all-error-message load-result)))
      (swtitle-dcs-append log-path "Result: ERROR_CORE_LSP_LOAD")
    )
    ((not (swcad-title-current-dwg-in-work-p))
      (swtitle-dcs-append log-path "Result: ABORT_NOT_WORK_COPY")
    )
    ((not (swtitle-dcs-probe-name-p))
      (swtitle-dcs-append log-path "Result: ABORT_NOT_DEDICATED_DIALOG_PROBE_COPY")
    )
    ((swcad-title-document-read-only-p)
      (swtitle-dcs-append log-path "Result: ABORT_READ_ONLY_DOCUMENT")
    )
    (T
      (setq frame-block "DR_A3_Outline")
      (setq placement-point (swtitle-dcs-placement-point))
      (swtitle-dcs-append log-path (strcat "Loaded version: " *swcad-title-scale-version*))
      (swtitle-dcs-append log-path (strcat "GstarCAD process ID: " (swcad-title-string (swcad-title-safe-getvar "PROCESSID"))))
      (swtitle-dcs-append log-path (strcat "GstarCAD application HWND: " (swcad-title-string (swcad-title-safe-vla-get (vlax-get-acad-object) 'HWND))))
      (swtitle-dcs-append log-path (strcat "Expected frame: " frame-block))
      (swtitle-dcs-append log-path (strcat "Expected title: " (swcad-title-target-title-block-name)))
      (swtitle-dcs-append log-path (strcat "Placement point: " (swcad-title-point-string placement-point)))
      (swtitle-dcs-append log-path "Dialog requested: yes")
      (setq result
        (vl-catch-all-apply
          'swcad-title-run-native-gmtitle
          (list frame-block placement-point)
        )
      )
      (if (vl-catch-all-error-p result)
        (progn
          (swtitle-dcs-append log-path (strcat "GMTITLE call error: " (vl-catch-all-error-message result)))
          (swtitle-dcs-append log-path "Result: ERROR_NATIVE_GMTITLE_CALL")
        )
        (progn
          (setq title (car result))
          (setq frame (cadr result))
          (setq new-enames (caddr result))
          (setq valid (swcad-title-native-gmtitle-result-valid-p result frame-block))
          (setq title-kinds (if title (swcad-title-native-link-target-kinds title) nil))
          (setq title-handles (if title (swcad-title-gmtitle-native-xdata-info title) nil))
          (setq frame-kinds (if frame (swcad-title-native-link-target-kinds frame) nil))
          (setq frame-handles (if frame (swcad-title-gmtitle-native-xdata-info frame) nil))
          (swtitle-dcs-append log-path (strcat "New INSERT count: " (itoa (length new-enames))))
          (swtitle-dcs-append log-path (strcat "Title handle: " (if title (swcad-title-ename-handle title) "<missing>")))
          (swtitle-dcs-append log-path (strcat "Frame handle: " (if frame (swcad-title-ename-handle frame) "<missing>")))
          (swtitle-dcs-append log-path (strcat "Title block: " (if title (swcad-title-effective-insert-name title) "<missing>")))
          (swtitle-dcs-append log-path (strcat "Frame block: " (if frame (swcad-title-effective-insert-name frame) "<missing>")))
          (swtitle-dcs-append log-path (strcat "Title native handles: " (vl-princ-to-string title-handles)))
          (swtitle-dcs-append log-path (strcat "Title native kinds: " (vl-princ-to-string title-kinds)))
          (swtitle-dcs-append log-path (strcat "Frame native handles: " (vl-princ-to-string frame-handles)))
          (swtitle-dcs-append log-path (strcat "Frame native kinds: " (vl-princ-to-string frame-kinds)))
          (swtitle-dcs-append log-path (strcat "Native result valid: " (if valid "yes" "no")))
          (if valid
            (progn
              (setq save-result (vl-catch-all-apply 'vla-Save (list (swcad-title-doc))))
              (setq save-ok (not (vl-catch-all-error-p save-result)))
              (swtitle-dcs-append log-path (strcat "Saved probe DWG: " (if save-ok "yes" "no")))
              (if save-ok
                (swtitle-dcs-append log-path "Result: NATIVE_GMTITLE_CREATED_BY_FIXED_CONTROL_SELECTION")
                (progn
                  (swtitle-dcs-append log-path (strcat "Save error: " (vl-catch-all-error-message save-result)))
                  (swtitle-dcs-append log-path "Result: ERROR_PROBE_SAVE")
                )
              )
            )
            (swtitle-dcs-append log-path "Result: FAIL_GMTITLE_SELECTION_OR_PLACEMENT")
          )
        )
      )
    )
  )
  (swtitle-dcs-append log-path (strcat "DBMOD after probe: " (itoa (getvar "DBMOD"))))
  (swtitle-dcs-append log-path "Runtime check completed: yes")
  (princ)
)

(swtitle-dcs-main)
